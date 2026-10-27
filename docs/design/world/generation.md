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
| Agua | Con `agua.png`: cada celda de agua se desplaza ±1 celda según dos ruidos suaves (frecuencia 0,06) y las celdas que eran vecinas se unen con una L, así que ningún río se corta. Prioridad si dos caen en la misma: vado > río navegable > estrecho > lago > mar. A ≤ 3 celdas de un lugar del CSV (por ejemplo, un manantial) el agua no se mueve, y los lugares que ocupan tierra nunca quedan en el agua; los que solo la nombran (`lugar`, como los rótulos de afluentes, y `manantial`: `RegionPlan.WATER_LABELS`) no la borran. Tampoco se mueve el agua pegada a una cumbre (el nacimiento al pie de Larr o de una cumbre: si cayera en la cumbre, el trozo de al lado quedaría suelto; versión 3). No pisa cumbres. Sin `agua.png`: río principal de la ADR 0006 sobre la rejilla gruesa. Los arroyos siguen en el chunk. |
| Caminos pintados | Puente donde, tras el meandro, el camino pasa sobre agua honda; camino donde no. Un borde de chunk lleva camino pintado si hay camino a los dos lados; la puerta se centra en el tramo más largo. |
| Bosques | `BosqueMap.build_planned` (ver abajo). |
| Villas y aldeas | Villas del CSV (la natal sustituye a `start_chunk`) y aldeas de la opción C. |
| Caminos de la red | Prim desde el Bosque natal + 15 % de ciclos sobre la adyacencia de Bosques (ADR 0006). Una arista cuyos dos Nujios ya unen caminos pintados pesa 0 y no se traza. |
| Puertas | Ver abajo. |
| Refugios | Reparto de la ADR 0006 sin cambios (`per_bosque`, `min_spacing`, `max_distance`). La garantía de ≤ 300 pasos la cierra el `ChunkBuilder` (paso 8). |
| Subregiones | Bloque `subregions` de la región o, si falta, las áreas (ver abajo). |
| Sicabis | Reparto por subregión (ver abajo). |

## Bosques (`BosqueMap.build_planned`)
`build()` y `for_region()` no cambian: el juego actual los sigue usando.
1. Los chunks pintados de cada Bosque clave son fijos. Si son menos de 4, el Bosque crece hasta 4 por chunks libres de alrededor. Su Nujio va en el chunk de su fila del CSV.
2. Cada villa del CSV empieza su propio Bosque (dos villas no comparten Bosque salvo que no quepa), con su Nujio en la villa.
3. El resto crece como siempre (6–12 de objetivo, arreglo de los pequeños a 4–16). Los chunks pintados y los de villa no se ceden, y dos grupos con villa o clave no se fusionan si hay otra opción.
4. Estilos (sin repetir hoja con los vecinos), estados y refugios, como en `build()`. Un Bosque con villa no puede nacer muerto.

## Áreas
Ni los datos (`"areas"` del JSON solo da nombres) ni el código anterior definían un área por geometría. Se usa la definición de la **ADR 0007**: un área es un grupo contiguo de **6 a 12 Bosques**. `BosqueMap._assign_areas` las reparte desde el Bosque natal y luego por id, creciendo en anchura hasta un objetivo por hash; un resto de menos de 6 Bosques se une al área vecina más pequeña (puede pasar de 12 en una región pequeña). En el Valle del Sara (~20 Bosques) salen 2 áreas. Los nombres de área no se asignan aquí (lore).

