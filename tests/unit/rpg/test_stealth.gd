extends GutTest
## Sigilo y arma que cierra el paso (Stealth; sigilo-y-robo.md, propuestas provisionales de #131 y
## #132): el camuflaje de máscara y talismán resta visión y se suma con tope; el arma lo anula;
## colarse sin ser visto no paga ni fuerza el Bosque (colado: sin cazadores, fruto = robo); ser
## visto rompe el camuflaje; el robo camuflado solo despierta a los Ofomni si un Único lo ve; el
## arma equipada hace hostil un Bosque pagado y guardarla lo devuelve a normal; ATQ del arma y
## "Peleas sin arma"; máscara que resta DEF y máscara que se rompe; velocidad del talismán y
## cazadores del Bosque enojado; pantalla I y HUD; guardado v15 con migración desde la v14.

const EXPLORATION: String = "res://scenes/world/exploration.tscn"
const Crossing = preload("res://scripts/rpg/crossing.gd")
const Screen = preload("res://scripts/rpg/inventory_screen.gd")
const Battle = preload("res://scripts/rpg/battle.gd")
const SAVE_SLOT: int = 91
const Q: StringName = &"primera_mision"
const LANZA: StringName = &"lanza_de_adoc"
const CORTEZA: StringName = &"mascara_de_corteza"
const MUSGO: StringName = &"mascara_de_musgo"
const CENIZA: StringName = &"mascara_de_ceniza"
const SEMILLAS: StringName = &"talisman_de_semillas"
const PLUMA: StringName = &"talisman_de_pluma"

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
	WorldClock.shelter_check = Callable()
	GameState.new_game(42)
	_arm_spear()


func after_each() -> void:
	get_tree().paused = false
	WorldClock.set_process(true)


func after_all() -> void:
	DirAccess.remove_absolute(SaveManager.slot_path(SAVE_SLOT))
	GameState.new_game(42)


func _exploration() -> Node:
	var expl: Node = load(EXPLORATION).instantiate()
	add_child_autofree(expl)
	expl.start()
	expl._fade.color.a = 0.0
	return expl


## Equipa (sin pasar por la bolsa) los objetos dados en sus ranuras.
func _wear(ids: Array[StringName]) -> void:
	for id: StringName in ids:
		GameState.equipped[String(InventoryLogic.slot_for(id))] = String(id)


func _unarm() -> void:
	GameState.equipped.main_hand = ""


## Un chunk del Bosque natal con frontera con _target, y el lado de esa frontera.
func _border_with_target() -> Array:
	for c: Vector2i in _map.chunks_of(_home):
		for side: Vector2i in ChunkData.SIDES:
			if _map.bosque_at(c + side) == _target:
				return [c, side]
	return []


func _accept_mission() -> void:
	var q: Dictionary = GameState.quests[Q]
	assert_true(QuestLogic.accept(q, _map, 42, _home))
	QuestLogic.commit(Q, q, QuestLogic.OFFERED)


# --- Datos -------------------------------------------------------------------------------------------

func test_catalog_has_masks_and_talismans_with_different_values() -> void:
	var masks: Array = Items.all().filter(func(e: Dictionary) -> bool: return str(e.kind) == "mask")
	var talismans: Array = Items.all().filter(func(e: Dictionary) -> bool: return str(e.kind) == "talisman")
	assert_gte(masks.size(), 3, "máscaras de diferentes formas")
	assert_gte(talismans.size(), 2)
	var values: Array = masks.map(func(e: Dictionary) -> int: return int(e.camouflage))
	assert_eq(values.size(), values.filter(func(v: int) -> bool: return values.count(v) == 1).size(), "valores distintos")
	assert_eq(Items.def_penalty(MUSGO), 2, "la potente pesa: DEF −2")
	assert_eq(Items.max_uses(CENIZA), 3, "la más potente se deshace")
	assert_almost_eq(Items.speed_bonus(PLUMA), 0.3, 0.001, "talismán de viaje")
	assert_eq(Items.camouflage(PLUMA), 0, "no oculta")
	var cfg: Dictionary = Stealth.config()
	assert_eq(int(cfg.camouflage_max), 14)
	assert_eq(int(cfg.sneak_max_vision), 1)
	assert_eq(int(cfg.hidden_vision), 2)


