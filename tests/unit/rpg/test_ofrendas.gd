extends GutTest
## Ofrendas v1 (ofrendas-v1.md): peaje con una ofrenda entera (con Luz suelta si no llega, sin
## cambio), ofrenda en combate contra un Botarramas (abre el paso, sin XP), bloqueo contra el
## Ofomni descarriado y hallazgos deterministas en refugios, una sola vez.

const Battle = preload("res://scripts/rpg/battle.gd")
const Crossing = preload("res://scripts/rpg/crossing.gd")
const Screen = preload("res://scripts/rpg/inventory_screen.gd")


func before_each() -> void:
	GameState.new_game(42)


func _give(ids: Array) -> void:
	for id: String in ids:
		GameState.inventory.append(Ofrendas.make_item(StringName(id)))


func test_catalog_values() -> void:
	assert_eq(Ofrendas.make_item(&"cuenta_de_barro"), { "id": "cuenta_de_barro", "luz": 3 })
	assert_eq(Ofrendas.make_item(&"figura_sarua").luz, 8)
	assert_eq(Ofrendas.display_name(&"trenza_votiva"), "Trenza votiva")
	assert_eq(Ofrendas.ids_from("refuge"), [&"cuenta_de_barro", &"trenza_votiva"] as Array[StringName])


func test_can_pay_with_loose_luz_but_not_combining() -> void:
	assert_false(Ofrendas.can_pay(3, 0, 4), "3 sin Luz no llega a 4")
	assert_true(Ofrendas.can_pay(3, 1, 4), "3 + 1 de Luz suelta")
	assert_true(Ofrendas.can_pay(8, 0, 4))
	assert_eq(Ofrendas.luz_needed(3, 4), 1)
	assert_eq(Ofrendas.luz_needed(8, 4), 0, "sin cambio: no devuelve nada")
	_give(["cuenta_de_barro", "cuenta_de_barro"])
	assert_eq(Ofrendas.payable(GameState.inventory, 0, 6), [] as Array[int], "dos ofrendas no se combinan")


func test_payable_lists_one_per_id_from_smallest() -> void:
	_give(["figura_sarua", "cuenta_de_barro", "trenza_votiva", "cuenta_de_barro"])
	assert_eq(Ofrendas.payable(GameState.inventory, 0, 4), [2, 0] as Array[int], "trenza (4) y figura (8)")
	assert_eq(Ofrendas.payable(GameState.inventory, 1, 4), [1, 2, 0] as Array[int], "con 1 de Luz, también la cuenta")
	assert_eq(Ofrendas.payable([], 10, 4), [] as Array[int])


func test_toll_with_ofrenda_loses_it_whole_without_change() -> void:
	_give(["cuenta_de_barro", "figura_sarua"])
	GameState.luz = 2
	assert_true(AdventureRules.pay_toll_with_ofrenda(5, 4, 1))
	assert_eq(GameState.inventory, [{ "id": "cuenta_de_barro", "luz": 3 }], "la figura se deja entera")
	assert_eq(GameState.luz, 2, "el excedente (4) se pierde: no hay cambio")
	assert_true(GameState.open_bosques.has(5), "abre el paso")


func test_toll_with_ofrenda_completed_with_luz() -> void:
	_give(["cuenta_de_barro"])
	GameState.luz = 0
	assert_false(AdventureRules.pay_toll_with_ofrenda(5, 4, 0), "3 sin Luz no basta")
	assert_eq(GameState.inventory.size(), 1)
	assert_false(GameState.open_bosques.has(5))
	GameState.luz = 1
	assert_true(AdventureRules.pay_toll_with_ofrenda(5, 4, 0))
	assert_eq(GameState.luz, 0, "3 + 1 de Luz suelta")
	assert_eq(GameState.inventory, [])
	assert_false(AdventureRules.pay_toll_with_ofrenda(6, 4, 0), "índice fuera del inventario")


func test_crossing_option_text() -> void:
	assert_eq(Crossing.ofrenda_option(Ofrendas.make_item(&"figura_sarua"), 4), "Ofrecer Figura sarua (8) por un paso de 4")
	assert_eq(Crossing.ofrenda_option(Ofrendas.make_item(&"cuenta_de_barro"), 4), "Ofrecer Cuenta de barro (3) por un paso de 4 (+1 Luz)")


