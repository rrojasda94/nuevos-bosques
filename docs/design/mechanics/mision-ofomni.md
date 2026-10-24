# Ficha: Misión "Primer encargo" — interceptar al Ofomni

> Dueño: `game-designer`. Versión 0.2.0 "Primer encargo". Fuentes: palabras del dueño (abajo), glosario (§1 "Pensamiento", §3 "Únicos" y "Ofomni", §5 "Sfida" y "Adoc"), `cruce-y-combate-v1.md`, `progresion-adoc.md`, `tiempo-y-riutash.md`.
> **Valores PROVISIONALES**, en `data/quests/primera_mision.json` y `data/combat/balance.json`. Implementación: `rpg-systems-dev` (PR 6). Los textos son de `narrative-writer`.

## Objetivo
Dar un motivo para explorar, cruzar Bosques y pelear: la primera misión del adoc.

Palabras del dueño: "el sfida de la villa te aborda y te dice que el nujio ha oido algo en Pensamiento. Hay un ofomni, un ojo con tentáculos que ha crazdo ya varios bosques y viene en dirección a nuestra villa. La misión en interceptar al ofomni y vencerlo. Le comenta que puede ser una misión dificl ya que sería la primera, pero los otros adoc han salido a otras misiones."

Si el Ofomni llega a la villa: "la misión falla y la villa queda dañada; la partida sigue" (respuesta del dueño, plan 0.2.0).

## Pilares
- **Pilar 1 (dos capas)**: la villa pide ayuda y el adoc sale al Bosque.
- **Pilar 2**: una misión completa (oferta → viaje → combate → recompensa) cabe en 15–25 minutos.
- **Pilar 3**: una brújula, un enemigo visible y un objetivo de una línea ("Intercepta al Ofomni").
- **Pilar 4**: la ruta del Ofomni depende de la seed y del grafo de Bosques.

## Presión de supervivencia
- **Añade**:
  - **Reloj**: el Ofomni avanza un Bosque cada 6 minutos hacia la villa natal.
  - **Rival duro**: hace falta nivel 2–3 y Luz.
  - **Coste del fracaso**: villa dañada y la mitad de la Luz suelta.
  - El jugador tiene que elegir entre pelear con los Únicos del camino (XP, riesgo) y pagar los peajes (Luz que luego le falta contra el Ofomni).
- **Alivia**: la recompensa rellena la Luz y da una ofrenda.

## Reglas

### Estados
`offered` → `active` → `completed` → `rewarded`, o bien `active` → `failed`.

| Estado | Cuándo |
|---|---|
| `offered` | Al empezar la partida: el sfida espera en la plaza de la villa natal. La brújula apunta a él (`navegacion.md`). |
| `active` | Al hablar con el sfida (E) y aceptar. El Ofomni empieza a moverse. |
| `completed` | Al vencer al Ofomni. |
| `rewarded` | Al volver a hablar con el sfida (E) después de `completed`. Recompensa, una sola vez. |
| `failed` | Si el Ofomni entra en el **Bosque natal** con la misión `active`. |

- **Diálogo del sfida**: oferta, recordatorio (si se le habla con la misión `active`), victoria y fracaso. Textos de `narrative-writer` en `data/quests/` y `data/npcs/`. Contenido de la oferta: el Nujio ha oído en Pensamiento que un Ofomni, un ojo con tentáculos, ha cruzado varios Bosques y viene hacia la villa. Será difícil por ser la primera misión, pero los otros adoc han salido a otras misiones.
- **¿Se puede rechazar?** En la 0.2.0 no hay opción de rechazar. Si el jugador no habla con el sfida, la misión sigue en `offered` y el Ofomni no se mueve.

### El Ofomni
- Es un **Único** de tipo Ofomni (glosario §3: subtipo de Únicos). Según el dueño, es un **ojo con tentáculos**. Placeholder: `UnicoArt.Kind.EYES`, más grande.
- **Aparición**: en un Bosque a **3 o 4 saltos** del Bosque natal (por seed), conectado por la adyacencia de `BosqueMap`.
- **Movimiento**: cada **6 minutos de reloj** (sin pausa) avanza **un Bosque** por el camino más corto hacia el Bosque natal. Con desempates deterministas por seed.
  - Desde 3 saltos llega en 18 minutos (unos 1,4 ciclos día/noche).
  - Desde 4 saltos, en 24 minutos.
