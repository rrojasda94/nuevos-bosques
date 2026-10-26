extends GutTest
## WorldChunk (ADR 0014 §5): capas de 80×80, objetos de varias casillas con `occupant`, solape
## rechazado, rebuild_blocked con las máscaras y serialización a tipos simples byte a byte.

const G := WorldChunk.Ground
const C := WorldChunk.Cliff
const K := WorldChunk.ObjectKind


func test_capas_nacen_con_80x80() -> void:
	var chunk := WorldChunk.new()
	for layer: PackedByteArray in [chunk.ground, chunk.level, chunk.cliff, chunk.decor, chunk.blocked, chunk.variant]:
		assert_eq(layer.size(), 6400)
	assert_eq(chunk.occupant.size(), 6400)
	assert_eq(chunk.occupant[0], WorldChunk.NO_OBJECT)
	assert_eq(chunk.occupant[6399], WorldChunk.NO_OBJECT)
	assert_eq(chunk.get_ground(Vector2i(79, 79)), G.GRASS)
	assert_eq(WorldChunk.center(), Vector2i(40, 40))


func test_getters_y_setters_por_casilla() -> void:
	var chunk := WorldChunk.new()
	var cell := Vector2i(79, 3)
	chunk.set_ground(cell, G.ROCKY)
	chunk.set_level(cell, 2)
	chunk.set_cliff(cell, C.STAIRS)
	chunk.set_decor(cell, 7)
	chunk.set_variant(cell, 3)
	assert_eq(chunk.get_ground(cell), G.ROCKY)
	assert_eq(chunk.get_level(cell), 2)
	assert_eq(chunk.get_cliff(cell), C.STAIRS)
	assert_eq(chunk.get_decor(cell), 7)
	assert_eq(chunk.get_variant(cell), 3)
	assert_eq(chunk.ground[3 * 80 + 79], G.ROCKY, "fila a fila")
	chunk.set_level(cell, 9)
	assert_eq(chunk.get_level(cell), WorldChunk.MAX_LEVEL, "el nivel se recorta a 0..3")


func test_in_bounds_y_bordes() -> void:
	assert_true(WorldChunk.in_bounds(Vector2i(0, 0)))
	assert_true(WorldChunk.in_bounds(Vector2i(79, 79)))
	assert_false(WorldChunk.in_bounds(Vector2i(80, 0)))
	assert_false(WorldChunk.in_bounds(Vector2i(-1, 5)))
	assert_eq(WorldChunk.border_cell(Vector2i.RIGHT, 10), Vector2i(79, 10))
	assert_eq(WorldChunk.border_cell(Vector2i.DOWN, 10), Vector2i(10, 79))
	var chunk := WorldChunk.new()
	assert_true(chunk.is_blocked(Vector2i(80, 0)), "fuera del chunk se considera bloqueado")


func test_objeto_de_varias_casillas_rellena_occupant() -> void:
	var chunk := WorldChunk.new()
	var house: int = chunk.add_object(K.HOUSE, Vector2i(10, 20), Vector2i(4, 3), 2)
	assert_eq(house, 0)
	for y: int in range(20, 23):
		for x: int in range(10, 14):
			assert_eq(chunk.object_index_at(Vector2i(x, y)), house)
	assert_eq(chunk.object_index_at(Vector2i(14, 20)), WorldChunk.NO_OBJECT)
	assert_eq(chunk.object_index_at(Vector2i(10, 23)), WorldChunk.NO_OBJECT)
	var obj: Dictionary = chunk.object_at(Vector2i(13, 22))
	assert_eq(obj.kind, K.HOUSE)
	assert_eq(obj.cell, Vector2i(10, 20))
	assert_eq(obj.size, Vector2i(4, 3))
	assert_eq(obj.variant, 2)
	assert_eq(chunk.object_at(Vector2i(0, 0)), {})
	var tree: int = chunk.add_object(K.TREE, Vector2i(78, 78), Vector2i(2, 2))
	assert_eq(tree, 1, "un 2x2 cabe justo en la esquina")
	assert_eq(chunk.objects_of(K.TREE).size(), 1)


