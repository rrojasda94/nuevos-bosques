# Ficha: Mundo 2.0 — movimiento libre, escala de viaje y relleno procedural (0.4)

> Dueño: `game-designer`. **Versión 0.4 "Mundo 2.0"**, PR M1 de [`roadmap-mundo-2.md`](../roadmap-mundo-2.md).
> Fuentes: [ADR 0014](../../decisions/0014-mundo-2-relieve-movimiento-libre-y-mundo-hibrido.md) (aceptado, manda), ADR 0007 (Bosques de 4–16 chunks), ADR 0008 (villas 1 de cada 5), `tiempo-y-riutash.md`, `navegacion.md`, `bosques-y-relacion.md`, `monstruos.md`, `sigilo-y-robo.md`, `mision-ofomni.md`.
> **Valores PROVISIONALES.** Esta ficha **no edita `data/`**: dice qué claves cambiarían y con qué valor. `data/world/movement.json` lo crea el PR M11 con los valores del ADR; los demás cambios entran en los PR de cada sistema (M5–M8, M11, M14, M15).
> Implementación: `engine-architect` (M11 movimiento), `world-gen-dev` (M5–M8 región, puntos de interés, refugios), `rpg-systems-dev` (M14–M15 interacción y monstruos).

## Objetivo
Que moverse por el Valle del Sara sea **fluido y legible** (8 direcciones, sin parpadeos) sin perder la presión de la 0.3: el riutash sigue obligando a planificar, los refugios siguen al alcance del aviso y los Únicos siguen pudiendo alcanzarte. Los chunks son más grandes (80×80), así que hay que comprobar que los tiempos de viaje no rompan el ritmo de 15 minutos.

Palabras del dueño (2026-10-24): "siento el mapa muy plano y la jugabilidad un poco tosca" y "mover con WASD resulta super complicado [en isométrico]... los arboles y los elementos decorativos se ven muy repetitivos. Si, el generador de chunks parpadea y quita la inmersion." Pidió "aumentar un poco el tamaño de los chunks".

## Pilares
- **Pilar 2 (sesiones cortas con progreso visible)**: un Bosque mediano se cruza andando en menos de 1 minuto y un día de Gietos sigue dando para una misión completa.
- **Pilar 3 (legibilidad 8-bit)**: velocidades que avanzan píxeles enteros por fotograma, puntos de interés que se reconocen de un vistazo (una laguna, un árbol hito, una colina con escalera).
- **Pilar 4 (cada partida es distinta, cada región se reconoce)**: la geografía grande y las villas con nombre son fijas; los puntos de interés, los senderos y los refugios cambian con la seed, con pesos por latitud (agreste al norte, llano y ribereño al sur, ADR 0007).

## Presión de supervivencia
- **Añade**:
  - Los chunks son un 25 % más largos: a igual número de chunks, todo queda más lejos en segundos.
  - El relieve obliga a rodear riscos y buscar escaleras: el camino real a un refugio es más largo que la línea recta.
- **Alivia**:
  - El movimiento libre y la ayuda de esquina eliminan los atascos en senderos estrechos.
  - Sin fundidos al cruzar chunks se pierde menos tiempo de reacción ante un aviso de riutash o un Único.
- **Balance buscado**: la presión neta **no cambia** respecto a la 0.3. Ver "Riutash y refugios".

## Reglas

### 1. Velocidades y caja de colisión (`data/world/movement.json`, lo crea M11)
| Parámetro | Valor de arranque (ADR) | Alternativa si hay saltos de píxel | Clave |
|---|---|---|---|
| Andar | **100 px/s** (1,67 px por tick a 60 Hz) | **120 px/s** (2 px por tick exactos) | `walk_speed` |
| Correr | **200 px/s** (3,33 px por tick) | **240 px/s** (4 px por tick) | `run_speed` |
| Ayuda de esquina | **5 px** | Igual | `corner_assist_px` |
| Caja en los pies | **10×6 px**, centrada en x, apoyada en los pies | Igual | `hitbox: [10, 6]` |

