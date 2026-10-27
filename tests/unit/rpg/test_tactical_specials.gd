extends GutTest
## Especiales del combate táctico (combate-tactico.md, "Ataques en área y especiales" y "Ataque por
## sorpresa"; ia-de-combate.md; PR T6): el área anunciada (Latigazo múltiple) golpea al turno
## siguiente solo a quien sigue dentro, su tamaño por tablero, la IA del Ofomni que maximiza el área,
## los aliados con IA que salen de ella, el ataque conjunto de los reparep con 2, 3 y 4, la sorpresa
## y la emboscada (CT, orientación y party automática) y el determinismo.
## Bloque tactical fijo de test sin evasión ni bonos de posición (los golpes aciertan y el daño es
## exacto) y tirada de daño 0.

const TACTICAL_SCENE: PackedScene = preload("res://scenes/rpg/tactical_battle_scene.tscn")
const STYLE: Dictionary = { "leaf": 0, "trunk": 0, "ground": 0 }
const TACTICAL: Dictionary = {
	"board": { "width": 8, "height": 6, "deploy_columns": 2, "max_per_side": 4, "ford_cost": 1,
		"latigazo": [3, 1] },
	"movement": { "mov_base": 3, "mov_agi_ref": 5, "mov_agi_div": 2, "mov_min": 2, "mov_max": 6,
		"jump_base": 1, "jump_agi_div": 7, "drop_extra": 1 },
	"ct": { "threshold": 100, "start_per_agi": 10, "cost_move_and_act": 100, "cost_single": 80,
		"cost_wait": 60, "reinforce_ct": 50 },
	"actions": { "evasion_base": 0, "evasion_per_agi": 0, "flank_factor": 0.5, "back_factor": 0.0,
		"height_evasion": 0, "hit_min": 5, "hit_max": 100, "flank_bonus": 0, "back_bonus": 0,
		"height_bonus": 0, "support_range": 2, "joint_max": 4 },
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
const NORTH := TacticalBoard.Facing.NORTH
const EAST := TacticalBoard.Facing.EAST
const SOUTH := TacticalBoard.Facing.SOUTH
const WEST := TacticalBoard.Facing.WEST
## Ofomni con Latigazo múltiple: cada 3 ataques, ×3, en área.
const OFOMNI: Dictionary = { "ai": "berserk", "special_every": 3, "special_factor": 3.0, "special_area": true }

var _saved_party: Array[String] = []


func before_each() -> void:
	_saved_party = GameState.last_party.duplicate()


func after_each() -> void:
	GameState.last_party = _saved_party


func _unit(id: StringName, side: int, cell: Vector2i, extra: Dictionary = {}) -> Dictionary:
	var u: Dictionary = { "id": id, "side": side, "agi": 5, "cell": cell, "max_hp": 30, "atk": 8, "def": 3,
		"facing": EAST if side == P else WEST }
	u.merge(extra, true)
	return u


func _battle(fighters: Array, cfg: Dictionary = TACTICAL, rng_seed: int = 1) -> TacticalBattle:
	return TacticalBattle.new(cfg, TacticalBoard.from_config(cfg.board), fighters, rng_seed)


## Da el turno a `index` (los demás en pie a CT 0).
func _turn(b: TacticalBattle, index: int) -> void:
	for i in b.units.size():
		if b.units[i].alive:
			b.set_ct(i, 0)
	b.set_ct(index, 100)
	assert_eq(b.begin_turn(), index)


func _cells(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Variant in list:
		out.append(c as Vector2i)
	out.sort_custom(func(a: Vector2i, c: Vector2i) -> bool: return a.y < c.y or (a.y == c.y and a.x < c.x))
	return out


# --- Área anunciada -----------------------------------------------------------------------------

func test_announced_area_hits_next_turn_only_who_stays_inside() -> void:
	var b := _battle([_unit(&"ofomni", E, Vector2i(5, 2), OFOMNI),
		_unit(&"adoc", P, Vector2i(4, 2), { "leader": true }),
		_unit(&"ally_0", P, Vector2i(4, 1)), _unit(&"ally_1", P, Vector2i(4, 3))])
	b.units[0].attacks = 2
	assert_true(b.will_announce(0), "su siguiente ataque es el tercero: lo anuncia")
	_turn(b, 0)
	b.wait_turn(WEST)
	assert_eq(b.last_announce, 0)
	assert_eq(_cells(b.units[0].announce), [Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3)] as Array[Vector2i],
		"3 x 1 justo delante")
	assert_eq(b.danger_cells(P).size(), 3)
	assert_true(b.danger_cells(E).is_empty(), "el área no amenaza a su propio bando")
	# El aliado de arriba sale del área; los otros dos se quedan.
	_turn(b, 2)
	assert_false(b.move_active(Vector2i(3, 0)).is_empty())
	b.end_turn(NORTH)
	_turn(b, 0)
	assert_true(b.can_area_strike())
	var res: Dictionary = b.area_strike()
	assert_eq(res.kind, TacticalBattle.KIND_AREA)
	assert_eq(res.text_key, TacticalBattle.TEXT_AREA)
	var hit: Array[int] = []
	for h: Dictionary in res.hits:
		hit.append(int(h.receiver))
		assert_eq(int(h.damage), (8 - 3) * 3, "ATQ − DEF, ×3")
	hit.sort()
	assert_eq(hit, [1, 3] as Array[int], "solo los que siguen dentro")
	assert_eq(int(b.units[2].hp), 30, "salir del área lo esquiva")
	assert_eq(int(b.units[1].hp), 15)
	assert_true((b.units[0].announce as Array).is_empty(), "el área se gasta")
	assert_eq(int(b.units[0].attacks), 3)
	b.end_turn(WEST)
	assert_eq(b.last_announce, TacticalBattle.NONE, "tras el especial vuelve a contar desde cero")


func test_area_strike_is_halved_by_defend_and_never_twice() -> void:
	var b := _battle([_unit(&"ofomni", E, Vector2i(5, 2), OFOMNI),
		_unit(&"adoc", P, Vector2i(4, 2), { "leader": true })])
	b.units[0].attacks = 2
	_turn(b, 0)
	b.wait_turn(WEST)
	_turn(b, 1)
	b.defend()
	b.end_turn(EAST)
	_turn(b, 0)
	var res: Dictionary = b.area_strike()
	assert_true(res.hits[0].defended)
	assert_eq(int(res.hits[0].damage), ceili(15 * 0.5), "Defender lo reduce a la mitad")
	assert_false(b.can_area_strike(), "una sola vez")
	assert_true(b.area_strike().is_empty())


func test_area_whiffs_when_everybody_left() -> void:
	var b := _battle([_unit(&"ofomni", E, Vector2i(5, 2), OFOMNI),
		_unit(&"adoc", P, Vector2i(4, 2), { "leader": true })])
	b.units[0].attacks = 2
	_turn(b, 0)
	b.wait_turn(WEST)
	_turn(b, 1)
	b.move_active(Vector2i(2, 2))
	b.end_turn(EAST)
	_turn(b, 0)
	var res: Dictionary = b.area_strike()
	assert_true(res.hits.is_empty())
	assert_true(res.missed)
	assert_eq(int(b.units[1].hp), 30)


func test_area_size_by_board() -> void:
	var balance: Dictionary = AdventureRules.balance()
	var small: Dictionary = TacticalBridge.arena_config(balance, 0.5)
	var medium: Dictionary = TacticalBridge.arena_config(balance, 0.7)
	var large: Dictionary = TacticalBridge.arena_config(balance, 0.95)
	assert_eq(small.arena_plan.size, TacticalArena.SMALL)
	assert_eq(medium.arena_plan.size, TacticalArena.MEDIUM)
	assert_eq(large.arena_plan.size, TacticalArena.LARGE)
	assert_eq(small.board.latigazo, [3, 1])
	assert_eq(medium.board.latigazo, [3, 1])
	assert_eq(large.board.latigazo, [3, 2], "más fondo en el grande, donde hay sitio para esquivar")
	var fighters: Array = [_unit(&"ofomni", E, Vector2i(6, 4), OFOMNI), _unit(&"adoc", P, Vector2i(1, 1), { "leader": true })]
	var big := TacticalBattle.new(large, TacticalBoard.from_config(large.board), fighters, 1)
	assert_eq(big.area_size(), Vector2i(3, 2))
	assert_eq(_cells(big.area_cells(Vector2i(6, 4), WEST)), [Vector2i(4, 3), Vector2i(5, 3), Vector2i(4, 4),
		Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5)] as Array[Vector2i], "3 de ancho y 2 de fondo")
	var little := TacticalBattle.new(small, TacticalBoard.from_config(small.board), fighters, 1)
	assert_eq(little.area_size(), Vector2i(3, 1))
	assert_eq(_cells(little.area_cells(Vector2i(0, 0), SOUTH)), [Vector2i(0, 1), Vector2i(1, 1)] as Array[Vector2i],
		"en el borde, solo las casillas del tablero")


