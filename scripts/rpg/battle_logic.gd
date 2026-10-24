class_name BattleLogic
extends RefCounted
## Combate por turnos contra un Único (ADR 0002, ADR 0009). Lógica pura: no toca GameState ni la
## escena. La escena (scripts/rpg/battle.gd) solo dibuja lo que devuelve play_turn.
## Números en data/combat/balance.json. RNG propio sembrado (nunca randi() global ni GameState.rng).
## Ataque especial configurable por monstruo: cada `special_every` ataques el rival multiplica su daño
## por `special_factor` y lo anuncia en el turno anterior (Latigazo múltiple del Ofomni).

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
## Ataque especial: cada cuántos ataques del rival (0 = nunca) y multiplicador de su daño.
var special_every: int = 0
var special_factor: float = 1.0
## Ataques que ha hecho ya el rival en este combate.
var unico_attacks: int = 0
## Claves de data/text/sistema.json para narrar al rival: attack, warning, special,
## special_defended (sin ellas, el texto genérico del Único).
var unico_texts: Dictionary = {}
## Perder este combate es game over (fatal_at del monstruo y Momento del inicio, monstruos.md).
var fatal: bool = false
## XP que da vencer (la fija AdventureRules según d).
var victory_xp: int = 0


## `unico` = { name, max_hp, atk, def } (ver AdventureRules.make_unico) y, opcionalmente,
## special_every, special_factor y texts.
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
	special_every = int(unico.get("special_every", 0))
	special_factor = float(unico.get("special_factor", 1.0))
	unico_texts = unico.get("texts", {})


## Fórmula de Atacar: max(min_damage, ATQ - DEF + roll).
static func attack_damage(atk: int, def: int, roll: int, min_damage: int) -> int:
	return maxi(min_damage, atk - def + roll)


## El ataque número `n` del rival (desde 1) es el especial.
static func is_special_attack(n: int, every: int) -> bool:
	return every > 0 and n % every == 0


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
## kind: attack, defend, offer_luz, flee_ok, flee_fail, unico_attack, unico_special (lleva además
## "defended": bool), special_warning (aviso del especial del turno siguiente), victory, defeat.
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
	unico_attacks += 1
	var special: bool = is_special_attack(unico_attacks, special_every)
	var hit: int = _roll_attack(unico_atk, adoc_def)
	if special:
		hit = roundi(hit * special_factor)
	var defended: bool = defending
	if defending:
		hit = defended_damage(hit, float(balance.defend_factor))
		defending = false
	adoc_hp = maxi(0, adoc_hp - hit)
	var e: Dictionary = _event(&"unico_special" if special else &"unico_attack", hit)
	if special:
		e.defended = defended
	events.append(e)
	if adoc_hp <= 0:
		result = Result.DEFEAT
		events.append(_event(&"defeat"))
	elif is_special_attack(unico_attacks + 1, special_every):
		events.append(_event(&"special_warning"))
	return events


func _event(kind: StringName, amount: int = 0) -> Dictionary:
	return { "kind": kind, "amount": amount, "unico_hp": unico_hp, "adoc_hp": adoc_hp, "luz": luz }


func _roll_attack(atk: int, def: int) -> int:
	var a: Dictionary = balance.attack
	var roll: int = rng.randi_range(int(a.roll_min), int(a.roll_max))
	return attack_damage(atk, def, roll, int(a.min_damage))
