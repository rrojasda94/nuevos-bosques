extends GutTest
## Interacción con E (navegacion.md, mision-ofomni.md): sondeo delante de los pies (Mundo 2.0),
## NPC del sfida (colocación determinista, bloquea el paso, diálogo) y lectura de letreros y
## refugios.

const WORLD_SCENE: String = "res://scenes/world/world_exploration.tscn"


func test_sfida_does_not_cut_the_villa() -> void:
	for s: int in [42, 7]:
		var plan := RegionPlan.for_region(s, &"valle_del_sara")
		var chunk: WorldChunk = ChunkBuilder.build(plan, plan.home_chunk)
		var at: Vector2i = Npc.sfida_cell_world(chunk)
		assert_true(at.x >= 0, "seed %d: hay sitio" % s)
		var before: PackedByteArray = chunk.reachable_from_hub().duplicate()
		chunk.blocked[WorldCoords.cell_index(at)] = 1
		chunk.add_object(WorldChunk.ObjectKind.ROCK, at)
		var after: PackedByteArray = chunk.reachable_from_hub()
		var lost: int = 0
		for i: int in before.size():
			if before[i] == 1 and after[i] == 0 and i != WorldCoords.cell_index(at):
				lost += 1
		assert_eq(lost, 0, "seed %d: bloquear al sfida no deja casillas aisladas" % s)


func test_npc_blocks_walking_in_exploration() -> void:
	WorldClock.set_process(false)
	GameState.new_game(42)
	var expl: WorldExploration = load(WORLD_SCENE).instantiate()
	add_child_autoqfree(expl)
	await expl.start()
	var npcs: Dictionary = expl.get("_npcs")
	assert_eq(npcs.size(), 1, "el sfida está en la villa natal")
	assert_true(npcs.has(&"sfida_natal"))
	var at: Vector2i = WorldCoords.world_pos_to_world_cell(npcs[&"sfida_natal"])
	assert_true(expl.player.is_blocked.call(at), "no se puede pisar al sfida")
	assert_false(expl.player.is_blocked.call(at + Vector2i.LEFT), "la plaza de al lado sí")
	assert_ne(expl.player.mover.cell, at)
	WorldClock.set_process(true)


func test_sfida_lines_greeting_then_rotating_ambient() -> void:
	# Sin misiones (con la misión ofrecida habla de ella: test_quest_logic).
	GameState.quests = {}
	NpcDialogue.reset_talks()
	var first: Array[Dictionary] = NpcDialogue.lines_for(&"sfida_natal")
	assert_eq(first.size(), 2)
	assert_eq(first[0], { "speaker": "Sfida", "text": "Brille tu Luz, adoc." })
	var second: Array[Dictionary] = NpcDialogue.lines_for(&"sfida_natal")
	assert_eq(second[0].text, first[0].text, "siempre saluda")
	assert_ne(second[1].text, first[1].text, "la frase de ambiente cambia")
	assert_eq(NpcDialogue.display_name(&"sfida_natal"), "Sfida")
	NpcDialogue.reset_talks()


func test_texts_loader_and_sprite() -> void:
	assert_eq(Texts.get_text("refuge_empty"), "Un refugio. Aquí pasarás el riutash.")
	assert_true(Texts.has_text("signpost_villa_natal"))
	assert_false(Texts.has_text("no_existe"))
	var img: Image = Npc.make_texture(Npc.SFIDA_COLORS, Vector2i.DOWN).get_image()
	assert_eq(img.get_size(), Vector2i(16, 16))
	assert_eq(img.get_pixel(7, 10).to_html(false), Npc.SFIDA_COLORS.trim.to_html(false))


# --- Mundo 2.0 (ADR 0014 §2): sondeo, objetos de varias casillas, NPC por distancia ------------

const K := WorldChunk.ObjectKind


## Chunk de hierba del Mundo 2.0 con un frutal 2×2, un letrero, un árbol hueco, una cueva (con la
## fila de arriba en la cara del risco), un Nujio y un árbol normal.
func _world_chunk(coord: Vector2i = Vector2i.ZERO) -> WorldChunk:
	var chunk := WorldChunk.new()
	chunk.coord = coord
	chunk.add_object(K.FRUIT_TREE, Vector2i(20, 20), Vector2i(2, 2))
	chunk.add_sign(Vector2i(10, 9), WorldChunk.SignKind.HOME_VILLA, Vector2i.LEFT)
	chunk.add_object(K.REFUGE_TREE, Vector2i(30, 30), Vector2i(2, 2))
	chunk.add_object(K.CAVE, Vector2i(40, 40), Vector2i(2, 2))
	chunk.set_cliff(Vector2i(40, 40), WorldChunk.Cliff.FACE)
	chunk.set_cliff(Vector2i(41, 40), WorldChunk.Cliff.FACE)
	chunk.add_object(K.TREE, Vector2i(50, 50), Vector2i(2, 2))
	chunk.nujio_rect = Rect2i(60, 60, 4, 3)
	chunk.add_object(K.NUJIO, chunk.nujio_rect.position, chunk.nujio_rect.size)
	chunk.rebuild_blocked()
	return chunk


