extends GutTest
## P3 (ajustes-playtest-0.5.md, puntos 2, 3 y 4a; ADR 0017): colarse si nadie te ve
## (Stealth.detects, can_cross_unseen, border_outcome y el gancho de BosqueBorder), arma enfundada o
## en la mano (GameState.weapon_drawn, toggle_weapon, sicabi, combate y guardado v21) y permiso del
## fruto a la vista (FruitRules.permission_state, aviso de entrada y confirmación del robo).

const SAVE_SLOT: int = 93
const HOME: int = 0
const TARGET: int = 1
const OTHER: int = 2
const LANZA: StringName = &"lanza_de_adoc"
const CORTEZA: StringName = &"mascara_de_corteza"
const SEMILLAS: StringName = &"talisman_de_semillas"


const OldStartKit = preload("res://tests/unit/rpg/old_start_kit.gd")


func before_each() -> void:
	WorldClock.set_process(false)
	GameState.new_game(42)
	# Equipo de antes de P4 (sin nada equipado y la bolsa de prueba): OldStartKit.
	OldStartKit.apply()
	Stealth.running = false
	for id: int in [HOME, TARGET, OTHER]:
		GameState.bosque_state_overrides[str(id)] = BosqueStates.SANO


func after_each() -> void:
	Stealth.running = false
	WorldClock.set_process(true)


func after_all() -> void:
	DirAccess.remove_absolute(SaveManager.slot_path(SAVE_SLOT))
	GameState.new_game(42)


func _wear(ids: Array[StringName]) -> void:
	for id: StringName in ids:
		GameState.equipped[String(InventoryLogic.slot_for(id))] = String(id)


## Lanza equipada; `drawn`: en la mano.
func _spear(drawn: bool) -> void:
	GameState.equipped.main_hand = String(LANZA)
	GameState.weapon_drawn = drawn


func _watcher(cell: Vector2i, vision: int, guardian: bool) -> Dictionary:
	return { "cell": cell, "vision": vision, "guardian": guardian }


# --- Detección ---------------------------------------------------------------------------------------

func test_detects_up_close_always() -> void:
	assert_true(Stealth.detects(2, 0, 14), "a 2 casillas te ve aunque vayas muy oculto")
	assert_true(Stealth.detects(1, 10, 14))
	assert_false(Stealth.detects(3, 10, 14), "a 3, con visión 10 − 14, no")


func test_detects_within_vision_minus_camouflage() -> void:
	assert_eq(Stealth.effective_vision(10, 6), 4)
	assert_true(Stealth.detects(4, 10, 6), "corteza: te ve a 4")
	assert_false(Stealth.detects(5, 10, 6))
	assert_false(Stealth.detects(3, 10, 9), "corteza + semillas: solo a su lado")


func test_without_anything_to_hide_vision_doubles() -> void:
	assert_eq(Stealth.effective_vision(10, 0), 20)
	assert_true(Stealth.detects(20, 10, 0), "sin nada que oculte te ve a 20")
	assert_false(Stealth.detects(21, 10, 0))
	assert_eq(Stealth.effective_vision(14, 0), 28, "hostilidad 2")


func test_sheathed_weapon_subtracts_its_penalty_from_camouflage() -> void:
	_wear([CORTEZA])
	assert_eq(Items.sheathed_camo_penalty(LANZA), 2, "la lanza, 2 (items.json)")
	_spear(false)
	assert_eq(Stealth.camouflage(), 4, "corteza 6 − lanza enfundada 2")
	assert_true(Stealth.detects(6, 10, Stealth.camouflage()), "un Botarramas te ve a 6")
	_spear(true)
	assert_eq(Stealth.camouflage(), 0, "en la mano, nada")
	GameState.equipped.main_hand = ""
	assert_eq(Stealth.camouflage(), 6, "en la bolsa, sin efecto")


func test_running_breaks_camouflage() -> void:
	_wear([CORTEZA, SEMILLAS])
	assert_eq(Stealth.camouflage(), 9)
	assert_true(Stealth.set_running(true))
	assert_false(Stealth.set_running(true), "sin cambio")
	assert_eq(Stealth.camouflage(), 0, "corriendo, tu camuflaje no cuenta")
	assert_true(Stealth.detects(20, 10, Stealth.camouflage()), "y te ven al doble de su visión")
	assert_eq(StealthHud.mask_state(), StealthHud.Mask.EXPOSED, "máscara en rojo")
	Stealth.set_running(false)
	assert_eq(Stealth.camouflage(), 9)


