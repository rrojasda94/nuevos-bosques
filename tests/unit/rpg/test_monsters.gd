extends GutTest
## Monstruos del mundo (monstruos.md): parámetros genéricos en balance.json, decisión de paso
## (MonsterSteering) y puestos de los Botarramas (BotarramasPosts).

const S := MonsterSteering.State
const CFG: Dictionary = {
	"vision_radius": 10, "step_time": 0.24, "engage_distance": 1, "idle_wander": 3,
	"leash": 14, "max_outside": 4,
}
## Chunk propio del monstruo en un campo abierto: de (0, 0) a (63, 63).
const HOME := Rect2i(0, 0, 64, 64)

var _open: Callable = func(_c: Vector2i) -> bool: return true


func _decide(state: int, cell: Vector2i, post: Vector2i, player: Vector2i, can_detect: bool = true,
		cfg: Dictionary = CFG, walkable: Callable = _open, phase: int = 0) -> Dictionary:
	return MonsterSteering.decide(state, cell, post, player, can_detect, cfg, HOME, walkable, phase, Vector2i.DOWN)


func test_every_monster_has_the_generic_parameters() -> void:
	for id in ["botarramas", "ofomni", "ofomni_descarriado"]:
		var cfg: Dictionary = AdventureRules.monster_config(StringName(id))
		for key in ["vision_radius", "step_time", "engage_distance", "fatal_at", "special_every", "stats", "name_key"]:
			assert_true(cfg.has(key), "%s.%s" % [id, key])
	var b: Dictionary = AdventureRules.monster_config(&"botarramas")
	assert_eq(int(b.vision_radius), 10)
	assert_almost_eq(float(b.step_time), 0.24, 0.0001)
	assert_eq(int(b.engage_distance), 1)
	assert_eq(int(b.leash), 14)
	assert_eq(int(b.max_outside), 4)
	assert_almost_eq(float(b.engage_cooldown), 3.0, 0.0001)
	assert_eq(int(AdventureRules.monster_config(&"ofomni_descarriado").engage_distance), 2)


func test_sees_within_vision_radius_only_if_it_can_detect() -> void:
	assert_true(MonsterSteering.sees(Vector2i(10, 10), Vector2i(20, 0), true, CFG), "Chebyshev 10")
	assert_false(MonsterSteering.sees(Vector2i(10, 10), Vector2i(21, 10), true, CFG))
	assert_false(MonsterSteering.sees(Vector2i(10, 10), Vector2i(12, 10), false, CFG), "Bosque abierto: no ve")
	var blind: Dictionary = CFG.duplicate()
	blind.vision_radius = 0
	assert_false(MonsterSteering.sees(Vector2i(10, 10), Vector2i(11, 10), true, blind), "visión 0 (camuflaje): no ve")
	assert_true(MonsterSteering.engages(Vector2i(10, 10), Vector2i(11, 10), true, blind), "pero de cerca te encuentra")


func test_engage_distance_is_per_monster() -> void:
	assert_true(MonsterSteering.engages(Vector2i(5, 5), Vector2i(6, 6), true, CFG), "diagonal")
	assert_false(MonsterSteering.engages(Vector2i(5, 5), Vector2i(7, 5), true, CFG))
	var far: Dictionary = CFG.duplicate()
	far.engage_distance = 2
	assert_true(MonsterSteering.engages(Vector2i(5, 5), Vector2i(7, 7), true, far))
	assert_false(MonsterSteering.engages(Vector2i(5, 5), Vector2i(6, 5), false, CFG), "pasivo: no hay encuentro")


func test_chases_towards_player_when_seen() -> void:
	var d: Dictionary = _decide(S.IDLE, Vector2i(10, 10), Vector2i(10, 10), Vector2i(16, 10))
	assert_eq(d.state, S.CHASE)
	assert_eq(d.step, Vector2i(11, 10))
	var stay: Dictionary = _decide(S.CHASE, Vector2i(10, 10), Vector2i(10, 10), Vector2i(11, 11))
	assert_eq(stay.step, Vector2i(10, 10), "ya en distancia de encuentro: no se mueve")


func test_chase_goes_around_obstacles() -> void:
	var wall: Callable = func(c: Vector2i) -> bool: return not (c.x == 11 and c.y >= 5 and c.y <= 15)
	var d: Dictionary = _decide(S.CHASE, Vector2i(10, 10), Vector2i(10, 10), Vector2i(14, 10), true, CFG, wall)
	assert_eq(d.state, S.CHASE)
	assert_true(d.step == Vector2i(10, 9) or d.step == Vector2i(10, 11), "rodea el muro")


