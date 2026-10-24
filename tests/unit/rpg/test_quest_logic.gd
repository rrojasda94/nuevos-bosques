extends GutTest
## Misión del Ofomni (mision-ofomni.md): estados, recompensa, ruta y avance del Ofomni, fracaso,
## combate de misión, monstruos fatales (fatal_at) y guardado v6.

const Q: StringName = QuestLogic.PRIMERA_MISION
const SAVE_SLOT: int = 96
const EVERY: float = 360.0

var _region: Dictionary
var _map: BosqueMap
var _home: int


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"valle_del_sara")
	_map = BosqueMap.for_region(42, _region)
	_home = AdventureRules.home_bosque(_map, _region)


func before_each() -> void:
	GameState.new_game(42)


func after_all() -> void:
	DirAccess.remove_absolute(SaveManager.slot_path(SAVE_SLOT))
	GameState.new_game(42)


func _active() -> Dictionary:
	var q: Dictionary = QuestLogic.new_quest()
	assert_true(QuestLogic.accept(q, _map, 42, _home))
	return q


func test_transitions() -> void:
	var q: Dictionary = QuestLogic.new_quest()
	assert_eq(QuestLogic.state_of(q), QuestLogic.OFFERED)
	assert_false(QuestLogic.transition(q, QuestLogic.COMPLETED), "no se completa sin aceptar")
	assert_false(QuestLogic.transition(q, QuestLogic.FAILED))
	assert_true(QuestLogic.transition(q, QuestLogic.ACTIVE))
	assert_false(QuestLogic.transition(q, QuestLogic.REWARDED), "no se cobra sin vencer")
	assert_true(QuestLogic.transition(q, QuestLogic.COMPLETED))
	assert_true(QuestLogic.transition(q, QuestLogic.REWARDED))
	assert_false(QuestLogic.transition(q, QuestLogic.ACTIVE))
	assert_true(QuestLogic.can_transition(QuestLogic.ACTIVE, QuestLogic.FAILED))
	assert_false(QuestLogic.can_transition(QuestLogic.FAILED, QuestLogic.COMPLETED))


func test_commit_writes_game_state_and_emits_on_change() -> void:
	watch_signals(EventBus)
	var q: Dictionary = QuestLogic.new_quest()
	QuestLogic.commit(Q, q, &"")
	assert_signal_emitted_with_parameters(EventBus, "quest_state_changed", [Q, QuestLogic.OFFERED])
	assert_eq(GameState.quests[Q], q)
	QuestLogic.commit(Q, q, QuestLogic.OFFERED)
	assert_signal_emit_count(EventBus, "quest_state_changed", 1, "sin cambio de estado no se avisa")


func test_reward_only_once() -> void:
	var q: Dictionary = _active()
	assert_eq(QuestLogic.claim_reward(q), {}, "active: nada que cobrar")
	QuestLogic.target_defeated(q)
	assert_eq(QuestLogic.state_of(q), QuestLogic.COMPLETED)
	var reward: Dictionary = QuestLogic.claim_reward(q)
	assert_eq(reward.ofrenda, "cuenco_ritual")
	assert_eq(QuestLogic.state_of(q), QuestLogic.REWARDED)
	assert_eq(QuestLogic.claim_reward(q), {}, "una sola vez")
	GameState.luz = 2
	AdventureRules.apply_quest_reward(reward)
	assert_eq(GameState.luz, AdventureRules.luz_max(), "Luz al tope")
	assert_eq(GameState.inventory, [{ "id": "cuenco_ritual", "luz": 6 }])
	assert_eq(GameState.xp, 25)
	assert_eq(GameState.fama, 1)


