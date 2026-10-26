extends GutTest
## Crecimiento del Adoc (moralidad-y-progresion.md, 0.5): stats automáticos por nivel, 3 puntos de
## stat por nivel con sus costes (ATQ y DEF 3, Vigor 1 = +2 PV, Luz 1 = +1 al límite), puntos sin
## gastar que se guardan, stats resultantes, pestaña Crecer, Ofomni descarriado ganable en nivel 3
## con cualquier build de combate (PV ×0,85) y guardado v18 con migración desde la tabla antigua.

const SAVE_SLOT: int = 93
const GrowthPage = preload("res://scripts/rpg/growth_page.gd")
const Screen = preload("res://scripts/rpg/inventory_screen.gd")
## Combates simulados por build para la media del Ofomni.
const RUNS: int = 400


func before_each() -> void:
	GameState.new_game(42)
	GameState.equipped.main_hand = ""


func after_all() -> void:
	DirAccess.remove_absolute(SaveManager.slot_path(SAVE_SLOT))
	GameState.new_game(42)


func _level_to(level: int) -> void:
	AdventureRules.gain_xp(AdventureRules.xp_for_level(level) - GameState.xp)


# --- Automático y puntos -------------------------------------------------------------------------

func test_level_up_gives_auto_stats_3_points_and_skill_points_on_even_levels() -> void:
	assert_eq([GameState.stat_points, GameState.skill_points], [0, 0])
	_level_to(2)
	assert_eq(AdocGrowth.player_stats(), { "max_hp": 33, "atk": 6, "def": 4 }, "nivel par: +3 PV, +1 DEF")
	assert_eq([GameState.stat_points, GameState.skill_points], [3, 1], "3 puntos y 1 de skill")
	_level_to(3)
	assert_eq(AdocGrowth.player_stats(), { "max_hp": 36, "atk": 7, "def": 4 }, "nivel impar: +3 PV, +1 ATQ")
	assert_eq([GameState.stat_points, GameState.skill_points], [6, 1], "sin punto de skill en impar")
	_level_to(10)
	assert_eq([GameState.stat_points, GameState.skill_points], [27, 5], "los no gastados se acumulan; 5 de skill")
	assert_eq(AdocGrowth.points_for_level(10), 27)
	assert_eq(AdocGrowth.skill_points_for_level(10), 5)


func test_costs_and_gains() -> void:
	assert_eq([AdocGrowth.cost(&"atk"), AdocGrowth.gain(&"atk")], [3, 1])
	assert_eq([AdocGrowth.cost(&"def"), AdocGrowth.gain(&"def")], [3, 1])
	assert_eq([AdocGrowth.cost(&"vigor"), AdocGrowth.gain(&"vigor")], [1, 2])
	assert_eq([AdocGrowth.cost(&"luz"), AdocGrowth.gain(&"luz")], [1, 1])


func test_buying_atk_costs_3_points() -> void:
	_level_to(2)
	watch_signals(EventBus)
	assert_true(AdocGrowth.buy(&"atk"))
	assert_eq(GameState.stat_points, 0)
	assert_eq(GameState.spent_points, { "atk": 3 })
	assert_eq(AdocGrowth.player_stats().atk, 7)
	assert_signal_emitted_with_parameters(EventBus, "stat_points_spent", [&"atk", 3])
	assert_false(AdocGrowth.buy(&"vigor"), "sin puntos no se compra nada")
	assert_false(AdocGrowth.buy(&"def"))


func test_vigor_and_luz_cost_1_point_each() -> void:
	_level_to(2)
	GameState.hp = 20
	assert_true(AdocGrowth.buy(&"vigor"))
	assert_eq(AdventureRules.max_hp(), 35, "+2 PV máx.")
	assert_eq(GameState.hp, 22, "y los PV actuales suben lo mismo")
	assert_true(AdocGrowth.buy(&"luz"))
	assert_eq(AdventureRules.luz_max(), 11, "+1 al límite de Luz suelta")
	AdventureRules.set_luz(99)
	assert_eq(GameState.luz, 11)
	assert_eq(GameState.stat_points, 1, "quedan los no gastados")
	assert_false(AdocGrowth.buy(&"atk"), "ATQ necesita 3")


func test_draft_applies_all_or_nothing() -> void:
	_level_to(3)
	assert_false(AdocGrowth.apply_draft({ &"atk": 2, &"vigor": 1 }), "7 puntos de 6: nada")
	assert_eq(GameState.stat_points, 6)
	assert_eq(GameState.spent_points, {})
	assert_true(AdocGrowth.apply_draft({ &"atk": 1, &"def": 1 }))
	assert_eq(AdocGrowth.player_stats(), { "max_hp": 36, "atk": 8, "def": 5 }, "build equilibrado de la ficha")
	assert_eq(GameState.stat_points, 0)