# --- Camuflaje -----------------------------------------------------------------------------------------

func test_camouflage_reduces_vision_and_adds_up_with_a_cap() -> void:
	_unarm()
	assert_eq(Stealth.camouflage(), 0, "sin máscara ni talismán")
	_wear([CORTEZA])
	assert_eq(Stealth.camouflage(), 6)
	assert_eq(AdventureRules.vision_radius(_target, 10), 4, "un Botarramas ve 6 casillas menos")
	assert_eq(int(MonsterField.inner_config(&"ofomni", MonsterField.ROLE_PATROL).vision_radius), 4, "y los de dentro")
	_wear([SEMILLAS])
	assert_eq(Stealth.camouflage(), 9, "máscara y talismán se suman")
	assert_eq(AdventureRules.vision_radius(_target, 10), 1)
	_wear([CENIZA])
	assert_eq(Stealth.camouflage(), 14, "11 + 3")
	assert_eq(AdventureRules.vision_radius(_target, 10), 0, "visión 0: solo te ve encima")
	var cfg: Dictionary = Stealth.config()
	cfg.camouflage_max = 12
	assert_eq(Stealth.camouflage(), 12, "con tope")
	cfg.camouflage_max = 14
	assert_eq(BosqueStates.stealth_vision_bonus(), Stealth.camouflage(), "el gancho del enojado usa el camuflaje")


func test_weapon_in_hand_cancels_camouflage() -> void:
	_wear([CORTEZA, SEMILLAS])
	assert_true(AdventureRules.is_armed(), "con la lanza en la mano")
	assert_eq(Stealth.gear_camouflage(), 9)
	assert_eq(Stealth.camouflage(), 0, "con el arma en la mano, tu Luz te delata")
	assert_false(Stealth.is_hidden())
	assert_false(Stealth.can_sneak_into(_target), "no se cuela armado")
	_unarm()
	assert_true(Stealth.is_hidden())


# --- Colarse -------------------------------------------------------------------------------------------

func test_sneaking_in_unseen_neither_pays_nor_forces_the_bosque() -> void:
	_unarm()
	_wear([CORTEZA])
	assert_false(Stealth.can_sneak_into(_target), "visión 4: no basta")
	_wear([SEMILLAS])
	assert_true(Stealth.can_sneak_into(_target), "visión 1: te cuelas")
	assert_false(Stealth.can_sneak_into(-1))
	watch_signals(EventBus)
	assert_eq(AdventureRules.sneak_into(_target), [] as Array[StringName], "nada se rompe")
	assert_signal_emitted_with_parameters(EventBus, "bosque_sneaked", [_target])
	assert_true(AdventureRules.is_sneaked(_target))
	assert_true(AdventureRules.is_passable(_target, _home), "su frontera se cruza mientras sigues dentro")
	assert_false(AdventureRules.is_paid(_target, _home), "no queda pagado")
	assert_false(AdventureRules.is_forced(_target), "ni forzado")
	assert_false(GameState.open_until.has(str(_target)))
	assert_eq(AdventureRules.relation(_target), 0, "sin pagar, la relación no cambia")
	assert_false(BosqueHunt.is_hunting(_target, _home), "sin cazadores mientras no te vean")
	assert_true(FruitRules.is_theft(_target, _home), "sin derecho a fruto: tomarlo es robo")
	# Al salir del Bosque deja de estar colado: para volver, hay que colarse otra vez.
	AdventureRules.leave_sneaked(_home)
	assert_false(AdventureRules.is_passable(_target, _home))


