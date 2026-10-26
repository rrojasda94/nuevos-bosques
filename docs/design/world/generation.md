# Generación del mundo: pasada de región (`RegionPlan`) y pasada de chunk (`ChunkBuilder`)

Dueño: `world-gen-dev`. Decisión: [ADR 0014 §5 y §6](../../decisions/0014-mundo-2-relieve-movimiento-libre-y-mundo-hibrido.md). Villas procedurales: [ficha del Mundo 2.0 §6](../mechanics/mundo-2.md) (opción C, decidida por el dueño el 2026-10-25).
La pasada de chunk (`ChunkBuilder`, M6–M9) solo lee este plan; ver la sección del final.

## Entrada y determinismo
- Entrada: `seed`, `region_id`, el JSON de la región y su autoría (`RegionAuthoring`: PNG + `lugares.csv`).
- `authoring_hash`: SHA-256 (63 bits) de las capas decodificadas y de los lugares. Cambia si se repinta o se mueve algo; no si se vuelve a guardar la misma PNG.
- `plan_seed = hash(seed, region_id, authoring_hash, GENERATOR_VERSION = 3)`. Todo lo procedural del plan (Bosques, aldeas, puertas, meandro) sale de él. El relieve y el río procedurales usan `ChunkGenerator.Terrain` con la seed, como la herramienta de exportación.
- Un solo hilo, sin `randi()` global ni `GameState.rng`. Medido: ~65 ms en el Valle del Sara (objetivo ≤ 1,5 s).
- Inmutable tras `build()`: las consultas devuelven copias; varios `ChunkBuilder` pueden leerlo a la vez.

## Capas (en este orden)
| Paso | Qué hace |
|---|---|
| Altura gruesa | 1 valor por celda gruesa (240×320). Pintado manda (niveles 0–3 y `LEVEL_PEAK` = 4, cumbre). Transparente: `Terrain.elevation` en el centro de la celda (en casillas del generador viejo, igual que la exportación), cuantizada con `-0.1 / 0.32 / 0.62`, y luego una pasada que quita celdas sueltas (solo en lo procedural). |
| Agua | Con `agua.png`: cada celda de agua se desplaza ±1 celda según dos ruidos suaves (frecuencia 0,06) y las celdas que eran vecinas se unen con una L, así que ningún río se corta. Prioridad si dos caen en la misma: vado > río navegable > estrecho > lago > mar. A ≤ 3 celdas de un lugar del CSV (por ejemplo, un manantial) el agua no se mueve y los lugares nunca quedan en el agua. Tampoco se mueve el agua pegada a una cumbre (el nacimiento al pie de Larr o de una cumbre: si cayera en la cumbre, el trozo de al lado quedaría suelto; versión 3). No pisa cumbres. Sin `agua.png`: río principal de la ADR 0006 sobre la rejilla gruesa. Los arroyos siguen en el chunk. |
| Caminos pintados | Puente donde, tras el meandro, el camino pasa sobre agua honda; camino donde no. Un borde de chunk lleva camino pintado si hay camino a los dos lados; la puerta se centra en el tramo más largo. |
| Bosques | `BosqueMap.build_planned` (ver abajo). |
| Villas y aldeas | Villas del CSV (la natal sustituye a `start_chunk`) y aldeas de la opción C. |
| Caminos de la red | Prim desde el Bosque natal + 15 % de ciclos sobre la adyacencia de Bosques (ADR 0006). Una arista cuyos dos Nujios ya unen caminos pintados pesa 0 y no se traza. |
| Puertas | Ver abajo. |
| Refugios | Reparto de la ADR 0006 sin cambios (`per_bosque`, `min_spacing`, `max_distance`). |

