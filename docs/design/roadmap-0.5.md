# Hoja de ruta 0.5 "Dos caminos" (antes "Los otros adoc")

> **Reorganización CONFIRMADA por el dueño (2026-10-25, ADR 0015; "6. Ok").** La 0.5 se llama **"Dos caminos"** y combina "Los otros adoc" con el camino garelino (`mechanics/dos-caminos.md`).
> **Historia en pausa**: primero mecánicas, jugabilidad y desarrollo de personaje. Los textos de historia (`historia/`) son un borrador aparcado. Los PR usan roles genéricos y los finales con hitos no entran.
>
> **Orden de la 0.5 "Dos caminos"** (sustituye a las tablas de abajo, que quedan como historial):
>
> | # | PR | Fichas | Depende de |
> |---|---|---|---|
> | 1 | Población de villas y diálogos (Ildo, Ista, Sfida…) | `npcs-y-villas.md` | 0.4 (villas con nombre) |
> | 2 | Senda, puntos y skills (Sombra / Confianza) **y estado de bando** (fiel / en duda / garelino) | `moralidad-y-progresion.md`, `dos-caminos.md` | 0.3 |
> | 3 | Garelinos: enemigo humano no letal, campamentos y ataques a Bosques | `monstruos.md` | 0.3 (combate en grupo, estados de Bosque) |
> | 4 | Encuentro con los garelinos y cambio de bando (mecánica, con textos genéricos) | `dos-caminos.md` | 2, 3 |
> | 5 | Grupo garelino: reclutar, miembros que se retiran, Piedras | `dos-caminos.md` | 3, 4 |
> | 6 | Persuadir villas (4 vías, convicción, necesidades) y contrapersuasión del fiel | `dos-caminos.md`, `npcs-y-villas.md` | 1, 5 |
> | 7 | Talar Bosques muertos (tú o tu grupo) y sembrar Piedras (Nuevos Bosques); Humores por exposición; magra | `dos-caminos.md`, `bosques-y-relacion.md` | 5; 0.3 (estados) |
> | 8 | Salvar los Bosques (lado fiel) y encargos compartidos con otros adoc | `bosques-y-relacion.md`, `otros-adoc.md` | 1, 3 |
> | 9 | Redención (con asilo de magra). Los finales quedan aparcados | `dos-caminos.md` | 6, 7, 8 |
>
> **Se mueve a la 0.6**: favores de los Sarua, artesanos y materiales, e Iserald con el combate de grupo grande (en la 0.5 el Iserald solo puede desatarse por una siembra, y lo sensato es huir). La personalización del adoc pasa a la 1.0, con el menú de inicio.

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