func test_blocked_chase_returns_to_post() -> void:
	var river: Callable = func(c: Vector2i) -> bool: return c.x != 12
	var d: Dictionary = _decide(S.CHASE, Vector2i(10, 10), Vector2i(8, 10), Vector2i(15, 10), true, CFG, river)
	assert_eq(d.state, S.RETURN, "sin camino hasta el jugador, vuelve")
	assert_eq(d.step, Vector2i(9, 10))


func test_leash_and_max_outside() -> void:
	var post := Vector2i(10, 2)
	assert_true(MonsterSteering.can_stand(Vector2i(10, -4), post, HOME, CFG, _open), "4 fuera de su chunk")
	assert_false(MonsterSteering.can_stand(Vector2i(10, -5), post, HOME, CFG, _open), "5 fuera: no")
	assert_false(MonsterSteering.can_stand(Vector2i(25, 2), post, HOME, CFG, _open), "a 15 de su puesto: no")
	assert_eq(MonsterSteering.outside_depth(Vector2i(70, 3), HOME), 7)
	# En el límite de max_outside no puede alcanzar al jugador: deja de perseguir y vuelve.
	var edge: Dictionary = _decide(S.CHASE, Vector2i(10, -4), post, Vector2i(10, -9))
	assert_eq(edge.state, S.RETURN, "no sale más de 4 casillas de su Bosque")
	assert_eq(edge.step, Vector2i(10, -3))
	# El jugador a más de `leash` del monstruo: deja de perseguir.
	var gone: Dictionary = _decide(S.CHASE, Vector2i(10, 8), post, Vector2i(10, 23))
	assert_eq(gone.state, S.RETURN)
	assert_eq(gone.step, Vector2i(10, 7))


func test_returns_then_limps_back_and_forth_at_rest() -> void:
	var back: Dictionary = _decide(S.RETURN, Vector2i(10, 12), Vector2i(10, 10), Vector2i(40, 40))
	assert_eq(back.step, Vector2i(10, 11))
	var home: Dictionary = _decide(S.RETURN, Vector2i(10, 10), Vector2i(10, 10), Vector2i(40, 40))
	assert_eq(home.state, S.IDLE)
	var offsets: Array[int] = []
	for phase in 12:
		offsets.append(MonsterSteering.idle_offset(phase, 3))
	assert_eq(offsets, [0, 1, 2, 3, 2, 1, 0, -1, -2, -3, -2, -1] as Array[int], "ida y vuelta de hasta 3")
	var idle: Dictionary = _decide(S.IDLE, Vector2i(10, 10), Vector2i(10, 10), Vector2i(40, 40), true, CFG, _open, 1)
	assert_eq(idle.step, Vector2i(10, 11), "renquea por su eje lateral")


func test_passive_monster_does_not_chase() -> void:
	var d: Dictionary = _decide(S.IDLE, Vector2i(10, 10), Vector2i(10, 10), Vector2i(12, 10), false)
	assert_eq(d.state, S.IDLE)
	var c: Dictionary = _decide(S.CHASE, Vector2i(12, 10), Vector2i(10, 10), Vector2i(14, 10), false)
	assert_eq(c.state, S.RETURN, "al abrirse el Bosque deja de perseguir")


# --- Puestos de los Botarramas ---

func _tramos(map: BosqueMap) -> Array:
	var out: Array = []
	for y in map.grid_size.y:
		for x in map.grid_size.x:
			var c := Vector2i(x, y)
			for side in [Vector2i.RIGHT, Vector2i.DOWN]:
				var n: Vector2i = c + side
				if map.bosque_at(n) >= 0 and map.bosque_at(n) != map.bosque_at(c):
					out.append([c, n])
	return out


