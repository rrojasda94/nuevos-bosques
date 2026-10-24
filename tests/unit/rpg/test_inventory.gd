extends GutTest
## Bolsa de 12 casillas y equipo en 3 ranuras (roadmap-0.3.md #113, sigilo-y-robo.md): añadir y
## apilar, bolsa llena, quitar, equipar y desequipar según el tipo, el ATQ del arma en el combate,
## ofrendas desde la bolsa, hallazgo y recompensa con la bolsa llena, pantalla (I), guardado v11 y
## migración desde la lista de ofrendas.

const Screen = preload("res://scripts/rpg/inventory_screen.gd")
const SAVE_SLOT: int = 93
const LANZA: StringName = &"lanza_de_adoc"
const MASK: StringName = &"mascara_de_corteza"
const TALISMAN: StringName = &"talisman_de_semillas"


func before_each() -> void:
	GameState.new_game(42)


func after_all() -> void:
	DirAccess.remove_absolute(SaveManager.slot_path(SAVE_SLOT))
	GameState.new_game(42)


## Llena las casillas libres de la bolsa con cuentas de barro.
func _fill_bag() -> void:
	while not InventoryLogic.is_full(GameState.bag):
		InventoryLogic.add(GameState.bag, &"cuenta_de_barro")


func test_catalog_has_every_kind() -> void:
	assert_eq(Items.kind_of(&"cuenco_ritual"), Items.KIND_OFRENDA)
	assert_eq(Items.luz_of(&"figura_sarua"), 8, "las ofrendas conservan sus ids y valores")
	assert_eq(Items.kind_of(LANZA), Items.KIND_WEAPON)
	assert_eq(Items.atk_bonus(LANZA), 2)
	assert_eq(Items.kind_of(MASK), Items.KIND_MASK)
	assert_eq(Items.kind_of(TALISMAN), Items.KIND_TALISMAN)
	assert_eq(int(Items.entry(MASK).camouflage), 0, "efecto como dato, aún sin usar")
	assert_eq(Items.bag_size(), 12)
	for e: Dictionary in Items.all():
		assert_true(e.has("name") and e.has("description") and e.has("stack_max"), str(e.id))


func test_new_game_bag_and_equipment() -> void:
	assert_eq(GameState.bag.size(), 12)
	assert_eq(InventoryLogic.equipped_in(GameState.equipped, &"main_hand"), LANZA, "la lanza empieza equipada")
	assert_eq(InventoryLogic.equipped_in(GameState.equipped, &"mask"), &"")
	assert_eq(InventoryLogic.count(GameState.bag, MASK), 1, "máscara provisional para probar")
	assert_eq(InventoryLogic.count(GameState.bag, TALISMAN), 1)
	assert_eq(InventoryLogic.free_slots(GameState.bag), 10)
	assert_true(AdventureRules.is_armed())


func test_add_stacks_up_to_stack_max() -> void:
	var bag: Array = InventoryLogic.new_bag(3)
	assert_true(InventoryLogic.add_stacked(bag, &"x", 4, 3))
	assert_eq(bag, [{ "id": "x", "qty": 3 }, { "id": "x", "qty": 1 }, {}])
	assert_true(InventoryLogic.add_stacked(bag, &"x", 2, 3), "completa el montón empezado")
	assert_eq(bag, [{ "id": "x", "qty": 3 }, { "id": "x", "qty": 3 }, {}])
	assert_true(InventoryLogic.add_stacked(bag, &"y", 1, 3))
	assert_false(InventoryLogic.add_stacked(bag, &"x", 1, 3), "no queda sitio para x")
	assert_eq(InventoryLogic.count(bag, &"x"), 6)


func test_ofrendas_take_one_slot_each() -> void:
	assert_true(InventoryLogic.add(GameState.bag, &"cuenta_de_barro", 2))
	assert_eq(InventoryLogic.free_slots(GameState.bag), 8, "stack_max 1: una casilla por ofrenda")
	assert_false(InventoryLogic.add(GameState.bag, &"no_existe"), "id fuera del catálogo")


