extends GutTest
## Skills por Senda (moralidad-y-progresion.md): dos ramas en cadena, umbral de Senda por skill, un
## punto por skill, lo aprendido se conserva aunque la Senda cambie, y el efecto de cada una:
## S1 visión −2, S2 golpe ×1,5 cada 3 turnos, S3 botín, S4 imponerse, C1 peaje −1, C2 los adoc
## aceptan siempre, C3 riutash al 75% en un Bosque pagado y C4 un Único aliado con relación >= 30.

const Battle = preload("res://scripts/rpg/battle.gd")
const Crossing = preload("res://scripts/rpg/crossing.gd")
const SkillsPage = preload("res://scripts/rpg/skills_page.gd")

var _region: Dictionary
var _map: BosqueMap
var _home: int
var _target: int


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"valle_del_sara")
	_map = BosqueMap.for_region(42, _region)
	_home = AdventureRules.home_bosque(_map, _region)
	_target = _map.neighbours_of(_home)[0]


const OldStartKit = preload("res://tests/unit/rpg/old_start_kit.gd")


func before_each() -> void:
	GameState.new_game(42)
	# Equipo de antes de P4 (sin nada equipado y la bolsa de prueba): OldStartKit.
	OldStartKit.apply()
	GameState.equipped.main_hand = ""


func after_all() -> void:
	GameState.new_game(42)


## Aprende la skill sin pasar por las reglas (para probar su efecto).
func _grant(skill: StringName) -> void:
	GameState.skills.append(String(skill))


# --- Árbol ---------------------------------------------------------------------------------------

func test_two_branches_of_four_with_thresholds() -> void:
	assert_eq(AdocGrowth.branch(AdocGrowth.SOMBRA), [&"paso_quedo", &"golpe_fuerte", &"botin", &"imponerse"] as Array[StringName])
	assert_eq(AdocGrowth.branch(AdocGrowth.CONFIANZA), [&"palabra_suave", &"rostro_conocido", &"descanso_nujio", &"llamada_bosque"] as Array[StringName])
	var sombra: Array = AdocGrowth.branch(AdocGrowth.SOMBRA).map(func(s: StringName) -> int: return AdocGrowth.threshold(s))
	var confianza: Array = AdocGrowth.branch(AdocGrowth.CONFIANZA).map(func(s: StringName) -> int: return AdocGrowth.threshold(s))
	assert_eq(sombra, [-10, -20, -35, -50])
	assert_eq(confianza, [10, 20, 35, 50])


func test_learning_needs_a_point_the_senda_and_the_previous_skill() -> void:
	GameState.senda = -60
	assert_eq(AdocGrowth.skill_state(&"paso_quedo"), AdocGrowth.SkillState.NEEDS_POINT)
	assert_false(AdocGrowth.learn(&"paso_quedo"), "sin punto de skill")
	GameState.skill_points = 2
	assert_eq(AdocGrowth.skill_state(&"golpe_fuerte"), AdocGrowth.SkillState.NEEDS_PREVIOUS)
	assert_false(AdocGrowth.learn(&"golpe_fuerte"), "hay que tener S1 para S2")
	watch_signals(EventBus)
	assert_true(AdocGrowth.learn(&"paso_quedo"))
	assert_signal_emitted_with_parameters(EventBus, "skill_learned", [&"paso_quedo"])
	assert_eq(GameState.skill_points, 1)
	assert_false(AdocGrowth.learn(&"paso_quedo"), "ya aprendida")
	assert_true(AdocGrowth.learn(&"golpe_fuerte"))
	assert_eq(GameState.skill_points, 0)


