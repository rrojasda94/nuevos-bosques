class_name OverworldMonster
extends Node2D
## Monstruo visible en el mundo (monstruos.md): se mueve por casillas con su propio step_time, con la
## misma colisión que el jugador (la casilla libre se la pregunta MonsterField) y un sprite de
## UnicoArt. Qué hace en cada paso lo decide MonsterSteering. Con hoja de varios fotogramas (PNG)
## cambia de fotograma en cada paso y mira hacia donde anda (el arte mira a la izquierda); con el
## placeholder de un fotograma, el sprite se balancea. No conoce el mapa ni GameState.

## Ángulo del balanceo al andar (radianes) y altura del saltito.
const SWAY: float = 0.18
const STEP_BOB: float = 1.5

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
## Papel en el mundo (MonsterField.ROLE_*): guardián de frontera, ronda, perseguidor...
var role: StringName = &"guardian"

var _idle_phase: int = 0
var _wait: float = 0.0
var _sway_side: float = 1.0
var _tween: Tween
var _sprite: Sprite2D


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


func is_moving() -> bool:
	return _tween != null and _tween.is_running()


## Un fotograma: enfriamiento, decisión y, si toca, un paso. `can_detect`: puede ver al jugador
## (p. ej. su Bosque está cerrado). `walkable`: casillas libres para él.
func think(delta: float, player: Vector2i, can_detect: bool, walkable: Callable) -> void:
	cooldown = maxf(0.0, cooldown - delta)
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


## Vuelve a su puesto y olvida al jugador durante `seconds` (retroceder, huir).
func calm(seconds: float) -> void:
	cooldown = seconds
	if state == MonsterSteering.State.CHASE:
		state = MonsterSteering.State.RETURN


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
