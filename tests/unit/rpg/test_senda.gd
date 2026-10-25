extends GutTest
## Senda y estado de bando (moralidad-y-progresion.md, dos-caminos.md): cada acto mueve la Senda lo
## que dice la ficha (enganchado donde ya ocurre), con topes en -100 y +100; icono de tres estados;
## bando fiel -> en duda con Senda <= -40 y vuelta a fiel con >= -20 (histéresis); garelino solo con
## set_bando; los NPC fieles comentan la duda.

const Crossing = preload("res://scripts/rpg/crossing.gd")
const COORD := Vector2i(6, 13)

var _region: Dictionary
var _map: BosqueMap
var _home: int
var _target: int


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"valle_del_sara")
	_map = BosqueMap.for_region(42, _region)
	_home = AdventureRules.home_bosque(_map, _region)
	_target = _map.neighbours_of(_home)[0]


func before_each() -> void:
	GameState.new_game(42)
	GameState.equipped.main_hand = ""
	NpcDialogue.reset_talks()


func after_all() -> void:
	GameState.new_game(42)


func test_spec_values_in_balance_json() -> void:
	var acts: Dictionary = Senda.config().acts
	assert_eq([Senda.min_value(), Senda.max_value()], [-100, 100])
	assert_eq(int(acts.guardian_defeated), -3)
	assert_eq(int(acts.unico_defeated), -3)
	assert_eq(int(acts.theft), -10)
	assert_eq(int(acts.fruit_taken_out), -1)
	assert_eq(int(acts.pay_luz), 1)
	assert_eq(int(acts.pay_ofrenda), 2)
	assert_eq(int(acts.ofrenda_left), 1)
	assert_eq(int(acts.adoc_helped), 2)
	assert_eq(int(acts.bosque_saved), 5)
	assert_eq([Senda.doubt_at(), Senda.faithful_at()], [-40, -20])
	assert_eq(GameState.senda, 0, "empieza en 0")
	assert_eq(GameState.bando, Senda.FIEL, "empieza fiel")


# --- Actos que bajan la Senda --------------------------------------------------------------------

func test_defeating_a_botarramas_lowers_senda_3() -> void:
	watch_signals(EventBus)
	AdventureRules.guardian_defeated(_target)
	assert_eq(GameState.senda, -3)
	assert_signal_emitted_with_parameters(EventBus, "senda_changed", [-3, -3])


func test_defeating_a_unico_lowers_senda_3_and_offending_more() -> void:
	AdventureRules.unico_defeated(_target, _home)
	assert_eq(GameState.senda, -3, "un Único de dentro del Bosque")
	AdventureRules.open_bosque(_target)
	AdventureRules.unico_defeated(_target, _home, true)
	assert_eq(GameState.senda, -3 - 3 - 2, "atacar a un pasivo con el paso abierto: ofender (-2) además")


func test_winning_a_border_battle_lowers_senda_but_reparep_and_quest_do_not() -> void:
	var logic: BattleLogic = AdventureRules.start_battle(_target, 1)
	logic.result = BattleLogic.Result.VICTORY
	AdventureRules.finish_battle(logic, _target)
	assert_eq(GameState.senda, -3, "Botarramas vencido en el borde")
	var reparep: BattleLogic = AdventureRules.start_battle(_target, 1, &"reparep", 2)
	reparep.result = BattleLogic.Result.VICTORY
	AdventureRules.finish_unico_battle(reparep, _target, _home)
	assert_eq(GameState.senda, -3, "los reparep no son Únicos del Bosque")
	var q: Dictionary = QuestLogic.new_quest()
	q.state = String(QuestLogic.ACTIVE)
	q.ofomni_d = 4
	GameState.quests[&"primera_mision"] = q
	var quest: BattleLogic = AdventureRules.start_quest_battle(&"primera_mision", 4)
	quest.result = BattleLogic.Result.VICTORY
	AdventureRules.finish_quest_battle(quest, &"primera_mision")
	assert_eq(GameState.senda, -3, "vencer al Ofomni descarriado no mueve la Senda")


func test_theft_lowers_senda_10() -> void:
	AdventureRules.record_theft(_target)
	assert_eq(GameState.senda, -10)
	FruitRules.take(COORD, Vector2i(5, 5), _target, _home)
	assert_eq(GameState.senda, -20, "un fruto sin permiso es robo")


