extends GutTest
## Lógica pura del streaming del WorldView (M12, ADR 0014 §6): sectores visibles con margen e
## histéresis, cola de montaje por prioridad, anillos de chunks activos y de prefetch, índice de
## objetos por sector y elección de piezas de WorldPainter.paint_sector.

const SECTOR_PX: int = WorldCoords.SECTOR * WorldCoords.TILE  # 256
const REGION_SECTORS := Vector2i(60, 80)
const VIEW_SIZE := Vector2(320, 180)


func _view_at(center: Vector2) -> Rect2:
	return Rect2(center - VIEW_SIZE * 0.5, VIEW_SIZE)


# --- sectores ---

func test_sector_range_covers_view_and_margin() -> void:
	# Centrada en el sector (10, 10): 320 px de ancho pisan los sectores 9 a 11; 180 de alto, el 10.
	var center := Vector2(10.5 * SECTOR_PX, 10.5 * SECTOR_PX)
	assert_eq(WorldStreamer.sector_range(_view_at(center), 0, REGION_SECTORS), Rect2i(9, 10, 3, 1))
	assert_eq(WorldStreamer.sector_range(_view_at(center), 1, REGION_SECTORS), Rect2i(8, 9, 5, 3),
			"con el margen, unos 5×3 sectores (5×4 al cruzar un límite)")
	var corner := Vector2(10 * SECTOR_PX + 160, 10 * SECTOR_PX + 90)
	assert_eq(WorldStreamer.sector_range(_view_at(corner), 0, REGION_SECTORS), Rect2i(10, 10, 2, 1),
			"alineada con el sector, solo 2×1")


func test_sector_range_clipped_to_region() -> void:
	var r: Rect2i = WorldStreamer.sector_range(_view_at(VIEW_SIZE * 0.5), 1, REGION_SECTORS)
	assert_eq(r.position, Vector2i.ZERO)
	assert_eq(r.end, Vector2i(3, 2))
	var far: Vector2 = Vector2(REGION_SECTORS * SECTOR_PX) - VIEW_SIZE * 0.5
	assert_eq(WorldStreamer.sector_range(_view_at(far), 2, REGION_SECTORS).end, REGION_SECTORS)


func test_plan_sectors_mounts_wanted_not_mounted() -> void:
	var center := Vector2(10.5 * SECTOR_PX, 10.5 * SECTOR_PX)
	var mounted: Dictionary = {Vector2i(10, 10): true}
	var result: Dictionary = WorldStreamer.plan_sectors(mounted, _view_at(center), REGION_SECTORS)
	assert_eq(result.mount.size(), 5 * 3 - 1)
	assert_false(result.mount.has(Vector2i(10, 10)))
	assert_true(result.mount.has(Vector2i(9, 9)))
	assert_eq(result.unmount.size(), 0)


func test_plan_sectors_hysteresis() -> void:
	var center := Vector2(10.5 * SECTOR_PX, 10.5 * SECTOR_PX)
	# Vista + margen 1 = x 8..12, y 9..11; histéresis de otro sector = x 7..13, y 8..12.
	var mounted: Dictionary = {Vector2i(7, 10): true, Vector2i(13, 10): true, Vector2i(6, 10): true,
			Vector2i(14, 10): true, Vector2i(10, 8): true, Vector2i(10, 7): true}
	var result: Dictionary = WorldStreamer.plan_sectors(mounted, _view_at(center), REGION_SECTORS)
	assert_false(result.unmount.has(Vector2i(7, 10)), "a 1 sector del margen se queda")
	assert_false(result.unmount.has(Vector2i(13, 10)))
	assert_false(result.unmount.has(Vector2i(10, 8)))
	assert_true(result.unmount.has(Vector2i(6, 10)), "a 2 sectores del margen se quita")
	assert_true(result.unmount.has(Vector2i(14, 10)))
	assert_true(result.unmount.has(Vector2i(10, 7)))
	assert_eq(result.unmount.size(), 3)


