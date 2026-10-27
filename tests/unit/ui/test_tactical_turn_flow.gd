extends GutTest
## Lógica de la escena táctica (PR T4): entrada -> dirección y cursor, salto entre objetivos,
## cámara con tableros de cualquier tamaño, máquina de estados del turno del jugador, Auto y orden
## al grupo (T5). Bloque tactical fijo de test, sin evasión, para que los golpes acierten.

const TACTICAL: Dictionary = {
	"board": { "width": 8, "height": 6, "deploy_columns": 2, "max_per_side": 3, "ford_cost": 1 },
	"movement": { "mov_base": 3, "mov_agi_ref": 5, "mov_agi_div": 2, "mov_min": 2, "mov_max": 6,
		"jump_base": 1, "jump_agi_div": 7, "drop_extra": 1 },
	"ct": { "threshold": 100, "start_per_agi": 10, "cost_move_and_act": 100, "cost_single": 80, "cost_wait": 60 },
	"actions": { "evasion_base": 0, "evasion_per_agi": 0, "flank_factor": 0.5, "back_factor": 0.0,
		"height_evasion": 0, "hit_min": 5, "hit_max": 100, "flank_bonus": 1, "back_bonus": 2,
		"height_bonus": 1, "support_range": 2 },
	"attack": { "roll_min": 0, "roll_max": 0, "min_damage": 1 },
	"defend_factor": 0.5,
	# Huida (P1): sin enemigos cercanos sale siempre (max 100), para que estos tests no dependan de la tirada.
	"flee": { "max": 100 },
	"finish_below": 0.3,
	"roles": {
		"attacker": { "atk_bonus": 1, "finish_bonus": 3, "finish_uses": 1 },
		"defender": { "def_bonus": 1, "cover_every": 2 },
		"support": { "heal_pct": 20, "heal_uses": 2, "cheer_atk": 2, "cheer_uses": 1 },
	},
}
const P := TacticalBattle.SIDE_PLAYER
const E := TacticalBattle.SIDE_ENEMY
const State := TacticalTurnFlow.State


func _unit(id: StringName, side: int, cell: Vector2i, extra: Dictionary = {}) -> Dictionary:
	var u: Dictionary = { "id": id, "side": side, "agi": 5, "cell": cell, "max_hp": 20, "atk": 6, "def": 2,
		"facing": TacticalBoard.Facing.EAST if side == P else TacticalBoard.Facing.WEST }
	u.merge(extra, true)
	return u


## Combate con el turno ya dado al primero (índice 0).
func _battle(fighters: Array, cfg: Dictionary = TACTICAL) -> TacticalBattle:
	var b := TacticalBattle.new(cfg, TacticalBoard.from_config(cfg.board), fighters, 1)
	for i in b.units.size():
		b.set_ct(i, 0)
	b.set_ct(0, 100)
	assert_eq(b.begin_turn(), 0)
	return b


func _action(name: StringName) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = true
	return e


func _ids(entries: Array[Dictionary]) -> Array:
	return entries.map(func(e: Dictionary) -> StringName: return e.id)


func _entry(entries: Array[Dictionary], id: StringName) -> Dictionary:
	for e: Dictionary in entries:
		if e.id == id:
			return e
	return {}


# --- Entrada y cursor ---------------------------------------------------------------------------

func test_input_maps_to_directions_and_confirm() -> void:
	assert_eq(TacticalTurnFlow.dir_from_event(_action(&"ui_up")), Vector2i.UP)
	assert_eq(TacticalTurnFlow.dir_from_event(_action(&"move_right")), Vector2i.RIGHT, "WASD también")
	assert_eq(TacticalTurnFlow.dir_from_event(_action(&"ui_down")), Vector2i.DOWN)
	assert_eq(TacticalTurnFlow.dir_from_event(_action(&"move_left")), Vector2i.LEFT)
	assert_eq(TacticalTurnFlow.dir_from_event(_action(&"interact")), Vector2i.ZERO)
	assert_true(TacticalTurnFlow.is_accept(_action(&"interact")), "E confirma")
	assert_true(TacticalTurnFlow.is_accept(_action(&"ui_accept")), "Enter confirma")
	assert_true(TacticalTurnFlow.is_cancel(_action(&"ui_cancel")))


