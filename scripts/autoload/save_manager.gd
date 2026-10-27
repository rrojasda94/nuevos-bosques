extends Node
## SaveManager: único punto de lectura/escritura de partidas en user://saves/.
## Mundo 2.0 (ADR 0014 §7 "Guardado"): las partidas de antes del Mundo 2.0 (save_version < 20 u
## otro generator_version) no se cargan: load_game devuelve ERR_SAVE_OLD_WORLD y quien llama
## muestra el aviso "save_old_world" de data/text/sistema.json. Al guardar se borran las cachés
## del mundo (WorldCache) que no usa ningún slot.

const SAVE_DIR := "user://saves"
## Error propio (fuera del rango de @GlobalScope.Error): la partida es de un mundo anterior.
const ERR_SAVE_OLD_WORLD: int = 1000
## Slots que se miran al limpiar la caché del mundo.
const MAX_SLOTS: int = 10


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
	clean_world_cache()
	EventBus.game_saved.emit(slot)
	return OK


## Mira el slot sin cargarlo: OK si se puede continuar; si no, ERR_FILE_NOT_FOUND,
## ERR_PARSE_ERROR, ERR_INVALID_DATA (versión futura o inválida) o ERR_SAVE_OLD_WORLD.
func check_slot(slot: int) -> int:
	var data: Variant = _read_slot(slot)
	if data is int:
		return data
	return _check_version(data)


## Carga el slot en GameState. Devuelve OK o el error de check_slot (un int: ERR_SAVE_OLD_WORLD no
## es un Error del motor).
func load_game(slot: int) -> int:
	var data: Variant = _read_slot(slot)
	if data is int:
		return data
	var check: int = _check_version(data)
	if check != OK:
		return check
	# Migraciones: de v1 a v19 se añadieron campos; GameState.from_dict les da su valor por
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
	# con relación <= -50 quedan marcados en angry_candidate; v13: el último Bosque pagado
	# (last_paid_bosque) es el de open_until con la caducidad más tardía, o ninguno; v14: ningún
	# cambio de estado de Bosque ni incendio apagado, salvo que los candidatos a enojarse con la
	# relación aún <= -50 pasan a enojados; v15: nada colado ni usos gastados; v16: ningún encuentro
	# con otros adoc; v17: ninguna misión lejana ni visión de Pensamiento; v18: Senda 0 y bando fiel, el mismo
	# nivel con los stats automáticos nuevos, nada gastado y todos los puntos de stat y de skill de
	# su nivel por repartir (AdocGrowth.migrate_points); v19: ninguna party elegida (migrate).
	# v20 (Mundo 2.0): las anteriores ya no llegan aquí (ERR_SAVE_OLD_WORLD). v21: el arma
	# equipada queda en la mano (migrate).
	GameState.from_dict(migrate(data))
	EventBus.game_loaded.emit(slot)
	return OK


## Pasa los datos de una partida guardada al formato actual donde from_dict no basta con su valor
## por defecto. v19 (combate táctico, T1b): sin last_party, la party elegida empieza vacía. v21 (arma
## enfundada, ajustes-playtest-0.5.md, 4a): sin weapon_drawn, un arma equipada queda en la mano,
## como el "armado" de la v20 (cierra Bosques y anula el camuflaje).
static func migrate(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	if int(out.get("save_version", 0)) < 19 and not out.has("last_party"):
		out["last_party"] = []
	if int(out.get("save_version", 0)) < 21 and not out.has("weapon_drawn"):
		var eq: Variant = out.get("equipped", {})
		out["weapon_drawn"] = eq is Dictionary and str(eq.get("main_hand", "")) != ""
	return out


## Borra las cachés del mundo que no usa ni la partida actual ni ningún slot (ADR 0014 §6,
## "Limpieza"). Sin mundo en GameState (tests, partida sin exploración) no borra nada, para no
## tirar la caché de una partida en curso. Devuelve cuántas carpetas borró.
func clean_world_cache(cache_root: String = WorldCache.ROOT) -> int:
	if GameState.world_key.is_empty():
		return 0
	var keep: Array[int] = [key_from_hex(GameState.world_key)]
	for slot: int in MAX_SLOTS:
		var data: Variant = _read_slot(slot)
		if data is Dictionary and not str(data.get("world_key", "")).is_empty():
			keep.append(key_from_hex(str(data.world_key)))
	return WorldCache.clean_unused(keep, cache_root)


## Clave del mundo desde su nombre hexadecimal (WorldCache.key_to_name).
static func key_from_hex(hex: String) -> int:
	return ("0x" + hex).hex_to_int()


func _read_slot(slot: int) -> Variant:
	if not FileAccess.file_exists(slot_path(slot)):
		return ERR_FILE_NOT_FOUND
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(slot_path(slot)))
	if typeof(data) != TYPE_DICTIONARY:
		return ERR_PARSE_ERROR
	return data


func _check_version(data: Dictionary) -> int:
	var version: int = int(data.get("save_version", 0))
	if version < 1 or version > GameState.SAVE_VERSION:
		return ERR_INVALID_DATA
	if GameState.is_old_world(data):
		return ERR_SAVE_OLD_WORLD
	return OK
