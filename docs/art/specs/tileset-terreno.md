# Spec: tileset de terreno (0.3)

> Dueño: `pixel-artist`. Estado: **primera pasada de arte**, generada por script. Sustituye a los tiles dibujados por código (`PlaceholderTileset`). El artista humano puede redibujar cualquier PNG si respeta esta spec: tamaño, orden de casillas y colores clave.
> Fuentes: `docs/art/style-guide.md`, `docs/glosario_nuevos_bosques.md` (Bosque, Nujio, Villa), ADR 0006 (estilos por Bosque), ADR 0008 (32 colores, combinaciones sin límite), preguntas abiertas #84 y #86.

## Cómo se generan
- `python tools/art/make_tiles.py` escribe `assets/tilesets/tileset_<grupo>.png`. `--preview <carpeta>` deja vistas x6 sobre fondo magenta.
- Los dibujos fijos (árboles, letrero, cueva, casas, puente) son matrices de caracteres, como en `make_sprites.py`. Las texturas que se repiten (hierba, sendero, camino, agua, risco, plaza) se componen con reglas deterministas (hash fijo): mismas entradas, mismos píxeles.
- El script falla si algún color se sale de la paleta, si hay alfa parcial o si un fruto cae fuera de la copa.
- Casillas de 16×16, sin márgenes ni separación entre casillas. Casillas sin uso: transparentes.
- En Godot: importación por defecto del proyecto (sin compresión, filtro Nearest, sin mipmaps). Los PNG van en Git LFS y los `.import` se commitean.

## Colores clave (se recolorean por Bosque)
Cada Bosque pinta el terreno con sus colores (`BosqueMap.styles`: `leaf`, `trunk`, `ground`, `shape`). `TerrainTileset` cambia, **solo en los grupos indicados**, estos colores del PNG por los del Bosque. El resto de colores del PNG son fijos.

| Juego de claves | Color en el PNG | Se cambia por | Grupos |
|---|---|---|---|
| Hierba | `3e8948` | `GROUNDS[ground][0]` hierba | suelo, sendero, camino, risco |
| Hierba | `63c74d` | `GROUNDS[ground][1]` brizna clara | suelo, sendero, camino, risco |
| Hierba | `265c42` | `GROUNDS[ground][4]` sombra de la hierba | suelo, sendero, camino, risco |
| Claro | `ead4aa` | `GROUNDS[ground][2]` claro | suelo, plaza, villa |
| Claro | `e4a672` | `GROUNDS[ground][3]` mota del claro | suelo, plaza, villa |
| Árbol | `c0cbdc` | `LEAVES[leaf][1]` hoja clara | árboles |
| Árbol | `8b9bb4` | `LEAVES[leaf][0]` hoja oscura | árboles |
| Árbol | `5a6988` | `TRUNKS[trunk]` tronco | árboles |
| Árbol | `e43b44` | `fruit_color()[0]` fruto | árboles |
| Árbol | `a22633` | `fruit_color()[1]` sombra del fruto | árboles |

- Las claves de árbol son las mismas que las de los monstruos (`UnicoArt.KEY_*`): un Bosque pinta igual sus árboles y sus Únicos.
- Dentro de un grupo, ningún píxel fijo puede usar una de sus claves. Fuera de su grupo, esos colores son normales (por eso el risco puede usar los grises y la villa el claro).
- `GROUNDS` gana un quinto color por suelo (sombra de la hierba): `265c42`, `193c3e`, `c28569`, `b86f50`.
- Si el artista necesita otra clave, se cambian a la vez `make_tiles.py`, `TerrainTileset.GROUP_KEYS` y esta tabla.

## Grupos y casillas

| Archivo | Tamaño | Columnas × filas | Contenido |
|---|---|---|---|
| `tileset_suelo.png` | 256×64 | 16 × 4 | Fila 0: hierba, 4 variantes (la 3 con dos florecillas). Fila 1: pedregal (hierba con 1-3 piedras), 4 variantes. Filas 2-3: claro, 16 máscaras × 2 variantes |
| `tileset_sendero.png` | 256×32 | 16 × 2 | Sendero (`PATH`): 16 máscaras × 2 variantes |
| `tileset_camino.png` | 256×32 | 16 × 2 | Camino principal (`ROAD`): 16 máscaras × 2 variantes |
| `tileset_agua.png` | 256×96 | 16 × 6 | Fila = tipo × 2 + fotograma. Tipos: río estrecho, río navegable, vado. Columna = máscara de orillas |
| `tileset_puente.png` | 32×32 | 2 × 2 | Columna 0: paso norte-sur; 1: paso este-oeste (la misma casilla girada 90°). Fila: variante |
| `tileset_risco.png` | 256×48 | 16 × 3 | Filas 0-1: risco, 16 máscaras × 2 variantes. Fila 2, columna 0: cueva (fondo transparente) |
| `tileset_plaza.png` | 256×32 | 16 × 2 | Plaza de losas: 16 máscaras × 2 variantes |
| `tileset_villa.png` | 256×32 | 16 × 2 | Fila = material (0 barro, 1 piedra). Columnas 0-7: techo; 8-11: fachada con ventanitas; 12-15: fachada con vano |
| `tileset_letrero.png` | 128×16 | 8 × 1 | Piedra con flecha tallada; columna = dirección (0 este y sentido horario). Fondo transparente |
| `tileset_arboles.png` | 144×96 | 9 × 6 | Fila = forma (copa redonda, conífera, palmera, cactus, espinoso, sauce). Columnas 0-3: árbol (2-3 son 0-1 reflejados); 4-5: frutal con fruto; 6-7: frutal vaciado (solo rabillos); 8: árbol hueco (refugio). Fondo transparente |

