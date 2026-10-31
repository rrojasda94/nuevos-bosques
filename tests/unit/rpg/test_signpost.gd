extends GutTest
## Letreros con E (pedido del dueño): villa de destino con nombre determinista, dirección y tiempo
## estimado de camino, para los dos tipos de letrero.

const SEEDS: Array[int] = [1, 42, 777, 123456789]

var _region: Dictionary


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"valle_del_sara")


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
	assert_eq(Signpost.text_for_seconds("Honda", false, Vector2i(1, -1), 235.0),
		"Hacia Villa Honda: noreste. Unos 4 minutos de camino.")
	assert_eq(Signpost.text_for_seconds("Honda", true, Vector2i.LEFT, 20.0),
		"Hacia Villa Honda, tu villa natal: oeste. Un minuto de camino.")
	assert_eq(Signpost.text_for_seconds("Honda", true, Vector2i.LEFT, 154.0, 600.0),
		"Hacia Villa Honda, tu villa natal: oeste. Unos 3 minutos de camino.", "llega antes del riutash")
	assert_eq(Signpost.text_for_seconds("Honda", false, Vector2i.UP, 154.0, 120.0),
		"Hacia Villa Honda: norte. Unos 3 minutos de camino. Pasarás un riutash por el camino.")


# --- Mundo 2.0 (ADR 0014 §2, mundo-2.md §2) ----------------------------------------------------

func _getter(chunks: Dictionary) -> Callable:
	return func(c: Vector2i) -> WorldChunk: return chunks.get(c)


func _sign_chunk(coord: Vector2i = Vector2i.ZERO) -> WorldChunk:
	var chunk := WorldChunk.new()
	chunk.coord = coord
	chunk.add_sign(Vector2i(10, 9), WorldChunk.SignKind.HOME_VILLA, Vector2i.LEFT)
	chunk.rebuild_blocked()
	return chunk


func test_travel_time_world_uses_walk_speed() -> void:
	# 80 casillas × 16 px / 100 px/s = 12,8 s por chunk (mundo-2.md §2).
	assert_almost_eq(Signpost.travel_seconds_world(1), 12.8, 0.001)
	assert_eq(Signpost.travel_minutes_world(0), 1, "mínimo un minuto")
	assert_eq(Signpost.travel_minutes_world(4), 1, "51,2 s")
	assert_eq(Signpost.travel_minutes_world(5), 2, "64 s")
	assert_eq(Signpost.text_world("Honda", false, Vector2i.UP, 5),
		"Hacia Villa Honda: norte. Unos 2 minutos de camino.")
	assert_eq(Signpost.text_world("Honda", true, Vector2i.LEFT, 5, 60.0),
		"Hacia Villa Honda, tu villa natal: oeste. Unos 2 minutos de camino. Pasarás un riutash por el camino.")


func test_sign_read_on_cell_changed_next_to_it() -> void:
	var get_chunk := _getter({ Vector2i.ZERO: _sign_chunk() })
	var near: Dictionary = Signpost.near_world(get_chunk, Vector2i(11, 10))
	assert_eq(near.world_cell, Vector2i(10, 9), "vale una vecina en diagonal")
	assert_eq(near.cell, Vector2i(10, 9))
	assert_eq(near.sign.kind, WorldChunk.SignKind.HOME_VILLA)
	assert_eq(Signpost.near_world(get_chunk, Vector2i(12, 10)), {}, "a dos casillas no")
	assert_eq(Signpost.sign_entered(get_chunk, Vector2i(12, 11), Vector2i(11, 10)).world_cell, Vector2i(10, 9),
		"al llegar a su lado se lee")
	assert_eq(Signpost.sign_entered(get_chunk, Vector2i(11, 10), Vector2i(10, 10)), {},
		"moverse junto al mismo letrero no lo repite")
	assert_eq(Signpost.sign_entered(get_chunk, Vector2i(10, 10), Vector2i(10, 12)), {}, "al alejarse no")
	assert_false(Signpost.sign_entered(get_chunk, Vector2i(10, 12), Vector2i(10, 10)).is_empty(), "al volver, otra vez")
	assert_eq(Signpost.near_world(_getter({}), Vector2i(11, 10)), {}, "sin chunk cargado no hay letrero")


func test_sign_next_to_the_chunk_border() -> void:
	var east := WorldChunk.new()
	east.coord = Vector2i(1, 0)
	east.add_sign(Vector2i(0, 5), WorldChunk.SignKind.BOSQUE_VILLA, Vector2i.RIGHT)
	east.rebuild_blocked()
	var get_chunk := _getter({ Vector2i.ZERO: _sign_chunk(), Vector2i(1, 0): east })
	var near: Dictionary = Signpost.sign_entered(get_chunk, Vector2i(77, 5), Vector2i(79, 5))
	assert_eq(near.coord, Vector2i(1, 0))
	assert_eq(near.cell, Vector2i(0, 5))
	assert_eq(near.world_cell, Vector2i(80, 5))


func test_destination_world_of_both_sign_kinds() -> void:
	var plan := RegionPlan.for_region(42, &"valle_del_sara")
	var map: BosqueMap = plan.bosques
	var home: int = plan.bosque_at(plan.home_chunk)
	var coords: Array[Vector2i] = map.chunks_of(home)
	for n: int in map.neighbours_of(home):
		coords.append_array(map.chunks_of(n))
	var seen_home := false
	var seen_bosque := false
	for coord: Vector2i in coords:
		if seen_home and seen_bosque:
			break
		var chunk: WorldChunk = ChunkBuilder.build(plan, coord)
		for s: Dictionary in chunk.signs:
			var dest: Dictionary = Signpost.destination_world(map, chunk, s.cell, home)
			if s.kind == WorldChunk.SignKind.HOME_VILLA:
				seen_home = true
				assert_true(dest.to_home)
				assert_eq(dest.bosque_id, home)
				assert_eq(dest.delta, s.direction, "sigue el camino")
				assert_eq(dest.chunks, map.road_distance(coord))
			else:
				seen_bosque = true
				assert_false(dest.to_home)
				assert_eq(dest.bosque_id, map.bosque_at(coord))
				var straight: Vector2i = map.nujio_chunk[dest.bosque_id] - coord
				assert_eq(dest.delta, straight)
				assert_eq(dest.chunks, absi(straight.x) + absi(straight.y))
			var text: String = Signpost.text_world(Signpost.villa_name(42, dest.bosque_id), dest.to_home, dest.delta, dest.chunks)
			assert_true(text.begins_with("Hacia Villa "), text)
		assert_eq(Signpost.destination_world(map, chunk, chunk.hub, home), {}, "sin letrero no hay destino")
	assert_true(seen_home, "hay letreros del camino")
	assert_true(seen_bosque, "hay letreros de Bosque")
