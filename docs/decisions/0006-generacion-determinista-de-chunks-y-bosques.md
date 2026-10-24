# ADR 0006 — Generación determinista de chunks, Bosques y su persistencia

> El nombre del archivo decía "zonas" por historia; se renombró en la pasada `refactor` del ADR 0011. "Zona" pasó a llamarse **Bosque** (iteración 2 del slice, 2026-10-23). La escala es chunk < Bosque < área < región.

## Contexto
ADR 0005 fija que el mapa de Nardaram es fijo, que lo que se genera al entrar usa la seed de la partida y que, dentro de una partida, un lugar visitado sigue igual si vuelves. En Aventura se viaja entre chunks adyacentes. El primer vertical slice (Aventura, "probar los controles") necesita esto funcionando.

La convención del STACK ("toda aleatoriedad por `GameState.rng`") no sirve para los chunks: un RNG compartido hace que un chunk dependa del orden en que se visitaron los anteriores, y entonces volver a un sitio no lo regenera igual.

Iteración 2, tras el primer playtest del dueño (ADR 0007):
- Un Bosque agrupa de 4 a 16 chunks contiguos. El jugador se mueve solo por su Bosque inicial.
- Hay ríos navegables y estrechos.
- La región del MVP es el Valle del Sara: agreste al norte, llana al sur.

Iteración 3, tras el segundo playtest (ADR 0008):
- Los árboles vuelven a bloquear, uno por casilla, con más espacio entre ellos.
- Las terrazas rectas "se notan muy falsas": los riscos pasan a ser afloramientos irregulares, agrupados en las montañas del norte.
- El río principal es continuo de punta a punta y tiene vados.
- Cada Bosque tiene un tipo de árbol y una paleta propios, definidos por su Nujio. El límite entre Bosques se ve por el color de la vegetación.
- Cada Bosque tiene un Nujio (6×6 a 8×8) y, con probabilidad 1/5, una villa. Hay letreros de piedra que señalan hacia la villa.
- Paleta: las combinaciones son ilimitadas, pero los colores son solo los 32 de la `.gpl` (confirmado por el dueño). No hay conflicto con el STACK.

Iteración 4, versión 0.2.0 (plan "Primer encargo"): el dueño pide que no sea fácil perderse y que se sepa volver a la villa, y que haya refugio ante el riutash. Se añaden caminos principales entre villas, letreros hacia la villa natal y refugios (ver "Caminos principales y refugios").

## Decisión

### Identidad y determinismo
- **Identidad de un chunk**: `(seed de partida, chunk_x, chunk_y)`, con coordenadas de chunk dentro de la región ((0, 0) = esquina noroeste).
  - La región (`GameState.region_id`, `data/world/regions/<id>.json`) aporta los **parámetros**.
  - El reparto en Bosques (`BosqueMap`, derivado de la seed) aporta Nujio, villa, letreros y aspecto.
- **Aleatoriedad de generación**: `ChunkGenerator` (`scripts/world/chunk_generator.gd`) no usa `GameState.rng` ni `randi()`/`randf()` globales. Usa:
  - `FastNoiseLite` sembrado con `hash(seed, sal)` y muestreado en **coordenadas de mundo**. Un test comprueba que cada casilla no tallada de un chunk coincide con el terreno base en esa posición del mundo, así que ríos y relieve siguen al cruzar el borde.
  - Un hash por casilla en coordenadas de mundo para los huecos entre árboles.
  - Un `RandomNumberGenerator` local sembrado con `hash(seed, chunk_x, chunk_y)` para las curvas de los senderos y la disposición de la villa.
  - `ChunkGenerator.hash_ints`: hash entero propio, estable entre ejecuciones y plataformas.
- `GameState.rng` sigue siendo el RNG de la simulación (días, combate, eventos).

