extends GutTest
## Estados de Bosque (bosques-y-relacion.md, #133): reparto determinista por seed con el natal
## sano; peaje por estado (enojado no acepta pagos, muerto y necesita_ayuda no cobran, corrupto
## ×1,5); Únicos y cazadores por estado; el muerto sin Nujio ni frutos; incendios que bloquean, se
## apagan con E y suben la relación +15; angry_candidate -> enojado; aviso del Iserald; tinte con
## la paleta; mapa y pantalla I; guardado v14 con migración desde la v13.

const EXPLORATION: String = "res://scenes/world/exploration.tscn"
const Crossing = preload("res://scripts/rpg/crossing.gd")
const Screen = preload("res://scripts/rpg/inventory_screen.gd")
const SAVE_SLOT: int = 92
const SEEDS: Array[int] = [1, 2, 42, 777, 9001, 123456789]

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


## Primer Bosque del reparto de la seed 42 con ese estado de generación (-1 si no hay).
func _first_with(state: String, map: BosqueMap = _map) -> int:
	for id: int in map.count():
		if map.state_of(id) == state:
			return id
	return -1


func _force(bosque_id: int, state: String) -> void:
	GameState.bosque_state_overrides[str(bosque_id)] = state


# --- Reparto ---------------------------------------------------------------------------------------

func test_distribution_is_deterministic_with_the_home_bosque_healthy() -> void:
	for s: int in SEEDS:
		var a: BosqueMap = BosqueMap.for_region(s, _region)
		var b: BosqueMap = BosqueMap.for_region(s, _region)
		assert_eq(a.state, b.state, "seed %d: mismo reparto" % s)
		assert_eq(a.state.size(), a.count())
		assert_eq(a.state_of(a.home_bosque), BosqueStates.SANO, "seed %d: el natal, sano" % s)
		for n: int in a.neighbours_of(a.home_bosque):
			assert_eq(a.state_of(n), BosqueStates.SANO, "seed %d: los vecinos del natal, sanos" % s)
		var counts: Dictionary = {}
		for id: int in a.count():
			counts[a.state[id]] = int(counts.get(a.state[id], 0)) + 1
			assert_true(BosqueMap.STATES.has(a.state[id]))
			if a.state[id] == BosqueStates.MUERTO:
				assert_false(a.has_villa[id], "seed %d: un muerto no tiene villa" % s)
				assert_false(a.has_nujio(id), "seed %d: ni Nujio" % s)
		assert_gt(int(counts.get("sano", 0)), a.count() / 2, "seed %d: la mayoría, sanos (%s)" % [s, counts])
		assert_gt(int(counts.get("enojado", 0)), 0, "seed %d: algunos enojados" % s)
		for kind: String in ["corrupto", "muerto", "necesita_ayuda"]:
			assert_between(int(counts.get(kind, 0)), 1, 2, "seed %d: 1-2 %s" % [s, kind])
	assert_ne(BosqueMap.for_region(1, _region).state, BosqueMap.for_region(2, _region).state, "otra seed, otro reparto")


func test_state_of_reads_the_game_change_over_the_generated_one() -> void:
	assert_eq(BosqueStates.state_of(_target, _map), BosqueStates.SANO)
	assert_eq(AdventureRules.bosque_state(_target), BosqueStates.SANO, "con el reparto de la partida")
	watch_signals(EventBus)
	assert_true(BosqueStates.set_state(_target, BosqueStates.CORRUPTO))
	assert_signal_emitted_with_parameters(EventBus, "bosque_state_changed", [_target, BosqueStates.CORRUPTO])
	assert_eq(BosqueStates.state_of(_target, _map), BosqueStates.CORRUPTO)
	assert_true(BosqueStates.set_state(_target, BosqueStates.SANO))
	assert_false(GameState.bosque_state_overrides.has(str(_target)), "volver al de generación borra el cambio")
	assert_eq(BosqueStates.state_of(-1), "")


# --- Peaje por estado ------------------------------------------------------------------------------

