extends GutTest
## Ajustes de playtest del combate táctico (ajustes-playtest-0.5.md; bloque P de roadmap-0.5.md):
## P1, huida con suerte (fórmula, % en el menú, fallar pierde el turno, bonus por intento, flee_chance
## del menú a 0,6); P2, IA más lista (alcance 2 del látigo, perfiles guardián, látigo y emboscadora,
## Defender bajo umbral, cortar la huida, altura y azar top-2 determinista). Bloque tactical fijo de
## test sin evasión (los golpes aciertan) y tirada de daño 0; la huida y la IA con los valores de la
## ficha.

const FLEE: Dictionary = { "base": 70, "agi_factor": 5, "adjacent_penalty": 35, "near_penalty": 10,
	"retry_bonus": 10, "min": 5, "max": 95, "fear_bonus": 20 }
const AI: Dictionary = { "help_below": 0.3, "finish_below": 0.3, "retreat_below": 0.2, "swarm_flee_below": 0.3,
	"tactical_retreat_below": 0.25, "defend_below": 0.5, "guard_radius": 2, "guard_defend_every": 2,
	"guard_advance_after": 3, "cut_flee_edge": 1, "cut_flee_above": 30, "height_weight": 1, "top2_weight": 0.75,
	"top2_margin": 0.8, "wait_max": 2 }
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
	"flee": FLEE,
	"ai": AI,
	"roles": {},
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


func _adoc(cell: Vector2i, extra: Dictionary = {}) -> Dictionary:
	var e: Dictionary = { "leader": true }
	e.merge(extra, true)
	return _unit(&"adoc", P, cell, e)


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


func _cfg_with(path: String, values: Dictionary) -> Dictionary:
	var cfg: Dictionary = TACTICAL.duplicate(true)
	(cfg[path] as Dictionary).merge(values, true)
	return cfg


# --- P1: huida con suerte -----------------------------------------------------------------------

func test_flee_formula_matches_the_examples() -> void:
	# Adoc de nivel 1 (AGI 5) en el borde izquierdo.
	var bot: Dictionary = { "agi": 3 }
	var far := _battle([_adoc(Vector2i(0, 2)), _unit(&"bot", E, Vector2i(5, 2), bot)])
	assert_eq(far.flee_chance(0), 95, "Botarramas lejos: el máximo")
	var near := _battle([_adoc(Vector2i(0, 2)), _unit(&"bot", E, Vector2i(3, 2), bot)])
	assert_eq(near.flee_chance(0), 70, "Botarramas a 3 casillas (Mov 2 + 1): 70 + 10 − 10")
	var adj := _battle([_adoc(Vector2i(0, 2)), _unit(&"bot", E, Vector2i(1, 2), bot)])
	assert_eq(adj.flee_chance(0), 45, "Botarramas adyacente: 70 + 10 − 35")
	var ofomni := _battle([_adoc(Vector2i(0, 2)), _unit(&"ofo", E, Vector2i(1, 2), { "agi": 6, "attack_range": [1, 2] })])
	assert_eq(ofomni.flee_chance(0), 30, "Ofomni adyacente: 70 − 5 − 35")
	ofomni.flee_fails = 2
	assert_eq(ofomni.flee_chance(0), 50, "el mismo Ofomni tras 2 intentos fallidos")
	var rep: Dictionary = { "agi": 7, "ai": "swarm" }
	var swarm := _battle([_adoc(Vector2i(0, 2)), _unit(&"r1", E, Vector2i(1, 2), rep),
		_unit(&"r2", E, Vector2i(0, 1), rep), _unit(&"r3", E, Vector2i(0, 4), rep)])
	assert_eq(swarm.flee_chance(0), 5, "rodeado por 3 reparep: 70 − 10 − 70 − 10, al mínimo")


