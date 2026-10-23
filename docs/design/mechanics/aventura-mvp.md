# Ficha: Modo Aventura — alcance del primer vertical slice

> Dueño: `game-designer`. Fuentes: ADR 0004, ADR 0005, ADR 0007. Estado: v0.2.
> Aquí solo hay cosas ya decididas por el dueño. Lo demás está en "Siguiente iteración" con su pregunta abierta.

## Objetivo
Según el dueño: **probar los controles y que sea divertido** (ADR 0005). El slice no busca un loop completo de Aventura. Busca validar el movimiento y la exploración de un Bosque generado.

Feedback del dueño sobre el prototipo (ADR 0007): "la velocidad está bien".

## Pilares
- **Pilar 4** (cada partida es distinta, cada región se reconoce): los Bosques se generan con la seed de la partida; la región Valle del Sara mantiene su identidad.
- **Pilar 3** (legibilidad 8-bit): exploración top-down.

## Presión de supervivencia
Ninguna en este slice. Las presiones de Aventura (muerte = game over, Luz, Únicos, cansancio, peligros de día y de noche, regiones desconocidas) entran en la siguiente iteración.

## Alcance del slice

### 1. Personaje
- El jugador controla **un personaje**. En este slice es **fijo**: sin pantalla de creación (ADR 0004 dice que en Aventura "creas un personaje"; la creación se pospone).
- Raza, oficio, stats y sprite: placeholder (ver #49 y #32).

### 2. Escala y Bosque inicial
- Escala espacial (ADR 0007): **chunk < Bosque < área < región < Sur Lenfi**. (El nivel "Bosque" se llamaba antes "zona".)
- Cada chunk mide **64×64 tiles** (ADR 0004). Un Bosque tiene **de 4 a 16 chunks** (ADR 0007). El número exacto dentro de ese rango y la forma en que se unen los chunks: por definir (#76). En el slice lo decide `world-gen-dev`, dentro del rango.
- Región: **Valle del Sara** (ADR 0007). Área de origen: por definir (#81). En el slice, un área fija que elige `world-gen-dev`.
- Cada chunk se genera **al entrar por primera vez**, a partir de la seed de la partida y de su posición en la jerarquía (región, área, Bosque, chunk) (ADR 0005, 0007).
- El slice cubre **un solo Bosque inicial**. Salir a otro Bosque, área o región queda para la siguiente iteración.

### 3. Terreno
- Los bosques son tupidos, pero **se puede caminar entre los árboles**: los árboles no bloquean (ADR 0007).
- **Barreras físicas**: agua, riscos y pendientes pronunciadas (ADR 0007).
- Relieve del Valle del Sara: más agreste al norte; el sur es más plano, con algunos claros ribereños (ADR 0007). Qué áreas son del norte o del sur: #80.
- Ríos: los grandes son navegables; los pegados a las montañas y los estrechos no (ADR 0007). La navegación no entra en el slice (#74): en él, toda el agua es barrera.

### 4. Movimiento dentro del Bosque
- Movimiento **libre** entre los chunks del Bosque inicial (ADR 0007). La forma de paso entre chunks está pendiente de confirmar (#76). Para el slice se propone el paso por el borde al chunk adyacente del mismo Bosque.

### 5. Persistencia en la partida
- Si el jugador vuelve a un chunk ya visitado en la misma partida, lo encuentra **tal como lo dejó**, con sus cambios (ADR 0005, respuestas #54).
- En una partida nueva (seed distinta), ese mismo lugar se genera de forma diferente.
- Cambios con el paso de mucho tiempo (lo orgánico crece o desaparece, la gente se mueve): fuera del slice (#65).
- Implicación técnica: hay que guardar los cambios del jugador sobre lo generado. El formato lo deciden `engine-architect` y `world-gen-dev`.

## Inputs / outputs
- **Inputs:** seed de partida, identificadores de región, área, Bosque y chunk, movimiento del jugador, cambios del jugador en el chunk.
- **Outputs:** chunk generado (determinista con los mismos inputs) más los cambios guardados, posición del personaje, registro de chunks visitados en la partida.

## Interacción con otros sistemas
- `world-gen-dev`: generación del Bosque y sus chunks (terreno, barreras).
- `engine-architect`: transición entre chunks y guardado de los chunks visitados.
- `rpg-systems-dev`: personaje y movimiento.
- No intervienen la capa ciudad, el combate, la Luz ni el ciclo día/noche en este slice.

## Casos límite
- Llegar al borde del Bosque inicial: en el slice es un límite que no se puede cruzar. En el juego completo, entrar a otro Bosque con Nujio cuesta Luz o un enfrentamiento con Únicos (#70, #71).
- Chunk con una barrera que lo atraviesa entero (por ejemplo, un río): por definir. Propuesta para `world-gen-dev`: que todos los chunks del Bosque inicial sean alcanzables a pie, porque la navegación no está en el slice.
- Volver a un chunk tras visitar muchos: tiene que seguir como el jugador lo dejó.
- Misma seed y mismo chunk en dos partidas: la generación base es idéntica (determinismo, ADR 0003).
- Seed distinta: chunk distinto.

## Criterios de éxito para playtest
Propuesta de `game-designer`, a confirmar con el dueño:
- Volver a 3 chunks ya visitados: los 3 están como el jugador los dejó (0 diferencias no causadas por el jugador).
- Dos partidas con seeds distintas producen el mismo lugar de forma visiblemente diferente.
- El jugador cruza a un chunk adyacente sin ayuda en su primer intento.
- El jugador camina entre los árboles y solo choca con agua, riscos o pendientes.
- El jugador dice que moverse "se siente bien" (pregunta directa tras la sesión). Es el objetivo explícito del dueño.

## Siguiente iteración (no decidido)
| Elemento | Qué se sabe | Preguntas |
|---|---|---|
| Creación de personaje | Se "crea un personaje" (ADR 0004). El glosario §9 cita lenfi, ueutrec y kulvar como jugables. | #49, #32 |
| Combate contra Únicos | Las misiones son para derrotar Únicos; el combate es por menú y por turnos (ADR 0002). Los Únicos también guardan la entrada a otros Bosques (ADR 0007). | #22b, #34, #51, #71 |
| Misiones | Aparecen y hacen viajar de lugar en lugar; las villas llaman al adoc. | #20, #21, #31 |
| Muerte | Game over (ADR 0004). | #21 |
| Progresión | Experiencia, habilidades, objetos, fama (ADR 0004). | #33 |
| Salir del Bosque inicial | A un Bosque con Nujio: pagar Luz o enfrentarse a sus Únicos. Sin Nujio: por definir (ADR 0007). | #70, #71 |
| Luz | Recurso de viaje y peaje entre Bosques (ADR 0005, 0007). | #57, #71 |
| Viaje a pie y cansancio | Se puede recorrer todo el mapa a pie; es más lento y cansa al personaje (ADR 0007). | #72, #73 |
| Mapa de la región | Sirve para viajar distancias largas (ADR 0005). | #56, #72 |
| Navegación | Ríos grandes navegables; estrechos y de montaña no (ADR 0007). | #74 |
| Día y noche | Momento de Gietos y Momento de Riumna, con peligros distintos; hay Bosques donde no se puede andar de noche (ADR 0007). | #75, #60 |
| Peligros de regiones desconocidas | Bosques agresivos, Únicos poderosos, etc. (ADR 0005). | #56, #58 |
| Elección de origen | Región de origen elegida; da conocimiento de su área y sus Bosques; cuanto más lejos, más difícil el viaje (ADR 0005). MVP: Valle del Sara (ADR 0007). | #66, #81, #56, #57 |
| Nuevos Bosques | Frecuencia por área: alta en Lean, Tossie y Ostie; muy rara en Nosie; casi imposible en Alciss (ADR 0007). | #69, #70, #77, #78 |
| Cambio con el tiempo | Lo orgánico crece o desaparece y la gente se mueve si pasa mucho tiempo (ADR 0005). | #65 |
