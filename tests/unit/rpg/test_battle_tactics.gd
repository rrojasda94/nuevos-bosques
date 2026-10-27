extends GutTest
## IA de combate (ia-de-combate.md): iniciativa (AGI + tirada, Defender primero, Apresurar,
## Esperar), formación (probabilidad por fila, penalización desde detrás, área), roles (Remate,
## Cubrir, Vendar, Animar), perfiles de enemigo, prioridades de los aliados y órdenes al grupo.
## Balance fijo de test con los valores de la ficha.

const Battle = preload("res://scripts/rpg/battle.gd")
const TACTICS: Dictionary = {
	"initiative": { "roll_min": 0, "roll_max": 2, "solo_lead": 3, "hasten_damage": -2, "hasten_agi": 4, "wait_factor": 1.25 },
	"formation": { "front_max": 3, "front_chance": 0.75, "back_factor": 0.75, "area_factor": 1.0 },
	"roles": {
		"order": ["attacker", "defender", "support"],
		"attacker": { "atk_bonus": 1, "finish_bonus": 3, "finish_uses": 1 },
		"defender": { "def_bonus": 1, "cover_every": 2 },
		"support": { "heal_pct": 20, "heal_uses": 2, "cheer_atk": 2, "cheer_uses": 1 },
	},
	"ai": { "help_below": 0.3, "finish_below": 0.3, "retreat_below": 0.2, "swarm_flee_below": 0.3, "tactical_retreat_below": 0.25 },
}
const BALANCE: Dictionary = {
	"adoc": { "max_hp": 30, "atk": 6, "def": 3, "agi": 5, "start_luz": 10, "luz_max": 10 },
	"attack": { "roll_min": -1, "roll_max": 2, "min_damage": 1 },
	"defend_factor": 0.5,
	"flee_chance": 0.75,
	"victory_luz": 1,
	"tactics": TACTICS,
}
const BRUTE: Dictionary = { "name": "Botarramas", "max_hp": 40, "atk": 5, "def": 1, "agi": 3, "ai": "aggressive" }
const REPAREP: Dictionary = { "name": "Reparep", "max_hp": 10, "atk": 3, "def": 1, "agi": 7, "ai": "swarm", "area_attack": true }
const ADOC_ALLY: Dictionary = { "name": "Tavra", "max_hp": 30, "atk": 6, "def": 3, "kind": "adoc", "agi": 5 }


func _logic(enemy: Dictionary = BRUTE, rng_seed: int = 7, hp: int = 30) -> BattleLogic:
	return BattleLogic.new(BALANCE, BALANCE.adoc, hp, 10, enemy, rng_seed)


func _ally(role: String, name: String = "Tavra", extra: Dictionary = {}) -> Dictionary:
	var a: Dictionary = ADOC_ALLY.duplicate()
	a.name = name
	a.role = role
	a.merge(extra, true)
	return a


func _with(base: Dictionary, extra: Dictionary) -> Dictionary:
	var d: Dictionary = base.duplicate()
	d.merge(extra, true)
	return d


func _kinds(events: Array[Dictionary]) -> Array:
	return events.map(func(e: Dictionary) -> StringName: return e.kind)


func _of(events: Array[Dictionary], kind: StringName) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return e.kind == kind)


## Tirada número `index` (desde 0) del RNG de daño de un combate con esa semilla.
func _roll(rng_seed: int, index: int) -> int:
	var mirror := RandomNumberGenerator.new()
	mirror.seed = rng_seed
	var r: int = 0
	for i in index + 1:
		r = mirror.randi_range(-1, 2)
	return r


# --- Iniciativa -----------------------------------------------------------------------------------

func test_order_is_agi_plus_roll_and_deterministic() -> void:
	for s in 50:
		var a := _logic(_with(BRUTE, { "agi": 10 }), s)
		a.add_enemy(_with(BRUTE, { "agi": 0 }))
		a.add_ally(_ally("attacker"))
		var order: Array[Dictionary] = a.turn_order()
		assert_eq(order.size(), 4)
		assert_eq([order[0].side, order[0].index], [BattleLogic.SLOT_ENEMY, 0], "AGI 10 siempre primero")
		assert_eq([order[3].side, order[3].index], [BattleLogic.SLOT_ENEMY, 1], "AGI 0 siempre el último")
		for slot in order:
			var agi: int = 10 if slot.side == BattleLogic.SLOT_ENEMY and slot.index == 0 else (0 if slot.side == BattleLogic.SLOT_ENEMY else 5)
			assert_between(int(slot.score), agi, agi + 2, "AGI + tirada de 0 a 2")
		var b := _logic(_with(BRUTE, { "agi": 10 }), s)
		b.add_enemy(_with(BRUTE, { "agi": 0 }))
		b.add_ally(_ally("attacker"))
		assert_eq(b.turn_order(), order, "misma semilla, mismo orden")


