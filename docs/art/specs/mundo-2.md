# Spec: relieve, objetos de varias casillas y decoración variada (Mundo 2.0)

> Dueño: `pixel-artist`. Estado: **spec** (hito M2 de [`roadmap-mundo-2.md`](../../design/roadmap-mundo-2.md)). No es arte: fija tamaños, piezas, claves de color, orígenes, atlas y nombres para que M13 (primera pasada por script) y M18 (arte final, artista humano) dibujen lo mismo, y para que `world-gen-dev` (M6–M8) sepa qué piezas existen.
> Fuentes: [ADR 0014](../../decisions/0014-mundo-2-relieve-movimiento-libre-y-mundo-hibrido.md) (§1 escala, §3 relieve, §5 paso 6 decoración y el Anexo), [`tileset-terreno.md`](tileset-terreno.md) (claves de la 0.3), [`style-guide.md`](../style-guide.md) y la dirección de arte propuesta en el PR #43 (`docs/art/direccion-de-arte.md`: místico, extraño sin ser terrorífico, verdes y azules apagados, movimiento sutil en saltos de píxel entero, un solo acento frío reservado a lo etéreo).
> Referencia de prueba: el arte del spike (`tools/art/make_tiles_zelda.py` y `scripts/spike/spike_art.gd`, rama local `spike/mapa-estilo-zelda`). Esta spec manda sobre el spike.

## 1. Reglas comunes
- **Paleta**: los 32 colores de `assets/palettes/palette_nuevos_bosques.gpl`. Alfa 0 o 255. Sin antialiasing, sin degradados, sin giros que no sean de 90°.
- **Rejilla**: casilla de 16×16 px. Un objeto de N×M casillas mide N·16 × M·16 px (salvo lo que se indique en la tabla final, columna "Sobresale").
- **Contorno**: 1 px `181425` en objetos con altura (árboles, rocas, casas, Nujio, tocones, troncos) y en el pie y los extremos de las caras. La decoración plana no lleva contorno completo, solo un píxel oscuro de apoyo (sombra de hierba).
- **Luz**: arriba a la izquierda, pero **casi cenital** en todo lo que se voltea (árboles, decoración, troncos): el brillo va arriba y la sombra abajo; el lado derecho solo se oscurece 1 o 2 px. Así el volteo horizontal no rompe la luz. Rocas, casas, caras y bordes **no se voltean** y llevan la luz de lado completa.
- **Volteo**: horizontal y por código (`Sprite2D.flip_h` o tile alternativo con `TRANSFORM_FLIP_H`), no se hornea en el PNG (en la 0.3 sí; aquí no, para no duplicar atlas).
- **Movimiento sutil** (dirección de arte): las copas y la hierba alta se mecen con un shader de desplazamiento por píxel entero (`engine-architect`). Para que funcione sin máscara, el tronco va siempre en el **tercio inferior** del sprite y no se mueve; si el shader necesita una máscara explícita, se pide a `engine-architect` y se añade aquí. Las únicas animaciones dibujadas son la cascada, su espuma y el Nujio.
- **Fondo**: los objetos y la decoración tienen fondo transparente. Las piezas de la capa de suelo (hierba, caras, bordes, escaleras, rampas, cascada, puente) son **opacas**: debajo no hay nada.
- **Validación** (M13 y al llegar el arte final, como `test_terrain_tileset`): tamaño de cada PNG, orden de casillas, colores de la paleta, alfa 0/255 y claves solo en su grupo.

## 2. Claves de color (recoloreado por Bosque)
Mismo mecanismo que la 0.3 (`TerrainTileset.recolor_map`): en cada **grupo** se cambian sus claves por los colores del Bosque (`BosqueMap.styles`: `leaf`, `trunk`, `ground`, `shape`). Dentro de un grupo ningún píxel fijo puede usar una de sus claves; fuera de él, esos colores son normales (por eso las rocas usan los grises).

### 2.1 Juegos de claves
| Juego | Clave en el PNG | Se cambia por | Origen |
|---|---|---|---|
| Hierba | `3e8948` | `GROUNDS[ground][0]` hierba | 0.3 |
| Hierba | `63c74d` | `GROUNDS[ground][1]` brizna clara | 0.3 |
| Hierba | `265c42` | `GROUNDS[ground][4]` sombra de la hierba | 0.3 |
| Claro | `ead4aa` | `GROUNDS[ground][2]` claro | 0.3 |
| Claro | `e4a672` | `GROUNDS[ground][3]` mota del claro | 0.3 |
| Árbol | `c0cbdc` | `LEAVES[leaf][1]` hoja clara | 0.3 |
| Árbol | `8b9bb4` | `LEAVES[leaf][0]` hoja oscura | 0.3 |
| Árbol | `5a6988` | `TRUNKS[trunk]` tronco | 0.3 |
| Árbol | `e43b44` | `fruit_color()[0]` fruto | 0.3 |
| Árbol | `a22633` | `fruit_color()[1]` sombra del fruto | 0.3 |
| Árbol | **`3a4466`** | `LEAF_SHADOW[leaf]` **sombra de hoja** (tabla 2.2) | **nueva** (spike) |
| Flor | `e43b44` | `flower_colors()[0]` = color del fruto | **nueva** (reusa la clave del fruto) |
| Flor | **`f6757a`** | `flower_colors()[1]` | **nueva** |
| Flor | **`ff0044`** | `flower_colors()[2]` | **nueva** |

