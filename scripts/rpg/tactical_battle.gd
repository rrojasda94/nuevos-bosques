class_name TacticalBattle
extends RefCounted
## Turnos CT, movimiento, orientación y acciones del combate táctico (combate-tactico.md, ADR 0016;
## PR T2 y T3). Lógica pura sobre un TacticalBoard: no toca GameState ni la escena, y no sustituye
## todavía a BattleLogic (el combate por menú sigue en uso hasta T8). Números en
## data/combat/balance.json (bloque tactical; config_from_balance le añade attack, defend_factor,
## tactics.roles y tactics.ai.finish_below, que se comparten con el combate por menú).
## - Combatientes: [{ id, side, agi, cell?, facing?, max_hp?, hp?, atk?, def?, role?, leader?,
##   accepts_payment?, strong_every?, strong_factor?, special_every?, special_factor?, special_area?,
##   joint?, reserve?, attack_range?, attack_line?, afraid? }] (side: SIDE_PLAYER o SIDE_ENEMY).
##   attack_range: [mín, máx] de su ataque normal (por defecto [1, 1]; el Ofomni [1, 2]); attack_line
##   (por defecto true): solo en línea, sin enemigos en medio (TacticalRules.can_strike). afraid:
##   estado Miedo (suma fear_bonus a su huida). `home`: su casilla inicial (el guardián no se aleja).
##   Hasta board.max_per_side por bando (el cupo, TacticalArena) en el tablero, en el orden de la
##   lista; los demás (y los que traen `reserve`) esperan en su borde (`waiting`, sin casilla ni
##   turno). Sin `cell`, se colocan en las columnas de su lado (el jugador en `player_side`, los
##   enemigos en el opuesto). Sin `facing`, miran al bando contrario. El rol (attacker, defender,
##   support) suma atk_bonus/def_bonus y da sus usos.
## - Refuerzos (T1b): cuando cae o se retira uno del tablero, su bando gana una entrada pendiente;
##   al empezar el siguiente turno (begin_turn), el primero que espera de ese bando entra con CT
##   ct.reinforce_ct en la casilla libre más cercana a su borde (TacticalBoard.entry_cells; si no
##   hay ninguna libre, lo intenta en el turno siguiente). last_entries dice quién entró. Los que
##   esperan cuentan para el final: no hay victoria mientras quede un enemigo esperando.
## - Mov = mov_base + floor((AGI − mov_agi_ref) / mov_agi_div), entre mov_min y mov_max; Salto =
##   jump_base + floor(AGI / jump_agi_div); se baja hasta Salto + drop_extra.
## - CT: inicial AGI × start_per_agi; cada tick CT += AGI (al menos 1, para que nadie se quede
##   parado); juega quien tenga CT ≥ threshold. Si varios: más CT primero; empate, el bando del
##   jugador; dentro de un bando, un orden fijo sorteado con la seed (determinista). Tras el turno,
##   CT −= cost_move_and_act, cost_single o cost_wait. El sobrante de CT se conserva.
## - Turno: begin_turn() elige quién juega (y le quita el Defender y el Cubrir de su turno anterior);
##   move_active() mueve dentro de lo alcanzable (una vez); una acción (una vez); end_turn(facing)
##   fija la orientación y cobra el CT. wait_turn(facing) es Esperar: termina el turno sin actuar.
## - Por las casillas de los aliados se pasa, pero no se para; por las de los enemigos, ni eso.
## - preview_order(n): los próximos n turnos sin tocar el estado (línea de iconos de la UI).
## - Acciones (T3) del combatiente en su turno. Cada una devuelve su resultado como dato para la UI
##   (T4), o {} si no vale (y entonces no gasta la acción): { actor, kind, target, damage, missed,
##   text_key, result, ... }. text_key es la clave del texto corto de la acción (Texts): TEXT_MISS
##   ("Falla") si esquiva. Atacar (attack; con Remate, finish), Defender, Cubrir, Vendar, Animar,
##   Ofrecer Luz, Ofrecer ofrenda y Huir. Evasión, alcance y bonos en TacticalRules.
## - Un golpe: tirada de precisión (TacticalRules.hit_chance) y, si acierta, daño =
##   BattleLogic.attack_damage(ATQ + Animar, DEF, tirada) + bono de posición (flanco, espalda,
##   altura) + Remate; luego ×Golpe fuerte y ×defend_factor si quien lo recibe se defiende. Cubrir:
##   si el golpe acierta a un protegido y su defensor sigue vecino a él, se lo lleva el defensor (con
##   su DEF y el mismo bono de posición). Animar, Remate y Golpe fuerte solo se gastan si acierta.
## - Caídos (PV 0): se retiran del tablero (remove_unit). Victoria cuando no queda ningún enemigo
##   (ni en el tablero ni esperando);
##   derrota cuando no queda nadie del jugador o cae un combatiente `leader` (el adoc).
## - Ofrecer Luz u ofrenda (set_payment da el peaje, la Luz suelta y las ofrendas): paga y termina
##   el combate (APPEASED); no vale si algún enemigo en pie no acepta pagos. Huir (P1,
##   ajustes-playtest-0.5.md §1a): desde una casilla del borde, con una tirada de flee_chance (bloque
##   tactical.flee; el porcentaje se ve en el menú). Si sale bien, huye todo el bando (FLED; el
##   enemigo recupera PV porque el siguiente combate lo crea entero). Si falla, el turno termina (CT
##   como si hubiera actuado) y el siguiente intento suma retry_bonus.
## - Retirada por el borde (T5): leave() saca del tablero al combatiente en su turno si está en una
##   casilla del borde (el último reparep que huye, el garelino que se retira; TacticalAI decide
##   cuándo). Queda `fled` y no cuenta como caído; check_end puede dar la victoria.
## - Orden al grupo (T5): group_order (BattleLogic.GroupOrder; Libre por defecto) y player_target (el
##   último enemigo al que atacó el `leader`), que lee TacticalAI. Cambiarla no gasta acción.
## - Especiales (T6):
##   - Ataque de área anunciado (Latigazo múltiple del Ofomni; `special_area`): cuenta sus ataques
##     (`attacks`); al terminar el turno en el que su siguiente ataque sería el especial (cada
##     `special_every`), anuncia el área (`announce`: las casillas de board.latigazo delante de él,
##     según su orientación final; 3 x 1 en los tableros pequeño y medio, 3 x 2 en el grande). En su
##     siguiente turno, area_strike() golpea con una sola tirada a todos los enemigos que sigan
##     dentro: daño = BattleLogic.attack_damage(ATQ, DEF, tirada) × special_factor (×defend_factor si
##     se defiende), sin evasión ni Cubrir; salir del área lo esquiva. danger_cells() da las casillas
##     anunciadas contra un bando (IA y escena). Sin `special_area`, el especial es un golpe normal
##     × special_factor.
##   - Ataque conjunto (`joint`, los reparep): si el atacante tiene compañeros `joint` vecinos del
##     mismo objetivo (hasta actions.joint_max en total, uno por lado), atacan juntos en su turno:
##     una tirada de precisión con la mejor posición de todos (la evasión más baja), daño =
##     BattleLogic.joint_damage (suma de ATQ, DEF restada una vez) + el bono de esa posición, y
##     ×defend_factor si se defiende. Los compañeros gastan su siguiente turno: CT −cost_single.
##   - Apertura (apply_opening): SURPRISE (emboscada tuya: no te detectaron), tu bando en el tablero
##     empieza con CT threshold y los enemigos con menos (juegan después), de espaldas a ti; AMBUSH
##     (emboscada del enemigo), al revés. NORMAL: como siempre.
## - RNG propio sembrado con la seed del combate: las tiradas son deterministas. La IA (azar top-2,
##   P2) tira con ai_rng, sembrado también con la seed del combate (otra sal): así no mueve las
##   tiradas de los golpes.

