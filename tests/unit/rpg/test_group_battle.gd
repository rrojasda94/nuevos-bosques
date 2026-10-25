extends GutTest
## Combate en grupo (monstruos.md, otros-adoc.md): ataque conjunto, objetivo, Defender, victoria con
## XP por cada enemigo, huir y pagar contra el grupo, aliados que no mueren y el 1 contra 1 de
## siempre. Balance fijo de test.

const Battle = preload("res://scripts/rpg/battle.gd")
const BALANCE: Dictionary = {
	"adoc": { "max_hp": 30, "atk": 6, "def": 3, "start_luz": 10, "luz_max": 10 },
	"attack": { "roll_min": -1, "roll_max": 2, "min_damage": 1 },
	"defend_factor": 0.5,
	"flee_chance": 0.75,
	"victory_luz": 1,
}
## Un reparep a d = 2: 10 / 3 / 1.
const REPAREP: Dictionary = { "name": "Reparep", "max_hp": 10, "atk": 3, "def": 1 }
const ALLY: Dictionary = { "name": "Tavra", "max_hp": 30, "atk": 6, "def": 3, "kind": "adoc" }


func _group(n: int, rng_seed: int = 7, hp: int = 30) -> BattleLogic:
	var logic := BattleLogic.new(BALANCE, BALANCE.adoc, hp, 10, REPAREP, rng_seed)
	for i in n - 1:
		logic.add_enemy(REPAREP)
	for i in n:
		logic.enemies[i].name = "Reparep %d" % (i + 1)
	logic.joint_attack = true
	return logic


## Tirada número `index` (desde 0) del RNG de un combate con esa semilla.
func _roll(rng_seed: int, index: int) -> int:
	var mirror := RandomNumberGenerator.new()
	mirror.seed = rng_seed
	var r: int = 0
	for i in index + 1:
		r = mirror.randi_range(-1, 2)
	return r


func test_joint_damage_sums_atk_and_subtracts_def_once() -> void:
	assert_eq(BattleLogic.joint_damage([3, 3, 3], 3, 0, 1), 6, "9 − 3, la DEF una sola vez")
	assert_eq(BattleLogic.joint_damage([3, 3, 3, 3], 3, 2, 1), 11)
	assert_eq(BattleLogic.joint_damage([2], 4, -1, 1), 1, "uno solo, mínimo 1")


func test_group_attacks_jointly_once_per_turn() -> void:
	for s in 40:
		var logic := _group(3, s)
		var events: Array[Dictionary] = logic.play_turn(BattleLogic.Action.DEFEND)
		var hits: Array = events.filter(func(e: Dictionary) -> bool: return e.kind == &"group_attack")
		assert_eq(hits.size(), 1, "una sola acción del grupo")
		var raw: int = BattleLogic.joint_damage([3, 3, 3], 3, _roll(s, 0), 1)
		assert_eq(hits[0].amount, ceili(raw * 0.5), "Defender reduce a la mitad el ataque conjunto")
		assert_true(hits[0].defended)
		assert_eq(hits[0].attackers, 3)
		assert_eq(logic.adoc_hp, 30 - hits[0].amount)
		var plain := _group(3, s)
		var after: Array[Dictionary] = plain.play_turn(BattleLogic.Action.FLEE)
		if plain.result == BattleLogic.Result.ONGOING:
			var hit: Dictionary = after.filter(func(e: Dictionary) -> bool: return e.kind == &"group_attack")[0]
			assert_false(hit.defended)


func test_fallen_members_lower_the_joint_attack() -> void:
	var logic := _group(4, 3)
	logic.enemies[0].hp = 0
	logic.enemies[1].hp = 0
	var events: Array[Dictionary] = logic.play_turn(BattleLogic.Action.DEFEND)
	var hit: Dictionary = events.filter(func(e: Dictionary) -> bool: return e.kind == &"group_attack")[0]
	assert_eq(hit.attackers, 2)
	assert_eq(hit.amount, ceili(BattleLogic.joint_damage([3, 3], 3, _roll(3, 0), 1) * 0.5))


