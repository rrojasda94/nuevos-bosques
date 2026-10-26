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
##   la columna interior y las filas del centro. entry_cells, las de entrada de un refuerzo (T1b):
##   primero la columna del borde.
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
## Transitable por casilla (caché de is_walkable para las búsquedas; se rehace tras set_cell).
var _walk: PackedByteArray
var _walk_dirty: bool = true


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
	board._walk_dirty = true
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
	_walk_dirty = true


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


## Coste a pie (sin límite de Mov) desde cada casilla hasta la meta más cercana de `goals`: { Vector2i:
## coste }. Búsqueda hacia atrás desde las metas (subir y bajar se invierten) por cubos de coste: lineal
## en casillas. `blocked`: casillas que no se cruzan. Para que la IA se acerque (TacticalAI, T5).
func walk_cost_to(goals: Array[Vector2i], jump: int, drop: int, blocked: Dictionary = {}) -> Dictionary:
	_refresh_walk()
	var dist: Dictionary = {}
	var buckets: Array = [[]]
	for g: Vector2i in goals:
		if is_walkable(g) and not blocked.has(g) and not dist.has(g):
			dist[g] = 0
			(buckets[0] as Array).append(g)
	var k: int = 0
	while k < buckets.size():
		var bucket: Array = buckets[k]
		var n: int = 0
		while n < bucket.size():
			var x: Vector2i = bucket[n]
			n += 1
			if int(dist[x]) != k:
				continue
			var xi: int = _index(x)
			var x_level: int = _level[xi]
			var x_stair: bool = _stair[xi] == 1
			var enter: int = ford_cost if _ford[xi] == 1 else 1
			for dir: Vector2i in NEIGHBOR_DIRS:
				var y: Vector2i = x + dir
				if y.x < 0 or y.y < 0 or y.x >= width or y.y >= height or blocked.has(y):
					continue
				var yi: int = y.y * width + y.x
				if _walk[yi] == 0:
					continue
				# Paso real (hacia delante): de y a x.
				if not x_stair and _stair[yi] == 0:
					var rise: int = x_level - _level[yi]
					if (rise >= 0 and rise > jump) or (rise < 0 and -rise > drop):
						continue
				var c: int = k + enter
				if dist.has(y) and int(dist[y]) <= c:
					continue
				dist[y] = c
				while buckets.size() <= c:
					buckets.append([])
				(buckets[c] as Array).append(y)
		k += 1
	return dist


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


## Casillas de entrada de un refuerzo (T1b): transitables, primero la columna del borde de su lado
## y, dentro de cada columna, las filas del centro hacia fuera; luego las columnas siguientes hacia
## el centro ("Refuerzo con su columna ocupada: entra por la casilla libre más cercana de su borde").
func entry_cells(side: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var rows: Array[int] = _center_rows()
	for k in width:
		var col: int = k if side == Side.LEFT else width - 1 - k
		for row: int in rows:
			var c := Vector2i(col, row)
			if is_walkable(c):
				out.append(c)
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


## Dijkstra sobre el tablero (pocas casillas: frontera ordenada a mano). { cost, came }. Los pasos
## son los de can_step, con las comprobaciones en línea (se llama mucho: IA, T5).
func _search(from: Vector2i, mov: int, jump: int, drop: int, impassable: Dictionary) -> Dictionary:
	var cost: Dictionary = {}
	var came: Dictionary = {}
	if not in_bounds(from):
		return { "cost": cost, "came": came }
	_refresh_walk()
	cost[from] = 0
	var frontier: Array[Vector2i] = [from]
	var queued: Dictionary = { from: true }
	while not frontier.is_empty():
		var best: int = 0
		for k in range(1, frontier.size()):
			if int(cost[frontier[k]]) < int(cost[frontier[best]]):
				best = k
		var cell: Vector2i = frontier[best]
		frontier.remove_at(best)
		queued.erase(cell)
		var ci: int = _index(cell)
		var cell_cost: int = int(cost[cell])
		var cell_level: int = _level[ci]
		var cell_stair: bool = _stair[ci] == 1
		for dir: Vector2i in NEIGHBOR_DIRS:
			var next: Vector2i = cell + dir
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height or impassable.has(next):
				continue
			var ni: int = next.y * width + next.x
			if _walk[ni] == 0:
				continue
			if not cell_stair and _stair[ni] == 0:
				var rise: int = _level[ni] - cell_level
				if (rise >= 0 and rise > jump) or (rise < 0 and -rise > drop):
					continue
			var c: int = cell_cost + (ford_cost if _ford[ni] == 1 else 1)
			if c > mov or (cost.has(next) and int(cost[next]) <= c):
				continue
			cost[next] = c
			came[next] = cell
			if not queued.has(next):
				frontier.append(next)
				queued[next] = true
	return { "cost": cost, "came": came }


func _refresh_walk() -> void:
	if not _walk_dirty:
		return
	_walk.resize(width * height)
	for y in height:
		for x in width:
			_walk[y * width + x] = 1 if is_walkable(Vector2i(x, y)) else 0
	_walk_dirty = false


func _index(cell: Vector2i) -> int:
	return cell.y * width + cell.x
