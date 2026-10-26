extends GutTest
## Dormir, Pensamiento y misiones lejanas con salvoconducto (bosques-y-relacion.md, "Dormir y
## Pensamiento", #136): dormir de noche salta al amanecer y cura como en refugio (en la villa, del
## todo); de día cuesta Luz y sin ella no se puede; solo en refugios y villas; el Ofomni descarriado
## avanza mientras duermes; visión determinista que crea la misión; ruta de salvoconducto solo por
## Bosques buenos (no siempre la más corta); peaje 0 en la ruta y en el Bosque que llama; completar
## da +25 de relación, fama y Luz; guardado v17 con migración desde la v16.

const EXPLORATION: String = "res://scenes/world/exploration.tscn"
const SAVE_SLOT: int = 93
const Q: StringName = QuestLogic.PRIMERA_MISION

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
	GameState.equipped.main_hand = ""


func after_each() -> void:
	get_tree().paused = false
	WorldClock.set_process(true)


func after_all() -> void:
	DirAccess.remove_absolute(SaveManager.slot_path(SAVE_SLOT))


func _exploration() -> Node:
	var expl: Node = load(EXPLORATION).instantiate()
	add_child_autofree(expl)
	expl.start()
	return expl


func _night(elapsed: float = 100.0) -> void:
	GameState.clock_momento = TimeConfig.RIUMNA
	GameState.clock_elapsed = elapsed


func _day(elapsed: float = 0.0) -> void:
	GameState.clock_momento = TimeConfig.GIETOS
	GameState.clock_elapsed = elapsed


## Un refugio fuera de una villa en el Bosque natal: [chunk, casilla].
func _refuge_outside_villa() -> Array:
	for coord: Vector2i in _map.refuge_chunks():
		if _map.bosque_at(coord) != _home:
			continue
		var chunk: ChunkData = ChunkGenerator.generate(42, coord, _region, _map)
		if chunk.has_villa:
			continue
		for y: int in ChunkData.SIZE:
			for x: int in ChunkData.SIZE:
				if chunk.is_refuge(Vector2i(x, y)):
					return [coord, Vector2i(x, y)]
	return []


## Primer día con visión desde el Bosque `from` (0 si no hay en 60 días).
func _vision_day(from: int) -> int:
	for day: int in range(1, 61):
		if not FarQuests.vision_for(_map, 42, day, from).is_empty():
			return day
	return 0


# --- Dormir ----------------------------------------------------------------------------------------

func test_night_sleep_jumps_to_dawn_and_heals_like_a_refuge() -> void:
	var expl: Node = _exploration()
	var spot: Array = _refuge_outside_villa()
	assert_false(spot.is_empty(), "hay un refugio fuera de la villa en el natal")
	expl._enter_chunk(spot[0], spot[1])
	assert_eq(expl._player.cell, spot[1] as Vector2i)
	_night(100.0)
	GameState.hp = 10
	var luz: int = GameState.luz
	var slept: Dictionary = expl.sleep_now()
	assert_false(slept.is_empty())
	assert_true(bool(slept.night))
	assert_almost_eq(float(slept.seconds), TimeConfig.duration(TimeConfig.RIUMNA) - 100.0, 0.01)
	assert_eq(GameState.clock_momento, TimeConfig.GIETOS, "despierta al amanecer")
	assert_almost_eq(GameState.clock_elapsed, 0.0, 0.01)
	var max_hp: int = AdventureRules.max_hp()
	assert_eq(GameState.hp, AdventureRules.riutash_hp(10, max_hp, true), "cura como refugiado: 50% de lo que falta")
	assert_eq(GameState.hp, 10 + ceili((max_hp - 10) * 0.5))
	assert_eq(GameState.luz, luz, "de noche es gratis")


