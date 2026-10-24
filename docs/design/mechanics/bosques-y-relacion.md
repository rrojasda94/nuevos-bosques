# Ficha (backlog): Estados de Bosque, relación, peaje temporal, salvoconducto y dormir

> Dueño: `game-designer`. **Entra en la versión 0.3 "El Bosque recuerda"** (PR 2: relación; PR 3: estados; PR 7: dormir; PR 8: fruto; ver `docs/design/roadmap-0.3.md`). Sin números cerrados: los valores son **propuestas** que hay que confirmar.
>
> **Ya implementado en el PR 1 (ADR 0013)**:
> - hostilidad por Bosque (+1 por Botarramas vencido; peaje +2 y visión +2 por nivel);
> - relación por Bosque de −100 a 100 (−10 por victoria, +1 al pagar);
> - Bosque **forzado** (vencido) frente a **pagado**.
>
> Esta ficha amplía esa base. La regla de **−5 por vencer a sus Botarramas** que proponía la tabla de relación queda sustituida por **−10** (ADR 0013).
> Fuentes: palabras del dueño (abajo); glosario §1 ("Pensamiento"), §3 ("Nujio", "Bosque", "Fruto", "Iserald"), §6 ("Salvoconducto", multiplicador del Ista) y §7 ("Nuevos Bosques"); ADR 0004 (garelinos, fatales), ADR 0010 (ofrendas); `cruce-y-combate-v1.md`, `monstruos.md`, `tiempo-y-riutash.md`, `ofrendas-v1.md`.

## Objetivo
Que cada Bosque tenga un estado reconocible que cambie cómo se cruza y qué ofrece, y que la relación del adoc con cada Bosque abra rutas propias.

## Palabras del dueño
Primera ronda (2026-10-24):
> "algo que quiero que quede pendiente tambien es el tipo de bosque y cuan agresivo o pacifico es, tambien su nivel de cordura, si está siendo atacado o no. Tambien tener en cuenta los nuevos bosques que no cobran luz y tienen otro tipo de vida silvestre con seres mas similares a mamiferos o reptiles. Aparte si un bosque diferente te llama para una misión, este no te cobra Luz puede ayudarte a tener una ruta de salvoconducto por bosques buenos que no necesariamente es la ruta más corta. Mejorar la relación con algunos bosques puede ayudarte a bajar el precio de Luz por cruzar o estar ahí."