func test_the_bosque_remembers_and_the_angry_one_needs_a_great_disguise() -> void:
	_unarm()
	_wear([CORTEZA, SEMILLAS])
	GameState.bosque_hostility[str(_target)] = 1
	assert_false(Stealth.can_sneak_into(_target), "hostilidad 1: sus Botarramas ven 2 más (visión 3)")
	GameState.bosque_hostility.erase(str(_target))
	GameState.bosque_state_overrides[str(_target)] = BosqueStates.ENOJADO
	assert_false(Stealth.can_sneak_into(_target), "enojado: +4 de visión")
	_wear([CENIZA])
	assert_true(Stealth.can_sneak_into(_target), "camuflaje muy muy bueno (14): visión 0")


func test_mask_that_breaks_after_its_uses() -> void:
	_unarm()
	_wear([CENIZA])
	assert_eq(Stealth.uses_left(CENIZA), 3)
	assert_eq(Stealth.uses_left(CORTEZA), -1, "la de corteza no se rompe")
	AdventureRules.sneak_into(_target)
	AdventureRules.sneak_into(_target)
	assert_eq(Stealth.uses_left(CENIZA), 1)
	watch_signals(EventBus)
	assert_eq(AdventureRules.sneak_into(_target), [CENIZA] as Array[StringName], "al tercer cruce se deshace")
	assert_signal_emitted_with_parameters(EventBus, "item_broken", [CENIZA])
	assert_eq(InventoryLogic.equipped_in(GameState.equipped, &"mask"), &"", "sale del equipo")
	assert_false(GameState.item_uses.has(String(CENIZA)))


func test_exploration_sneaks_through_a_closed_border_without_the_menu() -> void:
	var expl: Node = _exploration()
	_accept_mission()
	var border: Array = _border_with_target()
	expl._enter_chunk(border[0], expl._get_chunk(border[0]).hub)
	_unarm()
	_wear([CORTEZA, SEMILLAS])
	watch_signals(EventBus)
	expl._on_edge_reached(border[1])
	assert_eq(GameState.chunk_coord, border[0] + border[1], "cruza")
	assert_signal_not_emitted(EventBus, "bosque_border_reached", "sin menú del borde")
	assert_true(AdventureRules.is_sneaked(_target))
	assert_false(AdventureRules.is_paid(_target, _home))
	assert_true(_notice_contains(Texts.get_text("sneak_entered")), "avisa: te cuelas")
	expl._process(BosqueHunt.interval(0) + 1.0)
	assert_eq(expl._field.hunters().size(), 0, "colado y sin ser visto: el Bosque no caza")


func test_exploration_without_disguise_still_opens_the_border_menu() -> void:
	var expl: Node = _exploration()
	_accept_mission()
	var border: Array = _border_with_target()
	expl._enter_chunk(border[0], expl._get_chunk(border[0]).hub)
	_unarm()
	watch_signals(EventBus)
	expl._on_edge_reached(border[1])
	assert_eq(GameState.chunk_coord, border[0], "no cruza")
	assert_signal_emitted_with_parameters(EventBus, "bosque_border_reached", [_target])


# --- Te han visto ----------------------------------------------------------------------------------------

func test_being_seen_up_close_breaks_the_camouflage() -> void:
	var expl: Node = _exploration()
	_unarm()
	_wear([CORTEZA, SEMILLAS])
	AdventureRules.sneak_into(_target)
	var coord: Vector2i = _map.chunks_of(_target)[0]
	expl._enter_chunk(coord, expl._get_chunk(coord).hub)
	expl._fade.color.a = 0.0
	var at: Vector2i = expl._player.cell + Vector2i.RIGHT
	var m: OverworldMonster = expl._field.spawn_hunter(&"botarramas", _target, at, _map.styles[_target])
	m.cell = at
	watch_signals(EventBus)
	watch_signals(expl._field)
	expl._field._process(0.01)
	assert_signal_emitted(expl._field, "spotted", "se le echa encima: le ve")
	assert_signal_not_emitted(expl._field, "engaged", "tarda un instante en atacar")
	assert_signal_emitted_with_parameters(EventBus, "notice_requested", [Texts.get_text("stealth_spotted")])
	assert_signal_emitted_with_parameters(EventBus, "adoc_spotted", [_target])
	assert_true(Stealth.is_exposed(), "el camuflaje se rompe")
	assert_eq(Stealth.camouflage(), 0)
	assert_false(AdventureRules.is_sneaking_unseen(_target), "el Bosque ya sabe que estás dentro")
	assert_true(BosqueHunt.is_hunting(_target, _home), "y te caza")
	assert_eq(m.state, MonsterSteering.State.CHASE, "te persigue")
	assert_eq(int(m.cfg.vision_radius), int(AdventureRules.monster_config(&"botarramas").vision_radius), "ya ve de lejos")
	# Pasado el instante, el encuentro.
	expl._field._process(Stealth.seen_grace() + 0.01)
	assert_signal_emitted(expl._field, "engaged")
	# Con el tiempo, el camuflaje vuelve.
	assert_true(Stealth.tick(float(Stealth.config().exposed_seconds)))
	assert_true(Stealth.is_hidden())


