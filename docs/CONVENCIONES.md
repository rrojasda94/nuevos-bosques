# Convenciones de nombres y código

Fuente única de verdad para nombrar cosas en Nardaram. Si algo no está aquí, se copia el patrón más cercano que ya exista en el repo y se añade a este archivo.
El proceso (ramas, commits, PR, versiones) está en [`CONTRIBUTING.md`](../CONTRIBUTING.md).

## 1. Idioma
| Qué | Idioma |
|---|---|
| Identificadores de código (clases, funciones, variables, señales, nodos, archivos de código) | **Inglés** |
| Términos propios del mundo (lore) dentro de identificadores | **Español sin tildes ni ñ**, sin traducir (tabla 1.1) |
| Texto que ve el jugador | Español (con tildes) |
| Documentación, ADR, commits, PR, comentarios | Español |
| Archivos de datos y sus ids (`data/**/*.json`) | Claves en inglés; ids de lore en español sin tildes |

### 1.1 Términos de lore en el código
No se traducen: traducirlos rompe la búsqueda y crea sinónimos.

| Término | En código | Ejemplo |
|---|---|---|
| Bosque (con Nujio) | `bosque` | `BosqueMap`, `bosque_id`, `open_bosques` |
| Nuevo Bosque | `nuevo_bosque` | `is_nuevo_bosque` |
| Nujio | `nujio` | `nujio_rect` |
| Luz | `luz` | `luz_changed`, `luz_max` |
| Único | `unico` | `UNICO_TILES`, `unico_for()` |
| Villa | `villa` | `has_villa`, `rested_in_villa` |
| Adoc (y demás oficios) | `adoc`, `dumno`... | `adoc_stats` |
| Riutash | `riutash` | `riutash_passed` |
| Ofrenda | `ofrenda` | `ofrendas` |
| Garelino | `garelino` | `garelino_count` |
| Momento de Gietos / Riumna | `gietos` / `riumna` | `is_riumna` |

Las palabras genéricas van en inglés aunque existan en español: `chunk`, `region`, `area`, `tile`, `battle`, `hp`, `player`. Excepción documentada: `subregion`.

## 2. Archivos y carpetas
| Tipo | Regla | Ejemplo |
|---|---|---|
| Script `.gd` | `snake_case.gd`, igual que su `class_name` en snake | `battle_logic.gd` → `BattleLogic` |
| Escena `.tscn` | Mismo nombre que su script raíz | `battle.tscn` + `battle.gd` |
| Recurso `.tres` | `snake_case.tres` | `adoc_base.tres` |
| Datos `.json` | `snake_case.json`. Catálogos pequeños: un archivo con lista de entradas (`data/items/items.json`); entidades grandes: un archivo por id (`data/world/regions/valle_del_sara.json`) | |
| Test | `tests/unit/<dominio>/test_<archivo>.gd` | `tests/unit/rpg/test_battle_logic.gd` |
| Asset gráfico | `<tipo>_<nombre>[_<variante>].png` | `tileset_bosque_conifera.png`, `sprite_adoc_walk.png` |
| Audio | `<music\|sfx>_<nombre>.ogg`; los SFX cortos pueden ser `.wav` | `sfx_hit.wav`, `music_forest.ogg` |
| ADR | `docs/decisions/NNNN-titulo-en-kebab-case.md` | `0009-cruce-entre-bosques-y-combate-v1.md` |
| Fichas de diseño | `docs/design/mechanics/<nombre-kebab>.md` | `cruce-y-combate-v1.md` |
| Archivos estándar de la raíz | Nombre estándar en mayúsculas | `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md` |

Carpetas de código por dominio: `scripts/<autoload|core|world|rpg|city|ui>/`, y las escenas en el espejo `scenes/<dominio>/`.

## 3. GDScript
| Elemento | Regla | Ejemplo |
|---|---|---|
| Clase (`class_name`) | `PascalCase`, sustantivo | `ChunkBuilder` |
| Función | `snake_case`, verbo | `generate_chunk()`, `apply_damage()` |
| Función o variable privada | Prefijo `_` | `_held`, `_try_step()` |
| Variable | `snake_case`, sustantivo | `player_cell` |
| Booleano | `is_`, `has_`, `can_` | `is_walkable`, `has_villa` |
| Constante | `UPPER_SNAKE_CASE` | `STEP_TIME`, `SAVE_VERSION` |
| Enum | Tipo en `PascalCase`, valores en `UPPER_SNAKE_CASE` | `enum Tile { GRASS, RIVER_NARROW }` |
| Nodo en escena | `PascalCase` | `Player`, `Hud`, `BattleMenu` |
| Grupo | `snake_case` plural | `unicos` |
| Acción del Input Map | `snake_case`, verbo | `move_up`, `new_seed` |
| Texto visible en código | Constante `TEXT_*` o, más adelante, una clave de traducción | `TEXT_VICTORY` |

