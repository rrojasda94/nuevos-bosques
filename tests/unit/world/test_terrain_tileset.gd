extends GutTest
## Tileset de terreno (docs/art/specs/tileset-terreno.md): los PNG existen con el tamaño de la
## spec y solo usan la paleta; el atlas de cada Bosque sale de ellos recoloreado con su estilo; cada
## casilla del enum tiene dibujo; y las variantes de borde, orillas, puente, casas y letreros.

const PALETTE_PATH: String = "res://assets/palettes/palette_nuevos_bosques.gpl"
const SIZES: Dictionary = {
	&"suelo": Vector2i(256, 64),
	&"sendero": Vector2i(256, 32),
	&"camino": Vector2i(256, 32),
	&"agua": Vector2i(256, 96),
	&"puente": Vector2i(32, 32),
	&"risco": Vector2i(256, 48),
	&"plaza": Vector2i(256, 32),
	&"villa": Vector2i(256, 32),
	&"letrero": Vector2i(128, 16),
	&"arboles": Vector2i(144, 96),
}
const T: int = PlaceholderTileset.TILE


func _palette() -> Dictionary:
	var out: Dictionary = {}
	var f := FileAccess.open(PALETTE_PATH, FileAccess.READ)
	while not f.eof_reached():
		var parts: PackedStringArray = f.get_line().replace("\t", " ").split(" ", false)
		if parts.size() >= 3 and parts[0].is_valid_int() and parts[1].is_valid_int() and parts[2].is_valid_int():
			out[Color8(int(parts[0]), int(parts[1]), int(parts[2])).to_rgba32()] = true
	return out


func _colors(img: Image, rect: Rect2i) -> Dictionary:
	var seen: Dictionary = {}
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.0:
				seen[c.to_rgba32()] = true
	return seen


func _chunk_with(tiles: Dictionary, fill: int = ChunkData.Tile.GRASS) -> ChunkData:
	var chunk := ChunkData.new()
	chunk.tiles.resize(ChunkData.SIZE * ChunkData.SIZE)
	chunk.tiles.fill(fill)
	for cell: Vector2i in tiles:
		chunk.set_tile(cell, tiles[cell])
	return chunk


func test_pngs_exist_with_spec_size() -> void:
	for group: StringName in SIZES:
		var path: String = TerrainTileset.DIR + String(TerrainTileset.GROUPS[group])
		assert_true(ResourceLoader.exists(path), "existe %s" % path)
		assert_true(TerrainTileset.has_group(group), String(group))
		var img: Image = TerrainTileset.raw_image(group)
		assert_eq(img.get_size(), SIZES[group], path)
	assert_eq(SIZES.size(), TerrainTileset.GROUPS.size(), "todos los grupos tienen tamaño en la spec")


func test_pngs_only_use_the_palette_and_full_alpha() -> void:
	var palette: Dictionary = _palette()
	assert_eq(palette.size(), 32, "la paleta tiene 32 colores")
	for group: StringName in SIZES:
		var img: Image = TerrainTileset.raw_image(group)
		var bad: int = 0
		for y: int in img.get_height():
			for x: int in img.get_width():
				var c: Color = img.get_pixel(x, y)
				if c.a8 == 0:
					continue
				if c.a8 != 255 or not palette.has(c.to_rgba32()):
					bad += 1
		assert_eq(bad, 0, "%s: píxeles fuera de paleta o con alfa parcial" % group)


func test_every_tile_has_a_non_empty_texture() -> void:
	var source: TileSetAtlasSource = PlaceholderTileset.make_source({ "shape": 0, "leaf": 0, "trunk": 0, "ground": 0 })
	var img: Image = source.texture.get_image()
	assert_eq(img.get_height(), T * PlaceholderTileset.VARIANTS)
	for tile: int in ChunkData.Tile.size():
		assert_true(source.has_tile(Vector2i(tile, 0)), "casilla %d" % tile)
		var region: Image = img.get_region(Rect2i(tile * T, 0, T, T))
		assert_false(region.is_invisible(), "casilla %d con dibujo" % tile)
		assert_eq(_colors(img, Rect2i(tile * T, 0, T, T)).size() > 1, true, "casilla %d no es un color liso" % tile)


