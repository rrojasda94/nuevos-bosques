# Hoja de ruta 0.3 "El Bosque recuerda"

> Dueño: `game-designer`. Parte de la v0.2.0 publicada. El dueño eligió las 4 partes del backlog: (1) memoria y relación con los Bosques, (2) sigilo, armas y robo, (3) reparep y combate en grupo (más Aledra fatal de noche), (4) dormir, Pensamiento y fruto. El fruto se adelantó al principio por petición del dueño.
> Un PR = un tema (`CONTRIBUTING.md`). Cada PR que cambie mecánicas enlaza su ficha o ADR. Los valores son provisionales salvo que se indique.
>
> **Cambio de orden (dueño, 2026-10-24):** "continúa con lo que tienes pendiente y las dinámicas del juego, luego arreglamos mapa y jugabilidad". La 0.3 **termina con las dinámicas que quedan** (Únicos en el mundo, estados de Bosque, sigilo y robo, combate en grupo, dormir). El mapa y el movimiento nuevos (relieve estilo Zelda, movimiento libre en 8 direcciones, mundo híbrido sin parpadeos, más variedad visual) son la **0.4 "Mundo 2.0"** ([ADR 0014](../decisions/0014-mundo-2-relieve-movimiento-libre-y-mundo-hibrido.md), [`roadmap-mundo-2.md`](roadmap-mundo-2.md)). "Los otros adoc" pasa a ser la **0.5** ([`roadmap-0.5.md`](roadmap-0.5.md)). Hoja de ruta general: [`roadmap.md`](roadmap.md).
>
> **Para los PR que quedan:** como el mundo se rehace en la 0.4, la lógica nueva va en clases puras que trabajan con casillas e ids de Bosque (como `MonsterSteering`, `AdventureRules`, `FruitRules`), no en `exploration.gd` ni en `ChunkData`. Así se porta casi sin cambios.

## Qué queda para cerrar la 0.3
En este orden: **3c** (en curso) → **4** estados de Bosque → **6** sigilo y robo → **7** combate en grupo → **8** dormir, Pensamiento y salvoconducto. Después, versión 0.3.0 y se empieza la 0.4.

