extends GutTest
## Generación de chunks (ADR 0006): determinismo, árboles, riscos, ríos con vados y entradas.

const SEEDS: Array[int] = [1, 2, 42, 777, 123456789, 2147483647]
const COORDS: Array[Vector2i] = [Vector2i(6, 13), Vector2i(7, 13), Vector2i(0, 0), Vector2i(6, 1), Vector2i(11, 15)]

var _region: Dictionary
var _maps: Dictionary = {}


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"valle_del_sara")


func _map(seed_value: int) -> BosqueMap:
	if not _maps.has(seed_value):
		_maps[seed_value] = BosqueMap.build(seed_value, ChunkGenerator.region_size(_region))
	return _maps[seed_value]


func _gen(seed_value: int, coord: Vector2i) -> ChunkData:
	return ChunkGenerator.generate(seed_value, coord, _region, _map(seed_value))


func _count(chunk: ChunkData, tile: int) -> int:
	return chunk.tiles.count(tile)


func test_region_data_loads() -> void:
	assert_eq(ChunkGenerator.region_size(_region), Vector2i(12, 16))
	assert_true(_region.has("relief") and _region.has("rivers") and _region.has("forest"))
	assert_eq((_region.get("areas", []) as Array).size(), 7)


func test_chunk_has_expected_size() -> void:
	assert_eq(_gen(1, Vector2i.ZERO).tiles.size(), ChunkData.SIZE * ChunkData.SIZE)


func test_same_seed_and_coord_give_same_chunk() -> void:
	for s in SEEDS:
		for c in COORDS:
			assert_eq(_gen(s, c).tiles, _gen(s, c).tiles, "seed %d chunk %s" % [s, c])


func test_chunk_is_independent_of_visit_order() -> void:
	var first := _gen(42, Vector2i(6, 13)).tiles
	_gen(42, Vector2i(7, 13))
	_gen(42, Vector2i(2, 2))
	assert_eq(_gen(42, Vector2i(6, 13)).tiles, first)


func test_different_seeds_give_different_chunks() -> void:
	for i in SEEDS.size() - 1:
		assert_ne(_gen(SEEDS[i], Vector2i(6, 13)).tiles, _gen(SEEDS[i + 1], Vector2i(6, 13)).tiles,
			"seeds %d y %d" % [SEEDS[i], SEEDS[i + 1]])


func test_different_coords_give_different_chunks() -> void:
	assert_ne(_gen(42, Vector2i(6, 13)).tiles, _gen(42, Vector2i(7, 13)).tiles)


func test_trees_block_and_leave_room_to_walk() -> void:
	assert_false(ChunkData.is_walkable_tile(ChunkData.Tile.TREE))
	for s in SEEDS:
		var trees := _count(_gen(s, Vector2i(6, 12)), ChunkData.Tile.TREE)
		var ratio := float(trees) / (ChunkData.SIZE * ChunkData.SIZE)
		assert_between(ratio, 0.12, 0.40, "seed %d: %.0f%% árboles" % [s, ratio * 100.0])


func test_barriers_and_crossings() -> void:
	for t in [ChunkData.Tile.CLIFF, ChunkData.Tile.RIVER_NARROW, ChunkData.Tile.RIVER_NAVIGABLE, ChunkData.Tile.BUILDING, ChunkData.Tile.NUJIO]:
		assert_false(ChunkData.is_walkable_tile(t), "tile %d bloquea" % t)
	for t in [ChunkData.Tile.BRIDGE, ChunkData.Tile.FORD, ChunkData.Tile.PLAZA, ChunkData.Tile.SIGN, ChunkData.Tile.PATH, ChunkData.Tile.ROAD, ChunkData.Tile.REFUGE]:
		assert_true(ChunkData.is_walkable_tile(t), "tile %d se camina" % t)


func test_cliffs_cluster_in_northern_mountains() -> void:
	var north := 0
	var south := 0
	for s in SEEDS:
		for x in [2, 6, 9]:
			north += _count(_gen(s, Vector2i(x, 1)), ChunkData.Tile.CLIFF)
			south += _count(_gen(s, Vector2i(x, 12)), ChunkData.Tile.CLIFF)
	assert_gt(north, 0, "hay riscos en el norte")
	assert_eq(south, 0, "sin riscos en el sur llano")


func test_both_river_types_appear_in_region() -> void:
	var narrow := 0
	var navigable := 0
	for y in range(0, 16, 3):
		for x in range(0, 12, 2):
			var chunk := _gen(42, Vector2i(x, y))
			narrow += _count(chunk, ChunkData.Tile.RIVER_NARROW)
			navigable += _count(chunk, ChunkData.Tile.RIVER_NAVIGABLE)
	assert_gt(narrow, 0, "ríos estrechos")
	assert_gt(navigable, 0, "ríos navegables")