func test_flee_rules_are_pure_and_clamped() -> void:
	assert_eq(TacticalRules.flee_chance(5, 0, 0, 0, 0, false, FLEE), 95, "sin enemigos cercanos: max")
	assert_eq(TacticalRules.flee_chance(5, 1, 0, 5, 0, false, FLEE), 35, "Aledra (AGI 5) adyacente")
	assert_eq(TacticalRules.flee_chance(5, 1, 0, 5, 0, true, FLEE), 55, "con Miedo, + fear_bonus")
	assert_eq(TacticalRules.flee_chance(5, 3, 0, 9, 0, false, FLEE), 5, "nunca por debajo de min")
	assert_eq(TacticalRules.flee_chance(9, 0, 1, 1, 5, false, FLEE), 95, "nunca por encima de max")


func test_failed_flee_loses_the_turn() -> void:
	var cfg: Dictionary = _cfg_with("flee", { "min": 0, "max": 0 })
	var b := _battle([_adoc(Vector2i(1, 2)), _unit(&"bot", E, Vector2i(2, 2), { "agi": 3, "max_hp": 20 })], cfg)
	_turn(b, 0)
	assert_eq(b.flee(), {}, "fuera del borde no se puede intentar")
	b.move_active(Vector2i(0, 2))
	var r: Dictionary = b.flee()
	assert_eq(r.kind, TacticalBattle.KIND_FLEE)
	assert_true(r.failed, "con 0% siempre falla")
	assert_eq(r.text_key, TacticalBattle.TEXT_FLEE_FAIL)
	assert_eq(b.result, TacticalBattle.Result.ONGOING)
	assert_eq(b.active, TacticalBattle.NONE, "el turno termina")
	assert_eq(r.ct_cost, 100, "se movió y lo intentó: como mover y actuar")
	assert_eq(b.units[1].hp, 20, "el enemigo no recupera nada")
	_turn(b, 0)
	var still: Dictionary = b.flee()
	assert_eq(still.ct_cost, 80, "sin moverse: como actuar")


func test_each_failed_try_adds_the_retry_bonus() -> void:
	# base 0 y sin penalización: la probabilidad es solo el bonus por intento.
	var cfg: Dictionary = _cfg_with("flee", { "base": 0, "agi_factor": 0, "adjacent_penalty": 0, "min": 0 })
	var b := _battle([_adoc(Vector2i(0, 2)), _unit(&"bot", E, Vector2i(1, 2))], cfg)
	_turn(b, 0)
	assert_eq(b.flee_chance(0), 0)
	assert_true(b.flee().failed)
	assert_eq(b.flee_fails, 1)
	assert_eq(b.flee_chance(0), 10, "+retry_bonus por el intento fallido")


func test_flee_shows_the_chance_and_a_failure_ends_the_turn_in_the_menu() -> void:
	var b := _battle([_adoc(Vector2i(0, 2)), _unit(&"bot", E, Vector2i(1, 2), { "agi": 3 })])
	_turn(b, 0)
	var f := TacticalTurnFlow.new(b)
	f.begin_player_turn()
	var text: String = ""
	for e: Dictionary in f.act_entries():
		if e.id == TacticalTurnFlow.ACT_FLEE:
			text = str(e.text)
	assert_string_contains(text, "45%", "el porcentaje se ve antes de confirmar")
	var cfg: Dictionary = _cfg_with("flee", { "min": 0, "max": 0 })
	var lost := _battle([_adoc(Vector2i(0, 2)), _unit(&"bot", E, Vector2i(1, 2), { "agi": 3 })], cfg)
	_turn(lost, 0)
	var g := TacticalTurnFlow.new(lost)
	g.begin_player_turn()
	g.choose_main(TacticalTurnFlow.MAIN_ACT)
	var res: Dictionary = g.choose_act(TacticalTurnFlow.ACT_FLEE)
	assert_eq(res.kind, TacticalTurnFlow.KIND_END, "la escena pasa al siguiente turno")
	assert_true(res.failed)
	assert_eq(res.actor, 0)
	assert_eq(g.state, TacticalTurnFlow.State.IDLE)
	assert_eq(lost.active, TacticalBattle.NONE)


func test_menu_battle_flee_chance_is_lower() -> void:
	assert_almost_eq(float(AdventureRules.balance().flee_chance), 0.6, 0.0001, "combate por menú: 0,75 → 0,6")
	var flee: Dictionary = (AdventureRules.balance().tactical as Dictionary).flee
	assert_eq([int(flee.base), int(flee.adjacent_penalty), int(flee.min), int(flee.max)], [70, 35, 5, 95])


