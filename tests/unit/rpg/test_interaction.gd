extends GutTest
## Interacción con E (navegacion.md, mision-ofomni.md): objetivo según facing, NPC del sfida
## (colocación determinista, bloquea el paso, diálogo) y lectura de letreros y refugios.

const SEEDS: Array[int] = [1, 42, 777, 123456789]
const EXPLORATION_SCENE: PackedScene = preload("res://scenes/world/exploration.tscn")

var _region: Dictionary


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"valle_del_sara")


func _villa_chunk(seed_value: int) -> ChunkData:
	var map := BosqueMap.for_region(seed_value, _region)
	var home: int = AdventureRules.home_bosque(map, _region)
	return ChunkGenerator.generate(seed_value, map.nujio_chunk[home], _region, map)


## Chunk de hierba de prueba con un letrero y un refugio.
func _flat_chunk() -> ChunkData:
	var chunk := ChunkData.new()
	chunk.tiles.resize(ChunkData.SIZE * ChunkData.SIZE)
	chunk.tiles.fill(ChunkData.Tile.GRASS)
	chunk.set_tile(Vector2i(10, 9), ChunkData.Tile.SIGN)
	chunk.set_tile(Vector2i(20, 20), ChunkData.Tile.REFUGE)
	return chunk


func test_target_is_cell_plus_facing() -> void:
	var c := Vector2i(10, 10)
	assert_eq(Interaction.target_cell(c, Vector2i.UP), Vector2i(10, 9))
	assert_eq(Interaction.target_cell(c, Vector2i.DOWN), Vector2i(10, 11))
	assert_eq(Interaction.target_cell(c, Vector2i.LEFT), Vector2i(9, 10))
	assert_eq(Interaction.target_cell(c, Vector2i.RIGHT), Vector2i(11, 10))


func test_find_sign_ahead_and_refuge_underfoot() -> void:
	var chunk := _flat_chunk()
	var ahead: Dictionary = Interaction.find(chunk, Vector2i(10, 10), Vector2i.UP, {})
	assert_eq(ahead.kind, Interaction.Kind.SIGN)
	assert_eq(ahead.cell, Vector2i(10, 9))
	assert_eq(Interaction.find(chunk, Vector2i(10, 10), Vector2i.DOWN, {}).kind, Interaction.Kind.NONE,
		"de espaldas al letrero no se lee")
	assert_eq(Interaction.find(chunk, Vector2i(10, 9), Vector2i.LEFT, {}).kind, Interaction.Kind.SIGN,
		"de pie sobre el letrero")
	assert_eq(Interaction.find(chunk, Vector2i(20, 20), Vector2i.RIGHT, {}).kind, Interaction.Kind.REFUGE)
	assert_eq(Interaction.find(chunk, Vector2i(19, 20), Vector2i.RIGHT, {}).kind, Interaction.Kind.REFUGE)


func test_find_npc_has_priority_and_stays_in_bounds() -> void:
	var chunk := _flat_chunk()
	var npcs := { Vector2i(10, 9): &"sfida_natal" }
	var t: Dictionary = Interaction.find(chunk, Vector2i(10, 10), Vector2i.UP, npcs)
	assert_eq(t.kind, Interaction.Kind.NPC)
	assert_eq(t.npc_id, &"sfida_natal")
	assert_eq(Interaction.find(chunk, Vector2i(0, 0), Vector2i.LEFT, {}).kind, Interaction.Kind.NONE)


func test_sfida_cell_is_deterministic_reachable_plaza() -> void:
	for s: int in SEEDS:
		var chunk := _villa_chunk(s)
		var at: Vector2i = Npc.sfida_cell(chunk)
		assert_true(at.x >= 0, "seed %d: hay sitio" % s)
		assert_eq(Npc.sfida_cell(_villa_chunk(s)), at, "seed %d: determinista" % s)
		assert_eq(chunk.get_tile(at), ChunkData.Tile.PLAZA, "seed %d: en la plaza" % s)
		assert_true(chunk.is_reachable(at), "seed %d: alcanzable desde el hub" % s)
		assert_ne(at, chunk.hub, "seed %d: no es el hub" % s)
		assert_ne(at, Npc.villa_spawn_cell(chunk), "seed %d: no es donde aparece el Adoc" % s)
		assert_true(AdventureRules.is_next_to_nujio(chunk, at) or chunk.nujio_rect.grow(4).has_point(at),
			"seed %d: cerca del Nujio" % s)


func test_sfida_does_not_cut_the_villa() -> void:
	for s: int in SEEDS:
		var chunk := _villa_chunk(s)
		var at: Vector2i = Npc.sfida_cell(chunk)
		var before: PackedByteArray = chunk.reachable_from_hub().duplicate()
		var blocked := chunk.duplicate() as ChunkData
		blocked.tiles = chunk.tiles.duplicate()
		blocked.set_tile(at, ChunkData.Tile.BUILDING)
		var after: PackedByteArray = blocked.reachable_from_hub()
		var lost: int = 0
		for i: int in before.size():
			if before[i] == 1 and after[i] == 0 and i != at.y * ChunkData.SIZE + at.x:
				lost += 1
		assert_eq(lost, 0, "seed %d: bloquear al sfida no deja casillas aisladas" % s)
	assert_eq(Npc.sfida_cell(_flat_chunk()), Vector2i(-1, -1), "sin villa no hay sfida")


func test_npc_blocks_walking_in_exploration() -> void:
	GameState.new_game(42)
	var exploration: Node2D = EXPLORATION_SCENE.instantiate()
	add_child_autofree(exploration)
	exploration.start()
	var player: PlayerWalker = exploration.get_node("Player")
	var npcs: Dictionary = exploration.get("_npcs")
	assert_eq(npcs.size(), 1, "el sfida está en la villa natal")
	var at: Vector2i = npcs.keys()[0]
	assert_eq(npcs[at], &"sfida_natal")
	assert_false(player.is_walkable.call(at), "no se puede pisar al sfida")
	assert_true(player.is_walkable.call(at + Vector2i.LEFT), "la plaza de al lado sí")
	assert_ne(player.cell, at)


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