func test_sfida_dialogue_by_state_and_declined() -> void:
	var q: Dictionary = QuestLogic.new_quest()
	QuestLogic.commit(Q, q, &"")
	var offer: Array[Dictionary] = NpcDialogue.lines_for(&"sfida_natal")
	assert_eq(offer[0].text, "Adoc, espera. Te estaba buscando.")
	q.declined = true
	assert_eq(QuestLogic.state_of(q), QuestLogic.OFFERED, "Aún no: sigue ofrecida")
	assert_eq(NpcDialogue.lines_for(&"sfida_natal")[0].text, "Brille tu Luz, adoc.", "tras declinar, solo el saludo")
	QuestLogic.accept(q, _map, 42, _home)
	assert_eq(QuestLogic.giver_block(q), "reminder")
	assert_eq(NpcDialogue.lines_for(&"sfida_natal")[0].text, "El Ofomni sigue avanzando. No te demores.")
	QuestLogic.target_defeated(q)
	assert_eq(QuestLogic.giver_block(q), "completed_return")
	QuestLogic.claim_reward(q)
	assert_eq(QuestLogic.giver_block(q), "rewarded_idle")
	var failed: Dictionary = _active()
	failed.state = String(QuestLogic.FAILED)
	assert_eq(QuestLogic.giver_block(failed), "failed")
	failed.failed_told = true
	assert_eq(QuestLogic.giver_block(failed), "failed_reminder")
	QuestLogic.target_defeated(failed)
	assert_eq(QuestLogic.state_of(failed), QuestLogic.FAILED, "vencerlo tarde no completa la misión")
	assert_eq(QuestLogic.giver_block(failed), "failed_victory_return")


func test_spawn_at_3_or_4_hops_with_fixed_d() -> void:
	for s in [1, 7, 42, 99, 1234]:
		var map := BosqueMap.for_region(s, _region)
		var home: int = AdventureRules.home_bosque(map, _region)
		var spawn: int = QuestLogic.spawn_bosque(map, s, home, 3, 4)
		assert_eq(spawn, QuestLogic.spawn_bosque(map, s, home, 3, 4), "determinista")
		assert_between(map.distance(home, spawn), 3, 4)
	var q: Dictionary = _active()
	assert_eq(int(q.ofomni_d), _map.distance(int(q.ofomni_bosque), _home) + 1, "d = saltos + 1")


func test_route_is_deterministic_and_one_hop_closer_each_step() -> void:
	var spawn: int = QuestLogic.spawn_bosque(_map, 42, _home, 3, 4)
	var route: Array[int] = QuestLogic.route(_map, 42, spawn, _home)
	assert_eq(route, QuestLogic.route(_map, 42, spawn, _home))
	assert_eq(route.back(), _home)
	for i in route.size() - 1:
		assert_true(_map.neighbours_of(route[i]).has(route[i + 1]), "por la adyacencia")
		assert_eq(_map.distance(route[i + 1], _home), _map.distance(route[i], _home) - 1)


func test_advances_one_bosque_every_six_minutes_and_keeps_d() -> void:
	var q: Dictionary = _active()
	var route: Array[int] = QuestLogic.route(_map, 42, int(q.ofomni_bosque), _home)
	var d: int = int(q.ofomni_d)
	assert_eq(QuestLogic.advance(q, EVERY - 1.0, _map, 42, _home, EVERY), 0)
	assert_eq(int(q.ofomni_bosque), route[0])
	assert_eq(QuestLogic.advance(q, 1.0, _map, 42, _home, EVERY), 1)
	assert_eq(int(q.ofomni_bosque), route[1])
	assert_almost_eq(float(q.ofomni_elapsed), 0.0, 0.001)
	assert_eq(int(q.ofomni_d), d, "la d no cambia al acercarse")
	var offered: Dictionary = QuestLogic.new_quest()
	assert_eq(QuestLogic.advance(offered, EVERY * 10, _map, 42, _home, EVERY), 0, "sin aceptar no se mueve")


