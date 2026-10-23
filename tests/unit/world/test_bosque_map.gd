extends GutTest
## Bosques (ADR 0006): reparto, aspecto, Nujio, villas, letreros y accesibilidad a pie.

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


func test_nujio_is_6_to_8_tiles_and_reachable_on_foot() -> void:
	for s in [1, 42, 777, 9001]:
		var map := BosqueMap.build(s, _grid)
		for id in range(0, map.count(), 3):
			var chunk := ChunkGenerator.generate(s, map.nujio_chunk[id], _region, map)
			var rect := chunk.nujio_rect
			assert_true(rect.size.x >= 6 and rect.size.x <= 8 and rect.size.x == rect.size.y, "seed %d Bosque %d: Nujio %s" % [s, id, rect.size])
			assert_eq(chunk.tiles.count(ChunkData.Tile.NUJIO), rect.size.x * rect.size.y)
			assert_eq(map.bosque_at(map.nujio_chunk[id]), id, "el Nujio está en su Bosque")
			var reachable := false
			for y in range(rect.position.y - 1, rect.end.y + 1):
				for x in range(rect.position.x - 1, rect.end.x + 1):
					if chunk.is_reachable(Vector2i(x, y)):
						reachable = true
			assert_true(reachable, "seed %d Bosque %d: se llega a pie al Nujio" % [s, id])
			assert_eq(rect.get_center(), ChunkData.center(), "Nujio en el centro del chunk (claro o villa)")
			assert_eq(map.nujio_chunk[id], map.central_chunk(id), "Nujio en el chunk más central")
			if map.has_villa[id]:
				assert_true(chunk.has_villa)
				assert_gt(chunk.tiles.count(ChunkData.Tile.BUILDING), 0, "la villa tiene edificios")
				assert_gt(chunk.tiles.count(ChunkData.Tile.PLAZA), 0, "la villa tiene plaza")


func test_villa_buildings_are_reachable() -> void:
	var found := 0
	for s in range(1, 30):
		var map := BosqueMap.build(s, _grid)
		for id in map.count():
			if not map.has_villa[id]:
				continue
			found += 1
			var chunk := ChunkGenerator.generate(s, map.nujio_chunk[id], _region, map)
			for y in ChunkData.SIZE:
				for x in ChunkData.SIZE:
					if chunk.get_tile(Vector2i(x, y)) != ChunkData.Tile.BUILDING:
						continue
					var ok := false
					for d in ChunkData.SIDES:
						if chunk.is_reachable(Vector2i(x, y) + d) or chunk.get_tile(Vector2i(x, y) + d) == ChunkData.Tile.BUILDING:
							ok = true
					assert_true(ok, "seed %d: edificio aislado en %s" % [s, Vector2i(x, y)])
			if found >= 5:
				return


func test_signposts_appear_only_in_villa_bosques() -> void:
	for s in [1, 42, 777]:
		var map := BosqueMap.build(s, _grid)
		for id in map.count():
			for c in map.chunks_of(id).slice(0, 3):
				var chunk := ChunkGenerator.generate(s, c, _region, map)
				var signs := chunk.tiles.count(ChunkData.Tile.SIGN)
				if map.has_villa[id] and c != map.nujio_chunk[id]:
					assert_eq(signs, 1, "seed %d chunk %s: letrero hacia la villa" % [s, c])
				else:
					assert_eq(signs, 0, "seed %d chunk %s: sin letreros" % [s, c])


func test_home_bosque_is_fully_reachable_on_foot() -> void:
	# Flood fill por casillas desde el hub del chunk inicial, cruzando bordes solo hacia chunks del
	# mismo Bosque. Ni árboles, ni ríos, ni riscos, ni la villa pueden aislar un chunk.
	var start := ChunkGenerator.region_start_chunk(_region)
	for s in [1, 42, 777, 123456789, 5, 6]:
		var map := BosqueMap.build(s, _grid)
		var home := map.bosque_at(start)
		var chunks := {}
		for c in map.chunks_of(home):
			chunks[c] = ChunkGenerator.generate(s, c, _region, map)
		var reached := _flood(chunks, start, (chunks[start] as ChunkData).hub)
		for c in map.chunks_of(home):
			assert_true(reached.has(c), "seed %d: chunk %s del Bosque %d aislado" % [s, c, home])


func _chunk_of(world_cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(world_cell.x) / ChunkData.SIZE), floori(float(world_cell.y) / ChunkData.SIZE))


func _flood(chunks: Dictionary, start: Vector2i, hub: Vector2i) -> Dictionary:
	var first: Vector2i = start * ChunkData.SIZE + hub
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
