# Ficha: Tiempo y riutash (modo Aventura)

> Dueño: `game-designer`. Versión 0.2.0 "Primer encargo". Fuentes: ADR 0012 (tiempo real con pausa), ADR 0010 (curación y riutash), glosario §1 "Momento" y §2 "Riutash".
> **Valores PROVISIONALES**, en `data/world/time.json`. Implementación: `engine-architect` (PR 4).

## Objetivo
Que el tiempo avance y que el día y la noche marquen el ritmo de la partida. El riutash es un momento de peligro y de respiro: obliga a planificar dónde estar cuando llegue.

Palabras del dueño: "manejalo como dungeon keeper. Solo recuerda que entre dia y noche esta el riutash. debe haber una alerta para buscar refugio antes del riutash porque puede causar daño." En otra ocasión dijo que el riutash "regenera estamina y cura parcialmente. No cura heridas graves" (ADR 0010).

## Pilares
- **Pilar 2 (sesiones cortas con progreso visible)**: un ciclo día + noche dura 13 min, y cada riutash es un hito.
- **Pilar 3 (legibilidad 8-bit)**: un aviso parpadeante y un tono plateado de noche.
- **Pilar 4**: el riutash es un rasgo propio del mundo (glosario §2).

## Presión de supervivencia
- **Añade**: cada 5–8 minutos hay que estar en un refugio, o se pierde el 30% de los PV máximos. Obliga a planificar rutas cerca de refugios y caminos.
- **Alivia**: refugiarse cura el 50% de los PV que faltan. Es la única curación fuera de una villa.

## Reglas

### Reloj
| Parámetro | Valor provisional | Clave en `time.json` |
|---|---|---|
| Duración del Momento de Gietos (día) | 8 min reales | `gietos_seconds: 480` |
| Duración del Momento de Riumna (noche) | 5 min reales | `riumna_seconds: 300` |
| Primer aviso de riutash | 60 s antes | `warning_seconds: [60, 15]` |
| Segundo aviso | 15 s antes | (misma lista) |
| Momento al empezar una partida nueva | Gietos, al inicio del día | `start_momento: "gietos"`, `start_elapsed: 0` |

- El tiempo corre **solo mientras se explora**. Se detiene con el menú de pausa, el mapa (M), los diálogos, el menú del borde y el combate.
- Hay un riutash en **cada cambio**: Gietos → Riumna (atardecer) y Riumna → Gietos (amanecer). Son 2 por ciclo.
- El **día** (contador de días) sube en el riutash del amanecer.

### Riutash
Al llegar el riutash se comprueba dónde está el jugador:

| Situación | Efecto |
|---|---|
| **Expuesto** | Pierde el **30% de sus PV máximos**, redondeando hacia abajo. **Nunca baja de 1 PV**: el riutash no mata. |
| **En refugio** | Recupera el **50% de los PV que le faltan**, redondeando hacia arriba. |

