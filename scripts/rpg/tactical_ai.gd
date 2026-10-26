class_name TacticalAI
extends RefCounted
## IA del combate táctico en la cuadrícula (ia-de-combate.md, "Traducción a la cuadrícula";
## combate-tactico.md; ADR 0016; PR T5). Clase pura sin estado: dado un TacticalBattle y un
## combatiente, plan() devuelve un plan determinista (sin RNG; los empates, por casilla y por índice):
## { actor, move_to, action, target, facing }.
## - move_to: casilla a la que moverse (la suya si no se mueve); siempre dentro de reachable_for.
## - action: un KIND_* de TacticalBattle (attack, finish, defend, cover, bandage, cheer, leave) o
##   KIND_NONE si solo se mueve. Se comprueba con las mismas reglas que TacticalBattle (can_*), así
##   que nunca es ilegal. Se mueve primero y luego actúa.
## - facing: orientación al terminar desde move_to: hacia la amenaza más cercana (el perfil táctico
##   elige la que deja menos amenazas a su espalda y flancos). end_facing() la recalcula al final del
##   turno por si cayó alguien.
## Enemigos, por perfil (monsters.*.ai; sin perfil, agresivo):
## - agresivo: ataca al de menos PV al que llegue; si no llega a nadie, se acerca al más cercano.
## - enjambre: va al objetivo que ya tiene más compañeros de enjambre al lado (y si no, al de menos
##   DEF) y ocupa otra casilla vecina suya: así rodean (el ataque conjunto en sí es T6).
## - táctico: ataca primero al apoyo si llega, si no al de menos PV, desde la espalda o el flanco si
##   puede y con la casilla menos expuesta; usa sus roles (Vendar, Cubrir) con un compañero herido.
## - berserk: carga contra el más cercano. Nunca huye.
## - Huida con poca vida: el último enjambre de un grupo por debajo de swarm_flee_below y el táctico
##   por debajo de tactical_retreat_below van al borde más lejos del enemigo y salen del tablero
##   (TacticalBattle.leave: remove_unit y check_end); si no llegan al borde, se defienden.
## Aliados (bando del jugador), por rol y orden al grupo (battle.group_order):
## - Libre: 1) alguien por debajo de help_below: el apoyo lo Venda (alcance support_range) y el
##   defensor se pone a su lado y lo Cubre; 2) por debajo de retreat_below (no defensor): se aleja del
##   enemigo y se defiende; 3) atacante: Remate si llega a alguien por debajo de finish_below; 4) apoyo:
##   Animar a un aliado a su alcance que vaya a golpear; 5) atacar al de menos PV (empate, el de más
##   ATQ); 6) acercarse (el apoyo se queda a alcance de sus compañeros y lejos del enemigo).
## - Atacar: todos van a por player_target (el último al que atacó el Adoc) o, si no está, el de menos
##   PV; el atacante remata si puede. Si no llegan a él pero sí a otro, le golpean de paso.
## - Defender: se agrupan junto al Adoc; Vendar, Cubrir y Defender; solo atacan para rematar.
## Umbrales en balance.json (tactics.ai, que llega como battle.ai_cfg); alcances y reglas, en
## TacticalBattle y TacticalRules. run_turn() juega un turno entero sin animación (tests, IA contra IA).

const KIND_NONE: StringName = &""
const FREE: int = BattleLogic.GroupOrder.FREE
const ATTACK: int = BattleLogic.GroupOrder.ATTACK
const DEFEND: int = BattleLogic.GroupOrder.DEFEND
## Distancia "infinita" para los campos de distancia.
const FAR: int = 1 << 20

## Casillas alcanzables del que planea, calculadas una vez por plan() (se vacía al terminar).
static var _reach_cache: Dictionary = {}


# --- API ----------------------------------------------------------------------------------------

## Plan del combatiente `index` (normalmente el activo). Si ya se movió, move_to es su casilla; si
## ya actuó, action es KIND_NONE.
static func plan(b: TacticalBattle, index: int) -> Dictionary:
	var u: Dictionary = b.units[index]
	var out: Dictionary = { "actor": index, "move_to": u.cell, "action": KIND_NONE,
		"target": TacticalBattle.NONE }
	_reach_cache = {}
	if not b.is_over() and u.alive and not _foes(b, int(u.side)).is_empty():
		if int(u.side) == TacticalBattle.SIDE_ENEMY:
			_plan_enemy(b, index, out)
		else:
			_plan_ally(b, index, out)
	_reach_cache = {}
	out.facing = facing_for(b, index, out.move_to)
	return out