## Subregiones
Ni `lugares.csv` ni las capas pintadas dicen dónde está cada subregión (pregunta #101). El plan las lee del bloque `subregions` de la región: `[{ id, name, rects: [[x, y, ancho, alto], ...] }]` en chunks; manda el primer rectángulo que contiene el chunk. Los chunks que no cubre ninguno, y toda la región si no hay bloque, usan el **área** de su Bosque (ADR 0007, abajo) como subregión `area_<n>`. Con solo las áreas, el Valle del Sara tendría 2 o 3 "subregiones" y como mucho 2 o 3 sicabis; por eso el bloque.
- **Valle del Sara (provisional, lectura de `world-gen-dev` a confirmar por el dueño, #101)**: 7 subregiones con los límites de los afluentes de `sur-lenfi.md` (7mo Lean–Tossie, 5to Tossie–Ostie, 3ro Ostie–Cassie, 6to Causie–Alss, 4to Alss–Vastie, 2do Vastie–Cassie) y el Sara entre el oeste (columnas 0–5) y el este (6–11). Cassie ocupa el sur a los dos lados. Solo lo usa el reparto de sicabis.
- API: `subregion_of(chunk)`, `subregion_names()`.

## Sicabis (`lugares-e-interiores.md`, "Cómo se encuentran en el mundo")
- Bloque `sicabis` de la región (por defecto `RegionPlan.DEFAULT_SICABIS`, con `subregion_chance` 0: sin bloque no hay sicabis).
- Primero las del CSV (tipo nuevo `sicabi`), que cuentan para el tope de su subregión. Después, en orden de hash (`SALT_SICABI_ORDER`), cada subregión por debajo de `per_subregion_max` tira `subregion_chance` (`SALT_SICABI_ROLL`) y, si sale, toma el chunk de menor hash (`SALT_SICABI_CHUNK`) que cumple `sicabi_chunk_ok`: a ≥ `min_villa_distance_chunks` (Chebyshev) de toda villa o aldea, a ≥ `min_sicabi_distance_chunks` de otra sicabi y fuera de un Bosque muerto. Sin chunk, se queda sin sicabi. Las villas y aldeas ya están puestas: la sicabi es la que se aparta.
- El sitio exacto lo busca el `ChunkBuilder` (paso 7); si no lo encuentra, ese chunk no tiene entrada (en 5 seeds, 17 de 18).
- Medido (plan): seeds 42, 7, 1, 2 y 3 → 5, 3, 4, 3 y 3 sicabis.
- API: `sicabis()` ({ id, chunk, subregion, csv, macro solo si csv }), `sicabi_in_chunk(chunk)`, `sicabi_params()`. No cambia `GENERATOR_VERSION` (usa sus propias sales; el resto del plan no se mueve).

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
`ChunkBuilder.build(plan, coord) -> WorldChunk`. Solo lee el `RegionPlan` (inmutable) y devuelve un chunk nuevo: crea su propio `FastNoiseLite` y sus arreglos de trabajo, no usa `randi()` ni `GameState` y no toca la escena, así que se puede construir en cualquier orden y en hilos (`WorkerThreadPool`) con el mismo resultado byte a byte. Hace los pasos 1 a 7 de la ADR 0014 §5 (M6, M7 y M8). El RNG del chunk es `hash(plan_seed, x, y, 142)`; los pasos de M8 usan RNG propios (`hash(plan_seed, x, y, sal)`), así que no mueven lo anterior. `ChunkBuilder.VERSION` = 4.

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
- **Cuántos** (mundo-2.md §4): 1 con ancla; si no, 2 (55 %) o 3 (45 %). Los lugares del CSV del chunk (`hito`, `tarca`, `lugar`, `manantial`) ocupan su sitio y cuentan (`hito` es un hito; los demás son `PLACE`, con un `LANDMARK` 2×2 en la tarca y una fuente `SPRING` en el manantial).
- **Fuente** (`manantial`, mundo-2.md §4 "Fuentes de los afluentes"; bloque `springs`, por defecto `size` 3 y `clearing` 4): el río sale por el lado de la celda gruesa vecina con agua (`exit`). La huella de 3×3 va dentro de la celda del manantial, pegada a ese lado (si no cabe, la posición sin riscos y de un solo nivel más cercana, a ≤ 4 casillas); la casilla central pasa a `RIVER_NARROW` (bloquea, como el agua) y las otras 8 a `CLEARING` (rocas mojadas que se pisan; las dibuja el objeto). Alrededor, `clearing` casillas de claro reservado (`keep`): sin árboles ni ningún objeto. La huella es `solid` (ni senderos ni reparaciones la pisan) y su celda gruesa, sólida en el A*. El nodo del sendero va en la celda vecina seca del lado contrario al río (si no, de un lado; del mismo nivel si se puede), a 2 casillas de las rocas. `WorldChunk.points` guarda el `PLACE` con `rect` = la huella 3×3.
- **Tipo**: pesos de la ficha interpolados por latitud (`t` = fila / (filas − 1); norte, centro y sur en 0, 0,5 y 1), sin repetir tipo; si no cabe, otro tipo, como mucho 3 intentos por hueco. No se evita aún que dos vecinos tengan hito o círculo a la vez (recomendación de la ficha, queda pendiente).
- **Sitio**: 24 posiciones al azar dentro del interior seguro; centro a ≥ 12 casillas del borde (`border_margin`), a ≥ 12 (Chebyshev) del centro del chunk y a ≥ 24 de otro punto o del Nujio (`min_gap`). Sin agua ni cumbre; colina, laguna, hito y círculo sobre celdas de un mismo nivel; colina y laguna no en el nivel 3.
- **Formas**: colina (3×3, +1 nivel, escalera de 2 en el centro de su cara sur, árbol grande encima; el nodo es el pie de la escalera), hito (3×3, claro irregular y árbol grande 3×3), círculo de piedras (3×3, claro y 6 rocas 2×2 a 4,5 casillas, girado para dejar pasar los senderos), arboleda (3×3 de árboles forzados con un claro de 4×4 en medio), laguna (4×3 o 3×2, unión de 3 elipses con orilla de claro, sin tocar la celda del nodo), pradera (3×3 o 4×4 sin árboles; flores por toda la huella, paso 6).
- Parámetros en el bloque `points_of_interest` de la región (por defecto, los de la ficha).
- Se guardan en `WorldChunk.points` (`kind`, `rect` en casillas, `cell` = casilla del sendero que llega).

### 4. Red de senderos
- **Nodos**: puertas, puntos de interés y ancla (villa o Nujio; si no, el primer punto que no sea colina; si no, la primera puerta). El ancla es el nodo 0 y el hub.
- **Prim** sobre la distancia Manhattan en celdas gruesas. Las aristas que no unen dos nodos de camino (puertas de camino y, si el chunk tiene alguna, el ancla con villa o Nujio) llevan un recargo de 1000: las puertas de camino se unen entre sí antes que con nada, así el camino cruza el chunk entero. **Cambio frente al ADR** ("a mitad de precio"): con medio precio el camino se cortaba en los chunks con 2 puertas de camino lejanas.
- **A\*** (`AStarGrid2D`, sin diagonales, rejilla de 20×20) por arista, del nodo nuevo al del árbol. Coste de paso 1 más: cara de frente +2 y +1 por nivel (escalera), cascada +40, borde +3 (rampa), ir a lo largo de una cara +2 (`_compute_cost`). Peso por celda: agua honda ×5 (puente), vado ×1,5, camino pintado ×0,6, laguna ×8, colina ×6, zona de la villa ×2,5 (casas), arboleda ×1,5; cumbres, Nujio y árboles grandes, sólidos. Lo trazado pasa a ×0,4: los senderos siguientes se juntan con él (Y y ramales, sin X).
- **Enderezado**: el A\* deja escalones en diagonal; cada tramo de hasta 16 pasos se cambia por una L (o una recta) si no cuesta más.
- **Rasterizado**: cada paso grueso es un tramo recto de 4 casillas entre los "carriles" (casillas 1–2 de la celda para sendero, 1–3 para camino). La puerta se une a su carril con un tramo hacia dentro y otro a lo largo del borde. Sendero de 2 (`PATH`) y camino de 3 (`ROAD`); sobre agua, `BRIDGE`; la plaza y el vado no cambian.
- **Relieve**: una casilla de sendero sobre una cara la vuelve escalera (la columna entera, si cabe en el chunk); sobre un borde, rampa. Las cascadas y las cumbres no se tocan.
- **Reparación**: Dijkstra por casillas desde cada puerta y cada nodo hasta lo alcanzado desde el hub (casilla 1, agua 4, risco 6; caras solo en vertical y enteras dentro del chunk). Lo cruzado se vuelve escalera, rampa o puente y queda como sendero.

### 5. Formas grandes
- **Bosque**: rejilla de 2×2 casillas alineada con `world_cell` par. Ruido de baja frecuencia (`forest_frequency` 0,035, en coordenadas de mundo, así que la mancha sigue en el chunk vecino) con el umbral de `forest.density` (0,3 − densidad × 0,45) y +0,25 en el pedregal. Nunca sobre senderos, riscos, agua, claros, la zona del Nujio ni los puntos de interés (salvo la arboleda). Se quitan por cola los árboles con menos de 4 árboles vecinos (de 8) hasta que no queda ninguno: no hay árboles sueltos. Variante con rechazo de repetición (paso 6).
- **Rocas 2×2**: en la misma rejilla, en pedregal o nivel 3, con un 90 ‰ (`rock_permille`) por hash y nunca dos vecinas.
- **Nujio** 4×4 (objeto `NUJIO`) y **casas** 4×3 (`HOUSE`) de la villa: 5 en una villa con nombre y las del plan en una aldea, en corro a 8–12 casillas del Nujio, sin pisar senderos y con 1 casilla entre ellas. Calles y huertos en el paso 7.
- Parámetros en el bloque `chunk_shapes` de la región (por defecto, `ChunkBuilder.DEFAULT_SHAPES`).

### 6. Decoración variada (M8)
- **Árboles 2×2**: el aspecto (4 variantes × volteo = 8) es una función de la posición en la rejilla de árboles del mundo, no de qué celdas tienen árbol, así que casa entre chunks. Rechazo de repetición por clases de paridad (A = x e y pares, B = impares, C = x impar, D = y impar): A por hash; B evita sus 4 diagonales (A); C sus 4 ortogonales (A y B); D sus 4 ortogonales y sus 4 diagonales (C). **Dos vecinos ortogonales nunca repiten** variante y volteo; dos diagonales solo cuando los 8 vecinos de una D ya usan los 8 aspectos (medido: 1,5 ‰ de los pares diagonales).
- **Árboles secos** 2×2: un 12 ‰ de los árboles del bosque, por hash de la posición. **Árbol grande** 3×3 dentro del bosque: con probabilidad 0,3 por chunk, ocupa 4 celdas de la rejilla con árbol. **Árboles jóvenes** 1×1: dardos (90 por chunk) en el borde del bosque.
- **Tocones** (0–3), **troncos caídos** 2×1 (0–2) y **rocas 1×1** (1–4, en el pedregal si se puede): raros y bloquean. Todo objeto pequeño que bloquea pasa la prueba del **punto simple**: sus vecinas ortogonales que se pisan siguen unidas por el anillo de 8 vecinas, así que nunca corta un paso; tampoco va junto a algo interactivo, en un sendero, en la reserva de los nodos ni en un huerto.
- **Hierba**: 4 variantes (A–D) por ruido de baja frecuencia (`grass_frequency` 0,04, en `world_cell`) cortado en sus cuartiles (`grass_cuts`), nunca por hash por casilla. Medido: el 83 % de las parejas de casillas de hierba vecinas tienen la misma variante.
- **Decoración que no bloquea** (capa 2, una pieza por casilla): dardos con el RNG del chunk (`darts` 900) dentro de manchas de ruido (`patch_frequency` 0,09, por encima de `patch_cut`), sin dos piezas vecinas (Poisson); en las praderas, flores por toda la huella. La familia sale del sitio: piedrecitas en el pedregal; helechos, hojarasca, setas y raíces junto a los árboles (sin helechos en cactus y espinoso, sin hojarasca en cactus, sin setas en cactus y palmera; grieta seca en el cactus); flores o matas en lo abierto según otro ruido (`theme_frequency` 0,03), que también da el color de las flores de cada mancha (3 dibujos × 3 colores). Alrededor de cada flor, borde de matas (`flower_border` 0,6). Nunca en senderos, riscos, sombras, objetos ni bajo una casa o el Nujio (su sombra de objeto). En las seeds 42 y 7 salen las 24 piezas del catálogo común (con la grieta del cactus) y el huerto.
- Parámetros en el bloque `chunk_decor` de la región (por defecto, `ChunkBuilder.DEFAULT_DECOR`).

### 7. Villa, letreros, refugio y frutales (M8)
- **Villa y aldea**: casas 4×3 en corro alrededor de la plaza (paso 5); cada casa tiene una **calle** (sendero de 1) desde la casilla bajo su vano hasta la plaza o un sendero (camino libre más corto, ≤ 24 pasos), y el 60 % un **huerto** de 3×2 a un lado (pieza de decoración `HUERTO`, no bloquea). La plaza (`PLAZA`) sigue siendo el refugio de la villa (`AdventureRules.is_villa_rest`).
- **Nujio**: volteo por hash; su chunk lleva el refugio a ≤ 6 casillas de su huella (abajo).
- **Letreros** (misma lógica que la 0.3, `navegacion.md`): hacia la villa o aldea del Bosque en todo chunk del Bosque que no es el suyo (dirección = lado hacia ella), y hacia la villa natal en los chunks de camino (uno de cada dos por paridad de x + y, y los cruces de 3 o más lados; dirección = `road_home_side`). Se buscan por los senderos desde la puerta de ese lado (la más parecida si no la hay; la de casa tiene que ser la del camino) la primera casilla libre junto al sendero (junto al **camino de 3** para el de casa) a 3 pasos o más. Objeto `SIGN` + entrada en `signs` ({cell, kind, direction}).
- **Refugio** (reparto del `RegionPlan` sin cambios): 1) **cueva** 2×2 en la base de una cara (con cara a los dos lados, suelo seco y la casilla de debajo del mismo nivel y alcanzable): la fila de abajo (la boca) pasa a `Cliff.NONE` y se pisa, la de arriba sigue siendo cara; 2) si no, un **árbol 2×2** del bosque pasa a `REFUGE_TREE` (árbol hueco, no bloquea), primero los que dan a un sendero; 3) si no, un árbol hueco nuevo en suelo libre. Siempre a ≤ 6 casillas (Chebyshev) de un sendero, camino o calle, alcanzable y, en un chunk de Nujio, a ≤ 6 de su huella (`mundo-2.md` §3). Medido (seeds 42 y 7): 89 cuevas y 55 árboles huecos; ninguna casilla alcanzable a más de 270 pasos de un refugio o de la plaza de una villa (límite 300).
- **Frutales**: entre `fruit.per_chunk` árboles 2×2 del bosque pasan a `FRUIT_TREE` (clave = esquina noroeste), sin tocar el borde del chunk, con una vecina que se pisa y se alcanza (primero los que dan a un claro o un sendero) y a ≥ `chunk_fruit.min_spacing` = 6 (Chebyshev entre esquinas noroeste; bloque nuevo `chunk_fruit`, porque `fruit.min_spacing` = 5 lo sigue usando el generador viejo). Solo en los Bosques cuyo estado da fruto.
- **Refugio del reparto y puertas** (garantía, paso 8): el chunk mide los pasos desde cada puerta (un BFS por puerta) y elige el refugio (cueva, árbol hueco existente o nuevo, en ese orden de preferencia) al azar entre los que quedan a ≤ `door_reach` − 10 pasos de todas sus puertas; si ninguno lo cumple, el mejor de cada tipo. Las reglas del sendero y del Nujio se mantienen; el árbol hueco sin ellas sigue siendo solo el último recurso.
- **Entrada de sicabi** (chunk de `RegionPlan.sicabi_in_chunk`): objeto `SICABI_GATE` 2×2 en la rejilla de árboles (esquina par), a ≥ 10 casillas del borde, a ≥ `min_road_distance` (Chebyshev) de un camino de 3 y ≥ `min_path_distance` de cualquier sendero o calle. Candidatos: (0) bosque tupido, un árbol 2×2 del bosque que se sustituye (arco de raíces), con un prefiltro por tabla de sumas; (1) risco, 2 columnas de la base de una cara (como la cueva, con cara a los dos lados) cuya meseta tiene nivel ≥ `cliff_min_level`, sin pisar la cueva-refugio (ya está puesta: manda el refugio). Se prueban en orden al azar (la del CSV, por cercanía a su celda), como mucho 60: Dijkstra en la rejilla de árboles (40×40; pisar 1, quitar un árbol 3) desde la celda de debajo de la boca hasta una celda que se pisa entera y tiene sendero alcanzable. Ese **paso libre de 2 casillas** no se pinta: se quitan sus árboles (`WorldChunk.remove_object`) y los que quedarían sueltos, y se reserva (`keep`) para que no lo tape nada. En el bosque, con todo eso quitado, ≥ `forest_ratio` de las casillas a ≤ `forest_radius` tienen que tener árbol. La boca del risco pasa a `Cliff.NONE`. `WorldChunk.sicabi` = { id, cell (boca, casilla izquierda), variant }. No es punto de interés ni lleva sendero, letrero ni marca.
- **Colisión y accesibilidad**: `rebuild_blocked()` al final. `ChunkBuilder.inaccessible(chunk)` lista lo interactivo que no se alcanza desde el hub (letrero, frutal, Nujio y tarca desde una vecina; árbol hueco por sus casillas; cueva y entrada de sicabi por su boca; fuente por sus rocas; casa por su fila de delante); los tests exigen que esté vacío en toda la región.

