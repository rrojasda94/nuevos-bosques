class_name GrowthPage
extends Control
## Pestaña "Crecer" de la pantalla I (moralidad-y-progresion.md, "Puntos de stats al subir de nivel"):
## reparto de los puntos de stat. A la izquierda, los puntos que quedan y las compras (ATQ y DEF a 3
## puntos, Vigor y Luz a 1), Confirmar y Deshacer; a la derecha, cómo quedan los stats con el reparto
## y lo que da cada nivel solo. Aceptar sobre un stat lo añade al reparto (borrador); Confirmar lo
## aplica (AdocGrowth.apply_draft) y Deshacer lo vacía. Cerrar la pantalla o cambiar de pestaña sin
## confirmar descarta el borrador. Las reglas están en AdocGrowth; aquí solo se dibuja y se elige.
## Construida en código, dentro del panel de la pantalla I (que pausa el juego).

const ROW_CONFIRM: StringName = &"confirm"
const ROW_UNDO: StringName = &"undo"
const LEFT: float = 8.0
const RIGHT: float = 160.0
const TOP: float = 18.0
const ROW_H: float = 11.0
const COLOR_ON := Color("ffffff")
const COLOR_OFF := Color("5a6988")
const COLOR_CURSOR := Color("fee761")
const COLOR_UP := Color("63c74d")

## Borrador del reparto: { stat: compras }.
var draft: Dictionary = {}
var cursor: int = 0
var message: String = ""
var _points: Label
var _rows: Array[Label] = []
var _preview: Label
var _auto: Label
var _message: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_points = _label(Vector2(LEFT, TOP), Vector2(146, 12))
	_points.theme_type_variation = &"TitleLabel"
	for i: int in rows().size():
		_rows.append(_label(Vector2(LEFT, TOP + 16 + ROW_H * i), Vector2(150, 12)))
	_preview = _label(Vector2(RIGHT, TOP), Vector2(140, 60))
	_auto = _label(Vector2(RIGHT, TOP + 62), Vector2(140, 40))
	_auto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_auto.add_theme_color_override(&"font_color", COLOR_OFF)
	_message = _label(Vector2(LEFT, TOP + 16 + ROW_H * 6 + 4), Vector2(290, 24))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.theme_type_variation = &"TitleLabel"


func _label(pos: Vector2, size_px: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size_px
	add_child(l)
	return l


# --- Lógica de presentación (pura: la usan la página y los tests) ---------------------------------

## Filas del menú: los stats en su orden y luego Confirmar y Deshacer.
static func rows() -> Array[StringName]:
	var out: Array[StringName] = AdocGrowth.stat_order()
	out.append(ROW_CONFIRM)
	out.append(ROW_UNDO)
	return out


## Puntos que quedan con el borrador.
static func points_left(d: Dictionary) -> int:
	return GameState.stat_points - AdocGrowth.draft_cost(d)


## Texto de una fila: "ATQ +1 (3 puntos)", con " ×2" si el borrador ya lleva compras de ese stat.
static func row_text(row: StringName, d: Dictionary) -> String:
	if row == ROW_CONFIRM:
		return Texts.get_text("growth_option_confirm")
	if row == ROW_UNDO:
		return Texts.get_text("growth_option_undo")
	var text: String = Texts.get_text("growth_option_%s" % row) % [AdocGrowth.gain(row), AdocGrowth.cost(row)]
	var n: int = int(d.get(row, 0))
	if n > 0:
		text += " x%d" % n
	return text


## La fila se puede elegir: un stat si quedan puntos para él; Confirmar y Deshacer si hay borrador.
static func row_enabled(row: StringName, d: Dictionary) -> bool:
	if row == ROW_CONFIRM or row == ROW_UNDO:
		return not d.is_empty()
	return points_left(d) >= AdocGrowth.cost(row)


## Líneas de la vista previa: "PV máx. 36 -> 40" (o solo "PV máx. 36" si no cambia).
static func preview_lines(d: Dictionary) -> Array[String]:
	var spent: Dictionary = AdocGrowth.spent_with(d)
	var now: Dictionary = AdocGrowth.player_stats()
	var then: Dictionary = AdocGrowth.player_stats(GameState.level, spent)
	var luz_base: int = int(AdventureRules.balance().adoc.luz_max)
	var lines: Array[String] = []
	lines.append(_change("growth_preview_hp", int(now.max_hp), int(then.max_hp)))
	lines.append(_change("growth_preview_atk", int(now.atk), int(then.atk)))
	lines.append(_change("growth_preview_def", int(now.def), int(then.def)))
	lines.append(_change("growth_preview_luz", luz_base + int(AdocGrowth.bonuses().luz_max),
		luz_base + int(AdocGrowth.bonuses(spent).luz_max)))
	return lines


static func _change(key: String, before: int, after: int) -> String:
	var text: String = Texts.get_text(key) % before
	if after != before:
		text = Texts.get_text("growth_preview_change") % [text, after]
	return text


## Aceptar sobre la fila `row`: añade la compra al borrador, aplica el reparto o lo vacía. Devuelve
## el aviso que se muestra ("" si nada).
static func activate(row: StringName, d: Dictionary) -> String:
	if row == ROW_UNDO:
		d.clear()
		return ""
	if row == ROW_CONFIRM:
		if d.is_empty() or not AdocGrowth.apply_draft(d):
			return ""
		d.clear()
		return Texts.get_text("growth_confirmed")
	if points_left(d) < AdocGrowth.cost(row):
		return Texts.get_text("growth_cant_afford")
	d[row] = int(d.get(row, 0)) + 1
	return ""


# --- Página ---------------------------------------------------------------------------------------

## Al abrir la pestaña: borrador vacío y cursor arriba.
func reset() -> void:
	draft = {}
	cursor = 0
	message = ""
	refresh()


## Arriba/abajo mueve el cursor; aceptar elige. Devuelve si usó el evento.
func handle(event: InputEvent, accept: bool) -> bool:
	var list: Array[StringName] = rows()
	if accept:
		message = activate(list[cursor], draft)
		Sfx.play(&"menu_accept")
		refresh()
		return true
	var step: int = 0
	if event.is_action_pressed(&"ui_up", true) or event.is_action_pressed(&"move_up", true):
		step = -1
	elif event.is_action_pressed(&"ui_down", true) or event.is_action_pressed(&"move_down", true):
		step = 1
	if step == 0:
		return false
	cursor = posmod(cursor + step, list.size())
	message = ""
	Sfx.play(&"menu_move")
	refresh()
	return true


func refresh() -> void:
	if _points == null:
		return
	var left: int = points_left(draft)
	_points.text = Texts.get_text("growth_points") % left
	var list: Array[StringName] = rows()
	for i: int in list.size():
		var row: StringName = list[i]
		_rows[i].text = ("> " if i == cursor else "  ") + row_text(row, draft)
		var color: Color = COLOR_OFF if not row_enabled(row, draft) else (COLOR_CURSOR if i == cursor else COLOR_ON)
		_rows[i].add_theme_color_override(&"font_color", color)
	_preview.text = "\n".join(preview_lines(draft))
	_preview.add_theme_color_override(&"font_color", COLOR_UP if not draft.is_empty() else COLOR_ON)
	_auto.text = Texts.get_text("growth_auto")
	if message != "":
		_message.text = message
	elif GameState.stat_points <= 0:
		_message.text = Texts.get_text("growth_no_points")
	else:
		_message.text = ""
