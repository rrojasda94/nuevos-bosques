# Preguntas abiertas

Las 8 preguntas iniciales están resueltas en `0002-decisiones-fundacionales.md` y `0003-mapa-mundial-y-chunks.md`. Las resueltas después se tachan y apuntan a su fuente: un ADR o una entrada de `docs/glosario_nuevos_bosques.md` (en adelante, "glosario"; es la fuente de verdad del lore).

## Prioritarias: bloquean el vertical slice de Aventura (ADR 0005, `docs/design/mechanics/aventura-mvp.md`)

| # | Pregunta | Bloquea a |
|---|---|---|
| 62 | Escala (ADR 0005, respuestas): chunk < zona < área < región < Sur Lenfi. ¿Cuántos chunks tiene una zona, cuántas zonas un área y cuántas áreas una región? ¿Tienen forma de grid? ¿El tipo villa/bosque/geografía (#61) se decide por zona o por chunk? | world-gen-dev, engine-architect, game-designer |
| 63 | ¿Cómo se pasa entre chunks dentro de una zona (¿por el borde?) frente al viaje entre zonas, áreas y regiones (¿por el mapa de la región?)? | world-gen-dev, engine-architect, game-designer, ui-ux-dev |
| 68 | ¿Cuántas regiones de origen se pueden elegir en el MVP? El GDD dejaba "más de una región jugable" fuera del MVP, pero ahora el jugador elige su región de origen (#13). | game-designer, world-gen-dev |

## Lista

| # | Pregunta | Bloquea a |
|---|---|---|
| 9 | ~~¿Qué regiones son jugables?~~ **Resuelta en parte** en ADR 0005 (respuestas): solo se juega en la parte suroccidental de Nardaram; el jugador elige su región de origen, que le da conocimiento automático del área y sus zonas. Qué regiones exactamente: #64. Cuántas en el MVP: #68. | — |
| 10 | ~~¿Tamaño de chunk?~~ **Resuelta** en ADR 0004: 64×64 tiles. | — |
| 11 | ~~¿Condición de derrota?~~ **Resuelta** en ADR 0004: fallar la misión de la partida (concretada por modo). | — |
| 12 | ¿Cuántos días dura una expedición típica? (propuesta: 1–3) | game-designer, rpg-systems-dev |
| 13 | ~~¿El jugador elige región al empezar?~~ **Resuelta** en ADR 0005 (respuestas): "lo eliges". El jugador elige su región de origen. | — |
| 14 | ~~¿Dónde está y qué tamaño tiene la ciudad dentro del chunk?~~ **Resuelta en parte** en ADR 0004: el chunk puede tener o no una villa; el Nujio suele estar en el centro. Lo que falta pasa a #14b, #40, #42 y #50. | — |
| 14b | ¿Qué tamaño tiene una villa dentro del chunk de 64×64 y cuántos edificios tiene? ¿Siguen valiendo el grid de ciudad de 16×16 y la hoguera en el centro del GDD, o los sustituyen la villa y el Nujio? (El glosario §5 pone al Nujio en el centro, con una zona de eventos y ofrendas.) | world-gen-dev, city-systems-dev |
| 15 | ~~¿El modo se elige al empezar?~~ **Resuelta** en ADR 0004: se elige al empezar, de forma similar a Project Zomboid. Lo que falta pasa a #43. | — |
| 16 | ~~¿Condición de victoria de cada modo?~~ **Resuelta en parte** en ADR 0004: Supervivencia no tiene victoria; Garelino se gana eliminando al Nujio y sembrando las primeras semillas. Aventura sigue abierta en #31. | — |
| 17 | ~~¿Qué mata al Nujio?~~ **Resuelta en parte** en ADR 0004: en Supervivencia se pierde si los garelinos enloquecen al Nujio o aniquilan el bosque. Lo que falta pasa a #39. | — |
| 18 | ~~Garelino: ¿cómo se mide la influencia y cuándo se gana o se pierde?~~ **Resuelta** en ADR 0004: se gana eliminando al Nujio y sembrando las primeras semillas; se pierde al quedarse sin individuos. | — |
| 19 | Garelino: los bosques "dominados por un Nujio" que hay que destruir, ¿son uno solo por partida (el del chunk) o varios en la región? (El glosario §3 dice que hay un Nujio por Bosque.) | game-designer, world-gen-dev |
| 20 | Aventura: ¿cuántas misiones o Únicos hay por partida? ¿Se generan todas al inicio o van apareciendo? | game-designer, rpg-systems-dev |
| 21 | Aventura: la muerte del personaje es game over (ADR 0004). ¿Fallar una misión sin morir (plazo en días, huir, otra cosa) tiene alguna consecuencia o también termina la partida? | game-designer, rpg-systems-dev |
| 22 | ~~¿Cuántos tipos de Únicos hay?~~ **Resuelta en parte** en el glosario §3 "Únicos": se conocen Iserald (sale del propio Nujio, último recurso), Aledra (aparece si la villa crece en población sin permiso; causa enfermedades) y Ofomni (subtipo). Lo que falta pasa a #22b. | — |
| 22b | ¿Cuántos tipos de Únicos hay en el MVP, cuáles, y dependen de la región o del temperamento del Bosque? | game-designer, rpg-systems-dev, world-gen-dev |
| 23 | ~~¿Qué es exactamente "el adoc"?~~ **Resuelta** en el glosario §5, tabla de Oficios, "Adoc": "Protectores; únicos especialistas en armas, para apaciguar Únicos descarriados." Lo que falta pasa a #49. | — |
| 24 | ~~¿Qué son "las villas"?~~ **Resuelta** en el glosario §5 "Villa": espacio dentro de un Bosque para los lenfi, una por Bosque, regida por el Nujio y administrada por el Ildo. Las contradicciones con el chat pasan a #47 y #50. | — |
| 25 | ~~¿Qué significa "Garelino"?~~ **Resuelta en parte** en el glosario §7 "Estrella Azul (Garel / Gael Estrella Azul)". Que los garelinos sean seguidores de Garel Estrella Azul es una deducción, **a confirmar**. La grafía pasa a #46. | — |
| 26 | ¿Hay Únicos en Supervivencia? ¿Hay Nujio y garelinos en Aventura? | game-designer, narrative-writer |
| 27 | ~~¿Se genera el mundo entero o solo el chunk?~~ **Resuelta** en ADR 0005: lectura (a). El mapa de Nardaram es fijo (ADR 0003 sigue vigente); las zonas se generan al entrar, con la seed de la partida, y persisten durante esa partida. | — |
| 28 | ~~Supervivencia: ¿a quién controla el jugador?~~ **Resuelta en parte** en ADR 0005: "en teoría" al Nujio, como juego de gestión de villa. Choca con el glosario §9; pasa a #59. | — |
| 29 | ~~¿Cómo encaja cada modo en las dos capas?~~ **Resuelta en parte** en ADR 0005: la gestión de villa (ciudad por días) es sobre todo Supervivencia. Lo que falta de Aventura y Garelino pasa a #60. | — |
| 30 | ~~Aventura: ¿varios chunks por partida?~~ **Resuelta** en ADR 0005: en Aventura y Garelino se viaja entre chunks y por el mapa de la región para distancias largas. | — |
| 31 | Aventura: ¿hay una victoria final ("debe ganar": ganar qué) o es un modo sin final? | game-designer |
| 32 | Aventura: ¿se juega con un solo personaje o con party? (el GDD tenía party de hasta 3) ¿Y en Garelino, cuántas tropas combaten a la vez? | game-designer, rpg-systems-dev |
| 33 | Aventura: ¿qué es la fama, cómo se gana o se pierde y qué efectos tiene? | game-designer, rpg-systems-dev |
| 34 | Aventura: ¿qué pasa si el jugador intenta matar gente donde hay otras personas o seres con consciencia (acción bloqueada, penalización, game over)? ¿Qué cuenta como "ser con consciencia"? (El glosario dice que Nujio, Riumini y Originales tienen conciencia.) ¿Se puede matar donde no hay testigos? | game-designer, rpg-systems-dev, narrative-writer |
| 35 | Garelino: ¿cómo se mide la reputación del grupo y cuáles son exactamente sus efectos? ¿Se puede recuperar? | game-designer |
| 36 | ~~Garelino: ¿qué son los Humores del mundo?~~ **Resuelta en parte** en el glosario §2 "Humores del Mundo": eventos climatológicos focalizados (precipitaciones, tormentas, terremotos, areniscas, ventiscas, torbellinos, avalanchas); los disponen en mayor medida los Ojos y en menor el Bosque; se pueden atraer o alejar con rituales. Ver también §1 "Momento": desobedecer los mandatos de los Ojos puede volver adversos los Humores. Lo que falta pasa a #36b. | — |
| 36b | Garelino: ¿qué acciones concretas "delatan la intención y la ubicación" del grupo? ¿Qué Humores aparecen en el MVP y qué efectos de juego tienen? ¿Hay rituales para alejarlos? | game-designer, world-gen-dev |
| 37 | Garelino: ¿con cuántos individuos se empieza, cómo y dónde se recluta, qué cuesta, y cómo se mejoran las tropas? | game-designer, rpg-systems-dev |
| 38 | Garelino: ¿qué es concretamente "acelerar la decadencia" y "sembrar las primeras semillas"? (El glosario §7 habla de Piedras de los Nuevos Bosques que hacen crecer plantas.) | game-designer |
| 39 | ~~Supervivencia: ¿qué significa "enloquecer al Nujio"?~~ **Resuelta en parte** en el glosario §3 "Nujio": "Puede perder la cordura, evolucionar y cansarse de existir"; una de las teorías sobre Iserald es la pérdida de cordura del Nujio. Lo que falta pasa a #39b. | — |
| 39b | Supervivencia: ¿cómo funcionan en reglas la pérdida de cordura del Nujio y "aniquilar el bosque"? ¿Hay medidas visibles? ¿Perder la cordura hace aparecer a Iserald? | game-designer, city-systems-dev |
| 40 | Nujio: "entre 6x6 y 8x8 de diámetro", ¿en tiles? ¿Varía por seed? | world-gen-dev, pixel-artist |
| 41 | Nujio: ¿qué significa en reglas que "tiene poder sobre el actuar de la villa"? En parte responde el glosario: el Nujio rige las reglas del Bosque y la villa (§3, §5), la villa no puede crecer más allá de su límite (§5), y Aledra aparece si la villa crece sin permiso (§3). Falta su traducción a mecánicas. | game-designer, city-systems-dev |
| 42 | Si el chunk no tiene villa, ¿qué modos se pueden jugar en él? ¿Puede haber un Nujio sin villa? | world-gen-dev, game-designer |
| 43 | ¿Se puede cambiar de modo durante la partida? ¿Qué parte de Project Zomboid se toma como referencia? | game-designer, ui-ux-dev |
| 44 | ~~¿Los Únicos que envía el bosque son los mismos que los de Aventura?~~ **Resuelta** en el glosario §3 "Únicos": son agentes del Bosque que se activan como anticuerpos según su temperamento; Iserald sale del propio Nujio. El adoc apacigua a los "Únicos descarriados" (§5). | — |
| 45 | ~~¿Qué modos entran en el MVP?~~ **Resuelta** en ADR 0005: el modo Aventura, para probar los controles y que sea divertido. | — |
| 46 | Grafía: el glosario registra "Garel" y "Gael" para Estrella Azul. ¿El modo se llama definitivamente "Garelino"? | narrative-writer, ui-ux-dev |
| 47 | Villa: el dueño dijo que sus edificios sirven "para dormir o almacenar"; el glosario dice que la villa "no almacena comida". ¿Qué se almacena (herramientas, objetos, nada de comida)? | game-designer, city-systems-dev |
| 48 | Capa ciudad del GDD frente al glosario: recursos (madera, comida, oro), almacén, huerto, aserradero y cantera chocan con "no almacena comida", "madera solo de árboles muertos y con permiso" y la economía de Luz/Piedras (glosario §5, §6). ¿Se rediseña la capa ciudad? | game-designer, city-systems-dev |
| 49 | Personaje de Aventura: ¿tiene que ser adoc (los "únicos especialistas en armas")? ¿Qué razas y oficios se pueden elegir? (El glosario dice "con el oficio que se desee", pero también que los ueutrec "no tienen oficios".) ¿El personaje pertenece a una villa, o lo llaman villas de otros lugares? | game-designer, rpg-systems-dev, narrative-writer |
| 50 | Escala: el glosario da villas de 20 a 1000–2000 habitantes. ¿Cómo cabe eso en un chunk de 64×64? ¿Se representa a todos o se abstrae? | game-designer, world-gen-dev, city-systems-dev |
| 51 | El glosario dice que la caza y la guerra eran tabú en la era de los Bosques (§7 "Guerra"). ¿Hay combates contra animales del bosque? ¿Cómo encaja con los encuentros por bioma del GDD? | game-designer, rpg-systems-dev |
| 52 | Humores: el chat los describe como "climas agresivos"; el glosario dice que "no necesariamente son malas". ¿En el juego pueden ser favorables? | game-designer |
| 53 | Inaind (glosario §9, game master de la Mecánica v0.2): ¿tiene equivalente en el videojuego (director de eventos, generador de villas y caminos)? | game-designer, world-gen-dev |
| 56 | Mapa de la región: ¿cómo funciona el viaje largo (coste, tiempo, encuentros)? Ya se sabe (ADR 0005, respuestas) que la región de origen da conocimiento automático de su área y sus zonas, y que el viaje es más complicado cuanto más lejos del punto inicial. Falta: ¿qué da exactamente "conocer" (mapa revelado, menos peligro, menos coste)? ¿Cómo se llega a conocer lo demás? ¿Cómo se mide la distancia (zonas, áreas, regiones) y qué aumenta con ella? | game-designer, world-gen-dev, ui-ux-dev |
| 57 | Luz como recurso de viaje: ¿cómo se obtiene, cómo se gasta y qué pasa si te quedas sin ella? ¿El coste crece con la distancia al punto inicial o con el desconocimiento de la zona? ¿Es la misma Luz que la moneda del glosario §6? | game-designer, rpg-systems-dev |
| 58 | ¿Qué son en reglas los "bosques agresivos" y los "Únicos poderosos" de las regiones desconocidas? | game-designer, world-gen-dev |
| 59 | Supervivencia: el dueño dice que se juega "en teoría" con el Nujio; el glosario §9 dice que el Nujio no es jugable (dato de la Mecánica v0.2, de rol de mesa). ¿Se confirma el Nujio como avatar del jugador? ¿Cómo son en reglas las acciones: pedir Luz, controlar la población, el contento, amenazar con los Únicos y defenderse de los garelinos? | game-designer, city-systems-dev, narrative-writer |
| 60 | Aventura y Garelino: ¿avanza el tiempo por días? ¿Hay alguna gestión de villa o ciudad en estos modos? | game-designer, rpg-systems-dev, city-systems-dev |
| 54 | ~~Persistencia: ¿se conservan los cambios del jugador?~~ **Resuelta** en ADR 0005 (respuestas): la zona se mantiene tal como el jugador la dejó. Con mucho tiempo, los elementos orgánicos pueden crecer o desaparecer y la gente puede haberse movido; ver #65. | — |
| 55 | ~~¿Zona = chunk? ¿Cómo se conectan?~~ **Resuelta en parte** en ADR 0005 (respuestas): no son lo mismo; la escala es chunk < zona < área < región < Sur Lenfi. Lo que falta pasa a #62 y #63. | — |
| 64 | ¿Qué regiones forman la parte suroccidental jugable / el "Sur Lenfi"? Candidatas sin decidir, glosario §8 (regiones del Sur): Safio (Safis), Nan, Dorias, Sagra (valle del Sara), Gumna, Calf (= Naca), Ungol, Amuss, Hagat, Uta, Sanag, Sunasem, Ifa, Foss. El glosario dice además que al este de Ungol no hay lenfi y que al este de Hagat y Uta no hay humanos. ¿"Región" en esta escala es lo mismo que "región" en la lista del glosario? | narrative-writer, world-gen-dev, game-designer |
| 65 | Cambio con el tiempo en zonas visitadas: ¿cuánto es "mucho tiempo"? ¿Qué elementos cuentan como orgánicos? ¿Qué crece y qué desaparece, a qué ritmo? ¿Cómo se mueve la gente? | game-designer, world-gen-dev, engine-architect |
| 66 | ¿La región de origen influye en algo más que el conocimiento (raza, cultura del glosario §4, oficio, equipo inicial)? | game-designer, narrative-writer |
| 61 | Zonas: ¿qué decide si una zona nueva es villa, bosque o "geografía"? ¿Depende de la región del mapa fijo? ¿En Supervivencia también se generan zonas nuevas o solo la villa del Nujio? | world-gen-dev, game-designer |
