extends GutTest
## Autoload Sfx: carga los efectos de la spec, suena en el bus "SFX" y un nombre desconocido no
## rompe nada.

const EXPECTED: Array[StringName] = [
	&"step", &"text_blip", &"hit", &"whip", &"riutash_warning", &"riutash", &"level_up",
	&"menu_move", &"menu_accept",
]


func test_all_sfx_files_exist_and_load() -> void:
	for sfx_name: StringName in EXPECTED:
		var path: String = "res://assets/audio/sfx/sfx_%s.wav" % sfx_name
		assert_true(ResourceLoader.exists(path), "existe %s" % path)
		assert_true(Sfx.has(sfx_name), "Sfx tiene %s" % sfx_name)


func test_play_known_sfx() -> void:
	assert_true(Sfx.play(&"menu_move"))


func test_play_unknown_sfx_does_nothing() -> void:
	assert_false(Sfx.play(&"no_existe"))
	assert_false(Sfx.has(&"no_existe"))


func test_sfx_bus_exists() -> void:
	var index: int = AudioServer.get_bus_index(Sfx.BUS)
	assert_gt(index, 0, "bus SFX aparte del Master")
	assert_lt(AudioServer.get_bus_volume_db(index), 0.0, "volumen moderado")
