class_name SleepScreen
extends CanvasLayer
## Pantalla de dormir (bosques-y-relacion.md, "Dormir y Pensamiento"): fundido a negro con un texto
## corto; si hay visión, la pantalla de Pensamiento (glosario §1: "Mundo entre la Luz y el mundo
## físico, a donde va la Mente al dormir"), con un tinte plateado y etéreo, motas de Luz que flotan y
## el texto que se escribe; y al final el texto de despertar y el fundido de vuelta.
## Pausa el árbol mientras se ve (process_mode ALWAYS). No aplica reglas: avisa con blacked_out
## cuando la pantalla está en negro (la exploración salta el tiempo, SleepRules) y con finished al
## terminar.
## Uso: play(texto) -> blacked_out -> show_vision(texto, despertar) o wake(despertar) -> finished.

signal blacked_out
signal finished

const FADE_TIME: float = 0.6
const HOLD_TIME: float = 1.0
const WAKE_HOLD_TIME: float = 1.4
## Letras por segundo del texto de la visión (más lento que los diálogos: se recuerda).
const VISION_SPEED: float = 30.0
const BLACK := Color("181425")
## Tinte de Pensamiento: plata de Riumna y un azul pálido (paleta del juego).
const SILVER := Color("c0cbdc")
const SILVER_DIM := Color("8b9bb4")
const MIST := Color("3a4466")
const MOTE := Color("ffffff")
const MOTES: int = 28

enum Phase { IDLE, FADING, VISION_TYPING, VISION_DONE, WAKING }

var _phase: Phase = Phase.IDLE
var _wake_text: String = ""
var _typed: float = 0.0
var _time: float = 0.0
var _root: Control
var _black: ColorRect
var _vision: Control
var _caption: Label
var _title: Label
var _body: Label
var _recall: Label
var _hint: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.size = Vector2(320, 180)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = load("res://assets/ui/theme.tres")
	add_child(_root)
	_black = ColorRect.new()
	_black.size = _root.size
	_black.color = BLACK
	_root.add_child(_black)
	_vision = Control.new()
	_vision.size = _root.size
	_vision.draw.connect(_draw_vision)
	_root.add_child(_vision)
	_title = _label(Vector2(0, 26), SILVER, HORIZONTAL_ALIGNMENT_CENTER)
	_title.text = Texts.get_text("pensamiento_title")
	_vision.add_child(_title)
	_body = _label(Vector2(30, 52), Color("ffffff"), HORIZONTAL_ALIGNMENT_CENTER)
	_body.size = Vector2(260, 80)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vision.add_child(_body)
	_recall = _label(Vector2(0, 136), SILVER_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_recall.text = Texts.get_text("pensamiento_recall")
	_vision.add_child(_recall)
	_hint = _label(Vector2(296, 160), SILVER, HORIZONTAL_ALIGNMENT_LEFT)
	_hint.text = "v"
	_vision.add_child(_hint)
	_caption = _label(Vector2(10, 84), SILVER, HORIZONTAL_ALIGNMENT_CENTER)
	_caption.size = Vector2(300, 12)
	_root.add_child(_caption)


func _label(pos: Vector2, color: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(320, 12)
	l.horizontal_alignment = align
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_font_size_override(&"font_size", 8)
	return l


func is_playing() -> bool:
	return _phase != Phase.IDLE


## Fundido a negro con `text`; al quedar en negro (y un momento después) emite blacked_out.
func play(text: String) -> void:
	_phase = Phase.FADING
	visible = true
	get_tree().paused = true
	_vision.visible = false
	_black.modulate.a = 0.0
	_caption.text = text
	_caption.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_black, "modulate:a", 1.0, FADE_TIME)
	tween.tween_property(_caption, "modulate:a", 1.0, FADE_TIME * 0.5)
	tween.tween_interval(HOLD_TIME)
	tween.tween_callback(func() -> void: blacked_out.emit())


## Visión de Pensamiento: el texto se escribe; con Aceptar o E se completa y luego se despierta
## con `wake_text`.
func show_vision(text: String, wake_text: String) -> void:
	_wake_text = wake_text
	_body.text = text
	_body.visible_characters = 0
	_typed = 0.0
	_recall.visible = false
	_hint.visible = false
	_vision.visible = true
	_vision.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_caption, "modulate:a", 0.0, FADE_TIME * 0.5)
	tween.tween_property(_vision, "modulate:a", 1.0, FADE_TIME)
	tween.tween_callback(func() -> void: _phase = Phase.VISION_TYPING)


## Despierta: muestra `text` en negro y vuelve al juego (emite finished y quita la pausa).
func wake(text: String) -> void:
	_phase = Phase.WAKING
	_caption.text = text
	var tween: Tween = create_tween()
	if _vision.visible:
		tween.tween_property(_vision, "modulate:a", 0.0, FADE_TIME)
		tween.tween_callback(func() -> void: _vision.visible = false)
	else:
		tween.tween_property(_caption, "modulate:a", 0.0, FADE_TIME * 0.5)
	tween.tween_property(_caption, "modulate:a", 1.0, FADE_TIME * 0.5)
	tween.tween_interval(WAKE_HOLD_TIME)
	tween.tween_property(_caption, "modulate:a", 0.0, FADE_TIME * 0.5)
	tween.tween_property(_black, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(_end)


func _end() -> void:
	_phase = Phase.IDLE
	visible = false
	get_tree().paused = false
	finished.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if _vision.visible:
		_vision.queue_redraw()
	if _phase == Phase.VISION_TYPING:
		_typed += delta * VISION_SPEED
		_body.visible_characters = int(_typed)
		if _body.visible_characters >= _body.get_total_character_count():
			_finish_typing()
	elif _phase == Phase.VISION_DONE:
		_hint.visible = fmod(_time, 0.6) < 0.4


func _finish_typing() -> void:
	_body.visible_characters = -1
	_recall.visible = true
	_phase = Phase.VISION_DONE


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if not (event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"interact")):
		return
	if _phase == Phase.VISION_TYPING:
		_finish_typing()
	elif _phase == Phase.VISION_DONE:
		wake(_wake_text)


## Fondo de Pensamiento: bandas de niebla plateada que respiran y motas de Luz que suben.
func _draw_vision() -> void:
	_vision.draw_rect(Rect2(Vector2.ZERO, _vision.size), BLACK)
	var center := Vector2(160, 90)
	for i: int in 6:
		var r: float = 150.0 - i * 22.0 + sin(_time * 0.8 + i) * 3.0
		var c: Color = MIST.lerp(SILVER_DIM, i / 6.0)
		c.a = 0.18 + 0.05 * i
		_vision.draw_circle(center, r, c)
	for i: int in MOTES:
		var h: int = ChunkGenerator.hash_ints([i, 977])
		var x: float = float(h % 320)
		var speed: float = 6.0 + float((h >> 9) % 10)
		var y: float = fposmod(float((h >> 4) % 180) - _time * speed, 180.0)
		var c: Color = MOTE if i % 3 == 0 else SILVER
		c.a = 0.35 + 0.35 * sin(_time * 2.0 + i)
		_vision.draw_rect(Rect2(Vector2(roundf(x + sin(_time + i) * 2.0), roundf(y)), Vector2.ONE), c)