func test_ties_go_to_the_player_side_and_roll_matters() -> void:
	var flat: Dictionary = BALANCE.duplicate(true)
	flat.tactics.initiative.roll_max = 0
	var tie := BattleLogic.new(flat, BALANCE.adoc, 30, 10, _with(BRUTE, { "agi": 5 }), 1)
	tie.add_enemy(_with(BRUTE, { "agi": 5 }))
	tie.add_ally(_ally("attacker"))
	var sides: Array = tie.turn_order().map(func(s: Dictionary) -> StringName: return s.side)
	assert_eq(sides, [BattleLogic.SLOT_ADOC, BattleLogic.SLOT_ALLY, BattleLogic.SLOT_ENEMY, BattleLogic.SLOT_ENEMY], "empate: el bando del jugador")
	# Adoc AGI 5 contra AGI 6: va primero si su tirada supera a la otra en 1 o más (3 de 9 casos).
	var first: int = 0
	for s in 900:
		var l := _logic(_with(BRUTE, { "agi": 6 }), s)
		l.add_enemy(_with(BRUTE, { "agi": -50 }))
		if l.turn_order()[0].side == BattleLogic.SLOT_ADOC:
			first += 1
	assert_between(first, 240, 360, "~1/3")


func test_enemy_with_more_agi_acts_before_the_adoc_in_a_group() -> void:
	var l := _logic(_with(BRUTE, { "agi": 20 }), 3)
	l.add_enemy(_with(BRUTE, { "agi": 20 }))
	var kinds: Array = _kinds(l.play_turn(BattleLogic.Action.ATTACK, 0))
	assert_eq(kinds.slice(0, 3), [&"unico_attack", &"unico_attack", &"attack"])


func test_defend_resolves_before_anyone() -> void:
	for s in 20:
		var l := _logic(_with(BRUTE, { "agi": 20 }), s)
		l.add_enemy(_with(BRUTE, { "agi": 20 }))
		var events: Array[Dictionary] = l.play_turn(BattleLogic.Action.DEFEND)
		assert_eq(events[0].kind, &"defend", "Defender, antes que el más rápido")
		assert_true(_of(events, &"unico_attack").size() == 2)
		var raw: int = BattleLogic.attack_damage(5, 3, _roll(s, 0), 1)
		assert_eq(events[1].amount, ceili(raw * 0.5), "y ya protege del primer golpe")


func test_one_vs_one_adoc_first_unless_three_agi_behind() -> void:
	var close := _logic(_with(BRUTE, { "agi": 7 }))
	assert_eq(_kinds(close.play_turn(BattleLogic.Action.ATTACK)), [&"attack", &"unico_attack"], "+2 de AGI: el Adoc sigue primero")
	var fast := _logic(_with(BRUTE, { "agi": 8 }))
	assert_eq(_kinds(fast.play_turn(BattleLogic.Action.ATTACK)), [&"unico_attack", &"attack"], "+3: el rival primero")
	assert_eq(_kinds(fast.play_turn(BattleLogic.Action.DEFEND)), [&"defend", &"unico_attack"], "Defender sigue siendo primero")


func test_one_vs_one_damage_is_unchanged_with_tactics() -> void:
	var real: BattleLogic = _logic(_with(BRUTE, { "agi": 6 }), 7)
	var events: Array[Dictionary] = real.play_turn(BattleLogic.Action.ATTACK)
	assert_eq(events[0].amount, BattleLogic.attack_damage(6, 1, _roll(7, 0), 1), "sin filas: daño de siempre")
	assert_eq(events[1].amount, BattleLogic.attack_damage(5, 3, _roll(7, 1), 1))
	assert_false(events[1].has("actor"))