const SIDE_PLAYER: int = 0
const SIDE_ENEMY: int = 1
## Ningún combatiente en su turno.
const NONE: int = -1
## Sal del RNG del desempate (se suma a la semilla del combate).
const TIE_SALT: int = 4271
## Sal del RNG de las acciones (precisión y daño).
const ACTION_SALT: int = 7919
## Sal del RNG de la IA (azar top-2, P2).
const AI_SALT: int = 6007

## Fin del combate (mismo orden que BattleLogic.Result).
enum Result { ONGOING, VICTORY, DEFEAT, FLED, APPEASED }
## Cómo empieza el combate (T6): normal, sorpresa (emboscada tuya) o emboscada del enemigo.
enum Opening { NORMAL, SURPRISE, AMBUSH }

## Tipos de acción (campo `kind` del resultado).
const KIND_ATTACK: StringName = &"attack"
const KIND_FINISH: StringName = &"finish"
const KIND_DEFEND: StringName = &"defend"
const KIND_WAIT: StringName = &"wait"
const KIND_COVER: StringName = &"cover"
const KIND_BANDAGE: StringName = &"bandage"
const KIND_CHEER: StringName = &"cheer"
const KIND_OFFER_LUZ: StringName = &"offer_luz"
const KIND_OFRENDA: StringName = &"ofrenda"
const KIND_FLEE: StringName = &"flee"
const KIND_LEAVE: StringName = &"leave"
## Golpe del área anunciada (T6).
const KIND_AREA: StringName = &"area"
## Claves de texto corto (data/text/sistema.json, las escribe narrative-writer en T4).
const TEXT_MISS: StringName = &"tactical_miss"
const TEXT_ATTACK: StringName = &"tactical_attack"
const TEXT_ATTACK_FLANK: StringName = &"tactical_attack_flank"
const TEXT_ATTACK_BACK: StringName = &"tactical_attack_back"
const TEXT_STRONG: StringName = &"tactical_strong"
const TEXT_FINISH: StringName = &"tactical_finish"
const TEXT_DEFEND: StringName = &"tactical_defend"
const TEXT_WAIT: StringName = &"tactical_wait"
const TEXT_COVER: StringName = &"tactical_cover"
const TEXT_BANDAGE: StringName = &"tactical_bandage"
const TEXT_CHEER: StringName = &"tactical_cheer"
const TEXT_OFFER_LUZ: StringName = &"tactical_offer_luz"
const TEXT_OFRENDA: StringName = &"tactical_ofrenda"
const TEXT_FLEE: StringName = &"tactical_flee"
const TEXT_FLEE_FAIL: StringName = &"tactical_flee_fail"
const TEXT_ENEMY_FLEE: StringName = &"tactical_enemy_flee"
const TEXT_RETREAT: StringName = &"tactical_retreat"
const TEXT_AREA: StringName = &"tactical_area"
const TEXT_AREA_WARNING: StringName = &"tactical_area_warning"
const TEXT_JOINT: StringName = &"tactical_joint"
const TEXT_SURPRISE: StringName = &"tactical_surprise"
const TEXT_AMBUSH: StringName = &"tactical_ambush"
## Roles (ids de balance.json, tactics.roles; los mismos que BattleLogic).
const ROLE_ATTACKER: StringName = &"attacker"
const ROLE_DEFENDER: StringName = &"defender"
const ROLE_SUPPORT: StringName = &"support"

var board: TacticalBoard
var movement_cfg: Dictionary
var ct_cfg: Dictionary
var board_cfg: Dictionary
## Reglas de las acciones (tactical.actions), golpe (attack), Defender y roles.
var actions_cfg: Dictionary
var attack_cfg: Dictionary
var roles_cfg: Dictionary
var defend_factor: float = 0.5
var finish_below: float = 0.3
## Umbrales de la IA (tactics.ai: help_below, retreat_below, swarm_flee_below...; TacticalAI).
var ai_cfg: Dictionary = {}
## Huida (P1, tactical.flee) e intentos fallidos en este combate.
var flee_cfg: Dictionary = {}
var flee_fails: int = 0
## RNG de la IA (azar top-2; TacticalAI).
var ai_rng := RandomNumberGenerator.new()
## Orden al grupo del jugador (BattleLogic.GroupOrder) y último enemigo al que atacó el `leader`.
var group_order: int = BattleLogic.GroupOrder.FREE
var player_target: int = NONE
var rng := RandomNumberGenerator.new()
var result: Result = Result.ONGOING
## Pago (set_payment): peaje en Luz, Luz suelta y ofrendas de la bolsa ([{ id, luz }]).
var toll: int = 0
var luz: int = 0
var ofrendas: Array = []
## Índice de la ofrenda entregada (-1 si ninguna).
var ofrenda_index: int = -1
## Cubrir: { índice protegido: índice del defensor } hasta el siguiente turno del defensor.
var covers: Dictionary = {}
## Lado por donde llegó el jugador (sus columnas de colocación).
var player_side: TacticalBoard.Side = TacticalBoard.Side.LEFT
## Combatientes: [{ id, side, agi, mov, jump, drop, cell, facing, ct, tie, alive, hp, max_hp, atk,
## def, role, ai, fled, leader, accepts_payment, strong_every, strong_factor, strong_cooldown,
## special_every, special_factor, special_area, attacks, announce, joint, defending, cheer, heals_left,
## cheers_left, finishes_left, cover_ready, turns }]. `turns`: turnos propios
## empezados (Cubrir vuelve a estar listo cuando turns ≥ cover_ready).
var units: Array[Dictionary] = []
## Índice del combatiente en su turno (NONE fuera de un turno).
var active: int = NONE
var active_moved: bool = false
var active_acted: bool = false
## Turnos jugados (para la UI y los tests).
var turn_count: int = 0
## Entradas de refuerzo pendientes por bando (una por cada caído o retirado del tablero).
var pending_entries: Array[int] = [0, 0]
## Quién entró como refuerzo al empezar el último turno (índices; para la UI).
var last_entries: Array[int] = []
## Apertura del combate (apply_opening).
var opening: Opening = Opening.NORMAL
## Quién anunció un área al terminar el último turno (NONE si nadie; para la UI).
var last_announce: int = NONE


