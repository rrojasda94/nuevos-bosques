extends GutTest
## El Bosque recuerda (reglas del dueño 0.3): vencer a un Botarramas fuerza el Bosque sin pagarlo
## (se cruza, pero sus demás Botarramas siguen activos), la hostilidad sube el peaje y la visión,
## la relación baja y sube, Ofrecer Luz paga el peaje y termina la pelea, el Ofomni descarriado de
## la misión no acepta pagos y el guardado v9 (con migración desde v8).

const Battle = preload("res://scripts/rpg/battle.gd")
const Crossing = preload("res://scripts/rpg/crossing.gd")
const Screen = preload("res://scripts/rpg/inventory_screen.gd")
const Q: StringName = &"primera_mision"

var _map: BosqueMap
var _home: int
var _target: int


func before_all() -> void:
	var region: Dictionary = ChunkGenerator.load_region(&"valle_del_sara")
	_map = BosqueMap.for_region(42, region)
	_home = AdventureRules.home_bosque(_map, region)
	_target = _map.neighbours_of(_home)[0]


func before_each() -> void:
	GameState.new_game(42)


func _win(bosque_id: int, d: int = 1) -> void:
	var logic: BattleLogic = AdventureRules.start_battle(bosque_id, d)
	logic.result = BattleLogic.Result.VICTORY
	assert_eq(AdventureRules.finish_battle(logic, bosque_id), &"victory")


func _guardian(field: MonsterField, bosque_id: int, cell: Vector2i) -> OverworldMonster:
	var m := OverworldMonster.new()
	m.monster_id = MonsterField.BOTARRAMAS
	m.bosque_id = bosque_id
	m.key = "puesto_%d_%d" % [cell.x, cell.y]
	m.cell = cell
	m.cfg = MonsterField.guardian_config(AdventureRules.monster_config(MonsterField.BOTARRAMAS), bosque_id)
	field.add_child(m)
	field._monsters.append(m)
	return m


func test_victory_forces_the_bosque_and_other_botarramas_stay_active() -> void:
	var field: MonsterField = add_child_autofree(MonsterField.new())
	field._home = _home
	var beaten: OverworldMonster = _guardian(field, _target, Vector2i(5, 5))
	var other: OverworldMonster = _guardian(field, _target, Vector2i(40, 40))
	_win(_target)
	field.dissolve(beaten)
	assert_true(AdventureRules.is_forced(_target))
	assert_false(AdventureRules.is_paid(_target, _home), "vencer no paga")
	assert_true(AdventureRules.is_passable(_target, _home), "su frontera se cruza")
	assert_true(field._can_detect(other), "los demás Botarramas siguen activos")
	assert_true(field.occupied(Vector2i(40, 40)), "y cierran el paso")
	assert_true(MonsterSteering.engages(other.cell, Vector2i(41, 41), field._can_detect(other), other.cfg),
		"te interceptan y exigen el pago")


func test_paying_in_a_forced_bosque_makes_it_paid_and_passive() -> void:
	var field: MonsterField = add_child_autofree(MonsterField.new())
	field._home = _home
	var other: OverworldMonster = _guardian(field, _target, Vector2i(40, 40))
	_win(_target)
	var toll: int = AdventureRules.toll_for(_target, 1)
	assert_true(AdventureRules.pay_toll(_target, toll))
	assert_true(AdventureRules.is_paid(_target, _home))
	assert_false(AdventureRules.is_forced(_target), "deja de estar forzado")
	assert_false(field._can_detect(other), "pasivo")
	assert_false(field.occupied(Vector2i(40, 40)))


func test_crossing_menu_only_skips_paid_bosques() -> void:
	_win(_target)
	assert_eq(Crossing.title_for(_target), "El Bosque te observa. Su Nujio exige Luz.\nEl Bosque recuerda tu violencia.")
	assert_eq(Crossing.title_for(_home), "El Bosque te observa. Su Nujio exige Luz.", "sin hostilidad, sin aviso")


