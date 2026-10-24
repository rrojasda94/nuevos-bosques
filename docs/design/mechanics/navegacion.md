# Ficha: Navegación — caminos, letreros, refugios, mapa y brújula

> Dueño: `game-designer`. Versión 0.2.0 "Primer encargo". Fuentes: palabras del dueño (abajo), ADR 0008 (letreros de piedra hacia las villas, ríos continuos con pasos), `tiempo-y-riutash.md`.
> **Valores PROVISIONALES**. Implementación: `world-gen-dev` (PR 2, caminos, letreros y refugios) y `ui-ux-dev` (PR 3, mapa y brújula).

## Objetivo
Que no sea fácil perderse y que siempre se sepa volver a la villa natal.

Palabras del dueño: "mejorar los sistemas de caminos y generación de lugares con mejor planeamiento. Es muy facil perderse en este juego y no saber como regresar a la villa." Para la orientación eligió **las tres ayudas**: caminos principales con letreros hacia la villa natal, mapa con M y brújula en el HUD.

## Pilares
- **Pilar 3 (legibilidad 8-bit)**: un camino visible, una flecha y un mapa de cuadros.
- **Pilar 2 (sesiones cortas)**: menos tiempo perdido, más tiempo jugando.
- **Pilar 4**: la red de caminos se genera con la seed sobre el grafo de Bosques.

## Presión de supervivencia
- **Alivia**: perderse deja de ser un castigo. Los refugios junto a los caminos permiten sobrevivir al riutash.
- **Añade**: salir del camino lleva a lugares sin refugio cercano y con más riesgo ante el riutash. Las ayudas no evitan los peajes ni los Únicos.

## Reglas

### Caminos principales
- Una **red de caminos** une los chunks de Nujio de todos los Bosques de la región: un árbol de expansión sobre la adyacencia de Bosques, más algunas aristas extra para que haya ciclos (plan, PR 2).
- Tile nuevo **`ROAD`**: **2 casillas de ancho**, caminable y muy visible (distinto de la hierba y de los senderos actuales).
- Los caminos **no atraviesan agua** salvo por un **puente o vado** (ADR 0008: los ríos tienen zonas de paso).
- Desde cualquier chunk de Nujio se llega por camino a la villa natal.
- Los caminos **no anulan los bordes**: cruzar a otro Bosque sigue pidiendo peaje o combate (`cruce-y-combate-v1.md`).

### Letreros
- En cada **cruce de caminos** hay un letrero de piedra que apunta siempre a la **villa natal**. Señala el siguiente tramo del camino hacia casa (4 direcciones, ADR 0006), no la línea recta. Confirmado por el dueño el 2026-10-24.
- Se mantienen los letreros que apuntan a la villa del propio Bosque (ADR 0008).
- **Interacción** (dueño, 2026-10-24: "prefiero, que el letrero sea interactuable con el jugador y presionando E salga una ventana de dialogo que apunte en la dirección y de indicaciones de cuanto tomara llegar y el nombre de la villa 'tentativo'"):
  - Al pulsar **E** mirando al letrero se abre una **ventana de diálogo** (el `DialogueBox` del PR 5).
  - El diálogo muestra:
    - una **flecha** con la dirección;
    - el **tiempo estimado** hasta llegar;
    - el **nombre de la villa**, tentativo, sacado de una lista generada (`data/text/nombres_villas.json`, de `narrative-writer`; el glosario §5 dice que las villas se nombran normalmente por su Original fundador).
  - Ya no se leen al pisarlos.
- **La flecha sigue el camino**, no la línea recta: apunta hacia la salida del cruce por la que se llega antes a la villa siguiendo la red de caminos (decisión del dueño, establecida desde ahora).
- **Tiempo estimado** (provisional, propuesta de `game-designer`):
  - Se calcula con la longitud del recorrido por camino hasta la villa, en casillas, dividida entre la velocidad de paso del adoc.
  - Se redondea hacia arriba a minutos de reloj.
  - Se muestra como "unos N minutos". Si llegar lleva más que lo que falta para el próximo riutash, se añade "pasarás un riutash por el camino".
  - No cuenta peajes ni combates.
- Ejemplo de texto (provisional, `narrative-writer`): "↗ Villa <nombre> (natal): unos 4 minutos por el camino."

