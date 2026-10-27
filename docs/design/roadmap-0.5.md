# Hoja de ruta 0.5 "Dos caminos" (antes "Los otros adoc")

> **Reorganización CONFIRMADA por el dueño (2026-10-25, ADR 0015; "6. Ok").** La 0.5 se llama **"Dos caminos"** y combina "Los otros adoc" con el camino garelino (`mechanics/dos-caminos.md`).
> **Historia en pausa**: primero mecánicas, jugabilidad y desarrollo de personaje. Los textos de historia (`historia/`) son un borrador aparcado. Los PR usan roles genéricos y los finales con hitos no entran.
>
> **Orden de la 0.5 "Dos caminos"** (sustituye a las tablas de abajo, que quedan como historial):
>
> | # | PR | Fichas | Depende de |
> |---|---|---|---|
> | 1 | **Villas vivas y diálogos**: prioridad de oficios por tamaño de villa (obligatorios: Pholua, Ildo, Sfida, Folas/Folat, Sarua), cada oficiante en su sitio, rutinas por Momento (de día trabajan, de noche duermen en las casas), diálogos por oficio | `npcs-y-villas.md` | 0.4 (villas con nombre y colocación en el Mundo 2.0) |
> | 2 | Senda, puntos y skills (Sombra / Confianza) **y estado de bando** (fiel / en duda / garelino) — **Hecho** (PR #62): Senda e iconos, bando fiel / en duda, pestaña "Crecer" con 3 puntos, ramas de skills, afinidad de adoc y Ofomni descarriado ×0,85. El bando garelino llega con el PR 4 | `moralidad-y-progresion.md`, `dos-caminos.md` | 0.3 |
> | 4b | **IA de combate** — **Hecho** (PR #67): iniciativa por AGI, Táctica (Defender, Apresurar, Esperar, filas), roles, perfiles y órdenes. Se traduce a la cuadrícula en T5 | `ia-de-combate.md` | 0.3 |
> | **T1–T8** | **Combate táctico en cuadrícula** (ADR 0016, estilo FFTA, vista cenital con alturas por capas). Bloque de PR pequeños; plan en `combate-tactico.md`: T1 tablero lógico; T2 turnos CT, movimiento y orientación; T3 acciones con evasión, orientación y altura; T4 escena táctica (UI); T5 IA en la cuadrícula; T6 área, conjunto de reparep y sorpresa; T7 arte y tablero desde el relieve (depende de la 0.4); T8 retirar la escena antigua y balance. **Va antes de los garelinos**, que pelean ya en el tablero | `combate-tactico.md`, `ia-de-combate.md` | 2, 4b; T7 depende del Mundo 2.0 |
> | 3 | Garelinos: enemigo humano no letal, campamentos y ataques a Bosques | `monstruos.md` | 0.3 (combate en grupo, estados de Bosque); **T5** |
> | 4 | Encuentro con los garelinos y cambio de bando (mecánica, con textos genéricos) | `dos-caminos.md` | 2, 3 |
> | 5 | Grupo garelino: reclutar, miembros que se retiran, Piedras | `dos-caminos.md` | 3, 4, 4b, **T5** |
> | 6 | Persuadir villas (4 vías, convicción, necesidades) y contrapersuasión del fiel | `dos-caminos.md`, `npcs-y-villas.md` | 1, 5 |
> | 7 | Talar Bosques muertos (tú o tu grupo) y sembrar Piedras (Nuevos Bosques); Humores por exposición; magra | `dos-caminos.md`, `bosques-y-relacion.md` | 5; 0.3 (estados) |
> | 8 | Salvar los Bosques (lado fiel) y encargos compartidos con otros adoc | `bosques-y-relacion.md`, `otros-adoc.md` | 1, 3 |
> | 9 | Redención (con asilo de magra). Los finales quedan aparcados | `dos-caminos.md` | 6, 7, 8 |
>
> **Se mueve a la 0.6**: favores de los Sarua, artesanos y materiales (salvo el **trueque mínimo**, que se adelanta en P5), e Iserald con el combate de grupo grande. En la 0.5 el Iserald puede desatarse al dañar un Bosque, y lo sensato es huir. La personalización del adoc pasa a la 1.0, con el menú de inicio.
>
> ### P: ajustes de playtest
> El dueño jugó con el combate táctico activado: "es muy facil huir", el fruto no se entiende, "debería poderse entrar como sneaking", "las armas no afectan el combate", "los item no tienen ningun valor real" y "la ia de los enemigos es muy basica". La ficha es `mechanics/ajustes-playtest-0.5.md`. **Confirmado por el dueño (ADR 0017**: #191–#195 y #197). Siguen abiertas #190 (fruto en un Bosque forzado: solo afecta a los textos de P3, no bloquea) y #196 (consumibles: fuera del bloque). **Va antes de los garelinos (PR 3)**, que heredan la IA y la huida.
> **Ojo con el M17a**: la sesión del Mundo 2.0 está reescribiendo la exploración. Lo que toca `exploration.gd` u `OverworldMonster` va en reglas puras (`Stealth`, `FruitRules`, `AdventureRules`, `MonsterSteering`) con tests, más un **gancho mínimo** que se coordina con esa sesión.
>
> | # | PR | Agentes | Toca la exploración | Depende de |
> |---|---|---|---|---|
> | **P1** | **Huida con suerte** — **Hecho** (con P2): fórmula, % en el menú, fallo que pierde el turno y menú a 0,6. El `flee_cooldown` de 1,5 s **pasa a P6**: la calma tras huir usa `engage_cooldown`, el mismo dato que Retroceder, y separarlos exige tocar `scripts/world`. Plan original: `TacticalBattle.flee_chance()` (fórmula de §1a, `tactical.flee`), fallo que pierde el turno, % visible en el menú Huir; `flee_chance` del menú 0,75 → 0,6; `flee_cooldown` 1,5 s tras huir. Tests | rpg-systems-dev, ui-ux-dev (el %) | Solo un dato (`flee_cooldown`) | T6 (hecho) |
> | **P2** | **IA más lista** — **Hecho** (con P1): perfiles y reglas comunes; alcance por combatiente genérico en `TacticalRules.can_strike` (lo reutiliza P4 con la lanza). Plan original: perfiles guardián, látigo (alcance 2 del Ofomni) y emboscadora; Defender y Esperar; cortar la huida; azar top-2 con la seed del combate; preferencia de altura (sin efecto en el tablero llano). Tests de IA contra IA | rpg-systems-dev | No | P1 (cortar usa `flee_chance`). La altura ya se nota con T7a (hecho, `TacticalRelief`) |
> | **P3** | **Arma enfundada, colarse de verdad y permiso del fruto** — **Hecho**: reglas en `Stealth.border_outcome`, `AdventureRules.toggle_weapon` / `can_enter_sicabi` / `drawn_at_start`, `FruitRules.permission_state` / `prompt`; gancho en `BosqueBorder.decide` y `world_exploration.gd`; guardado v21. Pendiente: acción "Desenfundar" del táctico (P4). `weapon_drawn` y tecla Q (`toggle_weapon`, guardado); la regla de la sicabi (sin arma equipada, ni enfundada) queda como función pura para cuando lleguen las sicabis (0.6); `Stealth.detects` y `Stealth.can_cross_unseen` (con `close_detect`, `unmasked_vision_factor` y `run_breaks_camouflage`, y sin `sneak_max_vision`); `FruitRules.permission_state`, textos del robo, icono de permiso en el HUD y aviso de entrada. Gancho: `_on_edge_reached` pide la lista de vigías (distancia y visión) al campo de monstruos y llama a `can_cross_unseen`. `qa-tester`: reproducir el caso del fruto | rpg-systems-dev, ui-ux-dev (HUD), engine-architect (input y guardado), narrative-writer (textos) | **Sí**: gancho del borde y tecla | Coordinar con M17a |
> | **P4** | **Armas y objetos en el táctico**: alcance por arma (`range`, `line`) y lanza a 1–2; ATQ y arma visibles en la escena; acción **Objeto** (fruto); **Cuchillo** y **Honda** en `items.json` y sus fuentes (refugio, otros adoc); equipo inicial (lanza enfundada y máscara de corteza puestas, trenza votiva en la bolsa) | rpg-systems-dev, ui-ux-dev, pixel-artist (iconos de las 2 armas; placeholder vale) | No | P3 (estado enfundada para el equipo inicial y para la emboscada); T4 |
> | **P5** | **Trueque mínimo**: Sarua (máscaras y talismanes) y Paruas (armas) con ofrendas o Luz; existencias por seed y día. Sin materiales | rpg-systems-dev, ui-ux-dev | No (diálogo de villa) | P4 (catálogo); PR 1 de la 0.5 (Sarua como NPC), o como alternativa el diálogo de la plaza |
> | **P6** | **Sprint de los Únicos** — **Hecho**: `MonsterSteering.sprint_tick` / `speed_px` / `calm_seconds` (puros); gancho en `OverworldMonster.think_world` y `speed()`; `_retreat_from(monster, fled)` en `world_exploration.gd` (huida con éxito → `flee_cooldown` 1,5 s; Retroceder, rechazar el combate o pagar → `retreat_cooldown` 3 s). `engage_cooldown` queda para la calma al aparecer y la exploración vieja. Datos en `balance.json` (`monsters.<id>`), tabla de §1b; el Botarramas sin sprint. Tests: `tests/unit/world/test_monster_sprint.gd`. Plan original: estado de sprint puro en `MonsterSteering` (`sprint_trigger`, `sprint_px`, `sprint_seconds` y `sprint_cooldown` por monstruo); el gancho en el movimiento del monstruo. **Heredado de P1**: `flee_cooldown` = 1,5 s (calma tras una huida con éxito) separado del `engage_cooldown` de Retroceder (3 s), en la exploración nueva | rpg-systems-dev, world-gen-dev (sesión del Mundo 2.0) | **Sí**: movimiento del monstruo | M17a (mejor después, o dentro de él) |
>
> ```
> P1 ── P2
> P3 ── P4 ── P5
> P6 (después de M17a o dentro de él)
> ```
> - P1 y P3 pueden ir en paralelo.
> - Cerrar el bloque P también activa `tactical.enabled = true` por defecto, si el dueño lo aprueba tras el siguiente playtest (lo cierra T8).

> **Propuesta para la 0.6 (después del Mundo 2.0)**: **interiores y lugares especiales** (`mechanics/lugares-e-interiores.md`): casas por dentro, refugios por dentro, **tarcas** (cuevas amplias) y **sicabis** (lugares sagrados sin armas que regeneran Luz y conectan con la Luz y el Bosque). Dependen del Mundo 2.0.

> Dueño: `game-designer`. **Reparto confirmado por el dueño** ("1. si"): recoge la ronda de jugabilidad del dueño que no cabe en la 0.3.
>
> **Renumerada (dueño, 2026-10-24):** esta versión era la 0.4. Pasa a ser la **0.5**, porque la 0.4 es el **Mundo 2.0** ([`roadmap-mundo-2.md`](roadmap-mundo-2.md), ADR 0014): relieve, movimiento libre y mundo híbrido. Todo lo de aquí se construye sobre el mundo nuevo: villas con nombre (PR 1), materiales en zonas rocosas y montañosas (PR 4) e incendios (PR 6) aprovechan el relieve y los objetos de varias casillas. Hoja de ruta general: [`roadmap.md`](roadmap.md).
> Palabras del dueño: "quiero mejorar la jugabilidad y el interes del juego. Deberia haber más npc. encontrarte con otros adoc, ayudarles a luchar contra 'Unicos. salvar los bosques, poder ser un adoc malo y poderoso o uno que se apega a las reglas y avanza con calma. podemos incluir puntos de stats o skills. Algunas villas tienes saruas a los que les puedes pedir ofrendas a cambio de favores, otras villas pueden tener artesanos que hacen equipamiento más para uso de un adoc."
> Parte de la 0.3 terminada y del Mundo 2.0 (0.4): combate en grupo y aliados (PR 7), estados de Bosque (PR 4), inventario y equipo (PR 5).

## Criterio de reparto
- **En la 0.3**: solo lo que reutiliza el combate en grupo del PR 7. Los otros adoc como **aliados** en eventos del mundo.
- **En la 0.5** (antes numerada 0.4): todo lo que necesita NPC nuevos, economía de villa o progresión nueva. Así la 0.3 no se alarga y la 0.5 tiene un tema claro.

## Orden de los PR (propuesto)
| # | PR | Agentes | Ficha | Depende de |
|---|---|---|---|---|
| 1 | **Población de villas y diálogos**: lista de oficiantes por seed (Ildo, Sfida, Sarua, Paruas, Dumno, Rogoc, Pholua, Underil, Adoc, Ista); NPC con E; menú Hablar / Servicio / Adiós | world-gen-dev, rpg-systems-dev, narrative-writer | `npcs-y-villas.md` | 0.3 (villas, `DialogueBox`); 0.4 (villas con nombre del Mundo 2.0) |
| 2 | **Senda y puntos/skills**: eje −100…+100 y sus efectos; 1 punto de stat por nivel; 1 de skill cada 2 niveles, en 2 ramas (Golpe y Apaciguar) | rpg-systems-dev, ui-ux-dev | `moralidad-y-progresion.md` | 0.3 (hostilidad, relación, robo) |
| 3 | **Favores de Sarua**: llevar algo, recoger frutos lícitos, apaciguar un Único; recompensas en ofrendas | rpg-systems-dev, narrative-writer | `npcs-y-villas.md` | 1, 2 (la Senda modifica los favores) |
| 4 | **Artesanos de equipo y materiales**: fabricar y mejorar armas (Paruas), máscaras y talismanes (Sarua) con Luz y materiales; recolección de madera muerta, barro, piedra y fibra; artesanos de Bosques decrépitos que piden el material | rpg-systems-dev, ui-ux-dev, pixel-artist | `npcs-y-villas.md`, `sigilo-y-robo.md` | 1; 0.3 PR 5 (equipo) |
| 5 | **Otros adoc: encargos compartidos** y adoc en las villas | rpg-systems-dev, narrative-writer | `otros-adoc.md` | 1; 0.3 PR 7 (aliados) |
| 6 | **Salvar los Bosques**: incendios (apagar focos), defensa contra ataques con aliados, recuperar la cordura de un Bosque corrupto | world-gen-dev, rpg-systems-dev | `bosques-y-relacion.md` ("Salvar los Bosques") | 0.3 PR 4 (estados), PR 7 (grupo); 5 (encargos compartidos); 0.4 (relieve y objetos de varias casillas) |
| 7 | **Personalización del adoc** (ropa y cabello, no colores; #146) | ui-ux-dev, pixel-artist | por escribir | Menú de inicio (puede pasar a la 1.0 con el menú, ver `roadmap.md`) |

```
1 ─┬─ 3 ◄── 2
   ├─ 4
   └─ 5 ── 6
7: independiente
```

## Resueltas (dueño, para esta versión; se decidieron cuando era la 0.4)
- **#156**: 3 puntos de stat a mano por nivel, más +3 PV y +1 ATQ/DEF automáticos (decisión del coordinador). Ajuste de coste en #162.
- **#151**: la Senda se ve como icono (3 estados) y desbloquea las ramas **Sombra** y **Confianza** del árbol de skills.
- **#154**: Paruas, armas; Sarua, máscaras y talismanes.
- **#153**: los adoc son siempre aliados, con afinidad según la Senda. Los garelinos son el enemigo humano (no letal).
- **#152**: el Iserald se desata al dañar el Bosque, por los garelinos o con el Nujio sin cordura. Solo lo vence un grupo de adoc. Estado Miedo.

## PR nuevos que salen de las respuestas
| # | PR | Ficha | Depende de |
|---|---|---|---|
| 8 | **Garelinos**: enemigo humano, combate no letal, ataques a Bosques | `monstruos.md` ("Garelinos") | 0.3 PR 4 y PR 7; 6 |
| 9 | **Iserald y estado Miedo** (requiere grupos de adoc) | `monstruos.md` ("Iserald") | 5, 8 |

## Más respuestas del dueño
- **#158**: tras toda derrota no fatal, reaparición con el 50% de los PV junto al Nujio aliado más cercano o el último pagado; si no hay ninguno, en la villa natal. Afecta a la 0.3 (`cruce-y-combate-v2.md`): puede ir en el PR 3 o en un PR pequeño propio.
- **#159**: los artesanos usan **materiales** (madera muerta con permiso, barro, piedra, fibra, metal de Gietos rarísimo). El PR 4 incluye recolección de materiales y recetas.
- **#160**: el Nujio muere al desatarse el Iserald. Para vencerlo hacen falta 6–8 adoc; la mecánica de fuerza de grupo y la llamada de adoc van en el PR 9.

## Decisiones del dueño que bloquean
- **#162**: confirmar el coste de los puntos (ATQ y DEF a 3 puntos) y el Ofomni a PV ×0,85. Bloquea el PR 2.
- **#160 (resto)**: confirmar Miedo y si "6 u 8" incluye al jugador. Bloquea el PR 9.
- **#163**: si el Iserald sale de su Bosque y cuánto tiempo hay para reunir adoc. Bloquea el PR 9.
- **#164**: metal de Gietos como material. Bloquea una receta del PR 4.
- ~~**#165**~~ Resuelta: cenital estilo Zelda con relieve, movimiento libre y mundo híbrido (ADR 0014, en la 0.4).