func test_can_cross_unseen_with_several_watchers() -> void:
	var me := Vector2i(0, 0)
	var far_guard := _watcher(Vector2i(12, 0), 10, true)
	var near_patrol := _watcher(Vector2i(0, 4), 3, false)
	assert_true(Stealth.can_cross_unseen([], me, 0), "sin vigías, nadie te ve")
	assert_false(Stealth.can_cross_unseen([far_guard], me, 0), "sin máscara el Botarramas ve a 20")
	assert_true(Stealth.can_cross_unseen([far_guard], me, 9), "con 9 de camuflaje, a 12 no")
	assert_true(Stealth.can_cross_unseen([far_guard, near_patrol], me, 9))
	assert_false(Stealth.can_cross_unseen([far_guard, near_patrol, _watcher(Vector2i(2, 2), 0, false)], me, 14),
		"uno a tu lado te ve siempre")
	assert_eq(Stealth.first_detector([near_patrol, far_guard], me, 0), 1, "si te ven varios, gana el Botarramas")


func test_border_outcome_menu_seen_or_sneak() -> void:
	var me := Vector2i(0, 0)
	var guard := _watcher(Vector2i(5, 0), 10, true)
	var patrol := _watcher(Vector2i(0, 5), 10, false)
	assert_eq(Stealth.border_outcome([guard], me, 9, false, false).kind, Stealth.CROSS_SNEAK, "visión 1 a 5: te cuelas")
	assert_eq(Stealth.border_outcome([guard], me, 4, false, false).kind, Stealth.CROSS_MENU, "te ve el Botarramas: menú")
	var seen: Dictionary = Stealth.border_outcome([guard, patrol], me, 9, false, false)
	assert_eq(seen.kind, Stealth.CROSS_SNEAK)
	seen = Stealth.border_outcome([_watcher(Vector2i(30, 0), 10, true), patrol], me, 4, false, false)
	assert_eq(seen.kind, Stealth.CROSS_SEEN, "te ve otro Único: te persigue, sin menú")
	assert_eq(seen.index, 1)
	assert_eq(Stealth.border_outcome([], me, 9, false, true).kind, Stealth.CROSS_MENU, "ya te persiguen: no se cruza")


func test_with_the_spear_in_hand_you_cannot_sneak() -> void:
	_wear([CORTEZA, SEMILLAS])
	_spear(true)
	var out: Dictionary = Stealth.border_outcome([], Vector2i.ZERO, Stealth.camouflage(), AdventureRules.is_armed(), false)
	assert_eq(out.kind, Stealth.CROSS_MENU, "aunque nadie te vea, el Bosque siente tu arma")
	_spear(false)
	out = Stealth.border_outcome([], Vector2i.ZERO, Stealth.camouflage(), AdventureRules.is_armed(), false)
	assert_eq(out.kind, Stealth.CROSS_SNEAK, "enfundada, sí")


# --- Cruce sin menú (BosqueBorder) --------------------------------------------------------------------

func _border(decision: Dictionary) -> BosqueBorder:
	var border := BosqueBorder.new(func(c: Vector2i) -> int: return TARGET if c.x >= 10 else HOME,
		func(b: int) -> bool: return not AdventureRules.is_passable(b, HOME))
	border.decide = func(_b: int, _c: Vector2i) -> Dictionary: return decision
	border.current_bosque = HOME
	return border


