class_name BattleLogic
extends RefCounted
## Combate por turnos (ADR 0002, ADR 0009) del Adoc contra 1–4 enemigos, con 0–2 aliados
## (monstruos.md, "combate contra grupos"; otros-adoc.md, "Ayudar en combate"), con la IA de combate
## de ia-de-combate.md (iniciativa, formación, roles, perfiles de enemigo y órdenes al grupo). Lógica
## pura: no toca GameState ni la escena. La escena (scripts/rpg/battle.gd) solo dibuja lo que
## devuelve play_turn. Números en data/combat/balance.json (bloque tactics para la IA). RNG propio
## sembrado (nunca randi() global ni GameState.rng); el orden de turnos tira con otro RNG sembrado
## desde la misma semilla, para no mover las tiradas de daño.
## - Uno contra uno: el rival es enemies[0]; los campos unico_* lo leen y escriben. Sin filas ni
##   roles. El Adoc actúa primero salvo con Esperar o si el rival le saca `solo_lead` de AGI o más
##   (sin tirada de iniciativa).
## - Iniciativa: cada ronda, orden = AGI + tirada (roll_min..roll_max, del bloque tactics.initiative),
##   de mayor a menor; empate: el bando del jugador (el Adoc y luego los aliados en orden), luego los
##   enemigos en orden. Defender y Cubrir se resuelven antes que nadie; Esperar, el último. El orden
##   de la ronda siguiente queda en `round_order` (la escena lo dibuja como una línea de iconos).
##   Apresurar: ataque con hasten_damage y +hasten_agi de AGI la ronda siguiente. Esperar: ataque
##   ×wait_factor al final de la ronda. Un grupo de ataque conjunto (reparep) es un solo hueco, con
##   la AGI del más rápido.
## - Formación: dos filas por bando (FRONT, BACK; front_max delante). Los golpes van a la fila
##   delantera con front_chance (si las dos tienen a alguien); desde detrás, el cuerpo a cuerpo hace
##   ×back_factor (el apoyo cura y anima sin penalización). Cambiar de fila gasta el turno. El ataque
##   conjunto de un grupo con `area_attack` y el especial de un enemigo con `special_area` golpean a
##   toda la fila delantera (o a la de detrás si delante no queda nadie).
## - Roles (aliados y enemigos tácticos): atacante (+ATQ, Remate), defensor (+DEF, Cubrir cada
##   cover_every rondas: los golpes al protegido se los lleva él hasta su siguiente turno) y apoyo
##   (Vendar heal_uses veces, Animar). Un aliado sin rol (datos antiguos) ataca al objetivo del Adoc.
## - IA de aliados (orden Libre): prioridades de la ficha (curar o cubrir a quien baje de help_below,
##   cubrirse ante un especial anunciado, retirarse atrás con poca vida, rematar, atacar al de menos
##   PV). Órdenes al grupo (Atacar, Defender, Libre): no gastan turno, una vez por ronda.
## - Perfiles de enemigo (`ai`): aggressive y berserk (al de menos PV de la fila a la que llega),
##   swarm (ataque conjunto; el último, al de menos DEF, y huye con poca vida sin dar su XP),
##   tactical (Cubrir, Vendar, ataca primero al apoyo y se retira con poca vida). Sin perfil (datos
##   antiguos), objetivo al azar entre los de la fila.
## - Con aliados en pie, un aliado que llega a 0 PV se retira (no muere; ADR 0004) y deja de actuar.
## - Defender reduce a la mitad todos los golpes al Adoc de esa ronda.
## - Huir y pagar valen contra todo el grupo. Victoria cuando no queda ninguno en pie; `victory_xp`
##   es la XP total (AdventureRules la calcula por enemigo).
## Ataque especial configurable por monstruo: cada `special_every` ataques el rival multiplica su daño
## por `special_factor` y lo anuncia en el turno anterior (Latigazo múltiple del Ofomni).
## Pagar en combate (APPEASED, no da XP; el Bosque queda pagado): Ofrecer Luz entrega el peaje N
## del Bosque (con su hostilidad) en Luz suelta; la ofrenda (ofrendas-v1.md) entrega una del
## inventario, completada con Luz suelta hasta N. Se van todos. El Ofomni de la misión no acepta
## ninguno de los dos pagos (accepts_payment = false).
## Skills (moralidad-y-progresion.md, las fija AdventureRules): Golpe fuerte es pasiva: con
## `strong_every` > 0, el primer ataque del Adoc que la tenga lista hace `strong_factor` veces el daño
## y vuelve a estar lista `strong_every` turnos después. Botín: `loot_id` es la ofrenda que deja el
## rival si se le vence (la victoria la anuncia).

enum Action { ATTACK, DEFEND, OFFER_LUZ, FLEE, OFRENDA, HASTEN, WAIT, SWITCH_ROW }
enum Result { ONGOING, VICTORY, DEFEAT, FLED, APPEASED }
## Orden al grupo (ia-de-combate.md, sección 5). FREE por defecto.
enum GroupOrder { FREE, ATTACK, DEFEND }

## Objetivo de un ataque enemigo: el Adoc (los aliados, su índice).
const TARGET_ADOC: int = -1
## Filas de la formación.
const FRONT: int = 0
const BACK: int = 1
## Roles (ids de balance.json, tactics.roles).
const ROLE_NONE: StringName = &""
const ROLE_ATTACKER: StringName = &"attacker"
const ROLE_DEFENDER: StringName = &"defender"
const ROLE_SUPPORT: StringName = &"support"
## Perfiles de enemigo (monsters.*.ai).
const AI_NONE: StringName = &""
const AI_AGGRESSIVE: StringName = &"aggressive"
const AI_SWARM: StringName = &"swarm"
const AI_TACTICAL: StringName = &"tactical"
const AI_BERSERK: StringName = &"berserk"
## Perfiles del combate táctico (P2, ajustes-playtest-0.5.md §6a). En el combate por menú van como
## el agresivo (al de menos PV de la fila delantera).
const AI_GUARDIAN: StringName = &"guardian"
const AI_WHIP: StringName = &"whip"
const AI_AMBUSHER: StringName = &"ambusher"
## Huecos del orden de turnos: { side, index, score }.
const SLOT_ADOC: StringName = &"adoc"
const SLOT_ALLY: StringName = &"ally"
const SLOT_ENEMY: StringName = &"enemy"
## El grupo de ataque conjunto (una sola acción).
const SLOT_GROUP: StringName = &"group"
## Planes de la IA.
const PLAN_ATTACK: StringName = &"attack"
const PLAN_FINISH: StringName = &"finish"
const PLAN_DEFEND: StringName = &"defend"
const PLAN_COVER: StringName = &"cover"
const PLAN_BANDAGE: StringName = &"bandage"
const PLAN_CHEER: StringName = &"cheer"
const PLAN_SWITCH: StringName = &"switch_row"
## Sal del RNG del orden de turnos (se suma a la semilla del combate).
const ORDER_SALT: int = 7919

