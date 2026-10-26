class_name ChunkBuilder
extends RefCounted
## Pasada de chunk del Mundo 2.0 (ADR 0014 §5): convierte un chunk del RegionPlan en un
## WorldChunk nuevo. Hace los 7 pasos: suelo base y pedregal, relieve, puntos de interés, red de
## senderos y formas grandes (M6 y M7); decoración variada, letreros, refugio, frutales y trazado
## de la villa (M8).
##
## Relieve (ADR 0014 §3, spec de arte docs/art/specs/mundo-2.md §3):
## - `level[]` = nivel de la celda gruesa (0..3; la cumbre cuenta como 3 y además bloquea entera).
## - Caras hacia el sur: 2 filas por nivel de caída, en las casillas de ARRIBA del nivel de abajo
##   (una caída de 3 niveles ocupa 6 filas, así que sigue en la celda gruesa siguiente).
## - Bordes norte, este y oeste en las casillas del borde de la meseta (nivel de arriba), con la
##   máscara de la spec (1 = norte, 2 = este, 8 = oeste).
## - Cascada: cara cuya celda gruesa y la de la meseta de encima tienen agua. Bloquea.
## - Escaleras y rampas: donde una puerta o un sendero cruza una cara o un borde.
## Por construcción, dos casillas transitables de distinto nivel no son vecinas ortogonales salvo
## por una escalera o una rampa (lo verifica tests/unit/world/test_relief.gd).
##
## Lo que cambia el relieve (Nujio aplanado, colina +1 nivel) solo toca celdas gruesas del
## "interior seguro" (SAFE_*), las que ningún chunk vecino lee en su margen: dos chunks vecinos
## nunca se contradicen.
##
## Red de senderos: nodos = puertas + puntos de interés + ancla (villa o Nujio; si no, el primer
## punto de interés; si no, la primera puerta). Prim sobre la distancia en celdas gruesas (las
## puertas de camino se unen entre sí antes que nada); cada arista se traza con AStarGrid2D sobre la
## rejilla gruesa de 20×20 (agua, caras, casas y Nujio cuestan; lo trazado abarata). Cada paso grueso
## son 4 casillas en línea recta. Después, un Dijkstra por casillas repara lo que falte
## (escaleras, rampas y puentes) para que todo nodo se alcance desde el hub.
##
## Capas de dibujo (codificación completa en docs/design/world/generation.md, "Codificación para
## el dibujo"):
## - `variant` de una casilla con risco: la pieza del risco (ver VARIANT_*). En hierba sin risco:
##   la variante de hierba 0..3 (A..D), por ruido de baja frecuencia. En el resto, 0.
## - `decor` (capa 2, una pieza por casilla, spec §3.6): 1 y 2 sombras (Decor); desde
##   DECOR_PIECE_BASE, una pieza de decoración: DECOR_PIECE_BASE + DecorPiece. El volteo de la
##   decoración lo decide el dibujo (hash de la casilla), no va en los datos.
## - `objects[].variant`, por tipo: ver OBJECT_VARIANTS en generation.md (árbol: variante | volteo
##   << 2; frutal: variante 0-1 | volteo << 1; joven, tocón y tronco: variante 0-1 | volteo << 1;
##   seco, grande, hueco y Nujio: volteo; casa: material * 2 + variante; roca 2×2: 0..2; roca 1×1: 0..1).
##
## Apto para hilos: solo lee el RegionPlan (inmutable), crea su propio FastNoiseLite,
## RandomNumberGenerator, AStarGrid2D y arreglos de trabajo, no usa randi() ni GameState y no toca
## el árbol de escena. El resultado depende solo de (plan, coord): da igual el orden o el hilo.

## Piezas de sombra de la capa 2 (`WorldChunk.decor` < DECOR_PIECE_BASE). La sombra de objeto
## (casas y Nujio) la deduce el dibujo de `objects`; la decoración no se pone en esas casillas.
enum Decor { NONE, SHADOW_FOOT, SHADOW_EAST }
## Piezas de decoración (no bloquean; spec §6.2), en el orden del catálogo común de la spec: 0-15
## fila 0 de tileset_decoracion.png (columna = valor), 16-19 su fila 1 (columna = valor - 16),
## 20-23 tileset_piedras.png (columna = valor - 20; la 23 es la grieta seca del cactus). Después:
## SHAPE_1 y SHAPE_2, las dos piezas propias de la silueta del Bosque (M18), y HUERTO, surcos del
## huerto de la villa (pieza nueva, aún sin arte). Se amplía añadiendo valores al final.
enum DecorPiece {
	FLOWER_BUNCH_1, FLOWER_BUNCH_2, FLOWER_BUNCH_3, FLOWER_TALL_1, FLOWER_TALL_2, FLOWER_TALL_3,
	FLOWER_CARPET_1, FLOWER_CARPET_2, FLOWER_CARPET_3, TUFT_LOW, TUFT_V, TUFT_SPIKE, FERN_OPEN,
	FERN_YOUNG, LEAVES_LOOSE, LEAVES_PILE, MUSHROOM_BIG, MUSHROOM_RING, ROOT_PEEK, ROOT_ARCH,
	PEBBLES_TRIO, PEBBLE_FLAT, PEBBLES_GRAVEL, CRACK, SHAPE_1, SHAPE_2, HUERTO,
}
## Primer valor de `decor` que es una pieza de decoración (los anteriores son sombras).
const DECOR_PIECE_BASE: int = 3
## Ancla del chunk.
enum Anchor { NONE, VILLA, NUJIO }

## Versión de la salida del ChunkBuilder: súbela con cualquier cambio que altere los bytes de un
## chunk. WorldCache la combina con RegionPlan.GENERATOR_VERSION y WorldChunk.FORMAT_VERSION
## (combined_generator_version), así que invalida la caché. Cabe en 16 bits.
const VERSION: int = 3

const SIZE: int = WorldCoords.CHUNK
const LAST: int = SIZE - 1
const MACRO: int = WorldCoords.MACRO
const MACROS: int = WorldCoords.MACROS_PER_CHUNK
## Filas de cara por nivel de caída (32 px por nivel).
const FACE_ROWS_PER_LEVEL: int = 2

## Máscara de borde (spec §3.2, bits de la 0.3). La cumbre usa EDGE_PEAK (máscara sin uso).
const EDGE_N: int = 1
const EDGE_E: int = 2
const EDGE_W: int = 8
const EDGE_SIDES: int = EDGE_E | EDGE_W
const EDGE_PEAK: int = 15

## `variant` de las caras, cascadas y escaleras: fila | (columna << VARIANT_COLUMN_SHIFT).
const VARIANT_COLUMN_SHIFT: int = 2
const ROW_LIP: int = 0
const ROW_MIDDLE: int = 1
const ROW_BASE: int = 2
## Columnas de una cara (spec §3.1): extremos, tres medios que alternan por hash y suelto.
const FACE_END_LEFT: int = 0
const FACE_MIDDLE_A: int = 1
const FACE_END_RIGHT: int = 4
const FACE_SINGLE: int = 5
const FACE_MIDDLES: int = 3
## Columnas de escaleras y cascadas (spec §3.4 y §3.5).
const COLUMN_LEFT: int = 0
const COLUMN_MIDDLE: int = 1
const COLUMN_RIGHT: int = 2
## `variant` de bordes y rampas: la máscara (EDGE_*).

## Parámetros de suelo por defecto; la región los cambia con su bloque "chunk_ground".
## rocky_by_level: umbral del ruido de pedregal por nivel (por encima, pedregal; ≥ 1, nunca).
const DEFAULT_GROUND: Dictionary = {
	"rocky_frequency": 0.045,
	"rocky_by_level": [1.0, 0.6, 0.3, -0.05],
}
## Suelo de cada valor de RegionAuthoring.Water.
const WATER_GROUND: Array[int] = [
	WorldChunk.Ground.GRASS, WorldChunk.Ground.RIVER_NAVIGABLE, WorldChunk.Ground.RIVER_NARROW,
	WorldChunk.Ground.LAKE, WorldChunk.Ground.SEA, WorldChunk.Ground.FORD,
]
## Riscos que se pisan (bit = valor de WorldChunk.Cliff).
const CLIFF_OPEN: int = (1 << WorldChunk.Cliff.NONE) | (1 << WorldChunk.Cliff.STAIRS) \
		| (1 << WorldChunk.Cliff.RAMP)
## Suelos naturales que un sendero sustituye y sobre los que crecen árboles, rocas y casas.
const NATURAL_GROUND: int = (1 << WorldChunk.Ground.GRASS) | (1 << WorldChunk.Ground.ROCKY) \
		| (1 << WorldChunk.Ground.CLEARING)
const TREE_GROUND: int = (1 << WorldChunk.Ground.GRASS) | (1 << WorldChunk.Ground.ROCKY)

## Coste de la reparación por casillas: casilla normal, casilla de agua (se vuelve puente) y
## casilla de risco que se convertiría en escalera o rampa.
const COST_STEP: int = 1
const COST_WATER: int = 4
const COST_CLIFF: int = 6
## Hacia dónde se ensancha una escalera o rampa (a 2 casillas, como un sendero).
const WIDEN_STEPS: Array[int] = [1, -1]

## Celdas gruesas de margen alrededor del chunk: 3 al norte (una caída de 3 niveles baja 6 filas
## y la casilla de margen del norte necesita su origen), 2 a los lados y 1 al sur.
const PAD_W: int = 2
const PAD_N: int = 3
const MACRO_W: int = MACROS + 2 * PAD_W
const MACRO_H: int = MACROS + PAD_N + 1
## Casillas con 1 de margen alrededor (vecinos de las del borde del chunk).
const TILE_W: int = SIZE + 2
## Interior seguro: celdas gruesas que ningún vecino lee en su margen (el vecino del sur lee las 3
## últimas filas; el del norte, la primera; los de los lados, 2 columnas).
const SAFE_X0: int = PAD_W
const SAFE_X1: int = MACROS - 1 - PAD_W
const SAFE_Y0: int = 1
const SAFE_Y1: int = MACROS - 1 - PAD_N

## Ancho de sendero y de camino (casillas); también son los valores de la capa de trabajo `path`.
const PATH_W: int = RegionPlan.PATH_WIDTH
const ROAD_W: int = RegionPlan.ROAD_WIDTH
## Radio (celdas gruesas) de la zona aplanada alrededor del Nujio: con villa o aldea, y sin ella.
const VILLA_RADIUS: int = 3
const NUJIO_RADIUS: int = 1
## Huella del Nujio (spec de arte: 4×4, una celda gruesa).
const NUJIO_SIZE: int = 4
## Casillas de claro alrededor de un Nujio y de plaza alrededor del de una villa.
const NUJIO_CLEARING: int = 4
const PLAZA_RADIUS: int = 3
## Casas de una villa con nombre (las aldeas traen las suyas del plan). Huella 4×3. Radios
## (casillas desde el centro del Nujio) a los que se prueban.
const VILLA_HOUSES: int = 5
const HOUSE_SIZE := Vector2i(4, 3)
const HOUSE_RADII: Array[float] = [9.0, 10.5, 8.0, 12.0]
## Ningún punto de interés tiene su centro a menos de esto (Chebyshev) del centro del chunk.
const CENTER_CLEAR: int = 12
## Posiciones al azar que se prueban por tipo de punto de interés y de Nujio.
const SPOT_TRIES: int = 24
## Intentos de tipo por hueco (mundo-2.md §4: como mucho 3).
const KIND_TRIES: int = 3
## Tipos que se sortean (PLACE solo sale del CSV): los primeros de WorldChunk.PointKind.
const RANDOM_POINTS: int = 6
## Tipos que exigen celdas gruesas de un mismo nivel.
const FLAT_POINTS: int = (1 << WorldChunk.PointKind.HILL) | (1 << WorldChunk.PointKind.POND) \
		| (1 << WorldChunk.PointKind.LANDMARK_TREE) | (1 << WorldChunk.PointKind.STONE_CIRCLE)
## Tipos del CSV que son punto de interés (las villas y los Bosques clave son anclas).
const CSV_POINTS: Array[String] = ["hito", "tarca", "lugar", "manantial"]
## Puntos de interés por defecto (mundo-2.md §4); la región los cambia con "points_of_interest".
const DEFAULT_POI: Dictionary = {
	"count_weights": {"2": 55, "3": 45},
	"near_anchor": 1,
	"border_margin": 12,
	"min_gap": 24,
	"weights": {
		"north": {"colina": 35, "hito": 20, "circulo_piedras": 20, "arboleda": 15, "laguna": 5, "pradera": 5},
		"center": {"colina": 20, "hito": 20, "circulo_piedras": 15, "arboleda": 15, "laguna": 15, "pradera": 15},
		"south": {"colina": 5, "hito": 15, "circulo_piedras": 10, "arboleda": 15, "laguna": 30, "pradera": 25},
	},
}
## Formas grandes por defecto; la región los cambia con "chunk_shapes". El umbral del bosque sale
## de forest.density como en ChunkGenerator (0,3 - densidad × 0,45).
## - forest_frequency: ruido de las manchas de bosque (por casilla; baja frecuencia).
## - forest_min_neighbours: árboles 2×2 vecinos (de 8) que necesita uno para quedarse.
## - forest_rocky_penalty: el pedregal sube el umbral (menos árboles).
## - rock_permille: probabilidad (‰) de roca 2×2 en una celda 2×2 de pedregal o de montaña.
const DEFAULT_SHAPES: Dictionary = {
	"forest_frequency": 0.035,
	"forest_min_neighbours": 4,
	"forest_rocky_penalty": 0.25,
	"rock_permille": 90,
}
const DEFAULT_FOREST_DENSITY: float = 0.6
## Celdas de la rejilla de árboles y rocas (2×2 casillas, alineada con world_cell par).
const GRID: int = SIZE / 2
## Rocas del círculo de piedras: cuántas, a qué radio (casillas) y giros que se prueban.
const CIRCLE_ROCKS: int = 6
const CIRCLE_RADIUS: float = 4.5
const CIRCLE_TURNS: int = 12

## Coste del A* grueso (se suma al paso de 1): cara de frente (escalera, + 1 por nivel), borde
## (rampa), ir a lo largo de una cara, cascada.
const ASTAR_STAIRS: float = 2.0
const ASTAR_RAMP: float = 3.0
const ASTAR_ALONG_FACE: float = 2.0
const ASTAR_WATERFALL: float = 40.0
## Peso por celda gruesa (multiplica el coste de entrar): agua honda (puente), vado, camino pintado,
## laguna, colina, zona de casas, arboleda; y el descuento de lo ya trazado.
const WEIGHT_WATER: float = 5.0
const WEIGHT_FORD: float = 1.5
const WEIGHT_ROAD: float = 0.6
const WEIGHT_POND: float = 8.0
const WEIGHT_HILL: float = 6.0
const WEIGHT_VILLA: float = 2.5
const WEIGHT_GROVE: float = 1.5
const TRACED_FACTOR: float = 0.4
## Celdas gruesas hacia delante que mira el enderezado de una ruta del A*.
const STRAIGHTEN_WINDOW: int = 16
## Recargo de Prim de las aristas que no unen dos nodos de camino: así las puertas de camino (y la
## villa o el Nujio, si hay camino) se unen entre sí antes que con nada más y el camino atraviesa
## el chunk sin cortarse. Es más fuerte que el "a mitad de precio" del ADR (ver generation.md).
const NON_ROAD_EDGE: float = 1000.0

const SALT_ROCKY: int = 140
const SALT_FACE_COLUMN: int = 141
const SALT_CHUNK: int = 142
const SALT_FOREST: int = 143
const SALT_TREE: int = 144
const SALT_ROCK: int = 145
const SALT_HOUSE: int = 146
const SALT_GRASS: int = 147
const SALT_PATCH: int = 148
const SALT_THEME: int = 149
const SALT_ASPECT: int = 150
const SALT_DEAD: int = 151
const SALT_FLIP: int = 152
const SALT_REFUGE: int = 153
const SALT_FRUIT: int = 154
const SALT_DECOR: int = 155
const SALT_SMALL: int = 156
const SALT_VILLA: int = 157

