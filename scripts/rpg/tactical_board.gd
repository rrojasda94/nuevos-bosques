class_name TacticalBoard
extends RefCounted
## Tablero lógico del combate táctico (combate-tactico.md, ADR 0016; PR T1). Lógica pura: no toca
## GameState, la escena ni scripts/world. Tamaño de balance.json (tactical.board: 8 x 6).
## - Casillas con nivel 0–3 (las caras de risco ya comprimidas: un risco es un salto de nivel entre
##   casillas vecinas), bloqueada, escalera o rampa, agua o vado y objeto (árbol, roca: obstáculo).
## - Constructores: TacticalBoard.new(width, height) da un tablero llano (antes del Mundo 2.0);
##   from_cells(width, height, cells, origin) lo crea desde un diccionario por casilla con el formato
##   previsto de WorldQuery.rect: { Vector2i: { level, blocked, stair, ramp, water, ford,
##   object_kind } } (las claves que falten valen 0, false o &""). Las celdas se pasan a locales
##   restando `origin`.
## - Transitable: dentro, no bloqueada, sin objeto (salvo los de `walkable_objects`) y sin agua
##   salvo en un vado.
## - Pasos entre vecinas ortogonales: subir como mucho `jump` niveles y bajar como mucho `drop`; si
##   alguna de las dos es escalera o rampa, se pasa sin mirar el desnivel.
## - reachable/path_to: Dijkstra con coste por casilla (1, o ford_cost en un vado), con casillas que
##   no se pueden cruzar (enemigos) y casillas en las que no se puede acabar (cualquier ocupada).
## - Colocación: deploy_cells da las casillas de las `deploy_columns` columnas de un lado, primero
##   la columna interior y las filas del centro.
## - Bordes (huida desde cualquier borde, #184) y adyacencia ortogonal.
## No decide turnos ni acciones (TacticalBattle) ni elige el recorte del mundo (sesión del Mundo 2.0).

enum Side { LEFT, RIGHT }
## Orientación (4 direcciones), en el orden de NEIGHBOR_DIRS.
enum Facing { NORTH, EAST, SOUTH, WEST }

## Niveles del mundo (ADR 0014 §3). Estructura del mundo, no balance.
const MAX_LEVEL: int = 3
## Orden fijo de vecinas (N, E, S, O): el resultado no depende del orden de un diccionario.
const NEIGHBOR_DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var width: int
var height: int
## Coste de Mov de un vado (balance.json, tactical.board.ford_cost).
var ford_cost: int = 1
var _level: PackedInt32Array
var _blocked: PackedByteArray
var _stair: PackedByteArray
var _water: PackedByteArray
var _ford: PackedByteArray
var _object: Array[StringName] = []
var _walkable_objects: Array[StringName] = []


func _init(board_width: int, board_height: int) -> void:
	width = maxi(board_width, 1)
	height = maxi(board_height, 1)
	var n: int = width * height
	_level.resize(n)
	_blocked.resize(n)
	_stair.resize(n)
	_water.resize(n)
	_ford.resize(n)
	_object.resize(n)
	_level.fill(0)
	_blocked.fill(0)
	_stair.fill(0)
	_water.fill(0)
	_ford.fill(0)
	_object.fill(&"")


## Tablero desde un diccionario por casilla (formato de WorldQuery.rect). `walkable_objects`: kinds de
## objeto que no estorban (por defecto, todo objeto es obstáculo).
static func from_cells(board_width: int, board_height: int, cells: Dictionary,
		origin: Vector2i = Vector2i.ZERO, walkable_objects: Array = []) -> TacticalBoard:
	var board := TacticalBoard.new(board_width, board_height)
	for kind: Variant in walkable_objects:
		board._walkable_objects.append(StringName(kind))
	for key: Variant in cells:
		if not key is Vector2i:
			continue
		var local: Vector2i = (key as Vector2i) - origin
		if not board.in_bounds(local):
			continue
		var data: Dictionary = cells[key]
		var kind: Variant = data.get("object_kind", "")
		board.set_cell(local, int(data.get("level", 0)), bool(data.get("blocked", false)),
			bool(data.get("stair", false)) or bool(data.get("ramp", false)),
			bool(data.get("water", false)), bool(data.get("ford", false)),
			StringName(str(kind)) if kind != null else &"")
	return board


