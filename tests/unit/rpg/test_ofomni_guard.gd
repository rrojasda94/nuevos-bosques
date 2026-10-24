extends GutTest
## Ofomni que guardan su Bosque (OfomniGuard; sigilo-y-robo.md y feedback del dueño 0.3): un robo
## despierta a 1-2 Ofomni que persiguen dentro de ese Bosque y se rinden fuera; se apaciguan
## pagando el peaje y vencerlos suma hostilidad; con la primera misión ofrecida, intentar salir del
## Bosque natal hace que sus Ofomni te devuelvan a la villa, y con la misión activa ya no.

const EXPLORATION: String = "res://scenes/world/exploration.tscn"
const Q: StringName = &"primera_mision"

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
	GameState.new_game(42)


func after_each() -> void:
	get_tree().paused = false
	WorldClock.set_process(true)


func _exploration() -> Node:
	var expl: Node = load(EXPLORATION).instantiate()
	add_child_autofree(expl)
	expl.start()
	return expl


## Un chunk del Bosque natal con salida a otro Bosque, y el lado de esa salida.
func _home_exit() -> Array:
	for c: Vector2i in _map.chunks_of(_home):
		var sides: Array[Vector2i] = OfomniGuard.exit_sides(_map, c, _home)
		if not sides.is_empty():
			return [c, sides[0]]
	return []


## Roba en el Bosque natal: un segundo fruto en el mismo Momento.
func _steal_at_home() -> void:
	var coord: Vector2i = GameState.chunk_coord
	FruitRules.take(coord, Vector2i(1, 1), _home, _home)
	var r: Dictionary = FruitRules.take(coord, Vector2i(2, 1), _home, _home)
	assert_true(bool(r.theft), "el segundo fruto es robo")


# --- Datos ------------------------------------------------------------------------------------

func test_values_in_balance_json() -> void:
	var cfg: Dictionary = OfomniGuard.config()
	assert_eq(int(cfg.chase_count_min), 1)
	assert_eq(int(cfg.chase_count_max), 2)
	assert_eq(float(cfg.alert_chance), 1.0, "sin sigilo todavía: siempre alerta")
	assert_eq(int(cfg.confine_distance), 3)
	var ofomni: Dictionary = AdventureRules.monster_config(&"ofomni")
	var botarramas: Dictionary = AdventureRules.monster_config(&"botarramas")
	assert_lt(float(ofomni.step_time), float(botarramas.step_time), "algo más rápido que un Botarramas")
	assert_true(AdventureRules.is_appeasable(ofomni), "el Ofomni del Bosque se apacigua")
	assert_true(AdventureRules.monster_config(&"ofomni").fatal_at.is_empty(), "no es fatal")


func test_alert_and_count() -> void:
	assert_true(OfomniGuard.is_alerted(), "robo a la vista: 100%")
	for nonce: int in 20:
		var n: int = OfomniGuard.chase_count(42, _home, nonce)
		assert_between(n, 1, 2)
	assert_eq(OfomniGuard.chase_count(42, _home, 3), OfomniGuard.chase_count(42, _home, 3), "determinista")


func test_chase_state_caps_and_gives_up_outside() -> void:
	var chase := OfomniGuard.new()
	assert_eq(chase.alert(_target, 2), 2)
	assert_eq(chase.alert(_target, 2), 0, "nunca más de 2 a la vez")
	assert_false(chase.bosque_entered(_target), "otro chunk del mismo Bosque: siguen")
	assert_true(chase.is_active())
	chase.chaser_defeated()
	assert_eq(chase.count, 1)
	assert_true(chase.bosque_entered(_home), "sales del Bosque: se rinden")
	assert_false(chase.is_active())


func test_spawn_cells_out_of_sight_and_apart() -> void:
	var player := Vector2i(32, 32)
	var cells: Array[Vector2i] = OfomniGuard.spawn_cells(player, 2, func(_c: Vector2i) -> bool: return true,
		Rect2i(0, 0, ChunkData.SIZE, ChunkData.SIZE))
	assert_eq(cells.size(), 2)
	for c: Vector2i in cells:
		var off: Vector2i = (c - player).abs()
		assert_true(off.x > 10 or off.y > 6, "fuera de la vista inmediata")
		assert_lte(MonsterSteering.chebyshev(c, player), 14, "pero cerca")
	assert_gte(MonsterSteering.chebyshev(cells[0], cells[1]), 3, "separados")


# --- Persecución tras un robo -------------------------------------------------------------------