func test_main_river_is_continuous_from_north_to_south() -> void:
	# Cada fila de la región tiene río principal (o vado) y toca la fila siguiente (conexión 4).
	var height: int = ChunkGenerator.region_size(_region).y * ChunkData.SIZE
	for s in SEEDS:
		var terrain := ChunkGenerator.Terrain.new(s, _region)
		var breaks := 0
		for y in height - 1:
			var a := terrain.river_span(y)
			var b := terrain.river_span(y + 1)
			if a.y < a.x or a.x > b.y or b.x > a.y:
				breaks += 1
			var mid: int = (a.x + a.y) / 2
			var tile := terrain.tile_at(mid, y)
			if not (ChunkData.is_river(tile) or tile == ChunkData.Tile.FORD):
				breaks += 1
		assert_eq(breaks, 0, "seed %d: cortes en el río principal" % s)


func test_main_river_has_fords_regularly() -> void:
	var height: int = ChunkGenerator.region_size(_region).y * ChunkData.SIZE
	var spacing: int = int((_region.rivers as Dictionary).ford_spacing)
	for s in SEEDS:
		var terrain := ChunkGenerator.Terrain.new(s, _region)
		var last := -1
		var max_gap := 0
		for y in height:
			var span := terrain.river_span(y)
			if terrain.tile_at((span.x + span.y) / 2, y) == ChunkData.Tile.FORD:
				if last >= 0:
					max_gap = maxi(max_gap, y - last)
				last = y
		assert_gt(last, 0, "seed %d: hay vados" % s)
		assert_lte(max_gap, spacing * 2, "seed %d: vados como mucho cada %d filas" % [s, spacing * 2])


func test_rivers_are_sampled_in_world_space() -> void:
	# Cada casilla no tallada de un chunk coincide con el terreno base en esa posición del mundo,
	# así que los ríos siguen al cruzar el borde entre chunks.
	var carved: Array[int] = [ChunkData.Tile.PATH, ChunkData.Tile.BRIDGE, ChunkData.Tile.CLEARING,
		ChunkData.Tile.PLAZA, ChunkData.Tile.BUILDING, ChunkData.Tile.NUJIO, ChunkData.Tile.SIGN,
		ChunkData.Tile.ROAD, ChunkData.Tile.REFUGE, ChunkData.Tile.FRUIT_TREE]
	for s in [1, 42]:
		var terrain := ChunkGenerator.Terrain.new(s, _region)
		for c in [Vector2i(6, 13), Vector2i(7, 13), Vector2i(3, 5)]:
			var chunk := _gen(s, c)
			var mismatches := 0
			for y in ChunkData.SIZE:
				for x in ChunkData.SIZE:
					var tile := chunk.get_tile(Vector2i(x, y))
					if carved.has(tile):
						continue
					if tile != terrain.tile_at(c.x * ChunkData.SIZE + x, c.y * ChunkData.SIZE + y):
						mismatches += 1
			assert_eq(mismatches, 0, "seed %d chunk %s" % [s, c])


func test_hub_is_walkable() -> void:
	for s in SEEDS:
		for c in COORDS:
			var chunk := _gen(s, c)
			assert_true(chunk.is_walkable(chunk.hub), "seed %d chunk %s" % [s, c])


func test_every_side_has_walkable_entry_reachable_from_hub() -> void:
	for s in SEEDS:
		for c in COORDS:
			var chunk := _gen(s, c)
			for side in ChunkData.SIDES:
				var gate := ChunkData.border_cell(side, ChunkGenerator.gate_index(s, c, side))
				assert_true(chunk.is_reachable(gate), "seed %d chunk %s borde %s" % [s, c, side])


func test_gates_line_up_between_neighbours() -> void:
	for s in SEEDS:
		var c := Vector2i(2, 3)
		assert_eq(ChunkGenerator.gate_index(s, c, Vector2i.RIGHT), ChunkGenerator.gate_index(s, c + Vector2i.RIGHT, Vector2i.LEFT))
		assert_eq(ChunkGenerator.gate_index(s, c, Vector2i.DOWN), ChunkGenerator.gate_index(s, c + Vector2i.DOWN, Vector2i.UP))


func test_find_entry_returns_walkable_cell_on_requested_side() -> void:
	for s in SEEDS:
		var chunk := _gen(s, Vector2i(5, 8))
		for side in ChunkData.SIDES:
			for along: int in [0, 17, 32, 63]:
				var cell := chunk.find_entry(side, along)
				assert_true(chunk.is_walkable(cell), "seed %d borde %s along %d" % [s, side, along])
				assert_eq(cell, ChunkData.border_cell(side, cell.y if side.x != 0 else cell.x),
					"la entrada debe estar en el borde %s" % side)


func test_direction_names() -> void:
	assert_eq(ChunkGenerator.direction_name(Vector2i(0, -3)), "norte")
	assert_eq(ChunkGenerator.direction_name(Vector2i(2, 2)), "sureste")
	assert_eq(ChunkGenerator.direction_name(Vector2i(-5, 0)), "oeste")
	assert_eq(ChunkGenerator.direction_name(Vector2i(1, -1)), "noreste")