func test_step_cursor_stays_inside_any_board_size() -> void:
	assert_eq(TacticalTurnFlow.step_cursor(Vector2i(0, 0), Vector2i.LEFT, 8, 6), Vector2i(0, 0))
	assert_eq(TacticalTurnFlow.step_cursor(Vector2i(7, 5), Vector2i.DOWN, 8, 6), Vector2i(7, 5))
	assert_eq(TacticalTurnFlow.step_cursor(Vector2i(7, 5), Vector2i.RIGHT, 14, 10), Vector2i(8, 5), "14 × 10 deja seguir")
	assert_eq(TacticalTurnFlow.step_cursor(Vector2i(13, 9), Vector2i.DOWN, 14, 10), Vector2i(13, 9))


func test_next_in_direction_jumps_between_targets() -> void:
	var cells: Array[Vector2i] = [Vector2i(3, 2), Vector2i(5, 2), Vector2i(4, 1), Vector2i(4, 3)]
	assert_eq(TacticalTurnFlow.next_in_direction(cells, Vector2i(3, 2), Vector2i.RIGHT), Vector2i(5, 2), "en línea recta antes que en diagonal")
	assert_eq(TacticalTurnFlow.next_in_direction(cells, Vector2i(3, 2), Vector2i.UP), Vector2i(4, 1), "si no, el más cercano por ese lado")
	assert_eq(TacticalTurnFlow.next_in_direction(cells, Vector2i(4, 1), Vector2i.DOWN), Vector2i(4, 3))
	assert_eq(TacticalTurnFlow.next_in_direction(cells, Vector2i(4, 3), Vector2i.DOWN), Vector2i(4, 3), "sin nada debajo, se queda")
	assert_eq(TacticalTurnFlow.next_in_direction(cells, Vector2i(5, 2), Vector2i.LEFT), Vector2i(3, 2))


func test_cell_to_px_raises_each_level() -> void:
	var low: Vector2 = TacticalTurnFlow.cell_to_px(Vector2i(2, 3), 0)
	var high: Vector2 = TacticalTurnFlow.cell_to_px(Vector2i(2, 3), 2)
	assert_eq(low.x, 32.0)
	assert_eq(low.y - high.y, 2.0 * TacticalTurnFlow.LEVEL_PX, "cada nivel sube LEVEL_PX")
	assert_eq(TacticalTurnFlow.cell_to_px(Vector2i(0, 0), TacticalBoard.MAX_LEVEL), Vector2.ZERO, "el margen de arriba cabe el nivel 3")
	assert_eq(TacticalTurnFlow.board_px(8, 6), Vector2(128, 96 + TacticalBoard.MAX_LEVEL * TacticalTurnFlow.LEVEL_PX))


func test_camera_centers_a_board_that_fits() -> void:
	var view := Vector2(220, 118)
	var board: Vector2 = TacticalTurnFlow.board_px(8, 6)
	var off: Vector2 = TacticalTurnFlow.camera_offset(Vector2(8, 8), board, view, Vector2.ZERO, 24.0)
	assert_eq(off, Vector2(46, 5), "8 × 6 centrado, sin moverse con el foco")
	assert_eq(TacticalTurnFlow.camera_offset(Vector2(120, 100), board, view, off, 24.0), off)


func test_camera_follows_focus_on_a_big_board_without_showing_outside() -> void:
	var view := Vector2(220, 118)
	var board: Vector2 = TacticalTurnFlow.board_px(14, 10)
	var at_origin: Vector2 = TacticalTurnFlow.camera_offset(Vector2(8, 20), board, view, Vector2.ZERO, 24.0)
	assert_eq(at_origin, Vector2.ZERO, "esquina de arriba: sin desplazar")
	var far: Vector2 = TacticalTurnFlow.camera_offset(Vector2(13 * 16 + 8, 9 * 16 + 20), board, view, Vector2.ZERO, 24.0)
	assert_eq(far, view - board, "esquina de abajo: el tablero llega justo al borde")
	var mid: Vector2 = TacticalTurnFlow.camera_offset(Vector2(100, 110), board, view, Vector2.ZERO, 24.0)
	assert_eq(mid.y, 118.0 - 24.0 - 110.0, "se mueve lo justo para dejar el margen")
	assert_eq(mid.x, 0.0, "en horizontal el foco ya se ve")