## Ejecuta la acción de un plan (después de mover) y devuelve el resultado de TacticalBattle, o {}
## si no hay acción o ya no vale.
static func apply_action(b: TacticalBattle, p: Dictionary) -> Dictionary:
	var t: int = int(p.get("target", TacticalBattle.NONE))
	match StringName(p.get("action", KIND_NONE)):
		TacticalBattle.KIND_ATTACK:
			return b.attack(t)
		TacticalBattle.KIND_FINISH:
			return b.attack(t, true)
		TacticalBattle.KIND_DEFEND:
			return b.defend()
		TacticalBattle.KIND_COVER:
			return b.cover(t)
		TacticalBattle.KIND_BANDAGE:
			return b.bandage(t)
		TacticalBattle.KIND_CHEER:
			return b.cheer(t)
		TacticalBattle.KIND_LEAVE:
			return b.leave(StringName(b.units[int(p.actor)].ai) == BattleLogic.AI_TACTICAL)
	return {}


## Termina el turno del activo mirando hacia la amenaza (Esperar si no movió ni actuó). Devuelve el
## coste de CT (0 si ya no estaba en su turno, p. ej. tras salir por el borde).
static func finish_turn(b: TacticalBattle) -> int:
	if b.active == TacticalBattle.NONE:
		return 0
	var facing: TacticalBoard.Facing = end_facing(b, b.active)
	if b.active_moved or b.active_acted:
		return b.end_turn(facing)
	return int(b.wait_turn(facing).get("ct_cost", 0))


## Un turno entero de la IA para el activo, sin animación: { plan, path, result, ct_cost }.
static func run_turn(b: TacticalBattle) -> Dictionary:
	var index: int = b.active
	var p: Dictionary = plan(b, index)
	var path: Array[Vector2i] = []
	if p.move_to != b.units[index].cell:
		path = b.move_active(p.move_to)
	var res: Dictionary = apply_action(b, p)
	var cost: int = finish_turn(b) if not b.is_over() else 0
	return { "plan": p, "path": path, "result": res, "ct_cost": cost }


## Orientación al terminar en su casilla actual.
static func end_facing(b: TacticalBattle, index: int) -> TacticalBoard.Facing:
	return facing_for(b, index, b.units[index].cell)


## Orientación desde `cell`: hacia la amenaza más cercana (empate, la de menos PV y luego el índice).
## El perfil táctico elige entre las 4 la que deja menos amenazas detrás (espalda 2, flanco 1, solo
## las que le llegan el turno siguiente) y, si empatan, la de la más cercana.
static func facing_for(b: TacticalBattle, index: int, cell: Vector2i) -> TacticalBoard.Facing:
	var u: Dictionary = b.units[index]
	var foes: Array[int] = _foes(b, int(u.side))
	var current: TacticalBoard.Facing = int(u.facing) as TacticalBoard.Facing
	if foes.is_empty():
		return current
	var near: int = _nearest(b, cell, foes)
	var toward: TacticalBoard.Facing = TacticalBoard.facing_toward(cell, b.units[near].cell, current)
	if StringName(u.ai) != BattleLogic.AI_TACTICAL or int(u.side) != TacticalBattle.SIDE_ENEMY:
		return toward
	var best: int = int(toward)
	var best_score: int = _exposure_facing(b, cell, int(toward), foes)
	for f: int in 4:
		var s: int = _exposure_facing(b, cell, f, foes)
		if s < best_score:
			best_score = s
			best = f
	return best as TacticalBoard.Facing


# --- Enemigos -----------------------------------------------------------------------------------

static func _plan_enemy(b: TacticalBattle, i: int, out: Dictionary) -> void:
	var u: Dictionary = b.units[i]
	var profile: StringName = StringName(u.ai)
	if _should_flee(b, i):
		_plan_leave(b, i, out)
		return
	if profile == BattleLogic.AI_TACTICAL and _plan_help(b, i, out, _cfg(b, "help_below", 0.3)):
		return
	match profile:
		BattleLogic.AI_SWARM:
			_plan_swarm(b, i, out)
		BattleLogic.AI_TACTICAL:
			_plan_tactical(b, i, out)
		BattleLogic.AI_BERSERK:
			_plan_berserk(b, i, out)
		_:
			_plan_aggressive(b, i, out)


