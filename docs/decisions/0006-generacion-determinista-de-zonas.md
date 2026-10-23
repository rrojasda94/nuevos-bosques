# ADR 0006 — Generación determinista de chunks, Bosques y su persistencia

> El nombre del archivo dice "zonas" por historia. En el código, "zona" pasó a llamarse **Bosque** (iteración 2 del slice, 2026-10-23). La escala es chunk < Bosque < área < región.

## Contexto
ADR 0005 fija que el mapa de Nardaram es fijo, que lo que se genera al entrar usa la seed de la partida y que, dentro de una partida, un lugar visitado sigue igual si vuelves. En Aventura se viaja entre chunks adyacentes. El primer vertical slice (Aventura, "probar los controles") necesita esto funcionando.

La convención del STACK ("toda aleatoriedad por `GameState.rng`") no sirve para los chunks: un RNG compartido hace que un chunk dependa del orden en que se visitaron los anteriores, y entonces volver a un sitio no lo regenera igual.

Iteración 2, tras el primer playtest del dueño:
- Los árboles no bloquean: se camina por el bosque tupido.
- Las barreras son el agua, los riscos y las pendientes pronunciadas.
- Hay ríos navegables y estrechos, continuos entre chunks.
- Un Bosque agrupa de 4 a 16 chunks contiguos. El jugador se mueve solo por su Bosque inicial.
- La región del MVP es el Valle del Sara: agreste al norte, llana al sur.

## Decisión

### Identidad y determinismo
- **Identidad de un chunk**: `(seed de partida, chunk_x, chunk_y)`, con coordenadas de chunk dentro de la región ((0, 0) = esquina noroeste). La región (`GameState.region_id`, `data/world/regions/<id>.json`) aporta los **parámetros**, pero no entra en el hash.
- **Aleatoriedad de generación**: `ChunkGenerator` (`scripts/world/chunk_generator.gd`) no usa `GameState.rng` ni `randi()`/`randf()` globales. Usa:
  - `FastNoiseLite` sembrado con `hash(seed, sal)` y muestreado en **coordenadas de mundo**. Relieve, ríos y bosque continúan entre chunks vecinos; un test comprueba que cada casilla no tallada coincide con el terreno base en esa posición del mundo.
  - Un `RandomNumberGenerator` local sembrado con `hash(seed, chunk_x, chunk_y)` para el detalle (árboles sueltos, curvas de los senderos).
  - `ChunkGenerator.hash_ints`: hash entero propio, estable entre ejecuciones y plataformas.
- `GameState.rng` sigue siendo el RNG de la simulación (días, combate, eventos).

### Terreno (capas, en este orden)
1. **Ríos**: curvas de nivel (`|ruido| < ancho`) de un ruido de baja frecuencia estirado en Y, para que corra de norte a sur. Salen líneas continuas, no charcos.
   - El ancho crece hacia el sur. Desde `navigable_from` el río es `RIVER_NAVIGABLE` ("rio_navegable"); antes es `RIVER_NARROW`.
   - Los arroyos de montaña son una segunda red, siempre `RIVER_NARROW` ("rio_estrecho"), de ancho constante y solo al norte de `stream_until`. Si se estrechan gradualmente se rompen en charcos (lo detectó un test).
   - Los dos tipos bloquean a pie hasta que haya navegación.
2. **Relieve**: `elevación = base(y) + rugosidad(y) · ruido`. Base y rugosidad se interpolan de norte a sur con los valores del JSON de la región.
   - `CLIFF` (bloquea) donde la pendiente supera `steep_gradient` (pendientes pronunciadas, en manchas).
   - También es `CLIFF` el borde superior de una terraza (`terrace_step`) donde la pendiente supera `cliff_gradient`: riscos de 1 casilla.
   - `ROCKY` (transitable) por encima de `rocky_level`.
3. **Vegetación**:
   - `FOREST` (transitable) según `forest_density`.
   - `CLEARING`: claros por ruido, y claros ribereños junto al río al sur de `riverside_clearing_from`.
   - `GRASS` en el resto, con árboles sueltos.
