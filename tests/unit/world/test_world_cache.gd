extends GutTest
## Caché del mundo (WorldCache, ADR 0014 §6, M10): ida y vuelta byte a byte, la clave cambia con
## cada componente, clave o versión distinta = ausente, archivo truncado o corrupto = ausente sin
## errores del motor, manifiesto region.bin y limpieza de cachés no usadas.

const FakeBuilder := preload("res://tests/unit/world/fake_chunk_builder.gd")
const ROOT: String = "user://test_world_cache"

var _plan: RegionPlan


func before_all() -> void:
	_plan = RegionPlan.new()
	_plan.seed_value = 42
	_plan.region_id = &"test"
	_plan.authoring_hash = 7
	_plan.size_chunks = Vector2i(4, 4)
	_plan.home_chunk = Vector2i(1, 1)


func before_each() -> void:
	WorldCache.clean_unused([], ROOT)


func after_all() -> void:
	WorldCache.clean_unused([], ROOT)
	DirAccess.remove_absolute(ROOT)


func _cache(key: int = 1234) -> WorldCache:
	return WorldCache.new(key, ROOT)


func _bytes(chunk: WorldChunk) -> PackedByteArray:
	return var_to_bytes(chunk.to_dict())


func test_round_trip_is_byte_identical() -> void:
	var cache := _cache()
	for coord: Vector2i in [Vector2i(0, 0), Vector2i(3, 2), Vector2i(1, 1)]:
		var chunk: WorldChunk = FakeBuilder.build(_plan, coord)
		assert_eq(cache.save_chunk(chunk), OK)
		var loaded: WorldChunk = cache.load_chunk(coord)
		assert_not_null(loaded, "el chunk %s vuelve de la caché" % coord)
		if loaded == null:
			continue
		assert_eq(_bytes(loaded), _bytes(chunk), "mismos bytes tras la caché en %s" % coord)
		assert_eq(loaded.occupant, chunk.occupant, "occupant se rehace igual")
		assert_eq(loaded.blocked, chunk.blocked)


func test_same_chunk_writes_same_file() -> void:
	var a := WorldCache.new(1234, ROOT + "/a")
	var b := WorldCache.new(1234, ROOT + "/b")
	var chunk: WorldChunk = FakeBuilder.build(_plan, Vector2i(2, 3))
	a.save_chunk(chunk)
	b.save_chunk(FakeBuilder.build(_plan, Vector2i(2, 3)))
	assert_eq(FileAccess.get_file_as_bytes(a.chunk_path(chunk.coord)),
			FileAccess.get_file_as_bytes(b.chunk_path(chunk.coord)), "archivo determinista")
	WorldCache.clean_unused([], ROOT + "/a")
	WorldCache.clean_unused([], ROOT + "/b")
	DirAccess.remove_absolute(ROOT + "/a")
	DirAccess.remove_absolute(ROOT + "/b")


func test_missing_chunk_is_null() -> void:
	assert_null(_cache().load_chunk(Vector2i(9, 9)))


func test_key_changes_with_each_component() -> void:
	var base: int = WorldCache.key_for(42, &"valle_del_sara", 2, 99)
	assert_eq(base, WorldCache.key_for(42, &"valle_del_sara", 2, 99), "determinista")
	assert_true(base >= 0, "63 bits, positiva")
	assert_ne(base, WorldCache.key_for(43, &"valle_del_sara", 2, 99), "seed")
	assert_ne(base, WorldCache.key_for(42, &"otra", 2, 99), "region_id")
	assert_ne(base, WorldCache.key_for(42, &"valle_del_sara", 3, 99), "generator_version")
	assert_ne(base, WorldCache.key_for(42, &"valle_del_sara", 2, 100), "authoring_hash")
	assert_eq(WorldCache.key_to_name(base).length(), 16)


func test_generator_version_combines_region_builder_and_format() -> void:
	var v: int = WorldCache.combined_generator_version(1)
	assert_ne(v, WorldCache.combined_generator_version(2), "versión del ChunkBuilder")
	assert_eq(v >> 32, RegionPlan.GENERATOR_VERSION, "versión de la pasada de región")
	assert_eq(v & 0xFFFF, WorldChunk.FORMAT_VERSION, "formato del chunk")


func test_for_plan_uses_plan_key() -> void:
	var cache: WorldCache = WorldCache.for_plan(_plan, 1, ROOT)
	var expected: int = WorldCache.key_for(42, &"test", WorldCache.combined_generator_version(1), 7)
	assert_eq(cache.world_key, expected)
	assert_eq(cache.dir_path, "%s/%s" % [ROOT, WorldCache.key_to_name(expected)])


func test_different_key_is_treated_as_missing() -> void:
	var cache := _cache(1234)
	var chunk: WorldChunk = FakeBuilder.build(_plan, Vector2i(1, 2))
	cache.save_chunk(chunk)
	# Mismo archivo leído por un mundo con otra clave (p. ej. otra versión del generador).
	var other := _cache(5678)
	DirAccess.make_dir_recursive_absolute(other.dir_path)
	DirAccess.copy_absolute(cache.chunk_path(chunk.coord), other.chunk_path(chunk.coord))
	assert_null(other.load_chunk(chunk.coord), "clave distinta = regenerar")
	assert_not_null(cache.load_chunk(chunk.coord), "la buena sigue valiendo")


func test_wrong_coordinate_is_treated_as_missing() -> void:
	var cache := _cache()
	cache.save_chunk(FakeBuilder.build(_plan, Vector2i(0, 1)))
	DirAccess.copy_absolute(cache.chunk_path(Vector2i(0, 1)), cache.chunk_path(Vector2i(2, 2)))
	assert_null(cache.load_chunk(Vector2i(2, 2)), "un archivo con otra coordenada no vale")


