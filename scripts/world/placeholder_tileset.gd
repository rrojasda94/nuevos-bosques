class_name PlaceholderTileset
extends RefCounted
## Atlas del terreno de cada Bosque (forma de árbol, hojas, tronco y suelo según su estilo, ver
## BosqueMap.styles). Desde la 0.3 cada casilla sale del arte de pixel-artist (TerrainTileset:
## PNG de assets/tilesets/ recoloreados con el Bosque); si falta el PNG de un grupo, esa casilla
## se dibuja por código como en el placeholder original (paint_tile). El Nujio grande sigue
## siendo procedural (nujio_texture). Solo usa colores de assets/palettes/palette_nuevos_bosques.gpl.
## Atlas: columna = ChunkData.Tile, fila = variante (ver variant_for). Las casillas de agua tienen
## un segundo fotograma de animación en la columna tile + Tile.size().

const TILE: int = 16
## Filas del atlas: 16 máscaras de borde x 2 variantes (ver variant_for).
const VARIANTS: int = 32
## Bits de la máscara de borde de variant_for: lado cuyo vecino es "de fuera".
const EDGE_N: int = 1
const EDGE_E: int = 2
const EDGE_S: int = 4
const EDGE_W: int = 8
## Agua animada: fotogramas y velocidad (fotogramas por segundo).
const ANIMATED_TILES: Array[int] = [ChunkData.Tile.RIVER_NARROW, ChunkData.Tile.RIVER_NAVIGABLE, ChunkData.Tile.FORD]
const ANIM_FRAMES: int = 2
const WATER_FPS: float = 2.0
## Vecinos que dibujan hierba en el borde de senderos, caminos y claros.
const SOFT_TILES: Array[int] = [
	ChunkData.Tile.GRASS, ChunkData.Tile.TREE, ChunkData.Tile.FRUIT_TREE, ChunkData.Tile.ROCKY, ChunkData.Tile.CLIFF,
]
## Lo que cuenta como agua para las orillas.
const WATER_TILES: Array[int] = [
	ChunkData.Tile.RIVER_NARROW, ChunkData.Tile.RIVER_NAVIGABLE, ChunkData.Tile.FORD, ChunkData.Tile.BRIDGE,
]

# Paleta (Endesga 32).
const OUTLINE := Color("181425")
const GREEN_DARKEST := Color("193c3e")
const GREEN_DARK := Color("265c42")
const GREEN := Color("3e8948")
const GREEN_LIGHT := Color("63c74d")
const YELLOW := Color("fee761")
const WHITE := Color("ffffff")
const BROWN := Color("b86f50")
const BROWN_LIGHT := Color("e4a672")
const BROWN_DARK := Color("733e39")
const BLUE_DARK := Color("124e89")
const BLUE := Color("0099db")
const CYAN := Color("2ce8f5")
const SAND := Color("ead4aa")
const GREY_LIGHTEST := Color("c0cbdc")
const GREY_LIGHT := Color("8b9bb4")
const GREY := Color("5a6988")
const GREY_DARK := Color("3a4466")
const BLACKISH := Color("262b44")
const ROOF := Color("be4a2f")
const DOOR := Color("3e2731")

## Frutos: [color, sombra] candidatos (de la paleta), en orden de preferencia: rojo, amarillo,
## naranja, magenta, blanco y azul. Ver fruit_color.
const FRUIT_COLORS: Array = [
	[Color("e43b44"), Color("a22633")], [Color("fee761"), Color("feae34")], [Color("f77622"), Color("be4a2f")],
	[Color("b55088"), Color("68386c")], [Color("ffffff"), Color("c0cbdc")], [Color("0099db"), Color("124e89")],
]
## Frutos por árbol y separación mínima entre ellos (píxeles).
const FRUIT_CONTRAST: float = 0.5
const FRUITS_PER_TREE: int = 4
const FRUIT_SPACING: int = 4
## Las filas 0-1 del frutal tienen fruto; sumando esto (filas 2-3) se dibuja vaciado.
const FRUIT_EMPTY_VARIANT: int = 2

enum Shape { ROUND, CONIFER, PALM, CACTUS, THORNY, WILLOW }
const SHAPE_COUNT: int = 6
const SHAPE_NAMES: Array[String] = ["copa redonda", "conífera", "palmera", "cactus", "espinoso", "sauce"]