var balance: Dictionary
## Bloque tactics de balance.json ({} con un balance sin IA: sin tirada de iniciativa ni límite de
## la fila delantera, como el combate de antes).
var tactics: Dictionary
var rng := RandomNumberGenerator.new()
var order_rng := RandomNumberGenerator.new()
var result: Result = Result.ONGOING

var adoc_hp: int
var adoc_max_hp: int
var adoc_atk: int
var adoc_def: int
## Agilidad del Adoc (AdocGrowth.agility; sin ella en `adoc`, levels.agi_base o 0).
var adoc_agi: int
var adoc_row: int = FRONT
var luz: int
## Tope de Luz suelta del Adoc (con los puntos de Luz). Para anunciar el +1 de la victoria.
var luz_max: int = 10
## Los golpes al Adoc de esta ronda se reducen (Defender).
var defending: bool = false

## Enemigos: [{ name, hp, max_hp, atk, def, special_every, special_factor, attacks, texts, agi, ai,
## role, row, area_attack, special_area, gone, heals_left, finishes_left, cover_ready }].
## `gone`: huyó o se retiró (no está en pie aunque le queden PV).
var enemies: Array[Dictionary] = []
## Aliados: [{ name, hp, max_hp, atk, def, kind, retired, agi, role, row, defending, cheer,
## heals_left, cheers_left, finishes_left, cover_ready }]. kind: &"adoc" o el id de un Único.
var allies: Array[Dictionary] = []
## Los enemigos atacan juntos (grupo de reparep): una sola acción por ronda.
var joint_attack: bool = false:
	set(value):
		joint_attack = value
		_order_dirty = true
## Id de datos del rival (balance.json, monsters), si lo fija AdventureRules.
var monster_id: StringName = &""

## Ronda actual (0 antes del primer turno).
var round_number: int = 0
## Orden de la próxima ronda (sin Defender ni Esperar, que dependen de lo que se elija). Leerlo con
## turn_order(), que lo tira si cambió la composición del combate.
var round_order: Array[Dictionary] = []
var _order_dirty: bool = true
var group_order: GroupOrder = GroupOrder.FREE
## Último enemigo al que atacó el Adoc (-1 = ninguno): el objetivo de la orden Atacar.
var player_target: int = -1
## Animar sobre el Adoc: rondas que le quedan (se gasta en su siguiente ataque).
var adoc_cheer: int = 0
## Cubrir: protegido -> índice del defensor. Bando del jugador: clave TARGET_ADOC o índice de
## aliado; enemigos: índice de enemigo.
var ally_covers: Dictionary = {}
var enemy_covers: Dictionary = {}
var _hasten_bonus: int = 0
var _order_changed_round: int = -1

## Perder este combate es game over (fatal_at del monstruo y Momento del inicio, monstruos.md).
var fatal: bool = false
## XP que da vencer (la fija AdventureRules: según d y, en un grupo, por cada enemigo).
var victory_xp: int = 0
## Niveles que alcanza el Adoc si vence, en orden (los calcula AdventureRules al empezar), para
## anunciarlos en el combate tras la victoria.
var level_ups: Array[int] = []
## XP de cada enemigo de un grupo (la que no se da si huye) y niveles que se alcanzarían sin ella.
var enemy_xp: int = 0
var level_ups_fled: Array[int] = []
## Pagos: peaje del Bosque (N, con hostilidad), si el rival acepta Luz u ofrendas, copia del
## inventario ([{ id, luz }]) y la ofrenda entregada (índice en `ofrendas`, -1 = ninguna).
var toll: int = 0
var accepts_payment: bool = true
var ofrendas: Array = []
var ofrenda_index: int = -1
## El Adoc pelea sin arma (ATQ base): el combate lo avisa al empezar.
var unarmed: bool = false
## Golpe fuerte (skill): cada cuántos turnos (0 = sin la skill), multiplicador y turnos que faltan
## para que vuelva a estar listo (0 = listo).
var strong_every: int = 0
var strong_factor: float = 1.0
var strong_cooldown: int = 0
## Botín (skill): ofrenda que deja el rival al vencerlo (&"" = ninguna) y si cupo en la bolsa (lo
## escribe AdventureRules al aplicar la victoria).
var loot_id: StringName = &""
var loot_taken: bool = false

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


## `adoc` = { max_hp, atk, def, agi } del nivel del Adoc (AdventureRules.adoc_combat_stats). `unico` =
## { name, max_hp, atk, def } (ver AdventureRules.make_unico) y, opcionalmente, special_every,
## special_factor, texts, agi, ai, role, area_attack y special_area. Más enemigos con add_enemy;
## aliados con add_ally.
func _init(balance_data: Dictionary, adoc: Dictionary, hp: int, luz_amount: int, unico: Dictionary, rng_seed: int) -> void:
	balance = balance_data
	tactics = balance_data.get("tactics", {})
	rng.seed = rng_seed
	order_rng.seed = rng_seed + ORDER_SALT
	adoc_max_hp = int(adoc.max_hp)
	adoc_hp = clampi(hp, 1, adoc_max_hp)
	adoc_atk = int(adoc.atk)
	adoc_def = int(adoc.def)
	adoc_agi = int(adoc.get("agi", (balance_data.get("levels", {}) as Dictionary).get("agi_base", 0)))
	luz = luz_amount
	luz_max = int(balance_data.get("adoc", {}).get("luz_max", 10))
	add_enemy(unico)