func test_one_botarramas_per_border_segment_on_guarded_side() -> void:
	var region := ChunkGenerator.load_region(&"valle_del_sara")
	for s in [3, 42]:
		var map := BosqueMap.for_region(s, region)
		var home: int = AdventureRules.home_bosque(map, region)
		var tramos: Array = _tramos(map)
		var ids := {}
		for y in map.grid_size.y:
			for x in map.grid_size.x:
				for p: Dictionary in BotarramasPosts.posts_near(map, s, home, Vector2i(x, y)):
					ids[p.id] = p
					assert_eq(map.bosque_at(p.chunk), p.bosque_id, "en el lado del Bosque que guarda")
					assert_ne(map.bosque_at(p.chunk + p.side), p.bosque_id, "su lado da al otro Bosque")
					assert_ne(p.bosque_id, home, "el Bosque natal no se guarda")
		assert_eq(ids.size(), tramos.size(), "uno por tramo (seed %d)" % s)
		for t: Array in tramos:
			var a: Array[Dictionary] = BotarramasPosts.posts_near(map, s, home, t[0])
			var b: Array[Dictionary] = BotarramasPosts.posts_near(map, s, home, t[1])
			var shared: Array = a.filter(func(p: Dictionary) -> bool: return b.any(func(q: Dictionary) -> bool: return q.id == p.id))
			assert_eq(shared.size(), 1, "los dos chunks del tramo ven el mismo Botarramas")


func test_guarded_bosque_is_farther_from_home() -> void:
	var region := ChunkGenerator.load_region(&"valle_del_sara")
	var map := BosqueMap.for_region(42, region)
	var home: int = AdventureRules.home_bosque(map, region)
	for t: Array in _tramos(map):
		var a: int = map.bosque_at(t[0])
		var b: int = map.bosque_at(t[1])
		var g: int = BotarramasPosts.guarded_bosque(map, 42, home, a, b)
		assert_eq(g, BotarramasPosts.guarded_bosque(map, 42, home, b, a), "simétrico")
		assert_true(map.distance(home, g) >= map.distance(home, a if g == b else b))


func test_open_bosque_makes_its_botarramas_passive() -> void:
	GameState.new_game(42)
	GameState.equipped.main_hand = ""  # con el arma en la mano, ningún Bosque pagado es pasivo (test_stealth)
	var region := ChunkGenerator.load_region(&"valle_del_sara")
	var map := BosqueMap.for_region(42, region)
	var home: int = AdventureRules.home_bosque(map, region)
	var neighbour: int = map.neighbours_of(home)[0]
	var field: MonsterField = autofree(MonsterField.new())
	field._home = home
	var m: OverworldMonster = autofree(OverworldMonster.new())
	m.bosque_id = neighbour
	assert_true(field.can_detect(m), "Bosque cerrado: detecta")
	AdventureRules.pay_toll(neighbour, 0)
	assert_false(field.can_detect(m), "Bosque abierto: pasivo")
	var ofomni: OverworldMonster = autofree(OverworldMonster.new())
	assert_true(field.can_detect(ofomni), "el Ofomni no guarda Bosques: siempre detecta")


func test_passive_botarramas_does_not_block_and_defeated_dissolves() -> void:
	GameState.new_game(42)
	GameState.equipped.main_hand = ""  # con el arma en la mano, ningún Bosque pagado es pasivo (test_stealth)
	var region := ChunkGenerator.load_region(&"valle_del_sara")
	var map := BosqueMap.for_region(42, region)
	var home: int = AdventureRules.home_bosque(map, region)
	var neighbour: int = map.neighbours_of(home)[0]
	var field: MonsterField = add_child_autofree(MonsterField.new())
	field._home = home
	var m := OverworldMonster.new()
	m.bosque_id = neighbour
	m.key = "puesto_prueba"
	m.cell = Vector2i(5, 5)
	field.add_child(m)
	field._monsters.append(m)
	assert_true(field.occupied(Vector2i(5, 5)), "Bosque cerrado: bloquea")
	AdventureRules.pay_toll(neighbour, 0)
	assert_false(field.occupied(Vector2i(5, 5)), "pasivo: no bloquea el paso")
	field.dissolve(m)
	assert_false(field._monsters.has(m), "vencido: sale del campo")
	assert_true(GameState.defeated_monsters.has("puesto_prueba"), "no reaparece en la partida")
	var restored := GameState.to_dict()
	GameState.new_game(42)
	GameState.from_dict(restored)
	assert_true(GameState.defeated_monsters.has("puesto_prueba"), "se guarda y se carga")


# --- Mundo 2.0 (ADR 0014 §2 y §7, mundo-2.md §5) ---------------------------------------------------

const FakeBuilder := preload("res://tests/unit/world/fake_chunk_builder.gd")
const TICK: float = 1.0 / 64.0
## Monstruo del Mundo 2.0 de prueba: 64 px/s (1 px por TICK), engage_px de engage_distance 1.
const CFG_W: Dictionary = {
	"vision_radius": 10, "step_time": 0.25, "engage_distance": 1, "idle_wander": 0, "leash": 14,
	"max_outside": 4, "speed_px": 64, "idle_speed_px": 32, "engage_px": 10,
}
const IDS: Array[String] = ["botarramas", "ofomni_descarriado", "ofomni", "reparep", "aledra"]