Las dos claves de flor nuevas (`f6757a`, `ff0044`) hacen falta para "flores de 3 colores de su paleta" (ADR 0014 §5.6) sin gastar las claves de hoja, que usa la hojarasca. Si se prefiere no añadirlas, la alternativa es flor 2 = hoja clara y flor 3 = blanco fijo, a costa de quitar la hoja clara de la hojarasca. Se cambian a la vez el script de M13, `TerrainTileset` y esta tabla.

### 2.2 Sombra de hoja (`LEAF_SHADOW`, una por par de `LEAVES`)
Un tono más oscuro que la hoja oscura, siempre de la paleta (la del spike):

| `leaf` | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Hoja [oscura, clara] | `265c42` `3e8948` | `3e8948` `63c74d` | `124e89` `0099db` | `0099db` `2ce8f5` | `68386c` `b55088` | `b55088` `f6757a` | `a22633` `e43b44` | `be4a2f` `f77622` | `feae34` `fee761` | `8b9bb4` `ffffff` | `3a4466` `5a6988` | `733e39` `b86f50` |
| Sombra de hoja | `193c3e` | `265c42` | `262b44` | `124e89` | `3e2731` | `68386c` | `3e2731` | `733e39` | `d77643` | `5a6988` | `262b44` | `3e2731` |

El recoloreado es de **una sola pasada** (cada píxel se busca una vez en el mapa clave → color), así que un color de destino puede coincidir con otra clave (`leaf` 9 → `5a6988`) sin cadenas.

### 2.3 Colores de flor (`flower_colors(style)`)
- `[0]` = `fruit_color()[0]` (las flores del Bosque son las de su frutal).
- `[1]` y `[2]`: los dos primeros de la lista de preferencia `fee761, ffffff, f6757a, b55088, feae34, f77622, 0099db, e43b44` que sean distintos de `[0]`, distintos entre sí y con contraste suficiente sobre la hierba del Bosque (mismo criterio que `FRUIT_CONTRAST`). Determinista por estilo.
- **Excluido** el acento místico `2ce8f5`: la dirección de arte lo reserva para lo etéreo (mitahir, Luz, runas). El centro de las flores es `ffffff` fijo, por eso `ffffff` solo puede ser pétalo si `[0]` o `[1]` no lo son (si sale blanco, el centro pasa a `fee761`; regla de M13).

### 2.4 Sombra de nivel (hierba más clara en las mesetas altas)
El relieve se lee mejor si las mesetas altas tienen la hierba un tono más clara (ADR 0014 §3, tomado del isométrico). No es un dibujo: es una **segunda tabla de suelo** (`GROUNDS_HIGH`) para las casillas con `level >= 2`. Cada grupo con claves de hierba se recolorea dos veces por Bosque (normal y alto).

| `ground` | Normal [hierba, brizna, sombra] | Alto [hierba, brizna, sombra] |
|---|---|---|
| 0 (verde) | `3e8948` `63c74d` `265c42` | `63c74d` `3e8948` `3e8948` |
| 1 (verde oscuro) | `265c42` `3e8948` `193c3e` | `3e8948` `63c74d` `265c42` |
| 2 (arena) | `e4a672` `ead4aa` `c28569` | `ead4aa` `e4a672` `e4a672` |
| 3 (tierra) | `c28569` `e8b796` `b86f50` | `e8b796` `c28569` `c28569` |

- En el verde y en la arena no hay un tono más claro para la brizna: la brizna pasa a ser **más oscura** que la hierba (briznas en sombra sobre hierba al sol). Se valida en M13 con capturas; si no convence, el umbral sube a `level >= 3`.
- **Regla de las piezas mixtas**: cada pieza de relieve se recolorea con la tabla del **nivel de su casilla**. Las caras son casillas del nivel de abajo, así que el labio de hierba de una cara que baja de nivel 2 a 1 sale un tono más oscuro que la meseta: se acepta, se lee como el borde en sombra. La sombra al pie y la sombra este, con la del nivel de abajo.

### 2.5 Claves por grupo (atlas)
| Grupo (atlas) | Juegos de claves | Notas |
|---|---|---|
| `hierba` | Hierba (normal y alto) | |
| `relieve` | Hierba (normal y alto) | La roca usa los grises fijos `c0cbdc`, `8b9bb4`, `5a6988`, `3a4466` (como el risco de la 0.3). La escalera, `e4a672`/`b86f50`/`733e39` fijos; el camino de las rampas, `ead4aa` fijo |
| `cascada` | Hierba (normal) | Agua fija: `124e89`, `0099db`, `2ce8f5`, `ffffff`, igual que `tileset_agua.png` |
| `sombras` | Hierba (normal y alto) | Las variantes sobre sendero, camino y agua usan colores fijos |
| `decoracion` | Hierba, Árbol (sin fruto), Flor | Vegetal. Las setas usan colores fijos que no son claves |
| `piedras` | Hierba | Piedrecitas y grietas en grises fijos |
| `puente_ancho` | ninguno | Igual que `tileset_puente.png` |
| `arboles` (todos los sprites de árbol) | Hierba (normal) + Árbol (con fruto y sombra de hoja) | La sombra en el suelo dentro del sprite usa la clave de sombra de hierba |
| `rocas` | Hierba (normal) | Musgo y sombra en claves de hierba; roca en grises fijos |
| `madera` (tocones y troncos) | Hierba (normal) + Árbol (sin fruto) | Corteza = tronco; musgo = sombra de hoja; corte con anillos `e4a672`/`b86f50` fijos |
| `casas` | Claro | Como `tileset_villa.png`: barro `e8b796`/`c28569`, cañizo `d77643`/`b86f50`; piedra `c0cbdc`/`8b9bb4`, pizarra `8b9bb4`/`5a6988` |
| `nujio` | Hierba (normal) + Árbol (con sombra de hoja) | Acento `2ce8f5` fijo en las motas de Luz |