- Tipado estático siempre (`var hp: int`, `-> void`).
- Un script por escena. La lógica pura (sin nodos) va en clases aparte y testeables (`BattleLogic`, `AdventureRules`).
- Comentarios `##` de documentación en la cabecera de cada clase: qué es y qué no hace.

## 4. Señales (`EventBus`)
- Hechos ya ocurridos: `<sustantivo>_<verbo en participio>`, por ejemplo `battle_ended`, `chunk_entered`, `luz_changed`.
- Peticiones: `<acción>_requested`, por ejemplo `end_day_requested`, `scene_change_requested`.
- Los parámetros llevan tipo. Los ids son `StringName` para catálogos de datos e `int` para ids generados (bosques).
- Todas las señales entre sistemas viven en `EventBus`. Las señales locales de un nodo solo las escucha su padre.

## 5. Datos
- Claves JSON en `snake_case` inglés: `luz_max`, `flee_chance`, `start_chunk`.
- Ids en `snake_case` ASCII: `valle_del_sara`, `lean`, `cassie`.
- Los números de balance no se escriben en el código: van en `data/` (por ejemplo `data/combat/balance.json`).
- El guardado tiene `SAVE_VERSION`. Al cambiar el formato se sube la versión y se escribe la migración en `SaveManager`.

## 6. Escala del mundo y movimiento
`chunk` < `bosque` < `area` < `subregion` < `region` < Sur Lenfi.
- Coordenadas de chunk: `Vector2i` global del mundo (`chunk_coord`).
- Celda dentro del chunk: `cell` (0–79, ADR 0014).
- `world_cell` (`Vector2i`): casilla global de la región, `chunk_coord * 80 + cell`.
- `world_pos` (`Vector2`): posición en píxeles de los **pies** de un personaje.
- `sector`: bloque de 16×16 tiles para dibujar y hacer streaming.
- `macro`: celda gruesa de 4×4 tiles, la del relieve y la autoría.
- Las conversiones viven en `WorldCoords`. No se escriben `* 16`, `* 80` ni `/ 4` sueltos.
- Los chunks son `WorldChunk` (capas de 80×80). `ChunkData` ya no es un chunk: solo guarda la escala vieja (64) con la que `RegionPlan` muestrea `ChunkGenerator.Terrain`; no se usa en código nuevo.
- Prohibido usar `zone`/`zona`: es el nombre antiguo de `bosque` (ADR 0007).

### 6.1 Movimiento
**Movimiento libre en 8 direcciones (ADR 0014), no por casillas.**
- La posición es continua (`world_pos`, `float`) y el dibujo se ajusta al píxel.
- La colisión la resuelve `GridMover` (lógica pura) contra la cuadrícula lógica: una caja de 10×6 px en los pies, movimiento por ejes y ayuda de esquina. No se usa física de Godot para el mundo.
- Las **reglas siguen en casillas**: la casilla lógica de un personaje es la de sus pies, y los sistemas reaccionan a `cell_changed(world_cell)`, nunca a la posición en píxeles. Ejemplos: letreros, refugio, chunk entrado, límite de Bosque, visión de los Únicos.
- Las velocidades van en `data/world/movement.json` (`walk_speed`, `run_speed`, en px/s) y en los datos de cada monstruo (`speed_px`). No van en constantes.
- `facing` tiene 4 direcciones (eje dominante de la entrada) para los sprites y la interacción.
- El jugador es `PlayerController`; los monstruos, `OverworldMonster` con su propio `GridMover`. No hay tweens entre casillas.

## 7. Cuando falla una convención
Si encuentras código que no cumple esto, corrígelo en un PR `refactor` aparte, nunca mezclado con una funcionalidad. Si la convención está mal, se cambia este archivo en el mismo PR y se anota en el ADR 0011.
