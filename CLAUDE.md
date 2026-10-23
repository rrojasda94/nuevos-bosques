# Nardaram: Los Nuevos Bosques — Router de agentes

Este archivo NO contiene reglas de implementación. Solo sirve para decidir qué agente desplegar.
Cada agente vive en `.claude/agents/<nombre>.md` y es la única fuente de verdad de su área.

## Proyecto en una línea
RPG por turnos (menú) + gestión de ciudad por días, supervivencia, top-down, pixel art 8-bit, solo español. PC (Windows/Linux/macOS), publicación en Steam.
Mundo: mapa mundial diseñado a mano; cada partida ocurre en un chunk procedural generado con seed (ADR 0003).
Motor: Godot 4.x (GDScript). Ver `docs/STACK.md`.

## Tabla de enrutamiento

| Si la tarea trata de… | Despliega |
|---|---|
| Diseño de mecánicas, balance, loops de juego, GDD, economía del juego | `game-designer` |
| Historia, lore, personajes, diálogos, misiones (texto), tono | `narrative-writer` |
| Arquitectura Godot, escenas, autoloads, guardado, input, rendimiento, estructura de carpetas | `engine-architect` |
| Personajes jugables, stats, combate, inventario, equipo, progresión, quests (lógica) | `rpg-systems-dev` |
| Edificios, recursos, producción, ciudadanos, simulación por días, colocación en grid | `city-systems-dev` |
| Generación procedural de chunks, seeds, biomas, mapa mundial (datos), ruido, colocación de recursos y enemigos | `world-gen-dev` |
| Sprites, tilesets, paleta, animaciones, specs de arte, Aseprite | `pixel-artist` |
| HUD, menús, paneles, tema de UI, fuentes, accesibilidad | `ui-ux-dev` |
| Música chiptune, SFX, integración de audio | `audio-designer` |
| Tests (GUT), QA, reproducción de bugs, checklist de playtest | `qa-tester` |
| Entorno local: instalar Godot/addons (GUT), correr tests, scripts `tools/`, workflow de tests | `dev-tooling` |
| Steamworks, builds, export presets, CI/CD de releases, página de Steam, logros, versiones | `release-manager` |

## Reglas de enrutamiento
1. Una tarea que cruza áreas se divide: primero `engine-architect` si toca estructura, luego el agente de dominio.
2. Cualquier cambio de mecánica pasa por `game-designer` antes de implementarse (actualiza `docs/design/`).
3. Nunca implementar arte o audio final sin spec previa del agente correspondiente.
4. Decisiones técnicas o de diseño que afecten a más de un agente se registran en `docs/decisions/` (ADR).
5. Si no está claro qué agente aplica, usar `engine-architect` para triaje.

## Lectura mínima antes de cualquier tarea
- `docs/STACK.md` — stack y convenciones.
- `docs/design/GDD.md` — visión del juego.
- `docs/decisions/0002-*.md` y `0003-*.md` — decisiones fundacionales y modelo de mundo.
- El `.md` del agente correspondiente.
