extends GutTest
## IA del combate táctico en la cuadrícula (ia-de-combate.md, "Traducción a la cuadrícula"; PR T5):
## perfiles de enemigo (agresivo, enjambre, táctico, berserk), huida a baja vida, roles de los aliados
## (Vendar, Cubrir, Remate, Animar), órdenes de grupo, determinismo y prueba de humo IA contra IA.
## Bloque tactical fijo de test sin evasión (los golpes aciertan) y tirada de daño 0.

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
	"finish_below": 0.3,
	"ai": { "help_below": 0.3, "finish_below": 0.3, "retreat_below": 0.2, "swarm_flee_below": 0.3,
		"tactical_retreat_below": 0.25 },
	"roles": {
		"attacker": { "atk_bonus": 1, "finish_bonus": 3, "finish_uses": 1 },
		"defender": { "def_bonus": 1, "cover_every": 2 },
		"support": { "heal_pct": 20, "heal_uses": 2, "cheer_atk": 2, "cheer_uses": 1 },
	},
}
const P := TacticalBattle.SIDE_PLAYER
const E := TacticalBattle.SIDE_ENEMY
const EAST := TacticalBoard.Facing.EAST
const WEST := TacticalBoard.Facing.WEST
const NORTH := TacticalBoard.Facing.NORTH


func _unit(id: StringName, side: int, cell: Vector2i, extra: Dictionary = {}) -> Dictionary:
	var u: Dictionary = { "id": id, "side": side, "agi": 5, "cell": cell, "max_hp": 30, "atk": 8, "def": 3,
		"facing": EAST if side == P else WEST }
	u.merge(extra, true)
	return u


func _battle(fighters: Array, cfg: Dictionary = TACTICAL, rng_seed: int = 1) -> TacticalBattle:
	return TacticalBattle.new(cfg, TacticalBoard.from_config(cfg.board), fighters, rng_seed)


## Da el turno a `index` (los demás a CT 0).
func _turn(b: TacticalBattle, index: int) -> void:
	for i in b.units.size():
		b.set_ct(i, 0)
	b.set_ct(index, 100)
	assert_eq(b.begin_turn(), index)


func _plan(b: TacticalBattle, index: int) -> Dictionary:
	_turn(b, index)
	return TacticalAI.plan(b, index)


# --- Perfiles de enemigo ------------------------------------------------------------------------

func test_aggressive_goes_for_the_weakest_in_reach() -> void:
	var b := _battle([_unit(&"e", E, Vector2i(5, 2), { "ai": "aggressive" }),
		_unit(&"adoc", P, Vector2i(4, 2), { "leader": true }), _unit(&"weak", P, Vector2i(3, 4), { "hp": 5 })])
	var p: Dictionary = _plan(b, 0)
	assert_eq(p.action, TacticalBattle.KIND_ATTACK)
	assert_eq(p.target, 2, "va a por el de menos PV, aunque el Adoc esté al lado")
	assert_true(TacticalBoard.are_adjacent(p.move_to, Vector2i(3, 4)))


func test_aggressive_approaches_the_nearest_when_out_of_reach() -> void:
	var b := _battle([_unit(&"e", E, Vector2i(7, 0), { "ai": "aggressive" }),
		_unit(&"near", P, Vector2i(2, 1)), _unit(&"far", P, Vector2i(0, 5), { "hp": 2 })])
	var p: Dictionary = _plan(b, 0)
	assert_eq(p.action, TacticalAI.KIND_NONE)
	assert_eq(TacticalRules.distance(p.move_to, Vector2i(2, 1)), 3, "Mov 3 hacia el más cercano (6 − 3)")


func test_berserk_charges_the_nearest() -> void:
	var b := _battle([_unit(&"e", E, Vector2i(5, 2), { "ai": "berserk" }),
		_unit(&"adoc", P, Vector2i(4, 2), { "leader": true }), _unit(&"weak", P, Vector2i(3, 4), { "hp": 5 })])
	var p: Dictionary = _plan(b, 0)
	assert_eq(p.action, TacticalBattle.KIND_ATTACK)
	assert_eq(p.target, 1, "carga contra el más cercano, no contra el más débil")


