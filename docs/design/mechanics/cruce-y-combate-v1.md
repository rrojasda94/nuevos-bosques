# Ficha: Cruce de Bosques y combate v1 (modo Aventura, versión de prueba)

> Dueño: `game-designer`. Estado: v1, **versión de prueba**. Lo implementa `rpg-systems-dev` en paralelo.
> **Todos los números son PROVISIONALES**: los fijó el coordinador y se registran tal cual. Los posibles problemas de balance van como "propuesta de ajuste" y **no cambian los números de esta versión**.
> Fuentes: ADR 0002 (combate por menú y por turnos), ADR 0007 (para pasar a otro Bosque con Nujio: pagar Luz o enfrentarse a sus Únicos; más lejos, más difícil), ADR 0008 (Nujio en el centro del Bosque), **ADR 0010 (economía de Luz, ofrendas y curación)** y el glosario (§3 Únicos, §5 Adoc).
>
> **Cambio v1.1 (ADR 0010):** la curación pasa de "junto a cualquier Nujio" a "en la plaza o junto al Nujio de una villa". La curación por riutash espera al ciclo día/noche. Las ofrendas (artefactos de Luz que se usan enteros) son la siguiente iteración: v1.1 sigue usando Luz suelta.

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

### Distancia
- **distancia (d)** = número de saltos en el grafo de adyacencia de Bosques, desde el Bosque inicial hasta el **Bosque al que se intenta entrar**.
  - Se entiende que d se mide hasta el Bosque de destino. Si `rpg-systems-dev` la mide de otra forma, hay que unificarlo (#105).
- Un Bosque vecino del inicial tiene d = 1.

### Menú del borde
Al llegar al borde de un Bosque todavía no abierto aparece un menú:
1. **"Ofrecer N Luz"**, con **N = 3 + d**. Pagar abre el borde.
2. **"Enfrentar a sus Únicos"**: inicia el combate contra el Único del Bosque de destino.
3. **"Retroceder"**: vuelves a tu lado del borde sin coste.

Pagar o ganar **abre ese borde** (entre esos dos Bosques) **para el resto de la partida**, en los dos sentidos.

### Único (provisional)
- **Uno por Bosque**, generado por seed.
- Toma la **silueta y los colores de su Bosque**: según el glosario §3, nace de un árbol, un animal o una sustancia del Bosque. En v1 usa el tipo de árbol y la combinación de colores del Bosque (ADR 0008).
- Nombre provisional: **"Único de <tipo de árbol>"**.

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
- **Derrota** (PV del jugador a 0): **despiertas en el centro de tu Bosque inicial** con los PV completos y **pierdes la mitad de tu Luz**, redondeando hacia abajo.

### Curación (v1.1, ADR 0010)
- Los PV **se mantienen entre combates**.
- ~~Descansar junto a cualquier Nujio recupera los PV.~~ Sustituido: **estar en la plaza o junto al Nujio de una villa** recupera los PV por completo. La villa está en el chunk central de su Bosque, alrededor del Nujio (ADR 0008).
- **Tras un riutash** (cambio entre día y noche): también cura, según el dueño. Pendiente de que exista el ciclo día/noche (#75). Cuánto cura: #111.
- Ver el caso límite "Bosque inicial sin villa" (#110).

### Fuentes de Luz (ADR 0010)
- **v1**: ganar contra un Único da +1 de Luz.
- **Siguiente iteración**: ayudar a la gente de la villa con sus peligros (misiones de villa, #106).
- **Ofrendas** (siguiente iteración): una villa puede otorgar artefactos que almacenan Luz, de valores distintos. Se usan **enteros**: para pagar, el artefacto se deja completo en el Bosque y se pierde todo su valor aunque el coste fuera menor. Preguntas: #107–#109.

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
- **Huir con éxito**: vuelves a tu lado del borde y el borde sigue cerrado. Si el Único conserva su daño al volver a enfrentarlo: por definir (propuesta de ajuste 4).
- **Huida fallida (25%)**: se pierde el turno y el Único ataca.
- **Derrota con 0 o 1 de Luz**: pierdes ⌊Luz/2⌋ = 0. La partida sigue.
- **Defender seguido de Huir con éxito**: la reducción no se aplica, porque no hay turno siguiente.
- **Llegar con pocos PV a un borde lejano**: solo hay curación en villas (v1.1). Hay que volver a una villa accesible.
- **Bosque inicial sin villa** (4 de cada 5 Bosques, ADR 0008): hasta que exista el riutash, el jugador solo recupera PV al ser derrotado (despierta con PV completos). Propuesta de ajuste 6. Pregunta: #110.
- **Ninguna villa accesible**: lo mismo que el caso anterior.
- **Varios bordes del mismo Bosque**: si el Único de ese Bosque ya fue derrotado (o se pagó por otro borde), ¿protege sus otros bordes? Por definir (#104).
- **Bosques sin Nujio (Nuevos Bosques)**: ¿hay borde y Único? Por definir (#70). En v1 se asume que todos los Bosques tienen Nujio.

## Propuestas de ajuste (no cambian v1)
1. **Defender casi nunca compensa**: renuncia a ~4,5 de daño infligido para ahorrar ~1–3 de daño recibido, sin otro beneficio. Propuesta: que además dé algo (por ejemplo, +2 al siguiente ataque) o que reduzca todo el daño del turno en curso.
2. ~~**A partir de d = 4 no se puede ganar solo atacando.**~~ **Cerrada**: el dueño confirma que es intencionado que al principio sea complicado ir lejos (ADR 0010).
3. **Tope de DEF**: propuesta DEF máx. = 4, para que el daño base del jugador (ATQ 6) nunca baje de 2 antes del aleatorio.
4. **Huir y volver**: si el Único conserva el daño recibido, se puede "picar, huir, curarse en una villa y volver" hasta ganar cualquier pelea. Propuesta: el Único recupera sus PV completos cuando el jugador huye o retrocede.
5. ~~**Economía de Luz cerrada.**~~ **Resuelta en parte** (ADR 0010): habrá misiones de villa y ofrendas. En v1.1 la economía sigue cerrada hasta que se implementen.
6. **Curación escasa en v1.1**: con villa solo en 1 de cada 5 Bosques y sin riutash todavía, la mayoría de partidas no tendrá dónde curarse al principio. Propuesta: garantizar que el Bosque inicial de Aventura tenga villa (#110), o adelantar una curación por riutash simplificada.
7. **Ofrendas enteras**: si una ofrenda vale más que N, se pierde el excedente. Para que la decisión sea interesante, conviene que haya ofrendas de valores bajos (por ejemplo, del orden de N = 4–6) y no solo grandes.

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
- Ofrendas: si convive la Luz suelta con ellas, si hay cambio, si sirven para "Ofrecer Luz" en combate, si hay límite de inventario (#107). Valores y cómo se obtienen (#108). Qué se pierde al ser derrotado (#109).
- Curación por riutash: cuánto cura (#111). Bosque inicial sin villa (#110).
- **Tipos de Únicos**: cuáles y cuántos, y si dependen del Bosque o del temperamento (#22b).
- **Iserald**: el Único más poderoso, que sale del propio Nujio (glosario §3). ¿Aparece? ¿Cuándo? (#103)
- **Combate contra varios Únicos**: el menú dice "sus Únicos" en plural, pero v1 tiene uno por Bosque. ¿Habrá grupos? (#103)
- ¿El Único de un Bosque protege todos sus bordes? ¿Desaparece al ser derrotado? (#104)
- Definición exacta de la distancia d (#105).
- Game over real en Aventura frente al "despertar" de v1 (ADR 0004; #21).
