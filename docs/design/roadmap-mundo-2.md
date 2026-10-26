# Hoja de ruta 0.4 "Mundo 2.0"

> Dueño del plan técnico: `engine-architect`. Decisión: [ADR 0014](../decisions/0014-mundo-2-relieve-movimiento-libre-y-mundo-hibrido.md) (aceptado). Hoja de ruta general: [`roadmap.md`](roadmap.md).
> **Cuándo**: en curso desde el 2026-10-25. El dueño pidió ese día adelantarla antes de cerrar lo que quedaba de la 0.3; ese mismo día se publicó la 0.3.0, así que no hubo solape. Después viene la 0.5 "Los otros adoc" ([`roadmap-0.5.md`](roadmap-0.5.md)).
> Un PR = un tema (`CONTRIBUTING.md`). Las estimaciones son días de trabajo de un agente, incluidos los tests y la revisión.

## Qué verá el jugador en la 0.4
- Vista cenital estilo Zelda con **relieve**: mesetas, riscos con cara, escaleras, rampas y cascadas.
- **Movimiento libre en 8 direcciones**, fluido, con teclado o mando.
- **Mundo continuo**: sin fundidos ni parpadeos al cruzar de un chunk a otro.
- El Valle del Sara con su geografía pintada por el dueño, **villas con nombre** y lugares fijos. El relleno cambia en cada partida.
- Bosques con **formas grandes**: árboles de 2×2, claros, lagunas, colinas e hitos, y caminos que forman una red, no una X.
- **Más variedad** de árboles y decoración.
- Una pantalla "Creando el mundo…" con barra de progreso al empezar partida (unos segundos), y después cero esperas.
- Las partidas de la 0.3 no se pueden continuar (aviso en el menú).

## Cómo se mantiene jugable `main`
El mundo nuevo se construye **con clases nuevas** (`RegionAuthoring`, `RegionPlan`, `ChunkBuilder`, `WorldChunk`, `WorldCache`, `WorldStreamer`, `GridMover`, `PlayerController`) y una escena nueva (`scenes/world/world_view.tscn`), que se prueban con escenas y tests propios. El juego sigue usando `ChunkGenerator` y `exploration.tscn` hasta el **PR M17**, que hace el cambio y borra lo viejo.

## Estado
Se actualiza en cada PR del Mundo 2.0.

