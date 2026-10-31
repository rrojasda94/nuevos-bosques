class_name TacticalAI
extends RefCounted
## IA del combate táctico en la cuadrícula (ia-de-combate.md, "Traducción a la cuadrícula";
## combate-tactico.md; ADR 0016; PR T5; perfiles y reglas nuevas tras el playtest en P2,
## ajustes-playtest-0.5.md §6). Clase pura sin estado: dado un TacticalBattle y un combatiente,
## plan() devuelve un plan determinista con la seed del combate (el único azar es el top-2 de los
## enemigos, con battle.ai_rng; los empates, por casilla y por índice):
## { actor, move_to, action, target, facing }.
## - move_to: casilla a la que moverse (la suya si no se mueve); siempre dentro de reachable_for.
## - action: un KIND_* de TacticalBattle (attack, finish, defend, cover, bandage, cheer, leave; draw
##   si empezó con el arma en la funda, P4) o
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
## - berserk: carga contra el más cercano. Nunca huye ni Defiende, y no tira (sin azar).
## - guardián (P2, Botarramas): no se aleja más de guard_radius casillas de su casilla inicial
##   (`home`); ataca si llega desde ahí; si no, se pone lo más cerca del Adoc que le deja su sitio y
##   Defiende 1 de cada guard_defend_every turnos. Pasados guard_advance_after turnos suyos, avanza
##   como un agresivo. No corta la huida.
## - látigo (P2, Ofomni): alcance [1, 2] en línea (monsters.ofomni.attack_range). Al de menos PV y,
##   a igualdad, desde 2 casillas antes que adyacente; la altura le puntúa doble.
## - emboscadora (P2, Aledra): busca la espalda o el flanco; si solo llega de frente, Espera fuera
##   del alcance de sus enemigos (o se aparta a una casilla fuera de él) para golpear por detrás en
##   el siguiente turno. La altura le puntúa doble.
## - Reglas comunes (P2; todos los enemigos salvo el berserk):
##   - Cortar la huida (emboscadora, enjambre, táctico y látigo): si el Adoc está a cut_flee_edge
##     casillas o menos del borde y su flee_chance pasa de cut_flee_above, le ataca desde una casilla
##     adyacente si puede; si no puede atacar a nadie, se pone en la casilla alcanzable más cercana a
##     la casilla de borde más próxima al Adoc (si no llega a 1 de ella, se acerca como siempre).
##   - Defender: si no ataca este turno, algún enemigo le alcanza en su siguiente turno y le queda
##     menos de defend_below de PV, se mueve y Defiende.
##   - Esperar (táctico y emboscadora): si acercarse sin atacar le deja al alcance de 2 o más
##     enemigos, Espera (CT −60). Si ya lleva wait_max turnos seguidos sin actuar (`waits`), no
##     Espera, para que no haya bucles.
##   - Altura: +height_weight por nivel de la casilla (doble para el látigo y la emboscadora) en la
##     puntuación de las casillas de ataque y, al acercarse, a igualdad de camino.
##   - Azar top-2: entre las opciones de ataque de la misma prioridad (la clave del perfil), la de
##     más puntuación (daño esperado + altura) con top2_weight y la segunda con el resto, solo si
##     puntúa al menos top2_margin de la mejor. Nunca una opción de otra prioridad.
## - Área anunciada (T6): quien tiene un área anunciada la golpea en su turno sin moverse (KIND_AREA).
##   Quien va a anunciarla al terminar el turno (TacticalBattle.will_announce) elige la orientación
##   cuya área pilla a más enemigos (empate, hacia el más cercano) y, el berserk, entre las casillas
##   desde las que golpea a su objetivo, la que deja más enemigos dentro.
## - Enjambre y ataque conjunto (T6): rodean; el ataque conjunto lo resuelve TacticalBattle.attack
##   cuando hay compañeros vecinos del mismo objetivo.
## - Huida con poca vida: el último enjambre de un grupo por debajo de swarm_flee_below y el táctico
##   por debajo de tactical_retreat_below van al borde más lejos del enemigo y salen del tablero
##   (TacticalBattle.leave: remove_unit y check_end); si no llegan al borde, se defienden.
## Aliados (bando del jugador), por rol y orden al grupo (battle.group_order):
## - Libre: 1) alguien por debajo de help_below: el apoyo lo Venda (alcance support_range) y el
##   defensor se pone a su lado y lo Cubre; 2) si está en un área anunciada (T6), sale de ella (y
##   golpea desde fuera si llega); si no puede salir, se defiende; luego, por debajo de
##   retreat_below (no defensor y con algún compañero en pie; el último pelea): se aleja del
##   enemigo y se defiende; 3) atacante: Remate si llega a alguien por debajo de finish_below; 4) apoyo:
##   Animar a un aliado a su alcance que vaya a golpear; 5) atacar al de menos PV (empate, el de más
##   ATQ); 6) acercarse (el apoyo se queda a alcance de sus compañeros y lejos del enemigo).
## - Atacar: todos van a por player_target (el último al que atacó el Adoc) o, si no está, el de menos
##   PV; el atacante remata si puede. Si no llegan a él pero sí a otro, le golpean de paso.
## - Defender: se agrupan junto al Adoc (fuera de las áreas anunciadas); Vendar, Cubrir y Defender;
##   solo atacan para rematar.
## Umbrales en balance.json (tactics.ai, que llega como battle.ai_cfg); alcances y reglas, en
## TacticalBattle y TacticalRules. run_turn() juega un turno entero sin animación (tests, IA contra IA).