func test_swarm_joins_the_target_its_mates_already_touch() -> void:
	var b := _battle([_unit(&"r2", E, Vector2i(5, 3), { "ai": "swarm" }),
		_unit(&"r1", E, Vector2i(4, 2), { "ai": "swarm" }),
		_unit(&"adoc", P, Vector2i(3, 2), { "leader": true, "def": 3 }),
		_unit(&"soft", P, Vector2i(3, 4), { "def": 1 })])
	var p: Dictionary = _plan(b, 0)
	assert_eq(p.action, TacticalBattle.KIND_ATTACK)
	assert_eq(p.target, 2, "se suma al compañero junto al Adoc, aunque el otro tenga menos DEF")
	assert_true(TacticalBoard.are_adjacent(p.move_to, Vector2i(3, 2)))
	var alone := _battle([_unit(&"r", E, Vector2i(5, 3), { "ai": "swarm" }),
		_unit(&"adoc", P, Vector2i(3, 2), { "leader": true, "def": 3 }),
		_unit(&"soft", P, Vector2i(3, 4), { "def": 1 })])
	assert_eq(_plan(alone, 0).target, 2, "sin compañeros al lado, al de menos DEF")


func test_swarm_surrounds_from_a_free_side() -> void:
	var b := _battle([_unit(&"r2", E, Vector2i(7, 0), { "ai": "swarm", "agi": 3 }),
		_unit(&"r1", E, Vector2i(4, 2), { "ai": "swarm" }),
		_unit(&"adoc", P, Vector2i(3, 2), { "leader": true, "max_hp": 200 })])
	for k: int in 5:
		_turn(b, 0)
		TacticalAI.run_turn(b)
		if TacticalBoard.are_adjacent(b.units[0].cell, Vector2i(3, 2)):
			break
	assert_true(TacticalBoard.are_adjacent(b.units[0].cell, Vector2i(3, 2)), "llega a otra casilla vecina")
	assert_ne(b.units[0].cell, b.units[1].cell)
	var around: int = 0
	for dir: Vector2i in TacticalBoard.NEIGHBOR_DIRS:
		var at: int = b.unit_at(Vector2i(3, 2) + dir)
		if at != TacticalBattle.NONE and b.units[at].side == E:
			around += 1
	assert_eq(around, 2, "el Adoc queda rodeado por los dos")


func test_tactical_takes_the_flank_or_the_back() -> void:
	# Adoc en (3, 2) mirando al este: frente (4, 2), flancos (3, 1) y (3, 3), espalda (2, 2).
	var flank := _battle([_unit(&"g", E, Vector2i(5, 0), { "ai": "tactical" }),
		_unit(&"adoc", P, Vector2i(3, 2), { "leader": true })])
	var p: Dictionary = _plan(flank, 0)
	assert_eq(p.move_to, Vector2i(3, 1), "la espalda no le llega: flanco")
	assert_eq(p.action, TacticalBattle.KIND_ATTACK)
	var back := _battle([_unit(&"g", E, Vector2i(3, 0), { "ai": "tactical" }),
		_unit(&"adoc", P, Vector2i(3, 2), { "leader": true })])
	assert_eq(_plan(back, 0).move_to, Vector2i(2, 2), "llega a la espalda")
	var brute := _battle([_unit(&"e", E, Vector2i(5, 0), { "ai": "aggressive" }),
		_unit(&"adoc", P, Vector2i(3, 2), { "leader": true })])
	assert_eq(_plan(brute, 0).target, 1, "el agresivo también ataca")


func test_tactical_hits_the_support_first() -> void:
	var b := _battle([_unit(&"g", E, Vector2i(5, 2), { "ai": "tactical" }),
		_unit(&"adoc", P, Vector2i(4, 2), { "leader": true, "hp": 10 }),
		_unit(&"sup", P, Vector2i(4, 4), { "role": "support", "hp": 25 })])
	var p: Dictionary = _plan(b, 0)
	assert_eq(p.target, 2, "el apoyo, aunque tenga más PV")


