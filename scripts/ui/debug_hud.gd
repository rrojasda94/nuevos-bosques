extends CanvasLayer
## HUD de depuración del vertical slice: seed, chunk, Bosque y día, más avisos temporales.
## Solo escucha EventBus.

const NOTICE_TIME: float = 3.0
const NOTICE_OTHER_BOSQUE: String = "Este Bosque tiene Nujio: necesitas Luz\no enfrentarte a sus Únicos (próximamente)"
const NOTICE_REGION_EDGE: String = "Límite de la región"

var _bosque_id: int = -1
var _bosque_size: int = 0
var _notice_serial: int = 0

@onready var _label: Label = $Label
@onready var _notice: Label = $Notice


func _ready() -> void:
	EventBus.chunk_entered.connect(_on_chunk_entered)
	EventBus.day_ended.connect(func(_d: int) -> void: _refresh())
	EventBus.bosque_border_reached.connect(_on_bosque_border_reached)
	EventBus.signpost_read.connect(func(direction: String) -> void: _show_notice("Letrero de piedra: hacia la villa, al %s" % direction))
	_notice.text = ""
	_refresh()


func _on_chunk_entered(_coord: Vector2i, bosque_id: int, bosque_size: int) -> void:
	_bosque_id = bosque_id
	_bosque_size = bosque_size
	_refresh()


func _refresh() -> void:
	_label.text = "Seed %d  Chunk (%d, %d)  Día %d\nBosque #%d (%d chunks)  Shift corre  R seed" % [
		GameState.seed_value, GameState.chunk_coord.x, GameState.chunk_coord.y, GameState.day,
		_bosque_id, _bosque_size,
	]


func _on_bosque_border_reached(bosque_id: int) -> void:
	_show_notice(NOTICE_REGION_EDGE if bosque_id < 0 else NOTICE_OTHER_BOSQUE)


func _show_notice(text: String) -> void:
	_notice.text = text
	_notice_serial += 1
	var serial: int = _notice_serial
	await get_tree().create_timer(NOTICE_TIME).timeout
	if serial == _notice_serial:
		_notice.text = ""
