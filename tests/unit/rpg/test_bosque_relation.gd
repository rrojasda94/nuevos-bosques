extends GutTest
## Relación con cada Bosque (bosques-y-relacion.md, #134 y #135): el pago caduca al segundo riutash
## (permanente con amistad alta), multiplicadores del peaje por relación, dejar ofrendas ante el
## Nujio, descanso del riutash junto al Nujio, misión para el Bosque, topes, marca de candidato a
## enojarse y guardado v12 con migración desde la v11.

const Crossing = preload("res://scripts/rpg/crossing.gd")
const Screen = preload("res://scripts/rpg/inventory_screen.gd")
const SAVE_SLOT: int = 94

var _region: Dictionary
var _map: BosqueMap
var _home: int
var _target: int
## Mundo 2.0 de la seed 42 (chunks reales del Nujio) y un Bosque vecino del natal en él.
var _plan: RegionPlan
var _world_target: int


func before_all() -> void:
	_plan = RegionPlan.for_region(42, &"valle_del_sara")
	_world_target = _plan.bosques.neighbours_of(_plan.bosque_at(_plan.home_chunk))[0]
	_region = ChunkGenerator.load_region(&"valle_del_sara")
	_map = BosqueMap.for_region(42, _region)
	_home = AdventureRules.home_bosque(_map, _region)
	_target = _map.neighbours_of(_home)[0]


func before_each() -> void:
	WorldClock.set_process(false)
	# Otros tests dejan la comprobación de refugio de una exploración ya liberada.
	WorldClock.shelter_check = Callable()
	GameState.new_game(42)
	# Sin arma en la mano: con ella ningún Bosque deja pasar en paz (eso se prueba en test_stealth).
	GameState.equipped.main_hand = ""


func after_each() -> void:
	WorldClock.set_process(true)


func after_all() -> void:
	DirAccess.remove_absolute(SaveManager.slot_path(SAVE_SLOT))


func _pass_riutash() -> void:
	WorldClock.advance(WorldClock.time_to_riutash())


func _win(bosque_id: int) -> void:
	var logic: BattleLogic = AdventureRules.start_battle(bosque_id, 1)
	logic.result = BattleLogic.Result.VICTORY
	AdventureRules.finish_battle(logic, bosque_id)


# --- Caducidad del pago --------------------------------------------------------------------------

func test_payment_lasts_until_the_second_riutash() -> void:
	var cfg: Dictionary = AdventureRules.balance().bosque_relation
	assert_eq(int(cfg.paid_riutash), 2, "hasta el segundo riutash (dueño, #134)")
	assert_true(AdventureRules.pay_toll(_target, 0))
	assert_true(AdventureRules.is_paid(_target, _home))
	assert_eq(AdventureRules.open_riutash_left(_target), 2)
	assert_eq(Screen.toll_line(_target), "Paso: hasta el 2.º riutash")
	_pass_riutash()
	assert_eq(GameState.riutash_count, 1, "WorldClock cuenta los riutash")
	assert_true(AdventureRules.is_paid(_target, _home), "tras el primero sigue abierto")
	assert_eq(Screen.toll_line(_target), "Paso: hasta el próximo riutash")
	_pass_riutash()
	assert_false(AdventureRules.is_paid(_target, _home), "el segundo lo cierra")
	assert_false(AdventureRules.is_passable(_target, _home), "vuelve a cerrado")
	assert_eq(Screen.toll_line(_target), "", "sin paso, sin línea")
	watch_signals(EventBus)
	assert_eq(AdventureRules.expire_tolls(), [_target] as Array[int])
	assert_signal_emitted_with_parameters(EventBus, "bosque_toll_expired", [_target])
	assert_false(GameState.open_until.has(str(_target)), "se borra al caducar")
	assert_eq(AdventureRules.expire_tolls(), [] as Array[int], "una sola vez")


func test_expired_payment_returns_a_forced_bosque_to_forced_and_reactivates_botarramas() -> void:
	var field: MonsterField = add_child_autofree(MonsterField.new())
	field._home = _home
	var m := OverworldMonster.new()
	m.monster_id = MonsterField.BOTARRAMAS
	m.bosque_id = _target
	m.cfg = MonsterField.guardian_config(AdventureRules.monster_config(MonsterField.BOTARRAMAS), _target)
	field.add_child(m)
	_win(_target)
	assert_true(AdventureRules.pay_toll(_target, 0))
	assert_false(AdventureRules.is_forced(_target), "pagado: no cuenta como forzado")
	assert_false(field.can_detect(m), "pasivo mientras dura el pago")
	_pass_riutash()
	_pass_riutash()
	AdventureRules.expire_tolls()
	assert_true(AdventureRules.is_forced(_target), "vuelve a forzado")
	assert_true(AdventureRules.is_passable(_target, _home))
	assert_true(field.can_detect(m), "sus Botarramas vuelven a vigilar")