func _getter(chunks: Dictionary) -> Callable:
	return func(c: Vector2i) -> WorldChunk: return chunks.get(c)


## Pies en el centro de la casilla global.
func _at(world_cell: Vector2i) -> Vector2:
	return WorldCoords.world_cell_to_world_pos(world_cell)


func test_probe_is_feet_plus_facing_times_12() -> void:
	assert_eq(Interaction.probe_px(), 12.0, "en data/world/movement.json")
	assert_eq(Interaction.npc_reach_px(), 14.0)
	assert_eq(Interaction.probe_point(Vector2(168, 168), Vector2i.RIGHT), Vector2(180, 168))
	var cells: Array[Vector2i] = Interaction.probe_cells(Vector2(168, 168), Vector2i.RIGHT)
	assert_eq(cells.size(), 9, "sondeo, pies y las otras 7 vecinas del sondeo")
	assert_eq(cells[0], Vector2i(11, 10), "primero la casilla del sondeo")
	assert_eq(cells[1], Vector2i(10, 10), "después la de los pies")
	assert_eq(cells.slice(2, 4), [Vector2i(11, 9), Vector2i(11, 11)], "después las más cercanas al sondeo")
	var near: Array[Vector2i] = Interaction.probe_cells(Vector2(168, 161), Vector2i.DOWN)
	assert_eq(near[0], Vector2i(10, 10), "el sondeo puede caer en la casilla de los pies")
	assert_eq(near.size(), 9, "sin repetir los pies: el sondeo y sus 8 vecinas")
	assert_false(near.slice(1).has(near[0]))


func test_fruit_tree_2x2_from_any_neighbour_cell() -> void:
	var get_chunk := _getter({ Vector2i.ZERO: _world_chunk() })
	var cases: Array = [
		[Vector2i(19, 21), Vector2i.RIGHT], [Vector2i(22, 20), Vector2i.LEFT],
		[Vector2i(21, 19), Vector2i.DOWN], [Vector2i(20, 22), Vector2i.UP],
		[Vector2i(19, 19), Vector2i.RIGHT], [Vector2i(22, 22), Vector2i.UP],
	]
	for c: Array in cases:
		var t: Dictionary = Interaction.find_world(get_chunk, _at(c[0]), c[1])
		assert_eq(t.kind, Interaction.Kind.FRUIT_TREE, "desde %s mirando %s" % [c[0], c[1]])
		assert_eq(t.cell, Vector2i(20, 20), "la esquina noroeste")
		assert_eq(t.local, Vector2i(20, 20))
		assert_eq(t.chunk, Vector2i.ZERO)
	# A dos casillas no: el sondeo ve el árbol en sus 8 vecinas, pero los pies no están al lado.
	var far := Vector2(300, 20 * 16 + 8)
	assert_eq(Interaction.probe_cells(far, Vector2i.RIGHT)[0], Vector2i(19, 20))
	assert_eq(Interaction.find_world(get_chunk, far, Vector2i.RIGHT).kind, Interaction.Kind.NONE)


func test_sign_ahead_and_not_from_behind() -> void:
	var get_chunk := _getter({ Vector2i.ZERO: _world_chunk() })
	var t: Dictionary = Interaction.find_world(get_chunk, _at(Vector2i(10, 10)), Vector2i.UP)
	assert_eq(t.kind, Interaction.Kind.SIGN)
	assert_eq(t.cell, Vector2i(10, 9))
	assert_eq(Interaction.find_world(get_chunk, _at(Vector2i(10, 10)), Vector2i.DOWN).kind, Interaction.Kind.NONE,
		"de espaldas al letrero no se lee")
	assert_eq(Interaction.find_world(get_chunk, _at(Vector2i(10, 10)), Vector2i.LEFT).kind, Interaction.Kind.SIGN,
		"de lado, el letrero está en las vecinas del sondeo")


