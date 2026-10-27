extends GutTest
## Progresión del Adoc (progresion-adoc.md; stats automáticos de moralidad-y-progresion.md, 0.5):
## curva de niveles, stats por nivel, subida con tope, stats del nivel en el combate, mensajes de la
## subida y guardado v7.

const SAVE_SLOT: int = 95
const Battle = preload("res://scripts/rpg/battle.gd")
## Tabla de la ficha (0.5, columna "Auto"): nivel -> [XP acumulada, PV máx., ATQ, DEF].
const SPEC: Dictionary = {
	1: [0, 30, 6, 3], 2: [10, 33, 6, 4], 3: [25, 36, 7, 4], 4: [45, 39, 7, 5], 5: [70, 42, 8, 5],
	6: [100, 45, 8, 6], 7: [140, 48, 9, 6], 8: [190, 51, 9, 7], 9: [250, 54, 10, 7], 10: [320, 57, 10, 8],
}


func before_each() -> void:
	GameState.new_game(42)
	_arm_spear()


func after_all() -> void:
	DirAccess.remove_absolute(SaveManager.slot_path(SAVE_SLOT))


func test_level_table_matches_spec() -> void:
	assert_eq(AdventureRules.max_level(), 10)
	for level: int in SPEC:
		var row: Array = SPEC[level]
		assert_eq(AdventureRules.xp_for_level(level), row[0], "XP del nivel %d" % level)
		assert_eq(AdventureRules.adoc_stats(level), { "max_hp": row[1], "atk": row[2], "def": row[3] }, "stats del nivel %d" % level)


func test_compact_rule_holds() -> void:
	for level: int in range(2, 11):
		var a: Dictionary = AdventureRules.adoc_stats(level - 1)
		var b: Dictionary = AdventureRules.adoc_stats(level)
		assert_eq(b.max_hp - a.max_hp, 3, "+3 PV máx. en el nivel %d" % level)
		if level % 2 == 0:
			assert_eq([b.atk - a.atk, b.def - a.def], [0, 1], "par: +1 DEF")
		else:
			assert_eq([b.atk - a.atk, b.def - a.def], [1, 0], "impar: +1 ATQ")


func test_level_for_xp_is_inclusive_and_capped() -> void:
	assert_eq(AdventureRules.level_for_xp(0), 1)
	assert_eq(AdventureRules.level_for_xp(9), 1)
	assert_eq(AdventureRules.level_for_xp(10), 2, "umbral inclusivo")
	assert_eq(AdventureRules.level_for_xp(24), 2)
	assert_eq(AdventureRules.level_for_xp(25), 3)
	assert_eq(AdventureRules.level_for_xp(320), 10)
	assert_eq(AdventureRules.level_for_xp(99999), 10, "tope en el nivel 10")
	assert_eq(AdventureRules.xp_to_next(0), 10)
	assert_eq(AdventureRules.xp_to_next(12), 13)
	assert_eq(AdventureRules.xp_to_next(400), -1, "en el tope no hay siguiente")


func test_two_victories_reach_level_2() -> void:
	assert_eq(AdventureRules.victory_xp(1), 7)
	assert_eq(AdventureRules.levels_gained(0, 7), [] as Array[int])
	assert_eq(AdventureRules.levels_gained(7, 7), [2] as Array[int])


func test_gain_xp_levels_up_with_hp_and_signal() -> void:
	watch_signals(EventBus)
	GameState.hp = 20
	var levels: Array[int] = AdventureRules.gain_xp(10)
	assert_eq(levels, [2] as Array[int])
	assert_eq(GameState.level, 2)
	assert_eq(GameState.xp, 10)
	assert_eq(AdventureRules.max_hp(), 33)
	assert_eq(GameState.hp, 23, "los PV actuales suben +3, sin curar del todo")
	assert_signal_emitted_with_parameters(EventBus, "character_leveled_up", [&"adoc", 2])


func test_gain_xp_several_levels_at_once() -> void:
	watch_signals(EventBus)
	var levels: Array[int] = AdventureRules.gain_xp(45)
	assert_eq(levels, [2, 3, 4] as Array[int])
	assert_eq(GameState.level, 4)
	assert_eq(GameState.hp, 39, "30 + 3 × 3")
	assert_signal_emit_count(EventBus, "character_leveled_up", 3)


func test_gain_xp_stops_at_level_10() -> void:
	AdventureRules.gain_xp(320)
	assert_eq(GameState.level, 10)
	assert_eq(GameState.hp, 57)
	watch_signals(EventBus)
	assert_eq(AdventureRules.gain_xp(500), [] as Array[int])
	assert_eq(GameState.level, 10, "no hay nivel 11")
	assert_eq(GameState.xp, 820, "la XP sigue acumulándose")
	assert_signal_not_emitted(EventBus, "character_leveled_up")