func test_senda_threshold_is_inclusive() -> void:
	GameState.skill_points = 2
	GameState.senda = -9
	assert_eq(AdocGrowth.skill_state(&"paso_quedo"), AdocGrowth.SkillState.NEEDS_SENDA)
	assert_eq(AdocGrowth.skill_state(&"palabra_suave"), AdocGrowth.SkillState.NEEDS_SENDA)
	GameState.senda = -10
	assert_eq(AdocGrowth.skill_state(&"paso_quedo"), AdocGrowth.SkillState.AVAILABLE)
	GameState.senda = 10
	assert_eq(AdocGrowth.skill_state(&"palabra_suave"), AdocGrowth.SkillState.AVAILABLE)
	assert_eq(AdocGrowth.skill_state(&"paso_quedo"), AdocGrowth.SkillState.NEEDS_SENDA)


func test_learned_skills_stay_when_senda_changes() -> void:
	GameState.skill_points = 2
	GameState.senda = -25
	assert_true(AdocGrowth.learn(&"paso_quedo"))
	GameState.senda = 40
	assert_true(AdocGrowth.has_skill(&"paso_quedo"), "se conserva")
	assert_eq(AdocGrowth.skill_state(&"paso_quedo"), AdocGrowth.SkillState.LEARNED)
	assert_eq(AdocGrowth.skill_state(&"golpe_fuerte"), AdocGrowth.SkillState.NEEDS_SENDA, "pero no se sigue la rama")
	assert_true(AdocGrowth.learn(&"palabra_suave"), "la otra rama, si la Senda llega")


func test_skills_page_texts() -> void:
	GameState.skill_points = 1
	GameState.senda = -15
	assert_eq(SkillsPage.cell_text(&"paso_quedo"), "[!] Paso quedo")
	assert_eq(SkillsPage.cell_text(&"golpe_fuerte"), "[ ] Golpe fuerte")
	assert_eq(SkillsPage.threshold_line(&"paso_quedo"), "Requiere Senda <= -10")
	assert_eq(SkillsPage.threshold_line(&"palabra_suave"), "Requiere Senda >= +10")
	assert_string_contains(SkillsPage.detail_text(&"golpe_fuerte"), "Antes, la anterior de su rama.")
	assert_eq(SkillsPage.activate(&"paso_quedo"), "Aprendes Paso quedo.")
	assert_eq(SkillsPage.cell_text(&"paso_quedo"), "[x] Paso quedo")
	assert_eq(SkillsPage.status_line(), "Senda neutral   Bando: Fiel   Puntos de skill: 0")


# --- Efectos -------------------------------------------------------------------------------------

func test_s1_paso_quedo_lowers_unico_vision_by_2() -> void:
	var before: int = AdventureRules.vision_radius(_target, 10)
	_grant(&"paso_quedo")
	assert_eq(AdventureRules.vision_radius(_target, 10), before - 2)
	assert_eq(AdventureRules.vision_radius(_target, 2), 1, "sin camuflaje, 1 como mínimo")
	assert_eq(AdventureRules.raw_vision(_target, 10), before - 2, "también la del vigía al colarse")


func test_s2_golpe_fuerte_once_every_3_turns() -> void:
	var stats := { "max_hp": 500, "atk": 8, "def": 9 }
	var rival := { "name": "X", "max_hp": 999, "atk": 1, "def": 1 }
	var plain := BattleLogic.new(AdventureRules.balance(), stats, 500, 0, rival, 7)
	var strong := BattleLogic.new(AdventureRules.balance(), stats, 500, 0, rival, 7)
	strong.strong_every = 3
	strong.strong_factor = 1.5
	var marks: Array[bool] = []
	for turn: int in 7:
		var a: Dictionary = plain.play_turn(BattleLogic.Action.ATTACK)[0]
		var b: Dictionary = strong.play_turn(BattleLogic.Action.ATTACK)[0]
		var is_strong: bool = b.get("strong", false)
		marks.append(is_strong)
		assert_eq(int(b.amount), roundi(int(a.amount) * 1.5) if is_strong else int(a.amount), "turno %d" % (turn + 1))
	assert_eq(marks, [true, false, false, true, false, false, true] as Array[bool], "turnos 1, 4 y 7")


