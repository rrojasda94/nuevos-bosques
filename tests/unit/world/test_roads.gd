extends GutTest
## Red de caminos principales, letreros hacia la villa natal y refugios (ADR 0006).

const SEEDS: Array[int] = [1, 42, 777, 123456789]
const OK_ON_ROAD: Array[int] = [ChunkData.Tile.ROAD, ChunkData.Tile.BRIDGE, ChunkData.Tile.FORD]

var _region: Dictionary
var _maps: Dictionary = {}
var _chunks: Dictionary = {}


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"valle_del_sara")


func _map(seed_value: int) -> BosqueMap:
	if not _maps.has(seed_value):
		_maps[seed_value] = BosqueMap.for_region(seed_value, _region)
	return _maps[seed_value]


func _gen(seed_value: int, coord: Vector2i) -> ChunkData:
	var key := Vector3i(seed_value, coord.x, coord.y)
	if not _chunks.has(key):
		_chunks[key] = ChunkGenerator.generate(seed_value, coord, _region, _map(seed_value))
	return _chunks[key]


func _road_chunks(map: BosqueMap) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in map.grid_size.y:
		for x in map.grid_size.x:
			if map.has_road(Vector2i(x, y)):
				out.append(Vector2i(x, y))
	return out


## Chunks del camino a casa desde `from`, siguiendo road_home_side (incluye from y la villa).
func _path_home(map: BosqueMap, from: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [from]
	var c := from
	while map.road_home_side(c) != Vector2i.ZERO and out.size() < 400:
		c += map.road_home_side(c)
		out.append(c)
	return out


func test_every_nujio_reaches_home_villa_by_road() -> void:
	for s in range(1, 41):
		var map := _map(s)
		var home: Vector2i = map.nujio_chunk[map.home_bosque]
		assert_eq(map.home_bosque, AdventureRules.home_bosque(map, _region), "raíz = Bosque natal")
		# BFS por chunks unidos por lados de camino (en los dos sentidos).
		var seen := { home: true }
		var queue: Array[Vector2i] = [home]
		var head := 0
		while head < queue.size():
			var c: Vector2i = queue[head]
			head += 1
			for d in map.road_sides(c):
				assert_true(map.road_sides(c + d).has(-d), "seed %d: lado %s de %s sin pareja" % [s, d, c])
				assert_ne(map.bosque_at(c + d), -1, "seed %d: camino fuera de la región" % s)
				if not seen.has(c + d):
					seen[c + d] = true
					queue.append(c + d)
		for id in map.count():
			assert_true(seen.has(map.nujio_chunk[id]), "seed %d: el Nujio del Bosque %d no llega a casa" % [s, id])
			var path := _path_home(map, map.nujio_chunk[id])
			assert_eq(path[-1], home, "seed %d: road_home_side lleva a casa desde el Bosque %d" % [s, id])
			assert_eq(path.size() - 1, map.road_distance(map.nujio_chunk[id]))


func test_road_network_is_spanning_tree_plus_some_cycles() -> void:
	var with_cycles := 0
	for s in range(1, 41):
		var map := _map(s)
		var adjacency := 0
		for id in map.count():
			for n in map.neighbours_of(id):
				if n > id:
					adjacency += 1
		assert_between(map.road_edges.size(), map.count() - 1, adjacency, "seed %d" % s)
		if map.road_edges.size() > map.count() - 1:
			with_cycles += 1
	assert_gt(with_cycles, 10, "aristas extra en bastantes seeds (%d de 40)" % with_cycles)


func test_road_network_is_deterministic_by_seed() -> void:
	var size := ChunkGenerator.region_size(_region)
	var start := ChunkGenerator.region_start_chunk(_region)
	for s in SEEDS:
		var a := BosqueMap.build(s, size, start)
		var b := BosqueMap.build(s, size, start)
		assert_eq(a.road_edges, b.road_edges, "seed %d" % s)
		for y in size.y:
			for x in size.x:
				var c := Vector2i(x, y)
				assert_eq(a.road_sides(c), b.road_sides(c))
				assert_eq(a.road_home_side(c), b.road_home_side(c))
	assert_ne(_road_chunks(_map(1)), _road_chunks(_map(2)), "otra seed, otra red")


func test_road_tiles_are_walkable_connected_and_never_on_bare_water() -> void:
	assert_true(ChunkData.is_walkable_tile(ChunkData.Tile.ROAD))
	for s in [1, 42, 777]:
		var map := _map(s)
		var terrain := ChunkGenerator.Terrain.new(s, _region)
		for c in _road_chunks(map).slice(0, 14):
			var chunk := _gen(s, c)
			assert_gt(chunk.tiles.count(ChunkData.Tile.ROAD), 0, "seed %d chunk %s: hay camino" % [s, c])
			for y in ChunkData.SIZE:
				for x in ChunkData.SIZE:
					var cell := Vector2i(x, y)
					if chunk.get_tile(cell) != ChunkData.Tile.ROAD:
						continue
					var base := terrain.tile_at(c.x * ChunkData.SIZE + x, c.y * ChunkData.SIZE + y)
					if ChunkData.is_river(base) or base == ChunkData.Tile.FORD:
						fail_test("seed %d chunk %s: camino sobre agua en %s" % [s, c, cell])
					if not chunk.is_reachable(cell):
						fail_test("seed %d chunk %s: tramo de camino aislado en %s" % [s, c, cell])
			# La puerta del camino ocupa las mismas casillas del borde a los dos lados.
			for side in map.road_sides(c):
				var other := _gen(s, c + side)
				var g := ChunkGenerator.gate_index(s, c, side)
				for along in [g, g + 1]:
					var mine := ChunkData.border_cell(side, along)
					var theirs := ChunkData.border_cell(-side, along)
					assert_has(OK_ON_ROAD, chunk.get_tile(mine), "seed %d chunk %s lado %s" % [s, c, side])
					assert_has(OK_ON_ROAD, other.get_tile(theirs), "seed %d vecino %s lado %s" % [s, c + side, -side])
					assert_true(chunk.is_reachable(mine) and other.is_reachable(theirs))


func test_road_home_is_walkable_across_chunks() -> void:
	# Flood fill por casillas a través de los chunks del camino a casa desde el Nujio más lejano.
	for s in [1, 42, 777]:
		var map := _map(s)
		var far: Vector2i = map.nujio_chunk[0]
		for id in map.count():
			if map.road_distance(map.nujio_chunk[id]) > map.road_distance(far):
				far = map.nujio_chunk[id]
		var path := _path_home(map, far)
		var chunks := {}
		for c in path:
			chunks[c] = _gen(s, c)
		var reached := _flood(chunks, far, (chunks[far] as ChunkData).hub)
		assert_true(reached.has(path[-1]), "seed %d: de %s a la villa natal a pie (%d chunks)" % [s, far, path.size()])


func test_refuges_density_and_reachability() -> void:
	var refuges := 0
	var road := 0
	for s in range(1, 41):
		var map := _map(s)
		for c in _road_chunks(map):
			road += 1
			if map.has_refuge(c):
				refuges += 1
		# Yendo a casa, nunca más de 3 chunks seguidos sin refugio (la villa cuenta).
		for id in map.count():
			var gap := 0
			for c in _path_home(map, map.nujio_chunk[id]):
				gap = 0 if map.has_refuge(c) or map.road_distance(c) == 0 else gap + 1
				assert_lte(gap, 2, "seed %d: tramo largo sin refugio en %s" % [s, c])
	assert_between(float(refuges) / road, 0.3, 0.5, "%d refugios en %d chunks de camino" % [refuges, road])
	for s in [1, 42]:
		var map := _map(s)
		for c in _road_chunks(map).slice(0, 16):
			var chunk := _gen(s, c)
			var count := chunk.tiles.count(ChunkData.Tile.REFUGE)
			var expected := 1 if map.has_refuge(c) and not chunk.has_villa else 0
			assert_eq(count, expected, "seed %d chunk %s" % [s, c])
			if count == 0:
				continue
			var cell := Vector2i(chunk.tiles.find(ChunkData.Tile.REFUGE) % ChunkData.SIZE, chunk.tiles.find(ChunkData.Tile.REFUGE) / ChunkData.SIZE)
			assert_true(chunk.is_refuge(cell))
			assert_true(chunk.is_walkable(cell), "el refugio no bloquea")
			assert_true(chunk.is_reachable(cell), "seed %d chunk %s: refugio alcanzable" % [s, c])


func test_home_signs_point_along_the_road_home() -> void:
	for s in [1, 42, 777]:
		var map := _map(s)
		for c in _road_chunks(map).slice(0, 20):
			var chunk := _gen(s, c)
			var home_side := map.road_home_side(c)
			var wanted := home_side != Vector2i.ZERO and (map.road_sides(c).size() >= 3 or posmod(c.x + c.y, 2) == 0)
			if not wanted:
				assert_eq(chunk.home_sign, Vector2i(-1, -1), "seed %d chunk %s: sin letrero de camino" % [s, c])
				continue
			assert_eq(chunk.get_tile(chunk.home_sign), ChunkData.Tile.SIGN, "seed %d chunk %s" % [s, c])
			assert_eq(chunk.sign_kind(chunk.home_sign), ChunkData.SignKind.HOME_VILLA)
			assert_eq(chunk.home_direction, home_side, "apunta al siguiente tramo hacia casa")
			assert_true(map.road_distance(c + home_side) < map.road_distance(c), "ese tramo acerca a casa")
			assert_true(chunk.is_reachable(chunk.home_sign), "seed %d chunk %s: letrero alcanzable" % [s, c])
	# Por el camino a casa hay letrero al menos un chunk de cada dos.
	for s in range(1, 21):
		var map := _map(s)
		for id in map.count():
			var path := _path_home(map, map.nujio_chunk[id])
			for i in path.size() - 2:
				var a := posmod(path[i].x + path[i].y, 2) == 0 or map.road_sides(path[i]).size() >= 3
				var b := posmod(path[i + 1].x + path[i + 1].y, 2) == 0 or map.road_sides(path[i + 1]).size() >= 3
				assert_true(a or b, "seed %d: dos chunks seguidos sin letrero en %s" % [s, path[i]])


func test_bosque_villa_signs_are_still_bosque_kind() -> void:
	var chunk := ChunkData.new()
	chunk.home_sign = Vector2i(3, 4)
	assert_eq(chunk.sign_kind(Vector2i(3, 4)), ChunkData.SignKind.HOME_VILLA)
	assert_eq(chunk.sign_kind(Vector2i(5, 5)), ChunkData.SignKind.BOSQUE_VILLA)


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