const KIND_NONE: StringName = &""
const FREE: int = BattleLogic.GroupOrder.FREE
const ATTACK: int = BattleLogic.GroupOrder.ATTACK
const DEFEND: int = BattleLogic.GroupOrder.DEFEND
## Distancia "infinita" para los campos de distancia.
const FAR: int = 1 << 20
## Perfiles que cortan la huida del Adoc (P2).
const CUTTERS: Array[StringName] = [BattleLogic.AI_AMBUSHER, BattleLogic.AI_SWARM, BattleLogic.AI_TACTICAL,
	BattleLogic.AI_WHIP]
## Perfiles a los que la altura les puntúa doble (P2).
const HIGH_LOVERS: Array[StringName] = [BattleLogic.AI_WHIP, BattleLogic.AI_AMBUSHER]

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
		if bool(u.get("sheathed", false)) and _can_act(b, index):
			# P4: con el arma en la funda (emboscada), lo primero es desenfundar (sin moverse).
			out.action = TacticalBattle.KIND_DRAW
		elif int(u.side) == TacticalBattle.SIDE_ENEMY:
			_plan_enemy(b, index, out)
		else:
			_plan_ally(b, index, out)
	_reach_cache = {}
	var attacks: int = 1 if [TacticalBattle.KIND_ATTACK, TacticalBattle.KIND_FINISH,
		TacticalBattle.KIND_AREA].has(StringName(out.action)) else 0
	out.facing = facing_for(b, index, out.move_to, attacks)
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
		TacticalBattle.KIND_AREA:
			return b.area_strike()
		TacticalBattle.KIND_DRAW:
			return b.draw_weapon()
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
## las que le llegan el turno siguiente) y, si empatan, la de la más cercana. Quien va a anunciar su
## área al terminar (`extra_attacks`: ataques que aún hará este turno) mira hacia donde pilla a más.
static func facing_for(b: TacticalBattle, index: int, cell: Vector2i, extra_attacks: int = 0) -> TacticalBoard.Facing:
	var u: Dictionary = b.units[index]
	var foes: Array[int] = _foes(b, int(u.side))
	var current: TacticalBoard.Facing = int(u.facing) as TacticalBoard.Facing
	if foes.is_empty():
		return current
	var near: int = _nearest(b, cell, foes)
	var toward: TacticalBoard.Facing = TacticalBoard.facing_toward(cell, b.units[near].cell, current)
	if b.will_announce(index, extra_attacks):
		return int(best_area(b, index, cell, toward).facing) as TacticalBoard.Facing
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