- **Estados del Bosque** (sano, enojado, corrupto, muerto): como en la 0.3 se tiñe lo vegetal (`hierba`, `arboles`, `decoracion`, `madera`, `nujio` y la hierba de `relieve` y `sombras`); la roca, las piedras, las casas, el agua y el puente no. El fuego sigue siendo el de `PlaceholderTileset` (3 fotogramas a 6 fps).
- **Roca del color del Bosque**: pregunta abierta desde la 0.3. Propuesta para M18 (no se decide aquí): suelos 2 y 3 con roca arenisca (`ead4aa`/`e4a672`/`c28569`/`b86f50`) en lugar de gris. Pide claves de roca nuevas.

## 3. Relieve
Niveles 0–3 sobre la celda gruesa de 4×4 (ADR 0014 §3). Todas las piezas son casillas de la capa de suelo (opacas) salvo las sombras (capa 2, con transparencia).

### 3.1 Caras de risco (hacia el sur)
- **2 filas por nivel** (32 px de alto por nivel). Una caída de `d` niveles mide `2d` filas: **labio**, `2d − 2` filas **intermedias** y **base**.
- **Labio** (fila de arriba): 3 px de hierba colgando del borde (`3e8948`, último píxel `265c42`), dentada en 1 px con un periodo de 4–7 px; después 1 px de contorno `181425`; después roca clara.
- **Lajas**: columnas verticales de 4 a 7 px (periodo de 32 px, es decir, de 2 casillas; anchos del spike `6, 5, 7, 4, 6, 4`). Borde izquierdo de cada laja en `c0cbdc` (arriba) o `8b9bb4` (abajo); borde derecho en `5a6988`/`3a4466`; grietas horizontales cortas de 1 px `3a4466` al azar (hash fijo).
- **Oscurecen hacia el pie**: labio en `c0cbdc`/`8b9bb4`, intermedias en `8b9bb4`/`5a6988`, base en `5a6988`/`3a4466`, últimos 2 px `262b44` y 1 px de contorno `181425` al pie. Las intermedias **no llevan hierba**.
- **Base**: el último píxel de la base es contorno; el pie se ensucia con 1–3 lajas caídas de 2×2 px. La hierba de abajo empieza en la casilla de debajo (sombra al pie, §3.6).
- **Columnas** (en el atlas, por cada fila de cara): extremo izquierdo, medio A, medio B, medio C, extremo derecho, suelto (1 casilla de ancho, para tramos que una escalera deja cortos).
- **Extremos redondeados**: en la casilla de extremo la cara se curva hacia atrás: la roca ocupa todo el ancho arriba y se retira 4 px en la base, con el contorno siguiendo la curva y hierba del nivel de abajo fuera. El extremo **enlaza con la pared lateral** (O o E) de la casilla de encima: en el borde de contacto la roca mide lo mismo que la pared (10 px), así casan.
- **Continuidad**: los medios A, B y C casan entre sí en cualquier orden (las lajas cortan siempre en x = 0 y x = 16 en el mismo punto del periodo). `world-gen-dev` alterna A/B/C por hash de la columna.

### 3.2 Bordes norte, este y oeste
Van en las casillas del borde de la meseta (nivel de arriba) y bloquean. Máscara con los bits de la 0.3: 1 = norte, 2 = este, 8 = oeste (el sur es la cara, nunca un borde). Columna del atlas = máscara; las máscaras sin uso, transparentes.
- **Norte**: labio de roca de 5 px (6 en algunos tramos) arriba de la casilla: 1 px contorno, 1 px `c0cbdc`, roca `8b9bb4` con juntas `5a6988`, 1 px contorno y 1 px de sombra de hierba sobre la meseta. Es el canto de la pared que no se ve.
- **Oeste**: pared lateral de **10 px** (11 en algunos tramos) en el lado oeste, **iluminada**: contorno, 2 px `c0cbdc`, roca `8b9bb4`/`5a6988` en franjas verticales, contorno hacia la meseta.
- **Este**: igual que el oeste pero reflejada y **en sombra**: 2 px `8b9bb4` en el canto, roca `5a6988`/`3a4466`, más la **sombra este** sobre el suelo bajo (§3.6).
- Más anchos el este y el oeste que el norte a propósito (tomado del isométrico): se leen como pared.
- **Continuidad**: profundidad fija en los dos extremos de cada lado (norte 5 px; este y oeste 10 px), variación de 1 px solo en medio. Una pared de varias casillas casa.

### 3.3 Esquinas
- **Exteriores norte** (NO, NE): las máscaras 9 (N+O) y 3 (N+E) dibujan la esquina **redondeada**: el labio norte gira hacia la pared con un radio de 3–4 px, no en ángulo recto.
- **Exteriores sur** (SO, SE): las resuelven el extremo de la cara (§3.1) más la casilla de borde de encima (máscara 8 o 2), cuya pared llega hasta abajo.
- **Interiores (cóncavas), primera pasada**: piezas de **unión** que cierran el hueco sin más: muesca diagonal de 5×6 px donde el borde norte se encuentra con una pared (NO y NE interior, como el spike) y remate de cara contra pared (la cara acaba recta contra la pared lateral de la meseta vecina, a izquierda o a derecha). Bastan para que no queden agujeros.
- **Opción pendiente del dueño: esquinas interiores y tramos diagonales.** El dueño dijo en la v2 que las terrazas rectas "se notan muy falsas" (ADR 0006). Las caras del Mundo 2.0 son rectas a propósito, como en Zelda, en tramos cortos (rejilla de 4) y con extremos redondeados. La alternativa es dibujar esquinas interiores redondeadas de verdad y tramos de cara en diagonal de 45° (que también piden lógica de `world-gen-dev`). **No se decide en esta spec**: es decisión del dueño, **bloquea M18** (no M13) y, si la elige, cuesta 1 PR de arte más. Las filas 8–11 de `tileset_relieve.png` quedan reservadas y vacías para ella.
- **Caídas de varios niveles en los lados**: los bordes este, oeste y norte usan la misma pieza aunque la diferencia sea de 2 o 3 niveles (el lateral no muestra la altura). Es un límite conocido; la opción pendiente podría tratarlo.

