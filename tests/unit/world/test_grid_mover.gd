extends GutTest
## GridMover (ADR 0014 §2): deslizamiento, ayuda de esquina, diagonales cerradas, velocidad,
## cell_changed, facing y determinismo. Mapas en texto: "#" bloqueada, fuera del mapa bloqueada.

const DT: float = 1.0 / 60.0
const WALK: float = 100.0
const T: int = GridMover.TILE

const OPEN: Array[String] = [
	"##########",
	"#........#",
	"#........#",
	"#........#",
	"#........#",
	"#........#",
	"##########",
]
## Pasillo de 2 casillas (columnas 5 y 6) que sube desde la sala de abajo.
const CORRIDOR: Array[String] = [
	"############",
	"#####..#####",
	"#####..#####",
	"#####..#####",
	"#..........#",
	"#..........#",
	"#..........#",
	"############",
]
## Diagonal cerrada: (2,1) y (1,2) bloqueadas; (1,1) y (2,2) libres.
const DIAGONAL: Array[String] = [
	"#####",
	"#.#.#",
	"##..#",
	"#...#",
	"#####",
]


func _blocker(map: Array[String]) -> Callable:
	return func(c: Vector2i) -> bool:
		if c.y < 0 or c.y >= map.size() or c.x < 0 or c.x >= map[c.y].length():
			return true
		return map[c.y][c.x] == "#"


func _mover(pos: Vector2) -> GridMover:
	var m := GridMover.new(Vector2(10, 6), 5.0, WALK)
	m.place(pos)
	return m


func _run(m: GridMover, input: Vector2, ticks: int, map: Array[String], speed: float = WALK) -> void:
	var blocked: Callable = _blocker(map)
	for _i: int in ticks:
		m.step(input, speed, DT, blocked)


func _box_overlaps_blocked(m: GridMover, map: Array[String]) -> bool:
	var r: Rect2 = m.get_rect()
	var blocked: Callable = _blocker(map)
	for cy: int in range(floori(r.position.y / T), floori(r.end.y / T) + 1):
		for cx: int in range(floori(r.position.x / T), ceili(r.end.x / T)):
			if blocked.call(Vector2i(cx, cy)):
				return true
	return false


func test_config_loads_provisional_values() -> void:
	assert_eq(MovementConfig.walk_speed(), 100.0)
	assert_eq(MovementConfig.run_speed(), 200.0)
	assert_eq(MovementConfig.corner_assist_px(), 5.0)
	assert_eq(MovementConfig.hitbox(), Vector2(10, 6))
	var m: GridMover = GridMover.from_config()
	assert_eq(m.hitbox, Vector2(10, 6))


func test_pushing_into_wall_snaps_to_edge() -> void:
	var m := _mover(GridMover.cell_center(Vector2i(7, 3)))
	_run(m, Vector2.RIGHT, 60, OPEN)
	# Pared en la columna 9: el borde derecho de la caja queda pegado a x = 144.
	assert_almost_eq(m.world_pos.x, 9.0 * T - 5.0, 0.001)
	assert_eq(m.world_pos.y, GridMover.cell_center(Vector2i(7, 3)).y, "No se desvía en y")
	assert_false(_box_overlaps_blocked(m, OPEN))


func test_slides_along_wall_when_moving_diagonally() -> void:
	var m := _mover(GridMover.cell_center(Vector2i(1, 1)))
	_run(m, Vector2(1, -1), 30, OPEN)
	# Techo en la fila 0: la caja se pega abajo de él (y = 16 + 6) y sigue avanzando en x.
	assert_almost_eq(m.world_pos.y, 1.0 * T + 6.0, 0.001)
	assert_gt(m.world_pos.x, GridMover.cell_center(Vector2i(1, 1)).x + 30.0, "Desliza por la pared")
	assert_false(_box_overlaps_blocked(m, OPEN))


func test_feet_cell_never_blocked_when_resting_on_wall_below() -> void:
	var m := _mover(GridMover.cell_center(Vector2i(4, 5)))
	_run(m, Vector2.DOWN, 30, OPEN)
	assert_eq(m.cell, Vector2i(4, 5))
	assert_false(_blocker(OPEN).call(m.cell))
	assert_false(_box_overlaps_blocked(m, OPEN))


