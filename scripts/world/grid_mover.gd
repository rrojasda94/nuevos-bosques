class_name GridMover
extends RefCounted
## Movimiento libre en 8 direcciones con colisión contra la cuadrícula lógica (ADR 0014 §2).
## Lógica pura, sin nodos ni física de Godot: la usan el jugador (PlayerController) y, más
## adelante, los monstruos. Determinista: mismas entradas y mismo mapa dan la misma posición.
##
## - `world_pos` son los pies, en píxeles globales (float). La caja (`hitbox`, 10×6 px) está
##   centrada en x y apoyada en los pies: x en [pos.x - w/2, pos.x + w/2), y en [pos.y - h, pos.y].
## - Mueve por ejes (x y luego y): si choca, pega la caja al borde y así desliza por las paredes.
## - Ayuda de esquina: si se empuja recto contra un bloqueo que solapa la caja ≤ `corner_assist_px`,
##   empuja en perpendicular hacia el hueco a `assist_speed` (la de andar).
## - En diagonal no hay atajos: para pasar entre dos casillas en diagonal la caja tiene que
##   solapar las dos ortogonales, y si alguna está bloqueada no pasa.
## - Las reglas siguen en casillas: `cell_changed` avisa cuando cambia la casilla de los pies.

## Cambió la casilla de los pies (casilla global = floor(world_pos / TILE)).
signal cell_changed(world_cell: Vector2i)
## Se recorrieron otros STEP_PX píxeles: toca sonido de paso.
signal footstep

# ponytail: usar WorldCoords.TILE cuando entre M4
const TILE: int = 16
## Fotograma de andar cada FRAME_PX píxeles recorridos.
const FRAME_PX: float = 8.0
## Sonido de paso cada STEP_PX píxeles recorridos.
const STEP_PX: float = 16.0
## Holgura al pegar el borde inferior (pies) a una casilla bloqueada de abajo, para que la casilla
## de los pies nunca sea la bloqueada.
const SKIN: float = 1.0 / 256.0
## Entrada perpendicular por debajo de la cual se considera que se empuja recto (ayuda de esquina).
const STRAIGHT_EPS: float = 0.05

var world_pos: Vector2 = Vector2.ZERO
## Ancho y alto de la caja de los pies, en px.
var hitbox: Vector2
var corner_assist_px: float
## Velocidad del empujón de la ayuda de esquina (px/s): la de andar.
var assist_speed: float
## Orientación en 4 direcciones (eje dominante de la entrada).
var facing: Vector2i = Vector2i.DOWN
## Distancia total recorrida (px). De ella salen `anim_frame` y los pasos.
var distance: float = 0.0
## Casilla actual de los pies.
var cell: Vector2i = Vector2i.ZERO


func _init(p_hitbox: Vector2, p_corner_assist_px: float, p_assist_speed: float) -> void:
	hitbox = p_hitbox
	corner_assist_px = p_corner_assist_px
	assist_speed = p_assist_speed


## Un GridMover con los valores de data/world/movement.json.
static func from_config() -> GridMover:
	return GridMover.new(MovementConfig.hitbox(), MovementConfig.corner_assist_px(),
		MovementConfig.walk_speed())


static func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


## Centro de los pies para aparecer en una casilla (centro de la casilla).
static func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c * TILE) + Vector2(TILE, TILE) * 0.5


## Coloca los pies sin emitir `cell_changed` (aparecer, cargar partida).
func place(pos: Vector2) -> void:
	world_pos = pos
	cell = cell_of(pos)


## Fotograma de andar: sube uno cada FRAME_PX px recorridos.
func anim_frame() -> int:
	return int(distance / FRAME_PX)


## Caja de los pies en píxeles globales.
func get_rect() -> Rect2:
	return Rect2(world_pos.x - hitbox.x * 0.5, world_pos.y - hitbox.y, hitbox.x, hitbox.y)


## Avanza un tick. `input` es la dirección (de get_vector; se limita a longitud 1, así la diagonal
## no es más rápida), `speed` en px/s e `is_blocked(world_cell: Vector2i) -> bool`.
func step(input: Vector2, speed: float, delta: float, is_blocked: Callable) -> void:
	var dir: Vector2 = input.limit_length(1.0)
	_update_facing(dir)
	if dir == Vector2.ZERO:
		return
	var start: Vector2 = world_pos
	var motion: Vector2 = dir * speed * delta
	var assist: float = assist_speed * delta
	if _move_x(motion.x, is_blocked) and absf(dir.y) < STRAIGHT_EPS:
		_assist_from_x(int(signf(motion.x)), assist, is_blocked)
	if _move_y(motion.y, is_blocked) and absf(dir.x) < STRAIGHT_EPS:
		_assist_from_y(int(signf(motion.y)), assist, is_blocked)
	_advance_distance(world_pos.distance_to(start))
	var new_cell: Vector2i = cell_of(world_pos)
	if new_cell != cell:
		cell = new_cell
		cell_changed.emit(cell)