func test_theft_spawns_chasers_that_follow_inside_their_bosque_and_not_outside() -> void:
	var expl: Node = _exploration()
	assert_eq(_map.bosque_at(GameState.chunk_coord), _home)
	_steal_at_home()
	var chasers: Array[OverworldMonster] = expl._field.chasers()
	assert_between(chasers.size(), 1, 2, "despiertan 1 o 2 Ofomni")
	for m: OverworldMonster in chasers:
		assert_eq(m.monster_id, MonsterField.OFOMNI, "el Ofomni apaciguable, no el descarriado")
		assert_eq(m.bosque_id, _home)
		assert_eq(m.state, MonsterSteering.State.CHASE, "ya persiguen")
		assert_true(expl._field.can_detect(m), "aunque el Bosque dé permiso, el robo va aparte")
		var off: Vector2i = (m.cell - GameState.player_cell).abs()
		assert_true(off.x > 10 or off.y > 6, "aparecen fuera de la vista")
	var count: int = chasers.size()
	# Otro chunk del mismo Bosque: le siguen.
	var other: Vector2i = _map.chunks_of(_home).filter(func(c: Vector2i) -> bool: return c != GameState.chunk_coord)[0]
	expl._enter_chunk(other, expl._get_chunk(other).hub)
	assert_eq(expl._field.chasers().size(), count, "en otro chunk del Bosque siguen viniendo")
	# Fuera del Bosque: se rinden.
	watch_signals(EventBus)
	var exit: Array = _home_exit()
	var outside: Vector2i = exit[0] + exit[1]
	expl._enter_chunk(outside, expl._get_chunk(outside).hub)
	assert_eq(expl._field.chasers().size(), 0, "fuera de su Bosque no hay perseguidores")
	assert_false(expl._chase.is_active())
	assert_signal_emitted_with_parameters(EventBus, "notice_requested", [Texts.get_text("ofomni_chase_gave_up")])


func test_chasers_never_step_out_of_their_chunk() -> void:
	var cfg: Dictionary = MonsterField.inner_config(MonsterField.OFOMNI, MonsterField.ROLE_CHASER)
	assert_eq(int(cfg.max_outside), 0)
	var rect := Rect2i(0, 0, ChunkData.SIZE, ChunkData.SIZE)
	var all: Callable = func(_c: Vector2i) -> bool: return true
	var cell := Vector2i(62, 30)
	for i: int in 6:
		var d: Dictionary = MonsterSteering.decide(MonsterSteering.State.CHASE, cell, Vector2i(40, 30), Vector2i(72, 30),
			true, cfg, rect, all, 0, Vector2i.RIGHT)
		cell = d.step
		assert_true(rect.has_point(cell), "no cruza al chunk vecino")


func test_theft_elsewhere_does_not_wake_this_bosque() -> void:
	var expl: Node = _exploration()
	EventBus.bosque_robbed.emit(_target)
	assert_eq(expl._field.chasers().size(), 0, "solo los del Bosque en el que estás")


func test_loaded_game_has_no_chasers() -> void:
	var expl: Node = _exploration()
	_steal_at_home()
	assert_gt(expl._field.chasers().size(), 0)
	var save_before: Dictionary = GameState.to_dict()
	assert_false(save_before.has("chasers"), "no se guardan")
	expl.start()
	assert_eq(expl._field.chasers().size(), 0, "al cargar, desaparecen")
	assert_false(expl._chase.is_active())


# --- Combate con los perseguidores --------------------------------------------------------------

func test_chaser_can_be_appeased_paying_the_toll() -> void:
	var logic: BattleLogic = AdventureRules.start_battle(_target, 1, &"ofomni")
	assert_true(logic.accepts_payment)
	assert_gt(logic.toll, 0)
	logic.play_turn(BattleLogic.Action.OFFER_LUZ)
	assert_eq(logic.result, BattleLogic.Result.APPEASED)
	assert_eq(AdventureRules.finish_unico_battle(logic, _target, _home), &"appeased")
	assert_true(AdventureRules.is_paid(_target, _home), "apaciguar paga el peaje del Bosque")


func test_appeasing_at_home_does_not_open_anything() -> void:
	var before: int = AdventureRules.relation(_home)
	var logic: BattleLogic = AdventureRules.start_battle(_home, 1, &"ofomni")
	logic.play_turn(BattleLogic.Action.OFFER_LUZ)
	assert_eq(AdventureRules.finish_unico_battle(logic, _home, _home), &"appeased")
	assert_false(GameState.open_until.has(str(_home)), "el natal no cobra paso: no caduca nada")
	assert_eq(AdventureRules.relation(_home), before + 1)


func test_defeating_a_chaser_adds_hostility_without_forcing() -> void:
	var rel: int = AdventureRules.relation(_target)
	var logic: BattleLogic = AdventureRules.start_battle(_target, 1, &"ofomni")
	logic.result = BattleLogic.Result.VICTORY
	assert_eq(AdventureRules.finish_unico_battle(logic, _target, _home), &"victory")
	assert_eq(AdventureRules.hostility(_target), 1, "como con los Botarramas")
	assert_eq(AdventureRules.relation(_target), rel - 10)
	assert_false(AdventureRules.is_forced(_target), "ya estabas dentro: no fuerza")