func test_corner_assist_enters_two_tile_corridor() -> void:
	# Caja [76, 86): solapa la pared de la columna 4 en 4 px (≤ 5).
	var m := _mover(Vector2(81, 5 * T + 8))
	_run(m, Vector2.UP, 90, CORRIDOR)
	assert_lt(m.cell.y, 3, "Entró en el pasillo")
	assert_gte(m.get_rect().position.x, 5.0 * T - 0.001, "Empujado hacia el hueco")
	assert_false(_box_overlaps_blocked(m, CORRIDOR))


func test_corner_assist_from_the_right_side() -> void:
	# Caja [107, 117): solapa la pared de la columna 7 en 5 px.
	var m := _mover(Vector2(112, 5 * T + 8))
	_run(m, Vector2.UP, 90, CORRIDOR)
	assert_lt(m.cell.y, 3, "Entró en el pasillo")
	assert_lte(m.get_rect().end.x, 7.0 * T + 0.001)


func test_no_corner_assist_beyond_threshold() -> void:
	# Caja [74, 84): solapa la pared 6 px (> 5): se queda pegada debajo.
	var m := _mover(Vector2(79, 5 * T + 8))
	_run(m, Vector2.UP, 90, CORRIDOR)
	assert_eq(m.world_pos.x, 79.0, "Sin empujón lateral")
	assert_almost_eq(m.world_pos.y, 4.0 * T + 6.0, 0.001)


func test_corner_assist_horizontal_into_side_gap() -> void:
	# Hueco de una casilla a la derecha, en la fila 2.
	var map: Array[String] = [
		"######",
		"#..###",
		"#.....",
		"#..###",
		"######",
	]
	# Caja y en [29, 35]: solapa la fila 1 (bloqueada delante) en 3 px.
	var m := _mover(Vector2(40, 2 * T + 3))
	_run(m, Vector2.RIGHT, 60, map)
	assert_gt(m.world_pos.x, 3.0 * T + 8.0, "Pasó por el hueco")
	assert_eq(m.cell.y, 2)
	assert_false(_box_overlaps_blocked(m, map))


func test_diagonal_closed_between_two_corners() -> void:
	var m := _mover(GridMover.cell_center(Vector2i(1, 1)))
	var seen: Array[Vector2i] = []
	m.cell_changed.connect(func(c: Vector2i) -> void: seen.append(c))
	_run(m, Vector2(1, 1), 120, DIAGONAL)
	assert_eq(m.cell, Vector2i(1, 1), "No atraviesa la esquina")
	assert_eq(seen.size(), 0)
	assert_false(_box_overlaps_blocked(m, DIAGONAL))
	# Ni con entrada casi recta ni en sentido contrario.
	_run(m, Vector2(1, 0.02), 60, DIAGONAL)
	_run(m, Vector2(0.02, 1), 60, DIAGONAL)
	assert_eq(m.cell, Vector2i(1, 1))
	var back := _mover(GridMover.cell_center(Vector2i(2, 2)))
	_run(back, Vector2(-1, -1), 120, DIAGONAL)
	assert_eq(back.cell, Vector2i(2, 2))
	assert_false(_box_overlaps_blocked(back, DIAGONAL))


func test_diagonal_speed_equals_axis_speed() -> void:
	var start: Vector2 = GridMover.cell_center(Vector2i(1, 1))
	var axis := _mover(start)
	_run(axis, Vector2.RIGHT, 30, OPEN)
	var diag := _mover(start)
	_run(diag, Vector2(1, 1), 30, OPEN)
	var normalized := _mover(start)
	_run(normalized, Vector2(1, 1).normalized(), 30, OPEN)
	assert_almost_eq(axis.world_pos.distance_to(start), 50.0, 0.01)
	assert_almost_eq(diag.world_pos.distance_to(start), 50.0, 0.01, "La diagonal no es más rápida")
	assert_almost_eq(normalized.world_pos, diag.world_pos, Vector2(0.001, 0.001))
	var run := _mover(start)
	_run(run, Vector2(1, 1), 15, OPEN, 200.0)
	assert_almost_eq(run.world_pos.distance_to(start), 50.0, 0.01)


func test_analog_input_moves_slower() -> void:
	var start: Vector2 = GridMover.cell_center(Vector2i(1, 1))
	var m := _mover(start)
	_run(m, Vector2(0.5, 0), 30, OPEN)
	assert_almost_eq(m.world_pos.x - start.x, 25.0, 0.01)