### Máscaras de borde
Bits del lado cuyo vecino es "de fuera": 1 = norte, 2 = este, 4 = sur, 8 = oeste (`PlaceholderTileset.EDGE_*`). Columna del PNG = máscara.
- **Sendero, camino y claro**: borde donde el vecino es hierba, árbol, frutal, pedregal o risco. La hierba invade 1-3 px con un labio de brizna clara. En el sendero, la hierba deja sombra sobre la tierra. En el camino hay un bordillo de piedrecitas y rodadas en el sentido de la marcha (solo si la casilla tiene bordes a un lado o a los dos lados opuestos).
- **Plaza**: borde donde el vecino no es plaza ni Nujio: bordillo oscuro y tierra del claro.
- **Agua**: orilla donde el vecino no es agua, vado ni puente: tierra húmeda de 1-3 px, línea del agua oscura y espuma intermitente.
- **Risco**: borde donde el vecino no es risco (ver más abajo).
- **Regla de continuidad**: la profundidad del borde vale lo mismo (1 px; 2 en orillas y riscos) en los dos extremos de cada lado, así dos casillas vecinas con el mismo borde casan. En medio varía (1-3 px) para que no se vea recto.
- Fuera del chunk se supone la misma casilla: no se dibuja borde en el límite del chunk.
- **Sin transiciones entre Bosques**: cada Bosque tiene su atlas; el cambio de suelo entre dos Bosques es un corte recto en el borde del chunk. Es la frontera real del mundo (glosario: "sus límites son las únicas fronteras reales") y se deja visible a propósito.

### Variantes (fila del atlas de Godot)
`PlaceholderTileset.variant_for` decide la fila del atlas de cada casilla; `TerrainTileset.paint` la traduce a la casilla del PNG.

| Casilla | Fila del atlas |
|---|---|
| Hierba, pedregal, árbol | 0-3 por hash de la casilla del mundo |
| Claro, sendero, camino, plaza, risco | máscara + 16 × (0 o 1) |
| Ríos y vado | máscara de orillas (el fotograma va en la columna `tile + Tile.size()`) |
| Puente | orientación (0 norte-sur, 1 este-oeste) + 2 × (0 o 1) |
| Edificio | material × 16 + techo (0-7: 1 norte, 2 este, 4 oeste) o fachada (8 + 1 este + 2 oeste; +4 si lleva el vano) |
| Letrero | dirección + 8 × fondo (0 camino, 1 sendero, 2 hierba) |
| Refugio | 0 árbol hueco, 1 cueva (si toca roca) |
| Frutal | 0-1 con fruto, 2-3 vaciado (`FRUIT_EMPTY_VARIANT`) |
| Nujio | 0 (claro sin borde, bajo el sprite del Nujio) |

El atlas tiene 32 filas y `2 × Tile.size()` columnas: la segunda mitad guarda el segundo fotograma del agua.