func test_hasten_hits_for_less_and_gives_agi_next_round() -> void:
	for s in 30:
		var plain := _logic(BRUTE, s)
		var fast := _logic(BRUTE, s)
		var normal: int = plain.play_turn(BattleLogic.Action.ATTACK)[0].amount
		var hit: Dictionary = fast.play_turn(BattleLogic.Action.HASTEN)[0]
		assert_eq(hit.kind, &"attack")
		assert_true(hit.hasten)
		assert_eq(hit.amount, maxi(1, normal - 2), "−2 de daño")
	var g := _logic(_with(BRUTE, { "agi": 8 }), 4)
	g.add_enemy(_with(BRUTE, { "agi": 8 }))
	g.play_turn(BattleLogic.Action.HASTEN, 0)
	var adoc: Dictionary = g.turn_order().filter(func(s: Dictionary) -> bool: return s.side == BattleLogic.SLOT_ADOC)[0]
	assert_between(int(adoc.score), 9, 11, "AGI 5 + 4 la ronda siguiente")
	g.play_turn(BattleLogic.Action.DEFEND)
	adoc = g.turn_order().filter(func(s: Dictionary) -> bool: return s.side == BattleLogic.SLOT_ADOC)[0]
	assert_between(int(adoc.score), 5, 7, "solo una ronda")


func test_wait_acts_last_with_more_damage() -> void:
	for s in 30:
		var l := _logic(BRUTE, s)
		var events: Array[Dictionary] = l.play_turn(BattleLogic.Action.WAIT)
		assert_eq(_kinds(events), [&"unico_attack", &"attack"], "el último de la ronda")
		assert_true(events[1].wait)
		assert_eq(events[1].amount, maxi(1, roundi(BattleLogic.attack_damage(6, 1, _roll(s, 1), 1) * 1.25)), "×1,25")


# --- Formación ------------------------------------------------------------------------------------

func test_support_starts_behind_and_others_in_front() -> void:
	var l := _logic()
	l.add_ally(_ally("support", "Ivi"))
	l.add_ally(_ally("defender", "Gor"))
	assert_eq(l.adoc_row, BattleLogic.FRONT)
	assert_eq(l.allies[0].row, BattleLogic.BACK)
	assert_eq(l.allies[1].row, BattleLogic.FRONT)
	var four := _logic(REPAREP)
	for i in 3:
		four.add_enemy(REPAREP)
	assert_eq(four.enemies.map(func(e: Dictionary) -> int: return int(e.row)), [0, 0, 0, 1], "hasta 3 delante")


func test_melee_hits_front_row_75_percent() -> void:
	var back_hits: int = 0
	var total: int = 0
	for s in 1200:
		var l := _logic(_with(BRUTE, { "agi": 20, "ai": "" }), s)
		l.add_enemy(_with(BRUTE, { "agi": 20, "ai": "" }))
		l.add_ally(_ally("support", "Ivi", { "max_hp": 300 }))
		var hits: Array = _of(l.play_turn(BattleLogic.Action.DEFEND), &"unico_attack")
		for h in hits:
			total += 1
			if int(h.target) == 0:
				back_hits += 1
	assert_eq(total, 2400)
	assert_between(float(back_hits) / total, 0.22, 0.28, "25% a la fila de detrás")


func test_everything_goes_behind_when_front_is_empty() -> void:
	for s in 50:
		var l := _logic(_with(BRUTE, { "agi": 20 }), s)
		l.add_enemy(_with(BRUTE, { "agi": 20 }))
		l.add_ally(_ally("support", "Ivi"))
		l.adoc_row = BattleLogic.BACK
		l.allies[0].hp = 25
		var hits: Array = _of(l.play_turn(BattleLogic.Action.DEFEND), &"unico_attack")
		for h in hits:
			assert_eq(int(h.target), 0, "agresivo: el de menos PV de los de detrás")


func test_attacking_from_behind_does_less_but_support_heals_in_full() -> void:
	for s in 30:
		var l := _logic(_with(BRUTE, { "agi": 0 }), s)
		l.add_enemy(_with(BRUTE, { "agi": 0 }))
		l.adoc_row = BattleLogic.BACK
		var hit: Dictionary = l.play_turn(BattleLogic.Action.ATTACK, 0)[0]
		assert_true(hit.back)
		assert_eq(hit.amount, maxi(1, roundi(BattleLogic.attack_damage(6, 1, _roll(s, 0), 1) * 0.75)), "×0,75 desde detrás")
	var healer := _logic(_with(BRUTE, { "agi": 0, "atk": 0 }))
	healer.add_ally(_ally("support", "Ivi"))
	healer.adoc_hp = 5
	var events: Array[Dictionary] = healer.play_turn(BattleLogic.Action.DEFEND)
	var heal: Dictionary = _of(events, &"bandage")[0]
	assert_eq(heal.amount, 6, "el 20% de 30, sin penalización desde detrás")
	assert_eq(heal.target, BattleLogic.TARGET_ADOC)