func test_night_sleep_in_the_villa_heals_fully() -> void:
	var expl: Node = _exploration()
	assert_true(AdventureRules.is_villa_rest(expl._chunk, expl._player.cell), "empieza junto al Nujio de la villa")
	_night()
	GameState.hp = 3
	assert_false(expl.sleep_now().is_empty())
	assert_eq(GameState.hp, AdventureRules.max_hp(), "en la villa cura del todo")


func test_day_sleep_costs_luz_and_is_disabled_without_it() -> void:
	_day(0.0)
	assert_eq(SleepRules.day_cost(480.0), 4, "8 min: 4 de Luz")
	assert_eq(SleepRules.day_cost(180.0), 2, "3 min: 2 (redondeo hacia arriba)")
	assert_eq(SleepRules.day_cost(10.0), 1)
	assert_eq(SleepRules.day_cost(9999.0), 4, "como mucho 4")
	assert_eq(SleepRules.cost_now(), 4)
	_night()
	assert_eq(SleepRules.cost_now(), 0, "de noche no cuesta")
	_day(300.0)
	assert_eq(SleepRules.cost_now(), 2, "quedan 180 s")
	GameState.luz = 1
	assert_false(SleepRules.can_afford())
	assert_eq(SleepRules.sleep(false), {}, "sin Luz no se duerme")
	assert_eq(GameState.clock_momento, TimeConfig.GIETOS, "ni pasa el tiempo")
	assert_almost_eq(GameState.clock_elapsed, 300.0, 0.01)
	GameState.luz = 10
	var slept: Dictionary = SleepRules.sleep(false)
	assert_false(bool(slept.night))
	assert_eq(int(slept.cost), 2)
	assert_eq(GameState.luz, 8)
	assert_eq(GameState.clock_momento, TimeConfig.RIUMNA, "despierta al atardecer")


func test_day_sleep_in_the_scene_has_no_vision() -> void:
	var expl: Node = _exploration()
	_day(0.0)
	var day: int = _vision_day(_home)
	if day > 0:
		GameState.day = day
	var slept: Dictionary = expl.sleep_now()
	assert_eq(GameState.luz, AdventureRules.start_luz() - 4)
	assert_eq(slept.vision, {}, "de día no hay Pensamiento")
	assert_eq(GameState.last_vision_day, 0)


func test_cannot_sleep_outside_a_refuge_or_villa() -> void:
	var expl: Node = _exploration()
	var chunk: ChunkData = expl._chunk
	var grass := Vector2i(-1, -1)
	var plaza := Vector2i(-1, -1)
	for y: int in ChunkData.SIZE:
		for x: int in ChunkData.SIZE:
			var c := Vector2i(x, y)
			if grass.x < 0 and chunk.get_tile(c) == ChunkData.Tile.GRASS and not AdventureRules.is_villa_rest(chunk, c) \
					and chunk.is_reachable(c) and not expl._field.occupied(c):
				grass = c
			if plaza.x < 0 and chunk.get_tile(c) == ChunkData.Tile.PLAZA:
				plaza = c
	assert_true(SleepRules.can_sleep_at(chunk, plaza), "en la plaza de la villa")
	assert_false(SleepRules.can_sleep_at(chunk, grass), "en la hierba, no")
	expl._enter_chunk(chunk.coord, grass)
	assert_eq(expl._player.cell, grass)
	_night()
	assert_eq(expl.sleep_now(), {}, "fuera de refugio o villa no se duerme")
	assert_eq(GameState.clock_momento, TimeConfig.RIUMNA)
	var flat := ChunkData.new()
	flat.tiles.resize(ChunkData.SIZE * ChunkData.SIZE)
	flat.tiles.fill(ChunkData.Tile.GRASS)
	flat.set_tile(Vector2i(20, 20), ChunkData.Tile.REFUGE)
	assert_true(SleepRules.can_sleep_at(flat, Vector2i(20, 20)), "en un refugio")
	assert_false(SleepRules.can_sleep_at(flat, Vector2i(21, 20)), "al lado, no")
	assert_eq(Interaction.find(flat, Vector2i(30, 30), Vector2i.UP, {}).kind, Interaction.Kind.NONE)
	flat.has_villa = true
	flat.set_tile(Vector2i(30, 30), ChunkData.Tile.PLAZA)
	assert_eq(Interaction.find(flat, Vector2i(30, 30), Vector2i.UP, {}).kind, Interaction.Kind.REST, "E en la plaza: dormir")


