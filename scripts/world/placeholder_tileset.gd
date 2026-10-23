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
		ChunkData.Tile.TREE:
			image.fill_rect(Rect2i(o, Vector2i(TILE, TILE)), GREEN)
			var c := Vector2(7.5, 7.5)
			var hl := Vector2(5.0, 5.0) if variant == 0 else Vector2(9.0, 5.0)
			for y: int in TILE:
				for x: int in TILE:
					var p := Vector2(x, y)
					var d: float = p.distance_to(c)
					if d <= 6.2:
						image.set_pixelv(o + Vector2i(x, y), GREEN_DARK)
						if p.distance_to(hl) <= 2.6:
							image.set_pixelv(o + Vector2i(x, y), GREEN)
					elif d <= 7.6:
						image.set_pixelv(o + Vector2i(x, y), GREEN_DARKEST)
		ChunkData.Tile.WATER:
			image.fill_rect(Rect2i(o, Vector2i(TILE, TILE)), BLUE_DARK)
			var shift: int = variant * 5
			for i: int in 3:
				var y: int = (3 + i * 5 + variant * 2) % TILE
				var x0: int = (2 + i * 6 + shift) % (TILE - 4)
				for dx: int in 4:
					image.set_pixelv(o + Vector2i(x0 + dx, y), BLUE)
			_specks(image, o, CYAN, 1, salt)


## Puntos sueltos en posiciones fijas derivadas de `salt` (decorativo, determinista).
static func _specks(image: Image, o: Vector2i, color: Color, count: int, salt: int) -> void:
	for i: int in count:
		var h: int = ChunkGenerator.hash_ints([salt, i])
		image.set_pixelv(o + Vector2i(h % TILE, (h >> 8) % TILE), color)