### 8. Refugios garantizados (≤ 300 pasos)
Antes, la garantía de `mundo-2.md` §3 dependía de la suerte: al poner la tarca de Azhin en (8, 9) la seed 42 dio 312 pasos, y cualquier cambio de `lugares.csv` mueve el plan. Ahora se cumple **por construcción**, chunk a chunk, sin construir los vecinos (se sigue pudiendo construir en cualquier orden y en hilos). Bloque `refuges`: `walk_limit` 300 y `door_reach` 105 (parámetro técnico; entre 95 y 130 salen parecidos refugios extra, 105 dio el mínimo medido).
- Un chunk **de confianza** es uno con refugio del reparto o con villa (cualquiera lo sabe por el plan). Deja **cada casilla de sus puertas a ≤ `door_reach` pasos** (dentro del chunk) de su propio refugio o plaza.
- Todo chunk mide, después de los objetos pequeños (los últimos que bloquean), con dos BFS: los pasos a su refugio o plaza (`own`) y a sus casillas de puerta hacia un vecino de confianza (`via`). Cada casilla que se pisa tiene que cumplir `min(own, via + door_reach + 1) ≤ walk_limit`.
- Si algo falla, pone un **refugio extra** (un árbol 2×2 que pasa a hueco o un árbol hueco nuevo, el más cercano a pie a la casilla peor servida; +40 pasos de recargo si queda a más de 6 de un sendero) y vuelve a medir, hasta 6 veces. Un refugio no bloquea, así que solo acorta caminos.
- Por qué basta: desde una casilla sin refugio cerca se llega a una puerta del vecino de confianza (`via`), se cruza el borde (1 paso) y dentro del vecino hay ≤ `door_reach` hasta su refugio. Cada mitad la comprueba el propio chunk.
- Límite conocido: si la casilla de puerta del vecino estuviera bloqueada (una cascada o una cumbre justo en la puerta), ese paso no existe; las puertas evitan cumbres y agua honda, y el test de 5 seeds lo vigila.
- Medido (5 seeds): peor distancia 200–227 pasos (antes, 270–312 según `lugares.csv`); 72–91 refugios por región frente a 68–77 del reparto (de 4 a 17 extra por seed, 8 de media: chunks sin puerta hacia un vecino de confianza y chunks de Nujio, cuyo refugio tiene que quedar junto al Nujio aunque las puertas queden lejos). Cuesta ~5 ms por chunk (un BFS por puerta en los chunks con refugio y la comprobación).