## La orientación cuya área (TacticalBattle.area_cells) desde `cell` pilla a más enemigos de `index`
## (empate: `prefer`, luego el orden N, E, S, O): { facing, hits }.
static func best_area(b: TacticalBattle, index: int, cell: Vector2i, prefer: int) -> Dictionary:
	var best: Dictionary = {}
	for f: int in 4:
		var hits: int = b.foes_in(index, b.area_cells(cell, f)).size()
		var key: Array = [-hits, 0 if f == prefer else 1, f]
		if best.is_empty() or _less(key, best.key):
			best = { "facing": f, "hits": hits, "key": key }
	return { "facing": best.facing, "hits": best.hits }


static func _plan_enemy(b: TacticalBattle, i: int, out: Dictionary) -> void:
	var u: Dictionary = b.units[i]
	var profile: StringName = StringName(u.ai)
	if i == b.active and _can_act(b, i) and not (u.announce as Array).is_empty():
		out.action = TacticalBattle.KIND_AREA
		return
	if _should_flee(b, i):
		_plan_leave(b, i, out)
		return
	if profile == BattleLogic.AI_TACTICAL and _plan_help(b, i, out, _cfg(b, "help_below", 0.3)):
		return
	if not (CUTTERS.has(profile) and _plan_cut_flee(b, i, out)):
		match profile:
			BattleLogic.AI_SWARM:
				_plan_swarm(b, i, out)
			BattleLogic.AI_TACTICAL:
				_plan_tactical(b, i, out)
			BattleLogic.AI_BERSERK:
				_plan_berserk(b, i, out)
			BattleLogic.AI_GUARDIAN:
				_plan_guardian(b, i, out)
			BattleLogic.AI_WHIP:
				_plan_whip(b, i, out)
			BattleLogic.AI_AMBUSHER:
				_plan_ambusher(b, i, out)
			_:
				_plan_aggressive(b, i, out)
	# Defender (P2): sin ataque este turno, al alcance de alguien y con poca vida.
	if profile != BattleLogic.AI_BERSERK and StringName(out.action) == KIND_NONE and _can_act(b, i) \
			and _ratio(b, i) < _cfg(b, "defend_below", 0.5) \
			and _exposure(b, out.move_to, _foes(b, int(u.side)), TacticalBattle.NONE) > 0:
		out.action = TacticalBattle.KIND_DEFEND
		out.target = i


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
					# Los que esperan en el borde (refuerzos, T1b) también cuentan: no es el último.
					if v.alive or v.get("waiting", false):
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
		_take(b, i, out, _pick(b, i, opts, func(o: Dictionary) -> Array:
			return [int(b.units[o.target].hp)]))
		return
	_approach(b, i, out, _nearest(b, b.units[i].cell, _foes(b, int(b.units[i].side))))


## Berserk: carga contra el más cercano.
static func _plan_berserk(b: TacticalBattle, i: int, out: Dictionary) -> void:
	var here: Vector2i = b.units[i].cell
	var opts: Array[Dictionary] = _attack_options(b, i)
	if not opts.is_empty():
		var announce: bool = b.will_announce(i, 1)
		_take(b, i, out, _best(opts, func(o: Dictionary) -> Array:
			var area: int = int(best_area(b, i, o.cell, -1).hits) if announce else 0
			return [TacticalRules.distance(here, b.units[o.target].cell), int(b.units[o.target].hp),
				-area, -float(o.expected), int(o.cost)]))
		return
	_approach(b, i, out, _nearest(b, here, _foes(b, int(b.units[i].side))))