### Terreno base (capas, en este orden; `ChunkGenerator.Terrain.tile_at`)
1. **Río principal**: un eje `x = centro + meandro(y)`, con el centro sacado de la seed. Recorre la región entera de norte a sur.
   - Cada fila cubre desde el eje de esa fila hasta el de la siguiente (más medio ancho a cada lado), así que filas consecutivas siempre se tocan: **no hay cortes**.
   - El ancho va de `main_width_north` a `main_width_south` casillas.
   - Desde `navigable_from` el río es `RIVER_NAVIGABLE` ("rio_navegable"); antes es `RIVER_NARROW`.
   - **Vados** (`FORD`, transitables): un tramo de `ford_length` filas en una posición aleatoria de cada tramo de `ford_spacing` filas.
2. **Arroyos de montaña**: curvas de nivel (`|ruido| < ancho`), siempre `RIVER_NARROW` ("rio_estrecho").
   - Ancho constante: si se estrechan gradualmente se rompen en charcos.
   - Solo existen al norte de `stream_until` y terminan en seco en esa latitud (al dueño le gustan así).
   - Los ríos bloquean a pie hasta que haya navegación.
3. **Montañas**: `elevación = base(y) + rugosidad(y) · ruido`, interpolando de norte a sur con los valores del JSON.
   - Donde la elevación supera `mountain_level` hay "montaña".
   - Dentro de la montaña, `CLIFF` (bloquea) donde un ruido de crestas (`FRACTAL_RIDGED`) supera `outcrop_threshold`. Salen afloramientos, crestas y bordes rotos; nada de terrazas rectas.
   - En el sur llano no hay riscos (lo comprueba un test).
   - `ROCKY` (pedregal transitable) en las laderas.
4. **Claros ribereños** junto al río principal, al sur de `riverside_clearing_from`.
5. **Árboles** (`TREE`, bloquean, uno por casilla):
   - Masas por ruido (`forest.density`) rellenas al `forest.fill`, con huecos aleatorios por casilla.
   - Pasillos naturales sin árboles (curvas de nivel de otro ruido, `corridor_width`).
   - Árboles sueltos (`scatter`). En el sur salen del 20 al 30 % de casillas con árbol.
   - Fuera de los árboles: `CLEARING` por ruido y `GRASS` en el resto.

### Sobre el terreno base (por chunk)
- **Entradas**: cada borde tiene una entrada en `hash(seed, borde)`, idéntica vista desde los dos chunks.
  - Desde cada entrada se talla un sendero hasta el **hub** del chunk.
  - El sendero atraviesa árboles y riscos y cruza los ríos con `BRIDGE`.
- **Hub** (`ChunkData.hub`): la casilla desde la que se aparece y se mide la accesibilidad. Es el centro del chunk, salvo en el chunk del Nujio, donde queda justo al sur de él.
- **Nujio** (`NUJIO`, bloquea; huella en `ChunkData.nujio_rect`):
  - Va en el **chunk más central** de su Bosque (el más cercano al centroide de sus chunks; confirmado por el dueño).
  - Dentro de ese chunk, en el **centro**, rodeado de un claro, o en el centro de la villa.
  - Mide de 6×6 a 8×8 casillas según la seed.
  - Se dibuja como un sprite con la silueta y la paleta de su Bosque.
- **Villa** (`ChunkData.has_villa`), solo si el Bosque la tiene, en ese mismo chunk central:
  - Un claro amplio y una plaza (`PLAZA`) alrededor del Nujio.
  - De 4 a 7 edificios de 2×2 o 3×2 (`BUILDING`, bloquean) en anillo, con al menos una casilla libre alrededor de cada uno.
- **Letreros de piedra** (`SIGN`, transitables): en cada chunk de un Bosque con villa, salvo el de la villa, hay uno sobre el sendero de la entrada más orientada hacia la villa.
  - Al pisarlo o estar al lado, se emite `EventBus.signpost_read(dirección)` y el HUD dice "hacia la villa, al norte/sureste/...".

