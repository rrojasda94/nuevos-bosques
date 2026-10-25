extends GutTest
## WorldCoords (ADR 0014 §1): escala, ida y vuelta entre chunk/cell, world_cell y world_pos,
## sector y macro, con negativos y bordes.


func test_constantes_de_escala() -> void:
	assert_eq(WorldCoords.TILE, 16)
	assert_eq(WorldCoords.CHUNK, 80)
	assert_eq(WorldCoords.SECTOR, 16)
	assert_eq(WorldCoords.MACRO, 4)
	assert_eq(WorldCoords.SECTORS_PER_CHUNK, 5)
	assert_eq(WorldCoords.MACROS_PER_CHUNK, 20)
	assert_eq(WorldCoords.CHUNK_CELLS, 6400)


func test_floor_div_redondea_hacia_abajo_con_negativos() -> void:
	assert_eq(WorldCoords.floor_div(0, 80), 0)
	assert_eq(WorldCoords.floor_div(79, 80), 0)
	assert_eq(WorldCoords.floor_div(80, 80), 1)
	assert_eq(WorldCoords.floor_div(-1, 80), -1)
	assert_eq(WorldCoords.floor_div(-80, 80), -1)
	assert_eq(WorldCoords.floor_div(-81, 80), -2)


func test_world_cell_ida_y_vuelta() -> void:
	var chunks: Array[Vector2i] = [Vector2i.ZERO, Vector2i(3, 7), Vector2i(-1, -1), Vector2i(-5, 2), Vector2i(11, -15)]
	var cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i(79, 79), Vector2i(0, 79), Vector2i(40, 13)]
	for chunk: Vector2i in chunks:
		for cell: Vector2i in cells:
			var wc: Vector2i = WorldCoords.to_world_cell(chunk, cell)
			assert_eq(WorldCoords.world_cell_to_chunk(wc), chunk, "chunk de %s" % wc)
			assert_eq(WorldCoords.world_cell_to_cell(wc), cell, "cell de %s" % wc)


func test_world_cell_negativa_cae_en_el_chunk_anterior() -> void:
	assert_eq(WorldCoords.world_cell_to_chunk(Vector2i(-1, -1)), Vector2i(-1, -1))
	assert_eq(WorldCoords.world_cell_to_cell(Vector2i(-1, -1)), Vector2i(79, 79))
	assert_eq(WorldCoords.world_cell_to_chunk(Vector2i(-80, 80)), Vector2i(-1, 1))
	assert_eq(WorldCoords.world_cell_to_cell(Vector2i(-80, 80)), Vector2i(0, 0))
	assert_eq(WorldCoords.world_cell_to_chunk(Vector2i(-81, 0)), Vector2i(-2, 0))


func test_world_pos_a_casilla_por_los_pies() -> void:
	assert_eq(WorldCoords.world_pos_to_world_cell(Vector2(0, 0)), Vector2i(0, 0))
	assert_eq(WorldCoords.world_pos_to_world_cell(Vector2(15.99, 15.99)), Vector2i(0, 0))
	assert_eq(WorldCoords.world_pos_to_world_cell(Vector2(16, 16)), Vector2i(1, 1))
	assert_eq(WorldCoords.world_pos_to_world_cell(Vector2(-0.01, -16)), Vector2i(-1, -1))
	assert_eq(WorldCoords.world_pos_to_world_cell(Vector2(-16.01, 0)), Vector2i(-2, 0))


func test_world_pos_ida_y_vuelta_por_el_centro() -> void:
	for wc: Vector2i in [Vector2i.ZERO, Vector2i(959, 1279), Vector2i(-1, -1), Vector2i(-80, 81)]:
		var pos: Vector2 = WorldCoords.world_cell_to_world_pos(wc)
		assert_eq(pos, Vector2(wc * 16) + Vector2(8, 8))
		assert_eq(WorldCoords.world_pos_to_world_cell(pos), wc)
	assert_eq(WorldCoords.world_cell_origin(Vector2i(2, -1)), Vector2(32, -16))


func test_world_pos_a_chunk_y_cell() -> void:
	var pos: Vector2 = WorldCoords.cell_to_world_pos(Vector2i(2, -3), Vector2i(79, 0))
	assert_eq(WorldCoords.world_pos_to_chunk(pos), Vector2i(2, -3))
	assert_eq(WorldCoords.world_pos_to_cell(pos), Vector2i(79, 0))
	# Último píxel del chunk 0 y primero del 1.
	assert_eq(WorldCoords.world_pos_to_chunk(Vector2(1279.9, 0)), Vector2i(0, 0))
	assert_eq(WorldCoords.world_pos_to_chunk(Vector2(1280, 0)), Vector2i(1, 0))
	assert_eq(WorldCoords.world_pos_to_chunk(Vector2(-0.5, 0)), Vector2i(-1, 0))


func test_sector_y_bordes() -> void:
	assert_eq(WorldCoords.cell_to_sector(Vector2i(0, 15)), Vector2i(0, 0))
	assert_eq(WorldCoords.cell_to_sector(Vector2i(16, 79)), Vector2i(1, 4))
	assert_eq(WorldCoords.cell_to_sector(Vector2i(-1, -16)), Vector2i(-1, -1))
	assert_eq(WorldCoords.cell_to_sector(Vector2i(-17, 0)), Vector2i(-2, 0))
	for s: Vector2i in [Vector2i(0, 0), Vector2i(4, 4), Vector2i(-3, 2)]:
		var origin: Vector2i = WorldCoords.sector_origin(s)
		assert_eq(WorldCoords.cell_to_sector(origin), s)
		assert_eq(WorldCoords.cell_to_sector(origin + Vector2i(15, 15)), s)
		assert_eq(WorldCoords.cell_to_sector(origin - Vector2i.ONE), s - Vector2i.ONE)


func test_macro_y_bordes() -> void:
	assert_eq(WorldCoords.cell_to_macro(Vector2i(3, 4)), Vector2i(0, 1))
	assert_eq(WorldCoords.cell_to_macro(Vector2i(79, 79)), Vector2i(19, 19))
	assert_eq(WorldCoords.cell_to_macro(Vector2i(-1, -4)), Vector2i(-1, -1))
	assert_eq(WorldCoords.cell_to_macro(Vector2i(-5, 0)), Vector2i(-2, 0))
	for m: Vector2i in [Vector2i(0, 0), Vector2i(19, 7), Vector2i(-6, -1)]:
		var origin: Vector2i = WorldCoords.macro_origin(m)
		assert_eq(WorldCoords.cell_to_macro(origin), m)
		assert_eq(WorldCoords.cell_to_macro(origin + Vector2i(3, 3)), m)


func test_indice_de_capa() -> void:
	assert_eq(WorldCoords.cell_index(Vector2i(0, 0)), 0)
	assert_eq(WorldCoords.cell_index(Vector2i(79, 0)), 79)
	assert_eq(WorldCoords.cell_index(Vector2i(0, 1)), 80)
	assert_eq(WorldCoords.cell_index(Vector2i(79, 79)), 6399)
	for i: int in [0, 1, 79, 80, 3333, 6399]:
		assert_eq(WorldCoords.cell_index(WorldCoords.index_to_cell(i)), i)
	assert_true(WorldCoords.in_chunk(Vector2i(79, 0)))
	assert_false(WorldCoords.in_chunk(Vector2i(80, 0)))
	assert_false(WorldCoords.in_chunk(Vector2i(0, -1)))
