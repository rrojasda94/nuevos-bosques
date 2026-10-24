# Changelog

Todos los cambios que nota el jugador. Formato [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/), versiones [SemVer](https://semver.org/lang/es/). Proceso en [`CONTRIBUTING.md`](CONTRIBUTING.md).

## [Sin publicar]

### Añadido
- Caminos principales de tierra clara, de dos casillas de ancho, que unen las villas de todos los Bosques con la villa natal. En los cruces y cada pocos chunks hay letreros del camino que señalan hacia tu villa natal, y junto al camino hay refugios (árboles huecos o cuevas) cada 2 o 3 chunks.
- El tiempo avanza en Aventura y se para con los menús y el combate: un Día de Gietos de 8 minutos y una Noche de Riumna de 5 con luz de luna plateada, en la que los claros del mundo resaltan. Entre uno y otro pasa el riutash, avisado a los 60 y a los 15 segundos: en un refugio o en la plaza de una villa te cura la mitad de los PV que te faltan; expuesto te quita el 30% de tus PV máximos, pero nunca te mata. El día sube al amanecer y el HUD muestra el Momento y el tiempo que falta para el riutash.

### Cambiado
- El combate se narra estilo Pokémon: letra a letra, un mensaje por acción, con barras de PV animadas.
- Los Únicos son monstruos (cuadrúpedo, serpiente, cornudo, de muchos ojos, alado) con los colores de su Bosque. La serpiente es Aledra y el resto, Ofomni.

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
