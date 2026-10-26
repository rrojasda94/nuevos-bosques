# Ficha: Lugares especiales e interiores (para más adelante)

> Dueño: `game-designer`. **Para más adelante: 0.6 o después del Mundo 2.0** (`roadmap-0.5.md`). Valores **provisionales**.
> **Dependencia**: los interiores y la colocación de lugares en el mapa dependen del **Mundo 2.0** (0.4; lo lleva otra sesión, ADR 0014). Esta ficha no cambia sus documentos.
> Fuentes: palabras del dueño (abajo); glosario §5 ("Villa": casas de barro o piedra, sin puertas cerradas; resto de estructuras al aire libre), §5 ("Tarca — cueva; luego también templo"), §7 ("Tarca de Trastas"); `sigilo-y-robo.md` (arma equipada), `bosques-y-relacion.md` (relación, dormir y Pensamiento), `navegacion.md` (refugios).

## Objetivo
Dar al mundo lugares que se visitan por sí mismos: interiores con vida, cuevas amplias y lugares sagrados que recompensan llegar en paz.

Palabras del dueño (2026-10-25): "Despues tambien podemos empezar a crear los espacios dentre de edificios, refugios, tarcas (cuevas amplias), lugares como sicabis que son lugares muy bonitos y sagrados donde no puedes cargar con armas, te regeneran luz, te ayudan a conectar con la Luz y el Bosque."

## Pilares
- **Pilar 1**: los lugares sagrados premian la Senda respetuosa y el arma desequipada.
- **Pilar 3**: entrar en un interior es un cambio de escena claro.
- **Pilar 4**: dónde caen las sicabis y las tarcas depende de la seed, dentro del mapa del dueño.

## Presión de supervivencia
- **Alivia**: las sicabis regeneran Luz, el recurso más escaso, y conectan con el Bosque.
- **Añade**: para entrar en una sicabi hay que **desequipar el arma**, es decir, quedar más expuesto fuera.

## Reglas

### Interiores de edificios
- **Casas de la villa** (dormitorios): interior pequeño de 1 sala, sin puerta (glosario: "sin puertas cerradas"). De noche, los NPC duermen dentro (`npcs-y-villas.md`). Si la villa te acepta, una casa asignada para dormir.
- **Talleres**: al aire libre (glosario), no son interiores.
- **Casa del Dumno**: interior con enfermos; ahí se curan las heridas graves.

### Refugios por dentro
- **Árbol hueco o cueva pequeña** (`navegacion.md`): al entrar (E), escena interior de 1 sala. Ahí se pasa el riutash y se duerme. A veces hay un hallazgo (ofrenda o material).

### Tarcas (cuevas amplias)
- Glosario §5: "Tarca — cueva; luego también templo". La **Tarca de Trastas** (§7) es donde surgió el movimiento de Estrella Azul y donde están los ledai como profetas (dueño).
- **En el juego**: cueva amplia de varias salas, en zonas rocosas o montañosas.
  - Contiene **obsidiana** y **metal** (materiales de artesano, `npcs-y-villas.md`) y es buen refugio para el riutash.