## Bosques (`BosqueMap.build_planned`)
`build()` y `for_region()` no cambian: el juego actual los sigue usando.
1. Los chunks pintados de cada Bosque clave son fijos. Si son menos de 4, el Bosque crece hasta 4 por chunks libres de alrededor. Su Nujio va en el chunk de su fila del CSV.
2. Cada villa del CSV empieza su propio Bosque (dos villas no comparten Bosque salvo que no quepa), con su Nujio en la villa.
3. El resto crece como siempre (6–12 de objetivo, arreglo de los pequeños a 4–16). Los chunks pintados y los de villa no se ceden, y dos grupos con villa o clave no se fusionan si hay otra opción.
4. Estilos (sin repetir hoja con los vecinos), estados y refugios, como en `build()`. Un Bosque con villa no puede nacer muerto.

## Áreas
Ni los datos (`"areas"` del JSON solo da nombres) ni el código anterior definían un área por geometría. Se usa la definición de la **ADR 0007**: un área es un grupo contiguo de **6 a 12 Bosques**. `BosqueMap._assign_areas` las reparte desde el Bosque natal y luego por id, creciendo en anchura hasta un objetivo por hash; un resto de menos de 6 Bosques se une al área vecina más pequeña (puede pasar de 12 en una región pequeña). En el Valle del Sara (~20 Bosques) salen 2 áreas. Los nombres de área no se asignan aquí (lore).

## Aldeas (opción C)
- `procedural_villa_chance` = 0,2 en `valle_del_sara.json` (por defecto, 0: sin aldeas).
- Candidatos: Bosques con Nujio (no muertos), sin villa con nombre y que **no son vecinos** de un Bosque con villa con nombre (la natal incluida). En orden de hash, cada uno tiene aldea con probabilidad 0,2, hasta `aldeas.max_per_area` = 2 por área.
- La aldea va en el chunk del Nujio de su Bosque, con 2–4 casas (`aldeas.houses`) y un nombre tentativo de `data/text/nombres_villas.json` que no repite el de ninguna villa del CSV ni de otra aldea.
- Con 5 villas en el CSV, casi todo el valle queda cerca de una villa: salen aldeas en algunas seeds (por ejemplo, 2 con la seed 7 y 0 con la 42). Es lo esperado con la opción C.

## Puertas entre chunks
1. Borde con camino (pintado o de la red): puerta de camino de 3 casillas, donde cruza el camino pintado o por hash.
2. Si no, puerta de sendero de 2 casillas con probabilidad del 70 %.
3. Por cada Bosque, Kruskal sobre sus bordes interiores: las puertas abiertas unen, y los bordes cerrados (en orden de hash) se abren solo si unen dos partes separadas. Todo Bosque se recorre a pie de puerta en puerta.
- Posición por hash del borde, a ≥ 8 casillas de las esquinas, evitando cumbres y agua honda a los dos lados si se puede. Un borde se identifica igual desde los dos chunks, así que la puerta es la misma.

## API para el `ChunkBuilder` (M6+)
`level_at(macro)`, `water_at(macro)`, `road_at(macro)`, `chunk_block(layer, chunk)`, `bosque_at(chunk)`, `bosques` (estilos, estados, Nujio, áreas), `villas()`, `aldeas()`, `villa_in_chunk(chunk)`, `places_in_chunk(chunk)`, `road_sides(chunk)`, `door(chunk, side)` / `doors_of(chunk)`, `has_refuge(chunk)`, `refuge_chunks()`, `home_chunk`, `authoring_hash`, `plan_seed`.

## Pruebas y vista previa
- `tests/unit/world/test_region_plan.gd`: determinismo, 4–16 chunks, Bosques recorribles por puertas, puertas simétricas, villas del CSV, aldeas de la opción C, altura sin celdas sueltas, meandro sin cortes y tiempo (aviso).
- `bash tools/world/preview_region.sh valle_del_sara <seed>` dibuja el plan encima de la autoría (leyenda en [`autoria.md`](autoria.md)).

## Pasada de chunk (`ChunkBuilder`)
`ChunkBuilder.build(plan, coord) -> WorldChunk`. Solo lee el `RegionPlan` (inmutable) y devuelve un chunk nuevo: crea su propio `FastNoiseLite` y sus arreglos de trabajo, no usa `randi()` ni `GameState` y no toca la escena, así que se puede construir en cualquier orden y en hilos (`WorkerThreadPool`) con el mismo resultado byte a byte. Hoy (M7) hace los pasos 1 a 5 de la ADR 0014 §5; M8 añade la decoración, los letreros, el refugio, los frutales y el trazado completo de la villa. El RNG del chunk es `hash(plan_seed, x, y, 142)`.