## Huye o se retira: el último enjambre de un grupo con poca vida, o un táctico con poca vida.
static func _should_flee(b: TacticalBattle, i: int) -> bool:
	var u: Dictionary = b.units[i]
	var ratio: float = _ratio(b, i)
	match StringName(u.ai):
		BattleLogic.AI_SWARM:
			var group: int = 0
			var alive: int = 0
			for v: Dictionary in b.units:
				if int(v.side) == int(u.side) and StringName(v.ai) == BattleLogic.AI_SWARM:
					group += 1
					if v.alive:
						alive += 1
			return group > 1 and alive == 1 and ratio < _cfg(b, "swarm_flee_below", 0.3)
		BattleLogic.AI_TACTICAL:
			return ratio < _cfg(b, "tactical_retreat_below", 0.25)
	return false


## Al borde más lejos del enemigo y fuera del tablero; si no llega al borde, se defiende.
static func _plan_leave(b: TacticalBattle, i: int, out: Dictionary) -> void:
	var foes: Array[int] = _foes(b, int(b.units[i].side))
	var reach: Dictionary = _reach(b, i)
	var best_key: Array = []
	for c: Vector2i in _sorted(reach):
		var key: Array = [0 if b.board.is_edge(c) else 1, -_min_foe_dist(b, c, foes), int(reach[c])]
		if best_key.is_empty() or _less(key, best_key):
			best_key = key
			out.move_to = c
	if not _can_act(b, i):
		return
	out.action = TacticalBattle.KIND_LEAVE if b.board.is_edge(out.move_to) else TacticalBattle.KIND_DEFEND
	out.target = i


## Agresivo: al de menos PV al que llegue (empate: más daño esperado, menos camino).
static func _plan_aggressive(b: TacticalBattle, i: int, out: Dictionary) -> void:
	var opts: Array[Dictionary] = _attack_options(b, i)
	if not opts.is_empty():
		_take(b, i, out, _best(opts, func(o: Dictionary) -> Array:
			return [int(b.units[o.target].hp), -float(o.expected), int(o.cost)]))
		return
	_approach(b, i, out, _nearest(b, b.units[i].cell, _foes(b, int(b.units[i].side))))


## Berserk: carga contra el más cercano.
static func _plan_berserk(b: TacticalBattle, i: int, out: Dictionary) -> void:
	var here: Vector2i = b.units[i].cell
	var opts: Array[Dictionary] = _attack_options(b, i)
	if not opts.is_empty():
		_take(b, i, out, _best(opts, func(o: Dictionary) -> Array:
			return [TacticalRules.distance(here, b.units[o.target].cell), int(b.units[o.target].hp),
				-float(o.expected), int(o.cost)]))
		return
	_approach(b, i, out, _nearest(b, here, _foes(b, int(b.units[i].side))))


## Enjambre: rodea. El objetivo con más compañeros de enjambre al lado, luego el de menos DEF.
static func _plan_swarm(b: TacticalBattle, i: int, out: Dictionary) -> void:
	var opts: Array[Dictionary] = _attack_options(b, i)
	if not opts.is_empty():
		_take(b, i, out, _best(opts, func(o: Dictionary) -> Array:
			return [-_swarm_around(b, i, int(o.target)), int(b.units[o.target].def),
				int(b.units[o.target].hp), int(o.cost)]))
		return
	var here: Vector2i = b.units[i].cell
	var foes: Array[int] = _foes(b, int(b.units[i].side))
	var focus: int = foes[0]
	var focus_key: Array = []
	for f: int in foes:
		var key: Array = [-_swarm_around(b, i, f), int(b.units[f].def),
			TacticalRules.distance(here, b.units[f].cell), f]
		if focus_key.is_empty() or _less(key, focus_key):
			focus_key = key
			focus = f
	_approach(b, i, out, focus)


