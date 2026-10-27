class_name PlayerController
extends Node2D
## Jugador con movimiento libre en 8 direcciones (ADR 0014 §2). Lee la entrada en
## _physics_process, mueve con su GridMover y ajusta el dibujo al píxel. El nodo está en los pies:
## `position` es `world_pos` redondeado. No conoce el mapa: pregunta a `is_blocked`.
## Sprite: la hoja SHEET_PATH (4 direcciones x 2 fotogramas); si falta el PNG, el placeholder
## procedural de _make_texture. La hoja y el placeholder los usan también el combate y otros adoc.

## Reenvía GridMover.cell_changed: las reglas cuelgan de aquí, nunca de la posición en píxeles.
signal cell_changed(world_cell: Vector2i)

## Segundos por casilla de referencia del sigilo (Stealth.step_time): la velocidad del talismán de
## viaje se aplica como STEP_TIME / Stealth.step_time(STEP_TIME) (speed_scale).
const STEP_TIME: float = 0.16
const TILE_SIZE: int = 16
## Hoja del Adoc (docs/art/specs/primera-pasada.md): una fila por dirección, 2 fotogramas.
const SHEET_PATH: String = "res://assets/sprites/sprite_adoc_walk.png"
const SHEET_ROWS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]
const SHEET_FRAMES: int = 2

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
	_sprite.position = Vector2(0, -TILE_SIZE * 0.5)
	_has_sheet = ResourceLoader.exists(SHEET_PATH)
	if _has_sheet:
		_sprite.texture = load(SHEET_PATH)
		_sprite.hframes = SHEET_FRAMES
		_sprite.vframes = SHEET_ROWS.size()
	else:
		for dir: Vector2i in SHEET_ROWS:
			_textures[dir] = _make_texture(dir)
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
		var frame: int = mover.anim_frame() % SHEET_FRAMES
		_sprite.frame_coords = Vector2i(frame, SHEET_ROWS.find(mover.facing))
	else:
		_sprite.texture = _textures[mover.facing]


func _on_footstep() -> void:
	Sfx.play(&"step")


## El Adoc de espaldas (combate): primer fotograma de la fila "arriba" de la hoja, o el placeholder.
static func back_texture() -> Texture2D:
	if not ResourceLoader.exists(SHEET_PATH):
		return _make_texture(Vector2i.UP)
	var sheet: Texture2D = load(SHEET_PATH)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	var size := Vector2(sheet.get_width() / SHEET_FRAMES, sheet.get_height() / SHEET_ROWS.size())
	atlas.region = Rect2(Vector2(0, size.y * SHEET_ROWS.find(Vector2i.UP)), size)
	return atlas


## Sprite de placeholder 16x16 con colores de la paleta: túnica roja, pelo castaño.
static func _make_texture(dir: Vector2i) -> Texture2D:
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var skin := Color("e8b796")
	var hair := Color("733e39")
	var tunic := Color("e43b44")
	var belt := Color("3e2731")
	var legs := Color("3a4466")
	var outline := Color("181425")
	img.fill_rect(Rect2i(5, 2, 6, 6), skin)
	img.fill_rect(Rect2i(5, 2, 6, 2), hair)
	if dir == Vector2i.UP:
		img.fill_rect(Rect2i(5, 2, 6, 6), hair)
	elif dir == Vector2i.LEFT:
		img.fill_rect(Rect2i(9, 2, 2, 5), hair)
	elif dir == Vector2i.RIGHT:
		img.fill_rect(Rect2i(5, 2, 2, 5), hair)
	img.fill_rect(Rect2i(4, 8, 8, 5), tunic)
	img.fill_rect(Rect2i(4, 11, 8, 1), belt)
	img.fill_rect(Rect2i(5, 13, 2, 2), legs)
	img.fill_rect(Rect2i(9, 13, 2, 2), legs)
	if dir == Vector2i.DOWN:
		img.set_pixel(6, 5, outline)
		img.set_pixel(9, 5, outline)
	elif dir == Vector2i.LEFT:
		img.set_pixel(5, 5, outline)
	elif dir == Vector2i.RIGHT:
		img.set_pixel(10, 5, outline)
	add_outline(img, outline)
	return ImageTexture.create_from_image(img)


## Contorno: pinta de `color` los píxeles vacíos que tocan algo pintado (también para los NPC).
static func add_outline(img: Image, color: Color) -> void:
	var filled := img.duplicate() as Image
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y: int in h:
		for x: int in w:
			if filled.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in WorldChunk.SIDES:
				var p := Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and filled.get_pixelv(p).a > 0.0:
					img.set_pixel(x, y, color)
					break