### 3.4 Escaleras y rampas
- **Escalera**: un sendero o camino que cruza una cara; **toda la columna de la cara** se vuelve escalera (ADR 0014 §3). Transitable. Peldaños de piedra de 4 px (4 por casilla, 8 por nivel): huella `e4a672`, tabica `b86f50`, junta `733e39`, con mejillas de roca de 3 px a los lados (izquierda iluminada, derecha en sombra) que continúan las lajas de la cara. Columnas izquierda, medio y derecha (sendero de 2 = izquierda + derecha; camino de 3 = las tres). Filas: arriba (con el labio a los lados), intermedia y abajo (el último peldaño casa con el sendero o camino de debajo).
- **Rampa**: un sendero o camino que cruza un borde (norte, este u oeste). Transitable. La pared baja hasta desaparecer en la casilla de la rampa y la tierra del sendero (`b86f50`, motas `e4a672`/`733e39`) o del camino (`ead4aa`, rodadas `e4a672`) lleva **marcas de pendiente** de 1 px perpendiculares a la marcha, cada 3 px, más juntas hacia abajo. Hierba de la meseta en los lados.
  - Rampa norte: columnas izquierda/medio/derecha, una fila.
  - Rampas oeste y este: filas arriba/medio/abajo, una columna (sendero = arriba + abajo).
  - Material: sendero y camino, cada uno con su juego.

### 3.5 Cascada (animada)
Donde un río cruza una cara, la cara es agua que cae. Bloquea.
- **4 fotogramas a 4 fps** (bucle de 1 s). Sutil: hilos verticales de `0099db` y `2ce8f5` de 1 px sobre `124e89`, separados de 3 a 6 px, que **bajan 4 px por fotograma** con un patrón de periodo 16 px (el bucle casa entre casillas). Sin parpadeos de color ni destellos.
- Piezas: columnas izquierda, medio y derecha (los lados llevan 3 px de mejilla de roca como la escalera) × filas labio (el agua se curva sobre el borde, 2 px `2ce8f5` y la hierba del labio a los lados), intermedia y base.
- **Espuma al pie**: una fila más, sobre la casilla de agua de debajo: espuma `ffffff`/`2ce8f5` de 3–5 px que se desplaza 1 px por fotograma (mismos 4 fotogramas). Va en la capa de suelo sustituyendo a la casilla de agua del pie.
- Si un río cruza un borde este, oeste o norte no hay pieza: `world-gen-dev` lo evita o pide una pieza de rápido.

### 3.6 Sombras (capa 2, fondo transparente)
- **Sombra al pie**: en la casilla de debajo de la base de una cara, una franja de 3–4 px arriba con el borde inferior dentado (periodo de 2 px). Variantes por suelo de abajo: hierba (clave `265c42`, 2 variantes), sendero (`733e39`), camino (`e4a672`) y agua (`124e89`).
- **Sombra este**: en la casilla de abajo al este de un borde este, franja vertical de 3 px a la izquierda. Mismas variantes por suelo.
- **Sombra de objeto**: franja de 2 px bajo los objetos que llenan su huella (casas, Nujio, árbol grande si llega al borde): piezas izquierda, medio, derecha y esquina sureste (1 px más larga hacia el este). Solo sobre hierba.
- Una casilla solo tiene una pieza en la capa 2: `world-gen-dev` no pone decoración en casillas con sombra (si hace falta, pedir otra capa a `engine-architect`).

### 3.7 Cueva en una cara (refugio)
- **2×2 casillas** dentro de una cara: la boca en arco, de 18–20 px de ancho y 16–18 px de alto, `181425` dentro con una franja de `262b44` en el borde superior interior, apoyada en la base. Alrededor, las lajas de la cara siguen sin corte; 1–2 rocas caídas junto a la boca.
- Dos versiones: **con labio** (cara de 1 nivel: la fila de arriba es la del labio) y **sin labio** (caras más altas: la fila de arriba es intermedia).
- Colisión de referencia (la decide `world-gen-dev`): fila de abajo pisable (la boca), fila de arriba bloquea.

## 4. Árboles (sprites del nodo con orden en Y)
Un solo tipo de árbol por Bosque, de su silueta (`shape`), salvo los Nuevos Bosques, que mezclan 2 o 3 siluetas (pendiente de la 0.3, no cambia aquí). Las 6 siluetas: copa redonda, conífera, palmera, cactus, espinoso y sauce.