var _plan: RegionPlan
var _chunks: Dictionary = {}


func _tex() -> Texture2D:
	return ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))


func _world_monster(at: Vector2i, cfg: Dictionary = CFG_W) -> OverworldMonster:
	var m: OverworldMonster = autofree(OverworldMonster.new())
	m.setup_world(&"botarramas", "prueba", -1, at, Rect2i(0, 0, 80, 80), Vector2i.DOWN, cfg, _tex())
	return m


func _center(c: Vector2i) -> Vector2:
	return WorldCoords.world_cell_to_world_pos(c)


## Caja de los pies (10×6) con los pies en `pos`.
func _box(pos: Vector2) -> Rect2:
	return Rect2(pos.x - 5.0, pos.y - 6.0, 10.0, 6.0)


func _region_plan() -> RegionPlan:
	if _plan == null:
		_plan = RegionPlan.for_region(42, &"valle_del_sara")
	return _plan


func _chunk(c: Vector2i) -> WorldChunk:
	if not _chunks.has(c):
		_chunks[c] = FakeBuilder.build(_region_plan(), c)
	return _chunks[c]


var _open_chunks: Dictionary = {}


## Chunk de hierba sin nada que bloquee: todo se alcanza desde el hub. Para los tests que no deben
## depender de dónde pone árboles el builder falso.
func _open_chunk(c: Vector2i) -> WorldChunk:
	if not _open_chunks.has(c):
		var wc := WorldChunk.new()
		wc.coord = c
		wc.rebuild_blocked()
		_open_chunks[c] = wc
	return _open_chunks[c]


## Campo del Mundo 2.0 con el plan de la seed 42, chunks del builder falso (o abiertos con `open`;
## solo los de `loaded`, todos si está vacío) y el jugador con los pies en `player_cell`.
func _world_field(player_cell: Vector2i, loaded: Array = [], open: bool = false) -> MonsterField:
	var plan: RegionPlan = _region_plan()
	var field: MonsterField = add_child_autofree(MonsterField.new())
	field.set_physics_process(false)
	var get_chunk: Callable = func(c: Vector2i) -> WorldChunk:
		if not loaded.is_empty() and not loaded.has(c):
			return null
		return _open_chunk(c) if open else _chunk(c)
	field.populate_world(plan, plan.bosque_at(plan.home_chunk), get_chunk)
	field.terrain_blocked = func(c: Vector2i) -> bool:
		var wc: WorldChunk = get_chunk.call(WorldCoords.world_cell_to_chunk(c))
		return wc == null or wc.is_blocked(WorldCoords.world_cell_to_cell(c))
	field.area_walkable = func(c: Vector2i) -> bool: return not field.terrain_blocked.call(c)
	var pc: PlayerController = autofree(PlayerController.new())
	pc.mover.place(_center(player_cell))
	field.world_player = pc
	return field


func test_speed_and_engage_px_are_in_the_data_of_each_monster() -> void:
	for id: String in IDS:
		var cfg: Dictionary = AdventureRules.monster_config(StringName(id))
		assert_eq(int(cfg.speed_px), roundi(16.0 / float(cfg.step_time)), "%s.speed_px = 16 / step_time" % id)
		assert_eq(int(cfg.idle_speed_px), roundi(16.0 / float(cfg.idle_step_time)), "%s.idle_speed_px" % id)
		assert_eq(int(cfg.engage_px), int(cfg.engage_distance) * 16 - 6, "%s.engage_px = engage_distance × 16 − 6" % id)
	assert_eq(WorldEncounters.level_link_cells(), 2)


