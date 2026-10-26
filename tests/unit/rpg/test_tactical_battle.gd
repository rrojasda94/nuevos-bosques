extends GutTest
## Turnos CT, movimiento y orientación del combate táctico (combate-tactico.md, PR T2). Usa un bloque
## tactical fijo de test (los valores de balance.json se ajustan en playtest).

const TACTICAL: Dictionary = {
	"board": { "width": 8, "height": 6, "deploy_columns": 2, "max_per_side": 3, "ford_cost": 1 },
	"movement": { "mov_base": 3, "mov_agi_ref": 5, "mov_agi_div": 2, "mov_min": 2, "mov_max": 6,
		"jump_base": 1, "jump_agi_div": 7, "drop_extra": 1 },
	"ct": { "threshold": 100, "start_per_agi": 10, "cost_move_and_act": 100, "cost_single": 80, "cost_wait": 60 },
}
const P := TacticalBattle.SIDE_PLAYER
const E := TacticalBattle.SIDE_ENEMY


func _battle(fighters: Array, rng_seed: int = 1, board: TacticalBoard = null,
		side: TacticalBoard.Side = TacticalBoard.Side.LEFT) -> TacticalBattle:
	if board == null:
		board = TacticalBoard.from_config(TACTICAL.board)
	return TacticalBattle.new(TACTICAL, board, fighters, rng_seed, side)


# --- Mov y Salto por AGI ------------------------------------------------------------------------

func test_mov_from_agi_matches_sheet() -> void:
	var m: Dictionary = TACTICAL.movement
	assert_eq(TacticalBattle.move_range(5, m), 3, "adoc nivel 1")
	assert_eq(TacticalBattle.move_range(7, m), 4, "adoc desde nivel 4")
	assert_eq(TacticalBattle.move_range(3, m), 2, "Botarramas renquea")
	assert_eq(TacticalBattle.move_range(6, m), 3, "Ofomni")
	assert_eq(TacticalBattle.move_range(0, m), 2, "mínimo 2")
	assert_eq(TacticalBattle.move_range(20, m), 6, "máximo 6")


func test_jump_from_agi_matches_sheet() -> void:
	var m: Dictionary = TACTICAL.movement
	assert_eq(TacticalBattle.jump_height(5, m), 1)
	assert_eq(TacticalBattle.jump_height(6, m), 1)
	assert_eq(TacticalBattle.jump_height(7, m), 2, "reparep / adoc con AGI 7")
	assert_eq(TacticalBattle.jump_height(13, m), 2)
	assert_eq(TacticalBattle.jump_height(14, m), 3)


func test_units_get_mov_jump_and_drop() -> void:
	var b := _battle([{ "id": &"adoc", "side": P, "agi": 7 }, { "id": &"bot", "side": E, "agi": 3 }])
	assert_eq(b.units[0].mov, 4)
	assert_eq(b.units[0].jump, 2)
	assert_eq(b.units[0].drop, 3, "baja Salto + 1")
	assert_eq(b.units[1].mov, 2)


func test_balance_json_has_tactical_block() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/balance.json"))
	var tactical: Dictionary = data.tactical
	for key: String in ["board", "movement", "ct"]:
		assert_true(tactical.has(key), key)
	assert_eq(int(tactical.board.width), 8)
	assert_eq(int(tactical.board.height), 6)
	assert_eq(TacticalBattle.move_range(5, tactical.movement), 3)


# --- Colocación ---------------------------------------------------------------------------------