func test_crossing_unseen_marks_the_bosque_as_sneaked_without_menu() -> void:
	var border: BosqueBorder = _border({ "kind": Stealth.CROSS_SNEAK, "index": -1 })
	var blocks: Callable = border.blocks(func(_c: Vector2i) -> bool: return false)
	watch_signals(EventBus)
	watch_signals(border)
	assert_true(blocks.call(Vector2i(10, 0)), "cerrado: bloquea al tocarlo")
	border.tick(Vector2i(9, 0), true)
	assert_signal_emitted(border, "sneaked")
	assert_signal_not_emitted(EventBus, "bosque_border_reached", "sin menú del borde")
	assert_signal_not_emitted(border, "contacted", "no acude el Botarramas")
	assert_signal_emitted_with_parameters(EventBus, "bosque_sneaked", [TARGET])
	assert_true(AdventureRules.is_sneaked(TARGET), "el Bosque queda colado")
	assert_false(AdventureRules.is_paid(TARGET, HOME), "ni pagado")
	assert_false(AdventureRules.is_forced(TARGET), "ni forzado")
	assert_false(blocks.call(Vector2i(10, 0)), "ya no bloquea: se cruza")


func test_crossing_seen_by_a_botarramas_opens_the_menu() -> void:
	var border: BosqueBorder = _border({ "kind": Stealth.CROSS_MENU, "index": 0 })
	var blocks: Callable = border.blocks(func(_c: Vector2i) -> bool: return false)
	watch_signals(EventBus)
	blocks.call(Vector2i(10, 0))
	border.tick(Vector2i(9, 0), true)
	assert_signal_emitted_with_parameters(EventBus, "bosque_border_reached", [TARGET])
	assert_false(AdventureRules.is_sneaked(TARGET))


func test_crossing_seen_by_another_unico_neither_crosses_nor_opens_the_menu() -> void:
	var border: BosqueBorder = _border({ "kind": Stealth.CROSS_SEEN, "index": 1 })
	var blocks: Callable = border.blocks(func(_c: Vector2i) -> bool: return false)
	watch_signals(EventBus)
	watch_signals(border)
	blocks.call(Vector2i(10, 0))
	border.tick(Vector2i(9, 0), true)
	assert_signal_emitted(border, "seen")
	assert_signal_not_emitted(EventBus, "bosque_border_reached")
	assert_false(AdventureRules.is_sneaked(TARGET))
	assert_true(blocks.call(Vector2i(10, 0)), "sigue cerrado")


# --- Arma enfundada o en la mano ----------------------------------------------------------------------

func test_toggle_weapon_and_notice() -> void:
	assert_eq(AdventureRules.toggle_weapon(), &"none", "sin arma no hay nada que sacar")
	assert_eq(Texts.get_text(AdventureRules.weapon_toggle_text(&"none")), "No llevas arma.")
	_spear(false)
	watch_signals(EventBus)
	assert_eq(AdventureRules.toggle_weapon(), &"drawn")
	assert_true(AdventureRules.is_armed())
	assert_signal_emitted_with_parameters(EventBus, "weapon_toggled", [true])
	assert_eq(AdventureRules.toggle_weapon(), &"sheathed")
	assert_false(AdventureRules.is_armed())
	assert_true(AdventureRules.has_weapon(), "enfundada sigue equipada")
	assert_ne(Texts.get_text("weapon_drawn"), "weapon_drawn")
	assert_ne(Texts.get_text("weapon_sheathed"), "weapon_sheathed")


func test_drawing_inside_a_sneaked_bosque_is_felt() -> void:
	_spear(false)
	AdventureRules.sneak_into(TARGET)
	assert_true(AdventureRules.is_sneaking_unseen(TARGET))
	AdventureRules.toggle_weapon(TARGET)
	assert_false(AdventureRules.is_sneaking_unseen(TARGET), "sacarla dentro: el Bosque lo siente")


func test_sheathed_does_not_close_bosques() -> void:
	AdventureRules.open_bosque(TARGET)
	_spear(false)
	assert_false(AdventureRules.is_armed_against(TARGET, HOME), "enfundada no cierra")
	assert_true(AdventureRules.is_welcome(TARGET, HOME))
	assert_false(BosqueHunt.is_hunting(TARGET, HOME))
	_spear(true)
	assert_true(AdventureRules.is_armed_against(TARGET, HOME), "en la mano cierra, como antes")
	assert_false(AdventureRules.is_welcome(TARGET, HOME))


func test_equipping_sheathes_and_unequipping_clears_the_hand() -> void:
	var index: int = -1
	for i: int in GameState.bag.size():
		if InventoryLogic.id_at(GameState.bag, i) == LANZA:
			index = i
	GameState.weapon_drawn = true
	assert_true(AdventureRules.equip_from_bag(index))
	assert_false(GameState.weapon_drawn, "recién equipada, enfundada")
	AdventureRules.toggle_weapon()
	assert_true(AdventureRules.unequip_slot(&"main_hand"))
	assert_false(GameState.weapon_drawn)


