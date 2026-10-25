class_name BattleLogic
extends RefCounted
## Combate por turnos (ADR 0002, ADR 0009) del Adoc contra 1–4 enemigos, con 0–2 aliados
## (monstruos.md, "combate contra grupos"; otros-adoc.md, "Ayudar en combate"). Lógica pura: no toca
## GameState ni la escena. La escena (scripts/rpg/battle.gd) solo dibuja lo que devuelve play_turn.
## Números en data/combat/balance.json. RNG propio sembrado (nunca randi() global ni GameState.rng).
## - Uno contra uno: el rival es enemies[0]; los campos unico_* lo leen y escriben.
## - Orden del turno: el Adoc, luego los aliados (atacan al mismo objetivo que el Adoc, o al de
##   menos PV si ya cayó), luego los enemigos: si son de grupo (`joint_attack`, los reparep), una sola
##   acción, el ataque conjunto (suma de los ATQ de los vivos − la DEF del objetivo, restada una
##   vez); si no, uno por uno.
## - Con aliados en pie, cada ataque enemigo va al Adoc o a un aliado, al azar. Un aliado que llega a
##   0 PV se retira (no muere; ADR 0004) y deja de actuar.
## - Defender reduce a la mitad todos los golpes al Adoc de ese turno (el siguiente golpe o el ataque
##   conjunto).
## - Huir y pagar valen contra todo el grupo. Victoria cuando caen todos; `victory_xp` es la XP total
##   (AdventureRules la calcula por enemigo).
## Ataque especial configurable por monstruo: cada `special_every` ataques el rival multiplica su daño
## por `special_factor` y lo anuncia en el turno anterior (Latigazo múltiple del Ofomni).
## Pagar en combate (APPEASED, no da XP; el Bosque queda pagado): Ofrecer Luz entrega el peaje N
## del Bosque (con su hostilidad) en Luz suelta; la ofrenda (ofrendas-v1.md) entrega una del
## inventario, completada con Luz suelta hasta N. Se van todos. El Ofomni de la misión no acepta
## ninguno de los dos pagos (accepts_payment = false).

enum Action { ATTACK, DEFEND, OFFER_LUZ, FLEE, OFRENDA }
enum Result { ONGOING, VICTORY, DEFEAT, FLED, APPEASED }

## Objetivo de un ataque enemigo: el Adoc (los aliados, su índice).
const TARGET_ADOC: int = -1

var balance: Dictionary
var rng := RandomNumberGenerator.new()
var result: Result = Result.ONGOING

var adoc_hp: int
var adoc_max_hp: int
var adoc_atk: int
var adoc_def: int
var luz: int
## Los golpes al Adoc de este turno se reducen (Defender).
var defending: bool = false

## Enemigos: [{ name, hp, max_hp, atk, def, special_every, special_factor, attacks, texts }].
var enemies: Array[Dictionary] = []
## Aliados: [{ name, hp, max_hp, atk, def, kind, retired }]. kind: &"adoc" o el id de un Único.
var allies: Array[Dictionary] = []
## Los enemigos atacan juntos (grupo de reparep): una sola acción por turno.
var joint_attack: bool = false
## Id de datos del rival (balance.json, monsters), si lo fija AdventureRules.
var monster_id: StringName = &""

## Perder este combate es game over (fatal_at del monstruo y Momento del inicio, monstruos.md).
var fatal: bool = false
## XP que da vencer (la fija AdventureRules: según d y, en un grupo, por cada enemigo).
var victory_xp: int = 0
## Niveles que alcanza el Adoc si vence, en orden (los calcula AdventureRules al empezar), para
## anunciarlos en el combate tras la victoria.
var level_ups: Array[int] = []
## Pagos: peaje del Bosque (N, con hostilidad), si el rival acepta Luz u ofrendas, copia del
## inventario ([{ id, luz }]) y la ofrenda entregada (índice en `ofrendas`, -1 = ninguna).
var toll: int = 0
var accepts_payment: bool = true
var ofrendas: Array = []
var ofrenda_index: int = -1
## El Adoc pelea sin arma (ATQ base): el combate lo avisa al empezar.
var unarmed: bool = false

# --- El primer enemigo (uno contra uno) ---------------------------------------------------------
var unico_name: String:
	get: return str(enemies[0].name)
	set(value): enemies[0].name = value
var unico_hp: int:
	get: return int(enemies[0].hp)
	set(value): enemies[0].hp = value
var unico_max_hp: int:
	get: return int(enemies[0].max_hp)
	set(value): enemies[0].max_hp = value
var unico_atk: int:
	get: return int(enemies[0].atk)
	set(value): enemies[0].atk = value
