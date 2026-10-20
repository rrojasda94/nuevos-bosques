class_name TickTimer
extends Node
## Emite EventBus.tick a intervalo fijo. Único reloj de la simulación de ciudad.

@export var seconds_per_tick: float = 1.0
@export var running: bool = true

var _accum: float = 0.0


func _process(delta: float) -> void:
	if not running:
		return
	_accum += delta
	while _accum >= seconds_per_tick:
		_accum -= seconds_per_tick
		GameState.ticks += 1
		EventBus.tick.emit(GameState.ticks)