func test_switch_row_costs_the_turn_and_only_with_formation() -> void:
	var solo := _logic()
	assert_false(solo.can_switch_row())
	assert_eq(solo.play_turn(BattleLogic.Action.SWITCH_ROW), [] as Array[Dictionary], "1 contra 1: sin filas")
	var l := _logic(_with(BRUTE, { "agi": 0 }))
	l.add_ally(_ally("attacker"))
	var events: Array[Dictionary] = l.play_turn(BattleLogic.Action.SWITCH_ROW)
	var move: Dictionary = _of(events, &"switch_row")[0]
	assert_eq(move.actor, BattleLogic.TARGET_ADOC)
	assert_eq(l.adoc_row, BattleLogic.BACK)
	assert_eq(_of(events, &"attack").size(), 0, "gasta el turno")


func test_joint_attack_hits_the_whole_front_row() -> void:
	for s in 20:
		var l := _logic(REPAREP, s)
		l.add_enemy(REPAREP)
		l.add_enemy(REPAREP)
		l.joint_attack = true
		l.add_ally(_ally("attacker", "Tavra", { "max_hp": 99, "agi": 0 }))
		l.add_ally(_ally("support", "Ivi", { "max_hp": 99, "agi": 0 }))
		var events: Array[Dictionary] = l.play_turn(BattleLogic.Action.DEFEND)
		var hits: Array = _of(events, &"group_attack")
		assert_eq(hits.map(func(e: Dictionary) -> int: return int(e.target)), [BattleLogic.TARGET_ADOC, 0], "el Adoc y el de delante; el apoyo, no")
		assert_true(hits[0].area)
		assert_eq(hits[0].attackers, 3)
		assert_eq(hits[0].amount, ceili(BattleLogic.joint_damage([3, 3, 3], 3, _roll(s, 0), 1) * 0.5), "una tirada; Defender reduce el del Adoc")
		assert_eq(hits[1].amount, BattleLogic.joint_damage([3, 3, 3], 3, _roll(s, 0), 1))


func test_whip_special_hits_the_whole_front_row() -> void:
	var whip: Dictionary = _with(BRUTE, { "agi": 20, "special_every": 1, "special_factor": 3.0, "special_area": true, "ai": "berserk" })
	var l := _logic(whip, 5)
	l.adoc_hp = 30
	l.add_ally(_ally("attacker", "Tavra", { "max_hp": 99 }))
	l.add_ally(_ally("support", "Ivi", { "max_hp": 99 }))
	var specials: Array = _of(l.play_turn(BattleLogic.Action.ATTACK), &"unico_special")
	assert_eq(specials.map(func(e: Dictionary) -> int: return int(e.target)), [BattleLogic.TARGET_ADOC, 0])
	assert_eq(specials[0].amount, BattleLogic.attack_damage(5, 3, _roll(5, 0), 1) * 3)
	# El especial está siempre anunciado (cada ataque): el atacante se defiende (prioridad 2).
	assert_true(specials[1].defended)
	assert_eq(specials[1].amount, ceili(BattleLogic.attack_damage(5, 3, _roll(5, 0), 1) * 3 * 0.5), "la misma tirada, a la mitad")


# --- Roles ----------------------------------------------------------------------------------------

func test_role_bonuses() -> void:
	var l := _logic()
	l.add_ally(_ally("attacker"))
	l.add_ally(_ally("defender", "Gor"))
	assert_eq(l.allies[0].atk, 7, "atacante +1 ATQ")
	assert_eq(l.allies[1].def, 4, "defensor +1 DEF")


func test_finisher_adds_three_once_against_the_weak() -> void:
	for s in 20:
		var l := _logic(_with(BRUTE, { "agi": 0, "max_hp": 40 }), s)
		l.add_enemy(_with(BRUTE, { "agi": 0 }))
		l.add_ally(_ally("attacker", "Tavra", { "agi": 9 }))
		l.enemies[1].hp = 10
		var events: Array[Dictionary] = l.play_turn(BattleLogic.Action.DEFEND)
		var hit: Dictionary = _of(events, &"ally_attack")[0]
		assert_true(hit.get("finish", false), "Remate contra el que está por debajo del 30%")
		assert_eq(hit.target, 1)
		assert_eq(hit.amount, BattleLogic.attack_damage(7, 1, _roll(s, 0), 1) + 3)
		assert_eq(l.allies[0].finishes_left, 0)