func test_the_ofomni_advances_while_sleeping() -> void:
	var q: Dictionary = QuestLogic.new_quest()
	assert_true(QuestLogic.accept(q, _map, 42, _home))
	GameState.quests[Q] = q
	var expl: Node = _exploration()
	var from: int = int(q.ofomni_bosque)
	_day(0.0)
	assert_true(expl._quest.is_ofomni_active())
	expl.sleep_now()
	var every: float = float(QuestLogic.data(Q).ofomni.advance_seconds)
	var loaded: Dictionary = GameState.quests[Q]
	assert_eq(int(loaded.ofomni_bosque), QuestLogic.next_bosque(_map, 42, from, _home), "480 s: un Bosque más cerca")
	assert_almost_eq(float(loaded.ofomni_elapsed), 480.0 - every, 0.05)


func test_the_ofomni_reaching_the_villa_while_sleeping_fails_the_mission() -> void:
	var q: Dictionary = QuestLogic.new_quest()
	assert_true(QuestLogic.accept(q, _map, 42, _home))
	q.ofomni_bosque = _map.neighbours_of(_home)[0]
	q.ofomni_elapsed = 300.0
	GameState.quests[Q] = q
	var expl: Node = _exploration()
	_night(0.0)
	expl.sleep_now()
	assert_eq(QuestLogic.state_of(GameState.quests[Q]), QuestLogic.FAILED, "llega a la villa mientras duermes")
	assert_true(GameState.villa_damaged)


# --- Visión de Pensamiento ---------------------------------------------------------------------------

func test_vision_is_deterministic_and_creates_the_mission() -> void:
	var day: int = _vision_day(_home)
	assert_gt(day, 0, "la seed 42 tiene visiones")
	var a: Dictionary = FarQuests.vision_for(_map, 42, day, _home)
	assert_eq(FarQuests.vision_for(_map, 42, day, _home), a, "misma seed y día, misma visión")
	assert_true(FarQuests.has_vision(42, day))
	assert_gte(int(a.hops), FarQuests.min_hops(), "un Bosque lejano")
	assert_eq(_map.distance(_home, int(a.bosque)), int(a.hops))
	assert_true(FarQuests.types_for(_map, 42, int(a.bosque)).has(str(a.type)))
	assert_eq(a.target_chunk, FarQuests.objective_chunk(_map, 42, int(a.bosque), str(a.type)))
	var no_vision: int = 0
	for d: int in range(1, 61):
		if not FarQuests.has_vision(42, d):
			no_vision = d
			break
	assert_gt(no_vision, 0)
	assert_eq(FarQuests.vision_for(_map, 42, no_vision, _home), {}, "la mitad de las noches no hay visión")
	watch_signals(EventBus)
	var q: Dictionary = FarQuests.accept(_map, a, _home, day)
	assert_signal_emitted(EventBus, "quest_state_changed")
	assert_eq(GameState.far_quests.size(), 1)
	assert_true(FarQuests.is_active(q))
	var route: Array[int] = FarQuests.route_of(q)
	assert_eq(route.front(), _home)
	assert_eq(route.back(), int(a.bosque))
	assert_true(FarQuests.covers(int(a.bosque)))
	var again: Dictionary = FarQuests.vision_for(_map, 42, day, _home)
	assert_true(again.is_empty() or int(again.bosque) != int(a.bosque), "ese Bosque ya te llama: no repite")


