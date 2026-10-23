extends CanvasLayer
## HUD de depuración del vertical slice: seed, chunk y día. Solo escucha EventBus.

@onready var _label: Label = $Label


func _ready() -> void:
	EventBus.chunk_entered.connect(func(_c: Vector2i) -> void: _refresh())
	EventBus.day_ended.connect(func(_d: int) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	_label.text = "Seed %d  Zona (%d, %d)  Día %d\nWASD/flechas  Shift corre  R seed nueva" % [
		GameState.seed_value, GameState.chunk_coord.x, GameState.chunk_coord.y, GameState.day,
	]
