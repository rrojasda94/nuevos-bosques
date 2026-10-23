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

### 2. Zonas (chunks)
- Cada zona es un chunk de **64×64 tiles** (ADR 0004). Que zona y chunk sean lo mismo está pendiente de confirmar (#55).
- La zona se **genera al entrar en ella** por primera vez, a partir de la seed de la partida, la región del mapa fijo y el identificador de la zona (ADR 0005).
- Una zona nueva puede ser una villa, un bosque o una "geografía" (ADR 0005). Qué determina el tipo está por definir (#61). En el slice basta con un tipo, que elige `world-gen-dev`.
- La región sale del mapa mundial fijo (ADR 0003, 0005). Qué región: por definir (#9).

### 3. Movimiento entre zonas
- El personaje puede pasar a zonas adyacentes (ADR 0005: "en aventura y garelino si puedes viajar entre chunks"). Cómo se conectan (por el borde u otra forma) está pendiente de confirmar (#55). Para el slice se propone el paso por el borde al chunk adyacente.

### 4. Persistencia en la partida
- Si el jugador vuelve a una zona ya visitada en la misma partida, la encuentra **tal cual** (ADR 0005).
- En una partida nueva (seed distinta), esa misma zona se genera de forma diferente.
- Si "tal cual" incluye los cambios del jugador está por definir (#54). Para el slice basta con conservar la disposición generada.

## Inputs / outputs
- **Inputs:** seed de partida, región, identificador de zona, movimiento del jugador.
- **Outputs:** zona generada (determinista con los mismos inputs), posición del personaje, registro de zonas visitadas en la partida.

## Interacción con otros sistemas
- `world-gen-dev`: generación de la zona.
- `engine-architect`: transición entre zonas y guardado de las zonas visitadas.
- `rpg-systems-dev`: personaje y movimiento.
- No interviene la capa ciudad ni el combate en este slice.

## Casos límite
- Llegar al borde de la región o del mapa: por definir (comportamiento ligado a #55 y #56).
- Volver a una zona tras visitar muchas: tiene que seguir igual (persistencia).
- Misma seed y misma zona en dos partidas: la generación es idéntica (determinismo, ADR 0003).
- Seed distinta: zona distinta.

## Criterios de éxito para playtest
Propuesta de `game-designer`, a confirmar con el dueño:
- Volver a 3 zonas ya visitadas: las 3 se ven idénticas a la primera visita (0 diferencias).
- Dos partidas con seeds distintas producen la misma zona de forma visiblemente diferente.
- El jugador cruza a una zona adyacente sin ayuda en su primer intento.
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