func test_full_bag_rejects_and_changes_nothing() -> void:
	_fill_bag()
	var before: Array = GameState.bag.duplicate(true)
	assert_true(InventoryLogic.is_full(GameState.bag))
	assert_false(InventoryLogic.can_add(GameState.bag, &"figura_sarua"))
	assert_false(InventoryLogic.add(GameState.bag, &"figura_sarua"))
	assert_eq(GameState.bag, before)
	var bag: Array = InventoryLogic.new_bag(2)
	assert_false(InventoryLogic.add_stacked(bag, &"x", 3, 1), "todo o nada")
	assert_eq(bag, [{}, {}])


func test_remove() -> void:
	var bag: Array = InventoryLogic.new_bag(3)
	InventoryLogic.add_stacked(bag, &"x", 5, 3)
	assert_false(InventoryLogic.remove(bag, &"x", 6), "no hay tantas")
	assert_eq(InventoryLogic.count(bag, &"x"), 5)
	assert_true(InventoryLogic.remove(bag, &"x", 3), "empieza por la última casilla")
	assert_eq(bag, [{ "id": "x", "qty": 2 }, {}, {}])
	assert_true(InventoryLogic.remove_at(bag, 0, 2))
	assert_eq(bag, [{}, {}, {}])
	assert_false(InventoryLogic.remove_at(bag, 0))


func test_equip_by_kind() -> void:
	var mask_at: int = _index_of(MASK)
	assert_true(AdventureRules.equip_from_bag(mask_at))
	assert_eq(InventoryLogic.equipped_in(GameState.equipped, &"mask"), MASK, "la máscara va a su ranura")
	assert_eq(InventoryLogic.count(GameState.bag, MASK), 0)
	assert_true(AdventureRules.equip_from_bag(_index_of(TALISMAN)))
	assert_eq(InventoryLogic.equipped_in(GameState.equipped, &"talisman"), TALISMAN)
	InventoryLogic.add(GameState.bag, &"cuenco_ritual")
	assert_false(AdventureRules.equip_from_bag(_index_of(&"cuenco_ritual")), "las ofrendas no se equipan")
	assert_false(AdventureRules.equip_from_bag(11), "casilla vacía")


func test_unequip_and_reequip_weapon() -> void:
	watch_signals(EventBus)
	assert_true(AdventureRules.unequip_slot(&"main_hand"))
	assert_false(AdventureRules.is_armed(), "desequipada: el Adoc va desarmado")
	assert_eq(InventoryLogic.count(GameState.bag, LANZA), 1, "vuelve a la bolsa")
	assert_signal_emitted_with_parameters(EventBus, "item_unequipped", [&"main_hand", LANZA])
	assert_false(AdventureRules.unequip_slot(&"main_hand"), "ranura vacía")
	assert_true(AdventureRules.equip_from_bag(_index_of(LANZA)))
	assert_true(AdventureRules.is_armed())
	assert_signal_emitted_with_parameters(EventBus, "item_equipped", [&"main_hand", LANZA])


func test_equip_swaps_with_previous() -> void:
	InventoryLogic.add(GameState.bag, LANZA)
	_fill_bag()
	var at: int = _index_of(LANZA)
	assert_true(AdventureRules.equip_from_bag(at), "con la bolsa llena se cambia en la misma casilla")
	assert_eq(InventoryLogic.id_at(GameState.bag, at), LANZA, "la lanza anterior ocupa su sitio")
	assert_eq(InventoryLogic.equipped_in(GameState.equipped, &"main_hand"), LANZA)


func test_unequip_needs_room() -> void:
	_fill_bag()
	assert_false(AdventureRules.unequip_slot(&"main_hand"), "bolsa llena")
	assert_true(AdventureRules.is_armed())


func test_weapon_bonus_affects_combat() -> void:
	var base: int = int(AdventureRules.adoc_stats(GameState.level).atk)
	assert_eq(AdventureRules.start_battle(3, 2).adoc_atk, base + 2, "con la lanza")
	assert_eq(AdventureRules.adoc_stats(GameState.level).atk, base, "la tabla de niveles no cambia")
	AdventureRules.unequip_slot(&"main_hand")
	assert_eq(AdventureRules.start_battle(3, 2).adoc_atk, base, "desequipada no suma")
	GameState.quests[QuestLogic.PRIMERA_MISION] = QuestLogic.new_quest()
	assert_eq(AdventureRules.start_quest_battle(QuestLogic.PRIMERA_MISION, 3).adoc_atk, base)