## Enjambre: rodea. El objetivo con más compañeros de enjambre al lado, luego el de menos DEF.
static func _plan_swarm(b: TacticalBattle, i: int, out: Dictionary) -> void:
	var opts: Array[Dictionary] = _attack_options(b, i)
	if not opts.is_empty():
		_take(b, i, out, _pick(b, i, opts, func(o: Dictionary) -> Array:
			return [-_swarm_around(b, i, int(o.target)), int(b.units[o.target].def),
				int(b.units[o.target].hp)]))
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
		_take(b, i, out, _pick(b, i, opts, func(o: Dictionary) -> Array:
			var t: Dictionary = b.units[o.target]
			return [0 if t.role == TacticalBattle.ROLE_SUPPORT else 1, int(t.hp), _rel_rank(int(o.relation)),
				_exposure(b, o.cell, foes, int(o.target))]))
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
	_approach_or_wait(b, i, out, target, true)


## Guardián (P2, Botarramas): no se aleja de su sitio, Defiende a ratos y avanza si nadie se acerca.
static func _plan_guardian(b: TacticalBattle, i: int, out: Dictionary) -> void:
	var u: Dictionary = b.units[i]
	if int(u.turns) > int(_cfg(b, "guard_advance_after", 3)):
		_plan_aggressive(b, i, out)
		return
	var home: Vector2i = u.get("home", u.cell)
	var radius: int = int(_cfg(b, "guard_radius", 2))
	var reach: Dictionary = _reach(b, i)
	var zone: Array[Vector2i] = []
	for c: Vector2i in _sorted(reach):
		if TacticalRules.distance(c, home) <= radius:
			zone.append(c)
	if zone.is_empty():
		zone.append(u.cell)
	var opts: Array[Dictionary] = _attack_options(b, i, [], zone)
	if not opts.is_empty():
		_take(b, i, out, _pick(b, i, opts, func(o: Dictionary) -> Array:
			return [int(b.units[o.target].hp)]))
		return
	var foes: Array[int] = _foes(b, int(u.side))
	var focus: int = _leader(b, int(b.units[foes[0]].side))
	if focus == TacticalBattle.NONE:
		focus = _nearest(b, u.cell, foes)
	var fc: Vector2i = b.units[focus].cell
	var best_key: Array = []
	for c: Vector2i in zone:
		var key: Array = [TacticalRules.distance(c, fc), -_height_pts(b, i, c), TacticalRules.distance(c, home),
			int(reach.get(c, 0))]
		if best_key.is_empty() or _less(key, best_key):
			best_key = key
			out.move_to = c
	var every: int = maxi(1, int(_cfg(b, "guard_defend_every", 2)))
	if _can_act(b, i) and (int(u.turns) - 1) % every == 0:
		out.action = TacticalBattle.KIND_DEFEND
		out.target = i


## Látigo (P2, Ofomni): al de menos PV, mejor desde 2 casillas que adyacente.
static func _plan_whip(b: TacticalBattle, i: int, out: Dictionary) -> void:
	var opts: Array[Dictionary] = _attack_options(b, i)
	if not opts.is_empty():
		_take(b, i, out, _pick(b, i, opts, func(o: Dictionary) -> Array:
			var tc: Vector2i = b.units[o.target].cell
			return [int(b.units[o.target].hp), 1 if TacticalBoard.are_adjacent(o.cell, tc) else 0]))
		return
	_approach(b, i, out, _nearest(b, b.units[i].cell, _foes(b, int(b.units[i].side))))