- **Árbol 2×2** (32×32): **4 variantes por silueta** + volteo = 8 aspectos. Copa en los ~2/3 de arriba, tronco y raíces en el tercio de abajo, sombra elíptica en el suelo (clave `265c42`) bajo el tronco. Tres tonos de hoja (clara, oscura, sombra de hoja) en grumos de 3–6 px, nunca en ruido de 1 px. Cada variante cambia la silueta de la copa (no solo los brillos), la altura del tronco (±2 px) y las raíces.
  - **Extraño, no terrorífico**: la variante 3 de cada silueta tiene un nudo o dos huecos en el tronco o la copa que **casi** son una cara. Sutil: a 1× no debe leerse como cara a la primera.
  - Siluetas a 32 px: redonda (cúpula de 3 grumos), conífera (4 pisos escalonados), palmera (abanico de 6–7 hojas y tronco curvo anillado), cactus (tronco con 1–2 brazos y flor de color tronco), espinoso (copa con púas de 1–2 px en el contorno), sauce (cúpula con cortinas colgantes hasta la fila 26).
- **Árbol joven 1×1** (16×16): 2 variantes por silueta + volteo. Es la misma silueta, pequeña y con el tronco fino. Si bloquea lo decide `world-gen-dev` (propuesta: sí).
- **Árbol grande 3×3** (48×48): 1 por silueta + volteo. Hito: copa más ancha que alta, raíces que salen del borde de la huella, 1–3 motas de musgo (sombra de hoja). Se reconoce de lejos.
- **Árbol seco 2×2** (32×32): 1 por silueta + volteo. Ramas desnudas en color tronco y sombra de hoja; nada de hoja clara. Raro en un Bosque sano (no es el estado "muerto", que se tiñe).
- **Frutal 2×2**: las variantes 0 y 1 con **4–6 frutos de 2×2 px** (fruto y sombra) y rabillo de 1 px en tronco, siempre sobre píxeles de hoja (lo comprueba el script, como en la 0.3). En la palmera cuelgan bajo las hojas; en el cactus, sobre los brazos.
- **Frutal vaciado 2×2**: las mismas dos variantes solo con los rabillos.
- **Árbol hueco 2×2** (refugio): el árbol de la silueta con tronco ancho y una boca oscura en arco de 8×9 px en la base (en el cactus, un cactus ancho hueco). Se interactúa desde cualquier casilla vecina (`occupant[]`).

## 5. Otros objetos
- **Rocas 2×2** (32×32): 3 variantes, **sin volteo** (luz de lado completa). Bloques redondeados de 2–3 piezas, `c0cbdc` arriba a la izquierda, `8b9bb4`, `5a6988`, `3a4466` en la cara sur; musgo en claves de hierba en las grietas de arriba y sombra elíptica al pie. Van en el pedregal, la montaña y el círculo de piedras.
- **Rocas pequeñas 1×1**: 2 variantes, sin volteo. Raras y bloquean.
- **Tocones 1×1**: 2 variantes + volteo. Corte con 2 anillos (`e4a672`/`b86f50`), corteza en tronco, raíces cortas y musgo. Raros y bloquean.
- **Troncos caídos 2×1** (32×16): 2 variantes + volteo, horizontales, con la cara del corte a un lado y musgo encima. Versión vertical 1×2 (16×32): para M18, si `world-gen-dev` la pide.
- **Casas 4×3** (64×48): material barro y piedra (toda la villa igual, hash del chunk), **2 variantes** por material (posición del vano y de las ventanas), sin volteo. Vista 3/4: techo de 28–30 px (~60 %) arriba y fachada al sur de 18–20 px. Ventanas de 2×3 con alféizar; **sin puerta**: vano en arco abierto, `181425` dentro (glosario: sin puertas cerradas, ventanas pequeñas). Alero de 1 px que proyecta 1 px de sombra en la fachada. Sombra de objeto en la capa 2 (§3.6).
- **Puente de 3**: para el camino de 3 sobre el agua (el sendero de 2 usa solo izquierda + derecha). Tablones `e4a672`/`b86f50` con juntas `733e39`, pretil `3e2731` con postes cada 8 px, agua en sombra bajo los costados. Orientación norte-sur: columnas izquierda/medio/derecha × filas cabeza norte, tramo, cabeza sur (las cabezas casan con la orilla). Orientación este-oeste: la misma rotada 90° en M13; dibujada aparte en M18 para que la luz siga arriba a la izquierda.
- **Nujio**: el árbol madre del Bosque, de su silueta. **Huella 4×4** (64×64) y sprite de 64×80: la copa **sobresale 16 px** por encima de la huella (es lo más alto del Bosque y tapa a quien pase por detrás, a propósito). 1 por silueta + volteo. **2 fotogramas a 1 fps**: en el segundo, 3–5 motas de Luz (`2ce8f5`, el acento místico, y `ffffff`) cambian de sitio en la copa; nada más se mueve. Raíces que salen de la huella y suelo de claro alrededor (zona aplanada). Sustituye al Nujio procedural escalado (`PlaceholderTileset.nujio_texture`). Si en el juego hay Nujio de otros tamaños, se pide una pieza por tamaño.

## 6. Hierba y decoración

### 6.1 Hierba: 4 variantes
`world-gen-dev` las elige por **ruido de baja frecuencia** (manchas grandes), nunca por hash por casilla. Por eso cualquier variante tiene que casar con cualquier otra en los 4 lados: misma base, 1 px de base sin detalles en los bordes y detalles solo en el interior.
- A: rasa (base con 2–3 briznas).
- B: matas en V de 3–5 px (como la 0.3, sin flores: las flores pasan a la decoración).
- C: densa (más matas y más sombra de hierba).
- D: briznas claras sueltas.

La diferencia entre variantes es baja a propósito: las manchas se notan de lejos, el corte entre casillas no. El claro, el pedregal, el sendero, el camino, el agua y la plaza siguen con los PNG de la 0.3 en M13.