func test_placement_two_columns_per_side() -> void:
	var b := _battle([
		{ "id": &"adoc", "side": P, "agi": 5 }, { "id": &"ally", "side": P, "agi": 5 },
		{ "id": &"r1", "side": E, "agi": 7 }, { "id": &"r2", "side": E, "agi": 7 }, { "id": &"r3", "side": E, "agi": 7 },
	])
	var seen: Dictionary = {}
	for u: Dictionary in b.units:
		assert_false(seen.has(u.cell), "cada uno en su casilla")
		seen[u.cell] = true
		if u.side == P:
			assert_true(u.cell.x <= 1, "jugador en las 2 columnas de la izquierda")
			assert_eq(u.facing, TacticalBoard.Facing.EAST)
		else:
			assert_true(u.cell.x >= 6, "enemigos en las 2 de la derecha")
			assert_eq(u.facing, TacticalBoard.Facing.WEST)
	assert_eq(b.units[0].cell, Vector2i(1, 2), "el adoc, delante y en el centro")


func test_placement_from_the_right_and_given_cells() -> void:
	var b := _battle([
		{ "id": &"adoc", "side": P, "agi": 5 },
		{ "id": &"bot", "side": E, "agi": 3, "cell": Vector2i(3, 3), "facing": TacticalBoard.Facing.NORTH },
	], 1, null, TacticalBoard.Side.RIGHT)
	assert_true(b.units[0].cell.x >= 6)
	assert_eq(b.units[0].facing, TacticalBoard.Facing.WEST)
	assert_eq(b.units[1].cell, Vector2i(3, 3), "respeta la casilla dada")
	assert_eq(b.units[1].facing, TacticalBoard.Facing.NORTH)


func test_at_most_three_per_side() -> void:
	var fighters: Array = []
	for k in 5:
		fighters.append({ "id": StringName("e%d" % k), "side": E, "agi": 5 })
	fighters.append({ "id": &"adoc", "side": P, "agi": 5 })
	var b := _battle(fighters)
	assert_eq(b.on_board(E), 3, "3 enemigos en el tablero (cupo)")
	assert_eq(b.on_board(P), 1, "el adoc")
	assert_eq(b.waiting_units(E), [3, 4], "los otros 2 esperan en el borde (T1b)")
	assert_eq(b.units[3].cell, Vector2i(-1, -1), "sin casilla mientras esperan")


# --- CT -----------------------------------------------------------------------------------------

func test_initial_ct_is_agi_times_ten() -> void:
	var b := _battle([{ "id": &"adoc", "side": P, "agi": 5 }, { "id": &"rep", "side": E, "agi": 7 }])
	assert_eq(b.ct_of(0), 50)
	assert_eq(b.ct_of(1), 70)


func test_ct_order_fastest_first_and_ticks() -> void:
	var b := _battle([{ "id": &"adoc", "side": P, "agi": 5 }, { "id": &"rep", "side": E, "agi": 7 }])
	# rep: 70 -> 100 en 5 ticks (adoc 75).
	assert_eq(b.begin_turn(), 1)
	assert_eq(b.ct_of(1), 105, "70 + 7 × 5")
	assert_eq(b.ct_of(0), 75)
	assert_eq(b.end_turn(TacticalBoard.Facing.WEST), 60, "esperar")
	assert_eq(b.ct_of(1), 45)
	assert_eq(b.begin_turn(), 0, "adoc: 75 -> 100")
	assert_eq(b.ct_of(0), 100)


func test_ct_tie_goes_to_player_side() -> void:
	var b := _battle([{ "id": &"bot", "side": E, "agi": 5 }, { "id": &"adoc", "side": P, "agi": 5 }])
	assert_eq(b.begin_turn(), 1, "mismo CT: primero el bando del jugador")
	b.end_turn(TacticalBoard.Facing.EAST)
	assert_eq(b.begin_turn(), 0)


func test_ct_tie_within_side_is_seeded_and_deterministic() -> void:
	var fighters: Array = [
		{ "id": &"r1", "side": E, "agi": 7 }, { "id": &"r2", "side": E, "agi": 7 }, { "id": &"r3", "side": E, "agi": 7 },
	]
	var orders: Dictionary = {}
	for s in 30:
		var a := _battle(fighters, s)
		var c := _battle(fighters, s)
		assert_eq(a.preview_order(6), c.preview_order(6), "misma seed, mismo orden")
		orders[a.preview_order(3)] = true
	assert_gt(orders.size(), 1, "la seed decide el empate dentro del bando")