### 1. Suelo base y pedregal
- Agua de la celda gruesa del plan (río navegable, estrecho, lago, mar, vado) a escala de celda; el resto, hierba.
- Pedregal: ruido propio (`hash(plan_seed, 140)`), muestreado en `world_cell` para que case entre chunks. Una casilla es pedregal si el ruido supera el umbral de su nivel. Parámetros en el bloque `chunk_ground` de la región (por defecto `rocky_frequency` 0,045 y `rocky_by_level` [1, 0,6, 0,3, -0,05]: nunca en el nivel 0, casi todo el nivel 3).

### 2. Relieve
| Pieza | Dónde | `cliff` | `variant` |
|---|---|---|---|
| Nivel | `level[]` = nivel de la celda gruesa (0–3). La cumbre cuenta como 3 | — | — |
| Cara | Al sur de una meseta, en las casillas de **arriba** del nivel de abajo: 2 filas por nivel de caída. Una caída de 3 niveles (6 filas) sigue en la celda gruesa siguiente | `FACE` | fila (0 labio, 1 intermedia, 2 base) \| columna << 2 (0 extremo izq., 1–3 medios A/B/C por hash de la columna, 4 extremo der., 5 suelta) |
| Borde | Casillas de la meseta con un vecino más bajo al norte, este u oeste | `EDGE` | máscara: 1 norte, 2 este, 8 oeste (spec de arte §3.2) |
| Cumbre | Toda la celda gruesa pintada como cumbre: bloquea | `EDGE` | 15 (`EDGE_PEAK`) |
| Cascada | Cara cuya celda gruesa y la de la meseta de encima tienen agua. Bloquea | `WATERFALL` | fila \| columna << 2 (0 izq., 1 medio, 2 der.) |
| Escalera | Columna entera de una cara que cruza una puerta, un sendero o una reparación | `STAIRS` | como la cascada |
| Rampa | Casilla de borde que cruza una puerta, un sendero o una reparación | `RAMP` | máscara del borde |
| Sombra al pie | Casilla sin risco debajo de la base de una cara | `decor` = `SHADOW_FOOT` | — |
| Sombra este | Casilla sin risco al este de un borde este | `decor` = `SHADOW_EAST` | — |

- **Invariante** (ADR 0014 §3): como las caras y los bordes van en la frontera de cada celda gruesa con otro nivel, dos casillas transitables de distinto nivel nunca son vecinas ortogonales salvo por una escalera o una rampa, dentro del chunk y entre chunks.
- **Puertas**: cada casilla de puerta del plan que cae en una cara se vuelve escalera (la columna entera dentro del chunk) y la que cae en un borde, rampa. Cada chunk abre su propio lado, así que una cara partida por el borde del chunk queda abierta en los dos. Una escalera o rampa sobre agua lleva suelo de puente (sigue contando como agua para la cascada de debajo).
- **Interior seguro**: el vecino del sur lee las 3 últimas filas de celdas gruesas del chunk, el del norte la primera y los de los lados 2 columnas. Lo que cambia el nivel (Nujio aplanado, colinas) solo toca las celdas de dentro (columnas 2–17, filas 1–16), así que ningún vecino ve un relieve distinto del suyo.
- **Límite conocido**: un río que baja por un borde este u oeste (en el Valle del Sara, seed 42, hay 38 pares de celdas gruesas con agua y distinto nivel en horizontal) queda como borde sobre agua; la spec de arte no tiene pieza de "rápido" (§3.5).