## Emboscadora (P2, Aledra): por la espalda o el flanco; si solo llega de frente, Espera fuera de
## alcance (si lleva wait_max turnos seguidos sin actuar, ataca de frente).
static func _plan_ambusher(b: TacticalBattle, i: int, out: Dictionary) -> void:
	var u: Dictionary = b.units[i]
	var foes: Array[int] = _foes(b, int(u.side))
	var opts: Array[Dictionary] = _attack_options(b, i)
	if opts.is_empty():
		_approach_or_wait(b, i, out, _nearest(b, u.cell, foes), true)
		return
	var sneaky: Array[Dictionary] = []
	for o: Dictionary in opts:
		if int(o.relation) != TacticalRules.Relation.FRONT:
			sneaky.append(o)
	if not sneaky.is_empty():
		_take(b, i, out, _pick(b, i, sneaky, func(o: Dictionary) -> Array:
			return [_rel_rank(int(o.relation)), int(b.units[o.target].hp)]))
		return
	if int(u.waits) < int(_cfg(b, "wait_max", 2)):
		var reach: Dictionary = _reach(b, i)
		var best_key: Array = []
		var best: Vector2i = u.cell
		for c: Vector2i in _sorted(reach):
			var key: Array = [_exposure(b, c, foes, TacticalBattle.NONE), 0 if c == u.cell else 1,
				_min_foe_dist(b, c, foes), int(reach[c])]
			if best_key.is_empty() or _less(key, best_key):
				best_key = key
				best = c
		if int(best_key[0]) == 0:
			out.move_to = best
			return
	_take(b, i, out, _pick(b, i, opts, func(o: Dictionary) -> Array:
		return [int(b.units[o.target].hp)]))


## Cortar la huida (P2): el Adoc está junto al borde y su huida pasa de cut_flee_above. Devuelve si lo
## planeó (atacarle desde una casilla adyacente, o interponerse si no puede atacar a nadie).
static func _plan_cut_flee(b: TacticalBattle, i: int, out: Dictionary) -> bool:
	if not _can_act(b, i):
		return false
	var u: Dictionary = b.units[i]
	var foes: Array[int] = _foes(b, int(u.side))
	var adoc: int = _leader(b, int(b.units[foes[0]].side))
	if adoc == TacticalBattle.NONE:
		return false
	var ac: Vector2i = b.units[adoc].cell
	if _edge_dist(b, ac) > int(_cfg(b, "cut_flee_edge", 1)) or b.flee_chance(adoc) <= int(_cfg(b, "cut_flee_above", 30)):
		return false
	var adjacent: Array[Dictionary] = []
	for o: Dictionary in _attack_options(b, i, [adoc]):
		if TacticalBoard.are_adjacent(o.cell, ac):
			adjacent.append(o)
	if not adjacent.is_empty():
		_take(b, i, out, _pick(b, i, adjacent, func(_o: Dictionary) -> Array: return [0]))
		return true
	if not _attack_options(b, i).is_empty():
		return false
	var edge: Vector2i = ac
	var edge_key: Array = []
	for c: Vector2i in b.board.edge_cells():
		var key: Array = [TacticalRules.distance(c, ac), c.y, c.x]
		if edge_key.is_empty() or _less(key, edge_key):
			edge_key = key
			edge = c
	var reach: Dictionary = _reach(b, i)
	var best_key: Array = []
	var best: Vector2i = u.cell
	for c: Vector2i in _sorted(reach):
		var key: Array = [TacticalRules.distance(c, edge), TacticalRules.distance(c, ac), int(reach[c])]
		if best_key.is_empty() or _less(key, best_key):
			best_key = key
			best = c
	if int(best_key[0]) > 1:
		return false
	out.move_to = best
	return true


