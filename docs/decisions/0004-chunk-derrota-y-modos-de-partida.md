# ADR 0004 — Tamaño de chunk, derrota y modos de partida

> **Aviso (2026-10-24):** el [ADR 0014](0014-mundo-2-relieve-movimiento-libre-y-mundo-hibrido.md) **sustituye el tamaño de chunk**: 80×80 tiles desde la versión 0.4 (Mundo 2.0), a petición del dueño ("aumentar un poco el tamaño de los chunks"). La derrota y los modos siguen vigentes.

## Contexto
Respuestas del dueño del proyecto a las preguntas abiertas (2026-10-23), en dos rondas. Palabras textuales:

**Ronda 1 (#10, #11):**
> "chunk de 64x64 y derrota es fallar la misión de la partida. Vamos a poder jugar con modo supervivencia, manteniendo con vida al Nujio (gran arbol); modo garelino, que trata de expandir la influencia de los nuevo bosques a la región; modo aventura, que se generan misiones para derrotar Únicos (monstruos defensores de bosques que se han descarriado y entrado en modo berserk) hay muchos tipos de Únicos y las villas suele llamar al adoc para combatirlos."

**Ronda 2 (#14, #15, #16):** (el "[...]" es una omisión que ya venía en el texto recibido)
> "#14 el chunk puede tener o no tener una villa en su generación. Las villas son lugares de edificios pequeños que sirven como habitaciones para dormir o almacenar, el resto de estructuras de la villa son al aire libre. El Nujio esta por lo general en el centro de la vill y ocupa entre 6x6 y 8x8 de diametro, es un arbol gigantezco que tiene poder sobre el actuar de la villa. [...] #15 el modo se elige al empezar algo similar a project zomboid, pero el mapa se genera similar a minecraft o al juego enorme de enanos que demoro mucho tiempo en salir, no recuerdo el nombre. #16 para ganar en supervivencia no se puede, es un modo largo que debes evitar que los garelinos enloquezcan al nujio o que aniquilen el bosque. en modo aventura creas un personaje y este va viajando de lugar en lugar segun las misiones que aparezcan y debe ganar, si muere, es game over, pero sino va subiendo experiencia, aprendiendo habilidades, ganando objetos y fama, no puedes matar gente en lugares donde haya otras personas o seres que tengan consciencia. En modo garelino comandas un grupo de fanaticos que buscan destruir los bosques dominados por un nujio. Puedes mejorar tus tropas, aprender habilidades y estrategias para acelerar la decadencia, te enfrentas a los Humores del mundo que son climas agresivos que ocurren si delatas tu intension y ubicación, te enfrentas a los Únicos que evia el bosque y a la resistencia que ejerce la población de la villa, no se puede matar gente sino afecta grandemente la reputación de tu grupo y hace más dificil el trabajo o más agresivos y fuertes a los enemigos. Se vence eliminando al nujio y sembrando las primeras semillas de los nuevos bosques. En modo garelino pierdes si te quedas sin individuos. Puedes reclutar nuevos."

El "juego enorme de enanos" es **probablemente Dwarf Fortress, a confirmar**.

## Decisiones
| Tema | Decisión |
|---|---|
| Tamaño de chunk (#10) | **64×64 tiles.** |
| Villa en el chunk (#14) | El chunk **puede tener o no** una villa al generarse. La propuesta anterior de "ciudad central 24×16" no se confirmó. |
| Villas | Lugares de edificios pequeños que sirven como habitaciones para dormir o almacenar; el resto de estructuras de la villa están al aire libre. |
| Nujio | Árbol gigantesco. Por lo general está en el centro de la villa. Ocupa "entre 6x6 y 8x8 de diámetro" (unidad no dicha, previsiblemente tiles; ver #40). Tiene poder sobre el actuar de la villa. |
| Derrota (#11) | **Fallar la misión de la partida.** Concretado por modo en la tabla siguiente. |
| Elección de modo (#15) | El modo **se elige al empezar** la partida, de forma similar a Project Zomboid. |
| Generación del mapa | "Similar a Minecraft o a Dwarf Fortress (a confirmar)". **Posible conflicto con ADR 0003, sin resolver**: ver pregunta #27. |

### Modos de partida
| Modo | Qué hace el jugador | Victoria | Derrota |
|---|---|---|---|
| **Supervivencia** | Mantener con vida al Nujio. Modo largo. Debe evitar que los garelinos enloquezcan al Nujio o aniquilen el bosque. | **No hay victoria.** | Los garelinos enloquecen al Nujio o aniquilan el bosque. |
| **Garelino** | Comanda un grupo de fanáticos (garelinos) que buscan destruir los bosques dominados por un Nujio. Puede mejorar sus tropas, aprender habilidades y estrategias para acelerar la decadencia, y reclutar nuevos individuos. Se enfrenta a los Humores del mundo, a los Únicos que envía el bosque y a la resistencia de la población de la villa. | Eliminar al Nujio y sembrar las primeras semillas de los Nuevos Bosques. | Quedarse sin individuos. |
| **Aventura** | Crea un personaje que viaja de lugar en lugar según las misiones que aparezcan (misiones para derrotar Únicos; las villas suelen llamar al adoc para combatirlos). Sube experiencia, aprende habilidades, gana objetos y fama. | Por definir ("debe ganar"; ver #31). Es un survival (nota de abajo). | La muerte del personaje es game over **si el monstruo es fatal** (nota "Derrota en Aventura"). |

### Nota: Garelino dentro de Aventura (ADR 0015, 2026-10-25)
El modo **Garelino** deja de ser solo un modo aparte: pasa a ser un **camino dentro de Aventura**, al que el adoc llega según su Senda y un encuentro de historia con los garelinos (ADR 0015, `docs/design/mechanics/dos-caminos.md`). El modo suelto queda, para más adelante, como "empezar ya en el bando garelino".

### Nota: derrota en Aventura (2026-10-23)
Respuesta del dueño a la #126 ("si fallar un encargo no acaba la partida, ¿cuál es la misión de la partida en Aventura?"):

> "es un survival, deberia ser game over dependiendo del monstruo que te ataque, un iserald es fatal."

- **Aventura es un survival.** No hay una "misión de la partida" aparte: los encargos de villa (por ejemplo, el del Ofomni) pueden fallar sin que la partida acabe.
- **Que perder sea game over depende del monstruo que te vence.**
  - Regla provisional para el código: cada tipo de Único tiene `fatal: bool`.
  - Perder contra uno **fatal** es **game over**: la partida termina y se empieza otra.
  - Perder contra uno **no fatal**: despiertas en la villa natal (regla de v1).
- **Iserald es fatal** siempre (todavía no existe en el juego).
- **Provisional, a confirmar**: los Únicos comunes de borde y el Ofomni de la primera misión **no son fatales**, porque es la primera misión y una versión de prueba.
- Esto matiza la fila "Aventura" de la tabla de arriba: "la muerte del personaje es game over" vale solo contra monstruos fatales.
- Qué otros monstruos son fatales: #127.

**Actualización (2026-10-24).** Palabras del dueño: "El ofomni es no fatal en la primera mision. Aledras son fatales en las noches. Aun no tenemos más monstruos."
- El Ofomni **no es fatal en la primera misión**: confirmado.
- **Aledra es fatal de noche** (Momento de Riumna) y no fatal de día.
- La regla `fatal: bool` pasa a ser **fatal según el Momento**: campo `fatal_at` con la lista de Momentos en los que perder es game over (`[]` nunca, `["riumna"]` solo de noche, `["gietos", "riumna"]` siempre). Cuenta el Momento en que empieza el combate.
- Iserald: `["gietos", "riumna"]`.
- Detalle en `docs/design/mechanics/monstruos.md`.

### Reglas de no matar
- **Aventura**: no se puede matar gente en lugares donde haya otras personas o seres con consciencia.
- **Garelino**: matar gente afecta mucho a la reputación del grupo y hace más difícil el trabajo, o vuelve a los enemigos más agresivos y fuertes.

### Términos introducidos
El lore de estos términos lo fija `docs/glosario_nuevos_bosques.md`, que es la fuente de verdad y no se edita. Aquí solo figura lo que el dueño dijo en el chat como **regla de juego**.
- **Garelinos**: en el juego, el grupo de fanáticos que buscan destruir los bosques dominados por un Nujio. "Expandir los Nuevos Bosques" (ronda 1) consiste en eliminar al Nujio y sembrar las primeras semillas. En Supervivencia son el enemigo. El glosario no tiene una entrada "garelino". Que sean seguidores de Garel/Gael Estrella Azul (glosario §7) es una deducción, **a confirmar**.
- **Humores del mundo**: en Garelino aparecen como climas agresivos si el grupo delata su intención y su ubicación. Lore: glosario §2.
- **Únicos**: en Aventura son el objetivo de las misiones y en Garelino los envía el bosque. Lore: glosario §3 (anticuerpos del Bosque; subtipos Iserald, Aledra, Ofomni).
- **Villa, Nujio, adoc**: lore en el glosario, §5, §3 y §5 (Oficios) respectivamente.

Lo que no está ni en las citas ni en el glosario se queda por definir (ver `0000-preguntas-abiertas.md`).

### Conciliación con el glosario (2026-10-23)
Hay puntos en los que lo que el dueño dijo en el chat no cuadra con el glosario. No están resueltos; las preguntas están en `0000-preguntas-abiertas.md`.
- Villa: según el chat, sus edificios sirven "para dormir o almacenar"; según el glosario, la villa "no almacena comida" (#47).
- Grafía Garel / Gael (glosario, inconsistencias), que afecta al nombre del modo Garelino (#46).
- Humores: en el chat son "climas agresivos"; en el glosario, "no necesariamente malas" (#52).
- Personaje de Aventura: según el glosario, los adoc son los "únicos especialistas en armas", y los personajes jugables son lenfi, ueutrec o kulvar "con el oficio que se desee". Pero los ueutrec "no tienen oficios" (#49).

## Consecuencias
- Modifica ADR 0002: el "Objetivo de partida" ya no es "sobrevivir mientras el pueblo sobreviva". Lo fija el modo, y la derrota de ejemplo (población 0 / hambruna) queda sustituida.
- **Posible conflicto con ADR 0003** (mapa mundial hecho a mano + un chunk procedural por partida):
  - "el mapa se genera similar a minecraft o dwarf fortress" puede implicar que el mundo entero se genera (#27).
  - "viaja de lugar en lugar" en Aventura puede implicar varios chunks por partida (#30).
  - Nada de esto está resuelto; ADR 0003 sigue vigente hasta que se decida.
- **Posible tensión con el pilar 1 y ADR 0002** (ciudad por días + RPG): ninguno de los tres modos describe gestión de ciudad. Su relación con las dos capas está por definir (#29).
- La ciudad del GDD (grid 16×16, hoguera en el centro) pasa a revisarse frente a villas y Nujio (#14b).
- `GameState` deberá guardar el modo y el estado de la misión (estructura: `engine-architect`).
- Hay recursos nuevos (fama, reputación, tropas/individuos) que necesitan fuente, sumidero y efecto al agotarse antes de implementarse (`game-designer`).
- El lore lo fija `docs/glosario_nuevos_bosques.md` (del dueño del proyecto; no se edita). El GDD enlaza a él en vez de duplicarlo. `narrative-writer` trabaja a partir de ese archivo.
