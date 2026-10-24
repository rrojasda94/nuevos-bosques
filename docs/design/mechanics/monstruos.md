# Ficha: Monstruos (Únicos y otros)

> Dueño: `game-designer`. Fuentes: palabras del dueño (citadas en cada monstruo), glosario §3 ("Únicos", "Iserald", "Aledra", "Ofomni"), ADR 0004 (nota "Derrota en Aventura"), ADR 0009 (Únicos de placeholder), `mision-ofomni.md`, `cruce-y-combate-v1.md`.
> El lore lo fija el glosario; aquí solo hay reglas de juego. **Valores PROVISIONALES**.

## Objetivo
Reunir en un sitio qué monstruos hay, qué se sabe de cada uno y qué regla de derrota (fatal o no) aplica. Incluye una propuesta de combate contra grupos para los reparep.

## Pilares
- **Pilar 3 (legibilidad 8-bit)**: cada monstruo se reconoce por su silueta y se explica en una línea.
- **Pilar 4**: qué monstruos hay y cuándo son fatales cambia según el lugar y el Momento (día o noche).

## Presión de supervivencia
- **Añade**: los monstruos **fatales** convierten una derrota en **game over** (ADR 0004). Aledra lo es de noche, lo que hace la noche más peligrosa. Los grupos de reparep castigan pelear con la DEF baja o sin Luz.
- **Alivia**: los Únicos comunes y el Ofomni de la primera misión no son fatales; perder contra ellos te devuelve a la villa.

## Regla general: percepción y encuentro
Palabras del dueño (2026-10-24): "los Únicos deben tener un radio de visión, una velocidad, y una distancia para iniciar el engage."

Todo Único que se mueva por el mundo tiene tres parámetros (en datos, por tipo):

| Parámetro | Qué es | Botarramas (0.2.0) | Ofomni (0.2.0) |
|---|---|---|---|
| `vision_radius` | Casillas (Chebyshev) a las que ve al jugador y empieza a ir hacia él | 10 | Según el PR 6 |
| `step_time` | Segundos por casilla al moverse (más alto = más lento; el jugador va a 0,16) | 0,24 | Según el PR 6 |
| `engage_distance` | Distancia a la que empieza el encuentro (menú del borde o combate) | 1 | 2 |

- Las máscaras y los artefactos que camuflan la Luz (0.3.0) actuarán sobre la visión (`sigilo-y-robo.md`).
- Los valores del Ofomni que no figuran aquí son los del PR 6; deben copiarse a esta tabla cuando estén fijados.

## Regla general: apaciguable o no
- Cada tipo de monstruo tiene **`appeasable: bool`** (0.3, coordinador sobre las palabras del dueño).
  - `true`: en combate se puede pagar con "Ofrecer Luz" u "Ofrecer ofrenda" para que se vaya (ADR 0013). Ejemplos: Botarramas, `ofomni`.
  - `false`: esas acciones están desactivadas y hay que vencerlo o huir. Ejemplo: `ofomni_descarriado` (berserk, el de la misión).
- Encaja con el glosario §5: el adoc es especialista "para apaciguar Únicos descarriados". Que uno descarriado no se apacigüe con Luz, sino que haya que vencerlo, es la regla de juego actual.

## Regla general: fatal según el Momento
- Palabras del dueño: "es un survival, deberia ser game over dependiendo del monstruo que te ataque, un iserald es fatal" y "Aledras son fatales en las noches".
- Cada tipo de monstruo tiene un campo **`fatal_at`**: la lista de Momentos en los que perder contra él es game over.
  - `[]`: nunca es fatal.
  - `["gietos", "riumna"]`: siempre es fatal.
  - `["riumna"]`: solo de noche.
- Se mira el Momento en que **empieza** el combate. El reloj está parado durante el combate (ADR 0012), así que no cambia a mitad de pelea.
- Perder contra un monstruo fatal en ese Momento → **game over** (texto `defeat_fatal_game_over`). Si no → despiertas en la villa natal (regla de v1).
- Sustituye a la regla anterior `fatal: bool` (ADR 0004).

