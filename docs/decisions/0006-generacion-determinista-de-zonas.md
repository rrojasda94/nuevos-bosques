# ADR 0006 — Generación determinista de zonas (chunks) y su persistencia

## Contexto
ADR 0005 fija que el mapa de Nardaram es fijo, que las zonas se generan al entrar con la seed de la partida y que, dentro de una partida, una zona visitada sigue igual si vuelves. En Aventura se viaja entre chunks adyacentes. El primer vertical slice (Aventura, "probar los controles") necesita esto funcionando.

La convención del STACK ("toda aleatoriedad por `GameState.rng`") no sirve para los chunks: un RNG compartido hace que un chunk dependa del orden en que se visitaron los anteriores, y entonces volver a un sitio no lo regenera igual.

## Decisión
- **Identidad de un chunk**: `(seed de partida, chunk_x, chunk_y)`. Las coordenadas son globales en el mundo; la región (`GameState.region_id`) aporta los **parámetros** (densidad de bosque, agua) pero no entra en el hash. Cuando haya varias regiones, la región de un chunk saldrá de sus coordenadas en el mapa mundial.
- **Aleatoriedad de generación**: `ChunkGenerator` (`scripts/world/chunk_generator.gd`) no usa `GameState.rng` ni `randi()`/`randf()` globales. Usa:
  - `FastNoiseLite` sembrado con `hash(seed, sal)` y muestreado en **coordenadas de mundo**: el terreno (agua, masas de bosque) continúa entre chunks vecinos.
  - Un `RandomNumberGenerator` local sembrado con `hash(seed, chunk_x, chunk_y)` para el detalle (árboles sueltos, curvas de los senderos).
  - `ChunkGenerator.hash_ints`: hash entero propio, estable entre ejecuciones y plataformas.
- **Entradas garantizadas**: cada borde tiene una entrada cuya posición depende de `hash(seed, borde)`, donde el borde se identifica igual desde los dos chunks que lo comparten. Desde cada entrada se talla un sendero hasta el claro central (radio 4). Así todo chunk tiene 4 entradas conectadas con el centro, y las entradas de chunks vecinos coinciden.
- **Al cruzar un borde** el jugador aparece en la misma fila/columna del borde opuesto si esa casilla es transitable. Si no, en la casilla transitable más cercana de ese borde, prefiriendo las accesibles desde el centro (`ChunkData.find_entry`).
- **Persistencia**: los tiles **no se guardan**. `GameState` guarda `seed_value`, `chunk_coord` y `player_cell`, y el chunk se regenera (unos 2 ms). Dentro de la sesión hay una caché en memoria en la escena de exploración. `SAVE_VERSION` pasa a 2; las partidas v1 se cargan con valores por defecto.
- **Datos**: `ChunkData` (`scripts/core/data/chunk_data.gd`, `Resource`): un `PackedByteArray` de 64×64 con `ChunkData.Tile` (hierba, claro, sendero, árbol, agua; árbol y agua bloquean).
- **Píxel**: `rendering/2d/snap/snap_2d_transforms_to_pixel=true`, para que el tween entre casillas no deje subpíxeles.
- `GameState.rng` sigue siendo el RNG de la simulación (días, combate, eventos).

## Consecuencias
- Determinismo verificado en `tests/unit/world/test_chunk_generator.gd` (misma entrada = mismos bytes, independiente del orden de visita; seeds distintas = chunks distintos; entradas accesibles y alineadas entre vecinos).
- Los cambios del jugador sobre una zona (talar, construir, matar un Único) no persisten todavía. Cuando existan (#54), se guardarán como **diferencias** por chunk en `GameState.chunk` y se aplicarán sobre el chunk regenerado; no se guardarán los tiles completos.
- Cambiar el algoritmo, las constantes o las sales de `ChunkGenerator` cambia los mundos de partidas guardadas. Si eso importa una vez publicado, habrá que versionar el generador (`generator_version` en el guardado).
- El determinismo depende de que `FastNoiseLite` dé los mismos valores entre versiones de Godot; actualizar el motor puede cambiar los mundos generados.
- `data/world/regions/*.json` se lee con `FileAccess`. Al exportar, hay que incluir `data/*.json` en el filtro de recursos del preset (`release-manager`).
- La regla de `world-gen-dev.md` "rng sembrado con `hash(seed, region_id)`" queda sustituida para los chunks por lo descrito aquí.