func test_toll_by_state() -> void:
	assert_eq(AdventureRules.toll_for(_target, 1), 4, "sano: 3 + d")
	_force(_target, BosqueStates.CORRUPTO)
	assert_eq(AdventureRules.toll_for(_target, 1), 6, "corrupto: 4 × 1,5")
	GameState.bosque_relation[str(_target)] = 60
	assert_eq(AdventureRules.toll_for(_target, 1), 3, "corrupto con amistad alta: 4 × 1,5 × 0,5")
	GameState.bosque_relation[str(_target)] = 0
	assert_true(AdventureRules.can_pay_toll(_target))
	for free: String in [BosqueStates.MUERTO, BosqueStates.NECESITA_AYUDA]:
		_force(_target, free)
		assert_eq(AdventureRules.toll_for(_target, 1), 0, "%s: no cobra" % free)
		assert_false(AdventureRules.can_pay_toll(_target))
		assert_true(AdventureRules.is_paid(_target, _home), "%s: borde abierto" % free)
		assert_true(AdventureRules.is_passable(_target, _home))
		assert_false(BosqueHunt.is_hunting(_target, _home), "%s: no caza" % free)
	_force(_target, BosqueStates.ENOJADO)
	assert_false(AdventureRules.can_pay_toll(_target), "enojado: no se le puede pagar")
	assert_false(AdventureRules.is_paid(_target, _home))
	assert_false(AdventureRules.is_passable(_target, _home), "hay que vencer a sus Botarramas")
	assert_true(BosqueHunt.is_hunting(_target, _home))


func test_angry_border_menu_only_offers_fight_or_retreat() -> void:
	assert_eq(Crossing.actions_for(_target), [Crossing.Option.PAY_LUZ, Crossing.Option.OFRENDA, Crossing.Option.FIGHT, Crossing.Option.RETREAT])
	_force(_target, BosqueStates.ENOJADO)
	assert_eq(Crossing.actions_for(_target), [Crossing.Option.FIGHT, Crossing.Option.RETREAT])
	assert_string_contains(Crossing.title_for(_target), Texts.get_text("crossing_angry_title"))
	var logic: BattleLogic = AdventureRules.start_battle(_target, 1)
	assert_false(logic.accepts_payment, "sus Únicos no aceptan Luz ni ofrendas")
	assert_false(logic.can_offer_luz())
	_force(_target, BosqueStates.CORRUPTO)
	assert_string_contains(Crossing.title_for(_target), Texts.get_text("crossing_corrupt_line") % "×1,5")
	assert_true(AdventureRules.start_battle(_target, 1).accepts_payment)


func test_angry_border_menu_in_the_scene() -> void:
	var crossing: Node = load("res://scenes/rpg/crossing.tscn").instantiate()
	add_child_autofree(crossing)
	_force(_target, BosqueStates.ENOJADO)
	EventBus.bosque_border_reached.emit(_target)
	assert_true(crossing._panel.visible, "el menú se abre")
	assert_eq(crossing._actions, [Crossing.Option.FIGHT, Crossing.Option.RETREAT])
	crossing._close(&"retreated")
	_force(_target, BosqueStates.MUERTO)
	EventBus.bosque_border_reached.emit(_target)
	assert_false(crossing._panel.visible, "un Bosque muerto no cobra: no hay menú")


# --- Únicos y cazadores ------------------------------------------------------------------------------

func test_patrols_by_state() -> void:
	var base: int = BosquePatrols.patrols_of(_map, 42, _target).size()
	_force(_target, BosqueStates.ENOJADO)
	assert_eq(BosquePatrols.patrols_of(_map, 42, _target).size(), base * 2, "enojado: el doble")
	_force(_target, BosqueStates.MUERTO)
	assert_eq(BosquePatrols.patrols_of(_map, 42, _target).size(), 1, "muerto: uno solo")
	for p: Dictionary in BosquePatrols.patrols_of(_map, 42, _target):
		assert_eq(_map.bosque_at(p.chunk), _target)