## Táctico: el apoyo si llega, si no el de menos PV; por la espalda o el flanco y lo menos expuesto.
static func _plan_tactical(b: TacticalBattle, i: int, out: Dictionary) -> void:
	var foes: Array[int] = _foes(b, int(b.units[i].side))
	var opts: Array[Dictionary] = _attack_options(b, i)
	if not opts.is_empty():
		_take(b, i, out, _best(opts, func(o: Dictionary) -> Array:
			var t: Dictionary = b.units[o.target]
			return [0 if t.role == TacticalBattle.ROLE_SUPPORT else 1, int(t.hp), _rel_rank(int(o.relation)),
				_exposure(b, o.cell, foes, int(o.target)), int(o.cost)]))
		return
	var target: int = foes[0]
	var target_key: Array = []
	var here: Vector2i = b.units[i].cell
	for f: int in foes:
		var t: Dictionary = b.units[f]
		var key: Array = [0 if t.role == TacticalBattle.ROLE_SUPPORT else 1, int(t.hp),
			TacticalRules.distance(here, t.cell), f]
		if target_key.is_empty() or _less(key, target_key):
			target_key = key
			target = f
	_approach(b, i, out, target, true)


# --- Aliados ------------------------------------------------------------------------------------

static func _plan_ally(b: TacticalBattle, i: int, out: Dictionary) -> void:
	match b.group_order:
		ATTACK:
			_plan_focus(b, i, out)
		DEFEND:
			_plan_hold(b, i, out)
		_:
			_plan_free(b, i, out)


## Orden Libre: la lista de prioridades de su rol.
static func _plan_free(b: TacticalBattle, i: int, out: Dictionary) -> void:
	var u: Dictionary = b.units[i]
	var foes: Array[int] = _foes(b, int(u.side))
	if _plan_help(b, i, out, _cfg(b, "help_below", 0.3)):
		return
	if u.role != TacticalBattle.ROLE_DEFENDER and _ratio(b, i) < _cfg(b, "retreat_below", 0.2):
		_plan_retreat(b, i, out)
		return
	if _plan_finish(b, i, out):
		return
	if _plan_cheer(b, i, out):
		return
	var opts: Array[Dictionary] = _attack_options(b, i)
	if not opts.is_empty():
		_take(b, i, out, _best(opts, func(o: Dictionary) -> Array:
			var t: Dictionary = b.units[o.target]
			return [int(t.hp), -int(t.atk), -float(o.expected), int(o.cost)]))
		return
	if u.role == TacticalBattle.ROLE_SUPPORT:
		_plan_stay_near(b, i, out)
		return
	_approach(b, i, out, _nearest(b, u.cell, foes))


## Orden Atacar: todos al objetivo del Adoc (o al de menos PV).
static func _plan_focus(b: TacticalBattle, i: int, out: Dictionary) -> void:
	var foes: Array[int] = _foes(b, int(b.units[i].side))
	var target: int = b.player_target
	if target < 0 or target >= b.units.size() or not b.units[target].alive \
			or int(b.units[target].side) == int(b.units[i].side):
		target = _weakest(b, foes)
	var opts: Array[Dictionary] = _attack_options(b, i, [target])
	if not opts.is_empty():
		_take(b, i, out, _best(opts, func(o: Dictionary) -> Array:
			return [-float(o.expected), _rel_rank(int(o.relation)), int(o.cost)]))
		return
	_approach(b, i, out, target)
	# De paso: si desde donde queda llega a otro, le golpea.
	if _can_act(b, i):
		var near: Array[Dictionary] = _attack_options(b, i, foes, [out.move_to])
		if not near.is_empty():
			_take(b, i, out, _best(near, func(o: Dictionary) -> Array:
				return [int(b.units[o.target].hp), int(o.target)]))


## Orden Defender: Vendar, Cubrir, rematar si puede y, si no, agruparse junto al Adoc y defenderse.
static func _plan_hold(b: TacticalBattle, i: int, out: Dictionary) -> void:
	var u: Dictionary = b.units[i]
	if _plan_help(b, i, out, 1.0, true):
		return
	if _plan_finish(b, i, out):
		return
	var leader: int = _leader(b, int(u.side))
	var reach: Dictionary = _reach(b, i)
	if leader != TacticalBattle.NONE and leader != i:
		var foes: Array[int] = _foes(b, int(u.side))
		var lc: Vector2i = b.units[leader].cell
		var best_key: Array = []
		for c: Vector2i in _sorted(reach):
			var key: Array = [TacticalRules.distance(c, lc), -_min_foe_dist(b, c, foes), int(reach[c])]
			if best_key.is_empty() or _less(key, best_key):
				best_key = key
				out.move_to = c
	if _can_act(b, i):
		out.action = TacticalBattle.KIND_DEFEND
		out.target = i