func test_truncated_files_are_treated_as_missing() -> void:
	var cache := _cache()
	var chunk: WorldChunk = FakeBuilder.build(_plan, Vector2i(3, 3))
	cache.save_chunk(chunk)
	var path: String = cache.chunk_path(chunk.coord)
	var good: PackedByteArray = FileAccess.get_file_as_bytes(path)
	# (Sin el último byte, ZSTD aún saca la carga entera y su SHA-256 cuadra: vale y no se prueba.)
	for keep: int in [0, 3, 12, good.size() / 4, good.size() / 2, good.size() * 3 / 4]:
		_write_raw(path, good.slice(0, keep))
		assert_null(cache.load_chunk(chunk.coord), "truncado a %d bytes = regenerar" % keep)
	_write_raw(path, good)
	assert_not_null(cache.load_chunk(chunk.coord), "restaurado vuelve a valer")


func test_corrupted_files_are_treated_as_missing() -> void:
	var cache := _cache()
	var chunk: WorldChunk = FakeBuilder.build(_plan, Vector2i(2, 0))
	cache.save_chunk(chunk)
	var path: String = cache.chunk_path(chunk.coord)
	var good: PackedByteArray = FileAccess.get_file_as_bytes(path)
	for at: int in [good.size() - 5, good.size() / 2, 30]:
		var bad: PackedByteArray = good.duplicate()
		bad[at] = bad[at] ^ 0x5A
		_write_raw(path, bad)
		assert_null(cache.load_chunk(chunk.coord), "byte %d cambiado = regenerar" % at)
	_write_raw(path, "esto no es una caché".to_utf8_buffer())
	assert_null(cache.load_chunk(chunk.coord), "basura = regenerar")


func test_corrupted_payload_with_valid_container_is_missing() -> void:
	# Contenedor ZSTD válido y cabecera buena, pero la carga no cuadra con su SHA-256.
	var cache := _cache()
	var path: String = cache.chunk_path(Vector2i(1, 0))
	DirAccess.make_dir_recursive_absolute(cache.dir_path)
	var payload: PackedByteArray = var_to_bytes(FakeBuilder.build(_plan, Vector2i(1, 0)).to_dict())
	var file := FileAccess.open_compressed(path, FileAccess.WRITE, WorldCache.COMPRESSION)
	file.store_buffer(WorldCache.MAGIC)
	file.store_32(WorldCache.CACHE_VERSION)
	file.store_32(WorldChunk.FORMAT_VERSION)
	file.store_64(cache.world_key)
	file.store_32(payload.size())
	var zero_digest := PackedByteArray()
	zero_digest.resize(32)
	file.store_buffer(zero_digest)
	file.store_buffer(payload)
	file.close()
	assert_null(cache.load_chunk(Vector2i(1, 0)), "SHA-256 distinto = regenerar")


func test_old_format_version_is_missing() -> void:
	var cache := _cache()
	var path: String = cache.chunk_path(Vector2i(0, 0))
	DirAccess.make_dir_recursive_absolute(cache.dir_path)
	var file := FileAccess.open_compressed(path, FileAccess.WRITE, WorldCache.COMPRESSION)
	file.store_buffer(WorldCache.MAGIC)
	file.store_32(WorldCache.CACHE_VERSION)
	file.store_32(WorldChunk.FORMAT_VERSION + 1)
	file.close()
	assert_null(cache.load_chunk(Vector2i(0, 0)))


func test_region_manifest() -> void:
	var cache: WorldCache = WorldCache.for_plan(_plan, 1, ROOT)
	assert_true(cache.load_region().is_empty(), "sin preparar no hay manifiesto")
	assert_eq(cache.prepare(_plan), OK)
	var manifest: Dictionary = cache.load_region()
	assert_eq(manifest.get("seed"), 42)
	assert_eq(manifest.get("region_id"), "test")
	assert_eq(manifest.get("authoring_hash"), 7)
	assert_eq(manifest.get("size_chunks"), Vector2i(4, 4))
	assert_eq(manifest.get("home_chunk"), Vector2i(1, 1))
	assert_eq(manifest.get("generator_version"), WorldCache.combined_generator_version(1))
	_write_raw(cache.region_path(), PackedByteArray([1, 2, 3]))
	assert_true(cache.load_region().is_empty(), "manifiesto corrupto = ausente")
	assert_eq(cache.prepare(_plan), OK)
	assert_false(cache.load_region().is_empty(), "prepare lo rehace")


func test_clean_unused_keeps_only_listed_keys() -> void:
	var used := _cache(1)
	var unused := _cache(2)
	var also_unused := _cache(3)
	for cache: WorldCache in [used, unused, also_unused]:
		cache.save_chunk(FakeBuilder.build(_plan, Vector2i(0, 0)))
	var keep: Array[int] = [1]
	assert_eq(WorldCache.clean_unused(keep, ROOT), 2)
	assert_true(DirAccess.dir_exists_absolute(used.dir_path), "la usada se queda")
	assert_false(DirAccess.dir_exists_absolute(unused.dir_path))
	assert_false(DirAccess.dir_exists_absolute(also_unused.dir_path))
	assert_not_null(used.load_chunk(Vector2i(0, 0)))
	assert_eq(WorldCache.clean_unused(keep, ROOT + "/no_existe"), 0, "sin carpeta no hace nada")


func test_clear_removes_world_folder() -> void:
	var cache := _cache()
	cache.save_chunk(FakeBuilder.build(_plan, Vector2i(0, 0)))
	cache.clear()
	assert_false(DirAccess.dir_exists_absolute(cache.dir_path))
	assert_null(cache.load_chunk(Vector2i(0, 0)))


func _write_raw(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
