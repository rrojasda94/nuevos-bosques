extends GutTest
## Exploración del Mundo 2.0 en el juego (M17a, ADR 0014): partida nueva en la villa natal con el
## RegionPlan registrado (los ids de Bosque de todo el juego salen de plan.bosques), entrada en
## chunks por cell_changed, límite de Bosque, guardado y carga con las claves nuevas y rechazo de
## las partidas del mundo viejo. Un solo mundo (seed 42) para todo el script: crearlo tarda.

const SCENE: String = "res://scenes/world/world_exploration.tscn"
const SAVE_SLOT: int = 94
const SEED: int = 42

var _expl: WorldExploration
var _entered: Array = []


func before_all() -> void:
	WorldClock.set_process(false)
	GameState.new_game(SEED)
	_expl = load(SCENE).instantiate()
	_expl.quick_slot = SAVE_SLOT
	add_child(_expl)
	await _expl.start()
	EventBus.chunk_entered.connect(_on_chunk_entered)


func after_all() -> void:
	EventBus.chunk_entered.disconnect(_on_chunk_entered)
	_expl.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(SaveManager.slot_path(SAVE_SLOT))
	WorldClock.set_process(true)


func _on_chunk_entered(coord: Vector2i, bosque_id: int, _size: int) -> void:
	_entered.append([coord, bosque_id])


func test_new_game_starts_in_home_villa_with_region_plan() -> void:
	assert_true(_expl.started)
	assert_eq(MapLogic.region_plan(), _expl.plan, "el plan de la partida queda registrado")
	assert_eq(MapLogic.current_bosques(), _expl.plan.bosques, "Bosques del plan, no del mundo viejo")
	assert_eq(AdventureRules.current_home(), _expl.home_bosque)
	assert_eq(_expl.plan.bosque_at(GameState.chunk_coord), _expl.home_bosque, "en el Bosque natal")
	assert_eq(GameState.chunk_coord, _expl.bosques.nujio_chunk[_expl.home_bosque], "en el chunk de la villa natal")
	assert_true(WorldCoords.in_chunk(GameState.player_cell), "casilla 0-79")
	assert_false(_expl.world.streamer.is_blocked(_expl.player.mover.cell), "sobre una casilla transitable")
	assert_true(GameState.explored_chunks.has(GameState.chunk_coord))
	assert_false(GameState.world_key.is_empty(), "clave del mundo para la caché")
	assert_eq(GameState.world_key, WorldCache.key_to_name(_expl.world.world_key))


func test_crossing_reads_the_real_world_for_the_tactical_board() -> void:
	var crossing: Node = _expl.get_node(^"Crossing")
	assert_true(crossing.world_get_chunk.is_valid())
	assert_true(crossing.world_player_cell.is_valid())
	assert_eq(crossing.world_player_cell.call(), _expl.player.mover.cell)
	var c: WorldChunk = crossing.world_get_chunk.call(GameState.chunk_coord)
	assert_not_null(c)
	assert_eq(c.coord, GameState.chunk_coord)


func test_cell_changed_enters_the_next_chunk() -> void:
	_entered.clear()
	var from: Vector2i = _expl.player.mover.cell
	var next_chunk: Vector2i = WorldCoords.world_cell_to_chunk(from) + Vector2i(1, 0)
	var cell: Vector2i = WorldCoords.to_world_cell(next_chunk, Vector2i(2, 40))
	_expl._on_cell_changed(cell)
	assert_eq(GameState.chunk_coord, next_chunk)
	assert_eq(GameState.player_cell, Vector2i(2, 40))
	assert_true(GameState.explored_chunks.has(next_chunk), "chunk explorado")
	assert_eq(_entered.size(), 1)
	assert_eq(_entered[0], [next_chunk, _expl.plan.bosque_at(next_chunk)], "EventBus.chunk_entered con el Bosque del plan")
	_expl._on_cell_changed(from)
	assert_eq(GameState.chunk_coord, WorldCoords.world_cell_to_chunk(from))


func test_closed_bosque_cell_blocks_the_player() -> void:
	var plan: RegionPlan = _expl.plan
	var closed: Vector2i = Vector2i(-1, -1)
	for y: int in plan.size_chunks.y:
		for x: int in plan.size_chunks.x:
			var b: int = plan.bosque_at(Vector2i(x, y))
			if closed.x < 0 and b >= 0 and not AdventureRules.is_passable(b, _expl.home_bosque):
				closed = Vector2i(x, y)
	assert_true(closed.x >= 0, "hay un Bosque cerrado")
	var cell: Vector2i = WorldCoords.to_world_cell(closed, Vector2i(40, 40))
	assert_true(_expl.player.is_blocked.call(cell), "otro Bosque cerrado bloquea")


func test_save_has_world_2_keys_and_loads_back() -> void:
	var cell: Vector2i = _expl.player.mover.cell
	GameState.luz = 7
	assert_eq(_expl.quick_save(), OK)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.slot_path(SAVE_SLOT)))
	assert_eq(int(data.save_version), GameState.SAVE_VERSION)
	assert_eq(int(data.generator_version), GameState.GENERATOR_VERSION)
	assert_eq(str(data.world_key), GameState.world_key)
	assert_eq(Vector2i(int(data.player_cell[0]), int(data.player_cell[1])), WorldCoords.world_cell_to_cell(cell))
	assert_eq(data.player_facing.size(), 2)
	GameState.luz = 1
	assert_eq(_expl.quick_load(), OK)
	await wait_until(func() -> bool: return _expl.started, 30.0)
	assert_eq(GameState.luz, 7)
	assert_eq(_expl.player.mover.cell, cell, "vuelve a la misma casilla")


func test_old_world_save_is_rejected() -> void:
	var old: Dictionary = GameState.to_dict()
	old.save_version = 19
	old.erase("generator_version")
	var file := FileAccess.open(SaveManager.slot_path(SAVE_SLOT), FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	assert_eq(SaveManager.load_game(SAVE_SLOT), SaveManager.ERR_SAVE_OLD_WORLD)
	assert_eq(_expl.quick_load(), SaveManager.ERR_SAVE_OLD_WORLD)
	assert_true(_expl.started, "la partida en curso sigue")
	get_tree().paused = false
