extends GutTest
## Generación de chunks (ADR 0006): determinismo y entradas transitables.

const SEEDS: Array[int] = [1, 2, 42, 777, 123456789, 2147483647]
const COORDS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(3, -7)]

var _region: Dictionary


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"claro_inicial")


func _gen(seed_value: int, coord: Vector2i) -> ChunkData:
	return ChunkGenerator.generate(seed_value, coord, _region)


func test_region_data_loads() -> void:
	assert_true(_region.has("forest_density"), "claro_inicial.json debe cargarse")


func test_chunk_has_expected_size() -> void:
	assert_eq(_gen(1, Vector2i.ZERO).tiles.size(), ChunkData.SIZE * ChunkData.SIZE)


func test_same_seed_and_coord_give_same_chunk() -> void:
	for s in SEEDS:
		for c in COORDS:
			assert_eq(_gen(s, c).tiles, _gen(s, c).tiles, "seed %d chunk %s" % [s, c])


func test_chunk_is_independent_of_visit_order() -> void:
	var first := _gen(42, Vector2i(0, 0)).tiles
	_gen(42, Vector2i(1, 0))
	_gen(42, Vector2i(5, 5))
	assert_eq(_gen(42, Vector2i(0, 0)).tiles, first)


func test_different_seeds_give_different_chunks() -> void:
	for i in SEEDS.size() - 1:
		assert_ne(_gen(SEEDS[i], Vector2i.ZERO).tiles, _gen(SEEDS[i + 1], Vector2i.ZERO).tiles,
			"seeds %d y %d" % [SEEDS[i], SEEDS[i + 1]])


func test_different_coords_give_different_chunks() -> void:
	assert_ne(_gen(42, Vector2i(0, 0)).tiles, _gen(42, Vector2i(1, 0)).tiles)


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
		var c := Vector2i(2, -3)
		assert_eq(ChunkGenerator.gate_index(s, c, Vector2i.RIGHT), ChunkGenerator.gate_index(s, c + Vector2i.RIGHT, Vector2i.LEFT))
		assert_eq(ChunkGenerator.gate_index(s, c, Vector2i.DOWN), ChunkGenerator.gate_index(s, c + Vector2i.DOWN, Vector2i.UP))


func test_find_entry_returns_walkable_cell_on_requested_side() -> void:
	for s in SEEDS:
		var chunk := _gen(s, Vector2i(1, 1))
		for side in ChunkData.SIDES:
			for along in [0, 17, 32, 63]:
				var cell := chunk.find_entry(side, along)
				assert_true(chunk.is_walkable(cell), "seed %d borde %s along %d" % [s, side, along])
				assert_eq(cell, ChunkData.border_cell(side, cell.y if side.x != 0 else cell.x),
					"la entrada debe estar en el borde %s" % side)
