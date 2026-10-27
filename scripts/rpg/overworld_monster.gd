class_name OverworldMonster
extends Node2D
## Monstruo visible en el mundo (monstruos.md): se mueve por casillas con su propio step_time, con la
## misma colisión que el jugador (la casilla libre se la pregunta MonsterField) y un sprite de
## UnicoArt. Qué hace en cada paso lo decide MonsterSteering. Con hoja de varios fotogramas (PNG)
## cambia de fotograma en cada paso y mira hacia donde anda (el arte mira a la izquierda); con el
## placeholder de un fotograma, el sprite se balancea. No conoce el mapa ni GameState.
## Mundo 2.0 (ADR 0014 §2 "Monstruos", setup_world/think_world): deja los tweens y se mueve en
## continuo con su propio GridMover (la misma colisión que el jugador) hacia el centro de la casilla
## que decide MonsterSteering, a `speed_px` (o `idle_speed_px` en reposo) de sus datos; al llegar
## pide la siguiente. `cell` es la casilla que ocupa o a la que va (la reserva, como con el tween)
## y está en `world_cell`; la de sus pies es `mover.cell`. Si persigue y ya está a su
## engage_distance en casillas, se arrima dentro de su casilla hacia el jugador para que las cajas
## lleguen a engage_px (WorldEncounters). Dormido (`asleep`), no piensa ni se ve, y conserva todo.

## Ángulo del balanceo al andar (radianes) y altura del saltito.
const SWAY: float = 0.18
const STEP_BOB: float = 1.5
## Mundo 2.0: a esta distancia (px) del punto al que va, ha llegado.
const ARRIVE_PX: float = 0.01
## Mundo 2.0: avanzar menos que esto (px) en un tick con un punto por delante = atascado.
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
## Chunk propio en casillas de área (para max_outside).
var home_rect: Rect2i = Rect2i()
var lateral: Vector2i = Vector2i.RIGHT
var state: MonsterSteering.State = MonsterSteering.State.IDLE
## Segundos que le quedan sin ver al jugador (tras retroceder o huir, o al aparecer).
var cooldown: float = 0.0
## Segundos que le quedan antes de poder empezar el encuentro, aunque ya persiga (sigilo: acaba de
## ver al Adoc camuflado de cerca y le deja un instante para escapar).
var engage_delay: float = 0.0
## Mundo 2.0: sprint (P6): x = segundos de sprint que quedan, y = descanso antes del siguiente.
var sprint: Vector2 = Vector2.ZERO
## Papel en el mundo (MonsterField.ROLE_*): guardián de frontera, ronda, perseguidor...
var role: StringName = &"guardian"
## Cuántos van juntos (grupo de reparep: un solo monstruo en el mundo, el combate es contra todos).
var count: int = 1
## Encuentro con otro adoc al que pertenece este rival (MonsterField.ROLE_DUEL), o {}.
var encounter: Dictionary = {}

## Mundo 2.0: su movimiento continuo (null en la exploración vieja, que usa tweens).
var mover: GridMover = null
## Mundo 2.0: su chunk está fuera de los chunks activos (MonsterField). No piensa ni se ve.
var asleep: bool = false
## Mundo 2.0: puesto propio antes de acudir a un cruce fuera de puerta (MonsterField.summon_nearest).
var home_post: Vector2i = Vector2i.ZERO

var _idle_phase: int = 0
var _wait: float = 0.0
var _sway_side: float = 1.0
var _tween: Tween
var _sprite: Sprite2D
## Mundo 2.0: punto (pies, px) al que va ahora: el centro de `cell` o, al arrimarse, uno dentro.
var _goal: Vector2 = Vector2.ZERO


func setup(id: StringName, monster_key: String, owner_bosque: int, at: Vector2i, rect: Rect2i, axis: Vector2i,
		config: Dictionary, texture: Texture2D, frames: int = 1) -> void:
	monster_id = id
	key = monster_key
	bosque_id = owner_bosque
	cfg = config
	cell = at
	post = at
	home_rect = rect
	lateral = axis
	position = PlayerWalker.cell_to_position(at)
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.hframes = maxi(1, frames)
	# Los pies en el centro de la casilla: los sprites grandes sobresalen hacia arriba.
	_sprite.offset = Vector2(0, -(texture.get_height() - PlayerWalker.TILE_SIZE) * 0.5)
	add_child(_sprite)


## Mundo 2.0: como setup, con `at` y `rect` en world_cell. Aparece con los pies en el centro de `at`.
func setup_world(id: StringName, monster_key: String, owner_bosque: int, at: Vector2i, rect: Rect2i, axis: Vector2i,
		config: Dictionary, texture: Texture2D, frames: int = 1) -> void:
	setup(id, monster_key, owner_bosque, at, rect, axis, config, texture, frames)
	home_post = at
	# Sin ayuda de esquina: va de centro a centro de casillas transitables.
	mover = GridMover.new(MovementConfig.hitbox(), 0.0, 0.0)
	place_at(at)