func test_solape_y_fuera_de_limites_se_rechazan_sin_cambiar_nada() -> void:
	var chunk := WorldChunk.new()
	chunk.add_object(K.TREE, Vector2i(5, 5), Vector2i(2, 2))
	var before: PackedInt32Array = chunk.occupant.duplicate()
	assert_eq(chunk.add_object(K.ROCK, Vector2i(6, 6), Vector2i(2, 2)), WorldChunk.NO_OBJECT, "solapa una casilla")
	assert_eq(chunk.add_object(K.ROCK, Vector2i(4, 4), Vector2i(3, 3)), WorldChunk.NO_OBJECT, "lo rodea")
	assert_eq(chunk.add_object(K.TREE, Vector2i(79, 0), Vector2i(2, 2)), WorldChunk.NO_OBJECT, "se sale")
	assert_eq(chunk.add_object(K.TREE, Vector2i(-1, 0)), WorldChunk.NO_OBJECT)
	assert_eq(chunk.add_object(K.TREE, Vector2i(1, 1), Vector2i(0, 1)), WorldChunk.NO_OBJECT, "tamaño vacío")
	assert_eq(chunk.objects.size(), 1)
	assert_eq(chunk.occupant, before)
	assert_eq(chunk.add_object(K.ROCK, Vector2i(7, 5), Vector2i(2, 2)), 1, "pegado sí cabe")


func test_rebuild_blocked_sale_de_suelo_riscos_y_objetos() -> void:
	var chunk := WorldChunk.new()
	chunk.set_ground(Vector2i(1, 0), G.RIVER_NARROW)
	chunk.set_ground(Vector2i(2, 0), G.LAKE)
	chunk.set_ground(Vector2i(3, 0), G.BRIDGE)
	chunk.set_ground(Vector2i(4, 0), G.FORD)
	chunk.set_cliff(Vector2i(0, 1), C.FACE)
	chunk.set_cliff(Vector2i(1, 1), C.EDGE)
	chunk.set_cliff(Vector2i(2, 1), C.WATERFALL)
	chunk.set_cliff(Vector2i(3, 1), C.STAIRS)
	chunk.set_cliff(Vector2i(4, 1), C.RAMP)
	chunk.add_object(K.TREE_BIG, Vector2i(10, 10), Vector2i(3, 3))
	chunk.add_object(K.REFUGE_TREE, Vector2i(20, 20), Vector2i(2, 2))
	chunk.set_decor(Vector2i(30, 30), 5)
	chunk.rebuild_blocked()

	assert_false(chunk.is_blocked(Vector2i(0, 0)), "hierba")
	assert_true(chunk.is_blocked(Vector2i(1, 0)), "río")
	assert_true(chunk.is_blocked(Vector2i(2, 0)), "lago")
	assert_false(chunk.is_blocked(Vector2i(3, 0)), "puente")
	assert_false(chunk.is_blocked(Vector2i(4, 0)), "vado")
	assert_true(chunk.is_blocked(Vector2i(0, 1)), "cara")
	assert_true(chunk.is_blocked(Vector2i(1, 1)), "borde")
	assert_true(chunk.is_blocked(Vector2i(2, 1)), "cascada")
	assert_false(chunk.is_blocked(Vector2i(3, 1)), "escalera")
	assert_false(chunk.is_blocked(Vector2i(4, 1)), "rampa")
	assert_true(chunk.is_blocked(Vector2i(12, 12)), "árbol grande, todas sus casillas")
	assert_false(chunk.is_blocked(Vector2i(13, 12)))
	assert_false(chunk.is_blocked(Vector2i(21, 21)), "el refugio no bloquea")
	assert_false(chunk.is_blocked(Vector2i(30, 30)), "la decoración no bloquea")
	var count: int = 0
	for b: int in chunk.blocked:
		count += b
	assert_eq(count, 2 + 3 + 9, "nada más bloquea")


func test_mascaras_coinciden_con_las_funciones() -> void:
	assert_true(WorldChunk.is_ground_blocking(G.SEA))
	assert_false(WorldChunk.is_ground_blocking(G.ROAD))
	assert_true(WorldChunk.is_cliff_blocking(C.FACE))
	assert_false(WorldChunk.is_cliff_blocking(C.NONE))
	assert_true(WorldChunk.is_object_blocking(K.SIGN))
	assert_false(WorldChunk.is_object_blocking(K.CAVE))


func test_letreros_son_objetos_con_datos() -> void:
	var chunk := WorldChunk.new()
	assert_true(chunk.add_sign(Vector2i(5, 6), WorldChunk.SignKind.HOME_VILLA, Vector2i.LEFT))
	assert_false(chunk.add_sign(Vector2i(5, 6), WorldChunk.SignKind.BOSQUE_VILLA), "casilla ocupada")
	assert_eq(chunk.object_at(Vector2i(5, 6)).kind, K.SIGN)
	assert_eq(chunk.sign_at(Vector2i(5, 6)).kind, WorldChunk.SignKind.HOME_VILLA)
	assert_eq(chunk.sign_at(Vector2i(5, 6)).direction, Vector2i.LEFT)
	assert_eq(chunk.sign_at(Vector2i(0, 0)), {})
	assert_eq(chunk.signs.size(), 1)