func test_angry_bosque_hunts_from_the_start_more_often_and_sees_further() -> void:
	assert_eq(BosqueHunt.first_delay(0, BosqueStates.SANO), BosqueHunt.interval(0))
	assert_eq(BosqueHunt.first_delay(0, BosqueStates.ENOJADO), 8.0)
	assert_eq(BosqueHunt.interval(0, BosqueStates.ENOJADO), 45.0, "la mitad")
	assert_eq(BosqueHunt.max_hunters(BosqueStates.ENOJADO), 3)
	_force(_target, BosqueStates.ENOJADO)
	var hunt := BosqueHunt.new()
	assert_eq(hunt.tick(7.0, _target, _home, 42), &"")
	assert_ne(hunt.tick(1.5, _target, _home, 42), &"", "nada más entrar llega un cazador")
	assert_eq(hunt.tick(44.0, _target, _home, 42), &"")
	assert_ne(hunt.tick(1.5, _target, _home, 42), &"", "y luego cada 45 s")
	var base: int = int(AdventureRules.monster_config(&"botarramas").vision_radius)
	assert_eq(AdventureRules.vision_radius(_target, base), base + 4, "sus Botarramas ven más lejos")
	GameState.bosque_state_overrides.clear()
	assert_eq(AdventureRules.vision_radius(_target, base), base)


func _patrol(field: MonsterField, bosque_id: int, key: String) -> OverworldMonster:
	var m := OverworldMonster.new()
	m.role = MonsterField.ROLE_PATROL
	m.bosque_id = bosque_id
	m.monster_id = &"ofomni"
	m.key = key
	add_child_autofree(m)
	return m


func test_unicos_behaviour_by_state() -> void:
	var field: MonsterField = add_child_autofree(MonsterField.new())
	field._home = _home
	var m: OverworldMonster = _patrol(field, _target, "patrol:test:0")
	_force(_target, BosqueStates.NECESITA_AYUDA)
	assert_false(field.can_detect(m), "necesita ayuda: amistosos, no persiguen")
	# Corrupto pagado: a veces atacan igual (por Único y por Momento).
	_force(_target, BosqueStates.CORRUPTO)
	AdventureRules.pay_toll(_target, 0)
	var attacks: int = 0
	for r: int in 40:
		GameState.riutash_count = r
		GameState.open_until[str(_target)] = AdventureRules.OPEN_PERMANENT
		var ambush: bool = BosqueStates.ambushes(42, m.key, r, BosqueStates.CORRUPTO)
		assert_eq(field.can_detect(m), ambush)
		attacks += 1 if ambush else 0
	assert_between(attacks, 4, 30, "a veces, no siempre (%d de 40)" % attacks)
	# Muerto: el Único que ronda a veces va por su cuenta.
	_force(_target, BosqueStates.MUERTO)
	var independent: int = 0
	for r: int in 40:
		GameState.riutash_count = r
		var free: bool = BosqueStates.is_independent(42, m.key, r, BosqueStates.MUERTO)
		assert_eq(field.can_detect(m), free)
		assert_between(BosqueStates.independent_luz(42, m.key, r), 1, 2)
		independent += 1 if free else 0
	assert_between(independent, 4, 36, "a veces (%d de 40)" % independent)


