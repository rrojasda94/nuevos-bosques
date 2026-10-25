extends GutTest
## Reparep en el mundo (BosquePatrols.reparep_group_of, MonsterField) y otros adoc como aliados
## (AdocEncounters, otros-adoc.md); Único aliado en un Bosque que necesita ayuda
## (AdventureRules.bosque_allies); guardado v16 con migración; la lanza empieza guardada.

const EXPLORATION: String = "res://scenes/world/exploration.tscn"

var _region: Dictionary
var _map: BosqueMap
var _home: int


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"valle_del_sara")
	_map = BosqueMap.for_region(42, _region)
	_home = AdventureRules.home_bosque(_map, _region)


func before_each() -> void:
	WorldClock.set_process(false)
	WorldClock.shelter_check = Callable()
	GameState.new_game(42)


func after_each() -> void:
	get_tree().paused = false
	WorldClock.set_process(true)


func _force(bosque_id: int, state: String) -> void:
	GameState.bosque_state_overrides[str(bosque_id)] = state


## Primer Bosque (no natal) con un grupo de reparep.
func _bosque_with_reparep() -> int:
	for id: int in _map.count():
		if not BosquePatrols.reparep_group_of(_map, 42, id).is_empty():
			return id
	return -1


func test_reparep_groups_are_2_to_4_never_home_and_deterministic() -> void:
	assert_true(BosquePatrols.reparep_group_of(_map, 42, _home).is_empty(), "nunca en el natal")
	var found: int = 0
	for id: int in _map.count():
		var g: Dictionary = BosquePatrols.reparep_group_of(_map, 42, id)
		if g.is_empty():
			continue
		found += 1
		assert_between(int(g.count), 2, 4)
		assert_eq(g.monster, &"reparep")
		assert_eq(_map.bosque_at(g.chunk), id, "en un chunk de su Bosque")
		assert_eq(BosquePatrols.reparep_group_of(_map, 42, id), g, "determinista")
	assert_gt(found, 0)


func test_reparep_out_at_night_or_always_in_dangerous_states() -> void:
	var id: int = _bosque_with_reparep()
	_force(id, BosqueStates.SANO)
	var g: Dictionary = BosquePatrols.reparep_group_of(_map, 42, id)
	if g.is_empty():
		_force(id, BosqueStates.MUERTO)
		g = BosquePatrols.reparep_group_of(_map, 42, id)
	var ids_day: Array = BosquePatrols.patrols_in(_map, 42, g.chunk, TimeConfig.GIETOS).map(func(p: Dictionary) -> String: return p.id)
	var ids_night: Array = BosquePatrols.patrols_in(_map, 42, g.chunk, TimeConfig.RIUMNA).map(func(p: Dictionary) -> String: return p.id)
	assert_true(ids_night.has(g.id), "de noche está fuera")
	assert_eq(ids_day.has(g.id), not g.night, "de día solo si su estado lo saca siempre")
	for state in [BosqueStates.CORRUPTO, BosqueStates.MUERTO, BosqueStates.NECESITA_AYUDA]:
		_force(id, state)
		var always: Dictionary = BosquePatrols.reparep_group_of(_map, 42, id)
		assert_false(always.is_empty(), state)
		assert_false(always.night, "%s: siempre fuera" % state)


func test_reparep_on_the_map_is_one_group_and_engages_the_whole_group() -> void:
	var id: int = _bosque_with_reparep()
	_force(id, BosqueStates.MUERTO)
	var g: Dictionary = BosquePatrols.reparep_group_of(_map, 42, id)
	GameState.chunk_coord = g.chunk
	GameState.player_cell = Vector2i(-1, -1)
	GameState.open_until[str(id)] = -1
	var expl: Node = load(EXPLORATION).instantiate()
	add_child_autofree(expl)
	expl.start()
	var field: MonsterField = expl.get_node("Monsters")
	var groups: Array = field.with_role(MonsterField.ROLE_PATROL).filter(func(m: OverworldMonster) -> bool: return m.monster_id == &"reparep")
	assert_eq(groups.size(), 1, "un solo monstruo para todo el grupo")
	var m: OverworldMonster = groups[0]
	assert_eq(m.count, int(g.count))
	assert_true(field.can_detect(m), "en un Bosque muerto los reparep atacan siempre")
	watch_signals(EventBus)
	expl._request_unico_battle(m, false)
	assert_signal_emitted_with_parameters(EventBus, "group_battle_requested", [id, &"reparep", int(g.count), false, ""])
	get_tree().paused = false


