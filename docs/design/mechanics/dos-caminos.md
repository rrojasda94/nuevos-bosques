# Ficha: Dos caminos (adoc fiel o garelino)

> Dueño: `game-designer`. **Versión 0.5 "Dos caminos"** (nombre y orden **confirmados** por el dueño). ADR 0015. Valores **provisionales**.
> **Historia en pausa** (dueño, 2026-10-25: "por ahora no se cuales podrian ser las historias. Centremonos en mecanicas, jugabilidad, desarrollo de personaje y de ahi buscamos crear la historia del juego"). Esta ficha describe **mecánicas** con roles genéricos ("la ledai", "un adoc veterano", "el Ildo vecino"). `docs/design/historia/` es un borrador aparcado, no canon.
> Fuentes: palabras del dueño (abajo); ADR 0004 (modo Garelino original, regla de no matar), glosario §6 ("Piedras de los Nuevos Bosques como moneda") y §7 ("Estrella Azul", "Piedras de los Nuevos Bosques", "Nuevos Bosques", "Guerra"); `moralidad-y-progresion.md` (Senda), `monstruos.md` (garelinos, Iserald), `bosques-y-relacion.md` (estados, cordura, relación), `npcs-y-villas.md`, `otros-adoc.md`, `cruce-y-combate-v2.md`. La historia (escenas, diálogos) es de `narrative-writer` (`docs/design/historia/`).

## Objetivo
Que el adoc pueda acabar del lado de los Bosques o del lado de los Nuevos Bosques, y que esa elección cambie la partida: aliados, enemigos, cómo te reciben las villas y qué significa ganar.

Palabras del dueño (2026-10-25):
- "podriamos unir el modo garelino aqui mismo. Porque hariamos que dependiendo del camino del adoc, podria ser un detractor de los bosques y tomar parte de los nuevos bosques. Puedes juntar tu grupo y tratar de convenser a las villas para unirse a los nuevos bosqes."
- Cambio de bando: "es gradual, pero puede haber un momento de la historia que te cruzas con los garelinos y te invitan a unirte o tu a ellos."
- Volver atrás: sí, con un gran costo.
- Convencer villas: resolver su necesidad, diálogo y argumentos, la fuerza del grupo (intimidar o proteger, sin matar) y las Piedras como regalo.

## Pilares
- **Pilar 1 (dos capas)**: lo que haces en los Bosques decide de qué lado estás, y tu lado cambia cómo te tratan las villas.
- **Pilar 4**: dos partidas con la misma seed pueden terminar en bandos opuestos.
- **Pilar 3**: el bando se ve en un icono, junto al de la Senda.

## Presión de supervivencia
- **Garelino**: los Bosques te tratan como hostil (peajes, cazadores, Humores si te delatas), tu villa natal te rechaza y sembrar puede desatar un Iserald. A cambio, tienes un grupo propio y Piedras.
- **Fiel**: los garelinos persuaden villas y atacan Bosques. Tienes que defenderlos sin matar.

## 1. Lealtad
- Se apoya en la **Senda** (−100…+100, `moralidad-y-progresion.md`).
- Además hay un **estado de bando**, con tres valores:

| Bando | Cómo se llega | Qué implica |
|---|---|---|
| **fiel** | Inicio | Reglas normales. |
| **en duda** | Senda ≤ **−40** (automático, gradual). Se vuelve a fiel con Senda ≥ −20 | Se desbloquea la **invitación** del encuentro con los garelinos. Las villas lo notan: el Ildo o el Sfida comentan algo, sin efectos todavía. |
| **garelino** | Solo **aceptando** en el encuentro de historia, o **pidiendo unirte** en un campamento garelino estando en duda | Consecuencias de la sección 3. |

- El bando se ve con un **icono** junto al de la Senda (pantalla de estado).
- No se puede pasar de fiel a garelino sin estar antes en duda. El cambio es gradual, como pidió el dueño.

## 2. El encuentro de historia con los garelinos
- **Cuándo**: la primera vez que se cumplen las dos condiciones:
  - la misión del Ofomni ha terminado (`rewarded` o `failed`), o han pasado 3 días;
  - el jugador llega a un Bosque **en necesidad de ayuda bajo ataque garelino** (`bosques-y-relacion.md`), o pasa junto a un **campamento garelino**.
- **Escena**: un grupo garelino y su portavoz, **una ledai** (rol genérico). Lore del dueño: "los ledai en esta era son como profetas, al menos los ledai de la tarca de trastas que es donde esta Garel/estrellazul. Pero igual en la historia cualquiera puede convertirse en garelino y seguir a los ledai". Los textos de la escena quedan aparcados mientras la historia esté en pausa.
- **Opciones según el bando**:

| Bando del jugador | Opciones |
|---|---|
| **fiel** | "Defender el Bosque": combate no letal contra el grupo (`monstruos.md`). "Irte": sin combate, cordura del Bosque −10. "Escuchar": te dicen dónde está su campamento; Senda −3. |
| **en duda** | Además: **"Unirte"**. Te invitan, o pides unirte. Pasas a bando garelino. |

- **Al rechazar estando en duda**: Senda +5 y vuelves a fiel si la Senda llega a −20 o más. El campamento queda marcado en el mapa. Más adelante puedes ir **tú** a pedir unirte (dueño: "o tu a ellos"), si vuelves a estar en duda.
- **Al aceptar**:
  - Bando garelino.
  - Recibes **2 Piedras** y **1 miembro** de grupo de nivel igual al tuyo (o uno menos).
  - El campamento pasa a ser tu **base**: refugio, reaparición tras una derrota no fatal y reclutamiento.

## 3. Consecuencias de ser garelino
| Ámbito | Efecto (provisional) |
|---|---|
| **Villa natal** | Te rechaza: sin curación, sin servicios, y el Sfida te lo reprocha. No es tu punto de reaparición (lo es el campamento). |
| **Bosques con Nujio** | Te tratan como hostil. Al entrar por primera vez, hostilidad **2** y relación **−30**. **Peaje** (dueño, #168: "si tienes artefactos que oculten tu Luz, pueden aceptar el peaje como normal o mas caro. En caso contrario te atacara y deberas avanzar por el bosque con cautela"): **solo con un artefacto que oculte tu Luz** equipado (máscara o talismán de camuflaje, `sigilo-y-robo.md`), el Bosque acepta el pago. Coste propuesto según el nivel del artefacto: **nivel 1 ×1,5, nivel 2 ×1,25, nivel 3 ×1** (normal). Pagado así, no salen cazadores mientras lleves el artefacto equipado. Si te lo quitas dentro, el Bosque te reconoce y vuelve a atacarte. **Sin artefacto**: no se puede pagar (solo Enfrentar o Retroceder), salen **cazadores** (cada 90 s) y hay que avanzar con **cautela** (sigilo, evitar la visión de los Únicos). |
| **Humores** (ADR 0004: "climas agresivos que ocurren si delatas tu intension y ubicación") | Medidor de **exposición** por Bosque. Sube con actos visibles para un Único: vencer (+20), robar (+20), sembrar (+40), intimidar (+20). Al llegar a 100 cae un **Humor** sobre ti en ese Bosque (tormenta focal, glosario §2): −20% de los PV máximos por Momento y movimiento ×0,8, hasta salir del Bosque o pasar un riutash en refugio. La exposición baja 20 por riutash. |
| **Magra** (dueño: "si, se vuelve magra. Los nuevos y viejos bosques no son compatibles.") | Al unirte a los Nuevos Bosques te vuelves **magra** (glosario §5: quien abandona o cambia de oficio; condenado, suele huir pidiendo asilo y luego es desterrado). Propuesta: las **villas fieles** te niegan servicios y curación y te piden que te vayas; las villas convertidas te acogen. Los **Bosques con Nujio** no te dan fruto lícito (todo fruto que tomes es robo) ni descanso junto a su Nujio. |
| **Iserald** | Ya no se siembra junto a Nujio vivos (sección 6). Pero dañar un Bosque (robos, Botarramas vencidos, ataques) le baja la cordura y puede desatar su Iserald (fatal; `monstruos.md`). |
| **Reputación garelina** (0–100, empieza en 20) | Sube: villa convertida +20, siembra +15, Bosque defendido para los garelinos +10. Baja: intimidar en exceso (más de una vez por villa) −10, proteger un Bosque contra los garelinos −15. Con < 10, los garelinos dejan de apoyarte (no reclutas ni recibes Piedras). |
| **Otros adoc** | No quieren trabajar contigo (afinidad, `otros-adoc.md`). Nunca te atacan, pero pueden defender villas de tu persuasión (sección 8). |
| **Skills** | La rama **Sombra** encaja con el camino garelino; la rama **Confianza**, con el fiel (`moralidad-y-progresion.md`). |

## 4. Grupo garelino
- **Reclutar**:
  - En el **campamento** (siempre): 1 miembro por **2 Piedras**.
  - En una **villa convertida**: 1 miembro gratis por villa, una vez.
- **Tamaño máximo**: 5 miembros más el jugador.
- **Miembros**: nivel 1–5 (por seed, como mucho tu nivel). Stats de la tabla automática del adoc para su nivel (`moralidad-y-progresion.md`).
- **En combate**: son **aliados** del combate en grupo (`monstruos.md`, `otros-adoc.md`). Actúan después de ti y atacan a tu objetivo.
- **Caer**: un miembro a 0 PV **se retira** (no muere; no se mata gente). Vuelve al campamento y está disponible otra vez tras **2 riutash**, si vas a buscarlo.
- **Quedarse sin miembros** (regla original del modo Garelino: "pierdes si te quedas sin individuos"):
  - **Confirmado** (dueño, #169: "es solo un retroceso"): no es game over. Reputación garelina −20, y la siembra y la persuasión con fuerza quedan bloqueadas hasta reclutar a alguien.
- **IA del grupo** (dueño: "deberiamos tener NPC inteligentes que tengan formaciones o sepan como atacar, defender, adelantar turnos"): los miembros usan la iniciativa, las filas, los roles (atacante, defensor, apoyo) y las órdenes de `ia-de-combate.md`.
  - El "pierdes" original se reserva para el futuro modo "empezar como garelino" (#169).
- El grupo te sigue por el mundo (como un encargo compartido).

## 5. Persuadir villas
Cada villa tiene un medidor de **convicción** garelina, de 0 a 100. Al llegar a **100**, **se une** a los Nuevos Bosques.

**Villa natal** (dueño, #171: "si, es dificil"). Se puede convertir, pero es difícil. Propuesta:
- **Convicción inicial −50**, en lugar de 0.
- **Resistencia del Nujio natal**: −5 de convicción por día.
- **Requisito**: reputación garelina **≥ 60**. Si no, el diálogo y las Piedras no cuentan.
- El **Sfida** hace contrapersuasión: una vez por día, −10.
- Al convertirla:
  - el Bosque natal pasa a **enojado** y su Nujio, ofendido, baja la cordura −30;
  - la villa natal acepta Piedras y vuelve a ser tu punto de reaparición;
  - los otros adoc de la villa se marchan.

| Vía | Mecánica | Convicción |
|---|---|---|
| **Resolver su necesidad** | Cada villa genera **1 necesidad** por seed: comida escasa (fruto lejano o Bosque enojado), un Único que la acosa, un incendio en su Bosque, enfermedad (Aledra), o falta de un material o servicio. Resolverla es un encargo | **+30** |
| **Diálogo y argumentos** | Hablar con el **Ildo** o el **Ista**. Se elige 1 de 3 argumentos: **comida segura** (las Piedras dan fruto cada ciclo, glosario §7), **libertad** ("liberar a la humanidad del yugo de los Bosques", glosario §7) o **seguridad** (protección del grupo). El correcto depende del estado de la villa: hambre → comida; Bosque enojado o corrupto → libertad; amenazas → seguridad. Un intento por villa y día | Acierto **+15**; fallo **−5** |
| **Fuerza del grupo** | **Intimidar**: exige al menos 2 miembros en el grupo. **Proteger**: vencer a los Únicos o los peligros que la amenazan, de forma no letal | Intimidar **+20** (relación con su Bosque −20, Senda −5, exposición +20; una sola vez por villa sin penalización, después reputación garelina −10). Proteger **+20** |
| **Regalar Piedras** | Dar Piedras al Ildo | **+10 por Piedra**, como mucho +30 por esta vía |

- **Contrapersuasión**: los otros adoc y el jugador fiel pueden bajar la convicción (sección 8).
- **Cuando una villa se une**:
  - sus servicios aceptan **Piedras** como moneda, además de la Luz;
  - se puede **sembrar** en su Bosque (sección 6);
  - su Bosque **se ofende**: cordura −20 y relación con el jugador −20; si estaba sano, pasa a **enojado**;
  - da 1 miembro de grupo, una vez;
  - en el mapa se marca con un color de los Nuevos Bosques.

## 6. Sembrar las Piedras de los Nuevos Bosques
- **Qué son** (glosario §7): "Hacen crecer plantas que dan alimento cada cierto ciclo". Las creó Estrella Azul y se usan como moneda en las villas bajo su influencia (§6).
- **Recurso Piedras**:
  - **Fuente**: 2 al unirte; 1 por cada villa convertida; 1 por cada riutash pasado en el campamento si tu reputación garelina es ≥ 40.
  - **Sumidero**: reclutar (2), regalar a villas (1) y sembrar (1).
  - **Al agotarse**: no se puede sembrar ni reclutar en el campamento. Quedan la persuasión por necesidad y por diálogo.
  - Ocupan una casilla del inventario (apilables).
- **Dónde se siembra** (dueño: "siembras nuevos bosques donde los bosques de nujio ya no están, puedes mandar o talar tu mismo el bosque cuando el nujio ya murio"):
  - **Solo donde el Bosque de Nujio ya no está**, es decir, en un **Bosque muerto** (su Nujio murió, por ejemplo tras un Iserald).
  - **Se elimina** la siembra junto a un Nujio debilitado (con su pérdida de cordura y su Iserald) y junto a un Nujio sano.
- **Paso 1, talar el Bosque muerto** (propuesta):
  - **Tú mismo**: con E sobre los árboles muertos de un chunk. Unos **2 minutos de reloj por chunk** (talar 10 árboles a ~12 s cada uno).
  - **Mandar a tu grupo**: asignas **1 miembro** a un chunk. Lo tala en **1 riutash** y mientras tanto no está en tu grupo.
  - **Recompensa**: **madera** (unos 5 por chunk), material de artesano (`npcs-y-villas.md`).
  - **Riesgo**: exposición +20 por chunk talado (Humores), y los pocos Únicos del Bosque muerto (que a veces piden Luz).
  - **Talar un Bosque vivo** (con Nujio) no está permitido: es dañarlo (cordura −20) y no deja sembrar.
- **Paso 2, sembrar**:
  - Con E y **1 Piedra** en un chunk ya talado.
  - Tras **2 riutash**, ese chunk pasa a **Nuevo Bosque** (sin peaje de Luz, fauna de mamíferos y reptiles, `bosques-y-relacion.md`).
  - Cuando la **mitad** de los chunks del Bosque está sembrada, el Bosque entero pasa a Nuevo Bosque.
- **Riesgos**: exposición (Humores) y los cazadores de los Bosques vecinos con Nujio, que se ofenden (relación −10 con cada Bosque vecino por cada Bosque convertido).
- Glosario §7: los Nuevos Bosques "no requieren Luz, veneración ni vínculo, sí mucho trabajo y recursos".

## 7. Redención (volver a ser fiel)
"Gran costo" (dueño). Propuesta:
- **Requisitos** (todos):
  1. **Senda ≥ 0**, subida con actos respetuosos.
  2. **3 días** (6 riutash) **sin actos garelinos** (sin intimidar, sembrar, robar ni persuadir).
  3. **Ofrendas por valor total de 30** dejadas junto al Nujio de tu villa natal.
  4. **Una misión de redención**: salvar un Bosque en necesidad de ayuda o devolver a sano un Bosque corrupto (`bosques-y-relacion.md`).
  5. **Asilo de magra** (porque al hacerte garelino te volviste magra): pedir asilo al **Ildo** de una villa fiel, que te pone una prueba (la misión del punto 4) antes de aceptarte. Glosario §5: el magra "suele huir pidiendo asilo y luego ser desterrado". Propuesta: sin asilo no hay redención.
- **Al completarla**:
  - Vuelves a **fiel** y tu villa natal te acepta otra vez.
  - Los Bosques **conservan su memoria** (hostilidad y relación).
  - Los garelinos pasan a tratarte como **traidor**: sus grupos te atacan (combate no letal) y el campamento se cierra.
  - Tu grupo se disuelve.
- **Una sola vez por partida** (confirmado por el dueño, #170). Si vuelves a ser garelino, no hay segunda redención.

## 8. Adoc fiel frente a los garelinos
- Los garelinos tienen sus propios grupos, que **persuaden villas** por su cuenta: cada **2 días**, una villa cercana a un campamento gana **+15 de convicción**.
- El adoc fiel puede **frenarlo**:

| Acción | Efecto |
|---|---|
| Resolver la necesidad de la villa | Convicción −30 |
| Diálogo con el Ildo o el Ista | Argumentos de los Bosques: fruto, Nujio, pacto (glosario §3, §5). Acierto −15 |
| Proteger la villa de un ataque garelino | Combate no letal (`monstruos.md`). Convicción −20 |
| Ofrendas al Nujio de esa villa | Convicción −5 por cada 3 de valor |

- **Defender Bosques** de los ataques garelinos: "Salvar los Bosques" (`bosques-y-relacion.md`).

## 9. Regla de no matar gente
- Vale en **los dos caminos** (ADR 0004): **nadie mata ni muere** en combates entre personas (adoc, garelinos, villanos).
- Al perder, una persona **se retira**. Perder el jugador contra personas nunca es fatal: aplica la reaparición (`cruce-y-combate-v2.md`).
- **Intimidar** no es violencia letal. Es presión, con coste en reputación y relación.
- Los Únicos no son gente: "vuelven a la Luz del Bosque" (glosario §3).

## 10. Finales de cada camino (APARCADO)
> **Aparcado** (dueño: historia en pausa; #167). Los hitos de final no se implementan en la 0.5. La tabla queda como referencia para cuando se construya la historia.

Aventura sigue siendo un **survival**: la partida continúa después del final. El final sería un **hito** con escena y un resumen. Enlaza con #31 y con las condiciones originales del modo Garelino (ADR 0004).

| Camino | Final (provisional) | Base |
|---|---|---|
| **Garelino** | **Convertir 3 villas** y **convertir 3 Bosques muertos en Nuevos Bosques** (talados y sembrados) | ADR 0004: "Se vence eliminando al nujio y sembrando las primeras semillas de los nuevos bosques" |
| **Fiel** | **Salvar 3 Bosques** (de necesita ayuda o corrupto a sano) y que **ninguna villa de la región se convierta durante 10 días seguidos**, o **vencer a un Iserald** con un grupo de adoc | ADR 0004: modo Supervivencia ("evitar que los garelinos enloquezcan al nujio o aniquilen el bosque") |

## Inputs / outputs
- **Inputs:** Senda, acciones del jugador, encuentro, estado de Bosques y villas, Piedras, grupo.
- **Outputs:** bando, reputación garelina, exposición por Bosque, convicción por villa, Bosques sembrados y convertidos, hitos de final.

## Interacción con otros sistemas
- `moralidad-y-progresion.md`: Senda y ramas de skills.
- `bosques-y-relacion.md`: estados, cordura, relación, salvar los Bosques.
- `monstruos.md`: garelinos (enemigos o aliados), Iserald.
- `npcs-y-villas.md`: Ildo e Ista (diálogo), servicios con Piedras.
- `otros-adoc.md`: afinidad y contrapersuasión.
- Guardado: bando, reputación, exposición, convicción, Piedras, grupo (miembros y estado), siembras y uso de la redención.

## Casos límite
- **Pedir unirte sin haber tenido el encuentro**: imposible; el campamento no está en el mapa.
- **Senda sube a ≥ −20 estando en duda tras rechazar**: vuelves a fiel y la invitación se cierra hasta volver a −40.
- **Intentar sembrar en un Bosque con Nujio**: no se puede ("donde los bosques de nujio ya no están").
- **Talar con el grupo mientras te atacan**: el miembro asignado se retira si cae, y el chunk queda a medio talar (se conserva el avance).
- **Iserald desatado por dañar un Bosque con el jugador dentro**: estado Miedo; lo sensato es huir (Iserald fatal). Después el Bosque queda muerto y se puede talar y sembrar.
- **Villa convertida cuyo Bosque estaba pagado**: el pago se mantiene hasta que caduque; luego, hostilidad.
- **Redención con el grupo en combate**: no se puede iniciar con un encargo garelino activo.
- **Villa natal**: se puede convertir, pero es difícil (sección 5).
- **Garelino sin artefacto que oculte la Luz en un Bosque pagado antes**: el pago no vale; el Bosque te reconoce y te ataca.
- **Todos los miembros retirados en mitad de un combate**: el combate sigue contigo solo.

## Criterios de éxito para playtest
- Dos testers con la misma seed acaban en bandos distintos y describen partidas distintas.
- El jugador entiende por qué le invitan los garelinos (pregunta: "¿qué te llevó a ese momento?").
- El jugador usa al menos 2 de las 4 vías de persuasión.
- El dueño siente que volver atrás "cuesta mucho" pero es posible (pregunta directa).

## Preguntas abiertas
- ~~**#167**: finales.~~ **Aparcada**: historia en pausa.
- ~~Siembra, magra, ledai, nombres y 0.5~~: resueltas (dueño, 2026-10-25).
- ~~#168–#171~~ Resueltas (dueño, 2026-10-25): peaje solo con un artefacto que oculte la Luz; quedarse sin miembros es retroceso; redención una vez por partida; la villa natal se puede convertir, pero es difícil.
- **#174**: Agilidad como stat (`ia-de-combate.md`).
