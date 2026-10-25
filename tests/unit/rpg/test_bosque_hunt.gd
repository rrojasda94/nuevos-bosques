extends GutTest
## El Bosque recuerda de verdad (feedback del dueño 0.3): dentro de un Bosque sin pagar envía
## cazadores cada vez más a menudo con la hostilidad y para al pagar o al salir (BosqueHunt);
## enfrentarse a voluntad a un Único pasivo ofende al Bosque y lo deja forzado; por dentro rondan
## Únicos de varios tipos que no persiguen en un Bosque pagado (BosquePatrols); Aledra solo sale
## de noche, es fatal de noche y avisa antes del combate.

const EXPLORATION: String = "res://scenes/world/exploration.tscn"

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
	WorldClock.set_process(false)
	GameState.new_game(42)
	# Sin arma en la mano: con ella ningún Bosque deja pasar en paz (eso se prueba en test_stealth).
	GameState.equipped.main_hand = ""


func after_each() -> void:
	get_tree().paused = false
	GameState.clock_momento = TimeConfig.GIETOS
	WorldClock.set_process(true)


func _exploration() -> Node:
	var expl: Node = load(EXPLORATION).instantiate()
	add_child_autofree(expl)
	expl.start()
	return expl


# --- Cazadores ------------------------------------------------------------------------------------

func test_interval_shrinks_with_hostility_down_to_the_minimum() -> void:
	assert_eq(BosqueHunt.interval(0), 90.0)
	assert_eq(BosqueHunt.interval(1), 75.0)
	assert_eq(BosqueHunt.interval(4), 30.0)
	assert_eq(BosqueHunt.interval(9), 30.0, "nunca menos de 30 s")
	assert_eq(BosqueHunt.max_hunters(), 2)


func test_hunters_come_on_schedule_alternate_and_cap_at_two() -> void:
	AdventureRules.guardian_defeated(_target)
	assert_true(BosqueHunt.is_hunting(_target, _home), "forzado: el Bosque caza")
	assert_false(BosqueHunt.is_hunting(_home, _home), "el natal nunca")
	var hunt := BosqueHunt.new()
	var every: float = BosqueHunt.interval(1)
	assert_eq(hunt.tick(every - 1.0, _target, _home, 42), &"", "todavía no")
	var first: StringName = hunt.tick(1.5, _target, _home, 42)
	assert_ne(first, &"", "a los 75 s llega uno")
	assert_true(hunt.is_first())
	var second: StringName = hunt.tick(every, _target, _home, 42)
	assert_ne(second, &"")
	assert_ne(second, first, "alternan Botarramas y Ofomni")
	assert_eq(hunt.tick(every, _target, _home, 42), &"", "como mucho 2 a la vez")
	hunt.hunter_defeated(first)
	assert_ne(hunt.tick(every, _target, _home, 42), &"", "vencido uno, viene otro")


func test_hunters_stop_when_paying_or_leaving() -> void:
	AdventureRules.guardian_defeated(_target)
	var hunt := BosqueHunt.new()
	hunt.tick(1.0, _target, _home, 42)
	assert_eq(hunt.bosque_id, _target)
	hunt.tick(1.0, _home, _home, 42)
	assert_eq(hunt.bosque_id, -1, "al salir del Bosque se acaba")
	hunt.tick(1.0, _target, _home, 42)
	AdventureRules.pay_toll(_target, 0)
	assert_eq(hunt.tick(500.0, _target, _home, 42), &"", "pagado: no envía más")
	assert_eq(hunt.bosque_id, -1)


func test_exploration_sends_hunters_with_a_notice_and_removes_them_on_payment() -> void:
	var expl: Node = _exploration()
	AdventureRules.guardian_defeated(_target)
	var coord: Vector2i = _map.chunks_of(_target)[0]
	expl._enter_chunk(coord, expl._get_chunk(coord).hub)
	expl._fade.color.a = 0.0
	watch_signals(EventBus)
	expl._process(BosqueHunt.interval(1) + 0.1)
	assert_eq(expl._field.hunters().size(), 1, "el Bosque envía un cazador")
	assert_signal_emitted_with_parameters(EventBus, "notice_requested", [Texts.get_text("bosque_hunt_started")])
	var hunter: OverworldMonster = expl._field.hunters()[0]
	assert_eq(hunter.state, MonsterSteering.State.CHASE)
	var off: Vector2i = (hunter.cell - GameState.player_cell).abs()
	assert_true(off.x > 10 or off.y > 6, "aparece fuera de la vista")
	AdventureRules.pay_toll(_target, 0)
	expl._process(0.1)
	assert_eq(expl._field.hunters().size(), 0, "al pagar se van")


# --- Enfrentarse a voluntad -------------------------------------------------------------------------

func test_defeating_a_passive_unico_on_purpose_forces_the_paid_bosque() -> void:
	AdventureRules.pay_toll(_target, 0)
	assert_true(AdventureRules.is_paid(_target, _home))
	var rel: int = AdventureRules.relation(_target)
	var logic: BattleLogic = AdventureRules.start_battle(_target, 1, &"botarramas")
	logic.result = BattleLogic.Result.VICTORY
	assert_eq(AdventureRules.finish_unico_battle(logic, _target, _home, true), &"victory")
	assert_true(AdventureRules.is_forced(_target), "ofendido: pasa a forzado")
	assert_false(AdventureRules.is_paid(_target, _home), "el pago se pierde")
	assert_eq(AdventureRules.hostility(_target), 1)
	assert_eq(AdventureRules.relation(_target), rel - 10)