func test_independent_unico_asks_for_luz_then_fights_if_refused() -> void:
	var dead: int = _first_with(BosqueStates.MUERTO)
	assert_gt(dead, -1, "la seed 42 tiene un Bosque muerto")
	var expl: Node = _exploration()
	var m: OverworldMonster = expl._field.spawn_hunter(&"botarramas", dead, Vector2i(5, 5), _map.styles[dead])
	m.role = MonsterField.ROLE_PATROL
	var r: int = 0
	while not BosqueStates.is_independent(42, m.key, r, BosqueStates.MUERTO):
		r += 1
	GameState.riutash_count = r
	assert_true(expl._field.is_independent(m))
	var ask: int = BosqueStates.independent_luz(42, m.key, r)
	var luz: int = GameState.luz
	watch_signals(EventBus)
	expl._on_monster_engaged(m)
	assert_true(expl._dialogue.is_open(), "pide Luz antes de atacar")
	expl._dialogue.choice.emit(0)
	assert_eq(GameState.luz, luz - ask, "pagas lo que pide")
	assert_false(expl._field.is_independent(m), "satisfecho este Momento")
	assert_false(expl._field.can_detect(m))
	assert_signal_not_emitted(EventBus, "unico_battle_requested")
	# Otro Momento, otra vez; si te niegas, ataca.
	var r2: int = r + 1
	while not BosqueStates.is_independent(42, m.key, r2, BosqueStates.MUERTO):
		r2 += 1
	GameState.riutash_count = r2
	expl._dialogue._close()
	# Un fotograma para que se liberen las opciones de la pregunta anterior.
	await get_tree().process_frame
	expl._on_monster_engaged(m)
	expl._dialogue.choice.emit(1)
	assert_signal_emitted_with_parameters(EventBus, "unico_battle_requested", [dead, &"botarramas", false])
	# Las opciones de la primera pregunta se liberan en el siguiente fotograma.
	await get_tree().process_frame


# --- Bosque muerto ------------------------------------------------------------------------------------

func test_dead_bosque_has_no_nujio_no_fruit_and_is_never_a_respawn_point() -> void:
	for s: int in SEEDS:
		var map: BosqueMap = BosqueMap.for_region(s, _region)
		var dead: int = _first_with(BosqueStates.MUERTO, map)
		assert_gt(dead, -1, "seed %d: hay un Bosque muerto" % s)
		assert_false(ChunkGenerator.bosque_gives_fruit(_region, map, dead))
		var center: ChunkData = ChunkGenerator.generate(s, map.nujio_chunk[dead], _region, map)
		assert_eq(center.nujio_rect.size, Vector2i.ZERO, "seed %d: sin Nujio" % s)
		assert_eq(center.tiles.count(ChunkData.Tile.NUJIO), 0)
		assert_gt(center.tiles.count(ChunkData.Tile.ROCKY), 0, "decadencia: restos donde estaba el Nujio")
		assert_true(center.is_walkable(center.hub))
		for c: Vector2i in map.chunks_of(dead):
			var chunk: ChunkData = ChunkGenerator.generate(s, c, _region, map)
			assert_eq(chunk.tiles.count(ChunkData.Tile.FRUIT_TREE), 0, "seed %d chunk %s: sin frutos" % [s, c])
	var dead42: int = _first_with(BosqueStates.MUERTO)
	GameState.bosque_relation[str(dead42)] = 100
	assert_false(AdventureRules.is_ally(dead42, _home), "sin Nujio no es aliado")
	assert_ne(AdventureRules.respawn_target(_map, _map.nujio_chunk[dead42], _home), dead42)


# --- Incendios ------------------------------------------------------------------------------------------

func test_fires_block_and_never_cut_a_path() -> void:
	for s: int in SEEDS:
		var map: BosqueMap = BosqueMap.for_region(s, _region)
		var id: int = _first_with(BosqueStates.NECESITA_AYUDA, map)
		assert_gt(id, -1)
		var burning: int = 0
		for c: Vector2i in map.chunks_of(id):
			var chunk: ChunkData = ChunkGenerator.generate(s, c, _region, map)
			var always: bool = c == map.nujio_chunk[id]
			var cells: Array[Vector2i] = BosqueFires.fire_cells(chunk, s, BosqueStates.NECESITA_AYUDA, always)
			assert_eq(cells, BosqueFires.fire_cells(chunk, s, BosqueStates.NECESITA_AYUDA, always), "determinista")
			if always:
				assert_false(cells.is_empty(), "seed %d: el chunk central siempre arde" % s)
			if cells.is_empty():
				continue
			burning += 1
			assert_between(cells.size(), 3, 5, "seed %d chunk %s" % [s, c])
			var touches: bool = false
			var blocked: Dictionary = {}
			for f: Vector2i in cells:
				blocked[f] = true
				for d: Vector2i in ChunkData.SIDES:
					touches = touches or (chunk.is_reachable(f + d) and not cells.has(f + d))
			assert_true(touches, "seed %d chunk %s: se puede apagar desde delante" % [s, c])
			var lost: int = 0
			for f: Vector2i in cells:
				lost += 1 if chunk.is_reachable(f) else 0
			assert_eq(BosqueFires._reachable_count(chunk, blocked), BosqueFires._reachable_count(chunk, {}) - lost,
				"seed %d chunk %s: el fuego no corta ningún paso" % [s, c])
		assert_gt(burning, 0)
		# Otros estados no arden.
		var chunk0: ChunkData = ChunkGenerator.generate(s, map.nujio_chunk[map.home_bosque], _region, map)
		assert_true(BosqueFires.fire_cells(chunk0, s, BosqueStates.SANO, true).is_empty())


