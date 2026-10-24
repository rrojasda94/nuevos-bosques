class_name Texts
extends RefCounted
## Cargador mínimo de textos visibles (data/text/sistema.json, en español). No traduce: cuando
## haya localización, esta clase pasará a usar TranslationServer sin cambiar sus llamadas.

const SISTEMA_PATH: String = "res://data/text/sistema.json"

static var _sistema: Dictionary = {}


## Texto de data/text/sistema.json. Si la clave no existe, avisa en el log y devuelve la propia
## clave, para que el fallo se vea en pantalla.
static func get_text(key: String) -> String:
	if not has_text(key):
		push_warning("Texto sin definir: %s" % key)
		return key
	return str(_sistema[key])


static func has_text(key: String) -> bool:
	if _sistema.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SISTEMA_PATH))
		assert(parsed is Dictionary, "No se pudo leer %s" % SISTEMA_PATH)
		_sistema = parsed
	return _sistema.has(key)
