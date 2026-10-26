# ADR 0016 — Combate táctico en cuadrícula (estilo Final Fantasy Tactics Advance)

> Ficha de mecánica: `docs/design/mechanics/combate-tactico.md`. Revisión de la IA: `docs/design/mechanics/ia-de-combate.md`.

## Contexto
- ADR 0002 fijó: "Combate: Por turnos, por menú (Atacar / Habilidad / Objeto / Huir). **Sin grid táctico**."
- ADR 0009 y su v1.1 implementaron un combate por menú en una escena superpuesta, con narración mensaje a mensaje "estilo Pokémon".
- El PR #67 añadió la IA de combate en grupo: iniciativa por AGI, filas, roles y órdenes.

El dueño (2026-10-26):

> "algo que estas olvidando con lo de los combates es que tiene que ser como final fantasi advance de GBA esta super genial esa manera de combatir. mejor que la de estilo pokemon como ahora."

Y al preguntarle:

> "FF Tactics Advance, si. Pero que los stats igual influyen en la distancia que se pueden mover, el estivar, el atacar por sorpresa, el turno que le corresponde, etc."

## Decisión
- El combate pasa a ser **táctico por turnos en una cuadrícula**, al estilo de *Final Fantasy Tactics Advance* (GBA):
  - cada combatiente **se mueve** por un tablero, **actúa** y elige **orientación**;
  - posición, altura y orientación importan.
- **Los stats influyen** (dueño):
  - distancia de movimiento (Mov, derivado de AGI);
  - evasión (AGI, orientación y altura);
  - ataque por sorpresa (sigilo y visión);
  - orden de turno (AGI);
  - etcétera.
- Sustituye la **presentación** "estilo Pokémon" de ADR 0009 y el "sin grid táctico" de ADR 0002. Se conservan:
  - las reglas de economía y memoria (Ofrecer Luz u ofrenda paga y termina la pelea, el Bosque recuerda, la hostilidad y la relación, la XP, los fatales, la reaparición y la regla de no matar);
  - la IA del PR #67, traducida a la cuadrícula.
- **Vista (decisión del dueño)**: "vista desde arriba con las alturas por capas". Es cenital (top-down), con el mismo relieve en capas estilo Zelda del Mundo 2.0 (ADR 0014). No isométrica.
- El **tablero** (8 × 6) sale del terreno donde empieza el combate, con su relieve del Mundo 2.0 cuando exista.

## Respuestas del dueño (formulario)
| # | Respuesta | Decisión |
|---|---|---|
| #184 | "Cualquier borde, seguro" | Se huye desde **cualquier casilla del borde** del tablero, siempre con éxito. |
| #185 | "Más chico, 3 por bando" | Tablero de **8 × 6** y **hasta 3 por bando**, sin refuerzos. Reparep en grupos de 2–3. Latigazo múltiple en área de 3 × 1. |
| #186 | "Textos cortos y números" | Números de daño flotando y una línea corta con el nombre de la acción. Se acaba la narración mensaje a mensaje. |
| #187 | "Sí, todos" | **Todos** los combates van en tablero, también el 1 contra 1. |

**Alturas** (dato de la sesión del Mundo 2.0):
- El mundo tiene **niveles 0–3** (ADR 0014 §3), y las caras de risco ocupan 2 filas por nivel.
- En el tablero se eligen recortes con como mucho 2 niveles de diferencia, y las caras se **comprimen** a un salto de altura entre casillas vecinas.
- El recorte se pide con la consulta pura `WorldQuery.rect` que ofrece esa sesión.

## Consecuencias
- Cambio grande en `rpg-systems-dev` (lógica pura de tablero, turnos y movimiento, con tests), `ui-ux-dev` (escena de combate nueva) y `pixel-artist` (sprites de combate en 4 direcciones). El tablero desde el relieve depende de `world-gen-dev` y de la sesión del Mundo 2.0.
- Plan de PR pequeños en `combate-tactico.md` y en `roadmap-0.5.md`. Va antes de los garelinos y del grupo garelino, que lo usan.
- ADR 0002 y ADR 0009 se anotan con este cambio.
- Las partidas guardadas no cambian: el combate no se guarda a mitad.