func test_balanced_build_matches_the_spec_table_up_to_level_10() -> void:
	# Ficha: compra ATQ en los niveles pares y DEF en los impares.
	for level: int in range(2, 11):
		_level_to(level)
		assert_true(AdocGrowth.buy(&"atk" if level % 2 == 0 else &"def"))
	assert_eq(AdocGrowth.player_stats(), { "max_hp": 57, "atk": 15, "def": 12 })


func test_npc_adoc_use_auto_stats_without_points() -> void:
	_level_to(3)
	AdocGrowth.buy(&"atk")
	assert_eq(AdventureRules.adoc_stats(3), { "max_hp": 36, "atk": 7, "def": 4 }, "los adoc NPC no compran")
	assert_eq(AdventureRules.adoc_combat_stats().atk, 8)


func test_growth_page_draft_preview_and_confirm() -> void:
	_level_to(3)
	var d: Dictionary = {}
	assert_eq(GrowthPage.row_text(&"atk", d), "ATQ +1 (3 puntos)")
	assert_eq(GrowthPage.row_text(&"vigor", d), "Vigor: +2 PV (1 punto)")
	assert_false(GrowthPage.row_enabled(GrowthPage.ROW_CONFIRM, d), "sin borrador no se confirma")
	assert_eq(GrowthPage.activate(&"atk", d), "")
	assert_eq(GrowthPage.activate(&"vigor", d), "")
	assert_eq(GrowthPage.points_left(d), 2)
	assert_eq(GrowthPage.row_text(&"vigor", d), "Vigor: +2 PV (1 punto) x1")
	assert_false(GrowthPage.row_enabled(&"def", d), "DEF necesita 3")
	assert_eq(GrowthPage.activate(&"def", d), "No te llegan los puntos.")
	var preview: Array[String] = GrowthPage.preview_lines(d)
	assert_eq(preview[0], "PV máx. 36 -> 38")
	assert_eq(preview[1], "ATQ 7 -> 8")
	assert_eq(preview[2], "DEF 4", "sin cambio")
	assert_eq(GameState.stat_points, 6, "el borrador no gasta nada")
	assert_eq(GrowthPage.activate(GrowthPage.ROW_CONFIRM, d), "Has crecido.")
	assert_eq(d, {})
	assert_eq(GameState.stat_points, 2)
	assert_eq(AdocGrowth.player_stats(), { "max_hp": 38, "atk": 8, "def": 4 })
	GrowthPage.activate(&"luz", d)
	GrowthPage.activate(GrowthPage.ROW_UNDO, d)
	assert_eq(d, {}, "deshacer vacía el borrador")
	assert_eq(GameState.stat_points, 2)


func test_tab_names_show_pending_points() -> void:
	assert_eq(Screen.tab_name(Screen.TAB_GROW), "Crecer")
	_level_to(2)
	assert_eq(Screen.tab_name(Screen.TAB_GROW), "Crecer (3)")
	assert_eq(Screen.tab_name(Screen.TAB_SKILLS), "Senda (1)")
	assert_eq(Screen.tab_name(Screen.TAB_BAG), "Bolsa")


# --- Ofomni descarriado en nivel 3 (ficha, "Comprobación") -----------------------------------------

## Builds de nivel 3 de la ficha (6 puntos) -> puntos gastados por stat.
func _builds() -> Dictionary:
	return {
		"todo ATQ": { "atk": 6 },
		"equilibrado": { "atk": 3, "def": 3 },
		"todo DEF": { "def": 6 },
		"todo Vigor": { "vigor": 6 },
	}


## Simula RUNS combates solo atacando contra el Ofomni descarriado de distancia d. Devuelve
## { "wins": fracción ganada, "damage": daño medio recibido, "max_hp" }.
func _simulate(spent: Dictionary, d: int, weapon_atk: int) -> Dictionary:
	var stats: Dictionary = AdocGrowth.player_stats(3, spent)
	stats.atk = int(stats.atk) + weapon_atk
	var wins: int = 0
	var damage: int = 0
	for i: int in RUNS:
		var logic := BattleLogic.new(AdventureRules.balance(), stats, int(stats.max_hp), 0,
			AdventureRules.make_monster(&"ofomni_descarriado", d), 1000 + i)
		while not logic.is_over():
			logic.play_turn(BattleLogic.Action.ATTACK)
		if logic.result == BattleLogic.Result.VICTORY:
			wins += 1
		damage += int(stats.max_hp) - logic.adoc_hp
	return { "wins": float(wins) / RUNS, "damage": float(damage) / RUNS, "max_hp": int(stats.max_hp) }


func test_ofomni_hp_is_085() -> void:
	assert_eq(float(AdventureRules.monster_config(&"ofomni_descarriado").hp_factor), 0.85)
	assert_eq(AdventureRules.make_monster(&"ofomni_descarriado", 4).max_hp, 29)