func test_toll_rises_with_hostility_up_to_the_cap() -> void:
	var m: Dictionary = AdventureRules.balance().bosque_memory
	assert_eq(AdventureRules.toll_for(_target, 1), 4, "3 + 1 sin hostilidad")
	_win(_target)
	assert_eq(AdventureRules.hostility(_target), 1)
	assert_eq(AdventureRules.toll_for(_target, 1), 4 + int(m.hostility_toll))
	_win(_target)
	assert_eq(AdventureRules.toll_for(_target, 1), 4 + 2 * int(m.hostility_toll))
	for i in 5:
		_win(_target)
	assert_eq(AdventureRules.hostility(_target), 7, "la hostilidad sigue contando")
	assert_eq(AdventureRules.toll_for(_target, 1), int(m.toll_max), "tope del peaje")
	assert_eq(AdventureRules.toll_for(_home, 1), 4, "cada Bosque recuerda lo suyo")
	GameState.bosque_hostility[str(_target)] = 3
	assert_eq(AdventureRules.toll_for(_target, 9), AdventureRules.toll_cost(9), "lejos: el tope no lo baja")
	var logic: BattleLogic = AdventureRules.start_battle(_target, 1)
	assert_eq(logic.toll, int(m.toll_max), "el combate usa el peaje con hostilidad")


func test_ofrenda_lowers_hostility_and_toll_but_luz_does_not() -> void:
	_win(_target)
	_win(_target)
	assert_eq(AdventureRules.toll_for(_target, 1), 8)
	GameState.luz = 10
	assert_true(AdventureRules.pay_toll(_target, 8))
	assert_eq(AdventureRules.hostility(_target), 2, "pagar con Luz no borra la hostilidad")
	InventoryLogic.add(GameState.bag, &"figura_sarua")
	assert_true(AdventureRules.pay_toll_with_ofrenda(_target, 8, 0))
	assert_eq(AdventureRules.hostility(_target), 1, "el Bosque olvida con ofrendas")
	assert_eq(AdventureRules.toll_for(_target, 1), 6, "el peaje vuelve a bajar")
	var r: int = int(AdventureRules.monster_config(MonsterField.BOTARRAMAS).vision_radius)
	assert_eq(AdventureRules.vision_radius(_target, r), r + 2, "y la visión")
	# En combate, con la acción Ofrenda.
	var other: int = _home
	GameState.bosque_hostility[str(other)] = 1
	InventoryLogic.add(GameState.bag, &"figura_sarua")
	var logic: BattleLogic = AdventureRules.start_battle(other, 1)
	logic.offer_ofrenda(logic.payable_ofrendas()[0])
	assert_eq(AdventureRules.finish_battle(logic, other), &"appeased")
	assert_eq(AdventureRules.hostility(other), 0)
	InventoryLogic.add(GameState.bag, &"figura_sarua")
	AdventureRules.pay_toll_with_ofrenda(other, 4, 0)
	assert_eq(AdventureRules.hostility(other), 0, "no baja de 0")


func test_vision_rises_with_hostility_and_has_a_cap() -> void:
	var base: Dictionary = AdventureRules.monster_config(MonsterField.BOTARRAMAS)
	var r: int = int(base.vision_radius)
	assert_eq(MonsterField.guardian_config(base, _target).vision_radius, r)
	_win(_target)
	assert_eq(AdventureRules.vision_radius(_target, r), r + 2)
	_win(_target)
	_win(_target)
	assert_eq(AdventureRules.vision_radius(_target, r), r + 6)
	_win(_target)
	assert_eq(AdventureRules.vision_radius(_target, r), r + 6, "tope de +6")
	var cfg: Dictionary = MonsterField.guardian_config(base, _target)
	assert_eq(int(cfg.vision_radius), r + 6)
	assert_gte(int(cfg.leash), int(cfg.vision_radius), "la correa no corta la persecución")
	assert_eq(int(base.vision_radius), r, "no toca los datos compartidos")