func test_engage_by_pixels_between_boxes() -> void:
	var player: Rect2 = _box(_center(Vector2i(10, 10)))
	assert_eq(WorldEncounters.box_gap(_box(_center(Vector2i(11, 10))), player), 6.0, "vecino en x: 6 px")
	assert_eq(WorldEncounters.box_gap(_box(_center(Vector2i(10, 11))), player), 10.0, "vecino en y: 10 px")
	assert_eq(WorldEncounters.box_gap(_box(_center(Vector2i(10, 10)) + Vector2(3, 0)), player), 0.0, "se solapan")
	var b: Dictionary = AdventureRules.monster_config(&"botarramas")
	assert_true(WorldEncounters.engages(_box(_center(Vector2i(11, 11))), player, true, b), "diagonal: 10 px")
	assert_false(WorldEncounters.engages(_box(_center(Vector2i(10, 12))), player, true, b), "a dos casillas: 26 px")
	assert_false(WorldEncounters.engages(_box(_center(Vector2i(11, 10))), player, false, b), "pasivo: no hay encuentro")
	var o: Dictionary = AdventureRules.monster_config(&"ofomni")
	assert_true(WorldEncounters.engages(_box(_center(Vector2i(10, 12))), player, true, o), "Ofomni: engage_distance 2 = 26 px")
	assert_false(WorldEncounters.engages(_box(_center(Vector2i(10, 13))), player, true, o))


func test_monster_moves_continuously_towards_the_next_cell() -> void:
	var m: OverworldMonster = _world_monster(Vector2i(10, 10))
	var player := Vector2i(16, 10)
	var blocked: Callable = func(_c: Vector2i) -> bool: return false
	for i in 4:
		m.think_world(TICK, _center(player), player, true, _open, blocked)
	assert_eq(m.state, S.CHASE)
	assert_eq(m.cell, Vector2i(11, 10), "MonsterSteering eligió la siguiente casilla")
	assert_almost_eq(m.world_pos().x, 168.0 + 4.0, 0.001, "1 px por tick a 64 px/s: entre dos casillas, sin saltos")
	assert_true(m.is_moving())
	for i in 12:
		m.think_world(TICK, _center(player), player, true, _open, blocked)
	assert_almost_eq(m.world_pos().x, 184.0, 0.001, "en el centro de la casilla tras 16 px")
	assert_eq(m.mover.cell, Vector2i(11, 10))
	m.think_world(TICK, _center(player), player, true, _open, blocked)
	assert_eq(m.cell, Vector2i(12, 10), "al llegar pide la siguiente y sigue sin pararse")
	assert_almost_eq(m.world_pos().x, 185.0, 0.001)
	assert_eq(m.position, m.world_pos().round(), "el dibujo va ajustado al píxel")


func test_monster_collides_with_the_same_map_as_the_player() -> void:
	var m: OverworldMonster = _world_monster(Vector2i(10, 10))
	var wall: Callable = func(c: Vector2i) -> bool: return c.x == 11
	for i in 30:
		m.think_world(TICK, _center(Vector2i(16, 10)), Vector2i(16, 10), true, _open, wall)
	assert_almost_eq(m.world_pos().x, 176.0 - 5.0, 0.001, "su caja se pega a la pared")
	assert_eq(m.cell, Vector2i(10, 10), "atascado: se queda en su casilla")


func test_chasing_monster_closes_in_until_the_boxes_reach_engage_px() -> void:
	var m: OverworldMonster = _world_monster(Vector2i(10, 10))
	m.state = S.CHASE
	var pos := Vector2(11 * 16 + 15.5, 168.0)
	var player := Vector2i(11, 10)
	assert_false(WorldEncounters.engages(m.get_rect(), _box(pos), true, CFG_W), "al otro lado de la casilla vecina: 13,5 px")
	var blocked: Callable = func(_c: Vector2i) -> bool: return false
	for i in 20:
		m.think_world(TICK, pos, player, true, _open, blocked)
	assert_eq(m.mover.cell, Vector2i(10, 10), "no sale de su casilla")
	assert_true(WorldEncounters.engages(m.get_rect(), _box(pos), true, CFG_W), "se arrima hasta el encuentro")


func test_no_encounter_across_a_cliff_without_stairs_near() -> void:
	var chunk := WorldChunk.new()
	for x in 20:
		for y in range(6, 20):
			chunk.set_level(Vector2i(x, y), 1)
	var get_chunk: Callable = func(c: Vector2i) -> WorldChunk: return chunk if c == Vector2i.ZERO else null
	assert_true(WorldEncounters.levels_linked(Vector2i(5, 3), Vector2i(6, 4), get_chunk, 2), "mismo nivel")
	assert_false(WorldEncounters.levels_linked(Vector2i(5, 5), Vector2i(5, 6), get_chunk, 2), "risco en medio")
	chunk.set_cliff(Vector2i(8, 7), WorldChunk.Cliff.STAIRS)
	assert_false(WorldEncounters.levels_linked(Vector2i(5, 5), Vector2i(5, 6), get_chunk, 2), "escalera a 3: lejos")
	chunk.set_cliff(Vector2i(7, 7), WorldChunk.Cliff.RAMP)
	assert_true(WorldEncounters.levels_linked(Vector2i(5, 5), Vector2i(5, 6), get_chunk, 2), "rampa a 2")


