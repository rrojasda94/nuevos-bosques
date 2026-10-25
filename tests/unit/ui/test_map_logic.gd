extends GutTest
## Mapa de la región y brújula (navegacion.md): chunks explorados, qué se ve, migración del
## guardado v4 -> v5 y dirección de la brújula.

const SEED: int = 4242

var _region: Dictionary
var _map: BosqueMap


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"valle_del_sara")
	_map = BosqueMap.for_region(SEED, _region)


func before_each() -> void:
	GameState.new_game(SEED, &"valle_del_sara")


func test_mark_explored_adds_once() -> void:
	var explored: Array[Vector2i] = []
	assert_true(MapLogic.mark_explored(explored, Vector2i(3, 4)))
	assert_false(MapLogic.mark_explored(explored, Vector2i(3, 4)), "ya estaba explorado")
	assert_false(MapLogic.mark_explored(explored, Vector2i(-1, -1)), "coordenada inválida")
	assert_eq(explored, [Vector2i(3, 4)] as Array[Vector2i])


func test_explored_chunks_survive_save_and_load() -> void:
	MapLogic.mark_explored(GameState.explored_chunks, Vector2i(6, 13))
	MapLogic.mark_explored(GameState.explored_chunks, Vector2i(7, 13))
	GameState.set_objective(Vector2i(2, 3), "Ofomni", Vector2i(10, 20))
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.new_game(1)
	assert_true(GameState.explored_chunks.is_empty(), "partida nueva sin explorar")
	GameState.from_dict(data)
	assert_eq(GameState.explored_chunks, [Vector2i(6, 13), Vector2i(7, 13)] as Array[Vector2i])
	assert_eq(GameState.objective_chunk, Vector2i(2, 3))
	assert_eq(GameState.objective_cell, Vector2i(10, 20))
	assert_eq(GameState.objective_label, "Ofomni")


func test_migration_v4_marks_only_current_chunk() -> void:
	GameState.chunk_coord = Vector2i(5, 9)
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	data["save_version"] = 4
	data.erase("explored_chunks")
	data.erase("objective_chunk")
	data.erase("objective_cell")
	data.erase("objective_label")
	GameState.new_game(1)
	GameState.from_dict(data)
	assert_eq(GameState.explored_chunks, [Vector2i(5, 9)] as Array[Vector2i])
	assert_false(GameState.has_objective(), "sin objetivo tras migrar")


func test_migration_v4_without_position_has_nothing_explored() -> void:
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	data["save_version"] = 4
	data.erase("explored_chunks")
	GameState.from_dict(data)
	assert_true(GameState.explored_chunks.is_empty(), "(-1, -1): se marcará al entrar en el chunk")


func test_save_version_is_15() -> void:
	assert_eq(GameState.SAVE_VERSION, 15)
	assert_eq(int(GameState.to_dict()["save_version"]), 15)


func test_map_reveals_only_explored_chunks() -> void:
	var explored: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(50, 50)]
	assert_eq(MapLogic.visible_cells(_map, explored), [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i],
			"fuera de la región no se pinta")
	var leaf: int = int(_map.styles[_map.bosque_at(Vector2i(0, 0))].leaf)
	assert_eq(MapLogic.cell_leaf(_map, explored, Vector2i(0, 0)), leaf, "color de hoja de su Bosque")
	assert_eq(MapLogic.cell_leaf(_map, explored, Vector2i(5, 5)), -1, "no explorado: niebla")