func test_ofomni_ai_faces_the_area_that_catches_the_most() -> void:
	var b := _battle([_unit(&"ofomni", E, Vector2i(4, 2), OFOMNI),
		_unit(&"adoc", P, Vector2i(3, 2), { "leader": true, "hp": 10 }),
		_unit(&"ally_0", P, Vector2i(5, 3)), _unit(&"ally_1", P, Vector2i(4, 3))])
	b.units[0].attacks = 1
	_turn(b, 0)
	var p: Dictionary = TacticalAI.plan(b, 0)
	assert_eq(p.action, TacticalBattle.KIND_ATTACK)
	assert_eq(p.target, 1, "carga contra el más cercano de menos PV")
	assert_eq(p.move_to, Vector2i(4, 2), "desde la casilla cuya área pilla a más")
	assert_eq(p.facing, SOUTH, "al sur pilla a 2; hacia su objetivo, solo a 1")
	TacticalAI.run_turn(b)
	assert_eq(b.units[0].facing, SOUTH)
	assert_eq(_cells(b.units[0].announce), [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)] as Array[Vector2i])
	# En su siguiente turno golpea el área sin moverse.
	_turn(b, 0)
	var strike: Dictionary = TacticalAI.plan(b, 0)
	assert_eq(strike.action, TacticalBattle.KIND_AREA)
	assert_eq(strike.move_to, Vector2i(4, 2))
	var res: Dictionary = TacticalAI.run_turn(b)
	assert_eq((res.result.hits as Array).size(), 2)