func test_monsters_sleep_outside_the_active_chunks_and_keep_their_state() -> void:
	GameState.new_game(42)
	var a_cell: Vector2i = WorldCoords.to_world_cell(Vector2i(2, 2), Vector2i(40, 40))
	var b_cell: Vector2i = WorldCoords.to_world_cell(Vector2i(5, 5), Vector2i(45, 40))
	var field: MonsterField = _world_field(a_cell + Vector2i(5, 0), [Vector2i(-1, -1)])
	var a: OverworldMonster = field._add(&"botarramas", "a", -1, a_cell, field._home_rect(a_cell), Vector2i.DOWN, CFG_W, _tex())
	var b: OverworldMonster = field._add(&"botarramas", "b", -1, b_cell, field._home_rect(b_cell), Vector2i.DOWN, CFG_W, _tex())
	assert_eq(b.home_rect, Rect2i(400, 400, 80, 80), "su chunk en world_cell")
	b.state = S.CHASE
	b.cooldown = 1.5
	field._process_world(0.5)
	assert_false(a.asleep, "en el chunk del jugador: despierto")
	assert_true(a.visible)
	assert_true(b.asleep, "a 3 chunks: dormido")
	assert_false(b.visible)
	assert_almost_eq(b.cooldown, 1.5, 0.0001, "dormido no piensa")
	assert_almost_eq(a.cooldown, 0.0, 0.0001)
	var b_pos: Vector2 = b.world_pos()
	field.world_player.mover.place(_center(WorldCoords.to_world_cell(Vector2i(4, 4), Vector2i(70, 70))))
	field.update_active(Vector2i(4, 4))
	assert_false(b.asleep, "chunk vecino del jugador: despierta")
	assert_true(a.asleep)
	assert_eq(b.state, S.CHASE, "conserva su estado")
	assert_eq(b.world_pos(), b_pos, "y su posición")
	assert_almost_eq(b.cooldown, 1.5, 0.0001)


## Tramos de la región entre chunks de Bosques distintos: [chunk, lado].
func _plan_tramos(plan: RegionPlan) -> Array:
	var out: Array = []
	for y in plan.size_chunks.y:
		for x in plan.size_chunks.x:
			var c := Vector2i(x, y)
			for side in [Vector2i.RIGHT, Vector2i.DOWN]:
				var a: int = plan.bosque_at(c)
				var b: int = plan.bosque_at(c + side)
				if a >= 0 and b >= 0 and a != b:
					out.append([c, side])
	return out


func test_botarramas_only_at_the_new_doors() -> void:
	var plan: RegionPlan = _region_plan()
	var home: int = plan.bosque_at(plan.home_chunk)
	var with_door: int = 0
	var tramos: Array = _plan_tramos(plan)
	for t: Array in tramos:
		if plan.has_door(t[0], t[1]):
			with_door += 1
	var ids := {}
	for y in plan.size_chunks.y:
		for x in plan.size_chunks.x:
			for p: Dictionary in BotarramasPosts.posts_near_plan(plan, 42, home, Vector2i(x, y)):
				ids[p.id] = p
				assert_true(plan.has_door(p.chunk, p.side), "solo donde hay puerta")
				assert_eq(plan.bosque_at(p.chunk), p.bosque_id, "en el lado del Bosque que guarda")
	assert_gt(with_door, 0)
	assert_eq(ids.size(), with_door, "uno por tramo con puerta (%d tramos, %d con puerta)" % [tramos.size(), with_door])
	var depth: int = int(AdventureRules.monster_config(&"botarramas").post_depth)
	var checked: int = 0
	for p: Dictionary in ids.values().slice(0, 6):
		var wc: WorldChunk = _chunk(p.chunk)
		var door: Vector2i = BotarramasPosts.door_cell(plan, p.chunk, p.side)
		var d: Dictionary = plan.door(p.chunk, p.side)
		assert_eq(door, WorldChunk.border_cell(p.side, int(d.index) + int(d.width) / 2), "el medio de la puerta, en el borde del tramo")
		var cell: Vector2i = BotarramasPosts.post_cell_world(wc, plan, p.side, depth)
		assert_eq(BotarramasPosts.post_cell_world(wc, plan, p.side, depth), cell, "determinista")
		assert_true(wc.is_reachable(cell) or cell == door, "se llega desde el hub")
		assert_true(MonsterSteering.chebyshev(cell, door) <= depth + BotarramasPosts.SEARCH_RADIUS, "junto a la puerta")
		checked += 1
	assert_gt(checked, 0)


