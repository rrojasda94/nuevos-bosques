# GDD — Nardaram: Los Nuevos Bosques

> Dueño: `game-designer`. Estado: borrador v0.6 (incorpora ADR 0002 a 0005 y la conciliación con el glosario del dueño).
>
> **MVP = modo Aventura** (ADR 0005). Alcance del primer vertical slice: [`mechanics/aventura-mvp.md`](mechanics/aventura-mvp.md).
>
> **Lore:** la fuente de verdad es [`docs/glosario_nuevos_bosques.md`](../glosario_nuevos_bosques.md), del dueño del proyecto, y no se edita. Este GDD no redefine lore: enlaza a ese archivo.

## Visión
Cada partida ocurre en el mapa fijo de Nardaram. Las zonas (chunks de 64×64 tiles) se generan con la seed de la partida al entrar y persisten durante esa partida. Cada partida tiene un **modo elegido al empezar** (Supervivencia, Garelino o Aventura) con su propia misión (ADR 0004). El conflicto gira en torno al [Nujio](../glosario_nuevos_bosques.md) y su Bosque frente a los garelinos, que quieren sembrar los Nuevos Bosques. Pixel art 8-bit top-down, sesiones cortas, progreso visible. Solo español.

> La gestión de villa/ciudad por días (ADR 0002) corresponde sobre todo a Supervivencia (ADR 0005). Su papel en Aventura y Garelino está por definir (#60).

## Pilares
1. Dos capas, un mundo. (Encaje por modo: por definir, #29.)
2. Sesiones cortas con progreso visible (15 min = algo nuevo).
3. Legibilidad 8-bit.
4. **Cada partida es distinta, cada región se reconoce**: la seed cambia la disposición, la región mantiene su identidad.

## Loop principal (por días)
> Loop previo a ADR 0004. Previsiblemente corresponde a Supervivencia (ADR 0005); por revisar cuando se haga su ficha. Aventura: ver [`mechanics/aventura-mvp.md`](mechanics/aventura-mvp.md).
```
Inicio del día: ver estado del pueblo (comida, gente, amenazas) y de la misión
   ↓
Fase de ciudad: construir, asignar trabajos, gestionar almacén
   ↓
(opcional) Expedición: elegir destino en el chunk → explorar → combates por menú → loot/supervivientes
            Consume 1–3 días (pendiente #12); el pueblo sigue simulándose mientras tanto.
   ↓
Fin del día: producción → consumo → necesidades → eventos → chequeo de misión
```

## Modos de partida (ADR 0004)
El modo se elige al empezar, de forma similar a Project Zomboid. **Derrota = fallar la misión de la partida.**

| Modo | Qué haces | Victoria | Derrota |
|---|---|---|---|
| **Supervivencia** | Mantienes con vida al Nujio. Es un modo largo: debes evitar que los garelinos enloquezcan al Nujio o aniquilen el bosque. Juegas "en teoría" con el Nujio (choca con el glosario §9, #59). Es gestión de villa: pedir a los pobladores que mantengan o se esfuercen por más Luz, controlar el crecimiento de la población, mantenerlos contentos con el Nujio o amenazarlos con la fuerza de los Únicos, y evitar que los garelinos lleguen al Nujio (ADR 0005). | No hay. | Los garelinos enloquecen al Nujio o aniquilan el bosque (reglas: por definir, #39b). |
| **Garelino** | Comandas un grupo de fanáticos que buscan destruir los bosques dominados por un Nujio. Mejoras tus tropas, aprendes habilidades y estrategias para acelerar la decadencia y reclutas nuevos individuos. Te enfrentas a los Humores del mundo, a los Únicos que envía el bosque y a la resistencia de la población de la villa. | Eliminar al Nujio y sembrar las primeras semillas de los Nuevos Bosques. | Quedarte sin individuos. |
| **Aventura** (MVP) | Creas un personaje que viaja de lugar en lugar según las misiones que aparezcan (derrotar Únicos; las villas suelen llamar al adoc). Subes experiencia, aprendes habilidades, ganas objetos y fama. Viajas entre chunks y por el mapa de la región (ADR 0005). | Por definir (#31). | Muerte del personaje = game over. |

### Reglas de no matar
- **Aventura**: no se puede matar gente donde haya otras personas o seres con consciencia (qué ocurre si se intenta: por definir, #34).
- **Garelino**: matar gente afecta mucho a la reputación del grupo y hace más difícil el trabajo, o vuelve a los enemigos más agresivos y fuertes (medida y efectos: por definir, #35).

### Recursos de juego sin definir
Antes de implementarse necesitan fuente, sumidero y qué pasa si se agotan:
- Fama (Aventura): por definir (#33).
- Reputación del grupo (Garelino): por definir (#35).
- Individuos/tropas (Garelino): cuando llegan a 0, derrota. Reclutamiento y mejora: por definir (#37).
- Luz de viaje (Aventura y Garelino): quedarse sin ella es un riesgo del viaje (ADR 0005). Fuente, sumidero y efecto al agotarse: por definir (#57).
- Luz en Supervivencia: se pide a los pobladores (ADR 0005). Reglas: por definir (#59).

### Presiones de supervivencia por modo
- Supervivencia: los garelinos (sobre el Nujio y el bosque). Resto: por definir.
- Garelino: Humores del mundo, Únicos, resistencia de la villa, pérdida de individuos, reputación, riesgos de viaje.
- Aventura: muerte permanente del personaje y riesgos de viaje por regiones desconocidas: peligros, bosques agresivos, quedarse sin Luz, Únicos poderosos (ADR 0005; #56, #58).

## Mundo (ADR 0003, 0004, 0005)
- **Mapa mundial fijo** (ADR 0005): `data/world/world_map.json` + arte de referencia en `docs/design/world/`.
- Región → bioma, clima, relieve, facción, recursos, peligro.
- **Ámbito jugable:** solo la parte suroccidental de Nardaram (regiones concretas: #64).
- **Escala:** chunk < zona < área < región < Sur Lenfi (cantidades: #62).
- Generación: lo que se visita se genera al entrar, con la seed de la partida. Una zona nueva puede ser una villa, un bosque o una geografía (qué lo decide: #61). Si vuelves dentro de la misma partida, todo sigue como lo dejaste. Con mucho tiempo, lo orgánico puede crecer o desaparecer y la gente moverse (#65). Otra partida genera lugares distintos.
- **Región de origen:** el jugador la elige al empezar. Le da conocimiento automático del área y sus zonas. Cuanto más lejos del punto inicial, más complicado el viaje (#56, #57, #66).
- Viaje: en Aventura y Garelino se pasa entre chunks y se usa el mapa de la región para distancias largas (#63, #56).
- Chunk: **64×64 tiles.** Puede tener o no una villa al generarse.
- Villa en el chunk: edificios pequeños para dormir o almacenar; el resto de estructuras está al aire libre. Tamaño: por definir (#14b). Hay contradicciones con el glosario (#47, #50).
- Nujio en el chunk: suele estar en el centro de la villa; ocupa "entre 6x6 y 8x8 de diámetro" (unidad: por confirmar, #40).

## Capa ciudad (MVP)
> Corresponde sobre todo al modo Supervivencia (ADR 0005), que **no está en el MVP**. Por revisar frente a villas, Nujio y glosario (#14b, #48, #59). Choques: la hoguera central frente al Nujio en el centro, y la comida almacenada, la madera y el oro frente a la economía y las costumbres del glosario.
- Grid 16×16 top-down.
- Recursos: madera, piedra, comida, oro.
- Edificios iniciales: hoguera (centro), cabaña, aserradero, cantera, huerto, herrería.
- Ciudadanos: llegan por expediciones; necesitan cabaña y comida; trabajan en un edificio.
- Producción/consumo **por día** en `data/buildings/`.

## Capa RPG (MVP)
> Por revisar: en Aventura se crea un solo personaje y en Garelino se comandan tropas (#32, #49). Combates contra animales: #51.
- Party de hasta 3. Stats: HP, ATK, DEF, SPD.
- Combate por turnos, menú: Atacar / Habilidad / Objeto / Huir.
- Exploración top-down del chunk; encuentros según bioma de la región.
- Inventario 12 slots. Equipo: arma, armadura, accesorio.

## Términos de juego
| Término | Definición de juego |
|---|---|
| **Modo de partida** | Supervivencia, Garelino o Aventura; se elige al empezar (ADR 0004). |
| **Misión de la partida** | Lo que hay que cumplir según el modo; fallarla es la derrota. |
| **Chunk** | Área jugable de 64×64 tiles generada con seed (ADR 0003, 0004). |
| **Fama** | Recurso del modo Aventura. Por definir (#33). |
| **Reputación** | Recurso del grupo en el modo Garelino. Por definir (#35). |
| **Individuos / tropas** | Miembros del grupo en el modo Garelino; con 0 se pierde. Por definir (#37). |

### Términos de lore usados en el diseño (definición en el glosario)
- **Nujio**: ver [glosario §3](../glosario_nuevos_bosques.md).
- **Bosque**: ver [glosario §3](../glosario_nuevos_bosques.md).
- **Únicos** (Iserald, Aledra, Ofomni): ver [glosario §3](../glosario_nuevos_bosques.md).
- **Villa**: ver [glosario §5](../glosario_nuevos_bosques.md).
- **Adoc** (oficio): ver [glosario §5, Oficios](../glosario_nuevos_bosques.md).
- **Humores del Mundo**: ver [glosario §2](../glosario_nuevos_bosques.md).
- **Estrella Azul (Garel / Gael)**: ver [glosario §7](../glosario_nuevos_bosques.md). Que los garelinos sean sus seguidores es una deducción, a confirmar (#25, #46).
- **Nuevos Bosques** y **Piedras de los Nuevos Bosques**: ver [glosario §7](../glosario_nuevos_bosques.md).

## Fuente para diseño (glosario)
Material del glosario que puede alimentar mecánicas. **No son mecánicas decididas**: cada punto necesita una ficha y la confirmación del dueño antes de usarse.
- **Oficios** (§5): Dumno, Underil, Ildo, Ista, Ledai, Adoc, Sarua, Rogoc, Pholua, Sfida, Folas, Turos, Jiulua, Paruas, Jelios. Posibles clases o roles.
- **Economía** (§6): Luz y Piedras de los Nuevos Bosques como monedas (al oeste dominan las Piedras, al este la Luz). Posible sustituto de "oro" (#48).
- **Multiplicador de valor del Ista** (§6): déficit o superávit de −5 a +5 por recurso, aplicado como ±1.x sobre el valor nominal. Posible base de precios variables.
- **Ciclo día/noche** (§1 "Momento", §2 "Riutash"): día = Momento de Gietos, noche = Momento de Riumna; el riutash en las transiciones, y el clima puede cambiar tras uno. Posible estructura del paso del tiempo.
- **Personajes jugables** (§9): lenfi, ueutrec y kulvar, con el oficio o característica que se desee. No jugables: Únicos, Humores, Nujio, Mitahphol, Ojos (#49).
- **Reliquias** (§9): se obtienen derrotando enemigos, no comprando. Posible regla de loot.
- **Ecosistemas** (§8): sabana, pantano, bosque, pradera, desierto, montaña. Posibles biomas.
- **Regiones del Sur** (§8): candidatas para la parte suroccidental jugable (#64).
- **Situación inicial** (§9): era tardía de los Nuevos Bosques. Posible contexto de inicio.

## Fuera de alcance del MVP
Multijugador, mods, más de una región jugable (choca con la elección de región de origen; ver #68), localización (inglés en v1.x), **modos Supervivencia y Garelino** (el MVP es Aventura, ADR 0005).

## Métricas de playtest
- MVP (Aventura): ver los criterios de [`mechanics/aventura-mvp.md`](mechanics/aventura-mvp.md).
- Tiempo hasta el primer edificio construido: < 3 min. (Supervivencia; previo a ADR 0005.)
- Tiempo hasta la primera expedición: < 8 min. (Previo a ADR 0005; por revisar.)
- Jugador describe el loop sin ayuda tras 15 min.
- Duración media de partida antes de la primera derrota: 20–40 días (valor previo a ADR 0004; por revisar por modo).

## Pendiente
Ver `docs/decisions/0000-preguntas-abiertas.md`.
