extends GutTest
## Reparto y colocación de refugios (ADR 0006, navegacion.md, bosques-y-relacion.md): todo Bosque
## tiene refugio en su chunk de Nujio, ningún chunk queda a más de 2 chunks de uno, todo
## has_refuge produce una casilla REFUGE alcanzable y nunca cae en la plaza, el camino ni el agua.

const SEEDS: Array[int] = [1, 42, 777, 2024, 123456789]
## Seeds en las que se generan todos los chunks de la región.
const FULL_SEEDS: Array[int] = [1, 42]
const ALLOWED_UNDER: Array[int] = [
	ChunkData.Tile.TREE, ChunkData.Tile.GRASS, ChunkData.Tile.CLEARING, ChunkData.Tile.ROCKY,
	ChunkData.Tile.CLIFF, ChunkData.Tile.PATH,
]

var _region: Dictionary
var _no_fruit: Dictionary
var _maps: Dictionary = {}


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"valle_del_sara")
	# Sin frutales, para comparar chunks con y sin refugio casilla a casilla.
	_no_fruit = _region.duplicate(true)
	_no_fruit.fruit = { "states": [] }


func _map(seed_value: int) -> BosqueMap:
	if not _maps.has(seed_value):
		_maps[seed_value] = BosqueMap.for_region(seed_value, _region)
	return _maps[seed_value]


func _all_chunks(map: BosqueMap) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in map.grid_size.y:
		for x in map.grid_size.x:
			out.append(Vector2i(x, y))
	return out