func test_atlas_uses_the_bosque_colors_and_no_keys() -> void:
	var palette: Dictionary = _palette()
	for style: Dictionary in [
		{ "shape": PlaceholderTileset.Shape.CONIFER, "leaf": 4, "trunk": 3, "ground": 2 },
		{ "shape": PlaceholderTileset.Shape.PALM, "leaf": 8, "trunk": 6, "ground": 3 },
		{ "shape": PlaceholderTileset.Shape.WILLOW, "leaf": 2, "trunk": 1, "ground": 1 },
	]:
		var img: Image = PlaceholderTileset.make_source(style).texture.get_image()
		var leaf: Array = PlaceholderTileset.LEAVES[style.leaf]
		var ground: Array = PlaceholderTileset.GROUNDS[style.ground]
		var tree: Dictionary = _colors(img, Rect2i(ChunkData.Tile.TREE * T, 0, T, T))
		assert_true(tree.has((leaf[0] as Color).to_rgba32()), "%s: hoja oscura" % style)
		assert_true(tree.has((leaf[1] as Color).to_rgba32()), "%s: hoja clara" % style)
		assert_true(tree.has((PlaceholderTileset.TRUNKS[style.trunk] as Color).to_rgba32()), "%s: tronco" % style)
		assert_true(tree.has((ground[0] as Color).to_rgba32()), "%s: hierba bajo el árbol" % style)
		var grass: Dictionary = _colors(img, Rect2i(ChunkData.Tile.GRASS * T, 0, T, T))
		assert_true(grass.has((ground[0] as Color).to_rgba32()), "%s: hierba" % style)
		assert_false(grass.has(TerrainTileset.KEY_GRASS.to_rgba32()) and ground[0] != TerrainTileset.KEY_GRASS \
			and ground[1] != TerrainTileset.KEY_GRASS and ground[4] != TerrainTileset.KEY_GRASS, "%s: sin clave de hierba" % style)
		var clearing: Dictionary = _colors(img, Rect2i(ChunkData.Tile.CLEARING * T, 0, T, T))
		assert_true(clearing.has((ground[2] as Color).to_rgba32()), "%s: claro" % style)
		var all: Dictionary = _colors(img, Rect2i(Vector2i.ZERO, img.get_size()))
		for c: int in all:
			assert_true(palette.has(c), "%s: color %x de la paleta" % [style, c])


func test_tree_art_comes_from_the_png_silhouette() -> void:
	# Cada forma usa su fila del PNG: dos Bosques con la misma paleta y distinta forma difieren.
	var a: Image = PlaceholderTileset.make_source({ "shape": 0, "leaf": 1, "trunk": 0, "ground": 0 }).texture.get_image()
	var b: Image = PlaceholderTileset.make_source({ "shape": 3, "leaf": 1, "trunk": 0, "ground": 0 }).texture.get_image()
	var rect := Rect2i(ChunkData.Tile.TREE * T, 0, T, T)
	assert_ne(a.get_region(rect).get_data(), b.get_region(rect).get_data(), "copa redonda y cactus no son iguales")


func test_water_is_animated() -> void:
	var source: TileSetAtlasSource = PlaceholderTileset.make_source({})
	for tile: int in PlaceholderTileset.ANIMATED_TILES:
		assert_eq(source.get_tile_animation_frames_count(Vector2i(tile, 0)), PlaceholderTileset.ANIM_FRAMES, "casilla %d" % tile)
	var img: Image = source.texture.get_image()
	var count: int = ChunkData.Tile.size()
	var f0: Image = img.get_region(Rect2i(ChunkData.Tile.RIVER_NARROW * T, 0, T, T))
	var f1: Image = img.get_region(Rect2i((ChunkData.Tile.RIVER_NARROW + count) * T, 0, T, T))
	assert_ne(f0.get_data(), f1.get_data(), "los dos fotogramas del agua son distintos")


func test_edge_masks_for_path_cliff_and_water() -> void:
	var c := Vector2i(10, 10)
	var chunk: ChunkData = _chunk_with({
		c: ChunkData.Tile.PATH, c + Vector2i.LEFT: ChunkData.Tile.PATH, c + Vector2i.RIGHT: ChunkData.Tile.PATH,
	})
	var v: int = PlaceholderTileset.variant_for(chunk, c, 0) % 16
	assert_eq(v, PlaceholderTileset.EDGE_N | PlaceholderTileset.EDGE_S, "sendero este-oeste: hierba al norte y al sur")
	var cliff: ChunkData = _chunk_with({ c: ChunkData.Tile.CLIFF, c + Vector2i.UP: ChunkData.Tile.CLIFF })
	assert_eq(PlaceholderTileset.variant_for(cliff, c, 0) % 16,
		PlaceholderTileset.EDGE_E | PlaceholderTileset.EDGE_S | PlaceholderTileset.EDGE_W, "risco: cara al sur y bordes")
	var river: ChunkData = _chunk_with({}, ChunkData.Tile.RIVER_NARROW)
	river.set_tile(c + Vector2i.RIGHT, ChunkData.Tile.GRASS)
	assert_eq(PlaceholderTileset.variant_for(river, c, 0), PlaceholderTileset.EDGE_E, "orilla al este")
	assert_eq(PlaceholderTileset.variant_for(river, Vector2i(0, 0), 0), 0, "fuera del chunk no hay orilla")


