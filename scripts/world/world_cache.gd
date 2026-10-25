class_name WorldCache
extends RefCounted
## Caché en disco del mundo pregenerado (ADR 0014 §6, "Caché en disco"). Una carpeta por mundo:
## `user://world_cache/<world_key>/`, con `world_key = hash(seed, region_id, generator_version,
## authoring_hash)` en 16 cifras hexadecimales.
##
## Archivos (todos con FileAccess.open_compressed(..., COMPRESSION_ZSTD)):
## - `region.bin`: manifiesto del mundo. NO guarda el RegionPlan: el plan se reconstruye en cada
##   carga (M5 tarda ~65 ms, muy por debajo de leer y validar su contenido serializado, y BosqueMap
##   no tiene formato de tipos simples). Guarda la clave y lo que la forma, para depurar y para que
##   la limpieza sepa qué hay en cada carpeta.
## - `c_<x>_<y>.bin`: un WorldChunk (WorldChunk.to_dict con var_to_bytes, sin objetos).
## Cabecera de cada archivo, dentro del flujo comprimido: magia `NBW2`, CACHE_VERSION (u32),
## WorldChunk.FORMAT_VERSION (u32), world_key (u64), tamaño de la carga (u32) y su SHA-256
## (32 bytes). Después, la carga.
##
## La caché es derivable: si un archivo falta, tiene otra clave, otra versión, está truncado o
## corrupto (no cuadra el SHA-256), se trata como ausente y quien llama regenera. Nunca guarda
## cambios del jugador (esos van en GameState) y no va en el guardado ni en Steam Cloud.
## Escribe en un temporal y renombra, así que un cierre a medias no deja un archivo "válido".
## Es segura entre hilos: no tiene estado mutable tras _init y cada llamada abre su propio
## FileAccess. No toca el árbol de escena.

const ROOT: String = "user://world_cache"
const MAGIC: PackedByteArray = [0x4E, 0x42, 0x57, 0x32]  # "NBW2"
## Versión del contenedor (cabecera). Súbela si cambia el orden o el tipo de los campos.
const CACHE_VERSION: int = 1
const REGION_FILE: String = "region.bin"
const COMPRESSION: FileAccess.CompressionMode = FileAccess.COMPRESSION_ZSTD
## Tope de la carga, para no reservar memoria con un tamaño corrupto (un chunk ocupa ~60 KB).
const MAX_PAYLOAD: int = 4 * 1024 * 1024
## magia + 2 versiones + clave + tamaño + SHA-256.
const HEADER_SIZE: int = 4 + 4 + 4 + 8 + 4 + 32

var world_key: int = 0
## Versión de la generación que forma la clave (solo informativa: va en region.bin).
var generator_version: int = 0
var dir_path: String = ""
var root: String = ROOT


## `root` solo cambia en los tests (una carpeta aparte en user://).
func _init(key: int, cache_root: String = ROOT) -> void:
	world_key = key
	root = cache_root
	dir_path = "%s/%s" % [root, key_to_name(key)]


## Clave del mundo: SHA-256 de los cuatro valores, recortada a 63 bits (siempre positiva).
## `generator_version` debe cambiar con cualquier cambio de la salida: el que conecte el
## ChunkBuilder real usa combined_generator_version().
static func key_for(seed_value: int, region_id: StringName, generator_version: int, authoring_hash: int) -> int:
	var text: String = "%d|%s|%d|%d" % [seed_value, region_id, generator_version, authoring_hash]
	return text.sha256_buffer().decode_u64(0) & 0x7FFFFFFFFFFFFFFF


## Versión de toda la generación: la pasada de región, la de chunk y el formato del chunk. Así un
## cambio en cualquiera de las tres invalida la caché sin que nadie tenga que acordarse.
static func combined_generator_version(chunk_builder_version: int) -> int:
	return (RegionPlan.GENERATOR_VERSION << 32) | ((chunk_builder_version & 0xFFFF) << 16) \
			| (WorldChunk.FORMAT_VERSION & 0xFFFF)


## Caché del mundo de un plan ya construido.
static func for_plan(plan: RegionPlan, chunk_builder_version: int, cache_root: String = ROOT) -> WorldCache:
	var version: int = combined_generator_version(chunk_builder_version)
	var cache := WorldCache.new(key_for(plan.seed_value, plan.region_id, version, plan.authoring_hash),
			cache_root)
	cache.generator_version = version
	return cache


static func key_to_name(key: int) -> String:
	return "%016x" % key


static func chunk_file_name(coord: Vector2i) -> String:
	return "c_%d_%d.bin" % [coord.x, coord.y]