### Caminos principales y refugios (0.2.0)
- **Red** (`BosqueMap`, una vez por mapa, determinista por seed):
  - `home_bosque`: el Bosque de `home_chunk` (sin él, el del centro de la región). Coincide con `AdventureRules.home_bosque`.
  - Árbol de expansión (Prim) sobre la adyacencia de Bosques, desde el Bosque natal, con pesos `hash(seed, a, b)`. Además, cada arista de adyacencia fuera del árbol lleva camino con probabilidad `ROAD_EXTRA_PERCENT` = 15 % (ciclos). Lista en `road_edges`.
  - Cada arista Bosque–Bosque se traduce en chunks contiguos con un BFS por la rejilla de chunks desde el chunk de Nujio de uno hasta el del otro, **sin salir de esos dos Bosques**. El orden de vecinos del BFS sale de un hash por chunk, para que las rutas no sean todo eles.
  - `road_sides(coord)`: lados del chunk por los que pasa un camino. Siempre simétricos con el vecino.
  - BFS por la red desde el chunk de Nujio natal: `road_distance(coord)` y `road_home_side(coord)` (lado por el que sigue el camino hacia casa).
  - Un test comprueba con 40 seeds que desde cualquier chunk de Nujio se llega por camino a la villa natal.
- **Tallado** (`ChunkGenerator`): en los lados con camino, en vez del sendero se talla un `ROAD` (tile nuevo, caminable, tierra apisonada clara con rodadas) de **2 casillas de ancho**:
  - `_carve_path` con `width`, `tile`, `wiggle` (0,08 frente a 0,3 del sendero) y `straight` (6 casillas rectas desde la puerta).
  - Cada paso talla un bloque de 2×2 hacia +x/+y, así la puerta ocupa las casillas `gate` y `gate + 1` del borde vistas desde los dos chunks.
  - Puentes (`BRIDGE`) sobre los ríos y respeto de los vados, como el sendero. Un sendero nunca pisa un camino.
  - Los lados sin camino siguen con su sendero `PATH`.
- **Letreros hacia la villa natal** (`ChunkData.home_sign`, `home_direction`, `sign_kind(cell)` → `SignKind.BOSQUE_VILLA` / `HOME_VILLA`):
  - En los chunks de camino con 3 o más lados (cruces) y en los de `x + y` par. La paridad alterna entre chunks contiguos, así que en cualquier camino hay letrero al menos un chunk de cada dos.
  - Van junto al tramo recto del camino que lleva a casa (a 2–5 casillas de la puerta, en el lateral) y señalan el **siguiente tramo hacia casa** (`road_home_side`), no la línea recta: seguir las flechas lleva a la villa natal.
  - `EventBus.signpost_read(direction, kind)`. El HUD dice "Hacia tu villa natal: este" o, en los letreros de siempre, "Hacia la villa de este Bosque: ..." (textos de `data/text/sistema.json`).
  - Desviación de `navegacion.md` ("8 direcciones hacia la villa natal"): la flecha señala el siguiente tramo del camino (4 direcciones), porque la línea recta puede apuntar a un lado sin camino. Pendiente de confirmar por el dueño.
  - Los letreros hacia la villa del Bosque no cambian.
- **Refugios** (`REFUGE`, no bloquea; `ChunkData.is_refuge(cell)`):
  - En los chunks de camino con `road_distance % 5` en {1, 3}: yendo hacia casa hay refugio cada 2 o 3 chunks (40 % de los chunks de camino). En la villa no hace falta: su plaza cuenta como refugio (`AdventureRules.is_villa_rest`, PR del reloj).
  - Uno por chunk, pegado a un `ROAD` y fuera del claro central, prefiriendo ocupar un árbol (árbol hueco). Si toca roca se dibuja como cueva.
  - Al estar junto al camino, siempre se llega a pie desde el hub (test).

### Bosques
- `BosqueMap` (`scripts/world/bosque_map.gd`) reparte el grid de chunks de la región en Bosques de **4 a 16 chunks contiguos**, de forma determinista por seed:
  1. Crecimiento aleatorio desde semillas en orden barajado (objetivo de 6 a 12 chunks).
  2. Los grupos de menos de 4 se fusionan con el vecino más pequeño si caben, o les ceden chunks del borde los vecinos grandes sin dejar de ser contiguos.
  - Verificado con 200 seeds.