func test_ofrendas_come_from_bag_in_toll_and_battle() -> void:
	InventoryLogic.add(GameState.bag, &"trenza_votiva")
	InventoryLogic.add(GameState.bag, &"figura_sarua")
	assert_eq(AdventureRules.bag_ofrendas(), [Ofrendas.make_item(&"trenza_votiva"), Ofrendas.make_item(&"figura_sarua")],
		"la máscara y el talismán no son ofrendas")
	GameState.luz = 0
	assert_true(AdventureRules.pay_toll_with_ofrenda(5, 4, 0))
	assert_eq(InventoryLogic.count(GameState.bag, &"trenza_votiva"), 0, "sale de la bolsa")
	var logic: BattleLogic = AdventureRules.start_battle(3, 2)
	assert_eq(logic.ofrendas, [Ofrendas.make_item(&"figura_sarua")])
	logic.offer_ofrenda(0)
	AdventureRules.finish_battle(logic, 3)
	assert_eq(InventoryLogic.count(GameState.bag, &"figura_sarua"), 0)
	assert_eq(InventoryLogic.count(GameState.bag, MASK), 1, "lo demás sigue en la bolsa")


func test_refuge_with_full_bag_is_not_taken() -> void:
	var coord: Vector2i = _refuge_with_loot()
	_fill_bag()
	var item: Dictionary = AdventureRules.loot_refuge(coord)
	assert_false(item.is_empty())
	assert_false(bool(item.taken), "bolsa llena: no se toma")
	assert_false(AdventureRules.is_refuge_looted(coord), "el refugio la sigue guardando")
	InventoryLogic.remove_at(GameState.bag, 11)
	item = AdventureRules.loot_refuge(coord)
	assert_true(bool(item.taken), "con sitio, sí")
	assert_true(AdventureRules.is_refuge_looted(coord))
	assert_eq(InventoryLogic.id_at(GameState.bag, 11), StringName(str(item.id)))


func test_quest_reward_waits_for_room() -> void:
	var reward: Dictionary = QuestLogic.data(QuestLogic.PRIMERA_MISION).reward
	assert_true(AdventureRules.can_take_reward(reward))
	_fill_bag()
	assert_false(AdventureRules.can_take_reward(reward), "bolsa llena: el sfida espera")
	InventoryLogic.remove_at(GameState.bag, 11)
	AdventureRules.apply_quest_reward(reward)
	assert_eq(InventoryLogic.id_at(GameState.bag, 11), &"cuenco_ritual")


func test_screen_cursor_moves_between_bag_and_equipment() -> void:
	assert_eq(Screen.move_cursor(0, Vector2i.LEFT), 0, "sin dar la vuelta")
	assert_eq(Screen.move_cursor(0, Vector2i.RIGHT), 1)
	assert_eq(Screen.move_cursor(3, Vector2i.RIGHT), 3)
	assert_eq(Screen.move_cursor(1, Vector2i.DOWN), 5)
	assert_eq(Screen.move_cursor(9, Vector2i.DOWN), 13, "de la última fila a su ranura")
	assert_eq(Screen.move_cursor(11, Vector2i.DOWN), 14, "las columnas de la derecha bajan a la última ranura")
	assert_eq(Screen.move_cursor(12, Vector2i.UP), 8)
	assert_eq(Screen.move_cursor(14, Vector2i.RIGHT), 14)
	assert_eq(Screen.move_cursor(13, Vector2i.DOWN), 13)
	assert_eq(Screen.slot_of(12), &"main_hand")
	assert_eq(Screen.slot_of(3), &"")


func test_screen_accept_equips_and_unequips() -> void:
	assert_eq(Screen.activate(12), "Guardas: Lanza de adoc.")
	assert_false(AdventureRules.is_armed())
	assert_eq(Screen.activate(12), "", "ranura vacía: nada")
	assert_eq(Screen.activate(_index_of(LANZA)), "Te equipas: Lanza de adoc.")
	InventoryLogic.add(GameState.bag, &"cuenco_ritual")
	var at: int = _index_of(&"cuenco_ritual")
	assert_eq(Screen.activate(at), "Las ofrendas se dejan ante un Nujio.", "usar una ofrenda no hace nada")
	assert_eq(InventoryLogic.id_at(GameState.bag, at), &"cuenco_ritual")
	_fill_bag()
	assert_eq(Screen.activate(12), "Tu bolsa está llena.")


