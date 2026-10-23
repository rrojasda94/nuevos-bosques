# ADR 0008 — Aspecto de los Bosques, villas, viaje a pie y feedback del slice

## Contexto
Respuestas del dueño del proyecto (2026-10-23) tras probar la segunda versión del prototipo. Palabras textuales:

> "el bosque está muy tupido y no hay mucho espacio para caminar entre los arboles. Puedes consultar el PNG del mapa del Sur Lenfi, ahi pueder ver el mapa y las diferentes regiones y áreas separadas por colores. Alciss es una region en Alcuss. Cambia Sagra por Sara. #69 los nuevos bosques son bosques más parecidos a los bosques de nuestro mundo. Los bosques con nujio son diferentes tienen un solo tipo de arbol pero los colores son diferentes entre bosque y bosque. El nujio es enorme y define la paleta de colores. Si el nujio tiene hojas azules y tronco blanco todo el bosque es similar. El bosque contiguo puede ser totalmente diferente puede tener hojas moradas y troncos naranjas, tambienen pueden ser boques monocromos, no hay limite para las formas y variedades de colores entre uno y otro bosque, algunos pueden ser tipo coniferas, otro tipo catus, otro tipo palmeras otros mas espinozos, otros más de copas redondas, etc. #76 el bosuqe no necesariamente es un cuadrado, la forma y cantidad de chunks son generados aleatoriamente. #81 si. #80 puedes verlo ahí, ya iremos puliendo más el mapa y detallando mejor, pero ese es el preliminar. Villa, cambiemoslo, un Bosque puede o no tener una villa, la villa debe estar dentro de un chunk en caso ocurra que tenga una. Las chances de que haya una villa son del 1 en 5. Puede haber letreros de piedra en algunos caminos indicando hacia donde ir para allar una villa. #72 ir a pie igual cuesta y debes pagar. Ir al pie no significa gratis pero tienes más control del gasto y el riesgo. Respecto al norte y sur es en relación a la orientación de la imagen del mapa, el norte esta arriba y el sur abajo. los arroyos estan bien, me agrada, los rios tambien, pero los rios deben ser continuos y tener zonas de paso. respecto al limite entre uno y otro bosque es el color de la vegetación como te lo mencione antes."

> "me gustaba mas el tipo de bosque anterior del que no podias caminar entre los arboles. Las paredes si se notan muy falsas. No adecuadas."