func test_attack_hits_the_chosen_target_and_default_is_lowest_hp() -> void:
	var logic := _group(3, 5)
	logic.enemies[2].hp = 4
	assert_eq(logic.default_target(), 2, "el de menos PV")
	var events: Array[Dictionary] = logic.play_turn(BattleLogic.Action.ATTACK, 1)
	assert_eq(events[0].kind, &"attack")
	assert_eq(events[0].target, 1)
	assert_eq(logic.enemies[1].hp, 10 - events[0].amount)
	assert_eq(logic.enemies[0].hp, 10, "los demás no reciben daño")
	assert_eq(logic.enemies[2].hp, 4)
	var auto := _group(3, 5)
	auto.enemies[2].hp = 4
	var e2: Array[Dictionary] = auto.play_turn(BattleLogic.Action.ATTACK)
	assert_eq(e2[0].target, 2, "sin objetivo, al de menos PV")
	var dead := _group(3, 5)
	dead.enemies[0].hp = 0
	assert_eq(dead.play_turn(BattleLogic.Action.ATTACK, 0)[0].target, 1, "un caído no vale de objetivo")


func test_overkill_does_not_carry_over_and_fallen_is_announced() -> void:
	var logic := _group(2, 9)
	logic.enemies[0].hp = 1
	var events: Array[Dictionary] = logic.play_turn(BattleLogic.Action.ATTACK, 0)
	assert_eq(events[1].kind, &"enemy_down")
	assert_eq(events[1].target, 0)
	assert_eq(logic.enemies[1].hp, 10, "el daño sobrante no pasa al otro")
	assert_eq(logic.result, BattleLogic.Result.ONGOING)
	assert_eq(events[2].kind, &"group_attack")
	assert_eq(events[2].attackers, 1, "queda uno: ataca solo")


func test_victory_when_all_fall_with_xp_for_each() -> void:
	var logic := _group(3, 2)
	logic.victory_xp = 3 * 4
	for i in 3:
		logic.enemies[i].hp = 1
	var kinds: Array = []
	for turn in 3:
		kinds.append_array(logic.play_turn(BattleLogic.Action.ATTACK).map(func(e: Dictionary) -> StringName: return e.kind))
	assert_eq(logic.result, BattleLogic.Result.VICTORY)
	assert_eq(kinds.count(&"enemy_down"), 3)
	assert_eq(kinds.back(), &"victory")


func test_rules_give_xp_per_reparep_and_group_stats() -> void:
	GameState.new_game(42)
	var logic: BattleLogic = AdventureRules.start_battle(3, 2, &"reparep", 3)
	assert_eq(logic.enemies.size(), 3)
	assert_true(logic.joint_attack)
	assert_eq([logic.unico_max_hp, logic.unico_atk, logic.unico_def], [10, 3, 1], "PV 6 + 2·d, ATQ 2 + ⌊d/2⌋, DEF 1")
	assert_eq(logic.victory_xp, 3 * (2 + 2), "(2 + d) por reparep")
	assert_eq(logic.enemies[2].name, "Reparep 3")
	var one: BattleLogic = AdventureRules.start_battle(3, 3, &"reparep", 1)
	assert_eq([one.unico_max_hp, one.unico_atk], [12, 3])
	assert_eq(one.unico_name, "Reparep", "solo, sin número")


