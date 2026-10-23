extends Node2D
## Exploración del modo Aventura: dibuja el chunk actual y una franja de los chunks vecinos (para
## ver el color de la vegetación del Bosque de al lado), mueve al jugador y cambia al chunk vecino
## al salir por un borde, siempre dentro del Bosque inicial (ADR 0006). Los chunks se regeneran
## desde la seed; la caché es solo para no recalcular durante la sesión.

const TILE_SIZE: int = 16
## Duración del fundido al cambiar de chunk.
const TRANSITION_TIME: float = 0.2
## Casillas de cada chunk vecino que se dibujan alrededor del actual.
const NEIGHBOUR_MARGIN: int = 12

var _chunk: ChunkData
var _cache: Dictionary = {}
var _region: Dictionary = {}
var _bosques: BosqueMap
var _home_bosque: int = -1
var _nujio_textures: Dictionary = {}
## Evita repetir el aviso cada frame mientras se empuja contra un borde bloqueado.
var _blocked_dir: Vector2i = Vector2i.ZERO
var _last_sign: Vector2i = Vector2i(-1, -1)

@onready var _terrain: TileMapLayer = $Terrain
@onready var _nujios: Node2D = $Nujios
@onready var _player: PlayerWalker = $Player
@onready var _camera: Camera2D = $Player/Camera2D
@onready var _fade: ColorRect = $Transition/Fade


func _ready() -> void:
	_player.is_walkable = func(c: Vector2i) -> bool: return _chunk != null and _chunk.is_walkable(c)
	_player.edge_reached.connect(_on_edge_reached)
	_player.stepped.connect(_on_player_stepped)


## Arranca la exploración con el estado actual de GameState (partida nueva o cargada).
func start() -> void:
	_region = ChunkGenerator.load_region(GameState.region_id)
	_cache.clear()
	_nujio_textures.clear()
	_terrain.tile_set = PlaceholderTileset.make_tile_set()
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
	_check_sign(cell)


func _enter_chunk(coord: Vector2i, cell: Vector2i) -> void:
	_blocked_dir = Vector2i.ZERO
	_last_sign = Vector2i(-1, -1)
	_chunk = _get_chunk(coord)
	GameState.chunk_coord = coord
	_draw_area()
	if not _chunk.is_walkable(cell):
		cell = _chunk.hub
	GameState.player_cell = cell
	_player.place_at(cell)
	_camera.reset_smoothing()
	EventBus.chunk_entered.emit(coord, _home_bosque, _bosques.size_of(_home_bosque))
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, TRANSITION_TIME)


func _get_chunk(coord: Vector2i) -> ChunkData:
	if not _cache.has(coord):
		_cache[coord] = ChunkGenerator.generate(GameState.seed_value, coord, _region, _bosques)
		EventBus.chunk_generated.emit(GameState.region_id, GameState.seed_value)
	return _cache[coord]


## Dibuja el chunk actual, una franja de cada vecino dentro de la región y los Nujios visibles.
## Ajusta los límites de la cámara a lo dibujado.
func _draw_area() -> void:
	_terrain.clear()
	for child: Node in _nujios.get_children():
		child.queue_free()
	var size: int = ChunkData.SIZE
	var m: int = NEIGHBOUR_MARGIN
	var limits := Rect2i(0, 0, size, size)
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var offset := Vector2i(dx, dy)
			var bosque_id: int = _bosques.bosque_at(_chunk.coord + offset)
			if bosque_id < 0:
				continue
			_ensure_source(bosque_id)
			var chunk: ChunkData = _get_chunk(_chunk.coord + offset)
			var from := Vector2i(0 if dx >= 0 else size - m, 0 if dy >= 0 else size - m)
			var to := Vector2i(size if dx <= 0 else m, size if dy <= 0 else m)
			_draw_chunk(chunk, bosque_id, offset * size, Rect2i(from, to - from))
			limits = limits.merge(Rect2i(offset * size + from, to - from))
	_camera.limit_left = limits.position.x * TILE_SIZE
	_camera.limit_top = limits.position.y * TILE_SIZE
	_camera.limit_right = limits.end.x * TILE_SIZE
	_camera.limit_bottom = limits.end.y * TILE_SIZE


func _draw_chunk(chunk: ChunkData, bosque_id: int, offset: Vector2i, area: Rect2i) -> void:
	var sign_dir: int = _sign_direction_index(chunk.coord, bosque_id)
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var c := Vector2i(x, y)
			_terrain.set_cell(offset + c, bosque_id, Vector2i(chunk.get_tile(c), PlaceholderTileset.variant_for(chunk, c, sign_dir)))
	if chunk.nujio_rect.size.x > 0:
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = _nujio_texture(bosque_id)
		sprite.position = Vector2((offset + chunk.nujio_rect.position) * TILE_SIZE)
		_nujios.add_child(sprite)


func _ensure_source(bosque_id: int) -> void:
	var tile_set: TileSet = _terrain.tile_set
	if not tile_set.has_source(bosque_id):
		tile_set.add_source(PlaceholderTileset.make_source(_bosques.styles[bosque_id]), bosque_id)


func _nujio_texture(bosque_id: int) -> Texture2D:
	if not _nujio_textures.has(bosque_id):
		_nujio_textures[bosque_id] = PlaceholderTileset.nujio_texture(_bosques.styles[bosque_id], _bosques.nujio_size[bosque_id])
	return _nujio_textures[bosque_id]


## Índice de dirección (0 = este, sentido horario) hacia la villa del Bosque, o 0 si no hay.
func _sign_direction_index(coord: Vector2i, bosque_id: int) -> int:
	if not _bosques.has_villa[bosque_id]:
		return 0
	return ChunkGenerator.direction_index(_bosques.nujio_chunk[bosque_id] - coord)


## Al pisar un letrero de piedra o estar al lado, el HUD indica hacia dónde queda la villa.
func _check_sign(cell: Vector2i) -> void:
	for d: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var c: Vector2i = cell + d
		if ChunkData.in_bounds(c) and _chunk.get_tile(c) == ChunkData.Tile.SIGN:
			if c != _last_sign:
				_last_sign = c
				var to_villa: Vector2i = _bosques.nujio_chunk[_home_bosque] - _chunk.coord
				EventBus.signpost_read.emit(ChunkGenerator.direction_name(to_villa))
			return
	_last_sign = Vector2i(-1, -1)


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