func test_defender_covers_the_wounded_adoc() -> void:
	var l := _logic(_with(BRUTE, { "agi": 20 }), 3, 8)
	l.add_ally(_ally("defender", "Gor", { "max_hp": 99, "agi": 0 }))
	var events: Array[Dictionary] = l.play_turn(BattleLogic.Action.ATTACK)
	assert_eq(events[0].kind, &"cover", "Cubrir se resuelve primero")
	assert_eq(events[0].target, BattleLogic.TARGET_ADOC)
	var hit: Dictionary = _of(events, &"unico_attack")[0]
	assert_eq(hit.target, 0, "el golpe se lo lleva el defensor")
	assert_eq(hit.covered, BattleLogic.TARGET_ADOC)
	assert_eq(l.adoc_hp, 8 - 0, "el Adoc no recibe nada")
	var next: Array[Dictionary] = l.play_turn(BattleLogic.Action.ATTACK)
	assert_eq(_of(next, &"cover").size(), 0, "cada 2 rondas")


func test_support_bandages_twice_and_cheers() -> void:
	var l := _logic(_with(BRUTE, { "agi": 0, "atk": 0, "max_hp": 999 }), 2, 5)
	l.add_ally(_ally("support", "Ivi"))
	var heals: int = 0
	for turn in 4:
		l.adoc_hp = 5
		heals += _of(l.play_turn(BattleLogic.Action.DEFEND), &"bandage").size()
	assert_eq(heals, 2, "dos usos por combate")
	var c := _logic(_with(BRUTE, { "agi": 0, "max_hp": 999 }), 4)
	c.add_ally(_ally("support", "Ivi", { "agi": 9 }))
	var first: Array[Dictionary] = c.play_turn(BattleLogic.Action.DEFEND)
	var cheer: Dictionary = _of(first, &"cheer")[0]
	assert_eq(cheer.target, BattleLogic.TARGET_ADOC, "sin atacante aliado, anima al Adoc")
	assert_eq(cheer.amount, 2)
	var mirror := _logic(_with(BRUTE, { "agi": 0, "max_hp": 999 }), 4)
	mirror.add_ally(_ally("support", "Ivi", { "agi": 9 }))
	mirror.play_turn(BattleLogic.Action.DEFEND)
	mirror.adoc_cheer = 0
	var boosted: int = _of(c.play_turn(BattleLogic.Action.ATTACK), &"attack")[0].amount
	var plain: int = _of(mirror.play_turn(BattleLogic.Action.ATTACK), &"attack")[0].amount
	assert_eq(boosted, plain + 2, "+2 ATQ en su siguiente golpe")


# --- IA -------------------------------------------------------------------------------------------

func test_aggressive_hits_lowest_hp_in_front() -> void:
	for s in 20:
		var l := _logic(_with(BRUTE, { "agi": 20 }), s)
		l.add_ally(_ally("attacker", "Tavra", { "hp": 12 }))
		var hit: Dictionary = _of(l.play_turn(BattleLogic.Action.DEFEND), &"unico_attack")[0]
		assert_eq(hit.target, 0, "el aliado tiene menos PV")


func test_swarm_last_member_flees_without_its_xp() -> void:
	var l := _logic(REPAREP, 1)
	l.add_enemy(REPAREP)
	l.joint_attack = true
	l.enemy_xp = 4
	l.victory_xp = 8
	var fled_levels: Array[int] = []
	l.level_ups = [2] as Array[int]
	l.level_ups_fled = fled_levels
	l.enemies[0].hp = 0
	l.enemies[1].hp = 2
	var events: Array[Dictionary] = l.play_turn(BattleLogic.Action.DEFEND)
	assert_eq(_kinds(events), [&"defend", &"enemy_flees", &"victory"])
	assert_eq(events[1].actor, 1)
	assert_eq(l.result, BattleLogic.Result.VICTORY)
	assert_eq(events[2].xp, 4, "el que huye no da XP")
	assert_eq(events[2].level_ups, [], "niveles sin su XP")


