# Preguntas abiertas

Las 8 preguntas iniciales están resueltas en `0002-decisiones-fundacionales.md` y `0003-mapa-mundial-y-chunks.md`. Las resueltas después se tachan y apuntan a su fuente: un ADR o una entrada de `docs/glosario_nuevos_bosques.md` (en adelante, "glosario"; es la fuente de verdad del lore).

## Prioritaria

| # | Pregunta | Bloquea a |
|---|---|---|
| 27 | **¿Se genera el mundo entero o solo el chunk?** El dueño dijo: "el mapa se genera similar a minecraft o al juego enorme de enanos" (probablemente Dwarf Fortress, a confirmar). Esto puede contradecir ADR 0003. Hay dos lecturas posibles: **(a)** el mapa mundial de Nardaram sigue diseñado a mano y solo el chunk de 64×64 de cada partida se genera con seed, como dice ADR 0003, y la comparación con Minecraft/Dwarf Fortress se refiere a cómo se genera ese chunk; **(b)** el mundo también se genera proceduralmente, al estilo Dwarf Fortress: primero se genera el mundo y después el jugador elige dónde empezar. En ese caso ADR 0003 cambiaría. Dato a tener en cuenta (no resuelve nada): el glosario cita mapas hechos por el autor (general, culturales lenfi/kulvar/wertrak, ecosistemas) y una lista fija de regiones del Sur y del Norte (§8). Afecta también a #9, #13 y #30. | world-gen-dev, game-designer, narrative-writer, engine-architect |

## Lista

| # | Pregunta | Bloquea a |
|---|---|---|
| 9 | ¿Cuántas regiones tiene el mapa mundial y cuáles son jugables en MVP? (depende de #27). Candidatas según el glosario §8, regiones del Sur: Safio (Safis), Nan, Dorias, Sagra (valle del Sara), Gumna, Calf (= Naca), Ungol, Amuss, Hagat, Uta, Sanag, Sunasem, Ifa, Foss. | world-gen-dev, narrative-writer |
| 10 | ~~¿Tamaño de chunk?~~ **Resuelta** en ADR 0004: 64×64 tiles. | — |
| 11 | ~~¿Condición de derrota?~~ **Resuelta** en ADR 0004: fallar la misión de la partida (concretada por modo). | — |
| 12 | ¿Cuántos días dura una expedición típica? (propuesta: 1–3) | game-designer, rpg-systems-dev |
| 13 | ¿El jugador elige región al empezar o es aleatoria? (depende de #27) | world-gen-dev, ui-ux-dev |
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
| 28 | Supervivencia: ¿a quién controla el jugador: la villa, el Nujio u otra cosa? (El glosario §9 dice que el Nujio no es jugable.) | game-designer, city-systems-dev, rpg-systems-dev |
| 29 | ¿Cómo encaja cada modo en las dos capas de ADR 0002 y del pilar 1 (ciudad por días + RPG por turnos)? ¿Hay gestión de ciudad en los tres modos? ¿El tiempo avanza por días en todos? | game-designer, city-systems-dev, rpg-systems-dev |
| 30 | Aventura: el personaje "va viajando de lugar en lugar". ¿Cada lugar es un chunk distinto? ¿Una partida abarca varios chunks? (ADR 0003 dice un chunk por partida; ligada a #27) | world-gen-dev, game-designer, engine-architect |
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
| 45 | ¿Qué modos entran en el MVP: los tres o solo alguno? | game-designer, release-manager |
| 46 | Grafía: el glosario registra "Garel" y "Gael" para Estrella Azul. ¿El modo se llama definitivamente "Garelino"? | narrative-writer, ui-ux-dev |
| 47 | Villa: el dueño dijo que sus edificios sirven "para dormir o almacenar"; el glosario dice que la villa "no almacena comida". ¿Qué se almacena (herramientas, objetos, nada de comida)? | game-designer, city-systems-dev |
| 48 | Capa ciudad del GDD frente al glosario: recursos (madera, comida, oro), almacén, huerto, aserradero y cantera chocan con "no almacena comida", "madera solo de árboles muertos y con permiso" y la economía de Luz/Piedras (glosario §5, §6). ¿Se rediseña la capa ciudad? | game-designer, city-systems-dev |
| 49 | Personaje de Aventura: ¿tiene que ser adoc (los "únicos especialistas en armas")? ¿Qué razas y oficios se pueden elegir? (El glosario dice "con el oficio que se desee", pero también que los ueutrec "no tienen oficios".) ¿El personaje pertenece a una villa, o lo llaman villas de otros lugares? | game-designer, rpg-systems-dev, narrative-writer |
| 50 | Escala: el glosario da villas de 20 a 1000–2000 habitantes. ¿Cómo cabe eso en un chunk de 64×64? ¿Se representa a todos o se abstrae? | game-designer, world-gen-dev, city-systems-dev |
| 51 | El glosario dice que la caza y la guerra eran tabú en la era de los Bosques (§7 "Guerra"). ¿Hay combates contra animales del bosque? ¿Cómo encaja con los encuentros por bioma del GDD? | game-designer, rpg-systems-dev |
| 52 | Humores: el chat los describe como "climas agresivos"; el glosario dice que "no necesariamente son malas". ¿En el juego pueden ser favorables? | game-designer |
| 53 | Inaind (glosario §9, game master de la Mecánica v0.2): ¿tiene equivalente en el videojuego (director de eventos, generador de villas y caminos)? | game-designer, world-gen-dev |
