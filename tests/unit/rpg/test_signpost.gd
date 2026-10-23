extends GutTest
## Letreros con E (pedido del dueño): villa de destino con nombre determinista, dirección y tiempo
## estimado de camino, para los dos tipos de letrero.

const SEEDS: Array[int] = [1, 42, 777, 123456789]

var _region: Dictionary


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"valle_del_sara")


func test_travel_minutes_from_chunks() -> void:
	# 64 casillas x 0,16 s = 10,24 s por chunk; se redondea hacia arriba.
	assert_almost_eq(Signpost.travel_seconds(1), ChunkData.SIZE * PlayerWalker.STEP_TIME, 0.001)
	assert_eq(Signpost.travel_minutes(0), 1, "mínimo un minuto")
	assert_eq(Signpost.travel_minutes(5), 1, "51 s")
	assert_eq(Signpost.travel_minutes(6), 2, "61 s")
	assert_eq(Signpost.travel_minutes(23), 4, "235 s")
	assert_eq(Signpost.travel_minutes(24), 5, "246 s")


func test_villa_name_is_deterministic_and_from_the_list() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Signpost.NAMES_PATH))
	var names: Array = data.villas
	var differs := false
	for s: int in SEEDS:
		for id: int in 12:
			var n: String = Signpost.villa_name(s, id)
			assert_eq(Signpost.villa_name(s, id), n)
			assert_has(names, n)
			if n != Signpost.villa_name(s + 1, id):
				differs = true
	assert_true(differs, "depende de la seed")


func test_text_per_sign_kind_and_riutash() -> void:
	assert_eq(Signpost.text("Honda", false, Vector2i(1, -1), 23),
		"Hacia Villa Honda: noreste. Unos 4 minutos de camino.")
	assert_eq(Signpost.text("Honda", true, Vector2i.LEFT, 2),
		"Hacia Villa Honda, tu villa natal: oeste. Un minuto de camino.")
	assert_eq(Signpost.text("Honda", true, Vector2i.LEFT, 15, 600.0),
		"Hacia Villa Honda, tu villa natal: oeste. Unos 3 minutos de camino.", "llega antes del riutash")
	assert_eq(Signpost.text("Honda", false, Vector2i.UP, 15, 120.0),
		"Hacia Villa Honda: norte. Unos 3 minutos de camino. Pasarás un riutash por el camino.")


func test_destination_of_both_sign_kinds() -> void:
	var seen_home := false
	var seen_bosque := false
	for s: int in SEEDS:
		var map := BosqueMap.for_region(s, _region)
		var home: int = AdventureRules.home_bosque(map, _region)
		for coord: Vector2i in map.chunks_of(home) + map.chunks_of(map.neighbours_of(home)[0]):
			var chunk := ChunkGenerator.generate(s, coord, _region, map)
			for y: int in ChunkData.SIZE:
				for x: int in ChunkData.SIZE:
					var c := Vector2i(x, y)
					if chunk.get_tile(c) != ChunkData.Tile.SIGN:
						continue
					var dest: Dictionary = Signpost.destination(map, chunk, c, home)
					if chunk.sign_kind(c) == ChunkData.SignKind.HOME_VILLA:
						seen_home = true
						assert_true(dest.to_home)
						assert_eq(dest.bosque_id, home)
						assert_eq(dest.delta, chunk.home_direction, "sigue el camino")
						assert_eq(dest.chunks, map.road_distance(coord))
					else:
						seen_bosque = true
						assert_false(dest.to_home)
						assert_eq(dest.bosque_id, map.bosque_at(coord))
						var straight: Vector2i = map.nujio_chunk[dest.bosque_id] - coord
						assert_eq(dest.delta, straight)
						assert_eq(dest.chunks, absi(straight.x) + absi(straight.y))
	assert_true(seen_home, "hay letreros del camino")
	assert_true(seen_bosque, "hay letreros de Bosque")
