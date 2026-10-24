# Ficha: Cruce de Bosques y combate v1 (modo Aventura, versión de prueba)

> Dueño: `game-designer`. Estado: v1, **versión de prueba**. Lo implementa `rpg-systems-dev` en paralelo.
> **Todos los números son PROVISIONALES**: los fijó el coordinador y se registran tal cual. Los posibles problemas de balance van como "propuesta de ajuste" y **no cambian los números de esta versión**.
> Fuentes: ADR 0002 (combate por menú y por turnos), ADR 0007 (para pasar a otro Bosque con Nujio: pagar Luz o enfrentarse a sus Únicos; más lejos, más difícil), ADR 0008 (Nujio en el centro del Bosque), **ADR 0010 (economía de Luz, ofrendas y curación)** y el glosario (§3 Únicos, §5 Adoc).
>
> **Cambio v1.1 (ADR 0010):** la curación pasa de "junto a cualquier Nujio" a "en la plaza o junto al Nujio de una villa". La curación por riutash espera al ciclo día/noche. Las ofrendas (artefactos de Luz que se usan enteros) son la siguiente iteración: v1.1 sigue usando Luz suelta.
>
> **0.2.0:** el adoc sube de nivel ([`progresion-adoc.md`](progresion-adoc.md)): los stats de la tabla del personaje son los del nivel 1. Las ofrendas se usan en el borde y en combate según [`ofrendas-v1.md`](ofrendas-v1.md). El riutash cura y daña según [`tiempo-y-riutash.md`](tiempo-y-riutash.md).
>
> **Cambio v1.2 (ADR 0010, respuestas):** la Luz suelta tiene un límite de 10 (`luz_max`, provisional). El jugador empieza en la villa de su Bosque natal, que siempre existe. Las ofrendas se podrán usar en combate para que el Único se vaya (siguiente iteración).

## Objetivo
El dueño pidió: "Dame algo para cruzar temporalmente o poder cruzar y pelear contra alguien". De las opciones que se le propusieron, eligió:
- **(a)** En el borde de otro Bosque se puede **elegir** entre pagar Luz o enfrentarse a sus Únicos.
- **(b)** Si pierdes, **despiertas en tu Bosque**. Es una versión de prueba: el game over real de Aventura (ADR 0004) llegará después.
- **(c)** **Combate clásico por menú**, estilo Dragon Quest o Pokémon.

## Pilares
- **Pilar 1 (dos capas, un mundo)**: explorar el Bosque y combatir son parte del mismo viaje; la Luz conecta ambas.
- **Pilar 3 (legibilidad 8-bit)**: un menú de 3 opciones en el borde y uno de 4 acciones en combate.
- **Pilar 4**: cada Único toma la silueta y los colores de su Bosque, generados por seed.

## Presión de supervivencia
- **Añade**: la **Luz es escasa**. Se empieza con 10 y se pierde la mitad al ser derrotado. En v1 solo se gana 1 por victoria; más adelante también ayudando a las villas (ADR 0010). Cada cruce cuesta Luz (pagar u "Ofrecer Luz" en combate) o PV, y los PV solo se recuperan en una villa (más adelante, también tras un riutash). Las villas solo están en 1 de cada 5 Bosques.
- Que ir lejos sea complicado al principio es **intencionado** (ADR 0010). En el futuro, las ofrendas (artefactos que se gastan enteros) añadirán gestión de recursos: "es bueno saber administrar los recursos".
- **Alivia**: la derrota no termina la partida en esta versión de prueba (despiertas en tu Bosque).

## Reglas

### Personaje (provisional)
| Atributo | Valor |
|---|---|
| Oficio | **Adoc**: protectores, especialistas en armas para apaciguar Únicos descarriados (glosario §5) |
| PV | 30 |
| ATQ | 6 |
| DEF | 3 |
| Luz inicial | 10 |
| Límite de Luz suelta (`luz_max`) | 10 (provisional; ejemplo del dueño, ADR 0010). La Luz por encima del límite requiere ofrendas. |
| Lugar de inicio | La villa de su Bosque natal. El Bosque inicial siempre tiene villa (ADR 0010). |