### Codificación para el dibujo (M12 la lee)
| Capa | Valor |
|---|---|
| `variant` en casillas con risco | Ver la tabla del relieve (fila \| columna << 2; bordes y rampas, la máscara). En las 4 casillas de una `CAVE` se dibuja la pieza de cueva (con labio si la casilla de encima no es cara) en lugar del suelo y del risco. |
| `variant` en hierba sin risco | Variante de hierba 0–3 (A–D). En el resto de suelos, 0. |
| `decor` | 0 nada; 1 `SHADOW_FOOT`; 2 `SHADOW_EAST`; ≥ 3 (`DECOR_PIECE_BASE`) pieza = `decor − 3` (`ChunkBuilder.DecorPiece`): 0–15 fila 0 de `tileset_decoracion.png` (columna = pieza: flores 0–8 = dibujo × 3 + color, matas 9–11, helechos 12–13, hojarasca 14–15), 16–19 su fila 1 (setas, raíces; columna = pieza − 16), 20–23 `tileset_piedras.png` (columna = pieza − 20; 23 = grieta seca), 24–25 piezas propias de la silueta (M18, aún no salen), 26 `HUERTO` (sin arte aún). El volteo de la decoración lo decide el dibujo (hash de la casilla). La sombra de objeto bajo casas y Nujio la deduce el dibujo de `objects`. |