func test_tactical_facing_avoids_showing_its_back() -> void:
	var fighters: Array = [_unit(&"g", E, Vector2i(3, 3), { "ai": "tactical" }),
		_unit(&"a", P, Vector2i(3, 1), { "hp": 5 }), _unit(&"b", P, Vector2i(5, 3)), _unit(&"c", P, Vector2i(3, 5))]
	var cfg: Dictionary = TACTICAL.duplicate(true)
	cfg.board.width = 10
	cfg.board.max_per_side = 4
	var b := _battle(fighters, cfg)
	assert_eq(TacticalAI.facing_for(b, 0, Vector2i(3, 3)), EAST, "de lado a dos y de frente a otro, sin espalda")
	b.units[0].ai = &"aggressive"
	assert_eq(TacticalAI.facing_for(b, 0, Vector2i(3, 3)), NORTH, "los demás miran a la amenaza más cercana")


# --- Huida a baja vida --------------------------------------------------------------------------

func test_last_swarm_of_a_group_flees_by_the_edge() -> void:
	var b := _battle([_unit(&"r1", E, Vector2i(6, 2), { "ai": "swarm", "hp": 5 }),
		_unit(&"r2", E, Vector2i(6, 3), { "ai": "swarm" }), _unit(&"adoc", P, Vector2i(2, 2), { "leader": true })])
	assert_ne(_plan(b, 0).action, TacticalBattle.KIND_LEAVE, "con otro compañero en pie, no huye")
	b.end_turn(WEST)
	b.units[1].hp = 0
	b.remove_unit(1)
	var p: Dictionary = _plan(b, 0)
	assert_eq(p.action, TacticalBattle.KIND_LEAVE)
	assert_true(b.board.is_edge(p.move_to))
	var res: Dictionary = TacticalAI.run_turn(b)
	assert_eq(res.result.text_key, TacticalBattle.TEXT_ENEMY_FLEE)
	assert_false(b.units[0].alive)
	assert_true(b.units[0].fled)
	assert_eq(b.result, TacticalBattle.Result.VICTORY, "no queda ningún enemigo en pie")
	assert_eq(b.active, TacticalBattle.NONE)


func test_lone_swarm_aggressive_and_berserk_never_flee() -> void:
	for profile: String in ["swarm", "aggressive", "berserk"]:
		var b := _battle([_unit(&"r", E, Vector2i(6, 2), { "ai": profile, "hp": 1 }),
			_unit(&"adoc", P, Vector2i(2, 2), { "leader": true })])
		assert_ne(_plan(b, 0).action, TacticalBattle.KIND_LEAVE, profile)


func test_tactical_retreats_below_its_threshold() -> void:
	var b := _battle([_unit(&"g", E, Vector2i(5, 2), { "ai": "tactical", "hp": 7 }),
		_unit(&"g2", E, Vector2i(5, 3), { "ai": "tactical" }), _unit(&"adoc", P, Vector2i(4, 2), { "leader": true })])
	var p: Dictionary = _plan(b, 0)
	assert_eq(p.action, TacticalBattle.KIND_LEAVE, "7/30 < 25%")
	assert_eq(TacticalAI.run_turn(b).result.text_key, TacticalBattle.TEXT_RETREAT)
	assert_true(b.units[0].fled)
	assert_eq(b.result, TacticalBattle.Result.ONGOING, "queda el otro garelino")
	var cfg: Dictionary = TACTICAL.duplicate(true)
	cfg.board.width = 14
	cfg.board.height = 10
	var far := _battle([_unit(&"g", E, Vector2i(7, 5), { "ai": "tactical", "hp": 7, "agi": 3 }),
		_unit(&"adoc", P, Vector2i(5, 5), { "leader": true })], cfg)
	var q: Dictionary = _plan(far, 0)
	assert_eq(q.action, TacticalBattle.KIND_DEFEND, "sin llegar al borde, se defiende")
	assert_gt(TacticalRules.distance(q.move_to, Vector2i(5, 5)), 2, "y se aleja")


