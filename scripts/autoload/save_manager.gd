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
	# Migraciones: de v1 a v12 se añadieron campos; GameState.from_dict les da su valor por
	# defecto (v3: Luz y PV iniciales, ningún Bosque abierto; v4: reloj al inicio del Momento de
	# Gietos; v5: solo el chunk actual explorado y sin objetivo; v6: inventario vacío (antes era
	# un diccionario), sin misiones (la exploración la vuelve a ofrecer), villa sana, 0 XP y fama
	# y ningún Botarramas visto; v7: el nivel que corresponde a la XP guardada y ningún refugio
	# saqueado; v9: ningún Bosque forzado, hostilidad y relación a 0, y el Ofomni de la misión
	# pasa a ofomni_descarriado; v10: todos los frutales con fruto y ningún fruto tomado en el
	# Momento en ningún Bosque); v11: la lista de ofrendas "inventory" pasa a la bolsa de casillas y
	# el arma inicial va equipada (GameState._load_inventory); v12: el paso pagado caduca, así que
	# la lista permanente "open_bosques" pasa a open_until (abierto hasta el segundo riutash desde
	# la carga, o permanente con relación >= 60), el contador de riutash empieza en 0 y los Bosques
	# con relación <= -50 quedan marcados en angry_candidate.
	GameState.from_dict(data)
	EventBus.game_loaded.emit(slot)
	return OK