## Hojas: [oscuro, claro]. Todas de la paleta.
const LEAVES: Array = [
	[Color("265c42"), Color("3e8948")], [Color("3e8948"), Color("63c74d")],
	[Color("124e89"), Color("0099db")], [Color("0099db"), Color("2ce8f5")],
	[Color("68386c"), Color("b55088")], [Color("b55088"), Color("f6757a")],
	[Color("a22633"), Color("e43b44")], [Color("be4a2f"), Color("f77622")],
	[Color("feae34"), Color("fee761")], [Color("8b9bb4"), Color("ffffff")],
	[Color("3a4466"), Color("5a6988")], [Color("733e39"), Color("b86f50")],
]
const TRUNKS: Array = [
	Color("733e39"), Color("3e2731"), Color("ffffff"), Color("f77622"),
	Color("c0cbdc"), Color("262b44"), Color("e8b796"), Color("a22633"),
]
## Suelo: [hierba, motas de hierba, claro, motas de claro, sombra de la hierba].
const GROUNDS: Array = [
	[Color("3e8948"), Color("63c74d"), Color("63c74d"), Color("3e8948"), Color("265c42")],
	[Color("265c42"), Color("3e8948"), Color("3e8948"), Color("63c74d"), Color("193c3e")],
	[Color("e4a672"), Color("ead4aa"), Color("ead4aa"), Color("e4a672"), Color("c28569")],
	[Color("c28569"), Color("e8b796"), Color("e8b796"), Color("c28569"), Color("b86f50")],
]


static func make_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	return tile_set



## Atlas de un Bosque con estilo `style` (ver BosqueMap.styles).
static func make_source(style: Dictionary) -> TileSetAtlasSource:
	var count: int = ChunkData.Tile.size()
	var image := Image.create(TILE * count * ANIM_FRAMES, TILE * VARIANTS, false, Image.FORMAT_RGBA8)
	for tile: int in count:
		var frames: int = ANIM_FRAMES if ANIMATED_TILES.has(tile) else 1
		for variant: int in VARIANTS:
			for frame: int in frames:
				var o := Vector2i((tile + frame * count) * TILE, variant * TILE)
				if not TerrainTileset.paint(image, tile, variant, o, style, frame):
					paint_tile(image, tile, legacy_variant(tile, variant) + frame, o, style)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(TILE, TILE)
	for tile: int in count:
		for variant: int in VARIANTS:
			source.create_tile(Vector2i(tile, variant))
	for tile: int in ANIMATED_TILES:
		for variant: int in VARIANTS:
			var at := Vector2i(tile, variant)
			source.set_tile_animation_separation(at, Vector2i(count - 1, 0))
			source.set_tile_animation_frames_count(at, ANIM_FRAMES)
			source.set_tile_animation_speed(at, WATER_FPS)
	return source


## Textura del Nujio: la misma silueta y paleta del Bosque, a tamaño n x n casillas.
static func nujio_texture(style: Dictionary, n: int) -> Texture2D:
	return ImageTexture.create_from_image(_tree_image(style, n * TILE, false))


