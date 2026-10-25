class_name MovementConfig
extends RefCounted
## Lectura de data/world/movement.json (ADR 0014 §2): velocidades de andar y correr, ayuda de
## esquina y caja de colisión de los pies. Solo datos; la lógica está en GridMover.

const PATH: String = "res://data/world/movement.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		assert(parsed is Dictionary, "No se pudo leer %s" % PATH)
		_data = parsed
	return _data


static func walk_speed() -> float:
	return float(data().get("walk_speed", 100))


static func run_speed() -> float:
	return float(data().get("run_speed", 200))


static func corner_assist_px() -> float:
	return float(data().get("corner_assist_px", 5))


static func hitbox() -> Vector2:
	var box: Array = data().get("hitbox", [10, 6])
	return Vector2(float(box[0]), float(box[1]))
