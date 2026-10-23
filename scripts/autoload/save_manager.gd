extends Node
## SaveManager: único punto de lectura/escritura de partidas en user://saves/.

const SAVE_DIR := "user://saves"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


func save_game(slot: int) -> Error:
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(GameState.to_dict(), "\t"))
	file.close()
	EventBus.game_saved.emit(slot)
	return OK


func load_game(slot: int) -> Error:
	if not FileAccess.file_exists(slot_path(slot)):
		return ERR_FILE_NOT_FOUND
	var text := FileAccess.get_file_as_string(slot_path(slot))
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return ERR_PARSE_ERROR
	var version: int = int(data.get("save_version", 0))
	if version < 1 or version > GameState.SAVE_VERSION:
		return ERR_INVALID_DATA
	# Migraciones: de v1 a v2 solo se añadieron campos con valor por defecto en GameState.from_dict.
	GameState.from_dict(data)
	EventBus.game_loaded.emit(slot)
	return OK