## Variante visual de la casilla `cell` del chunk (fila del atlas):
## - Senderos, caminos, claros, plaza y riscos: máscara de borde (EDGE_*) + 16 x (0 o 1).
## - Agua y vado: máscara de orillas. Puente: orientación (0 norte-sur, 1 este-oeste) + 2 x (0 o 1).
## - Hierba, pedregal y árbol: 0-3. Frutal: 0-1 (exploration suma FRUIT_EMPTY_VARIANT si está vacío).
## - Edificio: material de la villa x 16 + techo (0-7) o fachada (8-11 con ventanas, 12-15 con vano).
## - Letrero: dirección de la flecha + 8 x fondo (TerrainTileset.SignGround). `sign_dir` = índice de
##   dirección hacia la villa del Bosque (orden de ChunkGenerator.direction_name); el letrero hacia
##   la villa natal usa su propia dirección (ChunkData.home_direction).
## - Refugio: cueva (1) si toca roca y árbol hueco (0) si no.
## Fuera del chunk se supone la misma casilla (sin borde).
static func variant_for(chunk: ChunkData, cell: Vector2i, sign_dir: int) -> int:
	var tile: int = chunk.get_tile(cell)
	var world: Vector2i = chunk.coord * ChunkData.SIZE + cell
	var alt: int = ChunkGenerator.hash_ints([world.x, world.y])
	match tile:
		ChunkData.Tile.CLIFF:
			return _edge_mask(chunk, cell, [ChunkData.Tile.CLIFF], false) + 16 * (alt % 2)
		ChunkData.Tile.PATH, ChunkData.Tile.ROAD, ChunkData.Tile.CLEARING:
			return _edge_mask(chunk, cell, SOFT_TILES, true) + 16 * (alt % 2)
		ChunkData.Tile.PLAZA:
			return _edge_mask(chunk, cell, [ChunkData.Tile.PLAZA, ChunkData.Tile.NUJIO], false) + 16 * (alt % 2)
		ChunkData.Tile.RIVER_NARROW, ChunkData.Tile.RIVER_NAVIGABLE, ChunkData.Tile.FORD:
			return _edge_mask(chunk, cell, WATER_TILES, false)
		ChunkData.Tile.BRIDGE:
			var ns: bool = _is(chunk, cell + Vector2i.UP, WATER_TILES) or _is(chunk, cell + Vector2i.DOWN, WATER_TILES)
			var ew: bool = _is(chunk, cell + Vector2i.LEFT, WATER_TILES) or _is(chunk, cell + Vector2i.RIGHT, WATER_TILES)
			return (1 if ns and not ew else 0) + 2 * (alt % 2)
		ChunkData.Tile.BUILDING:
			return _building_variant(chunk, cell)
		ChunkData.Tile.SIGN:
			var dir: int = sign_dir
			if chunk.sign_kind(cell) == ChunkData.SignKind.HOME_VILLA:
				dir = ChunkGenerator.direction_index(chunk.home_direction)
			return dir + 8 * _sign_ground(chunk, cell)
		ChunkData.Tile.REFUGE:
			for d: Vector2i in ChunkData.SIDES:
				var n: Vector2i = cell + d
				if ChunkData.in_bounds(n) and (chunk.get_tile(n) == ChunkData.Tile.CLIFF or chunk.get_tile(n) == ChunkData.Tile.ROCKY):
					return 1
			return 0
		ChunkData.Tile.GRASS, ChunkData.Tile.ROCKY, ChunkData.Tile.TREE:
			return alt % 4
		ChunkData.Tile.NUJIO:
			return 0
	return alt % 2


## Variante del dibujo procedural (el placeholder original) que corresponde a la fila `variant`
## del atlas: se usa cuando falta el PNG del grupo.
static func legacy_variant(tile: int, variant: int) -> int:
	match tile:
		ChunkData.Tile.CLIFF:
			var m: int = variant % 16
			return (1 if m & EDGE_S else 0) | (2 if m & EDGE_N else 0)
		ChunkData.Tile.BUILDING:
			return 0 if variant % 16 < 8 else 1
		ChunkData.Tile.SIGN:
			return variant % 8
		ChunkData.Tile.FRUIT_TREE:
			return variant % 4
		ChunkData.Tile.PATH, ChunkData.Tile.ROAD, ChunkData.Tile.CLEARING, ChunkData.Tile.PLAZA:
			return (variant / 16) % 2
	return variant % 2


## Bits EDGE_* de los lados cuyo vecino está (`edge_if_in`) o no está en `tiles`.
static func _edge_mask(chunk: ChunkData, cell: Vector2i, tiles: Array[int], edge_if_in: bool) -> int:
	var mask: int = 0
	var sides: Array = [[Vector2i.UP, EDGE_N], [Vector2i.RIGHT, EDGE_E], [Vector2i.DOWN, EDGE_S], [Vector2i.LEFT, EDGE_W]]
	for side: Array in sides:
		var n: Vector2i = cell + side[0]
		if not ChunkData.in_bounds(n):
			continue
		if tiles.has(chunk.get_tile(n)) == edge_if_in:
			mask |= int(side[1])
	return mask


static func _is(chunk: ChunkData, cell: Vector2i, tiles: Array[int]) -> bool:
	return ChunkData.in_bounds(cell) and tiles.has(chunk.get_tile(cell))


static func _is_building(chunk: ChunkData, cell: Vector2i) -> bool:
	return ChunkData.in_bounds(cell) and chunk.get_tile(cell) == ChunkData.Tile.BUILDING