func test_payment_is_permanent_with_high_friendship() -> void:
	GameState.bosque_relation[str(_target)] = 60
	assert_true(AdventureRules.pay_toll(_target, 0))
	assert_true(AdventureRules.is_open_permanent(_target))
	assert_eq(Screen.toll_line(_target), "Paso: permanente")
	for i in 6:
		_pass_riutash()
	assert_true(AdventureRules.is_paid(_target, _home), "no caduca")
	assert_eq(AdventureRules.expire_tolls(), [] as Array[int])


func test_reaching_friendship_while_open_makes_it_permanent_and_losing_it_restarts_the_clock() -> void:
	GameState.bosque_relation[str(_target)] = 55
	AdventureRules.pay_toll(_target, 0)
	assert_false(AdventureRules.is_open_permanent(_target), "56: aún caduca")
	AdventureRules.change_relation(_target, 4)
	assert_true(AdventureRules.is_open_permanent(_target), "60: permanente")
	_pass_riutash()
	_pass_riutash()
	assert_true(AdventureRules.is_paid(_target, _home))
	AdventureRules.change_relation(_target, -20)
	assert_eq(AdventureRules.open_riutash_left(_target), 2, "sin amistad, caduca desde ahora")


func test_home_bosque_never_expires() -> void:
	for i in 4:
		_pass_riutash()
	assert_true(AdventureRules.is_paid(_home, _home))
	assert_eq(Screen.toll_line(_home), "", "el natal no tiene pago")


# --- Multiplicadores del peaje ------------------------------------------------------------------

func test_toll_multipliers_by_relation() -> void:
	var cases: Array = [[0, 4], [29, 4], [30, 3], [59, 3], [60, 2], [100, 2], [-29, 4], [-30, 6], [-100, 6]]
	for c: Array in cases:
		GameState.bosque_relation[str(_target)] = c[0]
		assert_eq(AdventureRules.toll_for(_target, 1), c[1], "relación %d: peaje %d (base 4)" % [c[0], c[1]])


func test_multiplier_applies_on_top_of_hostility_and_its_cap() -> void:
	GameState.bosque_hostility[str(_target)] = 5
	GameState.bosque_relation[str(_target)] = 0
	assert_eq(AdventureRules.toll_for(_target, 1), 10, "4 + 10 se queda en el tope 10")
	GameState.bosque_relation[str(_target)] = -30
	assert_eq(AdventureRules.toll_for(_target, 1), 15, "tope 10 × 1,5")
	GameState.bosque_relation[str(_target)] = 60
	assert_eq(AdventureRules.toll_for(_target, 1), 5, "tope 10 × 0,5")
	GameState.bosque_hostility[str(_target)] = 1
	GameState.bosque_relation[str(_target)] = 30
	assert_eq(AdventureRules.toll_for(_target, 1), 5, "6 × 0,75 = 4,5, redondeado")
	assert_eq(AdventureRules.start_battle(_target, 1).toll, 5, "el combate cobra lo mismo")


func test_crossing_title_shows_the_relation_multiplier() -> void:
	var base: String = "El Bosque te observa. Su Nujio exige Luz."
	assert_eq(Crossing.title_for(_target), base, "relación 0: sin línea")
	GameState.bosque_relation[str(_target)] = 30
	assert_eq(Crossing.title_for(_target), base + "\nEl Bosque te aprecia: peaje ×0,75.")
	GameState.bosque_relation[str(_target)] = 60
	assert_eq(Crossing.title_for(_target), base + "\nEl Bosque es tu amigo: peaje ×0,5 y paso permanente.")
	GameState.bosque_relation[str(_target)] = -30
	GameState.bosque_hostility[str(_target)] = 1
	assert_eq(Crossing.title_for(_target), base + "\nEl Bosque recuerda tu violencia.\nEl Bosque desconfía de ti: peaje ×1,5.")


# --- Dejar una ofrenda ante el Nujio -------------------------------------------------------------

func test_leaving_an_ofrenda_raises_relation_lowers_hostility_and_leaves_the_bag() -> void:
	InventoryLogic.add(GameState.bag, &"cuenco_ritual")
	GameState.bosque_hostility[str(_target)] = 2
	watch_signals(EventBus)
	assert_true(AdventureRules.leave_ofrenda(_target, &"cuenco_ritual"))
	assert_eq(AdventureRules.relation(_target), 6, "suma su valor en Luz")
	assert_eq(AdventureRules.hostility(_target), 1, "el Bosque olvida un poco")
	assert_eq(InventoryLogic.count(GameState.bag, &"cuenco_ritual"), 0, "sale de la bolsa")
	assert_signal_emitted_with_parameters(EventBus, "bosque_ofrenda_left", [_target, &"cuenco_ritual"])
	assert_false(AdventureRules.is_paid(_target, _home), "no paga el peaje")
	assert_false(AdventureRules.leave_ofrenda(_target, &"cuenco_ritual"), "ya no queda")
	assert_false(AdventureRules.leave_ofrenda(_target, &"mascara_de_corteza"), "solo ofrendas")
	GameState.bosque_hostility[str(_target)] = 0
	InventoryLogic.add(GameState.bag, &"cuenta_de_barro")
	AdventureRules.leave_ofrenda(_target, &"cuenta_de_barro")
	assert_eq(AdventureRules.hostility(_target), 0, "sin bajar de 0")