func test_dissolve_refreshes_vision_of_the_others() -> void:
	var field: MonsterField = add_child_autofree(MonsterField.new())
	field._home = _home
	var beaten: OverworldMonster = _guardian(field, _target, Vector2i(5, 5))
	var other: OverworldMonster = _guardian(field, _target, Vector2i(40, 40))
	var r: int = int(other.cfg.vision_radius)
	_win(_target)
	field.dissolve(beaten)
	assert_eq(int(other.cfg.vision_radius), r + 2, "mira, observa")


func test_relation_drops_on_kill_and_rises_on_payment() -> void:
	var m: Dictionary = AdventureRules.balance().bosque_memory
	assert_eq(AdventureRules.relation(_target), 0)
	_win(_target)
	assert_eq(AdventureRules.relation(_target), int(m.relation_per_kill))
	AdventureRules.pay_toll(_target, 0)
	assert_eq(AdventureRules.relation(_target), int(m.relation_per_kill) + int(m.relation_per_payment))
	InventoryLogic.add(GameState.bag, &"figura_sarua")
	AdventureRules.pay_toll_with_ofrenda(_home, 4, 0)
	assert_eq(AdventureRules.relation(_home), int(m.relation_per_payment), "la ofrenda también suma")
	for i in 20:
		AdventureRules.change_relation(_target, -10)
	assert_eq(AdventureRules.relation(_target), -AdventureRules.relation_max(), "tope inferior")
	assert_eq(Screen.relation_line(_target), "Relación Bosque -100")
	assert_eq(Screen.relation_line(-1), "", "fuera de la región, sin línea")


func test_offer_luz_in_battle_appeases_and_pays() -> void:
	_win(_target)
	GameState.luz = 9
	var logic: BattleLogic = AdventureRules.start_battle(_target, 1)
	assert_eq(logic.toll, 6, "4 + 2 de hostilidad")
	assert_true(logic.can_offer_luz())
	assert_eq(Battle.menu_options(logic)[Battle.OFFER_LUZ_OPTION], "Ofrecer 6 Luz")
	var events: Array[Dictionary] = logic.play_turn(BattleLogic.Action.OFFER_LUZ)
	var msgs: Array[Dictionary] = Battle.messages_for(events, logic.balance)
	assert_eq(msgs[0].text, "Ofreces 6 de Luz al Bosque.")
	assert_eq(msgs[1].text, "El Único se aparta. El paso queda abierto.")
	var xp: int = GameState.xp
	assert_eq(AdventureRules.finish_battle(logic, _target), &"appeased")
	assert_eq(GameState.luz, 3)
	assert_eq(GameState.xp, xp, "no da XP")
	assert_true(AdventureRules.is_paid(_target, _home), "el Bosque queda pagado")
	assert_false(AdventureRules.is_forced(_target))
	assert_eq(AdventureRules.hostility(_target), 1, "apaciguar no suma hostilidad")


func test_offer_luz_disabled_without_enough_luz() -> void:
	GameState.luz = 3
	var logic: BattleLogic = AdventureRules.start_battle(_target, 1)
	assert_false(logic.can_offer_luz(), "3 no llega a 4")
	assert_eq(Battle.menu_options(logic)[Battle.OFFER_LUZ_OPTION], "Ofrecer 4 Luz", "el coste se ve igualmente")
	assert_eq(Battle.blocked_text(logic, BattleLogic.Action.OFFER_LUZ), "", "sin texto: solo falta Luz")
	assert_eq(logic.play_turn(BattleLogic.Action.OFFER_LUZ), [] as Array[Dictionary])


