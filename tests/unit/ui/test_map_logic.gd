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


func test_save_version_is_21() -> void:
	assert_eq(GameState.SAVE_VERSION, 21, "v20: Mundo 2.0; v21: arma enfundada (P3)")
	assert_eq(int(GameState.to_dict()["save_version"]), 21)


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


func test_arrow_patterns_point_in_eight_directions() -> void:
	var seen: Array = []
	for i: int in 8:
		var pattern: Array[String] = PixelIcons.arrow(i)
		assert_eq(PixelIcons.size_of(pattern), Vector2i(9, 9))
		assert_false(seen.has(pattern), "flecha %d distinta" % i)
		seen.append(pattern)
	assert_eq(PixelIcons.arrow(MapLogic.HERE), PixelIcons.HERE)


# --- Mundo 2.0: vista de la región y brújula en píxeles (M16) ------------------------------------

var _plan: RegionPlan


func _region_plan() -> RegionPlan:
	if _plan == null:
		_plan = RegionPlan.for_region(SEED, &"valle_del_sara")
	return _plan


func after_each() -> void:
	MapLogic.set_region_plan(null)


func test_current_bosques_uses_the_plan_when_registered() -> void:
	var plan: RegionPlan = _region_plan()
	MapLogic.set_region_plan(plan)
	assert_eq(MapLogic.region_plan(), plan)
	assert_same(MapLogic.current_bosques(), plan.bosques, "con plan, el reparto del plan")
	MapLogic.set_region_plan(null)
	assert_null(MapLogic.region_plan())
	assert_not_same(MapLogic.current_bosques(), plan.bosques, "sin plan, el del mundo viejo")


func test_chunk_and_map_pixel_conversions() -> void:
	assert_eq(MapLogic.PX_PER_CHUNK, 10, "misma celda que la rejilla vieja")
	assert_eq(MapLogic.chunk_to_map_px(Vector2i(3, 4)), Vector2i(30, 40))
	assert_eq(MapLogic.map_px_to_chunk(Vector2i(39, 40)), Vector2i(3, 4))
	assert_eq(MapLogic.map_px_to_chunk(Vector2i(-1, 0)), Vector2i(-1, 0), "redondea hacia abajo")
	assert_eq(MapLogic.macro_to_map_px(Vector2i(21, 7)), Vector2i(10, 3))
	assert_eq(MapLogic.macro_to_map_px(Vector2i(19, 19)), Vector2i(9, 9), "última celda gruesa del chunk 0")
	assert_eq(MapLogic.world_pos_to_map_px(Vector2(1280, 640)), Vector2(10, 5))
	for chunk: Vector2i in [Vector2i(0, 0), Vector2i(5, 9), Vector2i(11, 15)]:
		for cell: Vector2i in [Vector2i(0, 0), Vector2i(40, 7), Vector2i(79, 79)]:
			var px := Vector2i(MapLogic.world_pos_to_map_px(WorldCoords.cell_to_world_pos(chunk, cell)).floor())
			assert_eq(MapLogic.map_px_to_chunk(px), chunk, "la casilla %s del chunk %s cae en su celda" % [cell, chunk])


func test_terrain_colors_by_type() -> void:
	var road: int = RegionAuthoring.Road.ROAD
	var bridge: int = RegionAuthoring.Road.BRIDGE
	var none_w: int = RegionAuthoring.Water.NONE
	var none_r: int = RegionAuthoring.Road.NONE
	for level: int in MapLogic.HEIGHT_COLORS.size():
		assert_eq(MapLogic.terrain_color(level, none_w, none_r), MapLogic.HEIGHT_COLORS[level], "nivel %d" % level)
	assert_eq(MapLogic.terrain_color(RegionPlan.LEVEL_PEAK, none_w, none_r), MapLogic.HEIGHT_COLORS[4], "cumbre")
	for w: int in MapLogic.WATER_COLORS:
		assert_eq(MapLogic.terrain_color(2, w, none_r), MapLogic.WATER_COLORS[w], "el agua tapa la altura")
	assert_eq(MapLogic.terrain_color(2, RegionAuthoring.Water.RIVER_NAVIGABLE, bridge), MapLogic.ROAD_COLORS[bridge],
			"el puente tapa el agua")
	assert_eq(MapLogic.terrain_color(1, none_w, road), MapLogic.ROAD_COLORS[road])
	assert_ne(MapLogic.terrain_color(1, none_w, none_r, Color("b55088")), MapLogic.HEIGHT_COLORS[1], "velo del color de hoja")
	assert_eq(MapLogic.terrain_color(1, none_w, none_r, Color("b55088"), true),
			MapLogic.HEIGHT_COLORS[1].lerp(MapLogic.DEAD_TINT, MapLogic.DEAD_TINT_WEIGHT), "Bosque muerto: gris")
	# Contraste a 320×180: los tonos de altura se distinguen entre sí y del camino.
	var road_color: Color = MapLogic.ROAD_COLORS[road]
	for i: int in MapLogic.HEIGHT_COLORS.size():
		var c: Color = MapLogic.HEIGHT_COLORS[i]
		assert_gt(_color_distance(c, road_color), 0.15, "nivel %d frente al camino" % i)
		if i > 0:
			assert_gt(_color_distance(c, MapLogic.HEIGHT_COLORS[i - 1]), 0.15, "nivel %d frente al %d" % [i, i - 1])