func test_fire_is_put_out_with_e_and_raises_the_relation() -> void:
	var id: int = _first_with(BosqueStates.NECESITA_AYUDA)
	var coord: Vector2i = _map.nujio_chunk[id]
	var expl: Node = _exploration()
	expl._enter_chunk(coord, expl._get_chunk(coord).hub)
	expl._fade.color.a = 0.0
	assert_false(expl._fires.is_empty(), "el chunk arde")
	assert_eq(expl._fire_layer.get_child_count(), expl._fires.size(), "fuego animado en cada casilla")
	var fire: Vector2i = Vector2i(-1, -1)
	var stand: Vector2i = Vector2i(-1, -1)
	for f: Vector2i in expl._fires:
		if expl._fires[f] != coord:
			continue
		assert_false(expl._player.is_walkable.call(f), "el fuego bloquea")
		assert_false(expl._area_walkable(f), "también a los Únicos")
		for d: Vector2i in ChunkData.SIDES:
			if stand.x < 0 and expl._player.is_walkable.call(f + d) and expl._chunk.is_reachable(f + d):
				fire = f
				stand = f + d
	assert_gt(stand.x, -1, "hay desde dónde apagarlo")
	expl._player.place_at(stand)
	expl._player.facing = fire - stand
	var elapsed: float = GameState.clock_elapsed
	var relation: int = AdventureRules.relation(id)
	watch_signals(EventBus)
	expl._interact()
	assert_true(expl._dialogue.is_open(), "pregunta si apagarlo")
	expl._dialogue.choice.emit(0)
	assert_true(BosqueFires.is_extinguished(coord))
	assert_eq(AdventureRules.relation(id), relation + 15, "defenderlo: +15")
	assert_signal_emitted_with_parameters(EventBus, "bosque_fire_extinguished", [id, coord])
	assert_almost_eq(GameState.clock_elapsed, elapsed + BosqueFires.time_seconds(), 0.01, "gasta tiempo")
	assert_false(expl._fires.values().has(coord), "ya no arde")
	assert_true(expl._player.is_walkable.call(fire) or not expl._chunk.is_walkable(fire), "ya no bloquea más que antes")
	assert_false(BosqueFires.extinguish(coord, id, false), "una vez apagado, no vuelve")


func test_putting_out_a_fire_with_luz() -> void:
	var id: int = _first_with(BosqueStates.NECESITA_AYUDA)
	var coord: Vector2i = _map.nujio_chunk[id]
	var elapsed: float = GameState.clock_elapsed
	GameState.luz = 0
	assert_false(BosqueFires.extinguish(coord, id, true), "sin Luz no")
	GameState.luz = 5
	assert_true(BosqueFires.extinguish(coord, id, true))
	assert_eq(GameState.luz, 5 - BosqueFires.luz_cost())
	assert_eq(GameState.clock_elapsed, elapsed, "con Luz no pasa el tiempo")
	assert_eq(AdventureRules.relation(id), 15)


# --- angry_candidate -> enojado -----------------------------------------------------------------------