## Ayuda a un compañero por debajo de `below` (o a cualquiera herido con `any_hurt`): el apoyo lo
## Venda y el defensor lo Cubre (a su lado). Devuelve si lo planeó.
static func _plan_help(b: TacticalBattle, i: int, out: Dictionary, below: float, any_hurt: bool = false) -> bool:
	if not _can_act(b, i):
		return false
	var u: Dictionary = b.units[i]
	var foes: Array[int] = _foes(b, int(u.side))
	var reach: Dictionary = _reach(b, i)
	var range_max: int = int(b.actions_cfg.get("support_range", 2))
	if u.role == TacticalBattle.ROLE_SUPPORT and int(u.heals_left) > 0:
		for patient: int in _hurt_friends(b, i, below, true):
			if patient == i and int(b.units[i].hp) >= int(b.units[i].max_hp):
				continue
			var best_key: Array = []
			var best_cell := Vector2i(-1, -1)
			for c: Vector2i in _sorted(reach):
				var pc: Vector2i = c if patient == i else b.units[patient].cell
				if TacticalRules.distance(c, pc) > range_max:
					continue
				var key: Array = [-mini(_min_foe_dist(b, c, foes), 3), int(reach[c])]
				if best_key.is_empty() or _less(key, best_key):
					best_key = key
					best_cell = c
			if not best_key.is_empty():
				out.move_to = best_cell
				out.action = TacticalBattle.KIND_BANDAGE
				out.target = patient
				return true
	if u.role == TacticalBattle.ROLE_DEFENDER and int(u.turns) >= int(u.cover_ready):
		var threshold: float = 1.01 if any_hurt else below
		for patient: int in _hurt_friends(b, i, threshold, false):
			var pc: Vector2i = b.units[patient].cell
			var near_foe: int = _nearest(b, pc, foes)
			var best_key: Array = []
			var best_cell := Vector2i(-1, -1)
			for c: Vector2i in _sorted(reach):
				if not TacticalBoard.are_adjacent(c, pc):
					continue
				var key: Array = [TacticalRules.distance(c, b.units[near_foe].cell), int(reach[c])]
				if best_key.is_empty() or _less(key, best_key):
					best_key = key
					best_cell = c
			if not best_key.is_empty():
				out.move_to = best_cell
				out.action = TacticalBattle.KIND_COVER
				out.target = patient
				return true
	return false


## Remate (atacante con usos): al de menos PV por debajo de finish_below al que llegue.
static func _plan_finish(b: TacticalBattle, i: int, out: Dictionary) -> bool:
	var u: Dictionary = b.units[i]
	if u.role != TacticalBattle.ROLE_ATTACKER or int(u.finishes_left) <= 0:
		return false
	var low: Array[int] = []
	for f: int in _foes(b, int(u.side)):
		if _ratio(b, f) < b.finish_below:
			low.append(f)
	var opts: Array[Dictionary] = _attack_options(b, i, low)
	if opts.is_empty():
		return false
	_take(b, i, out, _best(opts, func(o: Dictionary) -> Array:
		return [int(b.units[o.target].hp), -float(o.expected), int(o.cost)]))
	return true


## Animar (apoyo con usos): a un compañero a su alcance que esté junto a un enemigo (va a golpear);
## empate, el de más ATQ. Desde la casilla más alejada del enemigo.
static func _plan_cheer(b: TacticalBattle, i: int, out: Dictionary) -> bool:
	var u: Dictionary = b.units[i]
	if u.role != TacticalBattle.ROLE_SUPPORT or int(u.cheers_left) <= 0 or not _can_act(b, i):
		return false
	var foes: Array[int] = _foes(b, int(u.side))
	var range_max: int = int(b.actions_cfg.get("support_range", 2))
	var friends: Array[int] = []
	for k: int in b.units.size():
		var v: Dictionary = b.units[k]
		if k != i and v.alive and int(v.side) == int(u.side) and int(v.cheer) <= 0 and _touches_foe(b, k, foes):
			friends.append(k)
	friends.sort_custom(func(x: int, y: int) -> bool:
		return int(b.units[x].atk) > int(b.units[y].atk) if int(b.units[x].atk) != int(b.units[y].atk) else x < y)
	var reach: Dictionary = _reach(b, i)
	for f: int in friends:
		var best_key: Array = []
		var best_cell := Vector2i(-1, -1)
		for c: Vector2i in _sorted(reach):
			if TacticalRules.distance(c, b.units[f].cell) > range_max:
				continue
			var key: Array = [-mini(_min_foe_dist(b, c, foes), 3), int(reach[c])]
			if best_key.is_empty() or _less(key, best_key):
				best_key = key
				best_cell = c
		if not best_key.is_empty():
			out.move_to = best_cell
			out.action = TacticalBattle.KIND_CHEER
			out.target = f
			return true
	return false


