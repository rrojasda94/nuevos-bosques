extends CanvasLayer
## Brújula del HUD (navegacion.md): flecha de 8 direcciones y etiqueta corta hacia el objetivo
## de GameState (objective_chunk) o, si no hay, hacia la villa natal. "Aquí" en el objetivo.
## Solo lee GameState; la dirección la calcula MapLogic.compass. Se pausa con el árbol.
## Con una misión lejana activa (FarQuests), una segunda fila plateada debajo apunta al siguiente
## Bosque de su ruta de salvoconducto (y, dentro del Bosque que llama, a su objetivo).
## Mundo 2.0 (ADR 0014 §7, M16): con RegionPlan (MapLogic.region_plan), apunta en píxeles a un
## `world_pos` exacto (MapLogic.compass_world); sin plan, por chunks como siempre.

const ARROW_COLOR := Color("feae34")
const ARROW_SHINE := Color("fee761")
const FAR_COLOR := Color("c0cbdc")
const FAR_SHINE := Color("ffffff")
const FAR_ROW: float = 11.0

var _index: int = 999
var _text: String = ""
var _far_index: int = 999
var _far_text: String = ""
var _far_label: Label
var _far_arrow: Control

@onready var _label: Label = $Root/Label
@onready var _arrow: Control = $Root/Arrow


func _ready() -> void:
	_arrow.draw.connect(_on_arrow_draw)
	_label.text = ""
	_far_label = _label.duplicate() as Label
	_far_label.position.y += FAR_ROW
	_far_label.add_theme_color_override(&"font_color", FAR_COLOR)
	_far_label.text = ""
	$Root.add_child(_far_label)
	_far_arrow = _arrow.duplicate() as Control
	_far_arrow.position.y += FAR_ROW
	$Root.add_child(_far_arrow)
	_far_arrow.draw.connect(_on_far_arrow_draw)


func _process(_delta: float) -> void:
	if GameState.chunk_coord.x < 0:
		return
	_update_far()
	var result: Dictionary
	var plan: RegionPlan = MapLogic.region_plan()
	if plan != null:
		result = MapLogic.compass_world(plan, _player_world_pos(), GameState.objective_chunk,
				GameState.objective_cell, GameState.objective_label)
	else:
		# ponytail: borrar en M17 (brújula por chunks del mundo viejo).
		result = MapLogic.compass(MapLogic.current_bosques(), GameState.chunk_coord, GameState.player_cell,
				GameState.objective_chunk, GameState.objective_cell, GameState.objective_label)
	if result.index == _index and result.label == _text:
		return
	_index = result.index
	_text = result.label
	_label.text = _text
	_arrow.queue_redraw()


## Fila de la misión lejana: la primera activa (FarQuests.compass_chunk).
func _update_far() -> void:
	var quests: Array[Dictionary] = FarQuests.active_quests()
	var index: int = 999
	var text: String = ""
	if not quests.is_empty():
		var map: BosqueMap = MapLogic.current_bosques()
		var target: Vector2i = FarQuests.compass_chunk(map, quests[0], GameState.chunk_coord)
		var result: Dictionary
		var plan: RegionPlan = MapLogic.region_plan()
		if plan != null:
			result = MapLogic.compass_world(plan, _player_world_pos(), target, Vector2i(-1, -1),
					Texts.get_text("compass_far_quest"))
		else:
			# ponytail: borrar en M17.
			result = MapLogic.compass(map, GameState.chunk_coord, GameState.player_cell, target,
					Vector2i(-1, -1), Texts.get_text("compass_far_quest"))
		index = result.index
		text = result.label
	if index == _far_index and text == _far_text:
		return
	_far_index = index
	_far_text = text
	_far_label.text = text
	_far_arrow.queue_redraw()


## Pies del jugador en píxeles del mundo: su `world_pos` (MapLogic.player_pos, que fija la
## exploración del Mundo 2.0) o, sin ella, chunk + casilla del guardado.
func _player_world_pos() -> Vector2:
	return MapLogic.player_pos()


func _on_far_arrow_draw() -> void:
	if _far_index == 999:
		return
	PixelIcons.draw(_far_arrow, PixelIcons.arrow(_far_index), Vector2.ZERO, FAR_COLOR, FAR_SHINE)


func _on_arrow_draw() -> void:
	if _index == 999:
		return
	PixelIcons.draw(_arrow, PixelIcons.arrow(_index), Vector2.ZERO, ARROW_COLOR, ARROW_SHINE)
