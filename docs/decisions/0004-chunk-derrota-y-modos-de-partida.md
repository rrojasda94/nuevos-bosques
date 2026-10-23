# ADR 0004 — Tamaño de chunk, derrota y modos de partida

## Contexto
Respuestas del dueño del proyecto a las preguntas abiertas #10 y #11 (2026-10-23). Palabras textuales:

> "chunk de 64x64 y derrota es fallar la misión de la partida. Vamos a poder jugar con modo supervivencia, manteniendo con vida al Nujio (gran arbol); modo garelino, que trata de expandir la influencia de los nuevo bosques a la región; modo aventura, que se generan misiones para derrotar Únicos (monstruos defensores de bosques que se han descarriado y entrado en modo berserk) hay muchos tipos de Únicos y las villas suele llamar al adoc para combatirlos."

## Decisiones
| Tema | Decisión |
|---|---|
| Tamaño de chunk (#10) | **64×64 tiles.** La ubicación y tamaño de la ciudad dentro del chunk (propuesta anterior: centro, 24×16) **no se confirmó**; sigue abierta. |
| Derrota (#11) | **Fallar la misión de la partida.** Cada partida tiene una misión, que depende del modo elegido. |
| Modos de partida | Tres modos, cada uno con su misión (tabla siguiente). |

### Modos de partida
| Modo | Misión (según el dueño) | Derrota |
|---|---|---|
| **Supervivencia** | Mantener con vida al **Nujio** (gran árbol). | Fallar la misión (por definir qué significa exactamente; previsiblemente, que el Nujio muera). |
| **Garelino** | Expandir la influencia de los Nuevos Bosques a la región. | Fallar la misión (por definir). |
| **Aventura** | Se generan misiones para derrotar **Únicos** (monstruos defensores de bosques que se han descarriado y entrado en modo berserk). Hay muchos tipos de Únicos; las villas suelen llamar al **adoc** para combatirlos. | Fallar la misión (por definir). |

Condiciones de victoria, métricas y reglas concretas de cada modo: por definir (ver `0000-preguntas-abiertas.md`).

## Consecuencias
- Modifica ADR 0002: el "Objetivo de partida" ya no es únicamente "sobrevivir mientras el pueblo sobreviva"; ahora lo fija el modo de partida. La condición de derrota de ejemplo de ADR 0002 (población 0 / hambruna) queda sustituida por "fallar la misión".
- `GameState` deberá guardar el modo de partida y el estado de su misión (estructura: `engine-architect`).
- El chequeo de fin de día pasa a ser "chequeo de misión" en lugar de un chequeo genérico de derrota.
- `world-gen-dev` trabaja con chunks de 64×64 tiles; la reserva de espacio para la ciudad queda pendiente.
- `game-designer` debe redactar una ficha por modo en `docs/design/mechanics/` cuando se resuelvan las preguntas nuevas.
- `narrative-writer` es dueño del lore de Nujio, Garelino, Únicos y adoc; hasta que lo amplíe, solo vale lo citado arriba.