var unico_def: int:
	get: return int(enemies[0].def)
	set(value): enemies[0].def = value
## Ataque especial del primer enemigo: cada cuántos ataques (0 = nunca) y multiplicador.
var special_every: int:
	get: return int(enemies[0].special_every)
	set(value): enemies[0].special_every = value
var special_factor: float:
	get: return float(enemies[0].special_factor)
	set(value): enemies[0].special_factor = value
## Ataques que ha hecho ya el primer enemigo en este combate.
var unico_attacks: int:
	get: return int(enemies[0].attacks)
	set(value): enemies[0].attacks = value
## Claves de data/text/sistema.json para narrar al rival: attack, warning, special,
## special_defended (sin ellas, el texto genérico del Único).
var unico_texts: Dictionary:
	get: return enemies[0].texts
	set(value): enemies[0].texts = value


## `adoc` = { max_hp, atk, def } del nivel del Adoc (AdventureRules.adoc_stats). `unico` =
## { name, max_hp, atk, def } (ver AdventureRules.make_unico) y, opcionalmente, special_every,
## special_factor y texts. Más enemigos con add_enemy; aliados con add_ally.
func _init(balance_data: Dictionary, adoc: Dictionary, hp: int, luz_amount: int, unico: Dictionary, rng_seed: int) -> void:
	balance = balance_data
	rng.seed = rng_seed
	adoc_max_hp = int(adoc.max_hp)
	adoc_hp = clampi(hp, 1, adoc_max_hp)
	adoc_atk = int(adoc.atk)
	adoc_def = int(adoc.def)
	luz = luz_amount
	add_enemy(unico)


## Añade un enemigo (mismo formato que `unico` en _init).
func add_enemy(unico: Dictionary) -> void:
	enemies.append({
		"name": str(unico.name),
		"hp": int(unico.max_hp),
		"max_hp": int(unico.max_hp),
		"atk": int(unico.atk),
		"def": int(unico.def),
		"special_every": int(unico.get("special_every", 0)),
		"special_factor": float(unico.get("special_factor", 1.0)),
		"attacks": 0,
		"texts": unico.get("texts", {}),
	})


## Añade un aliado: { name, max_hp, atk, def, kind } (y opcionalmente hp). Empieza en pie.
func add_ally(ally: Dictionary) -> void:
	var max_hp: int = maxi(1, int(ally.max_hp))
	allies.append({
		"name": str(ally.name),
		"hp": clampi(int(ally.get("hp", max_hp)), 1, max_hp),
		"max_hp": max_hp,
		"atk": int(ally.atk),
		"def": int(ally.def),
		"kind": StringName(str(ally.get("kind", "adoc"))),
		"retired": false,
	})


## Fórmula de Atacar: max(min_damage, ATQ - DEF + roll).
static func attack_damage(atk: int, def: int, roll: int, min_damage: int) -> int:
	return maxi(min_damage, atk - def + roll)


## Ataque conjunto (monstruos.md): la suma de los ATQ de los atacantes, con la DEF del objetivo
## restada una sola vez.
static func joint_damage(atks: Array, def: int, roll: int, min_damage: int) -> int:
	var total: int = 0
	for a: Variant in atks:
		total += int(a)
	return attack_damage(total, def, roll, min_damage)


## El ataque número `n` del rival (desde 1) es el especial.
static func is_special_attack(n: int, every: int) -> bool:
	return every > 0 and n % every == 0


## Golpe recibido con Defender activo: se reduce redondeando hacia arriba.
static func defended_damage(damage: int, factor: float) -> int:
	return ceili(damage * factor)


## Hay más de un enemigo (la escena dibuja la fila y pregunta el objetivo).
func is_group() -> bool:
	return enemies.size() > 1


func is_alive(index: int) -> bool:
	return index >= 0 and index < enemies.size() and int(enemies[index].hp) > 0


## Índices de los enemigos que siguen en pie.
func alive_enemies() -> Array[int]:
	var out: Array[int] = []
	for i: int in enemies.size():
		if is_alive(i):
			out.append(i)
	return out


## Objetivo por defecto: el enemigo vivo con menos PV (empate: el primero). -1 si no queda ninguno.
func default_target() -> int:
	var best: int = -1
	for i: int in alive_enemies():
		if best < 0 or int(enemies[i].hp) < int(enemies[best].hp):
			best = i
	return best


## Índices de los aliados que siguen peleando.
func active_allies() -> Array[int]:
	var out: Array[int] = []
	for i: int in allies.size():
		if not allies[i].retired:
			out.append(i)
	return out


## Luz que cuesta Ofrecer Luz: el peaje del Bosque.
func luz_cost() -> int:
	return toll