func test_nujio_menu_lists_one_option_per_ofrenda_type() -> void:
	InventoryLogic.add(GameState.bag, &"cuenta_de_barro", 2)
	InventoryLogic.add(GameState.bag, &"figura_sarua")
	assert_eq(AdventureRules.bag_ofrenda_ids(), [&"cuenta_de_barro", &"figura_sarua"] as Array[StringName])
	assert_eq(AdventureRules.nujio_ofrenda_option(&"cuenta_de_barro"), "Cuenta de barro (3 Luz) ×2")
	assert_eq(AdventureRules.nujio_ofrenda_option(&"figura_sarua"), "Figura sarua (8 Luz)")


func test_e_in_front_of_the_nujio_targets_it() -> void:
	var coord: Vector2i = _plan.bosques.nujio_chunk[_world_target]
	var nujio: WorldChunk = ChunkBuilder.build(_plan, coord)
	var rect: Rect2i = nujio.nujio_rect
	var below: Vector2i = WorldCoords.to_world_cell(coord, Vector2i(rect.position.x, rect.end.y))
	var get_chunk: Callable = func(c: Vector2i) -> WorldChunk: return nujio if c == coord else null
	var found: Dictionary = Interaction.find_world(get_chunk, WorldCoords.world_cell_to_world_pos(below), Vector2i.UP)
	assert_eq(found.kind, Interaction.Kind.NUJIO)
	assert_eq(found.cell, WorldCoords.to_world_cell(coord, rect.position), "la esquina noroeste del Nujio")


func test_paying_with_an_ofrenda_also_adds_its_value() -> void:
	InventoryLogic.add(GameState.bag, &"talisman_de_viaje")
	assert_true(AdventureRules.pay_toll_with_ofrenda(_target, 4, 0))
	assert_eq(AdventureRules.relation(_target), 5, "como dejarla: su valor (no el +1 de la Luz)")
	assert_true(AdventureRules.is_paid(_target, _home))


# --- Riutash junto al Nujio ---------------------------------------------------------------------

func test_riutash_sheltered_near_the_nujio_adds_relation() -> void:
	var target: int = _world_target
	var nujio: WorldChunk = ChunkBuilder.build(_plan, _plan.bosques.nujio_chunk[target])
	var rect: Rect2i = nujio.nujio_rect
	var radius: int = int(AdventureRules.balance().bosque_relation.nujio_rest_radius)
	assert_eq(radius, 6)
	var inside := Vector2i(rect.position.x - radius, rect.position.y)
	var outside := Vector2i(rect.position.x - radius - 1, rect.position.y)
	if not WorldChunk.in_bounds(outside):
		inside = Vector2i(rect.end.x - 1 + radius, rect.position.y)
		outside = inside + Vector2i.RIGHT
	assert_eq(AdventureRules.distance_to_nujio_world(nujio, inside), radius)
	assert_eq(AdventureRules.distance_to_nujio_world(nujio, outside), radius + 1)
	assert_true(AdventureRules.riutash_near_nujio_world(nujio, inside, target, true))
	assert_eq(AdventureRules.relation(target), 5, "+5")
	assert_false(AdventureRules.riutash_near_nujio_world(nujio, outside, target, true), "a 7 casillas no")
	assert_false(AdventureRules.riutash_near_nujio_world(nujio, inside, target, false), "expuesto no")
	assert_eq(AdventureRules.relation(target), 5)
	var plain := WorldChunk.new()
	assert_false(AdventureRules.riutash_near_nujio_world(plain, inside, target, true), "chunk sin Nujio")


