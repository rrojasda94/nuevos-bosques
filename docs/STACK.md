# Stack tecnológico

## Decisión
| Capa | Elección | Motivo |
|---|---|---|
| Motor | **Godot 4.x** (4.5+) | Gratis, sin regalías, 2D de primera, pixel-perfect nativo, TileMapLayer, exporta a Win/Linux/macOS. |
| Lenguaje | **GDScript** | Iteración rápida, integrado en el editor. C# solo si un sistema lo exige por rendimiento. |
| Render | `gl_compatibility` | Máxima compatibilidad con PCs modestos (target indie). |
| Arte | **Aseprite** | Estándar para pixel art; exporta spritesheets + JSON. |
| Paleta | 32 colores fijos (`assets/palettes/palette_nuevos_bosques.gpl`) | Look 8-bit consistente. Nada fuera de paleta. |
| Audio | **FamiStudio** (música chiptune) + **jsfxr / Bfxr** (SFX) | Estética NES, exporta WAV/OGG. |
| Steam | **GodotSteam** (addon GDExtension) | Logros, overlay, cloud saves, Steam Input. |
| Tests | **GUT** (Godot Unit Test) | Tests unitarios de GDScript en headless. |
| Datos | Recursos `.tres` + JSON en `data/`; autoría del mundo en PNG + CSV (ADR 0014) | Edificios, ítems, NPCs y quests como datos, no código. El dueño pinta la geografía sin programar. |
| CI | GitHub Actions + imagen `godot-ci` | Import headless, tests, export de builds. |
| Control de versiones | Git + Git LFS para binarios grandes | `.gitattributes` ya configurado. |

## Resolución y escala
- Viewport base: **320×180** (16:9). Escala entera: ×4 = 1280×720, ×6 = 1920×1080.
- Tile: **16×16 px**. Personajes 16×16 o 16×24.
- Filtro de texturas: `Nearest` (sin suavizado). Stretch mode `viewport`, aspect `keep`.
- Transformaciones 2D ajustadas al píxel (`snap_2d_transforms_to_pixel`, ADR 0006). Cámara con zoom entero.

## Mundo y movimiento (ADR 0014, Mundo 2.0, versión 0.4)
> Rige desde el PR M17 de [`roadmap-mundo-2.md`](design/roadmap-mundo-2.md). Hasta entonces: chunks de 64×64 que se generan al entrar y movimiento por casillas con tween (`PlayerWalker`, ADR 0006).

- **Vista** cenital 3/4 estilo Zelda con relieve en capas: niveles 0–3 sobre una celda gruesa de 4×4 tiles, caras de risco de 2 filas por nivel, escaleras, rampas y cascadas.
- **Escala**: chunk de **80×80 tiles** (unidad lógica: Bosques, peaje, refugios, mapa M, caché) y **sector** de 16×16 tiles (unidad de dibujo y streaming).
- **Movimiento libre en 8 direcciones** con `GridMover`, lógica pura con colisión contra la cuadrícula lógica (`blocked[]`), sin `CharacterBody2D`. Va en `_physics_process` a 60 Hz. Velocidades en `data/world/movement.json` (100 px/s andando y 200 px/s corriendo, equivalentes a las de antes).
- **Mundo híbrido**: autoría por región en `data/world/regions/<id>/` (`altura.png`, `agua.png`, `caminos.png`, `bosques.png` a 1 px = 4×4 tiles, más `lugares.csv`). El relleno es procedural y determinista por `(seed, region_id, authoring_hash, generator_version)`.
- **Pregeneración y caché**: la región se genera al crear la partida (anillo inicial con barra de progreso y el resto en segundo plano) con `WorkerThreadPool`, y se cachea en `user://world_cache/<world_key>/`, comprimida con ZSTD. La caché no va en el guardado ni en Steam Cloud.
- **Streaming**: en memoria, el chunk del jugador y sus 8 vecinos; dibujados, los sectores visibles más un margen. Presupuesto de ≤ 2 ms por fotograma para montar sectores. Sin fundidos entre chunks.
- **Presupuestos**: pasada de región ≤ 1,5 s; chunk ≤ 80 ms (mediana; `tools/world/bench_chunks.gd`); ningún fotograma de más de 20 ms por culpa del mundo.

## Estructura de carpetas
```
scenes/      Escenas .tscn por dominio (main, world, city, rpg, ui)
data/world/  Mapa mundial, regiones y su autoría PNG + CSV (ADR 0003, 0014)
scripts/     GDScript por dominio; autoload/ para singletons
assets/      sprites, tilesets, palettes, audio, fonts
data/        Datos de juego (edificios, ítems, npcs, quests)
tests/       Tests GUT
addons/      GodotSteam, GUT (se instalan, no se commitean si son pesados)
docs/        GDD, arte, decisiones (ADR)
.claude/     Agentes
```

## Convenciones
Nombres y estilo completos en [`CONVENCIONES.md`](CONVENCIONES.md); proceso de ramas, commits y versiones en [`CONTRIBUTING.md`](../CONTRIBUTING.md). Resumen:
- `snake_case` para archivos, funciones y variables; `PascalCase` para clases y nodos.
- Un script por escena; lógica compartida en `scripts/core/`.
- Comunicación entre sistemas por señales vía `EventBus`, nunca referencias directas cruzadas.
- Estado global solo en `GameState`; guardado solo por `SaveManager`.
- Gestión de villa por días (`EventBus.day_ended`, ADR 0002). En Aventura, tiempo real con pausa (ADR 0012): solo el autoload `WorldClock` avanza en `_process` (excepciones del Mundo 2.0, ADR 0014: el movimiento libre en `_physics_process` y el montaje de sectores del streaming, que dependen del fotograma), se detiene con `get_tree().paused` y guarda su estado en `GameState` (`clock_momento`, `clock_elapsed`); el resto reacciona a sus señales (`riutash_warning`, `riutash_passed`, `momento_changed`). Autoloads, en orden: `EventBus` → `GameState` → `WorldClock` → `SaveManager` → `Sfx` (efectos de sonido en el bus `SFX`; escucha a `EventBus`).
- Noche de Riumna: post-proceso de luz de luna (`assets/shaders/moonlight.gdshader`) en la `CanvasLayer` 1; la UI va en la capa 2 o más. Sus colores intermedios son la única excepción a la paleta (ADR 0012).
- Textos visibles de sistema: `Texts.get_text(clave)` lee `data/text/sistema.json`.
- Aleatoriedad de la simulación por `GameState.rng`. La generación de chunks usa ruido y RNG locales derivados de `hash(seed, coordenadas)` (ADR 0006). Nunca `randi()`/`randf()` globales. En los hilos de generación (ADR 0014), cada tarea crea sus propios `FastNoiseLite`, `RandomNumberGenerator` y `AStarGrid2D`, y no toca el árbol de escena.
- Input siempre por acciones del Input Map (`move_up/down/left/right`, `run`, `new_seed`), nunca teclas hardcodeadas. Con el movimiento libre (ADR 0014) se leen con `Input.get_vector`, que vale para teclado y mando.

## Alternativas descartadas
- **Unity**: licencias cambiantes, overkill para 2D pixel.
- **Unreal**: 3D-first, pesado.
- **Love2D / MonoGame**: sin editor, el sistema de ciudad + RPG se vuelve caro de construir.
- **GameMaker**: suscripción para exportar; menos libre que Godot.