func test_reaching_home_bosque_fails_the_quest() -> void:
	var q: Dictionary = _active()
	var hops: int = _map.distance(int(q.ofomni_bosque), _home)
	QuestLogic.advance(q, EVERY * (hops - 1), _map, 42, _home, EVERY)
	assert_eq(QuestLogic.state_of(q), QuestLogic.ACTIVE)
	QuestLogic.advance(q, EVERY, _map, 42, _home, EVERY)
	assert_eq(QuestLogic.state_of(q), QuestLogic.FAILED)
	assert_eq(int(q.ofomni_bosque), _home)
	assert_true(QuestLogic.ofomni_present(q), "espera en la villa y se le puede combatir")
	assert_eq(QuestLogic.ofomni_chunk(_map, _home, _home), _map.nujio_chunk[_home])
	assert_eq(QuestLogic.advance(q, EVERY * 5, _map, 42, _home, EVERY), 0, "ya no avanza")
	GameState.luz = 9
	AdventureRules.damage_villa(0.5)
	assert_eq(GameState.luz, 4, "mitad de la Luz suelta, hacia abajo")
	assert_true(GameState.villa_damaged)


func test_ofomni_chunk_is_in_its_bosque_closest_to_home() -> void:
	var spawn: int = QuestLogic.spawn_bosque(_map, 42, _home, 3, 4)
	var c: Vector2i = QuestLogic.ofomni_chunk(_map, spawn, _home)
	assert_eq(_map.bosque_at(c), spawn)
	var villa: Vector2i = _map.nujio_chunk[_home]
	for other: Vector2i in _map.chunks_of(spawn):
		assert_true((c - villa).length_squared() <= (other - villa).length_squared())


func test_exploration_offers_quest_and_runner_fails_it_at_the_villa() -> void:
	var exploration: Node2D = load("res://scenes/world/exploration.tscn").instantiate()
	add_child_autofree(exploration)
	exploration.start()
	var runner: QuestRunner = exploration.get_node("QuestRunner")
	var q: Dictionary = GameState.quests[Q]
	assert_eq(QuestLogic.state_of(q), QuestLogic.OFFERED, "ofrecida al empezar")
	assert_eq(GameState.objective_label, "Sfida", "la brújula apunta al sfida")
	assert_eq(GameState.objective_chunk, _map.nujio_chunk[_home])
	QuestLogic.accept(q, _map, 42, _home)
	QuestLogic.commit(Q, q, QuestLogic.OFFERED)
	GameState.luz = 9
	runner._process(EVERY * 10)
	assert_eq(QuestLogic.state_of(q), QuestLogic.FAILED)
	assert_true(GameState.villa_damaged)
	assert_eq(GameState.luz, 4)
	assert_eq(GameState.objective_label, "Ofomni")
	assert_eq(runner.ofomni_chunk(), _map.nujio_chunk[_home], "espera en la villa")
	var field: MonsterField = exploration.get_node("Monsters")
	assert_not_null(field.ofomni(), "el jugador está en la villa: lo ve")
	assert_true(MonsterSteering.chebyshev(field.ofomni().cell, exploration.get_node("Player").cell) >= MonsterField.OFOMNI_MIN_GAP)


func test_quest_battle_uses_its_own_attempts_and_completes_on_victory() -> void:
	QuestLogic.commit(Q, _active(), &"")
	var d: int = int(GameState.quests[Q].ofomni_d)
	var logic: BattleLogic = AdventureRules.start_quest_battle(Q, d)
	assert_eq(logic.unico_name, "Ofomni")
	assert_eq(logic.unico_max_hp, 18 + 4 * d)
	assert_eq(logic.special_every, 3)
	assert_eq(int(GameState.quests[Q].battle_attempts), 1)
	assert_eq(GameState.battle_attempts, {}, "no usa los intentos por Bosque")
	var opened: Array[int] = GameState.open_bosques.duplicate()
	logic.result = BattleLogic.Result.VICTORY
	assert_eq(AdventureRules.finish_quest_battle(logic, Q), &"victory")
	assert_eq(QuestLogic.state_of(GameState.quests[Q]), QuestLogic.COMPLETED)
	assert_eq(GameState.open_bosques, opened, "no abre Bosques")
	assert_eq(GameState.xp, 4 + 3 * d, "XP de la victoria")


