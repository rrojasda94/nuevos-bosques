class_name TimeConfig
extends RefCounted
## Lectura de data/world/time.json (ADR 0012): duración de cada Momento, avisos del riutash,
## Momento inicial y efectos del riutash. Solo datos; la lógica está en WorldClock y AdventureRules.

const PATH: String = "res://data/world/time.json"
const GIETOS: StringName = &"gietos"
const RIUMNA: StringName = &"riumna"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		assert(parsed is Dictionary, "No se pudo leer %s" % PATH)
		_data = parsed
	return _data


static func is_momento(value: StringName) -> bool:
	return value == GIETOS or value == RIUMNA


## El Momento que sigue al dado (tras el riutash).
static func next_momento(momento: StringName) -> StringName:
	return GIETOS if momento == RIUMNA else RIUMNA


## Duración en segundos del Momento dado (nunca menos de 1 s).
static func duration(momento: StringName) -> float:
	var key: String = "riumna_seconds" if momento == RIUMNA else "gietos_seconds"
	return maxf(1.0, float(data()[key]))


## Segundos antes del riutash en los que se avisa, de mayor a menor.
static func warnings() -> Array[int]:
	var result: Array[int] = []
	for w: Variant in data().get("warning_seconds", []):
		result.append(int(w))
	result.sort()
	result.reverse()
	return result


static func start_momento() -> StringName:
	var m := StringName(str(data().get("start_momento", "gietos")))
	return m if is_momento(m) else GIETOS


static func start_elapsed() -> float:
	return maxf(0.0, float(data().get("start_elapsed", 0)))


## Parámetros del post-proceso de luz de luna: { uniform: valor } listos para el shader
## (tint ya convertido a Color). No incluye fade_seconds.
static func moonlight_uniforms() -> Dictionary:
	var result: Dictionary = {}
	var m: Dictionary = data().get("moonlight", {})
	for key: String in m:
		if key.begins_with("$") or key == "fade_seconds":
			continue
		result[key] = Color.html(str(m[key])) if key == "tint" else float(m[key])
	return result


static func moonlight_fade_seconds() -> float:
	return float(data().get("moonlight", {}).get("fade_seconds", 3.0))


static func riutash_damage_pct() -> int:
	return int(data().riutash.exposed_damage_pct_of_max_hp)


static func riutash_heal_pct() -> int:
	return int(data().riutash.sheltered_heal_pct_of_missing_hp)