## Con poca vida: se aleja del enemigo más cercano (sin separarse del grupo si empata) y se defiende.
static func _plan_retreat(b: TacticalBattle, i: int, out: Dictionary) -> void:
	var u: Dictionary = b.units[i]
	var foes: Array[int] = _foes(b, int(u.side))
	var reach: Dictionary = _reach(b, i)
	var best_key: Array = []
	for c: Vector2i in _sorted(reach):
		var key: Array = [-_min_foe_dist(b, c, foes), _min_friend_dist(b, i, c), int(reach[c])]
		if best_key.is_empty() or _less(key, best_key):
			best_key = key
			out.move_to = c
	if _can_act(b, i):
		out.action = TacticalBattle.KIND_DEFEND
		out.target = i


## Apoyo sin nada que hacer: a alcance del compañero más cercano al enemigo y lejos del enemigo.
static func _plan_stay_near(b: TacticalBattle, i: int, out: Dictionary) -> void:
	var u: Dictionary = b.units[i]
	var foes: Array[int] = _foes(b, int(u.side))
	var range_max: int = int(b.actions_cfg.get("support_range", 2))
	var front: int = TacticalBattle.NONE
	var front_d: int = FAR
	for k: int in b.units.size():
		var v: Dictionary = b.units[k]
		if k != i and v.alive and int(v.side) == int(u.side):
			var d: int = _min_foe_dist(b, v.cell, foes)
			if d < front_d:
				front_d = d
				front = k
	if front == TacticalBattle.NONE:
		_approach(b, i, out, _nearest(b, u.cell, foes))
		return
	var reach: Dictionary = _reach(b, i)
	var best_key: Array = []
	for c: Vector2i in _sorted(reach):
		var d: int = TacticalRules.distance(c, b.units[front].cell)
		var key: Array = [maxi(0, d - range_max), -mini(_min_foe_dist(b, c, foes), 3), int(reach[c])]
		if best_key.is_empty() or _less(key, best_key):
			best_key = key
			out.move_to = c


# --- Opciones de ataque y acercamiento ------------------------------------------------------------