## Añade un enemigo (mismo formato que `unico` en _init). Con rol, suma su bonificación; el apoyo va
## detrás y el resto delante mientras quepa (front_max).
func add_enemy(unico: Dictionary) -> void:
	var role: StringName = StringName(str(unico.get("role", "")))
	var en: Dictionary = {
		"name": str(unico.name),
		"hp": int(unico.max_hp),
		"max_hp": int(unico.max_hp),
		"atk": int(unico.atk) + _role_num(role, "atk_bonus", 0),
		"def": int(unico.def) + _role_num(role, "def_bonus", 0),
		"special_every": int(unico.get("special_every", 0)),
		"special_factor": float(unico.get("special_factor", 1.0)),
		"attacks": 0,
		"texts": unico.get("texts", {}),
		"agi": int(unico.get("agi", 0)),
		"ai": StringName(str(unico.get("ai", ""))),
		"role": role,
		"area_attack": bool(unico.get("area_attack", false)),
		"special_area": bool(unico.get("special_area", false)),
		"attack_range": unico.get("attack_range", [1, 1]),
		"gone": false,
	}
	_give_role_uses(en)
	en.row = _starting_row(enemies, role)
	enemies.append(en)
	_order_dirty = true


## Añade un aliado: { name, max_hp, atk, def, kind } (y opcionalmente hp, agi y role). Empieza en
## pie, en la fila de su rol (el apoyo detrás).
func add_ally(ally: Dictionary) -> void:
	var max_hp: int = maxi(1, int(ally.max_hp))
	var role: StringName = StringName(str(ally.get("role", "")))
	var al: Dictionary = {
		"name": str(ally.name),
		"hp": clampi(int(ally.get("hp", max_hp)), 1, max_hp),
		"max_hp": max_hp,
		"atk": int(ally.atk) + _role_num(role, "atk_bonus", 0),
		"def": int(ally.def) + _role_num(role, "def_bonus", 0),
		"kind": StringName(str(ally.get("kind", "adoc"))),
		"retired": false,
		"agi": int(ally.get("agi", 0)),
		"role": role,
		"defending": false,
		"cheer": 0,
	}
	_give_role_uses(al)
	var side: Array[Dictionary] = allies.duplicate()
	side.append({ "row": adoc_row, "role": ROLE_NONE })
	al.row = _starting_row(side, role)
	allies.append(al)
	_order_dirty = true


func _give_role_uses(c: Dictionary) -> void:
	c.heals_left = _role_num(c.role, "heal_uses", 0) if c.role == ROLE_SUPPORT else 0
	c.cheers_left = _role_num(c.role, "cheer_uses", 0) if c.role == ROLE_SUPPORT else 0
	c.finishes_left = _role_num(c.role, "finish_uses", 0) if c.role == ROLE_ATTACKER else 0
	c.cover_ready = 0


func _starting_row(side: Array[Dictionary], role: StringName) -> int:
	if role == ROLE_SUPPORT:
		return BACK
	var front: int = 0
	for c: Dictionary in side:
		if int(c.get("row", FRONT)) == FRONT:
			front += 1
	return FRONT if front < _front_max() else BACK


## Fórmula de Atacar: max(min_damage, ATQ - DEF + roll).
static func attack_damage(atk: int, def: int, roll: int, min_damage: int) -> int:
	return maxi(min_damage, atk - def + roll)


## Ataque conjunto (monstruos.md): la suma de los ATQ de los atacantes, con la DEF del objetivo
## restada una sola vez.
static func joint_damage(atks: Array, def: int, roll: int, min_damage: int) -> int:
	var total: float = 0.0
	for a: Variant in atks:
		total += float(a)
	return attack_damage(roundi(total), def, roll, min_damage)


## El ataque número `n` del rival (desde 1) es el especial.
static func is_special_attack(n: int, every: int) -> bool:
	return every > 0 and n % every == 0


## Golpe recibido con Defender activo: se reduce redondeando hacia arriba.
static func defended_damage(damage: int, factor: float) -> int:
	return ceili(damage * factor)


## Daño con modificadores de la IA de combate (desde detrás, Esperar, Apresurar, Remate): primero el
## factor (redondeado) y luego el bono plano, sin bajar de `min_damage`. Sin modificadores, el mismo.
static func modified_damage(damage: int, factor: float, flat: int, min_damage: int) -> int:
	if is_equal_approx(factor, 1.0) and flat == 0:
		return damage
	return maxi(min_damage, roundi(damage * factor) + flat)


## Golpe fuerte listo: el Adoc tiene la skill y ya pasaron sus turnos de espera.
func is_strong_ready() -> bool:
	return strong_every > 0 and strong_cooldown <= 0


## Daño de un Golpe fuerte (redondeado).
static func strong_damage(damage: int, factor: float) -> int:
	return roundi(damage * factor)


## Hay más de un enemigo (la escena dibuja la fila y pregunta el objetivo).
func is_group() -> bool:
	return enemies.size() > 1


## Hay formación (filas): más de un combatiente en algún bando. El 1 contra 1 no tiene.
func has_formation() -> bool:
	return is_group() or not allies.is_empty()


## Uno contra uno: un solo enemigo y ningún aliado.
func is_solo() -> bool:
	return enemies.size() == 1 and allies.is_empty()


func is_alive(index: int) -> bool:
	return index >= 0 and index < enemies.size() and int(enemies[index].hp) > 0 and not enemies[index].gone


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


## Cambiar de fila: solo con formación.
func can_switch_row() -> bool:
	return not is_over() and has_formation()


## Se puede dar una orden al grupo: hay aliados en pie y no se ha cambiado en esta ronda.
func can_change_order() -> bool:
	return not is_over() and not active_allies().is_empty() and _order_changed_round != round_number


## Da una orden al grupo (no gasta turno; una vez por ronda). Devuelve si se aplicó.
func set_group_order(order: GroupOrder) -> bool:
	if not can_change_order():
		return false
	group_order = order
	_order_changed_round = round_number
	return true


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


