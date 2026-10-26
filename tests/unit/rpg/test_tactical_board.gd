extends GutTest
## Tablero lógico del combate táctico (combate-tactico.md, PR T1): casillas, alturas, escaleras,
## obstáculos, alcanzables, caminos, bordes y colocación.

const BOARD_CFG: Dictionary = { "width": 8, "height": 6, "deploy_columns": 2, "max_per_side": 3, "ford_cost": 2 }


func _flat() -> TacticalBoard:
	return TacticalBoard.new(8, 6)


func test_flat_board_is_all_walkable_level_zero() -> void:
	var b := _flat()
	assert_eq(b.width, 8)
	assert_eq(b.height, 6)
	for y in 6:
		for x in 8:
			assert_true(b.is_walkable(Vector2i(x, y)))
			assert_eq(b.level_at(Vector2i(x, y)), 0)
	assert_false(b.is_walkable(Vector2i(8, 0)), "fuera del tablero")
	assert_eq(b.walkable_ratio(), 1.0)


func test_from_cells_reads_world_query_format() -> void:
	var origin := Vector2i(100, 40)
	var cells: Dictionary = {
		origin + Vector2i(1, 1): { "level": 2 },
		origin + Vector2i(2, 1): { "blocked": true },
		origin + Vector2i(3, 1): { "ramp": true, "level": 1 },
		origin + Vector2i(4, 1): { "water": true },
		origin + Vector2i(5, 1): { "water": true, "ford": true },
		origin + Vector2i(6, 1): { "object_kind": "tree" },
		origin + Vector2i(7, 1): { "level": 9 },
		origin + Vector2i(20, 20): { "level": 1 },
	}
	var b := TacticalBoard.from_cells(8, 6, cells, origin)
	assert_eq(b.level_at(Vector2i(1, 1)), 2)
	assert_false(b.is_walkable(Vector2i(2, 1)), "bloqueada")
	assert_true(b.is_stair(Vector2i(3, 1)), "la rampa cuenta como escalera")
	assert_false(b.is_walkable(Vector2i(4, 1)), "agua sin vado")
	assert_true(b.is_walkable(Vector2i(5, 1)), "vado")
	assert_true(b.is_obstacle(Vector2i(6, 1)))
	assert_false(b.is_walkable(Vector2i(6, 1)), "árbol: obstáculo")
	assert_eq(b.level_at(Vector2i(7, 1)), TacticalBoard.MAX_LEVEL, "niveles 0–3")
	var flowers := TacticalBoard.from_cells(8, 6, { Vector2i(0, 0): { "object_kind": "flowers" } },
		Vector2i.ZERO, ["flowers"])
	assert_true(flowers.is_walkable(Vector2i(0, 0)), "objeto que no estorba")


func test_from_config_uses_board_size_and_ford_cost() -> void:
	var b := TacticalBoard.from_config(BOARD_CFG, { Vector2i(1, 0): { "water": true, "ford": true } })
	assert_eq(b.width, 8)
	assert_eq(b.height, 6)
	assert_eq(b.step_cost(Vector2i(1, 0)), 2)
	assert_eq(b.step_cost(Vector2i(2, 0)), 1)


func test_reachable_on_flat_board_is_manhattan_diamond() -> void:
	var b := _flat()
	var r: Dictionary = b.reachable(Vector2i(3, 3), 2, 1, 2)
	assert_eq(r.size(), 13, "rombo de radio 2 (cabe entero)")
	assert_eq(r[Vector2i(3, 3)], 0)
	assert_eq(r[Vector2i(5, 3)], 2)
	assert_false(r.has(Vector2i(5, 4)), "3 pasos")


func test_climbing_needs_jump_and_dropping_jump_plus_one() -> void:
	var b := _flat()
	b.set_cell(Vector2i(4, 3), 2)
	assert_false(b.can_step(Vector2i(3, 3), Vector2i(4, 3), 1, 2), "subir 2 con Salto 1")
	assert_true(b.can_step(Vector2i(3, 3), Vector2i(4, 3), 2, 3), "subir 2 con Salto 2")
	assert_true(b.can_step(Vector2i(4, 3), Vector2i(3, 3), 1, 2), "bajar 2 con Salto 1 (hasta 2)")
	b.set_cell(Vector2i(4, 3), 3)
	assert_false(b.can_step(Vector2i(4, 3), Vector2i(3, 3), 1, 2), "bajar 3 con Salto 1")
	assert_false(b.can_step(Vector2i(3, 3), Vector2i(5, 3), 9, 9), "solo vecinas")