- **Por qué se arranca con 100/200**: es la velocidad que el dueño aprobó en la 0.2 ("la velocidad esta bien", ADR 0007; 16 px / 0,16 s). Cambiarla sin probar sería mover dos cosas a la vez.
- **Cuándo pasar a 120/240**: si en la escena de prueba de M11 o en el playtest se nota un temblor al andar en línea recta (patrón 2-2-1 px por fotograma). Lo decide `game-designer` con el dueño; criterio en "Criterios de éxito".
- **Diagonal**: va normalizada (ADR). A 120 px/s son 1,41 px por tick en cada eje, así que en diagonal siempre habrá algo de irregularidad. Se acepta: el ojo la nota menos que en línea recta. No se cuantiza la diagonal.
- **Si se adopta 120/240, se escala todo lo que depende de la velocidad del jugador** para no cambiar el equilibrio de persecución: las velocidades de los monstruos ×1,2 (tabla del §5) y el talismán de pluma pasa de `speed_bonus` 0,3 a **0,25** (150 px/s = 2,5 px por tick, patrón 2-3 regular; con el tope `speed_bonus_max` 0,5 son 180 px/s = 3 px por tick exactos).
- **Ayuda de esquina**: 5 px es la mitad del ancho de la caja. Recomendación para `engine-architect`: limitarla a la mitad de la caja en el eje perpendicular, es decir, **5 px al moverse en vertical** (caja de 10 de ancho) y **3 px al moverse en horizontal** (caja de 6 de alto). Así entrar en un sendero de 2 casillas (32 px, 22 px de holgura) no exige apuntar y no se resbala por las esquinas al chocar de frente con un muro.
- **Correr no cuesta nada** hasta que exista el cansancio (#73, ADR 0007: "puedes cansar al personaje"). Con chunks de 80 se correrá casi siempre; se acepta en la 0.4 y se revisa cuando entre la estamina.
- **Sin cambios respecto al ADR**: sondeo de interacción a 12 px delante de los pies; NPC a ≤ 14 px del sondeo; fotograma de andar cada 8 px y sonido de paso cada 16 px (`pixel-artist` y `audio-designer` pueden pedir otro valor al correr si 25 cambios de fotograma por segundo se ven nerviosos).

### 2. Tiempos de viaje (chunk de 80 tiles = 1.280 px)
Línea recta; "por camino" multiplica por **1,3** (factor de rodeo medido a ojo en el spike: curvas del A\*, escaleras y puentes). En el norte agreste el rodeo puede llegar a 1,5.

| Trayecto | Andar 100 | Correr 200 | Andar 120 | Correr 240 | 0.3 (64 tiles, andar) |
|---|---|---|---|---|---|
| 1 chunk | 12,8 s | 6,4 s | 10,7 s | 5,3 s | 10,2 s |
| Bosque de 4 chunks (2×2), de lado a lado | 25,6 s (33 s por camino) | 12,8 s (17 s) | 21,3 s (28 s) | 10,7 s (14 s) | 20,5 s |
| Bosque de 9 chunks (3×3) | 38,4 s (50 s) | 19,2 s (25 s) | 32 s (42 s) | 16 s (21 s) | 30,7 s |
| Bosque de 16 chunks (4×4) | 51,2 s (67 s) | 25,6 s (33 s) | 42,7 s (55 s) | 21,3 s (28 s) | 41 s |
| Bosque de 16 alargado (2×8), a lo largo | 102 s (133 s) | 51 s (67 s) | 85 s (111 s) | 43 s (55 s) | 82 s |
| Región de norte a sur (16 chunks) | 205 s (4,4 min por camino) | 102 s (2,2 min) | 171 s (3,7 min) | 85 s (1,8 min) | 164 s |

Consecuencias:
- **Un Bosque típico se cruza andando en menos de 1 minuto por camino** (salvo los alargados). Es el tamaño que pide el pilar 2: cabe una decisión de peaje, un fruto y un refugio en una salida corta.
- **Bosques alargados**: un Bosque de 16 chunks en tira se hace largo (más de 2 minutos andando). Recomendación para `world-gen-dev` (M5): que el reparto procedural limite la relación de aspecto del Bosque a **3:1** en su caja (por ejemplo 2×6 sí, 2×8 no). Los Bosques clave pintados por el dueño no tienen límite.
- **Un día de Gietos** (480 s) andando por camino da para unos 29 chunks (36 en la 0.3). Sigue sobrando para la misión del Ofomni (ver §3).
- **Letreros** (`navegacion.md`): la fórmula del tiempo estimado pasa a ser `casillas de camino × 16 / walk_speed`, redondeada hacia arriba a minutos. Es la misma idea; solo cambia que la velocidad sale de `movement.json` y no de `STEP_TIME`.

### 3. Riutash y refugios
**Conclusión: no hace falta cambiar el reloj ni los avisos.** `data/world/time.json` se queda igual (`gietos_seconds` 480, `riumna_seconds` 300, `warning_seconds` [60, 15]). Lo que se fija es una **garantía de distancia a pie** que el generador debe cumplir.

Por qué basta:
- El reparto de refugios de `BosqueMap` (paso 2, `min_spacing` 2 en Manhattan) es un **empaquetado máximo**: todo chunk que no recibe refugio queda a menos de 2, es decir, **a 1 chunk** de uno. `max_distance` 2 es solo la red de seguridad. La densidad real es de 1 refugio cada 2–3 chunks.
- **Peor caso**: estar en el borde lejano de un chunk con el refugio en el borde lejano del chunk vecino, 2 chunks en línea recta (160 casillas, 2.560 px). Con rodeo de 1,4: unos **36 s andando a 100 px/s** (18 s corriendo). En la 0.3 eran 29 s. Cabe en el aviso de 60 s con margen.
- Con rodeo de norte (1,5) y una escalera lejos: unos 38–41 s. Sigue cabiendo.

| Parámetro | Valor 0.3 | Valor Mundo 2.0 | Dónde | Motivo |
|---|---|---|---|---|
| `refuges.per_bosque` | 1 | **1** (sin cambio) | `data/world/regions/valle_del_sara.json` | El reparto general ya cubre los Bosques grandes; un Bosque de 16 chunks recibe 5–7 refugios por el paso 2 |
| `refuges.min_spacing` | 2 | **2** (sin cambio) | ídem | Con 3, la distancia efectiva sube a 2 chunks (hasta 4 chunks de recorrido, ~70 s andando): no cabe en el aviso |
| `refuges.max_distance` | 2 | **2** (sin cambio) | ídem | Red de seguridad |
| `warning_seconds` | [60, 15] | **[60, 15]** (sin cambio) | `data/world/time.json` | Ver arriba |
| `gietos_seconds` / `riumna_seconds` | 480 / 300 | **480 / 300** (sin cambio) | ídem | El ciclo de 13 min sigue cuadrando con sesiones de 15 min |
| `advance_seconds` del Ofomni | 360 | **360** (sin cambio) | `data/quests/primera_mision.json` | A 3 saltos, ir hasta él por camino son unos 2,5 min más peajes; él tarda 18 min en llegar |

**Reglas nuevas de colocación dentro del chunk** (para `world-gen-dev`, M8; no son claves nuevas salvo que él lo prefiera):
- **Garantía de distancia a pie**: desde cualquier casilla transitable de la región, el refugio más cercano está a **≤ 300 casillas por camino** (A\* sobre `blocked[]`, contando escaleras y rampas). Son 48 s andando a 100 px/s y dejan 12 s de margen sobre el aviso. Es criterio de test (`test_region_plan` o el portado de `test_refuges`), con 5 seeds.
- **Refugio visible desde el sendero**: la boca de la cueva o el árbol hueco queda a **≤ 6 casillas** de un sendero o camino y conectado a él.
- **Refugio del chunk de Nujio**: a **≤ 6 casillas del borde del Nujio** (antes ≤ 3 casillas de su centro). Coincide con el radio de "descansar el riutash junto a su Nujio" de `bosques-y-relacion.md`, así que ese refugio siempre sube la relación.
- **Cueva frente a árbol hueco**: la cueva en cara de risco se prefiere (ADR), pero solo si cumple las dos reglas anteriores. Si no, árbol hueco.

**Presión que depende del tiempo dentro del Bosque**: al tardar un 25 % más en cruzar, el jugador que entra sin pagar pasa más tiempo expuesto a los cazadores. Propuesta para mantener la presión de la 0.3:

| Clave (`data/combat/balance.json`) | 0.3 | Mundo 2.0 |
|---|---|---|
| `bosque_hunt.base_seconds` | 90 | **110** |
| `bosque_hunt.min_seconds` | 30 | **35** |
| `bosque_states.enojado.hunt_first_seconds` | 8 | **8** (sin cambio: el Bosque enojado debe reaccionar ya) |
| `patrols.min_hub_distance` | 10 | **12** (casillas; el chunk es más grande y la plaza de la villa también) |
| `otros_adoc.min_hub_distance` | 8 | **10** |
| `ofomni_guard.spawn_view` / `spawn_max_distance` / `confine_distance` | [10, 6] / 14 / 3 | **sin cambio** (la pantalla sigue siendo de 20×11,25 casillas) |

**Frutales** (`valle_del_sara.json`, bloque `fruit`): `per_chunk` [3, 6] **sin cambio** (el chunk tiene 1,56 veces más superficie, pero los árboles son de 2×2 y el Bosque tiene ya más frutales por tener más casillas); `min_spacing` **5 → 6** (casillas Chebyshev entre esquinas noroeste, para que dos frutales de 2×2 no queden pegados).

### 4. Puntos de interés por chunk
**Cuántos** (ADR: 2 o 3; 1 junto a una villa o un Nujio):

| Chunk | Nº de puntos de interés |
|---|---|
| Con villa o con Nujio | **1** (más la villa o el Nujio, que hacen de ancla) |
| Resto | **2** (55 %) o **3** (45 %), por el RNG del chunk |
| Con un lugar del CSV (hito, tarca, lugar) | El lugar cuenta como uno de ellos |

**Tipos y pesos por latitud.** `t` = fila del chunk / (alto de la región − 1): 0 en el borde norte, 1 en el sur. Los pesos se **interpolan linealmente** entre las tres columnas (norte en t = 0, centro en t = 0,5, sur en t = 1), para que no haya un salto visible en una fila concreta.

| Tipo | Huella (celdas gruesas de 4×4) | Norte (t = 0) | Centro (t = 0,5) | Sur (t = 1) | Qué aporta al juego |
|---|---|---|---|---|---|
| `colina` (meseta +1 nivel, árbol hito encima, escalera en la cara sur) | 3×3 | **35** | 20 | 5 | Orientación; vista elevada; cueva-refugio posible en su cara |
| `hito` (árbol de 3×3 en un claro irregular) | 2×2 a 3×3 | **20** | 20 | 15 | Se ve desde lejos; buen ancla de sendero y de letrero |
| `circulo_piedras` (6 rocas de 2×2) | 3×3 | **20** | 15 | 10 | Lugar raro y reconocible; reservado para lugares del lore cuando existan |
| `arboleda` (rodal denso de 2×2 con un hueco dentro) | 3×3 | 15 | 15 | 15 | Escondite natural; candidato a árbol hueco-refugio |
| `laguna` (unión de 3 elipses con orilla de claro) | 3×2 a 4×3 | 5 | 15 | **30** | Barrera de agua que obliga a rodear; claros ribereños del sur (ADR 0007) |
| `pradera` (flores en manchas, sin árboles) | 3×3 a 4×4 | 5 | 15 | **25** | Respiro visual; buen sitio para frutales y para ver Únicos venir |
| **Total** | | 100 | 100 | 100 | |

Reglas:
- **Nunca dos del mismo tipo en un chunk** (ADR: "puntos de interés distintos").
- **No en el centro fijo** (ADR). Además: el centro de cada punto de interés queda a **≥ 12 casillas** del borde del chunk (para que no se corte en la costura) y a **≥ 24 casillas** del centro de otro punto de interés del mismo chunk.
- **Terreno**: ni `colina` ni `laguna` sobre una celda de nivel 3 o de cumbre; `laguna` solo sobre celdas gruesas de un mismo nivel. Si el tipo elegido no cabe, se vuelve a sortear entre los que quedan (como mucho 3 intentos; si no cabe ninguno, el chunk se queda con uno menos).
- **Variedad entre vecinos** (recomendación para `world-gen-dev`): el tipo de cada punto de interés se puede decidir en la pasada de región (es barato: solo hashes), y así se evita que **dos chunks vecinos ortogonales tengan un `hito` o un `circulo_piedras`** a la vez. La posición y el trazado siguen en la pasada de chunk.
- **Clave propuesta** en el JSON de región (estructura de `world-gen-dev`): `points_of_interest: { "count_weights": {"2": 55, "3": 45}, "near_anchor": 1, "border_margin": 12, "min_gap": 24, "weights": { "north": {...}, "center": {...}, "south": {...} } }` con los valores de la tabla.
- **La `laguna` no es una sicabi** (dueño, 2026-10-26: "lagos normales si"):
  - la laguna es un punto de interés del mapa abierto y **sí puede estar en el chunk de una villa o aldea**, como su único punto de interés, o junto a él;
  - las sicabis son raras, tienen entrada escondida y escena interior, y van a ≥ 2 chunks de cualquier villa (`lugares-e-interiores.md`, "Cómo se encuentran en el mundo").

#### Fuentes de los afluentes (dueño, 2026-10-26: "se ven en el juego")
**Para `world-gen-dev`, después de M9.** Valores provisionales.

Cada uno de los **7 afluentes** tiene su fuente **visible** en el sitio donde nace (`docs/design/world/sur-lenfi.md`, §Afluentes del Sara).

- **Qué es**: un punto de interés pequeño, un manantial con rocas y agua que brota.
  - **Huella**: **3×3 casillas**. La casilla central es el agua que brota y es la única que bloquea, como el agua. Las 8 de alrededor son rocas bajas mojadas que se pisan.
  - El río sale por el lado de la casilla de agua que da cuesta abajo, el mismo que pinta `agua.png`.
  - Alrededor, un **claro de 1 celda gruesa (4×4)** sin árboles ni decoración que bloquee, para que se vea de un vistazo (pilar 3).
- **Dónde**:
  - **3ro, 5to y 7mo**: en su lugar `manantial_<n>` de `lugares.csv`, que ya existe.
  - **1ro, 2do, 4to y 6to**: **decidido** (dueño, 2026-10-26): nacen también en un **manantial pisable**, como el 3ro, el 5to y el 7mo, en montaña o colina alta transitable (no en la cumbre). Hacen falta 4 filas nuevas `manantial_1`, `manantial_2`, `manantial_4` y `manantial_6`, que escribe `tools/world/paint_afluentes.py`, igual que las otras.
  - Cuenta como uno de los puntos de interés del chunk (ya es un `PLACE` del CSV, `generation.md` §3) y le llega sendero.
- **Nombre al acercarse**: a **≤ 4 casillas** del borde de la huella sale un rótulo con el nombre del lugar (columna `nombre` de `lugares.csv`) durante 3 s, una vez por visita.
  - Desde ese momento queda marcado en el mapa M.
  - El texto lo fija `narrative-writer` con el dueño. Hoy pone "Nacimiento del 3ro del Sara"; el cambio a "Fuente del 3ro del Sara" va en su propio cambio.
- **Sin mecánica nueva** en la 0.4: no cura, no da Luz ni es refugio.
- **Presión de supervivencia**: **alivia** un poco, porque orienta: río abajo siempre se llega al Sara.
- **Claves propuestas** (estructura de `world-gen-dev`):
  - objeto `SPRING` de 3×3 (`variant` = volteo 0–1; solo bloquea la casilla central);
  - en la región, bloque `springs: { "size": 3, "clearing": 4, "label_radius": 4, "label_seconds": 3 }`;
  - en `lugares.csv`, el tipo `manantial`, que ya existe.

### 5. Monstruos: velocidad y distancia de encuentro
El ADR pasa los monstruos a `GridMover` con `speed_px` = 16 / `step_time` y define el encuentro cuando las cajas están a ≤ `engage_px`.

**Cómo se mide `engage_px`**: la separación entre los bordes de las dos cajas, en Chebyshev (el mayor de los huecos en x y en y; 0 = se tocan). **Valor: `engage_px = engage_distance × 16 − 6`.** Con la caja de 10×6:
- En vertical, `engage_distance` 1 equivale exactamente a hoy (centros a 16 px).
- En horizontal, es un poco más generoso (centros a 20 px en vez de 16), lo que compensa que con movimiento libre el monstruo casi nunca "aterriza" justo en la casilla vecina.
- La fórmula `× 16` sin el −6 que sugiere el ADR daría centros a 22–26 px: los Únicos atraparían desde casi 2 casillas y el jugador no entendería por qué empezó el combate (pilar 3).

| Monstruo (`balance.json`, `monsters`) | `step_time` → `speed_px` (a 100) | `speed_px` si se adopta 120 (×1,2) | `idle_step_time` → `idle_speed_px` | `engage_distance` → `engage_px` |
|---|---|---|---|---|
| `botarramas` | 0,24 → **67** | 80 | 0,6 → **27** | 1 → **10** |
| `ofomni_descarriado` | 0,3 → **53** | 64 | 0,8 → **20** | 2 → **26** |
| `ofomni` | 0,2 → **80** | 96 | 0,8 → **20** | 2 → **26** |
| `reparep` | 0,26 → **62** | 74 | 0,5 → **32** | 1 → **10** |
| `aledra` | 0,22 → **73** | 87 | 0,7 → **23** | 1 → **10** |

- El jugador andando (100) sigue siendo más rápido que todos; el `ofomni` perseguidor (80) es el que más aprieta, como en la 0.3 ("algo más rápido que un Botarramas").
- **Sin cambio** en casillas: `vision_radius`, `leash`, `max_outside`, `idle_wander`, `patrol_wander`, `post_depth`. La visión sigue siendo Chebyshev en casillas (`MonsterSteering`).
- `retreat_cells` (2 o 3) se conserva en casillas: al retroceder, el jugador se desplaza `retreat_cells × 16` px en sentido contrario al monstruo, con su `GridMover` (si choca, se queda donde pare).
- Si `rpg-systems-dev` prefiere no renombrar claves en M15, `speed_px` y `engage_px` pueden calcularse desde las actuales; pero entonces el −6 tiene que vivir en datos (`engage_px_offset: -6` en `monsters`), no en el código.

### 6. Villas procedurales — **DECIDIDO: opción C** (dueño, 2026-10-25)
> Decisión del dueño (2026-10-25): "opción C (aldeas sin nombre con procedural_villa_chance 0,2, nunca junto a una villa con nombre, máximo 2 por área)". `procedural_villa_chance` = 0,2 en el JSON de la región (lo aplica M5).

**Contexto**: en la 0.3, **1 de cada 5 Bosques tiene villa** (ADR 0008, decidido por el dueño), con nombre tentativo de `data/text/nombres_villas.json`. El ADR 0014 pone las villas con nombre en `lugares.csv` y deja las demás a un parámetro de región, `procedural_villa_chance`, **por defecto 0** (solo villas con nombre). Hay que elegir.

| | **A. Solo villas con nombre** (`procedural_villa_chance` 0) | **B. Aldeas sin nombre propio en algunos Bosques** (`procedural_villa_chance` 0,2) | **C. Como B, con límites** (0,2 y nunca junto a una villa con nombre) |
|---|---|---|---|
| Qué hay | Solo las villas del CSV (y la villa natal) | Además, 1 de cada 5 Bosques sin villa del CSV tiene una **aldea**: 2–4 casas de 4×3, plaza (refugio) y su Nujio. Nombre tentativo de la lista, distinto en cada partida | Igual que B, pero una aldea nunca cae en un Bosque vecino de uno con villa con nombre, y como mucho 2 por área |
| Pilar 4 | Cada villa se reconoce de partida a partida | Más variedad; las villas con nombre siguen fijas | Variedad sin que las aldeas "tapen" a las villas con nombre |
| Curación y servicios | Depende de cuántas villas pinte el dueño. Con pocas (6–8 en 192 chunks), curarse y los oficios de la 0.5 (`npcs-y-villas.md`) quedan lejos; solo quedan los refugios y los frutos | Mantiene la densidad de la 0.3 (ADR 0008, #110) | Ídem, más repartida |
| Coste | Ninguno extra | Aldea = villa pequeña: el mismo generador con menos casas. Lista de nombres ya existe | B + una comprobación en `RegionPlan` |
| Riesgo | Que el mundo se sienta vacío entre villas | Que el jugador confunda aldeas con villas importantes | Mínimo |

**Recomendación de `game-designer`: C**, con `procedural_villa_chance` 0,2 (la densidad que eligió el dueño en el ADR 0008) y aldeas más pequeñas que las villas con nombre (2–4 casas frente a 5 o más), siempre con Ildo y Sfida y con como mucho 2 oficiantes de los "probables" de `npcs-y-villas.md`. En el letrero y en el mapa M se distinguen: "Villa <nombre>" frente a "aldea <nombre>" (textos y nombres: `narrative-writer`).

**No está decidido.** Hasta que el dueño responda, M5 trabaja con el valor por defecto del ADR (0) y deja el parámetro preparado. Si elige A, el ADR 0008 ("1 de cada 5 Bosques tiene villa") queda sustituido y hay que anotarlo en un ADR. Preguntas concretas para el dueño:
1. ¿Quieres que existan aldeas que cambian en cada partida, o solo las villas que pintes tú?
2. Si sí: ¿te parece bien 1 de cada 5 Bosques, más pequeñas y sin nombre fijo?
3. ¿Cuántas villas con nombre piensas poner en `lugares.csv` para el Valle del Sara? (Con menos de una por área, recomiendo B o C.)

### 7. Otras decisiones del dueño (solo enlazadas)
Están en "Decisiones del dueño que bloquean" de [`roadmap-mundo-2.md`](../roadmap-mundo-2.md); esta ficha no las decide:
- **Conservar al adoc** (nivel, XP, Luz, inventario, fama) al empezar una partida nueva en el Mundo 2.0, o empezar de cero. Bloquea M17.
- **Riscos rectos** en tramos cortos (como Zelda) o esquinas interiores y diagonales (+1 PR de arte). Bloquea M18. Ver también el riesgo del ADR 0006 ("las terrazas rectas se notan muy falsas").

## Inputs / outputs
- **Inputs:** entrada de movimiento (teclado o mando), `run`, `movement.json`, `blocked[]` del chunk, `RegionPlan` (latitud, Bosques, villas, refugios), datos de monstruos.
- **Outputs:** `world_pos` y `cell_changed(world_cell)` del jugador y de los monstruos, encuentros por `engage_px`, puntos de interés por chunk, refugios colocados, aldeas (si el dueño las acepta).

## Interacción con otros sistemas
- **Tiempo y riutash** (`tiempo-y-riutash.md`): sin cambios de reloj; la garantía de 300 casillas a un refugio es lo que sostiene el aviso de 60 s.
- **Navegación** (`navegacion.md`): tiempo estimado de los letreros con `walk_speed`; refugios a ≤ 6 casillas de un sendero.
- **Bosques y relación** (`bosques-y-relacion.md`): refugio del chunk de Nujio dentro del radio de 6 casillas que sube la relación. Peaje, caducidad y memoria sin cambios.
- **Sigilo** (`sigilo-y-robo.md`): el talismán de pluma suma velocidad a `walk_speed` y `run_speed`; 0,25 si se adopta 120.
- **Monstruos** (`monstruos.md`): `speed_px`, `idle_speed_px` y `engage_px` en datos.
- **Misión del Ofomni** (`mision-ofomni.md`): sin cambios.
- **Villas y NPC** (`npcs-y-villas.md`): depende de la decisión del §6.

## Casos límite
- **Entrada diagonal contra una pared**: se desliza a lo largo de ella a la velocidad de la componente libre (no a la velocidad completa). Es lo esperado.
- **Jugador corriendo con el talismán al tope** (200 × 1,5 = 300 px/s, o 360 con 240): cruza un chunk en 4,3 s (3,6 s). El anillo de precarga de 2 chunks sigue dando más de 8 s.
- **Monstruo que llega a `engage_px` atravesando una esquina en diagonal**: no puede, porque `GridMover` no pasa entre dos casillas bloqueadas en diagonal; el encuentro se comprueba solo con cajas en casillas alcanzables.
- **Monstruo y jugador en niveles distintos, a menos de `engage_px` en planta** (uno arriba del risco, otro al pie): **no hay encuentro**. Propuesta: el encuentro exige que las dos casillas de los pies tengan el mismo `level[]` o estén unidas por una escalera o rampa a ≤ 2 casillas. Si no, se vería un combate "a través" de un risco.
- **Riutash con el jugador en una escalera**: no es refugio; cuenta como expuesto.
- **Chunk sin sitio para ningún punto de interés** (montaña cerrada, mucho agua): se queda con 0 y su ancla es la primera puerta. Debe ser raro (< 5 % de los chunks; criterio de test de `world-gen-dev`).
- **Bosque clave pintado de 2×8**: se acepta aunque supere el 3:1; lo pintó el dueño.
- **Aldea (si se aprueba) en un Bosque muerto**: no puede, los Bosques muertos no tienen Nujio ni villa (como hoy).

## Criterios de éxito para playtest
Propuestas, a confirmar con el dueño:
- **Fluidez**: el dueño mueve al adoc 2 minutos por senderos, riscos y escaleras y dice que ya no se siente "tosco" (pregunta directa). Ningún atasco en la entrada de un sendero de 2 casillas.
- **Saltos de píxel**: en una línea recta de 10 casillas a 100 px/s, el dueño y QA no notan temblor (grabación a 60 fps). Si lo notan, se prueba 120/240 en la misma partida y se elige la que guste más.
- **Riutash**: igual que en la 0.3, el jugador llega a un refugio en al menos 2 de cada 3 riutash tras el aviso de 60 s. Ningún riutash pilla con el refugio más cercano a más de 50 s andando (registro del playtest).
- **Escala**: el dueño considera que un Bosque "se recorre en un rato" y no "se hace eterno" (pregunta directa). Cruzar un Bosque de 9 chunks por camino lleva entre 40 y 70 s andando.
- **Puntos de interés**: en 5 minutos de paseo, el jugador reconoce al menos 3 tipos distintos y es capaz de volver a uno por el recuerdo ("la laguna de antes").
- **Encuentros**: el dueño entiende siempre por qué empezó un combate (pregunta directa tras 3 encuentros); ningún encuentro a través de un risco.
- **Latitud**: en la vista previa de la región (M3), el norte se ve con más colinas y el sur con más lagunas y praderas.

## Feedback del dueño
| Fecha | Feedback | Acción |
|---|---|---|
| 2026-10-23 | "la velocidad esta bien" (prototipo por casillas, 0,16 s por casilla) | Se arranca con la misma velocidad equivalente, 100/200 px/s. |
| 2026-10-24 | "siento el mapa muy plano y la jugabilidad un poco tosca" | Movimiento libre en 8 direcciones con ayuda de esquina (§1); relieve y puntos de interés (§4). |
| 2026-10-24 | "aumentar un poco el tamaño de los chunks" | Chunk de 80 (ADR 0014); tiempos de viaje revisados (§2) sin cambiar el reloj (§3). |
| 2026-10-24 | "se ve muy repetitivo y se nota el patrón utilizado en forma de X y fractal"; "los arboles y los elementos decorativos se ven muy repetitivos" | Puntos de interés distintos por chunk, con pesos por latitud y sin repetir hitos entre vecinos (§4). La variedad de árboles y decoración es de `pixel-artist` (M2). |
| 2026-10-24 | "tener aldeas y lugares bien definidos" | Villas con nombre en el CSV. Aldeas procedurales: opción C, decidida el 2026-10-25 (§6). |
| 2026-10-25 | "tambien deberia tener algunos afluentes el río Sara. Estos bajan de las montañas y colinas que el vale del Sara tiene al oeste las Urd Gumnavis y al este las Gumnada Gumnavis. Pon tres afluentes al este y 4 al oeste. Que respeten un poco el mapa de las subregiones" | 7 afluentes de río estrecho pintados en `agua.png` con `tools/world/paint_afluentes.py`, cada uno nace en una cumbre de las Urd Gumnavis (4, oeste) o de las Gumnada Gumnavis (3, este) y sigue un límite de subregión del mapa a mano. Detalle en `docs/design/world/sur-lenfi.md` §Afluentes del Sara. |
| 2026-10-25 | "pon tres donde aparecen y un pequeño afluente cerca de sur del lugar. todos los afluentes son navegables una vez que salen de la zona montañosa. de sur a norte se llaman \"1ro del Sara\", \"2do del Sara\" y asi sucesivamente a medida que van uniendose al rio Sara" | El 4º del oeste pasa a ser un afluente pequeño en el sur de Cassie. Río estrecho en la montaña y navegable desde que sale de ella. Nombres "1ro del Sara"… "7mo del Sara" de sur a norte, en la tabla de `sur-lenfi.md` y como `lugar` en `lugares.csv`. |
| 2026-10-26 | "Sí, dales un tramo navegable al 6to y al 7mo antes de unirse al Sara." | Tramo final navegable de 30 celdas en el 6to y el 7mo (`navegable_min` en `tools/world/paint_afluentes.py`); el Sara sigue estrecho en esas confluencias. Tabla en `sur-lenfi.md`. |
| 2026-10-26 | Sobre las fuentes de los afluentes: "se ven en el juego." Sobre las sicabis: "Los sicabis tambien pero son lugares muy pequeños quizas podría accederse como a una caverna o edificio, si vas por entre un bosque o montaña, puede haber una entrada especial y al entrar es un sicabi." Y: "solo reuerda que las sicabis son lugares raros de hallar. no puede haber tantos cerca de una villa. lagos normales si." | **Fuentes** visibles, de 3×3 casillas con claro de 4×4 y nombre al acercarse, en los 7 afluentes (§4, "Fuentes de los afluentes"). **Sicabis**: entrada especial (arco de raíces en bosque tupido o grieta en un risco) fuera de los caminos, con escena interior. Como mucho 1 por subregión (probabilidad 0,6), a ≥ 2 chunks de cualquier villa o aldea y a ≥ 4 de otra sicabi (`lugares-e-interiores.md`). Las lagunas sí pueden estar junto a las villas (§4). Para `world-gen-dev` después de M9. |
| _playtest M19_ | | |

## Decisiones a confirmar con el dueño
- ~~**Villas procedurales** (§6)~~: decidido, opción C (2026-10-25).
- Arrancar a 100/200 px/s y pasar a 120/240 solo si se notan saltos de píxel.
- No cambiar el reloj del riutash; sostenerlo con la garantía de ≤ 300 casillas a un refugio.
- Pesos de los puntos de interés por latitud (§4).
- Que no haya encuentro entre niveles distintos sin escalera cerca (casos límite).
- Conservar al adoc y riscos rectos: ver §7.

## Preguntas abiertas
- Cansancio al correr (#73): con chunks de 80 correr es casi obligatorio; la estamina lo equilibrará.
- Navegación por ríos grandes (#74): con lagunas y ríos pintados, ¿barca en la 0.4 o más adelante?
- Bosques que no dejan andar de noche (#75): con el relieve, ¿mesetas que de noche solo se suben por escalera?
- ~~Fuentes de los afluentes que nacen en una cumbre~~: decidido (2026-10-26), manantial pisable para los 7.
- ¿Los Únicos ven a través de los riscos? El ADR deja `level[]` preparado; propuesta para más adelante: no ven a un nivel más alto que el suyo a más de 3 casillas.