## Juega una ronda completa en el orden de iniciativa: el Adoc con `action`, sus aliados y los
## enemigos que sigan en pie. `target`: enemigo al que ataca el Adoc (si no vale o es -1, el de menos
## PV).
## Devuelve eventos para narrar, en orden: { "kind": StringName, "amount": int, y el estado justo
## después del evento: "unico_hp" (el primer enemigo), "enemy_hp" y "ally_hp" (listas; un enemigo que
## huyó o se retiró sale con 0), "adoc_hp", "luz" } (la UI actualiza las barras con cada uno).
## kind: attack ("target"; "hasten", "wait", "back", "strong" y "covered" si aplican), defend,
## offer_luz (paga el peaje: "amount" = Luz entregada; le sigue unico_leaves y el combate acaba
## APPEASED), flee_ok, flee_fail, switch_row ("actor" = TARGET_ADOC o aliado, "row"), ally_attack
## ("actor" = aliado, "target" = enemigo; "finish" con Remate, "back", "covered"), ally_defend,
## cover ("actor", "target" = protegido del bando del jugador), bandage y cheer ("actor", "target",
## "amount" = PV curados o ATQ extra), enemy_down ("target": un enemigo de un grupo cae),
## unico_attack y unico_special ("actor" = enemigo, "target" = TARGET_ADOC o aliado, "covered" =
## a quién iba si un defensor lo cubrió; el especial lleva además "defended": bool y "area"),
## group_attack (ataque conjunto: "target", "attackers" = cuántos, "defended", "area"),
## enemy_cover y enemy_bandage ("actor", "target" = enemigo), enemy_flees y enemy_retreats ("actor"),
## ally_retires ("actor"), special_warning ("actor"; aviso del especial del turno siguiente),
## victory, defeat.
## Una acción no válida (Ofrecer Luz sin Luz o contra el Ofomni, cambiar de fila sin formación,
## combate acabado) devuelve [] y no consume turno.
## La ofrenda no se juega aquí: va por offer_ofrenda. La victoria lleva además "xp", "level_ups" y
## "loot" (id de la ofrenda del Botín, "" si no hay). Un ataque con Golpe fuerte lleva "strong".
func play_turn(action: Action, target: int = -1) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if is_over() or (action == Action.OFFER_LUZ and not can_offer_luz()) or action == Action.OFRENDA:
		return events
	if action == Action.SWITCH_ROW and not can_switch_row():
		return events
	if not is_alive(target):
		target = default_target()
	if strong_cooldown > 0:
		strong_cooldown -= 1
	if action == Action.OFFER_LUZ:
		var paid: int = luz_cost()
		luz -= paid
		result = Result.APPEASED
		events.append(_event(&"offer_luz", paid))
		events.append(_event(&"unico_leaves"))
		return events
	round_number += 1
	var plans: Dictionary = {}
	for i: int in active_allies():
		plans[i] = _plan_ally(i)
	turn_order()
	for slot: Dictionary in _resolve_order(action, plans):
		match slot.side:
			SLOT_ADOC:
				if adoc_hp > 0:
					_adoc_act(action, target, events)
					if result == Result.FLED:
						return events
			SLOT_ALLY:
				if not allies[slot.index].retired:
					_ally_act(int(slot.index), plans.get(slot.index, { "kind": PLAN_ATTACK }), target, events)
			SLOT_ENEMY:
				if is_alive(int(slot.index)):
					_enemy_act(int(slot.index), events)
			SLOT_GROUP:
				_joint_phase(events)
		if _check_victory(events):
			return events
		if adoc_hp <= 0:
			defending = false
			result = Result.DEFEAT
			events.append(_event(&"defeat"))
			return events
	_end_round(action, events)
	return events


## Orden de la ronda con lo elegido: Defender (el Adoc) y Defender o Cubrir (aliados) primero;
## Esperar, el último; el resto, por `round_order`.
func _resolve_order(action: Action, plans: Dictionary) -> Array[Dictionary]:
	var first: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	var last: Array[Dictionary] = []
	for slot: Dictionary in round_order:
		match slot.side:
			SLOT_ADOC:
				if action == Action.WAIT:
					last.append(slot)
				elif action == Action.DEFEND:
					first.append(slot)
				else:
					rest.append(slot)
			SLOT_ALLY:
				var kind: StringName = (plans.get(slot.index, {}) as Dictionary).get("kind", PLAN_ATTACK)
				if kind == PLAN_DEFEND or kind == PLAN_COVER:
					first.append(slot)
				else:
					rest.append(slot)
			_:
				rest.append(slot)
	first.append_array(rest)
	first.append_array(last)
	return first


func _end_round(action: Action, events: Array[Dictionary]) -> void:
	defending = false
	for al: Dictionary in allies:
		al.defending = false
		al.cheer = maxi(0, int(al.cheer) - 1)
	adoc_cheer = maxi(0, adoc_cheer - 1)
	for j: int in alive_enemies():
		var en: Dictionary = enemies[j]
		if is_special_attack(int(en.attacks) + 1, int(en.special_every)):
			var w: Dictionary = _event(&"special_warning")
			w.actor = j
			events.append(w)
	_hasten_bonus = _ini("hasten_agi", 0) if action == Action.HASTEN else 0
	_roll_order()


# --- Iniciativa -----------------------------------------------------------------------------------

## Orden de la próxima ronda: [{ side (SLOT_*), index, score }], de primero a último, sin contar
## Defender, Cubrir ni Esperar. Lo tira si hace falta (al empezar o si cambió algo con refresh_order).
func turn_order() -> Array[Dictionary]:
	if _order_dirty:
		_roll_order()
	return round_order


## Vuelve a tirar el orden de la próxima ronda (tras cambiar a mano la AGI o la composición).
func refresh_order() -> void:
	_order_dirty = true

## Tira el orden de la próxima ronda (`round_order`). En el 1 contra 1 no hay tirada: el Adoc va
## primero salvo que el rival le saque solo_lead de AGI o más.
func _roll_order() -> void:
	_order_dirty = false
	var slots: Array[Dictionary] = []
	var lo: int = _ini("roll_min", 0)
	var hi: int = maxi(lo, _ini("roll_max", 0))
	if is_solo():
		var lead: bool = int(enemies[0].agi) - (adoc_agi + _hasten_bonus) >= _ini("solo_lead", 3)
		slots.append(_slot(SLOT_ADOC, TARGET_ADOC, 1))
		if is_alive(0):
			slots.append(_slot(SLOT_GROUP if joint_attack else SLOT_ENEMY, -1 if joint_attack else 0, 2 if lead else 0))
		_sort_order(slots)
		round_order = slots
		return
	if adoc_hp > 0:
		slots.append(_slot(SLOT_ADOC, TARGET_ADOC, adoc_agi + _hasten_bonus + _order_roll(lo, hi)))
	for i: int in active_allies():
		slots.append(_slot(SLOT_ALLY, i, int(allies[i].agi) + _order_roll(lo, hi)))
	var alive: Array[int] = alive_enemies()
	if joint_attack:
		if not alive.is_empty():
			var fastest: int = -9999
			for j: int in alive:
				fastest = maxi(fastest, int(enemies[j].agi))
			slots.append(_slot(SLOT_GROUP, -1, fastest + _order_roll(lo, hi)))
	else:
		for j: int in alive:
			slots.append(_slot(SLOT_ENEMY, j, int(enemies[j].agi) + _order_roll(lo, hi)))
	_sort_order(slots)
	round_order = slots