func test_swarm_last_member_goes_for_lowest_def() -> void:
	for s in 20:
		var l := _logic(REPAREP, s)
		l.add_enemy(REPAREP)
		l.joint_attack = true
		l.enemies[0].hp = 0
		l.add_ally(_ally("attacker", "Tavra", { "def": 0 }))
		var hit: Dictionary = _of(l.play_turn(BattleLogic.Action.DEFEND), &"group_attack")[0]
		assert_eq(hit.target, 0, "DEF 0 frente a 3")
		assert_false(hit.has("area"), "solo, sin área")


func test_tactical_goes_for_the_support_and_retreats() -> void:
	var garelino: Dictionary = _with(BRUTE, { "name": "Garelino", "agi": 20, "ai": "tactical", "max_hp": 20 })
	for s in 20:
		var l := _logic(garelino, s)
		l.add_enemy(garelino)
		l.add_ally(_ally("support", "Ivi", { "max_hp": 99 }))
		l.allies[0].row = BattleLogic.FRONT
		for hit in _of(l.play_turn(BattleLogic.Action.DEFEND), &"unico_attack"):
			assert_eq(hit.target, 0, "al apoyo, si está a tiro")
	var hurt := _logic(garelino, 3)
	hurt.add_enemy(garelino)
	hurt.enemies[0].hp = 4
	var events: Array[Dictionary] = hurt.play_turn(BattleLogic.Action.DEFEND)
	assert_eq(_of(events, &"enemy_retreats")[0].actor, 0, "con menos del 25%, se retira")
	assert_false(hurt.is_alive(0))


func test_tactical_support_bandages_a_wounded_mate() -> void:
	var healer: Dictionary = _with(BRUTE, { "name": "Garelino", "agi": 20, "ai": "tactical", "role": "support", "max_hp": 20 })
	var l := _logic(healer, 2)
	l.add_enemy(_with(healer, { "role": "attacker", "agi": 0 }))
	l.enemies[1].hp = 5
	var events: Array[Dictionary] = l.play_turn(BattleLogic.Action.DEFEND)
	var heal: Dictionary = _of(events, &"enemy_bandage")[0]
	assert_eq([heal.actor, heal.target, heal.amount], [0, 1, 4], "el 20% de 20")
	assert_eq(l.enemies[1].hp, 9)


func test_berserk_never_flees_and_targets_the_weak() -> void:
	var mad: Dictionary = _with(BRUTE, { "name": "Ofomni descarriado", "agi": 20, "ai": "berserk", "special_every": 3, "special_factor": 3.0 })
	var l := _logic(mad, 6)
	l.add_ally(_ally("defender", "Gor", { "hp": 9, "max_hp": 99 }))
	l.enemies[0].hp = 1
	var events: Array[Dictionary] = l.play_turn(BattleLogic.Action.DEFEND)
	assert_eq(_of(events, &"enemy_flees").size() + _of(events, &"enemy_retreats").size(), 0, "nunca huye")
	assert_eq(_of(events, &"unico_attack")[0].target, 0)


func test_allies_defend_and_cover_against_an_announced_special() -> void:
	var whip: Dictionary = _with(BRUTE, { "agi": 0, "special_every": 2, "special_factor": 3.0, "max_hp": 999 })
	var l := _logic(whip, 9)
	l.adoc_hp = 30
	l.add_ally(_ally("defender", "Gor", { "max_hp": 99, "agi": 9 }))
	l.add_ally(_ally("attacker", "Tavra", { "max_hp": 99, "agi": 9 }))
	var first: Array[Dictionary] = l.play_turn(BattleLogic.Action.DEFEND)
	assert_eq(first.back().kind, &"special_warning")
	var events: Array[Dictionary] = l.play_turn(BattleLogic.Action.DEFEND)
	var cover: Dictionary = _of(events, &"cover")[0]
	assert_eq(cover.actor, 0)
	assert_eq(cover.target, BattleLogic.TARGET_ADOC, "el de delante con menos PV (30 frente a 99)")
	assert_eq(_of(events, &"ally_defend")[0].actor, 1, "los demás, Defender")


func test_wounded_ally_steps_back() -> void:
	var l := _logic(_with(BRUTE, { "agi": 0, "max_hp": 999 }), 1)
	l.add_ally(_ally("attacker", "Tavra", { "hp": 5 }))
	var events: Array[Dictionary] = l.play_turn(BattleLogic.Action.DEFEND)
	var move: Dictionary = _of(events, &"switch_row")[0]
	assert_eq([move.actor, move.row], [0, BattleLogic.BACK])
	assert_eq(l.allies[0].row, BattleLogic.BACK)


