# Hoja de ruta 0.4 "Los otros adoc" (propuesta)

> Dueño: `game-designer`. **Propuesta**: recoge la ronda de jugabilidad del dueño que no cabe en la 0.3.
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
| 4 | **Artesanos de equipo**: fabricar y mejorar armas, máscaras y talismanes (oficios a confirmar) | rpg-systems-dev, ui-ux-dev, pixel-artist | `npcs-y-villas.md`, `sigilo-y-robo.md` | 1; 0.3 PR 5 (equipo) |
| 5 | **Otros adoc: encargos compartidos** y adoc en las villas | rpg-systems-dev, narrative-writer | `otros-adoc.md` | 1; 0.3 PR 7 (aliados) |
| 6 | **Salvar los Bosques**: incendios (apagar focos), defensa contra ataques con aliados, recuperar la cordura de un Bosque corrupto | world-gen-dev, rpg-systems-dev | `bosques-y-relacion.md` ("Salvar los Bosques") | 0.3 PR 4 (estados), PR 7 (grupo); 5 (encargos compartidos) |
| 7 | **Personalización del adoc** (ropa y cabello, no colores; #146) | ui-ux-dev, pixel-artist | por escribir | Menú de inicio |

```
1 ─┬─ 3 ◄── 2
   ├─ 4
   └─ 5 ── 6
7: independiente
```

## Decisiones del dueño que bloquean
- **#156**: ¿sistema de puntos pequeño (1 de stat por nivel y 1 de skill cada 2 niveles) o más grande? Bloquea el PR 2.
- **#151**: ¿la Senda se ve o es oculta? Bloquea el PR 2 (UI).
- **#154**: ¿qué oficio fabrica armas (¿Paruas?) y cuál máscaras y talismanes (¿Sarua?)? ¿Hay materiales? Bloquea el PR 4.
- **#153**: ¿hay adoc rivales u hostiles? Bloquea el PR 5.
- **#152**: ¿la Senda violenta atrae a Iserald? Bloquea parte del PR 2.
- **#157**: ¿cómo se resuelve un combate contra atacantes humanos sin matarlos? Bloquea el PR 6.