func test_quest_battle_defeat_is_not_fatal() -> void:
	QuestLogic.commit(Q, _active(), &"")
	GameState.luz = 7
	var logic: BattleLogic = AdventureRules.start_quest_battle(Q, 4)
	assert_false(logic.fatal, "el Ofomni de la primera misión no es fatal")
	logic.result = BattleLogic.Result.DEFEAT
	logic.luz = 7
	assert_eq(AdventureRules.finish_quest_battle(logic, Q), &"defeat")
	assert_eq(GameState.hp, AdventureRules.max_hp())
	assert_eq(GameState.luz, 3)
	assert_eq(QuestLogic.state_of(GameState.quests[Q]), QuestLogic.ACTIVE, "él sigue avanzando")


func test_fatal_at_by_momento() -> void:
	assert_false(AdventureRules.is_fatal([], &"riumna"))
	assert_true(AdventureRules.is_fatal(["riumna"], &"riumna"))
	assert_false(AdventureRules.is_fatal(["riumna"], &"gietos"))
	assert_true(AdventureRules.is_fatal(["gietos", "riumna"], &"gietos"))
	var logic := BattleLogic.new(AdventureRules.balance(), AdventureRules.adoc_stats(1), 30, 6, AdventureRules.make_unico(2, "Aledra"), 1)
	logic.fatal = true
	logic.result = BattleLogic.Result.DEFEAT
	watch_signals(EventBus)
	var hp: int = GameState.hp
	assert_eq(AdventureRules.finish_battle(logic, 3), &"game_over")
	assert_signal_emitted(EventBus, "game_ended")
	assert_eq(GameState.hp, hp, "game over: no se despierta en la villa")
	var safe: BattleLogic = AdventureRules.start_battle(3, 2)
	assert_false(safe.fatal, "Botarramas: fatal_at vacío")


func test_save_v6_round_trip() -> void:
	var q: Dictionary = _active()
	QuestLogic.advance(q, 100.5, _map, 42, _home, EVERY)
	QuestLogic.commit(Q, q, &"")
	GameState.inventory = [{ "id": "cuenco_ritual", "luz": 6 }]
	GameState.villa_damaged = true
	GameState.xp = 13
	GameState.fama = 1
	GameState.seen_monsters = { "1,2,1,0": { "monster": "botarramas", "bosque_id": 3, "chunk": [2, 2] } }
	assert_eq(SaveManager.save_game(SAVE_SLOT), OK)
	GameState.new_game(7)
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	var loaded: Dictionary = GameState.quests[Q]
	assert_eq(QuestLogic.state_of(loaded), QuestLogic.ACTIVE)
	assert_eq(int(loaded.ofomni_bosque), int(q.ofomni_bosque))
	assert_almost_eq(float(loaded.ofomni_elapsed), 100.5, 0.001)
	assert_eq(int(loaded.ofomni_d), int(q.ofomni_d))
	assert_eq(GameState.inventory, [{ "id": "cuenco_ritual", "luz": 6 }])
	assert_true(GameState.villa_damaged)
	assert_eq(GameState.xp, 13)
	assert_eq(GameState.fama, 1)
	assert_eq(GameState.seen_monsters["1,2,1,0"].chunk, [2, 2])


func test_v5_save_migrates_with_defaults() -> void:
	var v5: Dictionary = GameState.to_dict()
	v5.save_version = 5
	v5.inventory = {}
	v5.quests = {}
	for key in ["villa_damaged", "xp", "fama", "seen_monsters"]:
		v5.erase(key)
	var file := FileAccess.open(SaveManager.slot_path(SAVE_SLOT), FileAccess.WRITE)
	file.store_string(JSON.stringify(v5))
	file.close()
	GameState.villa_damaged = true
	GameState.xp = 99
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	assert_eq(GameState.inventory, [], "el diccionario de v5 pasa a lista vacía")
	assert_eq(GameState.quests, {}, "sin misión: la exploración la vuelve a ofrecer")
	assert_false(GameState.villa_damaged)
	assert_eq(GameState.xp, 0)
	assert_eq(GameState.fama, 0)
	assert_eq(GameState.seen_monsters, {})