# --- P2: alcance 2 del látigo -------------------------------------------------------------------

func test_attack_range_two_in_line() -> void:
	var b := _battle([_unit(&"ofo", E, Vector2i(5, 2), { "attack_range": [1, 2] }), _adoc(Vector2i(3, 2)),
		_unit(&"ally", P, Vector2i(4, 4))])
	assert_true(b.can_attack(0, 1), "a 2 en línea")
	assert_false(b.can_hit_from(0, Vector2i(4, 3), 1), "a 2 pero no en línea")
	assert_true(b.can_hit_from(0, Vector2i(4, 2), 1), "a 1, como siempre")
	assert_false(b.can_hit_from(0, Vector2i(6, 2), 1), "a 3, fuera de alcance")
	b.units[2].cell = Vector2i(4, 2)
	assert_false(b.can_attack(0, 1), "con un enemigo en medio, el golpe es para ese")
	assert_true(b.can_attack(0, 2))
	var blocked := _battle([_unit(&"ofo", E, Vector2i(5, 2), { "attack_range": [1, 2] }), _adoc(Vector2i(3, 2))])
	blocked.board.set_cell(Vector2i(4, 2), 0, true)
	assert_false(blocked.can_attack(0, 1), "la casilla de en medio debe ser transitable")
	var melee := _battle([_unit(&"bot", E, Vector2i(5, 2)), _adoc(Vector2i(3, 2))])
	assert_false(melee.can_attack(0, 1), "sin attack_range, cuerpo a cuerpo")
	assert_eq(melee.threat_range(0), 4, "Mov 3 + alcance 1")
	assert_eq(b.threat_range(0), 5, "Mov 3 + alcance 2")


# --- P2: perfiles ----------------------------------------------------------------------------------

func test_guardian_holds_its_post_defends_and_then_advances() -> void:
	var b := _battle([_unit(&"bot", E, Vector2i(4, 2), { "ai": "guardian", "agi": 3 }), _adoc(Vector2i(1, 2))])
	b.units[0].home = Vector2i(6, 2)
	var p: Dictionary = _plan(b, 0)
	assert_eq(p.move_to, Vector2i(4, 2), "no se aleja más de 2 de su sitio, aunque el Adoc esté junto al borde")
	assert_eq(p.action, TacticalBattle.KIND_DEFEND, "no llega: Defiende")
	TacticalAI.finish_turn(b)
	var p2: Dictionary = _plan(b, 0)
	assert_eq(p2.action, TacticalAI.KIND_NONE, "como mucho 1 de cada 2 turnos")
	TacticalAI.finish_turn(b)
	_plan(b, 0)
	TacticalAI.finish_turn(b)
	var p4: Dictionary = _plan(b, 0)
	assert_gt(TacticalRules.distance(p4.move_to, Vector2i(6, 2)), 2, "al 4.º turno avanza como un agresivo")


func test_guardian_attacks_when_the_adoc_comes_close() -> void:
	var b := _battle([_unit(&"bot", E, Vector2i(6, 2), { "ai": "guardian", "agi": 3 }), _adoc(Vector2i(3, 2))])
	var p: Dictionary = _plan(b, 0)
	assert_eq(p.action, TacticalBattle.KIND_ATTACK)
	assert_eq(p.move_to, Vector2i(4, 2))


func test_whip_prefers_to_strike_from_two() -> void:
	var b := _battle([_unit(&"ofo", E, Vector2i(6, 2), { "ai": "whip", "agi": 6, "attack_range": [1, 2] }),
		_adoc(Vector2i(2, 2))])
	var p: Dictionary = _plan(b, 0)
	assert_eq(p.action, TacticalBattle.KIND_ATTACK)
	assert_eq(p.move_to, Vector2i(4, 2), "golpea desde 2 casillas en vez de pegarse")
	var res: Dictionary = TacticalAI.apply_action(b, p) if b.move_active(p.move_to).size() > 0 else {}
	assert_eq(res.get("damage", 0), 5, "el golpe a 2 casillas llega (8 − 3)")


