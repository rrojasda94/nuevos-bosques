# GDD — Nardaram: Los Nuevos Bosques

> Dueño: `game-designer`. Estado: borrador v0.10 (incorpora ADR 0002 a 0005, ADR 0007, 0008, 0010 y 0012, y la conciliación con el glosario del dueño).
>
> **MVP = modo Aventura en la región Valle del Sara** (ADR 0005, 0007). Alcance del primer vertical slice: [`mechanics/aventura-mvp.md`](mechanics/aventura-mvp.md).
>
> **Versión 0.2.0 "Primer encargo"** (fichas con valores provisionales):
> - [`mechanics/mision-ofomni.md`](mechanics/mision-ofomni.md): misión.
> - [`mechanics/tiempo-y-riutash.md`](mechanics/tiempo-y-riutash.md): tiempo real con pausa y riutash (ADR 0012).
> - [`mechanics/navegacion.md`](mechanics/navegacion.md): caminos, letreros, refugios, mapa y brújula.
> - [`mechanics/progresion-adoc.md`](mechanics/progresion-adoc.md): XP, niveles y fama.
> - [`mechanics/ofrendas-v1.md`](mechanics/ofrendas-v1.md): ofrendas.
>
> **Lore:** la fuente de verdad es [`docs/glosario_nuevos_bosques.md`](../glosario_nuevos_bosques.md), del dueño del proyecto. No se edita salvo petición explícita del dueño (única edición hasta ahora: "Sagra" → "Sara", ADR 0008). Este GDD no redefine lore: enlaza a ese archivo.

## Visión
Cada partida ocurre en el mapa fijo de Nardaram. Los Bosques (de 4 a 16 chunks de 64×64 tiles) se generan con la seed de la partida al entrar y persisten durante esa partida. Cada partida tiene un **modo elegido al empezar** (Supervivencia, Garelino o Aventura) con su propia misión (ADR 0004). El conflicto gira en torno al [Nujio](../glosario_nuevos_bosques.md) y su Bosque frente a los garelinos, que quieren sembrar los Nuevos Bosques. Pixel art 8-bit top-down, sesiones cortas, progreso visible. Solo español.