func test_reparep_passive_in_paid_sano_bosque_and_hostile_unpaid() -> void:
	var id: int = _bosque_with_reparep()
	_force(id, BosqueStates.SANO)
	var field := MonsterField.new()
	add_child_autofree(field)
	field._bosques = _map
	field._home = _home
	var m := OverworldMonster.new()
	autofree(m)
	m.monster_id = &"reparep"
	m.bosque_id = id
	m.role = MonsterField.ROLE_PATROL
	assert_true(field.can_detect(m), "sin pagar, persiguen")
	GameState.open_until[str(id)] = -1
	assert_false(field.can_detect(m), "pagado, pasivos")
	_force(id, BosqueStates.NECESITA_AYUDA)
	assert_true(field.can_detect(m), "en un Bosque que necesita ayuda, atacan aunque sus Únicos sean amistosos")


func test_reparep_victory_does_not_offend_the_bosque() -> void:
	var id: int = _bosque_with_reparep()
	var logic: BattleLogic = AdventureRules.start_battle(id, 2, &"reparep", 2)
	for e in logic.enemies:
		e.hp = 0
	logic.result = BattleLogic.Result.VICTORY
	assert_eq(AdventureRules.finish_unico_battle(logic, id, _home), &"victory")
	assert_eq(AdventureRules.hostility(id), 0, "no son Únicos del Bosque")
	assert_eq(AdventureRules.relation(id), 0)
	assert_eq(GameState.xp, 2 * 4)


func test_encounters_are_few_deterministic_and_never_home() -> void:
	var all: Array[Dictionary] = AdocEncounters.all(_map, 42)
	assert_gt(all.size(), 0)
	assert_lt(all.size(), _map.count() / 2, "pocas: 1 de cada pocos Bosques")
	for e: Dictionary in all:
		assert_ne(int(e.bosque_id), _home)
		assert_between(int(e.level), 1, 3)
		assert_true(AdocEncounters.data().names.has(e.name))
		assert_eq(AdocEncounters.encounter_of(_map, 42, int(e.bosque_id)), e)
		if e.enemy == &"reparep":
			assert_between(int(e.count), 2, 4)
		else:
			assert_eq(int(e.count), 1)


func test_paid_bosque_turns_unico_rival_into_reparep() -> void:
	var e: Dictionary = AdocEncounters.all(_map, 42)[0].duplicate()
	e.enemy = &"botarramas"
	e.count = 1
	assert_eq(AdocEncounters.with_enemy(e, false).enemy, &"botarramas")
	var welcome: Dictionary = AdocEncounters.with_enemy(e, true)
	assert_eq(welcome.enemy, &"reparep", "un Único pasivo no pelea")
	assert_between(int(welcome.count), 2, 4)


func test_helping_an_adoc_gives_relation_and_fama_and_resolves() -> void:
	var e: Dictionary = AdocEncounters.all(_map, 42)[0]
	var id: int = int(e.bosque_id)
	var ally: Dictionary = AdocEncounters.ally_of(e)
	var stats: Dictionary = AdventureRules.adoc_stats(int(e.level))
	assert_eq([ally.atk, ally.def, ally.max_hp], [stats.atk, stats.def, stats.max_hp], "ATQ y DEF de su nivel")
	var allies: Array[Dictionary] = [ally]
	var logic: BattleLogic = AdventureRules.start_battle(id, 2, &"reparep", 3, allies)
	assert_eq(logic.allies[0].name, e.name)
	assert_eq(logic.allies[0].kind, &"adoc")
	for en in logic.enemies:
		en.hp = 0
	logic.result = BattleLogic.Result.VICTORY
	var before_rel: int = AdventureRules.relation(id)
	var outcome: StringName = AdventureRules.finish_unico_battle(logic, id, _home)
	var lines: PackedStringArray = AdocEncounters.finish(e, outcome)
	assert_eq(AdventureRules.relation(id), before_rel + 5, "relación +5")
	assert_eq(GameState.fama, 1, "fama +1")
	assert_eq(lines[0], "%s: ¡Gracias, adoc! Sin ti no lo habría contado. El Bosque lo recordará." % e.name)
	assert_true(AdocEncounters.is_resolved(e.id))
	assert_true(AdocEncounters.encounter_in(_map, 42, e.chunk, false).is_empty(), "no vuelve")


func test_losing_or_fleeing_with_the_adoc_only_resolves() -> void:
	var e: Dictionary = AdocEncounters.all(_map, 42)[0]
	var lines: PackedStringArray = AdocEncounters.finish(e, &"fled")
	assert_eq(GameState.fama, 0)
	assert_eq(GameState.adoc_encounters[e.id], AdocEncounters.RETIRED)
	assert_string_contains(lines[0], "se retira")