func test_no_flicker_on_boundary() -> void:
	# Ir y volver sobre el límite de un sector no desmonta lo que se acaba de montar.
	var mounted: Dictionary = {}
	var a := Vector2(10.5 * SECTOR_PX, 10.5 * SECTOR_PX)
	for s: Vector2i in WorldStreamer.plan_sectors(mounted, _view_at(a), REGION_SECTORS).mount:
		mounted[s] = true
	var b: Vector2 = a + Vector2(SECTOR_PX * 0.6, 0)
	var r1: Dictionary = WorldStreamer.plan_sectors(mounted, _view_at(b), REGION_SECTORS)
	for s: Vector2i in r1.mount:
		mounted[s] = true
	assert_eq(r1.unmount.size(), 0)
	var r2: Dictionary = WorldStreamer.plan_sectors(mounted, _view_at(a), REGION_SECTORS)
	assert_eq(r2.unmount.size(), 0)
	assert_eq(r2.mount.size(), 0)


# --- cola de montaje ---

func test_priority_prefers_movement_direction() -> void:
	var focus: Vector2 = WorldStreamer.sector_center(Vector2i(10, 10))
	var east := Vector2i(12, 10)
	var west := Vector2i(8, 10)
	assert_lt(WorldStreamer.mount_priority(east, focus, Vector2.RIGHT),
			WorldStreamer.mount_priority(west, focus, Vector2.RIGHT))
	assert_lt(WorldStreamer.mount_priority(west, focus, Vector2(-3, 0)),
			WorldStreamer.mount_priority(east, focus, Vector2(-3, 0)))
	assert_eq(WorldStreamer.mount_priority(east, focus, Vector2.ZERO),
			WorldStreamer.mount_priority(west, focus, Vector2.ZERO), "quieto: solo distancia")


func test_sort_queue_ahead_first_then_near() -> void:
	var focus: Vector2 = WorldStreamer.sector_center(Vector2i(10, 10))
	var queue: Array[Vector2i] = [Vector2i(8, 10), Vector2i(11, 10), Vector2i(10, 12), Vector2i(12, 10)]
	WorldStreamer.sort_queue(queue, focus, Vector2.RIGHT)
	assert_eq(queue[0], Vector2i(11, 10))
	assert_eq(queue[1], Vector2i(12, 10), "delante, aunque esté más lejos que el de abajo")
	assert_eq(queue[-1], Vector2i(8, 10), "detrás, lo último")
	var still: Array[Vector2i] = [Vector2i(12, 10), Vector2i(9, 10), Vector2i(11, 10)]
	WorldStreamer.sort_queue(still, focus, Vector2.ZERO)
	assert_eq(still, [Vector2i(9, 10), Vector2i(11, 10), Vector2i(12, 10)] as Array[Vector2i], "empates por fila y columna")


# --- chunks ---

func test_chunk_rings() -> void:
	var size := Vector2i(12, 16)
	assert_eq(WorldStreamer.chunk_ring(Vector2i(5, 5), WorldStreamer.ACTIVE_RADIUS, size).size(), 9)
	assert_eq(WorldStreamer.chunk_ring(Vector2i(5, 5), WorldStreamer.PREFETCH_RADIUS, size).size(), 25)
	var corner: Array[Vector2i] = WorldStreamer.chunk_ring(Vector2i.ZERO, WorldStreamer.ACTIVE_RADIUS, size)
	assert_eq(corner, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)] as Array[Vector2i])
	assert_eq(WorldStreamer.chunk_ring(Vector2i(11, 15), 2, size).size(), 9)