## Decoración, variantes y objetos pequeños por defecto (paso 6); la región los cambia con su
## bloque "chunk_decor".
## - grass_frequency: ruido de las manchas de hierba; grass_cuts: cortes (bytes 0-255 del ruido)
##   entre las variantes A|B|C|D (los cuartiles del ruido: cuatro variantes casi iguales en área).
## - patch_frequency y patch_cut: manchas de decoración (por encima del corte, ~30 % del suelo).
## - theme_frequency: ruido que decide flores o matas y el color de las flores de cada mancha.
## - darts: intentos del muestreo de Poisson por chunk (dentro de las manchas, sin dos piezas
##   vecinas); flower_border: probabilidad de mata en cada vecina libre de una flor.
## - dead_permille: árboles 2×2 secos (‰); big_tree_chance: probabilidad de un árbol grande 3×3
##   dentro del bosque por chunk.
## - young_tries: intentos de árbol joven 1×1 en el borde del bosque; stumps, logs, small_rocks:
##   [mín, máx] tocones, troncos caídos 2×1 y rocas 1×1 por chunk (raros; bloquean).
const DEFAULT_DECOR: Dictionary = {
	"grass_frequency": 0.04,
	"grass_cuts": [98, 128, 157],
	"patch_frequency": 0.09,
	"patch_cut": 150,
	"theme_frequency": 0.03,
	"darts": 900,
	"flower_border": 0.6,
	"dead_permille": 12,
	"big_tree_chance": 0.3,
	"young_tries": 90,
	"stumps": [0, 3],
	"logs": [0, 2],
	"small_rocks": [1, 4],
}
## Frutales 2×2: lo que cambia respecto al bloque "fruit" de la región (mundo-2.md §3: separación
## de 5 a 6 entre esquinas noroeste). Bloque "chunk_fruit" de la región.
const DEFAULT_CHUNK_FRUIT: Dictionary = {"min_spacing": 6}
## Refugio (mundo-2.md §3): a ≤ 6 casillas de un sendero o camino, y en un chunk de Nujio a ≤ 6
## de su huella (radio de descanso de bosques-y-relacion.md).
const REFUGE_TRAIL_REACH: int = 6
const REFUGE_NUJIO_REACH: int = 6
## Profundidad mínima y máxima (pasos de sendero desde la puerta) a la que se busca sitio para un
## letrero, y casillas de margen con el borde del chunk.
const SIGN_MIN_DEPTH: int = 3
const SIGN_MAX_DEPTH: int = 40
## Huertos: tamaño y probabilidad por casa.
const HUERTO_SIZE := Vector2i(3, 2)
const HUERTO_CHANCE: float = 0.6
## Pasos máximos de una calle (de la puerta de una casa a la plaza o a un sendero).
const STREET_MAX: int = 24
## Tipos de objeto con los que se interactúa (accesibilidad): letrero, frutal, refugios, casa,
## Nujio y la tarca.
const INTERACTIVE: int = (1 << WorldChunk.ObjectKind.SIGN) | (1 << WorldChunk.ObjectKind.FRUIT_TREE) 		| (1 << WorldChunk.ObjectKind.REFUGE_TREE) | (1 << WorldChunk.ObjectKind.CAVE) 		| (1 << WorldChunk.ObjectKind.HOUSE) | (1 << WorldChunk.ObjectKind.NUJIO) 		| (1 << WorldChunk.ObjectKind.LANDMARK)
const TREE_KINDS: int = (1 << WorldChunk.ObjectKind.TREE) | (1 << WorldChunk.ObjectKind.TREE_YOUNG) 		| (1 << WorldChunk.ObjectKind.TREE_BIG) | (1 << WorldChunk.ObjectKind.TREE_DEAD) 		| (1 << WorldChunk.ObjectKind.FRUIT_TREE) | (1 << WorldChunk.ObjectKind.REFUGE_TREE)
## Suelos de sendero (para el refugio y los letreros) y suelos donde va la decoración.
const TRAIL_GROUND: int = (1 << WorldChunk.Ground.PATH) | (1 << WorldChunk.Ground.ROAD) 		| (1 << WorldChunk.Ground.BRIDGE)
const DECOR_GROUND: int = NATURAL_GROUND
## Siluetas (PlaceholderTileset.Shape) sin helechos, sin hojarasca y sin setas (spec §6.2).
const NO_FERNS: int = (1 << PlaceholderTileset.Shape.CACTUS) | (1 << PlaceholderTileset.Shape.THORNY)
const NO_LEAVES: int = 1 << PlaceholderTileset.Shape.CACTUS
## Margen (celdas de la rejilla de árboles) con el que se calculan los aspectos: la clase D mira
## a la C, que mira a la B, que mira a la A.
const ASPECT_PAD: int = 3
const NO_MUSHROOMS: int = (1 << PlaceholderTileset.Shape.CACTUS) | (1 << PlaceholderTileset.Shape.PALM)


## Construye el chunk `coord` del plan. Nunca devuelve null.
static func build(plan: RegionPlan, coord: Vector2i) -> WorldChunk:
	return _Build.new(plan, coord).run()


## Hash entero rápido (sin Array) para decisiones por posición del mundo.
static func _ihash(a: int, b: int, c: int) -> int:
	var h: int = (a * 0x27D4EB2D + b * 0x165667B1 + c * 0x9E3779B9) & 0xFFFFFFFF
	h = ((h ^ (h >> 15)) * 0x2C1B3C6D) & 0xFFFFFFFF
	h = ((h ^ (h >> 12)) * 0x297A2D39) & 0xFFFFFFFF
	return h ^ (h >> 15)


## Valor de `decor` de una pieza de decoración.
static func decor_value(piece: int) -> int:
	return DECOR_PIECE_BASE + piece


## Pieza de decoración (DecorPiece) de un valor de `decor`, o -1 si es nada o una sombra.
static func decor_piece(value: int) -> int:
	return value - DECOR_PIECE_BASE if value >= DECOR_PIECE_BASE else -1


## Comprobación de accesibilidad (ADR 0014 §5 paso 7): lo interactivo que no se alcanza a pie desde
## el hub, según `blocked`. Letrero, frutal, Nujio y tarca: alguna casilla vecina; refugio en árbol
## hueco: alguna de sus casillas; cueva: su boca (fila de abajo); casa: la fila de delante. Vacío
## si todo se alcanza. La usan los tests y sirve para depurar un chunk.
static func inaccessible(chunk: WorldChunk) -> Array[String]:
	var reach: PackedByteArray = chunk.reachable_from_hub()
	var out: Array[String] = []
	for obj: Dictionary in chunk.objects:
		var kind: int = obj.kind
		if (INTERACTIVE >> kind) & 1 == 0:
			continue
		var cell: Vector2i = obj.cell
		var size: Vector2i = obj.size
		var cells: Array[Vector2i] = []
		match kind:
			WorldChunk.ObjectKind.REFUGE_TREE:
				for y: int in range(cell.y, cell.y + size.y):
					for x: int in range(cell.x, cell.x + size.x):
						cells.append(Vector2i(x, y))
			WorldChunk.ObjectKind.CAVE:
				for x: int in range(cell.x, cell.x + size.x):
					cells.append(Vector2i(x, cell.y + size.y - 1))
			WorldChunk.ObjectKind.HOUSE:
				for x: int in range(cell.x, cell.x + size.x):
					cells.append(Vector2i(x, cell.y + size.y))
			_:
				for x: int in range(cell.x, cell.x + size.x):
					cells.append(Vector2i(x, cell.y - 1))
					cells.append(Vector2i(x, cell.y + size.y))
				for y: int in range(cell.y, cell.y + size.y):
					cells.append(Vector2i(cell.x - 1, y))
					cells.append(Vector2i(cell.x + size.x, y))
		var ok: bool = false
		for c: Vector2i in cells:
			if WorldChunk.in_bounds(c) and reach[WorldCoords.cell_index(c)] == 1:
				ok = true
				break
		if not ok:
			out.append("%s en %s" % [WorldChunk.ObjectKind.keys()[kind], cell])
	return out


## Casilla del carril de una celda gruesa: esquina superior izquierda del pincel del sendero.
static func lane_cell(macro: Vector2i) -> Vector2i:
	return macro * MACRO + Vector2i.ONE


## A* de la rejilla gruesa con el coste de cruzar el relieve: las caras se cruzan de frente (en
## vertical) y los bordes con rampa. No guarda referencia al _Build (sin ciclos de RefCounted).
class _PathGrid extends AStarGrid2D:
	var lv := PackedByteArray()
	var face := PackedByteArray()
	var wet := PackedByteArray()

	func _compute_cost(from_id: Vector2i, to_id: Vector2i) -> float:
		var a: int = from_id.y * MACROS + from_id.x
		var b: int = to_id.y * MACROS + to_id.x
		var cost: float = 1.0
		if from_id.y == to_id.y:
			if face[a] > 0 or face[b] > 0:
				cost += ASTAR_ALONG_FACE
			if lv[a] != lv[b]:
				cost += ASTAR_RAMP
			return cost
		var n: int = a if from_id.y < to_id.y else b
		var s: int = b if n == a else a
		if lv[n] > lv[s]:
			cost += ASTAR_STAIRS + lv[n] - lv[s]
			if wet[s] == 1:
				cost += ASTAR_WATERFALL
		elif lv[n] < lv[s]:
			cost += ASTAR_RAMP
		return cost