### Refugios
- Tile nuevo **`REFUGE`** (árbol hueco o cueva), junto a los caminos, **cada 2–3 chunks** de camino, de forma determinista.
- La **plaza de la villa** también es refugio.
- Sirven para el riutash (`tiempo-y-riutash.md`). Algunos guardan una ofrenda (`ofrendas-v1.md`).
- Se examinan con E.

### Mapa (tecla M)
- **Pausa el juego** y el reloj.
- Muestra una rejilla de **chunks explorados** (cada chunk visitado queda marcado para siempre en la partida) con el color de hoja de su Bosque.
- Encima: **caminos**, **villa natal**, **refugios vistos**, **posición del jugador** y **última posición conocida del Ofomni** (si la misión está activa).
- Los chunks no explorados no se muestran (niebla).
- Se cierra con M o con Esc.

### Brújula (HUD)
- Una flecha de **8 direcciones** apunta a:
  1. el **objetivo de la misión activa** (la última posición conocida del Ofomni);
  2. si la misión está ofrecida pero no aceptada, el **sfida**;
  3. si no hay misión activa, la **villa natal**.
- Junto a la flecha, una etiqueta corta del objetivo ("Ofomni", "Villa").
- La dirección se calcula de chunk a chunk. Dentro del chunk del objetivo, apunta a la casilla.

## Inputs / outputs
- **Inputs:** seed, grafo de Bosques, Bosque natal, chunk del jugador, chunks explorados, estado de la misión, última posición conocida del Ofomni.
- **Outputs:** tiles `ROAD` y `REFUGE` en los chunks generados, letreros, `GameState.explored_chunks`, dirección de la brújula, vista del mapa.

## Interacción con otros sistemas
- **Generación** (`world-gen-dev`): caminos, puentes y vados, letreros y refugios, todo determinista.
- **Tiempo**: refugios para el riutash. El mapa pausa el reloj.
- **Misión del Ofomni**: objetivo de la brújula y marca en el mapa.
- **Ofrendas**: hallazgos en refugios.
- **Interacción (E)**: leer letreros y examinar refugios.
- **Guardado**: chunks explorados y refugios saqueados.

## Casos límite
- **El jugador está en la villa natal sin misión**: la brújula no tiene a dónde apuntar. Se muestra un punto o "Aquí".
- **Objetivo en el mismo chunk**: la brújula apunta a la casilla. Si el jugador está encima, muestra "Aquí".
- **Posición del Ofomni desconocida** (antes de aceptar la misión): la brújula apunta al sfida.
- **Un río cruza el camino**: siempre hay puente o vado en el camino. Fuera del camino, el río puede ser barrera.
- **Chunk sin camino**: la brújula y el mapa siguen funcionando; no hay letreros.
- **Mapa con muchos chunks explorados**: se centra en el jugador y permite desplazarse (a decidir por `ui-ux-dev`).
- **Cargar una partida de la 0.1.0**: solo queda marcado como explorado el chunk actual.

## Criterios de éxito para playtest
Propuestas, a confirmar con el dueño:
- Desde un Bosque a 3 saltos, el jugador vuelve a la villa natal sin ayuda en menos de 3 minutos.
- El dueño dice que ya no se pierde (pregunta directa).
- El jugador usa el mapa (M) al menos una vez por sesión y sigue un camino al menos una vez sin que se le indique.
- Ningún tester se queda atrapado: todos los chunks de camino son alcanzables (test automático en el PR 2).

## Feedback del dueño
| Fecha | Feedback | Acción |
|---|---|---|
| 2026-10-24 | Letrero con E que abre un diálogo con la dirección, el tiempo hasta llegar y el nombre tentativo de la villa. | Hecho en esta ficha. La flecha sigue el camino. |

## Decisiones a confirmar con el dueño
- Fórmula del tiempo estimado (casillas de camino ÷ velocidad, en minutos, con aviso de riutash).
- La brújula apunta primero al sfida (misión ofrecida), luego al Ofomni (activa) y si no a la villa natal.
- Refugios cada 2–3 chunks de camino.
- El mapa muestra solo lo explorado, con niebla en el resto.

## Preguntas abiertas
- Caminos y letreros fuera de la red principal (#87).
- Navegación por ríos grandes (#74).
- Viaje largo por el mapa de la región (#56, #91).