func test_ofomni_is_winnable_at_level_3_with_any_combat_build() -> void:
	var builds: Dictionary = _builds()
	for name: String in builds:
		var r: Dictionary = _simulate(builds[name], 4, 0)
		gut.p("Ofomni d=4, sin arma, %s: gana %d%%, daño medio %.1f de %d" % [name, roundi(r.wins * 100), r.damage, r.max_hp])
		assert_lt(r.damage, float(r.max_hp), "%s: el daño medio no llega a sus PV" % name)
		assert_gte(r.wins, 0.6, "%s: gana la mayoría de las veces" % name)
		assert_gt(r.damage, r.max_hp * 0.5, "%s: no es trivial" % name)
		var armed: Dictionary = _simulate(builds[name], 5, Items.atk_bonus(&"lanza_de_adoc"))
		gut.p("Ofomni d=5, con lanza, %s: gana %d%%, daño medio %.1f de %d" % [name, roundi(armed.wins * 100), armed.damage, armed.max_hp])
		assert_gte(armed.wins, 0.6, "%s: con la lanza, también la d = 5" % name)


func test_ofomni_mean_damage_matches_the_spec_for_the_balanced_build() -> void:
	var r: Dictionary = _simulate(_builds()["equilibrado"], 4, 0)
	assert_almost_eq(r.damage, 25.0, 3.0, "ficha: ~25 de 36")


func test_level_2_still_loses_and_luz_only_build_loses() -> void:
	var lv2: Dictionary = AdocGrowth.player_stats(2, { "atk": 3 })
	var wins: int = 0
	for i: int in RUNS:
		var logic := BattleLogic.new(AdventureRules.balance(), lv2, int(lv2.max_hp), 0,
			AdventureRules.make_monster(&"ofomni_descarriado", 4), 1000 + i)
		while not logic.is_over():
			logic.play_turn(BattleLogic.Action.ATTACK)
		wins += 1 if logic.result == BattleLogic.Result.VICTORY else 0
	assert_lt(float(wins) / RUNS, 0.5, "nivel 2: sigue perdiendo casi siempre")
	var luz: Dictionary = _simulate({ "luz": 6 }, 4, 0)
	assert_lt(luz.wins, 0.5, "todo a Luz: pierde, como es lógico")


# --- Guardado ------------------------------------------------------------------------------------

func test_save_v18_round_trip() -> void:
	_level_to(4)
	AdocGrowth.buy(&"atk")
	AdocGrowth.buy(&"vigor")
	GameState.senda = -45
	GameState.bando = Senda.EN_DUDA
	GameState.senda = -12
	AdocGrowth.learn(AdocGrowth.PASO_QUEDO)
	var expected_points: int = GameState.stat_points
	assert_eq(SaveManager.save_game(SAVE_SLOT), OK)
	GameState.new_game(1)
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	assert_eq(int(GameState.to_dict().save_version), 18)
	assert_eq(GameState.senda, -12)
	assert_eq(GameState.bando, Senda.EN_DUDA, "el bando se guarda (la histéresis no lo recalcula al cargar)")
	assert_eq(GameState.stat_points, expected_points, "los no gastados se guardan")
	assert_eq(GameState.spent_points, { "atk": 3, "vigor": 1 })
	assert_eq(GameState.skill_points, 1)
	assert_eq(GameState.skills, ["paso_quedo"] as Array[String])
	assert_eq(AdocGrowth.player_stats(), { "max_hp": 41, "atk": 8, "def": 5 })


func test_load_sanitizes_growth() -> void:
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	data.senda = 500
	data.bando = "traidor"
	data.stat_points = -4
	data.spent_points = { "atk": 3, "magia": 9, "def": -3 }
	data.skills = ["paso_quedo", "paso_quedo", "volar"]
	GameState.from_dict(data)
	assert_eq(GameState.senda, 100)
	assert_eq(GameState.bando, Senda.FIEL)
	assert_eq(GameState.stat_points, 0)
	assert_eq(GameState.spent_points, { "atk": 3 })
	assert_eq(GameState.skills, ["paso_quedo"] as Array[String])


func test_migration_from_old_table_keeps_level_and_gives_points() -> void:
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	data.save_version = 17
	data.xp = 80
	data.level = 5
	data.hp = 46
	for key: String in ["senda", "bando", "stat_points", "spent_points", "skill_points", "skills"]:
		data.erase(key)
	GameState.from_dict(data)
	assert_eq(GameState.level, 5, "sin perder nivel")
	assert_eq(GameState.xp, 80)
	assert_eq(GameState.stat_points, 12, "3 por cada nivel subido, por repartir")
	assert_eq(GameState.skill_points, 2, "niveles 2 y 4")
	assert_eq(GameState.spent_points, {})
	assert_eq(GameState.skills, [] as Array[String])
	assert_eq([GameState.senda, GameState.bando], [0, Senda.FIEL])
	assert_eq(AdventureRules.max_hp(), 42, "stats automáticos del nivel 5")
	assert_eq(GameState.hp, 42, "los PV de la tabla antigua (46) quedan en el máximo nuevo")
	assert_true(SendaHud.has_points(), "el HUD avisa de los puntos")