- **Visibilidad**:
  - Dentro de su Bosque se ve como sprite en un chunk. Si su Bosque tiene varios chunks, se coloca en el chunk más cercano a la villa natal, del lado por donde avanza.
  - Al tocarlo empieza el combate.
- **Rastro**:
  - El sfida da la posición inicial al aceptar.
  - En cada **riutash** el Nujio "vuelve a oír" y se actualiza la última posición conocida en el mapa y en la brújula.
  - Entre riutash, la brújula apunta a la última posición conocida.

### Combate contra el Ofomni
- **Es un Ofomni descarriado** (`ofomni_descarriado`; 0.3). El dueño señaló: "el ofomni de la mision y el de los bosques con nujio no estan diferenciados".
  - El de la misión está en modo berserk y tiene **`appeasable: false`**: no acepta Luz ni ofrendas y hay que vencerlo.
  - El `ofomni` normal de un Bosque con Nujio sí se apacigua y será el perseguidor por robo (`monstruos.md`).
- **Distancia fija**: d_ofomni = (saltos del Bosque de aparición al Bosque natal) + 1, es decir, **4 o 5**, con las fórmulas de Único de v1.
  - Se fija al aparecer y **no cambia** aunque el Ofomni se acerque. Así no compensa esperar a que esté cerca, y se evita un exploit.
  - Hasta la 0.2.0: d = 4: PV 34, ATQ 8, DEF 3; d = 5: PV 38, ATQ 9, DEF 3.
  - **Desde la 0.3** (ADR 0013): PV reducidos (factor `hp_factor` en `balance.json`), ATQ y DEF iguales. Recomendación de `game-designer`: **×0,7** → d = 4: **PV 24**; d = 5: **PV 27**. Ver "Balance 0.3".
- **Látigos** (confirmado por el dueño: "el ofomni ataca con latigos y cada 3 turnos usa varios latigos"):
  - El **ataque normal** del Ofomni es un **latigazo** (uno de sus tentáculos), con la fórmula de daño normal. Texto: `ofomni_whip_hit`.
  - **Latigazo múltiple**: cada **3.er ataque** usa **varios látigos** y hace **×3 de daño**.
  - Se **anuncia** en el mensaje del turno anterior: "El Ofomni alza todos sus látigos..." (`ofomni_whips_warning`).
  - **Defender** lo reduce a la mitad (×1,5). Textos: `ofomni_whips_hit` y `ofomni_whips_defended` en `data/text/sistema.json`.
  - Da sentido a Defender: con pocos PV, un Latigazo múltiple sin defender puede matar (~13–20 de daño).
  - Las claves de texto `ofomni_gaze_*` pasan a llamarse `ofomni_whips_*`, y se añade `ofomni_whip_hit`. El código tiene que usar las claves nuevas.
- **No guarda bordes**: los guardianes del paso son los Botarramas (`monstruos.md`). En la 0.3.0 los Ofomni también serán perseguidores tras un robo (`sigilo-y-robo.md`).
- **No es fatal en la primera misión** (confirmado por el dueño, 2026-10-24: "El ofomni es no fatal en la primera mision"): perder contra él no es game over. `fatal_at: []` (`monstruos.md`).
- **Acciones** (0.3): **Atacar, Defender y Huir** (75%). **"Ofrecer Luz" y "Ofrecer ofrenda" están desactivadas** porque es `appeasable: false`: desde la 0.3 esas acciones sirven para pagar y que el Único se vaya (ADR 0013), y la misión es vencerlo. Hasta la 0.2.0, Ofrecer Luz hacía 8 de daño.
- **No abre Bosques** ni usa `battle_attempts` por Bosque (tiene su propia semilla de combate).
- Al **huir**, el Ofomni recupera todos sus PV (como los Únicos) y sigue su ruta.
- **Derrota**: el Ofomni es **no fatal** en esta misión (confirmado; ADR 0004). Despiertas en la villa natal (regla de v1: PV completos, mitad de la Luz suelta). El Ofomni **sigue avanzando**.

### Balance 0.3 (sin "Ofrecer Luz"; valores medios con el Latigazo múltiple; daño recibido frente a los PV del adoc)
Estrategia: solo atacar. Defender ante el Latigazo múltiple no cambia la media (alarga la pelea un turno), pero evita picos mortales.