- **Templos garelinos: solo unas pocas** (dueño, #176: "la de Trastas, la de Azhin, la de Lean y algunas más pero la mayoria de tarcas no"):
  - la **Tarca de Trastas** (glosario §7);
  - la **Tarca de Azhin** (nombre **nuevo** del dueño; hay que añadirlo al glosario, #177);
  - la **Tarca de Lean** (Lean es una subregión del Valle del Sara, `docs/design/world/sur-lenfi.md`);
  - y algunas más.
  - Son lugares de los ledai y campamentos garelinos (`dos-caminos.md`).
- **La mayoría de las tarcas** (dueño): "son lugares vacios y ocupados por algunos seres espirituales". **Qué seres son: por definir** (#178). Mientras tanto, la tarca común es un lugar vacío y tranquilo, con un encuentro espiritual sin definir.
- Cuántas: 1–2 por subregión montañosa (propuesta).

### Sicabis (término nuevo del dueño)
> Registro literal: "lugares como sicabis que son lugares muy bonitos y sagrados donde no puedes cargar con armas, te regeneran luz, te ayudan a conectar con la Luz y el Bosque". **No está en el glosario**: hay que añadirlo (lo hace el dueño, #175). No se le inventa más lore.

- **Lo que dijo el dueño**:
  - lugares **muy bonitos y sagrados**;
  - **no se puede entrar con armas**;
  - **regeneran Luz**;
  - ayudan a **conectar con la Luz y el Bosque**.
- **Cómo son** (dueño, #175: "Sicabis son un espacio geografico hermoso, como un jardin con un pequeño lago, muchas plantas hornamentales que solo existen en estos lugares"):
  - un **espacio geográfico hermoso**, como un **jardín** con un **pequeño lago**;
  - **muchas plantas ornamentales que solo existen allí**.
  - Para `pixel-artist` y `world-gen-dev`: tiles propios de plantas ornamentales exclusivas y una laguna pequeña; ocupa varios chunks o un claro grande del Mundo 2.0.
- **Mecánicas propuestas (provisionales)**:

| Regla | Propuesta |
|---|---|
| **Sin armas** | Con el arma equipada en la mano principal no se puede pasar el umbral (aviso: hay que desequiparla). Enlaza con la regla del arma equipada (`sigilo-y-robo.md`). |
| **Regenerar Luz** | Dentro, **+1 de Luz suelta cada 30 s** de reloj, hasta el límite (`luz_max`). |
| **Conectar con la Luz** | Acción **"Meditar"** (E), una vez por día: entras en **Pensamiento sin dormir**, también de día, y con 1/3 de probabilidad recibes una visión (misión lejana o señal de un Bosque). Enlaza con dormir y Pensamiento (`bosques-y-relacion.md`). |
| **Conectar con el Bosque** | Meditar sube la **relación +5** con el Bosque donde está la sicabi (una vez por día) y la **Senda +1**. |
| **Garelino** | **No puede entrar**, ni siquiera sin armas (dueño, #175: "no"). |
| **Cuántas** | **Raras**: 1 por subregión (propuesta), en lugares bonitos del mapa del dueño (claros, cascadas, lagunas del Mundo 2.0). |
| **Respeto** | No hay combate dentro: los Únicos no entran ni atacan allí. |

## Inputs / outputs
- **Inputs:** posición del jugador, arma equipada, Momento, bando, Bosque de la sicabi.
- **Outputs:** cambio a escena interior, Luz regenerada, visiones de Pensamiento, relación y Senda.

## Casos límite
- **Entrar en una sicabi perseguido por cazadores**: los Únicos no entran; esperan fuera hasta perderte de vista. Propuesta: no sirve como escondite indefinido, porque los cazadores esperan 60 s y luego vuelven a patrullar.
- **Equipar el arma dentro de una sicabi**: no se puede.
- **Riutash dentro de una sicabi**: cuenta como refugio.
- **Tarca templo garelino siendo fiel** (Trastas, Azhin, Lean y algunas más): territorio garelino; sus grupos te piden que te vayas (combate no letal si insistes).
- **Garelino ante una sicabi**: el umbral no le deja pasar (texto de `narrative-writer`).

## Criterios de éxito para playtest
- El jugador desvía su ruta para pasar por una sicabi y recargar Luz.
- El dueño reconoce las sicabis como "lugares muy bonitos y sagrados" (pregunta directa).

## Preguntas abiertas
- **#175** (en parte): sicabis: jardín con un pequeño lago y plantas ornamentales exclusivas; un garelino no puede entrar. Queda abierto añadir el término al glosario (lo hace el dueño) y confirmar las mecánicas propuestas (+1 Luz cada 30 s, Meditar, relación +5 y Senda +1, 1 por subregión).
- **#177**: añadir "Azhin" (Tarca de Azhin) al glosario. Lo hace el dueño.
- **#178**: ¿qué son los "seres espirituales" que ocupan las tarcas vacías?