func test_fled_swarm_gives_no_xp_through_the_bridge() -> void:
	var balance: Dictionary = AdventureRules.balance()
	var adoc: Dictionary = { "max_hp": 20, "atk": 6, "def": 3, "agi": 5 }
	var unico: Dictionary = { "name": "R1", "max_hp": 10, "atk": 4, "def": 1, "agi": 7, "ai": "swarm" }
	var logic := BattleLogic.new(balance, adoc, 18, 5, unico, 42)
	logic.add_enemy({ "name": "R2", "max_hp": 10, "atk": 4, "def": 1, "agi": 7, "ai": "swarm" })
	logic.victory_xp = 20
	logic.enemy_xp = 10
	var b: TacticalBattle = TacticalBridge.build_battle(logic)
	assert_eq(b.units[1].ai, BattleLogic.AI_SWARM, "el perfil pasa al combate táctico")
	b.units[1].hp = 0
	b.remove_unit(1)
	b.units[2].hp = 2
	b.units[2].fled = true
	b.remove_unit(2)
	b.check_end()
	TacticalBridge.apply_to_logic(b, logic)
	assert_eq(logic.result, BattleLogic.Result.VICTORY)
	assert_true(logic.enemies[1].gone, "huyó: no está en pie")
	assert_eq(logic.enemies[1].hp, 2)
	assert_eq(logic.victory_xp, 10, "sin la XP del que huye")


# --- Aliados por rol (Libre) --------------------------------------------------------------------

func test_support_bandages_the_hurt() -> void:
	var b := _battle([_unit(&"sup", P, Vector2i(0, 2), { "role": "support" }),
		_unit(&"adoc", P, Vector2i(3, 2), { "leader": true, "hp": 5 }), _unit(&"e", E, Vector2i(6, 2))])
	var p: Dictionary = _plan(b, 0)
	assert_eq(p.action, TacticalBattle.KIND_BANDAGE)
	assert_eq(p.target, 1)
	assert_true(TacticalRules.distance(p.move_to, Vector2i(3, 2)) <= 2, "alcance 2")
	var res: Dictionary = TacticalAI.run_turn(b)
	assert_eq(res.result.kind, TacticalBattle.KIND_BANDAGE)
	assert_eq(b.units[1].hp, 11, "+20% de 30")


func test_defender_covers_the_hurt_adoc() -> void:
	var b := _battle([_unit(&"def", P, Vector2i(2, 1), { "role": "defender" }),
		_unit(&"adoc", P, Vector2i(3, 2), { "leader": true, "hp": 5 }), _unit(&"e", E, Vector2i(6, 2))])
	var p: Dictionary = _plan(b, 0)
	assert_eq(p.action, TacticalBattle.KIND_COVER)
	assert_eq(p.target, 1)
	assert_true(TacticalBoard.are_adjacent(p.move_to, Vector2i(3, 2)))
	assert_eq(p.move_to, Vector2i(4, 2), "entre el Adoc y el enemigo")
	TacticalAI.run_turn(b)
	assert_eq(b.covers.get(1, -1), 0, "lo cubre")


func test_attacker_finishes_the_low_one() -> void:
	var b := _battle([_unit(&"atk", P, Vector2i(2, 2), { "role": "attacker" }),
		_unit(&"a", E, Vector2i(4, 2), { "max_hp": 10, "hp": 10 }),
		_unit(&"low", E, Vector2i(3, 4), { "max_hp": 100, "hp": 20 })])
	var p: Dictionary = _plan(b, 0)
	assert_eq(p.action, TacticalBattle.KIND_FINISH, "Remate a quien está por debajo del 30%")
	assert_eq(p.target, 2)
	b.units[0].finishes_left = 0
	b.end_turn(EAST)
	assert_eq(_plan(b, 0).target, 1, "sin Remate: al de menos PV absolutos")


func test_support_cheers_an_ally_about_to_hit() -> void:
	var b := _battle([_unit(&"sup", P, Vector2i(0, 2), { "role": "support" }),
		_unit(&"atk", P, Vector2i(4, 2), { "role": "attacker" }), _unit(&"e", E, Vector2i(5, 2))])
	var p: Dictionary = _plan(b, 0)
	assert_eq(p.action, TacticalBattle.KIND_CHEER)
	assert_eq(p.target, 1)


