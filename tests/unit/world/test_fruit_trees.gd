extends GutTest
## Generación de frutales (ADR 0006, bosques-y-relacion.md): determinismo, densidad, alcanzables
## desde una casilla vecina, nunca en la plaza ni en el camino, y dibujo con fruto y vaciado.

const SEEDS: Array[int] = [1, 2, 42, 777, 123456789]

var _region: Dictionary
var _maps: Dictionary = {}


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"valle_del_sara")


func _map(seed_value: int) -> BosqueMap:
	if not _maps.has(seed_value):
		_maps[seed_value] = BosqueMap.for_region(seed_value, _region)
	return _maps[seed_value]


func _gen(seed_value: int, coord: Vector2i, region: Dictionary = _region) -> ChunkData:
	return ChunkGenerator.generate(seed_value, coord, region, _map(seed_value))


## Región igual pero sin frutales (ningún estado da fruto).
func _region_without_fruit() -> Dictionary:
	var r: Dictionary = _region.duplicate(true)
	r.fruit = { "states": [] }
	return r


## Muestra de chunks por seed: el inicial, la villa natal, algunos con camino y otros repartidos.
func _sample(seed_value: int) -> Array[Vector2i]:
	var map: BosqueMap = _map(seed_value)
	var home: int = AdventureRules.home_bosque(map, _region)
	var out: Array[Vector2i] = [ChunkGenerator.region_start_chunk(_region), map.nujio_chunk[home]]
	for c: Vector2i in [Vector2i(0, 0), Vector2i(3, 4), Vector2i(6, 1), Vector2i(9, 9), Vector2i(11, 15), Vector2i(2, 12)]:
		if not out.has(c):
			out.append(c)
	return out


func test_fruit_params_in_region_json() -> void:
	var p: Dictionary = ChunkGenerator.fruit_params(_region)
	assert_eq(str(p.bosque_state), "sano", "todos los Bosques con Nujio, sanos de momento")
	assert_true((p.states as Array).has("sano"))
	assert_eq([int(p.per_chunk[0]), int(p.per_chunk[1])], [3, 6])
	assert_true(ChunkGenerator.bosque_gives_fruit(_region, _map(42), 0))
	assert_false(ChunkGenerator.bosque_gives_fruit(_region, _map(42), -1), "fuera de la región no")
	assert_false(ChunkGenerator.bosque_gives_fruit(_region_without_fruit(), _map(42), 0))


func test_fruit_trees_are_deterministic() -> void:
	for s: int in SEEDS:
		for c: Vector2i in _sample(s):
			var a: ChunkData = _gen(s, c)
			var b: ChunkData = _gen(s, c)
			assert_eq(a.tiles, b.tiles, "seed %d chunk %s" % [s, c])
			assert_eq(a.fruit_trees, b.fruit_trees, "seed %d chunk %s" % [s, c])
	# No depende del orden de visita.
	var first: Array[Vector2i] = _gen(42, Vector2i(6, 13)).fruit_trees
	_gen(42, Vector2i(2, 2))
	assert_eq(_gen(42, Vector2i(6, 13)).fruit_trees, first)
	assert_ne(_gen(1, Vector2i(6, 13)).fruit_trees, _gen(2, Vector2i(6, 13)).fruit_trees, "otra seed, otros frutales")


func test_density_three_to_six_per_chunk() -> void:
	var total: int = 0
	var chunks: int = 0
	for s: int in SEEDS:
		for c: Vector2i in _sample(s):
			var chunk: ChunkData = _gen(s, c)
			var n: int = chunk.tiles.count(ChunkData.Tile.FRUIT_TREE)
			assert_eq(n, chunk.fruit_trees.size(), "seed %d chunk %s: lista y tiles coinciden" % [s, c])
			assert_between(n, 3, 6, "seed %d chunk %s: %d frutales" % [s, c, n])
			total += n
			chunks += 1
	assert_between(float(total) / chunks, 3.5, 5.5, "media por chunk")


func test_fruit_trees_are_spaced() -> void:
	var spacing: int = int(ChunkGenerator.fruit_params(_region).min_spacing)
	for s: int in SEEDS:
		var trees: Array[Vector2i] = _gen(s, Vector2i(6, 13)).fruit_trees
		for i: int in trees.size():
			for j: int in range(i + 1, trees.size()):
				var d: Vector2i = (trees[i] - trees[j]).abs()
				assert_true(maxi(d.x, d.y) >= spacing, "seed %d: %s y %s" % [s, trees[i], trees[j]])


