# Preguntas abiertas

Las 8 preguntas iniciales están resueltas en `0002-decisiones-fundacionales.md` y `0003-mapa-mundial-y-chunks.md`. Las resueltas después se tachan y apuntan a su ADR.

## Prioritaria

| # | Pregunta | Bloquea a |
|---|---|---|
| 27 | **¿Se genera el mundo entero o solo el chunk?** El dueño dijo: "el mapa se genera similar a minecraft o al juego enorme de enanos" (probablemente Dwarf Fortress, a confirmar). Esto puede contradecir ADR 0003. Hay dos lecturas posibles: **(a)** el mapa mundial de Nardaram sigue diseñado a mano y solo el chunk de 64×64 de cada partida se genera con seed, como dice ADR 0003, y la comparación con Minecraft/Dwarf Fortress se refiere a cómo se genera ese chunk; **(b)** el mundo también se genera proceduralmente, al estilo Dwarf Fortress: primero se genera el mundo y después el jugador elige dónde empezar. En ese caso ADR 0003 cambiaría (el mapa hecho a mano dejaría de ser la fuente del mundo o pasaría a ser otra cosa). Afecta también a #9, #13 y #30. | world-gen-dev, game-designer, narrative-writer, engine-architect |

## Lista

| # | Pregunta | Bloquea a |
|---|---|---|
| 9 | ¿Cuántas regiones tiene el mapa mundial y cuáles son jugables en MVP? (depende de #27) | world-gen-dev, narrative-writer |
| 10 | ~~¿Tamaño de chunk?~~ **Resuelta** en ADR 0004: 64×64 tiles. | — |
| 11 | ~~¿Condición de derrota?~~ **Resuelta** en ADR 0004: fallar la misión de la partida (concretada por modo). | — |
| 12 | ¿Cuántos días dura una expedición típica? (propuesta: 1–3) | game-designer, rpg-systems-dev |
| 13 | ¿El jugador elige región al empezar o es aleatoria? (depende de #27) | world-gen-dev, ui-ux-dev |
| 14 | ~~¿Dónde está y qué tamaño tiene la ciudad dentro del chunk?~~ **Resuelta en parte** en ADR 0004: el chunk puede tener o no una villa; el Nujio suele estar en el centro de la villa. Lo que falta pasa a #14b, #40 y #41. | — |
| 14b | ¿Qué tamaño tiene una villa dentro del chunk de 64×64 y cuántos edificios tiene? ¿Sigue valiendo el grid de ciudad de 16×16 del GDD y la hoguera en el centro, o los sustituyen la villa y el Nujio? | world-gen-dev, city-systems-dev |
| 15 | ~~¿El modo se elige al empezar?~~ **Resuelta** en ADR 0004: se elige al empezar, de forma similar a Project Zomboid. Lo que falta pasa a #43. | — |
| 16 | ~~¿Condición de victoria de cada modo?~~ **Resuelta en parte** en ADR 0004: Supervivencia no tiene victoria; Garelino se gana eliminando al Nujio y sembrando las primeras semillas de los Nuevos Bosques. Aventura sigue abierta en #31. | — |
| 17 | ~~¿Qué mata al Nujio?~~ **Resuelta en parte** en ADR 0004: en Supervivencia se pierde si los garelinos enloquecen al Nujio o aniquilan el bosque. Está por lo general en el centro de la villa. Lo que falta pasa a #39. | — |
| 18 | ~~Garelino: ¿cómo se mide la influencia y cuándo se gana o se pierde?~~ **Resuelta** en ADR 0004: se gana eliminando al Nujio y sembrando las primeras semillas; se pierde al quedarse sin individuos. | — |
| 19 | Garelino: los bosques "dominados por un Nujio" que hay que destruir, ¿son uno solo por partida (el del chunk) o varios en la región del mapa mundial? | game-designer, world-gen-dev |
| 20 | Aventura: ¿cuántas misiones o Únicos hay por partida? ¿Se generan todas al inicio o van apareciendo? | game-designer, rpg-systems-dev |
| 21 | Aventura: la muerte del personaje es game over (ADR 0004). ¿Fallar una misión sin morir (plazo en días, huir, otra cosa) tiene alguna consecuencia o también termina la partida? | game-designer, rpg-systems-dev |
| 22 | ¿Cuántos tipos de Únicos hay en MVP y dependen de la región? | game-designer, narrative-writer, world-gen-dev |
| 23 | ¿Qué es exactamente "el adoc"? ¿Es el personaje del modo Aventura, una orden, un oficio? | narrative-writer, game-designer |
| 24 | Las villas ya están definidas (ADR 0004). ¿Las que llaman al adoc en Aventura son villas de otros chunks/lugares? ¿El personaje de Aventura tiene villa propia? | narrative-writer, game-designer |
| 25 | ~~¿Qué significa "Garelino"?~~ **Resuelta en parte** en ADR 0004: los garelinos son un grupo de fanáticos que buscan destruir los bosques dominados por un Nujio. Origen, historia y motivación: por definir (narrative-writer). | — |
| 26 | El Nujio aparece en Supervivencia y Garelino; los garelinos son el enemigo en Supervivencia; los Únicos aparecen en Aventura y Garelino. ¿Hay Únicos en Supervivencia? ¿Hay Nujio y garelinos en Aventura? | game-designer, narrative-writer |
| 28 | Supervivencia: ¿a quién controla el jugador: la villa, el Nujio u otra cosa? | game-designer, city-systems-dev, rpg-systems-dev |
| 29 | ¿Cómo encaja cada modo en las dos capas de ADR 0002 y del pilar 1 (ciudad por días + RPG por turnos)? ¿Hay gestión de ciudad en los tres modos? ¿El tiempo avanza por días en todos? | game-designer, city-systems-dev, rpg-systems-dev |
| 30 | Aventura: el personaje "va viajando de lugar en lugar". ¿Cada lugar es un chunk distinto? ¿Una partida abarca varios chunks? (ADR 0003 dice un chunk por partida; ligada a #27) | world-gen-dev, game-designer, engine-architect |
| 31 | Aventura: ¿hay una victoria final ("debe ganar": ganar qué) o es un modo sin final como Supervivencia? | game-designer |
| 32 | Aventura: ¿se juega con un solo personaje o con party? (el GDD tenía party de hasta 3) ¿Y en Garelino, cuántas tropas combaten a la vez? | game-designer, rpg-systems-dev |
| 33 | Aventura: ¿qué es la fama, cómo se gana o se pierde y qué efectos tiene? | game-designer, rpg-systems-dev |
| 34 | Aventura: ¿qué pasa si el jugador intenta matar gente donde hay otras personas o seres con consciencia (la acción está bloqueada, hay penalización, game over)? ¿Qué cuenta como "ser con consciencia"? ¿Se puede matar gente donde no hay testigos? | game-designer, rpg-systems-dev, narrative-writer |
| 35 | Garelino: ¿cómo se mide la reputación del grupo y cuáles son exactamente sus efectos ("más difícil el trabajo", "enemigos más agresivos y fuertes")? ¿Se puede recuperar? | game-designer |
| 36 | Garelino: Humores del mundo. ¿Qué tipos hay, qué acciones "delatan la intención y la ubicación" y qué efectos tienen? | game-designer, world-gen-dev, narrative-writer |
| 37 | Garelino: ¿con cuántos individuos se empieza, cómo y dónde se recluta, qué cuesta, y cómo se mejoran las tropas? | game-designer, rpg-systems-dev |
| 38 | Garelino: ¿qué es concretamente "acelerar la decadencia" y "sembrar las primeras semillas" (acciones, recursos, tiempo)? | game-designer |
| 39 | Supervivencia: ¿qué significan en reglas "enloquecer al Nujio" y "aniquilar el bosque"? ¿Hay medidas visibles (cordura, salud, extensión del bosque)? | game-designer, city-systems-dev |
| 40 | Nujio: "entre 6x6 y 8x8 de diámetro", ¿en tiles? ¿Varía por seed? | world-gen-dev, pixel-artist |
| 41 | Nujio: ¿qué significa en reglas que "tiene poder sobre el actuar de la villa"? | game-designer, city-systems-dev |
| 42 | Si el chunk no tiene villa, ¿qué modos se pueden jugar en él? ¿Puede haber un Nujio sin villa ("por lo general en el centro")? | world-gen-dev, game-designer |
| 43 | ¿Se puede cambiar de modo durante la partida? ¿Qué parte de Project Zomboid se toma como referencia (pantalla de elección de modo, opciones de sandbox, otra cosa)? | game-designer, ui-ux-dev |
| 44 | Únicos: en Aventura son "defensores de bosques descarriados en modo berserk"; en Garelino "los envía el bosque". ¿Son los mismos seres? ¿Los que envía el bosque también están en berserk? | narrative-writer, game-designer |
| 45 | ¿Qué modos entran en el MVP: los tres o solo alguno? | game-designer, release-manager |