## Casillas una a una
- **Hierba**: base con matas en V, sombra al pie y alguna brizna; una variante con dos florecillas (`fee761`, `ffffff`). Las matas se repiten en mosaico sin costura.
- **Claro**: tierra clara con motas; la variante 1 tiene florecillas amarillas.
- **Pedregal**: hierba con 1-3 piedras (luz arriba a la izquierda, sombra al pie en la sombra de la hierba).
- **Sendero**: tierra marrón (`b86f50`) con motas claras y oscuras.
- **Camino principal**: tierra apisonada clara (`ead4aa`, fijo en este grupo), rodadas y bordillo de piedras: se distingue del sendero.
- **Agua**: río estrecho claro (`0099db`/`2ce8f5`), río navegable profundo (`124e89`/`0099db`), vado = río estrecho con una hilera de piedras planas con espuma. **2 fotogramas a 2 fps**: las crestas se mueven 2 px y la espuma parpadea.
- **Puente**: tablones (`e4a672`/`b86f50`, juntas `733e39`), pretil `3e2731` con postes cada 8 px y agua en sombra a los lados.
- **Plaza**: losas claras irregulares con juntas, algún brillo blanco.
- **Edificios**: vista 3/4 (techo en la fila de arriba, fachada al sur en la de abajo). Barro: muro de adobe `e8b796`/`c28569` y techo de cañizo `d77643`/`b86f50`. Piedra: mampostería `c0cbdc`/`8b9bb4` y losas de pizarra `8b9bb4`/`5a6988`. Ventanas pequeñas de 2×3 con alféizar; **ningún edificio tiene puerta**: la casilla central de la fachada (la izquierda si mide 2) lleva un vano en arco abierto (glosario: "sin puertas cerradas, ventanas pequeñas"). Toda la villa usa el mismo material (hash del chunk).
- **Letrero**: piedra redondeada de 8×12 px con una flecha de 5×5 tallada (surco oscuro con luz abajo a la derecha). 8 direcciones: este y sureste dibujadas; el resto, giros de 90°. Se pinta sobre camino, sendero o hierba según dónde esté.
- **Refugio**: árbol hueco (la copa de la forma del Bosque sobre un tronco ancho con una boca oscura; en cactus, un cactus ancho hueco) o cueva (roca redondeada con boca negra en arco).
- **Árboles**: ver más abajo.

## Riscos (#84, provisional)
El dueño dijo que las paredes de la v2 "se notan muy falsas". Propuesta de esta pasada:
- El risco es un **afloramiento**, no un muro: la superficie de arriba es roca fracturada en bloques (celdas irregulares con luz arriba a la izquierda y grietas oscuras), con alguna brizna en las grietas.
- Al norte, oeste y este, la roca acaba en un borde **irregular** con contorno oscuro sobre la hierba (luz en el borde norte y oeste, sombra en el este).
- Solo al **sur** se ve la cara: corta (5-8 px), con el labio dentado, lajas verticales que se oscurecen hacia el pie, base con contorno y una franja de sombra sobre la hierba. Se lee como un escalón del terreno visto desde arriba, no como una pared de ladrillo.
- No hay rampas ni escalones transitables: los riscos siguen bloqueando (ADR 0006). Si el dueño quiere rampas, hace falta una casilla nueva (world-gen-dev).
- Pendiente de opinión del dueño: altura de la cara, si quiere esquinas interiores (ahora hay una pequeña muesca donde el borde gira), y si la roca de arriba debe tomar algo del color del Bosque.

## Árboles (#86, provisional)
- **Un solo tipo de árbol por Bosque** (glosario: en un Bosque con Nujio la flora es hija de su Nujio). La forma (`shape`) y los colores (`leaf`, `trunk`) vienen de `BosqueMap.styles`.
- **6 siluetas** de 16×16, dos dibujos cada una más sus reflejos (4 variantes): copa redonda, conífera (tres pisos), palmera (hojas en abanico y tronco curvo), cactus (tronco con brazos y flor de color tronco), espinoso (copa con púas) y sauce (cúpula con ramas colgantes). Luz arriba a la izquierda, contorno `181425` de 1 px.
- **Paleta por Bosque**: 3 colores propios (hoja oscura, hoja clara y tronco) más el fruto, elegidos de las tablas `LEAVES` (12 pares) y `TRUNKS` (8), siempre dentro de los 32. Combinaciones: 6 × 12 × 8 × 4 suelos = 2304, sin contar los frutos.
- **Frutal**: el árbol del Bosque con 2-4 frutos de 2×2 (color + sombra) y rabillo; vaciado: solo los rabillos. En la palmera los frutos cuelgan bajo las hojas (cocos).
- Las siluetas son solo visuales; si alguna tiene efecto de juego (por ejemplo, espinosos que dañan) lo decide game-designer.
- Pendiente: cómo se ve un Nuevo Bosque (sin Nujio, "más parecido a los de nuestro mundo"): propuesta, mezclar 2-3 siluetas en verdes y marrones naturales en un mismo Bosque. No se implementa en esta pasada.

## Lo que sigue siendo procedural
- **Nujio grande** (`PlaceholderTileset.nujio_texture`): la silueta del Bosque escalada por código a N×N casillas. Pide un dibujo propio por forma y tamaño (o una plantilla de 48×48 que se amplíe por partes); queda para otra pasada.
- **Respaldo**: si falta el PNG de un grupo, sus casillas se dibujan con el placeholder original (`PlaceholderTileset.paint_tile`, con la variante antigua de `legacy_variant`). El juego nunca se queda sin terreno.

## Cuando llegue el arte final
Validar contra esta spec: tamaño de cada PNG, orden de casillas, solo colores de la paleta, alfa 0 o 255, claves solo donde tocan. Los tests de `tests/unit/world/test_terrain_tileset.gd` lo comprueban.