func test_exploration_victory_dissolves_one_chaser_and_appeasing_sends_all_home() -> void:
	var expl: Node = _exploration()
	expl._chase.alert(_home, 2)
	expl._spawn_chasers(2)
	var chasers: Array[OverworldMonster] = expl._field.chasers()
	assert_eq(chasers.size(), 2)
	expl._pending_monster = chasers[0]
	EventBus.unico_battle_resolved.emit(_home, &"victory")
	assert_eq(expl._field.chasers().size(), 1, "vencido uno, el otro sigue")
	assert_eq(expl._chase.count, 1)
	assert_false(GameState.defeated_monsters.has(chasers[0].key), "no se guarda como vencido")
	expl._pending_monster = expl._field.chasers()[0]
	EventBus.unico_battle_resolved.emit(_home, &"appeased")
	assert_eq(expl._field.chasers().size(), 0, "apaciguado, se van todos")
	assert_false(expl._chase.is_active())


func test_engaging_a_chaser_starts_a_direct_battle() -> void:
	var expl: Node = _exploration()
	expl._chase.alert(_home, 1)
	expl._spawn_chasers(1)
	watch_signals(EventBus)
	expl._on_monster_engaged(expl._field.chasers()[0])
	assert_signal_emitted_with_parameters(EventBus, "unico_battle_requested", [_home, MonsterField.OFOMNI, false])
	assert_signal_not_emitted(EventBus, "bosque_border_reached", "sin menú del borde")


# --- Confinamiento de la primera misión ----------------------------------------------------------

func test_offered_mission_crossing_home_border_returns_to_villa() -> void:
	var expl: Node = _exploration()
	assert_true(OfomniGuard.is_confined(), "misión ofrecida, sin aceptar")
	var exit: Array = _home_exit()
	expl._enter_chunk(exit[0], expl._get_chunk(exit[0]).hub)
	watch_signals(EventBus)
	expl._on_edge_reached(exit[1])
	assert_signal_not_emitted(EventBus, "bosque_border_reached", "no abre el menú del borde")
	assert_true(expl._capturing)
	assert_eq(expl._field.with_role(MonsterField.ROLE_CAPTOR).size(), 2, "aparecen los Ofomni del Bosque natal")
	assert_true(expl._dialogue.is_open(), "lo cuentan")
	var luz: int = GameState.luz
	var hp: int = GameState.hp
	expl._dialogue.finished.emit()
	var villa: Vector2i = _map.nujio_chunk[_home]
	assert_eq(GameState.chunk_coord, villa, "de vuelta en la villa natal")
	assert_eq(GameState.player_cell, expl._get_chunk(villa).hub, "en la plaza")
	assert_eq(GameState.luz, luz, "sin perder Luz")
	assert_eq(GameState.hp, hp, "ni PV")
	assert_eq(GameState.objective_label, Texts.get_text("compass_sfida"), "la brújula sigue apuntando al sfida")


func test_offered_mission_nearing_the_border_also_captures() -> void:
	var expl: Node = _exploration()
	var exit: Array = _home_exit()
	var side: Vector2i = exit[1]
	expl._enter_chunk(exit[0], expl._get_chunk(exit[0]).hub)
	var mid: int = ChunkData.SIZE / 2
	var far: Vector2i = Vector2i(mid, mid)
	var near: Vector2i = Vector2i(mid, mid)
	if side.x != 0:
		near.x = ChunkData.SIZE - 3 if side.x > 0 else 2
		far.x = ChunkData.SIZE - 4 if side.x > 0 else 3
	else:
		near.y = ChunkData.SIZE - 3 if side.y > 0 else 2
		far.y = ChunkData.SIZE - 4 if side.y > 0 else 3
	assert_false(OfomniGuard.is_near_exit(_map, exit[0], far, _home), "a 4 pasos, todavía no")
	assert_true(OfomniGuard.is_near_exit(_map, exit[0], near, _home), "a 3 pasos, sí")
	expl._on_player_stepped(near)
	assert_true(expl._capturing)


func test_active_mission_lets_you_leave() -> void:
	var expl: Node = _exploration()
	var q: Dictionary = GameState.quests[Q]
	assert_true(QuestLogic.accept(q, _map, 42, _home))
	QuestLogic.commit(Q, q, QuestLogic.OFFERED)
	assert_false(OfomniGuard.is_confined())
	var exit: Array = _home_exit()
	expl._enter_chunk(exit[0], expl._get_chunk(exit[0]).hub)
	watch_signals(EventBus)
	expl._on_edge_reached(exit[1])
	assert_false(expl._capturing, "con la misión activa, nadie te detiene")
	var next: int = _map.bosque_at(exit[0] + exit[1])
	if AdventureRules.is_passable(next, _home):
		assert_ne(GameState.chunk_coord, exit[0], "cruza")
	else:
		assert_signal_emitted_with_parameters(EventBus, "bosque_border_reached", [next])
