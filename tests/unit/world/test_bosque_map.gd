extends GutTest
## Reparto de chunks en Bosques (ADR 0006) y accesibilidad a pie del Bosque inicial.

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
	assert_eq(BosqueMap.build(42, _grid).ids, BosqueMap.build(42, _grid).ids)
	assert_ne(BosqueMap.build(42, _grid).ids, BosqueMap.build(43, _grid).ids)


func test_outside_region_is_no_bosque() -> void:
	var map := BosqueMap.build(42, _grid)
	assert_eq(map.bosque_at(Vector2i(-1, 0)), -1)
	assert_eq(map.bosque_at(_grid), -1)


func test_home_bosque_is_fully_reachable_on_foot() -> void:
	# Flood fill por casillas desde el centro del chunk inicial, cruzando bordes solo hacia chunks
	# del mismo Bosque. Ningún chunk del Bosque puede quedar aislado por ríos o riscos.
	var start := ChunkGenerator.region_start_chunk(_region)
	for s in [1, 42, 777, 123456789]:
		var map := BosqueMap.build(s, _grid)
		var home := map.bosque_at(start)
		var chunks := {}
		for c in map.chunks_of(home):
			chunks[c] = ChunkGenerator.generate(s, c, _region)
		var reached := _flood(chunks, start)
		for c in map.chunks_of(home):
			assert_true(reached.has(c), "seed %d: chunk %s del Bosque %d aislado" % [s, c, home])


func _chunk_of(world_cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(world_cell.x) / ChunkData.SIZE), floori(float(world_cell.y) / ChunkData.SIZE))


func _flood(chunks: Dictionary, start: Vector2i) -> Dictionary:
	var first: Vector2i = start * ChunkData.SIZE + ChunkData.center()
	var seen := { first: true }
	var reached := {}
	var queue: Array[Vector2i] = [first]
	var head := 0
	while head < queue.size():
		var w: Vector2i = queue[head]
		head += 1
		reached[_chunk_of(w)] = true
		for d in ChunkData.SIDES:
			var n: Vector2i = w + d
			if seen.has(n):
				continue
			var cc := _chunk_of(n)
			if not chunks.has(cc):
				continue
			if (chunks[cc] as ChunkData).is_walkable(n - cc * ChunkData.SIZE):
				seen[n] = true
				queue.append(n)
	return reached
