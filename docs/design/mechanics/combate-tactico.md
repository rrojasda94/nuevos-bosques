# Ficha: Combate táctico en cuadrícula

> Dueño: `game-designer`. ADR 0016. **Versión 0.5** (antes del grupo garelino; `roadmap-0.5.md`). Valores **provisionales**.
> Sustituye la presentación por menú "estilo Pokémon" de `cruce-y-combate-v2.md`. Las reglas de cruce, pago, memoria del Bosque, XP, fatales y reaparición siguen igual. La IA del PR #67 se traduce a la cuadrícula (`ia-de-combate.md`).

## Objetivo
Combates tácticos donde importan la posición, la altura, la orientación y los stats, al estilo de *Final Fantasy Tactics Advance* (GBA).

Palabras del dueño:
- "algo que estas olvidando con lo de los combates es que tiene que ser como final fantasi advance de GBA esta super genial esa manera de combatir. mejor que la de estilo pokemon como ahora."
- "FF Tactics Advance, si. Pero que los stats igual influyen en la distancia que se pueden mover, el estivar, el atacar por sorpresa, el turno que le corresponde, etc."
- Sobre la vista: "vista desde arriba con las alturas por capas."

## Pilares
- **Pilar 3 (legibilidad 8-bit)**: un tablero pequeño, casillas resaltadas (dónde puedo moverme y a quién llego) y un icono de orientación.
- **Pilar 1**: el terreno del mundo es el tablero, y el sigilo del mundo decide la sorpresa.
- **Pilar 4**: cada combate ocurre sobre el relieve del lugar.

## Presión de supervivencia
- **Añade**: te pueden rodear, atacar por la espalda o desde lo alto, y los ataques en área castigan quedarse en mal sitio.
- **Alivia**: un buen posicionamiento (altura, flancos, esquivar lo anunciado) permite ganar peleas que por stats serían duras.

## Reglas