func test_spotted_only_matters_while_hidden() -> void:
	var expl: Node = _exploration()
	GameState.equipped.main_hand = String(LANZA)
	var m: OverworldMonster = expl._field.spawn_hunter(&"botarramas", _target, Vector2i(5, 5), _map.styles[_target])
	expl._on_monster_spotted(m)
	assert_false(Stealth.is_exposed(), "sin camuflaje no hay nada que romper")


# --- Robo -----------------------------------------------------------------------------------------------

func test_camouflaged_theft_only_alerts_if_watched() -> void:
	assert_true(OfomniGuard.is_alerted(), "sin camuflaje: 100%")
	assert_true(OfomniGuard.is_alerted(0.0, false, false))
	assert_false(OfomniGuard.is_alerted(0.0, true, false), "camuflado y sin Únicos a la vista: no despiertan")
	assert_true(OfomniGuard.is_alerted(0.0, true, true), "camuflado pero a la vista: despiertan")


func test_exploration_hidden_theft_wakes_no_ofomni_but_bare_theft_does() -> void:
	var expl: Node = _exploration()
	assert_eq(_map.bosque_at(GameState.chunk_coord), _home)
	_unarm()
	_wear([CORTEZA, SEMILLAS])
	var coord: Vector2i = GameState.chunk_coord
	expl._field.remove_roles([MonsterField.ROLE_PATROL, MonsterField.ROLE_GUARDIAN] as Array[StringName])
	FruitRules.take(coord, Vector2i(1, 1), _home, _home)
	var r: Dictionary = FruitRules.take(coord, Vector2i(2, 1), _home, _home)
	assert_true(bool(r.theft))
	assert_eq(expl._field.chasers().size(), 0, "nadie lo ha visto: los Ofomni no despiertan")
	assert_true(expl._theft_unseen)
	assert_eq(AdventureRules.hostility(_home), 1, "el Bosque echa en falta su fruto igualmente")
	# Sin camuflaje, a la vista: despiertan.
	GameState.equipped.mask = ""
	GameState.equipped.talisman = ""
	FruitRules.take(coord, Vector2i(3, 1), _home, _home)
	assert_gt(expl._field.chasers().size(), 0, "sin protección: despiertan")
	assert_false(expl._theft_unseen)


func test_exploration_hidden_theft_under_a_watching_unico_wakes_them() -> void:
	var expl: Node = _exploration()
	_unarm()
	_wear([CORTEZA, SEMILLAS])
	var coord: Vector2i = GameState.chunk_coord
	expl._field.spawn_hunter(&"botarramas", _home, expl._player.cell + Vector2i.RIGHT, _map.styles[_home])
	assert_true(expl._field.is_watched(_home, expl._player.cell))
	FruitRules.take(coord, Vector2i(1, 1), _home, _home)
	FruitRules.take(coord, Vector2i(2, 1), _home, _home)
	assert_gt(expl._field.chasers().size(), 0, "un Único lo ha visto")
	assert_true(Stealth.is_exposed(), "y te han visto")


# --- Arma equipada -------------------------------------------------------------------------------------------