func test_night_sleep_in_the_scene_brings_the_vision_once_per_day() -> void:
	var expl: Node = _exploration()
	var day: int = _vision_day(_home)
	GameState.day = day
	_night()
	var slept: Dictionary = expl.sleep_now()
	assert_false(slept.vision.is_empty(), "visión en Pensamiento")
	assert_eq(GameState.last_vision_day, day)
	assert_string_contains(expl._far.vision_text(slept.vision), str(int(slept.vision.hops)))
	var q: Dictionary = expl._far.accept(slept.vision, _home)
	assert_false(q.is_empty())
	assert_eq(int(q.day), day)
	assert_eq(expl._far.vision_after_sleep(day, _home), {}, "una visión por día")


func test_at_most_two_far_quests() -> void:
	var day: int = _vision_day(_home)
	for i: int in FarQuests.max_active():
		GameState.far_quests.append(FarQuests.new_quest(FarQuests.TYPE_FIRE, 1000 + i, Vector2i.ZERO, [] as Array[int], 1))
	assert_eq(FarQuests.vision_for(_map, 42, day, _home), {}, "con 2 activas no hay más visiones")


# --- Ruta de salvoconducto -------------------------------------------------------------------------

## Grafo construido: 0 - 1 - 4 es lo más corto, pero 1 es malo; 0 - 2 - 3 - 4 va por buenos.
func test_safe_route_only_through_good_bosques_and_not_always_the_shortest() -> void:
	var graph: Dictionary = { 0: [1, 2], 1: [0, 4], 2: [0, 3], 3: [2, 4], 4: [1, 3] }
	var neighbours := func(id: int) -> Array: return graph[id]
	var all_good := func(_id: int) -> bool: return true
	var good := func(id: int) -> bool: return id != 1
	assert_eq(FarQuests.safe_route(neighbours, 0, 4, all_good), [0, 1, 4] as Array[int], "la más corta")
	assert_eq(FarQuests.safe_route(neighbours, 0, 4, good), [0, 2, 3, 4] as Array[int], "más larga, por Bosques buenos")
	var none_good := func(id: int) -> bool: return id == 0
	assert_eq(FarQuests.safe_route(neighbours, 0, 4, none_good), [] as Array[int], "sin ruta buena")
	assert_eq(FarQuests.safe_route(neighbours, 1, 4, none_good), [1, 4] as Array[int], "el destino puede no ser bueno")


func test_good_bosques_and_real_routes() -> void:
	var target: int = _map.neighbours_of(_home)[0]
	assert_true(FarQuests.is_good(_map, _home))
	assert_true(FarQuests.is_good(_map, target), "sano")
	GameState.bosque_state_overrides[str(target)] = BosqueStates.CORRUPTO
	assert_false(FarQuests.is_good(_map, target), "corrupto sin relación")
	GameState.bosque_relation[str(target)] = 30
	assert_true(FarQuests.is_good(_map, target), "corrupto con relación >= 30")
	GameState.bosque_state_overrides[str(target)] = BosqueStates.ENOJADO
	assert_false(FarQuests.is_good(_map, target), "enojado, nunca")
	GameState.bosque_state_overrides[str(target)] = BosqueStates.NECESITA_AYUDA
	GameState.bosque_relation[str(target)] = 0
	assert_true(FarQuests.is_good(_map, target), "necesita ayuda")
	GameState.bosque_state_overrides.erase(str(target))
	for id: int in _map.count():
		if _map.distance(_home, id) < FarQuests.min_hops():
			continue
		var route: Array[int] = FarQuests.route_for(_map, _home, id)
		if route.size() == 1:
			continue
		assert_eq(route.front(), _home)
		assert_eq(route.back(), id)
		for i: int in range(1, route.size()):
			assert_true(_map.neighbours_of(route[i - 1]).has(route[i]), "tramos entre vecinos")
		for i: int in range(1, route.size() - 1):
			assert_true(FarQuests.is_good(_map, route[i]), "solo por Bosques buenos")
		var path: Array[Vector2i] = FarQuests.route_path(_map, route)
		for i: int in range(1, path.size()):
			assert_eq(absi(path[i].x - path[i - 1].x) + absi(path[i].y - path[i - 1].y), 1, "la línea va de chunk en chunk")
			assert_true(route.has(_map.bosque_at(path[i])), "por los Bosques de la ruta")


