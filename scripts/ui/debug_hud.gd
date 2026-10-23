extends CanvasLayer
## HUD de depuración del vertical slice: PV y Luz del Adoc, seed, chunk, Bosque y día, más avisos
## temporales. Solo escucha EventBus y lee GameState.

const NOTICE_TIME: float = 3.0
const NOTICE_REST: String = "Descansas en la villa"
const NOTICE_REGION_EDGE: String = "Límite de la región"
## Mismo texto que data/text/sistema.json (signpost_*); se cargará de ahí cuando haya cargador.
const NOTICE_SIGN_BOSQUE: String = "Hacia la villa de este Bosque: %s"
const NOTICE_SIGN_HOME: String = "Hacia tu villa natal: %s"

var _bosque_id: int = -1
var _bosque_size: int = 0
var _notice_serial: int = 0

@onready var _label: Label = $Label
@onready var _notice: Label = $Notice


func _ready() -> void:
	EventBus.chunk_entered.connect(_on_chunk_entered)
	EventBus.day_ended.connect(func(_d: int) -> void: _refresh())
	EventBus.bosque_border_reached.connect(_on_bosque_border_reached)
	EventBus.luz_changed.connect(func(_l: int) -> void: _refresh())
	EventBus.hp_changed.connect(func(_h: int, _m: int) -> void: _refresh())
	EventBus.rested_in_villa.connect(func() -> void: _show_notice(NOTICE_REST))
	EventBus.signpost_read.connect(_on_signpost_read)
	_notice.text = ""
	_refresh()


func _on_signpost_read(direction: String, kind: int) -> void:
	if kind == ChunkData.SignKind.HOME_VILLA:
		_show_notice(NOTICE_SIGN_HOME % direction)
	else:
		_show_notice(NOTICE_SIGN_BOSQUE % direction)


func _on_chunk_entered(_coord: Vector2i, bosque_id: int, bosque_size: int) -> void:
	_bosque_id = bosque_id
	_bosque_size = bosque_size
	_refresh()


func _refresh() -> void:
	_label.text = "PV %d/%d   Luz %d/%d\nSeed %d  Chunk (%d, %d)  Día %d\nBosque #%d (%d chunks)  Shift corre  R seed" % [
		GameState.hp, AdventureRules.max_hp(), GameState.luz, AdventureRules.luz_max(), GameState.seed_value, GameState.chunk_coord.x, GameState.chunk_coord.y, GameState.day,
		_bosque_id, _bosque_size,
	]


func _on_bosque_border_reached(bosque_id: int) -> void:
	# Los Bosques con Nujio abren el menú del borde (Crossing); aquí solo el límite de la región.
	if bosque_id < 0:
		_show_notice(NOTICE_REGION_EDGE)


func _show_notice(text: String) -> void:
	_notice.text = text
	_notice_serial += 1
	var serial: int = _notice_serial
	await get_tree().create_timer(NOTICE_TIME).timeout
	if serial == _notice_serial:
		_notice.text = ""