func _order_roll(lo: int, hi: int) -> int:
	return lo if lo == hi else order_rng.randi_range(lo, hi)


static func _slot(side: StringName, index: int, score: int) -> Dictionary:
	return { "side": side, "index": index, "score": score }


static func _sort_order(slots: Array[Dictionary]) -> void:
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.score) != int(b.score):
			return int(a.score) > int(b.score)
		var ra: int = _side_rank(a.side)
		var rb: int = _side_rank(b.side)
		if ra != rb:
			return ra < rb
		return int(a.index) < int(b.index))


static func _side_rank(side: StringName) -> int:
	match side:
		SLOT_ADOC:
			return 0
		SLOT_ALLY:
			return 1
	return 2


# --- El Adoc --------------------------------------------------------------------------------------

func _adoc_act(action: Action, target: int, events: Array[Dictionary]) -> void:
	match action:
		Action.ATTACK, Action.HASTEN, Action.WAIT:
			var t: int = target if is_alive(target) else default_target()
			if t < 0:
				return
			var cheer: int = _role_num(ROLE_SUPPORT, "cheer_atk", 0) if adoc_cheer > 0 else 0
			adoc_cheer = 0
			var hit: Dictionary = _enemy_cover_redirect(t)
			var dmg: int = _roll_attack(adoc_atk + cheer, int(enemies[hit.target].def))
			var strong: bool = is_strong_ready()
			if strong:
				dmg = strong_damage(dmg, strong_factor)
				strong_cooldown = strong_every
			var factor: float = 1.0
			var flat: int = 0
			var back: bool = has_formation() and adoc_row == BACK
			if back:
				factor *= _form("back_factor", 0.75)
			if action == Action.WAIT:
				factor *= float(_ini_f("wait_factor", 1.25))
			if action == Action.HASTEN:
				flat += _ini("hasten_damage", -2)
			dmg = modified_damage(dmg, factor, flat, _min_damage())
			player_target = t
			_hurt_enemy(int(hit.target), dmg)
			var a: Dictionary = _event(&"attack", dmg)
			a.target = int(hit.target)
			if strong:
				a.strong = true
			if action == Action.HASTEN:
				a.hasten = true
			if action == Action.WAIT:
				a.wait = true
			if back:
				a.back = true
			if hit.has("covered"):
				a.covered = int(hit.covered)
			events.append(a)
			_note_down(int(hit.target), events)
		Action.DEFEND:
			defending = true
			events.append(_event(&"defend"))
		Action.FLEE:
			if rng.randf() < float(balance.flee_chance):
				result = Result.FLED
				events.append(_event(&"flee_ok"))
				return
			events.append(_event(&"flee_fail"))
		Action.SWITCH_ROW:
			adoc_row = BACK if adoc_row == FRONT else FRONT
			var e: Dictionary = _event(&"switch_row")
			e.actor = TARGET_ADOC
			e.row = adoc_row
			events.append(e)


# --- Aliados --------------------------------------------------------------------------------------

## Plan de un aliado para esta ronda (ia-de-combate.md, secciones 4 y 5). Determinista y sin RNG:
## { kind, target }. El objetivo de un ataque se vuelve a elegir al actuar.
func _plan_ally(i: int) -> Dictionary:
	var al: Dictionary = allies[i]
	var role: StringName = al.role
	if role == ROLE_NONE:
		return { "kind": PLAN_ATTACK }
	var finish: int = _finish_target(al)
	match group_order:
		GroupOrder.ATTACK:
			var t: int = player_target if is_alive(player_target) else _weakest_enemy()
			if finish >= 0 and t >= 0 and _ratio_enemy(t) < _ai("finish_below", 0.3):
				return { "kind": PLAN_FINISH, "target": t }
			return { "kind": PLAN_ATTACK }
		GroupOrder.DEFEND:
			if role == ROLE_SUPPORT and int(al.heals_left) > 0:
				var hurt: int = _lowest_player_ratio(1.0)
				if hurt != -2:
					return { "kind": PLAN_BANDAGE, "target": hurt }
			if role == ROLE_DEFENDER and _cover_ready(al):
				var weak: int = _lowest_player_ratio(1.01, i)
				if weak != -2:
					return { "kind": PLAN_COVER, "target": weak }
			if finish >= 0:
				return { "kind": PLAN_FINISH, "target": finish }
			return { "kind": PLAN_DEFEND }
	# Libre.
	var low: int = _lowest_player_ratio(_ai("help_below", 0.3))
	if low != -2:
		if role == ROLE_SUPPORT and int(al.heals_left) > 0:
			return { "kind": PLAN_BANDAGE, "target": low }
		if role == ROLE_DEFENDER and _cover_ready(al) and low != i:
			return { "kind": PLAN_COVER, "target": low }
	if _special_announced():
		if role == ROLE_DEFENDER:
			var front: int = _weakest_front(i)
			if _cover_ready(al) and front != -2:
				return { "kind": PLAN_COVER, "target": front }
		return { "kind": PLAN_DEFEND }
	if role != ROLE_DEFENDER and _ratio_ally(i) < _ai("retreat_below", 0.2):
		return { "kind": PLAN_SWITCH } if int(al.row) == FRONT else { "kind": PLAN_DEFEND }
	if finish >= 0:
		return { "kind": PLAN_FINISH, "target": finish }
	if role == ROLE_SUPPORT and int(al.cheers_left) > 0:
		return { "kind": PLAN_CHEER, "target": _cheer_target() }
	return { "kind": PLAN_ATTACK }


