class_name PlayerWalker
extends Node2D
## Personaje de exploración: se mueve por casillas con un tween entre casillas (RPG clásico).
## No conoce el mapa: pregunta a `is_walkable` y avisa con `edge_reached` al intentar salir del chunk.
## Sprite: la hoja SHEET_PATH (4 direcciones x 2 fotogramas, cambia de fotograma en cada paso); si
## falta el PNG, el placeholder procedural de _make_texture.

signal edge_reached(direction: Vector2i)
signal stepped(cell: Vector2i)

## Segundos por casilla andando. AJUSTAR AQUÍ la sensación de movimiento.
const STEP_TIME: float = 0.16
## Al mantener "correr" (Shift) cada paso dura STEP_TIME / RUN_MULTIPLIER.
const RUN_MULTIPLIER: float = 2.0
## Píxeles que sube el sprite a mitad de paso (rebote de andar).
const STEP_BOB: float = 1.0
const TILE_SIZE: int = 16
## Hoja del Adoc (docs/art/specs/primera-pasada.md): una fila por dirección, 2 fotogramas.
const SHEET_PATH: String = "res://assets/sprites/sprite_adoc_walk.png"
const SHEET_ROWS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]
const SHEET_FRAMES: int = 2
## Suena el paso (Sfx "step") uno de cada STEP_SOUND_EVERY pasos, para no cansar.
const STEP_SOUND_EVERY: int = 2

const ACTIONS: Dictionary = {
	&"move_up": Vector2i.UP,
	&"move_down": Vector2i.DOWN,
	&"move_left": Vector2i.LEFT,
	&"move_right": Vector2i.RIGHT,
}

## Segundos por casilla andando ahora: STEP_TIME o menos con un talismán de viaje (Stealth.step_time;
## lo fija la escena que contiene al jugador).
var step_time: float = STEP_TIME
## (Vector2i) -> bool. Lo asigna la escena que contiene al jugador.
var is_walkable: Callable = func(_c: Vector2i) -> bool: return true
var cell: Vector2i = Vector2i.ZERO
var facing: Vector2i = Vector2i.DOWN

## Direcciones mantenidas, la última pulsada manda (giros limpios al cambiar de tecla).
var _held: Array[StringName] = []
var _tween: Tween
var _textures: Dictionary = {}
var _has_sheet: bool = false
var _frame: int = 0
var _steps: int = 0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_has_sheet = ResourceLoader.exists(SHEET_PATH)
	if _has_sheet:
		_sprite.texture = load(SHEET_PATH)
		_sprite.hframes = SHEET_FRAMES
		_sprite.vframes = SHEET_ROWS.size()
	else:
		for dir: Vector2i in ACTIONS.values():
			_textures[dir] = _make_texture(dir)
	_update_sprite()


func _update_sprite() -> void:
	if _has_sheet:
		_sprite.frame_coords = Vector2i(_frame, SHEET_ROWS.find(facing))
	else:
		_sprite.texture = _textures[facing]


func place_at(new_cell: Vector2i) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	_sprite.position = Vector2.ZERO
	cell = new_cell
	position = cell_to_position(cell)


static func cell_to_position(c: Vector2i) -> Vector2:
	return Vector2(c * TILE_SIZE) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5


func is_moving() -> bool:
	return _tween != null and _tween.is_running()


func _unhandled_input(event: InputEvent) -> void:
	for action: StringName in ACTIONS:
		if event.is_action_pressed(action):
			_held.erase(action)
			_held.append(action)
		elif event.is_action_released(action):
			_held.erase(action)


func _notification(what: int) -> void:
	# Al perder el foco (alt-tab, ventana incrustada en el editor) los "released" pueden no llegar.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_held.clear()


func _process(_delta: float) -> void:
	if not is_moving():
		_try_step()


func _try_step() -> void:
	# Si la ventana pierde el foco se puede perder un "released": se filtra contra el estado real.
	_held = _held.filter(func(a: StringName) -> bool: return Input.is_action_pressed(a))
	if _held.is_empty():
		return
	var dir: Vector2i = ACTIONS[_held.back()]
	if dir != facing:
		facing = dir
		_update_sprite()
	var target: Vector2i = cell + dir
	if not ChunkData.in_bounds(target):
		edge_reached.emit(dir)
		return
	if not is_walkable.call(target):
		return
	cell = target
	_frame = (_frame + 1) % SHEET_FRAMES
	_update_sprite()
	_steps += 1
	if _steps % STEP_SOUND_EVERY == 0:
		Sfx.play(&"step")
	var time: float = step_time
	if Input.is_action_pressed(&"run"):
		time /= RUN_MULTIPLIER
	_tween = create_tween()
	_tween.tween_property(self, "position", cell_to_position(target), time)
	_tween.parallel().tween_property(_sprite, "position:y", -STEP_BOB, time * 0.5)
	_tween.parallel().tween_property(_sprite, "position:y", 0.0, time * 0.5).set_delay(time * 0.5)
	_tween.finished.connect(_on_step_finished)


func _on_step_finished() -> void:
	_tween = null
	stepped.emit(cell)
	# Encadenar el siguiente paso en el mismo frame evita un tirón entre casillas.
	_try_step()


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
			for d: Vector2i in ChunkData.SIDES:
				var p := Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and filled.get_pixelv(p).a > 0.0:
					img.set_pixel(x, y, color)
					break