func _update_facing(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	var horizontal := Vector2i(int(signf(dir.x)), 0)
	var vertical := Vector2i(0, int(signf(dir.y)))
	var ax: float = absf(dir.x)
	var ay: float = absf(dir.y)
	if is_equal_approx(ax, ay):
		# Diagonal exacta: se conserva la orientación si es una de sus componentes.
		if facing != horizontal and facing != vertical:
			facing = vertical
	elif ax > ay:
		facing = horizontal
	else:
		facing = vertical


func _advance_distance(moved: float) -> void:
	var steps_before: int = int(distance / STEP_PX)
	distance += moved
	for _i: int in int(distance / STEP_PX) - steps_before:
		footstep.emit()


# Filas que cubre la caja: [top, bottom] cerrado abajo (los pies están dentro).
func _rows() -> Vector2i:
	return Vector2i(floori((world_pos.y - hitbox.y) / TILE), floori(world_pos.y / TILE))


# Columnas que cubre la caja: [left, right) abierto a la derecha.
func _cols() -> Vector2i:
	var half: float = hitbox.x * 0.5
	return Vector2i(floori((world_pos.x - half) / TILE), ceili((world_pos.x + half) / TILE) - 1)


func _column_blocked(c: int, rows: Vector2i, is_blocked: Callable) -> bool:
	for r: int in range(rows.x, rows.y + 1):
		if is_blocked.call(Vector2i(c, r)):
			return true
	return false


func _row_blocked(r: int, cols: Vector2i, is_blocked: Callable) -> bool:
	for c: int in range(cols.x, cols.y + 1):
		if is_blocked.call(Vector2i(c, r)):
			return true
	return false


## Mueve en x barriendo las columnas nuevas. Devuelve true si chocó (y pega la caja al borde).
func _move_x(dx: float, is_blocked: Callable) -> bool:
	if dx == 0.0:
		return false
	var half: float = hitbox.x * 0.5
	var rows: Vector2i = _rows()
	if dx > 0.0:
		var edge: float = world_pos.x + half
		for c: int in range(ceili(edge / TILE), ceili((edge + dx) / TILE)):
			if _column_blocked(c, rows, is_blocked):
				world_pos.x = float(c * TILE) - half
				return true
	else:
		var edge: float = world_pos.x - half
		for c: int in range(floori(edge / TILE) - 1, floori((edge + dx) / TILE) - 1, -1):
			if _column_blocked(c, rows, is_blocked):
				world_pos.x = float((c + 1) * TILE) + half
				return true
	world_pos.x += dx
	return false


## Mueve en y barriendo las filas nuevas. Devuelve true si chocó (y pega la caja al borde).
func _move_y(dy: float, is_blocked: Callable) -> bool:
	if dy == 0.0:
		return false
	var cols: Vector2i = _cols()
	if dy > 0.0:
		for r: int in range(floori(world_pos.y / TILE) + 1, floori((world_pos.y + dy) / TILE) + 1):
			if _row_blocked(r, cols, is_blocked):
				world_pos.y = float(r * TILE) - SKIN
				return true
	else:
		var top: float = world_pos.y - hitbox.y
		for r: int in range(floori(top / TILE) - 1, floori((top + dy) / TILE) - 1, -1):
			if _row_blocked(r, cols, is_blocked):
				world_pos.y = float((r + 1) * TILE) + hitbox.y
				return true
	world_pos.y += dy
	return false


## Chocó en x (sentido `sx`): si solo una de las dos filas del frente está bloqueada y la caja la
## solapa ≤ corner_assist_px, empuja en y hacia la fila libre (sin pasarse del hueco).
func _assist_from_x(sx: int, amount: float, is_blocked: Callable) -> void:
	var rows: Vector2i = _rows()
	if rows.x == rows.y:
		return
	var half: float = hitbox.x * 0.5
	var front: int = (ceili((world_pos.x + half) / TILE) if sx > 0
		else floori((world_pos.x - half) / TILE) - 1)
	var top_blocked: bool = is_blocked.call(Vector2i(front, rows.x))
	var bottom_blocked: bool = is_blocked.call(Vector2i(front, rows.y))
	if top_blocked == bottom_blocked:
		return
	if top_blocked:
		var overlap: float = float((rows.x + 1) * TILE) - (world_pos.y - hitbox.y)
		if overlap <= corner_assist_px:
			_move_y(minf(amount, overlap), is_blocked)
	else:
		var overlap: float = world_pos.y - float(rows.y * TILE) + SKIN
		if overlap <= corner_assist_px:
			_move_y(-minf(amount, overlap), is_blocked)


## Chocó en y (sentido `sy`): igual que _assist_from_x, empujando en x hacia la columna libre.
func _assist_from_y(sy: int, amount: float, is_blocked: Callable) -> void:
	var cols: Vector2i = _cols()
	if cols.x == cols.y:
		return
	var front: int = (floori(world_pos.y / TILE) + 1 if sy > 0
		else floori((world_pos.y - hitbox.y) / TILE) - 1)
	var left_blocked: bool = is_blocked.call(Vector2i(cols.x, front))
	var right_blocked: bool = is_blocked.call(Vector2i(cols.y, front))
	if left_blocked == right_blocked:
		return
	var half: float = hitbox.x * 0.5
	if left_blocked:
		var overlap: float = float((cols.x + 1) * TILE) - (world_pos.x - half)
		if overlap <= corner_assist_px:
			_move_x(minf(amount, overlap), is_blocked)
	else:
		var overlap: float = world_pos.x + half - float(cols.y * TILE)
		if overlap <= corner_assist_px:
			_move_x(-minf(amount, overlap), is_blocked)