func test_ai_allies_leave_the_announced_area() -> void:
	var b := _battle([_unit(&"ofomni", E, Vector2i(5, 2), OFOMNI),
		_unit(&"adoc", P, Vector2i(1, 5), { "leader": true }), _unit(&"ally_0", P, Vector2i(4, 2))])
	b.units[0].announce = [Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3)]
	_turn(b, 2)
	var p: Dictionary = TacticalAI.plan(b, 2)
	assert_false(b.danger_cells(P).has(p.move_to), "sale del área marcada")
	assert_eq(p.action, TacticalBattle.KIND_ATTACK, "y golpea desde fuera si llega")
	assert_true(TacticalBoard.are_adjacent(p.move_to, Vector2i(5, 2)))
	# Si ya no puede moverse, se defiende.
	b.active_moved = true
	var stuck: Dictionary = TacticalAI.plan(b, 2)
	assert_eq(stuck.action, TacticalBattle.KIND_DEFEND)
	assert_eq(stuck.move_to, Vector2i(4, 2))


func test_ai_ally_without_target_still_steps_out() -> void:
	var b := _battle([_unit(&"ofomni", E, Vector2i(7, 0), OFOMNI),
		_unit(&"adoc", P, Vector2i(0, 5), { "leader": true }), _unit(&"ally_0", P, Vector2i(3, 3))])
	b.units[0].announce = [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)]
	_turn(b, 2)
	var p: Dictionary = TacticalAI.plan(b, 2)
	assert_eq(p.action, TacticalAI.KIND_NONE)
	assert_false(b.danger_cells(P).has(p.move_to))
	assert_eq(TacticalRules.distance(p.move_to, Vector2i(3, 3)), 1, "la casilla segura más cercana")


# --- Ataque conjunto ----------------------------------------------------------------------------

func _swarm(n: int) -> TacticalBattle:
	var around: Array[Vector2i] = [Vector2i(4, 2), Vector2i(3, 1), Vector2i(3, 3), Vector2i(2, 2)]
	var fighters: Array = []
	for k: int in n:
		fighters.append(_unit(StringName("r%d" % k), E, around[k], { "ai": "swarm", "joint": true, "atk": 4 }))
	fighters.append(_unit(&"adoc", P, Vector2i(3, 2), { "leader": true, "max_hp": 100, "def": 3 }))
	return _battle(fighters)