func test_hurt_ally_retreats_and_defends() -> void:
	var b := _battle([_unit(&"atk", P, Vector2i(4, 2), { "role": "attacker", "hp": 3 }),
		_unit(&"e", E, Vector2i(5, 2))])
	var p: Dictionary = _plan(b, 0)
	assert_eq(p.action, TacticalBattle.KIND_DEFEND)
	assert_gt(TacticalRules.distance(p.move_to, Vector2i(5, 2)), 3, "se aleja del enemigo")


# --- Órdenes de grupo ---------------------------------------------------------------------------

func test_attack_order_goes_for_the_adoc_target() -> void:
	var fighters: Array = [_unit(&"atk", P, Vector2i(2, 2), { "role": "attacker" }),
		_unit(&"adoc", P, Vector2i(1, 4), { "leader": true }),
		_unit(&"weak", E, Vector2i(3, 2), { "hp": 4 }), _unit(&"big", E, Vector2i(4, 4))]
	var b := _battle(fighters)
	assert_eq(_plan(b, 0).target, 2, "Libre: al de menos PV")
	b.end_turn(EAST)
	b.set_group_order(BattleLogic.GroupOrder.ATTACK)
	b.player_target = 3
	var p: Dictionary = _plan(b, 0)
	assert_eq(p.target, 3, "Atacar: al objetivo del Adoc")
	assert_eq(p.action, TacticalBattle.KIND_ATTACK)


func test_leader_attack_sets_the_player_target() -> void:
	var b := _battle([_unit(&"adoc", P, Vector2i(2, 2), { "leader": true }), _unit(&"e", E, Vector2i(3, 2))])
	_turn(b, 0)
	b.attack(1)
	assert_eq(b.player_target, 1)


func test_defend_order_groups_by_the_adoc_and_defends() -> void:
	var b := _battle([_unit(&"atk", P, Vector2i(0, 2), { "role": "attacker" }),
		_unit(&"adoc", P, Vector2i(2, 4), { "leader": true }), _unit(&"e", E, Vector2i(7, 0))])
	b.set_group_order(BattleLogic.GroupOrder.DEFEND)
	var p: Dictionary = _plan(b, 0)
	assert_eq(p.action, TacticalBattle.KIND_DEFEND)
	assert_eq(TacticalRules.distance(p.move_to, Vector2i(2, 4)), 1, "junto al Adoc")
	var sup := _battle([_unit(&"sup", P, Vector2i(0, 0), { "role": "support" }),
		_unit(&"adoc", P, Vector2i(2, 1), { "leader": true, "hp": 25 }), _unit(&"e", E, Vector2i(7, 0))])
	sup.set_group_order(BattleLogic.GroupOrder.DEFEND)
	var q: Dictionary = _plan(sup, 0)
	assert_eq(q.action, TacticalBattle.KIND_BANDAGE, "con Defender, Venda a cualquier herido")
	assert_eq(q.target, 1)


# --- Determinismo y prueba de humo --------------------------------------------------------------

func test_same_seed_same_battle() -> void:
	var a: Array = _simulate(7, false)
	var c: Array = _simulate(7, false)
	assert_eq(a, c, "misma seed, mismos planes y mismo final")
	assert_false(a.is_empty())


func test_smoke_ai_vs_ai_never_illegal_and_always_ends() -> void:
	var ended: int = 0
	for k: int in 200:
		var log: Array = _simulate(1000 + k, k % 2 == 1)
		if not log.is_empty() and str(log[log.size() - 1]).begins_with("end"):
			ended += 1
	assert_eq(ended, 200, "los 200 combates (3v3 y 6v6) terminan sin bucles")


