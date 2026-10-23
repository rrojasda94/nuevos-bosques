extends GutTest
## Reglas del Adoc fuera del combate (ADR 0009): peaje, Únicos, resultado del combate, paso
## abierto guardado y descanso en una villa.

const SAVE_SLOT: int = 97

var _region: Dictionary
var _map: BosqueMap
var _home: int
var _b: Dictionary


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"valle_del_sara")
	_map = BosqueMap.for_region(42, _region)
	_home = AdventureRules.home_bosque(_map, _region)
	_b = AdventureRules.balance()


func before_each() -> void:
	GameState.new_game(42)


func after_all() -> void:
	DirAccess.remove_absolute(SaveManager.slot_path(SAVE_SLOT))


func test_new_game_starts_with_balance_values() -> void:
	assert_eq(GameState.hp, int(_b.adoc.max_hp))
	assert_eq(GameState.luz, int(_b.adoc.start_luz))
	assert_eq(GameState.open_bosques, [] as Array[int])


func test_spec_values_in_balance_json() -> void:
	assert_eq(AdventureRules.max_hp(), 30)
	assert_eq(AdventureRules.start_luz(), 10)
	assert_eq(AdventureRules.luz_max(), 10)
	assert_eq(AdventureRules.toll_cost(1), 4, "vecino del inicial: 3 + 1")


func test_bosque_distance() -> void:
	assert_eq(_map.distance(_home, _home), 0)
	for n in _map.neighbours_of(_home):
		assert_eq(_map.distance(_home, n), 1)
		assert_eq(_map.distance(n, _home), 1)
	for id in _map.count():
		assert_gt(_map.distance(_home, id), -1, "todos los Bosques conectados")
		assert_eq(_map.distance(_home, id), _map.distance(id, _home))
	assert_eq(_map.distance(_home, -1), -1)


func test_toll_cost_grows_with_distance() -> void:
	var t: Dictionary = _b.toll
	for id in _map.count():
		var d: int = _map.distance(_home, id)
		assert_eq(AdventureRules.toll_cost(d), int(t.base) + int(t.per_d) * d)
	assert_eq(AdventureRules.toll_cost(3) - AdventureRules.toll_cost(2), int(t.per_d))


func test_unico_stats_by_distance_with_caps() -> void:
	var u1: Dictionary = AdventureRules.make_unico(1, "conífera")
	assert_eq(u1.name, "Único de conífera")
	assert_eq([u1.max_hp, u1.atk, u1.def], [22, 5, 1])
	var u3: Dictionary = AdventureRules.make_unico(3, "sauce")
	assert_eq([u3.max_hp, u3.atk, u3.def], [30, 7, 2])
	var u6: Dictionary = AdventureRules.make_unico(6, "cactus")
	assert_eq([u6.max_hp, u6.atk, u6.def], [42, 10, 4])
	var far: Dictionary = AdventureRules.make_unico(20, "cactus")
	assert_eq([far.max_hp, far.atk, far.def], [42, 10, 4], "tope de d = 6")
	assert_lte(far.def, int(_b.unico.def_max), "tope de DEF")


func test_pay_toll_opens_passage_or_refuses() -> void:
	var target: int = _map.neighbours_of(_home)[0]
	assert_false(AdventureRules.is_passable(target, _home))
	assert_false(AdventureRules.pay_toll(target, GameState.luz + 1))
	assert_eq(GameState.luz, 10)
	assert_false(AdventureRules.is_passable(target, _home))
	assert_true(AdventureRules.pay_toll(target, 4))
	assert_eq(GameState.luz, 6)
	assert_true(AdventureRules.is_passable(target, _home))
	assert_true(AdventureRules.is_passable(_home, _home))
	assert_false(AdventureRules.is_passable(-1, _home), "límite de la región")