func test_world_field_puts_the_botarramas_of_the_active_chunks() -> void:
	GameState.new_game(42)
	var plan: RegionPlan = _region_plan()
	var home: int = plan.bosque_at(plan.home_chunk)
	var post: Dictionary = {}
	for t: Array in _plan_tramos(plan):
		var posts: Array[Dictionary] = BotarramasPosts.posts_near_plan(plan, 42, home, t[0])
		if not posts.is_empty():
			post = posts[0]
			break
	assert_false(post.is_empty())
	var field: MonsterField = _world_field(WorldCoords.to_world_cell(post.chunk, Vector2i(40, 40)))
	field.update_active(post.chunk)
	var m: OverworldMonster = field._find(String(post.id))
	assert_not_null(m, "el Botarramas de la puerta aparece al entrar su chunk en los activos")
	assert_eq(m.role, MonsterField.ROLE_GUARDIAN)
	assert_eq(WorldCoords.world_cell_to_chunk(m.cell), post.chunk)
	assert_not_null(m.mover, "con movimiento continuo")
	var n: int = field._monsters.size()
	field.update_active(post.chunk + Vector2i.ONE)
	field.update_active(post.chunk)
	assert_eq(field._find(String(post.id)), m, "no se repuebla: es el mismo")
	assert_gte(field._monsters.size(), n)


func test_border_of_a_closed_bosque_blocks_and_signals_once_per_contact() -> void:
	var closed := { 1: true }
	var border := BosqueBorder.new(func(c: Vector2i) -> int: return 1 if c.x < 0 else 0,
		func(b: int) -> bool: return bool(closed.get(b, false)))
	var mover := GridMover.new(Vector2(10, 6), 5.0, 100.0)
	mover.place(_center(Vector2i(2, 5)))
	var blocked: Callable = border.blocks(func(_c: Vector2i) -> bool: return false)
	watch_signals(EventBus)
	watch_signals(border)
	var push: Callable = func(dir: Vector2, ticks: int) -> void:
		for i in ticks:
			mover.step(dir, 100.0, 1.0 / 60.0, blocked)
			border.tick(mover.cell, dir != Vector2.ZERO)
	push.call(Vector2.LEFT, 60)
	assert_almost_eq(mover.world_pos.x, 5.0, 0.001, "la casilla del Bosque cerrado bloquea")
	assert_signal_emit_count(EventBus, "bosque_border_reached", 1, "una vez aunque siga empujando")
	assert_signal_emitted_with_parameters(EventBus, "bosque_border_reached", [1])
	assert_signal_emitted_with_parameters(border, "contacted", [1, Vector2i(-1, 5)])
	push.call(Vector2.ZERO, 20)
	push.call(Vector2.LEFT, 10)
	assert_signal_emit_count(EventBus, "bosque_border_reached", 1, "soltar y volver a empujar: el mismo contacto")
	push.call(Vector2.LEFT + Vector2.UP * 0.7, 10)
	assert_signal_emit_count(EventBus, "bosque_border_reached", 1, "deslizarse por el límite: el mismo contacto")
	push.call(Vector2.RIGHT, 10)
	push.call(Vector2.LEFT, 20)
	assert_signal_emit_count(EventBus, "bosque_border_reached", 2, "se apartó y vuelve: contacto nuevo")
	closed[1] = false
	assert_false(border.is_border(Vector2i(-1, 5)), "pagado: no bloquea")
	closed[1] = true
	border.current_bosque = 1
	assert_false(border.is_border(Vector2i(-1, 5)), "las casillas del Bosque en el que está no bloquean")