func test_battle_ofrenda_appeases_botarramas_and_opens_path() -> void:
	_give(["trenza_votiva", "cuenco_ritual"])
	GameState.luz = 5
	watch_signals(EventBus)
	var logic: BattleLogic = AdventureRules.start_battle(3, 2)
	assert_eq(logic.toll, 5, "peaje de d = 2")
	assert_true(logic.can_offer_ofrenda())
	assert_eq(logic.payable_ofrendas(), [0, 1] as Array[int], "trenza (4 + 1 Luz) y cuenco (6)")
	assert_eq(logic.play_turn(BattleLogic.Action.OFRENDA), [] as Array[Dictionary], "la ofrenda no va por play_turn")
	var events: Array[Dictionary] = logic.offer_ofrenda(0)
	assert_eq(events.map(func(e: Dictionary) -> StringName: return e.kind), [&"ofrenda", &"unico_leaves"])
	assert_eq(logic.result, BattleLogic.Result.APPEASED)
	assert_eq(logic.luz, 4, "completa la trenza con 1 de Luz")
	var msgs: Array[Dictionary] = Battle.messages_for(events, logic.balance)
	assert_eq(msgs[0].text, "Dejas Trenza votiva en el Bosque.")
	assert_eq(msgs[1].text, "El Único se aparta. El paso queda abierto.")
	assert_eq(AdventureRules.finish_battle(logic, 3), &"appeased")
	assert_true(GameState.open_bosques.has(3), "el paso queda abierto")
	assert_eq(GameState.inventory, [{ "id": "cuenco_ritual", "luz": 6 }])
	assert_eq(GameState.luz, 4)
	assert_eq(GameState.xp, 0, "no da XP")
	assert_signal_emitted_with_parameters(EventBus, "battle_ended", [3, &"appeased"])


func test_battle_ofrenda_needs_enough_value() -> void:
	_give(["cuenta_de_barro"])
	GameState.luz = 0
	var logic: BattleLogic = AdventureRules.start_battle(3, 2)
	assert_false(logic.can_offer_ofrenda(), "3 sin Luz no llega a 5")
	assert_eq(logic.offer_ofrenda(0), [] as Array[Dictionary])
	assert_eq(logic.result, BattleLogic.Result.ONGOING)


func test_battle_ofrenda_blocked_against_ofomni() -> void:
	_give(["figura_sarua"])
	var q: Dictionary = QuestLogic.new_quest()
	q.state = String(QuestLogic.ACTIVE)
	q.ofomni_d = 3
	GameState.quests[&"primera_mision"] = q
	var logic: BattleLogic = AdventureRules.start_quest_battle(&"primera_mision", 3)
	assert_false(logic.accepts_payment)
	assert_false(logic.can_offer_ofrenda())
	assert_eq(logic.payable_ofrendas(), [] as Array[int])
	assert_eq(logic.offer_ofrenda(0), [] as Array[Dictionary])
	assert_eq(Battle.blocked_text(logic, BattleLogic.Action.OFRENDA), "El Ofomni descarriado no acepta ofrendas.")


func test_battle_submenu_option_text() -> void:
	assert_eq(Battle.ofrenda_option(Ofrendas.make_item(&"trenza_votiva"), 1, 5), "Trenza votiva (4) + 1 Luz")
	assert_eq(Battle.ofrenda_option(Ofrendas.make_item(&"cuenco_ritual"), 2, 5), "Cuenco ritual (6) x2")


func test_refuge_loot_is_deterministic_and_about_one_in_three() -> void:
	var with_loot: int = 0
	var total: int = 0
	for y: int in 16:
		for x: int in 12:
			var c := Vector2i(x, y)
			var id: StringName = AdventureRules.refuge_ofrenda(42, c)
			assert_eq(AdventureRules.refuge_ofrenda(42, c), id, "misma seed y chunk, mismo hallazgo")
			assert_true(id == &"" or Ofrendas.ids_from("refuge").has(id), "solo ofrendas pequeñas")
			total += 1
			if id != &"":
				with_loot += 1
	assert_between(with_loot, total / 5, total / 2, "alrededor de 1 de cada 3")


func test_refuge_loot_only_once_per_game() -> void:
	var coord := _refuge_with_loot(42)
	var item: Dictionary = AdventureRules.loot_refuge(coord)
	assert_false(item.is_empty())
	assert_true([3, 4].has(int(item.luz)), "valor 3–4")
	assert_eq(GameState.inventory, [item])
	assert_true(AdventureRules.is_refuge_looted(coord))
	assert_eq(AdventureRules.loot_refuge(coord), {}, "segunda vez: no queda nada")
	assert_eq(GameState.inventory.size(), 1)
	var empty := _refuge_without_loot(42)
	assert_eq(AdventureRules.loot_refuge(empty), {})
	assert_false(AdventureRules.is_refuge_looted(empty))
	GameState.new_game(42)
	assert_false(AdventureRules.is_refuge_looted(coord), "partida nueva: se puede volver a recoger")


func test_inventory_lines() -> void:
	assert_eq(Screen.ofrenda_lines([]), ["Ninguna"] as Array[String])
	_give(["cuenco_ritual", "cuenta_de_barro", "cuenta_de_barro"])
	assert_eq(Screen.ofrenda_lines(GameState.inventory), ["Cuenta de barro (3) x2", "Cuenco ritual (6)"] as Array[String])


func _refuge_with_loot(seed_value: int) -> Vector2i:
	for i: int in 400:
		var c := Vector2i(i % 20, i / 20)
		if AdventureRules.refuge_ofrenda(seed_value, c) != &"":
			return c
	fail_test("ningún chunk con hallazgo")
	return Vector2i.ZERO


func _refuge_without_loot(seed_value: int) -> Vector2i:
	for i: int in 400:
		var c := Vector2i(i % 20, i / 20)
		if AdventureRules.refuge_ofrenda(seed_value, c) == &"":
			return c
	fail_test("todos los chunks con hallazgo")
	return Vector2i.ZERO