| Hito | Estado |
|---|---|
| M0 | Hecho |
| M1 ficha | Hecho (PR #47) |
| M2 spec de arte | Hecho (PR #51) |
| M3 autoría | Hecho (PR #53). Después, autoría del dueño: afluentes del Sara (#64, #69, #77), Larr, cordillera occidental transitable y Azhin (#72) |
| M4 `WorldChunk` y `WorldCoords` | Hecho (PR #50) |
| M5 `RegionPlan` | Hecho (PR #56). Villas procedurales: opción C |
| M6 relieve | Hecho (PR #61) |
| M7 senderos y formas grandes | Hecho (PR #79) |
| M8 decoración, villa, refugios, frutales y `WorldQuery` | Hecho (PR #82). Generador: mediana ~40 ms por chunk |
| M9 rendimiento | En curso |
| M10 caché y pregeneración | Hecho (PR #58) |
| M11 `GridMover` | Hecho (PR #48) |
| M12 `WorldView` | Hecho (PR #80). Ruta automática sin fotogramas > 20 ms del mundo |
| M13 tileset primera pasada | Hecho (PR #59) |
| M14 interacción | En curso |
| M15 monstruos | En curso |
| M16 mapa M y brújula | Hecho (PR #84) |
| Fuentes visibles y sicabis en el mundo | Pendiente, tras M9 (ficha en PR #83) |
| M17 cambio al Mundo 2.0 | Pendiente. Decidido: se empieza de cero |
| M18 arte final | Pendiente. Decidido: riscos con esquinas interiores y diagonales (+1 PR de arte) |
| M19 playtest y 0.4.0 | Pendiente |

## Orden de los PR
| # | PR | Agente | Archivos principales | Depende de | Estim. | Hecho cuando |
|---|---|---|---|---|---|---|
| M0 | `design: ADR 0014 Mundo 2.0 y hoja de ruta` (este) | engine-architect | `docs/decisions/0014-*`, `docs/design/roadmap*.md`, `docs/STACK.md`, `docs/CONVENCIONES.md` | — | 0,5 d | Merge en `main` |
| M1 | `design: ficha del Mundo 2.0` (velocidades, tiempos de viaje y riutash con chunks de 80, pesos de puntos de interés, villas procedurales sí o no, densidad de refugios) | game-designer | `docs/design/mechanics/mundo-2.md`, `data/world/movement.json` (valores) | M0 | 1 d | Ficha con valores provisionales y tabla de feedback |
| M2 | `art: spec de relieve, objetos de varias casillas y decoración variada` | pixel-artist | `docs/art/specs/mundo-2.md` | M0 | 1 d | Lista de piezas (caras, esquinas, escaleras, rampas, cascada, cueva; árboles 4 variantes × 6 siluetas, 3×3, joven y seco; ≥ 16 decoraciones por tipo de Bosque; casas 4×3), claves de color y tamaños |
| M3 | `feat(world): autoría de regiones (PNG + CSV), validador y vista previa` | world-gen-dev (lector), dev-tooling (`tools/`) | `scripts/world/region_authoring.gd`, `data/world/authoring_palette.json`, `data/world/regions/valle_del_sara/*`, `tools/world/preview_region.*`, `docs/design/world/autoria.md` | M0 | 2 d | PNG iniciales exportadas del generador actual; el validador detecta colores sueltos y lugares imposibles; la vista previa sale en `build/`; guía para el dueño; tests `test_region_authoring` |
| M4 | `feat(core): WorldChunk en capas, WorldCoords y banco de pruebas de rendimiento` | engine-architect | `scripts/core/data/world_chunk.gd`, `scripts/core/world_coords.gd`, `tools/world/bench_chunks.gd` | M0 | 1 d | Capas, `occupant`, objetos y `rebuild_blocked` con tests; el banco mide la mediana y el p95 |
| M5 | `feat(world): pasada de región (RegionPlan)`: altura gruesa, agua, Bosques clave + procedurales, villas del CSV, caminos, puertas con árbol por Bosque, refugios | world-gen-dev | `scripts/world/region_plan.gd`, `scripts/world/bosque_map.gd` (ampliar sin romper) | M3, M4 | 2,5 d | Determinista; Bosques de 4–16 chunks; todo Bosque recorrible por puertas; ≤ 1,5 s; tests `test_region_plan` |
| M6 | `feat(world): relieve por chunk` (niveles, caras, bordes, escaleras, rampas, cascadas, sombras) | world-gen-dev | `scripts/world/chunk_builder.gd` | M5 | 1,5 d | Invariante "niveles conectados solo por escalera o rampa" en 20 seeds; cascadas donde hay río; `test_relief` |
| M7 | `feat(world): puntos de interés, red de senderos (MST + A*) y formas grandes` | world-gen-dev | `scripts/world/chunk_builder.gd` | M6 | 2 d | Red conexa desde el hub; hub no central en ≥ 80 % de chunks; sin árboles sueltos; puertas iguales vistas desde los dos chunks |
| M8 | `feat(world): decoración variada, villa 4×3, Nujio, letreros, cueva-refugio y frutales 2×2 (datos)` | world-gen-dev | `scripts/world/chunk_builder.gd` | M7, M2 (lista de piezas) | 2 d | Rechazo de repetición de variantes; refugio y frutales alcanzables; tests portados de `test_refuges`, `test_fruit_trees`, `test_roads` |
| M9 | `perf(world): generador ≤ 80 ms por chunk` | world-gen-dev (+ engine-architect, revisión) | `scripts/world/chunk_builder.gd`, `region_plan.gd` | M8 | 1,5 d | `bench_chunks`: mediana ≤ 80 ms y p95 ≤ 150 ms en el PC de referencia; aviso en la CI |
| M10 | `feat(core): caché del mundo y pregeneración en hilos con barra de progreso` | engine-architect (+ ui-ux-dev, pantalla) | `scripts/world/world_cache.gd`, `scripts/world/world_pregen.gd`, `scenes/ui/world_loading.tscn` | M4; usa M5 (con un `ChunkBuilder` falso hasta que exista) | 2 d | Ida y vuelta byte a byte; clave distinta = regenerar; caché corrupta = regenerar; serie = paralelo; cola por prioridad |
| M11 | `feat(world): GridMover, movimiento libre en 8 direcciones` | engine-architect | `scripts/world/grid_mover.gd`, `scripts/world/player_controller.gd`, `data/world/movement.json` | M0 (valores de M1, con los provisionales del ADR mientras tanto) | 1,5 d | `test_grid_mover` (deslizamiento, esquinas, diagonales, velocidad, `cell_changed`); escena de prueba sobre una rejilla |
| M12 | `feat(world): WorldView con streaming por sectores, capas, orden en Y y cámara` | engine-architect | `scripts/world/world_streamer.gd`, `scripts/world/world_view.gd`, `scenes/world/world_view.tscn` | M4, M10, M11; arte placeholder del spike | 2,5 d | Andar y correr por toda la región sin fotogramas de más de 20 ms (escena de ruta automática); ≤ 2 ms por fotograma montando sectores |
| M13 | `art: tileset de relieve y objetos, primera pasada` | pixel-artist | `assets/tilesets/*`, `tools/art/*` | M2 | 2 d | Piezas de la spec en la paleta y recolorables por Bosque; sustituye al placeholder del spike |
| M14 | `feat(rpg): interacción, letreros, refugios, frutales 2×2, NPC y villa con movimiento libre` | rpg-systems-dev | `scripts/rpg/interaction.gd`, `fruit_rules.gd`, `signpost.gd`, `npc.gd`, `adventure_rules.gd` | M8, M12 | 1,5 d | E con sondeo; objetos de varias casillas; letreros y refugio por `cell_changed`; tests ajustados |
| M15 | `feat(rpg): monstruos con movimiento continuo y encuentros` (Botarramas, Ofomni, Únicos de la 0.3, límite de Bosque) | rpg-systems-dev | `scripts/rpg/monster_field.gd`, `overworld_monster.gd`, `botarramas_posts.gd` | M11, M12 | 1,5 d | `MonsterSteering` sin cambios; puestos en las puertas nuevas; cruce por el límite fuera de puerta; `test_monsters` ajustado |
| M16 | `feat(ui): mapa M con vista de la región y brújula en píxeles` | ui-ux-dev | `scripts/ui/region_map.gd`, `map_logic.gd`, `compass.gd` | M5, M12 | 1 d | Mapa con altura, agua, Bosques y caminos; brújula exacta; `test_map_logic` |
| M17 | `feat(save): cambio al Mundo 2.0` (exploración nueva, `SAVE_VERSION`, aviso de partidas viejas, borrar `ChunkGenerator`, `ChunkData`, `PlayerWalker` y la exploración vieja, STACK y CONVENCIONES vigentes) | engine-architect | `scripts/world/exploration.gd` (o su sustituta), `scenes/world/*`, `scripts/autoload/game_state.gd`, `save_manager.gd`, `data/text/sistema.json` | M9, M13, M14, M15, M16 | 2 d | Partida completa jugable (misión del Ofomni, peaje, frutos, riutash, refugio, derrota y reaparición); partidas viejas rechazadas con aviso; todos los tests en verde; arranque headless sin errores |
| M18 | `art: arte final del relieve y la decoración, y repaso de paleta` | pixel-artist | `assets/tilesets/*` | M13 (puede entrar tras M17) | 3 d | Aprobado por el dueño en el playtest |
| M19 | `test: playtest del Mundo 2.0` y versión 0.4.0 | qa-tester, release-manager | `docs/design/mechanics/mundo-2.md` (feedback), `CHANGELOG.md`, `project.godot` | M17 (y M18 si el dueño lo quiere en la 0.4.0) | 1 d | Checklist de playtest; el dueño juega; tag `v0.4.0` |
| D1 | **Tarea del dueño**: pintar el Valle del Sara sobre su mapa y rellenar `lugares.csv` | dueño (con world-gen-dev) | `data/world/regions/valle_del_sara/*` | M3 | — | El validador pasa y la vista previa le gusta. **No bloquea** el código (hay PNG iniciales) |

Total de código y arte: unos 32 días de agente, con 3 carriles en paralelo (en torno a 14–16 días de calendario).

## Qué puede ir en paralelo
Los carriles no tocan los mismos archivos:
```
              ┌─ M1 (diseño)                                   docs/design/mechanics
              ├─ M2 ── M13 ─────────────────── M18 (arte)      docs/art, assets/tilesets
M0 ─┬─────────┤
    │         ├─ M3 ─┐                                         región: region_authoring, tools/world
    │         └─ M4 ─┴─ M5 ─ M6 ─ M7 ─ M8 ─ M9 (generación)    region_plan, chunk_builder (en serie: mismo archivo)
    │                    │                │
    │              M4 ── M10 ─┐           │                    world_cache, world_pregen
    └─ M11 ───────────────────┴─ M12 ─────┴─┬─ M14 ─┐          grid_mover / world_streamer, world_view
                                            ├─ M15 ─┼─ M17 ─ M19
                                            └─ M16 ─┘
```
- **Desde el principio**: M1, M2, M3, M4 y M11 a la vez (diseño, arte, autoría, datos del chunk, movimiento).
- **Generación** (M5 → M9) va en serie, porque M6–M9 tocan `chunk_builder.gd`.
- **Motor**: M10 y M11 en paralelo con la generación; M12 cuando están M10 y M11 (usa el placeholder del spike y un `ChunkBuilder` provisional si M8 no ha terminado).
- **Juego**: M14, M15 y M16 a la vez cuando están M8 y M12 (tocan `rpg/interaction` + `fruit_rules`, `rpg/monster_*` y `ui/region_map` + `compass`, respectivamente).
- **M17** es el único que toca `exploration.gd`, `game_state.gd` y `save_manager.gd`. Lo hace uno solo y al final.
- **Arte** (M13, M18) en paralelo todo el tiempo; M18 puede salir en un 0.4.x.

## Dónde encaja respecto a la 0.3 y la 0.5
- **Orden del dueño** (2026-10-24): primero se cierran las dinámicas de la 0.3, después el Mundo 2.0 (0.4) y después "Los otros adoc" (0.5).
- **Por qué funciona bien así**:
  - Las dinámicas que quedan en la 0.3 (Únicos en el mundo, estados de Bosque, sigilo, combate en grupo, dormir) son sobre todo **reglas** (clases puras, combate, `GameState`) y casi no tocan la generación ni el dibujo, así que no se pierden con el cambio de mundo.
  - Hacer el Mundo 2.0 **antes** de la 0.5 evita construir NPC por oficio, artesanos, materiales (madera, piedra, obsidiana en zonas rocosas) e incendios sobre un mundo que se va a tirar. Esas features dependen del relieve, de las villas con nombre y de los objetos de varias casillas.
- **Condición para la 0.3**: la lógica nueva debe quedar en clases puras con casillas e ids de Bosque (no en `exploration.gd` ni en `ChunkData`). Así su porte en M14 y M15 es pequeño. Las señales visuales de los estados de Bosque (recolor del atlas) se rehacen en M13 con el arte nuevo.
- **Riesgo**: la 0.3 aún tiene 5 bloques y la 0.4 es grande. Si el dueño quiere ver el mundo nuevo antes, M1–M4 y M11 se pueden adelantar sin tocar el juego (documentos, autoría, datos y una escena de prueba de movimiento), pero solo si él lo pide.

## Decisiones del dueño que bloquean
- ~~**Conservar al adoc**~~: **decidido** (dueño, 2026-10-26): **se empieza de cero**. Las partidas de la 0.3 se rechazan con el aviso del ADR 0014 y no se conserva nada del adoc.
- ~~**Villas procedurales**~~: **decidido** (2026-10-25), opción C: aldeas sin nombre con `procedural_villa_chance` 0,2, nunca junto a una villa con nombre, como mucho 2 por área.
- ~~**Riscos rectos**~~: **decidido** (dueño, 2026-10-26): **esquinas interiores y tramos diagonales** (+1 PR de arte en M18; filas 8–11 de `tileset_relieve.png` reservadas en la spec). El generador tendrá que marcar dónde van (lo ve `world-gen-dev` con `pixel-artist`).