func chunk_path(coord: Vector2i) -> String:
	return "%s/%s" % [dir_path, chunk_file_name(coord)]


func region_path() -> String:
	return "%s/%s" % [dir_path, REGION_FILE]


## Crea la carpeta y escribe region.bin si falta o no es válido. Devuelve OK o el error.
func prepare(plan: RegionPlan) -> Error:
	var err: Error = DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK:
		return err
	if not load_region().is_empty():
		return OK
	return _write(region_path(), {
		"seed": plan.seed_value,
		"region_id": String(plan.region_id),
		"generator_version": generator_version,
		"authoring_hash": plan.authoring_hash,
		"size_chunks": plan.size_chunks,
		"home_chunk": plan.home_chunk,
	})


## Manifiesto de region.bin ({} si falta o no es válido).
func load_region() -> Dictionary:
	var data: Variant = _read(region_path())
	return data if data is Dictionary else {}


## Guarda el chunk. Seguro desde un hilo de trabajo. Devuelve OK o el error.
func save_chunk(chunk: WorldChunk) -> Error:
	var err: Error = DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK:
		return err
	return _write(chunk_path(chunk.coord), chunk.to_dict())


## Chunk de la caché, o null si falta o no vale (clave, versión, truncado, corrupto o de otra
## coordenada): quien llama lo regenera.
func load_chunk(coord: Vector2i) -> WorldChunk:
	var data: Variant = _read(chunk_path(coord))
	if not data is Dictionary:
		return null
	var chunk: WorldChunk = WorldChunk.from_dict(data)
	if chunk == null or chunk.coord != coord:
		return null
	return chunk


func has_chunk(coord: Vector2i) -> bool:
	return FileAccess.file_exists(chunk_path(coord))


## Borra la carpeta de este mundo entera.
func clear() -> void:
	_remove_tree(dir_path)


## Borra las carpetas de `cache_root` cuya clave no esté en `keep_keys` (las que usa algún slot).
## Devuelve cuántas borró. Pensada para SaveManager al guardar (se enchufa en M17).
static func clean_unused(keep_keys: Array[int], cache_root: String = ROOT) -> int:
	var dir := DirAccess.open(cache_root)
	if dir == null:
		return 0
	var keep: Dictionary = {}
	for key: int in keep_keys:
		keep[key_to_name(key)] = true
	var removed: int = 0
	for name: String in dir.get_directories():
		if not keep.has(name):
			_remove_tree("%s/%s" % [cache_root, name])
			removed += 1
	return removed


# --- formato ---------------------------------------------------------------------------------

func _write(path: String, data: Dictionary) -> Error:
	var payload: PackedByteArray = var_to_bytes(data)
	# Temporal por hilo: el hilo principal y un trabajador pueden escribir el mismo chunk a la vez.
	var tmp: String = "%s.%d.tmp" % [path, OS.get_thread_caller_id()]
	var file := FileAccess.open_compressed(tmp, FileAccess.WRITE, COMPRESSION)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(MAGIC)
	file.store_32(CACHE_VERSION)
	file.store_32(WorldChunk.FORMAT_VERSION)
	file.store_64(world_key)
	file.store_32(payload.size())
	file.store_buffer(_sha256(payload))
	file.store_buffer(payload)
	var err: Error = file.get_error()
	file.close()
	if err != OK:
		DirAccess.remove_absolute(tmp)
		return err
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		DirAccess.remove_absolute(tmp)
	return err


## Carga validada (Variant) o null. Nunca deja errores del motor en el registro con un archivo
## malo: comprueba la cabecera y el SHA-256 antes de decodificar.
func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open_compressed(path, FileAccess.READ, COMPRESSION)
	if file == null:
		return null
	if file.get_length() < HEADER_SIZE or file.get_buffer(4) != MAGIC:
		return null
	if file.get_32() != CACHE_VERSION or file.get_32() != WorldChunk.FORMAT_VERSION:
		return null
	if file.get_64() != world_key:
		return null
	var size: int = file.get_32()
	if size <= 0 or size > MAX_PAYLOAD or size != file.get_length() - HEADER_SIZE:
		return null
	var digest: PackedByteArray = file.get_buffer(32)
	var payload: PackedByteArray = file.get_buffer(size)
	if file.get_error() != OK or payload.size() != size or _sha256(payload) != digest:
		return null
	return bytes_to_var(payload)


static func _sha256(bytes: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish()


static func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for name: String in dir.get_files():
		DirAccess.remove_absolute("%s/%s" % [path, name])
	for name: String in dir.get_directories():
		_remove_tree("%s/%s" % [path, name])
	DirAccess.remove_absolute(path)
