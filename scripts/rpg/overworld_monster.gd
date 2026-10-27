class_name OverworldMonster
extends Node2D
## Monstruo visible en el mundo (monstruos.md) con un sprite de UnicoArt. Qué casilla pisa después
## lo decide MonsterSteering (la casilla libre se la pregunta MonsterField). Con hoja de varios
## fotogramas (PNG) cambia de fotograma al andar y mira hacia donde anda (el arte mira a la
## izquierda); con el placeholder de un fotograma, el sprite se balancea. No conoce el mapa ni
## GameState.
## Movimiento continuo (ADR 0014 §2 "Monstruos", setup_world/think_world): su propio GridMover (la
## misma colisión que el jugador) le lleva hacia el centro de la casilla que decide MonsterSteering,
## a `speed_px` (o `idle_speed_px` en reposo) de sus datos; al llegar pide la siguiente. `cell` es
## la casilla que ocupa o a la que va (la reserva) y está en `world_cell`; la de sus pies es `mover.cell`. Si persigue y ya está a su
## engage_distance en casillas, se arrima dentro de su casilla hacia el jugador para que las cajas
## lleguen a engage_px (WorldEncounters). Dormido (`asleep`), no piensa ni se ve, y conserva todo.

## Ángulo del balanceo al andar (radianes) y altura del saltito.
const SWAY: float = 0.18
const STEP_BOB: float = 1.5
## A esta distancia (px) del punto al que va, ha llegado.
const ARRIVE_PX: float = 0.01
## Avanzar menos que esto (px) en un tick con un punto por delante = atascado.
const STUCK_PX: float = 0.001

## Id de datos (balance.json, monsters.<id>): &"botarramas", &"ofomni" u &"ofomni_descarriado".
var monster_id: StringName = &""
## Id del puesto (Botarramas) o de la misión (Ofomni): clave en GameState.seen_monsters.
var key: String = ""
## Bosque al que pertenece (el que guarda un Botarramas). -1 si no guarda nada.
var bosque_id: int = -1
var cfg: Dictionary = {}
var cell: Vector2i = Vector2i.ZERO
var post: Vector2i = Vector2i.ZERO
## Chunk propio en world_cell (para max_outside).
var home_rect: Rect2i = Rect2i()
var lateral: Vector2i = Vector2i.RIGHT
var state: MonsterSteering.State = MonsterSteering.State.IDLE
## Segundos que le quedan sin ver al jugador (tras retroceder o huir, o al aparecer).
var cooldown: float = 0.0
## Segundos que le quedan antes de poder empezar el encuentro, aunque ya persiga (sigilo: acaba de
## ver al Adoc camuflado de cerca y le deja un instante para escapar).
var engage_delay: float = 0.0
## Papel en el mundo (MonsterField.ROLE_*): guardián de frontera, ronda, perseguidor...
var role: StringName = &"guardian"
## Cuántos van juntos (grupo de reparep: un solo monstruo en el mundo, el combate es contra todos).
var count: int = 1
## Encuentro con otro adoc al que pertenece este rival (MonsterField.ROLE_DUEL), o {}.
var encounter: Dictionary = {}

## Su movimiento continuo (lo crea setup_world).
var mover: GridMover = null
## Su chunk está fuera de los chunks activos (MonsterField). No piensa ni se ve.
var asleep: bool = false
## Puesto propio antes de acudir a un cruce fuera de puerta (MonsterField.summon_nearest).
var home_post: Vector2i = Vector2i.ZERO

var _idle_phase: int = 0
var _wait: float = 0.0


var _sprite: Sprite2D
## Punto (pies, px) al que va ahora: el centro de `cell` o, al arrimarse, uno dentro.
var _goal: Vector2 = Vector2.ZERO


## Prepara el monstruo con `at` (su puesto) y `rect` (su chunk) en world_cell. Aparece con los pies
## en el centro de `at`.
func setup_world(id: StringName, monster_key: String, owner_bosque: int, at: Vector2i, rect: Rect2i, axis: Vector2i,
		config: Dictionary, texture: Texture2D, frames: int = 1) -> void:
	monster_id = id
	key = monster_key
	bosque_id = owner_bosque
	cfg = config
	cell = at
	post = at
	home_rect = rect
	lateral = axis
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.hframes = maxi(1, frames)
	# Los pies en el centro de la casilla: los sprites grandes sobresalen hacia arriba.
	_sprite.offset = Vector2(0, -(texture.get_height() - WorldCoords.TILE) * 0.5)
	add_child(_sprite)
	home_post = at
	# Sin ayuda de esquina: va de centro a centro de casillas transitables.
	mover = GridMover.new(MovementConfig.hitbox(), 0.0, 0.0)
	place_at(at)


## Pone los pies en el centro de `at` (y ahí su casilla), sin andar.
func place_at(at: Vector2i) -> void:
	cell = at
	_goal = WorldCoords.world_cell_to_world_pos(at)
	mover.place(_goal)
	_sync()


## Caja de los pies (px globales).
func get_rect() -> Rect2:
	return mover.get_rect() if mover != null else Rect2(position, Vector2.ZERO)


## Posición de los pies (px).
func world_pos() -> Vector2:
	return mover.world_pos if mover != null else position