## Tablero llano con el tamaño y el coste de vado de balance.json (bloque tactical.board).
static func from_config(board_cfg: Dictionary, cells: Dictionary = {},
		origin: Vector2i = Vector2i.ZERO) -> TacticalBoard:
	var board := from_cells(int(board_cfg.get("width", 8)), int(board_cfg.get("height", 6)), cells, origin)
	board.ford_cost = maxi(int(board_cfg.get("ford_cost", 1)), 1)
	return board


func set_cell(cell: Vector2i, level: int = 0, blocked: bool = false, stair: bool = false,
		water: bool = false, ford: bool = false, object_kind: StringName = &"") -> void:
	if not in_bounds(cell):
		return
	var i: int = _index(cell)
	_level[i] = clampi(level, 0, MAX_LEVEL)
	_blocked[i] = 1 if blocked else 0
	_stair[i] = 1 if stair else 0
	_water[i] = 1 if (water or ford) else 0
	_ford[i] = 1 if ford else 0
	_object[i] = object_kind


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func level_at(cell: Vector2i) -> int:
	return _level[_index(cell)] if in_bounds(cell) else 0


func is_stair(cell: Vector2i) -> bool:
	return in_bounds(cell) and _stair[_index(cell)] == 1


func is_water(cell: Vector2i) -> bool:
	return in_bounds(cell) and _water[_index(cell)] == 1


func is_ford(cell: Vector2i) -> bool:
	return in_bounds(cell) and _ford[_index(cell)] == 1


func object_at(cell: Vector2i) -> StringName:
	return _object[_index(cell)] if in_bounds(cell) else &""


func is_obstacle(cell: Vector2i) -> bool:
	var kind: StringName = object_at(cell)
	return kind != &"" and not _walkable_objects.has(kind)