func _init(tactical: Dictionary, battle_board: TacticalBoard, fighters: Array, rng_seed: int,
		arrival_side: TacticalBoard.Side = TacticalBoard.Side.LEFT) -> void:
	board = battle_board
	movement_cfg = tactical.get("movement", {})
	ct_cfg = tactical.get("ct", {})
	board_cfg = tactical.get("board", {})
	actions_cfg = tactical.get("actions", {})
	attack_cfg = tactical.get("attack", { "roll_min": -1, "roll_max": 2, "min_damage": 1 })
	roles_cfg = tactical.get("roles", {})
	defend_factor = float(tactical.get("defend_factor", 0.5))
	finish_below = float(tactical.get("finish_below", 0.3))
	ai_cfg = tactical.get("ai", {})
	flee_cfg = tactical.get("flee", {})
	rng.seed = rng_seed + ACTION_SALT
	ai_rng.seed = rng_seed + AI_SALT
	player_side = arrival_side
	var tie_rng := RandomNumberGenerator.new()
	tie_rng.seed = rng_seed + TIE_SALT
	var max_side: int = int(board_cfg.get("max_per_side", 3))
	var per_side: Array[int] = [0, 0]
	for f: Variant in fighters:
		var data: Dictionary = f
		var side: int = SIDE_ENEMY if int(data.get("side", SIDE_PLAYER)) == SIDE_ENEMY else SIDE_PLAYER
		var waiting: bool = per_side[side] >= max_side or bool(data.get("reserve", false))
		if not waiting:
			per_side[side] += 1
		var agi: int = int(data.get("agi", 0))
		var jump: int = jump_height(agi, movement_cfg)
		var role: StringName = StringName(str(data.get("role", "")))
		var max_hp: int = maxi(1, int(data.get("max_hp", data.get("hp", 1))))
		var reach: Array = data.get("attack_range", [1, 1])
		var range_min: int = maxi(1, int(reach[0])) if reach.size() > 0 else 1
		var range_max: int = maxi(range_min, int(reach[1])) if reach.size() > 1 else range_min
		units.append({
			"hp": clampi(int(data.get("hp", max_hp)), 1, max_hp),
			"max_hp": max_hp,
			"atk": int(data.get("atk", 0)) + _role_num(role, "atk_bonus", 0),
			"def": int(data.get("def", 0)) + _role_num(role, "def_bonus", 0),
			"role": role,
			"ai": StringName(str(data.get("ai", ""))),
			"fled": false,
			"leader": bool(data.get("leader", false)),
			"accepts_payment": bool(data.get("accepts_payment", true)),
			"strong_every": int(data.get("strong_every", 0)),
			"strong_factor": float(data.get("strong_factor", 1.0)),
			"strong_cooldown": 0,
			"special_every": int(data.get("special_every", 0)),
			"special_factor": float(data.get("special_factor", 1.0)),
			"special_area": bool(data.get("special_area", false)),
			"attacks": 0,
			"announce": [],
			"joint": bool(data.get("joint", false)),
			"range_min": range_min,
			"range_max": range_max,
			"range_line": bool(data.get("attack_line", true)),
			"afraid": bool(data.get("afraid", false)),
			"waits": 0,
			"defending": false,
			"cheer": 0,
			"heals_left": _role_num(role, "heal_uses", 0) if role == ROLE_SUPPORT else 0,
			"cheers_left": _role_num(role, "cheer_uses", 0) if role == ROLE_SUPPORT else 0,
			"finishes_left": _role_num(role, "finish_uses", 0) if role == ROLE_ATTACKER else 0,
			"cover_ready": 0,
			"turns": 0,
			"id": data.get("id", &""),
			"side": side,
			"agi": agi,
			"mov": move_range(agi, movement_cfg),
			"jump": jump,
			"drop": jump + int(movement_cfg.get("drop_extra", 1)),
			"cell": Vector2i(-1, -1) if waiting else data.get("cell", Vector2i(-1, -1)),
			"facing": data.get("facing", -1),
			"ct": agi * int(ct_cfg.get("start_per_agi", 10)),
			"tie": tie_rng.randi(),
			"alive": not waiting,
			"waiting": waiting,
		})
	_place_units()
	for u: Dictionary in units:
		u.home = u.cell


## El bloque tactical de balance.json con lo que comparte con el combate por menú: attack (tirada y
## daño mínimo), defend_factor, roles (tactics.roles) y finish_below (tactics.ai).
static func config_from_balance(balance_data: Dictionary) -> Dictionary:
	var cfg: Dictionary = (balance_data.get("tactical", {}) as Dictionary).duplicate(true)
	var tactics: Dictionary = balance_data.get("tactics", {})
	if balance_data.has("attack"):
		cfg["attack"] = balance_data.attack
	if balance_data.has("defend_factor"):
		cfg["defend_factor"] = balance_data.defend_factor
	cfg["roles"] = tactics.get("roles", {})
	cfg["finish_below"] = (tactics.get("ai", {}) as Dictionary).get("finish_below", 0.3)
	cfg["ai"] = (tactics.get("ai", {}) as Dictionary).duplicate(true)
	return cfg


func _role_num(role: StringName, key: String, fallback: int) -> int:
	if role == &"":
		return fallback
	return int((roles_cfg.get(String(role), {}) as Dictionary).get(key, fallback))


# --- Derivados de AGI ---------------------------------------------------------------------------

## Mov (casillas por turno) según la AGI.
static func move_range(agi: int, cfg: Dictionary) -> int:
	var div: int = maxi(int(cfg.get("mov_agi_div", 2)), 1)
	var raw: int = int(cfg.get("mov_base", 3)) + floori(float(agi - int(cfg.get("mov_agi_ref", 5))) / div)
	return clampi(raw, int(cfg.get("mov_min", 2)), int(cfg.get("mov_max", 6)))


## Salto (niveles que se suben entre dos casillas vecinas) según la AGI.
static func jump_height(agi: int, cfg: Dictionary) -> int:
	var div: int = maxi(int(cfg.get("jump_agi_div", 7)), 1)
	return int(cfg.get("jump_base", 1)) + floori(float(agi) / div)


# --- Colocación ---------------------------------------------------------------------------------