func test_taking_stored_fruit_out_lowers_senda_1_each() -> void:
	AdventureRules.open_bosque(_target)
	FruitRules.take(COORD, Vector2i(5, 5), _target, _home, true)
	GameState.fruit_taken = {}
	FruitRules.take(COORD, Vector2i(6, 6), _target, _home, true)
	var paid_bonus: int = GameState.senda
	assert_eq(FruitRules.bosque_entered(_home), 2)
	assert_eq(GameState.senda, paid_bonus - 2, "-1 por fruto sacado")


# --- Actos que suben la Senda --------------------------------------------------------------------

func test_paying_with_luz_raises_1_and_with_ofrenda_2() -> void:
	assert_true(AdventureRules.pay_toll(_target, 3))
	assert_eq(GameState.senda, 1, "peaje con Luz")
	InventoryLogic.add(GameState.bag, &"cuenta_de_barro")
	var other: int = _map.neighbours_of(_home)[1]
	assert_true(AdventureRules.pay_toll_with_ofrenda(other, 3, 0))
	assert_eq(GameState.senda, 3, "peaje con ofrenda: +2")


func test_appeasing_in_battle_counts_as_paying() -> void:
	var logic: BattleLogic = AdventureRules.start_battle(_target, 1)
	logic.play_turn(BattleLogic.Action.OFFER_LUZ)
	AdventureRules.finish_battle(logic, _target)
	assert_eq(GameState.senda, 1)
	var home_logic: BattleLogic = AdventureRules.start_battle(_home, 1, &"ofomni")
	home_logic.toll = 1
	home_logic.play_turn(BattleLogic.Action.OFFER_LUZ)
	AdventureRules.finish_unico_battle(home_logic, _home, _home)
	assert_eq(GameState.senda, 2, "también en el Bosque natal")


func test_leaving_an_ofrenda_raises_1() -> void:
	InventoryLogic.add(GameState.bag, &"trenza_votiva")
	assert_true(AdventureRules.leave_ofrenda(_target, &"trenza_votiva"))
	assert_eq(GameState.senda, 1)


func test_helping_another_adoc_raises_2() -> void:
	var e: Dictionary = AdocEncounters.all(_map, 42)[0]
	AdocEncounters.finish(e, &"victory")
	assert_eq(GameState.senda, 2)
	var e2: Dictionary = AdocEncounters.all(_map, 42)[1]
	AdocEncounters.finish(e2, &"fled")
	assert_eq(GameState.senda, 2, "sin victoria no cuenta")


func test_saving_a_bosque_raises_5() -> void:
	assert_true(BosqueFires.extinguish(Vector2i(2, 2), _target, true))
	assert_eq(GameState.senda, 5, "apagar un incendio")
	AdventureRules.reward_bosque_defense(_target)
	assert_eq(GameState.senda, 10, "defender un Bosque")


func test_far_quest_done_raises_3() -> void:
	var q: Dictionary = FarQuests.new_quest(FarQuests.TYPE_FIRE, _target, Vector2i(3, 4), [_home, _target] as Array[int], 1)
	GameState.far_quests.append(q)
	assert_false(FarQuests.complete(q).is_empty())
	assert_eq(GameState.senda, 3)


# --- Topes e icono -------------------------------------------------------------------------------

func test_senda_is_capped() -> void:
	GameState.senda = 98
	assert_eq(Senda.record(Senda.BOSQUE_SAVED), 2, "solo sube hasta +100")
	assert_eq(GameState.senda, 100)
	watch_signals(EventBus)
	assert_eq(Senda.record(Senda.PAY_LUZ), 0)
	assert_signal_not_emitted(EventBus, "senda_changed", "en el tope no cambia")
	GameState.senda = -95
	GameState.bando = Senda.EN_DUDA
	Senda.record(Senda.THEFT)
	assert_eq(GameState.senda, -100)


