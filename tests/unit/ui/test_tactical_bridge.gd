extends GutTest
## Interruptor tactical.enabled y puente BattleLogic <-> TacticalBattle (PR T4): Crossing elige la
## escena, los combatientes pasan con sus stats y roles, y el resultado vuelve al BattleLogic para
## que AdventureRules lo aplique como siempre. También arranca la escena con un combate de prueba.

const CROSSING: GDScript = preload("res://scripts/rpg/crossing.gd")
const TACTICAL_SCENE: PackedScene = preload("res://scenes/rpg/tactical_battle_scene.tscn")
const MENU_SCENE: PackedScene = preload("res://scenes/rpg/battle.tscn")


func _logic(enemies: int = 2, allies: int = 1) -> BattleLogic:
	var balance: Dictionary = AdventureRules.balance()
	var adoc: Dictionary = { "max_hp": 20, "atk": 6, "def": 3, "agi": 5 }
	var unico: Dictionary = { "name": "R1", "max_hp": 10, "atk": 4, "def": 1, "agi": 7, "role": "defender" }
	var logic := BattleLogic.new(balance, adoc, 18, 5, unico, 42)
	for k: int in range(1, enemies):
		logic.add_enemy({ "name": "R%d" % (k + 1), "max_hp": 10, "atk": 4, "def": 1, "agi": 7 })
	for k: int in allies:
		logic.add_ally({ "name": "A%d" % k, "max_hp": 15, "atk": 5, "def": 2, "kind": "adoc", "agi": 6, "role": "attacker" })
	logic.toll = 3
	return logic


func test_switch_is_off_by_default_in_balance() -> void:
	assert_false(TacticalBridge.is_enabled(AdventureRules.balance()), "tactical.enabled false en balance.json")
	assert_false(TacticalBridge.is_enabled({}))
	assert_true(TacticalBridge.is_enabled({ "tactical": { "enabled": true } }))


func test_crossing_picks_the_scene_by_the_switch() -> void:
	assert_eq(CROSSING.battle_scene({ "tactical": { "enabled": false } }), MENU_SCENE)
	assert_eq(CROSSING.battle_scene({ "tactical": { "enabled": true } }), TACTICAL_SCENE)
	assert_eq(CROSSING.battle_scene(AdventureRules.balance()), MENU_SCENE, "por defecto, el combate por menú")


func test_build_battle_keeps_stats_roles_and_payment() -> void:
	var logic := _logic()
	var b: TacticalBattle = TacticalBridge.build_battle(logic)
	assert_eq(b.units.size(), 4)
	var adoc: Dictionary = b.units[0]
	assert_eq(adoc.id, TacticalBridge.ADOC_ID)
	assert_true(adoc.leader)
	assert_eq(adoc.hp, 18)
	assert_eq(adoc.max_hp, 20)
	assert_eq(adoc.atk, 6)
	var ally: Dictionary = b.units[1]
	assert_eq(ally.side, TacticalBattle.SIDE_PLAYER)
	assert_eq(ally.atk, logic.allies[0].atk, "el bono de rol no se suma dos veces")
	var enemy: Dictionary = b.units[2]
	assert_eq(enemy.side, TacticalBattle.SIDE_ENEMY)
	assert_eq(enemy.def, logic.enemies[0].def, "el bono de rol no se suma dos veces")
	assert_eq(b.toll, 3)
	assert_eq(b.luz, 5)
	assert_eq(b.board.width, 8, "tablero de balance.json")


func test_build_battle_caps_per_side_from_data() -> void:
	var logic := _logic(4, 0)
	var b: TacticalBattle = TacticalBridge.build_battle(logic)
	assert_eq(b.on_board(TacticalBattle.SIDE_ENEMY), 3, "3 enemigos en el tablero (max_per_side 3)")
	assert_eq(b.waiting_units(TacticalBattle.SIDE_ENEMY).size(), 1, "el cuarto espera en el borde (T1b)")
	var cfg: Dictionary = TacticalBattle.config_from_balance(logic.balance)
	cfg.board = { "width": 14, "height": 10, "deploy_columns": 2, "max_per_side": 6, "ford_cost": 1 }
	var big: TacticalBattle = TacticalBridge.build_battle(logic, cfg)
	assert_eq(big.units.size(), 5, "con max_per_side 6 entran los 4")
	assert_true(big.waiting_units(TacticalBattle.SIDE_ENEMY).is_empty())
	assert_eq(big.board.width, 14)


func test_apply_to_logic_returns_result_hp_and_luz() -> void:
	var logic := _logic(1, 1)
	var b: TacticalBattle = TacticalBridge.build_battle(logic)
	b.units[0].hp = 7
	b.units[1].hp = 0
	b.remove_unit(1)
	b.units[2].hp = 0
	b.remove_unit(2)
	b.check_end()
	TacticalBridge.apply_to_logic(b, logic)
	assert_eq(logic.result, BattleLogic.Result.VICTORY)
	assert_eq(logic.adoc_hp, 7)
	assert_true(logic.allies[0].retired, "el aliado caído se retira")
	assert_eq(logic.enemies[0].hp, 0)
	assert_eq(TacticalBridge.end_lines(logic)[0], Texts.get_text("tactical_victory"))


func test_apply_to_logic_appeased_pays_luz() -> void:
	var logic := _logic(1, 0)
	var b: TacticalBattle = TacticalBridge.build_battle(logic)
	b.set_ct(0, 100)
	b.set_ct(1, 0)
	assert_eq(b.begin_turn(), 0)
	assert_false(b.offer_luz().is_empty())
	TacticalBridge.apply_to_logic(b, logic)
	assert_eq(logic.result, BattleLogic.Result.APPEASED)
	assert_eq(logic.luz, 2, "5 − peaje 3")
	assert_eq(TacticalBridge.end_lines(logic), [Texts.get_text("tactical_appeased")] as Array[String])


func test_logic_index_from_ids() -> void:
	assert_eq(TacticalBridge.logic_index(&"adoc"), BattleLogic.TARGET_ADOC)
	assert_eq(TacticalBridge.logic_index(&"ally_1"), 1)
	assert_eq(TacticalBridge.logic_index(&"enemy_2"), 2)


func test_scene_starts_and_builds_units() -> void:
	var scene: TacticalBattleScene = TACTICAL_SCENE.instantiate()
	add_child_autofree(scene)
	var logic := _logic()
	scene.begin(logic, { "leaf": 0, "trunk": 0, "ground": 0 }, UnicoArt.Kind.REPAREP)
	assert_eq(scene.battle.units.size(), 4)
	assert_ne(scene.battle.active, TacticalBattle.NONE, "ya empezó un turno")
	if scene.battle.units[scene.battle.active].side == TacticalBattle.SIDE_PLAYER:
		assert_eq(scene.flow.state, TacticalTurnFlow.State.MENU)
	else:
		assert_eq(scene.flow.state, TacticalTurnFlow.State.IDLE)