func test_encounter_in_the_world_and_help_flow() -> void:
	var e: Dictionary = AdocEncounters.all(_map, 42)[0]
	GameState.chunk_coord = e.chunk
	GameState.player_cell = Vector2i(-1, -1)
	GameState.open_until[str(e.bosque_id)] = -1
	var expl: Node = load(EXPLORATION).instantiate()
	add_child_autofree(expl)
	expl.start()
	var field: MonsterField = expl.get_node("Monsters")
	var duels: Array[OverworldMonster] = field.with_role(MonsterField.ROLE_DUEL)
	assert_eq(duels.size(), 1, "el rival del adoc")
	assert_false(field.can_detect(duels[0]), "no hace caso al jugador")
	assert_true(field.occupied(duels[0].cell))
	assert_eq(expl._npcs.values().count(AdocEncounters.NPC_ID), 1, "el adoc bloquea su casilla")
	watch_signals(EventBus)
	expl._on_adoc_encounter_choice(0, expl._encounter)
	assert_signal_emitted(EventBus, "group_battle_requested")
	var params: Array = get_signal_parameters(EventBus, "group_battle_requested")
	assert_eq(params[4], e.id, "con el adoc como aliado")
	get_tree().paused = false


func test_bosque_in_need_sends_one_unico_ally_against_reparep() -> void:
	var id: int = _map.neighbours_of(_home)[0]
	_force(id, BosqueStates.NECESITA_AYUDA)
	var logic: BattleLogic = AdventureRules.start_battle(id, 2, &"reparep", 3)
	assert_eq(logic.allies.size(), 1, "1 Único del Bosque a tu lado")
	assert_eq(logic.allies[0].kind, &"botarramas")
	assert_eq(logic.allies[0].name, "Botarramas aliado")
	_force(id, BosqueStates.SANO)
	assert_eq(AdventureRules.start_battle(id, 2, &"reparep", 3).allies.size(), 0, "sano: sin aliados")
	_force(id, BosqueStates.NECESITA_AYUDA)
	assert_eq(AdventureRules.start_battle(id, 2, &"botarramas").allies.size(), 0, "no contra sus propios Únicos")
	var e: Dictionary = AdocEncounters.all(_map, 42)[0]
	_force(int(e.bosque_id), BosqueStates.NECESITA_AYUDA)
	var both: Array[Dictionary] = [AdocEncounters.ally_of(e)]
	assert_eq(AdventureRules.start_battle(int(e.bosque_id), 2, &"reparep", 2, both).allies.size(), 2, "el adoc y el Único")


func test_save_v16_round_trip_and_migration() -> void:
	GameState.adoc_encounters["adoc:3"] = AdocEncounters.HELPED
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	assert_gte(int(data.save_version), 16)
	GameState.new_game(1)
	GameState.from_dict(data)
	assert_eq(GameState.adoc_encounters, { "adoc:3": "helped" })
	data.save_version = 15
	data.erase("adoc_encounters")
	GameState.from_dict(data)
	assert_eq(GameState.adoc_encounters, {}, "v15: ningún encuentro resuelto")


func test_new_game_starts_with_the_spear_in_the_bag() -> void:
	assert_false(AdventureRules.is_armed(), "la lanza empieza guardada")
	assert_gt(InventoryLogic.count(GameState.bag, &"lanza_de_adoc"), 0, "en la bolsa")
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	data.save_version = 10
	data.erase("bag")
	data.erase("equipped")
	data.inventory = []
	GameState.from_dict(data)
	assert_eq(GameState.equipped.main_hand, "lanza_de_adoc", "las partidas antiguas siguen con la lanza equipada")


func test_reparep_and_adoc_art() -> void:
	var style := { "shape": 0, "leaf": 2, "trunk": 1, "ground": 0 }
	assert_eq(UnicoArt.kind_for(&"reparep"), UnicoArt.Kind.REPAREP)
	var img: Image = UnicoArt.texture(UnicoArt.Kind.REPAREP, style, 40).get_image()
	var translucent: bool = false
	for y in 40:
		for x in 40:
			var a: float = img.get_pixel(x, y).a
			if a > 0.0 and a < 1.0:
				translucent = true
	assert_true(translucent, "fantasmal: semitransparente")
	var group: Image = UnicoArt.group_texture(style, 4, 32).get_image()
	assert_eq(group.get_size(), Vector2i(32, 32))
	var adoc: Image = AdocNpc.frame_texture({ "light": "0099db", "dark": "124e89" }, Vector2i.DOWN).get_image()
	var has_clothes: bool = false
	for y in adoc.get_height():
		for x in adoc.get_width():
			if adoc.get_pixel(x, y).to_html(false) == "0099db":
				has_clothes = true
	assert_true(has_clothes, "otra ropa")