Segunda ronda (respuestas a #133–#136):
> "#134 si, debería tener un límite de tiempo el peaje pagado, a menos que tu amistad con el bosque sea alta.
> #135 llevar ofrendas de objetos y dejarlos en el bosque, ayudarlo con misiones, defenderlo de algun incendio o ataque, descansar riutash cerca al nujio. La relación se conserva entre sesiones, pero si hay game over o se empieza otra partidatodo se reinicia.
> #136 lo da el aceptar una misión de un bosque lejano luego de entrar en Pensamiento en la noche (dormir) durmiendo puedes oir o ver misiones distantes en áras o regiones más lejanas.
> #133 hay bosques sanos, bosques enojados, bosques corruptos, bosques muertos y bosques en necesidad de ayuda. Los sanos no tienen efecto, los enojados tienen muchos Únicos desplegados, no cobran entrada pero no eres bienvenido, deberas enfrentarte a varios únicos en diferentes momentos o tener algo que aumente tu velocidad o te camufle muy muy bien. Los bosques corruptos estan a punto de lanza su iserald y además cobran entrada, atacan a veces. Los bosques muertos solo tienen un numero limitado de Únicos a veces los Únicos idependientemente piden un poco de Luz, no tienen Nujio, se ve decadencia. Los Bosques que necesitan ayuda pueden presentar incendios, pero estos ayudan a jugador sin cobrar peaje, dan fruto (los normales tambien dan fruto) y algunos Únicos pelean junto a ti.."

## Pilares
- **Pilar 4**: el estado de cada Bosque cambia con la seed y con el tiempo. Cada partida tiene un mapa de estados distinto.
- **Pilar 1 (dos capas)**: lo que haces por un Bosque (ofrendas, misiones, defenderlo) cambia lo que el Bosque hace por ti.
- **Pilar 3 (legibilidad)**: cada estado se reconoce a simple vista (tabla "Cómo se ve").

## Presión de supervivencia
- **Añade**:
  - Los Bosques **enojados** (muchos Únicos, no hay pago posible) y los **corruptos** (peaje, ataques, riesgo de Iserald, que es fatal).
  - El peaje pagado **caduca**.
- **Alivia**:
  - Los Bosques **en necesidad de ayuda** (sin peaje, fruto, Únicos aliados) y los **Nuevos Bosques** (sin peaje de Luz).
  - La amistad alta hace el paso permanente.
  - El salvoconducto de las misiones lejanas.
  - El fruto.

## Estados de Bosque (reglas del dueño y propuestas)
Sustituyen al `temperament` numérico de la versión anterior de esta ficha.

| Estado | Lo que dijo el dueño | Peaje | Únicos | Otros efectos (propuesta salvo cita) |
|---|---|---|---|---|
| **sano** | "no tienen efecto"; "dan fruto" | Normal: N = 3 + d, modificado por la relación | Botarramas normales (`monstruos.md`) | Fruto. |
| **enojado** | "muchos Únicos desplegados, no cobran entrada pero no eres bienvenido, deberas enfrentarte a varios únicos en diferentes momentos o tener algo que aumente tu velocidad o te camufle muy muy bien" | **No se puede pagar**: el menú del borde no ofrece "Ofrecer Luz" ni ofrendas | Muchos: ×2 Botarramas por tramo y además Únicos que patrullan dentro, con encuentros repetidos | Para cruzarlo hay que vencerlos, ser más rápido (objetos de velocidad) o un camuflaje "muy muy bueno" (`sigilo-y-robo.md`). Sin fruto. |
| **corrupto** | "estan a punto de lanza su iserald y además cobran entrada, atacan a veces" | Sí: N × 1,5 (propuesta) | Normales, más **emboscadas** ocasionales dentro (por ejemplo, 1 cada 3 minutos de reloj con probabilidad) | Riesgo de **Iserald** (fatal, `monstruos.md`): ¿cuándo lo lanza? (#139). Sin fruto. |
| **muerto** | "solo tienen un numero limitado de Únicos a veces los Únicos idependientemente piden un poco de Luz, no tienen Nujio, se ve decadencia" | Sin peaje del Bosque | Pocos (por ejemplo, 1–2 en todo el Bosque). **A veces un Único pide Luz por su cuenta** (1–2): se paga o se pelea | Sin Nujio, así que no hay descanso de Nujio. Decadencia visible. Sin fruto (#140). **Un Bosque pasa a muerto cuando se desata su Iserald: el Nujio muere** (dueño). Sus artesanos, si los hay, pueden no tener materiales (`npcs-y-villas.md`). |
| **en necesidad de ayuda** | "pueden presentar incendios, pero estos ayudan a jugador sin cobrar peaje, dan fruto [...] y algunos Únicos pelean junto a ti" | **0** | **Aliados**: en combates dentro de este Bosque (o contra quien lo ataca), 1 Único del Bosque pelea a tu lado (propuesta) | **Incendios** (peligro y misión de defensa). Fruto. Defenderlo sube mucho la relación. |
| **Nuevo Bosque** (`kind` aparte) | "no cobran luz y tienen otro tipo de vida silvestre con seres mas similares a mamiferos o reptiles" | **0** de Luz | Sin Botarramas. Fauna de mamíferos y reptiles (#137) | — |

### Relación con la cordura y el "bajo ataque"
| Campo del modelo | Relación con los estados (propuesta) |
|---|---|
| `sanity` (0–100; glosario: el Nujio "puede perder la cordura") | sano ≥ 50. Por debajo de 20, el Bosque pasa a **corrupto** (Iserald inminente). La cordura no aplica a los **muertos** (sin Nujio). |
| `under_attack` / `hazard` (incendio, garelinos) | Si es verdadero y la cordura es ≥ 20, el estado es **en necesidad de ayuda**. Si nadie lo ayuda, la cordura baja con el tiempo. |
| Enojado | No depende de la cordura: es hostilidad hacia los forasteros. Puede venir de la generación o de que el jugador lo haya agraviado (relación ≤ −50, propuesta). |
| Muerto | Sin Nujio: un Nujio muerto (por ejemplo, tras Iserald, como cuenta el glosario §7) o cansado de existir (glosario §3). |

### Cómo se ve (#133)
| Estado | Señal visual (propuesta para `pixel-artist` y `world-gen-dev`) |
|---|---|
| sano | Colores plenos de su combinación; frutos en los árboles. |
| enojado | Más siluetas de Únicos a la vista; colores más saturados o rojizos en la vegetación del borde. |
| corrupto | Colores alterados o manchados; el Nujio con un aura extraña. |
| muerto | Decadencia: árboles secos o grises, sin frutos, sin Nujio. |
| en necesidad de ayuda | Humo o llamas (incendios), Únicos heridos. |
| Nuevo Bosque | Troncos de color madera y hojas verdes (glosario §7). |

El letrero y el mapa (M) podrían indicar el estado con texto o color (`navegacion.md`).

## Peaje con caducidad (#134)
- **Regla del dueño**: el peaje pagado tiene **límite de tiempo**, salvo que la **amistad con el Bosque sea alta**.
- **Confirmado por el dueño** ("#134 si"):
  - Pagar abre el Bosque **hasta el segundo riutash siguiente** (más o menos un ciclo día/noche: ~13 min de reloj, `tiempo-y-riutash.md`).
  - Con **relación ≥ 60** ("amistad alta"), el paso es **permanente**.
- ~~Vencer a los Botarramas abre por el mismo tiempo.~~ Sustituido por ADR 0013: vencer deja el Bosque "forzado" (#141).
- **Cambio técnico**: hoy `open_bosques` es permanente (ADR 0009). Pasará a guardar por Bosque **hasta cuándo** está abierto (número de riutash), más la marca de permanente por amistad.

## Relación con cada Bosque (#135)
- **Suben la relación** (dueño): dejar **ofrendas de objetos** en el Bosque, **ayudarlo con misiones**, **defenderlo de incendios o ataques** y **descansar el riutash cerca de su Nujio**.
- **Persistencia** (dueño): se **conserva entre sesiones** (va en el guardado). Un **game over** o una **partida nueva** la reinician.

| Acción | Cambio propuesto en `relation` (−100 … +100, empieza en 0) |
|---|---|
| Dejar una ofrenda (como peaje o de forma voluntaria junto al Nujio) | + su valor en Luz (3–8; implementado así en el PR #33) |
| Completar una misión para ese Bosque | +25 |
| Defenderlo de un incendio o un ataque | +15 |
| Descansar el riutash junto a su Nujio (a **≤ 6 casillas** del Nujio, o en la plaza de su villa; implementado en el PR de relación #33) | +5, una vez por riutash |
| Pagar el peaje con Luz suelta | +1 (propuesta; el dueño no lo nombró) |
| Vencer a sus Botarramas | **−10** (ADR 0013, implementado), además de +1 de hostilidad |
| Robar en él: por ahora, un segundo fruto del mismo Bosque en el mismo Momento, o fruto de un Bosque no pagado | **−20** y hostilidad +1 (implementado en el PR "frutos") |
| Pagar con una ofrenda | Además: **hostilidad −1**, sin bajar de 0 ("el bosque olvida con ofrendas", #147) |
| Sacar del Bosque un fruto guardado | **−5** por fruto y por salida (implementado) |
| Comer fuera de su Bosque un fruto guardado | **−5 más** con el Bosque de origen (implementado, PR #39) |
| Atacar con E a un Único pasivo de un Bosque pagado (ofensa) | **−10** y hostilidad +1; el Bosque queda forzado (implementado, PR #39) |

| Umbral (propuesta) | Efecto |
|---|---|
| ≥ 60, amistad alta | Peaje pagado permanente; peaje × 0,5 |
| ≥ 30 | Peaje × 0,75; cuenta como "Bosque bueno" para el salvoconducto |
| ≤ −30 | Peaje × 1,5 |
| ≤ −50 | El Bosque puede volverse **enojado** con el jugador |

- **Valores y umbrales de relación confirmados por el dueño** ("#135 si perfecto"): los de las dos tablas anteriores, con la amistad alta en relación ≥ 60.
- "Precio por estar ahí" (primera ronda): la caducidad del peaje es el coste de permanecer. No hace falta un cobro aparte por tiempo (lectura de `game-designer`, a confirmar).

## Dormir y Pensamiento (#136, salvoconducto)
- **Regla del dueño**: durmiendo de noche se entra en **Pensamiento** (glosario §1: "Mundo entre la Luz y el mundo físico, a donde va la Mente al dormir") y se pueden **oír o ver misiones distantes** en áreas o regiones lejanas. **Aceptar** una de esas misiones de un **Bosque lejano** da un **salvoconducto**.
- **Reglas del dueño sobre dormir** (respuesta a #142): "en villas y refugios y si pasa el tiempo, solo se debe dormir de noche, dormir de dia consume Luz. Gietos detesta el descanso."
  - Se duerme en **villas y refugios**.
  - Dormir **hace pasar el tiempo**.
  - Lo normal es dormir **de noche** (Momento de Riumna). Dormir **de día** (Momento de Gietos) es posible, pero **consume Luz**, porque "Gietos detesta el descanso". Encaja con el glosario §1: Gietos "pide que el mundo sea activo y vivaz", y desobedecer los mandatos de los Ojos puede volver adversos los Humores.
  - Solo dormir de noche permite entrar en **Pensamiento** y oír misiones lejanas (#136).
- **Propuesta de dormir** (valores provisionales):
  - Acción "Dormir" con E en un refugio o en la plaza o una casa de una villa.
  - **De noche**:
    - Salta el tiempo hasta el **riutash del amanecer**, que se pasa dormido en refugio: cuenta como **refugiado** y cura el 50% de los PV que faltan (`tiempo-y-riutash.md`).
    - Gratis.
    - El resto del mundo avanza durante el salto (por ejemplo, el Ofomni sigue su ruta).
    - Al despertar, con probabilidad **1/2**, llega una **visión de Pensamiento** con una misión lejana (diálogo para aceptarla o no).
  - **De día**:
    - Salta el tiempo hasta el **riutash del atardecer**, también como refugiado.
    - Cuesta **1 de Luz suelta por cada 2 minutos de reloj saltados** (redondeando hacia arriba; como máximo 4, porque el día dura 8 min).
    - Sin visiones de Pensamiento.
    - Si no hay Luz suficiente, la opción aparece desactivada.
  - Efecto sobre los Humores al dormir de día (glosario): fuera de alcance mientras no existan los Humores (#145).
- **Salvoconducto** (propuesta):
  - Al aceptar, el Bosque que llama no cobra peaje y se marca una **ruta por Bosques buenos** (estado sano o en necesidad de ayuda, o relación ≥ 30) hasta él. No tiene por qué ser la ruta más corta.
  - Mientras la misión siga activa, esos Bosques no cobran peaje.
  - Termina al completar o fallar la misión.

## Fruto
- **Regla del dueño**: los Bosques **sanos** y los **en necesidad de ayuda** dan fruto. Glosario §3: el fruto es "solo alimento [...] contiene lo necesario para mantener vivo y sano a un ser".
- **Adelantado al principio de la 0.3** (PR 2 "frutos", en implementación por `world-gen-dev`). Palabras del dueño: "Debemos incorporar los frutos, porque ya que no es facil recuperarse, los bosques normales deben dar frutos y con eso poder recuperar algo de vida. solo puedes tomar 1 fruto por Momento, sino es un robo al boque."
- **Respuesta del dueño a #149**: "en el bosque puedes encontrar frutos, si pagas tu peaje puedes tomar un fruto por momento. Pero si en otro arbol del mismo bosque tomas un futo, es robo. solo 1 por momento. el arbol del que tomaste queda vacio. No todos los arboles tienen fruto."
- **Reglas** (valores provisionales):
  - **No todos los árboles tienen fruto**: solo los **frutales** (tile `FRUIT_TREE`) de los Bosques normales (sanos; más adelante, también los que necesitan ayuda).
  - Con **E** se toma un fruto, que cura el **25% de los PV máximos**.
  - **1 fruto por Momento y por Bosque**, y solo si **pagaste el peaje** de ese Bosque o es el **Bosque natal**.
  - **Es robo**:
    - un **segundo fruto del mismo Bosque en el mismo Momento**, de cualquier árbol;
    - **cualquier fruto de un Bosque no pagado** (cerrado o forzado).
    - Efecto: **hostilidad +1** y **relación −20** con ese Bosque. Más adelante, también despierta a los Ofomni (`sigilo-y-robo.md`).
  - El árbol del que se toma el fruto **queda vacío** hasta el riutash.
- Esto cierra la pregunta del fruto como robo (#144) y la #149.
- **Implementado** (PR de frutos, 0.3): 3–6 frutales por chunk junto a claros y senderos, alcanzables desde una casilla vecina; valores en `balance.json` (`fruit.heal_pct`, `bosque_memory.hostility_per_theft` y `relation_per_theft`). Antes de robar, el juego avisa y deja elegir "Tomarlo igualmente" o "Dejarlo". El robo emite `EventBus.bosque_robbed`, donde se engancharán los Ofomni.
- **Feedback del dueño**: "los frutos se ven bien."
- **Frutos guardables** (dueño: "con la vida llena o con daño puedes elegir solo coger el fruto y almacenarlo en el inventario para consumirlo dentro del bosque luego. no puedes sacar un fruto de su bosque sino dañas su relación"). Se implementan en el PR de inventario (PR 5 de la 0.3).
  - Al tomar un fruto (lícito) se elige **"Comer"** o **"Guardar"**, con los PV llenos o con daño.
  - Un fruto guardado ocupa una casilla del inventario y recuerda su **Bosque de origen**.
  - ~~Solo se puede comer dentro de su Bosque.~~ **Corregido** (dueño, tras jugar: "Puedes comer el fruto del bosque en otro lado pero el bosque de donde salio ese fruto y esto perjudica tu relación con dicho bosque"):
    - **Se puede comer en cualquier sitio**.
    - Comerlo **fuera de su Bosque** baja la relación con el Bosque de origen **−5 más** (implementado, PR #39).
  - **Sacarlo de su Bosque** baja la relación con él: **−5 por fruto y por salida**. El fruto no se pierde al salir.
  - Tomar o comer más de un fruto (robo) **alerta a los Ofomni**, que persiguen (`sigilo-y-robo.md`, implementado).
  - Tomarlo para guardar cuenta igual para el límite de 1 por Momento y por Bosque.

## Salvar los Bosques (0.5, propuesta)
Palabras del dueño (2026-10-24): "salvar los bosques".
- **Bosque en necesidad de ayuda con incendio**:
  - Encargo "Apagar el incendio": hay **3–5 focos** (casillas de fuego) en un chunk del Bosque y se apagan con **E**, uno por uno.
  - El fuego se extiende 1 casilla por minuto de reloj. Si en **6 minutos** quedan focos, el Bosque pierde cordura (−20).
  - Recompensa: relación **+15**, Senda **+5**, **+1 de fama**, y el Bosque pasa a **sano**.
- **Bosque en necesidad de ayuda bajo ataque** (garelinos u otros):
  - Combate en grupo contra los atacantes, con **Únicos del Bosque como aliados** (y otros adoc, `otros-adoc.md`).
  - Mismas recompensas.
  - Si los atacantes son personas, la regla de no matar (ADR 0004) obliga a una resolución que no los mate (¿se retiran al perder?) (#157).
- **Bosque corrupto**:
  - Se puede **recuperar cordura** dejando ofrendas junto a su Nujio (+2 de cordura por cada punto de valor de la ofrenda) y descansando el riutash cerca de él (+5).
  - Si la cordura vuelve a ≥ 20, el Bosque deja de estar a punto de lanzar a su Iserald.
  - Recompensa al pasar a sano: relación +25, Senda +5.
- **Origen de estos encargos**: el Sfida de una villa, otros adoc (encargos compartidos), o una visión al dormir (Pensamiento) para Bosques lejanos, que da salvoconducto.

## Modelo de datos actualizado (por Bosque)
| Campo | Tipo | Valores | Persistencia |
|---|---|---|---|
| `kind` | enum | `nujio`, `nuevo_bosque` | Generación (seed) |
| `state` | enum | `sano`, `enojado`, `corrupto`, `muerto`, `necesita_ayuda` (solo `kind == nujio`) | Generación; cambia con eventos |
| `sanity` | int | 0–100 (no aplica a `muerto` ni a `nuevo_bosque`). Baja con cualquier cosa mala (robo −10, Botarramas vencido −5, dañar el Bosque −20, ataque de garelinos −10 por Momento, incendio no apagado −20). Con 0 se **desata el Iserald** (`monstruos.md`) | Guardado |
| `hazard` | enum o nulo | `null`, `incendio`, `ataque` (garelinos u otros) | Guardado |
| `relation` | int | −100 … +100 | Guardado por partida; se reinicia con un game over o una partida nueva |
| `open_until` | int o `PERMANENT` | Número de riutash hasta el que el paso está abierto | Guardado |
| `fruit_ready` | por árbol o por chunk | bool + riutash de rebrote | Guardado |
| `hostility` | int ≥ 0, con tope | +1 por Botarramas vencido o robo; −1 por pago con ofrenda (ADR 0013, #147) | Guardado |
| `fruit_taken_momento` | id del Momento | Momento en que se tomó el último fruto de ese Bosque | Guardado |
| `access` | enum | `cerrado`, `forzado`, `pagado` (ADR 0013; más `open_until` cuando caduque el pago) | Guardado |

### Peaje combinado (forma propuesta)
```
si kind == nuevo_bosque or state in [necesita_ayuda, muerto] -> 0
   (en muerto, un Único puede pedir 1–2 de Luz por su cuenta)
si salvoconducto activo y el Bosque está en la ruta -> 0
si state == enojado -> no se puede pagar (solo Enfrentar o Retroceder)
si no: N = (3 + d + 2 × hostilidad) × f_state × f_relation   (hostilidad: ADR 0013)
   f_state: sano 1, corrupto 1,5
   f_relation: ×0,5 (≥ 60), ×0,75 (≥ 30), ×1 (entre −29 y 29), ×1,5 (≤ −30)
N ≥ 1
```

## Casos límite
- **Caduca el paso mientras el jugador está dentro del Bosque**: puede salir libremente hacia el Bosque por el que entró; para volver a entrar, paga otra vez.
- **El Bosque cambia de estado con el jugador dentro** (por ejemplo, de sano a corrupto): aplica el nuevo estado desde ese momento.
- **Iserald se desata con el jugador en el Bosque**: aparece el Iserald (fatal) y el estado Miedo. Lo sensato es huir; solo un grupo de adoc puede vencerlo (`monstruos.md`, "Iserald"). Se desata con la cordura a 0, por daño al Bosque, por garelinos o porque el Nujio ya tenía la cordura al mínimo (dueño; #139).
- **Salvoconducto por un Bosque que se vuelve enojado**: sale de la ruta. Se recalcula una ruta buena, si existe.
- **Dormir de día sin Luz suficiente**: la opción aparece desactivada, con el coste a la vista.
- **Dormir con la misión del Ofomni activa**: el salto de tiempo puede acercarlo a la villa. El diálogo de "Dormir" debería avisarlo (propuesta).
- **Relación ≥ 60 con un Bosque corrupto**: el peaje es permanente, pero el riesgo de Iserald sigue.

## Criterios de éxito para playtest (borrador)
- El jugador identifica el estado de un Bosque antes de cruzarlo (pregunta: "¿cómo estaba ese Bosque?").
- El jugador elige alguna vez una ruta de salvoconducto más larga.
- Tras varias ofrendas y descansos, el jugador nota que el paso le cuesta menos o es permanente.
- El jugador usa "Dormir" y entiende que puede revelar misiones lejanas.

## Preguntas abiertas
- **#139**: corrupto e Iserald: ¿cuándo lo lanza un Bosque corrupto? ¿Se puede evitar (subir la cordura, ofrendas)? ¿Cómo se ve?
- **#140**: Bosques muertos: ¿se pueden revivir (Nuevos Bosques sembrados por garelinos, glosario §7)? ¿Cuánta Luz pide el Único "independiente"?
- **#141**: ¿vencer a los Botarramas también abre el paso solo por un tiempo, como pagar?
- ~~**#142**: dormir.~~ Resuelta: en villas y refugios, hace pasar el tiempo, de noche es lo normal y de día consume Luz. Siguen siendo propuestas el salto exacto, el coste de día y la frecuencia de las visiones.
- **#145**: ¿dormir de día vuelve adversos los Humores (glosario §1)? ¿Tiene más castigos que la Luz?
- **#143**: aliados: ¿cuántos Únicos pelean a tu lado en un Bosque en necesidad de ayuda? ¿Qué hacen en combate (atacan, curan)? ¿Pueden caer?
- **#144**: fruto: ¿qué hace exactamente (curar PV, estamina, heridas)? ¿Se puede llevar en el inventario?
- **#137**: fauna de los Nuevos Bosques.
- **#138**: cómo cambian la cordura y el estado de ataque.