## Opciones de ataque desde las casillas alcanzables (o `cells`), contra `targets` (por defecto,
## todos los enemigos en pie): [{ cell, target, cost, relation, hit, expected }]. Vacío si ya actuó.
static func _attack_options(b: TacticalBattle, i: int, targets: Array = [], cells: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _can_act(b, i):
		return out
	var u: Dictionary = b.units[i]
	var list: Array = targets if not targets.is_empty() else _foes(b, int(u.side))
	var reach: Dictionary = _reach(b, i)
	var from_cells: Array[Vector2i] = []
	if cells.is_empty():
		from_cells = _sorted(reach)
	else:
		for c: Variant in cells:
			if reach.has(c):
				from_cells.append(c as Vector2i)
	var min_damage: int = int(b.attack_cfg.get("min_damage", 1))
	for c: Vector2i in from_cells:
		for t: Variant in list:
			var ti: int = int(t)
			var tu: Dictionary = b.units[ti]
			if not tu.alive or int(tu.side) == int(u.side):
				continue
			if not TacticalRules.can_melee(b.board, c, tu.cell, int(u.jump)):
				continue
			var rel: TacticalRules.Relation = TacticalRules.relation(tu.cell, int(tu.facing), c)
			var height: int = b.board.level_at(c) - b.board.level_at(tu.cell)
			var hit: int = TacticalRules.hit_chance(TacticalRules.evasion(int(tu.agi), rel, height, b.actions_cfg), b.actions_cfg)
			var dmg: int = maxi(min_damage, int(u.atk) + int(u.cheer) - int(tu.def)
				+ TacticalRules.position_bonus(rel, height, b.actions_cfg))
			out.append({ "cell": c, "target": ti, "cost": int(reach[c]), "relation": rel, "hit": hit,
				"expected": hit * dmg / 100.0 })
	return out


## Fija en el plan una opción de ataque (Remate si es atacante con usos y el objetivo está bajo).
static func _take(b: TacticalBattle, i: int, out: Dictionary, o: Dictionary) -> void:
	var u: Dictionary = b.units[i]
	out.move_to = o.cell
	out.target = int(o.target)
	var finish: bool = u.role == TacticalBattle.ROLE_ATTACKER and int(u.finishes_left) > 0 \
		and _ratio(b, int(o.target)) < b.finish_below
	out.action = TacticalBattle.KIND_FINISH if finish else TacticalBattle.KIND_ATTACK


## Se acerca a `target`: la casilla alcanzable con menos camino a pie hasta una casilla desde la que
## golpearle (sin cruzar enemigos). Si no hay camino, por distancia en línea. `careful`: entre las de
## igual camino, la menos expuesta (táctico).
static func _approach(b: TacticalBattle, i: int, out: Dictionary, target: int, careful: bool = false) -> void:
	if target == TacticalBattle.NONE:
		return
	var u: Dictionary = b.units[i]
	var foes: Array[int] = _foes(b, int(u.side))
	var tc: Vector2i = b.units[target].cell
	var field: Dictionary = _distance_field(b, i, tc)
	var reach: Dictionary = _reach(b, i)
	var best_key: Array = []
	for c: Vector2i in _sorted(reach):
		var key: Array = [int(field.get(c, FAR)), _exposure(b, c, foes, TacticalBattle.NONE) if careful else 0,
			TacticalRules.distance(c, tc), int(reach[c])]
		if best_key.is_empty() or _less(key, best_key):
			best_key = key
			out.move_to = c


## Camino a pie (coste de Mov, sin límite) desde cada casilla hasta alguna libre desde la que `i`
## golpea a quien está en `target_cell` (TacticalBoard.walk_cost_to). Los enemigos de `i` no se
## cruzan; sus compañeros sí, pero sus casillas no sirven de meta (así el enjambre busca un lado libre).
static func _distance_field(b: TacticalBattle, i: int, target_cell: Vector2i) -> Dictionary:
	var u: Dictionary = b.units[i]
	var blocked: Dictionary = {}
	var taken: Dictionary = {}
	for k: int in b.units.size():
		var v: Dictionary = b.units[k]
		if k != i and v.alive:
			taken[v.cell] = true
			if int(v.side) != int(u.side):
				blocked[v.cell] = true
	var goals: Array[Vector2i] = []
	for c: Vector2i in b.board.neighbors(target_cell):
		if not taken.has(c) and TacticalRules.can_melee(b.board, c, target_cell, int(u.jump)):
			goals.append(c)
	return b.board.walk_cost_to(goals, int(u.jump), int(u.drop), blocked)


# --- Ayudas -------------------------------------------------------------------------------------

static func _reach(b: TacticalBattle, i: int) -> Dictionary:
	if not _reach_cache.has(i):
		_reach_cache[i] = b.reachable_for(i)
	return _reach_cache[i]


static func _cfg(b: TacticalBattle, key: String, fallback: float) -> float:
	return float(b.ai_cfg.get(key, fallback))


static func _can_act(b: TacticalBattle, i: int) -> bool:
	if b.is_over():
		return false
	return not b.active_acted if i == b.active else true


static func _ratio(b: TacticalBattle, i: int) -> float:
	return float(b.units[i].hp) / float(maxi(1, int(b.units[i].max_hp)))


static func _foes(b: TacticalBattle, side: int) -> Array[int]:
	var out: Array[int] = []
	for k: int in b.units.size():
		if b.units[k].alive and int(b.units[k].side) != side:
			out.append(k)
	return out


static func _leader(b: TacticalBattle, side: int) -> int:
	for k: int in b.units.size():
		if b.units[k].alive and int(b.units[k].side) == side and b.units[k].leader:
			return k
	return TacticalBattle.NONE


## Compañeros (y él mismo con `with_self`) por debajo de `below` de PV, del más herido al menos.
static func _hurt_friends(b: TacticalBattle, i: int, below: float, with_self: bool) -> Array[int]:
	var out: Array[int] = []
	for k: int in b.units.size():
		var v: Dictionary = b.units[k]
		if v.alive and int(v.side) == int(b.units[i].side) and (with_self or k != i) and _ratio(b, k) < below:
			out.append(k)
	out.sort_custom(func(x: int, y: int) -> bool:
		return _ratio(b, x) < _ratio(b, y) if _ratio(b, x) != _ratio(b, y) else x < y)
	return out


## El de menos PV (empate, más ATQ; luego el índice).
static func _weakest(b: TacticalBattle, list: Array[int]) -> int:
	var best: int = TacticalBattle.NONE
	for f: int in list:
		if best == TacticalBattle.NONE or _less([int(b.units[f].hp), -int(b.units[f].atk)],
				[int(b.units[best].hp), -int(b.units[best].atk)]):
			best = f
	return best


## El más cercano a `cell` (empate, menos PV; luego el índice).
static func _nearest(b: TacticalBattle, cell: Vector2i, list: Array[int]) -> int:
	var best: int = TacticalBattle.NONE
	var best_key: Array = []
	for f: int in list:
		var key: Array = [TacticalRules.distance(cell, b.units[f].cell), int(b.units[f].hp)]
		if best_key.is_empty() or _less(key, best_key):
			best_key = key
			best = f
	return best


static func _min_foe_dist(b: TacticalBattle, cell: Vector2i, foes: Array[int]) -> int:
	var d: int = FAR
	for f: int in foes:
		d = mini(d, TacticalRules.distance(cell, b.units[f].cell))
	return d


static func _min_friend_dist(b: TacticalBattle, i: int, cell: Vector2i) -> int:
	var d: int = 0
	var found: bool = false
	for k: int in b.units.size():
		var v: Dictionary = b.units[k]
		if k != i and v.alive and int(v.side) == int(b.units[i].side):
			var dk: int = TacticalRules.distance(cell, v.cell)
			d = dk if not found else mini(d, dk)
			found = true
	return d


static func _touches_foe(b: TacticalBattle, k: int, foes: Array[int]) -> bool:
	for f: int in foes:
		if TacticalBoard.are_adjacent(b.units[k].cell, b.units[f].cell):
			return true
	return false


## Compañeros de enjambre de `i` ya vecinos del objetivo.
static func _swarm_around(b: TacticalBattle, i: int, target: int) -> int:
	var n: int = 0
	for k: int in b.units.size():
		var v: Dictionary = b.units[k]
		if k != i and v.alive and int(v.side) == int(b.units[i].side) and StringName(v.ai) == BattleLogic.AI_SWARM \
				and TacticalBoard.are_adjacent(v.cell, b.units[target].cell):
			n += 1
	return n


## Enemigos (salvo `except`) que llegarían a golpear `cell` el turno siguiente (Mov + 1).
static func _exposure(b: TacticalBattle, cell: Vector2i, foes: Array[int], except: int) -> int:
	var n: int = 0
	for f: int in foes:
		if f != except and TacticalRules.distance(cell, b.units[f].cell) <= int(b.units[f].mov) + 1:
			n += 1
	return n


## Amenazas por detrás si mira hacia `facing` desde `cell`: espalda 2, flanco 1 (solo las que le
## llegan el turno siguiente).
static func _exposure_facing(b: TacticalBattle, cell: Vector2i, facing: int, foes: Array[int]) -> int:
	var s: int = 0
	for f: int in foes:
		var fc: Vector2i = b.units[f].cell
		if TacticalRules.distance(cell, fc) > int(b.units[f].mov) + 1:
			continue
		match TacticalRules.relation(cell, facing, fc):
			TacticalRules.Relation.BACK:
				s += 2
			TacticalRules.Relation.FLANK:
				s += 1
	return s


## Espalda antes que flanco, flanco antes que frente.
static func _rel_rank(rel: int) -> int:
	match rel:
		TacticalRules.Relation.BACK:
			return 0
		TacticalRules.Relation.FLANK:
			return 1
	return 2


static func _best(opts: Array[Dictionary], key: Callable) -> Dictionary:
	var best: Dictionary = opts[0]
	var best_key: Array = key.call(best)
	for k: int in range(1, opts.size()):
		var kk: Array = key.call(opts[k])
		if _less(kk, best_key):
			best_key = kk
			best = opts[k]
	return best


## Comparación lexicográfica de claves (números).
static func _less(a: Array, c: Array) -> bool:
	for k: int in mini(a.size(), c.size()):
		if a[k] != c[k]:
			return a[k] < c[k]
	return a.size() < c.size()


## Claves de un { Vector2i: coste } en orden fijo (fila y columna).
static func _sorted(reach: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k: Variant in reach.keys():
		out.append(k as Vector2i)
	out.sort_custom(func(x: Vector2i, y: Vector2i) -> bool: return x.y < y.y or (x.y == y.y and x.x < y.x))
	return out
