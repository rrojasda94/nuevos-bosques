extends GutTest
## Acciones del combate táctico (combate-tactico.md, PR T3): evasión por orientación y altura, bonos
## de daño, desnivel, Defender, Esperar, Ofrecer, Huir, victoria y derrota, roles en la cuadrícula y
## determinismo. Usa un bloque tactical fijo de test (los valores de balance.json se ajustan en
## playtest); la tirada de daño es 0 para que los números sean exactos.

const TACTICAL: Dictionary = {
	"board": { "width": 8, "height": 6, "deploy_columns": 2, "max_per_side": 3, "ford_cost": 1 },
	"movement": { "mov_base": 3, "mov_agi_ref": 5, "mov_agi_div": 2, "mov_min": 2, "mov_max": 6,
		"jump_base": 1, "jump_agi_div": 7, "drop_extra": 1 },
	"ct": { "threshold": 100, "start_per_agi": 10, "cost_move_and_act": 100, "cost_single": 80, "cost_wait": 60 },
	"actions": { "evasion_base": 5, "evasion_per_agi": 2, "flank_factor": 0.5, "back_factor": 0.0,
		"height_evasion": 10, "hit_min": 5, "hit_max": 100, "flank_bonus": 1, "back_bonus": 2,
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
const N := TacticalBoard.Facing.NORTH
const EAST := TacticalBoard.Facing.EAST
const S := TacticalBoard.Facing.SOUTH
const W := TacticalBoard.Facing.WEST
const FRONT := TacticalRules.Relation.FRONT
const FLANK := TacticalRules.Relation.FLANK
const BACK := TacticalRules.Relation.BACK


## Config del test sin evasión (todos los golpes aciertan) para comprobar daños exactos.
func _sure_cfg() -> Dictionary:
	var cfg: Dictionary = TACTICAL.duplicate(true)
	cfg.actions.evasion_base = 0
	cfg.actions.evasion_per_agi = 0
	cfg.actions.height_evasion = 0
	return cfg


func _battle(fighters: Array, cfg: Dictionary = TACTICAL, rng_seed: int = 1,
		board: TacticalBoard = null) -> TacticalBattle:
	if board == null:
		board = TacticalBoard.from_config(cfg.board)
	return TacticalBattle.new(cfg, board, fighters, rng_seed)


## Da el turno a `index` (los demás a CT 0).
func _turn(b: TacticalBattle, index: int) -> void:
	for i in b.units.size():
		b.set_ct(i, 0)
	b.set_ct(index, 100)
	assert_eq(b.begin_turn(), index)


func _unit(id: StringName, side: int, cell: Vector2i, facing: int, extra: Dictionary = {}) -> Dictionary:
	var u: Dictionary = { "id": id, "side": side, "agi": 5, "cell": cell, "facing": facing,
		"max_hp": 30, "atk": 10, "def": 3 }
	u.merge(extra, true)
	return u


# --- Orientación y evasión ----------------------------------------------------------------------

func test_relation_from_facing() -> void:
	var c := Vector2i(3, 3)
	assert_eq(TacticalRules.relation(c, EAST, Vector2i(4, 3)), FRONT)
	assert_eq(TacticalRules.relation(c, EAST, Vector2i(2, 3)), BACK)
	assert_eq(TacticalRules.relation(c, EAST, Vector2i(3, 2)), FLANK)
	assert_eq(TacticalRules.relation(c, EAST, Vector2i(3, 4)), FLANK)
	assert_eq(TacticalRules.relation(c, N, Vector2i(3, 4)), BACK)


func test_evasion_by_facing_matches_sheet() -> void:
	var a: Dictionary = TACTICAL.actions
	assert_eq(TacticalRules.evasion(5, FRONT, 0, a), 15, "adoc nivel 1 de frente")
	assert_eq(TacticalRules.evasion(5, FLANK, 0, a), 7, "de flanco, la mitad hacia abajo")
	assert_eq(TacticalRules.evasion(5, BACK, 0, a), 0, "por la espalda")


func test_evasion_by_height() -> void:
	var a: Dictionary = TACTICAL.actions
	assert_eq(TacticalRules.evasion(5, FRONT, 1, a), 5, "atacante 1 nivel por encima: −10")
	assert_eq(TacticalRules.evasion(5, FRONT, -1, a), 25, "por debajo: +10")
	assert_eq(TacticalRules.evasion(5, FRONT, 2, a), 0, "nunca negativa")
	assert_eq(TacticalRules.evasion(5, BACK, -1, a), 10, "espalda desde abajo")


func test_hit_chance_clamped() -> void:
	var a: Dictionary = TACTICAL.actions
	assert_eq(TacticalRules.hit_chance(15, a), 85)
	assert_eq(TacticalRules.hit_chance(0, a), 100)
	assert_eq(TacticalRules.hit_chance(99, a), 5, "mínimo 5%")


func test_attack_preview_uses_board_heights() -> void:
	var board := TacticalBoard.from_config(TACTICAL.board)
	board.set_cell(Vector2i(2, 2), 1)
	var b := _battle([
		_unit(&"adoc", P, Vector2i(2, 2), EAST),
		_unit(&"bot", E, Vector2i(3, 2), N),
	], TACTICAL, 1, board)
	var p: Dictionary = b.attack_preview(0, 1)
	assert_eq(p.relation, FLANK)
	assert_eq(p.height, 1)
	assert_eq(p.evasion, 0, "flanco 7 − 10 por la altura")
	assert_eq(p.hit_chance, 100)
	assert_eq(p.bonus, 2, "flanco +1, altura +1")


# --- Daño -------------------------------------------------------------------------------------

func test_position_bonus() -> void:
	var a: Dictionary = TACTICAL.actions
	assert_eq(TacticalRules.position_bonus(FRONT, 0, a), 0)
	assert_eq(TacticalRules.position_bonus(FLANK, 0, a), 1)
	assert_eq(TacticalRules.position_bonus(BACK, 0, a), 2)
	assert_eq(TacticalRules.position_bonus(BACK, 2, a), 4, "+1 por nivel a favor")
	assert_eq(TacticalRules.position_bonus(FRONT, -2, a), 0, "en contra no resta")


func test_damage_front_flank_back() -> void:
	var expected: Dictionary = { Vector2i(4, 3): 7, Vector2i(3, 2): 8, Vector2i(2, 3): 9 }
	for cell: Vector2i in expected:
		var b := _battle([
			_unit(&"adoc", P, cell, W),
			_unit(&"bot", E, Vector2i(3, 3), EAST),
		], _sure_cfg())
		_turn(b, 0)
		var r: Dictionary = b.attack(1)
		assert_false(r.missed)
		assert_eq(r.damage, expected[cell], "ATQ 10 − DEF 3 + bono desde %s" % cell)
		assert_eq(b.units[1].hp, 30 - int(expected[cell]))


func test_damage_height_bonus_and_text_keys() -> void:
	var board := TacticalBoard.from_config(TACTICAL.board)
	board.set_cell(Vector2i(2, 3), 1)
	var b := _battle([
		_unit(&"adoc", P, Vector2i(2, 3), EAST),
		_unit(&"bot", E, Vector2i(3, 3), EAST),
	], _sure_cfg(), 1, board)
	_turn(b, 0)
	var r: Dictionary = b.attack(1)
	assert_eq(r.damage, 10, "7 + espalda 2 + altura 1")
	assert_eq(r.text_key, TacticalBattle.TEXT_ATTACK_BACK)
	assert_eq(r.kind, TacticalBattle.KIND_ATTACK)
	assert_eq(r.actor, 0)
	assert_eq(r.target, 1)


func test_miss_uses_falla_key_and_no_damage() -> void:
	var cfg: Dictionary = TACTICAL.duplicate(true)
	cfg.actions.hit_max = 0
	cfg.actions.hit_min = 0
	var b := _battle([_unit(&"adoc", P, Vector2i(2, 3), EAST), _unit(&"bot", E, Vector2i(3, 3), W)], cfg)
	_turn(b, 0)
	var r: Dictionary = b.attack(1)
	assert_true(r.missed)
	assert_eq(r.damage, 0)
	assert_eq(r.text_key, TacticalBattle.TEXT_MISS)
	assert_eq(b.units[1].hp, 30)


func test_strong_hit_every_three_turns() -> void:
	var b := _battle([
		_unit(&"adoc", P, Vector2i(2, 3), EAST, { "strong_every": 3, "strong_factor": 1.5 }),
		_unit(&"bot", E, Vector2i(3, 3), EAST, { "max_hp": 200 }),
	], _sure_cfg())
	var strong: Array = []
	for k in 4:
		_turn(b, 0)
		strong.append(b.attack(1).strong)
		b.end_turn(EAST)
	assert_eq(strong, [true, false, false, true])


# --- Alcance y desnivel -------------------------------------------------------------------------

func test_melee_only_orthogonal_adjacent() -> void:
	var b := _battle([
		_unit(&"adoc", P, Vector2i(2, 2), EAST),
		_unit(&"diag", E, Vector2i(3, 3), W),
		_unit(&"far", E, Vector2i(4, 2), W),
	])
	assert_false(b.can_attack(0, 1), "diagonal no")
	assert_false(b.can_attack(0, 2), "a 2 casillas no")
	assert_eq(b.attack_targets(0), [] as Array[int])


func test_melee_height_limit_is_jump() -> void:
	var board := TacticalBoard.from_config(TACTICAL.board)
	board.set_cell(Vector2i(3, 2), 2)
	board.set_cell(Vector2i(3, 4), 1)
	var b := _battle([
		_unit(&"adoc", P, Vector2i(2, 2), EAST),
		_unit(&"rep", P, Vector2i(2, 4), EAST, { "agi": 7 }),
		_unit(&"high", E, Vector2i(3, 2), W),
		_unit(&"mid", E, Vector2i(3, 4), W),
	], TACTICAL, 1, board)
	assert_false(b.can_attack(0, 2), "Salto 1 no llega 2 niveles arriba")
	assert_true(b.can_attack(1, 3), "1 nivel con Salto 2")
	assert_false(b.can_attack(2, 0), "tampoco hacia abajo 2 niveles con Salto 1")
	b.units[1].cell = Vector2i(4, 2)
	assert_true(b.can_attack(1, 2), "Salto 2 llega 2 niveles")


func test_cannot_attack_own_side_or_twice() -> void:
	var b := _battle([
		_unit(&"adoc", P, Vector2i(2, 3), EAST),
		_unit(&"ally", P, Vector2i(2, 2), EAST),
		_unit(&"bot", E, Vector2i(3, 3), W, { "max_hp": 100 }),
	], _sure_cfg())
	_turn(b, 0)
	assert_eq(b.attack(1), {}, "no a un aliado")
	assert_false(b.attack(2).is_empty())
	assert_eq(b.attack(2), {}, "una acción por turno")
	assert_eq(b.end_turn(EAST), 80, "solo actuó")


# --- Defender y Esperar -------------------------------------------------------------------------

func test_defend_halves_damage_until_next_turn() -> void:
	var b := _battle([
		_unit(&"adoc", P, Vector2i(2, 3), EAST),
		_unit(&"bot", E, Vector2i(3, 3), W, { "max_hp": 100 }),
	], _sure_cfg())
	_turn(b, 1)
	var d: Dictionary = b.defend()
	assert_eq(d.kind, TacticalBattle.KIND_DEFEND)
	assert_eq(d.text_key, TacticalBattle.TEXT_DEFEND)
	assert_eq(b.end_turn(W), 80, "Defender cuenta como acción")
	_turn(b, 0)
	var r: Dictionary = b.attack(1)
	assert_true(r.defended)
	assert_eq(r.damage, 4, "7 × 0,5 hacia arriba")
	b.end_turn(EAST)
	_turn(b, 1)
	assert_false(b.units[1].defending, "se acaba en su siguiente turno")


func test_wait_costs_sixty_and_moving_then_waiting_eighty() -> void:
	var b := _battle([_unit(&"adoc", P, Vector2i(1, 3), EAST), _unit(&"bot", E, Vector2i(6, 3), W)])
	_turn(b, 0)
	var w: Dictionary = b.wait_turn(EAST)
	assert_eq(w.kind, TacticalBattle.KIND_WAIT)
	assert_eq(w.ct_cost, 60)
	assert_eq(b.active, TacticalBattle.NONE)
	_turn(b, 0)
	b.move_active(Vector2i(2, 3))
	assert_eq(b.wait_turn(EAST).ct_cost, 80)


# --- Ofrecer ------------------------------------------------------------------------------------

func test_offer_luz_pays_and_ends_battle() -> void:
	var b := _battle([_unit(&"adoc", P, Vector2i(1, 3), EAST), _unit(&"bot", E, Vector2i(6, 3), W)])
	b.set_payment(3, 5)
	_turn(b, 0)
	var r: Dictionary = b.offer_luz()
	assert_eq(r.kind, TacticalBattle.KIND_OFFER_LUZ)
	assert_eq(r.amount, 3)
	assert_eq(b.luz, 2)
	assert_eq(b.result, TacticalBattle.Result.APPEASED)
	assert_eq(r.result, TacticalBattle.Result.APPEASED)
	assert_true(b.is_over())
	b.end_turn(EAST)
	assert_eq(b.begin_turn(), TacticalBattle.NONE, "nadie juega tras el pago")


func test_offer_needs_luz_and_appeasable_enemies() -> void:
	var b := _battle([_unit(&"adoc", P, Vector2i(1, 3), EAST), _unit(&"bot", E, Vector2i(6, 3), W)])
	b.set_payment(3, 2)
	_turn(b, 0)
	assert_false(b.can_offer_luz(), "no llega la Luz")
	var c := _battle([
		_unit(&"adoc", P, Vector2i(1, 3), EAST),
		_unit(&"ofomni", E, Vector2i(6, 3), W, { "accepts_payment": false }),
	])
	c.set_payment(3, 9, [{ "id": "x", "luz": 5 }])
	_turn(c, 0)
	assert_eq(c.offer_luz(), {}, "el Ofomni descarriado no acepta")
	assert_eq(c.payable_ofrendas(), [] as Array[int])
	assert_false(c.is_over())


func test_offer_ofrenda_completes_with_luz() -> void:
	var b := _battle([_unit(&"adoc", P, Vector2i(1, 3), EAST), _unit(&"bot", E, Vector2i(6, 3), W)])
	b.set_payment(5, 2, [{ "id": "flor", "luz": 3 }])
	_turn(b, 0)
	assert_eq(b.payable_ofrendas(), [0] as Array[int])
	var r: Dictionary = b.offer_ofrenda(0)
	assert_eq(r.kind, TacticalBattle.KIND_OFRENDA)
	assert_eq(r.id, "flor")
	assert_eq(b.luz, 0, "3 de la ofrenda + 2 de Luz")
	assert_eq(b.ofrenda_index, 0)
	assert_eq(b.result, TacticalBattle.Result.APPEASED)


func test_enemy_cannot_offer() -> void:
	var b := _battle([_unit(&"adoc", P, Vector2i(1, 3), EAST), _unit(&"bot", E, Vector2i(6, 3), W)])
	b.set_payment(1, 5)
	_turn(b, 1)
	assert_eq(b.offer_luz(), {})


# --- Huir ---------------------------------------------------------------------------------------

func test_flee_only_from_edge() -> void:
	var b := _battle([
		_unit(&"adoc", P, Vector2i(1, 3), EAST),
		_unit(&"ally", P, Vector2i(1, 2), EAST),
		_unit(&"bot", E, Vector2i(6, 3), W),
	])
	_turn(b, 0)
	assert_false(b.can_flee_now())
	assert_eq(b.flee(), {}, "fuera del borde no aparece")
	b.move_active(Vector2i(0, 3))
	var r: Dictionary = b.flee()
	assert_eq(r.kind, TacticalBattle.KIND_FLEE)
	assert_eq(b.result, TacticalBattle.Result.FLED, "sin nadie cerca sale bien (max) y huye todo el bando")


func test_flee_from_any_edge_cell() -> void:
	for cell: Vector2i in [Vector2i(3, 0), Vector2i(7, 2), Vector2i(4, 5), Vector2i(0, 0)]:
		var b := _battle([_unit(&"adoc", P, cell, EAST), _unit(&"bot", E, Vector2i(5, 3), W)])
		_turn(b, 0)
		assert_false(b.flee().is_empty(), "borde %s" % cell)


func test_enemy_flee_is_not_this_action() -> void:
	var b := _battle([_unit(&"adoc", P, Vector2i(1, 3), EAST), _unit(&"bot", E, Vector2i(7, 3), W)])
	_turn(b, 1)
	assert_eq(b.flee(), {}, "la huida de un enemigo es de la IA (T5)")


# --- Victoria y derrota -------------------------------------------------------------------------

func test_victory_when_enemy_side_empty() -> void:
	var b := _battle([
		_unit(&"adoc", P, Vector2i(2, 3), EAST),
		_unit(&"r1", E, Vector2i(3, 3), W, { "hp": 1 }),
		_unit(&"r2", E, Vector2i(6, 1), W, { "hp": 1 }),
	], _sure_cfg())
	_turn(b, 0)
	var r: Dictionary = b.attack(1)
	assert_true(r.down)
	assert_false(b.units[1].alive, "el caído sale del tablero")
	assert_eq(b.unit_at(Vector2i(3, 3)), TacticalBattle.NONE)
	assert_eq(r.result, TacticalBattle.Result.ONGOING, "queda otro")
	b.end_turn(EAST)
	b.units[0].cell = Vector2i(5, 1)
	_turn(b, 0)
	r = b.attack(2)
	assert_eq(r.result, TacticalBattle.Result.VICTORY)
	assert_true(b.is_over())


func test_defeat_when_leader_falls() -> void:
	var b := _battle([
		_unit(&"adoc", P, Vector2i(2, 3), EAST, { "hp": 1, "leader": true }),
		_unit(&"ally", P, Vector2i(1, 1), EAST),
		_unit(&"bot", E, Vector2i(3, 3), W),
	], _sure_cfg())
	_turn(b, 2)
	var r: Dictionary = b.attack(0)
	assert_eq(r.result, TacticalBattle.Result.DEFEAT, "cae el adoc aunque quede un aliado")


func test_defeat_when_player_side_empty() -> void:
	var b := _battle([
		_unit(&"ally", P, Vector2i(2, 3), EAST, { "hp": 1 }),
		_unit(&"bot", E, Vector2i(3, 3), W),
	], _sure_cfg())
	_turn(b, 1)
	assert_eq(b.attack(0).result, TacticalBattle.Result.DEFEAT)


# --- Roles --------------------------------------------------------------------------------------

func test_cover_takes_hits_for_adjacent_ally() -> void:
	var b := _battle([
		_unit(&"adoc", P, Vector2i(2, 3), EAST),
		_unit(&"guard", P, Vector2i(2, 2), EAST, { "role": "defender" }),
		_unit(&"bot", E, Vector2i(3, 3), W),
	], _sure_cfg())
	assert_eq(b.units[1].def, 4, "+1 DEF de defensor")
	_turn(b, 1)
	var c: Dictionary = b.cover(0)
	assert_eq(c.kind, TacticalBattle.KIND_COVER)
	assert_eq(c.target, 0)
	b.end_turn(EAST)
	_turn(b, 2)
	var r: Dictionary = b.attack(0)
	assert_true(r.covered)
	assert_eq(r.receiver, 1)
	assert_eq(r.damage, 6, "ATQ 10 − DEF 4 del defensor")
	assert_eq(b.units[0].hp, 30)
	assert_eq(b.units[1].hp, 24)


func test_cover_needs_adjacency_and_cooldown() -> void:
	var b := _battle([
		_unit(&"adoc", P, Vector2i(2, 3), EAST),
		_unit(&"guard", P, Vector2i(2, 1), EAST, { "role": "defender" }),
		_unit(&"bot", E, Vector2i(3, 3), W),
	], _sure_cfg())
	_turn(b, 1)
	assert_false(b.can_cover(0), "no es vecino")
	b.move_active(Vector2i(2, 2))
	assert_true(b.can_cover(0))
	b.cover(0)
	b.end_turn(EAST)
	_turn(b, 1)
	assert_false(b.covers.has(0), "el Cubrir dura hasta su siguiente turno")
	assert_false(b.can_cover(0), "cada 2 turnos")
	b.end_turn(EAST)
	_turn(b, 1)
	assert_true(b.can_cover(0))


func test_cover_lost_if_protected_walks_away() -> void:
	var b := _battle([
		_unit(&"adoc", P, Vector2i(2, 3), EAST),
		_unit(&"guard", P, Vector2i(2, 2), EAST, { "role": "defender" }),
		_unit(&"bot", E, Vector2i(4, 4), W),
	], _sure_cfg())
	_turn(b, 1)
	b.cover(0)
	b.end_turn(EAST)
	_turn(b, 0)
	b.move_active(Vector2i(3, 4))
	b.end_turn(EAST)
	_turn(b, 2)
	var r: Dictionary = b.attack(0)
	assert_false(r.covered, "ya no es vecino de su defensor")
	assert_eq(r.receiver, 0)


func test_bandage_range_two_and_uses() -> void:
	var b := _battle([
		_unit(&"adoc", P, Vector2i(1, 3), EAST, { "hp": 10 }),
		_unit(&"healer", P, Vector2i(1, 1), EAST, { "role": "support" }),
		_unit(&"far", P, Vector2i(4, 1), EAST, { "hp": 10 }),
		_unit(&"bot", E, Vector2i(7, 3), W),
	])
	_turn(b, 1)
	assert_false(b.can_bandage(2), "a 3 casillas no llega")
	var r: Dictionary = b.bandage(0)
	assert_eq(r.kind, TacticalBattle.KIND_BANDAGE)
	assert_eq(r.amount, 6, "20% de 30")
	assert_eq(b.units[0].hp, 16)
	b.end_turn(EAST)
	_turn(b, 1)
	b.units[0].hp = 28
	assert_eq(b.bandage(0).amount, 2, "sin pasar de los PV máx.")
	b.end_turn(EAST)
	_turn(b, 1)
	assert_false(b.can_bandage(0), "2 usos por combate")


func test_cheer_adds_atk_to_next_hit() -> void:
	var b := _battle([
		_unit(&"adoc", P, Vector2i(2, 3), EAST),
		_unit(&"healer", P, Vector2i(1, 2), EAST, { "role": "support" }),
		_unit(&"bot", E, Vector2i(3, 3), EAST, { "max_hp": 100 }),
	], _sure_cfg())
	_turn(b, 1)
	assert_false(b.can_cheer(1), "no a sí mismo")
	var c: Dictionary = b.cheer(0)
	assert_eq(c.amount, 2)
	b.end_turn(EAST)
	_turn(b, 0)
	assert_eq(b.attack(2).damage, 11, "7 + 2 de espalda + 2 de Animar")
	b.end_turn(EAST)
	_turn(b, 0)
	assert_eq(b.attack(2).damage, 9, "solo el siguiente golpe")


func test_finish_bonus_below_threshold() -> void:
	var b := _battle([
		_unit(&"striker", P, Vector2i(2, 3), EAST, { "role": "attacker" }),
		_unit(&"bot", E, Vector2i(3, 3), W, { "max_hp": 100, "hp": 50 }),
	], _sure_cfg())
	assert_eq(b.units[0].atk, 11, "+1 ATQ de atacante")
	_turn(b, 0)
	assert_false(b.can_finish(1), "por encima del 30%")
	assert_eq(b.attack(1, true), {})
	b.units[1].hp = 20
	assert_true(b.can_finish(1))
	var r: Dictionary = b.attack(1, true)
	assert_eq(r.kind, TacticalBattle.KIND_FINISH)
	assert_eq(r.text_key, TacticalBattle.TEXT_FINISH)
	assert_eq(r.damage, 11, "11 − 3 + 3 de Remate")
	b.end_turn(EAST)
	_turn(b, 0)
	assert_false(b.can_finish(1), "1 uso por combate")


func test_only_role_can_use_role_actions() -> void:
	var b := _battle([
		_unit(&"adoc", P, Vector2i(2, 3), EAST, { "hp": 10 }),
		_unit(&"ally", P, Vector2i(2, 2), EAST),
		_unit(&"bot", E, Vector2i(6, 3), W),
	])
	_turn(b, 1)
	assert_false(b.can_cover(0))
	assert_false(b.can_bandage(0))
	assert_false(b.can_cheer(0))


# --- Determinismo -------------------------------------------------------------------------------

func _duel_log(rng_seed: int) -> Array:
	var cfg: Dictionary = TACTICAL.duplicate(true)
	cfg.attack = { "roll_min": -1, "roll_max": 2, "min_damage": 1 }
	var b := _battle([
		_unit(&"adoc", P, Vector2i(2, 3), EAST, { "max_hp": 500, "agi": 9 }),
		_unit(&"bot", E, Vector2i(3, 3), W, { "max_hp": 500, "agi": 9 }),
	], cfg, rng_seed)
	var out: Array = []
	for k in 12:
		var who: int = b.begin_turn()
		var r: Dictionary = b.attack(1 - who)
		out.append([who, r.missed, r.damage])
		b.end_turn(W if who == 1 else EAST)
	return out


func test_same_seed_same_results() -> void:
	assert_eq(_duel_log(5), _duel_log(5))
	var logs: Dictionary = {}
	for s in 8:
		logs[_duel_log(s)] = true
	assert_gt(logs.size(), 1, "la seed cambia las tiradas")


# --- balance.json -------------------------------------------------------------------------------

func test_config_from_balance() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/balance.json"))
	var cfg: Dictionary = TacticalBattle.config_from_balance(data)
	assert_true(cfg.has("actions"))
	assert_eq(TacticalRules.evasion(5, FRONT, 0, cfg.actions), 15)
	assert_eq(TacticalRules.evasion(5, FLANK, 0, cfg.actions), 7)
	assert_eq(float(cfg.defend_factor), 0.5)
	assert_true((cfg.roles as Dictionary).has("defender"))
	assert_true(cfg.has("attack"))
	var b := TacticalBattle.new(cfg, TacticalBoard.from_config(cfg.board),
		[_unit(&"adoc", P, Vector2i(1, 3), EAST, { "role": "attacker" })], 1)
	assert_eq(b.units[0].atk, 11)
