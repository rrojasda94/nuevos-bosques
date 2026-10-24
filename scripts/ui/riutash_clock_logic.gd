class_name RiutashClockLogic
extends RefCounted
## Lógica pura del reloj del riutash (tiempo-y-riutash.md): en qué posición está la esfera según
## el Momento y el tiempo que falta, a qué ritmo late el reloj al acercarse el riutash y cuándo
## suena el swish. No dibuja ni toca nodos: lo usan RiutashClock (escena) y RiutashDial (imagen).
##
## La esfera es una vuelta completa: la mitad de Gietos ocupa [0, 0.5) y la de Riumna [0.5, 1).
## Cada mitad dura lo que su Momento, así que el borde entre las dos (el riutash) pasa bajo la
## marca de "ahora" justo cuando llega el riutash, aunque el día y la noche duren distinto.

## Intervalo entre pulsos al empezar el primer aviso (60 s) y justo antes del último (15 s).
const PULSE_SLOW: float = 2.0
const PULSE_MID: float = 1.0
## Intervalo entre pulsos desde el último aviso hasta el riutash.
const PULSE_FAST: float = 0.5
## Segundos (antes del riutash) en los que también suena el swish, además de en cada aviso.
## Solo cuentan los que quedan por debajo del último aviso.
const SWISH_EXTRA: Array[int] = [10, 5]


## Posición de la esfera en [0, 1): 0 = amanecer (riutash), 0.25 = mediodía, 0.5 = atardecer
## (riutash), 0.75 = medianoche.
static func phase(momento: StringName, seconds_left: float, gietos_seconds: float, riumna_seconds: float) -> float:
	var is_riumna: bool = momento == TimeConfig.RIUMNA
	var duration: float = maxf(1.0, riumna_seconds if is_riumna else gietos_seconds)
	var progress: float = clampf(1.0 - seconds_left / duration, 0.0, 1.0)
	var result: float = (0.5 if is_riumna else 0.0) + 0.5 * progress
	return fposmod(result, 1.0)


## Paso (fotograma) de la esfera para `steps` pasos por vuelta. Redondea hacia abajo, de modo que
## el borde llega a la marca exactamente en el riutash y nunca antes.
static func step(value: float, steps: int) -> int:
	return posmod(floori(fposmod(value, 1.0) * steps), steps)


## Segundos entre pulsos del reloj, o 0 si no late. Late desde el primer aviso (`first`) y se
## acelera: de PULSE_SLOW a PULSE_MID hasta el último aviso (`last`) y PULSE_FAST desde él.
static func pulse_interval(seconds_left: float, first: float, last: float) -> float:
	if seconds_left <= 0.0 or seconds_left > first:
		return 0.0
	if seconds_left <= last:
		return PULSE_FAST
	var t: float = (first - seconds_left) / maxf(0.001, first - last)
	return lerpf(PULSE_SLOW, PULSE_MID, t)


## Píxeles que crece el radio del disco a los `t` segundos de un pulso de `length` segundos:
## sube de 0 a `max_grow` y vuelve a 0 (forma de triángulo). Fuera del pulso, 0.
static func pulse_grow(t: float, length: float, max_grow: int) -> int:
	if t < 0.0 or t >= length or length <= 0.0:
		return 0
	var x: float = 1.0 - absf(2.0 * t / length - 1.0)
	return clampi(roundi(x * max_grow), 0, max_grow)


## Segundos antes del riutash en los que suena el swish, de mayor a menor: todos los avisos y los
## de SWISH_EXTRA por debajo del último aviso.
static func swish_marks(warnings: Array[int]) -> Array[int]:
	var result: Array[int] = warnings.duplicate()
	var last: int = warnings.min() if not warnings.is_empty() else 0
	for extra: int in SWISH_EXTRA:
		if extra < last or warnings.is_empty():
			result.append(extra)
	result.sort()
	result.reverse()
	return result


## true si al pasar de `previous_left` a `seconds_left` segundos se ha cruzado alguna marca.
## Solo cuenta hacia abajo: el salto del riutash al Momento siguiente no cruza nada.
static func crossed_mark(previous_left: float, seconds_left: float, marks: Array[int]) -> bool:
	if seconds_left >= previous_left:
		return false
	for mark: int in marks:
		if previous_left > mark and seconds_left <= mark:
			return true
	return false
