extends GutTest
## Bosques (ADR 0006): reparto, aspecto, chunk del Nujio y villas. Lo que el ChunkBuilder pone en
## cada chunk (Nujio, villa, letreros, accesibilidad a pie) lo prueban test_chunk_builder y
## test_region_plan.

var _region: Dictionary
var _grid: Vector2i


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"valle_del_sara")
	_grid = ChunkGenerator.region_size(_region)


func test_every_chunk_belongs_to_a_bosque() -> void:
	var map := BosqueMap.build(42, _grid)
	var total := 0
	for id in map.count():
		total += map.size_of(id)
	assert_eq(total, _grid.x * _grid.y)
	assert_false(map.ids.has(-1))


func test_bosques_have_4_to_16_contiguous_chunks() -> void:
	var bad := 0
	for s in range(1, 201):
		var map := BosqueMap.build(s, _grid)
		for id in map.count():
			var n := map.size_of(id)
			if n < BosqueMap.MIN_SIZE or n > BosqueMap.MAX_SIZE or not map.is_contiguous(id):
				bad += 1
				fail_test("seed %d: Bosque %d con %d chunks (contiguo: %s)" % [s, id, n, map.is_contiguous(id)])
	assert_eq(bad, 0)


func test_bosque_map_is_deterministic_and_depends_on_seed() -> void:
	var a := BosqueMap.build(42, _grid)
	var b := BosqueMap.build(42, _grid)
	assert_eq(a.ids, b.ids)
	assert_eq(a.styles, b.styles, "tipo de árbol y paleta deterministas")
	assert_eq(a.has_villa, b.has_villa)
	assert_eq(a.nujio_chunk, b.nujio_chunk)
	assert_ne(a.ids, BosqueMap.build(43, _grid).ids)


func test_outside_region_is_no_bosque() -> void:
	var map := BosqueMap.build(42, _grid)
	assert_eq(map.bosque_at(Vector2i(-1, 0)), -1)
	assert_eq(map.bosque_at(_grid), -1)


func test_neighbouring_bosques_look_different() -> void:
	for s in range(1, 101):
		var map := BosqueMap.build(s, _grid)
		for id in map.count():
			for n in map.neighbours_of(id):
				if map.styles[id].leaf == map.styles[n].leaf:
					fail_test("seed %d: Bosques %d y %d comparten color de hoja" % [s, id, n])
	pass_test("vecinos con hojas distintas")


func test_styles_use_all_shapes_and_valid_palette_indices() -> void:
	var shapes := {}
	for s in range(1, 21):
		var map := BosqueMap.build(s, _grid)
		for style in map.styles:
			shapes[style.shape] = true
			assert_lt(int(style.leaf), PlaceholderTileset.LEAVES.size())
			assert_lt(int(style.trunk), PlaceholderTileset.TRUNKS.size())
			assert_lt(int(style.ground), PlaceholderTileset.GROUNDS.size())
	assert_eq(shapes.size(), PlaceholderTileset.SHAPE_COUNT, "salen las %d siluetas" % PlaceholderTileset.SHAPE_COUNT)


func test_nujio_chunk_is_the_most_central_of_its_bosque() -> void:
	for s in [1, 42, 777]:
		var map := BosqueMap.build(s, _grid)
		for id in map.count():
			var cells := map.chunks_of(id)
			var centroid := Vector2.ZERO
			for c in cells:
				centroid += Vector2(c)
			centroid /= cells.size()
			var best := INF
			for c in cells:
				best = minf(best, Vector2(c).distance_squared_to(centroid))
			assert_almost_eq(Vector2(map.nujio_chunk[id]).distance_squared_to(centroid), best, 0.0001)


func test_villa_frequency_is_about_one_in_five() -> void:
	var villas := 0
	var total := 0
	for s in range(1, 301):
		var map := BosqueMap.build(s, _grid)
		for id in map.count():
			total += 1
			if map.has_villa[id]:
				villas += 1
	assert_between(float(villas) / total, 0.17, 0.23, "%d villas en %d Bosques" % [villas, total])


func test_home_bosque_always_has_villa_and_others_keep_one_in_five() -> void:
	var start := ChunkGenerator.region_start_chunk(_region)
	var villas := 0
	var total := 0
	for s in range(1, 301):
		var map := BosqueMap.for_region(s, _region)
		var plain := BosqueMap.build(s, _grid)
		var home := map.bosque_at(start)
		assert_true(map.has_villa[home], "seed %d: el Bosque inicial tiene villa" % s)
		for id in map.count():
			if id == home:
				continue
			assert_eq(map.has_villa[id], plain.has_villa[id], "el resto no cambia")
			total += 1
			if map.has_villa[id]:
				villas += 1
	assert_between(float(villas) / total, 0.17, 0.23, "%d villas en %d Bosques" % [villas, total])