func test_accesibilidad_desde_el_hub() -> void:
	var chunk := WorldChunk.new()
	chunk.hub = Vector2i(2, 2)
	# Un muro de cara de risco en la columna 10 corta el chunk.
	for y: int in WorldChunk.SIZE:
		chunk.set_cliff(Vector2i(10, y), C.FACE)
	chunk.rebuild_blocked()
	assert_true(chunk.is_reachable(Vector2i(0, 79)))
	assert_false(chunk.is_reachable(Vector2i(10, 5)))
	assert_false(chunk.is_reachable(Vector2i(11, 5)))
	chunk.set_cliff(Vector2i(10, 40), C.STAIRS)
	chunk.rebuild_blocked()
	assert_true(chunk.is_reachable(Vector2i(79, 0)), "la escalera abre el paso")


func test_serializacion_ida_y_vuelta_byte_a_byte() -> void:
	var chunk := _sample_chunk()
	var bytes: PackedByteArray = var_to_bytes(chunk.to_dict())
	var back: WorldChunk = WorldChunk.from_dict(bytes_to_var(bytes))
	assert_not_null(back)
	assert_eq(var_to_bytes(back.to_dict()), bytes, "mismos bytes")
	assert_eq(back.occupant, chunk.occupant, "occupant se rehace desde los objetos")
	assert_eq(back.objects, chunk.objects)
	assert_eq(back.signs, chunk.signs)
	assert_eq(back.points, chunk.points)
	assert_eq(back.coord, Vector2i(-3, 7))
	assert_eq(back.nujio_rect, Rect2i(30, 30, 6, 6))
	assert_true(back.has_villa)
	assert_eq(back.hub, Vector2i(33, 40))
	assert_eq(back.blocked, chunk.blocked)


func test_serializacion_es_determinista_y_sin_objetos() -> void:
	var a: PackedByteArray = var_to_bytes(_sample_chunk().to_dict())
	var b: PackedByteArray = var_to_bytes(_sample_chunk().to_dict())
	assert_eq(a, b)
	# Sin objetos de Godot: se puede leer sin permitir objetos.
	assert_not_null(bytes_to_var(a))


func test_from_dict_rechaza_formatos_rotos() -> void:
	var data: Dictionary = _sample_chunk().to_dict()
	var wrong_version: Dictionary = data.duplicate()
	wrong_version.format = WorldChunk.FORMAT_VERSION + 1
	assert_null(WorldChunk.from_dict(wrong_version))
	var short_layer: Dictionary = data.duplicate()
	short_layer.ground = PackedByteArray([1, 2, 3])
	assert_null(WorldChunk.from_dict(short_layer))
	var overlap: Dictionary = data.duplicate()
	var objs: PackedInt32Array = overlap.objects
	objs.append_array(PackedInt32Array([K.ROCK, 10, 10, 1, 1, 0]))
	overlap.objects = objs
	assert_null(WorldChunk.from_dict(overlap), "objetos que se solapan")
	assert_null(WorldChunk.from_dict({}))


func _sample_chunk() -> WorldChunk:
	var chunk := WorldChunk.new()
	chunk.seed_value = 42
	chunk.coord = Vector2i(-3, 7)
	chunk.hub = Vector2i(33, 40)
	chunk.nujio_rect = Rect2i(30, 30, 6, 6)
	chunk.points.append({"kind": WorldChunk.PointKind.POND, "rect": Rect2i(8, 12, 16, 12), "cell": Vector2i(17, 21)})
	chunk.has_villa = true
	for i: int in WorldChunk.CELLS:
		chunk.ground[i] = i % 5
		chunk.level[i] = (i / 320) % 4
		chunk.variant[i] = (i * 7) % 4
		chunk.decor[i] = (i * 13) % 17
	chunk.set_cliff(Vector2i(0, 4), C.FACE)
	chunk.set_cliff(Vector2i(1, 4), C.STAIRS)
	chunk.add_object(K.TREE, Vector2i(10, 10), Vector2i(2, 2), 3)
	chunk.add_object(K.HOUSE, Vector2i(40, 50), Vector2i(4, 3), 1)
	chunk.add_object(K.NUJIO, Vector2i(30, 30), Vector2i(6, 6))
	chunk.add_sign(Vector2i(70, 2), WorldChunk.SignKind.BOSQUE_VILLA, Vector2i.UP)
	chunk.rebuild_blocked()
	return chunk