## Estado de una construcción: todo lo mutable vive aquí, uno por llamada.
class _Build:
	var plan: RegionPlan
	var coord: Vector2i
	var chunk: WorldChunk
	var rng := RandomNumberGenerator.new()
	# Celdas gruesas con margen (MACRO_W × MACRO_H).
	var m_level := PackedByteArray()
	var m_peak := PackedByteArray()
	var m_water := PackedByteArray()
	var m_face_rows := PackedByteArray() # filas de cara arriba de la celda (0..4)
	var m_face_start := PackedByteArray() # fila de la cara en la que empieza la celda (0 o 4)
	var m_face_len := PackedByteArray() # filas de la cara entera (2 por nivel de caída)
	var m_face_wet := PackedByteArray() # cascada
	# Celdas gruesas del chunk (MACROS × MACROS) para el A*.
	var g_solid := PackedByteArray()
	var g_weight := PackedFloat32Array()
	# Casillas con margen (TILE_W × TILE_W): relieve antes de escaleras y rampas.
	var t_cliff := PackedByteArray()
	var t_aux := PackedByteArray() # cara: fila dentro de la cara; borde: máscara
	var t_len := PackedByteArray() # cara: filas de la cara entera
	# Casillas del chunk.
	var path := PackedByteArray() # 0, PATH_W o ROAD_W
	var keep := PackedByteArray() # 1 = sin objetos (alrededor del hub y de los nodos)
	var solid := PackedByteArray() # 1 = reservada para un objeto grande: la reparación no pasa
	var no_tree := PackedByteArray()
	var force_tree := PackedByteArray()
	# Ancla y puntos de interés.
	var anchor: int = Anchor.NONE
	var anchor_macro := Vector2i(-1, -1)
	var villa: Dictionary = {}
	# { kind, a (celda gruesa sup. izq.), size (celdas gruesas), center (casilla), node (casilla), csv }
	var points: Array[Dictionary] = []
	# { tile, macro, road, door ({} si no es puerta), side }
	var nodes: Array[Dictionary] = []
	var has_road_door: bool = false
	# Reparación.
	var reached := PackedByteArray()
	var cost_h := PackedByteArray()
	var cost_v := PackedByteArray()
	var dist := PackedInt32Array()
	var prev := PackedInt32Array()
	var heap := PackedInt32Array()
	var heap_size: int = 0
	var queue := PackedInt32Array()
	# Paso 6-7 (M8).
	var seed_mix: int = 0
	var shape: int = 0
	var decor_params: Dictionary = {}
	var near_trail := PackedByteArray() # 1 = a ≤ REFUGE_TRAIL_REACH casillas de un sendero

	func _init(p: RegionPlan, c: Vector2i) -> void:
		plan = p
		coord = c

	func run() -> WorldChunk:
		chunk = WorldChunk.new()
		chunk.seed_value = plan.seed_value
		chunk.coord = coord
		rng.seed = ChunkGenerator.hash_ints([plan.plan_seed, coord.x, coord.y, SALT_CHUNK])
		seed_mix = (plan.plan_seed ^ (plan.plan_seed >> 32)) & 0xFFFFFFFF
		decor_params = DEFAULT_DECOR.merged(plan.region_params.get("chunk_decor", {}), true)
		var bosque_id: int = plan.bosque_at(coord)
		if bosque_id >= 0 and bosque_id < plan.bosques.styles.size():
			shape = int(plan.bosques.styles[bosque_id].get("shape", 0))
		_load_levels()
		_plan_anchor()
		_plan_points()
		_compute_faces()
		_classify()
		_fill()
		_init_tile_layers()
		var required: PackedInt32Array = _open_doors()
		_shape_anchor()
		_shape_points()
		_route_network()
		_place_hub()
		for node: Dictionary in nodes:
			required.append(WorldCoords.cell_index(node.tile))
		_connect(required)
		_place_objects()
		_paint_variants()
		_paint_shadows()
		chunk.rebuild_blocked()
		_flood_blocked()
		_place_refuge()
		_place_fruit()
		_place_small()
		_paint_grass()
		_place_decor()
		chunk.rebuild_blocked()
		return chunk

	# --- Celdas gruesas -------------------------------------------------------------------------

	func _mk(mx: int, my: int) -> int:
		return (my + PAD_N) * MACRO_W + mx + PAD_W

	func _load_levels() -> void:
		var n: int = MACRO_W * MACRO_H
		m_level.resize(n)
		m_peak.resize(n)
		m_water.resize(n)
		var origin: Vector2i = coord * MACROS
		var max_x: int = plan.size_macro.x - 1
		var max_y: int = plan.size_macro.y - 1
		for j: int in MACRO_H:
			# Fuera de la región se repite la última celda: el borde de la región es llano.
			var my: int = clampi(origin.y + j - PAD_N, 0, max_y)
			for i: int in MACRO_W:
				var m := Vector2i(clampi(origin.x + i - PAD_W, 0, max_x), my)
				var level: int = plan.level_at(m)
				var k: int = j * MACRO_W + i
				m_peak[k] = 1 if level == RegionPlan.LEVEL_PEAK else 0
				m_level[k] = mini(level, RegionPlan.LEVEL_MAX)
				m_water[k] = plan.water_at(m)

	func _compute_faces() -> void:
		var n: int = MACRO_W * MACRO_H
		m_face_rows.resize(n)
		m_face_start.resize(n)
		m_face_len.resize(n)
		m_face_wet.resize(n)
		var max_rows: int = FACE_ROWS_PER_LEVEL * RegionPlan.LEVEL_MAX
		for j: int in range(2, MACRO_H):
			for i: int in MACRO_W:
				var k: int = j * MACRO_W + i
				if m_peak[k] == 1:
					continue
				var low: int = m_level[k]
				var north: int = m_level[k - MACRO_W]
				var source: int = -1
				if north > low:
					m_face_len[k] = (north - low) * FACE_ROWS_PER_LEVEL
					m_face_rows[k] = mini(m_face_len[k], MACRO)
					source = k - MACRO_W
				elif north == low and max_rows > MACRO:
					# Una caída de más de 2 niveles sigue en esta celda.
					var len: int = (m_level[k - 2 * MACRO_W] - low) * FACE_ROWS_PER_LEVEL
					if len > MACRO:
						m_face_len[k] = len
						m_face_rows[k] = len - MACRO
						m_face_start[k] = MACRO
						source = k - 2 * MACRO_W
				if source >= 0 and m_water[k] != RegionAuthoring.Water.NONE \
						and m_water[source] != RegionAuthoring.Water.NONE:
					m_face_wet[k] = 1

	# --- Ancla: villa, aldea o Nujio --------------------------------------------------------------

	## Busca dónde va el Nujio (con su villa o solo) y aplana su zona. Sin sitio, no hay ancla.
	func _plan_anchor() -> void:
		villa = plan.villa_in_chunk(coord)
		var id: int = plan.bosque_at(coord)
		var nujio_here: bool = id >= 0 and id < plan.bosques.count() \
				and plan.bosques.nujio_chunk[id] == coord and plan.bosques.has_nujio(id)
		if villa.is_empty() and not nujio_here:
			return
		var radius: int = NUJIO_RADIUS if villa.is_empty() else VILLA_RADIUS
		var target := Vector2i(-1, -1)
		if not villa.is_empty():
			target = (villa.macro as Vector2i) - coord * MACROS
		else:
			for p: Dictionary in plan.places_in_chunk(coord):
				if p.type == "bosque":
					target = (p.cell as Vector2i) - coord * MACROS
					break
			if target.x < 0:
				target = _random_anchor(radius)
		var m: Vector2i = _find_anchor_macro(target, radius)
		if m.x < 0:
			villa = {}
			return
		anchor = Anchor.NUJIO if villa.is_empty() else Anchor.VILLA
		anchor_macro = m
		chunk.has_villa = anchor == Anchor.VILLA
		chunk.nujio_rect = Rect2i(m * MACRO, Vector2i(NUJIO_SIZE, NUJIO_SIZE))
		var level: int = m_level[_mk(m.x, m.y)]
		for my: int in range(maxi(m.y - radius, SAFE_Y0), mini(m.y + radius, SAFE_Y1) + 1):
			for mx: int in range(maxi(m.x - radius, SAFE_X0), mini(m.x + radius, SAFE_X1) + 1):
				var k: int = _mk(mx, my)
				m_level[k] = level
				m_peak[k] = 0

	func _anchor_range(radius: int) -> Rect2i:
		var lo := Vector2i(SAFE_X0 + radius, SAFE_Y0 + radius)
		var hi := Vector2i(SAFE_X1 - radius, SAFE_Y1 - radius)
		return Rect2i(lo, hi - lo + Vector2i.ONE)

	## El Nujio y la celda de debajo (la del hub) en seco y sin cumbre.
	func _anchor_ok(m: Vector2i) -> bool:
		for k: int in [_mk(m.x, m.y), _mk(m.x, m.y + 1)]:
			if m_peak[k] == 1 or m_water[k] != RegionAuthoring.Water.NONE:
				return false
		return true

	## Nujio sin villa ni lugar del CSV: al azar, lejos del centro fijo.
	func _random_anchor(radius: int) -> Vector2i:
		var r: Rect2i = _anchor_range(radius)
		var center: Vector2i = WorldChunk.center()
		for t: int in SPOT_TRIES:
			var m := Vector2i(rng.randi_range(r.position.x, r.end.x - 1), rng.randi_range(r.position.y, r.end.y - 1))
			var c: Vector2i = m * MACRO + Vector2i(MACRO / 2, MACRO / 2)
			if maxi(absi(c.x - center.x), absi(c.y - center.y)) >= CENTER_CLEAR and _anchor_ok(m):
				return m
		return Vector2i(MACROS / 2, MACROS / 2)

	## La celda válida más cercana (anillos de Chebyshev) a `target`, dentro del rango del radio.
	func _find_anchor_macro(target: Vector2i, radius: int) -> Vector2i:
		var r: Rect2i = _anchor_range(radius)
		var t := Vector2i(clampi(target.x, r.position.x, r.end.x - 1), clampi(target.y, r.position.y, r.end.y - 1))
		for ring: int in MACROS:
			for my: int in range(t.y - ring, t.y + ring + 1):
				for mx: int in range(t.x - ring, t.x + ring + 1):
					if maxi(absi(mx - t.x), absi(my - t.y)) != ring or not r.has_point(Vector2i(mx, my)):
						continue
					if _anchor_ok(Vector2i(mx, my)):
						return Vector2i(mx, my)
		return Vector2i(-1, -1)

	func _anchor_center() -> Vector2i:
		return chunk.nujio_rect.position + Vector2i(NUJIO_SIZE / 2, NUJIO_SIZE / 2)

	# --- Puntos de interés ------------------------------------------------------------------------

	func _plan_points() -> void:
		var params: Dictionary = DEFAULT_POI.merged(plan.region_params.get("points_of_interest", {}), true)
		var total: int = int(params.near_anchor)
		if anchor == Anchor.NONE:
			total = _weighted_count(params.count_weights)
		var used: Dictionary = {}
		for p: Dictionary in plan.places_in_chunk(coord):
			if not CSV_POINTS.has(String(p.type)):
				continue
			var local: Vector2i = (p.cell as Vector2i) - coord * MACROS
			if p.type == "hito":
				var a := Vector2i(clampi(local.x - 1, 0, MACROS - 3), clampi(local.y - 1, 0, MACROS - 3))
				_add_point(WorldChunk.PointKind.LANDMARK_TREE, a, Vector2i(3, 3), true)
				used[WorldChunk.PointKind.LANDMARK_TREE] = true
			elif p.type == "tarca":
				var a := Vector2i(clampi(local.x, 0, MACROS - 1), clampi(local.y - 1, 0, MACROS - 2))
				_add_point(WorldChunk.PointKind.PLACE, a, Vector2i(1, 2), true)
			else:
				_add_point(WorldChunk.PointKind.PLACE, Vector2i(clampi(local.x, 0, MACROS - 1),
						clampi(local.y, 0, MACROS - 1)), Vector2i.ONE, true)
		var weights: PackedFloat32Array = _latitude_weights(params.weights)
		var failed: Dictionary = used.duplicate()
		var slots: int = total - points.size()
		for slot: int in slots:
			for attempt: int in KIND_TRIES:
				var kind: int = _pick_kind(weights, failed)
				if kind < 0:
					break
				var size: Vector2i = _point_size(kind)
				var a: Vector2i = _find_spot(kind, size, params)
				if a.x >= 0:
					_add_point(kind, a, size, false)
					failed[kind] = true # nunca dos del mismo tipo
					break
				failed[kind] = true

	func _weighted_count(weights: Dictionary) -> int:
		var total: float = 0.0
		for key: Variant in weights:
			total += float(weights[key])
		var roll: float = rng.randf() * total
		var last: int = 0
		for key: Variant in weights:
			last = int(String(key))
			roll -= float(weights[key])
			if roll < 0.0:
				return last
		return last

	## Pesos de los tipos sorteables interpolados por latitud (norte t = 0, centro 0,5, sur 1).
	func _latitude_weights(table: Dictionary) -> PackedFloat32Array:
		var t: float = float(coord.y) / float(maxi(1, plan.size_chunks.y - 1))
		var a: Dictionary = table.get("north", {})
		var b: Dictionary = table.get("center", {})
		var f: float = t * 2.0
		if t > 0.5:
			a = b
			b = table.get("south", {})
			f = (t - 0.5) * 2.0
		var out := PackedFloat32Array()
		out.resize(RANDOM_POINTS)
		for k: int in RANDOM_POINTS:
			var id: String = WorldChunk.POINT_IDS[k]
			out[k] = maxf(0.0, lerpf(float(a.get(id, 0)), float(b.get(id, 0)), f))
		return out

	func _pick_kind(weights: PackedFloat32Array, excluded: Dictionary) -> int:
		var total: float = 0.0
		for k: int in RANDOM_POINTS:
			if not excluded.has(k):
				total += weights[k]
		if total <= 0.0:
			return -1
		var roll: float = rng.randf() * total
		var last: int = -1
		for k: int in RANDOM_POINTS:
			if excluded.has(k) or weights[k] <= 0.0:
				continue
			last = k
			roll -= weights[k]
			if roll < 0.0:
				return k
		return last

	## Huella en celdas gruesas (mundo-2.md §4).
	func _point_size(kind: int) -> Vector2i:
		match kind:
			WorldChunk.PointKind.POND:
				return Vector2i(4, 3) if rng.randf() < 0.5 else Vector2i(3, 2)
			WorldChunk.PointKind.MEADOW:
				return Vector2i(4, 4) if rng.randf() < 0.5 else Vector2i(3, 3)
		return Vector2i(3, 3)

	func _find_spot(kind: int, size: Vector2i, params: Dictionary) -> Vector2i:
		var x1: int = SAFE_X1 - size.x + 1
		var y1: int = SAFE_Y1 - size.y + 1
		if kind == WorldChunk.PointKind.HILL:
			y1 = mini(y1, MACROS - 1 - size.y) # la fila del pie de la escalera, dentro
		for t: int in SPOT_TRIES:
			var a := Vector2i(rng.randi_range(SAFE_X0, x1), rng.randi_range(SAFE_Y0, y1))
			if _spot_ok(kind, a, size, params):
				return a
		return Vector2i(-1, -1)

	func _spot_ok(kind: int, a: Vector2i, size: Vector2i, params: Dictionary) -> bool:
		var c: Vector2i = a * MACRO + size * (MACRO / 2)
		var margin: int = int(params.border_margin)
		if c.x < margin or c.y < margin or c.x > SIZE - margin or c.y > SIZE - margin:
			return false
		var center: Vector2i = WorldChunk.center()
		if maxi(absi(c.x - center.x), absi(c.y - center.y)) < CENTER_CLEAR:
			return false
		var gap: int = int(params.min_gap)
		for p: Dictionary in points:
			if ((p.center as Vector2i) - c).length_squared() < gap * gap:
				return false
		if anchor != Anchor.NONE and (_anchor_center() - c).length_squared() < gap * gap:
			return false
		var flat: bool = (FLAT_POINTS >> kind) & 1 == 1
		var base: int = -1
		for my: int in range(a.y, a.y + size.y):
			for mx: int in range(a.x, a.x + size.x):
				var k: int = _mk(mx, my)
				if m_peak[k] == 1 or m_water[k] != RegionAuthoring.Water.NONE:
					return false
				if base < 0:
					base = m_level[k]
				elif flat and m_level[k] != base:
					return false
		if (kind == WorldChunk.PointKind.HILL or kind == WorldChunk.PointKind.POND) and base >= RegionPlan.LEVEL_MAX:
			return false
		if kind == WorldChunk.PointKind.HILL:
			# Fila de debajo (la de la cara y el pie de la escalera), del mismo nivel y en seco.
			for mx: int in range(a.x, a.x + size.x):
				var k: int = _mk(mx, a.y + size.y)
				if m_peak[k] == 1 or m_water[k] != RegionAuthoring.Water.NONE or m_level[k] != base:
					return false
		return true

	## Registra el punto y su nodo de sendero; la colina sube su huella un nivel.
	func _add_point(kind: int, a: Vector2i, size: Vector2i, csv: bool) -> void:
		var mid := Vector2i(a.x + size.x / 2, a.y + size.y / 2)
		var node_macro: Vector2i = mid
		var node_offset := Vector2i.ZERO
		match kind:
			WorldChunk.PointKind.HILL:
				node_macro = Vector2i(mid.x, a.y + size.y)
				node_offset = Vector2i(0, 1) # pie de la escalera, debajo de las 2 filas de cara
				for my: int in range(a.y, a.y + size.y):
					for mx: int in range(a.x, a.x + size.x):
						m_level[_mk(mx, my)] += 1
			WorldChunk.PointKind.LANDMARK_TREE:
				node_macro = Vector2i(mid.x, a.y + size.y - 1)
			WorldChunk.PointKind.POND:
				node_macro = Vector2i(mid.x, a.y + size.y - 1)
			WorldChunk.PointKind.PLACE:
				node_macro = Vector2i(a.x, a.y + size.y - 1)
		node_macro = node_macro.clamp(Vector2i.ZERO, Vector2i(MACROS - 1, MACROS - 1))
		points.append({
			"kind": kind, "a": a, "size": size, "csv": csv,
			"center": a * MACRO + size * (MACRO / 2),
			"node": ChunkBuilder.lane_cell(node_macro) + node_offset,
		})

	# --- Relieve por casilla (con 1 de margen) --------------------------------------------------

	func _classify() -> void:
		var n: int = TILE_W * TILE_W
		t_cliff.resize(n)
		t_aux.resize(n)
		t_len.resize(n)
		var col_macro := PackedInt32Array()
		var col_rx := PackedInt32Array()
		col_macro.resize(TILE_W)
		col_rx.resize(TILE_W)
		for t: int in TILE_W:
			var mx: int = WorldCoords.floor_div(t - 1, MACRO)
			col_macro[t] = mx + PAD_W
			col_rx[t] = t - 1 - mx * MACRO
		for ty: int in TILE_W:
			var my: int = WorldCoords.floor_div(ty - 1, MACRO)
			var ry: int = ty - 1 - my * MACRO
			var row_k: int = (my + PAD_N) * MACRO_W
			var row_t: int = ty * TILE_W
			for tx: int in TILE_W:
				var k: int = row_k + col_macro[tx]
				var t: int = row_t + tx
				if m_peak[k] == 1:
					t_cliff[t] = WorldChunk.Cliff.EDGE
					t_aux[t] = EDGE_PEAK
					continue
				if ry < m_face_rows[k]:
					t_cliff[t] = WorldChunk.Cliff.WATERFALL if m_face_wet[k] == 1 else WorldChunk.Cliff.FACE
					t_aux[t] = m_face_start[k] + ry
					t_len[t] = m_face_len[k]
					continue
				var level: int = m_level[k]
				var mask: int = 0
				if ry == 0 and m_level[k - MACRO_W] < level:
					mask |= EDGE_N
				var rx: int = col_rx[tx]
				if rx == MACRO - 1 and m_level[k + 1] < level:
					mask |= EDGE_E
				if rx == 0 and m_level[k - 1] < level:
					mask |= EDGE_W
				if mask != 0:
					t_cliff[t] = WorldChunk.Cliff.EDGE
					t_aux[t] = mask

	## Suelo base, pedregal, nivel y riscos del chunk desde las capas con margen.
	func _fill() -> void:
		var params: Dictionary = DEFAULT_GROUND.merged(plan.region_params.get("chunk_ground", {}), true)
		var rocky: Array = params.rocky_by_level
		var thresholds := PackedFloat32Array()
		thresholds.resize(RegionPlan.LEVEL_MAX + 1)
		var any_rocky: bool = false
		for l: int in thresholds.size():
			thresholds[l] = float(rocky[mini(l, rocky.size() - 1)])
			any_rocky = any_rocky or thresholds[l] < 1.0
		var noise: FastNoiseLite = ChunkGenerator._make_noise(
				ChunkGenerator.hash_ints([plan.plan_seed, SALT_ROCKY]), float(params.rocky_frequency), 2)
		var wx0: int = coord.x * SIZE
		var wy0: int = coord.y * SIZE
		for y: int in SIZE:
			var my: int = y / MACRO + PAD_N
			var row_t: int = (y + 1) * TILE_W + 1
			var row_c: int = y * SIZE
			for x: int in SIZE:
				var k: int = my * MACRO_W + x / MACRO + PAD_W
				var c: int = row_c + x
				var level: int = m_level[k]
				chunk.level[c] = level
				chunk.cliff[c] = t_cliff[row_t + x]
				var water: int = m_water[k]
				if water != RegionAuthoring.Water.NONE:
					chunk.ground[c] = WATER_GROUND[water]
				elif any_rocky and thresholds[level] < 1.0 \
						and noise.get_noise_2d(wx0 + x, wy0 + y) > thresholds[level]:
					chunk.ground[c] = WorldChunk.Ground.ROCKY

	func _init_tile_layers() -> void:
		for layer: PackedByteArray in [path, keep, solid, no_tree, force_tree]:
			layer.resize(WorldChunk.CELLS)

	# --- Formas del ancla y de los puntos de interés (suelo y reservas) --------------------------

	func _shape_anchor() -> void:
		if anchor == Anchor.NONE:
			return
		var rect: Rect2i = chunk.nujio_rect
		var reach: int = VILLA_RADIUS * MACRO + MACRO / 2 if anchor == Anchor.VILLA else NUJIO_CLEARING
		var zone: Rect2i = rect.grow(reach).intersection(Rect2i(0, 0, SIZE, SIZE))
		for y: int in range(zone.position.y, zone.end.y):
			for x: int in range(zone.position.x, zone.end.x):
				var i: int = y * SIZE + x
				no_tree[i] = 1
				if chunk.cliff[i] != WorldChunk.Cliff.NONE or (NATURAL_GROUND >> chunk.ground[i]) & 1 == 0:
					continue
				var plaza: bool = anchor == Anchor.VILLA and rect.grow(PLAZA_RADIUS).has_point(Vector2i(x, y))
				chunk.ground[i] = WorldChunk.Ground.PLAZA if plaza else WorldChunk.Ground.CLEARING
		_mark(solid, rect)
		var node: Vector2i = ChunkBuilder.lane_cell(anchor_macro + Vector2i.DOWN)
		nodes.append({"tile": node, "macro": anchor_macro + Vector2i.DOWN, "road": false, "door": {}})
		_mark(keep, Rect2i(node - Vector2i.ONE, Vector2i(3, 3)))

	func _shape_points() -> void:
		for p: Dictionary in points:
			var a: Vector2i = p.a
			var size: Vector2i = p.size
			var foot := Rect2i(a * MACRO, size * MACRO)
			var mid: Vector2i = a + size / 2
			match int(p.kind):
				WorldChunk.PointKind.HILL:
					_mark(no_tree, foot.grow_individual(0, 0, 0, MACRO))
					# Escalera de 2 en la cara sur, bajo la celda del medio.
					for dx: int in PATH_W:
						var i: int = (mid.x * MACRO + 1 + dx) + (a.y + size.y) * MACRO * SIZE
						if chunk.cliff[i] == WorldChunk.Cliff.FACE:
							_stairs_column(i)
					_mark(solid, Rect2i(_big_tree_cell(p), Vector2i(3, 3)))
				WorldChunk.PointKind.LANDMARK_TREE:
					_mark(no_tree, foot)
					_clearing_blob(p.center, 5.5)
					_mark(solid, Rect2i(_big_tree_cell(p), Vector2i(3, 3)))
				WorldChunk.PointKind.STONE_CIRCLE:
					_mark(no_tree, foot)
					_clearing_blob(p.center, 6.5)
				WorldChunk.PointKind.GROVE:
					var hollow := Rect2i(mid * MACRO, Vector2i(MACRO, MACRO))
					_mark(force_tree, foot)
					for y: int in range(hollow.position.y, hollow.end.y):
						for x: int in range(hollow.position.x, hollow.end.x):
							var i: int = y * SIZE + x
							force_tree[i] = 0
							no_tree[i] = 1
							if chunk.cliff[i] == WorldChunk.Cliff.NONE and (NATURAL_GROUND >> chunk.ground[i]) & 1 == 1:
								chunk.ground[i] = WorldChunk.Ground.CLEARING
				WorldChunk.PointKind.POND:
					_mark(no_tree, foot.grow(1).intersection(Rect2i(0, 0, SIZE, SIZE)))
					_pond(p)
				WorldChunk.PointKind.MEADOW:
					_mark(no_tree, foot)
				WorldChunk.PointKind.PLACE:
					_mark(no_tree, foot.grow(2).intersection(Rect2i(0, 0, SIZE, SIZE)))
					_clearing_blob(p.center, 3.5)
					if size.y > 1:
						_mark(solid, Rect2i(a * MACRO + Vector2i(1, 1), Vector2i(2, 2)))
			var node: Vector2i = p.node
			_mark(keep, Rect2i(node - Vector2i.ONE, Vector2i(3, 3)))
			nodes.append({"tile": node, "macro": WorldCoords.floor_div_v(node, MACRO), "road": false, "door": {}})
			chunk.points.append({"kind": p.kind, "rect": foot, "cell": node})

	## Claro irregular (radio que ondula con el ángulo) alrededor de `center`.
	func _clearing_blob(center: Vector2i, radius: float) -> void:
		var phase: float = rng.randf() * TAU
		var r: int = ceili(radius + 1.5)
		for y: int in range(maxi(center.y - r, 0), mini(center.y + r, LAST) + 1):
			for x: int in range(maxi(center.x - r, 0), mini(center.x + r, LAST) + 1):
				var d := Vector2(x - center.x + 0.5, y - center.y + 0.5)
				var limit: float = radius + 1.2 * sin(3.0 * d.angle() + phase)
				if d.length() > limit:
					continue
				var i: int = y * SIZE + x
				no_tree[i] = 1
				if chunk.cliff[i] == WorldChunk.Cliff.NONE and (NATURAL_GROUND >> chunk.ground[i]) & 1 == 1:
					chunk.ground[i] = WorldChunk.Ground.CLEARING

	## Laguna: unión de 3 elipses dentro de la huella, sin tocar la celda del nodo, con orilla de claro.
	func _pond(p: Dictionary) -> void:
		var area := Rect2i((p.a as Vector2i) * MACRO, (p.size as Vector2i) * MACRO).grow(-1)
		var node_box := Rect2i(WorldCoords.floor_div_v(p.node, MACRO) * MACRO, Vector2i(MACRO, MACRO)).grow(1)
		var half := Vector2(area.size) * 0.5
		var origin := Vector2(area.position) + half
		var ellipses: Array[Vector3] = [Vector3(origin.x, origin.y - half.y * 0.15, 1.0)]
		for k: int in 2:
			var side: float = -1.0 if k == 0 else 1.0
			ellipses.append(Vector3(origin.x + side * half.x * rng.randf_range(0.3, 0.45),
					origin.y + rng.randf_range(-0.3, 0.2) * half.y, rng.randf_range(0.5, 0.65)))
		var lake := PackedByteArray()
		lake.resize(WorldChunk.CELLS)
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				if node_box.has_point(Vector2i(x, y)):
					continue
				var i: int = y * SIZE + x
				if chunk.cliff[i] != WorldChunk.Cliff.NONE or (NATURAL_GROUND >> chunk.ground[i]) & 1 == 0:
					continue
				for e: Vector3 in ellipses:
					var dx: float = (x + 0.5 - e.x) / (half.x * e.z)
					var dy: float = (y + 0.5 - e.y) / (half.y * maxf(e.z, 0.7))
					if dx * dx + dy * dy <= 1.0:
						lake[i] = 1
						break
		var shore: Rect2i = area.grow(1).intersection(Rect2i(0, 0, SIZE, SIZE))
		for y: int in range(shore.position.y, shore.end.y):
			for x: int in range(shore.position.x, shore.end.x):
				var i: int = y * SIZE + x
				if lake[i] == 1:
					chunk.ground[i] = WorldChunk.Ground.LAKE
				elif chunk.cliff[i] == WorldChunk.Cliff.NONE and (NATURAL_GROUND >> chunk.ground[i]) & 1 == 1:
					chunk.ground[i] = WorldChunk.Ground.CLEARING

	## Árbol grande (3×3) de la colina y del hito: en la celda gruesa del medio, a 2 filas del nodo.
	func _big_tree_cell(p: Dictionary) -> Vector2i:
		var mid: Vector2i = (p.a as Vector2i) + (p.size as Vector2i) / 2
		return mid * MACRO + Vector2i(1, 0)

	func _mark(layer: PackedByteArray, rect: Rect2i) -> void:
		var r: Rect2i = rect.intersection(Rect2i(0, 0, SIZE, SIZE))
		for y: int in range(r.position.y, r.end.y):
			for x: int in range(r.position.x, r.end.x):
				layer[y * SIZE + x] = 1

	# --- Puertas ----------------------------------------------------------------------------------

	## Abre las casillas de cada puerta (escalera o rampa si caen en un risco), crea su nodo y
	## devuelve sus casillas (índices del chunk), que tienen que quedar unidas al hub.
	func _open_doors() -> PackedInt32Array:
		var required := PackedInt32Array()
		for side: Vector2i in WorldChunk.SIDES:
			if not plan.has_door(coord, side):
				continue
			var door: Dictionary = plan.door(coord, side)
			var along: Vector2i = Vector2i.DOWN if side.x != 0 else Vector2i.RIGHT
			var first: Vector2i = door.cell
			for k: int in int(door.width):
				var cell: Vector2i = first + along * k
				var i: int = cell.y * SIZE + cell.x
				var cliff: int = chunk.cliff[i]
				if cliff == WorldChunk.Cliff.FACE:
					_stairs_column(i)
				elif cliff == WorldChunk.Cliff.EDGE and _aux(i) != EDGE_PEAK:
					_open_cell(i, WorldChunk.Cliff.RAMP)
				required.append(i)
			var middle: Vector2i = first + along * (int(door.width) / 2)
			var road: bool = bool(door.road)
			has_road_door = has_road_door or road
			nodes.append({"tile": middle, "macro": WorldCoords.floor_div_v(middle, MACRO), "road": road,
					"door": door, "side": side})
		return required

	# --- Red de senderos --------------------------------------------------------------------------

	## Ordena los nodos con el ancla primero, Prim sobre la distancia gruesa, A* por arista y
	## rasterizado a casillas (sendero de 2, camino de 3), con escaleras, rampas y puentes.
	func _route_network() -> void:
		_order_nodes()
		if nodes.is_empty():
			return
		var grid: _PathGrid = _make_grid()
		var count: int = nodes.size()
		var in_tree := PackedByteArray()
		in_tree.resize(count)
		in_tree[0] = 1
		_paint_rect(Rect2i(ChunkBuilder.lane_cell(nodes[0].macro), Vector2i(PATH_W, PATH_W)), PATH_W)
		for step: int in count - 1:
			var best: float = INF
			var bu: int = -1
			var bv: int = -1
			for u: int in count:
				if in_tree[u] == 0:
					continue
				for v: int in count:
					if in_tree[v] == 1:
						continue
					var mu: Vector2i = nodes[u].macro
					var mv: Vector2i = nodes[v].macro
					var w: float = absi(mu.x - mv.x) + absi(mu.y - mv.y)
					if not (nodes[u].road and nodes[v].road):
						w += NON_ROAD_EDGE
					if w < best:
						best = w
						bu = u
						bv = v
			in_tree[bv] = 1
			var width: int = ROAD_W if nodes[bu].road and nodes[bv].road else PATH_W
			var route: Array[Vector2i] = grid.get_id_path(nodes[bv].macro, nodes[bu].macro)
			if route.is_empty():
				continue # Sin paso grueso: lo resuelve la reparación por casillas.
			route = _straighten(grid, route)
			_paint_route(route, width)
			for m: Vector2i in route:
				var k: int = m.y * MACROS + m.x
				if g_solid[k] == 0:
					grid.set_point_weight_scale(m, g_weight[k] * TRACED_FACTOR)
		for node: Dictionary in nodes:
			if not (node.door as Dictionary).is_empty():
				_paint_door(node)
		_apply_paths()

	## Ancla primero: villa o Nujio; si no, el primer punto de interés que no sea colina (el hub no
	## cae en una escalera); si no, la primera puerta. El ancla de villa o Nujio es de camino si el
	## chunk tiene alguna puerta de camino.
	func _order_nodes() -> void:
		if nodes.is_empty():
			return
		var first: int = 0
		if anchor == Anchor.NONE:
			var doors: int = 0
			for node: Dictionary in nodes:
				if not (node.door as Dictionary).is_empty():
					doors += 1
			first = -1
			for k: int in range(doors, nodes.size()):
				if first < 0 and chunk.points[k - doors].kind != WorldChunk.PointKind.HILL:
					first = k
			if first < 0:
				first = doors if doors < nodes.size() else 0
		else:
			for k: int in nodes.size():
				if (nodes[k].door as Dictionary).is_empty():
					first = k
					break
			nodes[first].road = has_road_door
		var head: Dictionary = nodes[first]
		nodes.remove_at(first)
		nodes.insert(0, head)

	## El A* deja escalones cuando va en diagonal (muchas rutas cuestan lo mismo). Sustituye cada
	## tramo por una L (o una recta) si no cuesta más: menos giros y tramos rectos más largos.
	func _straighten(grid: _PathGrid, route: Array[Vector2i]) -> Array[Vector2i]:
		var n: int = route.size()
		if n < 3:
			return route
		var prefix := PackedFloat32Array()
		prefix.resize(n)
		for k: int in range(1, n):
			prefix[k] = prefix[k - 1] + _step_cost(grid, route[k - 1], route[k])
		var out: Array[Vector2i] = [route[0]]
		var i: int = 0
		while i < n - 1:
			var taken: bool = false
			for j: int in range(mini(n - 1, i + STRAIGHTEN_WINDOW), i + 1, -1):
				var a: Vector2i = route[i]
				var b: Vector2i = route[j]
				var budget: float = prefix[j] - prefix[i] + 0.001
				for corner: Vector2i in [Vector2i(b.x, a.y), Vector2i(a.x, b.y)]:
					var cells: Array[Vector2i] = _l_cells(a, corner, b)
					if _cells_cost(grid, a, cells) <= budget:
						out.append_array(cells)
						i = j
						taken = true
						break
				if taken:
					break
			if not taken:
				i += 1
				out.append(route[i])
		return out

	## Celdas de a (sin ella) a b pasando por la esquina, en pasos ortogonales.
	func _l_cells(a: Vector2i, corner: Vector2i, b: Vector2i) -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		var at: Vector2i = a
		for target: Vector2i in [corner, b]:
			while at != target:
				at += Vector2i(signi(target.x - at.x), signi(target.y - at.y))
				out.append(at)
		return out

	func _cells_cost(grid: _PathGrid, a: Vector2i, cells: Array[Vector2i]) -> float:
		var total: float = 0.0
		var from: Vector2i = a
		for c: Vector2i in cells:
			if grid.is_point_solid(c):
				return INF
			total += _step_cost(grid, from, c)
			from = c
		return total

	func _step_cost(grid: _PathGrid, from: Vector2i, to: Vector2i) -> float:
		return grid._compute_cost(from, to) * grid.get_point_weight_scale(to)

	func _make_grid() -> _PathGrid:
		var grid := _PathGrid.new()
		grid.region = Rect2i(0, 0, MACROS, MACROS)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		grid.update()
		var n: int = MACROS * MACROS
		grid.lv.resize(n)
		grid.face.resize(n)
		grid.wet.resize(n)
		g_solid.resize(n)
		g_weight.resize(n)
		g_weight.fill(1.0)
		var origin: Vector2i = coord * MACROS
		for my: int in MACROS:
			for mx: int in MACROS:
				var k: int = my * MACROS + mx
				var mk: int = _mk(mx, my)
				grid.lv[k] = m_level[mk]
				grid.face[k] = m_face_rows[mk]
				grid.wet[k] = m_face_wet[mk]
				if m_peak[mk] == 1:
					g_solid[k] = 1
				var water: int = m_water[mk]
				if water == RegionAuthoring.Water.FORD:
					g_weight[k] = WEIGHT_FORD
				elif water != RegionAuthoring.Water.NONE:
					g_weight[k] = WEIGHT_WATER
				elif plan.road_at(origin + Vector2i(mx, my)) != RegionAuthoring.Road.NONE:
					g_weight[k] = WEIGHT_ROAD
		if anchor != Anchor.NONE:
			if anchor == Anchor.VILLA:
				_weigh(Rect2i(anchor_macro - Vector2i(VILLA_RADIUS, VILLA_RADIUS), Vector2i.ONE * (2 * VILLA_RADIUS + 1)), WEIGHT_VILLA)
			g_solid[anchor_macro.y * MACROS + anchor_macro.x] = 1
		for p: Dictionary in points:
			var a: Vector2i = p.a
			var size: Vector2i = p.size
			var mid: Vector2i = a + size / 2
			match int(p.kind):
				WorldChunk.PointKind.HILL:
					_weigh(Rect2i(a, size), WEIGHT_HILL)
					g_solid[mid.y * MACROS + mid.x] = 1
				WorldChunk.PointKind.POND:
					_weigh(Rect2i(a, size), WEIGHT_POND)
				WorldChunk.PointKind.GROVE:
					_weigh(Rect2i(a, size), WEIGHT_GROVE)
				WorldChunk.PointKind.LANDMARK_TREE:
					g_solid[mid.y * MACROS + mid.x] = 1
		for node: Dictionary in nodes:
			var m: Vector2i = node.macro
			var k: int = m.y * MACROS + m.x
			g_solid[k] = 0 # un nodo siempre se puede alcanzar
			if (node.door as Dictionary).is_empty():
				g_weight[k] = minf(g_weight[k], 1.0)
		for k: int in n:
			var m := Vector2i(k % MACROS, k / MACROS)
			if g_solid[k] == 1:
				grid.set_point_solid(m, true)
			else:
				grid.set_point_weight_scale(m, g_weight[k])
		return grid

	func _weigh(rect: Rect2i, weight: float) -> void:
		var r: Rect2i = rect.intersection(Rect2i(0, 0, MACROS, MACROS))
		for my: int in range(r.position.y, r.end.y):
			for mx: int in range(r.position.x, r.end.x):
				var k: int = my * MACROS + mx
				g_weight[k] = maxf(g_weight[k], weight)

	## Tramos rectos entre los carriles de celdas gruesas consecutivas (4 casillas por paso).
	func _paint_route(route: Array[Vector2i], width: int) -> void:
		var brush := Vector2i(width - 1, width - 1)
		for k: int in route.size():
			var p: Vector2i = ChunkBuilder.lane_cell(route[k])
			var q: Vector2i = ChunkBuilder.lane_cell(route[k - 1]) if k > 0 else p
			var lo := Vector2i(mini(p.x, q.x), mini(p.y, q.y))
			var hi := Vector2i(maxi(p.x, q.x), maxi(p.y, q.y)) + brush
			_paint_rect(Rect2i(lo, hi - lo + Vector2i.ONE), width)

	## Tramo de la puerta: de sus casillas del borde hacia dentro hasta el carril de su celda gruesa.
	func _paint_door(node: Dictionary) -> void:
		var door: Dictionary = node.door
		var side: Vector2i = node.side
		var dw: int = int(door.width)
		var w: int = dw
		var first: Vector2i = door.cell
		var lane := Rect2i(ChunkBuilder.lane_cell(node.macro), Vector2i(w, w))
		var stub: Rect2i
		var link: Rect2i
		if side.x != 0:
			var x0: int = 0 if side.x < 0 else lane.position.x
			var x1: int = lane.end.x if side.x < 0 else SIZE
			stub = Rect2i(x0, first.y, x1 - x0, dw)
			var y0: int = mini(first.y, lane.position.y)
			var y1: int = maxi(first.y + dw, lane.end.y)
			link = Rect2i(lane.position.x, y0, w, y1 - y0)
		else:
			var y0: int = 0 if side.y < 0 else lane.position.y
			var y1: int = lane.end.y if side.y < 0 else SIZE
			stub = Rect2i(first.x, y0, dw, y1 - y0)
			var x0: int = mini(first.x, lane.position.x)
			var x1: int = maxi(first.x + dw, lane.end.x)
			link = Rect2i(x0, lane.position.y, x1 - x0, w)
		var value: int = ROAD_W if bool(door.road) else PATH_W
		_paint_rect(stub, value)
		_paint_rect(link, value)

	func _paint_rect(rect: Rect2i, value: int) -> void:
		var r: Rect2i = rect.intersection(Rect2i(0, 0, SIZE, SIZE))
		for y: int in range(r.position.y, r.end.y):
			for x: int in range(r.position.x, r.end.x):
				var i: int = y * SIZE + x
				if path[i] < value:
					path[i] = value

	## Suelo de sendero, camino y puente; caras cruzadas a escalera (si la cara entera cabe en el
	## chunk) y bordes a rampa. Cascadas, cumbres y lo reservado quedan como están.
	func _apply_paths() -> void:
		for i: int in WorldChunk.CELLS:
			var w: int = path[i]
			if w == 0:
				continue
			if solid[i] == 1:
				path[i] = 0
				continue
			var cliff: int = chunk.cliff[i]
			if cliff == WorldChunk.Cliff.WATERFALL:
				continue
			if cliff == WorldChunk.Cliff.FACE:
				var top: int = i / SIZE - _aux(i)
				if top < 0 or top + _len(i) - 1 > LAST:
					continue
				_stairs_column(i)
			elif cliff == WorldChunk.Cliff.EDGE:
				if _aux(i) == EDGE_PEAK:
					continue
				_open_cell(i, WorldChunk.Cliff.RAMP)
			_pave(i, w)

	## Suelo de una casilla de sendero (w = PATH_W) o camino (ROAD_W): puente sobre el agua.
	func _pave(i: int, w: int) -> void:
		var g: int = chunk.ground[i]
		if (WorldChunk.GROUND_BLOCKING >> g) & 1 == 1:
			chunk.ground[i] = WorldChunk.Ground.BRIDGE
		elif (NATURAL_GROUND >> g) & 1 == 1:
			chunk.ground[i] = WorldChunk.Ground.ROAD if w >= ROAD_W else WorldChunk.Ground.PATH

	# --- Hub ------------------------------------------------------------------------------------

	## El hub es la casilla del ancla (nodo 0). Si no se pisa, la transitable más cercana a ella.
	func _place_hub() -> void:
		var target: Vector2i = nodes[0].tile if not nodes.is_empty() else WorldChunk.center()
		if _walk(WorldCoords.cell_index(target)):
			chunk.hub = target
			return
		for r: int in range(1, SIZE):
			var best: int = -1
			var best_d: int = 1 << 30
			for y: int in range(maxi(target.y - r, 0), mini(target.y + r, LAST) + 1):
				var dy: int = y - target.y
				var step: int = 1 if absi(dy) == r else maxi(2 * r, 1)
				for x: int in range(target.x - r, target.x + r + 1, step):
					if x < 0 or x > LAST:
						continue
					var i: int = y * SIZE + x
					if not _walk(i):
						continue
					var dx: int = x - target.x
					var d: int = dx * dx + dy * dy
					if d < best_d:
						best_d = d
						best = i
			if best >= 0:
				chunk.hub = Vector2i(best % SIZE, best / SIZE)
				return

	## Se pisa: risco abierto, suelo que no es agua y sin objeto grande reservado.
	func _walk(i: int) -> bool:
		return (CLIFF_OPEN >> chunk.cliff[i]) & 1 == 1 and (WorldChunk.GROUND_BLOCKING >> chunk.ground[i]) & 1 == 0 \
				and solid[i] == 0

	# --- Reparación: todo nodo unido al hub -------------------------------------------------------

	## Pone escaleras, rampas y puentes (y su sendero) hasta que todas las casillas de `required`
	## se alcanzan desde el hub.
	func _connect(required: PackedInt32Array) -> void:
		reached.resize(WorldChunk.CELLS)
		queue.resize(WorldChunk.CELLS)
		var flooded: bool = false
		var costs: bool = false
		for r: int in required:
			if (CLIFF_OPEN >> chunk.cliff[r]) & 1 == 0 or solid[r] == 1:
				continue # Cumbre o cascada: no hay paso posible.
			if not flooded:
				_flood()
				flooded = true
			if reached[r] == 1:
				continue
			if not costs:
				_build_costs()
				dist.resize(WorldChunk.CELLS)
				prev.resize(WorldChunk.CELLS)
				heap.resize(WorldChunk.CELLS)
				costs = true
			var end: int = _search(r)
			if end >= 0:
				_carve(end)
				flooded = false

	## Coste de entrar o salir de cada casilla en horizontal y en vertical (0 = imposible). Una
	## cara se cruza en vertical y solo si cabe entera en el chunk; un borde, en el eje de su
	## máscara; cumbres, cascadas y objetos grandes, nunca.
	func _build_costs() -> void:
		cost_h.resize(WorldChunk.CELLS)
		cost_v.resize(WorldChunk.CELLS)
		cost_h.fill(0)
		cost_v.fill(0)
		for i: int in WorldChunk.CELLS:
			if solid[i] == 1:
				continue
			var cliff: int = chunk.cliff[i]
			if (CLIFF_OPEN >> cliff) & 1 == 1:
				var c: int = COST_WATER if (WorldChunk.GROUND_BLOCKING >> chunk.ground[i]) & 1 == 1 else COST_STEP
				cost_h[i] = c
				cost_v[i] = c
			elif cliff == WorldChunk.Cliff.FACE:
				var top: int = i / SIZE - _aux(i)
				cost_v[i] = COST_CLIFF if top >= 0 and top + _len(i) - 1 <= LAST else 0
			elif cliff == WorldChunk.Cliff.EDGE:
				var mask: int = _aux(i)
				if mask != EDGE_PEAK:
					cost_v[i] = COST_CLIFF if mask & EDGE_N != 0 else 0
					cost_h[i] = COST_CLIFF if mask & EDGE_SIDES != 0 else 0

	## Casillas que se pisan alcanzables desde el hub (sin contar los objetos pequeños, que aún no
	## están: nunca van sobre un sendero).
	func _flood() -> void:
		reached.fill(0)
		var start: int = chunk.hub.y * SIZE + chunk.hub.x
		if not _walk(start):
			return
		reached[start] = 1
		queue[0] = start
		var head: int = 0
		var tail: int = 1
		while head < tail:
			var i: int = queue[head]
			head += 1
			var x: int = i % SIZE
			if x > 0:
				tail = _flood_visit(i - 1, tail)
			if x < LAST:
				tail = _flood_visit(i + 1, tail)
			if i >= SIZE:
				tail = _flood_visit(i - SIZE, tail)
			if i < WorldChunk.CELLS - SIZE:
				tail = _flood_visit(i + SIZE, tail)

	func _flood_visit(n: int, tail: int) -> int:
		if reached[n] == 0 and _walk(n):
			reached[n] = 1
			queue[tail] = n
			return tail + 1
		return tail

	## Dijkstra desde `start` hasta lo ya alcanzado desde el hub. Devuelve la primera casilla
	## alcanzada (su cadena `prev` lleva a `start`) o -1.
	func _search(start: int) -> int:
		dist.fill(1 << 30)
		prev.fill(-1)
		heap_size = 0
		dist[start] = 0
		_push(start)
		while heap_size > 0:
			var top: int = _pop()
			var d: int = top >> 13
			var i: int = top & 8191
			if d != dist[i]:
				continue
			if reached[i] == 1:
				return i
			var x: int = i % SIZE
			if cost_h[i] > 0:
				if x > 0:
					_relax(i, i - 1, d, cost_h[i - 1])
				if x < LAST:
					_relax(i, i + 1, d, cost_h[i + 1])
			if cost_v[i] > 0:
				if i >= SIZE:
					_relax(i, i - SIZE, d, cost_v[i - SIZE])
				if i < WorldChunk.CELLS - SIZE:
					_relax(i, i + SIZE, d, cost_v[i + SIZE])
		return -1

	func _relax(from: int, to: int, d: int, cost: int) -> void:
		if cost > 0 and d + cost < dist[to]:
			dist[to] = d + cost
			prev[to] = from
			_push(to)

	## Convierte en escalera, rampa o puente lo que hace falta en el camino de `end` a su origen y
	## lo marca como sendero (sin objetos encima).
	func _carve(end: int) -> void:
		var i: int = end
		while i >= 0:
			var next: int = prev[i]
			var cliff: int = chunk.cliff[i]
			if cliff == WorldChunk.Cliff.FACE:
				_stairs_column(i)
				_widen_stairs(i)
			elif cliff == WorldChunk.Cliff.EDGE:
				# Un borde siempre está entre dos casillas del camino: los extremos están abiertos.
				_open_cell(i, WorldChunk.Cliff.RAMP)
				_widen_ramp(i, absi(next - i) == SIZE)
			if path[i] == 0:
				path[i] = 1
			_pave(i, PATH_W)
			if not cost_h.is_empty():
				cost_h[i] = COST_STEP
				cost_v[i] = COST_STEP
			i = next

	## Abre una casilla de risco (escalera o rampa) y actualiza sus costes si ya existen.
	func _open_cell(i: int, cliff: int) -> void:
		chunk.cliff[i] = cliff
		if (WorldChunk.GROUND_BLOCKING >> chunk.ground[i]) & 1 == 1:
			# Una escalera o rampa nunca queda en el agua: sobre el agua es un puente (y sigue
			# contando como agua para la cascada de debajo).
			chunk.ground[i] = WorldChunk.Ground.BRIDGE
		if not cost_h.is_empty():
			cost_h[i] = COST_STEP
			cost_v[i] = COST_STEP

	## La columna entera de la cara de `i` (dentro del chunk) pasa a escalera.
	func _stairs_column(i: int) -> void:
		var x: int = i % SIZE
		var top: int = i / SIZE - _aux(i)
		var bottom: int = top + _len(i) - 1
		for y: int in range(maxi(top, 0), mini(bottom, LAST) + 1):
			var c: int = y * SIZE + x
			if chunk.cliff[c] == WorldChunk.Cliff.FACE:
				_open_cell(c, WorldChunk.Cliff.STAIRS)

	## Segunda columna de escalera al lado (sendero de 2), si la cara vecina es igual y tiene
	## suelo abierto arriba y abajo.
	func _widen_stairs(i: int) -> void:
		var x: int = i % SIZE
		var top: int = i / SIZE - _aux(i)
		var bottom: int = top + _len(i) - 1
		if top < 1 or bottom > LAST - 1:
			return
		for step: int in WIDEN_STEPS:
			var nx: int = x + step
			if nx < 0 or nx > LAST:
				continue
			var n: int = i + step
			if chunk.cliff[n] != WorldChunk.Cliff.FACE or _aux(n) != _aux(i) or _len(n) != _len(i):
				continue
			if chunk.cliff[(top - 1) * SIZE + nx] != WorldChunk.Cliff.NONE \
					or chunk.cliff[(bottom + 1) * SIZE + nx] != WorldChunk.Cliff.NONE:
				continue
			_stairs_column(n)
			return

	## Segunda casilla de rampa a lo largo del borde (sendero de 2), si tiene la misma máscara.
	func _widen_ramp(i: int, vertical: bool) -> void:
		var x: int = i % SIZE
		var y: int = i / SIZE
		for step: int in WIDEN_STEPS:
			var n: int = -1
			if vertical and x + step >= 0 and x + step <= LAST:
				n = i + step
			elif not vertical and y + step >= 0 and y + step <= LAST:
				n = i + step * SIZE
			if n >= 0 and chunk.cliff[n] == WorldChunk.Cliff.EDGE and _aux(n) == _aux(i):
				_open_cell(n, WorldChunk.Cliff.RAMP)
				return

	# --- Formas grandes (objetos) -----------------------------------------------------------------

	func _place_objects() -> void:
		if anchor != Anchor.NONE:
			chunk.add_object(WorldChunk.ObjectKind.NUJIO, chunk.nujio_rect.position, chunk.nujio_rect.size,
					_flip_at(chunk.nujio_rect.position))
			if anchor == Anchor.VILLA:
				_place_houses()
				_place_streets()
				_place_huertos()
		for p: Dictionary in points:
			var a: Vector2i = p.a
			var size: Vector2i = p.size
			var mid: Vector2i = a + size / 2
			match int(p.kind):
				WorldChunk.PointKind.HILL, WorldChunk.PointKind.LANDMARK_TREE:
					chunk.add_object(WorldChunk.ObjectKind.TREE_BIG, _big_tree_cell(p), Vector2i(3, 3), _flip_at(_big_tree_cell(p)))
				WorldChunk.PointKind.STONE_CIRCLE:
					_place_circle(p)
				WorldChunk.PointKind.PLACE:
					if size.y > 1:
						chunk.add_object(WorldChunk.ObjectKind.LANDMARK, a * MACRO + Vector2i(1, 1), Vector2i(2, 2))
		_place_signs()
		_place_rocks()
		_place_forest()

	## Una casilla libre para un objeto que no es de los reservados.
	func _free(x: int, y: int, ground_mask: int) -> bool:
		if x < 0 or y < 0 or x > LAST or y > LAST:
			return false
		var i: int = y * SIZE + x
		return chunk.occupant[i] == WorldChunk.NO_OBJECT and path[i] == 0 and keep[i] == 0 \
				and solid[i] == 0 and chunk.cliff[i] == WorldChunk.Cliff.NONE \
				and (ground_mask >> chunk.ground[i]) & 1 == 1

	func _rect_free(rect: Rect2i, ground_mask: int) -> bool:
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				if not _free(x, y, ground_mask):
					return false
		return true

	## Casas de 4×3 en corro alrededor de la plaza, sin pisar senderos y con 1 casilla entre ellas.
	## Solo la huella y el objeto: el trazado de la villa es de M8.
	func _place_houses() -> void:
		var count: int = int(villa.get("houses", 0))
		if count <= 0:
			count = VILLA_HOUSES
		var center := Vector2(_anchor_center())
		var start: float = rng.randf() * TAU
		var material: int = ChunkGenerator.hash_ints([plan.plan_seed, coord.x, coord.y, SALT_HOUSE]) % 2
		var ground_mask: int = NATURAL_GROUND
		for k: int in count:
			var placed: bool = false
			for jitter: float in [0.0, 0.25, -0.25, 0.5, -0.5]:
				if placed:
					break
				var angle: float = start + TAU * k / count + jitter
				for radius: float in HOUSE_RADII:
					var at: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius - Vector2(HOUSE_SIZE) * 0.5
					var rect := Rect2i(Vector2i(roundi(at.x), roundi(at.y)), HOUSE_SIZE)
					if not _rect_free(rect, ground_mask) or not _no_objects(rect.grow(1)):
						continue
					chunk.add_object(WorldChunk.ObjectKind.HOUSE, rect.position, HOUSE_SIZE,
							material * 2 + ChunkGenerator.hash_ints([plan.plan_seed, coord.x, coord.y, k, SALT_HOUSE]) % 2)
					placed = true
					break

	func _no_objects(rect: Rect2i) -> bool:
		var r: Rect2i = rect.intersection(Rect2i(0, 0, SIZE, SIZE))
		for y: int in range(r.position.y, r.end.y):
			for x: int in range(r.position.x, r.end.x):
				if chunk.occupant[y * SIZE + x] != WorldChunk.NO_OBJECT:
					return false
		return true

	## 6 rocas de 2×2 en corro; se gira el corro para dejar pasar los senderos que entran.
	func _place_circle(p: Dictionary) -> void:
		var center := Vector2((p.a as Vector2i) * MACRO + (p.size as Vector2i) * (MACRO / 2))
		var best_turn: int = 0
		var best_free: int = -1
		for turn: int in CIRCLE_TURNS:
			var free: int = 0
			for k: int in CIRCLE_ROCKS:
				if _rect_free(_circle_rock(center, turn, k), NATURAL_GROUND):
					free += 1
			if free > best_free:
				best_free = free
				best_turn = turn
		for k: int in CIRCLE_ROCKS:
			var rect: Rect2i = _circle_rock(center, best_turn, k)
			if _rect_free(rect, NATURAL_GROUND):
				chunk.add_object(WorldChunk.ObjectKind.ROCK, rect.position, Vector2i(2, 2), k % 3)

	func _circle_rock(center: Vector2, turn: int, k: int) -> Rect2i:
		var angle: float = TAU * k / CIRCLE_ROCKS + TAU / CIRCLE_ROCKS * turn / CIRCLE_TURNS
		var at: Vector2 = center + Vector2(cos(angle), sin(angle)) * CIRCLE_RADIUS - Vector2.ONE
		return Rect2i(Vector2i(roundi(at.x), roundi(at.y)), Vector2i(2, 2))

	## Rocas de 2×2 sueltas en el pedregal y en la montaña (nivel 3), en la rejilla de 2×2.
	func _place_rocks() -> void:
		var params: Dictionary = DEFAULT_SHAPES.merged(plan.region_params.get("chunk_shapes", {}), true)
		var permille: int = int(params.rock_permille)
		if permille <= 0:
			return
		var gx0: int = coord.x * GRID
		var gy0: int = coord.y * GRID
		var rocks := PackedByteArray()
		rocks.resize(GRID * GRID)
		for gy: int in GRID:
			for gx: int in GRID:
				var x: int = gx * 2
				var y: int = gy * 2
				var i: int = y * SIZE + x
				if chunk.ground[i] != WorldChunk.Ground.ROCKY and chunk.level[i] < RegionPlan.LEVEL_MAX:
					continue
				var h: int = ChunkGenerator.hash_ints([plan.plan_seed, gx0 + gx, gy0 + gy, SALT_ROCK])
				if h % 1000 >= permille:
					continue
				if (gx > 0 and (rocks[gy * GRID + gx - 1] == 1 or (gy > 0 and rocks[(gy - 1) * GRID + gx - 1] == 1))) \
						or (gy > 0 and rocks[(gy - 1) * GRID + gx] == 1) \
						or (gy > 0 and gx < GRID - 1 and rocks[(gy - 1) * GRID + gx + 1] == 1):
					continue
				if not _rect_free(Rect2i(x, y, 2, 2), TREE_GROUND):
					continue
				chunk.add_object(WorldChunk.ObjectKind.ROCK, Vector2i(x, y), Vector2i(2, 2), (h >> 12) % 3)
				rocks[gy * GRID + gx] = 1

	## Bosque en manchas de árboles 2×2: ruido de baja frecuencia en la rejilla de 2×2 (alineada
	## con world_cell, así que las manchas siguen en el chunk vecino), sin árboles sueltos: se quitan
	## los que tienen menos de forest_min_neighbours árboles alrededor, hasta que no quede ninguno.
	func _place_forest() -> void:
		var params: Dictionary = DEFAULT_SHAPES.merged(plan.region_params.get("chunk_shapes", {}), true)
		var forest: Dictionary = plan.region_params.get("forest", {})
		var threshold: float = 0.3 - float(forest.get("density", DEFAULT_FOREST_DENSITY)) * 0.45
		var rocky_penalty: float = float(params.forest_rocky_penalty)
		var min_n: int = int(params.forest_min_neighbours)
		var noise: FastNoiseLite = ChunkGenerator._make_noise(
				ChunkGenerator.hash_ints([plan.plan_seed, SALT_FOREST]), float(params.forest_frequency), 2)
		var wx0: int = coord.x * SIZE
		var wy0: int = coord.y * SIZE
		var cand := PackedByteArray()
		cand.resize(GRID * GRID)
		for gy: int in GRID:
			for gx: int in GRID:
				var x: int = gx * 2
				var y: int = gy * 2
				var i: int = y * SIZE + x
				var forced: bool = force_tree[i] == 1 and force_tree[i + 1] == 1 \
						and force_tree[i + SIZE] == 1 and force_tree[i + SIZE + 1] == 1
				if not forced and (no_tree[i] == 1 or no_tree[i + 1] == 1 or no_tree[i + SIZE] == 1 or no_tree[i + SIZE + 1] == 1):
					continue
				if not _rect_free(Rect2i(x, y, 2, 2), TREE_GROUND | (1 << WorldChunk.Ground.CLEARING if forced else 0)):
					continue
				if not forced:
					var t: float = threshold
					if chunk.ground[i] == WorldChunk.Ground.ROCKY:
						t += rocky_penalty
					if noise.get_noise_2d(wx0 + x + 1, wy0 + y + 1) <= t:
						continue
				cand[gy * GRID + gx] = 1
		# Vecinos de cada candidato y poda por cola hasta que todos tengan min_n.
		var count := PackedByteArray()
		count.resize(GRID * GRID)
		var pending := PackedInt32Array()
		for g: int in GRID * GRID:
			if cand[g] == 0:
				continue
			var n: int = _grid_neighbours(cand, g)
			count[g] = n
			if n < min_n:
				pending.append(g)
		var head: int = 0
		while head < pending.size():
			var g: int = pending[head]
			head += 1
			if cand[g] == 0:
				continue
			cand[g] = 0
			var gx: int = g % GRID
			var gy: int = g / GRID
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var nx: int = gx + dx
					var ny: int = gy + dy
					if (dx == 0 and dy == 0) or nx < 0 or ny < 0 or nx >= GRID or ny >= GRID:
						continue
					var ng: int = ny * GRID + nx
					if cand[ng] == 1:
						count[ng] -= 1
						if count[ng] == min_n - 1:
							pending.append(ng)
		var gx0: int = coord.x * GRID
		var gy0: int = coord.y * GRID
		_place_big_forest_tree(cand)
		var aspects: PackedByteArray = _tree_aspects()
		var aw: int = GRID + 2 * ASPECT_PAD
		var dead: int = int(decor_params.dead_permille)
		var dead_salt: int = seed_mix ^ SALT_DEAD
		for g: int in GRID * GRID:
			if cand[g] == 1:
				var gx: int = g % GRID
				var gy: int = g / GRID
				var h: int = ChunkBuilder._ihash(gx0 + gx, gy0 + gy, dead_salt)
				if h % 1000 < dead:
					chunk.add_object(WorldChunk.ObjectKind.TREE_DEAD, Vector2i(gx * 2, gy * 2), Vector2i(2, 2), (h >> 12) & 1)
				else:
					chunk.add_object(WorldChunk.ObjectKind.TREE, Vector2i(gx * 2, gy * 2), Vector2i(2, 2),
							aspects[(gy + ASPECT_PAD) * aw + gx + ASPECT_PAD])

	func _grid_neighbours(cand: PackedByteArray, g: int) -> int:
		var gx: int = g % GRID
		var gy: int = g / GRID
		var n: int = 0
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var nx: int = gx + dx
				var ny: int = gy + dy
				if (dx != 0 or dy != 0) and nx >= 0 and ny >= 0 and nx < GRID and ny < GRID:
					n += cand[ny * GRID + nx]
		return n

	# --- Piezas de dibujo ------------------------------------------------------------------------

	func _paint_variants() -> void:
		var middles := PackedByteArray()
		middles.resize(SIZE)
		var wx0: int = coord.x * SIZE
		for x: int in SIZE:
			middles[x] = FACE_MIDDLE_A + ChunkGenerator.hash_ints([plan.plan_seed, wx0 + x, SALT_FACE_COLUMN]) % FACE_MIDDLES
		for y: int in SIZE:
			for x: int in SIZE:
				var i: int = y * SIZE + x
				var cliff: int = chunk.cliff[i]
				if cliff == WorldChunk.Cliff.NONE:
					continue
				if cliff == WorldChunk.Cliff.EDGE or cliff == WorldChunk.Cliff.RAMP:
					chunk.variant[i] = _aux(i)
					continue
				var pos: int = _aux(i)
				var row: int = ROW_LIP if pos == 0 else (ROW_BASE if pos == _len(i) - 1 else ROW_MIDDLE)
				var left: bool = _cliff_at(x - 1, y) == cliff
				var right: bool = _cliff_at(x + 1, y) == cliff
				var column: int
				if cliff == WorldChunk.Cliff.FACE:
					if left and right:
						column = middles[x]
					elif right:
						column = FACE_END_LEFT
					elif left:
						column = FACE_END_RIGHT
					else:
						column = FACE_SINGLE
				else:
					column = COLUMN_MIDDLE if left == right else (COLUMN_LEFT if right else COLUMN_RIGHT)
				chunk.variant[i] = row | (column << VARIANT_COLUMN_SHIFT)

	## Sombra al pie de las caras y al este de los bordes este (capa 2). Fuera del chunk se mira el
	## relieve del margen.
	func _paint_shadows() -> void:
		for y: int in SIZE:
			var row_t: int = (y + 1) * TILE_W + 1
			for x: int in SIZE:
				var i: int = y * SIZE + x
				if chunk.cliff[i] != WorldChunk.Cliff.NONE:
					continue
				var north: int = row_t + x - TILE_W
				var north_cliff: int = chunk.cliff[i - SIZE] if y > 0 else t_cliff[north]
				if north_cliff == WorldChunk.Cliff.FACE and t_aux[north] == t_len[north] - 1:
					chunk.decor[i] = Decor.SHADOW_FOOT
					continue
				var west: int = row_t + x - 1
				var west_cliff: int = chunk.cliff[i - 1] if x > 0 else t_cliff[west]
				var mask: int = t_aux[west]
				if west_cliff == WorldChunk.Cliff.EDGE and mask != EDGE_PEAK and mask & EDGE_E != 0:
					chunk.decor[i] = Decor.SHADOW_EAST

	# --- Paso 6-7 (M8): letreros ------------------------------------------------------------------

	## Bit de volteo por hash de la posición (objetos de una pieza con volteo).
	func _flip_at(cell: Vector2i) -> int:
		return ChunkBuilder._ihash(coord.x * SIZE + cell.x, coord.y * SIZE + cell.y, seed_mix ^ SALT_FLIP) & 1

	## Letreros (misma lógica que la 0.3, navegacion.md): hacia la villa (o aldea) del Bosque, en
	## los chunks del Bosque que no son el suyo, junto a la puerta del lado de la villa; y hacia la
	## villa natal en los chunks de camino (uno de cada dos por paridad y los cruces), junto al
	## camino de 3 de la puerta por la que sigue el camino a casa.
	func _place_signs() -> void:
		var b: BosqueMap = plan.bosques
		var id: int = plan.bosque_at(coord)
		if id >= 0 and id < b.count() and (b.has_villa[id] or b.has_aldea[id]) and b.nujio_chunk[id] != coord:
			var side: Vector2i = ChunkGenerator._side_towards(b.nujio_chunk[id] - coord)
			_place_sign(side, WorldChunk.SignKind.BOSQUE_VILLA, false)
		var roads: Array[Vector2i] = plan.road_sides(coord)
		if not roads.is_empty():
			var home_side: Vector2i = b.road_home_side(coord)
			if home_side != Vector2i.ZERO and (roads.size() >= 3 or posmod(coord.x + coord.y, 2) == 0):
				_place_sign(home_side, WorldChunk.SignKind.HOME_VILLA, true)

	## Busca por los senderos desde la puerta del lado `side` (o la más cercana a ese lado; la de
	## casa tiene que ser esa) la primera casilla libre junto al sendero, a SIGN_MIN_DEPTH pasos o
	## más. `road`: solo junto al camino de 3.
	func _place_sign(side: Vector2i, kind: int, road: bool) -> void:
		var best: Dictionary = {}
		var best_dot: int = -2
		for node: Dictionary in nodes:
			if (node.door as Dictionary).is_empty():
				continue
			var ns: Vector2i = node.side
			var d: int = ns.x * side.x + ns.y * side.y
			if road and (node.side != side or not bool(node.door.road)):
				continue
			if d > best_dot:
				best_dot = d
				best = node
		if road and best.is_empty():
			return
		var dist := PackedInt32Array()
		dist.resize(WorldChunk.CELLS)
		dist.fill(-1)
		var q := PackedInt32Array()
		if best.is_empty():
			q.append(WorldCoords.cell_index(chunk.hub))
		else:
			var door: Dictionary = best.door
			var along: Vector2i = Vector2i.DOWN if (best.side as Vector2i).x != 0 else Vector2i.RIGHT
			for k: int in int(door.width):
				q.append(WorldCoords.cell_index((door.cell as Vector2i) + along * k))
		for i: int in q:
			dist[i] = 0
		var head: int = 0
		while head < q.size():
			var i: int = q[head]
			head += 1
			var d: int = dist[i]
			if d > SIGN_MAX_DEPTH:
				break
			var x: int = i % SIZE
			var around: Array[int] = [i - SIZE if i >= SIZE else -1, i + SIZE if i < WorldChunk.CELLS - SIZE else -1,
					i - 1 if x > 0 else -1, i + 1 if x < LAST else -1]
			if d >= SIGN_MIN_DEPTH and (not road or chunk.ground[i] == WorldChunk.Ground.ROAD) and _walk(i):
				for n: int in around:
					if n >= 0 and _sign_ok(n):
						chunk.add_sign(WorldCoords.index_to_cell(n), kind, side)
						return
			for n: int in around:
				if n >= 0 and dist[n] < 0 and path[n] > 0 and _walk(n) and chunk.occupant[n] == WorldChunk.NO_OBJECT:
					dist[n] = d + 1
					q.append(n)

	func _sign_ok(i: int) -> bool:
		var x: int = i % SIZE
		var y: int = i / SIZE
		if x < 1 or y < 1 or x > LAST - 1 or y > LAST - 1:
			return false
		return _free(x, y, NATURAL_GROUND) and chunk.decor[i] < DECOR_PIECE_BASE

	# --- Villa: calles y huertos -----------------------------------------------------------------

	## Calle de cada casa: de la casilla bajo su vano (la fachada da al sur) a la plaza o a un
	## sendero, por el camino libre más corto (a lo sumo STREET_MAX pasos).
	func _place_streets() -> void:
		for obj: Dictionary in chunk.objects:
			if obj.kind != WorldChunk.ObjectKind.HOUSE:
				continue
			var cell: Vector2i = obj.cell
			var front_y: int = cell.y + (obj.size as Vector2i).y
			if front_y > LAST:
				continue
			for dx: int in [1, 2]:
				if _street_from(front_y * SIZE + cell.x + dx):
					break

	func _street_walk(i: int) -> bool:
		return _walk(i) and chunk.occupant[i] == WorldChunk.NO_OBJECT

	func _street_from(start: int) -> bool:
		if not _street_walk(start):
			return false
		var prev_of: Dictionary = {start: -1}
		var depth: Dictionary = {start: 0}
		var q := PackedInt32Array([start])
		var head: int = 0
		while head < q.size():
			var i: int = q[head]
			head += 1
			if chunk.ground[i] == WorldChunk.Ground.PLAZA or path[i] > 0:
				var c: int = prev_of[i]
				while c >= 0:
					if path[c] == 0:
						path[c] = PATH_W
					_pave(c, PATH_W)
					c = prev_of[c]
				return true
			if int(depth[i]) >= STREET_MAX:
				continue
			var x: int = i % SIZE
			for n: int in [i + SIZE if i < WorldChunk.CELLS - SIZE else -1, i - SIZE if i >= SIZE else -1,
					i - 1 if x > 0 else -1, i + 1 if x < LAST else -1]:
				if n >= 0 and not prev_of.has(n) and _street_walk(n):
					prev_of[n] = i
					depth[n] = int(depth[i]) + 1
					q.append(n)
		return false

	## Huerto de surcos (3×2, no bloquea) a un lado de algunas casas, con 1 casilla de hueco.
	func _place_huertos() -> void:
		var houses: Array[Dictionary] = chunk.objects_of(WorldChunk.ObjectKind.HOUSE)
		for obj: Dictionary in houses:
			var cell: Vector2i = obj.cell
			var size: Vector2i = obj.size
			var h: int = ChunkBuilder._ihash(coord.x * SIZE + cell.x, coord.y * SIZE + cell.y, seed_mix ^ SALT_VILLA)
			if (h % 1000) >= int(HUERTO_CHANCE * 1000.0):
				continue
			var west := Rect2i(cell.x - 1 - HUERTO_SIZE.x, cell.y + size.y - HUERTO_SIZE.y, HUERTO_SIZE.x, HUERTO_SIZE.y)
			var east := Rect2i(cell.x + size.x + 1, west.position.y, HUERTO_SIZE.x, HUERTO_SIZE.y)
			var order: Array[Rect2i] = [west, east]
			if (h >> 12) & 1 == 1:
				order = [east, west]
			for r: Rect2i in order:
				if _huerto_ok(r):
					for y: int in range(r.position.y, r.end.y):
						for x: int in range(r.position.x, r.end.x):
							chunk.decor[y * SIZE + x] = DECOR_PIECE_BASE + DecorPiece.HUERTO
					break

	func _huerto_ok(r: Rect2i) -> bool:
		if r.position.x < 1 or r.position.y < 1 or r.end.x > LAST or r.end.y > LAST:
			return false
		for y: int in range(r.position.y, r.end.y):
			for x: int in range(r.position.x, r.end.x):
				if not _free(x, y, NATURAL_GROUND) or chunk.decor[y * SIZE + x] != Decor.NONE:
					return false
		return true

	# --- Árboles: aspectos sin repetición, grande y secos ---------------------------------------

	## Aspecto (variante | volteo << 2, 0..7) de cada celda de la rejilla de árboles del chunk, con
	## ASPECT_PAD de margen. Es una función de la posición en el mundo, no de qué celdas tienen
	## árbol, así que casa entre chunks. Rechazo de repetición por clases de paridad (A, B, C, D):
	## A por hash; B evita sus 4 vecinas diagonales (A); C, sus 4 ortogonales (A y B); D, sus 4
	## ortogonales (A y B) y sus 4 diagonales (C). Dos vecinos ortogonales nunca repiten aspecto; dos
	## diagonales solo si los 8 vecinos de una D ya usan los 8 aspectos (rarísimo).
	func _tree_aspects() -> PackedByteArray:
		var w: int = GRID + 2 * ASPECT_PAD
		var asp := PackedByteArray()
		asp.resize(w * w)
		var gx0: int = coord.x * GRID - ASPECT_PAD
		var gy0: int = coord.y * GRID - ASPECT_PAD
		var salt: int = seed_mix ^ SALT_ASPECT
		var parity: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 1)]
		for cls: int in 4:
			var par: Vector2i = parity[cls]
			var j0: int = cls + ((par.y - (gy0 + cls)) & 1)
			var i0: int = cls + ((par.x - (gx0 + cls)) & 1)
			for j: int in range(j0, w - cls, 2):
				for i: int in range(i0, w - cls, 2):
					var k: int = j * w + i
					var mask: int = 0
					if cls == 1:
						mask = (1 << asp[k - w - 1]) | (1 << asp[k - w + 1]) | (1 << asp[k + w - 1]) | (1 << asp[k + w + 1])
					elif cls >= 2:
						mask = (1 << asp[k - 1]) | (1 << asp[k + 1]) | (1 << asp[k - w]) | (1 << asp[k + w])
						if cls == 3:
							var all: int = mask | (1 << asp[k - w - 1]) | (1 << asp[k - w + 1]) \
									| (1 << asp[k + w - 1]) | (1 << asp[k + w + 1])
							if all != 255:
								mask = all
					var a: int = ChunkBuilder._ihash(gx0 + i, gy0 + j, salt) & 7
					for t: int in 8:
						if (mask >> a) & 1 == 0:
							break
						a = (a + 1) & 7
					asp[k] = a
		return asp

	## Árbol grande 3×3 dentro del bosque (raro): ocupa 4 celdas de la rejilla con árbol.
	func _place_big_forest_tree(cand: PackedByteArray) -> void:
		var srng := RandomNumberGenerator.new()
		srng.seed = ChunkGenerator.hash_ints([plan.plan_seed, coord.x, coord.y, SALT_SMALL, 1])
		if srng.randf() >= float(decor_params.big_tree_chance):
			return
		for t: int in 16:
			var gx: int = srng.randi_range(1, GRID - 3)
			var gy: int = srng.randi_range(1, GRID - 3)
			var g: int = gy * GRID + gx
			if cand[g] == 1 and cand[g + 1] == 1 and cand[g + GRID] == 1 and cand[g + GRID + 1] == 1:
				for k: int in [g, g + 1, g + GRID, g + GRID + 1]:
					cand[k] = 0
				var cell := Vector2i(gx * 2, gy * 2)
				chunk.add_object(WorldChunk.ObjectKind.TREE_BIG, cell, Vector2i(3, 3), _flip_at(cell))
				return

	# --- Refugio --------------------------------------------------------------------------------

	## Casillas alcanzables desde el hub según `chunk.blocked` (en `reached`).
	func _flood_blocked() -> void:
		reached.resize(WorldChunk.CELLS)
		reached.fill(0)
		var start: int = WorldCoords.cell_index(chunk.hub)
		if chunk.blocked[start] == 1:
			return
		var q := PackedInt32Array()
		q.resize(WorldChunk.CELLS)
		q[0] = start
		reached[start] = 1
		var head: int = 0
		var tail: int = 1
		var blocked: PackedByteArray = chunk.blocked
		while head < tail:
			var i: int = q[head]
			head += 1
			var x: int = i % SIZE
			if x > 0 and reached[i - 1] == 0 and blocked[i - 1] == 0:
				reached[i - 1] = 1
				q[tail] = i - 1
				tail += 1
			if x < LAST and reached[i + 1] == 0 and blocked[i + 1] == 0:
				reached[i + 1] = 1
				q[tail] = i + 1
				tail += 1
			if i >= SIZE and reached[i - SIZE] == 0 and blocked[i - SIZE] == 0:
				reached[i - SIZE] = 1
				q[tail] = i - SIZE
				tail += 1
			if i < WorldChunk.CELLS - SIZE and reached[i + SIZE] == 0 and blocked[i + SIZE] == 0:
				reached[i + SIZE] = 1
				q[tail] = i + SIZE
				tail += 1

	## `near_trail`: casillas a ≤ REFUGE_TRAIL_REACH (Chebyshev) de un sendero, camino o calle.
	func _compute_near_trail() -> void:
		var r: int = REFUGE_TRAIL_REACH
		var rows := PackedInt32Array()
		rows.resize(WorldChunk.CELLS)
		for y: int in SIZE:
			var base: int = y * SIZE
			var count: int = 0
			for x: int in range(0, r + 1):
				count += 1 if path[base + x] > 0 else 0
			for x: int in SIZE:
				rows[base + x] = count
				if x + r + 1 < SIZE and path[base + x + r + 1] > 0:
					count += 1
				if x - r >= 0 and path[base + x - r] > 0:
					count -= 1
		near_trail.resize(WorldChunk.CELLS)
		for x: int in SIZE:
			var count: int = 0
			for y: int in range(0, r + 1):
				count += rows[y * SIZE + x]
			for y: int in SIZE:
				near_trail[y * SIZE + x] = 1 if count > 0 else 0
				if y + r + 1 < SIZE:
					count += rows[(y + r + 1) * SIZE + x]
				if y - r >= 0:
					count -= rows[(y - r) * SIZE + x]

	## Casillas (Chebyshev) entre la casilla y la huella del Nujio.
	func _nujio_gap(x: int, y: int) -> int:
		var n: Rect2i = chunk.nujio_rect
		var dx: int = maxi(0, maxi(n.position.x - x, x - (n.end.x - 1)))
		var dy: int = maxi(0, maxi(n.position.y - y, y - (n.end.y - 1)))
		return maxi(dx, dy)

	## Alguna casilla del rectángulo está a ≤ REFUGE_TRAIL_REACH de un sendero y, con `nujio`, todas
	## a ≤ REFUGE_NUJIO_REACH del Nujio. Con `trail` = false solo cuenta lo del Nujio.
	func _rect_near(r: Rect2i, nujio: bool, trail: bool = true) -> bool:
		var near: bool = not trail
		for y: int in range(r.position.y, r.end.y):
			for x: int in range(r.position.x, r.end.x):
				near = near or near_trail[y * SIZE + x] == 1
				if nujio and _nujio_gap(x, y) > REFUGE_NUJIO_REACH:
					return false
		return near

	## Acceso a un objeto: alguna casilla vecina (no las esquinas) que se pisa y se alcanza. 0 si una
	## de ellas tiene un suelo de `prefer`, 1 si solo otras, -1 si ninguna.
	func _access(cell: Vector2i, size: Vector2i, prefer: int) -> int:
		var best: int = -1
		var ring: Array[Vector2i] = []
		for x: int in range(cell.x, cell.x + size.x):
			ring.append(Vector2i(x, cell.y - 1))
			ring.append(Vector2i(x, cell.y + size.y))
		for y: int in range(cell.y, cell.y + size.y):
			ring.append(Vector2i(cell.x - 1, y))
			ring.append(Vector2i(cell.x + size.x, y))
		for c: Vector2i in ring:
			if c.x < 0 or c.y < 0 or c.x > LAST or c.y > LAST:
				continue
			var i: int = c.y * SIZE + c.x
			if chunk.blocked[i] == 0 and reached[i] == 1:
				if (prefer >> chunk.ground[i]) & 1 == 1:
					return 0
				best = 1
		return best

	## Refugio del chunk (reparto del RegionPlan, ADR 0006): cueva 2×2 en una cara de risco si
	## cumple las reglas de mundo-2.md §3 (a ≤ 6 de un sendero, alcanzable y, en un chunk de Nujio, a
	## ≤ 6 de su huella); si no, un árbol 2×2 del bosque pasa a árbol hueco; si no, un árbol hueco
	## nuevo en suelo libre. Último recurso: cualquier sitio alcanzable.
	func _place_refuge() -> void:
		if not plan.has_refuge(coord):
			return
		var refuge_rng := RandomNumberGenerator.new()
		refuge_rng.seed = ChunkGenerator.hash_ints([plan.plan_seed, coord.x, coord.y, SALT_REFUGE])
		_compute_near_trail()
		var nujio: bool = chunk.nujio_rect.size.x > 0
		if _place_cave(nujio, refuge_rng) or _hollow_existing(nujio, refuge_rng) \
				or _hollow_new(nujio, true, refuge_rng) or _hollow_new(nujio, false, refuge_rng) \
				or _hollow_new(false, false, refuge_rng):
			return
		push_warning("ChunkBuilder: chunk %s sin sitio para su refugio" % coord)

	## Cueva: 2 columnas de la base de una cara (con cara a los dos lados, para que la boca no dé a
	## otro nivel), sobre suelo seco, con la casilla de debajo del mismo nivel y alcanzable. La
	## fila de abajo (la boca) pasa a NONE y se pisa; la de arriba sigue siendo cara.
	func _place_cave(nujio: bool, r: RandomNumberGenerator) -> bool:
		var cands := PackedInt32Array()
		var face: int = WorldChunk.Cliff.FACE
		for y: int in range(1, LAST):
			for x: int in range(1, LAST - 2):
				var i: int = y * SIZE + x
				if chunk.cliff[i] != face or chunk.cliff[i + 1] != face or chunk.cliff[i - 1] != face or chunk.cliff[i + 2] != face:
					continue
				var aux: int = _aux(i)
				if aux != _len(i) - 1 or aux < 1 or _aux(i - 1) != aux or _aux(i + 1) != aux or _aux(i + 2) != aux:
					continue
				var b: int = i + SIZE
				if chunk.blocked[b] == 1 or chunk.blocked[b + 1] == 1 or reached[b] == 0 or reached[b + 1] == 0:
					continue
				if chunk.level[b] != chunk.level[i] or chunk.level[b + 1] != chunk.level[i]:
					continue
				if (NATURAL_GROUND >> chunk.ground[i]) & 1 == 0 or (NATURAL_GROUND >> chunk.ground[i + 1]) & 1 == 0:
					continue
				if not _rect_near(Rect2i(x, y, 2, 1), nujio):
					continue
				cands.append(i)
		if cands.is_empty():
			return false
		var at: int = cands[r.randi() % cands.size()]
		var rows: int = _len(at)
		for c: int in [at, at + 1]:
			chunk.cliff[c] = WorldChunk.Cliff.NONE
			chunk.variant[c] = 0
			chunk.blocked[c] = 0
			reached[c] = 1
			if chunk.decor[c + SIZE] == Decor.SHADOW_FOOT:
				chunk.decor[c + SIZE] = Decor.NONE
		var cell := Vector2i(at % SIZE, at / SIZE - 1)
		chunk.add_object(WorldChunk.ObjectKind.CAVE, cell, Vector2i(2, 2), 0 if rows == FACE_ROWS_PER_LEVEL else 1)
		return true

	func _hollow_existing(nujio: bool, r: RandomNumberGenerator) -> bool:
		var tiers: Array = [[], []]
		for k: int in chunk.objects.size():
			var obj: Dictionary = chunk.objects[k]
			if obj.kind != WorldChunk.ObjectKind.TREE:
				continue
			if not _rect_near(Rect2i(obj.cell, obj.size), nujio):
				continue
			var access: int = _access(obj.cell, obj.size, TRAIL_GROUND)
			if access >= 0:
				(tiers[access] as Array).append(k)
		for tier: Array in tiers:
			if tier.is_empty():
				continue
			var k: int = tier[r.randi() % tier.size()]
			var obj: Dictionary = chunk.objects[k]
			obj.kind = WorldChunk.ObjectKind.REFUGE_TREE
			obj.variant = (int(obj.variant) >> 2) & 1
			var cell: Vector2i = obj.cell
			for y: int in range(cell.y, cell.y + 2):
				for x: int in range(cell.x, cell.x + 2):
					chunk.blocked[y * SIZE + x] = 0
					reached[y * SIZE + x] = 1
			return true
		return false

	## Árbol hueco nuevo en 2×2 de suelo libre, con acceso. `trail`: a ≤ 6 de un sendero.
	func _hollow_new(nujio: bool, trail: bool, r: RandomNumberGenerator) -> bool:
		var area := Rect2i(1, 1, SIZE - 3, SIZE - 3)
		if nujio:
			area = chunk.nujio_rect.grow(REFUGE_NUJIO_REACH).intersection(area)
		var cands: Array[Vector2i] = []
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				var rect := Rect2i(x, y, 2, 2)
				var ok: bool = true
				for c: Vector2i in [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]:
					if not _free(c.x, c.y, NATURAL_GROUND) or chunk.decor[c.y * SIZE + c.x] >= DECOR_PIECE_BASE:
						ok = false
						break
				if not ok or not _rect_near(rect, nujio, trail):
					continue
				if _access(rect.position, rect.size, TRAIL_GROUND) < 0:
					continue
				cands.append(rect.position)
		if cands.is_empty():
			return false
		var cell: Vector2i = cands[r.randi() % cands.size()]
		chunk.add_object(WorldChunk.ObjectKind.REFUGE_TREE, cell, Vector2i(2, 2), _flip_at(cell))
		return true

	# --- Frutales -------------------------------------------------------------------------------

	## Frutales 2×2 (ADR 0006 "Frutales", ADR 0014 §7): entre per_chunk[0] y per_chunk[1] árboles
	## 2×2 del bosque pasan a FRUIT_TREE (clave = esquina noroeste), sin tocar el borde del chunk,
	## con una casilla vecina que se pisa y se alcanza (primero los que dan a un claro o un sendero)
	## y separados al menos min_spacing (Chebyshev entre esquinas noroeste).
	func _place_fruit() -> void:
		var id: int = plan.bosque_at(coord)
		if not ChunkGenerator.bosque_gives_fruit(plan.region_params, plan.bosques, id):
			return
		var params: Dictionary = ChunkGenerator.fruit_params(plan.region_params).merged(
				DEFAULT_CHUNK_FRUIT.merged(plan.region_params.get("chunk_fruit", {}), true), true)
		var range_n: Array = params.per_chunk
		var lo: int = int(range_n[0])
		var hi: int = maxi(lo, int(range_n[1]))
		var spacing: int = int(params.min_spacing)
		var frng := RandomNumberGenerator.new()
		frng.seed = ChunkGenerator.hash_ints([plan.plan_seed, coord.x, coord.y, SALT_FRUIT])
		var wanted: int = frng.randi_range(lo, hi)
		if wanted <= 0:
			return
		var open_ground: int = TRAIL_GROUND | (1 << WorldChunk.Ground.CLEARING)
		var pools: Array = [[], []]
		for k: int in chunk.objects.size():
			var obj: Dictionary = chunk.objects[k]
			if obj.kind != WorldChunk.ObjectKind.TREE:
				continue
			var cell: Vector2i = obj.cell
			if cell.x < 1 or cell.y < 1 or cell.x + 2 > LAST or cell.y + 2 > LAST:
				continue
			var access: int = _access(cell, obj.size, open_ground)
			if access >= 0:
				(pools[access] as Array).append(k)
		var picked: Array[Vector2i] = []
		for pool: Array in pools:
			for i: int in range(pool.size() - 1, 0, -1):
				var j: int = frng.randi_range(0, i)
				var tmp: int = pool[i]
				pool[i] = pool[j]
				pool[j] = tmp
			for k: int in pool:
				if picked.size() >= wanted:
					return
				var obj: Dictionary = chunk.objects[k]
				var c: Vector2i = obj.cell
				var far: bool = true
				for p: Vector2i in picked:
					if maxi(absi(p.x - c.x), absi(p.y - c.y)) < spacing:
						far = false
						break
				if far:
					picked.append(c)
					var v: int = obj.variant
					obj.kind = WorldChunk.ObjectKind.FRUIT_TREE
					obj.variant = (v & 1) | (((v >> 2) & 1) << 1)

	# --- Objetos pequeños que bloquean ----------------------------------------------------------

	## Bloquear la casilla no separa nada: sus vecinas ortogonales que se pisan siguen unidas por el
	## anillo de 8 vecinas (punto simple). Nunca en la primera ni en la última fila o columna.
	func _can_block(i: int) -> bool:
		var x: int = i % SIZE
		var y: int = i / SIZE
		if x < 1 or y < 1 or x > LAST - 1 or y > LAST - 1:
			return false
		var b: PackedByteArray = chunk.blocked
		# Anillo N, NE, E, SE, S, SW, W, NW (las pares son ortogonales).
		var ring: Array[int] = [i - SIZE, i - SIZE + 1, i + 1, i + SIZE + 1, i + SIZE, i + SIZE - 1, i - 1, i - SIZE - 1]
		var open: int = 0
		for k: int in 8:
			if b[ring[k]] == 0:
				open |= 1 << k
		if open == 255:
			return true
		var runs: int = 0
		for k: int in 8:
			if (open >> k) & 1 == 1 and (open >> ((k + 7) & 7)) & 1 == 0:
				var m: int = k
				var ortho: bool = false
				while (open >> m) & 1 == 1:
					ortho = ortho or m % 2 == 0
					m = (m + 1) & 7
				if ortho:
					runs += 1
		return runs <= 1

	## Casilla libre para un objeto pequeño: suelo de `ground_mask`, sin sendero, reservas, huerto
	## ni objetos interactivos o pequeños alrededor. `fringe`: además junto a un árbol del bosque.
	func _small_ok(i: int, fringe: bool, ground_mask: int) -> bool:
		var x: int = i % SIZE
		var y: int = i / SIZE
		if x < 1 or y < 1 or x > LAST - 1 or y > LAST - 1:
			return false
		if not _free(x, y, ground_mask) or no_tree[i] == 1 or chunk.blocked[i] == 1 or chunk.decor[i] >= DECOR_PIECE_BASE:
			return false
		var by_tree: bool = false
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var occ: int = chunk.occupant[i + dy * SIZE + dx]
				if occ == WorldChunk.NO_OBJECT:
					continue
				var obj: Dictionary = chunk.objects[occ]
				var kind: int = obj.kind
				if (INTERACTIVE >> kind) & 1 == 1 or kind == WorldChunk.ObjectKind.TREE_YOUNG \
						or kind == WorldChunk.ObjectKind.STUMP or kind == WorldChunk.ObjectKind.LOG \
						or (kind == WorldChunk.ObjectKind.ROCK and (obj.size as Vector2i).x == 1):
					return false
				by_tree = by_tree or kind == WorldChunk.ObjectKind.TREE or kind == WorldChunk.ObjectKind.TREE_DEAD
		return (by_tree or not fringe) and _can_block(i)

	func _add_small(kind: int, i: int, size: Vector2i, variant: int) -> void:
		chunk.add_object(kind, WorldCoords.index_to_cell(i), size, variant)
		for k: int in size.x:
			chunk.blocked[i + k] = 1
			reached[i + k] = 0

	## Árboles jóvenes 1×1 en el borde del bosque, tocones, troncos caídos 2×1 y rocas 1×1: raros,
	## bloquean y nunca cortan un paso (_can_block) ni tapan lo interactivo.
	func _place_small() -> void:
		var srng := RandomNumberGenerator.new()
		srng.seed = ChunkGenerator.hash_ints([plan.plan_seed, coord.x, coord.y, SALT_SMALL, 2])
		for t: int in int(decor_params.young_tries):
			var i: int = srng.randi_range(1, LAST - 1) + srng.randi_range(1, LAST - 1) * SIZE
			if _small_ok(i, true, TREE_GROUND):
				_add_small(WorldChunk.ObjectKind.TREE_YOUNG, i, Vector2i.ONE, srng.randi() & 3)
		var stumps: Array = decor_params.stumps
		for n: int in srng.randi_range(int(stumps[0]), int(stumps[1])):
			for t: int in 20:
				var i: int = srng.randi_range(1, LAST - 1) + srng.randi_range(1, LAST - 1) * SIZE
				if _small_ok(i, true, TREE_GROUND):
					_add_small(WorldChunk.ObjectKind.STUMP, i, Vector2i.ONE, srng.randi() & 3)
					break
		var rocks: Array = decor_params.small_rocks
		for n: int in srng.randi_range(int(rocks[0]), int(rocks[1])):
			for t: int in 20:
				var i: int = srng.randi_range(1, LAST - 1) + srng.randi_range(1, LAST - 1) * SIZE
				var rocky: bool = chunk.ground[i] == WorldChunk.Ground.ROCKY
				if (rocky or t >= 10) and _small_ok(i, not rocky, TREE_GROUND):
					_add_small(WorldChunk.ObjectKind.ROCK, i, Vector2i.ONE, srng.randi() & 1)
					break
		var logs: Array = decor_params.logs
		for n: int in srng.randi_range(int(logs[0]), int(logs[1])):
			for t: int in 20:
				var i: int = srng.randi_range(1, LAST - 2) + srng.randi_range(1, LAST - 1) * SIZE
				if not _small_ok(i, false, NATURAL_GROUND):
					continue
				chunk.blocked[i] = 1
				var ok: bool = _small_ok(i + 1, false, NATURAL_GROUND)
				chunk.blocked[i] = 0
				if ok:
					_add_small(WorldChunk.ObjectKind.LOG, i, Vector2i(2, 1), srng.randi() & 3)
					break

	# --- Hierba y decoración --------------------------------------------------------------------

	## Ruido del chunk en un bloque nativo (bytes 0-255 = -1..1), muestreado en world_cell.
	func _noise_block(salt: int, frequency: float) -> PackedByteArray:
		var noise: FastNoiseLite = ChunkGenerator._make_noise(ChunkGenerator.hash_ints([plan.plan_seed, salt]), frequency, 2)
		noise.offset = Vector3(coord.x * SIZE, coord.y * SIZE, 0.0)
		return noise.get_image(SIZE, SIZE, false, false, false).get_data()

	## Variante de hierba (A..D) por ruido de baja frecuencia: manchas grandes, nunca grano.
	func _paint_grass() -> void:
		var data: PackedByteArray = _noise_block(SALT_GRASS, float(decor_params.grass_frequency))
		var cuts: Array = decor_params.grass_cuts
		var c0: int = int(cuts[0])
		var c1: int = int(cuts[1])
		var c2: int = int(cuts[2])
		for i: int in WorldChunk.CELLS:
			if chunk.cliff[i] != WorldChunk.Cliff.NONE or chunk.ground[i] != WorldChunk.Ground.GRASS:
				continue
			var v: int = data[i]
			chunk.variant[i] = 0 if v < c0 else (1 if v < c1 else (2 if v < c2 else 3))

	## Se puede poner decoración: suelo natural sin risco, sin sendero, sin objeto, sin otra pieza
	## ni sombra (una sola pieza en la capa 2) y no justo debajo de una casa o del Nujio (sombra de
	## objeto).
	func _decor_ok(i: int) -> bool:
		if chunk.decor[i] != Decor.NONE or chunk.cliff[i] != WorldChunk.Cliff.NONE or path[i] > 0 \
				or chunk.occupant[i] != WorldChunk.NO_OBJECT or (DECOR_GROUND >> chunk.ground[i]) & 1 == 0:
			return false
		if i >= SIZE:
			var above: int = chunk.occupant[i - SIZE]
			if above != WorldChunk.NO_OBJECT:
				var kind: int = chunk.objects[above].kind
				if kind == WorldChunk.ObjectKind.HOUSE or kind == WorldChunk.ObjectKind.NUJIO:
					return false
		return true

	## Alguna de las 8 vecinas ya tiene pieza (muestreo de Poisson: nunca dos pegadas).
	func _decor_crowded(i: int) -> bool:
		var x: int = i % SIZE
		for dy: int in range(-1, 2):
			var row: int = i + dy * SIZE
			if row < 0 or row >= WorldChunk.CELLS:
				continue
			for dx: int in range(-1, 2):
				if (dx < 0 and x == 0) or (dx > 0 and x == LAST):
					continue
				if chunk.decor[row + dx] >= DECOR_PIECE_BASE:
					return true
		return false

	func _by_tree(i: int) -> bool:
		var x: int = i % SIZE
		for n: int in [i - SIZE, i + SIZE, i - 1 if x > 0 else -1, i + 1 if x < LAST else -1]:
			if n >= 0 and n < WorldChunk.CELLS and chunk.occupant[n] != WorldChunk.NO_OBJECT \
					and (TREE_KINDS >> chunk.objects[chunk.occupant[n]].kind) & 1 == 1:
				return true
		return false

	## Decoración que no bloquea (ADR 0014 §5 paso 6, spec §6.2): muestreo de Poisson (dardos con
	## el RNG del chunk, sin dos piezas vecinas) dentro de manchas de ruido de baja frecuencia; en
	## las praderas, flores por toda la huella. La familia sale del sitio: piedrecitas en el
	## pedregal; helechos, hojarasca, setas y raíces junto a los árboles (según la silueta del
	## Bosque); flores o matas en lo abierto según un segundo ruido, que también da el color de las
	## flores de cada mancha. Alrededor de cada flor, un borde de matas.
	func _place_decor() -> void:
		var patch: PackedByteArray = _noise_block(SALT_PATCH, float(decor_params.patch_frequency))
		var theme: PackedByteArray = _noise_block(SALT_THEME, float(decor_params.theme_frequency))
		var cut: int = int(decor_params.patch_cut)
		var drng := RandomNumberGenerator.new()
		drng.seed = ChunkGenerator.hash_ints([plan.plan_seed, coord.x, coord.y, SALT_DECOR])
		var floor_pieces: Array[int] = [DecorPiece.ROOT_PEEK, DecorPiece.ROOT_ARCH, DecorPiece.TUFT_LOW]
		var sbit: int = 1 << shape
		if NO_FERNS & sbit == 0:
			floor_pieces.append_array([DecorPiece.FERN_OPEN, DecorPiece.FERN_YOUNG])
		if NO_LEAVES & sbit == 0:
			floor_pieces.append_array([DecorPiece.LEAVES_LOOSE, DecorPiece.LEAVES_PILE])
		if NO_MUSHROOMS & sbit == 0:
			floor_pieces.append_array([DecorPiece.MUSHROOM_BIG, DecorPiece.MUSHROOM_RING])
		var stones: Array[int] = [DecorPiece.PEBBLES_TRIO, DecorPiece.PEBBLE_FLAT, DecorPiece.PEBBLES_GRAVEL]
		if shape == PlaceholderTileset.Shape.CACTUS:
			stones.append(DecorPiece.CRACK)
		var meadows: Array[Rect2i] = []
		for p: Dictionary in chunk.points:
			if p.kind == WorldChunk.PointKind.MEADOW:
				meadows.append(p.rect)
		var darts: int = int(decor_params.darts)
		var flowers := PackedInt32Array()
		var tries: Array[Vector2i] = []
		for m: Rect2i in meadows:
			tries.append(Vector2i(meadows.find(m), m.get_area() / 2))
		var total: int = darts
		for t: Vector2i in tries:
			total += t.y
		var meadow_at: int = 0
		var meadow_left: int = tries[0].y if not tries.is_empty() else 0
		for t: int in total:
			var i: int
			var meadow: bool = false
			if t < darts:
				i = drng.randi_range(0, WorldChunk.CELLS - 1)
				var cell := Vector2i(i % SIZE, i / SIZE)
				for m: Rect2i in meadows:
					meadow = meadow or m.has_point(cell)
			else:
				while meadow_left <= 0:
					meadow_at += 1
					meadow_left = tries[meadow_at].y
				meadow_left -= 1
				var m: Rect2i = meadows[meadow_at]
				i = drng.randi_range(m.position.y, m.end.y - 1) * SIZE + drng.randi_range(m.position.x, m.end.x - 1)
				meadow = true
			if not meadow and patch[i] <= cut:
				continue
			if not _decor_ok(i) or _decor_crowded(i):
				continue
			var piece: int
			var roll: int = drng.randi()
			if meadow:
				piece = (roll % 3) * 3 + clampi(theme[i] * 3 / 256, 0, 2)
			elif chunk.ground[i] == WorldChunk.Ground.ROCKY:
				piece = stones[roll % stones.size()] if roll % 10 < 7 else DecorPiece.TUFT_LOW + (roll >> 8) % 3
			elif _by_tree(i):
				piece = floor_pieces[roll % floor_pieces.size()]
			elif theme[i] > 140:
				piece = (roll % 3) * 3 + clampi((theme[i] - 141) * 3 / 115, 0, 2)
			elif roll % 10 < 8:
				piece = DecorPiece.TUFT_LOW + (roll >> 8) % 3
			else:
				piece = stones[(roll >> 8) % stones.size()]
			chunk.decor[i] = DECOR_PIECE_BASE + piece
			if piece <= DecorPiece.FLOWER_CARPET_3:
				flowers.append(i)
		var border: float = float(decor_params.flower_border)
		for i: int in flowers:
			var x: int = i % SIZE
			for dy: int in range(-1, 2):
				var row: int = i + dy * SIZE
				if row < 0 or row >= WorldChunk.CELLS:
					continue
				for dx: int in range(-1, 2):
					if (dx < 0 and x == 0) or (dx > 0 and x == LAST) or (dx == 0 and dy == 0):
						continue
					var n: int = row + dx
					if _decor_ok(n) and drng.randf() < border:
						chunk.decor[n] = DECOR_PIECE_BASE + DecorPiece.TUFT_LOW + drng.randi() % 3

	# --- Ayudas ----------------------------------------------------------------------------------

	## Risco de una casilla del chunk o de su margen (el margen, sin escaleras de los vecinos).
	func _cliff_at(x: int, y: int) -> int:
		if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
			return chunk.cliff[y * SIZE + x]
		return t_cliff[(y + 1) * TILE_W + x + 1]

	func _aux(i: int) -> int:
		return t_aux[(i / SIZE + 1) * TILE_W + i % SIZE + 1]

	func _len(i: int) -> int:
		return t_len[(i / SIZE + 1) * TILE_W + i % SIZE + 1]

	# Montículo binario de (distancia << 13 | casilla).
	func _push(i: int) -> void:
		var value: int = (dist[i] << 13) | i
		var k: int = heap_size
		heap_size += 1
		if heap_size > heap.size():
			heap.resize(heap_size * 2)
		while k > 0:
			var parent: int = (k - 1) >> 1
			if heap[parent] <= value:
				break
			heap[k] = heap[parent]
			k = parent
		heap[k] = value

	func _pop() -> int:
		var top: int = heap[0]
		heap_size -= 1
		var last: int = heap[heap_size]
		var k: int = 0
		while true:
			var child: int = 2 * k + 1
			if child >= heap_size:
				break
			if child + 1 < heap_size and heap[child + 1] < heap[child]:
				child += 1
			if heap[child] >= last:
				break
			heap[k] = heap[child]
			k = child
		heap[k] = last
		return top