# --- Máquina de estados del turno ---------------------------------------------------------------

func test_main_menu_and_move_flow() -> void:
	var b := _battle([_unit(&"adoc", P, Vector2i(1, 2), { "leader": true }), _unit(&"r", E, Vector2i(6, 2))])
	var f := TacticalTurnFlow.new(b)
	f.begin_player_turn()
	assert_eq(f.state, State.MENU)
	assert_eq(_ids(f.main_entries()), [TacticalTurnFlow.MAIN_MOVE, TacticalTurnFlow.MAIN_ACT, TacticalTurnFlow.MAIN_WAIT])
	assert_false(_entry(f.act_entries(), TacticalTurnFlow.ACT_ATTACK).enabled, "nadie a su alcance")
	f.choose_main(TacticalTurnFlow.MAIN_MOVE)
	assert_eq(f.state, State.MOVE)
	assert_true(f.highlight.has(Vector2i(4, 2)), "Mov 3 llega a (4, 2)")
	assert_false(f.highlight.has(Vector2i(5, 2)))
	assert_eq(f.cursor, Vector2i(1, 2))
	assert_true(f.confirm().is_empty(), "confirmar sobre sí mismo no mueve")
	for k: int in 3:
		f.move_cursor(Vector2i.RIGHT)
	assert_eq(f.cursor, Vector2i(4, 2))
	var res: Dictionary = f.confirm()
	assert_eq(res.kind, TacticalTurnFlow.KIND_MOVE)
	assert_eq(res.path.size(), 4)
	assert_eq(b.units[0].cell, Vector2i(4, 2))
	assert_eq(f.state, State.MENU, "falta actuar: vuelve al menú")
	assert_false(_entry(f.main_entries(), TacticalTurnFlow.MAIN_MOVE).enabled, "ya se movió")
	assert_eq(_entry(f.main_entries(), TacticalTurnFlow.MAIN_WAIT).text, Texts.get_text("tactical_menu_end"))


func test_cancel_goes_back_one_step() -> void:
	var b := _battle([_unit(&"adoc", P, Vector2i(1, 2)), _unit(&"r", E, Vector2i(2, 2))])
	var f := TacticalTurnFlow.new(b)
	f.begin_player_turn()
	f.choose_main(TacticalTurnFlow.MAIN_MOVE)
	f.cancel()
	assert_eq(f.state, State.MENU)
	f.choose_main(TacticalTurnFlow.MAIN_ACT)
	assert_eq(f.state, State.ACT)
	f.choose_act(TacticalTurnFlow.ACT_ATTACK)
	assert_eq(f.state, State.TARGET)
	f.cancel()
	assert_eq(f.state, State.ACT)
	f.choose_act(TacticalTurnFlow.ACT_BACK)
	assert_eq(f.state, State.MENU)
	f.choose_main(TacticalTurnFlow.MAIN_WAIT)
	assert_eq(f.state, State.FACING)
	f.cancel()
	assert_eq(f.state, State.MENU, "sin mover ni actuar se puede volver de la orientación")


func test_attack_with_preview_then_move_then_facing_ends_turn() -> void:
	var b := _battle([_unit(&"adoc", P, Vector2i(1, 2)), _unit(&"r", E, Vector2i(2, 2))])
	var f := TacticalTurnFlow.new(b)
	f.begin_player_turn()
	f.choose_main(TacticalTurnFlow.MAIN_ACT)
	assert_true(_entry(f.act_entries(), TacticalTurnFlow.ACT_ATTACK).enabled)
	assert_true(f.choose_act(TacticalTurnFlow.ACT_ATTACK).is_empty(), "Atacar pide objetivo")
	assert_eq(f.highlight, [Vector2i(2, 2)] as Array[Vector2i])
	assert_eq(f.cursor, Vector2i(2, 2))
	var p: Dictionary = f.cursor_preview()
	assert_eq(p.hit_chance, 100)
	assert_eq(p.relation, TacticalRules.Relation.FRONT)
	var res: Dictionary = f.confirm()
	assert_eq(res.kind, TacticalBattle.KIND_ATTACK)
	assert_eq(res.damage, 4, "ATQ 6 − DEF 2")
	assert_eq(f.state, State.MENU)
	f.choose_main(TacticalTurnFlow.MAIN_MOVE)
	f.move_cursor(Vector2i.UP)
	f.confirm()
	assert_eq(f.state, State.FACING, "movió y actuó: elige orientación")
	f.cancel()
	assert_eq(f.state, State.FACING, "ya no se puede volver")
	f.move_cursor(Vector2i.DOWN)
	assert_eq(f.facing, TacticalBoard.Facing.SOUTH)
	var end: Dictionary = f.confirm()
	assert_eq(end.kind, TacticalTurnFlow.KIND_END)
	assert_eq(end.ct_cost, 100, "mover y actuar")
	assert_eq(b.units[0].facing, TacticalBoard.Facing.SOUTH)
	assert_eq(b.active, TacticalBattle.NONE)
	assert_eq(f.state, State.IDLE)