func test_roads_refuges_and_villas_only_where_explored() -> void:
	var road_chunks: Array[Vector2i] = []
	var refuge_chunks: Array[Vector2i] = []
	for y: int in _map.grid_size.y:
		for x: int in _map.grid_size.x:
			var c := Vector2i(x, y)
			if _map.has_road(c):
				road_chunks.append(c)
			if _map.has_refuge(c) and _map.has_road(c):
				refuge_chunks.append(c)
	assert_gt(refuge_chunks.size(), 1, "la seed de prueba tiene refugios junto al camino")
	var none: Array[Vector2i] = []
	assert_true(MapLogic.visible_roads(_map, none).is_empty())
	assert_true(MapLogic.visible_refuges(_map, none).is_empty())
	assert_true(MapLogic.visible_villas(_map, none).is_empty())
	var explored: Array[Vector2i] = [refuge_chunks[0]]
	assert_eq(MapLogic.visible_refuges(_map, explored), explored)
	var roads: Dictionary = MapLogic.visible_roads(_map, explored)
	assert_eq(roads.keys(), [refuge_chunks[0]], "solo el tramo del chunk explorado")
	assert_eq(roads[refuge_chunks[0]], _map.road_sides(refuge_chunks[0]))
	assert_eq(MapLogic.visible_villas(_map, road_chunks).size(),
			_map.has_villa.count(true) - 1, "todas las villas tienen camino; la natal va aparte")


func test_compass_points_home_without_objective() -> void:
	var home: Vector2i = MapLogic.home_villa(_map)
	var from: Vector2i = home + Vector2i(0, -3)
	var result: Dictionary = MapLogic.compass(_map, from, Vector2i(10, 10), Vector2i(-1, -1), Vector2i(-1, -1), "")
	assert_eq(result.index, 2, "la villa natal queda al sur")
	assert_eq(result.label, Texts.get_text("compass_villa"))
	result = MapLogic.compass(_map, home + Vector2i(-2, 2), Vector2i(10, 10), Vector2i(-1, -1), Vector2i(-1, -1), "")
	assert_eq(result.index, 7, "noreste")


func test_compass_says_here_in_home_chunk() -> void:
	var home: Vector2i = MapLogic.home_villa(_map)
	var result: Dictionary = MapLogic.compass(_map, home, Vector2i(3, 3), Vector2i(-1, -1), Vector2i(-1, -1), "")
	assert_eq(result.index, MapLogic.HERE)
	assert_eq(result.label, Texts.get_text("compass_here"))


func test_compass_points_to_objective() -> void:
	var result: Dictionary = MapLogic.compass(_map, Vector2i(5, 5), Vector2i(1, 1), Vector2i(8, 5), Vector2i(-1, -1), "Ofomni")
	assert_eq(result.index, 0, "este")
	assert_eq(result.label, "Ofomni")
	result = MapLogic.compass(_map, Vector2i(5, 5), Vector2i(1, 1), Vector2i(2, 2), Vector2i(-1, -1), "Ofomni")
	assert_eq(result.index, 5, "noroeste")


func test_compass_inside_objective_chunk_points_to_cell_or_here() -> void:
	var target := Vector2i(4, 4)
	var result: Dictionary = MapLogic.compass(_map, target, Vector2i(10, 10), target, Vector2i(10, 30), "Ofomni")
	assert_eq(result.index, 2, "la casilla queda al sur")
	assert_eq(result.label, "Ofomni")
	result = MapLogic.compass(_map, target, Vector2i(10, 30), target, Vector2i(10, 30), "Ofomni")
	assert_eq(result.index, MapLogic.HERE, "encima del objetivo")
	assert_eq(result.label, Texts.get_text("compass_here"))
	result = MapLogic.compass(_map, target, Vector2i(10, 10), target, Vector2i(-1, -1), "Ofomni")
	assert_eq(result.index, MapLogic.HERE, "casilla desconocida: Aquí en el chunk")


func test_arrow_patterns_point_in_eight_directions() -> void:
	var seen: Array = []
	for i: int in 8:
		var pattern: Array[String] = PixelIcons.arrow(i)
		assert_eq(PixelIcons.size_of(pattern), Vector2i(9, 9))
		assert_false(seen.has(pattern), "flecha %d distinta" % i)
		seen.append(pattern)
	assert_eq(PixelIcons.arrow(MapLogic.HERE), PixelIcons.HERE)