| Adoc | d = 4, PV ×0,85 (29/8/3) | d = 4, **PV ×0,7 (24/8/3)** | d = 5, PV ×0,85 (32/9/3) | d = 5, **PV ×0,7 (27/9/3)** |
|---|---|---|---|---|
| Nivel 1 (30/6/3) | pierde (~66) | pierde (~55) | pierde | pierde |
| Nivel 2 (34/7/3) | pierde (~55) | pierde por poco (~39 de 34) | pierde (~72) | pierde (~46) |
| Nivel 3 (38/7/4) | **pierde** (~45 de 38) | **gana** (~32 de 38) | pierde (~61) | justo (~39 de 38) |
| Nivel 4 (42/8/4) | gana (~32 de 42) | gana (~27 de 42) | justo (~39 de 42) | gana (~33 de 42) |

- **Con −15%** (propuesta del coordinador), el Ofomni de d = 4 **ya no se puede ganar en nivel 3**: hace falta nivel 4. Rompe la dificultad que confirmó el dueño ("ganable desde nivel 3").
- **Con −30% (recomendado)**, el nivel 3 contra d = 4 queda igual que en la 0.2.0 con Luz (~32 de 38), y d = 5 en nivel 3 es justo (antes exigía la Luz llena).
- **Alternativa**: −15% de PV y −1 de ATQ (d = 4: 29/7/3). Con nivel 3, ~35 de 38, más justo.
- **0.4 (puntos de stat, `moralidad-y-progresion.md`)**: con la progresión nueva (automático +3 PV y +1 ATQ/DEF alternando, más 3 puntos por nivel), el ×0,7 resulta demasiado fácil. **Recomendación para la 0.4: PV ×0,85** (d = 4: 29). Gana cualquier build de combate de nivel 3, perdiendo del 70% al 95% de los PV, y el nivel 2 sigue perdiendo. Tabla en esa ficha.

### Balance 0.2.0 (historial, con "Ofrecer Luz" de 8 de daño)
Estrategia: primero todas las "Ofrecer Luz" disponibles, luego atacar.

| Adoc | Ofomni d = 4 (34/8/3), 0 Luz | d = 4, 4 Luz | d = 4, 10 Luz | Ofomni d = 5 (38/9/3), 4 Luz | d = 5, 10 Luz |
|---|---|---|---|---|---|
| Nivel 1 (30/6/3) | pierde | pierde | pierde (~33 de 30) | pierde | pierde |
| Nivel 2 (34/7/3) | pierde | pierde (~39 de 34) | justo (~33 de 34) | pierde | pierde (~39 de 34) |
| Nivel 3 (38/7/4) | pierde (~50) | **gana** (~32 de 38) | **gana** (~27 de 38) | pierde | **gana** (~33 de 38) |
| Nivel 4 (42/8/4) | pierde por poco (~45 de 42) | gana (~32 de 42) | gana (~27 de 42) | justo (~39 de 42) | gana (~33 de 42) |

Lectura de la 0.2.0 (dificultad **confirmada por el dueño**, "2 ok"): con nivel 3 y al menos 4 de Luz, el Ofomni de d = 4 es difícil pero ganable. El de d = 5 exige nivel 3 con la Luz llena, o nivel 4. Defender ante el Latigazo múltiple no cambia mucho el daño medio, pero evita picos mortales cuando quedan pocos PV. Sin el Latigazo múltiple, la pelea sería más o menos un nivel más fácil.

### Resultados
| Resultado | Efecto |
|---|---|
| **Victoria** | Estado `completed`. XP de la victoria (4 + 3·d: 16 o 19). Mensaje: el Ofomni "vuelve a la Luz del Bosque". |
| **Recompensa** (al hablar con el sfida, `rewarded`) | **Luz suelta rellenada hasta `luz_max`**, **1 ofrenda "Cuenco ritual" (valor 6)** (`ofrendas-v1.md`), **25 XP** y **+1 de fama**. Una sola vez. |
| **El Ofomni entra en el Bosque natal** | Estado `failed`. **Villa dañada**: pierdes la mitad de la Luz suelta (redondeando hacia abajo) y la villa queda marcada como dañada. El sfida lo reprocha. El Ofomni se queda en el chunk de la villa y **todavía se puede pelear con él** allí. |
| **Victoria después de `failed`** | XP de la victoria. La misión sigue en `failed`: sin recompensa ni fama. El sfida agradece, aunque tarde (texto de `narrative-writer`). |