func test_confronting_a_passive_unico_asks_first_and_warns() -> void:
	var expl: Node = _exploration()
	AdventureRules.pay_toll(_target, 0)
	var m: OverworldMonster = expl._field.spawn_hunter(&"botarramas", _target, Vector2i(5, 5), _map.styles[_target])
	m.role = MonsterField.ROLE_PATROL
	assert_false(expl._field.can_detect(m), "pasivo")
	watch_signals(EventBus)
	expl._confront(m)
	assert_true(expl._dialogue.is_open(), "pregunta antes")
	assert_signal_not_emitted(EventBus, "unico_battle_requested")
	expl._dialogue.choice.emit(0)
	assert_signal_emitted_with_parameters(EventBus, "unico_battle_requested", [_target, &"botarramas", true])


func test_confronting_an_active_guardian_opens_the_border_menu() -> void:
	var expl: Node = _exploration()
	var m: OverworldMonster = expl._field.spawn_hunter(&"botarramas", _target, Vector2i(5, 5), _map.styles[_target])
	m.role = MonsterField.ROLE_GUARDIAN
	watch_signals(EventBus)
	expl._confront(m)
	assert_signal_emitted_with_parameters(EventBus, "bosque_border_reached", [_target])


# --- Únicos que rondan ------------------------------------------------------------------------------

func test_each_bosque_has_one_or_two_patrols_of_varied_kinds() -> void:
	var kinds: Dictionary = {}
	for id: int in _map.count():
		var patrols: Array[Dictionary] = BosquePatrols.patrols_of(_map, 42, id)
		assert_between(patrols.size(), 1, 2)
		for p: Dictionary in patrols:
			assert_eq(_map.bosque_at(p.chunk), id, "ronda dentro de su Bosque")
			kinds[p.monster] = true
	assert_gt(kinds.size(), 1, "hay variedad")


func test_patrols_do_not_chase_in_a_paid_bosque() -> void:
	var field: MonsterField = add_child_autofree(MonsterField.new())
	field._home = _home
	var m := OverworldMonster.new()
	m.role = MonsterField.ROLE_PATROL
	m.bosque_id = _target
	m.monster_id = &"ofomni"
	add_child_autofree(m)
	assert_true(field.can_detect(m), "sin pagar: te persigue si te ve")
	AdventureRules.pay_toll(_target, 0)
	assert_false(field.can_detect(m), "pagado: te mira pasar")
	m.bosque_id = _home
	assert_false(field.can_detect(m), "en el natal, nunca")


func test_aledra_only_at_night_and_fatal_at_night() -> void:
	assert_false(BosquePatrols.is_out(&"aledra", TimeConfig.GIETOS), "de día no sale")
	assert_true(BosquePatrols.is_out(&"aledra", TimeConfig.RIUMNA), "al anochecer sí")
	assert_true(BosquePatrols.is_out(&"ofomni", TimeConfig.GIETOS))
	var cfg: Dictionary = AdventureRules.monster_config(&"aledra")
	assert_true(AdventureRules.is_fatal(cfg.fatal_at, TimeConfig.RIUMNA))
	assert_false(AdventureRules.is_fatal(cfg.fatal_at, TimeConfig.GIETOS))
	var aledra: Dictionary = AdventureRules.make_monster(&"aledra", 1)
	var botarramas: Dictionary = AdventureRules.make_monster(&"botarramas", 1)
	assert_gt(int(aledra.max_hp), int(botarramas.max_hp), "más fuerte que un Botarramas")
	assert_gt(int(aledra.atk), int(botarramas.atk))
	GameState.clock_momento = TimeConfig.RIUMNA
	assert_true(AdventureRules.start_battle(_target, 1, &"aledra").fatal, "de noche, perder es game over")
	GameState.clock_momento = TimeConfig.GIETOS
	assert_false(AdventureRules.start_battle(_target, 1, &"aledra").fatal)
	# Una Aledra que ronda: fuera solo de noche.
	for id: int in _map.count():
		for p: Dictionary in BosquePatrols.patrols_of(_map, 42, id):
			if p.monster == &"aledra":
				var day: Array = BosquePatrols.patrols_in(_map, 42, p.chunk, TimeConfig.GIETOS).map(func(x: Dictionary) -> String: return x.id)
				var night: Array = BosquePatrols.patrols_in(_map, 42, p.chunk, TimeConfig.RIUMNA).map(func(x: Dictionary) -> String: return x.id)
				assert_false(day.has(p.id))
				assert_true(night.has(p.id))


func test_aledra_at_night_warns_before_the_battle_and_lets_you_flee() -> void:
	var expl: Node = _exploration()
	GameState.clock_momento = TimeConfig.RIUMNA
	var m: OverworldMonster = expl._field.spawn_hunter(&"aledra", _target, Vector2i(5, 5), _map.styles[_target])
	watch_signals(EventBus)
	expl._on_monster_engaged(m)
	assert_true(expl._dialogue.is_open(), "avisa: Aledra de noche puede matarte")
	assert_signal_not_emitted(EventBus, "unico_battle_requested")
	expl._dialogue.choice.emit(1)
	assert_signal_not_emitted(EventBus, "unico_battle_requested", "huir: sin combate")
	assert_gt(m.cooldown, 0.0, "y deja de verte un rato")