- **Rasgos por Bosque**, todos deterministas por seed:
  - `styles[id]` = { `shape`, `leaf`, `trunk`, `ground` }: índices en las tablas de `PlaceholderTileset`.
    - 6 siluetas: copa redonda, conífera, palmera, cactus, espinoso y sauce.
    - 12 pares de color de hoja, 8 troncos y 4 suelos, todos de la paleta de 32.
    - Cada Bosque se asigna después de sus vecinos de id menor, con los que **nunca comparte color de hoja** e intenta no compartir silueta.
  - `has_villa[id]` (1 de cada 5).
  - `nujio_chunk[id]` y `nujio_size[id]`.
- **Área y región** no se modelan como niveles: la región es el JSON y sus áreas son una lista de nombres (`areas`).
- El **Bosque inicial** es el del `start_chunk` de la región. En el slice el jugador solo cruza a chunks de ese Bosque.
  - Al intentar salir, se emite `EventBus.bosque_border_reached(bosque_id)` y el HUD avisa (Luz y Únicos: próximamente). `bosque_id` vale -1 en el límite de la región.
- **El límite se ve por la vegetación**:
  - La escena de exploración dibuja, además del chunk actual, una franja de 12 casillas de cada chunk vecino dentro de la región, y la cámara llega hasta ella.
  - Cada Bosque tiene su propio atlas en el `TileSet` (id de la fuente = id del Bosque).
  - Ya no hay línea naranja.
- **Accesibilidad**: las entradas de chunks vecinos coinciden y cada entrada está unida al hub, así que todo el Bosque inicial se recorre a pie desde el punto de inicio. Lo comprueba un test con flood fill por casillas a través del Bosque entero. Otros tests comprueban que se llega a pie al Nujio y a los edificios de la villa.

### Persistencia y datos
- **Los tiles no se guardan.**
  - `GameState` guarda `seed_value`, `region_id`, `chunk_coord` y `player_cell`.
  - El chunk se regenera (unos 25 ms; al entrar se generan el chunk y sus vecinos).
  - `chunk_coord = (-1, -1)` significa "chunk inicial de la región".
  - El Bosque inicial se deriva de seed + región.
  - Dentro de la sesión hay una caché en memoria en la escena de exploración.
  - `SAVE_VERSION` = 2; las partidas v1 se cargan con valores por defecto.
- **Datos**: `ChunkData` (`scripts/core/data/chunk_data.gd`, `Resource`): un `PackedByteArray` de 64×64 con `ChunkData.Tile`, más `hub`, `nujio_rect` y `has_villa`.
  - Tipos: GRASS, CLEARING, PATH, TREE, ROCKY, CLIFF, RIVER_NARROW, RIVER_NAVIGABLE, BRIDGE, FORD, PLAZA, BUILDING, SIGN, NUJIO, ROAD y REFUGE (0.2.0).
  - Bloquean TREE, CLIFF, los dos ríos, BUILDING y NUJIO.
- **Región del MVP**: `data/world/regions/valle_del_sara.json`. `world_map.json` la marca como `start_region`; `claro_inicial` queda como dato antiguo sin uso.
- **Píxel**: `rendering/2d/snap/snap_2d_transforms_to_pixel=true`, para que el tween entre casillas no deje subpíxeles. El color de fondo es el más oscuro de la paleta.

