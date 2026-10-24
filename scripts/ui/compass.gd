extends CanvasLayer
## Brújula del HUD (navegacion.md): flecha de 8 direcciones y etiqueta corta hacia el objetivo
## de GameState (objective_chunk) o, si no hay, hacia la villa natal. "Aquí" en el objetivo.
## Solo lee GameState; la dirección la calcula MapLogic.compass. Se pausa con el árbol.

const ARROW_COLOR := Color("feae34")
const ARROW_SHINE := Color("fee761")

var _index: int = 999
var _text: String = ""

@onready var _label: Label = $Root/Label
@onready var _arrow: Control = $Root/Arrow


func _ready() -> void:
	_arrow.draw.connect(_on_arrow_draw)
	_label.text = ""


func _process(_delta: float) -> void:
	if GameState.chunk_coord.x < 0:
		return
	var result: Dictionary = MapLogic.compass(MapLogic.current_bosques(), GameState.chunk_coord, GameState.player_cell,
			GameState.objective_chunk, GameState.objective_cell, GameState.objective_label)
	if result.index == _index and result.label == _text:
		return
	_index = result.index
	_text = result.label
	_label.text = _text
	_arrow.queue_redraw()


func _on_arrow_draw() -> void:
	if _index == 999:
		return
	PixelIcons.draw(_arrow, PixelIcons.arrow(_index), Vector2.ZERO, ARROW_COLOR, ARROW_SHINE)