## Catálogo
| Monstruo | Qué dijo el dueño | Glosario §3 | `fatal_at` | Estado en el juego |
|---|---|---|---|---|
| **Botarramas** (nombre provisional; sustituyen a los "Únicos comunes de borde") | "Los Únicos que restringen el paso se llamaran Botarramas (por ahora) son aver sin plumas que renquean por los bosques cuando sienten la presencia de alguien acercandose." Antes: "los únicos no son arboles, son monstruos"; "pueden regenerarse con el tiempo" | Agentes del Bosque que se activan como anticuerpos; nacen de un árbol, animal o sustancia del Bosque | `[]` (provisional) | **0.2.0** (sección siguiente). Sustituyen a los 5 tipos de placeholder de borde (ADR 0009). |
| **Ofomni descarriado** (`ofomni_descarriado`, el de la misión) | "el ofomni de la mision y el de los bosques con nujio no estan diferenciados" (dueño, 0.3). Es el de "Primer encargo": berserk (glosario §5: los adoc apaciguan Únicos "descarriados"; ronda 1: Únicos "en modo berserk") | Subtipo de Únicos | `[]` en la primera misión | **`appeasable: false`**: no acepta Luz ni ofrendas; hay que vencerlo. Latigazo múltiple. 0.2.0, `mision-ofomni.md`. |
| **Ofomni** (`ofomni`, el de un Bosque con Nujio) | "un ojo con tentáculos"; "ataca con latigos y cada 3 turnos usa varios latigos"; "es no fatal en la primera mision"; "si robas algun objeto [...] despiertas a los ofomni que te persiguen por el bosque hasta la frontera" | Subtipo de Únicos | Por definir (#127) | **`appeasable: true`**: se puede apaciguar con Luz u ofrendas. 0.3: perseguidor tras un robo (`sigilo-y-robo.md`). No guarda bordes. |
| **Aledra** | "Aledras son fatales en las noches" | Aparece cuando la villa crece en población sin permiso y causa enfermedades. Serpiente roja gigante con aura rojiza, cabeza de calavera reptiliana, ojos negros que se comen la luz física y colmillos carmesí | `["riumna"]` | No existe todavía. **No guarda bordes**: queda para su evento de villa (glosario). Dónde y cuándo aparece en Aventura: #128. |
| **Iserald** | "un iserald es fatal" | El Único más poderoso y último recurso; sale del propio Nujio. Teorías: inmolación para que el Bosque no sea profanado, o pérdida de cordura | `["gietos", "riumna"]` | No existe todavía (#103). |
| **Reparep** | "son como cangrejos fantasmales y tacan en grupos de 2 hasta 4 individuos. Son debiles solos pero en grupo el ataque conjunto suma daños" | No aparece en el glosario | `[]` (provisional) | **0.3.0** (fuera de la 0.2.0). Propuesta de combate de grupo abajo. Si son Únicos o no: #128. |

"Aun no tenemos más monstruos" (dueño, 2026-10-24). Botarramas se añadió después (dueño, misma fecha).

**Comportamiento según el estado del Bosque** (backlog; `bosques-y-relacion.md`):
- **enojado**: muchos Únicos desplegados y encuentros repetidos; no se puede pagar.
- **corrupto**: emboscadas ocasionales y riesgo de **Iserald** (fatal) (#139).
- **muerto**: pocos Únicos; a veces uno pide un poco de Luz por su cuenta.
- **en necesidad de ayuda**: algunos Únicos del Bosque **pelean a tu lado** (aliados, #143).

## Botarramas (0.2.0, se implementa ya)
> Valores **PROVISIONALES**, en `data/combat/balance.json` (bloque `botarramas`; estructura: `rpg-systems-dev`). Arte: `pixel-artist` (ave sin plumas, renqueante, con la combinación de colores de su Bosque).

### Objetivo
Que los guardianes del paso entre Bosques se vean en el mundo y salgan al encuentro del jugador, en vez de aparecer solo como un menú al tocar el borde. Palabras del dueño: "Me gustaria ver que los Únicos esten visibles en el mapa. Que te intercepten cuando estas acercandote a uno de los bosques."

### Pilares y presión
- **Pilar 3 (legibilidad)**: el peligro se ve venir y se puede leer.
- **Pilar 4**: los puestos dependen de la seed y de las fronteras del Bosque.
- **Añade presión**: acercarse a un Bosque cerrado tiene un coste visible (Luz, ofrenda o combate).
- **Alivia**: el peligro se ve venir y se puede retroceder antes del contacto. Colarse **no** es posible sin máscara (dueño, 2026-10-24).

### Reglas
- **Quién**: los Botarramas son los Únicos que **restringen el paso** entre Bosques (sustituyen al "Único de borde" de `cruce-y-combate-v1.md`). Pertenecen al Bosque que guardan, el que el jugador quiere abrir.
- **Cuántos y dónde**:
  - Un Botarramas por cada **tramo de frontera de chunk**, es decir, cada lado de 64 casillas que comparten dos chunks de Bosques distintos.
  - Está apostado en el lado del Bosque que guarda, junto a la **puerta o el camino** que cruza ese tramo, o en su punto medio si no hay camino.
  - Posición determinista por seed.
- **Visibilidad**: se ven en el mundo. En el mapa (M) aparecen en su última posición vista (`navegacion.md`).
- **Reposo**: en su puesto, con un renqueo de ida y vuelta de hasta **3 casillas**.
- **Detección**: si el jugador entra en su **radio de visión** (`vision_radius` = 10 casillas, distancia de Chebyshev) y el Bosque está **cerrado**, el Botarramas pasa a **interceptar**.
- **Intercepción**:
  - Renquea hacia el jugador a **1 casilla cada 0,24 s** (el jugador va a 1 cada 0,16 s: el Botarramas va a 2/3 de su velocidad).
  - Respeta las casillas transitables y puede salir de su Bosque hasta **4 casillas** dentro del vecino.
  - Correa: no se aleja más de **14 casillas** de su puesto. Si el jugador sale de un radio de **14**, vuelve a su puesto.
- **Encuentro** (a `engage_distance` = 1, es decir, casilla adyacente, también en diagonal): se pausa el juego y se abre el **menú del borde** actual: "Ofrecer N Luz", "Ofrecer una ofrenda" (`ofrendas-v1.md`), "Enfrentar a sus Únicos" y "Retroceder". Las reglas, N y d son las de `cruce-y-combate-v1.md`.
- **Resultado**:
  - ~~Pagar o vencer abre el Bosque entero.~~ **0.3 (ADR 0013, "el Bosque recuerda")**:
    - **Pagar** (en el borde, o en combate con Ofrecer Luz u ofrenda) deja el Bosque **pagado**: todos sus Botarramas, **pasivos**.
    - **Vencer** disuelve **solo a ese** Botarramas. El Bosque queda **forzado**: los demás siguen activos y exigen pago. La **hostilidad** del Bosque sube 1 (peaje +2; `vision_radius` de sus Botarramas +2 por nivel, tope +6) y la relación baja 10 (`cruce-y-combate-v2.md`).
  - **Retroceder o huir**: el jugador vuelve 2 casillas hacia su Bosque y ese Botarramas queda **sin detectar durante 3 s**, para no repetir el menú en bucle.
  - **Derrota**: regla de v1 (no fatal: despiertas en la villa natal).
- **Sin colarse** (dueño, 2026-10-24: "sneak puede darse usando una mascara solamente o algun otro artefacto que camufle la Luz del jugador"):
  - En la 0.2.0 no hay máscaras, así que **el borde de un Bosque cerrado sigue cerrado**.
  - Si el jugador llega a la frontera sin que lo haya alcanzado un Botarramas, al tocarla se abre el mismo menú del borde (como en v1).
  - Colarse llegará con las máscaras y los artefactos de camuflaje de la 0.3.0 (`sigilo-y-robo.md`).
- **Stats**: los del Único de v1 según d (PV 18 + 4·d, ATQ 4 + d, DEF 1 + ⌊d/2⌋ con tope 4). XP y Luz de victoria: igual que un Único (`progresion-adoc.md`).
- **Fatal**: `fatal_at: []` (provisional).
- **Regeneración**: recupera todos sus PV si el jugador huye o retrocede (v1). Por tiempo: #120.
- **Nombre en el combate**: "Botarramas" (provisional; `narrative-writer`).

### Números (para `balance.json`)
| Clave propuesta | Valor |
|---|---|
| `botarramas.vision_radius` | 10 |
| `botarramas.step_time` | 0.24 (s por casilla) |
| `botarramas.engage_distance` | 1 |
| `botarramas.idle_wander` | 3 |
| `botarramas.leash` | 14 |
| `botarramas.max_outside` | 4 |
| `botarramas.contact_cooldown` | 3.0 (s) |
| Stats | Fórmula de `unico` según d (sin cambios) |

### Inputs / outputs
- **Inputs:** fronteras entre chunks de Bosques distintos, puertas y caminos, seed, posición del jugador, `open_bosques`.
- **Outputs:** posiciones y estados de los Botarramas (reposo, intercepción, pasivo, regreso), apertura del menú del borde, marcas en el mapa.

### Casos límite
- **Dos Botarramas detectan a la vez**: intercepta el que llega antes; el otro vuelve a su puesto si el Bosque se abre.
- **Botarramas bloqueado por agua o riscos**: no hay camino hasta el jugador y vuelve a su puesto. Si el jugador toca la frontera, se abre el menú igualmente (no se puede colarse sin máscara).
- **Bosque abierto**: sus Botarramas no interceptan aunque el jugador pase pegado.
- **El riutash llega durante una persecución**: la persecución sigue; el riutash se aplica según el refugio (`tiempo-y-riutash.md`).
- **Contacto mientras está abierto otro diálogo o el mapa**: no puede pasar, porque el mundo está en pausa.
- **El Ofomni de la misión**: no es un Botarramas y no guarda bordes.
- **Cargar una partida**: los Botarramas vuelven a su puesto.

### Criterios de éxito para playtest
Propuestas, a confirmar con el dueño:
- El jugador ve al Botarramas antes del contacto en al menos 4 de cada 5 intercepciones.
- El dueño reconoce el renqueo y el "ave sin plumas" (pregunta directa).
- Al menos una vez el jugador intenta esquivar a un Botarramas, y lo consigue más o menos 1 de cada 3 veces.
- El jugador entiende que un Bosque abierto ya no le corta el paso.

## Propuesta: combate contra grupos (reparep), 0.3.0
> Propuesta de `game-designer` con números **provisionales**. Requiere que el combate pase de 1 contra 1 a 1 contra varios.

### Reglas
- **Grupo**: de 2 a 4 reparep (por seed). Cada uno tiene sus PV.
- **Atacar**: el jugador **elige un objetivo** de entre los reparep vivos. El cursor salta por defecto al de menos PV.
- **Ofrecer Luz u ofrenda** (0.3, ADR 0013): paga y **todo el grupo** se va, sin XP. Si los reparep no guardan un borde, ¿qué se paga? (#128)
- **Ataque conjunto** (una sola acción del grupo por turno):
  - **Daño = max(1, (suma del ATQ de los reparep vivos) − DEF del adoc + aleatorio de −1 a +2)**.
  - La DEF del adoc se resta **una sola vez**, así que el grupo "suma daños", como pidió el dueño.
  - Cada reparep que cae baja mucho el daño del grupo.
  - Un mensaje por turno, por ejemplo "Los reparep atacan juntos: %d de daño" (texto de `narrative-writer`).
- **Defender** reduce a la mitad **todo** el ataque conjunto de ese turno.
- **Huir**: 75%, contra el grupo entero.
- **Ofrenda** (si el grupo guarda un borde): una ofrenda que llegue a N hace que **todo el grupo** se vaya.
- **Victoria**: cuando caen todos. XP = **(2 + d) por reparep** (un grupo de 3 a d = 2 da 12, frente a los 10 de un Único de d = 2). Luz de victoria: +1 por grupo.

### Stats individuales (provisionales)
| Stat | Fórmula | d = 1 | d = 2 | d = 3 |
|---|---|---|---|---|
| PV | 6 + 2·d | 8 | 10 | 12 |
| ATQ | 2 + ⌊d/2⌋ | 2 | 3 | 3 |
| DEF | 1 | 1 | 1 | 1 |

### Referencia (valores medios, a d = 2: cada reparep 10/3/1)
| Adoc | Grupo de 2 | Grupo de 3 | Grupo de 4 |
|---|---|---|---|
| Nivel 1 (30/6/3) | gana (~6 de daño) | gana (~16) | pierde por poco (~32 de 30) |
| Nivel 2 (34/7/3) | gana (~6) | gana (~16) | justo (~32 de 34) |
| Nivel 3 (38/7/4) | gana (~4) | gana (~12) | gana (~27 de 38) |

- Solo, un reparep apenas hace daño (1–2 por turno contra DEF 3–4). Un grupo de 4 pega como un Único de d = 4.
- ~~"Ofrecer Luz" (8 de daño) mata un reparep de un golpe.~~ Desde la 0.3, Ofrecer Luz ya no hace daño (ADR 0013). Contra grupos, la mejor respuesta pasa a ser una DEF alta y concentrar los ataques en un objetivo. Los números de la tabla de arriba son solo con Atacar y no cambian.
- La DEF alta es más valiosa contra grupos que contra Únicos, porque se resta del daño total.

## Inputs / outputs
- **Inputs:** tipo de monstruo, d, Momento al empezar el combate, tamaño del grupo (reparep), acciones del jugador.
- **Outputs:** resultado del combate; si es derrota, game over (fatal) o despertar en la villa (no fatal); XP y Luz.

## Interacción con otros sistemas
- **Combate** (`cruce-y-combate-v1.md`): fórmulas base. El grupo exige selección de objetivo y un ataque conjunto.
- **Tiempo** (`tiempo-y-riutash.md`): `fatal_at` depende del Momento.
- **Misión del Ofomni**: no fatal.
- **Guardado**: game over borra o cierra la partida (decisión técnica de `engine-architect`).
- **Arte** (`pixel-artist`): siluetas de Ofomni (ojo con tentáculos), Aledra (según el glosario), reparep (cangrejos fantasmales) e Iserald.

## Casos límite
- **Combate contra Aledra que empieza de día y se alarga**: sigue siendo no fatal, porque cuenta el Momento del inicio y el reloj está parado.
- **Derrota contra un fatal con la misión del Ofomni activa**: game over; la partida termina.
- **Grupo de reparep al que solo le queda uno**: el ataque conjunto es el de uno solo (casi siempre 1 de daño).
- **Matar al reparep elegido con un ataque que le sobra**: el daño sobrante no pasa a otro.
- **Grupo de 4 contra un adoc de nivel 1**: puede perder, pero los reparep no son fatales (provisional).

## Criterios de éxito para playtest
Propuestas, a confirmar con el dueño:
- El jugador reconoce cada monstruo por su silueta (pregunta: "¿qué era eso?").
- Antes de pelear contra un fatal, el jugador sabe que lo es (si se aprueba el aviso, #127).
- Contra reparep, el jugador elige objetivo y nota que matar uno reduce el daño del grupo.
- El dueño considera que los reparep "son débiles solos pero en grupo suman daños" (pregunta directa).

## Decisiones a confirmar con el dueño
- Botarramas: uno por tramo de frontera de chunk, visión 10, 2/3 de la velocidad del jugador, engage 1 y correa de 14 (#129).
- `fatal_at` por Momento, mirando el Momento del inicio del combate.
- Fórmula del ataque conjunto (suma de ATQ, DEF restada una vez), selección de objetivo y Defender sobre todo el ataque.
- Stats y XP de los reparep.
- Reparep en la 0.3.0, no en la 0.2.0.
- Aviso de "enemigo fatal" antes del combate (propuesta, #127).

## Preguntas abiertas
- Otros monstruos fatales, aviso previo, huir de un fatal, qué pasa tras un game over (#127).
- Dónde y cuándo aparecen Aledra y los reparep en Aventura. ¿Los reparep son Únicos? ¿Guardan bordes, vagan por el Bosque o salen de noche? (#128)
- Iserald en el juego (#103).
- Botarramas: números y nombre definitivo (#129).
- Aspecto y nombres de los Únicos comunes (#119).