## Se acerca y, si eso le deja al alcance de 2 o más enemigos, Espera en su sitio (P2; táctico y
## emboscadora), salvo que ya lleve wait_max turnos seguidos sin actuar.
static func _approach_or_wait(b: TacticalBattle, i: int, out: Dictionary, target: int, careful: bool) -> void:
	var u: Dictionary = b.units[i]
	_approach(b, i, out, target, careful)
	if out.move_to != u.cell and int(u.waits) < int(_cfg(b, "wait_max", 2)) \
			and _exposure(b, out.move_to, _foes(b, int(u.side)), TacticalBattle.NONE) >= 2:
		out.move_to = u.cell


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
	if _plan_escape(b, i, out):
		return
	# Retirarse atrás solo tiene sentido con compañeros delante: el último en pie pelea (si no, una
	# persecución sin fin con un enemigo más lento).
	if u.role != TacticalBattle.ROLE_DEFENDER and _ratio(b, i) < _cfg(b, "retreat_below", 0.2) \
			and _has_friend(b, i):
		_plan_retreat(b, i, out)
		return
	if _plan_finish(b, i, out):
		return
	if _plan_cheer(b, i, out):
		return
	var opts: Array[Dictionary] = _attack_options(b, i)
	if not opts.is_empty():
		var danger: Dictionary = b.danger_cells(int(u.side))
		_take(b, i, out, _best(opts, func(o: Dictionary) -> Array:
			var t: Dictionary = b.units[o.target]
			return [1 if danger.has(o.cell) else 0, int(t.hp), -int(t.atk), -float(o.expected), int(o.cost)]))
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
	var danger: Dictionary = b.danger_cells(int(u.side))
	if leader != TacticalBattle.NONE and leader != i:
		var foes: Array[int] = _foes(b, int(u.side))
		var lc: Vector2i = b.units[leader].cell
		var best_key: Array = []
		for c: Vector2i in _sorted(reach):
			var key: Array = [1 if danger.has(c) else 0, TacticalRules.distance(c, lc),
				-_min_foe_dist(b, c, foes), int(reach[c])]
			if best_key.is_empty() or _less(key, best_key):
				best_key = key
				out.move_to = c
	if _can_act(b, i):
		out.action = TacticalBattle.KIND_DEFEND
		out.target = i


## Sale de un área anunciada (T6, paso 2 de Libre): si está dentro, a una casilla alcanzable fuera
## de todas, golpeando desde ella si llega a alguien (al de menos PV); si no llega a nadie, la más
## cercana (empate, la más lejos del enemigo). Si no puede salir, se defiende. Devuelve si lo planeó.
static func _plan_escape(b: TacticalBattle, i: int, out: Dictionary) -> bool:
	var u: Dictionary = b.units[i]
	var danger: Dictionary = b.danger_cells(int(u.side))
	if danger.is_empty() or not danger.has(u.cell):
		return false
	var reach: Dictionary = _reach(b, i)
	var safe: Array[Vector2i] = []
	for c: Vector2i in _sorted(reach):
		if not danger.has(c):
			safe.append(c)
	if safe.is_empty():
		if _can_act(b, i):
			out.action = TacticalBattle.KIND_DEFEND
			out.target = i
		return true
	var opts: Array[Dictionary] = _attack_options(b, i, [], safe)
	if not opts.is_empty():
		_take(b, i, out, _best(opts, func(o: Dictionary) -> Array:
			var t: Dictionary = b.units[o.target]
			return [int(t.hp), -int(t.atk), -float(o.expected), int(o.cost)]))
		return true
	var foes: Array[int] = _foes(b, int(u.side))
	var best_key: Array = []
	for c: Vector2i in safe:
		var key: Array = [int(reach[c]), -mini(_min_foe_dist(b, c, foes), 3)]
		if best_key.is_empty() or _less(key, best_key):
			best_key = key
			out.move_to = c
	return true


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
			if not b.can_hit_from(i, c, ti):
				continue
			var rel: TacticalRules.Relation = TacticalRules.relation(tu.cell, int(tu.facing), c)
			var height: int = b.board.level_at(c) - b.board.level_at(tu.cell)
			# Con la precisión y el bono por la espalda del arma (P4: honda −10, cuchillo +2).
			var hit: int = TacticalRules.hit_chance(TacticalRules.evasion(int(tu.agi), rel, height, b.actions_cfg)
				- int(u.get("hit_mod", 0)), b.actions_cfg)
			var dmg: int = maxi(min_damage, int(u.atk) + int(u.cheer) - int(tu.def)
				+ TacticalRules.position_bonus(rel, height, b.actions_cfg) + b.weapon_back_bonus(i, rel))
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
## igual camino, la menos expuesta (táctico). Los enemigos (salvo el berserk) prefieren después la
## casilla más alta (P2).
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
			-_height_pts(b, i, c), TacticalRules.distance(c, tc), int(reach[c])]
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
	for c: Vector2i in TacticalRules.strike_cells(b.board, target_cell, int(u.jump), int(u.range_min),
			int(u.range_max), bool(u.range_line)):
		if not taken.has(c):
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


