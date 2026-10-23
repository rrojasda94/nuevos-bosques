# Ficha: Modo Aventura — alcance del primer vertical slice

> Dueño: `game-designer`. Fuentes: ADR 0004, ADR 0005. Estado: v0.1.
> Aquí solo hay cosas ya decididas por el dueño. Lo demás está en "Siguiente iteración" con su pregunta abierta.

## Objetivo
Según el dueño: **probar los controles y que sea divertido** (ADR 0005). El slice no busca un loop completo de Aventura. Busca validar moverse y explorar zonas generadas.

## Pilares
- **Pilar 4** (cada partida es distinta, cada región se reconoce): las zonas se generan con la seed de la partida.
- **Pilar 3** (legibilidad 8-bit): exploración top-down.

## Presión de supervivencia
Ninguna en este slice. Las presiones de Aventura (muerte = game over, Luz de viaje, Únicos, peligros de regiones desconocidas) entran en la siguiente iteración.

## Alcance del slice

### 1. Personaje
- El jugador controla **un personaje**. En este slice es **fijo**: sin pantalla de creación (ADR 0004 dice que en Aventura "creas un personaje"; la creación se pospone).
- Raza, oficio, stats y sprite: placeholder (ver #49 y #32).

### 2. Escala y chunks
- Escala espacial (ADR 0005, respuestas): **chunk < zona < área < región < Sur Lenfi**. Una zona contiene varios chunks; cuántos, por definir (#62).
- Cada chunk mide **64×64 tiles** (ADR 0004).
- Se genera **al entrar por primera vez**, a partir de la seed de la partida y de su posición en la jerarquía (región, área, zona, chunk) (ADR 0005).
- Una zona nueva puede ser una villa, un bosque o una "geografía" (ADR 0005). Qué determina el tipo y si se decide por zona o por chunk: por definir (#61, #62). En el slice basta con un tipo, que elige `world-gen-dev`.
- Solo se juega en la parte suroccidental de Nardaram. Qué regiones: por definir (#64).
- El slice cubre **una sola zona** de una sola región. Viajar entre zonas, áreas o regiones queda para la siguiente iteración.

### 3. Movimiento entre chunks (dentro de una zona)
- El personaje pasa a chunks adyacentes de la misma zona (ADR 0005: "en aventura y garelino si puedes viajar entre chunks"). La forma de paso está pendiente de confirmar (#63). Para el slice se propone el paso por el borde al chunk adyacente.

### 4. Persistencia en la partida
- Si el jugador vuelve a un chunk ya visitado en la misma partida, lo encuentra **tal como lo dejó**, con sus cambios (ADR 0005, respuestas #54).
- En una partida nueva (seed distinta), ese mismo lugar se genera de forma diferente.
- Cambios con el paso de mucho tiempo (crecimiento o desaparición de elementos orgánicos, movimiento de la gente): fuera del slice (#65).
- Implicación técnica: no basta con regenerar desde la seed. Hay que guardar los cambios del jugador sobre lo generado. El formato lo deciden `engine-architect` y `world-gen-dev`.

## Inputs / outputs
- **Inputs:** seed de partida, identificadores de región, área, zona y chunk, movimiento del jugador, cambios del jugador en el chunk.
- **Outputs:** chunk generado (determinista con los mismos inputs) más los cambios guardados, posición del personaje, registro de chunks visitados en la partida.

## Interacción con otros sistemas
- `world-gen-dev`: generación de la zona.
- `engine-architect`: transición entre zonas y guardado de las zonas visitadas.
- `rpg-systems-dev`: personaje y movimiento.
- No interviene la capa ciudad ni el combate en este slice.

## Casos límite
- Llegar al borde de la zona: por definir (#62, #63). En el slice el borde de la zona es un límite que no se puede cruzar.
- Volver a un chunk tras visitar muchos: tiene que seguir como el jugador lo dejó.
- Misma seed y mismo chunk en dos partidas: la generación base es idéntica (determinismo, ADR 0003).
- Seed distinta: chunk distinto.

## Criterios de éxito para playtest
Propuesta de `game-designer`, a confirmar con el dueño:
- Volver a 3 chunks ya visitados: los 3 están como el jugador los dejó (0 diferencias no causadas por el jugador).
- Dos partidas con seeds distintas producen el mismo lugar de forma visiblemente diferente.
- El jugador cruza a un chunk adyacente sin ayuda en su primer intento.
- El jugador dice que moverse "se siente bien" (pregunta directa tras la sesión). Es el objetivo explícito del dueño.

## Siguiente iteración (no decidido)
| Elemento | Qué se sabe | Preguntas |
|---|---|---|
| Creación de personaje | Se "crea un personaje" (ADR 0004). El glosario §9 cita lenfi, ueutrec y kulvar como jugables. | #49, #32 |
| Combate contra Únicos | Las misiones son para derrotar Únicos; el combate es por menú y por turnos (ADR 0002). | #22b, #34, #51 |
| Misiones | Aparecen y hacen viajar de lugar en lugar; las villas llaman al adoc. | #20, #21, #31 |
| Muerte | Game over (ADR 0004). | #21 |
| Progresión | Experiencia, habilidades, objetos, fama (ADR 0004). | #33 |
| Luz de viaje | Quedarse sin Luz es un riesgo del viaje (ADR 0005). | #57 |
| Mapa de la región | Sirve para viajar distancias largas (ADR 0005). | #56 |
| Peligros de regiones desconocidas | Bosques agresivos, Únicos poderosos, etc. (ADR 0005). | #56, #58 |
| Tiempo | Si en Aventura se avanza por días. | #60 |
| Viaje entre zonas, áreas y regiones | Escala chunk < zona < área < región < Sur Lenfi (ADR 0005). | #62, #63 |
| Elección de región de origen | El jugador la elige; da conocimiento automático del área y sus zonas. El viaje es más complicado cuanto más lejos del punto inicial (ADR 0005). | #64, #66, #68, #56, #57 |
| Cambio de zonas con el tiempo | Lo orgánico crece o desaparece y la gente se mueve si pasa mucho tiempo (ADR 0005). | #65 |
