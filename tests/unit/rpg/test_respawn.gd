extends GutTest
## Reaparición tras una derrota no fatal (cruce-y-combate-v2.md, dueño): despiertas con el 50% de
## los PV máximos y la mitad de la Luz suelta junto al Nujio más cercano entre los aliados (relación
## >= 30, o el natal) y el último Bosque pagado; si no, en la villa natal. Guardado v13
## (last_paid_bosque) con migración, y WorldClock.shelter_check suelto al salir la exploración.

const EXPLORATION: String = "res://scenes/world/exploration.tscn"
const SAVE_SLOT: int = 93
const Q: StringName = &"primera_mision"

var _region: Dictionary
var _map: BosqueMap
var _home: int
## Dos Bosques distintos del natal, con el chunk de Nujio en sitios distintos.
var _a: int
var _b: int
## Un Bosque sin villa.
var _wild: int


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"valle_del_sara")
	_map = BosqueMap.for_region(42, _region)
	_home = AdventureRules.home_bosque(_map, _region)
	var others: Array[int] = []
	for id: int in _map.count():
		if id != _home:
			others.append(id)
	_a = others[0]
	_b = others[others.size() - 1]
	_wild = -1
	for id: int in others:
		if not _map.has_villa[id]:
			_wild = id
			break


func before_each() -> void:
	WorldClock.set_process(false)
	GameState.new_game(42)


func after_each() -> void:
	WorldClock.set_process(true)


func after_all() -> void:
	DirAccess.remove_absolute(SaveManager.slot_path(SAVE_SLOT))


func _nujio(id: int) -> Vector2i:
	return _map.nujio_chunk[id]


func _lose(bosque_id: int) -> StringName:
	var logic: BattleLogic = AdventureRules.start_battle(bosque_id, 1)
	logic.adoc_hp = 0
	logic.result = BattleLogic.Result.DEFEAT
	return AdventureRules.finish_battle(logic, bosque_id)


func _win(bosque_id: int) -> void:
	var logic: BattleLogic = AdventureRules.start_battle(bosque_id, 1)
	logic.result = BattleLogic.Result.VICTORY
	AdventureRules.finish_battle(logic, bosque_id)


# --- Valores, PV y Luz ---------------------------------------------------------------------------

func test_values_in_balance_json() -> void:
	var cfg: Dictionary = AdventureRules.balance().respawn
	assert_eq(int(cfg.hp_pct), 50, "50% de los PV máximos (provisional)")
	assert_eq(int(cfg.ally_relation), 30, "aliado: relación >= 30")
	assert_eq(float(AdventureRules.balance().defeat_luz_factor), 0.5, "se pierde la mitad de la Luz")


func test_respawn_hp_is_half_of_max_rounding_up() -> void:
	assert_eq(AdventureRules.respawn_hp(30), 15)
	assert_eq(AdventureRules.respawn_hp(33), 17, "16,5 -> 17")
	assert_eq(AdventureRules.respawn_hp(1), 1, "nunca 0")


func test_border_defeat_wakes_at_half_hp_and_half_luz() -> void:
	GameState.luz = 9
	assert_eq(_lose(_a), &"defeat")
	assert_eq(GameState.hp, AdventureRules.respawn_hp(AdventureRules.max_hp()))
	assert_eq(GameState.hp, 15, "nivel 1: 30 PV -> 15")
	assert_eq(GameState.luz, 4, "mitad de 9, hacia abajo")


func test_quest_defeat_wakes_at_half_hp_and_half_luz() -> void:
	var q: Dictionary = QuestLogic.new_quest()
	assert_true(QuestLogic.accept(q, _map, 42, _home))
	QuestLogic.commit(Q, q, &"")
	var logic: BattleLogic = AdventureRules.start_quest_battle(Q, 4)
	logic.result = BattleLogic.Result.DEFEAT
	logic.luz = 6
	assert_eq(AdventureRules.finish_quest_battle(logic, Q), &"defeat")
	assert_eq(GameState.hp, 15)
	assert_eq(GameState.luz, 3)


# --- Destino ---------------------------------------------------------------------------------------

func test_without_allies_or_payments_wakes_in_home_villa() -> void:
	assert_eq(GameState.last_paid_bosque, -1)
	assert_eq(AdventureRules.respawn_target(_map, _nujio(_a), _home), _home, "aunque caiga junto a otro Nujio")
	assert_eq(AdventureRules.respawn_target(_map, _nujio(_b), _home), _home)