func test_s2_is_set_by_the_skill_and_narrated() -> void:
	assert_eq(AdventureRules.start_battle(_target, 1).strong_every, 0, "sin la skill")
	_grant(&"golpe_fuerte")
	var logic: BattleLogic = AdventureRules.start_battle(_target, 1)
	assert_eq([logic.strong_every, logic.strong_factor], [3, 1.5])
	logic.unico_hp = 999
	logic.unico_max_hp = 999
	var events: Array[Dictionary] = logic.play_turn(BattleLogic.Action.ATTACK)
	var msgs: Array[Dictionary] = Battle.messages_for(events, logic.balance, Battle.texts_for(logic))
	assert_string_starts_with(msgs[0].text, "¡Golpe fuerte! Atacas:")


func test_s3_botin_drops_a_small_ofrenda_one_in_four() -> void:
	assert_eq(AdventureRules.loot_for(42, _target, 0), &"", "sin la skill nunca")
	_grant(&"botin")
	var drops: int = 0
	for attempt: int in 400:
		var id: StringName = AdventureRules.loot_for(42, _target, attempt)
		if id != &"":
			drops += 1
			assert_has([&"cuenta_de_barro", &"trenza_votiva"], id, "ofrenda de 3 o 4")
	assert_between(drops, 70, 130, "~25%")


func test_s3_loot_goes_to_the_bag_on_victory() -> void:
	_grant(&"botin")
	var logic: BattleLogic
	for i: int in 40:
		logic = AdventureRules.start_battle(_target, 1)
		if logic.loot_id != &"":
			break
	assert_ne(logic.loot_id, &"", "en 40 intentos alguno deja botín")
	assert_eq(AdventureRules.start_battle(_target, 1, &"reparep", 2).loot_id, &"", "los reparep no son Únicos")
	logic.unico_hp = 1
	var events: Array[Dictionary] = logic.play_turn(BattleLogic.Action.ATTACK)
	assert_eq(str(events.back().loot), String(logic.loot_id))
	var texts: Array = Battle.messages_for(events, logic.balance, Battle.texts_for(logic)).map(func(m: Dictionary) -> String: return m.text)
	assert_has(texts, "El Único deja %s. Lo guardas." % Ofrendas.display_name(logic.loot_id))
	AdventureRules.finish_battle(logic, _target)
	assert_eq(InventoryLogic.count(GameState.bag, logic.loot_id), 1)


func test_s4_imponerse_needs_level_d_plus_2_and_counts_as_defeat() -> void:
	GameState.level = 4
	assert_false(AdventureRules.can_impose(_target, 2), "sin la skill")
	assert_false(Crossing.actions_for(_target).has(Crossing.Option.IMPOSE))
	_grant(&"imponerse")
	assert_true(Crossing.actions_for(_target).has(Crossing.Option.IMPOSE), "opción del menú del borde")
	assert_true(AdventureRules.can_impose(_target, 2), "nivel 4 >= 2 + 2")
	assert_false(AdventureRules.can_impose(_target, 3), "nivel 4 < 3 + 2")
	var xp: int = GameState.xp
	var relation: int = AdventureRules.relation(_target)
	assert_true(AdventureRules.impose(_target, 2))
	assert_true(AdventureRules.is_forced(_target), "Bosque forzado")
	assert_eq(AdventureRules.hostility(_target), 1, "hostilidad +1")
	assert_eq(AdventureRules.relation(_target), relation - 10, "relación -10")
	assert_eq(GameState.senda, -3, "como vencerlo")
	assert_eq(GameState.xp, xp, "sin XP")
	GameState.bosque_state_overrides[str(_target)] = BosqueStates.ENOJADO
	assert_false(AdventureRules.can_impose(_target, 1), "no funciona ante un Bosque enojado")
	assert_true(Crossing.actions_for(_target).has(Crossing.Option.IMPOSE), "se ve, desactivada")