func is_walkable(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	var i: int = _index(cell)
	if _blocked[i] == 1 or is_obstacle(cell):
		return false
	return _water[i] == 0 or _ford[i] == 1


## Coste de Mov de entrar en la casilla.
func step_cost(cell: Vector2i) -> int:
	return ford_cost if is_ford(cell) else 1


## Se puede pasar de `from` a su vecina `to` subiendo como mucho `jump` niveles y bajando como mucho
## `drop`. Escaleras y rampas no miran el desnivel.
func can_step(from: Vector2i, to: Vector2i, jump: int, drop: int) -> bool:
	if not is_walkable(to) or not are_adjacent(from, to):
		return false
	if is_stair(from) or is_stair(to):
		return true
	var rise: int = level_at(to) - level_at(from)
	return rise <= jump if rise >= 0 else -rise <= drop


func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir: Vector2i in NEIGHBOR_DIRS:
		if in_bounds(cell + dir):
			out.append(cell + dir)
	return out


static func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func is_edge(cell: Vector2i) -> bool:
	return in_bounds(cell) and (cell.x == 0 or cell.y == 0 or cell.x == width - 1 or cell.y == height - 1)


## Casillas del borde transitables (desde ellas se huye, #184).
func edge_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if is_edge(c) and is_walkable(c):
				out.append(c)
	return out


## Casillas alcanzables desde `from` con `mov` de coste: { Vector2i: coste } (incluye `from` con 0).
## `impassable`: casillas que no se pueden cruzar ni pisar (enemigos); `no_stop`: casillas por las
## que se pasa pero donde no se puede acabar (aliados). Se ignoran como claves de diccionario.
func reachable(from: Vector2i, mov: int, jump: int, drop: int, impassable: Dictionary = {},
		no_stop: Dictionary = {}) -> Dictionary:
	var search: Dictionary = _search(from, mov, jump, drop, impassable)
	var out: Dictionary = {}
	for cell: Vector2i in search.cost:
		if cell == from or not no_stop.has(cell):
			out[cell] = search.cost[cell]
	return out


## Camino más barato de `from` a `to` (ambas incluidas), o [] si no se llega con `mov`. Entre caminos
## de igual coste, el del orden fijo de vecinas (N, E, S, O).
func path_to(from: Vector2i, to: Vector2i, mov: int, jump: int, drop: int,
		impassable: Dictionary = {}, no_stop: Dictionary = {}) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if to != from and no_stop.has(to):
		return out
	var search: Dictionary = _search(from, mov, jump, drop, impassable)
	if not search.cost.has(to):
		return out
	var cell: Vector2i = to
	while cell != from:
		out.push_front(cell)
		cell = search.came[cell]
	out.push_front(from)
	return out


## Hay camino a pie (sin límite de Mov) entre alguna casilla de `a` y alguna de `b`. Para validar que
## el tablero es conexo entre los bandos.
func has_walk_path(a: Array[Vector2i], b: Array[Vector2i], jump: int, drop: int) -> bool:
	for start: Vector2i in a:
		if not is_walkable(start):
			continue
		var search: Dictionary = _search(start, width * height * maxi(ford_cost, 1), jump, drop, {})
		for target: Vector2i in b:
			if search.cost.has(target):
				return true
	return false


## Fracción de casillas transitables (0..1).
func walkable_ratio() -> float:
	var count: int = 0
	for y in height:
		for x in width:
			if is_walkable(Vector2i(x, y)):
				count += 1
	return float(count) / float(width * height)


## Diferencia entre el nivel más alto y el más bajo de las casillas transitables.
func level_span() -> int:
	var lo: int = MAX_LEVEL
	var hi: int = 0
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if is_walkable(c):
				lo = mini(lo, level_at(c))
				hi = maxi(hi, level_at(c))
	return maxi(hi - lo, 0)


## Casillas de colocación de un bando: las `columns` columnas de su lado, transitables, primero la
## columna interior (la más cercana al centro) y, en cada columna, las filas del centro hacia fuera
## (empate: la de arriba). Si no hay bastantes, se sigue con la columna siguiente hacia el centro.
func deploy_cells(side: int, columns: int, needed: int = 0) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var cols: Array[int] = []
	for k in width:
		cols.append(k if side == Side.LEFT else width - 1 - k)
	var take: int = clampi(columns, 1, width)
	var ordered_cols: Array[int] = cols.slice(0, take)
	ordered_cols.reverse()
	var rows: Array[int] = _center_rows()
	for col: int in ordered_cols:
		for row: int in rows:
			var c := Vector2i(col, row)
			if is_walkable(c):
				out.append(c)
	var extra: int = take
	while out.size() < needed and extra < width:
		for row: int in rows:
			var c := Vector2i(cols[extra], row)
			if is_walkable(c):
				out.append(c)
		extra += 1
	return out


## Vector de una orientación.
static func facing_vector(facing: Facing) -> Vector2i:
	return NEIGHBOR_DIRS[int(facing)]


## Orientación de `from` hacia `to`: el eje con más distancia (empate: el horizontal).
static func facing_toward(from: Vector2i, to: Vector2i, fallback: Facing = Facing.EAST) -> Facing:
	var d: Vector2i = to - from
	if d == Vector2i.ZERO:
		return fallback
	if absi(d.x) >= absi(d.y):
		return Facing.EAST if d.x > 0 else Facing.WEST
	return Facing.SOUTH if d.y > 0 else Facing.NORTH


func _center_rows() -> Array[int]:
	var rows: Array[int] = []
	for y in height:
		rows.append(y)
	var center: float = (height - 1) / 2.0
	rows.sort_custom(func(a: int, b: int) -> bool:
		var da: float = absf(a - center)
		var db: float = absf(b - center)
		return da < db if da != db else a < b)
	return rows


## Dijkstra sobre el tablero (pocas casillas: frontera ordenada a mano). { cost, came }.
func _search(from: Vector2i, mov: int, jump: int, drop: int, impassable: Dictionary) -> Dictionary:
	var cost: Dictionary = {}
	var came: Dictionary = {}
	if not in_bounds(from):
		return { "cost": cost, "came": came }
	cost[from] = 0
	var frontier: Array[Vector2i] = [from]
	while not frontier.is_empty():
		var best: int = 0
		for k in range(1, frontier.size()):
			if int(cost[frontier[k]]) < int(cost[frontier[best]]):
				best = k
		var cell: Vector2i = frontier[best]
		frontier.remove_at(best)
		for dir: Vector2i in NEIGHBOR_DIRS:
			var next: Vector2i = cell + dir
			if impassable.has(next) or not can_step(cell, next, jump, drop):
				continue
			var c: int = int(cost[cell]) + step_cost(next)
			if c > mov or (cost.has(next) and int(cost[next]) <= c):
				continue
			cost[next] = c
			came[next] = cell
			if not frontier.has(next):
				frontier.append(next)
	return { "cost": cost, "came": came }


func _index(cell: Vector2i) -> int:
	return cell.y * width + cell.x
