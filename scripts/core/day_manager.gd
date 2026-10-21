class_name DayManager
extends Node
## Único reloj de la simulación. El día avanza SOLO por acción del jugador (end_day)
## o cuando una expedición consume días. Nada de tiempo real.


func end_day() -> void:
	advance_days(1)


func advance_days(count: int) -> void:
	for _i in count:
		GameState.day += 1
		EventBus.day_ended.emit(GameState.day)
		EventBus.day_started.emit(GameState.day + 1)