func test_very_low_relation_turns_the_bosque_angry() -> void:
	AdventureRules.pay_toll(_target, 0)
	watch_signals(EventBus)
	AdventureRules.change_relation(_target, -40)
	assert_eq(AdventureRules.bosque_state(_target), BosqueStates.SANO, "-39: aún no")
	AdventureRules.change_relation(_target, -15)
	assert_true(AdventureRules.is_angry_candidate(_target))
	assert_eq(AdventureRules.bosque_state(_target), BosqueStates.ENOJADO, "<= -50: se enoja")
	assert_eq(str(GameState.bosque_state_overrides[str(_target)]), BosqueStates.ENOJADO, "se guarda")
	assert_signal_emitted_with_parameters(EventBus, "bosque_state_changed", [_target, BosqueStates.ENOJADO])
	assert_false(AdventureRules.is_paid(_target, _home), "el paso pagado se pierde")
	assert_false(AdventureRules.can_pay_toll(_target))
	AdventureRules.change_relation(_target, 80)
	assert_eq(AdventureRules.bosque_state(_target), BosqueStates.ENOJADO, "no se le pasa solo")
	# El natal nunca; un corrupto sigue corrupto.
	AdventureRules.change_relation(_home, -100)
	assert_eq(AdventureRules.bosque_state(_home), BosqueStates.SANO)
	var corrupt: int = _first_with(BosqueStates.CORRUPTO)
	AdventureRules.change_relation(corrupt, -100)
	assert_eq(AdventureRules.bosque_state(corrupt), BosqueStates.CORRUPTO)


# --- Avisos, tinte, mapa y pantalla I --------------------------------------------------------------------

func test_entering_a_corrupt_bosque_warns_of_its_iserald() -> void:
	var corrupt: int = _first_with(BosqueStates.CORRUPTO)
	var expl: Node = _exploration()
	GameState.open_until[str(corrupt)] = AdventureRules.OPEN_PERMANENT
	watch_signals(EventBus)
	var coord: Vector2i = _map.chunks_of(corrupt)[0]
	expl._enter_chunk(coord, expl._get_chunk(coord).hub)
	assert_signal_emitted_with_parameters(EventBus, "notice_requested", ["Este Bosque está al borde de soltar a su Iserald."])
	assert_signal_emitted_with_parameters(EventBus, "bosque_entered", [corrupt, BosqueStates.CORRUPTO])
	assert_true(BosqueStates.has_iserald_risk(BosqueStates.CORRUPTO))
	assert_eq(BosqueStates.entry_notice(BosqueStates.SANO), "", "el sano no avisa")


func test_state_tint_stays_in_the_palette() -> void:
	var style: Dictionary = { "shape": 0, "leaf": 1, "trunk": 0, "ground": 0 }
	for state: String in [BosqueStates.ENOJADO, BosqueStates.CORRUPTO, BosqueStates.MUERTO]:
		for c: Color in [Color("3e8948"), Color("63c74d"), Color("733e39"), Color("e4a672")]:
			var t: Color = PlaceholderTileset.state_color(c, state)
			assert_true(PlaceholderTileset.PALETTE.has(t), "%s %s -> %s" % [state, c.to_html(false), t.to_html(false)])
			if state == BosqueStates.MUERTO:
				assert_true(PlaceholderTileset.DEAD_COLORS.has(t), "muerto: seco y gris")
		assert_eq(PlaceholderTileset.state_color(PlaceholderTileset.OUTLINE, state), PlaceholderTileset.OUTLINE)
	assert_eq(PlaceholderTileset.state_color(Color("3e8948"), BosqueStates.SANO), Color("3e8948"), "el sano no cambia")
	var healthy: Image = PlaceholderTileset.make_source(style).texture.get_image()
	var dead: Image = PlaceholderTileset.make_source(style, BosqueStates.MUERTO).texture.get_image()
	var tree := Rect2i(ChunkData.Tile.TREE * PlaceholderTileset.TILE, 0, PlaceholderTileset.TILE, PlaceholderTileset.TILE)
	assert_ne(healthy.get_region(tree).get_data(), dead.get_region(tree).get_data(), "los árboles cambian")
	var water := Rect2i(ChunkData.Tile.RIVER_NARROW * PlaceholderTileset.TILE, 0, PlaceholderTileset.TILE, PlaceholderTileset.TILE)
	assert_eq(healthy.get_region(water).get_data(), dead.get_region(water).get_data(), "el agua no")
	assert_eq(PlaceholderTileset.fire_frames().size(), PlaceholderTileset.FIRE_FRAMES, "fuego animado")