func test_route_is_recalculated_when_a_bosque_turns_angry_and_compass_points_to_the_next() -> void:
	var day: int = _vision_day(_home)
	var q: Dictionary = FarQuests.accept(_map, FarQuests.vision_for(_map, 42, day, _home), _home, day)
	var route: Array[int] = FarQuests.route_of(q)
	assert_gt(route.size(), 2)
	assert_eq(FarQuests.next_step(q, _home), route[1])
	var compass: Vector2i = FarQuests.compass_chunk(_map, q, _map.nujio_chunk[_home])
	assert_eq(_map.bosque_at(compass), route[1], "la brújula apunta al siguiente Bosque de la ruta")
	assert_eq(FarQuests.compass_chunk(_map, q, FarQuests.target_chunk(q)), FarQuests.target_chunk(q))
	var line: Array[Vector2i] = FarQuests.map_path(_map, q)
	assert_eq(line.front(), _map.nujio_chunk[_home], "la línea del mapa sale del Nujio natal")
	assert_eq(line.back(), FarQuests.target_chunk(q), "y llega al objetivo")
	var middle: int = route[route.size() - 2]
	if middle == _home:
		return
	GameState.bosque_state_overrides[str(middle)] = BosqueStates.ENOJADO
	assert_false(FarQuests.is_route_valid(_map, q, _home))
	FarQuests.refresh_route(_map, q, _home)
	assert_false(FarQuests.route_of(q).has(middle), "el enojado sale de la ruta")


# --- Salvoconducto: peaje ----------------------------------------------------------------------------

func test_no_toll_on_the_route_nor_in_the_calling_bosque() -> void:
	var on_route: int = _map.neighbours_of(_home)[0]
	var caller: int = -1
	for id: int in _map.count():
		if id != _home and id != on_route and not _map.neighbours_of(_home).has(id):
			caller = id
			break
	GameState.bosque_state_overrides[str(caller)] = BosqueStates.CORRUPTO
	assert_gt(AdventureRules.toll_for(on_route, 1), 0)
	assert_gt(AdventureRules.toll_for(caller, 3), 0)
	assert_false(AdventureRules.is_paid(on_route, _home))
	var q: Dictionary = FarQuests.new_quest(FarQuests.TYPE_REPAREP, caller, _map.nujio_chunk[caller], [_home, on_route, caller] as Array[int], 1)
	GameState.far_quests.append(q)
	assert_eq(AdventureRules.toll_for(on_route, 1), 0, "en la ruta no se cobra")
	assert_eq(AdventureRules.toll_for(caller, 3), 0, "el Bosque que llama no cobra")
	assert_true(AdventureRules.is_paid(on_route, _home), "sus Botarramas dejan pasar como pagado")
	assert_true(AdventureRules.is_welcome(on_route, _home))
	assert_true(AdventureRules.is_passable(caller, _home))
	GameState.equipped.main_hand = "lanza_de_adoc"
	assert_false(AdventureRules.is_welcome(on_route, _home), "salvo que vayas armado")
	GameState.equipped.main_hand = ""
	FarQuests.fail(q)
	assert_gt(AdventureRules.toll_for(on_route, 1), 0, "al terminar la misión vuelve el peaje")
	assert_false(AdventureRules.is_paid(on_route, _home))


# --- Cumplir y fallar ------------------------------------------------------------------------------