func is_moving() -> bool:
	return mover != null and not _arrived()


## Duerme (fuera de los chunks activos) o despierta. Conserva estado, puesto y posición.
func set_asleep(value: bool) -> void:
	asleep = value
	visible = not value


## Velocidad (px/s) en su estado: speed_px persiguiendo o volviendo, idle_speed_px en reposo. Si los
## datos no la tienen, la de su tiempo de paso (16 / step_time).
func speed() -> float:
	if state == MonsterSteering.State.IDLE:
		return float(cfg.get("idle_speed_px", WorldCoords.TILE / maxf(0.01, float(cfg.get("idle_step_time", 0.5)))))
	return float(cfg.get("speed_px", WorldCoords.TILE / maxf(0.01, float(cfg.get("step_time", 0.25)))))


## Un tick. Si no ha llegado a su punto, anda hacia él con su GridMover; si ha llegado,
## MonsterSteering decide la siguiente casilla (en world_cell) y empieza a ir hacia su centro.
## `player_pos`: pies del jugador (px); `walkable`: casillas libres para él; `is_blocked`: colisión
## del terreno (la del GridMover).
func think_world(delta: float, player_pos: Vector2, player: Vector2i, can_detect: bool, walkable: Callable,
		is_blocked: Callable) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	engage_delay = maxf(0.0, engage_delay - delta)
	if not _arrived():
		_glide(delta, is_blocked)
		return
	_wait -= delta
	if _wait > 0.0:
		return
	var d: Dictionary = MonsterSteering.decide(state, cell, post, player, can_detect and cooldown <= 0.0, cfg,
		home_rect, walkable, _idle_phase, lateral)
	state = d.state
	if d.next_phase:
		_idle_phase += 1
	if d.step != cell:
		if d.step.x != cell.x:
			_sprite.flip_h = d.step.x > cell.x
		cell = d.step
		_goal = WorldCoords.world_cell_to_world_pos(cell)
		_glide(delta, is_blocked)
	elif state == MonsterSteering.State.CHASE:
		# A su distancia en casillas pero quizá no en píxeles: se arrima sin salir de su casilla.
		_goal = _approach_point(player_pos)
		_glide(delta, is_blocked)
	else:
		_wait = WorldCoords.TILE / speed()
		_goal = WorldCoords.world_cell_to_world_pos(cell)
		if state == MonsterSteering.State.IDLE:
			_look_at(player)


## Punto de `cell` (pies) más cercano a `target`: los pies no salen de su casilla.
func _approach_point(target: Vector2) -> Vector2:
	var origin: Vector2 = WorldCoords.world_cell_origin(cell)
	var far: Vector2 = origin + Vector2(WorldCoords.TILE, WorldCoords.TILE) - Vector2(GridMover.SKIN, GridMover.SKIN)
	return target.clamp(origin, far)


func _arrived() -> bool:
	return mover.world_pos.is_equal_approx(_goal)


## Anda hacia `_goal` sin pasarse. Si choca y no avanza (un objeto nuevo, una esquina), se queda
## donde está y esa pasa a ser su casilla.
func _glide(delta: float, is_blocked: Callable) -> void:
	var to: Vector2 = _goal - mover.world_pos
	var dist: float = to.length()
	if dist <= ARRIVE_PX or delta <= 0.0:
		mover.place(_goal)
		_sync()
		return
	var before: Vector2 = mover.world_pos
	mover.step(to / dist, minf(speed(), dist / delta), delta, is_blocked)
	if mover.world_pos.distance_to(_goal) <= ARRIVE_PX:
		mover.place(_goal)
	elif mover.world_pos.distance_squared_to(before) < STUCK_PX * STUCK_PX:
		_goal = mover.world_pos
		cell = mover.cell
	if to.x != 0.0 and absf(to.x) >= absf(to.y) and _sprite.hframes > 1:
		_sprite.flip_h = to.x > 0.0
	_sync()


## Dibujo ajustado al píxel; el fotograma de andar cambia cada GridMover.FRAME_PX recorridos.
func _sync() -> void:
	position = mover.world_pos.round()
	if _sprite == null:
		return
	if _sprite.hframes > 1:
		_sprite.frame = mover.anim_frame() % _sprite.hframes
		return
	# Placeholder: balanceo y saltito por paso (el pixel art no se gira, style-guide).
	var t: float = sin(mover.distance / WorldCoords.TILE * PI)
	_sprite.rotation = SWAY * t
	_sprite.position.y = -STEP_BOB * absf(t)


## Quieto, mira hacia el jugador si lo tiene cerca (te mira pasar). Solo con hoja de PNG: el arte
## mira a la izquierda y se voltea.
func _look_at(player: Vector2i) -> void:
	if _sprite.hframes <= 1 or player.x == cell.x or MonsterSteering.chebyshev(cell, player) > int(cfg.get("vision_radius", 0)):
		return
	_sprite.flip_h = player.x > cell.x


## Vuelve a su puesto y olvida al jugador durante `seconds` (retroceder, huir).
func calm(seconds: float) -> void:
	cooldown = seconds
	if state == MonsterSteering.State.CHASE:
		state = MonsterSteering.State.RETURN

