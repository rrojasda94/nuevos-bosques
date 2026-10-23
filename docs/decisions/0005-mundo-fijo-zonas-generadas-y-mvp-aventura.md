# ADR 0005 — Mapa fijo, zonas generadas persistentes, modos y MVP en Aventura

## Contexto
Respuestas del dueño del proyecto a las preguntas #27, #28, #29, #30 y #45 (2026-10-23). Palabras textuales:

> "el mapa de Nardaram ya existe es un mapa fijo. Lo que si no es fijo es cuando entras a una zona. Eso se puede generar aleatoriamente en cada partida. Si visitas un nuevo lugar en una partida se genera una villa, bosque o geografia nueva, pero si quieres regresar a ese lugar, se mantiene tal cual. En otra partida se vuelve a generar otro diferente. En aventura y garelino si puedes viajar entre chunks y tambien puedes usar el mapa de la región para viajar distancias más grandes. Pasa que si no conoces ciertas regiones puedes encontrarte con peligros, bosques agresivos, quedarte sin "Luz" para viajar, toparte con Únicos poderosos, etc. En modo supervivencia si jugamos con el Nujio en teoria, es más como un juego de gestión de villa tienes que pedir a los pobladores mantener o esforzarse por más Luz, controlar el crecimiento de la población, mantenerlos contentos con el Nujio o amenazarlos con la fuerza de los Únicos, evitar que los garelinos lleguen al Nujio. me gustaria empezar con el modo aventura para probar un poco los controles y que sea divertido."

## Decisiones
| Tema | Decisión |
|---|---|
| Mapa mundial (#27) | **Fijo**: el mapa de Nardaram ya existe. Se aplica la lectura (a): ADR 0003 sigue vigente. |
| Zonas | Se generan al entrar en ellas, con la seed de la partida. Al visitar un lugar nuevo se genera una villa, un bosque o una geografía nueva. |
| Persistencia | Dentro de una partida, una zona ya visitada **se mantiene tal cual** si vuelves. En otra partida se genera una diferente. |
| Varios chunks por partida (#30) | En **Aventura y Garelino** se puede viajar entre chunks y también usar el **mapa de la región** para distancias más grandes. En Supervivencia: por definir. |
| Riesgos de viaje | En regiones que no conoces puede haber peligros, bosques agresivos, quedarte sin Luz para viajar, Únicos poderosos, etc. La **Luz** es, por tanto, un recurso de viaje (reglas: por definir). |
| Supervivencia (#28, #29) | El jugador juega "en teoría" con el Nujio. Es un juego de **gestión de villa**: pedir a los pobladores que mantengan o se esfuercen por más Luz, controlar el crecimiento de la población, mantenerlos contentos con el Nujio o amenazarlos con la fuerza de los Únicos, y evitar que los garelinos lleguen al Nujio. |
| Capas de ADR 0002 | La capa de ciudad por días corresponde sobre todo a Supervivencia. Cómo encajan las capas en Aventura y Garelino: por definir. |
| MVP (#45) | **Modo Aventura.** Objetivo: probar los controles y que sea divertido. Alcance del primer vertical slice: `docs/design/mechanics/aventura-mvp.md`. |

## Respuestas del dueño (2026-10-23): #54, #55, #9, #13
Palabras textuales:
> "#54 tal como lo dejé, pero si pasa mucho tiempo puede que haya elementos que hayan crecido o desaparecido por ejemplo si son organicos o si la gente ya se ha movido. #55 chunk < zona < área < región < Sur Lenfi esa es la escala. El mapa que tengo dibujado es el mapa de Nardaram pero solo vamos a jugar en la parte sur occidental de este. #9 puedes elegir de que región eres y eso te da conocimiento automatico del área y las zonas que tiene, mientras más alejado esten los lugares del punto inicial, más complicado el viaje. #13 lo eliges."

| Tema | Decisión |
|---|---|
| Persistencia (#54) | Una zona visitada se mantiene **tal como el jugador la dejó**, con sus cambios. Si pasa mucho tiempo, los elementos orgánicos pueden haber crecido o desaparecido y la gente puede haberse movido. Reglas concretas: por definir (#65). |
| Escala espacial (#55) | **chunk < zona < área < región < Sur Lenfi.** Zona y chunk **no** son lo mismo: una zona contiene varios chunks. Cantidades y forma de conexión: por definir (#62, #63). |
| Ámbito jugable | El mapa dibujado es el de Nardaram entero, pero **solo se juega en la parte suroccidental**. Qué regiones la forman: por definir (#64). |
| Región de origen (#9, #13) | El jugador **elige** su región de origen al empezar. Eso le da conocimiento automático del área y de sus zonas. Cuanto más lejos del punto inicial, más complicado es el viaje (#56, #57). |

Corrección a la tabla de decisiones de arriba: donde dice "Zonas se generan al entrar", la unidad que se genera y persiste puede ser la zona o el chunk; queda abierto en #62. La generación debe identificar cada chunk dentro de su zona, área y región.

## Contradicciones registradas (sin resolver)
- **ADR 0003** describe el mapa mundial como un "grid de regiones" del que se genera "el chunk" con `seed + region_id`. Ahora entre región y chunk hay dos niveles más (área, zona), y por encima está el Sur Lenfi. Además, solo se juega una parte del mapa. ADR 0003 no dice en qué nivel se fijan las reglas de bioma, recursos y enemigos (¿región, área o zona?).
- **GDD, "Fuera de alcance del MVP"**: dejaba fuera "más de una región jugable", pero ahora el jugador elige su región de origen y viaja entre regiones (#68).
- **Glosario §9** dice que el Nujio no es jugable (dato de la Mecánica v0.2, el diseño de rol de mesa). En cambio, el dueño dice que en Supervivencia se juega "en teoría" con el Nujio (#59).
- **ADR 0003** decía un chunk por partida y que `GameState` guarda "el chunk generado". Ahora una partida tiene varios chunks persistentes (en Aventura y Garelino). ADR 0003 queda ampliado por este.

## Consecuencias
- La generación de cada zona debe ser determinista a partir de `seed de partida + región + identificador de la zona`. Su formato lo deciden `world-gen-dev` y `engine-architect`.
- `GameState` / guardado debe mantener las zonas visitadas en la partida. Si se guarda solo la disposición o también los cambios del jugador está por definir (#54).
- El primer trabajo de implementación es el vertical slice de Aventura. Las fichas de Supervivencia y Garelino se posponen.
- Antes de implementar la Luz como recurso de viaje hay que fijar su fuente, su sumidero y qué pasa si se agota (#57).
