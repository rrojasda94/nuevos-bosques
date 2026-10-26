class_name TacticalPartyScreen
extends CanvasLayer
## Paso previo al combate táctico: eliges qué aliados entran, hasta el cupo (combate-tactico.md,
## "Tu party"; #188, PR T1b). Lo abre TacticalBattleScene solo si la party no cabe entera y no es una
## emboscada (TacticalParty.needs_prompt).
## - Lista: el Adoc (siempre entra, en gris), cada aliado con su casilla [x] / [ ] y el botón de
##   confirmar. E marca o desmarca un aliado (no deja pasar de las plazas: cupo − 1); el botón
##   confirma. Viene preseleccionada (TacticalParty.preselect con GameState.last_party).
## - Al confirmar emite `confirmed(chosen)` (índices de logic.allies). No guarda nada: lo hace quien
##   la abre (TacticalParty.save_choice).

signal confirmed(chosen: Array[int])

const MARK_ON: String = "[x] "
const MARK_OFF: String = "[ ] "

var allies: Array = []
var quota: int = 1
var chosen: Array[int] = []
var _done: bool = false

@onready var _title: Label = $Root/Panel/Title
@onready var _menu: OptionMenu = $Root/Panel/Options
@onready var _hint: Label = $Root/Panel/Hint


func _ready() -> void:
	_menu.skip_disabled = true


## Abre la lista: `ally_list` (logic.allies), el cupo por bando y la preselección.
func open(ally_list: Array, side_quota: int, preselected: Array[int]) -> void:
	allies = ally_list
	quota = side_quota
	chosen = preselected.duplicate()
	_done = false
	_hint.text = Texts.get_text("tactical_party_hint")
	_redraw(false)


## Opción del botón de confirmar (la última).
func confirm_index() -> int:
	return allies.size() + 1


## Elige la opción `i` de la lista (también para los tests y las capturas): marca o desmarca un
## aliado, o confirma.
func choose(i: int) -> void:
	if _done:
		return
	if i == confirm_index():
		_done = true
		confirmed.emit(chosen.duplicate())
		return
	var ally: int = i - 1
	if ally >= 0 and ally < allies.size():
		chosen = TacticalParty.toggle(chosen, ally, quota)
		_redraw(true)


func _unhandled_input(event: InputEvent) -> void:
	if _done or event is InputEventMouseMotion or not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	var choice: int = _menu.handle(event)
	if event.is_action_pressed(&"interact") and not event.is_action_pressed(&"ui_accept"):
		choice = _menu.index
	if choice >= 0:
		choose(choice)


func _redraw(keep_cursor: bool) -> void:
	_title.text = Texts.get_text("tactical_party_title") % [chosen.size() + 1, quota]
	var texts: Array[String] = [Texts.get_text("tactical_party_adoc") % Texts.get_text("tactical_adoc_name")]
	var enabled: Array[bool] = [false]
	for i: int in allies.size():
		texts.append((MARK_ON if chosen.has(i) else MARK_OFF) + str((allies[i] as Dictionary).get("name", "?")))
		enabled.append(true)
	texts.append(Texts.get_text("tactical_party_confirm"))
	enabled.append(true)
	_menu.set_options(texts, enabled, keep_cursor)
