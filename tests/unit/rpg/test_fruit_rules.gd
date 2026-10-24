extends GutTest
## Frutos del Bosque (FruitRules, bosques-y-relacion.md): curación del 25%, un fruto por Momento
## y por Bosque con permiso (natal o peaje pagado), robo desde el primero sin permiso, rebrote en
## el riutash, guardado y migración.

const SAVE_SLOT: int = 95
const HOME: int = 0
const PAID: int = 1
const UNPAID: int = 2
const COORD := Vector2i(6, 13)
const OTHER := Vector2i(7, 13)

const EXPLORATION_SCENE: PackedScene = preload("res://scenes/world/exploration.tscn")


func before_each() -> void:
	WorldClock.set_process(false)
	GameState.new_game(42)
	GameState.open_bosques = [PAID]


func after_each() -> void:
	WorldClock.set_process(true)


func after_all() -> void:
	DirAccess.remove_absolute(SaveManager.slot_path(SAVE_SLOT))


func test_heal_is_25_percent_of_max_hp() -> void:
	assert_eq(int(FruitRules.config().heal_pct), 25, "provisional, en balance.json")
	assert_eq(FruitRules.heal_amount(30), 8, "7,5 hacia arriba")
	assert_eq(FruitRules.heal_amount(40), 10)
	GameState.hp = 10
	var r: Dictionary = FruitRules.take(COORD, Vector2i(5, 5), HOME, HOME)
	assert_eq(r.healed, 8)
	assert_eq(GameState.hp, 18)
	GameState.fruit_taken.clear()
	GameState.hp = AdventureRules.max_hp() - 2
	assert_eq(FruitRules.take(COORD, Vector2i(9, 9), HOME, HOME).healed, 2, "sin pasar del máximo")
	assert_eq(GameState.hp, AdventureRules.max_hp())


func test_taken_tree_is_emptied() -> void:
	assert_true(FruitRules.has_fruit(COORD, Vector2i(5, 5)))
	FruitRules.take(COORD, Vector2i(5, 5), HOME, HOME)
	assert_false(FruitRules.has_fruit(COORD, Vector2i(5, 5)))
	assert_true(FruitRules.has_fruit(OTHER, Vector2i(5, 5)), "misma casilla de otro chunk")
	assert_eq(FruitRules.take(COORD, Vector2i(5, 5), HOME, HOME), {}, "un árbol vacío no da nada")


func test_one_fruit_per_momento_per_bosque_second_is_theft() -> void:
	watch_signals(EventBus)
	GameState.hp = 5
	assert_false(FruitRules.is_theft(HOME, HOME))
	var first: Dictionary = FruitRules.take(COORD, Vector2i(5, 5), HOME, HOME)
	assert_false(first.theft, "el primero lo da el Bosque")
	assert_signal_not_emitted(EventBus, "bosque_robbed")
	assert_true(FruitRules.is_theft(HOME, HOME))
	var second: Dictionary = FruitRules.take(OTHER, Vector2i(20, 20), HOME, HOME)
	assert_true(second.theft, "otro árbol del mismo Bosque en el mismo Momento: robo")
	assert_gt(second.healed, 0, "cura igual")
	assert_signal_emitted_with_parameters(EventBus, "bosque_robbed", [HOME])
	assert_eq(FruitRules.taken_in(HOME), 2)


func test_limit_is_per_bosque() -> void:
	FruitRules.take(COORD, Vector2i(5, 5), HOME, HOME)
	assert_false(FruitRules.is_theft(PAID, HOME), "otro Bosque pagado aún da su fruto")
	assert_false(FruitRules.take(OTHER, Vector2i(5, 5), PAID, HOME).theft)
	assert_true(FruitRules.is_theft(PAID, HOME))


func test_unpaid_bosque_is_theft_from_the_first() -> void:
	watch_signals(EventBus)
	assert_true(FruitRules.has_permission(HOME, HOME), "el natal da permiso")
	assert_true(FruitRules.has_permission(PAID, HOME), "con el peaje pagado")
	assert_false(FruitRules.has_permission(UNPAID, HOME))
	assert_true(FruitRules.is_theft(UNPAID, HOME))
	assert_true(FruitRules.take(COORD, Vector2i(5, 5), UNPAID, HOME).theft)
	assert_signal_emitted_with_parameters(EventBus, "bosque_robbed", [UNPAID])