## Techo o fachada según haya edificio debajo; material (barro o piedra) igual en toda la villa.
## La fachada lleva un vano sin puerta en su casilla central (la izquierda si son 2) y ventanitas
## en las demás.
static func _building_variant(chunk: ChunkData, cell: Vector2i) -> int:
	var material: int = ChunkGenerator.hash_ints([chunk.coord.x, chunk.coord.y, 77]) % 2
	var east: bool = not _is_building(chunk, cell + Vector2i.RIGHT)
	var west: bool = not _is_building(chunk, cell + Vector2i.LEFT)
	if _is_building(chunk, cell + Vector2i.DOWN):
		var north: bool = not _is_building(chunk, cell + Vector2i.UP)
		return material * 16 + (1 if north else 0) + (2 if east else 0) + (4 if west else 0)
	var left: int = cell.x
	while _is_building(chunk, Vector2i(left - 1, cell.y)):
		left -= 1
	var right: int = cell.x
	while _is_building(chunk, Vector2i(right + 1, cell.y)):
		right += 1
	var door: bool = cell.x - left == (right - left) / 2
	return material * 16 + (12 if door else 8) + (1 if east else 0) + (2 if west else 0)


## Fondo del letrero: camino si está en medio del camino, sendero si toca uno, hierba si no.
static func _sign_ground(chunk: ChunkData, cell: Vector2i) -> int:
	var road: Array[int] = [ChunkData.Tile.ROAD]
	if (_is(chunk, cell + Vector2i.LEFT, road) and _is(chunk, cell + Vector2i.RIGHT, road)) \
			or (_is(chunk, cell + Vector2i.UP, road) and _is(chunk, cell + Vector2i.DOWN, road)):
		return TerrainTileset.SignGround.ROAD
	var path: Array[int] = [ChunkData.Tile.PATH, ChunkData.Tile.BRIDGE]
	for d: Vector2i in ChunkData.SIDES:
		if _is(chunk, cell + d, path):
			return TerrainTileset.SignGround.PATH
	return TerrainTileset.SignGround.GRASS


