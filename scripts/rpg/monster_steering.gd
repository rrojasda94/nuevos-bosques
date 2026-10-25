class_name MonsterSteering
extends RefCounted
## Decisiones de los monstruos del mundo (monstruos.md), en lógica pura: si ven al jugador, si
## empieza el encuentro y cuál es su siguiente casilla (hacia el jugador, de vuelta al puesto o el
## renqueo de reposo). Lee los parámetros genéricos de cada monstruo (balance.json, monsters.<id>):
## vision_radius, engage_distance, leash, max_outside e idle_wander. Sin constantes por tipo.
## Distancias en casillas de Chebyshev. Las casillas son de "área": relativas al chunk actual, así
## que un monstruo puede estar en el chunk vecino (coordenadas negativas o >= 64).

enum State { IDLE, CHASE, RETURN }

## Paso imposible: no hay camino.
const NO_PATH := Vector2i(-99999, -99999)
## Tope de casillas que explora la búsqueda de camino.
const MAX_NODES: int = 6000
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## El monstruo ve al jugador: puede detectar (Bosque cerrado, sin enfriamiento...) y está dentro de
## su vision_radius. El sigilo (Stealth) ya viene restado en cfg.vision_radius (MonsterField): con
## visión 0 solo te encuentra si se te echa encima (engages).
static func sees(cell: Vector2i, player: Vector2i, can_detect: bool, cfg: Dictionary) -> bool:
	return can_detect and chebyshev(cell, player) <= int(cfg.vision_radius)


## Empieza el encuentro (menú del borde o combate): a engage_distance o menos (1 = adyacente,
## también en diagonal). El camuflaje no lo evita: de tan cerca, te ve igualmente.
static func engages(cell: Vector2i, player: Vector2i, can_detect: bool, cfg: Dictionary) -> bool:
	return can_detect and cell != player and chebyshev(cell, player) <= int(cfg.engage_distance)


## Casillas que la casilla queda fuera de `home_rect` (0 si está dentro).
static func outside_depth(cell: Vector2i, home_rect: Rect2i) -> int:
	var dx: int = maxi(home_rect.position.x - cell.x, cell.x - (home_rect.end.x - 1))
	var dy: int = maxi(home_rect.position.y - cell.y, cell.y - (home_rect.end.y - 1))
	return maxi(0, maxi(dx, dy))


## El monstruo puede pisar la casilla: transitable, a `leash` o menos de su puesto y sin salir de
## `home_rect` más de `max_outside` casillas.
static func can_stand(cell: Vector2i, post: Vector2i, home_rect: Rect2i, cfg: Dictionary, walkable: Callable) -> bool:
	return chebyshev(cell, post) <= int(cfg.leash) and outside_depth(cell, home_rect) <= int(cfg.max_outside) \
		and bool(walkable.call(cell))


## Desplazamiento del renqueo de reposo en la fase `phase`: 0, 1 .. w, w-1 .. -w .. -1 (ida y vuelta).
static func idle_offset(phase: int, wander: int) -> int:
	if wander <= 0:
		return 0
	var t: int = posmod(phase, 4 * wander)
	if t <= wander:
		return t
	if t <= 3 * wander:
		return 2 * wander - t
	return t - 4 * wander


## Primer paso del camino más corto (4 direcciones) desde `from` hasta una casilla que cumpla
## `is_goal`, pisando solo casillas `allowed`. `from` si ya está en la meta; NO_PATH si no hay camino.
static func path_step(from: Vector2i, is_goal: Callable, allowed: Callable) -> Vector2i:
	if is_goal.call(from):
		return from
	var first: Dictionary = { from: from }
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size() and queue.size() < MAX_NODES:
		var c: Vector2i = queue[head]
		head += 1
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if first.has(n) or not allowed.call(n):
				continue
			first[n] = n if c == from else first[c]
			if is_goal.call(n):
				return first[n]
			queue.append(n)
	return NO_PATH


## Siguiente decisión: { "state": State, "step": casilla a la que moverse (la actual = quieto),
## "next_phase": true si el renqueo de reposo llegó a su punto y pasa a la fase siguiente }.
## `walkable`: casillas libres (terreno, sin el jugador ni otros monstruos). `lateral`: eje del
## renqueo de reposo.
static func decide(state: State, cell: Vector2i, post: Vector2i, player: Vector2i, can_detect: bool,
		cfg: Dictionary, home_rect: Rect2i, walkable: Callable, idle_phase: int, lateral: Vector2i) -> Dictionary:
	var allowed: Callable = func(c: Vector2i) -> bool: return can_stand(c, post, home_rect, cfg, walkable)
	var visible: bool = sees(cell, player, can_detect, cfg)
	if state == State.CHASE and (not can_detect or chebyshev(cell, player) > int(cfg.leash)):
		state = State.RETURN
	elif state != State.CHASE and visible:
		state = State.CHASE
	if state == State.CHASE:
		if engages(cell, player, can_detect, cfg) or chebyshev(cell, player) <= 1:
			return { "state": state, "step": cell, "next_phase": false }
		var engage: int = int(cfg.engage_distance)
		var step: Vector2i = path_step(cell, func(c: Vector2i) -> bool: return chebyshev(c, player) <= maxi(1, engage), allowed)
		if step != NO_PATH:
			return { "state": state, "step": step, "next_phase": false }
		state = State.RETURN
	if state == State.RETURN:
		if cell != post:
			var back: Vector2i = path_step(cell, func(c: Vector2i) -> bool: return c == post, allowed)
			return { "state": state if back != NO_PATH else State.IDLE, "step": back if back != NO_PATH else cell, "next_phase": false }
		state = State.IDLE
	var target: Vector2i = post + lateral * idle_offset(idle_phase, int(cfg.get("idle_wander", 0)))
	if cell == target or not allowed.call(target):
		return { "state": state, "step": cell, "next_phase": true }
	var s: Vector2i = path_step(cell, func(c: Vector2i) -> bool: return c == target, allowed)
	return { "state": state, "step": s if s != NO_PATH else cell, "next_phase": s == NO_PATH }
