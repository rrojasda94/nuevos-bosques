extends CanvasLayer
## HUD de depuración del vertical slice: PV y Luz del Adoc, seed, chunk, Bosque y día, Momento y
## tiempo hasta el riutash (WorldClock), más avisos temporales. El último aviso del riutash parpadea
## y se queda fijo hasta que pasa. Solo escucha EventBus y lee GameState y WorldClock.

const NOTICE_TIME: float = 3.0
const NOTICE_REST: String = "Descansas en la villa"
const NOTICE_REGION_EDGE: String = "Límite de la región"
## Línea del reloj: Momento y tiempo hasta el riutash (mm:ss).
const TEXT_CLOCK: String = "%s   Riutash en %s"
## Intervalo del parpadeo del aviso fijo del riutash.
const BLINK_TIME: float = 0.4

var _bosque_id: int = -1
var _bosque_size: int = 0
var _notice_serial: int = 0
## Aviso fijo (último aviso del riutash). Vuelve a mostrarse al acabar un aviso temporal.
var _sticky: String = ""
var _riutash_text: String = ""
var _clock_seconds: int = -1
var _blink: Timer

@onready var _label: Label = $Label
@onready var _notice: Label = $Notice


func _ready() -> void:
	EventBus.chunk_entered.connect(_on_chunk_entered)
	EventBus.day_started.connect(func(_d: int) -> void: _refresh())
	EventBus.bosque_border_reached.connect(_on_bosque_border_reached)
	EventBus.luz_changed.connect(func(_l: int) -> void: _refresh())
	EventBus.hp_changed.connect(func(_h: int, _m: int) -> void: _refresh())
	EventBus.rested_in_villa.connect(func() -> void: _show_notice(NOTICE_REST))
	EventBus.riutash_warning.connect(_on_riutash_warning)
	EventBus.riutash_passed.connect(_on_riutash_passed)
	EventBus.momento_changed.connect(_on_momento_changed)
	_blink = Timer.new()
	_blink.wait_time = BLINK_TIME
	_blink.timeout.connect(_on_blink)
	add_child(_blink)
	_blink.start()
	_notice.text = ""
	_refresh()


## Solo redibuja cuando cambia el segundo mostrado. Además repone o quita el aviso fijo tras cargar
## una partida o empezar otra (los avisos ya pasados no se reemiten).
func _process(_delta: float) -> void:
	var left: float = WorldClock.time_to_riutash()
	var seconds: int = ceili(left)
	if seconds == _clock_seconds:
		return
	_clock_seconds = seconds
	var last: int = _last_warning()
	if left <= last and _sticky.is_empty():
		_set_sticky(Texts.get_text("riutash_warning_%d" % last))
	elif left > last and not _sticky.is_empty():
		_set_sticky("")
	_refresh()


func _on_chunk_entered(_coord: Vector2i, bosque_id: int, bosque_size: int) -> void:
	_bosque_id = bosque_id
	_bosque_size = bosque_size
	_refresh()


func _refresh() -> void:
	_label.text = "PV %d/%d   Luz %d/%d\nSeed %d  Chunk (%d, %d)  Día %d\nBosque #%d (%d chunks)  Shift corre  R seed\n%s" % [
		GameState.hp, AdventureRules.max_hp(), GameState.luz, AdventureRules.luz_max(), GameState.seed_value, GameState.chunk_coord.x, GameState.chunk_coord.y, GameState.day,
		_bosque_id, _bosque_size, _clock_line(),
	]


func _clock_line() -> String:
	var seconds: int = ceili(WorldClock.time_to_riutash())
	var momento: String = Texts.get_text("hud_momento_%s" % WorldClock.momento())
	return TEXT_CLOCK % [momento, "%02d:%02d" % [floori(seconds / 60.0), seconds % 60]]


## El aviso más cercano al riutash (el que parpadea), o 0 si no hay avisos.
func _last_warning() -> int:
	var warnings: Array[int] = TimeConfig.warnings()
	return warnings.back() if not warnings.is_empty() else 0


func _on_riutash_warning(seconds_left: int) -> void:
	var text: String = Texts.get_text("riutash_warning_%d" % seconds_left)
	if seconds_left == _last_warning():
		_set_sticky(text)
	else:
		_show_notice(text)


func _on_riutash_passed(sheltered: bool) -> void:
	_set_sticky("")
	_riutash_text = Texts.get_text("riutash_passed_sheltered" if sheltered else "riutash_passed_exposed")


## Diferido para que DayManager ya haya subido el día al amanecer.
func _on_momento_changed(momento: StringName) -> void:
	_announce_momento.call_deferred(momento)


func _announce_momento(momento: StringName) -> void:
	var text: String = Texts.get_text("momento_%s" % momento)
	if momento == TimeConfig.GIETOS:
		text += " " + Texts.get_text("new_day") % GameState.day
	_show_notice(_riutash_text + "\n" + text if not _riutash_text.is_empty() else text)
	_riutash_text = ""
	_refresh()


func _set_sticky(text: String) -> void:
	_sticky = text
	_notice.visible = true
	_notice_serial += 1
	_notice.text = text


func _on_blink() -> void:
	_notice.visible = not _notice.visible if not _sticky.is_empty() and _notice.text == _sticky else true


func _on_bosque_border_reached(bosque_id: int) -> void:
	# Los Bosques con Nujio abren el menú del borde (Crossing); aquí solo el límite de la región.
	if bosque_id < 0:
		_show_notice(NOTICE_REGION_EDGE)


func _show_notice(text: String) -> void:
	_notice.visible = true
	_notice.text = text
	_notice_serial += 1
	var serial: int = _notice_serial
	await get_tree().create_timer(NOTICE_TIME).timeout
	if serial == _notice_serial:
		_notice.text = _sticky