func test_joint_attack_with_2_3_and_4_adjacent() -> void:
	for n: int in [2, 3, 4]:
		var b := _swarm(n)
		var target: int = n
		_turn(b, 0)
		var res: Dictionary = b.attack(target)
		assert_eq((res.joint as Array).size(), n, "%d atacan juntos" % n)
		assert_eq(int(res.damage), 4 * n - 3, "suma de ATQ − DEF una sola vez (%d)" % n)
		assert_eq(res.text_key, TacticalBattle.TEXT_JOINT)
		for k: int in range(1, n):
			assert_eq(b.ct_of(k), -80, "los compañeros gastan su siguiente turno")


func test_lone_or_non_joint_attacks_alone() -> void:
	var b := _swarm(1)
	_turn(b, 0)
	var res: Dictionary = b.attack(1)
	assert_true((res.joint as Array).is_empty())
	assert_eq(int(res.damage), 1, "4 − 3")
	var mixed := _battle([_unit(&"r0", E, Vector2i(4, 2), { "joint": true, "atk": 4 }),
		_unit(&"other", E, Vector2i(2, 2), { "atk": 4 }),
		_unit(&"adoc", P, Vector2i(3, 2), { "leader": true, "max_hp": 100 })])
	_turn(mixed, 0)
	assert_eq(int(mixed.attack(2).damage), 1, "quien no es del grupo no se suma")


func test_joint_attack_is_capped_and_halved_by_defend() -> void:
	var cfg: Dictionary = TACTICAL.duplicate(true)
	cfg.actions.joint_max = 3
	var around: Array[Vector2i] = [Vector2i(4, 2), Vector2i(3, 1), Vector2i(3, 3), Vector2i(2, 2)]
	var fighters: Array = []
	for k: int in 4:
		fighters.append(_unit(StringName("r%d" % k), E, around[k], { "joint": true, "atk": 4 }))
	fighters.append(_unit(&"adoc", P, Vector2i(3, 2), { "leader": true, "max_hp": 100, "def": 3 }))
	var b := _battle(fighters, cfg)
	_turn(b, 4)
	b.defend()
	b.end_turn(EAST)
	_turn(b, 0)
	var res: Dictionary = b.attack(4)
	assert_eq((res.joint as Array).size(), 3, "como mucho joint_max")
	assert_eq(int(res.damage), ceili((12 - 3) * 0.5), "Defender reduce a la mitad todo el ataque")


func test_swarm_ai_and_bridge_make_the_joint_attack() -> void:
	var adoc: Dictionary = { "max_hp": 40, "atk": 6, "def": 3, "agi": 5 }
	var logic := BattleLogic.new(AdventureRules.balance(), adoc, 40, 5,
		{ "name": "R1", "max_hp": 10, "atk": 4, "def": 1, "agi": 7, "ai": "swarm" }, 42)
	logic.add_enemy({ "name": "R2", "max_hp": 10, "atk": 4, "def": 1, "agi": 7, "ai": "swarm" })
	logic.joint_attack = true
	var fighters: Array = TacticalBridge.fighters_from_logic(logic)
	assert_true(fighters[1].joint)
	assert_true(fighters[2].joint)
	# Con un compañero ya junto al Adoc, el enjambre rodea y ataca junto.
	var b := _battle([_unit(&"r1", E, Vector2i(5, 3), { "ai": "swarm", "joint": true, "atk": 4 }),
		_unit(&"r0", E, Vector2i(4, 2), { "ai": "swarm", "joint": true, "atk": 4 }),
		_unit(&"adoc", P, Vector2i(3, 2), { "leader": true, "max_hp": 100, "def": 3 })])
	_turn(b, 0)
	var res: Dictionary = TacticalAI.run_turn(b)
	assert_eq(res.plan.target, 2)
	assert_eq((res.result.joint as Array).size(), 2)
	assert_eq(int(res.result.damage), 8 - 3)


# --- Sorpresa y emboscada -----------------------------------------------------------------------