func test_bridge_orientation_follows_the_crossing() -> void:
	var c := Vector2i(10, 10)
	var ns: ChunkData = _chunk_with({ c: ChunkData.Tile.BRIDGE, c + Vector2i.LEFT: ChunkData.Tile.RIVER_NARROW, c + Vector2i.RIGHT: ChunkData.Tile.RIVER_NARROW })
	assert_eq(PlaceholderTileset.variant_for(ns, c, 0) % 2, 0, "río a los lados: el paso va norte-sur")
	var ew: ChunkData = _chunk_with({ c: ChunkData.Tile.BRIDGE, c + Vector2i.UP: ChunkData.Tile.RIVER_NARROW, c + Vector2i.DOWN: ChunkData.Tile.RIVER_NARROW })
	assert_eq(PlaceholderTileset.variant_for(ew, c, 0) % 2, 1, "río arriba y abajo: el paso va este-oeste")


func test_house_has_roof_windows_and_one_doorway() -> void:
	var tiles: Dictionary = {}
	for x: int in range(10, 13):
		for y: int in range(10, 12):
			tiles[Vector2i(x, y)] = ChunkData.Tile.BUILDING
	var chunk: ChunkData = _chunk_with(tiles, ChunkData.Tile.CLEARING)
	var doors: int = 0
	for x: int in range(10, 13):
		var roof: int = PlaceholderTileset.variant_for(chunk, Vector2i(x, 10), 0) % 16
		assert_lt(roof, 8, "fila de arriba: techo")
		assert_eq(roof & 1, 1, "techo con borde norte")
		var front: int = PlaceholderTileset.variant_for(chunk, Vector2i(x, 11), 0) % 16
		assert_gte(front, 8, "fila de abajo: fachada")
		doors += 1 if front >= 12 else 0
	assert_eq(doors, 1, "un solo vano, sin puerta")
	assert_gte(PlaceholderTileset.variant_for(chunk, Vector2i(11, 11), 0) % 16, 12, "el vano va en el centro")


func test_sign_variant_keeps_direction_and_ground() -> void:
	var c := Vector2i(20, 20)
	var chunk: ChunkData = _chunk_with({
		c: ChunkData.Tile.SIGN, c + Vector2i.UP: ChunkData.Tile.ROAD, c + Vector2i.DOWN: ChunkData.Tile.ROAD,
	})
	for dir: int in 8:
		var v: int = PlaceholderTileset.variant_for(chunk, c, dir)
		assert_eq(v % 8, dir, "flecha %d" % dir)
		assert_eq(v / 8, TerrainTileset.SignGround.ROAD, "en medio del camino")
	assert_lt(PlaceholderTileset.variant_for(chunk, c, 7), PlaceholderTileset.VARIANTS)


func test_variants_fit_in_the_atlas_for_real_chunks() -> void:
	var region: Dictionary = ChunkGenerator.load_region(&"valle_del_sara")
	var map: BosqueMap = BosqueMap.for_region(42, region)
	var start: Vector2i = ChunkGenerator.region_start_chunk(region)
	for coord: Vector2i in [start, Vector2i(5, 0), Vector2i(6, 8)]:
		var chunk: ChunkData = ChunkGenerator.generate(42, coord, region, map)
		for y: int in ChunkData.SIZE:
			for x: int in ChunkData.SIZE:
				var v: int = PlaceholderTileset.variant_for(chunk, Vector2i(x, y), 3)
				if v < 0 or v >= PlaceholderTileset.VARIANTS:
					fail_test("variante %d fuera del atlas en %s %s" % [v, coord, Vector2i(x, y)])
					return
	pass_test("todas las variantes caben")


func test_missing_png_falls_back_to_procedural() -> void:
	# Un grupo que no existe no pinta nada: make_source usa el dibujo por código.
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	assert_false(TerrainTileset.paint(img, -1, 0, Vector2i.ZERO, {}), "casilla desconocida")
	PlaceholderTileset.paint_tile(img, ChunkData.Tile.GRASS, 0, Vector2i.ZERO, {})
	assert_false(img.is_invisible(), "el procedural sigue dibujando")
	assert_eq(PlaceholderTileset.legacy_variant(ChunkData.Tile.CLIFF, PlaceholderTileset.EDGE_S | PlaceholderTileset.EDGE_N), 3)
	assert_eq(PlaceholderTileset.legacy_variant(ChunkData.Tile.BUILDING, 12), 1, "fachada")
