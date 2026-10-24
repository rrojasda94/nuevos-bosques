extends Node
## WorldClock: reloj del modo Aventura (ADR 0012, ficha tiempo-y-riutash.md). Tiempo real que se
## detiene con la pausa del árbol (process_mode heredado = pausable): menú del borde, combate,
## diálogos y mapa congelan el reloj.
## Alterna el Momento de Gietos (día) y el de Riumna (noche); entre uno y otro pasa el riutash.
## El estado vive en GameState (clock_momento, clock_elapsed) para que se guarde con la partida;
## aquí solo está la lógica de avance y las señales. No aplica efectos: la exploración decide si
## el jugador está refugiado (shelter_check) y aplica el riutash; DayManager sube el día.

## Devuelve true si el jugador está en un refugio en el instante del riutash. La asigna la escena
## que conoce la posición del jugador (exploración). Sin asignar = expuesto.
var shelter_check: Callable = Callable()


func _process(delta: float) -> void:
	advance(delta)


func momento() -> StringName:
	return GameState.clock_momento


func is_night() -> bool:
	return GameState.clock_momento == TimeConfig.RIUMNA


## Segundos que faltan para el próximo riutash.
func time_to_riutash() -> float:
	return maxf(0.0, TimeConfig.duration(GameState.clock_momento) - GameState.clock_elapsed)


## Avanza el reloj `seconds` segundos. Emite, en orden, los avisos que se crucen, el riutash y el
## cambio de Momento (varias veces si el salto es largo). Los tests lo llaman directamente.
func advance(seconds: float) -> void:
	var remaining: float = maxf(0.0, seconds)
	while true:
		var left: float = time_to_riutash()
		var step: float = minf(remaining, left)
		for w: int in TimeConfig.warnings():
			if left > w and left - step <= w:
				EventBus.riutash_warning.emit(w)
		GameState.clock_elapsed += step
		remaining -= step
		if GameState.clock_elapsed >= TimeConfig.duration(GameState.clock_momento):
			_pass_riutash()
		elif remaining <= 0.0:
			break


func _pass_riutash() -> void:
	var sheltered: bool = shelter_check.is_valid() and bool(shelter_check.call())
	EventBus.riutash_passed.emit(sheltered)
	GameState.clock_momento = TimeConfig.next_momento(GameState.clock_momento)
	GameState.clock_elapsed = 0.0
	EventBus.momento_changed.emit(GameState.clock_momento)