func test_every_fruit_tree_is_reachable_from_a_neighbour() -> void:
	for s: int in SEEDS:
		for c: Vector2i in _sample(s):
			var chunk: ChunkData = _gen(s, c)
			for t: Vector2i in chunk.fruit_trees:
				assert_false(chunk.is_walkable(t), "seed %d %s: bloquea como un árbol" % [s, t])
				var reachable: bool = false
				for d: Vector2i in ChunkData.SIDES:
					reachable = reachable or chunk.is_reachable(t + d)
				assert_true(reachable, "seed %d chunk %s: frutal %s alcanzable" % [s, c, t])
				# Desde esa casilla, E mirando al árbol lo encuentra.
				for d: Vector2i in ChunkData.SIDES:
					if chunk.is_reachable(t + d):
						assert_eq(Interaction.find(chunk, t + d, -d, {}).kind, Interaction.Kind.FRUIT_TREE)
						break


func test_fruit_trees_only_replace_trees() -> void:
	# Mismo chunk sin frutales: cada FRUIT_TREE era un TREE y el resto no cambia, así que nunca
	# hay frutales en la plaza, en el camino, en los senderos ni en el agua.
	var bare: Dictionary = _region_without_fruit()
	for s: int in SEEDS:
		for c: Vector2i in _sample(s):
			var with_fruit: ChunkData = _gen(s, c)
			var without: ChunkData = _gen(s, c, bare)
			assert_eq(without.tiles.count(ChunkData.Tile.FRUIT_TREE), 0)
			var changed: int = 0
			for i: int in with_fruit.tiles.size():
				if with_fruit.tiles[i] != without.tiles[i]:
					changed += 1
					assert_eq(without.tiles[i], ChunkData.Tile.TREE, "seed %d chunk %s: solo sustituye árboles" % [s, c])
					assert_eq(with_fruit.tiles[i], ChunkData.Tile.FRUIT_TREE)
			assert_eq(changed, with_fruit.fruit_trees.size())


func test_no_fruit_trees_near_the_villa_plaza() -> void:
	for s: int in SEEDS:
		var map: BosqueMap = _map(s)
		var home: int = AdventureRules.home_bosque(map, _region)
		var chunk: ChunkData = _gen(s, map.nujio_chunk[home])
		assert_true(chunk.has_villa, "seed %d: villa natal" % s)
		var radius: int = map.nujio_size[home] / 2 + 3 + ChunkGenerator.FRUIT_PLAZA_MARGIN
		for t: Vector2i in chunk.fruit_trees:
			assert_true((t - ChunkData.center()).length_squared() > radius * radius, "seed %d: %s lejos de la plaza" % [s, t])
			for d: Vector2i in ChunkData.SIDES:
				var n: int = chunk.get_tile(t + d) if ChunkData.in_bounds(t + d) else -1
				assert_ne(n, ChunkData.Tile.PLAZA, "seed %d: %s no toca la plaza" % [s, t])


func test_fruit_tree_art_has_fruit_and_empty_variants() -> void:
	var style: Dictionary = { "shape": PlaceholderTileset.Shape.ROUND, "leaf": 0, "trunk": 0, "ground": 0 }
	var source: TileSetAtlasSource = PlaceholderTileset.make_source(style)
	var img: Image = source.texture.get_image()
	var col: int = ChunkData.Tile.FRUIT_TREE * PlaceholderTileset.TILE
	var fruit: Color = PlaceholderTileset.fruit_color(style)[0]
	var ripe: Image = img.get_region(Rect2i(col, 0, 16, 16))
	var empty: Image = img.get_region(Rect2i(col, PlaceholderTileset.FRUIT_EMPTY_VARIANT * 16, 16, 16))
	assert_gt(_count_color(ripe, fruit), 4, "con fruto se ven los frutos")
	assert_eq(_count_color(empty, fruit), 0, "vaciado no")
	# El color del fruto contrasta con las hojas de cada Bosque.
	for leaf: int in PlaceholderTileset.LEAVES.size():
		var pair: Array = PlaceholderTileset.fruit_color({ "leaf": leaf })
		assert_false(PlaceholderTileset.LEAVES[leaf].has(pair[0]), "hoja %d" % leaf)


func _count_color(img: Image, color: Color) -> int:
	var n: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).is_equal_approx(color):
				n += 1
	return n