func test_weapon_makes_a_paid_bosque_hostile_and_putting_it_away_restores_it() -> void:
	AdventureRules.open_bosque(_target)
	assert_true(AdventureRules.is_paid(_target, _home))
	assert_true(AdventureRules.is_armed())
	assert_false(AdventureRules.is_welcome(_target, _home), "con el arma en la mano no te deja pasar en paz")
	assert_true(AdventureRules.is_welcome(_home, _home), "el natal, sí")
	assert_true(BosqueHunt.is_hunting(_target, _home), "los cazadores salen como sin pagar")
	assert_eq(Crossing.actions_for(_target, _home), [Crossing.Option.FIGHT, Crossing.Option.RETREAT] as Array[int], "el peaje no se ofrece")
	assert_string_contains(Crossing.title_for(_target, _home), Texts.get_text("crossing_armed_title"))
	var field := MonsterField.new()
	add_child_autofree(field)
	field._home = _home
	field._bosques = _map
	var m := OverworldMonster.new()
	m.bosque_id = _target
	m.role = MonsterField.ROLE_PATROL
	m.key = "x"
	autofree(m)
	assert_true(field.can_detect(m), "sus Únicos te ven y te persiguen")
	# Guardarla deja todo como antes.
	assert_true(AdventureRules.unequip_slot(&"main_hand"))
	assert_true(AdventureRules.is_welcome(_target, _home))
	assert_false(BosqueHunt.is_hunting(_target, _home))
	assert_eq(Crossing.actions_for(_target, _home).size(), 4, "vuelve a ofrecer el peaje")
	assert_false(field.can_detect(m), "te miran pasar")


func test_weapon_does_not_close_free_bosques() -> void:
	GameState.bosque_state_overrides[str(_target)] = BosqueStates.NECESITA_AYUDA
	assert_true(AdventureRules.is_welcome(_target, _home), "el que necesita ayuda no cobra y te ayuda")
	GameState.bosque_state_overrides[str(_target)] = BosqueStates.MUERTO
	assert_true(AdventureRules.is_welcome(_target, _home), "el muerto no tiene Nujio")


func test_exploration_warns_when_crossing_armed_and_border_menu_opens_even_if_paid() -> void:
	var expl: Node = _exploration()
	_accept_mission()
	AdventureRules.open_bosque(_target)
	var border: Array = _border_with_target()
	expl._enter_chunk(border[0], expl._get_chunk(border[0]).hub)
	watch_signals(EventBus)
	expl._on_edge_reached(border[1])
	assert_eq(GameState.chunk_coord, border[0] + border[1], "pagado: cruza")
	assert_true(_notice_contains(Texts.get_text("bosque_feels_weapon")), "El Bosque siente tu arma.")
	var crossing: Node = expl.get_node("Crossing")
	EventBus.bosque_border_reached.emit(_target)
	assert_true(crossing._panel.visible, "sus Botarramas te enfrentan aunque hayas pagado")
	assert_eq(crossing._actions, [Crossing.Option.FIGHT, Crossing.Option.RETREAT] as Array[int])
	crossing._close(&"retreated")
	AdventureRules.unequip_slot(&"main_hand")
	EventBus.bosque_border_reached.emit(_target)
	assert_false(crossing._panel.visible, "desarmado y pagado: paso en paz")


func test_equipping_inside_a_bosque_warns_in_the_inventory() -> void:
	AdventureRules.unequip_slot(&"main_hand")
	var index: int = -1
	for i: int in GameState.bag.size():
		if InventoryLogic.id_at(GameState.bag, i) == LANZA:
			index = i
	var text: String = Screen.activate(index, _target, _home)
	assert_string_contains(text, Texts.get_text("bosque_feels_weapon"))
	AdventureRules.unequip_slot(&"main_hand")
	assert_false(Screen.activate(index, _home, _home).contains(Texts.get_text("bosque_feels_weapon")), "en el natal, no")