func test_map_and_inventory_show_the_state() -> void:
	var corrupt: int = _first_with(BosqueStates.CORRUPTO)
	var c: Vector2i = _map.chunks_of(corrupt)[0]
	var explored: Array[Vector2i] = [c, _map.nujio_chunk[_home]]
	var states: Dictionary = MapLogic.visible_states(_map, explored)
	assert_eq(states.size(), 1, "solo los no sanos")
	assert_eq(str(states[c]), BosqueStates.CORRUPTO)
	assert_eq(Screen.state_line(corrupt), "Bosque corrupto")
	assert_eq(Screen.state_line(_home), "Bosque sano")
	assert_eq(Screen.state_line(-1), "")
	GameState.bosque_relation[str(corrupt)] = -20
	assert_eq(Screen.state_relation_line(corrupt), "Bosque corrupto: relación -20", "pantalla I: estado y relación")
	assert_eq(Screen.state_relation_line(-1), "")
	assert_eq(BosqueStates.allies_in_battle(BosqueStates.NECESITA_AYUDA), 1, "gancho del combate en grupo")
	assert_eq(BosqueStates.stealth_vision_bonus(), 0, "gancho del sigilo")


# --- Guardado ------------------------------------------------------------------------------------------

func test_save_v14_keeps_state_changes_and_put_out_fires() -> void:
	assert_eq(GameState.SAVE_VERSION, 14)
	_force(_target, BosqueStates.ENOJADO)
	GameState.extinguished_fires.append(Vector2i(3, 4))
	var data: Dictionary = GameState.to_dict()
	assert_eq(data.bosque_state_overrides, { str(_target): BosqueStates.ENOJADO })
	assert_eq(data.extinguished_fires, [[3, 4]])
	assert_eq(SaveManager.save_game(SAVE_SLOT), OK)
	GameState.new_game(42)
	assert_true(GameState.bosque_state_overrides.is_empty(), "partida nueva: sin cambios")
	assert_true(GameState.extinguished_fires.is_empty())
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	assert_eq(AdventureRules.bosque_state(_target), BosqueStates.ENOJADO)
	assert_true(BosqueFires.is_extinguished(Vector2i(3, 4)))


func test_migration_from_v13_turns_angry_candidates_angry() -> void:
	var other: int = _map.neighbours_of(_home)[1]
	var data: Dictionary = GameState.to_dict()
	data.save_version = 13
	data.erase("bosque_state_overrides")
	data.erase("extinguished_fires")
	data.angry_candidate = [_target, other]
	data.bosque_relation = { str(_target): -60, str(other): -10 }
	data.open_until = { str(_target): 5 }
	GameState.from_dict(data)
	assert_eq(AdventureRules.bosque_state(_target), BosqueStates.ENOJADO, "candidato aún en el umbral: enojado")
	assert_false(GameState.open_until.has(str(_target)), "pierde el paso pagado")
	assert_eq(AdventureRules.bosque_state(other), BosqueStates.SANO, "candidato que mejoró: sigue sano")
	assert_true(GameState.extinguished_fires.is_empty())
	# Basura en el guardado: se descarta.
	data = GameState.to_dict()
	data.bosque_state_overrides = { "3": "furioso", "-1": "enojado", str(other): "muerto" }
	GameState.from_dict(data)
	assert_eq(GameState.bosque_state_overrides, { str(other): "muerto" })
