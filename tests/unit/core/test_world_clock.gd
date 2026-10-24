extends GutTest
## Reloj de Aventura (ADR 0012, ficha tiempo-y-riutash.md): ciclo de Momentos, avisos y riutash
## en orden, día al amanecer, guardado, migración de v3 y pausa. Todo con WorldClock.advance():
## el _process del reloj se apaga durante cada test para no depender del tiempo real.

const SAVE_SLOT: int = 96

var _events: Array = []
var _day_manager: DayManager
var _old_check: Callable


func before_each() -> void:
	WorldClock.set_process(false)
	_old_check = WorldClock.shelter_check
	WorldClock.shelter_check = Callable()
	GameState.new_game(42)
	_events = []
	EventBus.riutash_warning.connect(_on_warning)
	EventBus.riutash_passed.connect(_on_passed)
	EventBus.momento_changed.connect(_on_momento)
	_day_manager = DayManager.new()
	add_child_autofree(_day_manager)


func after_each() -> void:
	EventBus.riutash_warning.disconnect(_on_warning)
	EventBus.riutash_passed.disconnect(_on_passed)
	EventBus.momento_changed.disconnect(_on_momento)
	WorldClock.shelter_check = _old_check
	WorldClock.set_process(true)


func after_all() -> void:
	DirAccess.remove_absolute(SaveManager.slot_path(SAVE_SLOT))


func _on_warning(seconds_left: int) -> void:
	_events.append(["warning", seconds_left])


func _on_passed(sheltered: bool) -> void:
	_events.append(["passed", sheltered])


func _on_momento(momento: StringName) -> void:
	_events.append(["momento", momento])


func test_spec_values_in_time_json() -> void:
	assert_eq(TimeConfig.duration(&"gietos"), 480.0)
	assert_eq(TimeConfig.duration(&"riumna"), 300.0)
	assert_eq(TimeConfig.warnings(), [60, 15] as Array[int])
	assert_eq(TimeConfig.riutash_damage_pct(), 30)
	assert_eq(TimeConfig.riutash_heal_pct(), 50)


func test_moonlight_uniforms_match_shader() -> void:
	var uniforms: Dictionary = TimeConfig.moonlight_uniforms()
	assert_true(uniforms.tint is Color)
	assert_false(uniforms.has("fade_seconds"))
	var shader: Shader = load("res://assets/shaders/moonlight.gdshader")
	var names: Array = shader.get_shader_uniform_list().map(func(u: Dictionary) -> String: return u.name)
	for key: String in uniforms:
		assert_has(names, key, "uniform del shader: %s" % key)
	assert_gt(TimeConfig.moonlight_fade_seconds(), 0.0)


func test_new_game_starts_at_dawn_of_gietos() -> void:
	assert_eq(WorldClock.momento(), &"gietos")
	assert_false(WorldClock.is_night())
	assert_eq(WorldClock.time_to_riutash(), 480.0)


func test_warnings_riutash_and_momento_in_order() -> void:
	WorldClock.advance(419.0)
	assert_eq(_events, [], "nada antes de los 60 s finales")
	WorldClock.advance(1.0)
	assert_eq(_events, [["warning", 60]])
	WorldClock.advance(44.0)
	assert_eq(_events.size(), 1, "aún faltan 16 s")
	WorldClock.advance(1.0)
	assert_eq(_events.back(), ["warning", 15])
	WorldClock.advance(14.5)
	assert_eq(_events.size(), 2)
	WorldClock.advance(0.5)
	assert_eq(_events, [["warning", 60], ["warning", 15], ["passed", false], ["momento", &"riumna"]])
	assert_true(WorldClock.is_night())
	assert_eq(WorldClock.time_to_riutash(), 300.0)


func test_full_cycle_in_one_big_step_keeps_order() -> void:
	WorldClock.advance(480.0 + 300.0 + 10.0)
	assert_eq(_events, [
		["warning", 60], ["warning", 15], ["passed", false], ["momento", &"riumna"],
		["warning", 60], ["warning", 15], ["passed", false], ["momento", &"gietos"],
	])
	assert_eq(WorldClock.momento(), &"gietos")
	assert_almost_eq(WorldClock.time_to_riutash(), 470.0, 0.001)


func test_shelter_check_decides_sheltered() -> void:
	WorldClock.shelter_check = func() -> bool: return true
	WorldClock.advance(480.0)
	assert_has(_events, ["passed", true])


func test_day_rises_only_at_dawn() -> void:
	watch_signals(EventBus)
	WorldClock.advance(480.0)
	assert_eq(GameState.day, 1, "el atardecer no sube el día")
	assert_signal_not_emitted(EventBus, "day_started")
	WorldClock.advance(300.0)
	assert_eq(GameState.day, 2, "el amanecer sí")
	assert_signal_emitted_with_parameters(EventBus, "day_ended", [1])
	assert_signal_emitted_with_parameters(EventBus, "day_started", [2])
	WorldClock.advance(780.0)
	assert_eq(GameState.day, 3)


func test_end_day_reports_ended_and_started_days() -> void:
	GameState.day = 4
	watch_signals(EventBus)
	_day_manager.end_day()
	assert_eq(GameState.day, 5)
	assert_signal_emitted_with_parameters(EventBus, "day_ended", [4])
	assert_signal_emitted_with_parameters(EventBus, "day_started", [5])


func test_clock_survives_save_and_load() -> void:
	WorldClock.advance(480.0 + 100.5)
	assert_eq(SaveManager.save_game(SAVE_SLOT), OK)
	GameState.new_game(1)
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	assert_eq(WorldClock.momento(), &"riumna")
	assert_almost_eq(GameState.clock_elapsed, 100.5, 0.001)
	assert_almost_eq(WorldClock.time_to_riutash(), 199.5, 0.001)


func test_loaded_close_to_riutash_gives_only_remaining_warnings() -> void:
	GameState.clock_elapsed = 470.0
	GameState.from_dict(JSON.parse_string(JSON.stringify(GameState.to_dict())))
	WorldClock.advance(10.0)
	assert_eq(_events, [["passed", false], ["momento", &"riumna"]])


func test_v3_save_loads_with_clock_at_start() -> void:
	var old: Dictionary = GameState.to_dict()
	old.erase("clock_momento")
	old.erase("clock_elapsed")
	old.save_version = 3
	GameState.clock_momento = &"riumna"
	GameState.clock_elapsed = 123.0
	GameState.from_dict(old)
	assert_eq(GameState.clock_momento, &"gietos")
	assert_eq(GameState.clock_elapsed, 0.0)


func test_invalid_clock_values_are_sanitized() -> void:
	var data: Dictionary = GameState.to_dict()
	data.clock_momento = "mediodia"
	data.clock_elapsed = -5
	GameState.from_dict(data)
	assert_eq(GameState.clock_momento, &"gietos")
	assert_eq(GameState.clock_elapsed, 0.0)


func test_clock_does_not_run_while_tree_is_paused() -> void:
	# El reloj hereda el modo de proceso (pausable): con el árbol en pausa Godot no llama a su
	# _process. No se espera un frame con la pausa puesta para no congelar al propio GUT.
	assert_eq(WorldClock.process_mode, Node.PROCESS_MODE_INHERIT)
	WorldClock.set_process(true)
	assert_true(WorldClock.can_process())
	get_tree().paused = true
	var paused_can_process: bool = WorldClock.can_process()
	get_tree().paused = false
	assert_false(paused_can_process)


func test_process_advances_the_clock() -> void:
	WorldClock._process(2.5)
	assert_almost_eq(GameState.clock_elapsed, 2.5, 0.001)
