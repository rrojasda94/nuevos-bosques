# Changelog

Todos los cambios que nota el jugador. Formato [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/), versiones [SemVer](https://semver.org/lang/es/). Proceso en [`CONTRIBUTING.md`](CONTRIBUTING.md).

## [Sin publicar]

### Añadido
- Caminos principales de tierra clara, de dos casillas de ancho, que unen las villas de todos los Bosques con la villa natal. En los cruces y cada pocos chunks hay letreros del camino que señalan hacia tu villa natal, y junto al camino hay refugios (árboles huecos o cuevas) cada 2 o 3 chunks.
- El tiempo avanza en Aventura y se para con los menús y el combate: un Día de Gietos de 8 minutos y una Noche de Riumna de 5 con luz de luna plateada, en la que los claros del mundo resaltan. Entre uno y otro pasa el riutash, avisado a los 60 y a los 15 segundos: en un refugio o en la plaza de una villa te cura la mitad de los PV que te faltan; expuesto te quita el 30% de tus PV máximos, pero nunca te mata. El día sube al amanecer y el HUD muestra el Momento y el tiempo que falta para el riutash.
- Tecla E (botón A del mando) para interactuar. El sfida espera en la plaza de la villa natal y te saluda. Los letreros se leen con E: muestran una flecha hacia la villa de destino, su nombre y cuántos minutos de camino quedan (y si te pillará el riutash). Los refugios también se examinan con E.
- Mapa de la región con M (botón Select del mando): pausa el juego y muestra los chunks que has explorado con el color de su Bosque, los caminos, tu villa natal, las villas y refugios que has visto y dónde estás. Se cierra con M o Esc. En la esquina del HUD, una brújula de 8 direcciones señala tu villa natal (o el objetivo de la misión) y dice "Aquí" al llegar.

- Primera misión, "Primer encargo": al empezar, la brújula señala al sfida. Si hablas con él (E) te cuenta que un Ofomni viene hacia la villa y puedes aceptar o decir "Aún no". Al aceptar, el Ofomni (un ojo enorme con tentáculos) aparece a 3 o 4 Bosques y avanza un Bosque cada 6 minutos de juego. En cada riutash el Nujio vuelve a oírlo: la brújula y el mapa marcan su última posición. En su chunk se le ve y sale a por ti. Si lo vences, vuelve con el sfida: tu Luz se llena y recibes un Cuenco ritual, experiencia y fama. Si llega a tu villa, la misión falla, la villa queda dañada, pierdes la mitad de tu Luz y el Ofomni se queda allí esperando. Perder contra él no es el final: despiertas en la villa y él sigue avanzando.
- Combate contra el Ofomni: ataca con latigazos y cada tercer ataque usa el Latigazo múltiple (triple de daño). Lo anuncia un turno antes, y Defender lo deja en la mitad.
- Botarramas: aves sin plumas que renquean con los colores de su Bosque. Guardan cada tramo de frontera de un Bosque cerrado, junto a su puerta o camino. Te ven a 10 casillas, salen a por ti hasta 4 casillas fuera de su Bosque y, al alcanzarte, abren el menú del borde (pagar Luz, enfrentarlos o retroceder). Si retrocedes o huyes, te apartas dos casillas y te dejan en paz unos segundos. Pagar o vencer abre el Bosque y sus Botarramas se quedan quietos. En el mapa (M) aparecen donde los viste por última vez.
- Las victorias dan experiencia (4 + 3 por cada salto de distancia). Los niveles llegan más adelante.

### Cambiado
- Los letreros ya no se leen solos al pisarlos ni al pasar al lado.
- El combate se narra estilo Pokémon: letra a letra, un mensaje por acción, con barras de PV animadas.
- Los guardianes de los bordes son siempre Botarramas: ya no aparecen Aledra ni Ofomni en los cruces. El borde de un Bosque cerrado sigue sin dejarte pasar sin pagar o vencer.
- Retroceder en el menú del borde te aparta dos casillas en vez de una.
- El guardado pasa a la versión 6 (misiones, ofrendas, villa dañada, experiencia y fama). Las partidas anteriores se cargan y la misión vuelve a estar ofrecida.

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

[Sin publicar]: https://github.com/rrojasda94/nuevos-bosques/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/rrojasda94/nuevos-bosques/releases/tag/v0.1.0