func test_ally_attacks_lowest_hp_then_highest_atk() -> void:
	var l := _logic(_with(BRUTE, { "agi": 0, "max_hp": 30 }), 1)
	l.add_enemy(_with(BRUTE, { "agi": 0, "max_hp": 30, "atk": 9 }))
	l.add_enemy(_with(BRUTE, { "agi": 0, "max_hp": 40 }))
	l.add_ally(_ally("defender", "Gor", { "agi": 9 }))
	var hit: Dictionary = _of(l.play_turn(BattleLogic.Action.DEFEND), &"ally_attack")[0]
	assert_eq(hit.target, 1, "empate a 30 PV: el de más ATQ")


# --- Órdenes --------------------------------------------------------------------------------------

func test_group_orders_do_not_spend_the_turn_and_once_per_round() -> void:
	var solo := _logic()
	assert_false(solo.set_group_order(BattleLogic.GroupOrder.ATTACK), "sin aliados no hay órdenes")
	var l := _logic(_with(BRUTE, { "max_hp": 999 }))
	l.add_ally(_ally("attacker"))
	assert_eq(l.group_order, BattleLogic.GroupOrder.FREE, "Libre por defecto")
	var hp_before: int = l.adoc_hp
	assert_true(l.set_group_order(BattleLogic.GroupOrder.DEFEND))
	assert_eq(l.adoc_hp, hp_before, "no pasa nada: no gasta turno")
	assert_eq(l.round_number, 0)
	assert_false(l.set_group_order(BattleLogic.GroupOrder.ATTACK), "una vez por ronda")
	l.play_turn(BattleLogic.Action.DEFEND)
	assert_true(l.set_group_order(BattleLogic.GroupOrder.ATTACK), "en la ronda siguiente, otra vez")


func test_attack_order_focuses_the_player_target() -> void:
	var l := _logic(_with(BRUTE, { "agi": 0, "max_hp": 50 }), 3)
	l.add_enemy(_with(BRUTE, { "agi": 0, "max_hp": 20 }))
	l.add_ally(_ally("defender", "Gor", { "agi": 0 }))
	l.set_group_order(BattleLogic.GroupOrder.ATTACK)
	var events: Array[Dictionary] = l.play_turn(BattleLogic.Action.ATTACK, 0)
	assert_eq(_of(events, &"ally_attack")[0].target, 0, "al objetivo del jugador, no al de menos PV")
	var free := _logic(_with(BRUTE, { "agi": 0, "max_hp": 50 }), 3)
	free.add_enemy(_with(BRUTE, { "agi": 0, "max_hp": 20 }))
	free.add_ally(_ally("defender", "Gor", { "agi": 0 }))
	assert_eq(_of(free.play_turn(BattleLogic.Action.ATTACK, 0), &"ally_attack")[0].target, 1, "Libre: al de menos PV")


func test_defend_order_heals_and_guards_without_attacking() -> void:
	var l := _logic(_with(BRUTE, { "agi": 0, "max_hp": 999 }), 3, 25)
	l.add_ally(_ally("support", "Ivi"))
	l.add_ally(_ally("attacker", "Tavra"))
	l.set_group_order(BattleLogic.GroupOrder.DEFEND)
	var events: Array[Dictionary] = l.play_turn(BattleLogic.Action.DEFEND)
	assert_eq(_of(events, &"bandage")[0].target, BattleLogic.TARGET_ADOC, "venda al herido aunque pase del 30%")
	assert_eq(_of(events, &"ally_defend")[0].actor, 1, "el atacante se defiende")
	assert_eq(_of(events, &"ally_attack").size(), 0, "nadie ataca")


# --- Datos y narración ----------------------------------------------------------------------------