func test_ambusher_takes_the_flank_or_waits_for_it() -> void:
	# Adoc en (3, 2) mirando al este: la emboscadora llega a un flanco.
	var flank := _battle([_unit(&"ale", E, Vector2i(5, 3), { "ai": "ambusher" }), _adoc(Vector2i(3, 2))])
	var p: Dictionary = _plan(flank, 0)
	assert_eq(p.action, TacticalBattle.KIND_ATTACK)
	assert_true([Vector2i(3, 1), Vector2i(3, 3)].has(p.move_to), "por el flanco, no de frente: %s" % p.move_to)
	# Solo llega de frente: se aparta fuera del alcance del Adoc y no ataca.
	var front := _battle([_unit(&"ale", E, Vector2i(6, 2), { "ai": "ambusher" }), _adoc(Vector2i(2, 2))])
	var q: Dictionary = _plan(front, 0)
	assert_eq(q.action, TacticalAI.KIND_NONE, "espera su ocasión")
	assert_gt(TacticalRules.distance(q.move_to, Vector2i(2, 2)), 4, "fuera del alcance del Adoc (Mov 3 + 1)")
	# Si ya lleva wait_max turnos sin actuar, ataca de frente.
	front.units[0].waits = 2
	assert_eq(TacticalAI.plan(front, 0).action, TacticalBattle.KIND_ATTACK)


# --- P2: reglas comunes ----------------------------------------------------------------------------

func test_defends_below_the_threshold_when_it_cannot_attack() -> void:
	for profile: String in ["aggressive", "swarm", "tactical"]:
		var b := _battle([_unit(&"e", E, Vector2i(7, 2), { "ai": profile, "hp": 10 }), _adoc(Vector2i(2, 2))])
		var p: Dictionary = _plan(b, 0)
		assert_eq(p.action, TacticalBattle.KIND_DEFEND, "%s con 10/30 PV y al alcance del Adoc" % profile)
		assert_ne(p.move_to, Vector2i(7, 2), "se mueve y Defiende")
	var healthy := _battle([_unit(&"e", E, Vector2i(7, 2), { "ai": "aggressive" }), _adoc(Vector2i(2, 2))])
	assert_eq(_plan(healthy, 0).action, TacticalAI.KIND_NONE, "con la vida entera solo se acerca")
	var mad := _battle([_unit(&"e", E, Vector2i(7, 2), { "ai": "berserk", "hp": 10 }), _adoc(Vector2i(2, 2))])
	assert_eq(_plan(mad, 0).action, TacticalAI.KIND_NONE, "el berserk nunca Defiende")


func test_cuts_the_flight_of_the_adoc_on_the_edge() -> void:
	var whip: Dictionary = { "ai": "whip", "agi": 6, "attack_range": [1, 2] }
	var b := _battle([_unit(&"ofo", E, Vector2i(4, 2), whip), _adoc(Vector2i(0, 2))])
	assert_gt(b.flee_chance(1), 30)
	var p: Dictionary = _plan(b, 0)
	assert_eq(p.action, TacticalBattle.KIND_ATTACK)
	assert_eq(p.move_to, Vector2i(1, 2), "se pega al Adoc para que no huya (en vez de golpear desde 2)")
	var calm := _battle([_unit(&"ofo", E, Vector2i(4, 2), whip), _adoc(Vector2i(0, 2))],
		_cfg_with("ai", { "cut_flee_above": 100 }))
	assert_eq(_plan(calm, 0).move_to, Vector2i(2, 2), "sin corte, el látigo golpea desde 2")
	var inside := _battle([_unit(&"ofo", E, Vector2i(6, 2), whip), _adoc(Vector2i(2, 2))])
	assert_eq(_plan(inside, 0).move_to, Vector2i(4, 2), "lejos del borde no hay corte")
	# El guardián no corta: quiere que te vayas.
	var guard := _battle([_unit(&"bot", E, Vector2i(3, 2), { "ai": "guardian", "agi": 3 }), _adoc(Vector2i(0, 2))])
	guard.units[0].home = Vector2i(5, 2)
	var g: Dictionary = _plan(guard, 0)
	assert_eq(g.action, TacticalBattle.KIND_DEFEND)
	assert_eq(g.move_to, Vector2i(3, 2), "no sale de su sitio para cortar")


