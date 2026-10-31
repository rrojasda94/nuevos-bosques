extends GutTest
## Utilidades del mundo que siguen en ChunkGenerator tras borrar el generador viejo (M17b): datos de
## región, relieve y río principal de la ADR 0006 (ChunkGenerator.Terrain, del que parte
## RegionPlan), puertas, direcciones, frutos por estado de Bosque y color del fruto. La generación
## de chunks la prueban test_chunk_builder, test_region_plan y test_places_and_refuges.

const SEEDS: Array[int] = [1, 2, 42, 777, 123456789, 2147483647]

var _region: Dictionary
var _maps: Dictionary = {}


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"valle_del_sara")


func _map(seed_value: int) -> BosqueMap:
	if not _maps.has(seed_value):
		_maps[seed_value] = BosqueMap.for_region(seed_value, _region)
	return _maps[seed_value]


## Altura de la región en casillas de la escala de Terrain (chunks de ChunkData.SIZE).
func _height() -> int:
	return ChunkGenerator.region_size(_region).y * ChunkData.SIZE


func test_region_data_loads() -> void:
	assert_eq(ChunkGenerator.region_size(_region), Vector2i(12, 16))
	assert_true(_region.has("relief") and _region.has("rivers") and _region.has("forest"))
	assert_eq((_region.get("areas", []) as Array).size(), 7)
	assert_true(ChunkGenerator.load_region(&"no_existe").is_empty())


func test_main_river_is_continuous_from_north_to_south() -> void:
	# Cada fila de la región tiene río principal y toca la fila siguiente (conexión 4).
	for s in SEEDS:
		var terrain := ChunkGenerator.Terrain.new(s, _region)
		var breaks := 0
		for y in _height() - 1:
			var a := terrain.river_span(y)
			var b := terrain.river_span(y + 1)
			if a.y < a.x or a.x > b.y or b.x > a.y:
				breaks += 1
		assert_eq(breaks, 0, "seed %d: cortes en el río principal" % s)


func test_main_river_has_fords_regularly() -> void:
	var spacing: int = int((_region.rivers as Dictionary).ford_spacing)
	for s in SEEDS:
		var terrain := ChunkGenerator.Terrain.new(s, _region)
		var last := -1
		var max_gap := 0
		for y in _height():
			if terrain.is_ford_row(y):
				if last >= 0 and y - last > 1:
					max_gap = maxi(max_gap, y - last)
				last = y
		assert_gt(last, 0, "seed %d: hay vados" % s)
		assert_lte(max_gap, spacing * 2, "seed %d: vados como mucho cada %d filas" % [s, spacing * 2])


func test_terrain_is_deterministic_and_depends_on_the_seed() -> void:
	var a := ChunkGenerator.Terrain.new(42, _region)
	var b := ChunkGenerator.Terrain.new(42, _region)
	var c := ChunkGenerator.Terrain.new(43, _region)
	var differs: bool = false
	for i: int in 20:
		var p := Vector2(37.0 * i, 51.0 * i)
		assert_eq(a.elevation(p.x, p.y), b.elevation(p.x, p.y))
		assert_eq(a.river_span(i * 40), b.river_span(i * 40))
		differs = differs or a.elevation(p.x, p.y) != c.elevation(p.x, p.y)
	assert_true(differs, "otra seed, otro relieve")


func test_gates_line_up_between_neighbours() -> void:
	for s in SEEDS:
		var c := Vector2i(2, 3)
		assert_eq(ChunkGenerator.gate_index(s, c, Vector2i.RIGHT), ChunkGenerator.gate_index(s, c + Vector2i.RIGHT, Vector2i.LEFT))
		assert_eq(ChunkGenerator.gate_index(s, c, Vector2i.DOWN), ChunkGenerator.gate_index(s, c + Vector2i.DOWN, Vector2i.UP))


func test_hash_is_stable() -> void:
	assert_eq(ChunkGenerator.hash_ints([1, 2, 3]), ChunkGenerator.hash_ints([1, 2, 3]))
	assert_ne(ChunkGenerator.hash_ints([1, 2, 3]), ChunkGenerator.hash_ints([3, 2, 1]))
	assert_gte(ChunkGenerator.hash_ints([-5, 1 << 40]), 0, "nunca negativo")


func test_direction_names() -> void:
	assert_eq(ChunkGenerator.direction_name(Vector2i(0, -3)), "norte")
	assert_eq(ChunkGenerator.direction_name(Vector2i(2, 2)), "sureste")
	assert_eq(ChunkGenerator.direction_name(Vector2i(-5, 0)), "oeste")
	assert_eq(ChunkGenerator.direction_name(Vector2i(1, -1)), "noreste")
	assert_eq(ChunkGenerator.direction_name(Vector2i.ZERO), "aquí")
	assert_eq(ChunkGenerator._side_towards(Vector2i(5, -2)), Vector2i.RIGHT)
	assert_eq(ChunkGenerator._side_towards(Vector2i(1, -4)), Vector2i.UP)


func test_fruit_params_and_bosque_states() -> void:
	var p: Dictionary = ChunkGenerator.fruit_params(_region)
	assert_false(p.has("bosque_state"), "el estado sale de BosqueMap.state, no de la región")
	assert_true((p.states as Array).has("sano"))
	assert_true((p.states as Array).has("necesita_ayuda"))
	assert_eq([int(p.per_chunk[0]), int(p.per_chunk[1])], [3, 6])
	var map: BosqueMap = _map(42)
	var home: int = map.home_bosque
	assert_eq(ChunkGenerator.bosque_state(_region, map, home), "sano")
	assert_true(ChunkGenerator.bosque_gives_fruit(_region, map, home))
	assert_false(ChunkGenerator.bosque_gives_fruit(_region, map, -1), "fuera de la región no")
	var without: Dictionary = _region.duplicate(true)
	without.fruit = { "states": [] }
	assert_false(ChunkGenerator.bosque_gives_fruit(without, map, home))
	for id: int in map.count():
		var state: String = map.state_of(id)
		assert_eq(ChunkGenerator.bosque_gives_fruit(_region, map, id), state == "sano" or state == "necesita_ayuda",
				"Bosque %d (%s)" % [id, state])


func test_fruit_color_contrasts_with_every_leaf() -> void:
	for leaf: int in PlaceholderTileset.LEAVES.size():
		var pair: Array = PlaceholderTileset.fruit_color({ "leaf": leaf })
		assert_false(PlaceholderTileset.LEAVES[leaf].has(pair[0]), "hoja %d" % leaf)
