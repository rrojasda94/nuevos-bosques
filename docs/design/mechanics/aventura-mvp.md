# Ficha: Modo Aventura — alcance del primer vertical slice

> Dueño: `game-designer`. Fuentes: ADR 0004, ADR 0005, ADR 0007, ADR 0008. Estado: v0.3.
> Aquí solo hay cosas ya decididas por el dueño. Lo demás está en "Siguiente iteración" con su pregunta abierta.

## Objetivo
Según el dueño: **probar los controles y que sea divertido** (ADR 0005). El slice no busca un loop completo de Aventura. Busca validar el movimiento y la exploración de un Bosque generado.

## Feedback de playtest del dueño
| Versión | Feedback | Acción |
|---|---|---|
| v1 | "la velocidad está bien" (ADR 0007). | Mantener la velocidad. |
| v2 (árboles transitables, riscos como paredes) | "el bosque está muy tupido y no hay mucho espacio para caminar entre los árboles"; "me gustaba más el tipo de bosque anterior del que no podías caminar entre los árboles"; "las paredes sí se notan muy falsas. No adecuadas." Le gustan los arroyos y los ríos (ADR 0008). | Árboles que bloquean, como en la v1, con más espacio para caminar entre ellos (confirmado por el dueño, ADR 0008). Rehacer los riscos (#84). Mantener los arroyos. Ríos continuos con pasos (#88). |
| v3 | "ya lo siento mejor al bosque" (ADR 0008, nota de respuestas al mapa). | Mantener la dirección de la v3. Siguen abiertos los riscos (#84), los tipos de árbol (#86) y los pasos de río (#88). |

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
- Escala espacial (ADR 0007, 0008): **chunk < Bosque < área < subregión < región < Sur Lenfi**. El nivel "Bosque" se llamaba antes "zona"; "subregión" es nombre propuesto (#100).
- Cada chunk mide **64×64 tiles** (ADR 0004). Un Bosque tiene **de 4 a 16 chunks** (ADR 0007). La **forma y el número** de chunks se generan **aleatoriamente** con la seed; no tiene por qué ser cuadrado (ADR 0008). Se asume que los chunks son contiguos.
- Región: **Valle del Sara** (ADR 0007). El jugador elige el área de origen (ADR 0008), pero en el slice es un área fija sin pantalla de elección (#92). Las 7 áreas del mapa y sus vecinos están en [`../world/sur-lenfi.md`](../world/sur-lenfi.md).
- Aspecto del Bosque inicial (con Nujio): **un solo tipo de árbol** y una **combinación de colores definida por su Nujio**, siempre con los **32 colores de la paleta del proyecto** (ADR 0008). Dentro del slice basta un tipo de árbol y una combinación, generados por seed (#86).
- El Nujio está en el **centro del Bosque**, en su chunk más central; si hay villa, la villa ocupa ese chunk y el Nujio está en su centro (ADR 0008). En el slice, el Nujio puede ser un placeholder en ese chunk, o no aparecer.
- Cada chunk se genera **al entrar por primera vez**, a partir de la seed de la partida y de su posición en la jerarquía (región, área, Bosque, chunk) (ADR 0005, 0007).
- El slice cubre **un solo Bosque inicial**. Salir a otro Bosque, área o región queda para la siguiente iteración.

### 3. Terreno
- **Árboles**: **bloquean**, como en la v1, **con más espacio para caminar entre ellos** (ADR 0008, confirmado; sustituye lo dicho en ADR 0007).
- **Otras barreras físicas**: agua, riscos y pendientes pronunciadas (ADR 0007). Los riscos de la v2 no sirven visualmente (#84).
- **Ríos**: deben ser **continuos** y tener **zonas de paso** (ADR 0008). Los arroyos actuales le gustan al dueño. Los ríos grandes son navegables y los estrechos o de montaña no (ADR 0007), pero la navegación no entra en el slice (#74): se cruzan por las zonas de paso (#88).
- Relieve del Valle del Sara: más agreste al norte y más plano, con claros ribereños, al sur. Norte arriba en la imagen del mapa (ADR 0007, 0008). Según el mapa (`docs/design/world/Sur-Lenfi_02.jpg`): subregiones Lean, Causie, Tossie y Alss al norte; Ostie y Vastie (muy montañosa) en el centro; Cassie al sur, en la costa, cruzada por el río Sara. Si el área fija del slice es de una subregión del norte, el terreno debería ser más agreste; si es de Cassie, más llano y con claros ribereños.

### 4. Movimiento dentro del Bosque
- Movimiento **libre** entre los chunks del Bosque inicial (ADR 0007). Para el slice se propone el paso por el borde al chunk adyacente del mismo Bosque.
- El límite con un Bosque vecino se reconoce por el **color de la vegetación** (ADR 0008). En el slice, el borde del Bosque inicial puede mostrar la vegetación del vecino, con otra combinación de colores, aunque no se pueda cruzar.

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
- Chunk con un río que lo atraviesa entero: los ríos tienen zonas de paso (ADR 0008), así que todos los chunks del Bosque inicial deben ser alcanzables a pie.
- Árboles que bloquean demasiado: no debe quedar ninguna parte del Bosque inaccesible por culpa de los árboles (propuesta de game-designer).
- Volver a un chunk tras visitar muchos: tiene que seguir como el jugador lo dejó.
- Misma seed y mismo chunk en dos partidas: la generación base es idéntica (determinismo, ADR 0003).
- Seed distinta: chunk distinto.

## Criterios de éxito para playtest
Propuesta de `game-designer`, a confirmar con el dueño:
- Volver a 3 chunks ya visitados: los 3 están como el jugador los dejó (0 diferencias no causadas por el jugador).
- Dos partidas con seeds distintas producen el mismo lugar de forma visiblemente diferente.
- El jugador cruza a un chunk adyacente sin ayuda en su primer intento.
- El dueño juzga que el espacio entre árboles bloqueantes permite caminar con comodidad y que los riscos no "se notan falsos" (pregunta directa).
- Todos los chunks del Bosque inicial son alcanzables a pie (cruzando los ríos por sus pasos).
- Un observador distingue a simple vista dónde termina el Bosque inicial y empieza el vecino (color de la vegetación).
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
| Viaje a pie y cansancio | Se puede recorrer todo el mapa a pie; es más lento y cansa al personaje (ADR 0007). Ir a pie también cuesta, pero da más control sobre el gasto y el riesgo (ADR 0008). | #73, #91 |
| Villas | 1 de cada 5 Bosques tiene villa, dentro de un solo chunk. Hay letreros de piedra en algunos caminos que indican hacia una villa (ADR 0008). | #14b, #47, #50, #87 |
| Variedad de Bosques | Cada Bosque con Nujio tiene un tipo de árbol y una combinación de colores propia (dentro de la paleta de 32); los Nuevos Bosques se parecen a los de nuestro mundo (ADR 0008). | #61, #86 |
| Mapa de la región | Sirve para viajar distancias largas (ADR 0005). | #56, #91 |
| Navegación | Ríos grandes navegables; estrechos y de montaña no (ADR 0007). | #74 |
| Día y noche | Momento de Gietos y Momento de Riumna, con peligros distintos; hay Bosques donde no se puede andar de noche (ADR 0007). | #75, #60 |
| Peligros de regiones desconocidas | Bosques agresivos, Únicos poderosos, etc. (ADR 0005). | #56, #58 |
| Elección de origen | Región de origen elegida; da conocimiento de su área y sus Bosques; cuanto más lejos, más difícil el viaje (ADR 0005). MVP: Valle del Sara (ADR 0007); el área de origen también se elige (ADR 0008). | #66, #92, #56, #57 |
| Nuevos Bosques | Frecuencia por subregión: alta en Lean, Tossie y Ostie; muy rara en Nosie; casi imposible en Alciss, la más alejada (ADR 0007, 0008). | #70, #78 |
| Cambio con el tiempo | Lo orgánico crece o desaparece y la gente se mueve si pasa mucho tiempo (ADR 0005). | #65 |