## Decisiones
| Tema | Decisión |
|---|---|
| Nuevos Bosques (#69) | Se parecen más a los bosques de nuestro mundo. |
| Bosques con Nujio (#69) | Tienen **un solo tipo de árbol**. El Nujio es enorme y **define la combinación de colores** del Bosque, dentro de la paleta de 32 colores del proyecto (ver confirmaciones) (si tiene hojas azules y tronco blanco, todo el bosque es similar). El Bosque contiguo puede ser totalmente distinto, e incluso monocromo. No hay límite de formas ni de colores: coníferas, cactus, palmeras, espinosos, copas redondas, etc. |
| Límite entre Bosques | Se reconoce por el **color de la vegetación**. |
| Forma del Bosque (#76) | No tiene por qué ser cuadrado. La **forma y el número de chunks se generan aleatoriamente**, dentro del rango de 4 a 16 chunks de ADR 0007. |
| Área de origen (#81) | **Sí**, el jugador la elige. |
| Villa (sustituye lo anterior) | Un Bosque puede tener o no una villa, con una **probabilidad de 1 entre 5**. Si la tiene, la villa está **dentro de un solo chunk**. Puede haber **letreros de piedra** en algunos caminos que indiquen hacia dónde está una villa. |
| Viaje a pie (#72) | **También cuesta**: hay que pagar. Ir a pie da más control sobre el gasto y el riesgo. |
| Orientación (#80) | Norte arriba y sur abajo en la imagen del mapa. El mapa (regiones y áreas por colores) es preliminar y **todavía no está en el repo**. |
| Geografía | ~~Alciss es una región dentro de Alcuss.~~ **Corregido por las confirmaciones:** Alcuss es una región y Alciss es un área. "Sagra" pasa a llamarse **"Sara"**; aplicado en el glosario y en los documentos de diseño. |
| Ríos y arroyos | Al dueño le gustan los arroyos y los ríos del prototipo. Los ríos deben ser **continuos** y tener **zonas de paso**. |
| Árboles (feedback del slice) | Prefiere el bosque de la primera versión, en el que no se podía caminar entre los árboles. Árboles que bloquean, con más espacio para caminar entre ellos: **confirmado** (ver confirmaciones). |
| Riscos (feedback del slice) | Las paredes de la segunda versión "se notan muy falsas. No adecuadas." |

## Confirmaciones del dueño (2026-10-23)
Preguntas del coordinador:
1. "Árboles: entendí que bloquean, como en la primera versión, pero con más espacio entre ellos. ¿Es así?"
2. "Sara: ahora es a la vez el río y la región. ¿Te sirve así, o la región se llama 'Valle del Sara' para distinguirla?"
3. "Nujio sin villa: ¿dónde está el Nujio en esos casos?"
4. "Alcuss: ¿Alcuss es un país o reino, por encima de las regiones? ¿Y Adess, Istil, Sass y Ness también son regiones?"
5. (Antes) La paleta de 32 colores frente a los colores sin límite.

Respuesta textual:
> "1 si 2 si 3 en el centro del bosque 4 Alcuss es una region y Alciss es un área. Los colores sin limites me referia a la combinacion, usa los que estan definidos en el proyecto."

| # | Decisión |
|---|---|
| #83 Árboles | **Bloquean**, como en la v1, **con más espacio entre ellos**. Confirmado. |
| #93 Sara | La región se llama **"Valle del Sara"** y **"Sara"** es el río. *Interpretado*: el "sí" respondía a una pregunta de "o esto o lo otro"; se elige esta lectura porque el dueño siempre dice "región del Valle del Sara". Confirmar si hace falta. En el glosario §8, "Sara (valle del Sara)" se lee como esa región. |
| #89 Nujio | El Nujio está **en el centro del Bosque**. Para la implementación: en el chunk más central del Bosque. Si el Bosque tiene villa, la villa va en ese chunk y el Nujio en su centro (coherente con ADR 0004). |
| #77 Alcuss | **Alcuss es una región** y **Alciss es un área**. Adess, Istil, Sass y Ness son probablemente áreas de Alcuss, a confirmar. La frase de ADR 0007 "Alciss… la región más alejada" se lee como "el área más alejada". La escala chunk < Bosque < área < región < Sur Lenfi queda intacta. "Nosie" sigue sin ubicar. |
| #85 Paleta | Solo se usan los **32 colores de la paleta del proyecto** (`assets/palettes/nuevos-bosques.gpl`). Lo "sin límite" son las **combinaciones** de esos colores entre Bosques. Ya no hay conflicto con `docs/STACK.md` ni con `docs/art/style-guide.md`. |

## Nota: mapa del Sur Lenfi (2026-10-23)
El dueño subió el mapa a `docs/design/world/Sur-Lenfi_02.jpg`; su descripción está en `docs/design/world/sur-lenfi.md`. Según el mapa:
- Lo confirma: Alciss es un área de Alcuss, en el extremo este. Adess, Istil, Sass y Ness también son áreas de Alcuss.
- Lo confirma: Nosie es una región propia, al este del Valle del Sara.
- Áreas del Valle del Sara: al norte Lean, Causie, Tossie y Alss; en el centro Ostie y Vastie; al sur Cassie, en la costa. Agrupación por color, *lectura del mapa*.
- El mapa escribe "Cassie" (el dueño escribió "Casie", #99).

Choques nuevos, sin resolver:
- La lista de regiones del mapa no coincide con la del glosario §8 (#94).
- El Valle del Sara tiene 7 áreas frente a las "decenas o un centenar" de ADR 0007 (#95).
- Marca azul en la desembocadura de Cassie (#96).
- Ríos o límites (#97).
- ¿El lago es Ungol? (#98)

## Contradicciones registradas
- ~~**ADR 0007** dice "puedes caminar entre los árboles". Ahora el dueño prefiere que no se pueda caminar entre ellos (#83).~~ Resuelta: los árboles bloquean, con más espacio (confirmaciones).
- ~~**Alcuss y la escala** (#77).~~ Resuelta: Alcuss es una región y Alciss un área (confirmaciones).
- ~~**Paleta** (#85).~~ Resuelta: 32 colores; lo ilimitado son las combinaciones (confirmaciones).
- **Villa**:
  - Sustituye "el chunk puede tener o no una villa" (ADR 0004).
  - Choca con el glosario §5: "una por Bosque" se podía leer como que todo Bosque tiene villa, y allí la villa va de 20 a 1000–2000 habitantes, cuando ahora cabe en un chunk de 64×64 (#50).
  - Choca con el glosario §5 en Umun-Mal, que "ocupa 3 Bosques" (#50).
  - ~~Choca con ADR 0004 sobre la posición del Nujio (#89).~~ Resuelta: el Nujio está en el centro del Bosque y, si hay villa, en el centro de esta (confirmaciones).
- ~~**"Sara"**: nombra a la vez el río y la región (#93).~~ Resuelta por interpretación: región "Valle del Sara", río "Sara" (confirmaciones).
- **Mapa**: el dueño remite al "PNG del mapa del Sur Lenfi" con áreas por colores. Los mapas localizados (cultural de 2021 y "Nardaram Regiones 20260211") no incluyen Lean, Tossie, etc. ni están en el repo (#80).

## Consecuencias
- **Prototipo**:
  - Los árboles vuelven a bloquear, con más espacio entre ellos (confirmado).
  - Hay que rehacer los riscos; las "paredes" actuales no sirven.
  - Los ríos deben ser continuos, con pasos.
  - Los Bosques vecinos se distinguen por la paleta de la vegetación.
- **`world-gen-dev`**: forma irregular del Bosque; 1/5 de Bosques con villa (en un solo chunk); letreros de piedra en caminos; ríos continuos con pasos; un tipo de árbol y una paleta por Bosque con Nujio.
- **`pixel-artist`**: necesita una spec de variantes de árbol por Bosque y de combinaciones de color dentro de la paleta de 32 (#86).
- La clave de generación debe incluir el tipo de árbol y la paleta del Bosque, ambos deterministas por seed.