func test_villa_plaza_counts_as_near_its_nujio() -> void:
	var home: int = _plan.bosque_at(_plan.home_chunk)
	var villa: WorldChunk = ChunkBuilder.build(_plan, _plan.bosques.nujio_chunk[home])
	assert_true(villa.has_villa)
	var radius: int = int(AdventureRules.balance().bosque_relation.nujio_rest_radius)
	var far_plaza := Vector2i(-1, -1)
	var any_plaza := Vector2i(-1, -1)
	for i: int in WorldChunk.CELLS:
		var c: Vector2i = WorldCoords.index_to_cell(i)
		if villa.get_ground(c) == WorldChunk.Ground.PLAZA:
			any_plaza = c
			if AdventureRules.distance_to_nujio_world(villa, c) > radius:
				far_plaza = c
	assert_ne(any_plaza, Vector2i(-1, -1))
	var plaza: Vector2i = far_plaza if far_plaza.x >= 0 else any_plaza
	assert_true(AdventureRules.is_near_nujio_world(villa, plaza), "la plaza de la villa cuenta")
	assert_true(AdventureRules.riutash_near_nujio_world(villa, plaza, home, true))
	assert_eq(AdventureRules.relation(home), 5)


# --- Misiones, defensa, topes y marca de enojo ---------------------------------------------------

func test_home_mission_reward_adds_25_with_the_home_bosque() -> void:
	AdventureRules.apply_quest_reward({ "xp": 0 }, _home)
	assert_eq(AdventureRules.relation(_home), 25)
	assert_eq(AdventureRules.relation(_target), 0, "solo el de la misión")
	AdventureRules.apply_quest_reward({ "xp": 0 })
	assert_eq(AdventureRules.relation(_home), 25, "sin Bosque, nada")
	AdventureRules.reward_bosque_mission(_target)
	assert_eq(AdventureRules.relation(_target), 25)
	AdventureRules.reward_bosque_defense(_target)
	assert_eq(AdventureRules.relation(_target), 40, "defenderlo: +15")


func test_relation_is_capped_and_marks_angry_candidates() -> void:
	AdventureRules.change_relation(_target, 250)
	assert_eq(AdventureRules.relation(_target), 100, "tope superior")
	AdventureRules.change_relation(_target, -149)
	assert_eq(AdventureRules.relation(_target), -49)
	assert_false(AdventureRules.is_angry_candidate(_target), "-49: aún no")
	AdventureRules.change_relation(_target, -1)
	assert_true(AdventureRules.is_angry_candidate(_target), "-50: candidato a enojarse")
	AdventureRules.change_relation(_target, -500)
	assert_eq(AdventureRules.relation(_target), -100, "tope inferior")
	AdventureRules.change_relation(_target, 120)
	assert_true(AdventureRules.is_angry_candidate(_target), "la marca se queda")
	assert_eq(GameState.angry_candidate, [_target] as Array[int], "sin repetidos")


# --- Guardado v12 y migración -------------------------------------------------------------------

func test_save_v12_round_trip() -> void:
	var other: int = _map.neighbours_of(_home)[1]
	_pass_riutash()
	AdventureRules.pay_toll(_target, 0)
	GameState.bosque_relation[str(other)] = 70
	AdventureRules.pay_toll(other, 0)
	AdventureRules.change_relation(_home, -60)
	assert_eq(SaveManager.save_game(SAVE_SLOT), OK)
	GameState.new_game(1)
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	assert_eq(int(GameState.to_dict().save_version), GameState.SAVE_VERSION)
	assert_eq(GameState.riutash_count, 1)
	assert_eq(GameState.open_until, { str(_target): 3, str(other): AdventureRules.OPEN_PERMANENT })
	assert_eq(GameState.angry_candidate, [_home] as Array[int])
	assert_eq(AdventureRules.open_riutash_left(_target), 2)


func test_migration_from_v11_opens_until_the_second_riutash_or_permanently() -> void:
	var other: int = _map.neighbours_of(_home)[1]
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	data.save_version = 11
	for key in ["open_until", "riutash_count", "angry_candidate"]:
		data.erase(key)
	data.open_bosques = [_target, other]
	data.forced_bosques = [_target, 7]
	data.bosque_relation = { str(other): 75, "9": -55 }
	GameState.from_dict(data)
	assert_eq(GameState.riutash_count, 0)
	assert_eq(AdventureRules.open_riutash_left(_target), 2, "hasta el segundo riutash desde la carga")
	assert_true(AdventureRules.is_open_permanent(other), "amistad alta: permanente")
	assert_eq(GameState.forced_bosques, [7] as Array[int], "lo pagado en la v11 no estaba forzado")
	assert_eq(GameState.angry_candidate, [9] as Array[int], "ya en -55: candidato")
	_pass_riutash()
	_pass_riutash()
	assert_false(AdventureRules.is_paid(_target, _home), "y caduca")
	assert_true(AdventureRules.is_paid(other, _home))


func test_v12_ignores_a_stray_open_bosques_list() -> void:
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	data.open_bosques = [_target]
	data.open_until = { "3": -7, "4": 5 }
	GameState.from_dict(data)
	assert_false(AdventureRules.is_open(_target))
	assert_true(AdventureRules.is_open_permanent(3), "negativo = permanente")
	assert_eq(int(GameState.open_until["4"]), 5)