func test_icon_has_three_states_without_number() -> void:
	assert_eq(Senda.icon_for(-30), Senda.Icon.VIOLENT)
	assert_eq(Senda.icon_for(-29), Senda.Icon.NEUTRAL)
	assert_eq(Senda.icon_for(29), Senda.Icon.NEUTRAL)
	assert_eq(Senda.icon_for(30), Senda.Icon.RESPECTFUL)
	assert_eq(Senda.icon_name(Senda.Icon.VIOLENT), "violenta")
	assert_eq(Senda.icon_name(Senda.Icon.RESPECTFUL), "respetuosa")


func test_icon_change_is_announced() -> void:
	GameState.senda = 26
	watch_signals(EventBus)
	Senda.record(Senda.BOSQUE_SAVED)
	assert_signal_emitted_with_parameters(EventBus, "notice_requested", ["Tu Senda se vuelve respetuosa."])


# --- Bando ---------------------------------------------------------------------------------------

func test_bando_goes_to_doubt_at_minus_40_with_hysteresis() -> void:
	GameState.senda = -30
	watch_signals(EventBus)
	Senda.record(Senda.THEFT)
	assert_eq(GameState.senda, -40)
	assert_eq(GameState.bando, Senda.EN_DUDA, "Senda <= -40: en duda")
	assert_signal_emitted_with_parameters(EventBus, "bando_changed", [Senda.EN_DUDA])
	Senda.change(19)
	assert_eq(GameState.senda, -21)
	assert_eq(GameState.bando, Senda.EN_DUDA, "entre -40 y -20 sigue en duda (histéresis)")
	Senda.change(1)
	assert_eq(GameState.bando, Senda.FIEL, "Senda >= -20: vuelve a fiel")
	Senda.change(-15)
	assert_eq(GameState.senda, -35)
	assert_eq(GameState.bando, Senda.FIEL, "fiel no pasa a en duda hasta -40")


func test_bando_for_is_pure() -> void:
	assert_eq(Senda.bando_for(Senda.FIEL, -39), Senda.FIEL)
	assert_eq(Senda.bando_for(Senda.FIEL, -40), Senda.EN_DUDA)
	assert_eq(Senda.bando_for(Senda.EN_DUDA, -21), Senda.EN_DUDA)
	assert_eq(Senda.bando_for(Senda.EN_DUDA, -20), Senda.FIEL)
	assert_eq(Senda.bando_for(Senda.GARELINO, 100), Senda.GARELINO, "la Senda no saca de garelino")
	assert_eq(Senda.bando_for(Senda.GARELINO, -100), Senda.GARELINO)


func test_set_bando_for_the_story_encounter() -> void:
	assert_true(AdventureRules.set_bando(Senda.GARELINO))
	assert_eq(GameState.bando, Senda.GARELINO)
	Senda.change(80)
	assert_eq(GameState.bando, Senda.GARELINO, "solo el encuentro (u otra regla) lo cambia")
	assert_false(AdventureRules.set_bando(&"traidor"), "bando no válido")
	assert_false(AdventureRules.set_bando(Senda.GARELINO), "ya lo era")


func test_faithful_npcs_notice_the_doubt() -> void:
	var calm: Array[Dictionary] = NpcDialogue.lines_for(&"sfida_natal")
	var texts: Array = calm.map(func(l: Dictionary) -> String: return l.text)
	assert_false(texts.has(Texts.get_text("npc_doubt_line")), "fiel: nada")
	GameState.bando = Senda.EN_DUDA
	var doubt: Array[Dictionary] = NpcDialogue.lines_for(&"sfida_natal")
	assert_eq(doubt[0].text, "Brille tu Luz, adoc.", "el saludo primero")
	assert_eq(doubt[1].text, Texts.get_text("npc_doubt_line"), "y luego lo nota")
	assert_eq(doubt[1].speaker, "Sfida")


func test_hud_icons_follow_senda_and_bando() -> void:
	var hud := SendaHud.new()
	add_child_autofree(hud)
	assert_eq(hud._senda, Senda.Icon.NEUTRAL)
	assert_eq(hud._bando, Senda.FIEL)
	assert_false(hud._points)
	GameState.senda = -60
	GameState.bando = Senda.EN_DUDA
	GameState.stat_points = 3
	hud._process(0.0)
	assert_eq(hud._senda, Senda.Icon.VIOLENT)
	assert_eq(hud._bando, Senda.EN_DUDA)
	assert_true(hud._points, "+ con puntos por gastar")