func test_crossing_off_door_summons_the_nearest_botarramas() -> void:
	GameState.new_game(42)
	var plan: RegionPlan = _region_plan()
	var home: int = plan.bosque_at(plan.home_chunk)
	var post: Dictionary = {}
	for t: Array in _plan_tramos(plan):
		var posts: Array[Dictionary] = BotarramasPosts.posts_near_plan(plan, 42, home, t[0])
		if not posts.is_empty():
			post = posts[0]
			break
	var guard: int = post.bosque_id
	var door: Vector2i = BotarramasPosts.door_cell(plan, post.chunk, post.side)
	# Lejos de la puerta, en el borde del chunk que guarda (del lado del Bosque cerrado).
	var along: int = 70 if (door.y if post.side.x != 0 else door.x) < 40 else 10
	var bump_local: Vector2i = WorldChunk.border_cell(post.side, along)
	var bump: Vector2i = WorldCoords.to_world_cell(post.chunk, bump_local)
	var field: MonsterField = _world_field(bump + post.side, [], true)
	field.update_active(post.chunk)
	assert_not_null(field._find(String(post.id)))
	var nearest: OverworldMonster = null
	for g: OverworldMonster in field.with_role(MonsterField.ROLE_GUARDIAN):
		if g.bosque_id == guard and (nearest == null or MonsterSteering.chebyshev(g.cell, bump) < MonsterSteering.chebyshev(nearest.cell, bump)):
			nearest = g
	var m: OverworldMonster = field.summon_nearest(guard, bump)
	assert_eq(m, nearest, "acude el Botarramas más cercano de ese Bosque")
	if m == null:
		return
	assert_eq(m.state, S.CHASE)
	assert_eq(plan.bosque_at(WorldCoords.world_cell_to_chunk(m.post)), guard, "se aposta en su Bosque")
	assert_true(MonsterSteering.chebyshev(m.post, bump) <= BotarramasPosts.SEARCH_RADIUS, "junto al choque")
	assert_true(MonsterSteering.chebyshev(m.cell, m.post) <= int(m.cfg.leash), "a su correa del puesto nuevo")
	assert_eq(field.summon_nearest(home, bump), null, "el natal no tiene Botarramas")


func test_unicos_of_03_are_ported_to_world_cells() -> void:
	GameState.new_game(42)
	var plan: RegionPlan = _region_plan()
	var home: int = plan.bosque_at(plan.home_chunk)
	var chunk := Vector2i(-1, -1)
	for y in plan.size_chunks.y:
		for x in plan.size_chunks.x:
			var c := Vector2i(x, y)
			var b: int = plan.bosque_at(c)
			if b >= 0 and b != home and chunk.x < 0 \
					and not BosquePatrols.patrols_in(plan.bosques, 42, c, GameState.clock_momento).is_empty() \
					and not _chunk(c).is_blocked(_chunk(c).hub):
				chunk = c
	assert_true(chunk.x >= 0, "hay un chunk con Únicos que rondan")
	var bosque: int = plan.bosque_at(chunk)
	var wc: WorldChunk = _chunk(chunk)
	var player: Vector2i = WorldCoords.to_world_cell(chunk, wc.hub)
	var field: MonsterField = _world_field(player, [chunk])
	field.update_active(chunk)
	var patrols: Array[OverworldMonster] = field.with_role(MonsterField.ROLE_PATROL)
	assert_gt(patrols.size(), 0, "rondan en su chunk")
	for m: OverworldMonster in patrols:
		assert_eq(WorldCoords.world_cell_to_chunk(m.cell), chunk)
		assert_true(wc.is_reachable(WorldCoords.world_cell_to_cell(m.cell)))
		assert_eq(int(m.cfg.leash), maxi(int(AdventureRules.monster_config(m.monster_id).leash), WorldCoords.CHUNK),
			"la correa cubre el chunk de 80")
	var cells: Array[Vector2i] = OfomniGuard.spawn_cells(player, 2, field.can_place_world, field._home_rect(player))
	assert_gt(cells.size(), 0)
	var style: Dictionary = plan.bosques.styles[bosque]
	field.spawn_chasers(bosque, cells, style)
	for m: OverworldMonster in field.chasers():
		assert_eq(m.state, S.CHASE, "el perseguidor ya persigue")
		assert_eq(m.home_rect, Rect2i(chunk * 80, Vector2i(80, 80)))
		assert_not_null(m.mover)
	field.spawn_ofomni_world("primera_mision", player + Vector2i(2, 0), style)
	var o: OverworldMonster = field.ofomni()
	assert_not_null(o, "el Ofomni descarriado")
	assert_true(MonsterSteering.chebyshev(o.cell, player) >= MonsterField.OFOMNI_MIN_GAP)
	assert_true(field.can_detect(o), "siempre ve")
	field.dissolve(o)
	assert_true(GameState.defeated_monsters.has("primera_mision"), "vencido: no vuelve")