## Un combate IA contra IA con la seed: bando del jugador con roles y orden al azar (sembrado), y
## enemigos con perfiles. Comprueba en cada turno que el plan es legal. Devuelve el registro.
func _simulate(rng_seed: int, big: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var cfg: Dictionary = TACTICAL.duplicate(true)
	cfg.actions.evasion_base = 5
	cfg.actions.evasion_per_agi = 2
	cfg.actions.height_evasion = 10
	cfg.attack = { "roll_min": -1, "roll_max": 2, "min_damage": 1 }
	var per_side: int = 6 if big else 3
	cfg.board = { "width": 14 if big else 8, "height": 10 if big else 6, "deploy_columns": 3 if big else 2,
		"max_per_side": per_side, "ford_cost": 1 }
	var board := TacticalBoard.from_config(cfg.board)
	# Relieve suave y algún obstáculo en el centro.
	for n: int in rng.randi_range(0, 6):
		var c := Vector2i(rng.randi_range(3, board.width - 4), rng.randi_range(0, board.height - 1))
		board.set_cell(c, rng.randi_range(0, 1), false, false, false, false, &"tree" if rng.randf() < 0.5 else &"")
	var roles: Array = ["attacker", "defender", "support", ""]
	var profiles: Array = ["aggressive", "swarm", "tactical", "berserk"]
	var fighters: Array = [{ "id": &"adoc", "side": P, "agi": rng.randi_range(5, 8), "max_hp": 30,
		"atk": 7, "def": 3, "leader": true }]
	for k: int in per_side - 1:
		fighters.append({ "id": StringName("ally_%d" % k), "side": P, "agi": rng.randi_range(4, 8),
			"max_hp": rng.randi_range(15, 30), "atk": rng.randi_range(4, 8), "def": rng.randi_range(1, 3),
			"role": roles[rng.randi_range(0, roles.size() - 1)] })
	var profile: String = profiles[rng.randi_range(0, profiles.size() - 1)]
	for k: int in per_side:
		var p: String = profile if rng.randf() < 0.7 else profiles[rng.randi_range(0, profiles.size() - 1)]
		fighters.append({ "id": StringName("enemy_%d" % k), "side": E, "agi": rng.randi_range(3, 8),
			"max_hp": rng.randi_range(12, 30), "atk": rng.randi_range(4, 8), "def": rng.randi_range(1, 3),
			"ai": p, "role": roles[rng.randi_range(0, roles.size() - 1)] if p == "tactical" else "" })
	var b := TacticalBattle.new(cfg, board, fighters, rng_seed)
	b.set_group_order(rng.randi_range(0, 2))
	var log: Array = []
	for turn: int in 600:
		if b.is_over():
			break
		var i: int = b.begin_turn()
		if i == TacticalBattle.NONE:
			break
		var p: Dictionary = TacticalAI.plan(b, i)
		var reach: Dictionary = b.reachable_for(i)
		if not reach.has(p.move_to):
			fail_test("seed %d turno %d: casilla inalcanzable %s" % [rng_seed, turn, p.move_to])
			return []
		if p.move_to != b.units[i].cell:
			b.move_active(p.move_to)
		if not _legal(b, p):
			fail_test("seed %d turno %d: acción ilegal %s" % [rng_seed, turn, p])
			return []
		var res: Dictionary = TacticalAI.apply_action(b, p)
		if p.action != TacticalAI.KIND_NONE and res.is_empty():
			fail_test("seed %d turno %d: la acción no se ejecutó %s" % [rng_seed, turn, p])
			return []
		if not b.is_over():
			TacticalAI.finish_turn(b)
		log.append([i, p.move_to, p.action, p.target, p.facing, int(res.get("damage", 0))])
	if b.is_over():
		log.append("end %d" % b.result)
	return log


## La acción del plan es legal ahora (ya movido) según TacticalBattle.
func _legal(b: TacticalBattle, p: Dictionary) -> bool:
	var t: int = int(p.target)
	match StringName(p.action):
		TacticalAI.KIND_NONE:
			return true
		TacticalBattle.KIND_ATTACK:
			return b.can_act() and b.can_attack(b.active, t)
		TacticalBattle.KIND_FINISH:
			return b.can_finish(t)
		TacticalBattle.KIND_DEFEND:
			return b.can_act()
		TacticalBattle.KIND_COVER:
			return b.can_cover(t)
		TacticalBattle.KIND_BANDAGE:
			return b.can_bandage(t)
		TacticalBattle.KIND_CHEER:
			return b.can_cheer(t)
		TacticalBattle.KIND_LEAVE:
			return b.can_leave()
	return false