func test_theft_raises_hostility_and_lowers_relation() -> void:
	var mem: Dictionary = AdventureRules.balance().bosque_memory
	assert_eq(int(mem.hostility_per_theft), 1)
	assert_eq(int(mem.relation_per_theft), -20)
	FruitRules.take(COORD, Vector2i(5, 5), PAID, HOME)
	assert_eq(AdventureRules.hostility(PAID), 0, "el fruto con permiso no es robo")
	assert_eq(AdventureRules.relation(PAID), 0)
	FruitRules.take(COORD, Vector2i(9, 9), PAID, HOME)
	assert_eq(AdventureRules.hostility(PAID), 1, "el segundo: hostilidad +1")
	assert_eq(AdventureRules.relation(PAID), -20, "y relación -20")
	FruitRules.take(OTHER, Vector2i(9, 9), UNPAID, HOME)
	assert_eq(AdventureRules.hostility(UNPAID), 1)
	assert_eq(AdventureRules.relation(UNPAID), -20)


func test_forced_bosque_gives_no_permission() -> void:
	AdventureRules.guardian_defeated(UNPAID)
	assert_true(AdventureRules.is_forced(UNPAID))
	assert_true(AdventureRules.is_passable(UNPAID, HOME), "se cruza")
	assert_false(FruitRules.has_permission(UNPAID, HOME), "pero no se ha pagado: no da fruto")
	assert_true(FruitRules.is_theft(UNPAID, HOME))
	AdventureRules.pay_toll(UNPAID, 0)
	assert_true(FruitRules.has_permission(UNPAID, HOME), "al pagar, sí")


func test_regrow_resets_trees_and_counters() -> void:
	FruitRules.take(COORD, Vector2i(5, 5), HOME, HOME)
	FruitRules.take(OTHER, Vector2i(5, 5), PAID, HOME)
	FruitRules.regrow()
	assert_true(FruitRules.has_fruit(COORD, Vector2i(5, 5)))
	assert_eq(GameState.fruit_taken, {})
	assert_false(FruitRules.is_theft(HOME, HOME))


func test_riutash_in_exploration_regrows_fruit() -> void:
	var exploration: Node2D = EXPLORATION_SCENE.instantiate()
	add_child_autofree(exploration)
	exploration.start()
	FruitRules.take(COORD, Vector2i(5, 5), HOME, HOME)
	WorldClock.advance(WorldClock.time_to_riutash() + 0.1)
	assert_true(FruitRules.has_fruit(COORD, Vector2i(5, 5)), "rebrota tras el riutash")
	assert_eq(GameState.fruit_taken, {})


func test_save_round_trip() -> void:
	FruitRules.take(COORD, Vector2i(5, 5), HOME, HOME)
	FruitRules.take(OTHER, Vector2i(1, 2), PAID, HOME)
	assert_eq(SaveManager.save_game(SAVE_SLOT), OK)
	GameState.new_game(1)
	assert_eq(GameState.fruit_taken, {})
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	assert_eq(GameState.emptied_fruit_trees, [Vector4i(6, 13, 5, 5), Vector4i(7, 13, 1, 2)] as Array[Vector4i])
	assert_eq(GameState.fruit_taken, { str(HOME): 1, str(PAID): 1 })
	assert_true(FruitRules.is_theft(HOME, HOME), "el Momento sigue contado tras cargar")
	assert_eq(int(GameState.to_dict().save_version), 10)


func test_migration_from_v8_has_all_fruit() -> void:
	FruitRules.take(COORD, Vector2i(5, 5), HOME, HOME)
	var v8: Dictionary = GameState.to_dict()
	v8.save_version = 8
	v8.erase("emptied_fruit_trees")
	v8.erase("fruit_taken")
	GameState.from_dict(v8)
	assert_eq(GameState.emptied_fruit_trees, [] as Array[Vector4i])
	assert_eq(GameState.fruit_taken, {})
	assert_true(FruitRules.has_fruit(COORD, Vector2i(5, 5)))