func _opening_battle() -> TacticalBattle:
	return _battle([_unit(&"adoc", P, Vector2i(-1, -1), { "leader": true, "agi": 5 }),
		_unit(&"ally_0", P, Vector2i(-1, -1), { "agi": 4 }),
		_unit(&"enemy_0", E, Vector2i(-1, -1), { "agi": 9 }), _unit(&"enemy_1", E, Vector2i(-1, -1), { "agi": 8 })])


func test_surprise_your_side_plays_first_and_enemies_show_their_back() -> void:
	var b := _opening_battle()
	b.apply_opening(TacticalBattle.Opening.SURPRISE)
	assert_eq(b.ct_of(0), 100)
	assert_eq(b.ct_of(1), 100)
	assert_lt(b.ct_of(2), 100)
	assert_lt(b.ct_of(3), 100)
	for k: int in [2, 3]:
		assert_eq(b.units[k].facing, EAST, "los enemigos, de espaldas al jugador (que llega por la izquierda)")
		assert_eq(TacticalRules.relation(b.units[k].cell, int(b.units[k].facing), b.units[0].cell),
			TacticalRules.Relation.BACK)
	for k: int in [0, 1]:
		assert_eq(b.units[k].facing, EAST, "el jugador mira al enemigo")
	var first: Array[int] = [b.begin_turn()]
	b.end_turn(EAST)
	first.append(b.begin_turn())
	first.sort()
	assert_eq(first, [0, 1] as Array[int], "jugáis todos antes")
	assert_eq(b.opening_text_key(), TacticalBattle.TEXT_SURPRISE)


func test_ambush_the_other_way_round() -> void:
	var b := _opening_battle()
	b.apply_opening(TacticalBattle.Opening.AMBUSH)
	assert_eq(b.ct_of(2), 100)
	assert_eq(b.ct_of(3), 100)
	assert_lt(b.ct_of(0), 100)
	for k: int in [0, 1]:
		assert_eq(b.units[k].facing, WEST, "tú, de espaldas al enemigo")
	var first: Array[int] = [b.begin_turn()]
	b.end_turn(WEST)
	first.append(b.begin_turn())
	first.sort()
	assert_eq(first, [2, 3] as Array[int])
	assert_eq(b.opening_text_key(), TacticalBattle.TEXT_AMBUSH)
	var normal := _opening_battle()
	normal.apply_opening(TacticalBattle.Opening.NORMAL)
	assert_eq(normal.ct_of(2), 90, "normal: CT por AGI")
	assert_eq(normal.opening_text_key(), &"")


func test_opening_rules_from_exploration() -> void:
	assert_eq(TacticalBridge.opening_for_confront(false), TacticalBattle.Opening.SURPRISE,
		"abordarlo sin que te persiga: no te ha detectado")
	assert_eq(TacticalBridge.opening_for_confront(true), TacticalBattle.Opening.NORMAL)
	assert_eq(TacticalBridge.opening_for_engaged(MonsterField.ROLE_HUNTER, false), TacticalBattle.Opening.AMBUSH,
		"un cazador aparece fuera de la vista")
	assert_eq(TacticalBridge.opening_for_engaged(MonsterField.ROLE_PATROL, true), TacticalBattle.Opening.AMBUSH,
		"Aledra de noche")
	assert_eq(TacticalBridge.opening_for_engaged(MonsterField.ROLE_PATROL, false), TacticalBattle.Opening.NORMAL)
	assert_eq(TacticalBridge.opening_for_sleep(), TacticalBattle.Opening.AMBUSH)


func _logic(allies: int) -> BattleLogic:
	var adoc: Dictionary = { "max_hp": 20, "atk": 6, "def": 3, "agi": 5 }
	var logic := BattleLogic.new(AdventureRules.balance(), adoc, 20, 5,
		{ "name": "R1", "max_hp": 10, "atk": 4, "def": 1, "agi": 7 }, 42)
	logic.add_enemy({ "name": "R2", "max_hp": 10, "atk": 4, "def": 1, "agi": 7 })
	for k: int in allies:
		logic.add_ally({ "name": "Aliado %d" % k, "kind": "adoc", "max_hp": 15, "atk": 5, "def": 2, "agi": 6 })
	return logic


func _cfg(quota: int) -> Dictionary:
	var cfg: Dictionary = TacticalBattle.config_from_balance(AdventureRules.balance())
	cfg.board = { "width": 8, "height": 6, "deploy_columns": 2, "max_per_side": quota, "ford_cost": 1 }
	return cfg