func _place_units() -> void:
	var columns: int = int(board_cfg.get("deploy_columns", 2))
	var enemy_side: TacticalBoard.Side = TacticalBoard.Side.RIGHT if player_side == TacticalBoard.Side.LEFT \
		else TacticalBoard.Side.LEFT
	var taken: Dictionary = {}
	for u: Dictionary in units:
		if u.alive and board.in_bounds(u.cell):
			taken[u.cell] = true
	for side: int in [SIDE_PLAYER, SIDE_ENEMY]:
		var board_side: TacticalBoard.Side = player_side if side == SIDE_PLAYER else enemy_side
		var cells: Array[Vector2i] = board.deploy_cells(board_side, columns, _count_side(side) + taken.size())
		for u: Dictionary in units:
			if u.side != side:
				continue
			if u.waiting:
				if int(u.facing) < 0:
					u.facing = _facing_from(board_side)
				continue
			if not board.in_bounds(u.cell):
				for c: Vector2i in cells:
					if not taken.has(c):
						u.cell = c
						break
				taken[u.cell] = true
			if int(u.facing) < 0:
				u.facing = _facing_from(board_side)


## Orientación de quien sale de un lado: hacia el lado contrario.
static func _facing_from(board_side: TacticalBoard.Side) -> TacticalBoard.Facing:
	return TacticalBoard.Facing.EAST if board_side == TacticalBoard.Side.LEFT else TacticalBoard.Facing.WEST


## Lado del tablero de un bando.
func board_side_of(side: int) -> TacticalBoard.Side:
	if side == SIDE_PLAYER:
		return player_side
	return TacticalBoard.Side.RIGHT if player_side == TacticalBoard.Side.LEFT else TacticalBoard.Side.LEFT


func _count_side(side: int) -> int:
	var n: int = 0
	for u: Dictionary in units:
		if u.side == side and u.alive:
			n += 1
	return n


# --- Refuerzos (T1b) ----------------------------------------------------------------------------

## Índices de los que esperan en el borde de un bando, en orden de entrada.
func waiting_units(side: int) -> Array[int]:
	var out: Array[int] = []
	for i in units.size():
		if units[i].side == side and units[i].waiting:
			out.append(i)
	return out


## Combatientes de un bando en el tablero.
func on_board(side: int) -> int:
	return _count_side(side)


## Entran los refuerzos pendientes de cada bando (el jugador primero), con CT reinforce_ct, en la
## casilla libre más cercana a su borde. Sin casilla libre, quedan pendientes. Devuelve quién entró.
func deploy_reinforcements() -> Array[int]:
	var out: Array[int] = []
	for side: int in [SIDE_PLAYER, SIDE_ENEMY]:
		var queue: Array[int] = waiting_units(side)
		if queue.is_empty():
			pending_entries[side] = 0
			continue
		var board_side: TacticalBoard.Side = board_side_of(side)
		var free: Array[Vector2i] = []
		for c: Vector2i in board.entry_cells(board_side):
			if unit_at(c) == NONE:
				free.append(c)
		while pending_entries[side] > 0 and not queue.is_empty() and not free.is_empty():
			var i: int = queue.pop_front()
			var u: Dictionary = units[i]
			u.cell = free.pop_front()
			u.alive = true
			u.waiting = false
			u.ct = int(ct_cfg.get("reinforce_ct", 50))
			u.facing = _facing_from(board_side)
			u.home = u.cell
			pending_entries[side] -= 1
			out.append(i)
		if queue.is_empty():
			pending_entries[side] = 0
	return out


# --- Turnos CT ----------------------------------------------------------------------------------

## CT de un combatiente.
func ct_of(index: int) -> int:
	return int(units[index].ct)


## Fija el CT (sorpresa y emboscada, T6: CT 100 para un bando).
func set_ct(index: int, value: int) -> void:
	units[index].ct = value


## Retira a un combatiente (caído o huido): deja de jugar y de ocupar casilla.
func remove_unit(index: int) -> void:
	if units[index].alive:
		pending_entries[int(units[index].side)] += 1
	units[index].alive = false
	units[index].announce = []
	covers.erase(index)
	_drop_covers_by(index)
	if active == index:
		active = NONE


## Empieza el turno del siguiente combatiente (avanza ticks si nadie llega al umbral) y devuelve su
## índice, o NONE si no queda nadie en pie.
func begin_turn() -> int:
	assert(active == NONE, "Termina el turno antes de empezar otro")
	last_entries = []
	last_announce = NONE
	if is_over():
		return NONE
	last_entries = deploy_reinforcements()
	var cts: Array[int] = _cts()
	var next: int = _advance(cts)
	for i in units.size():
		units[i].ct = cts[i]
	active = next
	active_moved = false
	active_acted = false
	if next != NONE:
		var u: Dictionary = units[next]
		u.turns = int(u.turns) + 1
		u.defending = false
		u.strong_cooldown = maxi(0, int(u.strong_cooldown) - 1)
		_drop_covers_by(next)
	return next


## Casillas alcanzables por el combatiente en su turno: { Vector2i: coste }. Vacío si ya se movió.
func reachable_for(index: int) -> Dictionary:
	if index == active and active_moved:
		return { units[index].cell: 0 }
	var u: Dictionary = units[index]
	return board.reachable(u.cell, int(u.mov), int(u.jump), int(u.drop), _enemy_cells(u.side),
		_occupied_cells(index))


## Camino del combatiente hasta `to` (vacío si no llega).
func path_for(index: int, to: Vector2i) -> Array[Vector2i]:
	var u: Dictionary = units[index]
	return board.path_to(u.cell, to, int(u.mov), int(u.jump), int(u.drop), _enemy_cells(u.side),
		_occupied_cells(index))


## Mueve al combatiente en su turno a `to`. Devuelve el camino recorrido ([] si no puede: fuera de
## lo alcanzable, ya se movió o no es su turno). La orientación pasa a la del último paso.
func move_active(to: Vector2i) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if active == NONE or active_moved or to == units[active].cell:
		return none
	var path: Array[Vector2i] = path_for(active, to)
	if path.is_empty():
		return none
	units[active].cell = to
	units[active].facing = TacticalBoard.facing_toward(path[path.size() - 2], to)
	active_moved = true
	return path


## El combatiente en su turno actuó (atacar, Defender, objeto…; las acciones llegan en T3).
func mark_acted() -> void:
	if active != NONE:
		active_acted = true


## Coste de CT según lo que hizo en el turno.
func turn_cost(moved: bool, acted: bool) -> int:
	if moved and acted:
		return int(ct_cfg.get("cost_move_and_act", 100))
	if moved or acted:
		return int(ct_cfg.get("cost_single", 80))
	return int(ct_cfg.get("cost_wait", 60))


## Termina el turno: fija la orientación (4 direcciones) y cobra el CT. Devuelve el coste cobrado.
func end_turn(facing: TacticalBoard.Facing) -> int:
	if active == NONE:
		return 0
	var cost: int = turn_cost(active_moved, active_acted)
	units[active].facing = facing
	# Turnos seguidos sin actuar (la IA no Espera ni se aparta si ya lleva tactics.ai.wait_max).
	units[active].waits = 0 if active_acted else int(units[active].waits) + 1
	units[active].ct = int(units[active].ct) - cost
	if will_announce(active):
		units[active].announce = area_cells(units[active].cell, facing)
		last_announce = active
	active = NONE
	turn_count += 1
	return cost