func test_weapon_atk_bonus_and_unarmed_notice() -> void:
	var base: Dictionary = AdventureRules.adoc_stats(GameState.level)
	assert_eq(int(AdventureRules.adoc_combat_stats().atk), int(base.atk) + 2, "lanza: ATQ +2")
	var logic: BattleLogic = AdventureRules.start_battle(_target, 1)
	assert_eq(logic.adoc_atk, int(base.atk) + 2)
	assert_false(logic.unarmed)
	assert_eq(Battle.start_messages(logic).size(), 1)
	_unarm()
	assert_eq(int(AdventureRules.adoc_combat_stats().atk), int(base.atk), "sin arma: ATQ base")
	logic = AdventureRules.start_battle(_target, 1)
	assert_true(logic.unarmed)
	var msgs: Array[Dictionary] = Battle.start_messages(logic)
	assert_eq(msgs.size(), 2)
	assert_eq(str(msgs[1].text), "Peleas sin arma.")


func test_heavy_mask_lowers_def() -> void:
	var base: Dictionary = AdventureRules.adoc_stats(GameState.level)
	_wear([MUSGO])
	assert_eq(int(AdventureRules.adoc_combat_stats().def), maxi(0, int(base.def) - 2))
	assert_string_contains(Screen.stat_lines()[3], "(−2)", "la pantalla I lo muestra")


# --- Velocidad y Bosque enojado -------------------------------------------------------------------------

func test_travel_talisman_speeds_up_the_step() -> void:
	assert_almost_eq(Stealth.step_time(PlayerWalker.STEP_TIME), PlayerWalker.STEP_TIME, 0.0001)
	_wear([PLUMA])
	assert_almost_eq(Stealth.step_time(PlayerWalker.STEP_TIME), PlayerWalker.STEP_TIME / 1.3, 0.0001, "un 30% más rápido")
	var cfg: Dictionary = Stealth.config()
	cfg.speed_bonus_max = 0.2
	assert_almost_eq(Stealth.speed_bonus(), 0.2, 0.0001, "con tope")
	cfg.speed_bonus_max = 0.5


func test_exploration_applies_the_talisman_speed_when_equipped() -> void:
	var expl: Node = _exploration()
	assert_almost_eq(expl._player.step_time, PlayerWalker.STEP_TIME, 0.0001)
	var index: int = -1
	for i: int in GameState.bag.size():
		if InventoryLogic.id_at(GameState.bag, i) == PLUMA:
			index = i
	assert_true(AdventureRules.equip_from_bag(index))
	assert_almost_eq(expl._player.step_time, PlayerWalker.STEP_TIME / 1.3, 0.0001)
	AdventureRules.unequip_slot(&"talisman")
	assert_almost_eq(expl._player.step_time, PlayerWalker.STEP_TIME, 0.0001)


func test_angry_bosque_hunters_take_longer_with_great_camouflage_or_speed() -> void:
	var state: String = BosqueStates.ENOJADO
	var first: float = BosqueHunt.first_delay(0, state)
	var interval: float = BosqueHunt.interval(0, state)
	_unarm()
	_wear([CORTEZA])
	assert_almost_eq(BosqueHunt.first_delay(0, state), first, 0.001, "camuflaje 6 (visión 4): no basta")
	_wear([SEMILLAS])
	assert_almost_eq(BosqueHunt.first_delay(0, state), first * 2.0, 0.001, "visión ≤ 2: tardan el doble")
	assert_almost_eq(BosqueHunt.interval(0, state), interval * 2.0, 0.001)
	assert_almost_eq(BosqueHunt.interval(0, BosqueStates.SANO), BosqueHunt.interval(0), 0.001, "solo en el enojado")
	GameState.equipped.mask = ""
	GameState.equipped.talisman = String(PLUMA)
	assert_almost_eq(BosqueHunt.first_delay(0, state), first * 2.0, 0.001, "o con velocidad")


# --- Pantalla I y HUD ------------------------------------------------------------------------------------