`objects[].variant` por tipo:

| Tipo | `variant` |
|---|---|
| `TREE` | variante 0–3 \| volteo << 2 |
| `FRUIT_TREE` | variante 0–1 \| volteo << 1 |
| `TREE_YOUNG`, `STUMP`, `LOG` | variante 0–1 \| volteo << 1 |
| `TREE_DEAD`, `TREE_BIG`, `REFUGE_TREE`, `NUJIO` | volteo (0–1) |
| `ROCK` | 2×2: 0–2; 1×1 (roca pequeña): 0–1 |
| `HOUSE` | material × 2 + variante (material igual en toda la villa) |
| `CAVE` | 0 con labio (cara de 1 nivel), 1 sin labio |
| `SIGN`, `LANDMARK` | 0 (la dirección del letrero está en `signs`) |
| `SPRING` (3×3) | volteo (bit 0) \| lado por el que sale el río << 1 (0 este, 1 sur, 2 oeste, 3 norte). Solo bloquea la casilla central, que en `ground` es `RIVER_NARROW`; las 8 de alrededor son `CLEARING` y se pisan (rocas mojadas del dibujo) |
| `SICABI_GATE` (2×2) | variante (bit 0: 0 arco de raíces en el bosque, 1 grieta en el risco) \| volteo << 1. Bloquea la fila de arriba (`WorldChunk.OBJECT_MOUTH`) y se pisa la de abajo (la boca). En el risco, la fila de arriba sigue siendo `FACE` y la boca es `Cliff.NONE`: se dibuja como la cueva, con su propia pieza |