## Los próximos `count` turnos (índices de combatiente) sin tocar el estado. Si alguien está en su
## turno, se supone que cobra `active_cost` (por defecto, mover y actuar) y se cuenta desde ahí.
func preview_order(count: int, active_cost: int = -1) -> Array[int]:
	var cts: Array[int] = _cts()
	var out: Array[int] = []
	if active != NONE:
		cts[active] -= active_cost if active_cost >= 0 else turn_cost(true, true)
	var full: int = turn_cost(true, true)
	while out.size() < count:
		var next: int = _advance(cts)
		if next == NONE:
			break
		out.append(next)
		cts[next] -= full
	return out


## Puede intentar huir (T3): está en una casilla del borde. Que salga bien es otra cosa (P1,
## flee_chance).
func can_flee(index: int) -> bool:
	return units[index].alive and board.is_edge(units[index].cell)


## Probabilidad (%) de que `index` huya desde donde está (P1, ajustes-playtest-0.5.md §1a;
## TacticalRules.flee_chance). Adyacente: enemigo en pie a 1 casilla ortogonal. Cercano: enemigo en
## pie que le alcanzaría en su siguiente turno (threat_range: Mov + su alcance; con alcance 1 es el
## Mov + 1 de la ficha). La AGI que cuenta es la más alta de esos enemigos.
func flee_chance(index: int = active) -> int:
	if not _valid(index):
		return 0
	var u: Dictionary = units[index]
	var adjacent: int = 0
	var near: int = 0
	var max_agi: int = 0
	for k: int in units.size():
		var v: Dictionary = units[k]
		if not v.alive or int(v.side) == int(u.side):
			continue
		var d: int = TacticalRules.distance(u.cell, v.cell)
		if d == 1:
			adjacent += 1
		elif d <= threat_range(k):
			near += 1
		else:
			continue
		max_agi = maxi(max_agi, int(v.agi))
	return TacticalRules.flee_chance(int(u.agi), adjacent, near, max_agi, flee_fails, bool(u.afraid), flee_cfg)


## Casillas (Manhattan) a las que `index` llega a golpear en su siguiente turno: Mov + alcance máximo.
func threat_range(index: int) -> int:
	return int(units[index].mov) + int(units[index].range_max)


## Índice del combatiente en una casilla (NONE si está libre).
func unit_at(cell: Vector2i) -> int:
	for i in units.size():
		if units[i].alive and units[i].cell == cell:
			return i
	return NONE


# --- Acciones (T3) ------------------------------------------------------------------------------

func is_over() -> bool:
	return result != Result.ONGOING


## Datos del pago en combate: peaje N del Bosque (con su hostilidad), Luz suelta y ofrendas de la
## bolsa ([{ id, luz }], Ofrendas.from_bag).
func set_payment(toll_amount: int, luz_amount: int, ofrenda_list: Array = []) -> void:
	toll = toll_amount
	luz = luz_amount
	ofrendas = ofrenda_list


## El combatiente en su turno todavía puede actuar.
func can_act() -> bool:
	return not is_over() and active != NONE and not active_acted


## `attacker` llega a `target` (enemigo en pie, a su alcance y desnivel ≤ su Salto; por defecto,
## cuerpo a cuerpo: vecino).
func can_attack(attacker: int, target: int) -> bool:
	if not _valid(attacker) or not _valid(target) or not units[attacker].alive:
		return false
	return can_hit_from(attacker, units[attacker].cell, target)


## `attacker` golpearía a `target` desde la casilla `from`: su alcance, el desnivel y, en línea, sin
## enemigos ni casillas intransitables en medio. La IA lo usa con casillas a las que aún no fue.
func can_hit_from(attacker: int, from: Vector2i, target: int) -> bool:
	if not _valid(attacker) or not _valid(target):
		return false
	var a: Dictionary = units[attacker]
	var t: Dictionary = units[target]
	if not t.alive or a.side == t.side:
		return false
	var rmax: int = int(a.range_max)
	var blockers: Dictionary = {}
	if rmax > 1:
		blockers = _enemy_cells(int(a.side))
		blockers.erase(t.cell)
	return TacticalRules.can_strike(board, from, t.cell, int(a.jump), int(a.range_min), rmax,
		bool(a.range_line), blockers)


## Enemigos a los que llega `attacker` desde su casilla.
func attack_targets(attacker: int) -> Array[int]:
	var out: Array[int] = []
	for i in units.size():
		if can_attack(attacker, i):
			out.append(i)
	return out


## Lo que la UI enseña antes de atacar: { relation, height, evasion, hit_chance, bonus }.
func attack_preview(attacker: int, target: int) -> Dictionary:
	var a: Dictionary = units[attacker]
	var t: Dictionary = units[target]
	var rel: TacticalRules.Relation = TacticalRules.relation(t.cell, int(t.facing), a.cell)
	var height: int = board.level_at(a.cell) - board.level_at(t.cell)
	var ev: int = TacticalRules.evasion(int(t.agi), rel, height, actions_cfg)
	return {
		"relation": rel,
		"height": height,
		"evasion": ev,
		"hit_chance": TacticalRules.hit_chance(ev, actions_cfg),
		"bonus": TacticalRules.position_bonus(rel, height, actions_cfg),
	}


## Remate posible: el combatiente en su turno es atacante con usos y el objetivo está por debajo de
## finish_below de sus PV.
func can_finish(target: int) -> bool:
	if not can_act() or not can_attack(active, target):
		return false
	var a: Dictionary = units[active]
	var t: Dictionary = units[target]
	return a.role == ROLE_ATTACKER and int(a.finishes_left) > 0 \
		and float(t.hp) / float(t.max_hp) < finish_below


