extends GutTest
## Round-trip de GameState: to_dict -> from_dict debe conservar el estado.


func test_round_trip_preserves_resources() -> void:
	GameState.new_game(1234)
	GameState.resources["wood"] = 42
	var data := GameState.to_dict()
	GameState.new_game(1)
	GameState.from_dict(data)
	assert_eq(GameState.resources["wood"], 42)
	assert_eq(GameState.seed_value, 1234)


func test_round_trip_preserves_day_and_region() -> void:
	GameState.new_game(99, &"bosque_norte")
	GameState.day = 7
	var data := GameState.to_dict()
	GameState.new_game(1)
	GameState.from_dict(data)
	assert_eq(GameState.day, 7)
	assert_eq(GameState.region_id, &"bosque_norte")


func test_round_trip_preserves_chunk_coord_and_player_cell() -> void:
	GameState.new_game(5)
	GameState.chunk_coord = Vector2i(-2, 3)
	GameState.player_cell = Vector2i(10, 63)
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.new_game(1)
	GameState.from_dict(data)
	assert_eq(GameState.chunk_coord, Vector2i(-2, 3))
	assert_eq(GameState.player_cell, Vector2i(10, 63))
	assert_eq(GameState.seed_value, 5)


func test_new_game_resets_chunk_position() -> void:
	GameState.chunk_coord = Vector2i(4, 4)
	GameState.new_game(5)
	assert_eq(GameState.chunk_coord, Vector2i(-1, -1), "(-1, -1) = chunk inicial de la región")
	assert_eq(GameState.region_id, &"valle_del_sara")


# --- Mundo 2.0 (ADR 0014 §7 "Guardado") ---------------------------------------------------------

const SAVE_SLOT: int = 95


func after_all() -> void:
	DirAccess.remove_absolute(SaveManager.slot_path(SAVE_SLOT))


func test_save_version_is_world_2() -> void:
	assert_gte(GameState.SAVE_VERSION, 20)
	assert_eq(GameState.GENERATOR_VERSION, 2)
	var data: Dictionary = GameState.to_dict()
	assert_eq(int(data.save_version), GameState.SAVE_VERSION)
	assert_eq(int(data.generator_version), GameState.GENERATOR_VERSION)
	assert_false(GameState.is_old_world(data))


func test_round_trip_world_2_keys() -> void:
	GameState.new_game(5)
	GameState.world_key = WorldCache.key_to_name(0x7abcdef012345678)
	GameState.player_facing = Vector2i.LEFT
	GameState.chunk_coord = Vector2i(3, 7)
	GameState.player_cell = Vector2i(79, 0)
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.new_game(1)
	assert_eq(GameState.world_key, "", "partida nueva sin mundo")
	assert_eq(GameState.player_facing, Vector2i.DOWN)
	GameState.from_dict(data)
	assert_eq(GameState.world_key, "7abcdef012345678", "la clave de 63 bits no pierde precisión en el JSON")
	assert_eq(SaveManager.key_from_hex(GameState.world_key), 0x7abcdef012345678)
	assert_eq(GameState.player_facing, Vector2i.LEFT)
	assert_eq(GameState.chunk_coord, Vector2i(3, 7))
	assert_eq(GameState.player_cell, Vector2i(79, 0), "casillas 0-79")


func test_bad_world_2_values_fall_back() -> void:
	var data: Dictionary = GameState.to_dict()
	data.player_facing = [1, 1]
	data.player_cell = [80, 3]
	GameState.from_dict(data)
	assert_eq(GameState.player_facing, Vector2i.DOWN, "solo 4 direcciones")
	assert_eq(GameState.player_cell, Vector2i(-1, -1), "fuera del chunk de 80: aparece en la villa")


func test_old_world_saves_are_rejected() -> void:
	GameState.new_game(5)
	for version: int in [1, 13, 19]:
		var old: Dictionary = GameState.to_dict()
		old.save_version = version
		old.erase("generator_version")
		old.erase("world_key")
		assert_true(GameState.is_old_world(old), "v%d es del mundo viejo" % version)
		var file := FileAccess.open(SaveManager.slot_path(SAVE_SLOT), FileAccess.WRITE)
		file.store_string(JSON.stringify(old))
		file.close()
		GameState.day = 99
		assert_eq(SaveManager.check_slot(SAVE_SLOT), SaveManager.ERR_SAVE_OLD_WORLD)
		assert_eq(SaveManager.load_game(SAVE_SLOT), SaveManager.ERR_SAVE_OLD_WORLD, "v%d no se carga" % version)
		assert_eq(GameState.day, 99, "no toca la partida en curso")
	var other: Dictionary = GameState.to_dict()
	other.generator_version = 3
	assert_true(GameState.is_old_world(other), "otra versión del mundo tampoco")
	assert_ne(Texts.get_text("save_old_world"), "save_old_world", "aviso en sistema.json")


func test_save_and_load_world_2_slot() -> void:
	GameState.new_game(77)
	GameState.player_facing = Vector2i.UP
	assert_eq(SaveManager.save_game(SAVE_SLOT), OK)
	GameState.new_game(1)
	assert_eq(SaveManager.check_slot(SAVE_SLOT), OK)
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	assert_eq(GameState.seed_value, 77)
	assert_eq(GameState.player_facing, Vector2i.UP)


func test_clean_world_cache_keeps_the_current_world() -> void:
	var root: String = "user://test_clean_world_cache"
	for key: int in [11, 22]:
		DirAccess.make_dir_recursive_absolute("%s/%s" % [root, WorldCache.key_to_name(key)])
	GameState.new_game(5)
	assert_eq(SaveManager.clean_world_cache(root), 0, "sin mundo no borra nada")
	GameState.world_key = WorldCache.key_to_name(22)
	assert_eq(SaveManager.clean_world_cache(root), 1)
	assert_false(DirAccess.dir_exists_absolute("%s/%s" % [root, WorldCache.key_to_name(11)]))
	assert_true(DirAccess.dir_exists_absolute("%s/%s" % [root, WorldCache.key_to_name(22)]))
	DirAccess.remove_absolute("%s/%s" % [root, WorldCache.key_to_name(22)])
	DirAccess.remove_absolute(root)
	GameState.world_key = ""