- **Villa dañada** en la 0.2.0: solo es una marca y un texto. Sigue curando y sirviendo de refugio. Los efectos reales están por definir (#124).

## Inputs / outputs
- **Inputs:** seed, grafo de Bosques, Bosque natal, reloj (`WorldClock`), riutash, interacción con el sfida (E), resultado del combate.
- **Outputs:** estado de la misión (`GameState.quests`), Bosque actual y última posición conocida del Ofomni, recompensas (Luz, ofrenda, XP, fama), marca de villa dañada, señal `quest_state_changed`.

## Interacción con otros sistemas
- **Tiempo** (`tiempo-y-riutash.md`): el movimiento y el rastro dependen del reloj y del riutash.
- **Navegación** (`navegacion.md`): brújula y mapa con la última posición conocida.
- **Combate** (`cruce-y-combate-v1.md`): fórmulas, más los látigos (normal y múltiple) y la ausencia de "Ofrecer ofrenda".
- **Progresión** (`progresion-adoc.md`): XP y fama.
- **Ofrendas** (`ofrendas-v1.md`): recompensa.
- **Guardado**: estado de la misión, Bosque del Ofomni, tiempo hasta su próximo movimiento, última posición conocida y villa dañada.

## Casos límite
- **El jugador no acepta la misión**: el Ofomni no se mueve. La brújula apunta al sfida.
- **El Ofomni entra en el Bosque donde está el jugador**: aparece en su chunk de entrada. Si el jugador está en otro chunk de ese Bosque, lo verá al entrar.
- **El Ofomni pasa por Bosques ya abiertos o cerrados**: él no paga peajes ni abre bordes.
- **El jugador está en el Bosque natal cuando entra el Ofomni**: `failed`. Aparece en el chunk de la villa y se puede pelear.
- **Se acaba el movimiento mientras el jugador está en combate con él**: no puede pasar, porque el reloj está parado durante el combate.
- **Derrota contra el Ofomni con la misión `active`**: despiertas en la villa y él sigue. Si estaba a 1 salto, puede llegar pronto y la misión fallaría.
- **Huir del Ofomni**: vuelves a la casilla anterior y el Ofomni recupera sus PV.
- **Recompensa ya cobrada**: hablar con el sfida da un texto de agradecimiento sin más recompensas.
- **Luz al máximo al cobrar**: el relleno no cambia nada. Se recibe igualmente la ofrenda, la XP y la fama.
- **Cargar a mitad de misión**: se conservan el estado, la posición del Ofomni y el tiempo hasta su próximo salto.

## Criterios de éxito para playtest
Propuestas, a confirmar con el dueño:
- El jugador entiende el objetivo tras el diálogo del sfida y sale de la villa en menos de 2 minutos.
- La misión completa (aceptar → vencer → cobrar) dura entre 15 y 25 minutos.
- En la primera partida el jugador gana o pierde al Ofomni por poco (le quedan o le faltan menos de 10 PV).
- El jugador usa "Defender" al menos una vez ante un Latigazo múltiple anunciado.
- Al menos una vez el jugador elige pelear en un borde en vez de pagar para ganar XP antes del Ofomni (pregunta: "¿por qué peleaste o pagaste?").
- El dueño considera justo el fracaso (villa dañada, la partida sigue) (pregunta directa).

## Decisiones del dueño (2026-10-23)
Respuesta textual a la propuesta: "1 si, me agrada eso. el ofomni ataca con latigos y cada 3 turnos usa varios latigos. 2 ok 3 ok 4 vale 5 es un survival, deberia ser game over dependiendo del monstruo que te ataque, un iserald es fatal."

| Tema | Estado |
|---|---|
| Ataque fuerte cada 3 turnos (×3, anunciado, Defender a la mitad) | **Confirmado**, como **Latigazo múltiple** (látigos, no "Mirada"). |
| Dificultad ganable desde nivel 3 | **Confirmada**. |
| Avance de un Bosque cada 6 min, solo tras aceptar | **Confirmado**. |
| Recompensa: Luz al tope, Cuenco ritual (6), 25 XP, +1 de fama | **Confirmada**. |
| Derrota en Aventura | Depende del monstruo: hay monstruos **fatales** (game over) e Iserald siempre lo es. El Ofomni es **no fatal en la primera misión** (confirmado el 2026-10-24). |

## Decisiones aún a confirmar
- La d del Ofomni es fija desde su aparición (4–5). La dificultad confirmada se calculó con esa regla.
- Villa dañada: la mitad de la Luz suelta y una marca, sin más efectos en la 0.2.0 (#124).
- Vencerlo después de fallar no da recompensa.

## Preguntas abiertas
- Efectos reales de la villa dañada (#124).
- Qué otros monstruos son fatales (#127).
- Más misiones de villa (#106).