func _ally_act(i: int, plan: Dictionary, adoc_target: int, events: Array[Dictionary]) -> void:
	var al: Dictionary = allies[i]
	_drop_covers(ally_covers, i)
	var kind: StringName = plan.get("kind", PLAN_ATTACK)
	match kind:
		PLAN_DEFEND:
			al.defending = true
			var d: Dictionary = _event(&"ally_defend")
			d.actor = i
			events.append(d)
			return
		PLAN_COVER:
			var who: int = int(plan.target)
			if who == TARGET_ADOC or (who >= 0 and not allies[who].retired):
				ally_covers[who] = i
				al.cover_ready = round_number + _role_num(ROLE_DEFENDER, "cover_every", 2)
				var c: Dictionary = _event(&"cover")
				c.actor = i
				c.target = who
				events.append(c)
				return
		PLAN_BANDAGE:
			var patient: int = int(plan.target)
			if patient == TARGET_ADOC or (patient >= 0 and not allies[patient].retired):
				al.heals_left = int(al.heals_left) - 1
				var healed: int = _heal_player(patient)
				var b: Dictionary = _event(&"bandage", healed)
				b.actor = i
				b.target = patient
				events.append(b)
				return
		PLAN_CHEER:
			var who: int = int(plan.target)
			al.cheers_left = int(al.cheers_left) - 1
			if who == TARGET_ADOC:
				adoc_cheer = 2
			else:
				allies[who].cheer = 2
			var ch: Dictionary = _event(&"cheer", _role_num(ROLE_SUPPORT, "cheer_atk", 0))
			ch.actor = i
			ch.target = who
			events.append(ch)
			return
		PLAN_SWITCH:
			al.row = BACK if int(al.row) == FRONT else FRONT
			var s: Dictionary = _event(&"switch_row")
			s.actor = i
			s.row = al.row
			events.append(s)
			return
	# Atacar (o Remate).
	var t: int = -1
	var finish: bool = false
	if kind == PLAN_FINISH and is_alive(int(plan.get("target", -1))) and int(al.finishes_left) > 0:
		t = int(plan.target)
		finish = true
	elif al.role == ROLE_NONE:
		t = adoc_target if is_alive(adoc_target) else default_target()
	elif group_order == GroupOrder.ATTACK and is_alive(player_target):
		t = player_target
	else:
		t = _weakest_enemy()
	if t < 0:
		return
	var cheer: int = _role_num(ROLE_SUPPORT, "cheer_atk", 0) if int(al.cheer) > 0 else 0
	al.cheer = 0
	var hit: Dictionary = _enemy_cover_redirect(t)
	var dmg: int = _roll_attack(int(al.atk) + cheer, int(enemies[hit.target].def))
	var factor: float = 1.0
	var flat: int = 0
	var back: bool = int(al.row) == BACK
	if back:
		factor *= _form("back_factor", 0.75)
	if finish:
		flat += _role_num(ROLE_ATTACKER, "finish_bonus", 0)
		al.finishes_left = int(al.finishes_left) - 1
	dmg = modified_damage(dmg, factor, flat, _min_damage())
	_hurt_enemy(int(hit.target), dmg)
	var e: Dictionary = _event(&"ally_attack", dmg)
	e.actor = i
	e.target = int(hit.target)
	if finish:
		e.finish = true
	if back:
		e.back = true
	if hit.has("covered"):
		e.covered = int(hit.covered)
	events.append(e)
	_note_down(int(hit.target), events)


## Objetivo de Remate para un atacante con usos: el enemigo en pie por debajo de finish_below con
## menos PV (-1 si no hay).
func _finish_target(c: Dictionary) -> int:
	if c.role != ROLE_ATTACKER or int(c.finishes_left) <= 0:
		return -1
	var best: int = -1
	for j: int in alive_enemies():
		if _ratio_enemy(j) < _ai("finish_below", 0.3) and (best < 0 or int(enemies[j].hp) < int(enemies[best].hp)):
			best = j
	return best


## Objetivo de Atacar de un aliado: el enemigo con menos PV; empate, el de más ATQ; luego el primero.
func _weakest_enemy() -> int:
	var best: int = -1
	for j: int in alive_enemies():
		if best < 0:
			best = j
			continue
		var hj: int = int(enemies[j].hp)
		var hb: int = int(enemies[best].hp)
		if hj < hb or (hj == hb and int(enemies[j].atk) > int(enemies[best].atk)):
			best = j
	return best


## Del bando del jugador, quien tiene la menor fracción de PV por debajo de `below` (TARGET_ADOC o
## índice de aliado; -2 si nadie). `skip`: aliado que no cuenta.
func _lowest_player_ratio(below: float, skip: int = -99) -> int:
	var best: int = -2
	var best_ratio: float = below
	for ref: int in _player_refs():
		if ref == skip:
			continue
		var r: float = _ratio_player(ref)
		if r < best_ratio:
			best = ref
			best_ratio = r
	return best


## Quien está delante con menos PV (sin contar a `skip`; -2 si nadie).
func _weakest_front(skip: int) -> int:
	var best: int = -2
	for ref: int in _player_refs():
		if ref == skip or _player_row(ref) != FRONT:
			continue
		if best == -2 or _player_hp(ref) < _player_hp(best):
			best = ref
	return best


## A quién anima el apoyo: el atacante aliado de delante con más ATQ; si no hay, el Adoc.
func _cheer_target() -> int:
	var best: int = TARGET_ADOC
	for i: int in active_allies():
		if allies[i].role == ROLE_ATTACKER and int(allies[i].row) == FRONT:
			if best == TARGET_ADOC or int(allies[i].atk) > int(allies[best].atk):
				best = i
	return best


func _cover_ready(c: Dictionary) -> bool:
	return c.role == ROLE_DEFENDER and round_number >= int(c.cover_ready)


## Algún enemigo en pie hará su ataque especial en esta ronda (se anunció en la anterior).
func _special_announced() -> bool:
	for j: int in alive_enemies():
		var en: Dictionary = enemies[j]
		if is_special_attack(int(en.attacks) + 1, int(en.special_every)):
			return true
	return false


func _heal_player(ref: int) -> int:
	var max_hp: int = _player_max_hp(ref)
	var amount: int = mini(ceili(max_hp * _role_num(ROLE_SUPPORT, "heal_pct", 0) / 100.0), max_hp - _player_hp(ref))
	if ref == TARGET_ADOC:
		adoc_hp += amount
	else:
		allies[ref].hp = int(allies[ref].hp) + amount
	return amount


# --- Enemigos -------------------------------------------------------------------------------------

## Un enemigo que actúa por su cuenta (no de ataque conjunto).
func _enemy_act(j: int, events: Array[Dictionary]) -> void:
	var en: Dictionary = enemies[j]
	_drop_covers(enemy_covers, j)
	if en.ai == AI_TACTICAL and _tactical_move(j, events):
		return
	en.attacks = int(en.attacks) + 1
	var special: bool = is_special_attack(int(en.attacks), int(en.special_every))
	if special and en.special_area:
		_area_special(j, events)
		return
	var pick: Dictionary = _pick_player_target(en.ai)
	var tgt: int = int(pick.target)
	var hit: int = _roll_attack(int(en.atk), _target_def(tgt))
	if special:
		hit = roundi(hit * float(en.special_factor))
	var factor: float = _form("back_factor", 0.75) if int(en.row) == BACK else 1.0
	var flat: int = 0
	var finish: bool = false
	if en.ai == AI_TACTICAL and en.role == ROLE_ATTACKER and int(en.finishes_left) > 0 and _ratio_player(tgt) < _ai("finish_below", 0.3):
		flat += _role_num(ROLE_ATTACKER, "finish_bonus", 0)
		en.finishes_left = int(en.finishes_left) - 1
		finish = true
	hit = modified_damage(hit, factor, flat, _min_damage())
	var defended: bool = _is_defending(tgt)
	if defended:
		hit = defended_damage(hit, float(balance.defend_factor))
	_hurt_target(tgt, hit)
	var e: Dictionary = _event(&"unico_special" if special else &"unico_attack", hit)
	if special:
		e.defended = defended
	if enemies.size() > 1 or not allies.is_empty():
		e.actor = j
		e.target = tgt
	if pick.has("covered"):
		e.covered = int(pick.covered)
	if finish:
		e.finish = true
	events.append(e)
	_note_retired(tgt, events)