func _color_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_region_image_draws_water_and_bosque_borders() -> void:
	var plan: RegionPlan = _region_plan()
	var img: Image = MapLogic.region_image(plan)
	assert_eq(img.get_size(), plan.size_chunks * MapLogic.PX_PER_CHUNK, "un píxel por cada 2×2 celdas gruesas")
	var allowed: Array = MapLogic.WATER_COLORS.values() + MapLogic.ROAD_COLORS.values() + [MapLogic.BORDER_COLOR]
	var checked: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			if plan.water_at(Vector2i(x, y) * MapLogic.MACROS_PER_PX) == RegionAuthoring.Water.RIVER_NAVIGABLE:
				checked += 1
				assert_true(allowed.has(img.get_pixel(x, y)), "agua en (%d, %d)" % [x, y])
	assert_gt(checked, 0, "el Valle del Sara tiene un río navegable")
	var border_found: bool = false
	for cy: int in plan.size_chunks.y:
		for cx: int in range(1, plan.size_chunks.x):
			var c := Vector2i(cx, cy)
			var b: int = plan.bosque_at(c)
			var west: int = plan.bosque_at(c + Vector2i.LEFT)
			if b >= 0 and west >= 0 and b != west:
				var px: Vector2i = MapLogic.chunk_to_map_px(c)
				assert_eq(img.get_pixel(px.x, px.y + 5), MapLogic.BORDER_COLOR, "límite al oeste del chunk %s" % c)
				border_found = true
	assert_true(border_found, "hay Bosques vecinos")


func test_region_places_with_names_and_exploration() -> void:
	var places: Array[Dictionary] = MapLogic.region_places(_region_plan())
	assert_eq(places[0].kind, "villa_natal", "la natal, primera (su rótulo tiene prioridad)")
	assert_eq(places[0].name, "Olss")
	assert_eq(places[0].px, Vector2i(65, 135), "celda gruesa (130, 270) / 2")
	assert_eq(places[0].chunk, Vector2i(6, 13))
	var kinds: Dictionary = {}
	var azhin: Dictionary = {}
	for p: Dictionary in places:
		kinds[p.kind] = true
		if p.kind == "manantial":
			assert_false(p.label, "el nacimiento no lleva rótulo (no cabe)")
		elif p.kind == "lugar":
			assert_true(p.label, "los afluentes llevan su nombre")
		if p.name == "Azhin":
			azhin = p
	for k: String in ["villa", "tarca", "lugar", "manantial"]:
		assert_true(kinds.has(k), "hay %s" % k)
	var none: Array[Vector2i] = []
	assert_eq(MapLogic.visible_places(places, none).size(), 1, "sin explorar, solo la villa natal")
	assert_false(azhin.is_empty())
	var explored: Array[Vector2i] = [azhin.chunk]
	var seen: Array[Dictionary] = MapLogic.visible_places(places, explored)
	assert_true(seen.has(azhin), "Azhin, al explorar su chunk")
	for p: Dictionary in seen:
		assert_true(p.kind == "villa_natal" or p.chunk == azhin.chunk, "%s no está explorado" % p.name)


func test_labels_do_not_overlap_and_stay_inside() -> void:
	var bounds := Rect2i(0, 0, 120, 160)
	var places: Array[Dictionary] = [
		{ "kind": "villa", "name": "Azhin", "px": Vector2i(8, 2), "label": true },
		{ "kind": "villa", "name": "Olss", "px": Vector2i(60, 60), "label": true },
		{ "kind": "aldea", "name": "Ussie", "px": Vector2i(60, 60), "label": true },
		{ "kind": "lugar", "name": "1ro del Sara", "px": Vector2i(118, 158), "label": true },
		{ "kind": "manantial", "name": "Nacimiento", "px": Vector2i(30, 90), "label": false },
	]
	var labels: Array[Dictionary] = MapLogic.layout_labels(places, bounds)
	assert_eq(labels.size(), 4, "el manantial no lleva rótulo")
	var boxes: Array[Rect2i] = []
	for l: Dictionary in labels:
		var box := Rect2i((l.at as Vector2i) - Vector2i.ONE, PixelFont.box_size(l.text))
		assert_true(bounds.encloses(box), "%s dentro del mapa" % l.text)
		for other: Rect2i in boxes:
			assert_false(other.intersects(box), "%s no pisa otro rótulo" % l.text)
		boxes.append(box)
	assert_eq(labels[0].at, Vector2i(1, 6), "Azhin debajo, empujado dentro por la izquierda")
	assert_eq(labels[1].at, Vector2i(53, 64), "Olss debajo de su punto")
	assert_eq(labels[2].at, Vector2i(51, 52), "Ussie, en el mismo punto, encima")