func test_victory_restores_luz_bonus_keeps_hp_and_opens() -> void:
	var target: int = _map.neighbours_of(_home)[0]
	var logic: BattleLogic = AdventureRules.start_battle(target, 1, "conífera")
	logic.adoc_hp = 17
	logic.luz = 4
	logic.result = BattleLogic.Result.VICTORY
	assert_eq(AdventureRules.finish_battle(logic, target), &"victory")
	assert_eq(GameState.hp, 17, "los PV se mantienen entre combates")
	assert_eq(GameState.luz, 4 + int(_b.victory_luz))
	assert_true(GameState.open_bosques.has(target))


func test_victory_at_luz_cap_does_not_exceed_max() -> void:
	var target: int = _map.neighbours_of(_home)[0]
	var logic: BattleLogic = AdventureRules.start_battle(target, 1, "conífera")
	logic.luz = AdventureRules.luz_max()
	logic.result = BattleLogic.Result.VICTORY
	AdventureRules.finish_battle(logic, target)
	assert_eq(GameState.luz, AdventureRules.luz_max(), "+1 con la Luz al tope no sube")
	AdventureRules.set_luz(99)
	assert_eq(GameState.luz, AdventureRules.luz_max())
	AdventureRules.set_luz(-3)
	assert_eq(GameState.luz, 0)


func test_defeat_restores_hp_halves_luz_and_keeps_closed() -> void:
	var target: int = _map.neighbours_of(_home)[0]
	GameState.luz = 7
	var logic: BattleLogic = AdventureRules.start_battle(target, 1, "conífera")
	logic.adoc_hp = 0
	logic.result = BattleLogic.Result.DEFEAT
	assert_eq(AdventureRules.finish_battle(logic, target), &"defeat")
	assert_eq(GameState.hp, AdventureRules.max_hp())
	assert_eq(GameState.luz, 3, "mitad de 7, redondeando hacia abajo")
	assert_false(GameState.open_bosques.has(target))


func test_fled_keeps_damage_taken_and_unico_returns_at_full_hp() -> void:
	var target: int = _map.neighbours_of(_home)[0]
	var first: BattleLogic = AdventureRules.start_battle(target, 2, "palmera")
	first.unico_hp = 3
	first.adoc_hp = 12
	first.result = BattleLogic.Result.FLED
	assert_eq(AdventureRules.finish_battle(first, target), &"fled")
	assert_eq(GameState.hp, 12)
	assert_false(GameState.open_bosques.has(target), "el paso sigue cerrado")
	var second: BattleLogic = AdventureRules.start_battle(target, 2, "palmera")
	assert_eq(second.unico_hp, second.unico_max_hp, "huir no conserva el daño hecho al Único")
	assert_eq(second.adoc_hp, 12)
	assert_eq(GameState.battle_attempts[str(target)], 2)
	assert_ne(first.rng.seed, second.rng.seed, "cada intento tiene su propia semilla")


func test_battle_seed_is_deterministic() -> void:
	assert_eq(AdventureRules.battle_seed(42, 3, 0), AdventureRules.battle_seed(42, 3, 0))
	assert_ne(AdventureRules.battle_seed(42, 3, 0), AdventureRules.battle_seed(42, 4, 0))
	assert_ne(AdventureRules.battle_seed(42, 3, 0), AdventureRules.battle_seed(43, 3, 0))


func test_open_passage_luz_and_hp_survive_save_and_load() -> void:
	var target: int = _map.neighbours_of(_home)[0]
	AdventureRules.pay_toll(target, 4)
	AdventureRules.set_hp(21)
	GameState.battle_attempts["5"] = 2
	assert_eq(SaveManager.save_game(SAVE_SLOT), OK)
	GameState.new_game(1)
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	assert_eq(GameState.open_bosques, [target] as Array[int])
	assert_eq(GameState.luz, 6)
	assert_eq(GameState.hp, 21)
	assert_eq(GameState.battle_attempts, { "5": 2 })
	assert_true(AdventureRules.is_passable(target, _home))