func test_home_counts_as_ally() -> void:
	assert_true(AdventureRules.is_ally(_home, _home))
	assert_false(AdventureRules.is_ally(-1, _home))


func test_nearest_ally_wins() -> void:
	GameState.bosque_relation[str(_a)] = 30
	GameState.bosque_relation[str(_b)] = 45
	assert_true(AdventureRules.is_ally(_a, _home))
	assert_eq(AdventureRules.respawn_target(_map, _nujio(_a), _home), _a)
	assert_eq(AdventureRules.respawn_target(_map, _nujio(_b), _home), _b)
	assert_eq(AdventureRules.respawn_target(_map, _nujio(_home), _home), _home, "junto a casa, la villa natal")


func test_relation_below_threshold_is_not_ally() -> void:
	GameState.bosque_relation[str(_a)] = 29
	assert_false(AdventureRules.is_ally(_a, _home))
	assert_eq(AdventureRules.respawn_target(_map, _nujio(_a), _home), _home)


func test_last_paid_bosque_counts_even_after_expiring() -> void:
	assert_true(AdventureRules.pay_toll(_a, 0))
	assert_eq(GameState.last_paid_bosque, _a)
	assert_false(AdventureRules.is_ally(_a, _home), "pagar no lo hace aliado (relación 1)")
	assert_eq(AdventureRules.respawn_target(_map, _nujio(_a), _home), _a)
	GameState.open_until.erase(str(_a))
	assert_eq(AdventureRules.respawn_target(_map, _nujio(_a), _home), _a, "el último pagado, aunque caduque")


func test_only_the_last_payment_counts() -> void:
	AdventureRules.pay_toll(_a, 0)
	AdventureRules.pay_toll(_b, 0)
	assert_eq(GameState.last_paid_bosque, _b)
	assert_eq(AdventureRules.respawn_target(_map, _nujio(_a), _home), _home if _dist(_home, _a) <= _dist(_b, _a) else _b)


func test_ofrenda_and_appeasing_also_set_last_paid() -> void:
	assert_true(InventoryLogic.add(GameState.bag, &"cuenco_ritual"))
	var index: int = AdventureRules.bag_ofrendas().size() - 1
	assert_true(AdventureRules.pay_toll_with_ofrenda(_a, 1, index))
	assert_eq(GameState.last_paid_bosque, _a, "pagar con una ofrenda")
	var logic: BattleLogic = AdventureRules.start_battle(_b, 1)
	logic.result = BattleLogic.Result.APPEASED
	AdventureRules.finish_battle(logic, _b)
	assert_eq(GameState.last_paid_bosque, _b, "Ofrecer Luz en combate también paga")


func test_forced_bosque_is_not_ally() -> void:
	_win(_a)
	assert_true(AdventureRules.is_forced(_a))
	assert_eq(GameState.last_paid_bosque, -1, "vencer no es pagar")
	GameState.bosque_relation[str(_a)] = 40
	assert_false(AdventureRules.is_ally(_a, _home), "forzado sin pagar: no es aliado")
	assert_eq(AdventureRules.respawn_target(_map, _nujio(_a), _home), _home)


func _dist(from_id: int, to_id: int) -> int:
	var d: Vector2i = _nujio(from_id) - _nujio(to_id)
	return absi(d.x) + absi(d.y)


# --- Casilla y aviso -------------------------------------------------------------------------------

func test_respawn_cell_is_walkable_next_to_the_nujio() -> void:
	for id: int in [_home, _a, _b, _wild]:
		if id < 0:
			continue
		var chunk: ChunkData = ChunkGenerator.generate(42, _nujio(id), _region, _map)
		var cell: Vector2i = AdventureRules.respawn_cell(chunk)
		assert_true(chunk.is_walkable(cell), "Bosque %d: transitable" % id)
		assert_true(chunk.is_reachable(cell), "Bosque %d: se sale andando" % id)
		assert_true(AdventureRules.is_next_to_nujio(chunk, cell), "Bosque %d: junto al Nujio" % id)


func test_notice_names_the_villa_or_the_bosque() -> void:
	var name: String = Signpost.villa_name(42, _home)
	assert_eq(AdventureRules.respawn_notice(_map, _home), "Despiertas junto al Nujio de %s." % name)
	assert_ne(_wild, -1, "seed 42 tiene Bosques sin villa")
	assert_eq(AdventureRules.respawn_notice(_map, _wild), Texts.get_text("respawn_bosque"))


