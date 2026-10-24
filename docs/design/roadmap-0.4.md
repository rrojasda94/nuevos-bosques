# Hoja de ruta 0.4 "Los otros adoc"

> Dueño: `game-designer`. **Reparto confirmado por el dueño** ("1. si"): recoge la ronda de jugabilidad del dueño que no cabe en la 0.3.
> Palabras del dueño: "quiero mejorar la jugabilidad y el interes del juego. Deberia haber más npc. encontrarte con otros adoc, ayudarles a luchar contra 'Unicos. salvar los bosques, poder ser un adoc malo y poderoso o uno que se apega a las reglas y avanza con calma. podemos incluir puntos de stats o skills. Algunas villas tienes saruas a los que les puedes pedir ofrendas a cambio de favores, otras villas pueden tener artesanos que hacen equipamiento más para uso de un adoc."
> Parte de la 0.3 terminada: combate en grupo y aliados (PR 7), estados de Bosque (PR 4), inventario y equipo (PR 5).

## Criterio de reparto
- **En la 0.3**: solo lo que reutiliza el combate en grupo del PR 7. Los otros adoc como **aliados** en eventos del mundo.
- **En la 0.4**: todo lo que necesita NPC nuevos, economía de villa o progresión nueva. Así la 0.3 no se alarga y la 0.4 tiene un tema claro.

## Orden de los PR (propuesto)
| # | PR | Agentes | Ficha | Depende de |
|---|---|---|---|---|
| 1 | **Población de villas y diálogos**: lista de oficiantes por seed (Ildo, Sfida, Sarua, Paruas, Dumno, Rogoc, Pholua, Underil, Adoc, Ista); NPC con E; menú Hablar / Servicio / Adiós | world-gen-dev, rpg-systems-dev, narrative-writer | `npcs-y-villas.md` | 0.3 (villas, `DialogueBox`) |
| 2 | **Senda y puntos/skills**: eje −100…+100 y sus efectos; 1 punto de stat por nivel; 1 de skill cada 2 niveles, en 2 ramas (Golpe y Apaciguar) | rpg-systems-dev, ui-ux-dev | `moralidad-y-progresion.md` | 0.3 (hostilidad, relación, robo) |
| 3 | **Favores de Sarua**: llevar algo, recoger frutos lícitos, apaciguar un Único; recompensas en ofrendas | rpg-systems-dev, narrative-writer | `npcs-y-villas.md` | 1, 2 (la Senda modifica los favores) |
| 4 | **Artesanos de equipo y materiales**: fabricar y mejorar armas (Paruas), máscaras y talismanes (Sarua) con Luz y materiales; recolección de madera muerta, barro, piedra y fibra; artesanos de Bosques decrépitos que piden el material | rpg-systems-dev, ui-ux-dev, pixel-artist | `npcs-y-villas.md`, `sigilo-y-robo.md` | 1; 0.3 PR 5 (equipo) |
| 5 | **Otros adoc: encargos compartidos** y adoc en las villas | rpg-systems-dev, narrative-writer | `otros-adoc.md` | 1; 0.3 PR 7 (aliados) |
| 6 | **Salvar los Bosques**: incendios (apagar focos), defensa contra ataques con aliados, recuperar la cordura de un Bosque corrupto | world-gen-dev, rpg-systems-dev | `bosques-y-relacion.md` ("Salvar los Bosques") | 0.3 PR 4 (estados), PR 7 (grupo); 5 (encargos compartidos) |
| 7 | **Personalización del adoc** (ropa y cabello, no colores; #146) | ui-ux-dev, pixel-artist | por escribir | Menú de inicio |

```
1 ─┬─ 3 ◄── 2
   ├─ 4
   └─ 5 ── 6
7: independiente
```

## Resueltas (dueño, 0.4)
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
- **#165**: isométrico o cenital con relieve. Afecta al arte y la generación de terreno, en paralelo.