### 6.2 Decoración (no bloquea, capa 2, 1×1)
Piezas de 16×16 con fondo transparente y el dibujo apoyado en la mitad de abajo de la casilla (para que lo que está al norte no parezca flotar). Todas se voltean. 1 px de sombra de hierba al pie de cada mata o flor.

**Catálogo común** (23 piezas, `tileset_decoracion.png` y `tileset_piedras.png`):

| Familia | Piezas | Notas |
|---|---|---|
| Flores | **3 dibujos × 3 colores = 9**: ramillete (3–5 flores de 3 px), flores altas (2–3 tallos de 4–6 px), tapiz (6–9 florecillas de 1–2 px) | Color de flor 1, 2 o 3 (§2.3); centro `ffffff`; tallo en brizna |
| Matas | 3: baja, alta en V, con espiga | Claves de hierba. Forman el **borde de matas** alrededor de las manchas de flores (ADR 0014 §5.6) |
| Helechos | 2: abierto (5–7 frondas), joven (enrollado) | Hoja oscura y clara |
| Hojarasca | 2: hojas sueltas (4–6 de 2 px), montoncito | Hoja oscura, clara y sombra de hoja: las hojas caídas son las del Bosque |
| Setas | 2: seta grande sola, corro de 3–4 setitas | Fijos: sombrero `be4a2f` con motas `ffffff`, pie `e8b796`. Sin brillo: las setas de Luz (acento) serían etéreas y las decide `game-designer` |
| Raíces | 2: raíz que asoma, raíz en arco | Tronco y sombra de hoja |
| Piedrecitas | 3: trío, piedra plana, guijarros | En `tileset_piedras.png` (grises fijos) |

**Piezas propias por silueta** (2 cada una, en `tileset_decoracion.png` salvo que se indique):

| Silueta | Pieza 1 | Pieza 2 |
|---|---|---|
| Copa redonda | Bellotas o frutillos caídos (fruto) | Musgo en tapiz (sombra de hoja y hoja oscura) |
| Conífera | Piñas caídas (tronco) | Agujas en el suelo (hoja oscura) |
| Palmera | Hoja de palma caída (hoja clara y oscura) | Coco (fruto) |
| Cactus | Grieta seca (`tileset_piedras.png`) | Cardo bajo (hoja oscura, flor 1) |
| Espinoso | Zarza baja (hoja oscura y sombra de hoja) | Espinas caídas (tronco) |
| Sauce | Juncos (brizna y hierba) | Hilos colgantes caídos (hoja clara) |

**Qué piezas usa cada tipo de Bosque** (tipo = silueta; los Nuevos Bosques usan el catálogo común completo):

| Silueta | Flores | Matas | Helechos | Hojarasca | Setas | Raíces | Piedrecitas | Propias | **Total** |
|---|---|---|---|---|---|---|---|---|---|
| Copa redonda | 9 | 3 | 2 | 2 | 2 | 2 | 3 | 2 | **25** |
| Conífera | 9 | 3 | 2 | 2 | 2 | 2 | 3 | 2 | **25** |
| Palmera | 9 | 3 | 2 | 2 | 0 | 2 | 3 | 2 | **23** |
| Cactus | 9 | 3 | 0 | 0 | 0 | 2 | 3 | 2 | **19** |
| Espinoso | 9 | 3 | 0 | 2 | 2 | 2 | 3 | 2 | **23** |
| Sauce | 9 | 3 | 2 | 2 | 2 | 2 | 3 | 2 | **25** |

Todas pasan de 16. Con 3 colores de flor por Bosque, el volteo y los colores de hoja, salen cientos de aspectos. Las piezas propias son M18; en M13 el mínimo de 16 se cumple solo con el catálogo común (17 en el cactus).

## 7. Origen de los sprites (orden en Y)
- Todos los objetos del nodo con orden en Y (`y_sort_enabled`) son `Sprite2D` con `centered = false` y `offset = (−ancho / 2, −alto)`, en píxeles del sprite (incluido lo que sobresale).
- La posición del nodo es el **centro del borde sur de la huella**, en píxeles del mundo: `x = (col_noroeste + ancho_en_casillas / 2) · 16`, `y = (fila_noroeste + alto_en_casillas) · 16`.
- Así, quien tiene los pies más al sur que la base del objeto se dibuja delante y quien está al norte, detrás. El jugador, los NPC y los monstruos ya tienen el origen en los pies (ADR 0014 §2).
- La clave de los frutales y de los objetos en `occupant[]`/`objects` es la **esquina noroeste** de la huella (ADR 0014 §7); el origen de dibujo es otro (la base).
- Las piezas de las capas de suelo y de sombras son tiles normales (origen 0, sin orden en Y).

## 8. Atlas y nombres de archivo
Según [`docs/CONVENCIONES.md`](../../CONVENCIONES.md) §2 (`<tipo>_<nombre>[_<variante>].png`): `tileset_` para lo que va en un `TileMapLayer` y `sprite_` para los `Sprite2D`. Todo en `assets/tilesets/` (los `sprite_` de objetos de mundo también, junto a su tileset) y en Git LFS, con su `.import` (Nearest, sin mipmaps, sin compresión). Sin márgenes ni separación; casillas o fotogramas sin uso, transparentes. Los nombres no chocan con los de la 0.3, que conviven hasta M17.