### 3. Ancla y puntos de interés
- **Ancla**: la villa o aldea del chunk (`villa_in_chunk`) o el Nujio de su Bosque (`nujio_chunk`, si no está muerto). El Nujio (4×4, una celda gruesa) va en la celda de la villa o del lugar `bosque` del CSV; si no hay, al azar a ≥ 12 casillas del centro. Se acerca al interior seguro si hace falta (radio 3 celdas con villa, 1 sin ella) y busca la celda seca más cercana. Su zona (7×7 o 3×3 celdas gruesas) se aplana a su nivel; la villa lleva claro, plaza a 3 casillas del Nujio y casas; el Nujio solo, claro a 4 casillas. El hub es la casilla del carril de la celda de debajo del Nujio.
- **Cuántos** (mundo-2.md §4): 1 con ancla; si no, 2 (55 %) o 3 (45 %). Los lugares del CSV del chunk (`hito`, `tarca`, `lugar`, `manantial`) ocupan su sitio y cuentan (`hito` es un hito; los demás son `PLACE`, con un `LANDMARK` 2×2 en la tarca).
- **Tipo**: pesos de la ficha interpolados por latitud (`t` = fila / (filas − 1); norte, centro y sur en 0, 0,5 y 1), sin repetir tipo; si no cabe, otro tipo, como mucho 3 intentos por hueco. No se evita aún que dos vecinos tengan hito o círculo a la vez (recomendación de la ficha, queda pendiente).
- **Sitio**: 24 posiciones al azar dentro del interior seguro; centro a ≥ 12 casillas del borde (`border_margin`), a ≥ 12 (Chebyshev) del centro del chunk y a ≥ 24 de otro punto o del Nujio (`min_gap`). Sin agua ni cumbre; colina, laguna, hito y círculo sobre celdas de un mismo nivel; colina y laguna no en el nivel 3.
- **Formas**: colina (3×3, +1 nivel, escalera de 2 en el centro de su cara sur, árbol grande encima; el nodo es el pie de la escalera), hito (3×3, claro irregular y árbol grande 3×3), círculo de piedras (3×3, claro y 6 rocas 2×2 a 4,5 casillas, girado para dejar pasar los senderos), arboleda (3×3 de árboles forzados con un claro de 4×4 en medio), laguna (4×3 o 3×2, unión de 3 elipses con orilla de claro, sin tocar la celda del nodo), pradera (3×3 o 4×4 sin árboles; las flores son de M8).
- Parámetros en el bloque `points_of_interest` de la región (por defecto, los de la ficha).
- Se guardan en `WorldChunk.points` (`kind`, `rect` en casillas, `cell` = casilla del sendero que llega). `WorldChunk.FORMAT_VERSION` = 2.

### 4. Red de senderos
- **Nodos**: puertas, puntos de interés y ancla (villa o Nujio; si no, el primer punto que no sea colina; si no, la primera puerta). El ancla es el nodo 0 y el hub.
- **Prim** sobre la distancia Manhattan en celdas gruesas. Las aristas que no unen dos nodos de camino (puertas de camino y, si el chunk tiene alguna, el ancla con villa o Nujio) llevan un recargo de 1000: las puertas de camino se unen entre sí antes que con nada, así el camino cruza el chunk entero. **Cambio frente al ADR** ("a mitad de precio"): con medio precio el camino se cortaba en los chunks con 2 puertas de camino lejanas.
- **A\*** (`AStarGrid2D`, sin diagonales, rejilla de 20×20) por arista, del nodo nuevo al del árbol. Coste de paso 1 más: cara de frente +2 y +1 por nivel (escalera), cascada +40, borde +3 (rampa), ir a lo largo de una cara +2 (`_compute_cost`). Peso por celda: agua honda ×5 (puente), vado ×1,5, camino pintado ×0,6, laguna ×8, colina ×6, zona de la villa ×2,5 (casas), arboleda ×1,5; cumbres, Nujio y árboles grandes, sólidos. Lo trazado pasa a ×0,4: los senderos siguientes se juntan con él (Y y ramales, sin X).
- **Enderezado**: el A\* deja escalones en diagonal; cada tramo de hasta 16 pasos se cambia por una L (o una recta) si no cuesta más.
- **Rasterizado**: cada paso grueso es un tramo recto de 4 casillas entre los "carriles" (casillas 1–2 de la celda para sendero, 1–3 para camino). La puerta se une a su carril con un tramo hacia dentro y otro a lo largo del borde. Sendero de 2 (`PATH`) y camino de 3 (`ROAD`); sobre agua, `BRIDGE`; la plaza y el vado no cambian.
- **Relieve**: una casilla de sendero sobre una cara la vuelve escalera (la columna entera, si cabe en el chunk); sobre un borde, rampa. Las cascadas y las cumbres no se tocan.
- **Reparación**: Dijkstra por casillas desde cada puerta y cada nodo hasta lo alcanzado desde el hub (casilla 1, agua 4, risco 6; caras solo en vertical y enteras dentro del chunk). Lo cruzado se vuelve escalera, rampa o puente y queda como sendero.