func test_wait_without_acting_costs_wait() -> void:
	var b := _battle([_unit(&"adoc", P, Vector2i(1, 2)), _unit(&"r", E, Vector2i(6, 2))])
	var f := TacticalTurnFlow.new(b)
	f.begin_player_turn()
	f.choose_main(TacticalTurnFlow.MAIN_WAIT)
	f.move_cursor(Vector2i.UP)
	var end: Dictionary = f.confirm()
	assert_eq(end.kind, TacticalTurnFlow.KIND_END)
	assert_eq(end.text_key, TacticalBattle.TEXT_WAIT)
	assert_eq(end.ct_cost, 60)
	assert_eq(b.units[0].facing, TacticalBoard.Facing.NORTH)


func test_act_menu_shows_role_actions_and_flee_only_on_edge() -> void:
	var support := _unit(&"adoc", P, Vector2i(1, 2), { "role": "support" })
	var b := _battle([support, _unit(&"ally", P, Vector2i(1, 3), { "hp": 10 }), _unit(&"r", E, Vector2i(6, 2))])
	var f := TacticalTurnFlow.new(b)
	f.begin_player_turn()
	var ids: Array = _ids(f.act_entries())
	assert_true(ids.has(TacticalTurnFlow.ACT_BANDAGE))
	assert_true(ids.has(TacticalTurnFlow.ACT_CHEER))
	assert_false(ids.has(TacticalTurnFlow.ACT_COVER), "Cubrir es del defensor")
	assert_false(ids.has(TacticalTurnFlow.ACT_FLEE), "(1, 2) no es borde")
	f.choose_main(TacticalTurnFlow.MAIN_ACT)
	f.choose_act(TacticalTurnFlow.ACT_BANDAGE)
	assert_eq(f.state, State.TARGET)
	assert_true(f.highlight.has(Vector2i(1, 3)))
	f.move_cursor(Vector2i.DOWN)
	var res: Dictionary = f.confirm()
	assert_eq(res.kind, TacticalBattle.KIND_BANDAGE)
	assert_eq(b.units[1].hp, 14)
	var edge := _battle([_unit(&"adoc", P, Vector2i(0, 2)), _unit(&"r", E, Vector2i(6, 2))])
	var g := TacticalTurnFlow.new(edge)
	g.begin_player_turn()
	assert_true(_ids(g.act_entries()).has(TacticalTurnFlow.ACT_FLEE), "en el borde aparece Huir")
	g.choose_main(TacticalTurnFlow.MAIN_ACT)
	var fled: Dictionary = g.choose_act(TacticalTurnFlow.ACT_FLEE)
	assert_eq(fled.kind, TacticalBattle.KIND_FLEE)
	assert_eq(g.state, State.OVER)


func test_offer_luz_entry_carries_toll_and_needs_luz() -> void:
	var b := _battle([_unit(&"adoc", P, Vector2i(1, 2)), _unit(&"r", E, Vector2i(6, 2))])
	b.set_payment(3, 2)
	var f := TacticalTurnFlow.new(b)
	f.begin_player_turn()
	var luz: Dictionary = _entry(f.act_entries(), TacticalTurnFlow.ACT_OFFER_LUZ)
	assert_eq(luz.text, Texts.get_text("tactical_act_offer_luz") % 3)
	assert_false(luz.enabled, "2 de Luz no llegan a 3")
	b.luz = 5
	f.choose_main(TacticalTurnFlow.MAIN_ACT)
	var res: Dictionary = f.choose_act(TacticalTurnFlow.ACT_OFFER_LUZ)
	assert_eq(res.kind, TacticalBattle.KIND_OFFER_LUZ)
	assert_eq(f.state, State.OVER)


