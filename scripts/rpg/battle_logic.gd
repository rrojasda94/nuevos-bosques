class_name BattleLogic
extends RefCounted
## Combate por turnos contra un Único (ADR 0002, ADR 0009). Lógica pura: no toca GameState ni la
## escena. La escena (scripts/rpg/battle.gd) solo dibuja lo que devuelve play_turn.
## Números en data/combat/balance.json. RNG propio sembrado (nunca randi() global ni GameState.rng).

enum Action { ATTACK, DEFEND, OFFER_LUZ, FLEE }
enum Result { ONGOING, VICTORY, DEFEAT, FLED }

var balance: Dictionary
var rng := RandomNumberGenerator.new()
var result: Result = Result.ONGOING

var adoc_hp: int
var adoc_max_hp: int
var adoc_atk: int
var adoc_def: int
var luz: int
## El siguiente golpe que reciba el Adoc se reduce (Defender).
var defending: bool = false

var unico_name: String
var unico_hp: int
var unico_max_hp: int
var unico_atk: int
var unico_def: int


## `unico` = { name, max_hp, atk, def } (ver AdventureRules.make_unico).
func _init(balance_data: Dictionary, hp: int, luz_amount: int, unico: Dictionary, rng_seed: int) -> void:
	balance = balance_data
	rng.seed = rng_seed
	var adoc: Dictionary = balance.adoc
	adoc_max_hp = int(adoc.max_hp)
	adoc_hp = clampi(hp, 1, adoc_max_hp)
	adoc_atk = int(adoc.atk)
	adoc_def = int(adoc.def)
	luz = luz_amount
	unico_name = unico.name
	unico_max_hp = int(unico.max_hp)
	unico_hp = unico_max_hp
	unico_atk = int(unico.atk)
	unico_def = int(unico.def)


## Fórmula de Atacar: max(min_damage, ATQ - DEF + roll).
static func attack_damage(atk: int, def: int, roll: int, min_damage: int) -> int:
	return maxi(min_damage, atk - def + roll)


## Golpe recibido con Defender activo: se reduce redondeando hacia arriba.
static func defended_damage(damage: int, factor: float) -> int:
	return ceili(damage * factor)


func luz_cost() -> int:
	return int(balance.offer_luz.cost)


func can_offer_luz() -> bool:
	return luz >= luz_cost()


func is_over() -> bool:
	return result != Result.ONGOING


## Juega un turno completo (primero el Adoc, luego el Único si sigue en pie).
## Devuelve eventos para narrar, en orden: { "kind": StringName, "amount": int, y el estado justo
## después del evento: "unico_hp", "adoc_hp", "luz" } (la UI actualiza las barras con cada uno).
## kind: attack, defend, offer_luz, flee_ok, flee_fail, unico_attack, victory, defeat.
## Una acción no válida (Ofrecer Luz sin Luz, combate acabado) devuelve [] y no consume turno.
func play_turn(action: Action) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if is_over() or (action == Action.OFFER_LUZ and not can_offer_luz()):
		return events
	match action:
		Action.ATTACK:
			var dmg: int = _roll_attack(adoc_atk, unico_def)
			unico_hp = maxi(0, unico_hp - dmg)
			events.append(_event(&"attack", dmg))
		Action.DEFEND:
			defending = true
			events.append(_event(&"defend"))
		Action.OFFER_LUZ:
			luz -= luz_cost()
			var dmg_luz: int = int(balance.offer_luz.damage)
			unico_hp = maxi(0, unico_hp - dmg_luz)
			events.append(_event(&"offer_luz", dmg_luz))
		Action.FLEE:
			if rng.randf() < float(balance.flee_chance):
				result = Result.FLED
				events.append(_event(&"flee_ok"))
				return events
			events.append(_event(&"flee_fail"))
	if unico_hp <= 0:
		result = Result.VICTORY
		events.append(_event(&"victory"))
		return events
	var hit: int = _roll_attack(unico_atk, adoc_def)
	if defending:
		hit = defended_damage(hit, float(balance.defend_factor))
		defending = false
	adoc_hp = maxi(0, adoc_hp - hit)
	events.append(_event(&"unico_attack", hit))
	if adoc_hp <= 0:
		result = Result.DEFEAT
		events.append(_event(&"defeat"))
	return events


func _event(kind: StringName, amount: int = 0) -> Dictionary:
	return { "kind": kind, "amount": amount, "unico_hp": unico_hp, "adoc_hp": adoc_hp, "luz": luz }


func _roll_attack(atk: int, def: int) -> int:
	var a: Dictionary = balance.attack
	var roll: int = rng.randi_range(int(a.roll_min), int(a.roll_max))
	return attack_damage(atk, def, roll, int(a.min_damage))