### 5. Formas grandes
- **Bosque**: rejilla de 2×2 casillas alineada con `world_cell` par. Ruido de baja frecuencia (`forest_frequency` 0,035, en coordenadas de mundo, así que la mancha sigue en el chunk vecino) con el umbral de `forest.density` (0,3 − densidad × 0,45) y +0,25 en el pedregal. Nunca sobre senderos, riscos, agua, claros, la zona del Nujio ni los puntos de interés (salvo la arboleda). Se quitan por cola los árboles con menos de 4 árboles vecinos (de 8) hasta que no queda ninguno: no hay árboles sueltos. Variante = hash de la posición % 4 (el rechazo de repetición es de M8).
- **Rocas 2×2**: en la misma rejilla, en pedregal o nivel 3, con un 90 ‰ (`rock_permille`) por hash y nunca dos vecinas.
- **Nujio** 4×4 (objeto `NUJIO`) y **casas** 4×3 (`HOUSE`) de la villa: 5 en una villa con nombre y las del plan en una aldea, en corro a 8–12 casillas del Nujio, sin pisar senderos y con 1 casilla entre ellas. Es solo la huella; el trazado de la villa (calles, oficios) es de M8.
- Parámetros en el bloque `chunk_shapes` de la región (por defecto, `ChunkBuilder.DEFAULT_SHAPES`).
- **Para más adelante** (combate táctico, ADR 0016): lo que necesita una consulta de un rectángulo de `world_cell` (nivel, bloqueado, escalera o rampa, agua o vado, objeto) está en las capas del `WorldChunk`; la consulta pura irá aparte, sin cambiar el generador.

### Rendimiento
`godot --headless --path . -s tools/world/bench_chunks.gd -- --builder=world` (50 chunks de las filas del norte, seed 42, el plan fuera de la medición). Medido en M6: mediana 19,5 ms, p95 26,5 ms. Medido en M7 (mismo PC): mediana 32–35 ms, p95 38–67 ms con 50 chunks; con los 192, mediana 33–39 ms. Objetivo de M9: ≤ 80 ms de mediana.

### Pruebas
`tests/unit/world/test_relief.gd`: el invariante en la región entera de 3 seeds y en las 3 filas del norte de otras 17 (dentro de cada chunk y entre chunks vecinos), puertas unidas al hub, cascadas exactamente donde el agua cruza una cara, caras de 2 filas por nivel, cumbres que bloquean, sombras, determinismo (mismos bytes), orden de construcción y construcción en paralelo. Las celdas que cambian colinas y Nujios no se comparan con el plan.

`tests/unit/world/test_chunk_builder.gd` (región entera, 2 seeds): red conexa desde el hub a todas las puertas y puntos de interés (con `blocked`, objetos incluidos), hub a ≥ 4 casillas del centro en ≥ 80 % de los chunks, puertas que se pisan y llevan sendero a los dos lados, ningún objeto sobre un sendero, árboles 2×2 en la rejilla y sin sueltos, rocas, Nujio y casas, puntos de interés distintos y lejos del centro, pesos por latitud, colina con escalera, determinismo y `points` en el formato de la caché.