func test_flow_works_with_six_per_side_on_a_big_board() -> void:
	var cfg: Dictionary = TACTICAL.duplicate(true)
	cfg.board = { "width": 14, "height": 10, "deploy_columns": 2, "max_per_side": 6, "ford_cost": 1 }
	var fighters: Array = []
	for k: int in 6:
		fighters.append({ "id": StringName("p%d" % k), "side": P, "agi": 5, "max_hp": 20, "atk": 5, "def": 2 })
		fighters.append({ "id": StringName("e%d" % k), "side": E, "agi": 5, "max_hp": 20, "atk": 5, "def": 2 })
	var b := TacticalBattle.new(cfg, TacticalBoard.from_config(cfg.board), fighters, 3)
	assert_eq(b.units.size(), 12, "6 por bando")
	assert_eq(b.preview_order(12).size(), 12)
	var i: int = b.begin_turn()
	var f := TacticalTurnFlow.new(b)
	if b.units[i].side == P:
		f.begin_player_turn()
		f.choose_main(TacticalTurnFlow.MAIN_MOVE)
		for k: int in 20:
			f.move_cursor(Vector2i.RIGHT)
		assert_eq(f.cursor.x, 13, "el cursor llega al borde de un tablero de 14")
	pass_test("6 contra 6")


# --- Auto y orden al grupo (T5) -----------------------------------------------------------------

func test_auto_only_for_allies_and_order_cycles_without_cost() -> void:
	var b := _battle([_unit(&"ally", P, Vector2i(1, 2), { "role": "attacker" }),
		_unit(&"adoc", P, Vector2i(1, 3), { "leader": true }), _unit(&"r", E, Vector2i(6, 2))])
	var f := TacticalTurnFlow.new(b)
	f.begin_player_turn()
	var ids: Array = _ids(f.main_entries())
	assert_true(ids.has(TacticalTurnFlow.MAIN_AUTO), "un aliado puede jugar en Auto")
	assert_true(ids.has(TacticalTurnFlow.MAIN_ORDER), "con aliados, la orden al grupo")
	assert_eq(_entry(f.main_entries(), TacticalTurnFlow.MAIN_ORDER).text,
		Texts.get_text("battle_tactic_order") % Texts.get_text("battle_order_free"))
	f.choose_main(TacticalTurnFlow.MAIN_ORDER)
	assert_eq(b.group_order, BattleLogic.GroupOrder.ATTACK)
	assert_eq(f.state, State.MENU, "cambiar la orden no gasta nada")
	assert_false(b.active_moved or b.active_acted)
	f.choose_main(TacticalTurnFlow.MAIN_ORDER)
	f.choose_main(TacticalTurnFlow.MAIN_ORDER)
	assert_eq(b.group_order, BattleLogic.GroupOrder.FREE, "Libre -> Atacar -> Defender -> Libre")
	f.choose_main(TacticalTurnFlow.MAIN_AUTO)
	assert_eq(f.state, State.IDLE, "Auto: la escena juega el turno con TacticalAI")
	var res: Dictionary = TacticalAI.run_turn(b)
	assert_eq(res.plan.move_to, Vector2i(4, 2), "el atacante en Auto se acerca al enemigo (Mov 3)")
	assert_eq(b.active, TacticalBattle.NONE, "turno terminado")


func test_leader_has_no_auto_and_no_order_without_allies() -> void:
	var b := _battle([_unit(&"adoc", P, Vector2i(1, 2), { "leader": true }), _unit(&"r", E, Vector2i(6, 2))])
	var f := TacticalTurnFlow.new(b)
	f.begin_player_turn()
	var ids: Array = _ids(f.main_entries())
	assert_false(ids.has(TacticalTurnFlow.MAIN_AUTO))
	assert_false(ids.has(TacticalTurnFlow.MAIN_ORDER))
	f.choose_main(TacticalTurnFlow.MAIN_AUTO)
	assert_eq(f.state, State.MENU)
