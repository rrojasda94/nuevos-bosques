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