### Distancia
- **distancia (d)** = número de saltos en el grafo de adyacencia de Bosques, desde el Bosque inicial hasta el **Bosque al que se intenta entrar**.
  - Se entiende que d se mide hasta el Bosque de destino. Si `rpg-systems-dev` la mide de otra forma, hay que unificarlo (#105).
- Un Bosque vecino del inicial tiene d = 1.

### Menú del borde
> **0.2.0 (Botarramas):** el menú ya no sale al pisar el borde. Sale cuando un **Botarramas** visible del Bosque cerrado intercepta al jugador y llega a tocarlo (`monstruos.md`, sección "Botarramas"). Si el jugador cruza sin contacto, se cuela sin abrir el Bosque (propuesta, #129). Las opciones y N no cambian.

Al llegar al borde de un Bosque todavía no abierto aparece un menú:
1. **"Ofrecer N Luz"**, con **N = 3 + d**. Pagar abre el borde.
2. **"Enfrentar a sus Únicos"**: inicia el combate contra el Único del Bosque de destino.
3. **"Retroceder"**: vuelves a tu lado del borde sin coste.

Pagar o ganar **abre ese borde** (entre esos dos Bosques) **para el resto de la partida**, en los dos sentidos.

### Único (provisional)
> **0.2.0:** el Único que restringe el paso se llama **Botarramas** (nombre provisional): un ave sin plumas que renquea. Hay uno por tramo de frontera de chunk, todos con los stats de abajo según d. El Ofomni y Aledra ya no guardan bordes. Detalle en `monstruos.md`.

- ~~**Uno por Bosque**, generado por seed.~~ Sustituido por los Botarramas (uno por tramo de frontera).
- **Los Únicos son monstruos, no árboles** (dueño, playtest v1). Según el glosario §3, nacen al activarse a partir de un árbol, un animal o una sustancia del Bosque. No hay contradicción: nacen de eso, pero son monstruos.
- Placeholder: **una criatura con la combinación de colores de su Bosque** (ADR 0008). Sustituye a la silueta de árbol del principio de v1.
- Nombre provisional: **"Único de <tipo de árbol>"**. Por revisar junto con aspecto, tipos y nombres (#119).
- **Regeneración**: los Únicos se regeneran con el tiempo (dueño). Hoy recuperan todos los PV cuando el jugador huye. La regeneración por tiempo espera al ciclo día/noche (#75). Ritmo y Únicos derrotados: #104, #120.

| Stat | Fórmula |
|---|---|
| PV | 18 + 4·d |
| ATQ | 4 + d |
| DEF | 1 + d/2, con "tope razonable" (valor del tope: lo decide `rpg-systems-dev`; ver propuesta de ajuste 3) |

### Combate
- Combate por turnos, **primero el jugador**. Después de cada acción del jugador, actúa el Único.
- **Acciones del jugador**:
  | Acción | Efecto |
  |---|---|
  | **Atacar** | Daño = max(1, ATQ − DEF + aleatorio de −1 a +2). |
  | **Defender** | El daño recibido en el turno siguiente se reduce a la mitad. |
  | **Ofrecer Luz** | Cuesta 2 de Luz. "Apacigua" 8 puntos de PV del Único, ignorando su DEF. Encaja con el adoc, que apacigua Únicos. |
  | **Huir** | 75% de éxito. Si sale bien, vuelves a tu lado del borde. |
- **El Único** ataca con la misma fórmula de daño.
- El aleatorio se interpreta como entero uniforme de −1 a +2. Toda aleatoriedad pasa por `GameState.rng` (ADR 0003).
- **Victoria**: el Único "vuelve a la Luz del Bosque" (glosario §3), el borde se abre y **ganas 1 de Luz**.
- **Derrota** (PV del jugador a 0) contra un Único **no fatal**: **despiertas en el centro de tu Bosque inicial** con los PV completos y **pierdes la mitad de tu Luz**, redondeando hacia abajo. Contra un monstruo **fatal en el Momento del combate**: game over (ADR 0004; `fatal_at` en [`monstruos.md`](monstruos.md)). Los Únicos comunes de borde no son fatales (provisional, #127). El combate contra grupos (reparep) está propuesto para la 0.3.0 en `monstruos.md`.

### Curación (v1.1, ADR 0010)
- Los PV **se mantienen entre combates**.
- ~~Descansar junto a cualquier Nujio recupera los PV.~~ Sustituido: **estar en la plaza o junto al Nujio de una villa** recupera los PV por completo. La villa está en el chunk central de su Bosque, alrededor del Nujio (ADR 0008).
- **Tras un riutash** (cambio entre día y noche): **regenera la estamina** y **cura en parte**, pero **no cura heridas graves** (ADR 0010). Pendiente de que exista el ciclo día/noche (#75). Cuánto cura exactamente: #114.
- **Heridas graves** (ADR 0010; siguiente iteración, no entran en v1):
  - Son perks o estados negativos que deja un **combate complicado**, aparte de los PV.
  - **Solo se curan en una villa con el oficiante adecuado**, por ejemplo un **dumno** (glosario §5). No las curan el riutash ni la curación normal de villa.
  - Si la villa no tiene dumno, se puede pedir uno a otra villa, pero el jugador tiene que quedarse más tiempo allí.
  - Preguntas: #114, #116–#118.
- El Bosque inicial siempre tiene villa (#110 resuelta), así que siempre hay al menos un lugar donde curarse.

### Fuentes de Luz (ADR 0010)
- **v1**: ganar contra un Único da +1 de Luz.
- **Siguiente iteración**: ayudar a la gente de la villa con sus peligros (misiones de villa, #106).
- **Luz suelta**: existe, hasta el límite `luz_max` = 10 (provisional). Lo que supere el límite requiere ofrendas (ADR 0010).
- **Ofrendas** (siguiente iteración): una villa puede otorgar artefactos que almacenan Luz, de valores distintos. Se usan **enteros**: para pagar, el artefacto se deja completo en el Bosque y se pierde todo su valor aunque el coste fuera menor.
  - En combate, una ofrenda se puede ofrecer **"para que el Único se vaya"**, y eso **abre el paso igual que vencer** (ADR 0010). Si basta cualquier ofrenda o hace falta un valor mínimo: #112.
  - Inventario: #113. Valores: #108. Derrota: #109.

### Estado guardado
Luz, PV y bordes abiertos. Cuando existan las ofrendas, también el inventario de ofrendas con su valor.

## Inputs / outputs
- **Inputs:** grafo de adyacencia de Bosques, Bosque inicial, seed (Único y tirada de daño), PV, Luz, elección en el menú del borde y en el combate.
- **Outputs:** borde abierto o no, PV y Luz actualizados, posición del jugador (su lado del borde, el Bosque de destino o el centro del Bosque inicial).

## Interacción con otros sistemas
- `world-gen-dev`: grafo de adyacencia, tipo de árbol y colores del Bosque (para el Único), posición del Nujio y de las villas (curación).
- `engine-architect`: guardado de Luz, PV y bordes abiertos.
- `ui-ux-dev`: menú del borde y menú de combate.
- `pixel-artist`: silueta del Único derivada del tipo de árbol del Bosque.
- Aventura (`aventura-mvp.md`): esta ficha sustituye el "borde del Bosque inicial infranqueable" del slice.

## Tabla de referencia (valores medios con los números provisionales)
Daño medio del jugador al atacar: ATQ−DEF del Único + 0,5 (siempre ≥ 1). Daño medio del Único: su ATQ − 3 + 0,5. Se toma DEF = 1 + ⌊d/2⌋.

| d | N (Luz para pagar) | PV Único | ATQ Único | DEF Único | Daño medio jugador | Ataques medios para vencer | Daño medio del Único por golpe | Daño medio recibido en la pelea (PV del jugador: 30) |
|---|---|---|---|---|---|---|---|---|
| 1 | 4 | 22 | 5 | 1 | 5,5 | 4 | 2,5 | ~7,5 |
| 2 | 5 | 26 | 6 | 2 | 4,5 | 6 | 3,5 | ~17,5 |
| 3 | 6 | 30 | 7 | 2 | 4,5 | 7 | 4,5 | ~27 |
| 4 | 7 | 34 | 8 | 3 | 3,5 | 10 | 5,5 | ~50 (no se puede ganar solo atacando) |
| 5 | 8 | 38 | 9 | 3 | 3,5 | 11 | 6,5 | ~65 |

Con la acción "Ofrecer Luz", por ejemplo en d = 3: 2 usos (4 de Luz) quitan 16 PV, quedan unos 3 ataques y se reciben ~18 de daño. Cuesta menos Luz que pagar (6).

## Casos límite
- **No tener Luz suficiente para pagar N**: la opción "Ofrecer N Luz" aparece deshabilitada (o con un aviso). Siguen disponibles "Enfrentar" y "Retroceder".
- **Luz < 2 en combate**: "Ofrecer Luz" no está disponible.
- **Volver a un borde ya abierto**: no aparece el menú; se cruza libremente en ambos sentidos.
- **Huir con éxito**: vuelves a tu lado del borde y el borde sigue cerrado. El Único recupera todos sus PV (implementado). Más adelante se regenerará con el tiempo (#120).
- **Huida fallida (25%)**: se pierde el turno y el Único ataca.
- **Derrota con 0 o 1 de Luz**: pierdes ⌊Luz/2⌋ = 0. La partida sigue.
- **Defender seguido de Huir con éxito**: la reducción no se aplica, porque no hay turno siguiente.
- **Llegar con pocos PV a un borde lejano**: solo hay curación en villas (v1.1). Hay que volver a una villa accesible.
- ~~**Bosque inicial sin villa.**~~ No puede ocurrir: el Bosque inicial siempre tiene villa (ADR 0010).
- **Victoria con la Luz suelta al máximo (10)**: el +1 supera `luz_max`. ¿Se pierde, se convierte en ofrenda o no se suma? En v1 se propone que no se sume (tope). Pregunta: #115. Ocurre ya en la primera victoria si no se ha gastado Luz, porque se empieza con 10.
- **Varios bordes del mismo Bosque**: si el Único de ese Bosque ya fue derrotado (o se pagó por otro borde), ¿protege sus otros bordes? Por definir (#104).
- **Bosques sin Nujio (Nuevos Bosques)**: ¿hay borde y Único? Por definir (#70). En v1 se asume que todos los Bosques tienen Nujio.

## Propuestas de ajuste (no cambian v1)
1. **Defender casi nunca compensa**: renuncia a ~4,5 de daño infligido para ahorrar ~1–3 de daño recibido, sin otro beneficio. Propuesta: que además dé algo (por ejemplo, +2 al siguiente ataque) o que reduzca todo el daño del turno en curso.
2. ~~**A partir de d = 4 no se puede ganar solo atacando.**~~ **Cerrada**: el dueño confirma que es intencionado que al principio sea complicado ir lejos (ADR 0010).
3. **Tope de DEF**: propuesta DEF máx. = 4, para que el daño base del jugador (ATQ 6) nunca baje de 2 antes del aleatorio.
4. ~~**Huir y volver.**~~ **Aplicada**: el Único recupera todos sus PV al huir. El dueño indica que los Únicos "pueden regenerarse con el tiempo"; cuando exista el ciclo día/noche, la regeneración pasará a depender del tiempo (#120). Ojo: si se regenera despacio, vuelve a ser posible picar y huir.
5. ~~**Economía de Luz cerrada.**~~ **Resuelta en parte** (ADR 0010): habrá misiones de villa y ofrendas. En v1.1 la economía sigue cerrada hasta que se implementen.
6. ~~**Curación escasa en v1.1.**~~ **Resuelta**: el Bosque inicial siempre tiene villa (ADR 0010).7. **Ofrendas enteras**: si una ofrenda vale más que N, se pierde el excedente. Para que la decisión sea interesante, conviene que haya ofrendas de valores bajos (por ejemplo, del orden de N = 4–6) y no solo grandes.
8. **Luz inicial igual al límite**: empezar con 10 y `luz_max` = 10 hace que la recompensa de la primera victoria se pierda si no se ha gastado nada. Propuesta: empezar con menos (por ejemplo, 6–8) o que el excedente se convierta en una ofrenda pequeña.

## Feedback de playtest del dueño
| Versión | Pregunta | Respuesta textual | Acción |
|---|---|---|---|
| v1 (commit 5225c92) | Dificultad | "esta bien el nivel de dificultad asi por ahora." | Números de combate **validados de momento**. |
| v1 | Ritmo de la narración | "que vaya narrandose asi como en pokemon." | Narración mensaje a mensaje, estilo Pokémon (en implementación). |
| v1 | ¿El Único se distingue de un árbol? | "los únicos no son arboles, son monstruos." | Placeholder de criatura con los colores de su Bosque. Aspecto, tipos y nombres: #119. |
| v1 | Regeneración al huir | "Los Únicos pueden regenerarse con el tiempo." | Hoy recupera todos los PV al huir. Por tiempo cuando exista día/noche (#120). |
| v1 | Coste en Luz | "si por ahora." | N = 3 + d **validado de momento**. |

## Criterios de éxito para playtest
Propuestas de `game-designer`, a confirmar con el dueño:
- El jugador entiende sin ayuda las 3 opciones del borde y elige al menos una vez "Ofrecer N Luz" y al menos una vez "Enfrentar" en 15 minutos.
- La primera pelea (d = 1) dura entre 3 y 6 turnos del jugador.
- En 3 peleas, el jugador usa al menos 3 de las 4 acciones.
- El jugador vuelve al menos una vez a una villa para curarse antes de otro cruce, sin que se lo indiquen.
- El dueño dice que la pelea "se siente" como un combate clásico por menú (pregunta directa).

## Preguntas abiertas
- ~~De dónde sale la Luz además de ganar combates (#57).~~ Resuelta (ADR 0010): de las misiones de villa y de las ofrendas.
- Misiones de villa: tipos de peligro y recompensa (#106).
- Ofrendas: si hay cambio al pagar con una de más valor (#107, sin respuesta en ese punto). Valores y cómo se obtienen (#108). Qué se pierde al ser derrotado (#109).
- ~~Curación por riutash (#111); Bosque inicial sin villa (#110).~~ Resueltas (ADR 0010). Quedan las heridas graves (#114) y la estamina (#73).
- ~~Ofrenda en combate: ¿abre el borde?~~ Sí, abre el paso (ADR 0010). Falta saber si hace falta un valor mínimo (#112).
- Heridas graves: qué es un combate complicado, tipos y efectos, tiempo de espera del dumno, oficiantes de cada villa (#114, #116–#118).
- Inventario: cuadrícula, slots o peso (#113).
- Luz al superar `luz_max` (#115).
- **Tipos de Únicos**: cuáles y cuántos, y si dependen del Bosque o del temperamento (#22b). Aspecto como monstruos y nombres (#119).
- Regeneración de los Únicos con el tiempo (#120).
- **Iserald**: el Único más poderoso, que sale del propio Nujio (glosario §3). ¿Aparece? ¿Cuándo? (#103)
- **Combate contra varios Únicos**: el menú dice "sus Únicos" en plural, pero v1 tiene uno por Bosque. ¿Habrá grupos? (#103)
- ¿El Único de un Bosque protege todos sus bordes? ¿Desaparece al ser derrotado? (#104)
- Definición exacta de la distancia d (#105).
- Game over real en Aventura frente al "despertar" de v1 (ADR 0004; #21).
