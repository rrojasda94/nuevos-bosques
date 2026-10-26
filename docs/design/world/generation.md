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
`ChunkBuilder.build(plan, coord) -> WorldChunk`. Solo lee el `RegionPlan` (inmutable) y devuelve un chunk nuevo: crea su propio `FastNoiseLite` y sus arreglos de trabajo, no usa `randi()` ni `GameState` y no toca la escena, así que se puede construir en cualquier orden y en hilos (`WorkerThreadPool`) con el mismo resultado byte a byte. Hoy (M6) hace los pasos 1 y 2 de la ADR 0014 §5; M7–M8 añaden puntos de interés, senderos, formas grandes y decoración.

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
| Escalera | Columna entera de una cara que cruza una puerta o el enlace de una puerta | `STAIRS` | como la cascada |
| Rampa | Casilla de borde que cruza una puerta o el enlace de una puerta | `RAMP` | máscara del borde |
| Sombra al pie | Casilla sin risco debajo de la base de una cara | `decor` = `SHADOW_FOOT` | — |
| Sombra este | Casilla sin risco al este de un borde este | `decor` = `SHADOW_EAST` | — |

- **Invariante** (ADR 0014 §3): como las caras y los bordes van en la frontera de cada celda gruesa con otro nivel, dos casillas transitables de distinto nivel nunca son vecinas ortogonales salvo por una escalera o una rampa, dentro del chunk y entre chunks.
- **Puertas** (provisional hasta la red de senderos de M7): cada casilla de puerta del plan que cae en una cara se vuelve escalera (la columna entera dentro del chunk) y la que cae en un borde, rampa. Cada chunk abre su propio lado, así que una cara partida por el borde del chunk queda abierta en los dos.
- **Enlace con el hub**: si una puerta no se alcanza desde el hub sin cruzar riscos (el agua no corta: los puentes son de M7), un Dijkstra desde la puerta busca el cruce más barato (casilla 1, agua 4, risco 6). Las caras se cruzan en vertical y solo si caben enteras en el chunk; los bordes, en el eje de su máscara. Lo cruzado se vuelve escalera o rampa, de 2 de ancho si la cara o el borde vecino es igual. Por eso un chunk nunca cambia el relieve de su vecino.
- **Hub** provisional: la casilla transitable más cercana al centro. En M7 pasa al ancla del chunk (villa, Nujio o punto de interés).
- **Límite conocido**: un río que baja por un borde este u oeste (en el Valle del Sara, seed 42, hay 38 pares de celdas gruesas con agua y distinto nivel en horizontal) queda como borde sobre agua; la spec de arte no tiene pieza de "rápido" (§3.5).

### Rendimiento
`godot --headless --path . -s tools/world/bench_chunks.gd -- --builder=world` (50 chunks de las filas del norte, seed 42, el plan fuera de la medición). Medido en M6: mediana 19,5 ms, p95 26,5 ms (objetivo de M9: ≤ 80 ms con todos los pasos).

### Pruebas
`tests/unit/world/test_relief.gd`: el invariante en la región entera de 3 seeds y en las 3 filas del norte de otras 17 (dentro de cada chunk y entre chunks vecinos), puertas unidas al hub, cascadas exactamente donde el agua cruza una cara, caras de 2 filas por nivel, cumbres que bloquean, sombras, determinismo (mismos bytes), orden de construcción y construcción en paralelo.