## Atacar cuerpo a cuerpo a `target`. Con `finish`, Remate (solo si can_finish). Resultado: actor,
## kind (attack o finish), target (a quién apuntó), receiver (quién recibió el golpe: el defensor si
## lo cubrió), damage, missed, hit_chance, relation, height, covered, defended, strong, finish, down,
## text_key, result.
func attack(target: int, finish: bool = false) -> Dictionary:
	if not can_act() or not can_attack(active, target) or (finish and not can_finish(target)):
		return {}
	var a: Dictionary = units[active]
	var t: Dictionary = units[target]
	var joint: Array[int] = joint_group(active, target)
	var preview: Dictionary = attack_preview(active, target)
	for k: int in joint:
		var p: Dictionary = attack_preview(k, target)
		if int(p.hit_chance) > int(preview.hit_chance) or (int(p.hit_chance) == int(preview.hit_chance) 				and int(p.bonus) > int(preview.bonus)):
			preview = p
	active_acted = true
	a.facing = TacticalBoard.facing_toward(a.cell, t.cell, a.facing)
	var special: bool = false
	if int(a.special_every) > 0:
		a.attacks = int(a.attacks) + 1
		special = not a.special_area and BattleLogic.is_special_attack(int(a.attacks), int(a.special_every))
	var out: Dictionary = _result(KIND_FINISH if finish else KIND_ATTACK, target)
	out.joint = []
	if joint.size() > 1:
		out.joint = joint
	out.special = false
	if joint.size() > 1:
		# Los compañeros atacan en el turno del primero y gastan su siguiente turno.
		for k: int in joint:
			if k != active:
				units[k].ct = int(units[k].ct) - int(ct_cfg.get("cost_single", 80))
				units[k].facing = TacticalBoard.facing_toward(units[k].cell, t.cell, units[k].facing)
	if a.leader:
		player_target = target
	out.receiver = target
	out.hit_chance = preview.hit_chance
	out.relation = preview.relation
	out.height = preview.height
	out.damage = 0
	out.missed = rng.randi_range(0, 99) >= int(preview.hit_chance)
	out.covered = false
	out.defended = false
	out.strong = false
	out.finish = finish
	out.down = false
	if out.missed:
		out.text_key = TEXT_MISS
		return out
	var receiver: int = _cover_redirect(target)
	var r: Dictionary = units[receiver]
	var roll: int = rng.randi_range(int(attack_cfg.get("roll_min", -1)), int(attack_cfg.get("roll_max", 2)))
	var min_damage: int = int(attack_cfg.get("min_damage", 1))
	var dmg: int = BattleLogic.attack_damage(int(a.atk) + int(a.cheer), int(r.def), roll, min_damage)
	if joint.size() > 1:
		var atks: Array = []
		for k: int in joint:
			atks.append(int(units[k].atk) + (int(units[k].cheer) if k == active else 0))
		dmg = BattleLogic.joint_damage(atks, int(r.def), roll, min_damage)
	a.cheer = 0
	if special:
		dmg = BattleLogic.strong_damage(dmg, float(a.special_factor))
		out.special = true
	if int(a.strong_every) > 0 and int(a.strong_cooldown) <= 0:
		dmg = BattleLogic.strong_damage(dmg, float(a.strong_factor))
		a.strong_cooldown = int(a.strong_every)
		out.strong = true
	dmg += int(preview.bonus)
	if finish:
		dmg += _role_num(ROLE_ATTACKER, "finish_bonus", 0)
		a.finishes_left = int(a.finishes_left) - 1
	if r.defending:
		dmg = BattleLogic.defended_damage(dmg, defend_factor)
		out.defended = true
	dmg = maxi(min_damage, dmg)
	out.receiver = receiver
	out.covered = receiver != target
	out.damage = dmg
	r.hp = maxi(0, int(r.hp) - dmg)
	if int(r.hp) == 0:
		out.down = true
		remove_unit(receiver)
		check_end()
	if finish:
		out.text_key = TEXT_FINISH
	elif joint.size() > 1:
		out.text_key = TEXT_JOINT
	elif out.strong:
		out.text_key = TEXT_STRONG
	elif preview.relation == TacticalRules.Relation.BACK:
		out.text_key = TEXT_ATTACK_BACK
	elif preview.relation == TacticalRules.Relation.FLANK:
		out.text_key = TEXT_ATTACK_FLANK
	else:
		out.text_key = TEXT_ATTACK
	out.result = result
	return out


## Defender: el daño recibido ×defend_factor hasta su siguiente turno. Cuenta como acción.
func defend() -> Dictionary:
	if not can_act():
		return {}
	active_acted = true
	units[active].defending = true
	var out: Dictionary = _result(KIND_DEFEND, active)
	out.text_key = TEXT_DEFEND
	return out


## Esperar: termina el turno sin actuar (CT −cost_wait si tampoco se movió; sin el ×1,25 del combate
## por menú). Resultado con ct_cost.
func wait_turn(facing: TacticalBoard.Facing) -> Dictionary:
	if is_over() or active == NONE or active_acted:
		return {}
	var out: Dictionary = _result(KIND_WAIT, active)
	out.text_key = TEXT_WAIT
	out.ct_cost = end_turn(facing)
	return out


## Cubrir (defensor, cada cover_every turnos propios): los golpes que acierten a `target` (aliado
## vecino) se los lleva él hasta su siguiente turno, mientras sigan vecinos.
func can_cover(target: int) -> bool:
	if not can_act() or not _valid(target) or target == active:
		return false
	var a: Dictionary = units[active]
	var t: Dictionary = units[target]
	return a.role == ROLE_DEFENDER and int(a.turns) >= int(a.cover_ready) and t.alive \
		and t.side == a.side and TacticalBoard.are_adjacent(a.cell, t.cell)


func cover(target: int) -> Dictionary:
	if not can_cover(target):
		return {}
	active_acted = true
	var a: Dictionary = units[active]
	covers[target] = active
	a.cover_ready = int(a.turns) + _role_num(ROLE_DEFENDER, "cover_every", 2)
	var out: Dictionary = _result(KIND_COVER, target)
	out.text_key = TEXT_COVER
	return out


## Vendar (apoyo, heal_uses por combate): cura heal_pct % de los PV máx. de un aliado (o de sí mismo)
## a support_range casillas o menos.
func can_bandage(target: int) -> bool:
	return _support_ok(target, "heals_left", true)


func bandage(target: int) -> Dictionary:
	if not can_bandage(target):
		return {}
	active_acted = true
	var a: Dictionary = units[active]
	var t: Dictionary = units[target]
	a.heals_left = int(a.heals_left) - 1
	var healed: int = mini(ceili(int(t.max_hp) * _role_num(ROLE_SUPPORT, "heal_pct", 0) / 100.0),
		int(t.max_hp) - int(t.hp))
	t.hp = int(t.hp) + healed
	var out: Dictionary = _result(KIND_BANDAGE, target)
	out.amount = healed
	out.text_key = TEXT_BANDAGE
	return out


## Animar (apoyo, cheer_uses por combate): +cheer_atk de ATQ al siguiente golpe que acierte de otro
## aliado a support_range casillas o menos (no se acumula).
func can_cheer(target: int) -> bool:
	return _support_ok(target, "cheers_left", false)


func cheer(target: int) -> Dictionary:
	if not can_cheer(target):
		return {}
	active_acted = true
	units[active].cheers_left = int(units[active].cheers_left) - 1
	var bonus: int = _role_num(ROLE_SUPPORT, "cheer_atk", 0)
	units[target].cheer = bonus
	var out: Dictionary = _result(KIND_CHEER, target)
	out.amount = bonus
	out.text_key = TEXT_CHEER
	return out


