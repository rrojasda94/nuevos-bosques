class_name BosqueBorder
extends RefCounted
## Límite de Bosque del Mundo 2.0 (ADR 0014 §2 "Borde de Bosque", §7 Botarramas): una casilla de
## otro Bosque cerrado bloquea al jugador y, al chocar con ella, se emite
## `EventBus.bosque_border_reached(bosque_id)` una sola vez por contacto. Vale igual en una puerta
## (donde espera su Botarramas) que fuera de ella, entre árboles: el flujo del cruce es el mismo y
## `contacted` avisa a quien tiene que hacer acudir al Botarramas más cercano (MonsterField).
## Lógica pura: no conoce la escena. La exploración compone el `is_blocked` del jugador con
## `blocks(terrain)` y llama a `tick(had_input)` una vez por tick de física.
##
## Un contacto empieza en el primer tick en que el GridMover pregunta por una casilla de Bosque
## cerrado y dura mientras siga empujando contra ella. Acaba cuando hay entrada de movimiento sin
## choque con el límite (se aparta o se desliza a otra parte) o al cambiar de Bosque (cruzar tras
## pagar). Los ticks sin entrada (quieto, menú abierto) no lo acaban: soltar la tecla y volver a
## empujar el mismo borde no reabre el menú.

## Empezó un contacto con el límite del Bosque `bosque_id` en la casilla `world_cell`.
signal contacted(bosque_id: int, world_cell: Vector2i)

## (Vector2i world_cell) -> int: id del Bosque de la casilla (-1 fuera de la región).
var bosque_at: Callable
## (int bosque_id) -> bool: su frontera está cerrada para el jugador (sin pagar, sin forzar, sin
## colarse). Ver AdventureRules.is_passable.
var is_closed: Callable
## Bosque en el que está el jugador (el de la casilla de sus pies). Sus casillas nunca bloquean.
var current_bosque: int = -1

var _hit_bosque: int = -1
var _hit_cell: Vector2i = Vector2i.ZERO
var _contact_bosque: int = -1


func _init(p_bosque_at: Callable, p_is_closed: Callable) -> void:
	bosque_at = p_bosque_at
	is_closed = p_is_closed


## Bosque de una casilla de la región según el RegionPlan (los Bosques van por chunks).
static func plan_bosque_at(plan: RegionPlan) -> Callable:
	return func(c: Vector2i) -> int: return plan.bosque_at(WorldCoords.world_cell_to_chunk(c))


## La casilla es de otro Bosque y está cerrado.
func is_border(world_cell: Vector2i) -> bool:
	var b: int = bosque_at.call(world_cell)
	return b >= 0 and b != current_bosque and bool(is_closed.call(b))


## `is_blocked` del jugador: el del terreno más el límite. Apunta el choque con el límite.
func blocks(terrain: Callable) -> Callable:
	return func(c: Vector2i) -> bool:
		if is_border(c):
			if _hit_bosque < 0:
				_hit_bosque = bosque_at.call(c)
				_hit_cell = c
			return true
		return bool(terrain.call(c))


## Un tick de física (después de mover al jugador). `player_cell`: casilla de sus pies;
## `had_input`: hubo entrada de movimiento. Emite como mucho una vez por contacto.
func tick(player_cell: Vector2i, had_input: bool) -> void:
	var here: int = bosque_at.call(player_cell)
	if here != current_bosque:
		current_bosque = here
		_contact_bosque = -1
	var hit: int = _hit_bosque
	_hit_bosque = -1
	if hit < 0:
		if had_input:
			_contact_bosque = -1
		return
	if hit == _contact_bosque:
		return
	_contact_bosque = hit
	contacted.emit(hit, _hit_cell)
	EventBus.bosque_border_reached.emit(hit)


## Hay un contacto en curso con el límite de ese Bosque.
func in_contact(bosque_id: int) -> bool:
	return _contact_bosque >= 0 and _contact_bosque == bosque_id
