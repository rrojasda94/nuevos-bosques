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
	assert_false(MonsterSteering.is_camouflaged(), "en la 0.2.0 no hay camuflaje")


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


func test_post_cell_is_deterministic_reachable_and_near_the_gate() -> void:
	var region := ChunkGenerator.load_region(&"valle_del_sara")
	var map := BosqueMap.for_region(42, region)
	var home: int = AdventureRules.home_bosque(map, region)
	var depth: int = int(AdventureRules.monster_config(&"botarramas").post_depth)
	var checked: int = 0
	for t: Array in _tramos(map).slice(0, 12):
		for p: Dictionary in BotarramasPosts.posts_near(map, 42, home, t[0]):
			var chunk: ChunkData = ChunkGenerator.generate(42, p.chunk, region, map)
			var cell: Vector2i = BotarramasPosts.post_cell(chunk, 42, p.side, depth)
			var again: ChunkData = ChunkGenerator.generate(42, p.chunk, region, map)
			assert_eq(BotarramasPosts.post_cell(again, 42, p.side, depth), cell, "determinista")
			assert_true(chunk.is_reachable(cell), "se llega desde el hub")
			var gate: Vector2i = ChunkData.border_cell(p.side, ChunkGenerator.gate_index(42, p.chunk, p.side))
			assert_true(MonsterSteering.chebyshev(cell, gate) <= depth + BotarramasPosts.SEARCH_RADIUS, "junto a la puerta")
			checked += 1
	assert_gt(checked, 0)


func test_open_bosque_makes_its_botarramas_passive() -> void:
	GameState.new_game(42)
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