## Dibujo procedural (el placeholder original) de la casilla `tile` con su variante antigua
## (legacy_variant). Solo se usa si falta el PNG del grupo.
static func paint_tile(image: Image, tile: int, variant: int, o: Vector2i, style: Dictionary) -> void:
	var ground: Array = GROUNDS[int(style.get("ground", 0))]
	var v2: int = variant % 2
	var salt: int = tile * 10 + v2
	var full := Rect2i(o, Vector2i(TILE, TILE))
	match tile:
		ChunkData.Tile.GRASS:
			image.fill_rect(full, ground[0])
			_specks(image, o, ground[1], 7, salt)
		ChunkData.Tile.CLEARING, ChunkData.Tile.NUJIO:
			image.fill_rect(full, ground[2])
			_specks(image, o, ground[3], 4, salt)
			if v2 == 1:
				_specks(image, o, YELLOW, 2, salt + 100)
		ChunkData.Tile.PATH:
			image.fill_rect(full, BROWN)
			_specks(image, o, BROWN_LIGHT, 6, salt)
			_specks(image, o, BROWN_DARK, 4, salt + 100)
		ChunkData.Tile.TREE:
			image.fill_rect(full, ground[0])
			_specks(image, o, ground[1], 3, salt)
			var tree: Image = _tree_image(style, TILE, v2 == 1)
			image.blend_rect(tree, Rect2i(0, 0, TILE, TILE), o)
		ChunkData.Tile.FRUIT_TREE:
			image.fill_rect(full, ground[0])
			_specks(image, o, ground[1], 3, salt)
			image.blend_rect(_fruit_tree_image(style, v2 == 1, variant < FRUIT_EMPTY_VARIANT), Rect2i(0, 0, TILE, TILE), o)
		ChunkData.Tile.ROCKY:
			image.fill_rect(full, ground[0])
			_specks(image, o, GREY, 8, salt)
			_specks(image, o, GREY_LIGHT, 5, salt + 100)
		ChunkData.Tile.CLIFF:
			_paint_cliff(image, o, variant & 3)
		ChunkData.Tile.RIVER_NARROW:
			_water(image, o, v2, BLUE, CYAN)
		ChunkData.Tile.RIVER_NAVIGABLE:
			_water(image, o, v2, BLUE_DARK, BLUE)
			_specks(image, o, GREY_DARK, 3, salt)
		ChunkData.Tile.FORD:
			_water(image, o, v2, BLUE, CYAN)
			for i: int in 5:
				var h: int = ChunkGenerator.hash_ints([salt, i, 7])
				var p := Vector2i(1 + h % 12, 1 + (h >> 8) % 12)
				image.fill_rect(Rect2i(o + p, Vector2i(3, 2)), GREY_LIGHT)
				image.set_pixelv(o + p + Vector2i(1, 1), GREY)
		ChunkData.Tile.BRIDGE:
			image.fill_rect(full, BLUE_DARK)
			image.fill_rect(Rect2i(o.x + 2, o.y, TILE - 4, TILE), BROWN)
			for y: int in range(0, TILE, 4):
				image.fill_rect(Rect2i(o.x + 2, o.y + y, TILE - 4, 1), BROWN_DARK)
			image.fill_rect(Rect2i(o.x + 2, o.y, 1, TILE), BROWN_DARK)
			image.fill_rect(Rect2i(o.x + TILE - 3, o.y, 1, TILE), BROWN_DARK)
		ChunkData.Tile.PLAZA:
			image.fill_rect(full, GREY_LIGHTEST)
			for y: int in range(0, TILE, 5):
				image.fill_rect(Rect2i(o.x, o.y + y, TILE, 1), GREY_LIGHT)
			for x: int in range(2 + v2 * 3, TILE, 6):
				image.fill_rect(Rect2i(o.x + x, o.y, 1, TILE), GREY_LIGHT)
		ChunkData.Tile.BUILDING:
			if v2 == 0:
				image.fill_rect(full, ROOF)
				for y: int in range(1, TILE, 4):
					image.fill_rect(Rect2i(o.x, o.y + y, TILE, 1), BROWN_DARK)
			else:
				image.fill_rect(full, SAND)
				image.fill_rect(Rect2i(o.x, o.y, TILE, 3), BROWN_DARK)
				image.fill_rect(Rect2i(o.x + 5, o.y + 7, 6, 9), DOOR)
				image.fill_rect(Rect2i(o.x, o.y + TILE - 1, TILE, 1), BROWN_DARK)
		ChunkData.Tile.SIGN:
			image.fill_rect(full, BROWN)
			_specks(image, o, BROWN_LIGHT, 4, salt)
			_paint_sign(image, o, variant)
		ChunkData.Tile.ROAD:
			# Tierra apisonada clara con rodadas y guijarros: se distingue del sendero (marrón).
			image.fill_rect(full, SAND)
			_specks(image, o, BROWN_LIGHT, 10, salt)
			_specks(image, o, GREY_LIGHT, 3, salt + 100)
			image.fill_rect(Rect2i(o.x + 4, o.y, 1, TILE), BROWN_LIGHT)
			image.fill_rect(Rect2i(o.x + 11, o.y, 1, TILE), BROWN_LIGHT)
			for y: int in range(v2 * 3, TILE, 6):
				image.set_pixel(o.x + 4, o.y + y, BROWN)
				image.set_pixel(o.x + 11, o.y + (y + 2) % TILE, BROWN)
		ChunkData.Tile.REFUGE:
			if v2 == 1:
				_paint_cave(image, o, ground)
			else:
				_paint_hollow_tree(image, o, ground, style)


## Roca con cara de sombra al sur (bit 0) y borde iluminado al norte (bit 1). Los bordes de
## sombra y luz son irregulares para que no se lean como un muro recto.
static func _paint_cliff(image: Image, o: Vector2i, bits: int) -> void:
	image.fill_rect(Rect2i(o, Vector2i(TILE, TILE)), GREY)
	_specks(image, o, GREY_LIGHT, 10, 501 + bits)
	_specks(image, o, GREY_DARK, 8, 601 + bits)
	# Grietas diagonales cortas.
	for i: int in 3:
		var h: int = ChunkGenerator.hash_ints([701 + bits, i])
		var p := Vector2i(h % 13, (h >> 8) % 10)
		for k: int in 3:
			image.set_pixelv(o + p + Vector2i(k, k), BLACKISH)
	if bits & 2:
		for x: int in TILE:
			var depth: int = 1 + ChunkGenerator.hash_ints([801, x]) % 3
			image.fill_rect(Rect2i(o.x + x, o.y, 1, depth), GREY_LIGHTEST)
	if bits & 1:
		for x: int in TILE:
			var top: int = 7 + ChunkGenerator.hash_ints([901, x]) % 4
			image.fill_rect(Rect2i(o.x + x, o.y + top, 1, TILE - top), GREY_DARK)
			image.set_pixel(o.x + x, o.y + top, OUTLINE)
			if x % 3 == 0:
				image.fill_rect(Rect2i(o.x + x, o.y + top + 2, 1, TILE - top - 2), BLACKISH)


