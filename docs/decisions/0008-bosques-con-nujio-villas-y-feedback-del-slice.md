# ADR 0008 — Aspecto de los Bosques, villas, viaje a pie y feedback del slice

## Contexto
Respuestas del dueño del proyecto (2026-10-23) tras probar la segunda versión del prototipo. Palabras textuales:

> "el bosque está muy tupido y no hay mucho espacio para caminar entre los arboles. Puedes consultar el PNG del mapa del Sur Lenfi, ahi pueder ver el mapa y las diferentes regiones y áreas separadas por colores. Alciss es una region en Alcuss. Cambia Sagra por Sara. #69 los nuevos bosques son bosques más parecidos a los bosques de nuestro mundo. Los bosques con nujio son diferentes tienen un solo tipo de arbol pero los colores son diferentes entre bosque y bosque. El nujio es enorme y define la paleta de colores. Si el nujio tiene hojas azules y tronco blanco todo el bosque es similar. El bosque contiguo puede ser totalmente diferente puede tener hojas moradas y troncos naranjas, tambienen pueden ser boques monocromos, no hay limite para las formas y variedades de colores entre uno y otro bosque, algunos pueden ser tipo coniferas, otro tipo catus, otro tipo palmeras otros mas espinozos, otros más de copas redondas, etc. #76 el bosuqe no necesariamente es un cuadrado, la forma y cantidad de chunks son generados aleatoriamente. #81 si. #80 puedes verlo ahí, ya iremos puliendo más el mapa y detallando mejor, pero ese es el preliminar. Villa, cambiemoslo, un Bosque puede o no tener una villa, la villa debe estar dentro de un chunk en caso ocurra que tenga una. Las chances de que haya una villa son del 1 en 5. Puede haber letreros de piedra en algunos caminos indicando hacia donde ir para allar una villa. #72 ir a pie igual cuesta y debes pagar. Ir al pie no significa gratis pero tienes más control del gasto y el riesgo. Respecto al norte y sur es en relación a la orientación de la imagen del mapa, el norte esta arriba y el sur abajo. los arroyos estan bien, me agrada, los rios tambien, pero los rios deben ser continuos y tener zonas de paso. respecto al limite entre uno y otro bosque es el color de la vegetación como te lo mencione antes."

> "me gustaba mas el tipo de bosque anterior del que no podias caminar entre los arboles. Las paredes si se notan muy falsas. No adecuadas."

## Decisiones
| Tema | Decisión |
|---|---|
| Nuevos Bosques (#69) | Se parecen más a los bosques de nuestro mundo. |
| Bosques con Nujio (#69) | Tienen **un solo tipo de árbol**. El Nujio es enorme y **define la paleta de colores** del Bosque (si tiene hojas azules y tronco blanco, todo el bosque es similar). El Bosque contiguo puede ser totalmente distinto, e incluso monocromo. No hay límite de formas ni de colores: coníferas, cactus, palmeras, espinosos, copas redondas, etc. |
| Límite entre Bosques | Se reconoce por el **color de la vegetación**. |
| Forma del Bosque (#76) | No tiene por qué ser cuadrado. La **forma y el número de chunks se generan aleatoriamente**, dentro del rango de 4 a 16 chunks de ADR 0007. |
| Área de origen (#81) | **Sí**, el jugador la elige. |
| Villa (sustituye lo anterior) | Un Bosque puede tener o no una villa, con una **probabilidad de 1 entre 5**. Si la tiene, la villa está **dentro de un solo chunk**. Puede haber **letreros de piedra** en algunos caminos que indiquen hacia dónde está una villa. |
| Viaje a pie (#72) | **También cuesta**: hay que pagar. Ir a pie da más control sobre el gasto y el riesgo. |
| Orientación (#80) | Norte arriba y sur abajo en la imagen del mapa. El mapa (regiones y áreas por colores) es preliminar y **todavía no está en el repo**. |
| Geografía | Alciss es una **región** dentro de Alcuss. "Sagra" pasa a llamarse **"Sara"**; aplicado en el glosario y en los documentos de diseño. |
| Ríos y arroyos | Al dueño le gustan los arroyos y los ríos del prototipo. Los ríos deben ser **continuos** y tener **zonas de paso**. |
| Árboles (feedback del slice) | Prefiere el bosque de la primera versión, en el que no se podía caminar entre los árboles. Según el coordinador, la lectura es: árboles que bloquean, con más espacio para caminar entre ellos. Lo de "más espacio" es interpretación, **a confirmar** (#83). |
| Riscos (feedback del slice) | Las paredes de la segunda versión "se notan muy falsas. No adecuadas." |

## Contradicciones registradas (sin resolver)
- **ADR 0007** dice "puedes caminar entre los árboles" (los árboles no bloquean). Ahora el dueño prefiere que no se pueda caminar entre ellos (#83).
- **Alcuss y la escala**: si Alciss es una región "en Alcuss", Alcuss está por encima del nivel región. Pero ADR 0007 cita "la Región de Alcuss", que contiene a Adess, Istil, Sass, Ness y Alciss. La escala chunk < Bosque < área < región < Sur Lenfi no tiene un nivel entre región y Sur Lenfi (#77).
- **Paleta**: `docs/STACK.md` y `docs/art/style-guide.md` fijan 32 colores "sin excepciones". Bosques con paletas propias "sin límite de colores" chocan con eso (#85).
- **Villa**:
  - Sustituye "el chunk puede tener o no una villa" (ADR 0004).
  - Choca con el glosario §5: "una por Bosque" se podía leer como que todo Bosque tiene villa, y allí la villa va de 20 a 1000–2000 habitantes, cuando ahora cabe en un chunk de 64×64 (#50).
  - Choca con el glosario §5 en Umun-Mal, que "ocupa 3 Bosques" (#50).
  - Choca con ADR 0004, que sitúa al Nujio "por lo general en el centro de la villa" (#89).
- **"Sara"**: ahora nombra a la vez el río Sara (glosario §8, §5, §7, §9) y la región o "valle del Sara". Ver #93.
- **Mapa**: el dueño remite al "PNG del mapa del Sur Lenfi" con áreas por colores. Los mapas localizados (cultural de 2021 y "Nardaram Regiones 20260211") no incluyen Lean, Tossie, etc. ni están en el repo (#80).

## Consecuencias
- **Prototipo**:
  - Los árboles vuelven a bloquear, con más espacio entre ellos (a confirmar, #83).
  - Hay que rehacer los riscos; las "paredes" actuales no sirven.
  - Los ríos deben ser continuos, con pasos.
  - Los Bosques vecinos se distinguen por la paleta de la vegetación.
- **`world-gen-dev`**: forma irregular del Bosque; 1/5 de Bosques con villa (en un solo chunk); letreros de piedra en caminos; ríos continuos con pasos; un tipo de árbol y una paleta por Bosque con Nujio.
- **`pixel-artist`**: necesita una spec de variantes de árbol por Bosque y una solución de paleta compatible o una ADR que cambie la regla de 32 colores (#85).
- La clave de generación debe incluir el tipo de árbol y la paleta del Bosque, ambos deterministas por seed.