func test_scene_ambush_enters_the_last_party_and_says_it() -> void:
	GameState.last_party = ["adoc:2"] as Array[String]
	var scene: TacticalBattleScene = TACTICAL_SCENE.instantiate()
	add_child_autofree(scene)
	scene.begin(_logic(3), STYLE, UnicoArt.Kind.REPAREP, [], _cfg(2), null, true)
	assert_null(scene.party_screen, "sin preguntar")
	assert_eq(scene.battle.units[1].id, &"ally_2", "entra la última party guardada")
	assert_eq(scene.battle.opening, TacticalBattle.Opening.AMBUSH)
	var label: Label = scene.get_node("Root/ActionBox/Text")
	assert_eq(label.text, Texts.get_text("tactical_ambush"))
	assert_eq(label.text, "¡Emboscada!")
	assert_true(scene.get_node("Root/ActionBox").visible)
	assert_eq(scene.battle.active, TacticalBattle.NONE, "el primer turno espera a que se lea la línea")
	for u: Dictionary in scene.battle.units:
		if u.alive and int(u.side) == E:
			assert_eq(int(u.ct), 100)


func test_scene_surprise_says_it() -> void:
	var scene: TacticalBattleScene = TACTICAL_SCENE.instantiate()
	add_child_autofree(scene)
	scene.begin(_logic(0), STYLE, UnicoArt.Kind.REPAREP, [], _cfg(3), null, false, true)
	assert_eq(scene.battle.opening, TacticalBattle.Opening.SURPRISE)
	assert_eq((scene.get_node("Root/ActionBox/Text") as Label).text, "¡Sorpresa!")
	assert_eq(scene.battle.ct_of(0), 100)


func test_scene_marks_the_announced_cells() -> void:
	var scene: TacticalBattleScene = TACTICAL_SCENE.instantiate()
	add_child_autofree(scene)
	scene.begin(_logic(0), STYLE, UnicoArt.Kind.EYES, [], _cfg(3))
	assert_true(scene.announced_cells().is_empty())
	scene.battle.units[1].announce = [Vector2i(4, 1), Vector2i(4, 2)]
	assert_eq(scene.announced_cells().size(), 2)


# --- Determinismo -------------------------------------------------------------------------------

func test_same_seed_same_special_battle() -> void:
	var a: Array = _simulate(11)
	var c: Array = _simulate(11)
	assert_false(a.is_empty())
	assert_eq(a, c, "misma seed, mismos anuncios, golpes y final")


## Ofomni con Latigazo y dos reparep contra el Adoc y dos aliados, todos con IA, con sorpresa.
func _simulate(rng_seed: int) -> Array:
	var cfg: Dictionary = TACTICAL.duplicate(true)
	cfg.attack = { "roll_min": -1, "roll_max": 2, "min_damage": 1 }
	cfg.actions.evasion_base = 5
	cfg.actions.evasion_per_agi = 2
	var b := _battle([_unit(&"adoc", P, Vector2i(-1, -1), { "leader": true, "max_hp": 40 }),
		_unit(&"ally_0", P, Vector2i(-1, -1), { "role": "defender" }),
		_unit(&"ally_1", P, Vector2i(-1, -1), { "role": "support" }),
		_unit(&"ofomni", E, Vector2i(-1, -1), OFOMNI.merged({ "max_hp": 40, "agi": 6 })),
		_unit(&"r0", E, Vector2i(-1, -1), { "ai": "swarm", "joint": true, "atk": 4, "agi": 7 }),
		_unit(&"r1", E, Vector2i(-1, -1), { "ai": "swarm", "joint": true, "atk": 4, "agi": 7 })], cfg, rng_seed)
	b.apply_opening(TacticalBattle.Opening.SURPRISE)
	var log: Array = []
	for turn: int in 400:
		if b.is_over():
			break
		var i: int = b.begin_turn()
		if i == TacticalBattle.NONE:
			break
		var r: Dictionary = TacticalAI.run_turn(b)
		log.append([i, r.plan.move_to, r.plan.action, r.plan.target, r.plan.facing,
			int(r.result.get("damage", 0)), b.last_announce])
	log.append("end %d" % b.result)
	return log