## Le queda algún compañero en el tablero.
static func _has_friend(b: TacticalBattle, i: int) -> bool:
	for k: int in b.units.size():
		if k != i and b.units[k].alive and int(b.units[k].side) == int(b.units[i].side):
			return true
	return false


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
		if f != except and TacticalRules.distance(cell, b.units[f].cell) <= b.threat_range(f):
			n += 1
	return n


## Amenazas por detrás si mira hacia `facing` desde `cell`: espalda 2, flanco 1 (solo las que le
## llegan el turno siguiente).
static func _exposure_facing(b: TacticalBattle, cell: Vector2i, facing: int, foes: Array[int]) -> int:
	var s: int = 0
	for f: int in foes:
		var fc: Vector2i = b.units[f].cell
		if TacticalRules.distance(cell, fc) > b.threat_range(f):
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


## Elige una opción de ataque de un enemigo (P2). Prioridad: las de menor `tier` (la clave del perfil;
## nunca se sale de ella). Dentro, puntuación = daño esperado + altura (_height_pts); empate, menos
## camino y luego el orden de las casillas. Azar top-2 (no para el berserk ni los aliados): la mejor
## con top2_weight y la segunda con el resto, si la segunda puntúa al menos top2_margin de la mejor.
static func _pick(b: TacticalBattle, i: int, opts: Array[Dictionary], tier: Callable) -> Dictionary:
	var cands: Array[Dictionary] = []
	var best_tier: Array = []
	for o: Dictionary in opts:
		var t: Array = tier.call(o)
		if cands.is_empty() or _less(t, best_tier):
			best_tier = t
			cands.clear()
			cands.append(o)
		elif not _less(best_tier, t):
			cands.append(o)
	var ranked: Array = []
	for k: int in cands.size():
		var o: Dictionary = cands[k]
		ranked.append([-(float(o.expected) + _height_pts(b, i, o.cell)), int(o.cost), k])
	ranked.sort_custom(func(x: Array, y: Array) -> bool: return _less(x, y))
	var first: Dictionary = cands[int(ranked[0][2])]
	if ranked.size() < 2 or not _rolls(b, i):
		return first
	var top: float = -float(ranked[0][0])
	var second_score: float = -float(ranked[1][0])
	if second_score < top * _cfg(b, "top2_margin", 0.8):
		return first
	if b.ai_rng.randf() < _cfg(b, "top2_weight", 0.75):
		return first
	return cands[int(ranked[1][2])]


## Tira el azar top-2: enemigos, salvo el berserk.
static func _rolls(b: TacticalBattle, i: int) -> bool:
	var u: Dictionary = b.units[i]
	return int(u.side) == TacticalBattle.SIDE_ENEMY and StringName(u.ai) != BattleLogic.AI_BERSERK


## Puntos por la altura de `cell` (P2): height_weight por nivel; doble para el látigo y la
## emboscadora. Solo los enemigos, salvo el berserk (0 en el tablero llano).
static func _height_pts(b: TacticalBattle, i: int, cell: Vector2i) -> float:
	if not _rolls(b, i):
		return 0.0
	var w: float = _cfg(b, "height_weight", 1.0)
	if HIGH_LOVERS.has(StringName(b.units[i].ai)):
		w *= 2.0
	return w * b.board.level_at(cell)


## Casillas hasta el borde del tablero.
static func _edge_dist(b: TacticalBattle, cell: Vector2i) -> int:
	return mini(mini(cell.x, cell.y), mini(b.board.width - 1 - cell.x, b.board.height - 1 - cell.y))


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
