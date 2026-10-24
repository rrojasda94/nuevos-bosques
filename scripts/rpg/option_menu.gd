class_name OptionMenu
extends VBoxContainer
## Lista vertical de opciones con cursor, para teclado o mando (ui_up/ui_down/ui_accept/ui_cancel).
## Las opciones desactivadas se ven en gris y el cursor las salta (o, con skip_disabled = false,
## se pueden marcar y aceptarlas devuelve DISABLED, para que quien la usa explique por qué).
## Quien la contiene le pasa los eventos con handle(). Suena al mover el cursor y al aceptar (Sfx).

const NONE: int = -1
const CANCEL: int = -2
## Se aceptó una opción desactivada (solo con skip_disabled = false); `index` dice cuál.
const DISABLED: int = -3
const COLOR_ON := Color("ffffff")
const COLOR_OFF := Color("5a6988")
const COLOR_CURSOR := Color("fee761")

var index: int = 0
var skip_disabled: bool = true
var _texts: Array[String] = []
var _enabled: Array[bool] = []


## `keep_cursor`: conserva la opción marcada si sigue activa (si no, vuelve a la primera).
func set_options(texts: Array[String], enabled: Array[bool], keep_cursor: bool = false) -> void:
	var previous: int = index
	_texts = texts
	_enabled = enabled
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for i: int in texts.size():
		var label := Label.new()
		label.add_theme_font_size_override(&"font_size", 8)
		label.add_theme_constant_override(&"line_spacing", -2)
		add_child(label)
	index = previous if keep_cursor and previous < texts.size() else 0
	if not _enabled[index] and skip_disabled:
		_move(1)
	_redraw()


## Devuelve el índice elegido con ui_accept, CANCEL con ui_cancel o NONE.
func handle(event: InputEvent) -> int:
	var before: int = index
	if event.is_action_pressed(&"ui_up", true):
		_move(-1)
	elif event.is_action_pressed(&"ui_down", true):
		_move(1)
	elif event.is_action_pressed(&"ui_accept"):
		if not _enabled[index]:
			return NONE if skip_disabled else DISABLED
		Sfx.play(&"menu_accept")
		return index
	elif event.is_action_pressed(&"ui_cancel"):
		return CANCEL
	if index != before:
		Sfx.play(&"menu_move")
	return NONE


func _move(step: int) -> void:
	for i: int in _texts.size():
		var next: int = posmod(index + step * (i + 1), _texts.size())
		if _enabled[next] or not skip_disabled:
			index = next
			break
	_redraw()


func _redraw() -> void:
	for i: int in get_child_count():
		var label := get_child(i) as Label
		label.text = ("> " if i == index else "  ") + _texts[i]
		var color: Color = COLOR_OFF if not _enabled[i] else (COLOR_CURSOR if i == index else COLOR_ON)
		label.add_theme_color_override(&"font_color", color)