func test_preview_does_not_change_state_and_matches_play() -> void:
	var b := _battle([
		{ "id": &"adoc", "side": P, "agi": 5 }, { "id": &"rep", "side": E, "agi": 7 }, { "id": &"bot", "side": E, "agi": 3 },
	], 3)
	var before: Array = [b.ct_of(0), b.ct_of(1), b.ct_of(2)]
	var preview: Array[int] = b.preview_order(8)
	assert_eq([b.ct_of(0), b.ct_of(1), b.ct_of(2)], before)
	assert_eq(preview.size(), 8)
	var played: Array[int] = []
	for k in 8:
		played.append(b.begin_turn())
		b.mark_acted()
		b.active_moved = true
		b.end_turn(TacticalBoard.Facing.EAST)
	assert_eq(played, preview, "la previsión supone mover y actuar")
	# Más ágil, más turnos.
	var count: Dictionary = { 0: 0, 1: 0, 2: 0 }
	for i: int in b.preview_order(30):
		count[i] += 1
	assert_gt(count[1], count[0])
	assert_gt(count[0], count[2])


func test_preview_during_turn_uses_given_cost() -> void:
	var b := _battle([{ "id": &"adoc", "side": P, "agi": 10 }, { "id": &"bot", "side": E, "agi": 9 }])
	assert_eq(b.begin_turn(), 0, "adoc empieza con CT 100")
	assert_eq(b.preview_order(1, 100)[0], 1, "si mueve y actúa, juega el otro")
	assert_eq(b.preview_order(6), b.preview_order(6, 100), "por defecto, mover y actuar")
	assert_lte(b.preview_order(6, 60).find(0), b.preview_order(6, 100).find(0), "si espera, vuelve antes")
	assert_eq(b.active, 0, "previsualizar no termina el turno")


func test_turn_costs() -> void:
	var b := _battle([{ "id": &"adoc", "side": P, "agi": 10 }, { "id": &"bot", "side": E, "agi": 1 }])
	assert_eq(b.turn_cost(true, true), 100)
	assert_eq(b.turn_cost(true, false), 80)
	assert_eq(b.turn_cost(false, true), 80)
	assert_eq(b.turn_cost(false, false), 60)
	b.begin_turn()
	assert_eq(b.end_turn(TacticalBoard.Facing.EAST), 60, "esperar")
	assert_eq(b.ct_of(0), 40)
	b.begin_turn()
	b.mark_acted()
	assert_eq(b.end_turn(TacticalBoard.Facing.EAST), 80, "solo actuar")
	b.begin_turn()
	var start: Vector2i = b.units[0].cell
	assert_false(b.move_active(start + Vector2i(1, 0)).is_empty())
	b.mark_acted()
	assert_eq(b.end_turn(TacticalBoard.Facing.SOUTH), 100, "mover y actuar")
	assert_eq(b.units[0].facing, TacticalBoard.Facing.SOUTH, "orientación final")


func test_waiting_comes_back_sooner() -> void:
	var waits := _battle([{ "id": &"adoc", "side": P, "agi": 5 }, { "id": &"bot", "side": E, "agi": 5 }])
	var acts := _battle([{ "id": &"adoc", "side": P, "agi": 5 }, { "id": &"bot", "side": E, "agi": 5 }])
	waits.begin_turn()
	waits.end_turn(TacticalBoard.Facing.EAST)
	acts.begin_turn()
	acts.mark_acted()
	acts.active_moved = true
	acts.end_turn(TacticalBoard.Facing.EAST)
	assert_gt(waits.ct_of(0), acts.ct_of(0), "esperar deja más CT")
	assert_eq(waits.ct_of(0) - acts.ct_of(0), 40)


