class_name PlayerController
extends Node2D
## Jugador con movimiento libre en 8 direcciones (ADR 0014 §2). Lee la entrada en
## _physics_process, mueve con su GridMover y ajusta el dibujo al píxel. El nodo está en los pies:
## `position` es `world_pos` redondeado. No conoce el mapa: pregunta a `is_blocked`.
## Sustituirá a PlayerWalker en M17; mientras tanto reutiliza su hoja, contorno y placeholder.

## Reenvía GridMover.cell_changed: las reglas cuelgan de aquí, nunca de la posición en píxeles.
signal cell_changed(world_cell: Vector2i)

## (Vector2i) -> bool, en casillas globales. Lo asigna la escena que contiene al jugador.
var is_blocked: Callable = func(_c: Vector2i) -> bool: return false
## Multiplicador de velocidad (p. ej. talismán de viaje); lo fija la escena.
var speed_scale: float = 1.0
## Si es false no lee la entrada (diálogos, menús).
var input_enabled: bool = true
var mover: GridMover = GridMover.from_config()

var _sprite: Sprite2D
var _textures: Dictionary = {}
var _has_sheet: bool = false
var _walk_speed: float = MovementConfig.walk_speed()
var _run_speed: float = MovementConfig.run_speed()


func _ready() -> void:
	_sprite = get_node_or_null(^"Sprite2D") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = &"Sprite2D"
		add_child(_sprite)
	# Pies en el origen del nodo: el sprite de 16×16 queda encima.
	_sprite.position = Vector2(0, -PlayerWalker.TILE_SIZE * 0.5)
	_has_sheet = ResourceLoader.exists(PlayerWalker.SHEET_PATH)
	if _has_sheet:
		_sprite.texture = load(PlayerWalker.SHEET_PATH)
		_sprite.hframes = PlayerWalker.SHEET_FRAMES
		_sprite.vframes = PlayerWalker.SHEET_ROWS.size()
	else:
		for dir: Vector2i in PlayerWalker.SHEET_ROWS:
			# ponytail: _make_texture es de PlayerWalker; pasa aquí cuando se borre en M17.
			_textures[dir] = PlayerWalker._make_texture(dir)
	mover.cell_changed.connect(cell_changed.emit)
	mover.footstep.connect(_on_footstep)
	_sync()


## Coloca los pies en una posición global sin emitir cell_changed.
func place_at(pos: Vector2) -> void:
	mover.place(pos)
	_sync()


## Coloca los pies en el centro de una casilla global.
func place_at_cell(c: Vector2i) -> void:
	place_at(GridMover.cell_center(c))


func _physics_process(delta: float) -> void:
	if not input_enabled:
		return
	var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var speed: float = _run_speed if Input.is_action_pressed(&"run") else _walk_speed
	mover.step(input, speed * speed_scale, delta, is_blocked)
	_sync()


func _sync() -> void:
	position = mover.world_pos.round()
	if _has_sheet:
		var frame: int = mover.anim_frame() % PlayerWalker.SHEET_FRAMES
		_sprite.frame_coords = Vector2i(frame, PlayerWalker.SHEET_ROWS.find(mover.facing))
	else:
		_sprite.texture = _textures[mover.facing]


func _on_footstep() -> void:
	Sfx.play(&"step")