`WorldChunk.FORMAT_VERSION` = 3 (`SPRING` y `SICABI_GATE` al final de `ObjectKind`, clave `sicabi` en `to_dict`) y `ChunkBuilder.VERSION` = 4: la caché se invalida sola.

**Arte que falta** (lo pide `pixel-artist`; hoy `WorldPainter` no dibuja estos objetos y no rompe): `SPRING` 3×3 (48×48 px: agua que brota en el centro, rocas bajas mojadas alrededor y la salida del río por cada uno de los 4 lados, con volteo) y `SICABI_GATE` 2×2 en dos variantes (arco de raíces entre árboles, por silueta de Bosque, y grieta en la base de una cara de risco, distinta de la boca de la cueva-refugio).

### Consulta de un rectángulo (`WorldQuery`, combate táctico, ADR 0016)
`WorldQuery.rect(get_chunk: Callable, origin_world_cell: Vector2i, size: Vector2i) -> WorldQuery.Area`: capas fila a fila del rectángulo (`level`, `blocked`, `ground`, `cliff`, `crossing` = `Crossing.NONE/STAIRS/RAMP`, `water` = `Water.NONE/DEEP/FORD/BRIDGE`, `object_kind` = `ObjectKind` o −1, `loaded`) y `at(world_cell) -> Dictionary`. Cruza los bordes de chunk con `WorldCoords`; un chunk que `get_chunk` no da (null) cuenta como bloqueado. Clase pura, sin escena.