func test_completing_gives_relation_fame_and_luz() -> void:
	var caller: int = _map.neighbours_of(_home)[0]
	var chunk: Vector2i = _map.nujio_chunk[caller]
	var q: Dictionary = FarQuests.new_quest(FarQuests.TYPE_FIRE, caller, chunk, [_home, caller] as Array[int], 1)
	GameState.far_quests.append(q)
	var runner := FarQuestRunner.new()
	add_child_autofree(runner)
	runner.start(_map, _home)
	runner.set_process(false)
	assert_eq(runner.check(), [], "aún arde")
	GameState.luz = 2
	GameState.extinguished_fires.append(chunk)
	assert_true(FarQuests.is_accomplished(q))
	var lines: Array = runner.check()
	assert_eq(lines.size(), 2)
	assert_eq(AdventureRules.relation(caller), 25, "relación +25 (reward_bosque_mission)")
	assert_eq(GameState.fama, 1, "fama +1")
	assert_eq(GameState.luz, 2 + int(FarQuests.reward().luz), "algo de Luz")
	assert_eq(QuestLogic.state_of(q), QuestLogic.REWARDED)
	assert_false(FarQuests.covers(caller), "el salvoconducto termina")
	assert_eq(runner.check(), [], "una sola vez")


func test_reparep_mission_and_failure() -> void:
	var caller: int = _map.neighbours_of(_home)[0]
	var q: Dictionary = FarQuests.new_quest(FarQuests.TYPE_REPAREP, caller, _map.nujio_chunk[caller], [caller] as Array[int], 1)
	GameState.far_quests.append(q)
	assert_false(FarQuests.is_accomplished(q))
	GameState.defeated_monsters.append("reparep:%d" % caller)
	assert_true(FarQuests.is_accomplished(q), "vencido su grupo de reparep")
	var other: Dictionary = FarQuests.new_quest(FarQuests.TYPE_FIRE, caller, _map.nujio_chunk[caller], [caller] as Array[int], 2)
	assert_false(FarQuests.has_failed(other, _map))
	GameState.bosque_state_overrides[str(caller)] = BosqueStates.ENOJADO
	assert_true(FarQuests.has_failed(other, _map), "el Bosque que llama se ha enojado")
	assert_true(FarQuests.fail(other))
	assert_eq(QuestLogic.state_of(other), QuestLogic.FAILED)


# --- Guardado --------------------------------------------------------------------------------------

func test_save_v17_fields_round_trip() -> void:
	var q: Dictionary = FarQuests.new_quest(FarQuests.TYPE_FIRE, 5, Vector2i(3, 4), [_home, 2, 5] as Array[int], 7)
	GameState.far_quests.append(q)
	GameState.last_vision_day = 7
	assert_eq(int(GameState.to_dict().save_version), GameState.SAVE_VERSION)
	assert_eq(SaveManager.save_game(SAVE_SLOT), OK)
	GameState.new_game(7)
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	assert_eq(GameState.far_quests.size(), 1)
	var loaded: Dictionary = GameState.far_quests[0]
	assert_eq(str(loaded.type), FarQuests.TYPE_FIRE)
	assert_eq(int(loaded.bosque), 5)
	assert_eq(FarQuests.target_chunk(loaded), Vector2i(3, 4))
	assert_eq(FarQuests.route_of(loaded), [_home, 2, 5] as Array[int])
	assert_eq(int(loaded.day), 7)
	assert_true(FarQuests.is_active(loaded))
	assert_eq(GameState.last_vision_day, 7)
	assert_true(FarQuests.covers(2))


func test_migration_from_v16_has_no_far_quests() -> void:
	GameState.far_quests.append(FarQuests.new_quest(FarQuests.TYPE_FIRE, 5, Vector2i(3, 4), [5] as Array[int], 7))
	GameState.last_vision_day = 7
	var v16: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	v16.save_version = 16
	v16.erase("far_quests")
	v16.erase("last_vision_day")
	var file := FileAccess.open(SaveManager.slot_path(SAVE_SLOT), FileAccess.WRITE)
	file.store_string(JSON.stringify(v16))
	file.close()
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	assert_eq(GameState.far_quests, [] as Array[Dictionary])
	assert_eq(GameState.last_vision_day, 0)
	assert_eq(FarQuests.sanitize({ "type": "nada", "bosque": 3 }), {}, "tipos desconocidos se descartan")
	assert_eq(FarQuests.sanitize("basura"), {})