### Frutales (0.3.0)
- **Tile** `FRUIT_TREE` (valor 16, al final del enum para no mover los índices del atlas). Bloquea como `TREE`. `ChunkData.fruit_trees` guarda sus casillas en el orden de colocación.
- **Qué Bosques**: los que dan fruto según su estado (`bosques-y-relacion.md`: sano y necesita_ayuda). Mientras no haya estados por Bosque, todos los Bosques con Nujio tienen el estado `fruit.bosque_state` de la región (`"sano"`). `ChunkGenerator.bosque_state()` es el punto que cambiará el PR de estados.
- **Parámetros** en el bloque `fruit` de la región: `bosque_state`, `states`, `per_chunk` ([3, 6]) y `min_spacing` (5, Chebyshev).
- **Algoritmo**, el último paso de `generate()` (después de senderos, camino, villa, Nujio, letreros y refugio):
  1. RNG propio sembrado con `hash(seed, x, y, SALT_FRUIT = 31)`; con él se elige cuántos (entre `per_chunk[0]` y `per_chunk[1]`).
  2. Candidatos: casillas `TREE` fuera del borde del chunk y fuera de la plaza de la villa más 2 casillas, con al menos una vecina ortogonal transitable y alcanzable desde el hub (desde ahí se toma el fruto con E).
  3. Dos grupos: primero los que dan a un `CLEARING` o un `PATH` (para que se encuentren), luego el resto. Cada grupo se baraja con Fisher-Yates y el RNG local (nunca `Array.shuffle`, que usa el RNG global).
  4. Se aceptan en orden si están a `min_spacing` o más de los ya elegidos.
- **Garantías**: solo sustituye árboles, así que no cambia por dónde se anda ni pisa la plaza, el camino, los senderos o el agua. Lo comprueba `tests/unit/world/test_fruit_trees.gd` comparando con la misma región sin frutales.
- **Dibujo** (`PlaceholderTileset`): la silueta y los colores del árbol del Bosque, con hasta 4 frutos de 2x2. El color es el primero de rojo, amarillo, naranja, magenta, blanco y azul (con su sombra, todos de la paleta) que contrasta con las dos hojas del Bosque. En las filas 0-1 del atlas el frutal tiene fruto; en las 2-3 (`FRUIT_EMPTY_VARIANT`) solo quedan los rabillos.
- **Estado del jugador**, que no es de generación: los frutales vaciados y los frutos tomados por Bosque en el Momento viven en `GameState` (guardado v10) y los gestiona `FruitRules`. Los tiles se siguen regenerando.

## Consecuencias
- Determinismo y reglas verificados en `tests/unit/world/test_chunk_generator.gd`, `tests/unit/world/test_bosque_map.gd` y `tests/unit/world/test_roads.gd` (caminos, letreros y refugios).
- Los caminos se trazan por chunks; dentro de un chunk el camino puede cruzar un río en diagonal y dejar un puente escalonado. Es aceptable con el placeholder; con el arte final convendrá forzar cruces rectos.
- Los cambios del jugador sobre un chunk (ADR 0005, #54: "tal como lo dejé") no persisten todavía. Cuando existan, se guardarán como **diferencias** por chunk en `GameState.chunk` y se aplicarán sobre el chunk regenerado; no se guardarán los tiles completos.
- Cambiar el algoritmo, las constantes, las sales, los parámetros de región o las tablas de estilo cambia los mundos de las partidas guardadas. Una vez publicado habrá que versionar el generador (`generator_version` en el guardado).
- El determinismo depende de que `FastNoiseLite` dé los mismos valores entre versiones de Godot; actualizar el motor puede cambiar los mundos generados.
- Los senderos a bordes bloqueados (otro Bosque, límite de la región) existen igualmente: son los caminos que se abrirán cuando haya Luz o Únicos.
- La villa es mínima (edificios y plaza); las "estructuras al aire libre" de la villa están por diseñar.
- Los arroyos terminan en seco en la latitud `stream_until`. Es aceptable para el slice; cuando haya hidrología de verdad, que desemboquen en el río principal.
- Las tablas de estilo (`PlaceholderTileset.LEAVES/TRUNKS/GROUNDS`, siluetas) son de placeholder. `pixel-artist` las sustituirá por su spec manteniendo los índices o con migración.
- `data/world/regions/*.json` se lee con `FileAccess`. Al exportar, hay que incluir `data/*.json` en el filtro de recursos del preset (`release-manager`).
- La regla de `world-gen-dev.md` "rng sembrado con `hash(seed, region_id)`" queda sustituida para los chunks por lo descrito aquí.