## Especial en área (Latigazo múltiple): una tirada, un golpe a cada uno de la fila delantera.
func _area_special(j: int, events: Array[Dictionary]) -> void:
	var en: Dictionary = enemies[j]
	var a: Dictionary = balance.attack
	var roll: int = rng.randi_range(int(a.roll_min), int(a.roll_max))
	for ref: int in _area_row():
		var tgt: int = ref
		var covered: int = -2
		if ally_covers.has(ref) and _cover_active(ally_covers, ref):
			tgt = int(ally_covers[ref])
			covered = ref
		if tgt != TARGET_ADOC and allies[tgt].retired:
			continue
		var hit: int = roundi(attack_damage(int(en.atk), _target_def(tgt), roll, int(a.min_damage)) * float(en.special_factor))
		hit = modified_damage(hit, _form("back_factor", 0.75) if int(en.row) == BACK else 1.0, 0, _min_damage())
		var defended: bool = _is_defending(tgt)
		if defended:
			hit = defended_damage(hit, float(balance.defend_factor))
		_hurt_target(tgt, hit)
		var e: Dictionary = _event(&"unico_special", hit)
		e.defended = defended
		e.area = true
		if enemies.size() > 1 or not allies.is_empty():
			e.actor = j
			e.target = tgt
		if covered != -2:
			e.covered = covered
		events.append(e)
		_note_retired(tgt, events)
		if adoc_hp <= 0:
			return


## Perfil táctico (garelinos): retirarse con poca vida, Cubrir o Vendar a un compañero herido.
## Devuelve si gastó el turno.
func _tactical_move(j: int, events: Array[Dictionary]) -> bool:
	var en: Dictionary = enemies[j]
	if _ratio_enemy(j) < _ai("tactical_retreat_below", 0.25):
		en.gone = true
		var r: Dictionary = _event(&"enemy_retreats")
		r.actor = j
		events.append(r)
		return true
	var low: int = -1
	for k: int in alive_enemies():
		if _ratio_enemy(k) < _ai("help_below", 0.3) and (low < 0 or _ratio_enemy(k) < _ratio_enemy(low)):
			low = k
	if low < 0:
		return false
	if en.role == ROLE_SUPPORT and int(en.heals_left) > 0:
		en.heals_left = int(en.heals_left) - 1
		var t: Dictionary = enemies[low]
		var amount: int = mini(ceili(int(t.max_hp) * _role_num(ROLE_SUPPORT, "heal_pct", 0) / 100.0), int(t.max_hp) - int(t.hp))
		t.hp = int(t.hp) + amount
		var b: Dictionary = _event(&"enemy_bandage", amount)
		b.actor = j
		b.target = low
		events.append(b)
		return true
	if en.role == ROLE_DEFENDER and low != j and _cover_ready(en):
		enemy_covers[low] = j
		en.cover_ready = round_number + _role_num(ROLE_DEFENDER, "cover_every", 2)
		var c: Dictionary = _event(&"enemy_cover")
		c.actor = j
		c.target = low
		events.append(c)
		return true
	return false


## Ataque conjunto del grupo: una sola acción. Con `area_attack` y más de uno en pie, golpea a toda la
## fila delantera; si no, a un objetivo. Un enjambre que se queda en uno con poca vida huye.
func _joint_phase(events: Array[Dictionary]) -> void:
	var alive: Array[int] = alive_enemies()
	if alive.is_empty():
		return
	var lead: Dictionary = enemies[alive[0]]
	for j: int in alive:
		_drop_covers(enemy_covers, j)
	if alive.size() == 1 and lead.ai == AI_SWARM and is_group() and _ratio_enemy(alive[0]) < _ai("swarm_flee_below", 0.3):
		lead.gone = true
		victory_xp = maxi(0, victory_xp - enemy_xp)
		level_ups = level_ups_fled.duplicate()
		var f: Dictionary = _event(&"enemy_flees")
		f.actor = alive[0]
		events.append(f)
		return
	var atks: Array = []
	var area: bool = false
	for j: int in alive:
		atks.append(int(enemies[j].atk) * (_form("back_factor", 0.75) if int(enemies[j].row) == BACK else 1.0))
		area = area or bool(enemies[j].area_attack)
	area = area and alive.size() > 1
	var a: Dictionary = balance.attack
	if not area:
		var pick: Dictionary = _pick_player_target(lead.ai)
		var tgt: int = int(pick.target)
		var roll: int = rng.randi_range(int(a.roll_min), int(a.roll_max))
		_joint_hit(tgt, atks, roll, false, pick.get("covered", -2), events)
		return
	var roll_area: int = rng.randi_range(int(a.roll_min), int(a.roll_max))
	for ref: int in _area_row():
		var tgt: int = ref
		var covered: int = -2
		if ally_covers.has(ref) and _cover_active(ally_covers, ref):
			tgt = int(ally_covers[ref])
			covered = ref
		if tgt != TARGET_ADOC and allies[tgt].retired:
			continue
		_joint_hit(tgt, atks, roll_area, true, covered, events)
		if adoc_hp <= 0:
			return


func _joint_hit(tgt: int, atks: Array, roll: int, area: bool, covered: int, events: Array[Dictionary]) -> void:
	var hit: int = joint_damage(atks, _target_def(tgt), roll, _min_damage())
	if area:
		hit = modified_damage(hit, _form("area_factor", 1.0), 0, _min_damage())
	var defended: bool = false
	if _is_defending(tgt):
		hit = defended_damage(hit, float(balance.defend_factor))
		defended = true
	_hurt_target(tgt, hit)
	var e: Dictionary = _event(&"group_attack", hit)
	e.target = tgt
	e.attackers = atks.size()
	e.defended = defended
	if area:
		e.area = true
	if covered != -2:
		e.covered = covered
	events.append(e)
	_note_retired(tgt, events)


