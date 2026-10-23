class_name PlaceholderTileset
extends RefCounted
## Tiles de placeholder generados por código. Solo usa colores de assets/palettes/nuevos-bosques.gpl.
## Cada Bosque tiene su propio atlas (forma de árbol, hojas, tronco y suelo según su estilo,
## ver BosqueMap.styles). Se sustituye por el arte de pixel-artist cuando exista.
## Atlas: columna = ChunkData.Tile, fila = variante (ver variant_for).

const TILE: int = 16
## Filas del atlas: las usan los letreros (8 direcciones); el resto usa 0-3.
const VARIANTS: int = 8

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
## Suelo: [hierba, motas de hierba, claro, motas de claro].
const GROUNDS: Array = [
	[Color("3e8948"), Color("63c74d"), Color("63c74d"), Color("3e8948")],
	[Color("265c42"), Color("3e8948"), Color("3e8948"), Color("63c74d")],
	[Color("e4a672"), Color("ead4aa"), Color("ead4aa"), Color("e4a672")],
	[Color("c28569"), Color("e8b796"), Color("e8b796"), Color("c28569")],
]


static func make_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	return tile_set


## Atlas de un Bosque con estilo `style` (ver BosqueMap.styles).
static func make_source(style: Dictionary) -> TileSetAtlasSource:
	var count: int = ChunkData.Tile.size()
	var image := Image.create(TILE * count, TILE * VARIANTS, false, Image.FORMAT_RGBA8)
	for tile: int in count:
		for variant: int in VARIANTS:
			_paint(image, tile, variant, Vector2i(tile * TILE, variant * TILE), style)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(TILE, TILE)
	for tile: int in count:
		for variant: int in VARIANTS:
			source.create_tile(Vector2i(tile, variant))
	return source


## Textura del Nujio: la misma silueta y paleta del Bosque, a tamaño n x n casillas.
static func nujio_texture(style: Dictionary, n: int) -> Texture2D:
	return ImageTexture.create_from_image(_tree_image(style, n * TILE, false))


## Variante visual de la casilla `cell` del chunk. `sign_dir` = índice de dirección de los
## letreros (orden de ChunkGenerator.direction_name).
static func variant_for(chunk: ChunkData, cell: Vector2i, sign_dir: int) -> int:
	var tile: int = chunk.get_tile(cell)
	match tile:
		ChunkData.Tile.CLIFF:
			var below: Vector2i = cell + Vector2i.DOWN
			var above: Vector2i = cell + Vector2i.UP
			var south_face: bool = ChunkData.in_bounds(below) and chunk.get_tile(below) != ChunkData.Tile.CLIFF
			var north_edge: bool = ChunkData.in_bounds(above) and chunk.get_tile(above) != ChunkData.Tile.CLIFF
			return (1 if south_face else 0) | (2 if north_edge else 0)
		ChunkData.Tile.BUILDING:
			var below_b: Vector2i = cell + Vector2i.DOWN
			return 1 if not ChunkData.in_bounds(below_b) or chunk.get_tile(below_b) != ChunkData.Tile.BUILDING else 0
		ChunkData.Tile.SIGN:
			return sign_dir
	var world: Vector2i = chunk.coord * ChunkData.SIZE + cell
	return ChunkGenerator.hash_ints([world.x, world.y]) % 2


static func _paint(image: Image, tile: int, variant: int, o: Vector2i, style: Dictionary) -> void:
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
