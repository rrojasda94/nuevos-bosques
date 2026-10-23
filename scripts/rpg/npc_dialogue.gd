class_name NpcDialogue
extends RefCounted
## Punto central de lo que dice cada NPC al hablarle con E. Lee data/npcs/<id>.json (textos de
## narrative-writer) y devuelve las líneas para DialogueBox ({ "speaker", "text" }).
## PUNTO DE ENGANCHE de las misiones: lines_for() es el único sitio que decide qué se dice. El
## PR 6 (misión del Ofomni) añade aquí los textos según el estado de la misión, antes del saludo
## por defecto. Además la exploración emite EventBus.npc_talked(npc_id) al empezar cada charla.

const NPC_PATH: String = "res://data/npcs/%s.json"

static var _data: Dictionary = {}
## Charlas por NPC en la sesión: elige la frase de ambiente en rueda (sin tocar GameState.rng).
static var _talks: Dictionary = {}


static func data(npc_id: StringName) -> Dictionary:
	if not _data.has(npc_id):
		var path: String = NPC_PATH % npc_id
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(parsed is Dictionary, "No se pudo leer %s" % path)
		_data[npc_id] = parsed
	return _data[npc_id]


static func display_name(npc_id: StringName) -> String:
	return str(data(npc_id).get("name", npc_id))


## Líneas de la próxima charla con el NPC. Sin misiones: su saludo y una frase de ambiente.
static func lines_for(npc_id: StringName) -> Array[Dictionary]:
	var d: Dictionary = data(npc_id)
	var talk: int = int(_talks.get(npc_id, 0))
	_talks[npc_id] = talk + 1
	var out: Array[Dictionary] = []
	out.append_array(_block_lines(d.get("greeting", {})))
	var ambient: Array = d.get("ambient", [])
	if not ambient.is_empty():
		out.append_array(_block_lines(ambient[talk % ambient.size()]))
	return out


## Líneas de un bloque de texto de los JSON ({ "id", "lines": [{ "speaker", "text" }] }).
static func _block_lines(block: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line: Variant in block.get("lines", []):
		out.append(DialogueQueue.normalize(line))
	return out


## Solo para tests: olvida las charlas de la sesión.
static func reset_talks() -> void:
	_talks.clear()
