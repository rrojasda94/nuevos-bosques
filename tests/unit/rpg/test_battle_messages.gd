extends GutTest
## Narración del combate (v1.1, estilo Pokémon) y placeholder de los Únicos como monstruos.

const Battle = preload("res://scripts/rpg/battle.gd")
const BALANCE: Dictionary = {
	"adoc": { "max_hp": 30, "atk": 6, "def": 3, "start_luz": 10, "luz_max": 10 },
	"attack": { "roll_min": -1, "roll_max": 2, "min_damage": 1 },
	"defend_factor": 0.5,
	"flee_chance": 0.75,
	"victory_luz": 1,
}
const UNICO: Dictionary = { "name": "Único serpiente", "max_hp": 22, "atk": 5, "def": 1 }


func _logic(luz: int = 10, unico: Dictionary = UNICO, rng_seed: int = 7) -> BattleLogic:
	return BattleLogic.new(BALANCE, BALANCE.adoc, 30, luz, unico, rng_seed)


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
	weak.max_hp = 1
	var logic := _logic(3, weak)
	var events: Array[Dictionary] = logic.play_turn(BattleLogic.Action.ATTACK)
	var msgs: Array[Dictionary] = Battle.messages_for(events, BALANCE)
	assert_eq(msgs.size(), 2, "no hay mensaje de ataque del Único tras vencer")
	assert_eq(msgs[0].text, "Atacas: %d de daño." % events[0].amount)
	assert_eq(msgs[0].unico_hp, 0)
	assert_eq(msgs[1].text, "El Único vuelve a la Luz del Bosque. (+1 Luz)")
	assert_eq(msgs[1].luz, 4)
	var capped := BattleLogic.new(BALANCE, BALANCE.adoc, 30, 10, weak, 7)
	var at_cap: Array[Dictionary] = Battle.messages_for(capped.play_turn(BattleLogic.Action.ATTACK), BALANCE)
	assert_eq(at_cap[1].text, "El Único vuelve a la Luz del Bosque.", "al tope no se anuncia +1")
	assert_eq(at_cap[1].luz, 10)


func test_defeat_message_is_last() -> void:
	var brute: Dictionary = UNICO.duplicate()
	brute.atk = 99
	var msgs: Array[Dictionary] = Battle.messages_for(_logic(10, brute).play_turn(BattleLogic.Action.ATTACK), BALANCE)
	assert_eq(msgs.size(), 3)
	assert_eq(msgs[2].text, "Caes. Despertarás junto a un Nujio.")
	assert_eq(msgs[1].adoc_hp, 0)


func test_border_guardians_are_always_botarramas() -> void:
	GameState.new_game(42)
	var logic: BattleLogic = AdventureRules.start_battle(3, 2)
	assert_eq(logic.unico_name, "Botarramas", "los bordes ya no usan Aledra ni Ofomni")
	assert_eq(logic.special_every, 0, "sin ataque especial")


func test_whip_texts_for_ofomni() -> void:
	var unico: Dictionary = UNICO.duplicate()
	unico.texts = AdventureRules.monster_config(&"ofomni").texts
	var texts: Dictionary = Battle.texts_for(_logic(10, unico))
	var events: Array[Dictionary] = [
		{ "kind": &"unico_attack", "amount": 4, "unico_hp": 22, "adoc_hp": 26, "luz": 10 },
		{ "kind": &"special_warning", "amount": 0, "unico_hp": 22, "adoc_hp": 26, "luz": 10 },
		{ "kind": &"unico_special", "amount": 12, "defended": false, "unico_hp": 22, "adoc_hp": 14, "luz": 10 },
		{ "kind": &"unico_special", "amount": 6, "defended": true, "unico_hp": 22, "adoc_hp": 8, "luz": 10 },
	]
	var msgs: Array[Dictionary] = Battle.messages_for(events, BALANCE, texts)
	assert_eq(msgs[0].text, "El Ofomni te azota con un látigo: 4 de daño.")
	assert_eq(msgs[1].text, "El Ofomni alza todos sus látigos...")
	assert_eq(msgs[2].text, "¡Latigazo múltiple! Los látigos caen: 12 de daño.")
	assert_eq(msgs[3].text, "Resistes los látigos: 6 de daño.")


func test_fatal_defeat_message_is_game_over() -> void:
	var logic := _logic()
	logic.fatal = true
	var texts: Dictionary = Battle.texts_for(logic)
	var events: Array[Dictionary] = [{ "kind": &"defeat", "amount": 0, "unico_hp": 22, "adoc_hp": 0, "luz": 10 }]
	assert_eq(Battle.messages_for(events, BALANCE, texts)[0].text, "Has caído ante Único serpiente. Tu viaje termina aquí.")


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
