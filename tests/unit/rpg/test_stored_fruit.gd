extends GutTest
## Frutos guardados en la bolsa (dueño: "puedes elegir solo coger el fruto y almacenarlo en el
## inventario para consumirlo dentro del bosque luego. no puedes sacar un fruto de su bosque sino
## dañas su relación"): guardar o comer, apilado por origen, límite y robo, comerlo solo en su
## Bosque, penalización al sacarlo (una vez por salida) y guardado.

const Screen = preload("res://scripts/rpg/inventory_screen.gd")
const SAVE_SLOT: int = 92
const HOME: int = 0
const PAID: int = 1
const UNPAID: int = 2
const COORD := Vector2i(6, 13)


func before_each() -> void:
	GameState.new_game(42)
	GameState.open_bosques = [PAID]


func after_all() -> void:
	DirAccess.remove_absolute(SaveManager.slot_path(SAVE_SLOT))
	GameState.new_game(42)


func _fruit_index(origin: int) -> int:
	for i: int in GameState.bag.size():
		if InventoryLogic.id_at(GameState.bag, i) == Items.FRUIT_ID and InventoryLogic.origin_at(GameState.bag, i) == origin:
			return i
	return -1


func _fill_bag() -> void:
	while not InventoryLogic.is_full(GameState.bag):
		InventoryLogic.add(GameState.bag, &"cuenta_de_barro")


func test_store_instead_of_eating() -> void:
	GameState.hp = 10
	var r: Dictionary = FruitRules.take(COORD, Vector2i(5, 5), HOME, HOME, true)
	assert_true(r.stored)
	assert_eq(r.healed, 0, "guardado no cura")
	assert_eq(GameState.hp, 10)
	assert_false(FruitRules.has_fruit(COORD, Vector2i(5, 5)), "el árbol queda vacío igual")
	var i: int = _fruit_index(HOME)
	assert_eq(GameState.bag[i], { "id": "fruto", "qty": 1, "origin": HOME, "out": false })
	var eaten: Dictionary = FruitRules.take(COORD, Vector2i(6, 6), HOME, HOME)
	assert_false(eaten.stored)
	assert_gt(eaten.healed, 0)


func test_stored_fruit_counts_for_limit_and_theft() -> void:
	watch_signals(EventBus)
	assert_false(FruitRules.take(COORD, Vector2i(5, 5), HOME, HOME, true).theft)
	assert_eq(FruitRules.taken_in(HOME), 1, "cuenta para el límite del Momento")
	assert_true(FruitRules.take(COORD, Vector2i(6, 6), HOME, HOME, true).theft, "el segundo es robo aunque se guarde")
	assert_signal_emitted_with_parameters(EventBus, "bosque_robbed", [HOME])
	assert_true(FruitRules.take(COORD, Vector2i(7, 7), UNPAID, HOME, true).theft, "sin permiso: robo")


func test_fruits_stack_by_origin() -> void:
	for n: int in 6:
		FruitRules.take(COORD, Vector2i(n, 1), HOME, HOME, true)
	FruitRules.take(COORD, Vector2i(9, 1), PAID, HOME, true)
	assert_eq(int(Items.entry(Items.FRUIT_ID).stack_max), 5)
	assert_eq(InventoryLogic.count(GameState.bag, Items.FRUIT_ID), 7)
	assert_eq(InventoryLogic.qty_at(GameState.bag, _fruit_index(HOME)), 5, "un montón de 5 y otro de 1")
	assert_eq(InventoryLogic.qty_at(GameState.bag, _fruit_index(PAID)), 1, "otro origen, otra casilla")
	assert_eq(InventoryLogic.free_slots(GameState.bag), 7)


func test_full_bag_can_only_eat() -> void:
	_fill_bag()
	assert_false(FruitRules.can_store(HOME))
	assert_eq(FruitRules.take(COORD, Vector2i(5, 5), HOME, HOME, true), {}, "no se guarda")
	assert_true(FruitRules.has_fruit(COORD, Vector2i(5, 5)), "y el árbol lo conserva")
	assert_eq(FruitRules.taken_in(HOME), 0)
	assert_false(FruitRules.take(COORD, Vector2i(5, 5), HOME, HOME).is_empty(), "comer sí")


func test_eat_only_in_origin_bosque() -> void:
	FruitRules.take(COORD, Vector2i(5, 5), PAID, HOME, true)
	var i: int = _fruit_index(PAID)
	GameState.hp = 10
	assert_false(FruitRules.can_eat(i, HOME))
	assert_eq(FruitRules.eat_from_bag(i, HOME), -1, "fuera de su Bosque, no")
	assert_eq(Screen.describe_at(i, HOME), "Este fruto solo se puede comer en su Bosque.")
	assert_eq(Screen.activate(i, HOME), "Este fruto solo se puede comer en su Bosque.")
	assert_eq(InventoryLogic.count(GameState.bag, Items.FRUIT_ID), 1)
	assert_eq(GameState.hp, 10)
	var heal: int = FruitRules.heal_amount(AdventureRules.max_hp())
	assert_eq(Screen.activate(i, PAID), "Comes el fruto. +%d PV" % heal, "en su Bosque, sí")
	assert_eq(GameState.hp, 10 + heal)
	assert_eq(InventoryLogic.count(GameState.bag, Items.FRUIT_ID), 0)


func test_taking_fruit_out_hurts_relation_once_per_exit() -> void:
	FruitRules.take(COORD, Vector2i(5, 5), PAID, HOME, true)
	FruitRules.take(COORD, Vector2i(6, 6), PAID, HOME, true)
	var per: int = int(AdventureRules.balance().bosque_memory.relation_per_fruit_taken_out)
	assert_eq(per, -5)
	var before: int = AdventureRules.relation(PAID)
	assert_eq(FruitRules.bosque_entered(PAID), 0, "dentro de su Bosque, nada")
	assert_eq(FruitRules.bosque_entered(HOME), 2, "sale con 2 frutos")
	assert_eq(AdventureRules.relation(PAID), before + 2 * per)
	assert_eq(FruitRules.bosque_entered(UNPAID), 0, "ya sacados: no penaliza otra vez")
	assert_eq(AdventureRules.relation(PAID), before + 2 * per)
	assert_eq(InventoryLogic.count(GameState.bag, Items.FRUIT_ID), 2, "los frutos no desaparecen")
	assert_eq(FruitRules.bosque_entered(-1), 0, "fuera de la región no cuenta")
	FruitRules.bosque_entered(PAID)
	assert_eq(FruitRules.bosque_entered(HOME), 2, "volver y salir otra vez es otra salida")
	assert_eq(AdventureRules.relation(PAID), before + 4 * per)


func test_save_keeps_origin_and_mark() -> void:
	FruitRules.take(COORD, Vector2i(5, 5), PAID, HOME, true)
	FruitRules.bosque_entered(HOME)
	var bag: Array = GameState.bag.duplicate(true)
	assert_eq(SaveManager.save_game(SAVE_SLOT), OK)
	GameState.new_game(7)
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	assert_eq(GameState.bag, bag)
	assert_true(bool(GameState.bag[_fruit_index(PAID)].out), "sigue marcado como sacado")
	assert_eq(FruitRules.bosque_entered(UNPAID), 0, "no penaliza otra vez tras cargar")