func test_descarriado_refuses_luz_and_ofrendas_but_bosque_ofomni_accepts() -> void:
	var q: Dictionary = QuestLogic.new_quest()
	q.state = String(QuestLogic.ACTIVE)
	q.ofomni_d = 4
	GameState.quests[Q] = q
	InventoryLogic.add(GameState.bag, &"figura_sarua")
	var logic: BattleLogic = AdventureRules.start_quest_battle(Q, 4)
	assert_false(logic.can_offer_luz())
	assert_false(logic.can_offer_ofrenda())
	assert_eq(Battle.menu_options(logic)[Battle.OFFER_LUZ_OPTION], "Ofrecer Luz")
	assert_eq(Battle.blocked_text(logic, BattleLogic.Action.OFFER_LUZ), "El Ofomni descarriado no atiende a tu Luz.")
	assert_eq(logic.unico_max_hp, 24, "d = 4: 34 x 0,7")
	assert_eq(AdventureRules.make_monster(&"ofomni_descarriado", 5).max_hp, 27, "d = 5: 38 x 0,7")
	assert_eq(QuestLogic.data(Q).target, "ofomni_descarriado")
	assert_false(AdventureRules.is_appeasable(AdventureRules.monster_config(&"ofomni_descarriado")))
	var bosque_ofomni: Dictionary = AdventureRules.monster_config(&"ofomni")
	assert_true(AdventureRules.is_appeasable(bosque_ofomni), "el Ofomni de un Bosque se apacigua")
	assert_eq(AdventureRules.monster_name(&"ofomni"), "Ofomni")
	assert_eq(AdventureRules.make_monster(&"ofomni", 4).max_hp, 34, "sin rebaja de PV")
	var appeasable: BattleLogic = AdventureRules.start_battle(_target, 1, &"ofomni")
	assert_true(appeasable.accepts_payment)
	assert_true(appeasable.can_offer_luz())


func test_save_v9_round_trip() -> void:
	_win(_target)
	AdventureRules.pay_toll(_home, 0)
	var other: int = _map.neighbours_of(_home)[1] if _map.neighbours_of(_home).size() > 1 else _target
	GameState.forced_bosques.append(other)
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	assert_eq(int(data.save_version), GameState.SAVE_VERSION)
	GameState.new_game(1)
	GameState.from_dict(data)
	assert_true(GameState.forced_bosques.has(_target))
	assert_eq(AdventureRules.hostility(_target), 1)
	assert_eq(AdventureRules.relation(_target), -10)
	assert_eq(AdventureRules.relation(_home), 1)


func test_migration_from_v8() -> void:
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	data.save_version = 8
	for key in ["forced_bosques", "bosque_hostility", "bosque_relation"]:
		data.erase(key)
	data.open_bosques = [_target]
	data.objective_label = "Ofomni"
	data.seen_monsters = { "primera_mision": { "monster": "ofomni", "bosque_id": -1, "chunk": [1, 1] } }
	GameState.from_dict(data)
	assert_eq(GameState.forced_bosques, [] as Array[int], "lo abierto en v8 sigue pagado")
	assert_true(AdventureRules.is_paid(_target, _home))
	assert_eq(GameState.bosque_hostility, {})
	assert_eq(GameState.bosque_relation, {})
	assert_eq(GameState.objective_label, "Ofomni descarriado", "la brújula usa el nombre nuevo")
	assert_eq(GameState.seen_monsters.primera_mision.monster, "ofomni_descarriado")


func test_load_sanitizes_memory() -> void:
	var data: Dictionary = GameState.to_dict()
	data.open_bosques = [_target]
	data.forced_bosques = [_target, 7, 7]
	data.bosque_relation = { "3": 500, "4": -500 }
	data.bosque_hostility = "basura"
	GameState.from_dict(data)
	assert_eq(GameState.forced_bosques, [7] as Array[int], "pagado gana a forzado; sin repetidos")
	assert_eq(AdventureRules.relation(3), 100)
	assert_eq(AdventureRules.relation(4), -100)
	assert_eq(GameState.bosque_hostility, {})
