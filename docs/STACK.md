# Stack tecnológico

## Decisión
| Capa | Elección | Motivo |
|---|---|---|
| Motor | **Godot 4.x** (4.5+) | Gratis, sin regalías, 2D de primera, pixel-perfect nativo, TileMapLayer, exporta a Win/Linux/macOS. |
| Lenguaje | **GDScript** | Iteración rápida, integrado en el editor. C# solo si un sistema lo exige por rendimiento. |
| Render | `gl_compatibility` | Máxima compatibilidad con PCs modestos (target indie). |
| Arte | **Aseprite** | Estándar para pixel art; exporta spritesheets + JSON. |
| Paleta | 32 colores fijos (`assets/palettes/nuevos-bosques.gpl`) | Look 8-bit consistente. Nada fuera de paleta. |
| Audio | **FamiStudio** (música chiptune) + **jsfxr / Bfxr** (SFX) | Estética NES, exporta WAV/OGG. |
| Steam | **GodotSteam** (addon GDExtension) | Logros, overlay, cloud saves, Steam Input. |
| Tests | **GUT** (Godot Unit Test) | Tests unitarios de GDScript en headless. |
| Datos | Recursos `.tres` + JSON en `data/` | Edificios, ítems, NPCs y quests como datos, no código. |
| CI | GitHub Actions + imagen `godot-ci` | Import headless, tests, export de builds. |
| Control de versiones | Git + Git LFS para binarios grandes | `.gitattributes` ya configurado. |

## Resolución y escala
- Viewport base: **320×180** (16:9). Escala entera: ×4 = 1280×720, ×6 = 1920×1080.
- Tile: **16×16 px**. Personajes 16×16 o 16×24.
- Filtro de texturas: `Nearest` (sin suavizado). Stretch mode `viewport`, aspect `keep`.

## Estructura de carpetas
```
scenes/      Escenas .tscn por dominio (main, world, city, rpg, ui)
scripts/     GDScript por dominio; autoload/ para singletons
assets/      sprites, tilesets, palettes, audio, fonts
data/        Datos de juego (edificios, ítems, npcs, quests)
tests/       Tests GUT
addons/      GodotSteam, GUT (se instalan, no se commitean si son pesados)
docs/        GDD, arte, decisiones (ADR)
.claude/     Agentes
```

## Convenciones
- `snake_case` para archivos, funciones y variables; `PascalCase` para clases y nodos.
- Un script por escena; lógica compartida en `scripts/core/`.
- Comunicación entre sistemas por señales vía `EventBus`, nunca referencias directas cruzadas.
- Estado global solo en `GameState`; guardado solo por `SaveManager`.
- Tiempo de simulación de ciudad por ticks (`EventBus.tick`), no por `_process`.

## Alternativas descartadas
- **Unity**: licencias cambiantes, overkill para 2D pixel.
- **Unreal**: 3D-first, pesado.
- **Love2D / MonoGame**: sin editor, el sistema de ciudad + RPG se vuelve caro de construir.
- **GameMaker**: suscripción para exportar; menos libre que Godot.
