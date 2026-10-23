extends GutTest
## Generación de chunks (ADR 0006): determinismo, tiles transitables, ríos y entradas.

const SEEDS: Array[int] = [1, 2, 42, 777, 123456789, 2147483647]
const COORDS: Array[Vector2i] = [Vector2i(6, 13), Vector2i(7, 13), Vector2i(0, 0), Vector2i(6, 1), Vector2i(11, 15)]

var _region: Dictionary


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"valle_del_sara")


func _gen(seed_value: int, coord: Vector2i) -> ChunkData:
	return ChunkGenerator.generate(seed_value, coord, _region)


func _count(chunk: ChunkData, tile: int) -> int:
	return chunk.tiles.count(tile)


func test_region_data_loads() -> void:
	assert_eq(ChunkGenerator.region_size(_region), Vector2i(12, 16))
	assert_true(_region.has("relief") and _region.has("rivers"))
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


func test_forest_is_walkable_and_present() -> void:
	assert_true(ChunkData.is_walkable_tile(ChunkData.Tile.FOREST))
	assert_gt(_count(_gen(42, Vector2i(6, 13)), ChunkData.Tile.FOREST), 500, "bosque tupido")


func test_barriers_are_cliffs_and_rivers() -> void:
	assert_false(ChunkData.is_walkable_tile(ChunkData.Tile.CLIFF))
	assert_false(ChunkData.is_walkable_tile(ChunkData.Tile.RIVER_NARROW))
	assert_false(ChunkData.is_walkable_tile(ChunkData.Tile.RIVER_NAVIGABLE))
	assert_true(ChunkData.is_walkable_tile(ChunkData.Tile.BRIDGE))


func test_north_is_more_rugged_than_south() -> void:
	var north := 0
	var south := 0
	for s in SEEDS:
		for x in [2, 6, 9]:
			north += _count(_gen(s, Vector2i(x, 1)), ChunkData.Tile.CLIFF)
			south += _count(_gen(s, Vector2i(x, 14)), ChunkData.Tile.CLIFF)
	assert_gt(north, south * 2, "norte %d riscos, sur %d" % [north, south])


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


func test_rivers_are_sampled_in_world_space() -> void:
	# Los ríos salen de una función de coordenadas de mundo: cada casilla no tallada de un chunk
	# coincide con el terreno base en esa posición del mundo. Así un río sigue al cruzar el borde.
	var rng := RandomNumberGenerator.new()
	for s in [1, 42]:
		var terrain := ChunkGenerator.Terrain.new(s, _region)
		for c in [Vector2i(6, 13), Vector2i(7, 13), Vector2i(3, 5)]:
			var chunk := _gen(s, c)
			var mismatches := 0
			for y in ChunkData.SIZE:
				for x in ChunkData.SIZE:
					var tile := chunk.get_tile(Vector2i(x, y))
					if tile == ChunkData.Tile.PATH or tile == ChunkData.Tile.BRIDGE or tile == ChunkData.Tile.CLEARING:
						continue
					var base := terrain.tile_at(c.x * ChunkData.SIZE + x, c.y * ChunkData.SIZE + y, rng)
					if ChunkData.is_river(tile) != ChunkData.is_river(base):
						mismatches += 1
			assert_eq(mismatches, 0, "seed %d chunk %s" % [s, c])


func test_rivers_are_long_not_puddles() -> void:
	# En una ventana de 3x3 chunks, todo río que no toca el borde de la ventana es largo.
	var rng := RandomNumberGenerator.new()
	var window: int = ChunkData.SIZE * 3
	var components := 0
	for case: Array in [[1, Vector2i(5, 8)], [42, Vector2i(5, 8)], [777, Vector2i(5, 8)], [42, Vector2i(2, 0)], [777, Vector2i(7, 12)]]:
		var s: int = case[0]
		var terrain := ChunkGenerator.Terrain.new(s, _region)
		var origin: Vector2i = (case[1] as Vector2i) * ChunkData.SIZE
		var river := PackedByteArray()
		river.resize(window * window)
		for y in window:
			for x in window:
				river[y * window + x] = 1 if ChunkData.is_river(terrain.tile_at(origin.x + x, origin.y + y, rng)) else 0
		var seen := PackedByteArray()
		seen.resize(window * window)
		for i in window * window:
			if river[i] == 0 or seen[i] == 1:
				continue
			var queue: Array[int] = [i]
			seen[i] = 1
			var head := 0
			var touches_edge := false
			components += 1
			while head < queue.size():
				var p: int = queue[head]
				head += 1
				var px: int = p % window
				var py: int = p / window
				if px == 0 or py == 0 or px == window - 1 or py == window - 1:
					touches_edge = true
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
					var nx: int = px + d.x
					var ny: int = py + d.y
					if nx < 0 or ny < 0 or nx >= window or ny >= window:
						continue
					var n: int = ny * window + nx
					if river[n] == 1 and seen[n] == 0:
						seen[n] = 1
						queue.append(n)
			if not touches_edge:
				assert_gt(queue.size(), 40, "seed %d: charco de %d casillas en %s" % [s, queue.size(), origin + Vector2i(i % window, i / window)])
	assert_gt(components, 0, "la ventana debe contener ríos")


func test_center_is_walkable() -> void:
	for s in SEEDS:
		for c in COORDS:
			assert_true(_gen(s, c).is_walkable(ChunkData.center()), "seed %d chunk %s" % [s, c])


func test_every_side_has_walkable_entry_reachable_from_center() -> void:
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