> La gestión de villa/ciudad por días (ADR 0002) corresponde sobre todo a Supervivencia (ADR 0005). En **Aventura el tiempo corre en tiempo real con pausa** (ADR 0012), con día (Momento de Gietos), noche (Momento de Riumna) y un riutash en cada cambio. Garelino: por definir (#60).

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
| **Aventura** (MVP) | Creas un personaje que viaja de lugar en lugar según las misiones que aparezcan (derrotar Únicos; las villas suelen llamar al adoc). Subes experiencia, aprendes habilidades, ganas objetos y fama. Viajas entre chunks y por el mapa de la región (ADR 0005). Primera misión: interceptar al Ofomni ([`mechanics/mision-ofomni.md`](mechanics/mision-ofomni.md)); si falla, la villa queda dañada y la partida sigue. | Es un **survival** (#31). | **Depende del monstruo** (ADR 0004): perder contra un monstruo **fatal en ese Momento** es game over (Iserald siempre; Aledra de noche); contra uno no fatal, despiertas en la villa. El Ofomni no es fatal en la primera misión (confirmado). Los Únicos comunes tampoco lo son (provisional, #127). |

### Reglas de no matar
- **Aventura**: no se puede matar gente donde haya otras personas o seres con consciencia (qué ocurre si se intenta: por definir, #34).
- **Garelino**: matar gente afecta mucho a la reputación del grupo y hace más difícil el trabajo, o vuelve a los enemigos más agresivos y fuertes (medida y efectos: por definir, #35).

### Recursos de juego sin definir
Antes de implementarse necesitan fuente, sumidero y qué pasa si se agotan:
- Fama (Aventura): provisional, +1 por misión cobrada y sin efectos todavía ([`mechanics/progresion-adoc.md`](mechanics/progresion-adoc.md); #33).
- XP y niveles (Aventura): XP = 4 + 3·d por victoria; niveles 1–10 ([`mechanics/progresion-adoc.md`](mechanics/progresion-adoc.md)).
- Ofrendas: catálogo provisional de 5, con valores de 3 a 8 ([`mechanics/ofrendas-v1.md`](mechanics/ofrendas-v1.md)).
- Reputación del grupo (Garelino): por definir (#35).
- Individuos/tropas (Garelino): cuando llegan a 0, derrota. Reclutamiento y mejora: por definir (#37).
- **Luz** (Aventura; ADR 0005, 0007, 0010):
  - **Fuentes**: vencer a Únicos y ayudar a la gente de la villa con sus peligros (misiones de villa, #106). Las villas también otorgan **ofrendas**: artefactos que almacenan Luz, de valores distintos.
  - **Sumideros**: pagar la entrada a Bosques con Nujio y la acción "Ofrecer Luz" en combate. Las ofrendas se usan **enteras**: se deja el artefacto completo en el Bosque y se pierde todo su valor aunque el coste fuera menor. Es gestión de recursos intencionada.
  - **Al agotarse**: hay que cruzar combatiendo o retroceder.
  - Que al principio sea difícil ir lejos es intencionado.
  - Valores provisionales en [`mechanics/cruce-y-combate-v1.md`](mechanics/cruce-y-combate-v1.md). Abiertas: #107–#109.
- **Luz suelta** (ADR 0010): tiene un límite (ejemplo: 10). Por encima, la Luz requiere ofrendas. Las ofrendas también se pueden ofrecer en combate "para que el Único se vaya", y eso abre el paso igual que vencer (#112). Excedente sobre el límite: #115.
- **Inventario**: provisionalmente, una lista sin límite (0.2.0). Sin decidir entre cuadrícula (Diablo), slots (Minecraft) o peso (Kingdom Come: Deliverance) (#113).
- **Riutash** (ADR 0012): expuesto, −30% de los PV máx. (nunca mata); en refugio, +50% de los PV que faltan. Avisos 60 s y 15 s antes ([`mechanics/tiempo-y-riutash.md`](mechanics/tiempo-y-riutash.md)).
- **Orientación** (0.2.0): caminos principales con letreros hacia la villa natal, refugios junto a los caminos, mapa (M) y brújula ([`mechanics/navegacion.md`](mechanics/navegacion.md)). El letrero se lee con **E** y abre un diálogo con una flecha que sigue el camino, el tiempo estimado hasta llegar y el nombre tentativo de la villa.
- **Noche** (Momento de Riumna): tono plateado de luz de luna; los colores resaltan de otra forma, no se oscurecen (post-proceso, excepción a la paleta anotada en ADR 0012).
- **Monstruos** ([`mechanics/monstruos.md`](mechanics/monstruos.md)):
  - Botarramas, Ofomni, Aledra, Iserald y reparep.
  - **Botarramas** (0.2.0, nombre provisional): son los Únicos que restringen el paso, aves sin plumas que renquean. Se ven en el mundo (y en el mapa) y salen a interceptar al jugador cuando se acerca a un Bosque cerrado; al tocarlo se abre el menú del borde. Sustituyen a los "Únicos de borde" genéricos.
  - **Sigilo, armas y robo** (0.3.0, [`mechanics/sigilo-y-robo.md`](mechanics/sigilo-y-robo.md)): solo una máscara u otro artefacto que camufle la Luz permite colarse (sin eso, el borde sigue cerrado). El arma se equipa o se desequipa de la mano principal, y solo equipada cierra el paso. Robar despierta a los Ofomni, que persiguen hasta la frontera.
  - Todos los Únicos tienen radio de visión, velocidad y distancia de encuentro (`vision_radius`, `step_time`, `engage_distance`).
- **Bosques con carácter y relación** (backlog, después de la 0.2.0; [`mechanics/bosques-y-relacion.md`](mechanics/bosques-y-relacion.md)):
  - Cada Bosque tiene tipo, temperamento (de agresivo a pacífico), cordura y estado de "bajo ataque".
  - Los Nuevos Bosques no cobran Luz y tienen otra fauna (mamíferos y reptiles).
  - Un Bosque que te llama a una misión no cobra y puede darte un salvoconducto por Bosques buenos.
  - Mejorar la relación con un Bosque abarata cruzarlo o estar en él.
  - Cada uno es fatal o no según el Momento (`fatal_at`). Aledra es fatal de noche; Iserald, siempre; el Ofomni no lo es en la primera misión.
  - Los reparep (cangrejos fantasmales en grupos de 2 a 4) traen el combate contra grupos, propuesto para la 0.3.0.
- **Curación de PV** (Aventura, ADR 0010): en una villa (plaza o junto a su Nujio) o, en parte, tras un riutash (cambio entre día y noche). El riutash **no cura heridas graves**.
- **Heridas graves** (Aventura, ADR 0010): perks o estados negativos que deja un combate complicado, aparte de los PV. Solo se curan en una villa con el oficiante adecuado, por ejemplo un dumno ([glosario §5](../glosario_nuevos_bosques.md)). Se puede pedir un dumno a otra villa, a cambio de quedarse más tiempo. Pendiente: #116–#118. Las villas solo están en 1 de cada 5 Bosques, pero **se empieza en la villa natal** y el Bosque inicial siempre tiene villa.
- **Estamina** (Aventura): el viaje a pie cansa al personaje (ADR 0007) y el riutash la regenera (ADR 0010). Medida, gasto y efectos: por definir (#73).
- Luz en Supervivencia: se pide a los pobladores (ADR 0005). Reglas: por definir (#59).

### Presiones de supervivencia por modo
- Supervivencia: los garelinos (sobre el Nujio y el bosque). Resto: por definir.
- Garelino: Humores del mundo, Únicos, resistencia de la villa, pérdida de individuos, reputación, riesgos de viaje.
- Aventura: muerte permanente del personaje y riesgos de viaje por regiones desconocidas: peligros, bosques agresivos, quedarse sin Luz, Únicos poderosos (ADR 0005; #56, #58). También el peaje de Luz o los Únicos para entrar a Bosques con Nujio, el cansancio al viajar a pie y los peligros de la noche (ADR 0007; #71, #73, #75).

## Mundo (ADR 0003, 0004, 0005, 0007, 0008)
- **Mapa mundial fijo** (ADR 0005): `data/world/world_map.json` + arte de referencia en `docs/design/world/`. Mapa del Sur Lenfi (preliminar; norte arriba): `docs/design/world/Sur-Lenfi_02.jpg`, descrito en [`world/sur-lenfi.md`](world/sur-lenfi.md).
- Región → bioma, clima, relieve, facción, recursos, peligro.
- **Ámbito jugable:** solo la parte suroccidental de Nardaram. Regiones del mapa, de oeste a este: Safis, Dorias, Valle del Sara, Nosie, Balasu, Naca (al norte del lago), Cabuta (costa sur) y Alcuss. Conciliación con el glosario: #94. Cuáles son jugables: #64.
- **Escala** (ADR 0007, 0008): chunk (64×64 tiles) < **Bosque** (4–16 chunks, forma y número aleatorios) < área (6–12 Bosques) < **subregión** (grupo de áreas; cada color del mapa; nombre propuesto, #100) < región (de decenas a un centenar de áreas) < Sur Lenfi.
- **Tipos de Bosque** (ADR 0008):
  - Con Nujio: un solo tipo de árbol (coníferas, cactus, palmeras, espinosos, copas redondas…) y una combinación de colores definida por su Nujio. El Bosque contiguo puede ser totalmente distinto, incluso monocromo.
  - Nuevos Bosques: se parecen a los bosques de nuestro mundo.
  - El límite entre Bosques se ve por el color de la vegetación.
  - Colores: solo los 32 de la paleta del proyecto. Lo "sin límite" son las combinaciones entre Bosques (ADR 0008, confirmaciones). Tipos para el MVP: #86. Otros tipos: #61.
- **Villas** (ADR 0008): 1 de cada 5 Bosques tiene villa, dentro de un solo chunk. Algunos caminos tienen letreros de piedra que indican hacia una villa (#87, #90). El Nujio está en el centro del Bosque (chunk más central); si hay villa, la villa ocupa ese chunk y el Nujio está en su centro.
- Generación: lo que se visita se genera al entrar, con la seed de la partida. Si vuelves dentro de la misma partida, todo sigue como lo dejaste. Con mucho tiempo, lo orgánico puede crecer o desaparecer y la gente moverse (#65). Otra partida genera lugares distintos.
- **Origen:** el jugador elige región y área de origen al empezar (ADR 0005, 0008). Le da conocimiento automático del área y sus Bosques. Cuanto más lejos del punto inicial, más complicado el viaje (#56, #57, #66).
- **Viaje** (ADR 0007):
  - Movimiento libre dentro del Bosque inicial.
  - Para entrar a otro Bosque que aún tenga Nujio: pagar Luz o enfrentarse a los Únicos que envía (#70, #71). Desde la 0.2.0, el aviso lo da un **Botarramas** visible que intercepta al jugador ([`mechanics/monstruos.md`](mechanics/monstruos.md)). Versión de prueba con números provisionales: [`mechanics/cruce-y-combate-v1.md`](mechanics/cruce-y-combate-v1.md).
  - Se puede recorrer todo el mapa a pie: es más lento, cansa al personaje y **también cuesta**, pero da más control sobre el gasto y el riesgo (ADR 0008; #73, #91). También se puede usar el mapa de la región para distancias largas (#56).
- **Terreno** (ADR 0007, 0008):
  - Árboles: bloquean, con espacio para caminar entre ellos (ADR 0008, confirmado).
  - Otras barreras físicas: agua, riscos y pendientes pronunciadas (aspecto de los riscos: #84).
  - Ríos continuos con zonas de paso (#88); los grandes son navegables, los estrechos y de montaña no (#74).
- **Día y noche** (ADR 0007): Momento de Gietos y Momento de Riumna, con peligros distintos; hay Bosques donde no se puede andar de noche (#75).
- **Región Valle del Sara** (MVP): 7 subregiones según el mapa, cada una con varias áreas (#101). Al norte, Lean, Causie, Tossie y Alss; en el centro, Ostie y Vastie; al sur, Cassie, en la costa (grafía confirmada). Más agreste al norte; el sur es más plano, con claros ribereños. El **río Sara** cruza Cassie hasta la costa y tiene afluentes. Vecinos: Dorias al oeste, Nosie al este, Cabuta al sureste. La región es "Valle del Sara" y "Sara" es el río (interpretado, ADR 0008). Detalle y vecinos: [`world/sur-lenfi.md`](world/sur-lenfi.md).
- **Región Alcuss**: subregiones Adess, Istil, Sass, Ness y Alciss (la más oriental). Hay lenfi en varios lugares de Ness y Alciss.
- **Lago Ungol** al sur de Naca; la **cordillera de Ungol**, al sur del lago, no tiene lenfi (ADR 0008).
- Nivel de Safis, Dorias, Nosie, Naca, Balasu y Cabuta (¿región o subregión?): #102. Las regiones del glosario §8 son grupos de áreas que se integrarán más adelante (#94).
- **Frecuencia de Nuevos Bosques**: alta en Lean, Tossie y Ostie (origen de la expansión, noroeste del Valle del Sara); muy rara en Nosie (al este del Valle del Sara); casi imposible en Alciss, la subregión más alejada (#78, #79).
- Villa: edificios pequeños para dormir o almacenar; el resto de estructuras está al aire libre; cabe en un chunk. Tamaño interno: por definir (#14b). Hay contradicciones con el glosario (#47, #50).
- Nujio: enorme, define la combinación de colores de su Bosque; está en el centro del Bosque (y de la villa, si la hay); ocupa "entre 6x6 y 8x8 de diámetro" (unidad: por confirmar, #40).

## Capa ciudad (MVP)
> Corresponde sobre todo al modo Supervivencia (ADR 0005), que **no está en el MVP**. Por revisar frente a villas, Nujio y glosario (#14b, #48, #59). Choques: la hoguera central frente al Nujio en el centro, y la comida almacenada, la madera y el oro frente a la economía y las costumbres del glosario.
- Grid 16×16 top-down.
- Recursos: madera, piedra, comida, oro.
- Edificios iniciales: hoguera (centro), cabaña, aserradero, cantera, huerto, herrería.
- Ciudadanos: llegan por expediciones; necesitan cabaña y comida; trabajan en un edificio.
- Producción/consumo **por día** en `data/buildings/`.

## Capa RPG (MVP)
> Por revisar: en Aventura se crea un solo personaje y en Garelino se comandan tropas (#32, #49). Combates contra animales: #51.
>
> **Versión de prueba en curso** (Aventura): un solo personaje, un Adoc (30 PV, ATQ 6, DEF 3, 10 de Luz), en combate por menú contra Únicos con las acciones Atacar, Defender, Ofrecer Luz y Huir. Números provisionales en [`mechanics/cruce-y-combate-v1.md`](mechanics/cruce-y-combate-v1.md). Tras el playtest de v1, el dueño da por buenos **de momento** la dificultad y el coste en Luz. La narración del combate va mensaje a mensaje, **estilo Pokémon**. Los **Únicos son monstruos, no árboles** (aspecto, tipos y nombres: #119) y **se regeneran con el tiempo** (#120). El Ofomni de la primera misión ataca con **látigos** y cada 3 turnos lanza un **Latigazo múltiple** anunciado (×3; Defender lo reduce a la mitad) ([`mechanics/mision-ofomni.md`](mechanics/mision-ofomni.md)). Cada tipo de monstruo es **fatal o no según el Momento** (ADR 0004, `mechanics/monstruos.md`). La lista siguiente es previa y por revisar.
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