- **Refugio**: una casilla `REFUGE` (árbol hueco o cueva, junto a los caminos) o la plaza de una villa (las casillas donde ya se descansa, ADR 0009). Los refugios se describen en `navegacion.md`.
- El riutash **no cura heridas graves** (ADR 0010; las heridas graves no existen aún en la 0.2.0).
- Estamina: el riutash la regenerará cuando exista (#73). No está en la 0.2.0.
- Mensaje al pasar, por ejemplo: "El riutash pasa. Te has resguardado." / "El riutash te alcanza." (textos: `narrative-writer`).

### Avisos
- A 60 s: aviso en el HUD, "Se acerca el riutash. Busca refugio." (texto provisional).
- A 15 s: aviso parpadeante.
- El HUD muestra siempre el Momento actual y el tiempo que falta para el próximo riutash.

### Noche (Momento de Riumna)
- ~~Tinte azul.~~ Sustituido (dueño, 2026-10-24: "la noche o momento de riumna tiene un hue plateado y los colores del mundo resaltan de otro modo"):
  - **Tono plateado** (Riumna, "luz plateada", glosario §1).
  - Es **luz de luna, no oscuridad**: los colores del mundo resaltan de otra forma, sin apagarse.
  - Transición suave.
- Se implementa como **post-proceso de iluminación**, una excepción a la paleta de 32 colores que anota `engine-architect` en el ADR 0012. Los assets siguen dentro de la paleta.
- Criterio: de noche se tiene que seguir leyendo el terreno (caminos, agua, refugios y bordes de Bosque) tan bien como de día.
- En la 0.2.0 la noche no tiene peligros propios ni Bosques que impidan andar. Siguen pendientes (#75).

## Inputs / outputs
- **Inputs:** tiempo real transcurrido sin pausa, estado de pausa, casilla del jugador (¿refugio?), PV actuales y máximos.
- **Outputs:** Momento actual, segundos hasta el riutash, señales `momento_changed`, `riutash_warning(seconds_left)` y `riutash_passed(sheltered)`, PV ajustados, contador de días.

## Interacción con otros sistemas
- **Navegación** (`navegacion.md`): refugios junto a los caminos.
- **Misión del Ofomni** (`mision-ofomni.md`): el Ofomni avanza con el reloj y su posición se revela en cada riutash.
- **Combate** (`cruce-y-combate-v1.md`): el reloj está parado durante el combate.
- **Guardado**: el Momento y el tiempo transcurrido se guardan.

## Casos límite
- **Riutash con el jugador a 1 PV y expuesto**: sigue con 1 PV.
- **Riutash con los PV al máximo y en refugio**: no hay cambio. El mensaje dice igualmente que se ha resguardado.
- **Pausa justo antes del riutash**: el reloj se congela; al reanudar, el riutash llega cuando toque. Pausar no evita el riutash.
- **El riutash tocaría durante un combate o un diálogo**: no puede, porque el reloj está parado. Llega al volver a explorar.
- **Entrar o salir de un refugio en el mismo instante del riutash**: cuenta la casilla en la que está el jugador en el frame del riutash.
- **Cargar una partida**: el reloj sigue donde se guardó. Si faltaban 10 s para el riutash, se dan los avisos que queden.
- **Partida nueva**: empieza al inicio del día, así que el primer riutash llega a los 8 minutos.

## Criterios de éxito para playtest
Propuestas, a confirmar con el dueño:
- El jugador nota el aviso de 60 s y llega a un refugio en al menos 2 de cada 3 riutash, sin que se lo recuerden.
- Ningún riutash pilla al jugador por sorpresa (pregunta directa: "¿supiste que venía?").
- El dueño considera que 8 + 5 minutos dan buen ritmo y que la noche se distingue del día a simple vista.
- El daño del riutash se percibe como un riesgo real pero no injusto, porque nunca mata.
- El dueño reconoce el tono plateado de la noche como "colores que resaltan de otro modo", no como oscuridad (pregunta directa).

## Feedback del dueño
| Fecha | Feedback | Acción |
|---|---|---|
| 2026-10-24 | "la noche o momento de riumna tiene un hue plateado y los colores del mundo resaltan de otro modo" | El tinte azul pasa a ser un tono plateado de luz de luna, como post-proceso (excepción a la paleta, ADR 0012). |
| 2026-10-24 | Aledra es fatal de noche (`monstruos.md`). | La noche añade riesgo de muerte donde haya Aledras (cuando existan). |

## Decisiones a confirmar con el dueño
- El refugio cura el 50% de lo que falta y la exposición quita el 30% de los PV máximos, sin matar nunca (#122).
- El día sube en el riutash del amanecer.
- La plaza de la villa cuenta como refugio.

## Backlog relacionado (después de la 0.2.0; `bosques-y-relacion.md`)
- **Dormir** (dueño: "en villas y refugios y si pasa el tiempo, solo se debe dormir de noche, dormir de dia consume Luz. Gietos detesta el descanso."):
  - **De noche**: lleva a **Pensamiento** (misiones lejanas). Propuesta: salta hasta el riutash del amanecer, pasado como refugiado, y es gratis.
  - **De día**: propuesta: salta hasta el riutash del atardecer y cuesta 1 de Luz por cada 2 minutos saltados (máximo 4), sin Pensamiento.
  - Detalle en `bosques-y-relacion.md`.
- **Descansar el riutash cerca del Nujio** de un Bosque sube la relación con él (dueño).
- El **peaje pagado caduca**. Propuesta: hasta el segundo riutash siguiente, salvo amistad alta (#134).

## Preguntas abiertas
- Dormir de día y los Humores (#145).
- Peligros propios de la noche y Bosques donde no se puede andar de noche (#75).
- Estamina (#73) y heridas graves (#114, #116).
- Regeneración de los Únicos con el tiempo (#120).
- ¿Supervivencia usará también tiempo real con pausa? (#121)