| Archivo | Tamaño | Rejilla | Contenido |
|---|---|---|---|
| `tileset_hierba.png` | 64×16 | 4 × 1 de 16 | Variantes A, B, C, D |
| `tileset_relieve.png` | 256×192 | 16 × 12 de 16 | Fila 0 labio, 1 intermedia, 2 base: col 0 extremo izq., 1–3 medio A/B/C, 4 extremo der., 5 suelto; cols 6–8 escalera izq./medio/der.; cols 9–10 (filas 0–1) cueva con labio; cols 11–12 (filas 0–1) cueva sin labio. Fila 3: bordes, columna = máscara (1, 2, 3, 8, 9, 10, 11). Fila 4: col 0 unión interior NO, 1 NE, 2 remate de cara contra pared a la izquierda, 3 a la derecha. Fila 5: rampa norte, cols 0–2 sendero izq./medio/der., 3–5 camino. Filas 5–7 (arriba/medio/abajo): col 6 rampa oeste sendero, 7 oeste camino, 8 este sendero, 9 este camino. Filas 8–11: reservadas para la opción pendiente (§3.3) |
| `tileset_cascada.png` | 192×64 | 12 × 4 de 16 | Columnas = pieza × fotograma (cols 0–3 izq., 4–7 medio, 8–11 der.; 4 fotogramas seguidos, como pide `TileSetAtlasSource` para animar). Filas: labio, intermedia, base, espuma al pie |
| `tileset_sombras.png` | 128×48 | 8 × 3 de 16 | Fila 0 sombra al pie, fila 1 sombra este: cols 0–1 hierba A/B, 2 sendero, 3 camino, 4 agua. Fila 2: sombra de objeto izq., medio, der., esquina SE |
| `tileset_decoracion.png` | 256×48 | 16 × 3 de 16 | Fila 0: flores (cols 0–2 ramillete en color 1/2/3, 3–5 flores altas, 6–8 tapiz), 9–11 matas, 12–13 helechos, 14–15 hojarasca. Fila 1: 0–1 setas, 2–3 raíces, 4–14 propias por silueta (2 por silueta en el orden de `Shape`, salvo la grieta del cactus), 15 libre. Fila 2: libre (crecimiento) |
| `tileset_piedras.png` | 64×16 | 4 × 1 de 16 | Trío, piedra plana, guijarros, grieta seca (cactus) |
| `tileset_puente_ancho.png` | 96×48 | 6 × 3 de 16 | Cols 0–2 norte-sur (izq./medio/der. × cabeza norte, tramo, cabeza sur); cols 3–5 este-oeste (cabeza oeste, tramo, cabeza este × arriba/medio/abajo) |
| `sprite_arboles.png` | 320×192 | 10 × 6 de 32 | Fila = silueta (orden de `PlaceholderTileset.Shape`). Cols 0–3 variantes, 4–5 frutal con fruto (de las variantes 0 y 1), 6–7 frutal vaciado, 8 hueco, 9 seco |
| `sprite_arbol_joven.png` | 32×96 | 2 × 6 de 16 | Fila = silueta, col = variante |
| `sprite_arbol_grande.png` | 48×288 | 1 × 6 de 48 | Fila = silueta |
| `sprite_rocas.png` | 96×32 | 3 × 1 de 32 | Variantes 0–2 |
| `sprite_rocas_pequenas.png` | 32×16 | 2 × 1 de 16 | Variantes 0–1 |
| `sprite_madera.png` | 96×16 | — | x 0–31: tocones (2 de 16×16); x 32–95: troncos caídos (2 de 32×16) |
| `sprite_casas.png` | 128×96 | 2 × 2 de 64×48 | Fila = material (0 barro, 1 piedra), col = variante |
| `sprite_nujio.png` | 128×480 | 2 × 6 de 64×80 | Fila = silueta, col = fotograma |

El script de M13 es `tools/art/make_world2.py` (o una ampliación de `make_tiles.py`; lo decide M13), con `--preview <carpeta>` como los demás.

## 9. Tabla de piezas
Prioridad: **M13** = tiene que estar en la primera pasada por script (la usa el generador de M6–M8 o el juego en M17); **M18** = puede esperar al arte final. Todo lo de M13 se redibuja en M18. "Sobresale" = píxeles del sprite por encima de la huella.