func test_compass_px_points_to_exact_world_pos() -> void:
	var from := Vector2(1000, 1000)
	assert_eq(MapLogic.compass_px(from, from + Vector2(500, 0), "X").index, 0, "este")
	assert_eq(MapLogic.compass_px(from, from + Vector2(0, 500), "X").index, 2, "sur")
	assert_eq(MapLogic.compass_px(from, from + Vector2(-300, -300), "X").index, 5, "noroeste")
	assert_eq(MapLogic.compass_px(from, from + Vector2(-300, 280), "X").index, 3, "suroeste")
	var r: Dictionary = MapLogic.compass_px(from, from + Vector2(100, 100), "Ofomni")
	assert_almost_eq(float(r.angle), PI / 4.0, 0.0001, "ángulo exacto")
	assert_eq(r.label, "Ofomni")
	assert_almost_eq(MapLogic.compass_angle(Vector2.ZERO, Vector2(-1, 0)), PI, 0.0001)
	# Dentro del mismo chunk, hacia la casilla exacta.
	var player: Vector2 = WorldCoords.cell_to_world_pos(Vector2i(4, 4), Vector2i(10, 10))
	assert_eq(MapLogic.compass_px(player, WorldCoords.cell_to_world_pos(Vector2i(4, 4), Vector2i(14, 9)), "X").index, 0,
			"casi al este")
	assert_eq(MapLogic.compass_px(player, WorldCoords.cell_to_world_pos(Vector2i(4, 4), Vector2i(14, 6)), "X").index, 7,
			"noreste")
	var here: Dictionary = MapLogic.compass_px(from, from + Vector2(MapLogic.HERE_RADIUS_PX - 1, 0), "X")
	assert_eq(here.index, MapLogic.HERE)
	assert_eq(here.label, Texts.get_text("compass_here"))
	for i: int in 8:
		var v := Vector2.from_angle(i * PI / 4.0)
		assert_eq(MapLogic.angle_to_index(v.angle()), i)
		assert_eq(MapLogic.angle_to_index(v.angle()), ChunkGenerator.direction_index(Vector2i((v * 3.0).round())),
				"mismo índice que la brújula vieja")


func test_objective_world_pos_from_saved_chunk_and_cell() -> void:
	assert_eq(MapLogic.objective_world_pos(Vector2i(2, 3), Vector2i(10, 20)),
			WorldCoords.cell_to_world_pos(Vector2i(2, 3), Vector2i(10, 20)))
	assert_eq(MapLogic.objective_world_pos(Vector2i(2, 3), Vector2i(-1, -1)),
			Vector2(2.5, 3.5) * WorldCoords.CHUNK_PX, "casilla desconocida: centro del chunk")


func test_compass_world_points_home_or_to_objective() -> void:
	var plan: RegionPlan = _region_plan()
	var home: Vector2 = MapLogic.home_world_pos(plan)
	assert_eq(home, Vector2(130 * 4 * 16 + 32, 270 * 4 * 16 + 32), "centro de la celda gruesa de Olss")
	var none := Vector2i(-1, -1)
	var r: Dictionary = MapLogic.compass_world(plan, home + Vector2(0, -2000), none, none, "")
	assert_eq(r.index, 2, "la villa natal queda al sur")
	assert_eq(r.label, Texts.get_text("compass_villa"))
	assert_eq(MapLogic.compass_world(plan, home + Vector2(4, 4), none, none, "").index, MapLogic.HERE)
	var chunk := Vector2i(3, 3)
	var inside: Vector2 = WorldCoords.cell_to_world_pos(chunk, Vector2i(40, 40))
	r = MapLogic.compass_world(plan, inside, chunk, Vector2i(40, 70), "Ofomni")
	assert_eq(r.index, 2, "a la casilla del objetivo")
	assert_eq(r.label, "Ofomni")
	assert_eq(MapLogic.compass_world(plan, inside, chunk, none, "Ofomni").index, MapLogic.HERE,
			"casilla desconocida: Aquí en el chunk")
	assert_eq(MapLogic.compass_world(plan, inside, chunk + Vector2i(-2, 0), none, "Ofomni").index, 4,
			"fuera del chunk, a su centro")