func test_prefers_the_high_cell() -> void:
	var cfg: Dictionary = _cfg_with("actions", { "flank_bonus": 0, "back_bonus": 0, "height_bonus": 0 })
	cfg.ai.top2_margin = 2.0
	var flat := _battle([_unit(&"e", E, Vector2i(5, 2), { "ai": "aggressive" }), _adoc(Vector2i(3, 2))], cfg)
	assert_eq(_plan(flat, 0).move_to, Vector2i(4, 2), "en el llano no hace nada: la más barata")
	var high := _battle([_unit(&"e", E, Vector2i(5, 2), { "ai": "aggressive" }), _adoc(Vector2i(3, 2))], cfg)
	high.board.set_cell(Vector2i(3, 3), 1)
	assert_eq(_plan(high, 0).move_to, Vector2i(3, 3), "a igualdad de lo demás, la casilla más alta")
	var mad := _battle([_unit(&"e", E, Vector2i(5, 2), { "ai": "berserk" }), _adoc(Vector2i(3, 2))], cfg)
	mad.board.set_cell(Vector2i(3, 3), 1)
	assert_eq(_plan(mad, 0).move_to, Vector2i(4, 2), "el berserk carga sin mirar la altura")


func test_top2_is_deterministic_and_stays_in_the_same_priority() -> void:
	var cfg: Dictionary = _cfg_with("actions", { "flank_bonus": 0, "back_bonus": 0, "height_bonus": 0 })
	var seen: Dictionary = {}
	for s: int in range(1, 41):
		var a := _battle([_unit(&"e", E, Vector2i(5, 2), { "ai": "aggressive" }), _adoc(Vector2i(3, 2)),
			_unit(&"strong", P, Vector2i(5, 4), { "hp": 30, "max_hp": 60 })], cfg, s)
		var c := _battle([_unit(&"e", E, Vector2i(5, 2), { "ai": "aggressive" }), _adoc(Vector2i(3, 2)),
			_unit(&"strong", P, Vector2i(5, 4), { "hp": 30, "max_hp": 60 })], cfg, s)
		a.units[1].hp = 20
		c.units[1].hp = 20
		var pa: Dictionary = _plan(a, 0)
		var pc: Dictionary = _plan(c, 0)
		assert_eq([pa.move_to, pa.target], [pc.move_to, pc.target], "seed %d: misma seed, mismo plan" % s)
		assert_eq(pa.target, 1, "nunca el objetivo de otra prioridad (más PV)")
		seen[pa.move_to] = int(seen.get(pa.move_to, 0)) + 1
	assert_gt(seen.size(), 1, "con varias casillas iguales, a veces elige la segunda")
	assert_gt(int(seen.get(Vector2i(4, 2), 0)), 20, "la mejor (la más barata) sale casi siempre")
	for s: int in range(1, 21):
		var m := _battle([_unit(&"e", E, Vector2i(5, 2), { "ai": "berserk" }), _adoc(Vector2i(3, 2))], cfg, s)
		assert_eq(_plan(m, 0).move_to, Vector2i(4, 2), "seed %d: el berserk no tira" % s)


func test_real_data_profiles_reach_the_board() -> void:
	GameState.new_game(42)
	assert_eq(str(AdventureRules.make_monster(&"aledra", 2).ai), "ambusher")
	var ofomni: Dictionary = AdventureRules.make_monster(&"ofomni", 2)
	assert_eq(str(ofomni.ai), "whip")
	var logic := BattleLogic.new(AdventureRules.balance(), AdventureRules.adoc_combat_stats(), 30, 5, ofomni, 3)
	var b: TacticalBattle = TacticalBridge.build_battle(logic)
	var enemy: Dictionary = b.units[b.units.size() - 1]
	assert_eq([enemy.range_min, enemy.range_max, StringName(enemy.ai)], [1, 2, BattleLogic.AI_WHIP])
