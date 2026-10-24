class_name DialogueBox
extends Panel
## Caja de diálogo reutilizable (exploración y combate): muestra líneas una a una con efecto de
## máquina de escribir y una flecha que parpadea al terminar cada línea. Aceptar (ui_accept,
## ui_cancel o interact) completa la línea o pasa a la siguiente; al acabar emite `finished`.
## Con ask() muestra una lista de opciones (OptionMenu) y emite `choice`. Una línea con
## "arrow": Vector2i dibuja una flecha grande hacia esa dirección (letreros).
## La lógica vive en DialogueQueue; aquí solo se dibuja y se recibe la entrada.

## Se emite al pasar la última línea.
signal finished
## Se emite al empezar a mostrarse cada línea (el combate actualiza las barras con ella).
signal line_started(line: Dictionary)
## Índice de la opción elegida en ask(). Cancelar elige la última opción.
signal choice(index: int)

## Letras por segundo. AJUSTAR AQUÍ la velocidad del texto (combate y diálogos).
const TEXT_SPEED: float = 45.0
## Parpadeo de la flecha: periodo y parte del periodo en que se ve.
const BLINK_PERIOD: float = 0.6
const BLINK_ON: float = 0.4
const TEXT_TOP: float = 2.0
const TEXT_TOP_WITH_SPEAKER: float = 12.0
const CHOICE_ROW: float = 12.0
const CHOICE_WIDTH: float = 80.0
## Hueco a la derecha del texto cuando la línea lleva flecha.
const ARROW_SPACE: float = 40.0

## La caja lee la entrada ella misma. false si el padre le pasa los eventos con handle().
@export var handle_input: bool = true
## Pausa el árbol mientras está abierta (exploración). Necesita process_mode ALWAYS.
@export var pause_tree: bool = false
## Se oculta al terminar las líneas o al elegir una opción.
@export var hide_when_done: bool = true

var _queue := DialogueQueue.new()
var _blink: float = 0.0
var _asking: bool = false

@onready var _speaker: Label = $Speaker
@onready var _text: Label = $Text
@onready var _more: CanvasItem = $More
@onready var _arrow: Polygon2D = $Arrow
@onready var _choices: Control = $Choices
@onready var _menu: OptionMenu = $Choices/Options


func _ready() -> void:
	_choices.visible = false
	_more.visible = false
	resized.connect(_layout)
	_layout()
	if hide_when_done:
		visible = false


## Abre la caja con estas líneas: cada una es { "speaker", "text" } o un texto suelto.
func show_lines(lines: Array) -> void:
	_open()
	if _queue.start(lines):
		_show_current()
	else:
		_end()


## Texto fijo, sin escritura ni flecha, que no espera a que se pulse (p. ej. "¿Qué hará el Adoc?").
func show_static(line: Variant) -> void:
	_queue.start([])
	_set_line(DialogueQueue.normalize(line))
	_text.visible_characters = -1
	_more.visible = false


## Pregunta con opciones. `line`: el texto de la pregunta; `options`: textos de las opciones.
func ask(line: Variant, options: Array) -> void:
	_open()
	show_static(line)
	var texts: Array[String] = []
	var enabled: Array[bool] = []
	for o: Variant in options:
		texts.append(str(o))
		enabled.append(true)
	_menu.set_options(texts, enabled)
	_choices.size = Vector2(CHOICE_WIDTH, CHOICE_ROW * texts.size() + 4.0)
	_choices.position = Vector2(size.x - CHOICE_WIDTH, -_choices.size.y - 2.0)
	_choices.visible = true
	_asking = true


func is_open() -> bool:
	return _queue.is_active or _asking


func _unhandled_input(event: InputEvent) -> void:
	if handle_input and is_open() and not event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
		handle(event)


## Procesa un evento. true si lo ha usado.
func handle(event: InputEvent) -> bool:
	if _asking:
		var picked: int = _menu.handle(event)
		if picked == OptionMenu.CANCEL:
			picked = _menu.get_child_count() - 1
		if picked < 0:
			return false
		_asking = false
		_choices.visible = false
		_close()
		choice.emit(picked)
		return true
	if not _queue.is_active:
		return false
	if not (event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel") \
			or event.is_action_pressed(&"interact")):
		return false
	match _queue.press():
		DialogueQueue.Press.COMPLETED:
			_on_typed()
		DialogueQueue.Press.NEXT:
			_show_current()
		DialogueQueue.Press.FINISHED:
			_end()
	return true


func _process(delta: float) -> void:
	if _queue.is_typing:
		if _queue.tick(delta, TEXT_SPEED, _text.get_total_character_count()):
			_on_typed()
		else:
			_text.visible_characters = _queue.visible_chars
	elif _queue.is_active:
		_blink += delta
		_more.visible = fmod(_blink, BLINK_PERIOD) < BLINK_ON


func _open() -> void:
	visible = true
	if pause_tree:
		get_tree().paused = true


func _close() -> void:
	if pause_tree:
		get_tree().paused = false
	if hide_when_done:
		visible = false


func _show_current() -> void:
	_set_line(_queue.current)
	_text.visible_characters = 0
	_more.visible = false
	line_started.emit(_queue.current)


func _set_line(line: Dictionary) -> void:
	var speaker: String = line.get("speaker", "")
	_speaker.text = speaker
	_speaker.visible = speaker != ""
	_text.offset_top = TEXT_TOP_WITH_SPEAKER if speaker != "" else TEXT_TOP
	_text.text = line.get("text", "")
	var arrow: Vector2i = line.get("arrow", Vector2i.ZERO)
	_arrow.visible = arrow != Vector2i.ZERO
	_arrow.rotation = Vector2(arrow).angle()
	_text.offset_right = -5.0 - (ARROW_SPACE if _arrow.visible else 0.0)


func _on_typed() -> void:
	_text.visible_characters = -1
	_blink = 0.0
	_more.visible = true


func _end() -> void:
	_more.visible = false
	_close()
	finished.emit()


func _layout() -> void:
	(_more as Node2D).position = Vector2(size.x - 11.0, size.y - 8.0)
	_arrow.position = Vector2(size.x - ARROW_SPACE / 2.0 - 4.0, size.y / 2.0)