### Rendimiento
`godot --headless --path . -s tools/world/bench_chunks.gd -- --builder=world` (50 chunks de las filas del norte, seed 42, el plan fuera de la medición). Medido en M6: mediana 19,5 ms, p95 26,5 ms. Medido en M7 (mismo PC): mediana 32–35 ms, p95 38–67 ms con 50 chunks; con los 192, mediana 33–39 ms. Medido en M8 (mismo PC, 3 pasadas): mediana 37,8–40,6 ms, p95 44–71 ms con 50 chunks; con los 192, mediana 40,4 ms y p95 49 ms. Objetivo de M9: mediana ≤ 80 ms y p95 ≤ 150 ms (el banco dice si se cumple; en la CI, la región entera con `--count=192 --profile`, como aviso).

**Perfil por fases (M9).** `-- --builder=world --count=192 --profile` añade los ms medios por chunk de cada fase de `ChunkBuilder.build` (`ChunkBuilder.profiling`, solo en serie; no cambia la salida). Antes de M9, en el mismo PC: `place_objects` 11,8 ms (el bucle de candidatos del bosque, ~11 ms), `connect` 10,1 ms (una sola inundación desde el hub: en la seed 42 nunca hace falta el Dijkstra), y el resto de fases por debajo de 3,5 ms; total 43 ms. La causa común era leer y escribir las capas del chunk por nombre dentro de los bucles (`chunk.cliff[i]`, `chunk.level[c] = …`): cada acceso pasa por la propiedad de otro objeto. M9 las toma en variables locales (y las devuelve al final si se escriben) en la inundación, los candidatos del bosque, `_fill`, `_paint_variants`, `_paint_shadows`, la cueva-refugio y `_access`, y quita los bucles `range()` de `_grid_neighbours` y el literal de array de `_hollow_new`. La salida es la misma byte a byte (huella md5 de la región entera, seeds 42 y 7; `VERSION` sin cambios). Después, con el PC cargado por otros procesos: mediana 34–39 ms frente a 49–62 ms del código anterior en pasadas alternas, mínimo 25 ms frente a 32–37 ms; perfil: `place_objects` 9,3 ms (ahora casi todo es `add_object`, de `WorldChunk`), `connect` 4,4 ms, el resto ≤ 3,2 ms. El perfil es plano: lo que queda no se arregla con cambios baratos.