## Árbol hueco: tronco ancho con la copa del Bosque y una boca oscura en arco al pie.
static func _paint_hollow_tree(image: Image, o: Vector2i, ground: Array, style: Dictionary) -> void:
	var leaf: Array = LEAVES[int(style.get("leaf", 0))]
	var trunk: Color = TRUNKS[int(style.get("trunk", 0))]
	image.fill_rect(Rect2i(o, Vector2i(TILE, TILE)), ground[0])
	# Copa con contorno, sobresale por los lados del tronco.
	for y: int in range(0, 8):
		for x: int in TILE:
			var d: float = Vector2(x - 7.5, (y - 3.5) * 1.5).length()
			if d < 7.9:
				var color: Color = OUTLINE if d > 6.9 else (leaf[1] if d < 3.8 and x < 8 else leaf[0])
				image.set_pixel(o.x + x, o.y + y, color)
	# Tronco ancho con contorno y raíces abiertas al pie.
	image.fill_rect(Rect2i(o.x + 3, o.y + 6, 10, 10), OUTLINE)
	image.fill_rect(Rect2i(o.x + 4, o.y + 6, 8, 10), trunk)
	image.fill_rect(Rect2i(o.x + 1, o.y + 14, 14, 2), OUTLINE)
	image.fill_rect(Rect2i(o.x + 2, o.y + 14, 12, 1), trunk)
	image.fill_rect(Rect2i(o.x + 4, o.y + 7, 1, 7), BROWN_DARK)
	# Boca del hueco: arco negro con borde oscuro.
	for y: int in range(8, 16):
		for x: int in range(5, 11):
			var r: float = Vector2(x - 7.5, maxf(0.0, 11.0 - y) * 1.2).length()
			if r < 3.2:
				image.set_pixel(o.x + x, o.y + y, OUTLINE if r < 2.4 else DOOR)
	image.set_pixel(o.x + 4, o.y + 9, BROWN_DARK)
	image.set_pixel(o.x + 11, o.y + 12, BROWN_DARK)


## Cueva: roca redondeada con una boca negra en arco.
static func _paint_cave(image: Image, o: Vector2i, ground: Array) -> void:
	image.fill_rect(Rect2i(o, Vector2i(TILE, TILE)), ground[0])
	for y: int in TILE:
		for x: int in TILE:
			var d: float = Vector2(x - 7.5, (y - 10.0) * 1.1).length()
			if d < 8.5 and y >= 1:
				image.set_pixel(o.x + x, o.y + y, GREY_DARK if d > 7.2 else (GREY_LIGHT if y < 6 else GREY))
	for y: int in range(7, 16):
		for x: int in range(3, 13):
			var r: float = Vector2(x - 7.5, maxf(0.0, 11.0 - y) * 1.1).length()
			if r < 4.2:
				image.set_pixel(o.x + x, o.y + y, OUTLINE if r < 3.3 else BLACKISH)


static func _paint_sign(image: Image, o: Vector2i, dir_index: int) -> void:
	# Piedra.
	for y: int in range(2, 15):
		for x: int in range(3, 13):
			var d: float = Vector2(x - 7.5, (y - 8.5) * 0.8).length()
			if d <= 5.0:
				image.set_pixel(o.x + x, o.y + y, GREY_LIGHT if d < 4.2 else GREY_DARK)
	# Flecha en la dirección (0 = este, sentido horario, como ChunkGenerator.direction_name).
	var angle: float = dir_index * PI / 4.0
	var dir := Vector2(cos(angle), sin(angle))
	var c := Vector2(7.5, 8.0)
	for i: int in range(-3, 4):
		var p: Vector2 = c + dir * i
		image.set_pixel(o.x + roundi(p.x), o.y + roundi(p.y), DOOR)
	var tip: Vector2 = c + dir * 3.0
	for side: float in [-1.0, 1.0]:
		var wing: Vector2 = tip - dir.rotated(side * PI / 4.0) * 2.0
		image.set_pixel(o.x + roundi(wing.x), o.y + roundi(wing.y), DOOR)