func test_inventory_shows_each_item_effects() -> void:
	assert_true(Screen.describe(LANZA).begins_with("ATQ +2. "))
	assert_true(Screen.describe(CORTEZA).begins_with("Camuflaje 6. "))
	assert_true(Screen.describe(MUSGO).begins_with("Camuflaje 8. DEF −2. "))
	assert_true(Screen.describe(CENIZA).begins_with("Camuflaje 11. Usos: 3. "))
	assert_true(Screen.describe(PLUMA).begins_with("Paso +30%. "))
	GameState.item_uses[String(CENIZA)] = 2
	assert_string_contains(Screen.describe(CENIZA), "Usos: 1.", "los que quedan")


func test_hud_icons_follow_the_state() -> void:
	assert_eq(StealthHud.mask_state(), StealthHud.Mask.NONE)
	_wear([CORTEZA])
	assert_eq(StealthHud.mask_state(), StealthHud.Mask.NONE, "armado: el camuflaje no funciona")
	_unarm()
	assert_eq(StealthHud.mask_state(), StealthHud.Mask.HIDDEN, "oculto")
	Stealth.expose()
	assert_eq(StealthHud.mask_state(), StealthHud.Mask.EXPOSED, "te han visto")


# --- Guardado ------------------------------------------------------------------------------------------

func test_save_v15_keeps_sneaked_bosques_exposure_and_uses() -> void:
	assert_gte(GameState.SAVE_VERSION, 15)
	_unarm()
	_wear([CENIZA])
	AdventureRules.sneak_into(_target)
	Stealth.expose()
	var data: Dictionary = GameState.to_dict()
	assert_eq(data.sneaked_bosques, { str(_target): false })
	assert_eq(data.item_uses, { String(CENIZA): 1 })
	assert_gt(float(data.stealth_exposed), 0.0)
	assert_eq(SaveManager.save_game(SAVE_SLOT), OK)
	GameState.new_game(42)
	assert_true(GameState.sneaked_bosques.is_empty(), "partida nueva: nada colado")
	assert_eq(GameState.stealth_exposed, 0.0)
	assert_true(GameState.item_uses.is_empty())
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	assert_true(AdventureRules.is_sneaking_unseen(_target), "sigues colado")
	assert_true(AdventureRules.is_passable(_target, _home), "al cargar dentro, no te devuelve a la villa")
	assert_eq(Stealth.uses_left(CENIZA), 2)
	assert_true(Stealth.is_exposed())


func test_migration_from_v14_has_no_stealth_state() -> void:
	GameState.sneaked_bosques[str(_target)] = true
	GameState.item_uses[String(CENIZA)] = 2
	var data: Dictionary = GameState.to_dict()
	data.save_version = 14
	data.erase("sneaked_bosques")
	data.erase("stealth_exposed")
	data.erase("item_uses")
	GameState.from_dict(data)
	assert_true(GameState.sneaked_bosques.is_empty())
	assert_eq(GameState.stealth_exposed, 0.0)
	assert_true(GameState.item_uses.is_empty())
	# Basura en el guardado: se descarta.
	data = GameState.to_dict()
	data.sneaked_bosques = { "-3": false, str(_target): true }
	data.item_uses = { "mascara_de_corteza": 4, String(CENIZA): 9, "no_existe": 1 }
	data.stealth_exposed = -5.0
	GameState.from_dict(data)
	assert_eq(GameState.sneaked_bosques, { str(_target): true })
	assert_true(GameState.item_uses.is_empty(), "solo usos válidos de objetos que se rompen")
	assert_eq(GameState.stealth_exposed, 0.0)


## Algún aviso del HUD emitido desde watch_signals contiene `text`.
func _notice_contains(text: String) -> bool:
	var n: int = get_signal_emit_count(EventBus, "notice_requested")
	for i: int in n:
		var params: Array = get_signal_parameters(EventBus, "notice_requested", i)
		if str(params[0]).contains(text):
			return true
	return false


## Pone la lanza en la mano (desde la 0.3 una partida nueva la empieza guardada en la bolsa).
func _arm_spear() -> void:
	for i in GameState.bag.size():
		if InventoryLogic.id_at(GameState.bag, i) == &"lanza_de_adoc":
			AdventureRules.equip_from_bag(i)
			return