## Ofrecer Luz: el bando del jugador paga el peaje y el combate acaba (APPEASED). No vale si algún
## enemigo en pie no acepta pagos (Ofomni descarriado, Aledra), sin peaje o sin Luz bastante.
func can_offer_luz() -> bool:
	return _player_acting() and _enemies_accept() and toll > 0 and luz >= toll


func offer_luz() -> Dictionary:
	if not can_offer_luz():
		return {}
	active_acted = true
	luz -= toll
	result = Result.APPEASED
	var out: Dictionary = _result(KIND_OFFER_LUZ, NONE)
	out.amount = toll
	out.luz = luz
	out.text_key = TEXT_OFFER_LUZ
	out.result = result
	return out


## Índices de `ofrendas` con los que se puede pagar ahora (Ofrendas.payable).
func payable_ofrendas() -> Array[int]:
	if not _player_acting() or not _enemies_accept():
		return []
	return Ofrendas.payable(ofrendas, luz, toll)


## Ofrecer la ofrenda `index` (completada con Luz suelta hasta el peaje): APPEASED.
func offer_ofrenda(index: int) -> Dictionary:
	if not payable_ofrendas().has(index):
		return {}
	active_acted = true
	var item: Dictionary = ofrendas[index]
	luz -= Ofrendas.luz_needed(int(item.luz), toll)
	ofrenda_index = index
	result = Result.APPEASED
	var out: Dictionary = _result(KIND_OFRENDA, NONE)
	out.amount = int(item.luz)
	out.id = str(item.id)
	out.luz = luz
	out.text_key = TEXT_OFRENDA
	out.result = result
	return out


## Huir: el combatiente del jugador en su turno está en una casilla del borde (P1).
func can_flee_now() -> bool:
	return _player_acting() and can_flee(active)


## Intenta huir con una tirada de flee_chance(). Si sale bien, huye todo el bando (FLED). Si falla
## ("No logras escapar"), cuenta como actuar y el turno termina ya, mirando hacia donde miraba (CT
## −100 si se movió, −80 si no); el siguiente intento suma retry_bonus. Resultado con chance,
## failed y ct_cost.
func flee() -> Dictionary:
	if not can_flee_now():
		return {}
	var chance: int = flee_chance(active)
	active_acted = true
	var out: Dictionary = _result(KIND_FLEE, NONE)
	out.chance = chance
	out.failed = rng.randi_range(0, 99) >= chance
	out.ct_cost = 0
	if out.failed:
		flee_fails += 1
		out.text_key = TEXT_FLEE_FAIL
		out.ct_cost = end_turn(int(units[active].facing) as TacticalBoard.Facing)
		return out
	result = Result.FLED
	out.text_key = TEXT_FLEE
	out.result = result
	return out


## Retirarse por el borde: el combatiente en su turno está en una casilla del borde y sale del
## tablero (no cae: queda `fled`). Termina su turno. `retreat`: texto de retirada (garelino) en vez
## del de huida (reparep).
func can_leave() -> bool:
	return can_act() and board.is_edge(units[active].cell)


func leave(retreat: bool = false) -> Dictionary:
	if not can_leave():
		return {}
	var who: int = active
	active_acted = true
	var out: Dictionary = _result(KIND_LEAVE, who)
	units[who].fled = true
	remove_unit(who)
	turn_count += 1
	check_end()
	out.text_key = TEXT_RETREAT if retreat else TEXT_ENEMY_FLEE
	out.result = result
	return out


# --- Especiales (T6) ----------------------------------------------------------------------------

## Quiénes atacan juntos a `target` si ataca `attacker`: él primero y sus compañeros `joint` en pie
## que también le llegan cuerpo a cuerpo (hasta actions.joint_max en total, por índice). Solo él si no
## es `joint` o no tiene compañeros al lado.
func joint_group(attacker: int, target: int) -> Array[int]:
	var out: Array[int] = [attacker]
	if not bool(units[attacker].joint):
		return out
	var cap: int = int(actions_cfg.get("joint_max", 4))
	for k: int in units.size():
		if out.size() >= cap:
			break
		var v: Dictionary = units[k]
		if k != attacker and v.alive and bool(v.joint) and int(v.side) == int(units[attacker].side) 				and can_attack(k, target):
			out.append(k)
	return out


## Tamaño del área anunciada en este tablero: Vector2i(ancho, fondo) (board.latigazo; 3 x 1 por
## defecto, TacticalArena lo fija por tamaño de tablero).
func area_size() -> Vector2i:
	var a: Variant = board_cfg.get("latigazo", [3, 1])
	if a is Vector2i:
		return a
	var arr: Array = a
	return Vector2i(maxi(1, int(arr[0])), maxi(1, int(arr[1])))


