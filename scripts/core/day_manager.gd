class_name DayManager
extends Node
## Contador de días de la partida. En Aventura el día sube en el riutash del amanecer (Riumna →
## Gietos), que marca WorldClock con momento_changed (ADR 0012). end_day y advance_days quedan
## para la gestión de villa por días (ADR 0002, fuera del MVP) y las expediciones que consumen días.
## No lleva tiempo propio: el tiempo real con pausa es de WorldClock.


func _ready() -> void:
	EventBus.momento_changed.connect(_on_momento_changed)


func end_day() -> void:
	advance_days(1)


## Cada día que pasa emite day_ended(día que termina) y day_started(día que empieza).
func advance_days(count: int) -> void:
	for _i in count:
		var ended: int = GameState.day
		GameState.day += 1
		EventBus.day_ended.emit(ended)
		EventBus.day_started.emit(GameState.day)


func _on_momento_changed(momento: StringName) -> void:
	if momento == TimeConfig.GIETOS:
		advance_days(1)