func test_flee_and_pay_count_for_the_whole_group() -> void:
	var fled: int = 0
	for s in 200:
		var logic := _group(4, s)
		logic.play_turn(BattleLogic.Action.FLEE)
		if logic.result == BattleLogic.Result.FLED:
			fled += 1
	assert_between(fled, 130, 170, "75% contra el grupo entero")
	var paying := _group(3, 1)
	paying.toll = 5
	var events: Array[Dictionary] = paying.play_turn(BattleLogic.Action.OFFER_LUZ)
	assert_eq(events.map(func(e: Dictionary) -> StringName: return e.kind), [&"offer_luz", &"unico_leaves"])
	assert_eq(paying.result, BattleLogic.Result.APPEASED, "se van todos")
	assert_eq(paying.luz, 5)
	var ofrenda := _group(3, 1)
	ofrenda.toll = 4
	ofrenda.ofrendas = [{ "id": "cuenta_de_barro", "luz": 3 }]
	assert_eq(ofrenda.offer_ofrenda(0).back().kind, &"unico_leaves")
	assert_eq(ofrenda.result, BattleLogic.Result.APPEASED)


func test_allies_act_after_the_adoc_on_the_same_target() -> void:
	var logic := _group(3, 11)
	logic.add_ally(ALLY)
	var events: Array[Dictionary] = logic.play_turn(BattleLogic.Action.ATTACK, 1)
	var kinds: Array = events.map(func(e: Dictionary) -> StringName: return e.kind)
	assert_eq(kinds[0], &"attack")
	assert_eq(kinds[1], &"ally_attack", "el aliado justo después del Adoc")
	assert_eq(events[1].target, 1, "contra el mismo objetivo")
	assert_eq(events[1].actor, 0)
	assert_eq(logic.enemies[1].hp, maxi(0, 10 - events[0].amount - events[1].amount))
	assert_true(events.back().has("ally_hp"))


func test_ally_retires_instead_of_dying_and_stops_acting() -> void:
	var brutes: Dictionary = REPAREP.duplicate()
	brutes.atk = 40
	var retired: bool = false
	for s in 30:
		var logic := BattleLogic.new(BALANCE, BALANCE.adoc, 30, 10, brutes, s)
		logic.add_enemy(brutes)
		logic.joint_attack = true
		logic.add_ally(ALLY)
		var events: Array[Dictionary] = logic.play_turn(BattleLogic.Action.DEFEND)
		var hit: Dictionary = events.filter(func(e: Dictionary) -> bool: return e.kind == &"group_attack")[0]
		if hit.target == 0:
			retired = true
			assert_eq(logic.allies[0].hp, 0)
			assert_true(logic.allies[0].retired, "a 0 PV se retira")
			assert_eq(events.back().kind, &"ally_retires")
			assert_eq(logic.result, BattleLogic.Result.ONGOING, "el combate sigue")
			assert_eq(logic.active_allies(), [] as Array[int])
			var next: Array[Dictionary] = logic.play_turn(BattleLogic.Action.DEFEND)
			assert_false(next.any(func(e: Dictionary) -> bool: return e.kind == &"ally_attack"), "ya no actúa")
			assert_false(next.any(func(e: Dictionary) -> bool: return int(e.get("target", -1)) == 0), "ya no la atacan")
	assert_true(retired, "alguna vez atacan al aliado (al azar)")


func test_enemies_split_between_adoc_and_ally() -> void:
	var on_ally: int = 0
	for s in 200:
		var logic := _group(2, s)
		logic.add_ally(ALLY)
		var events: Array[Dictionary] = logic.play_turn(BattleLogic.Action.DEFEND)
		var hit: Dictionary = events.filter(func(e: Dictionary) -> bool: return e.kind == &"group_attack")[0]
		if hit.target == 0:
			on_ally += 1
			assert_eq(logic.adoc_hp, 30, "Defender no protege al aliado, pero el Adoc no recibe nada")
			assert_false(hit.defended)
	assert_between(on_ally, 70, 130, "50/50")