func test_weapon_draws_itself_in_combat_except_in_an_enemy_ambush() -> void:
	var base: int = int(AdocGrowth.player_stats().atk)
	_spear(false)
	assert_true(AdventureRules.drawn_at_start(false))
	assert_eq(int(AdventureRules.adoc_combat_stats().atk), base + 2, "se desenfunda sola")
	assert_false(AdventureRules.drawn_at_start(true), "emboscada del enemigo: sigue enfundada")
	assert_eq(int(AdventureRules.adoc_combat_stats(true).atk), base, "ATQ base")
	var logic: BattleLogic = AdventureRules.start_battle(TARGET, 1, &"botarramas", 1, [], true)
	assert_eq(logic.adoc_atk, base)
	assert_true(logic.unarmed)
	assert_false(GameState.weapon_drawn, "el combate no cambia su estado")
	_spear(true)
	assert_true(AdventureRules.drawn_at_start(true), "ya en la mano: cuenta también en la emboscada")
	logic = AdventureRules.start_battle(TARGET, 1)
	assert_eq(logic.adoc_atk, base + 2)
	assert_false(logic.unarmed)


func test_sicabi_rule_forbids_even_a_sheathed_weapon() -> void:
	assert_true(AdventureRules.can_enter_sicabi(), "sin arma equipada, sí")
	_spear(false)
	assert_false(AdventureRules.can_enter_sicabi(), "ni enfundada (dueño, #193)")
	_spear(true)
	assert_false(AdventureRules.can_enter_sicabi())
	assert_ne(Texts.get_text("sicabi_weapon"), "sicabi_weapon")


# --- Guardado ------------------------------------------------------------------------------------------

func test_save_keeps_the_weapon_state() -> void:
	assert_gte(GameState.SAVE_VERSION, 21)
	assert_false(GameState.weapon_drawn, "partida nueva: nada en la mano")
	_spear(true)
	var data: Dictionary = GameState.to_dict()
	assert_true(bool(data.weapon_drawn))
	assert_eq(SaveManager.save_game(SAVE_SLOT), OK)
	GameState.new_game(42)
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	assert_true(GameState.weapon_drawn, "vuelve en la mano")
	GameState.weapon_drawn = false
	SaveManager.save_game(SAVE_SLOT)
	GameState.weapon_drawn = true
	SaveManager.load_game(SAVE_SLOT)
	assert_false(GameState.weapon_drawn, "y enfundada")


func test_migration_from_v20_leaves_an_equipped_weapon_in_hand() -> void:
	_spear(false)
	var data: Dictionary = GameState.to_dict()
	data.save_version = 20
	data.erase("weapon_drawn")
	GameState.from_dict(SaveManager.migrate(data))
	assert_true(GameState.weapon_drawn, "v20: un arma equipada era el 'armado' de antes")
	data.equipped.main_hand = ""
	GameState.from_dict(SaveManager.migrate(data))
	assert_false(GameState.weapon_drawn, "sin arma, nada en la mano")
	# Basura: en la mano sin arma equipada no vale.
	data = GameState.to_dict()
	data.weapon_drawn = true
	data.equipped.main_hand = ""
	GameState.from_dict(data)
	assert_false(GameState.weapon_drawn)


# --- Fruto: permiso a la vista ---------------------------------------------------------------------------