func test_set_ct_for_ambush_and_remove_unit() -> void:
	var b := _battle([{ "id": &"adoc", "side": P, "agi": 3 }, { "id": &"rep", "side": E, "agi": 7 }])
	b.set_ct(0, 100)
	assert_eq(b.begin_turn(), 0, "emboscada: CT 100 juega ya")
	b.end_turn(TacticalBoard.Facing.EAST)
	b.remove_unit(1)
	for k in 3:
		assert_eq(b.begin_turn(), 0, "el retirado no juega")
		b.end_turn(TacticalBoard.Facing.EAST)
	b.remove_unit(0)
	assert_eq(b.begin_turn(), TacticalBattle.NONE, "nadie en pie")


# --- Movimiento ---------------------------------------------------------------------------------

func test_move_within_reach_once_and_faces_last_step() -> void:
	var b := _battle([{ "id": &"adoc", "side": P, "agi": 5 }, { "id": &"bot", "side": E, "agi": 3 }])
	b.set_ct(0, 100)
	assert_eq(b.begin_turn(), 0)
	var start: Vector2i = b.units[0].cell
	assert_true(b.move_active(start + Vector2i(4, 0)).is_empty(), "Mov 3: 4 casillas no")
	var path: Array[Vector2i] = b.move_active(start + Vector2i(2, 1))
	assert_eq(path.size(), 4)
	assert_eq(b.units[0].cell, start + Vector2i(2, 1))
	var last: Vector2i = path[path.size() - 1] - path[path.size() - 2]
	assert_eq(TacticalBoard.facing_vector(b.units[0].facing), last, "mira hacia donde anduvo")
	assert_true(b.move_active(start).is_empty(), "solo se mueve una vez")
	assert_eq(b.reachable_for(0).size(), 1)


func test_move_blocked_by_enemies_and_occupied_cells() -> void:
	var b := _battle([
		{ "id": &"adoc", "side": P, "agi": 5, "cell": Vector2i(2, 2) },
		{ "id": &"ally", "side": P, "agi": 5, "cell": Vector2i(2, 3) },
		{ "id": &"bot", "side": E, "agi": 3, "cell": Vector2i(3, 2) },
	])
	b.set_ct(0, 200)
	assert_eq(b.begin_turn(), 0)
	var r: Dictionary = b.reachable_for(0)
	assert_false(r.has(Vector2i(3, 2)), "casilla del enemigo")
	assert_false(r.has(Vector2i(2, 3)), "casilla del aliado")
	assert_true(r.has(Vector2i(2, 4)), "se pasa por el aliado")
	assert_true(b.move_active(Vector2i(2, 3)).is_empty())
	assert_eq(b.unit_at(Vector2i(3, 2)), 2)
	assert_eq(b.unit_at(Vector2i(5, 5)), TacticalBattle.NONE)


func test_move_with_heights_uses_unit_jump() -> void:
	var board := TacticalBoard.from_config(TACTICAL.board)
	for y in 6:
		board.set_cell(Vector2i(3, y), 2)
	var slow := _battle([{ "id": &"adoc", "side": P, "agi": 5, "cell": Vector2i(2, 2) }], 1, board)
	var fast := _battle([{ "id": &"adoc", "side": P, "agi": 7, "cell": Vector2i(2, 2) }], 1, board)
	assert_false(slow.reachable_for(0).has(Vector2i(3, 2)), "Salto 1")
	assert_true(fast.reachable_for(0).has(Vector2i(3, 2)), "Salto 2")


# --- Huida por bordes ---------------------------------------------------------------------------

func test_can_flee_only_from_edge() -> void:
	var b := _battle([
		{ "id": &"adoc", "side": P, "agi": 5, "cell": Vector2i(3, 3) },
		{ "id": &"bot", "side": E, "agi": 3, "cell": Vector2i(7, 0) },
	])
	assert_false(b.can_flee(0), "no está en el borde")
	assert_true(b.can_flee(1), "esquina")
	b.set_ct(0, 100)
	b.begin_turn()
	b.move_active(Vector2i(3, 5))
	assert_true(b.can_flee(0), "cualquier borde vale (también el de abajo)")