| Id | Pieza | Tamaño (casillas) | Sobresale | Variantes | Volteo | Fotogramas | Atlas | Prioridad |
|---|---|---|---|---|---|---|---|---|
| `grass` | Hierba | 1×1 | — | 4 | no | 1 | `tileset_hierba` | M13 |
| `face_lip` | Cara, labio | 1×1 | — | 6 columnas | no | 1 | `tileset_relieve` | M13 |
| `face_mid` | Cara, intermedia | 1×1 | — | 6 columnas | no | 1 | `tileset_relieve` | M13 |
| `face_base` | Cara, base | 1×1 | — | 6 columnas | no | 1 | `tileset_relieve` | M13 |
| `border` | Borde N/E/O (máscara) | 1×1 | — | 7 máscaras | no | 1 | `tileset_relieve` | M13 |
| `corner_outer_n` | Esquina exterior NO/NE (en `border` 9 y 3) | 1×1 | — | 2 | no | 1 | `tileset_relieve` | M13 |
| `corner_inner_join` | Unión interior NO/NE | 1×1 | — | 2 | no | 1 | `tileset_relieve` | M13 |
| `face_wall_join` | Remate de cara contra pared | 1×1 | — | 2 | no | 1 | `tileset_relieve` | M13 |
| `corner_inner_round`, `face_diagonal` | Esquinas interiores y tramos diagonales | — | — | — | — | — | `tileset_relieve` filas 8–11 | **Pendiente del dueño** (bloquea M18) |
| `stairs` | Escalera | 1×1 | — | 3 columnas × 3 filas | no | 1 | `tileset_relieve` | M13 |
| `ramp_n` | Rampa norte | 1×1 | — | 3 columnas × 2 materiales | no | 1 | `tileset_relieve` | M13 |
| `ramp_w`, `ramp_e` | Rampa oeste y este | 1×1 | — | 3 filas × 2 materiales | no | 1 | `tileset_relieve` | M13 |
| `cave` | Cueva en cara | 2×2 | — | 2 (con y sin labio) | no | 1 | `tileset_relieve` | M13 |
| `waterfall` | Cascada | 1×1 | — | 3 columnas × 3 filas | no | 4 a 4 fps | `tileset_cascada` | M13 |
| `waterfall_foam` | Espuma al pie de la cascada | 1×1 | — | 3 columnas | no | 4 a 4 fps | `tileset_cascada` | M13 |
| `shadow_foot` | Sombra al pie de cara | 1×1 | — | 5 (por suelo) | no | 1 | `tileset_sombras` | M13 |
| `shadow_east` | Sombra este | 1×1 | — | 5 (por suelo) | no | 1 | `tileset_sombras` | M13 |
| `shadow_object` | Sombra de objeto | 1×1 | — | 4 | no | 1 | `tileset_sombras` | M13 |
| `level_light` | Sombra de nivel (tabla `GROUNDS_HIGH`) | — | — | — | — | — | (recoloreado) | M13 |
| `tree` | Árbol | 2×2 | 0 | 4 × 6 siluetas | sí | 1 | `sprite_arboles` | M13 |
| `tree_fruit` | Frutal con fruto | 2×2 | 0 | 2 × 6 | sí | 1 | `sprite_arboles` | M13 |
| `tree_fruit_empty` | Frutal vaciado | 2×2 | 0 | 2 × 6 | sí | 1 | `sprite_arboles` | M13 |
| `tree_hollow` | Árbol hueco (refugio) | 2×2 | 0 | 1 × 6 | sí | 1 | `sprite_arboles` | M13 |
| `tree_dead` | Árbol seco | 2×2 | 0 | 1 × 6 | sí | 1 | `sprite_arboles` | M13 |
| `tree_young` | Árbol joven | 1×1 | 0 | 2 × 6 | sí | 1 | `sprite_arbol_joven` | M13 |
| `tree_big` | Árbol grande (hito) | 3×3 | 0 | 1 × 6 | sí | 1 | `sprite_arbol_grande` | M13 |
| `rock` | Roca | 2×2 | 0 | 3 | no | 1 | `sprite_rocas` | M13 |
| `rock_small` | Roca pequeña | 1×1 | 0 | 2 | no | 1 | `sprite_rocas_pequenas` | M13 |
| `stump` | Tocón | 1×1 | 0 | 2 | sí | 1 | `sprite_madera` | M13 |
| `log` | Tronco caído horizontal | 2×1 | 0 | 2 | sí | 1 | `sprite_madera` | M13 |
| `log_vertical` | Tronco caído vertical | 1×2 | 0 | 2 | sí | 1 | (se añade a `sprite_madera`) | M18, si se pide |
| `house` | Casa | 4×3 | 0 | 2 × 2 materiales | no | 1 | `sprite_casas` | M13 |
| `bridge_wide` | Puente de 3 (y de 2) | 1×1 por pieza | — | 3 × 3 × 2 orientaciones | no | 1 | `tileset_puente_ancho` | M13 (este-oeste rotado); M18 (este-oeste dibujado) |
| `nujio` | Nujio | 4×4 | 16 px | 1 × 6 | sí | 2 a 1 fps | `sprite_nujio` | M13 (1 fotograma); M18 (2 fotogramas) |
| `decor_flowers` | Flores (3 dibujos × 3 colores) | 1×1 | — | 9 | sí | 1 | `tileset_decoracion` | M13 |
| `decor_tuft` | Matas | 1×1 | — | 3 | sí | 1 | `tileset_decoracion` | M13 |
| `decor_fern` | Helechos | 1×1 | — | 2 | sí | 1 | `tileset_decoracion` | M13 |
| `decor_leaves` | Hojarasca | 1×1 | — | 2 | sí | 1 | `tileset_decoracion` | M13 |
| `decor_mushroom` | Setas | 1×1 | — | 2 | sí | 1 | `tileset_decoracion` | M13 |
| `decor_root` | Raíces | 1×1 | — | 2 | sí | 1 | `tileset_decoracion` | M13 |
| `decor_pebbles` | Piedrecitas | 1×1 | — | 3 | sí | 1 | `tileset_piedras` | M13 |
| `decor_shape_*` | Propias por silueta | 1×1 | — | 2 × 6 | sí | 1 | `tileset_decoracion`, `tileset_piedras` | M18 |
| `rock_tint` | Roca del color del suelo (propuesta) | — | — | — | — | — | (claves nuevas) | Pendiente del dueño (M18) |

## Preguntas abiertas
- **Dueño**: esquinas interiores y tramos diagonales (§3.3; bloquea M18). Roca del color del Bosque (§2.5). Umbral de la sombra de nivel (`level >= 2` o `>= 3`), tras ver las capturas de M13.
- **`world-gen-dev`**: si el árbol joven bloquea; ríos que cruzan bordes laterales (§3.5); tamaños de Nujio distintos de 4×4; no poner decoración en casillas con sombra.
- **`engine-architect`**: máscara del shader de balanceo, si hace falta (§1); dos atlas por Bosque (normal y alto) para los grupos con hierba (§2.4).
- **`game-designer`**: setas de Luz u otra decoración con efecto o con el acento místico (§6.2).
