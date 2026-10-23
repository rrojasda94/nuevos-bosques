extends Node2D
## Exploración del modo Aventura: dibuja el chunk actual, mueve al jugador y cambia al chunk
## vecino al salir por un borde. Los chunks se regeneran desde la seed (ADR 0006); la caché es
## solo para no recalcular durante la sesión.

const TILE_SIZE: int = 16
## Duración del fundido al cambiar de chunk.
const TRANSITION_TIME: float = 0.2

var _chunk: ChunkData
var _cache: Dictionary = {}
var _region: Dictionary = {}

@onready var _terrain: TileMapLayer = $Terrain
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
	_player.stepped.connect(func(c: Vector2i) -> void: GameState.player_cell = c)


## Arranca la exploración con el estado actual de GameState (partida nueva o cargada).
func start() -> void:
	_region = ChunkGenerator.load_region(GameState.region_id)
	_cache.clear()
	_enter_chunk(GameState.chunk_coord, GameState.player_cell)


func _enter_chunk(coord: Vector2i, cell: Vector2i) -> void:
	_chunk = _get_chunk(coord)
	GameState.chunk_coord = coord
	_draw_chunk()
	if not _chunk.is_walkable(cell):
		cell = ChunkData.center()
	GameState.player_cell = cell
	_player.place_at(cell)
	_camera.reset_smoothing()
	EventBus.chunk_entered.emit(coord)
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


func _on_edge_reached(direction: Vector2i) -> void:
	var along: int = _player.cell.y if direction.x != 0 else _player.cell.x
	var next_coord: Vector2i = GameState.chunk_coord + direction
	var entry: Vector2i = _get_chunk(next_coord).find_entry(-direction, along)
	_enter_chunk(next_coord, entry)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"new_seed"):
		# Elegir una seed nueva no es aleatoriedad de juego: se usa un RNG aparte, no GameState.rng.
		var picker := RandomNumberGenerator.new()
		picker.randomize()
		GameState.new_game(picker.randi_range(1, 999_999_999), GameState.region_id)
		start()
