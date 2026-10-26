class_name SkillsPage
extends Control
## Pestaña "Senda" de la pantalla I (moralidad-y-progresion.md, "Skills por Senda"): los iconos de la
## Senda y del bando (sin número), los puntos de skill y el árbol de dos ramas, Sombra a la izquierda
## y Confianza a la derecha, cada una en cadena de arriba abajo. Cada skill se ve aprendida (verde),
## disponible (blanca, con "!") o bloqueada (gris); debajo, la marcada: su estado, su umbral de Senda
## y su descripción. Aceptar la aprende (AdocGrowth.learn). Las reglas están en AdocGrowth y Senda;
## aquí solo se dibuja y se elige. Construida en código, dentro del panel de la pantalla I.

const LEFT: float = 8.0
const COLUMN: float = 150.0
const TOP: float = 18.0
const ROW_H: float = 11.0
const COLOR_LEARNED := Color("63c74d")
const COLOR_AVAILABLE := Color("ffffff")
const COLOR_LOCKED := Color("5a6988")
const COLOR_CURSOR := Color("fee761")

## Rama (0 = Sombra, 1 = Confianza) y posición en ella de la skill marcada.
var column: int = 0
var row: int = 0
var message: String = ""
var _icons: SendaHud
var _status: Label
var _headers: Array[Label] = []
var _cells: Array = [[], []]
var _name: Label
var _detail: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons = SendaHud.new()
	_icons.show_points = false
	_icons.backing = true
	_icons.position = Vector2(LEFT, TOP + 1)
	_icons.size = Vector2(24, 9)
	add_child(_icons)
	_status = _label(Vector2(LEFT + 26, TOP - 1), Vector2(266, 12))
	for b: int in AdocGrowth.BRANCHES.size():
		var header: Label = _label(Vector2(LEFT + COLUMN * b, TOP + 13), Vector2(140, 12))
		header.theme_type_variation = &"TitleLabel"
		_headers.append(header)
		for i: int in AdocGrowth.branch(AdocGrowth.BRANCHES[b]).size():
			_cells[b].append(_label(Vector2(LEFT + COLUMN * b, TOP + 25 + ROW_H * i), Vector2(140, 12)))
	_name = _label(Vector2(LEFT, TOP + 25 + ROW_H * 4 + 3), Vector2(290, 12))
	_name.theme_type_variation = &"TitleLabel"
	_detail = _label(Vector2(LEFT, TOP + 25 + ROW_H * 4 + 15), Vector2(290, 46))
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _label(pos: Vector2, size_px: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size_px
	add_child(l)
	return l


# --- Lógica de presentación (pura: la usan la página y los tests) ---------------------------------

## Línea de estado: "Senda respetuosa   Bando: Fiel   Puntos de skill: 1".
static func status_line() -> String:
	return "   ".join(PackedStringArray([
		Texts.get_text("skills_senda") % Senda.icon_name(Senda.icon()),
		Texts.get_text("skills_bando") % Senda.bando_name(GameState.bando),
		Texts.get_text("skills_points") % GameState.skill_points,
	]))


## Texto de una skill en el árbol: "[x] Paso quedo" (aprendida), "[!] Paso quedo" (disponible) o
## "[ ] Paso quedo" (bloqueada).
static func cell_text(skill: StringName) -> String:
	var mark: String = "[ ]"
	match AdocGrowth.skill_state(skill):
		AdocGrowth.SkillState.LEARNED:
			mark = "[x]"
		AdocGrowth.SkillState.AVAILABLE:
			mark = "[!]"
	return "%s %s" % [mark, AdocGrowth.skill_name(skill)]


static func cell_color(skill: StringName) -> Color:
	match AdocGrowth.skill_state(skill):
		AdocGrowth.SkillState.LEARNED:
			return COLOR_LEARNED
		AdocGrowth.SkillState.AVAILABLE:
			return COLOR_AVAILABLE
	return COLOR_LOCKED


## Umbral de Senda de la skill: "Requiere Senda <= -10" o "Requiere Senda >= +10".
static func threshold_line(skill: StringName) -> String:
	var t: int = AdocGrowth.threshold(skill)
	var key: String = "skills_threshold_max" if AdocGrowth.branch_of(skill) == AdocGrowth.SOMBRA else "skills_threshold_min"
	return Texts.get_text(key) % t


## Estado legible de la skill ("Aprendida.", "Tu Senda aún no llega."...).
static func state_line(skill: StringName) -> String:
	var keys: Array[String] = ["skills_state_learned", "skills_state_available", "skills_state_needs_point",
		"skills_state_needs_senda", "skills_state_needs_previous"]
	return Texts.get_text(keys[AdocGrowth.skill_state(skill)])


## Detalle de la skill marcada: estado y umbral en una línea y la descripción debajo.
static func detail_text(skill: StringName) -> String:
	return "%s %s\n%s" % [threshold_line(skill) + ".", state_line(skill), AdocGrowth.skill_description(skill)]


## Aceptar sobre la skill: la aprende si se puede. Devuelve el aviso.
static func activate(skill: StringName) -> String:
	if AdocGrowth.learn(skill):
		return Texts.get_text("skills_learned") % AdocGrowth.skill_name(skill)
	return state_line(skill)


# --- Página ---------------------------------------------------------------------------------------

func selected() -> StringName:
	return AdocGrowth.branch(AdocGrowth.BRANCHES[column])[row]


func reset() -> void:
	column = 0
	row = 0
	message = ""
	refresh()


## Flechas o WASD mueven por el árbol; aceptar aprende. Devuelve si usó el evento.
func handle(event: InputEvent, accept: bool) -> bool:
	if accept:
		message = activate(selected())
		Sfx.play(&"menu_accept")
		refresh()
		return true
	var d := Vector2i.ZERO
	if event.is_action_pressed(&"ui_up", true) or event.is_action_pressed(&"move_up", true):
		d = Vector2i.UP
	elif event.is_action_pressed(&"ui_down", true) or event.is_action_pressed(&"move_down", true):
		d = Vector2i.DOWN
	elif event.is_action_pressed(&"ui_left", true) or event.is_action_pressed(&"move_left", true):
		d = Vector2i.LEFT
	elif event.is_action_pressed(&"ui_right", true) or event.is_action_pressed(&"move_right", true):
		d = Vector2i.RIGHT
	if d == Vector2i.ZERO:
		return false
	column = clampi(column + d.x, 0, AdocGrowth.BRANCHES.size() - 1)
	row = clampi(row + d.y, 0, AdocGrowth.branch(AdocGrowth.BRANCHES[column]).size() - 1)
	message = ""
	Sfx.play(&"menu_move")
	refresh()
	return true


func refresh() -> void:
	if _status == null:
		return
	_status.text = status_line()
	for b: int in AdocGrowth.BRANCHES.size():
		var branch_id: StringName = AdocGrowth.BRANCHES[b]
		_headers[b].text = Texts.get_text("skills_branch_%s" % branch_id)
		var list: Array[StringName] = AdocGrowth.branch(branch_id)
		for i: int in list.size():
			var cell: Label = _cells[b][i]
			var marked: bool = b == column and i == row
			cell.text = ("> " if marked else "  ") + cell_text(list[i])
			cell.add_theme_color_override(&"font_color", COLOR_CURSOR if marked else cell_color(list[i]))
	var skill: StringName = selected()
	_name.text = AdocGrowth.skill_name(skill)
	_detail.text = message if message != "" else detail_text(skill)
	_icons.queue_redraw()