func test_one_vs_one_unchanged() -> void:
	var unico: Dictionary = { "name": "Único serpiente", "max_hp": 22, "atk": 5, "def": 1 }
	var logic := BattleLogic.new(BALANCE, BALANCE.adoc, 30, 10, unico, 7)
	assert_false(logic.is_group())
	var events: Array[Dictionary] = logic.play_turn(BattleLogic.Action.ATTACK)
	assert_eq(events.map(func(e: Dictionary) -> StringName: return e.kind), [&"attack", &"unico_attack"])
	assert_false(events[1].has("actor"), "sin actor ni listas en el 1 contra 1")
	assert_false(events[1].has("enemy_hp"))
	assert_eq(events[0].amount, BattleLogic.attack_damage(6, 1, _roll(7, 0), 1))
	assert_eq(events[1].amount, BattleLogic.attack_damage(5, 3, _roll(7, 1), 1))
	logic.unico_hp = 1
	assert_eq(logic.enemies[0].hp, 1, "unico_hp es el primer enemigo")


func test_group_messages_name_each_actor() -> void:
	var logic := _group(3, 4)
	logic.add_ally(ALLY)
	var texts: Dictionary = Battle.texts_for(logic)
	texts.group = "Ataque conjunto de %s: %d de daño."
	texts.plural = "los reparep"
	texts.group_name = "los reparep"
	var events: Array[Dictionary] = [
		{ "kind": &"attack", "amount": 5, "target": 1, "unico_hp": 10, "adoc_hp": 30, "luz": 10, "enemy_hp": [10, 5, 10], "ally_hp": [30] },
		{ "kind": &"ally_attack", "amount": 6, "actor": 0, "target": 1, "unico_hp": 10, "adoc_hp": 30, "luz": 10, "enemy_hp": [10, 0, 10], "ally_hp": [30] },
		{ "kind": &"enemy_down", "amount": 0, "target": 1, "unico_hp": 10, "adoc_hp": 30, "luz": 10, "enemy_hp": [10, 0, 10], "ally_hp": [30] },
		{ "kind": &"group_attack", "amount": 9, "target": -1, "attackers": 2, "defended": false, "unico_hp": 10, "adoc_hp": 21, "luz": 10, "enemy_hp": [10, 0, 10], "ally_hp": [30] },
		{ "kind": &"group_attack", "amount": 4, "target": 0, "attackers": 2, "defended": false, "unico_hp": 10, "adoc_hp": 21, "luz": 10, "enemy_hp": [10, 0, 10], "ally_hp": [26] },
	]
	var msgs: Array = Battle.messages_for(events, BALANCE, texts).map(func(m: Dictionary) -> String: return m.text)
	assert_eq(msgs[0], "Atacas a Reparep 2: 5 de daño.")
	assert_eq(msgs[1], "Tavra golpea a Reparep 2: 6 de daño.")
	assert_eq(msgs[2], "Reparep 2 se deshace en niebla.")
	assert_eq(msgs[3], "Ataque conjunto de los reparep: 9 de daño.")
	assert_eq(msgs[4], "Ataque conjunto de los reparep contra Tavra: 4 de daño.")


func test_reparep_texts_from_data() -> void:
	GameState.new_game(42)
	var logic: BattleLogic = AdventureRules.start_battle(3, 2, &"reparep", 4)
	var texts: Dictionary = Battle.texts_for(logic)
	assert_eq(Battle.start_messages(logic)[0].text, "¡Te rodean los reparep! Son 4.")
	var e: Array[Dictionary] = [{ "kind": &"group_attack", "amount": 9, "target": -1, "attackers": 4, "defended": false,
		"unico_hp": 10, "adoc_hp": 21, "luz": 10, "enemy_hp": [10, 10, 10, 10], "ally_hp": [] }]
	assert_eq(Battle.messages_for(e, BALANCE, texts)[0].text, "Ataque conjunto de los reparep: 9 de daño.")
	e[0].attackers = 1
	e[0].enemy_hp = [0, 0, 10, 0]
	assert_eq(Battle.messages_for(e, BALANCE, texts)[0].text, "Reparep 3 te pellizca: 9 de daño.")
	var choices: Array[int] = [0, 2]
	assert_eq(Battle.target_options(logic, choices), ["Reparep 1  PV 10", "Reparep 3  PV 10"] as Array[String])
	assert_eq(Battle.group_title(logic), "Reparep x4")
