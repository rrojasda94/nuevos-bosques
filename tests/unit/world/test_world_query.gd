extends GutTest
## WorldQuery.rect (consulta de un rectángulo de world_cell para el combate táctico, ADR 0016):
## cruza bordes de chunk, copia nivel, bloqueo, escalera o rampa, agua y objeto, y trata un chunk
## que falta como bloqueado.

var _chunks: Dictionary = {}


func before_all() -> void:
	var plan: RegionPlan = RegionPlan.for_region(42, &"valle_del_sara")
	for coord: Vector2i in [Vector2i(5, 12), Vector2i(6, 12), Vector2i(5, 13), Vector2i(6, 13)]:
		_chunks[coord] = ChunkBuilder.build(plan, coord)


func _chunk_of(coord: Vector2i) -> WorldChunk:
	return _chunks.get(coord)


func test_rect_crosses_chunk_borders_and_matches_the_chunks() -> void:
	var origin := Vector2i(6 * WorldCoords.CHUNK - 7, 13 * WorldCoords.CHUNK - 5)
	var size := Vector2i(14, 11)
	var area: WorldQuery.Area = WorldQuery.rect(_chunk_of, origin, size)
	assert_eq(area.size, size)
	assert_eq(area.level.size(), size.x * size.y)
	var kinds: Dictionary = {}
	for y: int in size.y:
		for x: int in size.x:
			var wc: Vector2i = origin + Vector2i(x, y)
			var chunk: WorldChunk = _chunks[WorldCoords.world_cell_to_chunk(wc)]
			var cell: Vector2i = WorldCoords.world_cell_to_cell(wc)
			var got: Dictionary = area.at(wc)
			assert_true(got.loaded)
			assert_eq(got.level, chunk.get_level(cell), "nivel en %s" % wc)
			assert_eq(got.blocked, chunk.is_blocked(cell), "bloqueo en %s" % wc)
			assert_eq(got.cliff, chunk.get_cliff(cell))
			assert_eq(got.object, int(chunk.object_at(cell).get("kind", WorldChunk.NO_OBJECT)))
			kinds[WorldCoords.world_cell_to_chunk(wc)] = true
	assert_eq(kinds.size(), 4, "el rectángulo toca 4 chunks")


func test_crossings_and_water_are_classified() -> void:
	# Busca en los chunks cargados una escalera o rampa y agua, y compara con la consulta.
	var stairs: int = 0
	var water: int = 0
	for coord: Vector2i in _chunks:
		var area: WorldQuery.Area = WorldQuery.rect(_chunk_of, coord * WorldCoords.CHUNK, Vector2i(WorldCoords.CHUNK, WorldCoords.CHUNK))
		var chunk: WorldChunk = _chunks[coord]
		for i: int in WorldChunk.CELLS:
			var c: int = chunk.cliff[i]
			var expected: int = WorldQuery.Crossing.STAIRS if c == WorldChunk.Cliff.STAIRS else (WorldQuery.Crossing.RAMP if c == WorldChunk.Cliff.RAMP else WorldQuery.Crossing.NONE)
			assert_eq(area.crossing[i], expected)
			stairs += int(expected != WorldQuery.Crossing.NONE)
			var g: int = chunk.ground[i]
			if g == WorldChunk.Ground.FORD:
				assert_eq(area.water[i], WorldQuery.Water.FORD)
			elif g == WorldChunk.Ground.BRIDGE:
				assert_eq(area.water[i], WorldQuery.Water.BRIDGE)
			elif WorldChunk.is_ground_blocking(g):
				assert_eq(area.water[i], WorldQuery.Water.DEEP)
			else:
				assert_eq(area.water[i], WorldQuery.Water.NONE)
			water += int(area.water[i] != WorldQuery.Water.NONE)
	gut.p("escaleras o rampas: %d; agua: %d" % [stairs, water])


func test_missing_chunks_block() -> void:
	var origin := Vector2i(5 * WorldCoords.CHUNK - 2, 12 * WorldCoords.CHUNK)
	var area: WorldQuery.Area = WorldQuery.rect(_chunk_of, origin, Vector2i(4, 1))
	assert_false(area.at(origin).loaded, "el chunk (4, 12) no está cargado")
	assert_true(area.at(origin).blocked)
	assert_true(area.at(origin + Vector2i(2, 0)).loaded)
	assert_eq(area.at(origin + Vector2i(9, 0)), {}, "fuera del rectángulo")
	assert_eq(WorldQuery.rect(_chunk_of, origin, Vector2i.ZERO).level.size(), 0)