func test_screen_texts() -> void:
	assert_eq(Screen.equipment_lines(GameState.equipped), ["Mano: Lanza de adoc", "Máscara: —", "Talismán: —"] as Array[String])
	assert_eq(Screen.describe(&"figura_sarua"), "Luz 8. Figura tallada en piedra. Guarda mucha Luz.")
	assert_true(Screen.describe(LANZA).begins_with("ATQ +2. "))
	assert_eq(Screen.id_under(12, GameState.bag, GameState.equipped), LANZA)


func test_save_v11_round_trip() -> void:
	InventoryLogic.add(GameState.bag, &"cuenco_ritual")
	AdventureRules.equip_from_bag(_index_of(MASK))
	AdventureRules.unequip_slot(&"main_hand")
	var bag: Array = GameState.bag.duplicate(true)
	var equipped: Dictionary = GameState.equipped.duplicate()
	assert_eq(SaveManager.save_game(SAVE_SLOT), OK)
	GameState.new_game(7)
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	assert_eq(GameState.bag, bag)
	assert_eq(GameState.equipped, equipped)
	assert_false(AdventureRules.is_armed(), "la lanza sigue guardada")
	assert_eq(int(GameState.to_dict().save_version), 11)


func test_load_sanitizes_bag_and_equipment() -> void:
	var data: Dictionary = GameState.to_dict()
	data.bag = [{ "id": "no_existe", "qty": 1 }, { "id": "cuenco_ritual", "qty": 9 }, null]
	data.equipped = { "main_hand": "mascara_de_corteza", "mask": "mascara_de_corteza", "talisman": "nada" }
	GameState.from_dict(data)
	assert_eq(GameState.bag.size(), 12, "siempre 12 casillas")
	assert_eq(GameState.bag[0], {}, "id desconocido fuera")
	assert_eq(GameState.bag[1], { "id": "cuenco_ritual", "qty": 1 }, "cantidad hasta stack_max")
	assert_eq(GameState.equipped, { "main_hand": "", "mask": "mascara_de_corteza", "talisman": "" }, "cada ranura con su tipo")


func test_migration_from_v10_and_v9_ofrenda_list() -> void:
	for version: int in [9, 10]:
		var old: Dictionary = GameState.to_dict()
		old.save_version = version
		old.erase("bag")
		old.erase("equipped")
		old.inventory = [{ "id": "cuenco_ritual", "luz": 6 }, { "id": "cuenta_de_barro", "luz": 3 }, { "id": "cuenta_de_barro", "luz": 3 }]
		var file := FileAccess.open(SaveManager.slot_path(SAVE_SLOT), FileAccess.WRITE)
		file.store_string(JSON.stringify(old))
		file.close()
		GameState.new_game(7)
		assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
		assert_eq(AdventureRules.bag_ofrendas(), [Ofrendas.make_item(&"cuenco_ritual"), Ofrendas.make_item(&"cuenta_de_barro"),
			Ofrendas.make_item(&"cuenta_de_barro")], "v%d: las ofrendas pasan a la bolsa" % version)
		assert_eq(InventoryLogic.free_slots(GameState.bag), 9, "sin la máscara ni el talismán de partida nueva")
		assert_eq(InventoryLogic.equipped_in(GameState.equipped, &"main_hand"), LANZA, "la lanza va equipada")


func _index_of(id: StringName) -> int:
	for i: int in GameState.bag.size():
		if InventoryLogic.id_at(GameState.bag, i) == id:
			return i
	fail_test("%s no está en la bolsa" % id)
	return -1


func _refuge_with_loot() -> Vector2i:
	for i: int in 400:
		var c := Vector2i(i % 20, i / 20)
		if AdventureRules.refuge_ofrenda(GameState.seed_value, c) != &"":
			return c
	fail_test("ningún chunk con hallazgo")
	return Vector2i.ZERO