## Casillas del área delante de `cell` mirando hacia `facing`: area_size().y filas de fondo y
## area_size().x de ancho, centradas en la línea de su mirada. Solo las que caen dentro del tablero.
func area_cells(cell: Vector2i, facing: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var size: Vector2i = area_size()
	var dir: Vector2i = TacticalBoard.NEIGHBOR_DIRS[facing]
	var side := Vector2i(-dir.y, dir.x)
	var from: int = -((size.x - 1) / 2)
	for depth: int in range(1, size.y + 1):
		for w: int in range(from, from + size.x):
			var c: Vector2i = cell + dir * depth + side * w
			if board.in_bounds(c):
				out.append(c)
	return out


## Anunciará su área al terminar el turno: tiene especial en área, no hay otro anuncio pendiente y su
## siguiente ataque (contando `extra` ataques más de este turno) es el especial.
func will_announce(index: int, extra: int = 0) -> bool:
	var u: Dictionary = units[index]
	var every: int = int(u.special_every)
	return bool(u.special_area) and every > 0 and u.alive and (u.announce as Array).is_empty() 		and BattleLogic.is_special_attack(int(u.attacks) + extra + 1, every)


## Casillas anunciadas contra el bando `side` (por enemigos suyos): { Vector2i: índice de quien las
## anunció }.
func danger_cells(side: int) -> Dictionary:
	var out: Dictionary = {}
	for i in units.size():
		var u: Dictionary = units[i]
		if u.alive and int(u.side) != side:
			for c: Variant in u.announce:
				out[c] = i
	return out


## Enemigos de `index` en las casillas `cells`.
func foes_in(index: int, cells: Array) -> Array[int]:
	var out: Array[int] = []
	for c: Variant in cells:
		var at: int = unit_at(c as Vector2i)
		if at != NONE and int(units[at].side) != int(units[index].side):
			out.append(at)
	return out


## El combatiente en su turno tiene un área anunciada y puede golpearla.
func can_area_strike() -> bool:
	return can_act() and not (units[active].announce as Array).is_empty()


## Golpe del área anunciada: una tirada para todos los enemigos que sigan dentro. Cuenta como su
## ataque especial. Resultado con hits: [{ receiver, damage, defended, down }] y damage (el total).
func area_strike() -> Dictionary:
	if not can_area_strike():
		return {}
	var a: Dictionary = units[active]
	var cells: Array = a.announce
	a.announce = []
	a.attacks = int(a.attacks) + 1
	active_acted = true
	var out: Dictionary = _result(KIND_AREA, NONE)
	out.cells = cells
	out.text_key = TEXT_AREA
	var min_damage: int = int(attack_cfg.get("min_damage", 1))
	var roll: int = rng.randi_range(int(attack_cfg.get("roll_min", -1)), int(attack_cfg.get("roll_max", 2)))
	var hits: Array[Dictionary] = []
	var total: int = 0
	for t: int in foes_in(active, cells):
		var r: Dictionary = units[t]
		var dmg: int = BattleLogic.strong_damage(BattleLogic.attack_damage(int(a.atk), int(r.def), roll, min_damage),
			float(a.special_factor))
		var defended: bool = bool(r.defending)
		if defended:
			dmg = BattleLogic.defended_damage(dmg, defend_factor)
		dmg = maxi(min_damage, dmg)
		r.hp = maxi(0, int(r.hp) - dmg)
		var down: bool = int(r.hp) == 0
		hits.append({ "receiver": t, "damage": dmg, "defended": defended, "down": down })
		total += dmg
		if down:
			remove_unit(t)
	check_end()
	out.hits = hits
	out.damage = total
	out.missed = hits.is_empty()
	out.result = result
	return out


## Apertura del combate (sorpresa o emboscada): el bando que sorprende, en el tablero, empieza con CT
## threshold (juega antes que nadie) y el otro con menos de threshold, mirando hacia el lado contrario
## (de espaldas al que sorprende). Llamar antes del primer turno.
func apply_opening(kind: Opening) -> void:
	opening = kind
	if kind == Opening.NORMAL:
		return
	var first: int = SIDE_PLAYER if kind == Opening.SURPRISE else SIDE_ENEMY
	var threshold: int = int(ct_cfg.get("threshold", 100))
	var away: TacticalBoard.Facing = _facing_from(board_side_of(first))
	for u: Dictionary in units:
		if not u.alive:
			continue
		if int(u.side) == first:
			u.ct = threshold
		else:
			u.ct = mini(int(u.ct), threshold - 1)
			u.facing = away


## Clave del texto de la apertura (sorpresa o emboscada; &"" si normal).
func opening_text_key() -> StringName:
	match opening:
		Opening.SURPRISE:
			return TEXT_SURPRISE
		Opening.AMBUSH:
			return TEXT_AMBUSH
	return &""


## Cambia la orden al grupo (BattleLogic.GroupOrder). No gasta acción.
func set_group_order(order: int) -> void:
	group_order = clampi(order, BattleLogic.GroupOrder.FREE, BattleLogic.GroupOrder.DEFEND)


func _valid(index: int) -> bool:
	return index >= 0 and index < units.size()


func _player_acting() -> bool:
	return can_act() and units[active].side == SIDE_PLAYER


func _enemies_accept() -> bool:
	for u: Dictionary in units:
		if u.alive and u.side == SIDE_ENEMY and not u.accepts_payment:
			return false
	return true


func _support_ok(target: int, uses_key: String, allow_self: bool) -> bool:
	if not can_act() or not _valid(target) or (target == active and not allow_self):
		return false
	var a: Dictionary = units[active]
	var t: Dictionary = units[target]
	return a.role == ROLE_SUPPORT and int(a[uses_key]) > 0 and t.alive and t.side == a.side \
		and TacticalRules.distance(a.cell, t.cell) <= int(actions_cfg.get("support_range", 2))


## Quién recibe un golpe que acierta a `target`: su defensor si lo cubre y sigue vecino a él.
func _cover_redirect(target: int) -> int:
	if not covers.has(target):
		return target
	var guard: int = int(covers[target])
	if _valid(guard) and units[guard].alive and TacticalBoard.are_adjacent(units[guard].cell, units[target].cell):
		return guard
	return target


func _drop_covers_by(guard: int) -> void:
	for who: Variant in covers.keys():
		if int(covers[who]) == guard:
			covers.erase(who)


## Fin del combate tras una caída: derrota si cae un `leader` o no queda nadie del jugador; victoria
## si no queda ningún enemigo. Las acciones la llaman solas; quien retire a alguien con remove_unit
## por otra vía (la IA de T5, un enemigo que huye) la llama después.
func check_end() -> void:
	var players: int = 0
	var enemies: int = 0
	for u: Dictionary in units:
		if u.alive or u.waiting:
			if u.side == SIDE_PLAYER:
				players += 1
			else:
				enemies += 1
		elif u.side == SIDE_PLAYER and u.leader:
			result = Result.DEFEAT
			return
	if players == 0:
		result = Result.DEFEAT
	elif enemies == 0:
		result = Result.VICTORY


func _result(kind: StringName, target: int) -> Dictionary:
	return {
		"actor": active,
		"kind": kind,
		"target": target,
		"damage": 0,
		"missed": false,
		"text_key": &"",
		"result": result,
	}


func _cts() -> Array[int]:
	var cts: Array[int] = []
	for u: Dictionary in units:
		cts.append(int(u.ct))
	return cts


## Avanza `cts` hasta que alguien llega al umbral y devuelve quién juega (NONE sin nadie en pie).
func _advance(cts: Array[int]) -> int:
	var threshold: int = int(ct_cfg.get("threshold", 100))
	var any_alive: bool = false
	for u: Dictionary in units:
		any_alive = any_alive or bool(u.alive)
	if not any_alive:
		return NONE
	while true:
		var best: int = NONE
		for i in units.size():
			if not units[i].alive or cts[i] < threshold:
				continue
			if best == NONE or _goes_before(i, best, cts):
				best = i
		if best != NONE:
			return best
		for i in units.size():
			if units[i].alive:
				cts[i] += maxi(int(units[i].agi), 1)
	return NONE


## `a` juega antes que `b` con los mismos ticks: más CT; empate, el bando del jugador; luego el orden
## sorteado con la seed; luego el índice.
func _goes_before(a: int, b: int, cts: Array[int]) -> bool:
	if cts[a] != cts[b]:
		return cts[a] > cts[b]
	if units[a].side != units[b].side:
		return units[a].side == SIDE_PLAYER
	if units[a].tie != units[b].tie:
		return int(units[a].tie) > int(units[b].tie)
	return a < b


func _enemy_cells(side: int) -> Dictionary:
	var out: Dictionary = {}
	for u: Dictionary in units:
		if u.alive and u.side != side:
			out[u.cell] = true
	return out


func _occupied_cells(except: int) -> Dictionary:
	var out: Dictionary = {}
	for i in units.size():
		if i != except and units[i].alive:
			out[units[i].cell] = true
	return out
