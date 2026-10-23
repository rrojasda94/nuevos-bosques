extends GutTest
## Narración del combate (v1.1, estilo Pokémon) y placeholder de los Únicos como monstruos.

const Battle = preload("res://scripts/rpg/battle.gd")
const BALANCE: Dictionary = {
	"adoc": { "max_hp": 30, "atk": 6, "def": 3, "start_luz": 10, "luz_max": 10 },
	"attack": { "roll_min": -1, "roll_max": 2, "min_damage": 1 },
	"defend_factor": 0.5,
	"offer_luz": { "cost": 2, "damage": 8 },
	"flee_chance": 0.75,
	"victory_luz": 1,
}
const UNICO: Dictionary = { "name": "Único serpiente", "max_hp": 22, "atk": 5, "def": 1 }


func _logic(luz: int = 10, unico: Dictionary = UNICO, rng_seed: int = 7) -> BattleLogic:
	return BattleLogic.new(BALANCE, 30, luz, unico, rng_seed)


func test_one_message_per_action_in_order_with_bar_state() -> void:
	var logic := _logic()
	var events: Array[Dictionary] = logic.play_turn(BattleLogic.Action.ATTACK)
	var msgs: Array[Dictionary] = Battle.messages_for(events, BALANCE)
	assert_eq(msgs.size(), 2)
	var dealt: int = events[0].amount
	var taken: int = events[1].amount
	assert_eq(msgs[0].text, "Atacas: %d de daño." % dealt)
	assert_eq(msgs[1].text, "El Único te golpea: %d de daño." % taken)
	assert_eq(msgs[0].unico_hp, 22 - dealt, "la barra del Único baja con el primer mensaje")
	assert_eq(msgs[0].adoc_hp, 30, "la del Adoc todavía no")
	assert_eq(msgs[1].adoc_hp, 30 - taken, "la del Adoc baja con el segundo")


func test_defend_and_flee_fail_sequences() -> void:
	var defend: Array[Dictionary] = Battle.messages_for(_logic().play_turn(BattleLogic.Action.DEFEND), BALANCE)
	assert_eq(defend[0].text, "Te pones en guardia.")
	assert_string_starts_with(defend[1].text, "El Único te golpea")
	for s in 50:
		var logic := _logic(10, UNICO, s)
		var msgs: Array[Dictionary] = Battle.messages_for(logic.play_turn(BattleLogic.Action.FLEE), BALANCE)
		if logic.result == BattleLogic.Result.FLED:
			assert_eq(msgs.size(), 1)
			assert_eq(msgs[0].text, "Huyes a tu lado del Bosque.")
		else:
			assert_eq(msgs.size(), 2)
			assert_eq(msgs[0].text, "No logras huir.")


func test_victory_messages_and_luz_cap() -> void:
	var weak: Dictionary = UNICO.duplicate()
	weak.max_hp = 8
	var logic := _logic(4, weak)
	var msgs: Array[Dictionary] = Battle.messages_for(logic.play_turn(BattleLogic.Action.OFFER_LUZ), BALANCE)
	assert_eq(msgs.size(), 2, "no hay mensaje de ataque del Único tras vencer")
	assert_eq(msgs[0].text, "Ofreces Luz: 8 de daño.")
	assert_eq(msgs[0].unico_hp, 0)
	assert_eq(msgs[1].text, "El Único vuelve a la Luz del Bosque. (+1 Luz)")
	assert_eq(msgs[1].luz, 3)
	var capped := BattleLogic.new(BALANCE, 30, 10, weak, 7)
	capped.luz = 12  # Luz al tope tras pagar 2: simulado para comprobar el texto.
	var at_cap: Array[Dictionary] = Battle.messages_for(capped.play_turn(BattleLogic.Action.OFFER_LUZ), BALANCE)
	assert_eq(at_cap[1].text, "El Único vuelve a la Luz del Bosque.", "al tope no se anuncia +1")
	assert_eq(at_cap[1].luz, 10)


func test_defeat_message_is_last() -> void:
	var brute: Dictionary = UNICO.duplicate()
	brute.atk = 99
	var msgs: Array[Dictionary] = Battle.messages_for(_logic(10, brute).play_turn(BattleLogic.Action.ATTACK), BALANCE)
	assert_eq(msgs.size(), 3)
	assert_eq(msgs[2].text, "Caes. Despertarás junto al Nujio de tu villa.")
	assert_eq(msgs[1].adoc_hp, 0)


func test_unico_kind_is_deterministic_per_bosque() -> void:
	for s in [1, 42, 777]:
		for id in 30:
			assert_eq(UnicoArt.kind_for(s, id), UnicoArt.kind_for(s, id))
	var differs := false
	for id in 30:
		if UnicoArt.kind_for(1, id) != UnicoArt.kind_for(2, id):
			differs = true
	assert_true(differs, "depende de la seed")
	assert_eq(UnicoArt.display_name(UnicoArt.Kind.SERPENT), "Único serpiente")


func test_unico_kind_does_not_follow_tree_shape() -> void:
	var region := ChunkGenerator.load_region(&"valle_del_sara")
	var kinds_by_shape := {}
	var all_kinds := {}
	for s in range(1, 61):
		var map := BosqueMap.for_region(s, region)
		for id in map.count():
			var shape: int = map.styles[id].shape
			var kind: int = UnicoArt.kind_for(s, id)
			if not kinds_by_shape.has(shape):
				kinds_by_shape[shape] = {}
			kinds_by_shape[shape][kind] = true
			all_kinds[kind] = true
	assert_eq(all_kinds.size(), UnicoArt.Kind.size(), "aparecen todos los tipos de monstruo")
	for shape in kinds_by_shape:
		assert_eq(kinds_by_shape[shape].size(), UnicoArt.Kind.size(), "árbol %d: todos los monstruos posibles" % shape)


func test_unico_texture_uses_bosque_colors_and_aura() -> void:
	var style := { "shape": 0, "leaf": 4, "trunk": 3, "ground": 0 }
	for kind in UnicoArt.Kind.size():
		var img: Image = UnicoArt.texture(kind, style, 96).get_image()
		var seen := {}
		for y in 96:
			for x in 96:
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					seen[c.to_html(false)] = true
		var leaf: Array = PlaceholderTileset.LEAVES[4]
		assert_true(seen.has(leaf[0].to_html(false)), "tipo %d: hoja oscura del Bosque" % kind)
		assert_true(seen.has(PlaceholderTileset.TRUNKS[3].to_html(false)), "tipo %d: color del tronco" % kind)
		assert_true(seen.has(UnicoArt.AURA.to_html(false)), "tipo %d: aura" % kind)
		assert_true(seen.has(PlaceholderTileset.WHITE.to_html(false)), "tipo %d: ojos" % kind)