## Orden de los PR
| # | PR | Agentes | Ficha / ADR | Depende de | Estado |
|---|---|---|---|---|---|
| 1 | **El Bosque recuerda**: vencer deja el Bosque forzado y pagar lo deja pagado; hostilidad; relación base; Ofrecer Luz paga y termina la pelea; ajuste del Ofomni; `appeasable` | rpg-systems-dev | ADR 0013, `cruce-y-combate-v2.md`, `mision-ofomni.md`, `monstruos.md` | — | **Hecho** (PR #24) |
| 2 | **Frutos**: `FRUIT_TREE`, +25% de PV, 1 por Momento, el extra es robo (hostilidad +1, relación −20), rebrote tras el riutash | world-gen-dev, rpg-systems-dev | `bosques-y-relacion.md` ("Fruto") | 1 (hostilidad y relación) | **Hecho** (PR #25) |
| 3 | **Relación completa**: el pago caduca (`open_until`); ofrendas dejadas en el Bosque; descanso del riutash junto al Nujio; umbrales de amistad (peaje ×0,75 / ×0,5, paso permanente con ≥ 60) | rpg-systems-dev, engine-architect (guardado) | `bosques-y-relacion.md` | 1, 2 | **Hecho** (PR #33 en main; descanso junto al Nujio a ≤ 6 casillas; ofrenda = + su valor en relación) |
| 3b | **Reaparición tras una derrota no fatal**: 50% de los PV, junto al Nujio aliado más cercano o el último pagado, o en la villa natal (#158) | rpg-systems-dev | `cruce-y-combate-v2.md` | 3 (relación ≥ 30 = aliado) | **Hecho** (PR #35 en main) |
| 3c | **Únicos en el mundo**: Ofomni perseguidores, el Bosque envía Únicos, enfrentar a voluntad, variedad de Únicos y Aledra nocturna | rpg-systems-dev | `monstruos.md`, `mision-ofomni.md` | 1, 3 | **En curso** (rama `feat/ofomni-guardianes`) |
| 9b | ~~Prueba isométrica~~ | engine-architect, pixel-artist, world-gen-dev | ADR 0014 | — | **Decidido** (#165): vista cenital estilo Zelda con relieve, movimiento libre y mundo híbrido. Se implementa en la **0.4** (`roadmap-mundo-2.md`); el isométrico se descarta por el control |
| 4 | **Estados de Bosque**: sano, enojado, corrupto, muerto y necesita ayuda; su generación por seed y área; señales visuales; peaje según el estado | world-gen-dev, rpg-systems-dev, pixel-artist | `bosques-y-relacion.md` | 3 (la relación ≤ −50 vuelve el Bosque enojado; los factores del peaje) | Pendiente |
| 5 | **Inventario y equipo**: bolsa + ranuras de equipo (mano principal, máscara, talismán); equipar y desequipar el arma; **frutos guardables** (comer o guardar; solo se comen en su Bosque; sacarlos baja la relación −5) | rpg-systems-dev, ui-ux-dev | `ofrendas-v1.md`, `sigilo-y-robo.md` | — (en paralelo con 3 y 4) | **Hecho** (PR #27: 12 casillas + 3 ranuras) |
| 6 | **Sigilo y robo**: las máscaras y los artefactos de camuflaje reducen la visión de los Únicos; el arma equipada cierra el paso; el robo despierta a `ofomni` apaciguables que persiguen hasta la frontera | rpg-systems-dev, world-gen-dev | `sigilo-y-robo.md`, `monstruos.md` | 1, 2 (robo de fruto), 5 (equipo) | Pendiente |
| 7 | **Combate en grupo**: reparep (2–4, ataque conjunto, elegir objetivo); **aliados** (Únicos en Bosques que necesitan ayuda y **otros adoc** en eventos del mundo: "Ayudar / Seguir tu camino"); Aledra fatal de noche | rpg-systems-dev, pixel-artist | `monstruos.md`, `otros-adoc.md` ("Ayudar en combate") | 1; 4 (para los aliados de Bosque) | Pendiente |
| 8 | **Dormir, Pensamiento y misiones lejanas con salvoconducto** | rpg-systems-dev, narrative-writer | `bosques-y-relacion.md`, `tiempo-y-riutash.md` | 3 y 4 (Bosques "buenos" para la ruta), misiones (0.2) | Pendiente |
| 9 | **Tileset de terreno con arte real** | pixel-artist (spec), world-gen-dev (integración) | spec en `docs/art/` | — (en paralelo) | **Hecho** (PR #31). Se rehace para el relieve en la 0.4 |
| 10 | ~~Personalización del adoc~~ | — | — | — | **Movido a la 0.5** (`roadmap-0.5.md`) |

> **Ronda de jugabilidad del dueño** ("más npc", otros adoc, Senda, puntos y skills, sarua y artesanos, salvar los Bosques): en la 0.3 solo entra lo que reutiliza el combate en grupo, es decir, otros adoc como **aliados** en el PR 7. El resto va a **"Los otros adoc"**, ahora la **0.5** (`roadmap-0.5.md`). **Reparto confirmado por el dueño.** En el PR 7, el adoc aliado puede rechazar tu ayuda si vuestras Sendas son muy distintas (afinidad, `otros-adoc.md`); hasta que exista la Senda (0.5), todos aceptan.

### Dependencias en resumen
```
1 ─┬─ 2 ─┬─ 3 ── 4 ─┬─ 7 (aliados)
   │     │          └─ 8
   │     └─ 6 ◄── 5
   └─ 7 (reparep)
3c: en curso (depende de 1 y 3)
9: hecho; 9b: decidido (0.4); 10: movido a la 0.5
```

## #113 (inventario): **confirmado por el dueño** ("perfecto")
**Slots estilo Minecraft: una bolsa de 12 casillas más 3 ranuras de equipo** (mano principal, cara/máscara, talismán).
- Es la más legible en 8-bit a 320×180 y la más barata de hacer.
- Encaja con lo que ya dice el GDD: "Inventario 12 slots. Equipo: arma, armadura, accesorio".
- Las ofrendas ocupan 1 casilla cada una. El límite de 12 hace que importe qué llevas, sin el puzzle de la cuadrícula.
- El **peso** enlazaría con la estamina, pero la estamina aún no existe (#73) y sería más difícil de leer.
- La **cuadrícula** es la más cara en UI.
- Se puede pasar a peso más adelante si llega la estamina.

## Decisiones del dueño que bloquean, por PR
Ordenadas por urgencia (primero lo que bloquea lo que está en curso o es lo siguiente).

**PR 1 y 2 (en curso)**
- **#148**: ¿PV del Ofomni ×0,7 (recomendado; sigue ganable en nivel 3) o ×0,85 (exige nivel 4)?
- ~~**#147**~~ Resuelta: la hostilidad baja con ofrendas (−1 por pago con ofrenda) y los Botarramas disueltos no reaparecen. Queda abierto si "forzado" caduca.
- ~~**#149**~~ Resuelta: 1 fruto por Momento **por Bosque** y solo si pagaste su peaje (o es el natal); el resto es robo.

**PR 3, relación**
- ~~#134 y #135~~ **Confirmadas**: el pago dura hasta el segundo riutash (permanente con relación ≥ 60), y se aceptan los valores de relación propuestos. Sin bloqueos.

**PR 4, estados**
- **#150**: ¿qué proporción de cada estado hay por área o región? ¿Cambian con el tiempo durante la partida?
- **#139**: ¿cuándo lanza su Iserald un Bosque corrupto? (Iserald es fatal y no existe aún: ¿entra en la 0.3?)
- **#140**: Bosques muertos: cuánta Luz pide el Único "independiente" y si un Bosque puede revivir.

**PR 5, inventario**
- ~~**#113**~~ Confirmado: slots estilo Minecraft (12 + 3 ranuras).
- **#131**: ¿cuesta un turno equipar o desequipar el arma en combate? ¿Se puede pelear sin arma?

**PR 6, sigilo**
- **#132**: efecto y duración de máscaras y talismanes, si se gastan y de dónde salen.
- **#130**: qué más cuenta como robo (además del fruto extra) y qué es "estar sin protección".

**PR 7, grupo**
- **#128**: dónde aparecen los reparep y Aledra; si se confirma la mecánica de grupo.
- **#143**: cuántos aliados hay y qué hacen.

**PR 8, dormir**
- Confirmar las propuestas de dormir (salto, coste de día, 1/2 de probabilidad de visión) (#142, #145).
- **#106 / #136**: tipos de misiones lejanas y duración del salvoconducto.

**PR 9, tileset** (hecho)
- **#84** (cómo se ven los riscos) pasa a la 0.4: lo responde el relieve del ADR 0014. **#86** (tipos de árbol en el MVP) sigue abierta.

**PR 10**
- **#146**: opciones de personalización.