4. **Entradas**: cada borde tiene una entrada cuya posición depende de `hash(seed, borde)`, donde el borde se identifica igual desde los dos chunks que lo comparten. Desde cada entrada se talla un sendero hasta el claro central (radio 4). El sendero atraviesa riscos y cruza los ríos con `BRIDGE`. Todo chunk tiene así 4 entradas conectadas con el centro, y las de chunks vecinos coinciden.

### Bosques
- `BosqueMap` (`scripts/world/bosque_map.gd`) reparte el grid de chunks de la región en Bosques de **4 a 16 chunks contiguos**, de forma determinista por seed:
  1. Crecimiento aleatorio desde semillas en orden barajado (objetivo de 6 a 12 chunks).
  2. Los grupos de menos de 4 se fusionan con el vecino más pequeño si caben, o les ceden chunks del borde los vecinos grandes sin dejar de ser contiguos.
  - Verificado con 200 seeds.
- **Área y región** no se modelan como niveles: la región es el JSON y sus áreas son una lista de nombres (`areas`).
- El **Bosque inicial** es el del `start_chunk` de la región. En el slice el jugador solo cruza a chunks de ese Bosque.
  - Al intentar salir, se emite `EventBus.bosque_border_reached(bosque_id)` y el HUD avisa (Luz y Únicos: próximamente). `bosque_id` vale -1 en el límite de la región.
  - Los bordes bloqueados se marcan con una línea naranja.
- **Accesibilidad**: como las entradas de chunks vecinos coinciden y cada entrada está unida al centro, todo el Bosque inicial se recorre a pie desde el punto de inicio. Lo comprueba un test con flood fill por casillas a través del Bosque entero.

### Persistencia y datos
- **Los tiles no se guardan.**
  - `GameState` guarda `seed_value`, `region_id`, `chunk_coord` y `player_cell`, y el chunk se regenera (unos 2 a 4 ms).
  - `chunk_coord = (-1, -1)` significa "chunk inicial de la región".
  - El Bosque inicial se deriva de seed + región.
  - Dentro de la sesión hay una caché en memoria en la escena de exploración.
  - `SAVE_VERSION` = 2; las partidas v1 se cargan con valores por defecto.
- **Datos**: `ChunkData` (`scripts/core/data/chunk_data.gd`, `Resource`): un `PackedByteArray` de 64×64 con `ChunkData.Tile`. Tipos: GRASS, CLEARING, PATH, FOREST, ROCKY, CLIFF, RIVER_NARROW, RIVER_NAVIGABLE y BRIDGE. Bloquean CLIFF y los dos ríos.
- **Región del MVP**: `data/world/regions/valle_del_sara.json`. `world_map.json` la marca como `start_region`; `claro_inicial` queda como dato antiguo sin uso.
- **Píxel**: `rendering/2d/snap/snap_2d_transforms_to_pixel=true`, para que el tween entre casillas no deje subpíxeles.

## Consecuencias
- Determinismo y reglas verificados en `tests/unit/world/test_chunk_generator.gd` y `tests/unit/world/test_bosque_map.gd`.
- Los cambios del jugador sobre un chunk (ADR 0005, #54: "tal como lo dejé") no persisten todavía. Cuando existan, se guardarán como **diferencias** por chunk en `GameState.chunk` y se aplicarán sobre el chunk regenerado; no se guardarán los tiles completos.
- Cambiar el algoritmo, las constantes, las sales o los parámetros de región cambia los mundos de las partidas guardadas. Una vez publicado habrá que versionar el generador (`generator_version` en el guardado).
- El determinismo depende de que `FastNoiseLite` dé los mismos valores entre versiones de Godot; actualizar el motor puede cambiar los mundos generados.
- Los senderos a bordes bloqueados (otro Bosque, límite de la región) existen igualmente: son los caminos que se abrirán cuando haya Luz o Únicos.
- Los arroyos terminan en seco en la latitud `stream_until`. Es aceptable para el slice; cuando haya hidrología de verdad, que desemboquen en el río principal.
- `data/world/regions/*.json` se lee con `FileAccess`. Al exportar, hay que incluir `data/*.json` en el filtro de recursos del preset (`release-manager`).
- La regla de `world-gen-dev.md` "rng sembrado con `hash(seed, region_id)`" queda sustituida para los chunks por lo descrito aquí.
