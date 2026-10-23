class_name PlaceholderTileset
extends RefCounted
## Tileset de placeholder generado por código. Solo usa colores de assets/palettes/nuevos-bosques.gpl.
## Se sustituye por el tileset de pixel-artist cuando exista.
## Atlas: columna = ChunkData.Tile, fila = variante visual.

const TILE: int = 16
const VARIANTS: int = 2

# Colores de la paleta (Endesga 32).
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
const BLUE_DEEP := Color("3a4466")
const GREY_LIGHT := Color("8b9bb4")
const GREY := Color("5a6988")
const GREY_DARK := Color("3a4466")
const BLACKISH := Color("262b44")


static func build() -> TileSet:
	var count: int = ChunkData.Tile.size()
	var image := Image.create(TILE * count, TILE * VARIANTS, false, Image.FORMAT_RGBA8)
	for tile: int in count:
		for variant: int in VARIANTS:
			_paint(image, tile, variant, Vector2i(tile * TILE, variant * TILE))
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(TILE, TILE)
	for tile: int in count:
		for variant: int in VARIANTS:
			source.create_tile(Vector2i(tile, variant))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	tile_set.add_source(source, 0)
	return tile_set


## Variante visual estable para una casilla del mundo (no consume RNG).
static func variant_for(world_cell: Vector2i) -> int:
	return ChunkGenerator.hash_ints([world_cell.x, world_cell.y]) % VARIANTS


static func _paint(image: Image, tile: int, variant: int, o: Vector2i) -> void:
	var salt: int = tile * 10 + variant
	match tile:
		ChunkData.Tile.GRASS:
			image.fill_rect(Rect2i(o, Vector2i(TILE, TILE)), GREEN)
			_specks(image, o, GREEN_LIGHT, 7, salt)
			_specks(image, o, GREEN_DARK, 4, salt + 100)
		ChunkData.Tile.CLEARING:
			image.fill_rect(Rect2i(o, Vector2i(TILE, TILE)), GREEN_LIGHT)
			_specks(image, o, GREEN, 4, salt)
			if variant == 1:
				_specks(image, o, YELLOW, 2, salt + 100)
				_specks(image, o, WHITE, 1, salt + 200)
		ChunkData.Tile.PATH:
			image.fill_rect(Rect2i(o, Vector2i(TILE, TILE)), BROWN)
			_specks(image, o, BROWN_LIGHT, 6, salt)
			_specks(image, o, BROWN_DARK, 4, salt + 100)
		ChunkData.Tile.FOREST:
			# Bosque tupido y transitable: dos copas solapadas por tile.
			image.fill_rect(Rect2i(o, Vector2i(TILE, TILE)), GREEN_DARK)
			var centers: Array[Vector2] = [Vector2(4.5, 5.0), Vector2(11.0, 10.5)]
			if variant == 1:
				centers = [Vector2(11.0, 4.5), Vector2(4.5, 11.0)]
			for c: Vector2 in centers:
				_canopy(image, o, c, 4.6)
		ChunkData.Tile.ROCKY:
			image.fill_rect(Rect2i(o, Vector2i(TILE, TILE)), GREEN)
			_specks(image, o, GREY, 8, salt)
			_specks(image, o, GREY_LIGHT, 5, salt + 100)
			_specks(image, o, GREEN_DARK, 3, salt + 200)
		ChunkData.Tile.CLIFF:
			image.fill_rect(Rect2i(o, Vector2i(TILE, TILE)), GREY)
			for y: int in TILE:
				for x: int in TILE:
					if (x + y * 3 + variant * 5) % 7 == 0:
						image.set_pixel(o.x + x, o.y + y, GREY_DARK)
			image.fill_rect(Rect2i(o.x, o.y, TILE, 2), GREY_LIGHT)
			image.fill_rect(Rect2i(o.x, o.y + TILE - 3, TILE, 3), BLACKISH)
		ChunkData.Tile.RIVER_NARROW:
			_water(image, o, variant, BLUE, CYAN)
		ChunkData.Tile.RIVER_NAVIGABLE:
			_water(image, o, variant, BLUE_DARK, BLUE)
			_specks(image, o, BLUE_DEEP, 4, salt)
		ChunkData.Tile.BRIDGE:
			image.fill_rect(Rect2i(o, Vector2i(TILE, TILE)), BLUE_DARK)
			image.fill_rect(Rect2i(o.x + 2, o.y, TILE - 4, TILE), BROWN)
			for y: int in range(0, TILE, 4):
				image.fill_rect(Rect2i(o.x + 2, o.y + y, TILE - 4, 1), BROWN_DARK)
			image.fill_rect(Rect2i(o.x + 2, o.y, 1, TILE), BROWN_DARK)
			image.fill_rect(Rect2i(o.x + TILE - 3, o.y, 1, TILE), BROWN_DARK)


static func _canopy(image: Image, o: Vector2i, c: Vector2, r: float) -> void:
	for y: int in TILE:
		for x: int in TILE:
			var d: float = Vector2(x, y).distance_to(c)
			if d <= r - 1.0:
				var lit: bool = Vector2(x, y).distance_to(c + Vector2(-1.5, -1.5)) <= r * 0.35
				image.set_pixel(o.x + x, o.y + y, GREEN_LIGHT if lit else GREEN)
			elif d <= r:
				image.set_pixel(o.x + x, o.y + y, GREEN_DARKEST)


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