func test_data_gives_agi_profiles_and_roles() -> void:
	GameState.new_game(42)
	assert_eq(AdocGrowth.agility(1), 5)
	assert_eq(AdocGrowth.agility(2), 6)
	assert_eq(AdocGrowth.agility(5), 7, "5 + ⌊5/2⌋")
	assert_eq(int(AdventureRules.adoc_combat_stats().agi), 5)
	var m: Dictionary = AdventureRules.make_monster(&"botarramas", 2)
	assert_eq([m.agi, m.ai], [3, "guardian"], "P2: el Botarramas guarda su sitio")
	var r: Dictionary = AdventureRules.make_monster(&"reparep", 2)
	assert_eq([r.agi, r.ai, r.area_attack], [7, "swarm", true])
	var o: Dictionary = AdventureRules.make_monster(&"ofomni_descarriado", 4)
	assert_eq([o.agi, o.ai, o.special_area, o.attack_range], [6, "berserk", true, [1.0, 2.0]], "alcance del JSON (números)")
	assert_eq(AdventureRules.make_monster(&"ofomni", 2).agi, 6)
	var role: StringName = AdventureRules.recruit_role(42, "adoc:3")
	assert_true([&"attacker", &"defender", &"support"].has(role))
	assert_eq(AdventureRules.recruit_role(42, "adoc:3"), role, "determinista")
	var logic: BattleLogic = AdventureRules.start_battle(3, 2, &"reparep", 3)
	assert_eq(logic.enemy_xp, 4)
	assert_eq(logic.adoc_agi, 5)


func test_real_one_vs_one_keeps_the_adoc_first() -> void:
	GameState.new_game(42)
	for monster in [&"botarramas", &"ofomni", &"aledra", &"reparep"]:
		var logic: BattleLogic = AdventureRules.start_battle(3, 2, monster, 1)
		assert_eq(logic.turn_order()[0].side, BattleLogic.SLOT_ADOC, "%s: el Adoc primero en el 1 contra 1" % monster)


func test_tactics_messages() -> void:
	var l := _logic(REPAREP)
	l.add_enemy(REPAREP)
	l.add_ally(_ally("defender", "Gor"))
	l.add_ally(_ally("support", "Ivi"))
	var texts: Dictionary = Battle.texts_for(l)
	var base: Dictionary = { "amount": 0, "unico_hp": 10, "adoc_hp": 30, "luz": 10, "enemy_hp": [10, 10], "ally_hp": [30, 30] }
	var events: Array[Dictionary] = [
		_with(base, { "kind": &"cover", "actor": 0, "target": -1 }),
		_with(base, { "kind": &"group_attack", "amount": 5, "target": 0, "covered": -1, "attackers": 2 }),
		_with(base, { "kind": &"bandage", "amount": 6, "actor": 1, "target": -1 }),
		_with(base, { "kind": &"cheer", "amount": 2, "actor": 1, "target": 0 }),
		_with(base, { "kind": &"switch_row", "actor": -1, "row": 1 }),
		_with(base, { "kind": &"ally_attack", "amount": 7, "actor": 0, "target": 1, "finish": true }),
		_with(base, { "kind": &"attack", "amount": 4, "target": 1, "hasten": true }),
		_with(base, { "kind": &"enemy_flees", "actor": 1 }),
	]
	var msgs: Array = Battle.messages_for(events, BALANCE, texts).map(func(m: Dictionary) -> String: return m.text)
	assert_eq(msgs[0], "Gor se pone delante de ti para cubrirte.")
	assert_eq(msgs[1], "Gor se lleva el golpe que iba para ti: 5 de daño.")
	assert_eq(msgs[2], "Ivi te venda las heridas: +6 PV.")
	assert_eq(msgs[3], "Ivi anima a Gor: +2 ATQ.")
	assert_eq(msgs[4], "Pasas a la fila de atrás.")
	assert_eq(msgs[5], "¡Remate! Gor golpea a Reparep: 7 de daño.")
	assert_eq(msgs[6], "¡Te apresuras! Atacas a Reparep: 4 de daño.")
	assert_eq(msgs[7], "Reparep huye del combate.")


func test_tactics_menu_entries() -> void:
	var solo := _logic()
	var entries: Array[Dictionary] = Battle.tactics_entries(solo)
	assert_eq(entries.map(func(e: Dictionary) -> String: return e.text), ["Defender", "Apresurar", "Esperar", "Ir atrás", "Volver"])
	assert_false(entries[3].enabled, "1 contra 1: sin filas")
	var l := _logic()
	l.add_ally(_ally("attacker"))
	var with_allies: Array[Dictionary] = Battle.tactics_entries(l)
	assert_eq(with_allies[4].text, "Orden: Libre")
	assert_true(with_allies[3].enabled)
	assert_eq(Battle.menu_options(l)[Battle.TACTICS_OPTION], "Táctica")