func test_reachable_respects_heights() -> void:
	var b := _flat()
	# Una meseta de nivel 2 en la columna 4 corta el tablero.
	for y in 6:
		b.set_cell(Vector2i(4, y), 2)
	var low: Dictionary = b.reachable(Vector2i(3, 3), 4, 1, 2)
	assert_false(low.has(Vector2i(4, 3)), "Salto 1 no sube 2 niveles")
	assert_false(low.has(Vector2i(5, 3)))
	var high: Dictionary = b.reachable(Vector2i(3, 3), 4, 2, 3)
	assert_true(high.has(Vector2i(4, 3)))
	assert_eq(high[Vector2i(5, 3)], 2, "sube y baja al otro lado")


func test_stairs_cross_heights_without_jump() -> void:
	var b := _flat()
	for y in 6:
		b.set_cell(Vector2i(4, y), 3)
	b.set_cell(Vector2i(4, 5), 3, false, true)
	var r: Dictionary = b.reachable(Vector2i(3, 5), 3, 1, 2)
	assert_true(r.has(Vector2i(4, 5)), "la escalera sube 3 niveles sin Salto")
	assert_true(r.has(Vector2i(5, 5)), "y baja por el otro lado")
	assert_eq(r[Vector2i(4, 4)], 2, "de la escalera a la meseta vecina")
	assert_eq(r[Vector2i(4, 3)], 3, "y por la meseta")
	assert_false(r.has(Vector2i(4, 2)), "fuera de Mov")
	assert_false(b.can_step(Vector2i(3, 3), Vector2i(4, 3), 2, 3), "sin escalera, 3 niveles no se suben")
	assert_false(b.reachable(Vector2i(3, 3), 1, 2, 3).has(Vector2i(4, 3)))


func test_obstacles_water_and_fords() -> void:
	var b := TacticalBoard.from_config(BOARD_CFG)
	for y in 6:
		b.set_cell(Vector2i(3, y), 0, false, false, true)
	var r: Dictionary = b.reachable(Vector2i(2, 2), 6, 1, 2)
	assert_false(r.has(Vector2i(4, 2)), "el agua corta el paso")
	b.set_cell(Vector2i(3, 2), 0, false, false, true, true)
	r = b.reachable(Vector2i(2, 2), 6, 1, 2)
	assert_eq(r[Vector2i(3, 2)], 2, "el vado cuesta ford_cost")
	assert_eq(r[Vector2i(4, 2)], 3)
	b.set_cell(Vector2i(2, 3), 0, false, false, false, false, &"rock")
	r = b.reachable(Vector2i(2, 2), 6, 1, 2)
	assert_false(r.has(Vector2i(2, 3)), "la roca no se pisa")
	assert_true(r.has(Vector2i(2, 4)), "se rodea")
	assert_eq(r[Vector2i(2, 4)], 4)


func test_impassable_and_no_stop_cells() -> void:
	var b := _flat()
	var enemy: Dictionary = { Vector2i(3, 2): true }
	var ally: Dictionary = { Vector2i(2, 3): true }
	var r: Dictionary = b.reachable(Vector2i(2, 2), 2, 1, 2, enemy, ally)
	assert_false(r.has(Vector2i(3, 2)), "no se pisa al enemigo")
	assert_false(r.has(Vector2i(4, 2)), "ni se cruza")
	assert_false(r.has(Vector2i(2, 3)), "no se acaba sobre el aliado")
	assert_true(r.has(Vector2i(2, 4)), "pero se pasa por él")


func test_path_is_shortest_and_deterministic() -> void:
	var b := _flat()
	b.set_cell(Vector2i(3, 2), 0, true)
	var path: Array[Vector2i] = b.path_to(Vector2i(2, 2), Vector2i(4, 2), 6, 1, 2)
	assert_eq(path.size(), 5, "rodea la casilla bloqueada: 4 pasos")
	assert_eq(path[0], Vector2i(2, 2))
	assert_eq(path[path.size() - 1], Vector2i(4, 2))
	for k in range(1, path.size()):
		assert_true(TacticalBoard.are_adjacent(path[k - 1], path[k]))
	assert_eq(b.path_to(Vector2i(2, 2), Vector2i(4, 2), 6, 1, 2), path, "mismo camino")
	assert_eq(b.path_to(Vector2i(2, 2), Vector2i(7, 5), 3, 1, 2), [] as Array[Vector2i], "fuera de Mov")