func test_refuge_tree_and_cave_are_objects() -> void:
	var chunk := _world_chunk()
	var get_chunk := _getter({ Vector2i.ZERO: chunk })
	var inside: Dictionary = Interaction.find_world(get_chunk, _at(Vector2i(30, 31)), Vector2i.RIGHT)
	assert_eq(inside.kind, Interaction.Kind.REFUGE, "dentro del árbol hueco")
	assert_eq(inside.cell, Vector2i(30, 30))
	assert_eq(Interaction.find_world(get_chunk, _at(Vector2i(29, 30)), Vector2i.RIGHT).kind, Interaction.Kind.REFUGE,
		"desde fuera, mirándolo")
	var cave: Dictionary = Interaction.find_world(get_chunk, _at(Vector2i(41, 41)), Vector2i.UP)
	assert_eq(cave.kind, Interaction.Kind.REFUGE, "en la boca de la cueva")
	assert_eq(cave.cell, Vector2i(40, 40))
	for c: Vector2i in [Vector2i(30, 30), Vector2i(31, 31), Vector2i(40, 41), Vector2i(41, 41)]:
		assert_true(AdventureRules.is_refuge_world(chunk, c), "%s es refugio" % c)
		assert_true(AdventureRules.is_riutash_shelter_world(chunk, c))
	assert_false(AdventureRules.is_refuge_world(chunk, Vector2i(40, 40)), "la cara de la cueva no se pisa")
	assert_false(AdventureRules.is_refuge_world(chunk, Vector2i(29, 30)))
	assert_false(AdventureRules.is_riutash_shelter_world(chunk, Vector2i(29, 30)))
	assert_false(AdventureRules.is_refuge_world(chunk, Vector2i(50, 50)), "un árbol normal no")


func test_plain_tree_is_skipped_and_nujio_found() -> void:
	var get_chunk := _getter({ Vector2i.ZERO: _world_chunk() })
	assert_eq(Interaction.find_world(get_chunk, _at(Vector2i(49, 50)), Vector2i.RIGHT).kind, Interaction.Kind.NONE)
	var t: Dictionary = Interaction.find_world(get_chunk, _at(Vector2i(62, 63)), Vector2i.UP)
	assert_eq(t.kind, Interaction.Kind.NUJIO, "el Nujio desde cualquiera de sus casillas")
	assert_eq(t.cell, Vector2i(60, 60))


func test_villa_rest_on_the_plaza() -> void:
	var chunk := _world_chunk()
	chunk.has_villa = true
	chunk.set_ground(Vector2i(5, 5), WorldChunk.Ground.PLAZA)
	var get_chunk := _getter({ Vector2i.ZERO: chunk })
	var t: Dictionary = Interaction.find_world(get_chunk, _at(Vector2i(5, 5)), Vector2i.DOWN)
	assert_eq(t.kind, Interaction.Kind.REST)
	assert_eq(t.cell, Vector2i(5, 5))
	assert_true(AdventureRules.is_villa_rest_world(chunk, Vector2i(64, 61)), "junto al Nujio de la villa")
	assert_true(AdventureRules.is_riutash_shelter_world(chunk, Vector2i(5, 5)), "la plaza es refugio")
	assert_eq(Interaction.find_world(get_chunk, _at(Vector2i(61, 63)), Vector2i.UP).kind, Interaction.Kind.NUJIO,
		"el Nujio antes que el descanso")
	chunk.has_villa = false
	assert_eq(Interaction.find_world(get_chunk, _at(Vector2i(5, 5)), Vector2i.DOWN).kind, Interaction.Kind.NONE,
		"sin villa no se descansa")


func test_objects_across_the_chunk_border() -> void:
	var east := WorldChunk.new()
	east.coord = Vector2i(1, 0)
	east.add_sign(Vector2i(0, 5), WorldChunk.SignKind.BOSQUE_VILLA, Vector2i.RIGHT)
	east.rebuild_blocked()
	var get_chunk := _getter({ Vector2i.ZERO: _world_chunk(), Vector2i(1, 0): east })
	var t: Dictionary = Interaction.find_world(get_chunk, _at(Vector2i(79, 5)), Vector2i.RIGHT)
	assert_eq(t.kind, Interaction.Kind.SIGN)
	assert_eq(t.cell, Vector2i(80, 5))
	assert_eq(t.chunk, Vector2i(1, 0))
	assert_eq(t.local, Vector2i(0, 5))
	var only_west := _getter({ Vector2i.ZERO: _world_chunk() })
	assert_eq(Interaction.find_world(only_west, _at(Vector2i(79, 5)), Vector2i.RIGHT).kind, Interaction.Kind.NONE,
		"un chunk sin cargar no da nada")