func test_permission_state_granted_used_and_denied() -> void:
	AdventureRules.open_bosque(TARGET)
	assert_eq(FruitRules.permission_state(HOME, HOME), FruitRules.GRANTED, "natal")
	assert_eq(FruitRules.permission_state(TARGET, HOME), FruitRules.GRANTED, "pagado")
	FruitRules.take(Vector2i(3, 3), Vector2i(1, 1), TARGET, HOME)
	assert_eq(FruitRules.permission_state(TARGET, HOME), FruitRules.USED, "ya tomaste el de este Momento")
	assert_eq(FruitRules.permission_state(OTHER, HOME), FruitRules.CLOSED, "cerrado")
	AdventureRules.guardian_defeated(OTHER)
	assert_eq(FruitRules.permission_state(OTHER, HOME), FruitRules.FORCED, "forzado: vencer no da permiso")
	GameState.forced_bosques.clear()
	AdventureRules.sneak_into(OTHER)
	assert_eq(FruitRules.permission_state(OTHER, HOME), FruitRules.SNEAKED, "colado")
	assert_eq(StealthHud.fruit_color(FruitRules.GRANTED), StealthHud.COLOR_FRUIT_GRANTED, "verde")
	assert_eq(StealthHud.fruit_color(FruitRules.USED), StealthHud.COLOR_FRUIT_USED, "gris")
	for state: StringName in [FruitRules.FORCED, FruitRules.SNEAKED, FruitRules.CLOSED]:
		assert_eq(StealthHud.fruit_color(state), StealthHud.COLOR_FRUIT_DENIED, "rojo")


func test_entry_notice_in_forced_or_sneaked_bosque() -> void:
	assert_eq(FruitRules.entry_notice(HOME, HOME), "")
	assert_eq(FruitRules.entry_notice(OTHER, HOME), "", "cerrado: no se entra")
	AdventureRules.guardian_defeated(OTHER)
	assert_eq(FruitRules.entry_notice(OTHER, HOME), "Este Bosque no te ha dado permiso: su fruto no es tuyo.")
	AdventureRules.sneak_into(TARGET)
	assert_eq(FruitRules.entry_notice(TARGET, HOME), "Te has colado: su fruto no es tuyo.")


func test_theft_confirmation_says_why_and_starts_on_leave() -> void:
	var p: Dictionary = FruitRules.prompt(HOME, HOME, true)
	assert_eq(p.text, Texts.get_text("fruit_prompt"), "con permiso, la pregunta de siempre")
	assert_eq(p.options, ["Comerlo", "Guardarlo", "Dejarlo"] as Array[String])
	assert_eq(int(p.cursor), 0)
	AdventureRules.guardian_defeated(OTHER)
	p = FruitRules.prompt(OTHER, HOME, true)
	assert_eq(p.text, "Este Bosque no te ha dado permiso: tomarlo es robar.\nVencer a su Botarramas no da permiso.")
	assert_eq(p.actions, [&"eat", &"store", &"leave"] as Array[StringName])
	assert_eq(p.options[0], "Robarlo", "dice lo que es")
	assert_eq(p.options[2], "Dejarlo")
	assert_eq(int(p.cursor), 2, "el cursor empieza en Dejarlo")
	AdventureRules.sneak_into(TARGET)
	p = FruitRules.prompt(TARGET, HOME, false)
	assert_eq(p.options, ["Robarlo", "Dejarlo"] as Array[String])
	assert_eq(int(p.cursor), 1)
	assert_string_ends_with(p.text, "Te has colado.")
	FruitRules.take(Vector2i(3, 3), Vector2i(1, 1), HOME, HOME)
	assert_string_ends_with(FruitRules.prompt(HOME, HOME, false).text, "Ya tomaste el fruto de este Momento.")


func test_eating_a_stored_fruit_elsewhere_does_not_count_as_taking() -> void:
	# El caso del dueño: guardar en un Bosque pagado, comerlo en otro pagado y tomar el de ese.
	AdventureRules.open_bosque(TARGET)
	AdventureRules.open_bosque(OTHER)
	assert_false(bool(FruitRules.take(Vector2i(3, 3), Vector2i(1, 1), TARGET, HOME, true).theft))
	var index: int = -1
	for i: int in GameState.bag.size():
		if InventoryLogic.id_at(GameState.bag, i) == Items.FRUIT_ID:
			index = i
	FruitRules.eat_from_bag(index, OTHER)
	assert_eq(FruitRules.permission_state(OTHER, HOME), FruitRules.GRANTED, "comer el guardado no gasta el de este Bosque")
	assert_false(bool(FruitRules.take(Vector2i(4, 4), Vector2i(1, 1), OTHER, HOME).theft), "no es robo")


func test_fruit_description_is_up_to_date() -> void:
	assert_string_contains(Items.description(Items.FRUIT_ID), "Puedes comerlo en cualquier sitio")