func test_cell_changed_once_per_change() -> void:
	var m := _mover(GridMover.cell_center(Vector2i(1, 2)))
	var seen: Array[Vector2i] = []
	m.cell_changed.connect(func(c: Vector2i) -> void: seen.append(c))
	_run(m, Vector2.RIGHT, 60, OPEN)  # 100 px: pasa por las casillas 2..7
	assert_eq(seen, [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2),
		Vector2i(6, 2), Vector2i(7, 2)] as Array[Vector2i])
	seen.clear()
	_run(m, Vector2.RIGHT, 60, OPEN)  # llega a la pared y empuja: casilla 8 y nada más
	assert_eq(seen, [Vector2i(8, 2)] as Array[Vector2i])
	assert_eq(m.cell, GridMover.cell_of(m.world_pos))


func test_place_does_not_emit() -> void:
	var m := _mover(Vector2.ZERO)
	watch_signals(m)
	m.place(GridMover.cell_center(Vector2i(3, 3)))
	assert_signal_not_emitted(m, "cell_changed")
	assert_eq(m.cell, Vector2i(3, 3))


func test_facing_dominant_axis() -> void:
	var m := _mover(GridMover.cell_center(Vector2i(4, 3)))
	var blocked: Callable = _blocker(OPEN)
	assert_eq(m.facing, Vector2i.DOWN)
	m.step(Vector2(1, 0.3), WALK, DT, blocked)
	assert_eq(m.facing, Vector2i.RIGHT)
	m.step(Vector2(0.2, -1), WALK, DT, blocked)
	assert_eq(m.facing, Vector2i.UP)
	m.step(Vector2.ZERO, WALK, DT, blocked)
	assert_eq(m.facing, Vector2i.UP, "Sin entrada se conserva")
	m.step(Vector2(-1, -1).normalized(), WALK, DT, blocked)
	assert_eq(m.facing, Vector2i.UP, "Diagonal exacta: conserva si es componente")
	m.step(Vector2(1, 1).normalized(), WALK, DT, blocked)
	assert_eq(m.facing, Vector2i.DOWN, "Diagonal exacta sin componente común: la vertical")
	m.step(Vector2.RIGHT, WALK, DT, blocked)
	m.step(Vector2(1, 1).normalized(), WALK, DT, blocked)
	assert_eq(m.facing, Vector2i.RIGHT)


func test_facing_changes_even_against_wall() -> void:
	var m := _mover(GridMover.cell_center(Vector2i(1, 1)))
	m.step(Vector2.LEFT, WALK, DT, _blocker(OPEN))
	assert_eq(m.facing, Vector2i.LEFT)


func test_animation_and_footsteps_by_distance() -> void:
	var m := _mover(GridMover.cell_center(Vector2i(1, 2)))
	watch_signals(m)
	_run(m, Vector2.RIGHT, 21, OPEN)  # 35 px
	assert_eq(m.anim_frame(), 4)
	assert_signal_emit_count(m, "footstep", 2)
	_run(m, Vector2.RIGHT, 600, OPEN)  # contra la pared: ya no anda
	var frame: int = m.anim_frame()
	_run(m, Vector2.RIGHT, 30, OPEN)
	assert_eq(m.anim_frame(), frame, "Empujar la pared no anima")


func test_deterministic() -> void:
	var a := _mover(GridMover.cell_center(Vector2i(2, 5)))
	var b := _mover(GridMover.cell_center(Vector2i(2, 5)))
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 1234
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 1234
	var blocked: Callable = _blocker(CORRIDOR)
	for _i: int in 2000:
		var in_a := Vector2(rng_a.randf_range(-1, 1), rng_a.randf_range(-1, 1))
		var in_b := Vector2(rng_b.randf_range(-1, 1), rng_b.randf_range(-1, 1))
		a.step(in_a, 200.0, DT, blocked)
		b.step(in_b, 200.0, DT, blocked)
		if _i % 100 == 0:
			assert_false(_box_overlaps_blocked(a, CORRIDOR))
	assert_eq(a.world_pos, b.world_pos)
	assert_eq(a.facing, b.facing)
	assert_eq(a.distance, b.distance)
	assert_false(_box_overlaps_blocked(a, CORRIDOR))


func test_large_delta_does_not_tunnel() -> void:
	var m := _mover(GridMover.cell_center(Vector2i(1, 2)))
	m.step(Vector2.RIGHT, 2000.0, 1.0, _blocker(OPEN))
	assert_almost_eq(m.world_pos.x, 9.0 * T - 5.0, 0.001)