## A quién ataca un enemigo del bando del jugador: primero la fila (delante con front_chance si las
## dos tienen a alguien; si no, la que quede) y dentro de ella según el perfil: sin perfil, al azar
## (sin tirar si solo hay uno); agresivo y berserk, el de menos PV; táctico, el apoyo y si no el de
## menos PV; enjambre, el de menos DEF. Un defensor que cubre al elegido se lleva el golpe.
## { target, covered (si lo cubrieron) }.
func _pick_player_target(ai: StringName) -> Dictionary:
	var front: Array[int] = []
	var back: Array[int] = []
	for ref: int in _player_refs():
		if _player_row(ref) == FRONT or not has_formation():
			front.append(ref)
		else:
			back.append(ref)
	var row: Array[int] = front
	if not front.is_empty() and not back.is_empty():
		row = front if rng.randf() < _form("front_chance", 0.75) else back
	elif front.is_empty():
		row = back
	var t: int = row[0]
	match ai:
		AI_AGGRESSIVE, AI_BERSERK, AI_GUARDIAN, AI_WHIP, AI_AMBUSHER:
			t = _min_by(row, func(r: int) -> int: return _player_hp(r))
		AI_SWARM:
			t = _min_by(row, func(r: int) -> int: return _target_def(r))
		AI_TACTICAL:
			var supports: Array[int] = []
			for r: int in row:
				if r != TARGET_ADOC and allies[r].role == ROLE_SUPPORT:
					supports.append(r)
			t = _min_by(supports if not supports.is_empty() else row, func(r: int) -> int: return _player_hp(r))
		_:
			if row.size() > 1:
				t = row[rng.randi_range(0, row.size() - 1)]
	var out: Dictionary = { "target": t }
	if ally_covers.has(t) and _cover_active(ally_covers, t):
		out.target = int(ally_covers[t])
		out.covered = t
	return out


static func _min_by(refs: Array[int], key: Callable) -> int:
	var best: int = refs[0]
	for r: int in refs:
		if int(key.call(r)) < int(key.call(best)):
			best = r
	return best


## Fila que recibe un ataque en área: la delantera del bando del jugador, o la de detrás si delante
## no queda nadie.
func _area_row() -> Array[int]:
	var front: Array[int] = []
	var back: Array[int] = []
	for ref: int in _player_refs():
		if _player_row(ref) == FRONT or not has_formation():
			front.append(ref)
		else:
			back.append(ref)
	return front if not front.is_empty() else back


## El golpe del jugador o de un aliado a un enemigo cubierto va a su defensor.
func _enemy_cover_redirect(t: int) -> Dictionary:
	if enemy_covers.has(t):
		var k: int = int(enemy_covers[t])
		if k != t and is_alive(k):
			return { "target": k, "covered": t }
	return { "target": t }


func _cover_active(covers: Dictionary, ref: int) -> bool:
	var k: int = int(covers[ref])
	return k != ref and k >= 0 and k < allies.size() and not allies[k].retired


static func _drop_covers(covers: Dictionary, coverer: int) -> void:
	for key: Variant in covers.keys():
		if int(covers[key]) == coverer:
			covers.erase(key)


# --- Bando del jugador ----------------------------------------------------------------------------

## El Adoc (TARGET_ADOC) y los aliados en pie, en ese orden.
func _player_refs() -> Array[int]:
	var out: Array[int] = [TARGET_ADOC]
	out.append_array(active_allies())
	return out


func _player_row(ref: int) -> int:
	return adoc_row if ref == TARGET_ADOC else int(allies[ref].row)


func _player_hp(ref: int) -> int:
	return adoc_hp if ref == TARGET_ADOC else int(allies[ref].hp)


func _player_max_hp(ref: int) -> int:
	return adoc_max_hp if ref == TARGET_ADOC else int(allies[ref].max_hp)


func _ratio_player(ref: int) -> float:
	return float(_player_hp(ref)) / maxf(1.0, float(_player_max_hp(ref)))


func _ratio_ally(i: int) -> float:
	return _ratio_player(i)


func _ratio_enemy(j: int) -> float:
	return float(enemies[j].hp) / maxf(1.0, float(enemies[j].max_hp))


func _is_defending(tgt: int) -> bool:
	return defending if tgt == TARGET_ADOC else bool(allies[tgt].defending)


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
	_drop_covers(ally_covers, tgt)
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
	v.loot = String(loot_id)
	events.append(v)
	return true


func _event(kind: StringName, amount: int = 0) -> Dictionary:
	var e: Dictionary = { "kind": kind, "amount": amount, "unico_hp": 0 if enemies[0].gone else unico_hp, "adoc_hp": adoc_hp, "luz": luz }
	if is_group() or not allies.is_empty():
		e.enemy_hp = enemies.map(func(en: Dictionary) -> int: return 0 if en.gone else int(en.hp))
		e.ally_hp = allies.map(func(al: Dictionary) -> int: return int(al.hp))
	return e


func _roll_attack(atk: int, def: int) -> int:
	var a: Dictionary = balance.attack
	var roll: int = rng.randi_range(int(a.roll_min), int(a.roll_max))
	return attack_damage(atk, def, roll, int(a.min_damage))


func _min_damage() -> int:
	return int(balance.attack.min_damage)


# --- Números del bloque tactics -------------------------------------------------------------------

func _ini(key: String, fallback: int) -> int:
	return int((tactics.get("initiative", {}) as Dictionary).get(key, fallback))


func _ini_f(key: String, fallback: float) -> float:
	return float((tactics.get("initiative", {}) as Dictionary).get(key, fallback))


func _form(key: String, fallback: float) -> float:
	return float((tactics.get("formation", {}) as Dictionary).get(key, fallback))


## Sin bloque tactics no hay límite de la fila delantera (todos delante, como antes).
func _front_max() -> int:
	return int((tactics.get("formation", {}) as Dictionary).get("front_max", 99))


func _ai(key: String, fallback: float) -> float:
	return float((tactics.get("ai", {}) as Dictionary).get(key, fallback))


func _role_num(role: StringName, key: String, fallback: int) -> int:
	if role == ROLE_NONE:
		return fallback
	var roles: Dictionary = tactics.get("roles", {})
	return int((roles.get(String(role), {}) as Dictionary).get(key, fallback))
