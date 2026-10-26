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
  - la **Tarca de Azhin**. Azhin es una villa pequeña, la más septentrional del Valle del Sara, en el noroeste, pegada a la cordillera occidental. De allí salieron los primeros Nuevos Bosques, con los ledai venidos de la Tarca de Trastas (dueño; `docs/design/world/sur-lenfi.md`). Hay que añadirla al glosario (lo hace el dueño, #181);
  - la **Tarca de Lean** (Lean es una subregión del Valle del Sara, `docs/design/world/sur-lenfi.md`);
  - y algunas más.
  - Son lugares de los ledai y campamentos garelinos (`dos-caminos.md`).
- **La mayoría de las tarcas** (dueño): "son lugares vacios y ocupados por algunos seres espirituales".
  - **Cómo son esos seres** (dueño, #178): "Son cuerpos etereos y amorfos de tamaño pequeño o mediano." Se registra tal cual: sin nombre ni comportamiento inventados.
  - **Actitud** (dueño, #180: "Los espiritus de la tarca normalmente son neutros, pero puede tocar una que sean hostiles. Igual puedes atacarlos y provocarles."):
    - **neutros** por defecto;
    - a veces **hostiles** (según la tarca);
    - el jugador **puede atacarlos o provocarlos**.
  - **Mecánica (confirmada por el dueño, #183: "me sirve tu idea"; valores provisionales)**:
    - **Por tarca vacía**: 2–4 espíritus. Con probabilidad **1/5** (por seed), la tarca es **hostil**: sus espíritus atacan al ver al jugador.
    - **Neutros**: flotan y se apartan. Con E se pueden **atacar** (combate en grupo). **Provocar** (pasar pegado varias veces o atacar a uno) vuelve hostiles a todos los de esa tarca hasta el siguiente riutash.
    - **Stats** (pequeño / mediano): PV 10 / 20, ATQ 3 / 5, DEF 1 / 2. Perfil de IA "agresivo" si son hostiles (`ia-de-combate.md`). `fatal_at: []`.
    - **No son Únicos** de un Bosque: atacarlos no cambia la hostilidad ni la relación de ningún Bosque. Propuesta: Senda −1 si los provocas sin motivo.
    - **Recompensa**: XP como un Único de d = 1 (pequeño) o d = 2 (mediano). Sin botín. Al caer, ¿se disipan? Se registra solo "cuerpos etéreos", sin más lore.
- Cuántas: 1–2 por subregión montañosa (propuesta).

### Sicabis (término nuevo del dueño)
> Registro literal: "lugares como sicabis que son lugares muy bonitos y sagrados donde no puedes cargar con armas, te regeneran luz, te ayudan a conectar con la Luz y el Bosque". Ya está en el glosario (`docs/glosario_nuevos_bosques.md`, [Chat 2026-10], #181). No se le inventa más lore.

- **Lo que dijo el dueño**:
  - lugares **muy bonitos y sagrados**;
  - **no se puede entrar con armas**;
  - **regeneran Luz**;
  - ayudan a **conectar con la Luz y el Bosque**.
- **Cómo son** (dueño, #175: "Sicabis son un espacio geografico hermoso, como un jardin con un pequeño lago, muchas plantas hornamentales que solo existen en estos lugares"):
  - un **espacio geográfico hermoso**, como un **jardín** con un **pequeño lago**;
  - **muchas plantas ornamentales que solo existen allí**.
  - Para `pixel-artist` y `world-gen-dev`: tiles propios de plantas ornamentales exclusivas y una laguna pequeña. Es un **lugar muy pequeño** con escena interior propia (ver "Cómo se encuentran en el mundo"), no un claro del mapa abierto.
- **Mecánicas propuestas (provisionales)**:

| Regla | Propuesta |
|---|---|
| **Sin armas** | Con el arma equipada en la mano principal no se puede pasar el umbral (aviso: hay que desequiparla). Enlaza con la regla del arma equipada (`sigilo-y-robo.md`). |
| **Regenerar Luz** | Dentro, **+1 de Luz suelta cada 30 s** de reloj, hasta el límite (`luz_max`). |
| **Conectar con la Luz** | Acción **"Meditar"** (E), una vez por día: entras en **Pensamiento sin dormir**, también de día, y con 1/3 de probabilidad recibes una visión (misión lejana o señal de un Bosque). Enlaza con dormir y Pensamiento (`bosques-y-relacion.md`). |
| **Conectar con el Bosque** | Meditar sube la **relación +5** con el Bosque donde está la sicabi (una vez por día) y la **Senda +1**. |
| **Garelino** | **No puede entrar**, ni siquiera sin armas (dueño, #175: "no"). |
| **Cuántas** | **Raras** (dueño, 2026-10-26: "son lugares raros de hallar"): **como mucho 1 por subregión**, y solo en 6 de cada 10 subregiones. Lejos de villas y aldeas. Detalle en "Cómo se encuentran en el mundo". |
| **Respeto** | No hay combate dentro: los Únicos no entran ni atacan allí. |

#### Cómo se encuentran en el mundo (dueño, 2026-10-26)
> Registro literal: "Los sicabis tambien [se ven en el juego] pero son lugares muy pequeños quizas podría accederse como a una caverna o edificio, si vas por entre un bosque o montaña, puede haber una entrada especial y al entrar es un sicabi." Y: "solo reuerda que las sicabis son lugares raros de hallar. no puede haber tantos cerca de una villa. lagos normales si."

**Para `world-gen-dev`, después de M9.** Valores provisionales.

- **Entrada especial** en el mapa abierto, como la boca de una cueva o la puerta de una casa. Hay dos variantes según el terreno:
  - **Bosque tupido**: un arco de raíces entre árboles. Objeto de 2×2 casillas que se pisa por su fila de abajo.
    - Condición: al menos el **70 %** de las casillas a ≤ 6 casillas (Chebyshev) de la entrada tienen árbol.
  - **Montaña**: una grieta en la base de una cara de risco, de nivel 2 o más. Se coloca como la cueva-refugio (2×2, la fila de abajo es la boca), pero con su propio dibujo, para no confundirla con un refugio.
- **Fuera de los caminos principales**:
  - la entrada queda a **≥ 10 casillas** de cualquier `ROAD` (camino de 3) y a **≥ 6 casillas** de cualquier `PATH` (sendero);
  - no se le traza sendero;
  - sí se garantiza un **paso libre de al menos 2 casillas de ancho** desde la red de senderos. Sin dibujar: es un hueco entre los árboles o una cornisa. La entrada entra en la comprobación `inaccessible()`.
  - Es lo contrario que el refugio, que va a ≤ 6 de un sendero y a la vista.
- **Al entrar** (E en la boca, con el arma desequipada) se cambia a la **escena interior de la sicabi**: el jardín con un pequeño lago y plantas ornamentales exclusivas.
  - Propuesta de tamaño: **una sola pantalla, 20×11 casillas**, sin cámara que se desplace (pilar 3).
  - Al salir se vuelve a la boca.
  - Todas las reglas de la tabla de arriba (Luz, Meditar, sin armas, garelino) se aplican dentro de esa escena.
- **Rareza** (por región, con el RNG del plan de región):
  - **Tope: 1 por subregión.**
  - Cada subregión tiene sicabi con probabilidad **0,6**. En el Valle del Sara, con 7 subregiones, salen de media unas **4 por partida** (entre 0 y 7) en 192 chunks.
  - Si en una subregión no hay ningún sitio que cumpla las reglas, se queda sin sicabi (no se fuerza).
- **Distancias mínimas** (en chunks, Chebyshev entre el chunk de la entrada y el otro chunk):
  - a **cualquier villa o aldea**, con nombre o procedural: **≥ 2 chunks**. Es decir, ni en el chunk de la villa ni en sus 8 vecinos: al menos 80 casillas en línea recta y más por camino;
  - a **otra sicabi**: **≥ 4 chunks**;
  - **no en un Bosque muerto**, porque Meditar sube la relación con el Bosque de la sicabi (`bosques-y-relacion.md`).
  - Puede caer en el chunk de un Nujio. Ahí no cuenta como punto de interés: no lo es, va escondida.
- **Orden de prioridad**:
  - si el dueño pinta una sicabi en `lugares.csv` (tipo nuevo `sicabi`), esa es la de su subregión y cuenta para el tope;
  - si no, el generador sortea el chunk;
  - las reglas de distancia se aplican igual a las dos.
- **Las lagunas normales no son sicabis**:
  - el punto de interés `laguna` del Mundo 2.0 (`mundo-2.md` §4) se ve en el mapa abierto, **sí puede estar en el chunk de una villa o aldea o junto a él** ("lagos normales si"), no tiene interior y no regenera Luz;
  - la sicabi nunca está en el mapa abierto: su lago está dentro de la escena interior.
- **Qué irían en `data/`** (nombres de claves propuestos; la estructura la decide `world-gen-dev`):
  - En el JSON de la región (`data/world/regions/valle_del_sara.json`), bloque `sicabis`:
    `{ "per_subregion_max": 1, "subregion_chance": 0.6, "min_villa_distance_chunks": 2, "min_sicabi_distance_chunks": 4, "min_road_distance": 10, "min_path_distance": 6, "access_width": 2, "forest_ratio": 0.7, "forest_radius": 6, "cliff_min_level": 2, "allow_dead_bosque": false }`.
  - En `lugares.csv`: tipo nuevo `sicabi` (id, nombre, x, y), por si el dueño quiere fijar alguna.
  - En el chunk: objeto nuevo `SICABI_GATE` (2×2, `variant` = 0 bosque, 1 montaña | volteo << 1) y una entrada en `WorldChunk.places` o similar con su celda de boca.
  - Las reglas de dentro (Luz cada 30 s, Meditar, relación +5, Senda +1, espera de 60 s de los cazadores) son de `rpg-systems-dev`. Propuesta: `data/world/sicabi.json` con `luz_regen_seconds` 30, `meditate_relation` 5, `meditate_senda` 1, `vision_chance` 0.333, `hunter_wait_seconds` 60.
- **Qué no se inventa**:
  - los **nombres** de las sicabis, su lore y los textos del umbral y del garelino (`narrative-writer`, con el dueño);
  - qué plantas son en concreto (`pixel-artist` hace la spec a partir de "plantas ornamentales que solo existen en estos lugares").

**Presión de supervivencia** de la colocación: **añade** un desvío fuera de los senderos para encontrarla, lejos de la villa (sin curación cerca). **Alivia**, una vez encontrada, con la Luz y un refugio para el riutash.

## Inputs / outputs
- **Inputs:** posición del jugador, arma equipada, Momento, bando, Bosque de la sicabi.
- **Outputs:** cambio a escena interior, Luz regenerada, visiones de Pensamiento, relación y Senda.

## Casos límite
- **Entrar en una sicabi perseguido por cazadores**: los Únicos no entran; esperan fuera hasta perderte de vista. Propuesta: no sirve como escondite indefinido, porque los cazadores esperan 60 s y luego vuelven a patrullar.
- **Equipar el arma dentro de una sicabi**: no se puede.
- **Riutash dentro de una sicabi**: cuenta como refugio.
- **Tarca templo garelino siendo fiel** (Trastas, Azhin, Lean y algunas más): territorio garelino; sus grupos te piden que te vayas (combate no letal si insistes).
- **Garelino ante una sicabi**: el umbral no le deja pasar (texto de `narrative-writer`).
- **Aldea procedural que caería a menos de 2 chunks de una sicabi**: se colocan antes las villas y las aldeas, y luego las sicabis. Así la sicabi es la que se aparta o desaparece, nunca la aldea.
- **Subregión pequeña o toda cerca de villas**: se queda sin sicabi. Es aceptable, porque son raras.
- **Entrada de montaña que coincide con el sitio de una cueva-refugio**: manda el refugio (es supervivencia); la sicabi busca otro sitio.

## Criterios de éxito para playtest
- El jugador desvía su ruta para pasar por una sicabi y recargar Luz.
- El dueño reconoce las sicabis como "lugares muy bonitos y sagrados" (pregunta directa).
- **Rareza** (test de `world-gen-dev`, 5 seeds):
  - nunca más de 1 sicabi por subregión;
  - ninguna a menos de 2 chunks de una villa o aldea, ni a menos de 4 de otra;
  - entre 2 y 6 por región en al menos 4 de las 5 seeds.
- **Hallazgo** (playtest): en una partida de 1 hora, el jugador encuentra 1 sicabi como mucho sin buscarla y siente que "la ha descubierto" (pregunta directa).

## Preguntas abiertas
- **#175** (en parte): sicabis: jardín con un pequeño lago y plantas ornamentales exclusivas; un garelino no puede entrar. Queda abierto confirmar las mecánicas propuestas (+1 Luz cada 30 s, Meditar, relación +5 y Senda +1). El término ya está en el glosario. La rareza y la colocación las dio el dueño el 2026-10-26 ("lugares raros de hallar", entrada especial en bosque o montaña). Los números (tope de 1 por subregión, probabilidad 0,6, ≥ 2 chunks de una villa, ≥ 4 entre sicabis) son propuesta.
- **Nueva: ¿la entrada se ve a simple vista o hay que buscarla?**
  - Propuesta por defecto (pilar 3): el objeto de la entrada **se ve** si está en pantalla, pero queda fuera de los senderos, sin letrero que lleve a ella y sin marca en el mapa M hasta haberla encontrado.
  - La alternativa sería esconderla del todo: que solo aparezca al acercarse a ≤ 3 casillas o con una pista (un Bosque, una visión de Meditar). Hay que preguntarlo al dueño.
- ~~#177 y #178~~ Resueltas: Azhin, villa del noroeste; seres etéreos y amorfos, pequeños o medianos.
- ~~#179, #180, #181~~ Resueltas: cordillera occidental transitable y Larr al norte (`docs/design/world/sur-lenfi.md`); espíritus neutros por defecto, a veces hostiles, y se les puede atacar o provocar; glosario actualizado con autorización del dueño.
- ~~#182 y #183~~ Resueltas: Azhin está en Lean; la mecánica de los espíritus está confirmada.
