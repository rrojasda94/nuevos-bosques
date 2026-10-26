extends GutTest
## Refuerzos del combate táctico (combate-tactico.md, "Si un grupo es mayor que el cupo"; PR T1b):
## quien no cabe espera en su borde y entra con CT 50, en una casilla libre de su borde, al empezar
## el turno siguiente a la caída o retirada de uno de los suyos; en los dos bandos. Y prueba de humo
## IA contra IA con refuerzos (TacticalAI, T5), sin bucles.

const TACTICAL: Dictionary = {
	"board": { "width": 8, "height": 6, "deploy_columns": 2, "max_per_side": 2, "ford_cost": 1 },
	"movement": { "mov_base": 3, "mov_agi_ref": 5, "mov_agi_div": 2, "mov_min": 2, "mov_max": 6,
		"jump_base": 1, "jump_agi_div": 7, "drop_extra": 1 },
	"ct": { "threshold": 100, "start_per_agi": 10, "cost_move_and_act": 100, "cost_single": 80,
		"cost_wait": 60, "reinforce_ct": 50 },
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


func _unit(id: StringName, side: int, extra: Dictionary = {}) -> Dictionary:
	var u: Dictionary = { "id": id, "side": side, "agi": 5, "max_hp": 10, "atk": 8, "def": 0 }
	u.merge(extra, true)
	return u


## 3 del jugador (el Adoc y 2 aliados) contra 3 enemigos, con cupo 2: un refuerzo por bando.
func _battle() -> TacticalBattle:
	var fighters: Array = [
		_unit(&"adoc", P, { "leader": true, "max_hp": 40 }), _unit(&"ally_0", P), _unit(&"ally_1", P),
		_unit(&"enemy_0", E), _unit(&"enemy_1", E), _unit(&"enemy_2", E),
	]
	return TacticalBattle.new(TACTICAL, TacticalBoard.from_config(TACTICAL.board), fighters, 3)


## Da el turno a `index` (los demás a CT 0) y devuelve quién juega.
func _turn(b: TacticalBattle, index: int) -> int:
	for i in b.units.size():
		if b.units[i].alive:
			b.set_ct(i, 0)
	b.set_ct(index, 100)
	return b.begin_turn()


func test_extra_fighters_wait_on_their_edge() -> void:
	var b := _battle()
	assert_eq(b.on_board(P), 2)
	assert_eq(b.on_board(E), 2)
	assert_eq(b.waiting_units(P), [2] as Array[int])
	assert_eq(b.waiting_units(E), [5] as Array[int])
	assert_false(b.units[2].alive, "no juega mientras espera")
	assert_false(b.preview_order(20).has(2), "no sale en la línea de orden")
	assert_false(b.preview_order(20).has(5))


func test_enemy_reinforcement_enters_when_one_falls() -> void:
	var b := _battle()
	b.units[3].hp = 1
	b.units[3].cell = Vector2i(3, 2)
	b.units[0].cell = Vector2i(2, 2)
	assert_eq(_turn(b, 0), 0)
	var res: Dictionary = b.attack(3)
	assert_true(res.down)
	assert_eq(b.result, TacticalBattle.Result.ONGOING)
	b.end_turn(TacticalBoard.Facing.EAST)
	assert_eq(b.pending_entries[E], 1)
	b.begin_turn()
	assert_eq(b.last_entries, [5] as Array[int], "entra el que esperaba")
	var u: Dictionary = b.units[5]
	assert_true(u.alive)
	assert_false(u.waiting)
	assert_eq(u.cell.x, 7, "en la columna de su borde")
	assert_eq(u.facing, TacticalBoard.Facing.WEST)
	assert_true(b.waiting_units(E).is_empty())
	assert_eq(b.pending_entries[E], 0)


func test_reinforcement_enters_with_ct_50() -> void:
	var b := _battle()
	b.units[3].hp = 1
	b.units[3].cell = Vector2i(3, 2)
	b.units[0].cell = Vector2i(2, 2)
	_turn(b, 0)
	b.attack(3)
	b.end_turn(TacticalBoard.Facing.EAST)
	# Antes de avanzar ticks: deploy_reinforcements fija CT 50.
	var entered: Array[int] = b.deploy_reinforcements()
	assert_eq(entered, [5] as Array[int])
	assert_eq(b.ct_of(5), 50)


func test_player_reinforcement_enters_when_an_ally_falls() -> void:
	var b := _battle()
	b.units[1].hp = 1
	b.units[1].cell = Vector2i(4, 3)
	b.units[3].cell = Vector2i(5, 3)
	assert_eq(_turn(b, 3), 3)
	var res: Dictionary = b.attack(1)
	assert_true(res.down)
	b.end_turn(TacticalBoard.Facing.WEST)
	b.begin_turn()
	assert_true(b.last_entries.has(2), "entra el aliado que esperaba")
	assert_true(b.units[2].alive)
	assert_eq(b.units[2].cell.x, 0, "por el borde del jugador")
	assert_eq(b.units[2].facing, TacticalBoard.Facing.EAST)


func test_reinforcement_enters_when_one_retreats() -> void:
	var b := _battle()
	b.units[4].cell = Vector2i(7, 0)
	_turn(b, 4)
	var res: Dictionary = b.leave(true)
	assert_eq(res.kind, TacticalBattle.KIND_LEAVE)
	assert_eq(b.result, TacticalBattle.Result.ONGOING, "queda un enemigo esperando")
	b.begin_turn()
	assert_eq(b.last_entries, [5] as Array[int])


func test_reinforcement_takes_the_nearest_free_edge_cell() -> void:
	var b := _battle()
	# Columna del borde enemigo llena: ocupa las 6 filas de x = 7 con casillas bloqueadas salvo una.
	for y: int in 6:
		if y != 0:
			b.board.set_cell(Vector2i(7, y), 0, true)
	b.units[4].cell = Vector2i(7, 0)
	b.units[3].hp = 1
	b.units[3].cell = Vector2i(3, 2)
	b.units[0].cell = Vector2i(2, 2)
	_turn(b, 0)
	b.attack(3)
	b.end_turn(TacticalBoard.Facing.EAST)
	b.begin_turn()
	assert_eq(b.units[5].cell.x, 6, "su columna está ocupada: la siguiente hacia dentro")


func test_no_victory_while_an_enemy_waits() -> void:
	var b := _battle()
	b.remove_unit(3)
	b.remove_unit(4)
	b.check_end()
	assert_eq(b.result, TacticalBattle.Result.ONGOING, "el tercero sigue esperando")
	assert_eq(b.pending_entries[E], 2)
	b.begin_turn()
	assert_eq(b.last_entries, [5] as Array[int], "y entra")
	assert_eq(b.pending_entries[E], 0, "no queda nadie más esperando")
	b.remove_unit(5)
	b.check_end()
	assert_eq(b.result, TacticalBattle.Result.VICTORY)


func test_pending_entries_do_not_fill_free_slots_on_their_own() -> void:
	# Con una party elegida más pequeña que el cupo, el que no se eligió no entra sin una caída.
	var fighters: Array = [_unit(&"adoc", P, { "leader": true }), _unit(&"ally_0", P, { "reserve": true }),
		_unit(&"enemy_0", E)]
	var b := TacticalBattle.new(TACTICAL, TacticalBoard.from_config(TACTICAL.board), fighters, 3)
	assert_eq(b.waiting_units(P), [1] as Array[int])
	b.begin_turn()
	assert_true(b.last_entries.is_empty())
	assert_false(b.units[1].alive)


# --- Escena -------------------------------------------------------------------------------------

func test_scene_shows_waiting_and_places_reinforcements() -> void:
	var balance: Dictionary = AdventureRules.balance()
	var logic := BattleLogic.new(balance, { "max_hp": 30, "atk": 6, "def": 3, "agi": 5 }, 30, 5,
		{ "name": "R1", "max_hp": 10, "atk": 4, "def": 1, "agi": 7 }, 42)
	for k: int in 3:
		logic.add_enemy({ "name": "R%d" % (k + 2), "max_hp": 10, "atk": 4, "def": 1, "agi": 7 })
	var cfg: Dictionary = TacticalBattle.config_from_balance(balance)
	cfg.board = { "width": 8, "height": 6, "deploy_columns": 2, "max_per_side": 2, "ford_cost": 1 }
	var scene: TacticalBattleScene = load("res://scenes/rpg/tactical_battle_scene.tscn").instantiate()
	add_child_autofree(scene)
	scene.begin(logic, { "leaf": 0, "trunk": 0, "ground": 0 }, UnicoArt.Kind.REPAREP, [], cfg)
	assert_eq(scene.battle.waiting_units(E).size(), 2)
	var waiting_view: Node2D = scene._views[scene.battle.waiting_units(E)[0]].node
	assert_false(waiting_view.visible, "quien espera no se dibuja en el tablero")
	var labels: int = 0
	for child: Node in scene.get_node("Root/OrderLine").get_children():
		if child is Label and (child as Label).text == Texts.get_text("tactical_waiting"):
			labels += 1
	assert_eq(labels, 1, "la línea de orden marca a los que esperan")


# --- Humo: IA contra IA con refuerzos -----------------------------------------------------------

func test_ai_vs_ai_with_reinforcements_ends_without_loops() -> void:
	for rng_seed: int in [1, 2, 3, 5, 8, 13, 21, 34]:
		var r: Dictionary = _simulate(rng_seed)
		if r.is_empty():
			return
		assert_true(r.over, "seed %d: el combate termina" % rng_seed)
		assert_gt(int(r.entries), 0, "seed %d: entró algún refuerzo" % rng_seed)


func test_ai_vs_ai_is_deterministic_with_reinforcements() -> void:
	assert_eq(_simulate(7), _simulate(7))


func _simulate(rng_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var cfg: Dictionary = TACTICAL.duplicate(true)
	var roles: Array = ["attacker", "defender", "support", ""]
	var profiles: Array = ["aggressive", "swarm", "tactical", "berserk"]
	var fighters: Array = [{ "id": &"adoc", "side": P, "agi": rng.randi_range(5, 8), "max_hp": 40,
		"atk": 7, "def": 3, "leader": true }]
	for k: int in 3:
		fighters.append({ "id": StringName("ally_%d" % k), "side": P, "agi": rng.randi_range(4, 8),
			"max_hp": rng.randi_range(10, 20), "atk": rng.randi_range(4, 8), "def": rng.randi_range(1, 2),
			"role": roles[rng.randi_range(0, roles.size() - 1)] })
	var profile: String = profiles[rng.randi_range(0, profiles.size() - 1)]
	for k: int in 4:
		fighters.append({ "id": StringName("enemy_%d" % k), "side": E, "agi": rng.randi_range(3, 8),
			"max_hp": rng.randi_range(8, 16), "atk": rng.randi_range(4, 8), "def": rng.randi_range(0, 2),
			"ai": profile, "role": roles[rng.randi_range(0, roles.size() - 1)] if profile == "tactical" else "" })
	var b := TacticalBattle.new(cfg, TacticalBoard.from_config(cfg.board), fighters, rng_seed)
	b.set_group_order(rng.randi_range(0, 2))
	var entries: int = 0
	var log: Array = []
	for turn: int in 1500:
		if b.is_over():
			break
		var i: int = b.begin_turn()
		if i == TacticalBattle.NONE:
			break
		entries += b.last_entries.size()
		for e: int in b.last_entries:
			assert_eq(b.ct_of(e) >= 50, true, "entra con CT 50 (o más tras los ticks)")
		var p: Dictionary = TacticalAI.plan(b, i)
		if not b.reachable_for(i).has(p.move_to):
			fail_test("seed %d turno %d: casilla inalcanzable" % [rng_seed, turn])
			return {}
		if p.move_to != b.units[i].cell:
			b.move_active(p.move_to)
		TacticalAI.apply_action(b, p)
		if not b.is_over():
			TacticalAI.finish_turn(b)
		# Nadie comparte casilla.
		var seen: Dictionary = {}
		for u: Dictionary in b.units:
			if u.alive:
				if seen.has(u.cell):
					fail_test("seed %d turno %d: dos en %s" % [rng_seed, turn, u.cell])
					return {}
				seen[u.cell] = true
		log.append([i, p.move_to, p.action, p.target])
	return { "over": b.is_over(), "entries": entries, "log": log, "result": b.result }