static func _water(image: Image, o: Vector2i, variant: int, base: Color, wave: Color) -> void:
	image.fill_rect(Rect2i(o, Vector2i(TILE, TILE)), base)
	var shift: int = variant * 5
	for i: int in 3:
		var y: int = (3 + i * 5 + variant * 2) % TILE
		var x0: int = (2 + i * 6 + shift) % (TILE - 4)
		for dx: int in 4:
			image.set_pixel(o.x + x0 + dx, o.y + y, wave)


## Puntos sueltos en posiciones fijas derivadas de `salt` (decorativo, determinista).
static func _specks(image: Image, o: Vector2i, color: Color, count: int, salt: int) -> void:
	for i: int in count:
		var h: int = ChunkGenerator.hash_ints([salt, i])
		image.set_pixelv(o + Vector2i(h % TILE, (h >> 8) % TILE), color)


## Árbol de `px` x `px` píxeles con fondo transparente y contorno.
static func _tree_image(style: Dictionary, px: int, mirror: bool) -> Image:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var leaf: Array = LEAVES[int(style.get("leaf", 0))]
	var trunk: Color = TRUNKS[int(style.get("trunk", 0))]
	var colors: Array = [Color(0, 0, 0, 0), leaf[0], leaf[1], trunk]
	var shape: int = int(style.get("shape", 0))
	for y: int in px:
		for x: int in px:
			var u: float = (x + 0.5) / px
			var v: float = (y + 0.5) / px
			if mirror:
				u = 1.0 - u
			var k: int = _shape_pixel(shape, u, v)
			if k > 0:
				img.set_pixel(x, y, colors[k])
	var filled := img.duplicate() as Image
	for y: int in px:
		for x: int in px:
			if filled.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in ChunkData.SIDES:
				var p := Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < px and p.y < px and filled.get_pixelv(p).a > 0.0:
					img.set_pixel(x, y, OUTLINE)
					break
	return img


## Colores de fruto del Bosque ([color, sombra]): el primer par de FRUIT_COLORS (en orden de
## preferencia) que se aleja al menos FRUIT_CONTRAST (RGB) de sus dos colores de hoja; si ninguno
## llega, el que más se aleja.
static func fruit_color(style: Dictionary) -> Array:
	var leaf: Array = LEAVES[int(style.get("leaf", 0))]
	var best: Array = FRUIT_COLORS[0]
	var best_d: float = -1.0
	for pair: Array in FRUIT_COLORS:
		var d: float = minf(_rgb_distance(pair[0], leaf[0]), _rgb_distance(pair[0], leaf[1]))
		if d >= FRUIT_CONTRAST:
			return pair
		if d > best_d:
			best_d = d
			best = pair
	return best


static func _rgb_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## Frutal: el árbol del Bosque (misma silueta y colores) con frutos de 2x2 sobre las hojas.
## Sin fruto (`ripe` = false) quedan solo los rabillos, para que se reconozca como frutal.
static func _fruit_tree_image(style: Dictionary, mirror: bool, ripe: bool) -> Image:
	var img: Image = _tree_image(style, TILE, mirror)
	var leaf: Array = LEAVES[int(style.get("leaf", 0))]
	var fruit: Array = fruit_color(style)
	for p: Vector2i in fruit_spots(img, leaf):
		img.set_pixelv(p + Vector2i(0, -1), BROWN_DARK)
		if ripe:
			img.fill_rect(Rect2i(p, Vector2i(2, 2)), fruit[0])
			img.set_pixelv(p + Vector2i(1, 1), fruit[1])
	return img


## Hasta FRUITS_PER_TREE esquinas de bloques 2x2 de hoja (con hoja también encima, para el
## rabillo), separados FRUIT_SPACING píxeles. Orden fijo por hash: determinista. Las siluetas de
## hojas finas (palmera) no tienen bloques así: entonces vale cualquier 2x2 opaco que toque hoja
## en la mitad alta del árbol (frutos colgando de la copa).
static func fruit_spots(img: Image, leaf: Array) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = _fruit_candidates(img, leaf, true)
	if candidates.size() < 2:
		candidates = _fruit_candidates(img, leaf, false)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return ChunkGenerator.hash_ints([a.x, a.y, 41]) < ChunkGenerator.hash_ints([b.x, b.y, 41]))
	var spots: Array[Vector2i] = []
	for c: Vector2i in candidates:
		if spots.size() >= FRUITS_PER_TREE:
			break
		var far: bool = true
		for s: Vector2i in spots:
			if maxi(absi(s.x - c.x), absi(s.y - c.y)) < FRUIT_SPACING:
				far = false
				break
		if far:
			spots.append(c)
	return spots


