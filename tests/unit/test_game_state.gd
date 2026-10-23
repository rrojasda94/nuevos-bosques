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
	assert_eq(GameState.chunk_coord, Vector2i.ZERO)
