# Changelog

Todos los cambios que nota el jugador. Formato [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/), versiones [SemVer](https://semver.org/lang/es/). Proceso en [`CONTRIBUTING.md`](CONTRIBUTING.md).

## [Sin publicar]

### Añadido
- El Bosque recuerda: cada Botarramas que vences sube 2 de Luz el peaje de su Bosque (hasta 10) y hace que sus demás Botarramas vean 2 casillas más lejos (hasta 6 más). Cuando el Bosque recuerda tu violencia, el menú del borde lo avisa con una línea más.
- Relación con cada Bosque: baja 10 cada vez que vences a uno de sus Botarramas y sube 1 cada vez que pagas con Luz. La pantalla de estado (I) muestra la relación con el Bosque en el que estás.
- Pagar con una ofrenda (en el borde o en combate) hace que el Bosque olvide un poco: su hostilidad baja 1, y con ella el peaje y la visión de sus Botarramas. Pagar con Luz abre el paso, pero no borra lo que recuerda.
- Frutos en los Bosques: algunos árboles, junto a claros y senderos, tienen frutos de un color que destaca sobre sus hojas (3 a 6 frutales por chunk). Con E frente a uno tomas un fruto y recuperas el 25% de tus PV máximos; el árbol queda vacío hasta el próximo riutash. Cada Bosque te da un fruto por Momento si es tu Bosque natal o has pagado su peaje. Tomar un segundo fruto del mismo Bosque en el mismo Momento, o cualquier fruto de un Bosque que no te ha dado permiso, es robar: el juego te avisa y te deja elegir entre "Tomarlo igualmente" y "Dejarlo", y si lo tomas, "El Bosque lo ha visto.": su hostilidad sube 1 y tu relación con él baja 20. El guardado pasa a la versión 10; las partidas anteriores se cargan con todos los frutales llenos.
- Bolsa y equipo: la pantalla de estado (I) es ahora interactiva. Tiene una bolsa de 12 casillas y 3 ranuras de equipo (mano principal, máscara y talismán), la descripción del objeto marcado y la ficha del Adoc. Te mueves con las flechas, WASD o la cruceta; Aceptar (Intro, Espacio o E) equipa el objeto o lo guarda en la bolsa, e I o Esc cierran. Empiezas con la Lanza de adoc equipada (ATQ +2: desequipada no suma) y, para probar, una máscara y un talismán que aún no tienen efecto. Cada ofrenda ocupa una casilla. Con la bolsa llena, "Tu bolsa está llena": la ofrenda de un refugio se queda allí y el sfida guarda tu recompensa hasta que vuelvas con sitio. El guardado pasa a la versión 11; en las partidas anteriores tus ofrendas pasan a la bolsa y la lanza va equipada.
- Frutos guardados: al tomar un fruto con E eliges "Comerlo", "Guardarlo" o "Dejarlo" (con la bolsa llena solo puedes comerlo). Guardado cuenta igual para el fruto por Momento y para el robo, y se apila hasta 5 por Bosque de origen. Desde la pantalla de I se come y cura el 25% de tus PV máximos, pero solo dentro de su Bosque: fuera, su casilla se ve apagada. Si entras en otro Bosque con frutos de otro origen, "El Bosque de origen nota que te llevas su fruto." y tu relación con él baja 5 por fruto, una vez por cada salida.
- Dejar ofrendas ante el Nujio: con E frente a un Nujio, "Dejar una ofrenda" abre la lista de las ofrendas de tu bolsa (una opción por tipo, con su valor y cuántas llevas). La ofrenda sale de la bolsa, tu relación con ese Bosque sube su valor en Luz y su hostilidad baja 1. No paga el peaje.
- La relación cambia el peaje: con relación 30 o más el peaje es ×0,75; con 60 o más (amistad), ×0,5 y el paso pagado ya no caduca; con −30 o menos, ×1,5. El menú del borde lo dice con una línea más ("El Bosque te aprecia: peaje ×0,75.", "El Bosque es tu amigo: peaje ×0,5 y paso permanente." o "El Bosque desconfía de ti: peaje ×1,5.").
- Más formas de ganarte a un Bosque: si el riutash te pilla refugiado a 6 casillas o menos de su Nujio (o en la plaza de su villa), la relación sube 5 ("Pasaste el riutash junto al Nujio. El Bosque te acoge."). Cobrar la recompensa del sfida sube 25 la relación con tu Bosque natal.

### Cambiado
- El tiempo hasta el riutash ya no es un contador: en la esquina inferior derecha hay un reloj del riutash, como el de Minecraft, cuya esfera gira con el día. La mitad de Gietos (cielo azul y ojo dorado) y la de Riumna (cielo ultramarino, ojo plateado roto y riumini) pasan bajo la marca de arriba, y el riutash llega cuando el borde entre las dos queda bajo ella. En el último minuto el reloj late, cada vez más deprisa, y suena un "swish" en los avisos de 60 y 15 segundos y a los 10 y 5; al pasar el riutash, destella. Los avisos de texto se mantienen.
- El terreno tiene arte de verdad: hierba con matas, claros, senderos y caminos con bordes de hierba (el camino principal con rodadas y bordillo de piedras), ríos con orillas y agua que se mueve, vados de piedras, puentes de tablones, plaza de losas, casas de barro o de piedra con ventanitas y un vano sin puerta, letreros de piedra con la flecha tallada, árboles huecos y cuevas, y las 6 formas de árbol con sus frutos, todo con los colores de cada Bosque. Los riscos son ahora afloramientos de roca con una cara de sombra al sur, para que se lean como un desnivel y no como una pared.
- El paso pagado caduca: pagar el peaje (con Luz, con una ofrenda o en combate) abre el Bosque hasta el segundo riutash siguiente. Al caducar, el Bosque vuelve a estar cerrado (o forzado, si habías vencido a alguno de sus Botarramas), sus Botarramas vuelven a vigilar y el HUD avisa "Tu paso por este Bosque ha caducado.". Con amistad (relación 60 o más) el paso es permanente. La pantalla de estado (I) muestra hasta cuándo dura el paso del Bosque en el que estás ("Paso: hasta el 2.º riutash", "Paso: hasta el próximo riutash" o "Paso: permanente"). El guardado pasa a la versión 12; en las partidas anteriores, lo que tenías pagado queda abierto hasta el segundo riutash desde que cargas (o para siempre si ya tenías amistad con ese Bosque).
- Pagar el peaje con una ofrenda sube la relación con el Bosque su valor en Luz, como dejarla ante el Nujio (antes subía 1, como pagar con Luz).
- Vencer a un Botarramas ya no abre su Bosque: puedes cruzar su frontera, pero sus demás Botarramas siguen alerta, te salen al paso también dentro del Bosque y vuelven a exigirte el pago. Pagar (con Luz o con una ofrenda) deja el Bosque abierto y a sus Botarramas tranquilos.
- "Ofrecer Luz" en combate ya no hace daño: paga el peaje del Bosque con tu Luz suelta ("Ofrecer N Luz"), el Botarramas se aparta y el paso queda abierto, sin experiencia. Si no te llega la Luz, la opción sale en gris.
- El Ofomni de la misión es ahora el Ofomni descarriado: un Único que ha perdido el control, que no acepta Luz ni ofrendas y al que hay que vencer. Tiene menos PV (un 30% menos) para compensar que Ofrecer Luz ya no le hace daño. Las partidas guardadas se convierten solas.

### Corregido
- Un Botarramas vencido ya no vuelve a su puesto a bloquear el camino: se desvanece en la Luz del Bosque y no reaparece en la partida. Los Botarramas de un Bosque ya abierto no cierran el paso.
- Ya hay refugios más allá de tu Bosque: todos los Bosques tienen al menos uno, junto a su Nujio, y hay más repartidos por toda la región (más o menos uno de cada 2 o 3 chunks), también lejos del camino, junto a senderos y claros. Nunca estás a más de 2 chunks de un refugio y siempre se llega a pie.

## [0.2.0] - 2026-10-24
"Primer encargo": la primera misión del modo Aventura, con tiempo, orientación, progresión, ofrendas y primeros sprites y sonidos.

### Añadido
- Caminos principales de tierra clara, de dos casillas de ancho, que unen las villas de todos los Bosques con la villa natal. En los cruces y cada pocos chunks hay letreros del camino que señalan hacia tu villa natal, y junto al camino hay refugios (árboles huecos o cuevas) cada 2 o 3 chunks.
- El tiempo avanza en Aventura y se para con los menús y el combate: un Día de Gietos de 8 minutos y una Noche de Riumna de 5 con luz de luna plateada, en la que los claros del mundo resaltan. Entre uno y otro pasa el riutash, avisado a los 60 y a los 15 segundos: en un refugio o en la plaza de una villa te cura la mitad de los PV que te faltan; expuesto te quita el 30% de tus PV máximos, pero nunca te mata. El día sube al amanecer y el HUD muestra el Momento y el tiempo que falta para el riutash.
- Tecla E (botón A del mando) para interactuar. El sfida espera en la plaza de la villa natal y te saluda. Los letreros se leen con E: muestran una flecha hacia la villa de destino, su nombre y cuántos minutos de camino quedan (y si te pillará el riutash). Los refugios también se examinan con E.
- Mapa de la región con M (botón Select del mando): pausa el juego y muestra los chunks que has explorado con el color de su Bosque, los caminos, tu villa natal, las villas y refugios que has visto y dónde estás. Se cierra con M o Esc. En la esquina del HUD, una brújula de 8 direcciones señala tu villa natal (o el objetivo de la misión) y dice "Aquí" al llegar.
- Primera misión, "Primer encargo": al empezar, la brújula señala al sfida. Si hablas con él (E) te cuenta que un Ofomni viene hacia la villa y puedes aceptar o decir "Aún no". Al aceptar, el Ofomni (un ojo enorme con tentáculos) aparece a 3 o 4 Bosques y avanza un Bosque cada 6 minutos de juego. En cada riutash el Nujio vuelve a oírlo: la brújula y el mapa marcan su última posición. En su chunk se le ve y sale a por ti. Si lo vences, vuelve con el sfida: tu Luz se llena y recibes un Cuenco ritual, experiencia y fama. Si llega a tu villa, la misión falla, la villa queda dañada, pierdes la mitad de tu Luz y el Ofomni se queda allí esperando. Perder contra él no es el final: despiertas en la villa y él sigue avanzando.
- Combate contra el Ofomni: ataca con latigazos y cada tercer ataque usa el Latigazo múltiple (triple de daño). Lo anuncia un turno antes, y Defender lo deja en la mitad.
- Botarramas: aves sin plumas que renquean con los colores de su Bosque. Guardan cada tramo de frontera de un Bosque cerrado, junto a su puerta o camino. Te ven a 10 casillas, salen a por ti hasta 4 casillas fuera de su Bosque y, al alcanzarte, abren el menú del borde (pagar Luz, enfrentarlos o retroceder). Si retrocedes o huyes, te apartas dos casillas y te dejan en paz unos segundos. Pagar o vencer abre el Bosque y sus Botarramas se quedan quietos. En el mapa (M) aparecen donde los viste por última vez.
- Las victorias dan experiencia (4 + 3 por cada salto de distancia).
- Niveles del 1 al 10: cada nivel da +4 PV máximos y +1 de ataque (o +1 de defensa en los niveles 3, 6 y 9). Al subir, tus PV actuales suben también 4. El combate lo anuncia tras la victoria ("¡Subes a nivel N!") y el HUD muestra "Nv N". La recompensa de la misión también puede subirte de nivel.
- Ofrendas: en el menú del borde, "Ofrecer una ofrenda" abre la lista de las que alcanzan el peaje, con su valor y el coste del paso. Se dejan enteras: si valen más que el peaje, el resto se pierde; si valen menos, se completan con Luz suelta. No se combinan varias.
- Acción "Ofrenda" en el combate contra un Botarramas: si la ofrenda (más tu Luz suelta) llega al peaje, el Botarramas se aparta y el paso queda abierto, sin experiencia. El Ofomni no acepta ofrendas.
- Hallazgos: uno de cada tres refugios guarda una ofrenda pequeña (Cuenta de barro o Trenza votiva). Se recoge con E una sola vez por partida; después, "No queda nada".
- Pantalla de estado con I (botón Y del mando): nivel, experiencia hasta el siguiente nivel, PV, ataque, defensa, Luz suelta, fama y tus ofrendas. Pausa el juego y se cierra con I o Esc.
- Primeros sprites de pixel art y efectos de sonido: el Adoc (lenfi de trenza negra y ropa de protector) anda con dos fotogramas por dirección, el sfida respira con su túnica de oficiante y una pizca de Luz entre las manos, los Botarramas renquean y el Ofomni mueve los tentáculos, los dos con los colores de su Bosque, también en el combate. Suenan los pasos, las letras de los diálogos, el menú, los golpes y latigazos del combate, los avisos del riutash y su destello.

### Cambiado
- Los letreros ya no se leen solos al pisarlos ni al pasar al lado.
- El combate se narra estilo Pokémon: letra a letra, un mensaje por acción, con barras de PV animadas.
- Los guardianes de los bordes son siempre Botarramas: ya no aparecen Aledra ni Ofomni en los cruces. El borde de un Bosque cerrado sigue sin dejarte pasar sin pagar o vencer.
- Retroceder en el menú del borde te aparta dos casillas en vez de una.
- El guardado pasa a la versión 7 (misiones, ofrendas, villa dañada, experiencia, nivel, fama y refugios saqueados). Las partidas anteriores se cargan: la misión vuelve a estar ofrecida y el nivel es el que corresponde a la experiencia guardada.
- El menú del combate tiene cinco acciones: Atacar, Defender, Ofrecer Luz, Ofrenda y Huir. Las que no se pueden usar salen en gris, pero el cursor ya no las salta.

## [0.1.0] - 2026-10-23
Primer vertical slice del modo Aventura.

### Añadido
- Exploración top-down por casillas (WASD o flechas; Shift para correr) en chunks de 64×64 generados por seed.
- Región Valle del Sara con relieve norte-sur, río Sara continuo con vados y puentes, y arroyos de montaña.
- Bosques de 4 a 16 chunks, cada uno con su tipo de árbol, su combinación de colores y su Nujio en el centro.
- Villas en 1 de cada 5 Bosques, con plaza, edificios y letreros de piedra que apuntan a ellas. La villa natal está garantizada en el Bosque inicial.
- Cruce entre Bosques: ofrecer Luz o enfrentar al Único del Bosque.
- Combate por turnos con menú: Atacar, Defender, Ofrecer Luz y Huir.
- Luz suelta con tope de 10. Descanso en villas. Al perder, despiertas en la villa natal.
- Guardado de seed, posición, Luz, PV y Bosques abiertos.

[Sin publicar]: https://github.com/rrojasda94/nuevos-bosques/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/rrojasda94/nuevos-bosques/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/rrojasda94/nuevos-bosques/releases/tag/v0.1.0