### Tablero y vista
- **Vista: cenital (top-down) con alturas por capas** (decisión del dueño): el mismo relieve en capas estilo Zelda del Mundo 2.0 (ADR 0014).
- **Todos los combates van en tablero**, también el 1 contra 1 contra un Botarramas (dueño, #187: "Sí, todos").
- **De dónde sale**: un **recorte del terreno** alrededor del punto donde empieza el combate.
  - Se pide a la consulta del Mundo 2.0 `WorldQuery.rect(origin_world_cell, size)`, que devuelve por casilla `level`, `blocked`, `stair/ramp`, `water/ford` y `object_kind` (la ofrece la otra sesión).
  - Conserva árboles y rocas (obstáculos), agua (no transitable salvo en vados) y alturas.
  - Antes del Mundo 2.0, el recorte es llano.
- **Tamaño variable según el espacio** (dueño: "la cantidad de personajes que pueden entrar en un campo de batalla debe ser proporcional al espacio que haya disponible [...] si es un espacio reducido, podrian entrar solo 1 a 3 por bando y es un mapa muy abierto como un desierto o una villa, podría ser el 6v6"):

| Tablero | Casillas | Dónde | Cámara |
|---|---|---|---|
| **Pequeño** | 8 × 6 | Bosque denso, tarca, cueva, interiores | Fija (cabe en 320 × 180) |
| **Medio** | 10 × 8 | Bosque claro, senderos, orillas de río | Fija o con poco desplazamiento |
| **Grande** | 14 × 10 | Desierto, pradera, sabana, villa | Se desplaza con el cursor |

  - **Cómo se elige** (propuesta):
    1. Primero se elige el recorte (reglas de abajo: poco desnivel, transitable, conexo).
    2. Luego se mira qué proporción de un recorte **grande** (14 × 10) alrededor del punto de encuentro es transitable:
       - **≥ 80%** → grande;
       - **≥ 60%** → medio;
       - si no → pequeño.
    3. El **bioma** solo desempata.
  - La escena de UI (T4) ya admite tamaño variable y cámara con desplazamiento.
  - El "8 × 6 y 3 por bando" de #185 pasa a ser **lo típico en espacios cerrados**, no un tope (ADR 0016).
- **Alturas en el tablero** (el mundo tiene **niveles 0–3**, ADR 0014 §3; en el mundo, cada nivel de risco ocupa **2 filas** de cara, que bloquean):
  1. **Se buscan recortes con poco desnivel**: el recorte se elige, dentro de 1 chunk del punto de encuentro, para que tenga **como mucho 2 niveles** de diferencia y al menos un **70% de casillas transitables**.
  2. **Las caras de risco se comprimen**: en el tablero, cada casilla toma el **nivel** del terreno, y las filas de cara de risco **desaparecen**. El risco queda como un **salto de altura entre casillas vecinas**, como en FFTA, en lugar de 2 filas bloqueadas por nivel. Así el desnivel no se come el tablero.
  3. **Escaleras y rampas** se conservan y unen niveles sin gastar Salto.
  4. **Tablero conexo**: debe existir un camino a pie (con escaleras o rampas) entre los dos bandos. Si no, se elige otro recorte.
- **Colocación**:
  - cada bando, en las columnas del lado por donde llegó (o el opuesto, los enemigos): **2 columnas** en el tablero pequeño y el medio, **3** en el grande;
  - entre ambos quedan 4 columnas (pequeño), 6 (medio) u 8 (grande). Con Mov 3–5 se llega al contacto en 1–3 turnos.

### Stats que influyen (dueño: "los stats igual influyen")
| Stat | Influye en |
|---|---|
| **AGI** | Turno, movimiento (Mov), salto, evasión |
| **ATQ / DEF** | Daño (misma fórmula de siempre) |
| **PV** | Aguante |

**Derivados de AGI** (provisionales):
- **Mov** (casillas por turno) = 3 + ⌊(AGI − 5)/2⌋, entre 2 y 6.
  - Adoc: 3 en nivel 1 y 4 desde el nivel 4.
  - Botarramas (AGI 3): 2, porque renquea.
  - Ofomni y Aledra: 3.
  - Reparep: 4.
- **Salto** (niveles que puede subir **entre dos casillas vecinas**) = 1 + ⌊AGI/7⌋.
  - Adoc: 1 en nivel 1 y 2 desde AGI 7.
  - Reparep: 2.
  - Un salto de 3 niveles (de 0 a 3) solo se sube por escalera o rampa: nadie llega a Salto 3 en la práctica.
- Se baja hasta Salto + 1 capas. Las **escaleras y rampas** se suben sin gastar Salto.

### Turnos (estilo CT de FFTA)
- Cada combatiente tiene un contador **CT**. En cada tick, CT += AGI. Al llegar a **100**, juega su turno.
- **CT inicial** = AGI × 10, así que el más ágil empieza antes.
- **En su turno**: **mover** (hasta Mov) y **actuar**, en cualquier orden. Al terminar, **elige orientación** (4 direcciones).
- **Coste del turno**:

| Hizo | CT tras el turno |
|---|---|
| Mover y actuar | −100 |
| Solo una de las dos | −80 |
| Ninguna (**Esperar**) | −60 (vuelve a jugar antes) |

- **Empate de CT**: primero el bando del jugador.
- Una línea de iconos muestra el orden de los próximos turnos (ya existe, PR #67).

### Atacar, evasión y orientación
- **Alcance**: cuerpo a cuerpo a **1 casilla ortogonal** (no en diagonal).
- **Precisión** = 100 − **Evasión** del defensor (mínimo 5%, máximo 100%).
- **Evasión** (provisional):

| Por dónde le atacan | Evasión |
|---|---|
| **Frente** | 5 + 2 × AGI (%) |
| **Flanco** | La mitad |
| **Espalda** | 0 |

  - **Altura** (niveles 0–3 del mundo; en el tablero, como mucho 2 de diferencia): −10 puntos de evasión por cada **nivel** que el atacante esté por **encima** y +10 por cada nivel por **debajo**.
  - **Cuerpo a cuerpo entre niveles**: solo se puede atacar a una casilla vecina si la diferencia de nivel es ≤ el Salto del atacante (si no, no llega).
- **Daño**: max(1, ATQ − DEF + aleatorio de −1 a +2), más:
  - **flanco** +1;
  - **espalda** +2;
  - +1 por cada capa de altura a favor.
- **Ejemplo**: un adoc de nivel 1 (AGI 5) tiene un 15% de evasión de frente, un 7% de flanco y un 0% de espalda.

### Ataque por sorpresa (dueño: "el atacar por sorpresa")
- **Emboscada tuya**: si el combate empieza con el enemigo **sin haberte detectado**:
  - lo abordas sin entrar en su `vision_radius`, gracias a Paso quedo, una máscara o una sicabi cercana, o lo atacas con E por la espalda mientras ronda;
  - tú y tus aliados empezáis con **CT 100** (jugáis todos antes) y los enemigos empiezan **de espaldas** a vosotros.
- **Emboscada del enemigo**: si te alcanzan sin que lo hayas visto (un cazador que aparece fuera de la vista, Aledra de noche, un ataque al dormir):
  - los enemigos empiezan con CT 100 y **tú, de espaldas**.
- **Normal**: CT inicial por AGI y orientaciones enfrentadas.

### Acciones del jugador
| Acción | Efecto |
|---|---|
| **Atacar** | Ver arriba. Golpe fuerte (rama Sombra), pasivo: tu primer ataque listo hace ×1,5, una vez cada 3 turnos |
| **Defender** | El daño recibido ×0,5 hasta tu siguiente turno; cuenta como acción |
| **Esperar** | No actúas; CT −60 |
| **Ofrecer Luz / Ofrecer ofrenda** | Sin cambios: pagas N y el Único **apaciguable** se va; termina el combate (ADR 0013). Desactivado con los no apaciguables (Ofomni descarriado, Aledra) |
| **Huir** | Desde **cualquier casilla del borde** del tablero, **siempre** con éxito (dueño, #184: "Cualquier borde, seguro"). Huye todo tu bando. El enemigo recupera PV (como hoy) |
| **Orden al grupo** | Libre / Atacar a tu objetivo / Defender (PR #67), sin gastar acción |

- **Apresurar** (PR #67) desaparece: el sistema CT ya premia moverse sin actuar o esperar.
- **Cambiar de fila** desaparece: las filas pasan a ser **posición real** (`ia-de-combate.md`).

### Ataques en área y especiales
- **Latigazo múltiple del Ofomni** (cada 3 ataques, ×3):
  - área según el tablero: **3 × 1** (la línea de 3 justo delante) en el pequeño y el medio, y **3 × 2** en el grande, donde hay más sitio para esquivar;
  - se **anuncia** en su turno anterior marcando las casillas; salir del área lo esquiva;
  - **Defender** lo reduce a la mitad.
- **Ataque conjunto de los reparep**: cuando **2 o más reparep están adyacentes al mismo objetivo** (como mucho 4, uno por lado ortogonal), atacan juntos en el turno del primero, con daño = suma de ATQ − DEF (una sola vez). Los demás se acercan para rodear.
- **Vendar y Animar** (apoyo): alcance **2 casillas**.

### Grupo y tamaño
- **Cupo por bando, proporcional al espacio** (idea del dueño; fórmula propuesta, valores en datos):
  - **Cupo** = clamp(⌊casillas transitables del tablero / (N × 2)⌋, 1, 6), con **N = 8** casillas por personaje.
  - El coordinador propuso N ≈ 6; con 8 el tablero medio da 4 y no 5, más cerca del "1 a 3 en reducido, 6 en abierto" del dueño.

  | Tablero (transitable) | Casillas libres | Cupo |
  |---|---|---|
  | 8 × 6 al 70% | ~33 | 2 |
  | 8 × 6 al 100% | 48 | 3 |
  | 10 × 8 al 80% | ~64 | 4 |
  | 14 × 10 al 90% | ~126 | 6 (tope) |

  - El mismo cupo vale para los **dos bandos**.
- **Tu party** (dueño, #188: "eliges tu party inicial"):
  - **Antes del combate** eliges quiénes entran, hasta el cupo, entre tus aliados presentes (adoc aliados, miembros del grupo garelino, el Único de la Llamada del Bosque).
  - La elección viene **preseleccionada** con la última que usaste; confirmar es un botón.
  - En una **emboscada del enemigo** no hay tiempo: entra la última party guardada.
  - El jugador siempre entra.
- **Si un grupo es mayor que el cupo** (los dos bandos, propuesta):
  - los que sobran **esperan en su borde** y entran como **refuerzo** cuando cae o se retira uno de su bando, por su columna de colocación;
  - así un grupo grande sigue siendo una amenaza en un espacio pequeño, pero escalonada;
  - la huida por cualquier borde sigue disponible.
- **Tamaños de grupo**:
  - **Reparep**: vuelven a grupos de **2–4**, como dijo el dueño ("de 2 hasta 4"). En un tablero pequeño (cupo 2–3), el resto entra como refuerzo.
  - **Garelinos**: 2–4; en espacios abiertos pueden llegar a 6.
  - **Grupo garelino propio**: hasta 5 miembros (`dos-caminos.md`); entran según el cupo y tu elección.
  - **Únicos solos**: 1.
- **Aliados caídos**: se retiran (no mueren; regla de no matar).

### Lo que no cambia
- Encuentro con los Botarramas: primero el **menú del borde** (pagar, ofrenda, Imponerse, enfrentar, retroceder). "Enfrentar" abre el tablero.
- El Bosque recuerda, hostilidad, relación, XP por victoria, `fatal_at`, reaparición tras una derrota no fatal, Senda.
- **Textos** (dueño, #186: "Textos cortos y números"):
  - **números de daño flotando** sobre el que recibe el golpe ("Falla" si esquiva);
  - una **línea corta** con el nombre de la acción, como en FFTA ("Golpe por la espalda", "Latigazo múltiple", "Vendar").
  - **Se acaba la narración mensaje a mensaje** (estilo Pokémon).

## Inputs / outputs
- **Inputs:** terreno del punto de encuentro (alturas, obstáculos, agua), combatientes (stats, AGI, rol), estado de detección (sorpresa), acciones.
- **Outputs:** posiciones, CT, orientaciones, daño y evasiones, resultado del combate (victoria, pago, huida, derrota).

## Interacción con otros sistemas
- `ia-de-combate.md`: IA en la cuadrícula.
- `cruce-y-combate-v2.md`: reglas de pago y memoria.
- `sigilo-y-robo.md` y `monstruos.md`: visión y sorpresa.
- Mundo 2.0 (ADR 0014; otra sesión): relieve en capas para el tablero.
- `moralidad-y-progresion.md`: AGI automática con el nivel y skills.

## Casos límite
- **Recorte con agua o riscos que separan a los bandos**: el recorte se desplaza o se garantiza un camino (el tablero debe ser conexo).
- **Nadie puede alcanzar a nadie** (Mov bajo y tablero grande): los perfiles de IA se acercan cada turno; el tablero de 12 × 8 lo limita.
- **Combate contra un solo Botarramas**: también en tablero (#187); rápido por su Mov 2 en un tablero de 8 × 6.
- **Huir sin estar en el borde**: la opción no aparece; hay que caminar hasta cualquier casilla del borde. En un 8 × 6 son 3 casillas como mucho; en un 14 × 10, hasta 5 (huir en abierto cuesta más, y está bien).
- **Cupo 1** (espacio muy cerrado): solo el jugador contra un enemigo; el resto de los dos bandos entra como refuerzo.
- **Refuerzo enemigo con su columna ocupada**: entra por la casilla libre más cercana de su borde.
- **Recorte sin zona de poco desnivel en 1 chunk**: se usa el mejor disponible, con las caras de risco comprimidas a saltos de altura.
- **Emboscada con aliados lejos**: los aliados aparecen junto al jugador.

## Criterios de éxito para playtest
- El dueño reconoce el estilo FFTA (pregunta directa).
- El jugador usa al menos una vez la altura o la espalda a propósito.
- El jugador esquiva un Latigazo anunciado moviéndose fuera del área.
- Una emboscada con sigilo cambia el resultado de una pelea difícil.

## Plan de PR (pequeños)
| # | PR | Agentes | Depende de |
|---|---|---|---|
| T1 | **Tablero lógico** (clase pura; **hecho**): casillas, niveles 0–3 con las caras comprimidas, obstáculos, elección del recorte (poco desnivel, 70% transitable, conexo), colocación inicial; tests. Consume `WorldQuery.rect` cuando exista | rpg-systems-dev, engine-architect | — (llano hasta que haya relieve) |
| T2 | **Turnos CT, movimiento** (Mov, Salto, caminos) **y orientación**; tests | rpg-systems-dev | T1 |
| T3 | **Acciones**: atacar con evasión, orientación y altura; Defender, Esperar, Ofrecer, Huir desde cualquier borde; tests | rpg-systems-dev | T2 |
| T4 | **Escena táctica**: cursor, rangos resaltados, menú Mover / Actuar / Esperar / Orientación, línea de turnos, números de daño flotando y línea corta de acción | ui-ux-dev | T3 |
| T5 | **IA en la cuadrícula**: perfiles con movimiento, roles (Cubrir, Remate, Vendar, Animar), órdenes | rpg-systems-dev | T3 |
| T6 | **Especiales**: Latigazo en área anunciado, ataque conjunto de reparep, sorpresa y emboscada | rpg-systems-dev | T5 |
| T7 | **Arte**: sprites de combate en 4 direcciones; tablero desde el relieve del Mundo 2.0 | pixel-artist, world-gen-dev (sesión del Mundo 2.0) | T4; 0.4 |
| T8 | Retirar la escena antigua y ajustar el balance tras el playtest | rpg-systems-dev, game-designer | T6 |

## Preguntas abiertas
- ~~#184–#187~~ Resueltas por el dueño:
  - Huir desde cualquier borde, siempre;
  - tablero de 8 × 6 y 3 por bando;
  - textos cortos y números;
  - todos los combates en tablero.
- ~~**#188**~~ Resuelta (dueño: "eliges tu party inicial").
- **#189**: tablero y cupo variables: ¿se confirman los 3 tamaños (8 × 6, 10 × 8, 14 × 10), la elección por la proporción transitable, N = 8 casillas por personaje (cupo entre 1 y 6) y los refuerzos por el borde para los que no caben?

### Pendiente en el plan de PR (tablero variable)
- **T1b**: tamaño de tablero según el espacio, cupo por bando, refuerzos, y pantalla de elección de party (lógica y tests; la UI de T4 ya admite tamaño variable).