## Mundo 2.0: pone los pies en el centro de `at` (y ahí su casilla), sin andar.
func place_at(at: Vector2i) -> void:
	cell = at
	_goal = WorldCoords.world_cell_to_world_pos(at)
	mover.place(_goal)
	_sync()


## Mundo 2.0: caja de los pies (px globales).
func get_rect() -> Rect2:
	return mover.get_rect() if mover != null else Rect2(position, Vector2.ZERO)


## Mundo 2.0: posición de los pies (px).
func world_pos() -> Vector2:
	return mover.world_pos if mover != null else position


func is_moving() -> bool:
	if mover != null:
		return not _arrived()
	return _tween != null and _tween.is_running()


## Mundo 2.0: duerme (fuera de los chunks activos) o despierta. Conserva estado, puesto y posición.
func set_asleep(value: bool) -> void:
	asleep = value
	visible = not value


## Velocidad (px/s) en su estado: speed_px persiguiendo o volviendo, idle_speed_px en reposo. Si los
## datos no la tienen, la de su tiempo de paso (16 / step_time).
## Esprintando, sprint_px (MonsterSteering.speed_px).
func speed() -> float:
	return MonsterSteering.speed_px(cfg, state, is_sprinting())


## Mundo 2.0: está esprintando (P6, MonsterSteering.sprint_tick).
func is_sprinting() -> bool:
	return sprint.x > 0.0


## Mundo 2.0: un tick. Si no ha llegado a su punto, anda hacia él con su GridMover; si ha llegado,
## MonsterSteering decide la siguiente casilla (en world_cell) y empieza a ir hacia su centro.
## `player_pos`: pies del jugador (px); `walkable`: casillas libres para él; `is_blocked`: colisión
## del terreno (la del GridMover).
func think_world(delta: float, player_pos: Vector2, player: Vector2i, can_detect: bool, walkable: Callable,
		is_blocked: Callable) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	engage_delay = maxf(0.0, engage_delay - delta)
	var chasing: bool = state == MonsterSteering.State.CHASE and can_detect and cooldown <= 0.0
	sprint = MonsterSteering.sprint_tick(sprint, delta, chasing, MonsterSteering.chebyshev(mover.cell, player), cfg)
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


# ponytail: borrar en M17 (exploración vieja, por casillas con tween); el Mundo 2.0 usa think_world.
## Un fotograma: enfriamiento, decisión y, si toca, un paso. `can_detect`: puede ver al jugador
## (p. ej. su Bosque está cerrado). `walkable`: casillas libres para él.
func think(delta: float, player: Vector2i, can_detect: bool, walkable: Callable) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	engage_delay = maxf(0.0, engage_delay - delta)
	_wait -= delta
	if is_moving() or _wait > 0.0:
		return
	var d: Dictionary = MonsterSteering.decide(state, cell, post, player, can_detect and cooldown <= 0.0, cfg,
		home_rect, walkable, _idle_phase, lateral)
	state = d.state
	if d.next_phase:
		_idle_phase += 1
	var time: float = float(cfg.step_time) if state != MonsterSteering.State.IDLE else float(cfg.idle_step_time)
	_wait = time
	if d.step != cell:
		_step_to(d.step, time)
	elif state == MonsterSteering.State.IDLE:
		_look_at(player)


## Quieto, mira hacia el jugador si lo tiene cerca (te mira pasar). Solo con hoja de PNG: el arte
## mira a la izquierda y se voltea.
func _look_at(player: Vector2i) -> void:
	if _sprite.hframes <= 1 or player.x == cell.x or MonsterSteering.chebyshev(cell, player) > int(cfg.get("vision_radius", 0)):
		return
	_sprite.flip_h = player.x > cell.x


## Vuelve a su puesto y olvida al jugador durante `seconds` (retroceder, huir: MonsterSteering.
## calm_seconds). Corta el sprint en curso sin descanso: al acabar la calma puede volver a esprintar.
func calm(seconds: float) -> void:
	cooldown = seconds
	sprint.x = 0.0
	if state == MonsterSteering.State.CHASE:
		state = MonsterSteering.State.RETURN


# ponytail: borrar en M17 (tween por casillas).
func _step_to(target: Vector2i, time: float) -> void:
	var animated: bool = _sprite.hframes > 1
	if animated:
		_sprite.frame = (_sprite.frame + 1) % _sprite.hframes
		if target.x != cell.x:
			_sprite.flip_h = target.x > cell.x
	cell = target
	_sway_side = -_sway_side
	_tween = create_tween()
	_tween.tween_property(self, "position", PlayerWalker.cell_to_position(target), time)
	_tween.parallel().tween_property(_sprite, "position:y", -STEP_BOB, time * 0.5)
	_tween.parallel().tween_property(_sprite, "position:y", 0.0, time * 0.5).set_delay(time * 0.5)
	# El pixel art no se gira (style-guide): el balanceo es solo del placeholder.
	if not animated:
		_tween.parallel().tween_property(_sprite, "rotation", SWAY * _sway_side, time * 0.5)
		_tween.parallel().tween_property(_sprite, "rotation", 0.0, time * 0.5).set_delay(time * 0.5)
