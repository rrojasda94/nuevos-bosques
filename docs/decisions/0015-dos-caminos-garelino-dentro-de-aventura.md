# ADR 0015 — Dos caminos: Garelino dentro de Aventura

> Modifica ADR 0004 (modos de partida). Mecánicas en `docs/design/mechanics/dos-caminos.md`. Hoja de ruta: `docs/design/roadmap-0.5.md`.

## Contexto
ADR 0004 definía tres modos separados: Supervivencia, Garelino y Aventura. El dueño propone (2026-10-25):

> "podriamos unir el modo garelino aqui mismo. Porque hariamos que dependiendo del camino del adoc, podria ser un detractor de los bosques y tomar parte de los nuevos bosques. Puedes juntar tu grupo y tratar de convenser a las villas para unirse a los nuevos bosqes."

Respuestas a las preguntas del coordinador:
- **Cambio de bando**: "es gradual, pero puede haber un momento de la historia que te cruzas con los garelinos y te invitan a unirte o tu a ellos."
- **Volver atrás**: sí, con un gran costo.
- **Convencer villas**: cuatro vías: resolver su necesidad, diálogo y argumentos, la fuerza del grupo (intimidar o proteger sin matar, con efecto en la reputación) y las Piedras de los Nuevos Bosques como regalo.

## Decisión
- **Garelino pasa a ser un camino dentro de Aventura**. El adoc puede pasar de **fiel** a **garelino** según su Senda (`moralidad-y-progresion.md`) y tras un **encuentro de historia** con los garelinos.
- Como garelino reúne un **grupo**, **persuade villas** y **siembra Piedras de los Nuevos Bosques**. Puede **volver** con una redención muy cara.
- **El modo Garelino suelto** de ADR 0004 queda como una opción de inicio para más adelante: **"empezar ya en el bando garelino"**. No es un modo aparte con otras reglas.
- La regla de **no matar gente** (ADR 0004) vale en los dos caminos: todos los combates entre personas son no letales.
- La 0.5 se llama **"Dos caminos"** y combina "Los otros adoc" con este camino (`roadmap-0.5.md`).

## Respuestas del dueño (2026-10-25)
> "1. por ahora no se cuales podrian ser las historias. Centremonos en mecanicas, jugabilidad, desarrollo de personaje y de ahi buscamos crear la historia del juego. 2. siembras nuevos bosques donde los bosques de nujio ya no están, puedes mandar o talar tu mismo el bosque cuando el nujio ya murio. 3. si, se vuelve magra. Los nuevos y viejos bosques no son compatibles. 4. los ledai en esta era son como profetas, al menos los ledai de la tarca de trastas que es donde esta Garel/estrellazul. Pero igual en la historia cualquiera puede convertirse en garelino y seguir a los ledai. 5. No 6. Ok"

| Tema | Decisión |
|---|---|
| Historia | **En pausa**. Prioridad: mecánicas, jugabilidad y desarrollo de personaje. `docs/design/historia/` queda como **borrador aparcado, no canon**, y los finales con hitos quedan aparcados (#167). |
| Siembra | Solo **donde el Bosque de Nujio ya no está**: con el Nujio muerto, se **tala** el Bosque (tú o tu grupo) y luego se **siembra**. Se elimina la siembra junto a un Nujio debilitado. |
| Magra | El adoc que se une a los Nuevos Bosques se vuelve **magra**: los Bosques viejos y nuevos no son compatibles. |
| Ledai | En esta era son como **profetas**, al menos los de la Tarca de Trastas, donde está Garel / Estrella Azul. Cualquiera puede hacerse garelino y seguirlos. |
| Nombres | **No aprobados** (Oridna, Urdan, Avessa, Tiunel). Se usan roles genéricos hasta que el dueño ponga nombres. |
| Hoja de ruta | **Confirmado**: la 0.5 se llama "Dos caminos", con el orden propuesto; los artesanos y el Iserald pasan a la 0.6. |

## Consecuencias
- ADR 0004: la fila "Garelino" de la tabla de modos queda acotada por este ADR. Las condiciones originales del modo (vence eliminando al Nujio y sembrando las primeras semillas; pierde al quedarse sin individuos) inspiran los objetivos del camino garelino (`dos-caminos.md`, "Finales").
- Nuevo recurso: **Piedras de los Nuevos Bosques** (glosario §6 y §7), con fuente, sumidero y agotamiento en la ficha.
- Las fichas de NPC, otros adoc, monstruos y Senda se enlazan con los bandos.
- Pendiente del dueño: los finales, el trato de los Bosques a un garelino, quedarse sin miembros, la redención y la villa natal (`0000-preguntas-abiertas.md`, #167–#171).