## Ofrecer Luz: el rival acepta pagos, hay peaje y llega la Luz suelta.
func can_offer_luz() -> bool:
	return not is_over() and accepts_payment and toll > 0 and luz >= toll


func is_over() -> bool:
	return result != Result.ONGOING


## Índices de `ofrendas` con los que se puede pagar el peaje ahora (uno por id, de menor a mayor
## valor). Vacío si el rival no acepta ofrendas.
func payable_ofrendas() -> Array[int]:
	if not accepts_payment:
		return []
	return Ofrendas.payable(ofrendas, luz, toll)


func can_offer_ofrenda() -> bool:
	return not is_over() and not payable_ofrendas().is_empty()


## Entrega la ofrenda `index` de `ofrendas` (entera, completada con Luz suelta si hace falta): los
## enemigos se van y el combate acaba (APPEASED). Eventos: ofrenda ("amount" = valor, "id"; "luz" ya
## descontada) y unico_leaves. Si no se puede, devuelve [] y no consume turno.
func offer_ofrenda(index: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if is_over() or not payable_ofrendas().has(index):
		return events
	var item: Dictionary = ofrendas[index]
	var value: int = int(item.luz)
	luz -= Ofrendas.luz_needed(value, toll)
	ofrenda_index = index
	result = Result.APPEASED
	var e: Dictionary = _event(&"ofrenda", value)
	e.id = str(item.id)
	events.append(e)
	events.append(_event(&"unico_leaves"))
	return events


## Juega un turno completo: el Adoc, sus aliados y los enemigos que sigan en pie. `target`: enemigo
## al que ataca el Adoc (si no vale o es -1, el de menos PV).
## Devuelve eventos para narrar, en orden: { "kind": StringName, "amount": int, y el estado justo
## después del evento: "unico_hp" (el primer enemigo), "enemy_hp" y "ally_hp" (listas), "adoc_hp",
## "luz" } (la UI actualiza las barras con cada uno).
## kind: attack ("target"), defend, offer_luz (paga el peaje: "amount" = Luz entregada; le sigue
## unico_leaves y el combate acaba APPEASED), flee_ok, flee_fail, ally_attack ("actor" = aliado,
## "target" = enemigo), enemy_down ("target": un enemigo de un grupo cae), unico_attack y
## unico_special ("actor" = enemigo, "target" = TARGET_ADOC o aliado; el especial lleva además
## "defended": bool), group_attack (ataque conjunto: "target", "attackers" = cuántos, "defended"),
## ally_retires ("actor"), special_warning ("actor"; aviso del especial del turno siguiente),
## victory, defeat.
## Una acción no válida (Ofrecer Luz sin Luz o contra el Ofomni, combate acabado) devuelve [] y no
## consume turno.
## La ofrenda no se juega aquí: va por offer_ofrenda. La victoria lleva además "xp" y "level_ups".
func play_turn(action: Action, target: int = -1) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if is_over() or (action == Action.OFFER_LUZ and not can_offer_luz()) or action == Action.OFRENDA:
		return events
	if not is_alive(target):
		target = default_target()
	match action:
		Action.ATTACK:
			var dmg: int = _roll_attack(adoc_atk, int(enemies[target].def))
			_hurt_enemy(target, dmg)
			var a: Dictionary = _event(&"attack", dmg)
			a.target = target
			events.append(a)
			_note_down(target, events)
		Action.DEFEND:
			defending = true
			events.append(_event(&"defend"))
		Action.OFFER_LUZ:
			var paid: int = luz_cost()
			luz -= paid
			result = Result.APPEASED
			events.append(_event(&"offer_luz", paid))
			events.append(_event(&"unico_leaves"))
			return events
		Action.FLEE:
			if rng.randf() < float(balance.flee_chance):
				result = Result.FLED
				events.append(_event(&"flee_ok"))
				return events
			events.append(_event(&"flee_fail"))
	if _check_victory(events):
		return events
	for i: int in active_allies():
		var t: int = target if is_alive(target) else default_target()
		var dmg: int = _roll_attack(int(allies[i].atk), int(enemies[t].def))
		_hurt_enemy(t, dmg)
		var e: Dictionary = _event(&"ally_attack", dmg)
		e.actor = i
		e.target = t
		events.append(e)
		_note_down(t, events)
		if _check_victory(events):
			return events
	if joint_attack:
		_joint_phase(events)
	else:
		_single_phase(events)
	defending = false
	if adoc_hp <= 0:
		result = Result.DEFEAT
		events.append(_event(&"defeat"))
		return events
	for j: int in alive_enemies():
		var en: Dictionary = enemies[j]
		if is_special_attack(int(en.attacks) + 1, int(en.special_every)):
			var w: Dictionary = _event(&"special_warning")
			w.actor = j
			events.append(w)
	return events


## Ataque conjunto del grupo: una sola acción contra el Adoc o un aliado.
func _joint_phase(events: Array[Dictionary]) -> void:
	var atks: Array = []
	for j: int in alive_enemies():
		atks.append(int(enemies[j].atk))
	if atks.is_empty():
		return
	var tgt: int = _pick_target()
	var a: Dictionary = balance.attack
	var roll: int = rng.randi_range(int(a.roll_min), int(a.roll_max))
	var hit: int = joint_damage(atks, _target_def(tgt), roll, int(a.min_damage))
	var defended: bool = false
	if tgt == TARGET_ADOC and defending:
		hit = defended_damage(hit, float(balance.defend_factor))
		defended = true
	_hurt_target(tgt, hit)
	var e: Dictionary = _event(&"group_attack", hit)
	e.target = tgt
	e.attackers = atks.size()
	e.defended = defended
	events.append(e)
	_note_retired(tgt, events)


## Cada enemigo vivo ataca por su cuenta (el uno contra uno de siempre).
func _single_phase(events: Array[Dictionary]) -> void:
	for j: int in alive_enemies():
		var en: Dictionary = enemies[j]
		en.attacks = int(en.attacks) + 1
		var special: bool = is_special_attack(int(en.attacks), int(en.special_every))
		var tgt: int = _pick_target()
		var hit: int = _roll_attack(int(en.atk), _target_def(tgt))
		if special:
			hit = roundi(hit * float(en.special_factor))
		var defended: bool = tgt == TARGET_ADOC and defending
		if defended:
			hit = defended_damage(hit, float(balance.defend_factor))
		_hurt_target(tgt, hit)
		var e: Dictionary = _event(&"unico_special" if special else &"unico_attack", hit)
		if special:
			e.defended = defended
		if enemies.size() > 1 or not allies.is_empty():
			e.actor = j
			e.target = tgt
		events.append(e)
		_note_retired(tgt, events)
		if adoc_hp <= 0:
			return


## A quién ataca un enemigo: sin aliados en pie, al Adoc (sin tirar dado); con aliados, al azar entre
## el Adoc y ellos.
func _pick_target() -> int:
	var active: Array[int] = active_allies()
	if active.is_empty():
		return TARGET_ADOC
	var roll: int = rng.randi_range(0, active.size())
	return TARGET_ADOC if roll == 0 else active[roll - 1]


func _target_def(tgt: int) -> int:
	return adoc_def if tgt == TARGET_ADOC else int(allies[tgt].def)


func _hurt_target(tgt: int, hit: int) -> void:
	if tgt == TARGET_ADOC:
		adoc_hp = maxi(0, adoc_hp - hit)
	else:
		allies[tgt].hp = maxi(0, int(allies[tgt].hp) - hit)


func _hurt_enemy(index: int, dmg: int) -> void:
	enemies[index].hp = maxi(0, int(enemies[index].hp) - dmg)


## Un aliado a 0 PV se retira (no muere).
func _note_retired(tgt: int, events: Array[Dictionary]) -> void:
	if tgt == TARGET_ADOC or allies[tgt].retired or int(allies[tgt].hp) > 0:
		return
	allies[tgt].retired = true
	var e: Dictionary = _event(&"ally_retires")
	e.actor = tgt
	events.append(e)


## En un grupo, cada enemigo que cae se anuncia (el uno contra uno pasa directo a la victoria).
func _note_down(index: int, events: Array[Dictionary]) -> void:
	if is_group() and not is_alive(index):
		var e: Dictionary = _event(&"enemy_down")
		e.target = index
		events.append(e)


func _check_victory(events: Array[Dictionary]) -> bool:
	if not alive_enemies().is_empty():
		return false
	result = Result.VICTORY
	var v: Dictionary = _event(&"victory")
	v.xp = victory_xp
	v.level_ups = level_ups.duplicate()
	events.append(v)
	return true


func _event(kind: StringName, amount: int = 0) -> Dictionary:
	var e: Dictionary = { "kind": kind, "amount": amount, "unico_hp": unico_hp, "adoc_hp": adoc_hp, "luz": luz }
	if is_group() or not allies.is_empty():
		e.enemy_hp = enemies.map(func(en: Dictionary) -> int: return int(en.hp))
		e.ally_hp = allies.map(func(al: Dictionary) -> int: return int(al.hp))
	return e


func _roll_attack(atk: int, def: int) -> int:
	var a: Dictionary = balance.attack
	var roll: int = rng.randi_range(int(a.roll_min), int(a.roll_max))
	return attack_damage(atk, def, roll, int(a.min_damage))