func test_c1_palabra_suave_toll_minus_1_min_1() -> void:
	var before: int = AdventureRules.toll_for(_target, 2)
	_grant(&"palabra_suave")
	assert_eq(AdventureRules.toll_for(_target, 2), before - 1)
	GameState.bosque_relation[str(_target)] = 100
	assert_gte(AdventureRules.toll_for(_target, 0), 1, "mínimo 1")


func test_c2_rostro_conocido_adoc_always_accept() -> void:
	var refusing: Dictionary = {}
	for e: Dictionary in AdocEncounters.all(_map, 42):
		GameState.senda = -100 if AdocEncounters.adoc_senda(42, str(e.id)) >= 0 else 100
		if not AdocEncounters.accepts_help(e):
			refusing = e
			break
	assert_false(refusing.is_empty(), "con la Senda opuesta alguno no quiere")
	GameState.senda = AdocEncounters.adoc_senda(42, str(refusing.id))
	assert_true(AdocEncounters.accepts_help(refusing), "misma Senda: acepta")
	GameState.senda = -100 if GameState.senda >= 0 else 100
	assert_false(AdocEncounters.accepts_help(refusing))
	_grant(&"rostro_conocido")
	assert_true(AdocEncounters.accepts_help(refusing), "con Rostro conocido aceptan siempre")


func test_adoc_senda_is_in_range_and_deterministic() -> void:
	for e: Dictionary in AdocEncounters.all(_map, 42):
		var s: int = AdocEncounters.adoc_senda(42, str(e.id))
		assert_between(s, -80, 80)
		assert_eq(AdocEncounters.adoc_senda(42, str(e.id)), s)


func test_c3_descanso_del_nujio_heals_75_in_a_paid_bosque() -> void:
	GameState.hp = 10
	var max_hp: int = AdventureRules.max_hp()
	AdventureRules.apply_riutash(true, _home)
	var normal: int = GameState.hp
	assert_eq(normal, 10 + ceili((max_hp - 10) * 0.5), "sin la skill: 50%")
	_grant(&"descanso_nujio")
	GameState.hp = 10
	AdventureRules.apply_riutash(true, _home)
	assert_eq(GameState.hp, 10 + ceili((max_hp - 10) * 0.75), "Bosque natal (pagado): 75%")
	GameState.hp = 10
	AdventureRules.apply_riutash(true, _target)
	assert_eq(GameState.hp, normal, "Bosque sin pagar: 50%")
	AdventureRules.open_bosque(_target)
	GameState.hp = 10
	AdventureRules.apply_riutash(true, _target)
	assert_eq(GameState.hp, 10 + ceili((max_hp - 10) * 0.75), "pagado: 75%")
	GameState.hp = 30
	AdventureRules.apply_riutash(false, _target)
	assert_lt(GameState.hp, 30, "expuesto, hiere igual")


func test_c4_llamada_del_bosque_brings_an_ally_with_relation_30() -> void:
	_grant(&"llamada_bosque")
	GameState.bosque_relation[str(_target)] = 29
	assert_eq(AdventureRules.start_battle(_target, 2, &"reparep", 2).allies.size(), 0, "relación 29: nadie")
	GameState.bosque_relation[str(_target)] = 30
	var logic: BattleLogic = AdventureRules.start_battle(_target, 2, &"reparep", 2)
	assert_eq(logic.allies.size(), 1, "un Único del Bosque a tu lado")
	assert_eq(logic.allies[0].kind, &"botarramas")
	assert_eq(AdventureRules.start_battle(_target, 2, &"botarramas").allies.size(), 0, "no contra sus propios Únicos")
	GameState.skills = []
	assert_eq(AdventureRules.start_battle(_target, 2, &"reparep", 2).allies.size(), 0, "sin la skill")
