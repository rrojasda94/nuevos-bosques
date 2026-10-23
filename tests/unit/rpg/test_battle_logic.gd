extends GutTest
## Combate por turnos contra un Único (ADR 0009). Usa un balance fijo de test para no depender de
## los valores de data/combat/balance.json, que se ajustan en playtest.

const BALANCE: Dictionary = {
	"adoc": { "max_hp": 30, "atk": 6, "def": 3, "start_luz": 10, "luz_max": 10 },
	"attack": { "roll_min": -1, "roll_max": 2, "min_damage": 1 },
	"defend_factor": 0.5,
	"offer_luz": { "cost": 2, "damage": 8 },
	"flee_chance": 0.75,
	"victory_luz": 1,
}
const UNICO: Dictionary = { "name": "Único serpiente", "max_hp": 22, "atk": 5, "def": 1 }


func _logic(hp: int = 30, luz: int = 10, unico: Dictionary = UNICO, rng_seed: int = 7) -> BattleLogic:
	return BattleLogic.new(BALANCE, hp, luz, unico, rng_seed)


func test_attack_formula() -> void:
	assert_eq(BattleLogic.attack_damage(6, 1, 0, 1), 5)
	assert_eq(BattleLogic.attack_damage(6, 1, 2, 1), 7)
	assert_eq(BattleLogic.attack_damage(6, 1, -1, 1), 4)
	assert_eq(BattleLogic.attack_damage(4, 10, 2, 1), 1, "mínimo 1 de daño")


func test_attack_damage_stays_in_range_and_is_deterministic() -> void:
	for s in 200:
		var a := _logic(30, 10, UNICO, s)
		var events: Array[Dictionary] = a.play_turn(BattleLogic.Action.ATTACK)
		var dmg: int = events[0].amount
		assert_between(dmg, 6 - 1 - 1, 6 - 1 + 2)
		assert_eq(a.unico_hp, 22 - dmg)
		var b := _logic(30, 10, UNICO, s)
		assert_eq(b.play_turn(BattleLogic.Action.ATTACK), events, "mismo seed, mismo turno")


func test_unico_counterattacks_with_attack_formula() -> void:
	var a := _logic()
	var events: Array[Dictionary] = a.play_turn(BattleLogic.Action.ATTACK)
	assert_eq(events[1].kind, &"unico_attack")
	assert_between(events[1].amount, 1, 5 - 3 + 2)
	assert_eq(a.adoc_hp, 30 - events[1].amount)


func test_defend_halves_next_hit_rounding_up() -> void:
	assert_eq(BattleLogic.defended_damage(5, 0.5), 3)
	assert_eq(BattleLogic.defended_damage(4, 0.5), 2)
	assert_eq(BattleLogic.defended_damage(1, 0.5), 1)
	for s in 50:
		var a := _logic(30, 10, UNICO, s)
		var mirror := RandomNumberGenerator.new()
		mirror.seed = s
		var raw: int = BattleLogic.attack_damage(5, 3, mirror.randi_range(-1, 2), 1)
		var events: Array[Dictionary] = a.play_turn(BattleLogic.Action.DEFEND)
		assert_eq(events[1].amount, ceili(raw / 2.0))
		assert_false(a.defending, "Defender solo cubre el siguiente golpe")


func test_offer_luz_costs_luz_and_ignores_def() -> void:
	var tough: Dictionary = UNICO.duplicate()
	tough.def = 50
	var a := _logic(30, 5, tough)
	var events: Array[Dictionary] = a.play_turn(BattleLogic.Action.OFFER_LUZ)
	assert_eq(events[0].kind, &"offer_luz")
	assert_eq(a.unico_hp, 22 - 8)
	assert_eq(a.luz, 3)


func test_offer_luz_without_enough_luz_does_nothing() -> void:
	var a := _logic(30, 1)
	assert_false(a.can_offer_luz())
	assert_eq(a.play_turn(BattleLogic.Action.OFFER_LUZ), [] as Array[Dictionary])
	assert_eq(a.luz, 1)
	assert_eq(a.unico_hp, 22)
	assert_eq(a.adoc_hp, 30, "no consume turno: el Único no ataca")


func test_victory_ends_before_unico_attacks() -> void:
	var weak: Dictionary = UNICO.duplicate()
	weak.max_hp = 8
	var a := _logic(30, 4, weak)
	var events: Array[Dictionary] = a.play_turn(BattleLogic.Action.OFFER_LUZ)
	assert_eq(a.result, BattleLogic.Result.VICTORY)
	assert_eq(events.back().kind, &"victory")
	assert_eq(a.adoc_hp, 30)
	assert_eq(a.play_turn(BattleLogic.Action.ATTACK), [] as Array[Dictionary], "combate acabado")


func test_defeat_when_hp_reaches_zero() -> void:
	var brute: Dictionary = UNICO.duplicate()
	brute.atk = 99
	var a := _logic(5, 4, brute)
	var events: Array[Dictionary] = a.play_turn(BattleLogic.Action.DEFEND)
	assert_eq(a.result, BattleLogic.Result.DEFEAT)
	assert_eq(a.adoc_hp, 0)
	assert_eq(events.back().kind, &"defeat")


func test_flee_is_deterministic_and_about_75_percent() -> void:
	var fled: int = 0
	for s in 1000:
		var a := _logic(30, 10, UNICO, s)
		var b := _logic(30, 10, UNICO, s)
		var ea: Array[Dictionary] = a.play_turn(BattleLogic.Action.FLEE)
		assert_eq(b.play_turn(BattleLogic.Action.FLEE), ea)
		if a.result == BattleLogic.Result.FLED:
			fled += 1
			assert_eq(ea.size(), 1, "si huyes, el Único no ataca")
		else:
			assert_eq(ea[0].kind, &"flee_fail")
			assert_eq(ea[1].kind, &"unico_attack", "si fallas, el Único ataca")
	assert_between(fled, 700, 800)
