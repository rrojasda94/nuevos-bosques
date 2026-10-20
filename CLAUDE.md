# Nuevos Bosques — Router de agentes

Este archivo NO contiene reglas de implementación. Solo sirve para decidir qué agente desplegar.
Cada agente vive en `.claude/agents/<nombre>.md` y es la única fuente de verdad de su área.

## Proyecto en una línea
RPG + gestión de ciudad, indie, pixel art 8-bit, PC (Windows/Linux/macOS), publicación en Steam.
Motor: Godot 4.x (GDScript). Ver `docs/STACK.md`.

## Tabla de enrutamiento

| Si la tarea trata de… | Despliega |
|---|---|
| Diseño de mecánicas, balance, loops de juego, GDD, economía del juego | `game-designer` |
| Historia, lore, personajes, diálogos, misiones (texto), tono | `narrative-writer` |
| Arquitectura Godot, escenas, autoloads, guardado, input, rendimiento, estructura de carpetas | `engine-architect` |
| Personajes jugables, stats, combate, inventario, equipo, progresión, quests (lógica) | `rpg-systems-dev` |
| Edificios, recursos, producción, ciudadanos, simulación por ticks, colocación en grid | `city-systems-dev` |
| Sprites, tilesets, paleta, animaciones, specs de arte, Aseprite | `pixel-artist` |
| HUD, menús, paneles, tema de UI, fuentes, accesibilidad | `ui-ux-dev` |
| Música chiptune, SFX, integración de audio | `audio-designer` |
| Tests (GUT), QA, reproducción de bugs, checklist de playtest | `qa-tester` |
| Steamworks, builds, export presets, CI/CD, página de Steam, logros, versiones | `release-manager` |

## Reglas de enrutamiento
1. Una tarea que cruza áreas se divide: primero `engine-architect` si toca estructura, luego el agente de dominio.
2. Cualquier cambio de mecánica pasa por `game-designer` antes de implementarse (actualiza `docs/design/`).
3. Nunca implementar arte o audio final sin spec previa del agente correspondiente.
4. Decisiones técnicas o de diseño que afecten a más de un agente se registran en `docs/decisions/` (ADR).
5. Si no está claro qué agente aplica, usar `engine-architect` para triaje.

## Lectura mínima antes de cualquier tarea
- `docs/STACK.md` — stack y convenciones.
- `docs/design/GDD.md` — visión del juego.
- El `.md` del agente correspondiente.