func test_v2_save_loads_with_adventure_defaults() -> void:
	var old: Dictionary = GameState.to_dict()
	for key in ["luz", "hp", "open_bosques", "battle_attempts"]:
		old.erase(key)
	old.save_version = 2
	GameState.luz = 0
	GameState.from_dict(old)
	assert_eq(GameState.luz, AdventureRules.start_luz())
	assert_eq(GameState.hp, AdventureRules.max_hp())
	assert_eq(GameState.open_bosques, [] as Array[int])


func _nujio_chunk_of(with_villa: bool) -> ChunkData:
	for id in _map.count():
		if _map.has_villa[id] == with_villa:
			return ChunkGenerator.generate(42, _map.nujio_chunk[id], _region, _map)
	return null


func test_rest_in_villa_plaza_or_next_to_its_nujio() -> void:
	var villa: ChunkData = _nujio_chunk_of(true)
	assert_not_null(villa, "seed 42 tiene al menos una villa")
	assert_true(villa.has_villa)
	var rect: Rect2i = villa.nujio_rect
	assert_true(AdventureRules.is_villa_rest(villa, rect.position + Vector2i(-1, 0)), "junto al Nujio")
	assert_true(AdventureRules.is_villa_rest(villa, rect.end), "también en diagonal")
	assert_false(AdventureRules.is_villa_rest(villa, rect.position), "dentro del Nujio no")
	var plaza: Vector2i = Vector2i(-1, -1)
	for y in ChunkData.SIZE:
		for x in ChunkData.SIZE:
			var c := Vector2i(x, y)
			if villa.get_tile(c) == ChunkData.Tile.PLAZA and not rect.grow(1).has_point(c):
				plaza = c
	assert_ne(plaza, Vector2i(-1, -1))
	assert_true(AdventureRules.is_villa_rest(villa, plaza), "en la plaza, lejos del Nujio")
	assert_false(AdventureRules.is_villa_rest(villa, Vector2i(0, 0)), "fuera de la plaza")


func test_no_rest_next_to_nujio_without_villa() -> void:
	var wild: ChunkData = _nujio_chunk_of(false)
	assert_false(wild.has_villa)
	assert_true(AdventureRules.is_next_to_nujio(wild, wild.nujio_rect.position + Vector2i(-1, 0)))
	assert_false(AdventureRules.is_villa_rest(wild, wild.nujio_rect.position + Vector2i(-1, 0)))


func test_rest_heals_fully_and_notifies() -> void:
	AdventureRules.set_hp(4)
	watch_signals(EventBus)
	AdventureRules.rest()
	assert_eq(GameState.hp, AdventureRules.max_hp())
	assert_signal_emitted(EventBus, "rested_in_villa")


func test_spawn_and_defeat_wake_up_in_home_villa_next_to_nujio() -> void:
	var expl: Node = load("res://scenes/world/exploration.tscn").instantiate()
	add_child_autofree(expl)
	expl.start()
	var villa_chunk: Vector2i = _map.nujio_chunk[_home]
	var chunk: ChunkData = ChunkGenerator.generate(42, villa_chunk, _region, _map)
	assert_true(chunk.has_villa, "el Bosque inicial tiene villa")
	assert_eq(GameState.chunk_coord, villa_chunk)
	assert_true(AdventureRules.is_next_to_nujio(chunk, GameState.player_cell), "aparece junto al Nujio")
	# Tras una derrota en otro chunk, despierta en el mismo sitio.
	var other: Vector2i = _map.chunks_of(_home).filter(func(c: Vector2i) -> bool: return c != villa_chunk)[0]
	GameState.chunk_coord = other
	expl.start()
	assert_eq(GameState.chunk_coord, other, "una partida cargada conserva su chunk")
	EventBus.crossing_resolved.emit(_map.neighbours_of(_home)[0], &"defeated")
	assert_eq(GameState.chunk_coord, villa_chunk)
	assert_true(AdventureRules.is_next_to_nujio(chunk, GameState.player_cell))