# --- Exploración -----------------------------------------------------------------------------------

func test_exploration_wakes_next_to_the_nearest_ally_and_tells_where() -> void:
	var target: int = _wild if _wild >= 0 else _a
	AdventureRules.pay_toll(target, 0)
	GameState.chunk_coord = _nujio(target)
	var expl: Node = load(EXPLORATION).instantiate()
	add_child_autofree(expl)
	expl.start()
	assert_eq(GameState.chunk_coord, _nujio(target), "partida en un Bosque pagado")
	watch_signals(EventBus)
	EventBus.crossing_resolved.emit(target, &"defeated")
	assert_eq(GameState.chunk_coord, _nujio(target))
	var chunk: ChunkData = ChunkGenerator.generate(42, _nujio(target), _region, _map)
	assert_true(AdventureRules.is_next_to_nujio(chunk, GameState.player_cell))
	assert_signal_emitted_with_parameters(EventBus, "notice_requested", [AdventureRules.respawn_notice(_map, target)])


func test_exploration_quest_defeat_wakes_in_home_villa() -> void:
	var expl: Node = load(EXPLORATION).instantiate()
	add_child_autofree(expl)
	expl.start()
	var villa_chunk: Vector2i = _nujio(_home)
	var other: Vector2i = _map.chunks_of(_home).filter(func(c: Vector2i) -> bool: return c != villa_chunk)[0]
	GameState.chunk_coord = other
	expl.start()
	watch_signals(EventBus)
	EventBus.quest_battle_resolved.emit(Q, &"defeat")
	assert_eq(GameState.chunk_coord, villa_chunk)
	assert_signal_emitted_with_parameters(EventBus, "notice_requested",
		["Despiertas junto al Nujio de %s." % Signpost.villa_name(42, _home)])


func test_exploration_releases_shelter_check_on_exit() -> void:
	var expl: Node = load(EXPLORATION).instantiate()
	add_child(expl)
	assert_true(WorldClock.shelter_check.is_valid(), "la exploración presta su comprobación")
	remove_child(expl)
	assert_false(WorldClock.shelter_check.is_valid(), "al salir del árbol la suelta")
	expl.free()
	WorldClock.advance(WorldClock.time_to_riutash())
	assert_eq(GameState.riutash_count, 1, "el riutash pasa sin llamar a la exploración liberada")


# --- Guardado --------------------------------------------------------------------------------------

func test_save_keeps_last_paid_bosque() -> void:
	assert_gte(GameState.SAVE_VERSION, 13)
	AdventureRules.pay_toll(_a, 0)
	assert_eq(int(GameState.to_dict().last_paid_bosque), _a)
	assert_eq(SaveManager.save_game(SAVE_SLOT), OK)
	GameState.new_game(1)
	assert_eq(GameState.last_paid_bosque, -1, "partida nueva: ninguno")
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	assert_eq(GameState.last_paid_bosque, _a)


func test_migration_from_v12_takes_the_latest_open_payment() -> void:
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	data.save_version = 12
	data.erase("last_paid_bosque")
	data.open_until = { "3": 5, "4": 7, "5": AdventureRules.OPEN_PERMANENT }
	GameState.from_dict(data)
	assert_eq(GameState.last_paid_bosque, 4, "el de caducidad más tardía")
	data.open_until = { "6": AdventureRules.OPEN_PERMANENT, "2": AdventureRules.OPEN_PERMANENT }
	GameState.from_dict(data)
	assert_eq(GameState.last_paid_bosque, 2, "solo permanentes: el de id más bajo")
	data.open_until = {}
	GameState.from_dict(data)
	assert_eq(GameState.last_paid_bosque, -1, "nada pagado: ninguno")


func test_waking_in_a_villa_heals_fully() -> void:
	var expl: Node = load(EXPLORATION).instantiate()
	add_child_autofree(expl)
	expl.start()
	var villa_chunk: Vector2i = _nujio(_home)
	var other: Vector2i = _map.chunks_of(_home).filter(func(c: Vector2i) -> bool: return c != villa_chunk)[0]
	GameState.chunk_coord = other
	expl.start()
	EventBus.quest_battle_resolved.emit(Q, &"defeat")
	assert_eq(GameState.chunk_coord, villa_chunk)
	assert_eq(GameState.hp, AdventureRules.max_hp(), "despertar en la villa cura del todo")