func test_npc_by_distance_and_half_plane() -> void:
	var get_chunk := _getter({ Vector2i.ZERO: _world_chunk() })
	var feet := Vector2(168, 168)
	assert_eq(Interaction.npc_in_reach(feet, Vector2i.RIGHT, { &"sfida": Vector2(184, 168) }), &"sfida", "a 4 px")
	assert_eq(Interaction.npc_in_reach(feet, Vector2i.RIGHT, { &"sfida": Vector2(194, 168) }), &"sfida", "a 14 px")
	assert_eq(Interaction.npc_in_reach(feet, Vector2i.RIGHT, { &"sfida": Vector2(195, 168) }), &"", "a 15 px no")
	assert_eq(Interaction.npc_in_reach(feet, Vector2i.RIGHT, { &"sfida": Vector2(168, 170) }), &"",
		"a 12 px del sondeo pero no delante de los pies")
	assert_eq(Interaction.npc_in_reach(feet, Vector2i.LEFT, { &"sfida": Vector2(184, 168) }), &"", "de espaldas")
	assert_eq(Interaction.npc_in_reach(feet, Vector2i.RIGHT, { &"lejos": Vector2(190, 170), &"cerca": Vector2(183, 166) }),
		&"cerca", "el más cercano al sondeo")
	# El NPC va antes que el letrero de delante.
	var t: Dictionary = Interaction.find_world(get_chunk, _at(Vector2i(10, 10)), Vector2i.UP,
		{ &"sfida_natal": _at(Vector2i(10, 9)) + Vector2(3, 0) })
	assert_eq(t.kind, Interaction.Kind.NPC)
	assert_eq(t.npc_id, &"sfida_natal")
	assert_eq(t.cell, Vector2i(10, 9))


func test_sfida_and_spawn_in_the_world_villa() -> void:
	for s: int in [42, 7]:
		var plan := RegionPlan.for_region(s, &"valle_del_sara")
		var chunk: WorldChunk = ChunkBuilder.build(plan, plan.home_chunk)
		assert_true(chunk.has_villa, "seed %d: el chunk natal tiene villa" % s)
		var spawn: Vector2i = Npc.villa_spawn_cell_world(chunk)
		assert_true(chunk.is_walkable(spawn) and chunk.is_reachable(spawn), "seed %d: se aparece en el suelo" % s)
		assert_true(AdventureRules.is_next_to_nujio_world(chunk, spawn), "seed %d: junto al Nujio" % s)
		assert_true(AdventureRules.is_villa_rest_world(chunk, spawn), "seed %d: se descansa al aparecer" % s)
		var at: Vector2i = Npc.sfida_cell_world(chunk)
		assert_true(at.x >= 0, "seed %d: hay sitio para el sfida" % s)
		assert_eq(Npc.sfida_cell_world(ChunkBuilder.build(plan, plan.home_chunk)), at, "seed %d: determinista" % s)
		assert_eq(chunk.get_ground(at), WorldChunk.Ground.PLAZA, "seed %d: en la plaza" % s)
		assert_true(chunk.is_reachable(at), "seed %d: alcanzable" % s)
		assert_ne(at, chunk.hub)
		assert_ne(at, spawn)
		# Se le habla desde la casilla de al lado, mirándolo.
		var get_chunk := _getter({ plan.home_chunk: chunk })
		var sfida_cell: Vector2i = WorldCoords.to_world_cell(plan.home_chunk, at)
		var t: Dictionary = Interaction.find_world(get_chunk, _at(sfida_cell + Vector2i.LEFT), Vector2i.RIGHT,
			{ &"sfida_natal": _at(sfida_cell) })
		assert_eq(t.kind, Interaction.Kind.NPC, "seed %d: se habla con el sfida" % s)
	assert_eq(Npc.sfida_cell_world(_world_chunk()), Vector2i(-1, -1), "sin villa no hay sfida")


func test_npc_setup_world_puts_feet_at_the_cell_center() -> void:
	var npc := Npc.new()
	add_child_autofree(npc)
	npc.setup_world(&"sfida_natal", Vector2i(85, 3))
	assert_eq(npc.world_pos, Vector2(85 * 16 + 8, 3 * 16 + 8))
	assert_eq(npc.position, npc.world_pos, "el nodo está en los pies (orden en Y)")
	assert_eq(npc.world_cell, Vector2i(85, 3))