static func _fruit_candidates(img: Image, leaf: Array, strict: bool) -> Array[Vector2i]:
	var size: Vector2i = img.get_size()
	var out: Array[Vector2i] = []
	for y: int in range(1, size.y - 1):
		for x: int in range(0, size.x - 1):
			if not strict and y > size.y * 0.6:
				continue
			var leaves: int = 0
			var ok: bool = true
			for k: Vector2i in [Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var c: Color = img.get_pixelv(Vector2i(x, y) + k)
				var is_leaf: bool = c == leaf[0] or c == leaf[1]
				leaves += 1 if is_leaf else 0
				if (strict and not is_leaf) or c.a == 0.0:
					ok = false
					break
			if ok and leaves > 0:
				out.append(Vector2i(x, y))
	return out


## 0 = vacío, 1 = hoja oscura, 2 = hoja clara, 3 = tronco. (u, v) en [0, 1], v hacia abajo.
static func _shape_pixel(shape: int, u: float, v: float) -> int:
	var p := Vector2(u, v)
	match shape:
		Shape.ROUND:
			if p.distance_to(Vector2(0.5, 0.42)) < 0.38:
				return 2 if p.distance_to(Vector2(0.38, 0.3)) < 0.14 else 1
			if absf(u - 0.5) < 0.09 and v > 0.6 and v < 0.95:
				return 3
		Shape.CONIFER:
			if v > 0.04 and v < 0.8:
				var tier: float = fmod((v - 0.04) * 3.0, 1.0)
				var hw: float = 0.05 + 0.42 * tier * (0.45 + 0.55 * (v - 0.04) / 0.76)
				if absf(u - 0.5) < hw:
					return 2 if u < 0.5 - hw * 0.35 else 1
			if absf(u - 0.5) < 0.07 and v >= 0.8 and v < 0.96:
				return 3
		Shape.PALM:
			var c := Vector2(0.47, 0.28)
			var r: float = p.distance_to(c)
			if r < 0.44 and v < 0.58:
				var a: float = atan2(v - c.y, u - c.x)
				var k: float = fmod(absf(a) / TAU * 7.0, 1.0)
				var width: float = 0.06 + 0.16 * (1.0 - r / 0.44)
				if minf(k, 1.0 - k) < width:
					return 2 if r < 0.13 else 1
			var axis: float = 0.47 + 0.14 * (v - 0.3)
			if absf(u - axis) < 0.065 and v > 0.3 and v < 0.96:
				return 3
		Shape.CACTUS:
			if p.distance_to(Vector2(0.5, 0.12)) < 0.07:
				return 3
			var body: bool = absf(u - 0.5) < 0.13 and v > 0.14 and v < 0.96
			var arms: bool = (u > 0.17 and u < 0.29 and v > 0.32 and v < 0.62) or (u > 0.17 and u < 0.5 and v > 0.53 and v < 0.62) \
				or (u > 0.71 and u < 0.83 and v > 0.22 and v < 0.52) or (u > 0.5 and u < 0.83 and v > 0.43 and v < 0.52)
			if body or arms:
				return 2 if absf(u - 0.45) < 0.03 or absf(u - 0.23) < 0.02 else 1
		Shape.THORNY:
			var c2 := Vector2(0.5, 0.52)
			var r2: float = p.distance_to(c2)
			var a2: float = atan2(v - c2.y, u - c2.x)
			var spike: float = pow(absf(sin(a2 * 3.5)), 8.0)
			if r2 < 0.2 + 0.24 * spike:
				if r2 > 0.3:
					return 3
				return 2 if p.distance_to(c2 + Vector2(-0.06, -0.07)) < 0.08 else 1
			if absf(u - 0.5) < 0.05 and v > 0.7 and v < 0.95:
				return 3
		Shape.WILLOW:
			var dome: bool = p.distance_to(Vector2(0.5, 0.45)) < 0.38 and v < 0.47
			var strands: bool = v >= 0.45 and v < 0.9 and absf(u - 0.5) < 0.38 - (v - 0.45) * 0.2 and fmod(u * 9.0, 1.0) < 0.55
			if dome:
				return 2 if p.distance_to(Vector2(0.38, 0.25)) < 0.12 else 1
			if strands:
				return 1
			if absf(u - 0.5) < 0.07 and v > 0.45 and v < 0.96:
				return 3
	return 0