func test_battle_logic_uses_level_stats() -> void:
	GameState.level = 5
	GameState.xp = 70
	GameState.hp = 42
	var logic: BattleLogic = AdventureRules.start_battle(3, 2)
	assert_eq(logic.adoc_max_hp, 42)
	assert_eq(logic.adoc_atk, 8 + 2, "ATQ del nivel 5 más la Lanza de adoc equipada")
	assert_eq(logic.adoc_def, 5)
	assert_eq(logic.adoc_hp, 42)
	var stats := { "max_hp": 50, "atk": 11, "def": 7 }
	var direct := BattleLogic.new(AdventureRules.balance(), stats, 99, 5, AdventureRules.make_unico(1, "X"), 1)
	assert_eq([direct.adoc_max_hp, direct.adoc_atk, direct.adoc_def, direct.adoc_hp], [50, 11, 7, 50])


func test_victory_applies_xp_and_level_with_messages() -> void:
	GameState.xp = 5
	GameState.hp = 20
	var logic: BattleLogic = AdventureRules.start_battle(3, 2)
	assert_eq(logic.victory_xp, 10)
	assert_eq(logic.level_ups, [2] as Array[int], "5 + 10 = 15: nivel 2")
	# Victoria forzada: el Único a 1 PV y un ataque que siempre lo tumba.
	logic.unico_hp = 1
	var events: Array[Dictionary] = logic.play_turn(BattleLogic.Action.ATTACK)
	assert_eq(events.back().kind, &"victory")
	var msgs: Array[Dictionary] = Battle.messages_for(events, logic.balance)
	var texts: Array = msgs.map(func(m: Dictionary) -> String: return m.text)
	assert_eq(texts.slice(-3), ["Ganas 10 de experiencia.", "¡Subes a nivel 2!", "Tienes puntos para crecer (pantalla I)."], "tras la victoria")
	assert_eq(AdventureRules.finish_battle(logic, 3), &"victory")
	assert_eq(GameState.xp, 15)
	assert_eq(GameState.level, 2)
	assert_eq(GameState.hp, logic.adoc_hp + 3)


func test_quest_reward_levels_up_and_notices() -> void:
	watch_signals(EventBus)
	GameState.xp = 7
	AdventureRules.apply_quest_reward({ "xp": 25, "fama": 1 })
	assert_eq(GameState.level, 3, "7 + 25 = 32")
	assert_signal_emit_count(EventBus, "character_leveled_up", 2)
	assert_signal_emitted_with_parameters(EventBus, "notice_requested", ["¡Subes a nivel 2!\n¡Subes a nivel 3!\nTienes puntos para crecer (pantalla I)."])


func test_save_v7_round_trip_level_and_refuges() -> void:
	AdventureRules.gain_xp(30)
	GameState.looted_refuges.append(Vector2i(3, 4))
	assert_eq(SaveManager.save_game(SAVE_SLOT), OK)
	GameState.new_game(1)
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	assert_eq(GameState.xp, 30)
	assert_eq(GameState.level, 3)
	assert_eq(GameState.looted_refuges, [Vector2i(3, 4)] as Array[Vector2i])
	assert_eq(int(GameState.to_dict().save_version), GameState.SAVE_VERSION)


func test_migration_from_v6_derives_level_from_xp() -> void:
	GameState.xp = 30
	GameState.hp = 30
	var v6: Dictionary = GameState.to_dict()
	v6.save_version = 6
	v6.erase("level")
	v6.erase("looted_refuges")
	GameState.new_game(1)
	GameState.from_dict(v6)
	assert_eq(GameState.level, 3, "el nivel que corresponde a su XP")
	assert_eq(AdventureRules.max_hp(), 36, "stats automáticos del nivel 3 (0.5)")
	assert_eq(GameState.stat_points, 6, "los puntos del nivel, por repartir")
	assert_eq(GameState.hp, 30, "los PV guardados se conservan")
	assert_eq(GameState.looted_refuges, [] as Array[Vector2i])


func test_migration_from_old_save_starts_at_level_1() -> void:
	var v5: Dictionary = GameState.to_dict()
	v5.save_version = 5
	for key: String in ["level", "looted_refuges", "xp", "fama", "bag", "equipped"]:
		v5.erase(key)
	GameState.level = 7
	GameState.from_dict(v5)
	assert_eq(GameState.level, 1)
	assert_eq(GameState.xp, 0)


func test_hud_status_lines() -> void:
	const Screen = preload("res://scripts/rpg/inventory_screen.gd")
	GameState.xp = 12
	GameState.level = 2
	GameState.hp = 30
	GameState.fama = 1
	var lines: Array[String] = Screen.stat_lines()
	assert_eq(lines[0], "Nivel 2")
	assert_eq(lines[1], "XP 12 / 25")
	assert_eq(lines[2], "PV 30/33")
	assert_eq(lines[3], "ATQ 8 (+2)   DEF 4", "con la lanza equipada")
	assert_eq(lines[5], "Fama 1")
	GameState.level = 10
	GameState.xp = 400
	assert_eq(Screen.stat_lines()[1], "XP 400 (nivel máximo)")


## Pone la lanza en la mano (desde la 0.3 una partida nueva la empieza guardada en la bolsa).
func _arm_spear() -> void:
	for i in GameState.bag.size():
		if InventoryLogic.id_at(GameState.bag, i) == &"lanza_de_adoc":
			AdventureRules.equip_from_bag(i)
			GameState.weapon_drawn = true
			return
