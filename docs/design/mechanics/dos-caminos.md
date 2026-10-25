# Ficha: Dos caminos (adoc fiel o garelino)

> Dueño: `game-designer`. **Versión 0.5 "Dos caminos"**. ADR 0015. Valores **provisionales**.
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
- **Escena** (`narrative-writer`): un grupo garelino y su portavoz.
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
| **Bosques con Nujio** | Te tratan como hostil. Al entrar por primera vez, hostilidad **2** y relación **−30**. Peaje ×2. Los **cazadores** salen aunque hayas pagado (cada 120 s). |
| **Humores** (ADR 0004: "climas agresivos que ocurren si delatas tu intension y ubicación") | Medidor de **exposición** por Bosque. Sube con actos visibles para un Único: vencer (+20), robar (+20), sembrar (+40), intimidar (+20). Al llegar a 100 cae un **Humor** sobre ti en ese Bosque (tormenta focal, glosario §2): −20% de los PV máximos por Momento y movimiento ×0,8, hasta salir del Bosque o pasar un riutash en refugio. La exposición baja 20 por riutash. |
| **Iserald** | Sembrar junto a un Nujio vivo le baja la cordura (sección 6) y puede desatarlo (fatal; `monstruos.md`). |
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
  - Propuesta: **no es game over** dentro de Aventura, sino un **retroceso**: reputación garelina −20 y la siembra y la persuasión con fuerza quedan bloqueadas hasta reclutar a alguien.
  - El "pierdes" original se reserva para el futuro modo "empezar como garelino" (#169).
- El grupo te sigue por el mundo (como un encargo compartido).

## 5. Persuadir villas
Cada villa (menos la natal, #171) tiene un medidor de **convicción** garelina, de 0 a 100. Al llegar a **100**, **se une** a los Nuevos Bosques.

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
- **Dónde se siembra** (con E, 1 Piedra):
  - **Junto a un Nujio muerto** (Bosque muerto): sin riesgo. Tras **2 riutash**, el Bosque pasa a **Nuevo Bosque** (sin peaje de Luz, fauna de mamíferos y reptiles, `bosques-y-relacion.md`).
  - **Junto a un Nujio debilitado** (Bosque corrupto, cordura < 20): la siembra le baja la cordura **−30**. Si llega a 0, **se desata el Iserald** (fatal; el Nujio muere y el Bosque queda muerto, `monstruos.md`). Después ya se puede sembrar junto al Nujio muerto.
  - **Junto a un Nujio sano**: no se puede (la Piedra no prende). Hay que debilitar antes el Bosque, con consecuencias.
- **Riesgos**: exposición +40 (Humores), los cazadores del Bosque y el Iserald.
- Glosario §7: los Nuevos Bosques "no requieren Luz, veneración ni vínculo, sí mucho trabajo y recursos".

## 7. Redención (volver a ser fiel)
"Gran costo" (dueño). Propuesta:
- **Requisitos** (todos):
  1. **Senda ≥ 0**, subida con actos respetuosos.
  2. **3 días** (6 riutash) **sin actos garelinos** (sin intimidar, sembrar, robar ni persuadir).
  3. **Ofrendas por valor total de 30** dejadas junto al Nujio de tu villa natal.
  4. **Una misión de redención**: salvar un Bosque en necesidad de ayuda o devolver a sano un Bosque corrupto (`bosques-y-relacion.md`).
- **Al completarla**:
  - Vuelves a **fiel** y tu villa natal te acepta otra vez.
  - Los Bosques **conservan su memoria** (hostilidad y relación).
  - Los garelinos pasan a tratarte como **traidor**: sus grupos te atacan (combate no letal) y el campamento se cierra.
  - Tu grupo se disuelve.
- **Una sola vez por partida** (propuesta, #170). Si vuelves a ser garelino, no hay segunda redención.

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

## 10. Finales de cada camino (propuesta)
Aventura sigue siendo un **survival**: la partida continúa después del final. El final es un **hito** con escena (`narrative-writer`) y un resumen. Enlaza con #31 y con las condiciones originales del modo Garelino (ADR 0004).

| Camino | Final (provisional) | Base |
|---|---|---|
| **Garelino** | **Convertir 3 villas** y **sembrar en 3 Bosques** (Nuevos Bosques creados) | ADR 0004: "Se vence eliminando al nujio y sembrando las primeras semillas de los nuevos bosques" |
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
- **Siembra en un Bosque corrupto que desata el Iserald con el jugador dentro**: estado Miedo; lo sensato es huir (Iserald fatal).
- **Villa convertida cuyo Bosque estaba pagado**: el pago se mantiene hasta que caduque; luego, hostilidad.
- **Redención con el grupo en combate**: no se puede iniciar con un encargo garelino activo.
- **Villa natal**: no se puede convertir (propuesta, #171).
- **Todos los miembros retirados en mitad de un combate**: el combate sigue contigo solo.

## Criterios de éxito para playtest
- Dos testers con la misma seed acaban en bandos distintos y describen partidas distintas.
- El jugador entiende por qué le invitan los garelinos (pregunta: "¿qué te llevó a ese momento?").
- El jugador usa al menos 2 de las 4 vías de persuasión.
- El dueño siente que volver atrás "cuesta mucho" pero es posible (pregunta directa).

## Preguntas abiertas
- **#167**: finales: ¿los objetivos propuestos (garelino: 3 villas y 3 siembras; fiel: 3 Bosques salvados y 10 días sin conversiones, o vencer un Iserald) o sin final?
- **#168**: siendo garelino, ¿los Bosques aceptan tu Luz (peaje ×2) o la rechazan?
- **#169**: quedarse sin miembros: ¿retroceso (propuesta) o derrota, como en el modo original?
- **#170**: redención: ¿una sola vez por partida?
- **#171**: ¿se puede convertir la villa natal?