**Pregeneración (M9).** Las tareas del anillo inicial son de alta prioridad y solo toman chunks del anillo. Las del segundo plano las lanza `WorldPregen.poll()` cuando termina el anillo, con prioridad baja, para no ocupar los hilos que el motor usa en cada fotograma.

### Pruebas
`tests/unit/world/test_relief.gd`: el invariante en la región entera de 3 seeds y en las 3 filas del norte de otras 17 (dentro de cada chunk y entre chunks vecinos), puertas unidas al hub, cascadas exactamente donde el agua cruza una cara, caras de 2 filas por nivel, cumbres que bloquean, sombras, determinismo (mismos bytes), orden de construcción y construcción en paralelo. Las celdas que cambian colinas y Nujios no se comparan con el plan.

`tests/unit/world/test_chunk_builder.gd` (región entera, 2 seeds): red conexa desde el hub a todas las puertas y puntos de interés (con `blocked`, objetos incluidos), hub a ≥ 4 casillas del centro en ≥ 80 % de los chunks, puertas que se pisan y llevan sendero a los dos lados, ningún objeto sobre un sendero, árboles 2×2 en la rejilla y sin sueltos, rocas, Nujio y casas, puntos de interés distintos y lejos del centro, pesos por latitud, colina con escalera, determinismo y `points` en el formato de la caché. M8: refugio según el reparto (cueva o árbol hueco, a ≤ 6 de un sendero y del Nujio) y ninguna casilla a más de 300 pasos de un refugio; frutales 2×2 separados 6 y alcanzables; todo lo interactivo alcanzable (`inaccessible`); variantes de árbol sin repetir entre vecinos ortogonales (también entre chunks); árboles jóvenes, grandes, secos, tocones, troncos y rocas pequeñas, raros; letreros junto al sendero o camino y apuntando bien; casas de villa sin pegarse ni pisar senderos, con acceso, plaza y huertos; decoración nunca en senderos, sombras ni objetos (≥ 16 piezas distintas); hierba en manchas; ríos sin huecos junto a rótulos y manantiales.

`tests/unit/world/test_places_and_refuges.gd` (región entera, 5 seeds: 42, 7, 1, 2 y 3): 7 fuentes 3×3 por seed con el centro de agua que bloquea, rocas que se pisan y se alcanzan, claro sin objetos, `PLACE` en `points` y sendero a ≤ 3; sicabis del plan (≤ 1 por subregión, ≥ 2 chunks de villas y aldeas, ≥ 4 entre ellas, nunca en un Bosque muerto, 2–6 por región en ≥ 4 seeds, deterministas, 7 subregiones que cubren la región); entradas (solo en chunks del plan, fila de arriba que bloquea, boca alcanzable, ≥ 10 de un camino y ≥ 6 de un sendero, bosque ≥ 70 % o risco de nivel ≥ 2, paso libre de 2 hasta un sendero, ≥ 80 % de las del plan, mismos bytes y misma colisión desde la caché); y ninguna casilla a más de 300 pasos de un refugio (antes en `test_chunk_builder`, con 2 seeds). En `test_chunk_builder`, el refugio del reparto es uno que cumple las reglas y los extra son pocos (< 1/4 del reparto).

`tests/unit/world/test_world_query.gd`: `WorldQuery.rect` cruza bordes, copia las capas y bloquea los chunks que faltan.