func test_evict_beyond_hysteresis() -> void:
	var loaded: Array = [Vector2i(5, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(2, 9), Vector2i(1, 1)]
	var out: Array[Vector2i] = WorldStreamer.chunks_to_evict(loaded, Vector2i(5, 5))
	assert_false(out.has(Vector2i(7, 5)), "anillo de prefetch")
	assert_false(out.has(Vector2i(8, 5)), "un chunk de histéresis")
	assert_true(out.has(Vector2i(2, 9)))
	assert_true(out.has(Vector2i(1, 1)))
	assert_eq(out.size(), 2)


func test_objects_by_sector() -> void:
	var chunk := WorldChunk.new()
	var a: int = chunk.add_object(WorldChunk.ObjectKind.TREE, Vector2i(3, 3), Vector2i(2, 2))
	var b: int = chunk.add_object(WorldChunk.ObjectKind.HOUSE, Vector2i(15, 20), Vector2i(4, 3))
	var c: int = chunk.add_object(WorldChunk.ObjectKind.CAVE, Vector2i(40, 40), Vector2i(2, 2))
	var d: int = chunk.add_object(WorldChunk.ObjectKind.ROCK, Vector2i(79, 79))
	var index: Array[PackedInt32Array] = WorldStreamer.objects_by_sector(chunk)
	assert_eq(index.size(), 25)
	assert_eq(index[0], PackedInt32Array([a]))
	assert_eq(index[1 * 5 + 0], PackedInt32Array([b]), "por la casilla noroeste, aunque cruce sectores")
	assert_false(index[2 * 5 + 2].has(c), "la cueva va en la capa de suelo")
	assert_eq(index[24], PackedInt32Array([d]))


# --- piezas ---

func _flat_chunk(coord: Vector2i = Vector2i.ZERO) -> WorldChunk:
	var chunk := WorldChunk.new()
	chunk.coord = coord
	return chunk


func _code_at(paint: Dictionary, layer: String, local: Vector2i) -> int:
	return (paint[layer] as PackedInt32Array)[local.y * WorldCoords.SECTOR + local.x]


func test_paint_sector_needs_its_chunk() -> void:
	assert_eq(WorldPainter.paint_sector(Vector2i(5, 0), {Vector2i.ZERO: _flat_chunk()}), {})
	var paint: Dictionary = WorldPainter.paint_sector(Vector2i(4, 4), {Vector2i.ZERO: _flat_chunk()})
	assert_eq((paint.ground as PackedInt32Array).size(), 256)


func test_paint_grass_level_and_variant() -> void:
	var chunk := _flat_chunk()
	chunk.set_variant(Vector2i(1, 1), 2)
	chunk.set_level(Vector2i(2, 1), 2)
	var paint: Dictionary = WorldPainter.paint_sector(Vector2i.ZERO, {Vector2i.ZERO: chunk})
	var code: int = _code_at(paint, "ground", Vector2i(1, 1))
	assert_eq(WorldPainter.code_source(code), WorldPainter.Src.GRASS)
	assert_eq(WorldPainter.code_atlas(code), Vector2i(2, 0))
	assert_eq(WorldPainter.code_source(_code_at(paint, "ground", Vector2i(2, 1))), WorldPainter.Src.GRASS_HIGH,
			"meseta alta: hierba de GROUNDS_HIGH")
	assert_eq(_code_at(paint, "overlay", Vector2i(1, 1)), WorldPainter.NONE)


func test_paint_cliff_pieces_from_builder_variant() -> void:
	var chunk := _flat_chunk()
	var shift: int = ChunkBuilder.VARIANT_COLUMN_SHIFT
	chunk.set_cliff(Vector2i(4, 4), WorldChunk.Cliff.FACE)
	chunk.set_variant(Vector2i(4, 4), ChunkBuilder.ROW_BASE | (ChunkBuilder.FACE_END_RIGHT << shift))
	chunk.set_cliff(Vector2i(5, 4), WorldChunk.Cliff.STAIRS)
	chunk.set_variant(Vector2i(5, 4), ChunkBuilder.ROW_MIDDLE | (ChunkBuilder.COLUMN_RIGHT << shift))
	chunk.set_cliff(Vector2i(6, 4), WorldChunk.Cliff.WATERFALL)
	chunk.set_variant(Vector2i(6, 4), ChunkBuilder.ROW_LIP | (ChunkBuilder.COLUMN_MIDDLE << shift))
	chunk.set_cliff(Vector2i(7, 4), WorldChunk.Cliff.EDGE)
	chunk.set_variant(Vector2i(7, 4), ChunkBuilder.EDGE_N | ChunkBuilder.EDGE_W)
	chunk.set_level(Vector2i(7, 4), 3)
	var paint: Dictionary = WorldPainter.paint_sector(Vector2i.ZERO, {Vector2i.ZERO: chunk})
	var face: int = _code_at(paint, "ground", Vector2i(4, 4))
	assert_eq(WorldPainter.code_source(face), WorldPainter.Src.RELIEF)
	assert_eq(WorldPainter.code_atlas(face), Vector2i(ChunkBuilder.FACE_END_RIGHT, ChunkBuilder.ROW_BASE))
	assert_eq(WorldPainter.code_atlas(_code_at(paint, "ground", Vector2i(5, 4))), Vector2i(WorldPainter.STAIRS_COL + 2, 1))
	var fall: int = _code_at(paint, "ground", Vector2i(6, 4))
	assert_eq(WorldPainter.code_source(fall), WorldPainter.Src.WATERFALL)
	assert_eq(WorldPainter.code_atlas(fall), Vector2i(4, 0), "columna del medio, primer fotograma")
	var edge: int = _code_at(paint, "ground", Vector2i(7, 4))
	assert_eq(WorldPainter.code_source(edge), WorldPainter.Src.RELIEF_HIGH)
	assert_eq(WorldPainter.code_atlas(edge), Vector2i(9, WorldPainter.EDGE_ROW))


func test_paint_shadows_from_builder_decor() -> void:
	var chunk := _flat_chunk()
	chunk.set_decor(Vector2i(3, 3), ChunkBuilder.Decor.SHADOW_FOOT)
	chunk.set_decor(Vector2i(3, 5), ChunkBuilder.Decor.SHADOW_EAST)
	chunk.set_ground(Vector2i(3, 5), WorldChunk.Ground.PATH)
	var paint: Dictionary = WorldPainter.paint_sector(Vector2i.ZERO, {Vector2i.ZERO: chunk})
	var foot: int = _code_at(paint, "overlay", Vector2i(3, 3))
	assert_eq(WorldPainter.code_source(foot), WorldPainter.Src.SHADOWS)
	assert_eq(WorldPainter.code_atlas(foot).y, 0)
	assert_lt(WorldPainter.code_atlas(foot).x, 2, "sobre hierba: variante A o B")
	assert_eq(WorldPainter.code_atlas(_code_at(paint, "overlay", Vector2i(3, 5))), Vector2i(2, 1), "este, sobre sendero")


func test_paint_reads_neighbour_chunk_for_borders() -> void:
	var a := _flat_chunk(Vector2i.ZERO)
	var b := _flat_chunk(Vector2i(1, 0))
	a.set_ground(Vector2i(79, 10), WorldChunk.Ground.PATH)
	b.set_ground(Vector2i(0, 10), WorldChunk.Ground.PATH)
	var alone: Dictionary = WorldPainter.paint_sector(Vector2i(4, 0), {Vector2i.ZERO: a})
	var both: Dictionary = WorldPainter.paint_sector(Vector2i(4, 0), {Vector2i.ZERO: a, Vector2i(1, 0): b})
	var mask_alone: int = WorldPainter.code_atlas(_code_at(alone, "ground", Vector2i(15, 10))).x
	var mask_both: int = WorldPainter.code_atlas(_code_at(both, "ground", Vector2i(15, 10))).x
	assert_eq(mask_alone & WorldPainter.E, 0, "sin vecino se supone la misma casilla")
	assert_eq(mask_both & WorldPainter.E, 0, "el sendero sigue en el chunk de al lado")
	assert_eq(mask_both & WorldPainter.N, WorldPainter.N, "hierba al norte")


func test_sprite_origin_and_sign_columns() -> void:
	assert_eq(WorldPainter.object_base(Vector2i(10, 20), Vector2i(2, 2)), Vector2(10 * 16 + 16, 22 * 16))
	assert_eq(WorldPainter.object_base(Vector2i(0, 0), Vector2i(4, 3)), Vector2(32, 48))
	assert_eq(WorldPainter.sign_column(Vector2i.RIGHT), 0)
	assert_eq(WorldPainter.sign_column(Vector2i.DOWN), 2)
	assert_eq(WorldPainter.sign_column(Vector2i.LEFT), 4)
	assert_eq(WorldPainter.sign_column(Vector2i.UP), 6)
