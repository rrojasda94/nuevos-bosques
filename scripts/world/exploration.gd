extends Node2D
## Exploración del modo Aventura: dibuja el chunk actual, mueve al jugador y cambia al chunk
## vecino al salir por un borde, siempre dentro del Bosque inicial (ADR 0006). Los chunks se
## regeneran desde la seed; la caché es solo para no recalcular durante la sesión.

const TILE_SIZE: int = 16
## Duración del fundido al cambiar de chunk.
const TRANSITION_TIME: float = 0.2
## Marca de los bordes que no se pueden cruzar (otro Bosque o límite de la región).
const BORDER_COLOR := Color("f77622")
const BORDER_WIDTH: float = 2.0

var _chunk: ChunkData
var _cache: Dictionary = {}
var _region: Dictionary = {}
var _bosques: BosqueMap
var _home_bosque: int = -1
## Evita repetir el aviso cada frame mientras se empuja contra un borde bloqueado.
var _blocked_dir: Vector2i = Vector2i.ZERO

@onready var _terrain: TileMapLayer = $Terrain
@onready var _borders: Node2D = $Borders
@onready var _player: PlayerWalker = $Player
@onready var _camera: Camera2D = $Player/Camera2D
@onready var _fade: ColorRect = $Transition/Fade


func _ready() -> void:
	_terrain.tile_set = PlaceholderTileset.build()
	var world_px: int = ChunkData.SIZE * TILE_SIZE
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = world_px
	_camera.limit_bottom = world_px
	_player.is_walkable = func(c: Vector2i) -> bool: return _chunk != null and _chunk.is_walkable(c)
	_player.edge_reached.connect(_on_edge_reached)
	_player.stepped.connect(_on_player_stepped)


## Arranca la exploración con el estado actual de GameState (partida nueva o cargada).
func start() -> void:
	_region = ChunkGenerator.load_region(GameState.region_id)
	_cache.clear()
	_bosques = BosqueMap.build(GameState.seed_value, ChunkGenerator.region_size(_region))
	var start_chunk: Vector2i = ChunkGenerator.region_start_chunk(_region)
	_home_bosque = _bosques.bosque_at(start_chunk)
	var coord: Vector2i = GameState.chunk_coord
	if _bosques.bosque_at(coord) != _home_bosque:
		coord = start_chunk
	_enter_chunk(coord, GameState.player_cell)


func _on_player_stepped(cell: Vector2i) -> void:
	GameState.player_cell = cell
	_blocked_dir = Vector2i.ZERO


func _enter_chunk(coord: Vector2i, cell: Vector2i) -> void:
	_blocked_dir = Vector2i.ZERO
	_chunk = _get_chunk(coord)
	GameState.chunk_coord = coord
	_draw_chunk()
	_draw_borders()
	if not _chunk.is_walkable(cell):
		cell = ChunkData.center()
	GameState.player_cell = cell
	_player.place_at(cell)
	_camera.reset_smoothing()
	EventBus.chunk_entered.emit(coord, _home_bosque, _bosques.size_of(_home_bosque))
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, TRANSITION_TIME)


func _get_chunk(coord: Vector2i) -> ChunkData:
	if not _cache.has(coord):
		_cache[coord] = ChunkGenerator.generate(GameState.seed_value, coord, _region)
		EventBus.chunk_generated.emit(GameState.region_id, GameState.seed_value)
	return _cache[coord]


func _draw_chunk() -> void:
	_terrain.clear()
	var origin: Vector2i = _chunk.coord * ChunkData.SIZE
	for y: int in ChunkData.SIZE:
		for x: int in ChunkData.SIZE:
			var c := Vector2i(x, y)
			var variant: int = PlaceholderTileset.variant_for(origin + c)
			_terrain.set_cell(c, 0, Vector2i(_chunk.get_tile(c), variant))


## Línea naranja en los bordes que dan a otro Bosque o fuera de la región.
func _draw_borders() -> void:
	for child: Node in _borders.get_children():
		child.queue_free()
	var px: float = ChunkData.SIZE * TILE_SIZE
	var inset: float = BORDER_WIDTH * 0.5
	var lines: Dictionary = {
		Vector2i.LEFT: [Vector2(inset, 0), Vector2(inset, px)],
		Vector2i.RIGHT: [Vector2(px - inset, 0), Vector2(px - inset, px)],
		Vector2i.UP: [Vector2(0, inset), Vector2(px, inset)],
		Vector2i.DOWN: [Vector2(0, px - inset), Vector2(px, px - inset)],
	}
	for side: Vector2i in ChunkData.SIDES:
		if _bosques.bosque_at(_chunk.coord + side) == _home_bosque:
			continue
		var line := Line2D.new()
		line.width = BORDER_WIDTH
		line.default_color = BORDER_COLOR
		line.points = PackedVector2Array(lines[side])
		_borders.add_child(line)


func _on_edge_reached(direction: Vector2i) -> void:
	var next_coord: Vector2i = GameState.chunk_coord + direction
	var next_bosque: int = _bosques.bosque_at(next_coord)
	if next_bosque != _home_bosque:
		if direction != _blocked_dir:
			_blocked_dir = direction
			EventBus.bosque_border_reached.emit(next_bosque)
		return
	var along: int = _player.cell.y if direction.x != 0 else _player.cell.x
	var entry: Vector2i = _get_chunk(next_coord).find_entry(-direction, along)
	_enter_chunk(next_coord, entry)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"new_seed"):
		# Elegir una seed nueva no es aleatoriedad de juego: se usa un RNG aparte, no GameState.rng.
		var picker := RandomNumberGenerator.new()
		picker.randomize()
		GameState.new_game(picker.randi_range(1, 999_999_999), GameState.region_id)
		start()
