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
- **De dónde sale**: un **recorte del terreno** alrededor del punto donde empieza el combate.
  - Conserva árboles y rocas (obstáculos), agua (no transitable salvo en vados) y **alturas** (capas 0–2 del Mundo 2.0, con escaleras y rampas).
  - Antes del Mundo 2.0, el recorte es llano.
- **Tamaño**: **12 × 8 casillas** (a 16 px son 192 × 128 en una pantalla de 320 × 180, y queda sitio para la interfaz).
- **Recorte jugable**: si menos del 50% de las casillas son transitables, se desplaza el recorte al claro más cercano (a 1 chunk como mucho).
- **Colocación**: el jugador y sus aliados aparecen en las **2 columnas del lado por donde llegó**; los enemigos, alrededor del punto de encuentro, del lado opuesto.

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
- **Salto** (capas que puede subir) = 1 + ⌊AGI/7⌋.
  - Adoc: 1 en nivel 1 y 2 desde AGI 7.
  - Reparep: 2.
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

  - **Altura**: −10 puntos de evasión por cada capa que el atacante esté por **encima** y +10 por cada capa por **debajo**.
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
| **Huir** | Solo desde una casilla del **borde por el que llegaste** (2 columnas). Funciona siempre (provisional, #184). El enemigo recupera PV (como hoy) |
| **Orden al grupo** | Libre / Atacar a tu objetivo / Defender (PR #67), sin gastar acción |

- **Apresurar** (PR #67) desaparece: el sistema CT ya premia moverse sin actuar o esperar.
- **Cambiar de fila** desaparece: las filas pasan a ser **posición real** (`ia-de-combate.md`).

### Ataques en área y especiales
- **Latigazo múltiple del Ofomni** (cada 3 ataques, ×3):
  - **área de 3 × 2 casillas** delante de él;
  - se **anuncia** en su turno anterior marcando las casillas; salir del área lo esquiva;
  - **Defender** lo reduce a la mitad.
- **Ataque conjunto de los reparep**: cuando **2 o más reparep están adyacentes al mismo objetivo**, atacan juntos en el turno del primero, con daño = suma de ATQ − DEF (una sola vez). Los demás reparep se acercan para rodear.
- **Vendar y Animar** (apoyo): alcance **2 casillas**.

### Grupo y tamaño
- **Por bando**: hasta **6** en el tablero:
  - el jugador más 0–2 aliados adoc (más con "Llamada del Bosque");
  - el grupo garelino de hasta 5;
  - enemigos de 1 a 4 (reparep 2–4, garelinos 2–3).
  - Si un bando supera los 6, los que sobran entran como **refuerzo** cuando cae uno (provisional, #185).
- **Aliados caídos**: se retiran (no mueren; regla de no matar).

### Lo que no cambia
- Encuentro con los Botarramas: primero el **menú del borde** (pagar, ofrenda, Imponerse, enfrentar, retroceder). "Enfrentar" abre el tablero.
- El Bosque recuerda, hostilidad, relación, XP por victoria, `fatal_at`, reaparición tras una derrota no fatal, Senda.
- **Textos**: frases cortas sobre el tablero ("¡Golpe por la espalda!", números de daño). La narración larga mensaje a mensaje se reduce (#186).

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
- **Combate contra un solo Botarramas**: también en tablero (#187); rápido por su Mov 2.
- **Huir sin estar en el borde de entrada**: la opción no aparece; hay que caminar hasta allí.
- **Emboscada con aliados lejos**: los aliados aparecen junto al jugador.

## Criterios de éxito para playtest
- El dueño reconoce el estilo FFTA (pregunta directa).
- El jugador usa al menos una vez la altura o la espalda a propósito.
- El jugador esquiva un Latigazo anunciado moviéndose fuera del área.
- Una emboscada con sigilo cambia el resultado de una pelea difícil.

## Plan de PR (pequeños)
| # | PR | Agentes | Depende de |
|---|---|---|---|
| T1 | **Tablero lógico** (clase pura): casillas, alturas, obstáculos, recorte del terreno, colocación inicial; tests | rpg-systems-dev, engine-architect | — (llano hasta que haya relieve) |
| T2 | **Turnos CT, movimiento** (Mov, Salto, caminos) **y orientación**; tests | rpg-systems-dev | T1 |
| T3 | **Acciones**: atacar con evasión, orientación y altura; Defender, Esperar, Ofrecer, Huir desde el borde; tests | rpg-systems-dev | T2 |
| T4 | **Escena táctica**: cursor, rangos resaltados, menú Mover / Actuar / Esperar / Orientación, línea de turnos, textos cortos | ui-ux-dev | T3 |
| T5 | **IA en la cuadrícula**: perfiles con movimiento, roles (Cubrir, Remate, Vendar, Animar), órdenes | rpg-systems-dev | T3 |
| T6 | **Especiales**: Latigazo en área anunciado, ataque conjunto de reparep, sorpresa y emboscada | rpg-systems-dev | T5 |
| T7 | **Arte**: sprites de combate en 4 direcciones; tablero desde el relieve del Mundo 2.0 | pixel-artist, world-gen-dev (sesión del Mundo 2.0) | T4; 0.4 |
| T8 | Retirar la escena antigua y ajustar el balance tras el playtest | rpg-systems-dev, game-designer | T6 |

## Preguntas abiertas
- **#184**: Huir: ¿solo desde el borde por el que llegaste y siempre con éxito, o con probabilidad desde cualquier sitio?
- **#185**: tamaño: ¿tablero de 12 × 8 y hasta 6 por bando (con refuerzos)?
- **#186**: ¿se conserva algo de la narración mensaje a mensaje (estilo Pokémon) o solo textos cortos sobre el tablero?
- **#187**: ¿todos los combates van en tablero, también el 1 contra 1 contra un Botarramas?