func _refuge_cells(chunk: ChunkData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in chunk.tiles.size():
		if chunk.tiles[i] == ChunkData.Tile.REFUGE:
			out.append(Vector2i(i % ChunkData.SIZE, i / ChunkData.SIZE))
	return out


func test_region_json_has_refuge_params() -> void:
	assert_true(_region.has("refuges"), "valle_del_sara define el reparto de refugios")
	for key in BosqueMap.DEFAULT_REFUGES:
		assert_true((_region.refuges as Dictionary).has(key), "refuges.%s" % key)


func test_every_bosque_has_a_refuge_in_its_nujio_chunk() -> void:
	for s in range(1, 41):
		var map := _map(s)
		for id in map.count():
			assert_true(map.has_refuge(map.nujio_chunk[id]), "seed %d: Bosque %d con refugio en su Nujio" % [s, id])
			var any := false
			for c in map.chunks_of(id):
				any = any or map.has_refuge(c)
			assert_true(any, "seed %d: Bosque %d con refugio" % [s, id])


func test_no_chunk_is_more_than_two_chunks_from_a_refuge() -> void:
	var max_distance: int = int(_region.refuges.max_distance)
	assert_lte(max_distance, 2)
	for s in range(1, 41):
		var map := _map(s)
		var refuges := map.refuge_chunks()
		for c in _all_chunks(map):
			var best := 999
			for r in refuges:
				best = mini(best, absi(r.x - c.x) + absi(r.y - c.y))
			assert_eq(map.refuge_distance(c), best)
			assert_lte(best, max_distance, "seed %d: chunk %s a %d chunks del refugio más cercano" % [s, c, best])


func test_refuge_density_about_one_every_two_or_three_chunks_also_off_road() -> void:
	var refuges := 0
	var off_road := 0
	var chunks := 0
	for s in range(1, 41):
		var map := _map(s)
		for c in _all_chunks(map):
			chunks += 1
			if map.has_refuge(c):
				refuges += 1
				if not map.has_road(c):
					off_road += 1
	var rate := float(refuges) / chunks
	assert_between(rate, 1.0 / 3.0, 0.5, "%d refugios en %d chunks" % [refuges, chunks])
	assert_gt(float(off_road) / refuges, 0.3, "%d de %d refugios fuera del camino principal" % [off_road, refuges])


func test_every_flagged_chunk_gets_one_reachable_refuge_never_on_plaza_road_or_water() -> void:
	for s in FULL_SEEDS:
		var map := _map(s)
		var bare := BosqueMap.for_region(s, _region)
		bare._refuges.clear()
		for c in _all_chunks(map):
			var chunk := ChunkGenerator.generate(s, c, _no_fruit, map)
			var cells := _refuge_cells(chunk)
			if not map.has_refuge(c):
				assert_eq(cells.size(), 0, "seed %d chunk %s: sin refugio" % [s, c])
				continue
			if cells.size() != 1:
				fail_test("seed %d chunk %s: %d casillas REFUGE (se esperaba 1)" % [s, c, cells.size()])
				continue
			var cell: Vector2i = cells[0]
			assert_true(chunk.is_walkable(cell), "el refugio no bloquea")
			assert_true(chunk.is_reachable(cell), "seed %d chunk %s: refugio %s alcanzable desde el hub" % [s, c, cell])
			assert_ne(cell, chunk.hub, "no ocupa el hub")
			# Mismo chunk sin refugio: solo cambia esa casilla, y lo que había debajo es suelo natural
			# o un sendero (nunca plaza, camino, agua, letrero, edificio ni Nujio).
			var before := ChunkGenerator.generate(s, c, _no_fruit, bare)
			var under: int = before.get_tile(cell)
			assert_has(ALLOWED_UNDER, under, "seed %d chunk %s: refugio sobre el tile %d" % [s, c, under])
			var diff := 0
			for i in chunk.tiles.size():
				if chunk.tiles[i] != before.tiles[i]:
					diff += 1
			assert_eq(diff, 1, "seed %d chunk %s: el refugio solo cambia su casilla" % [s, c])


func test_refuge_sits_next_to_the_nujio_in_bosques_without_villa() -> void:
	for s in [1, 42, 777]:
		var map := _map(s)
		for id in map.count():
			var c: Vector2i = map.nujio_chunk[id]
			var chunk := ChunkGenerator.generate(s, c, _region, map)
			var cells := _refuge_cells(chunk)
			assert_eq(cells.size(), 1, "seed %d Bosque %d: refugio en el chunk de Nujio" % [s, id])
			if cells.is_empty() or map.has_villa[id]:
				continue  # En la villa, la plaza ya cuenta como descanso junto al Nujio.
			var gap := ChunkGenerator._nujio_gap(chunk.nujio_rect, cells[0])
			assert_between(gap, 1, ChunkGenerator.REFUGE_NUJIO_REACH, "seed %d Bosque %d: a %d casillas del Nujio" % [s, id, gap])


func test_refuges_are_deterministic_by_seed() -> void:
	for s in SEEDS:
		var a := BosqueMap.for_region(s, _region)
		var b := BosqueMap.for_region(s, _region)
		assert_eq(a.refuge_chunks(), b.refuge_chunks(), "seed %d: mismo reparto" % s)
		for c in a.refuge_chunks().slice(0, 4):
			var ca := ChunkGenerator.generate(s, c, _region, a)
			var cb := ChunkGenerator.generate(s, c, _region, b)
			assert_eq(_refuge_cells(ca), _refuge_cells(cb), "seed %d chunk %s: misma casilla" % [s, c])
	assert_ne(_map(1).refuge_chunks(), _map(2).refuge_chunks(), "otra seed, otro reparto")


func test_params_change_the_distribution() -> void:
	var size := ChunkGenerator.region_size(_region)
	var start := ChunkGenerator.region_start_chunk(_region)
	var sparse := BosqueMap.build(42, size, start, { "min_spacing": 4, "max_distance": 3 })
	var dense := BosqueMap.build(42, size, start)
	assert_lt(sparse.refuge_chunks().size(), dense.refuge_chunks().size())
	for c in _all_chunks(sparse):
		assert_lte(sparse.refuge_distance(c), 3)
	var two := BosqueMap.build(42, size, start, { "per_bosque": 2 })
	for id in two.count():
		var n := 0
		for c in two.chunks_of(id):
			n += 1 if two.has_refuge(c) else 0
		assert_gte(n, 2, "per_bosque = 2 en el Bosque %d" % id)


func test_placement_never_fails_even_without_free_ground() -> void:
	# Todo agua salvo un sendero que llega al hub: el refugio cae en el sendero, nunca en el agua.
	var chunk := ChunkData.new()
	chunk.tiles.resize(ChunkData.SIZE * ChunkData.SIZE)
	chunk.tiles.fill(ChunkData.Tile.RIVER_NAVIGABLE)
	for x in range(2, ChunkData.SIZE - 2):
		chunk.set_tile(Vector2i(x, chunk.hub.y), ChunkData.Tile.PATH)
	var cell := ChunkGenerator._place_refuge(chunk, 42, Vector2i(3, 3), 0, false)
	assert_true(ChunkData.in_bounds(cell), "siempre hay refugio")
	assert_eq(chunk.get_tile(cell), ChunkData.Tile.REFUGE)
	assert_eq(cell.y, chunk.hub.y, "sobre el sendero")
	assert_ne(cell, chunk.hub)
	assert_true(chunk.is_reachable(cell))
	# Rodeado de árboles: ocupa un árbol pegado a la zona abierta (árbol hueco), no se descarta.
	var woods := ChunkData.new()
	woods.tiles.resize(ChunkData.SIZE * ChunkData.SIZE)
	woods.tiles.fill(ChunkData.Tile.TREE)
	woods.set_tile(woods.hub, ChunkData.Tile.CLEARING)
	var t := ChunkGenerator._place_refuge(woods, 7, Vector2i(1, 1), 0, false)
	assert_eq(absi(t.x - woods.hub.x) + absi(t.y - woods.hub.y), 1, "junto al hub, el único acceso")
	assert_true(woods.is_reachable(t))