func test_edges_and_adjacency() -> void:
	var b := _flat()
	assert_true(b.is_edge(Vector2i(0, 3)))
	assert_true(b.is_edge(Vector2i(7, 0)))
	assert_true(b.is_edge(Vector2i(4, 5)))
	assert_false(b.is_edge(Vector2i(3, 3)))
	assert_eq(b.edge_cells().size(), 2 * 8 + 2 * 4)
	b.set_cell(Vector2i(0, 0), 0, true)
	assert_eq(b.edge_cells().size(), 2 * 8 + 2 * 4 - 1, "una bloqueada no sirve para huir")
	assert_true(TacticalBoard.are_adjacent(Vector2i(2, 2), Vector2i(2, 3)))
	assert_false(TacticalBoard.are_adjacent(Vector2i(2, 2), Vector2i(3, 3)), "no en diagonal")
	assert_eq(b.neighbors(Vector2i(0, 0)).size(), 2)
	assert_eq(b.neighbors(Vector2i(3, 3)).size(), 4)


func test_no_cell_is_more_than_three_steps_from_an_edge() -> void:
	var b := _flat()
	for y in 6:
		for x in 8:
			var start := Vector2i(x, y)
			var r: Dictionary = b.reachable(start, 3, 1, 2)
			var near: bool = false
			for c: Vector2i in r:
				near = near or b.is_edge(c)
			assert_true(near, "desde %s se llega a un borde en 3" % start)


func test_deploy_cells_two_columns_per_side() -> void:
	var b := _flat()
	var left: Array[Vector2i] = b.deploy_cells(TacticalBoard.Side.LEFT, 2)
	assert_eq(left.size(), 12)
	for c: Vector2i in left:
		assert_true(c.x <= 1)
	assert_eq(left[0], Vector2i(1, 2), "columna interior, fila del centro (empate: arriba)")
	assert_eq(left[1], Vector2i(1, 3))
	var right: Array[Vector2i] = b.deploy_cells(TacticalBoard.Side.RIGHT, 2)
	for c: Vector2i in right:
		assert_true(c.x >= 6)
	assert_eq(right[0], Vector2i(6, 2))


func test_deploy_skips_blocked_and_extends_when_short() -> void:
	var b := _flat()
	for y in 6:
		b.set_cell(Vector2i(0, y), 0, true)
		if y != 4:
			b.set_cell(Vector2i(1, y), 0, false, false, false, false, &"tree")
	var cells: Array[Vector2i] = b.deploy_cells(TacticalBoard.Side.LEFT, 2, 3)
	assert_eq(cells[0], Vector2i(1, 4))
	assert_eq(cells.size(), 7, "sigue por la columna 2 si faltan casillas")
	assert_true(cells[1].x == 2)


func test_connectivity_ratio_and_span() -> void:
	var b := _flat()
	var left: Array[Vector2i] = b.deploy_cells(TacticalBoard.Side.LEFT, 2)
	var right: Array[Vector2i] = b.deploy_cells(TacticalBoard.Side.RIGHT, 2)
	assert_true(b.has_walk_path(left, right, 1, 2))
	for y in 6:
		b.set_cell(Vector2i(4, y), 0, false, false, true)
	assert_false(b.has_walk_path(left, right, 1, 2), "un río sin vado separa a los bandos")
	assert_almost_eq(b.walkable_ratio(), 42.0 / 48.0, 0.0001)
	b.set_cell(Vector2i(4, 0), 0, false, false, true, true)
	assert_true(b.has_walk_path(left, right, 1, 2), "el vado los une")
	b.set_cell(Vector2i(2, 2), 2)
	assert_eq(b.level_span(), 2)


func test_facing_helpers() -> void:
	assert_eq(TacticalBoard.facing_vector(TacticalBoard.Facing.NORTH), Vector2i(0, -1))
	assert_eq(TacticalBoard.facing_vector(TacticalBoard.Facing.WEST), Vector2i(-1, 0))
	assert_eq(TacticalBoard.facing_toward(Vector2i(2, 2), Vector2i(5, 3)), TacticalBoard.Facing.EAST)
	assert_eq(TacticalBoard.facing_toward(Vector2i(2, 2), Vector2i(2, 0)), TacticalBoard.Facing.NORTH)
	assert_eq(TacticalBoard.facing_toward(Vector2i(2, 2), Vector2i(1, 3)), TacticalBoard.Facing.WEST, "empate: horizontal")
