class_name DialogueQueue
extends RefCounted
## Lógica pura de una caja de diálogo con máquina de escribir: cola de líneas, letras visibles,
## completar la línea al pulsar durante la escritura y pasar a la siguiente al pulsar después.
## No dibuja nada: la usa DialogueBox y los tests.
## Cada línea es un Dictionary con al menos { "speaker", "text" }; las claves extra (por ejemplo
## las barras del combate) se conservan tal cual.

## Resultado de press().
enum Press { IGNORED, COMPLETED, NEXT, FINISHED }

## Línea que se está mostrando ({} si no hay ninguna).
var current: Dictionary = {}
var is_typing: bool = false
## Hay una línea en pantalla (escribiéndose o esperando a que se pulse).
var is_active: bool = false
## Letras visibles de la línea actual; -1 = todas.
var visible_chars: int = -1

var _lines: Array[Dictionary] = []
var _chars: float = 0.0


## Convierte un texto suelto o un Dictionary en una línea { speaker, text, ... }.
static func normalize(line: Variant) -> Dictionary:
	if line is Dictionary:
		var d: Dictionary = (line as Dictionary).duplicate()
		d.speaker = str(d.get("speaker", ""))
		d.text = str(d.get("text", ""))
		return d
	return { "speaker": "", "text": str(line) }


## Sustituye la cola y muestra la primera línea. false si no había ninguna.
func start(lines: Array) -> bool:
	_lines.clear()
	for line: Variant in lines:
		_lines.append(normalize(line))
	return advance()


func pending() -> int:
	return _lines.size()


## Pasa a la siguiente línea. false (y queda inactiva) si la cola se ha vaciado.
func advance() -> bool:
	if _lines.is_empty():
		current = {}
		is_active = false
		is_typing = false
		visible_chars = -1
		return false
	current = _lines.pop_front()
	is_active = true
	is_typing = true
	_chars = 0.0
	visible_chars = 0
	return true


## Avanza la escritura `delta` segundos a `speed` letras por segundo. `total`: letras de la línea.
## true si la línea acaba de completarse en esta llamada.
func tick(delta: float, speed: float, total: int) -> bool:
	if not is_typing:
		return false
	_chars += delta * speed
	visible_chars = int(_chars)
	if visible_chars >= total:
		complete()
		return true
	return false


## Muestra la línea entera de golpe.
func complete() -> void:
	is_typing = false
	visible_chars = -1


## Pulsar aceptar: completa la línea si se está escribiendo; si no, pasa a la siguiente.
func press() -> Press:
	if not is_active:
		return Press.IGNORED
	if is_typing:
		complete()
		return Press.COMPLETED
	return Press.NEXT if advance() else Press.FINISHED
