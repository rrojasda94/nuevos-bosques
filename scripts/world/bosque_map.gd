class_name BosqueMap
extends RefCounted
## Reparto de los chunks de una región en Bosques (escala: chunk < Bosque < área < región).
## Cada Bosque es un grupo contiguo de MIN_SIZE a MAX_SIZE chunks. Determinista por seed (ADR 0006):
## crecimiento aleatorio desde semillas sobre el grid de chunks y luego arreglo de los grupos
## pequeños (fusión con un vecino o cesión de chunks del borde de un vecino grande).
## Red de caminos principales (ADR 0006): árbol de expansión sobre la adyacencia de Bosques,
## enraizado en el Bosque natal, más un ROAD_EXTRA_PERCENT de aristas extra (ciclos). Cada arista
## se traduce en chunks contiguos entre los dos chunks de Nujio. Se calcula una vez por mapa.

const MIN_SIZE: int = 4
const MAX_SIZE: int = 16
## Tamaño objetivo al crecer; los arreglos posteriores mantienen todo dentro de MIN..MAX.
const GROW_MIN: int = 6
const GROW_MAX: int = 12
const SALT_BOSQUE: int = 5
const SALT_STYLE: int = 8
const SALT_VILLA: int = 9
const SALT_NUJIO: int = 10
## 1 de cada VILLA_ODDS Bosques tiene villa (ADR 0008).
const VILLA_ODDS: int = 5
const NUJIO_MIN: int = 6
const NUJIO_MAX: int = 8
const SALT_ROAD: int = 15
const SALT_ROAD_EXTRA: int = 16
const SALT_ROAD_ORDER: int = 17
## Porcentaje de aristas de adyacencia fuera del árbol que también llevan camino (ciclos).
const ROAD_EXTRA_PERCENT: int = 15
## Refugio en los chunks de camino cuya distancia por camino a la villa natal, módulo
## REFUGE_PERIOD, esté en REFUGE_STEPS: uno cada 2 o 3 chunks yendo hacia casa.
const REFUGE_PERIOD: int = 5
const REFUGE_STEPS: Array[int] = [1, 3]

var grid_size: Vector2i = Vector2i.ZERO
## Id de Bosque por chunk (fila a fila). Los ids van de 0 a count() - 1.
var ids: PackedInt32Array = PackedInt32Array()
var _groups: Array = []  # Array[Array[Vector2i]], índice = id
## Por Bosque (índice = id): aspecto y rasgos. Todo determinista por seed.
## style = { "shape", "leaf", "trunk", "ground" }: índices en las tablas de PlaceholderTileset.
var styles: Array[Dictionary] = []
var has_villa: Array[bool] = []
## Chunk que contiene al Nujio (y a la villa, si la hay): el más central del Bosque.
var nujio_chunk: Array[Vector2i] = []
var nujio_size: Array[int] = []
## Bosque natal (el de home_chunk; sin home_chunk, el del centro de la región). Raíz de la red.
var home_bosque: int = -1
## Aristas Bosque–Bosque con camino principal: Vector2i(a, b) con a < b.
var road_edges: Array[Vector2i] = []
var _road_sides: Dictionary = {}  # Vector2i -> Array[Vector2i]
var _road_distance: Dictionary = {}  # Vector2i -> int (chunks de camino hasta la villa natal)
var _road_home_side: Dictionary = {}  # Vector2i -> Vector2i (lado del siguiente tramo a casa)


## Reparto de la región `region` (JSON) con su Bosque inicial (el de start_chunk) con villa.
static func for_region(seed_value: int, region: Dictionary) -> BosqueMap:
	return build(seed_value, ChunkGenerator.region_size(region), ChunkGenerator.region_start_chunk(region))


## `home_chunk`: chunk inicial de la partida. Su Bosque tiene siempre villa (el lugar natal del
## Adoc, ADR 0009), fuera del sorteo de 1 de cada VILLA_ODDS; el resto no cambia.
static func build(seed_value: int, size: Vector2i, home_chunk: Vector2i = Vector2i(-1, -1)) -> BosqueMap:
	var map := BosqueMap.new()
	map.grid_size = size
	map.ids.resize(size.x * size.y)
	map.ids.fill(-1)
	var rng := RandomNumberGenerator.new()
	rng.seed = ChunkGenerator.hash_ints([seed_value, SALT_BOSQUE])
	map._grow(rng)
	map._fix_small_groups()
	map._compact()
	map._assign_traits(seed_value)
	if map._in_grid(home_chunk):
		map.has_villa[map.bosque_at(home_chunk)] = true
		map.home_bosque = map.bosque_at(home_chunk)
	else:
		map.home_bosque = map.bosque_at(size / 2)
	map._build_roads(seed_value)
	return map


func count() -> int:
	return _groups.size()


## Id del Bosque del chunk, o -1 si está fuera de la región.
func bosque_at(coord: Vector2i) -> int:
	if not _in_grid(coord):
		return -1
	return ids[coord.y * grid_size.x + coord.x]


func size_of(bosque_id: int) -> int:
	return (_groups[bosque_id] as Array).size() if bosque_id >= 0 and bosque_id < _groups.size() else 0


func chunks_of(bosque_id: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if bosque_id >= 0 and bosque_id < _groups.size():
		out.assign(_groups[bosque_id])
	return out


func _in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < grid_size.x and c.y < grid_size.y


func _set_id(c: Vector2i, bosque_id: int) -> void:
	ids[c.y * grid_size.x + c.x] = bosque_id


func _grow(rng: RandomNumberGenerator) -> void:
	# Orden de semillas barajado con el RNG propio (Array.shuffle usa el RNG global).
	var order: Array[Vector2i] = []
	for y: int in grid_size.y:
		for x: int in grid_size.x:
			order.append(Vector2i(x, y))
	for i: int in range(order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = order[i]
		order[i] = order[j]
		order[j] = tmp
	for start: Vector2i in order:
		if bosque_at(start) != -1:
			continue
		var bosque_id: int = _groups.size()
		var target: int = rng.randi_range(GROW_MIN, GROW_MAX)
		var group: Array[Vector2i] = [start]
		_set_id(start, bosque_id)
		var frontier: Array[Vector2i] = _free_neighbours(start)
		while group.size() < target and not frontier.is_empty():
			var c: Vector2i = frontier.pop_at(rng.randi() % frontier.size())
			if bosque_at(c) != -1:
				continue
			_set_id(c, bosque_id)
			group.append(c)
			frontier.append_array(_free_neighbours(c))
		_groups.append(group)


func _free_neighbours(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in ChunkData.SIDES:
		if _in_grid(c + d) and bosque_at(c + d) == -1:
			out.append(c + d)
	return out


## Ids vecinos de un grupo, ordenados por tamaño y luego por id (determinista).
func _neighbour_ids(bosque_id: int) -> Array[int]:
	var out: Array[int] = []
	for c: Vector2i in _groups[bosque_id]:
		for d: Vector2i in ChunkData.SIDES:
			var other: int = bosque_at(c + d)
			if other != -1 and other != bosque_id and not out.has(other):
				out.append(other)
	out.sort_custom(func(a: int, b: int) -> bool:
		return size_of(a) < size_of(b) or (size_of(a) == size_of(b) and a < b))
	return out


func _fix_small_groups() -> void:
	for bosque_id: int in _groups.size():
		var group: Array = _groups[bosque_id]
		if group.is_empty() or group.size() >= MIN_SIZE:
			continue
		var neighbours: Array[int] = _neighbour_ids(bosque_id)
		if neighbours.is_empty():
			continue
		if size_of(neighbours[0]) + group.size() <= MAX_SIZE:
			_merge(bosque_id, neighbours[0])
			continue
		# Vecinos demasiado grandes para fusionar: se les quitan chunks del borde.
		while group.size() < MIN_SIZE and _steal_one(bosque_id):
			pass
		if group.size() < MIN_SIZE:
			_merge(bosque_id, neighbours[0])


func _merge(from_id: int, into_id: int) -> void:
	for c: Vector2i in _groups[from_id]:
		_set_id(c, into_id)
		(_groups[into_id] as Array).append(c)
	(_groups[from_id] as Array).clear()


## Pasa al grupo `bosque_id` un chunk de un vecino que siga contiguo y con más de MIN_SIZE.
func _steal_one(bosque_id: int) -> bool:
	var neighbours: Array[int] = _neighbour_ids(bosque_id)
	neighbours.reverse()
	for other: int in neighbours:
		if size_of(other) <= MIN_SIZE:
			continue
		for c: Vector2i in (_groups[other] as Array).duplicate():
			if not _touches(c, bosque_id):
				continue
			var rest: Array = (_groups[other] as Array).duplicate()
			rest.erase(c)
			if _is_contiguous(rest):
				_groups[other] = rest
				_set_id(c, bosque_id)
				(_groups[bosque_id] as Array).append(c)
				return true
	return false


func _touches(c: Vector2i, bosque_id: int) -> bool:
	for d: Vector2i in ChunkData.SIDES:
		if bosque_at(c + d) == bosque_id:
			return true
	return false


static func _is_contiguous(cells: Array) -> bool:
	if cells.is_empty():
		return true
	var seen: Array = [cells[0]]
	var head: int = 0
	while head < seen.size():
		var c: Vector2i = seen[head]
		head += 1
		for d: Vector2i in ChunkData.SIDES:
			if cells.has(c + d) and not seen.has(c + d):
				seen.append(c + d)
	return seen.size() == cells.size()


func is_contiguous(bosque_id: int) -> bool:
	return _is_contiguous(_groups[bosque_id])


## Quita los grupos vacíos y renumera los ids de forma estable.
func _compact() -> void:
	var kept: Array = []
	for group: Array in _groups:
		if group.is_empty():
			continue
		for c: Vector2i in group:
			_set_id(c, kept.size())
		kept.append(group)
	_groups = kept


## Aspecto (forma de árbol y colores), villa y Nujio de cada Bosque. Cada Bosque se compara con
## sus vecinos ya asignados: nunca comparten color de hoja y, si se puede, tampoco forma.
func _assign_traits(seed_value: int) -> void:
	var shapes: int = PlaceholderTileset.SHAPE_COUNT
	var leaves: int = PlaceholderTileset.LEAVES.size()
	var trunks: int = PlaceholderTileset.TRUNKS.size()
	var grounds: int = PlaceholderTileset.GROUNDS.size()
	for id: int in _groups.size():
		var neighbours: Array[int] = []
		for n: int in _neighbour_ids(id):
			if n < id:
				neighbours.append(n)
		var style: Dictionary = {}
		for attempt: int in 64:
			var h: int = ChunkGenerator.hash_ints([seed_value, id, attempt, SALT_STYLE])
			style = {
				"shape": h % shapes,
				"leaf": (h >> 4) % leaves,
				"trunk": (h >> 9) % trunks,
				"ground": (h >> 14) % grounds,
			}
			var clash: bool = false
			for n: int in neighbours:
				var other: Dictionary = styles[n]
				if other.leaf == style.leaf or (attempt < 32 and other.shape == style.shape):
					clash = true
					break
			if not clash:
				break
		styles.append(style)
		var hv: int = ChunkGenerator.hash_ints([seed_value, id, SALT_VILLA])
		has_villa.append(hv % VILLA_ODDS == 0)
		var hn: int = ChunkGenerator.hash_ints([seed_value, id, SALT_NUJIO])
		nujio_chunk.append(central_chunk(id))
		nujio_size.append(NUJIO_MIN + (hn >> 8) % (NUJIO_MAX - NUJIO_MIN + 1))


func neighbours_of(bosque_id: int) -> Array[int]:
	return _neighbour_ids(bosque_id)


## Distancia en saltos de adyacencia entre dos Bosques (0 = el mismo, 1 = vecinos).
## -1 si alguno no existe o no están conectados.
func distance(from_id: int, to_id: int) -> int:
	if from_id < 0 or to_id < 0 or from_id >= count() or to_id >= count():
		return -1
	var dist: Dictionary = { from_id: 0 }
	var queue: Array[int] = [from_id]
	var head: int = 0
	while head < queue.size():
		var id: int = queue[head]
		head += 1
		if id == to_id:
			return dist[id]
		for n: int in _neighbour_ids(id):
			if not dist.has(n):
				dist[n] = dist[id] + 1
				queue.append(n)
	return -1


## Chunk del Bosque más cercano a su centroide (empates: el primero en orden de crecimiento).
func central_chunk(bosque_id: int) -> Vector2i:
	var group: Array = _groups[bosque_id]
	var centroid := Vector2.ZERO
	for c: Vector2i in group:
		centroid += Vector2(c)
	centroid /= group.size()
	var best: Vector2i = group[0]
	for c: Vector2i in group:
		if Vector2(c).distance_squared_to(centroid) < Vector2(best).distance_squared_to(centroid):
			best = c
	return best


# --- Red de caminos principales ---

## Lados (dirección hacia fuera) del chunk por los que pasa un camino principal.
func road_sides(coord: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(_road_sides.get(coord, []))
	return out


func has_road(coord: Vector2i) -> bool:
	return _road_sides.has(coord)


## Chunks de camino entre `coord` y el chunk de Nujio del Bosque natal (-1 si no hay camino).
func road_distance(coord: Vector2i) -> int:
	return _road_distance.get(coord, -1)


## Lado del chunk por el que sigue el camino hacia la villa natal (ZERO en la villa o sin camino).
func road_home_side(coord: Vector2i) -> Vector2i:
	return _road_home_side.get(coord, Vector2i.ZERO)


## El chunk tiene un refugio junto al camino: uno cada 2 o 3 chunks de camino hacia casa.
func has_refuge(coord: Vector2i) -> bool:
	var d: int = road_distance(coord)
	return d > 0 and REFUGE_STEPS.has(d % REFUGE_PERIOD)


func _build_roads(seed_value: int) -> void:
	if home_bosque < 0:
		return
	# Prim con pesos por hash desde el Bosque natal.
	var in_tree: Dictionary = { home_bosque: true }
	var tree: Dictionary = {}
	while in_tree.size() < count():
		var best := Vector2i(-1, -1)
		var best_w: int = 1 << 62
		for a: int in in_tree:
			for b: int in _neighbour_ids(a):
				if in_tree.has(b):
					continue
				var w: int = _edge_weight(seed_value, a, b, SALT_ROAD)
				if w < best_w or (w == best_w and _edge(a, b) < best):
					best_w = w
					best = Vector2i(a, b)
		if best.x < 0:
			break  # Grafo no conexo (no pasa en una región completa).
		in_tree[best.y] = true
		tree[_edge(best.x, best.y)] = true
	for a: int in count():
		for b: int in _neighbour_ids(a):
			var e: Vector2i = _edge(a, b)
			if a > b or tree.has(e):
				continue
			if _edge_weight(seed_value, a, b, SALT_ROAD_EXTRA) % 100 < ROAD_EXTRA_PERCENT:
				tree[e] = true
	for e: Vector2i in tree:
		road_edges.append(e)
	road_edges.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return p.x < q.x or (p.x == q.x and p.y < q.y))
	for e: Vector2i in road_edges:
		var route: Array[Vector2i] = _chunk_route(seed_value, e.x, e.y)
		for i: int in route.size() - 1:
			_add_road_side(route[i], route[i + 1] - route[i])
			_add_road_side(route[i + 1], route[i] - route[i + 1])
	# Distancia por camino a la villa natal y lado del siguiente tramo hacia casa.
	var home: Vector2i = nujio_chunk[home_bosque]
	_road_distance[home] = 0
	var queue: Array[Vector2i] = [home]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d: Vector2i in ChunkData.SIDES:
			if not (_road_sides.get(c, []) as Array).has(d) or _road_distance.has(c + d):
				continue
			_road_distance[c + d] = _road_distance[c] + 1
			_road_home_side[c + d] = -d
			queue.append(c + d)


static func _edge(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


static func _edge_weight(seed_value: int, a: int, b: int, salt: int) -> int:
	return ChunkGenerator.hash_ints([seed_value, mini(a, b), maxi(a, b), salt])


func _add_road_side(coord: Vector2i, side: Vector2i) -> void:
	if not _road_sides.has(coord):
		var fresh: Array[Vector2i] = []
		_road_sides[coord] = fresh
	var sides: Array = _road_sides[coord]
	if not sides.has(side):
		sides.append(side)


## Camino más corto por chunks contiguos entre los Nujios de dos Bosques vecinos, sin salir de
## ellos. El orden de los vecinos en el BFS sale de un hash para que no sean todo eles.
func _chunk_route(seed_value: int, a: int, b: int) -> Array[Vector2i]:
	var from: Vector2i = nujio_chunk[a]
	var to: Vector2i = nujio_chunk[b]
	var parent: Dictionary = { from: from }
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == to:
			break
		var dirs: Array[Vector2i] = ChunkData.SIDES.duplicate()
		var h: int = ChunkGenerator.hash_ints([seed_value, c.x, c.y, SALT_ROAD_ORDER])
		for i: int in range(dirs.size() - 1, 0, -1):
			var j: int = (h >> (i * 3)) % (i + 1)
			var tmp: Vector2i = dirs[i]
			dirs[i] = dirs[j]
			dirs[j] = tmp
		for d: Vector2i in dirs:
			var n: Vector2i = c + d
			var id: int = bosque_at(n)
			if (id == a or id == b) and not parent.has(n):
				parent[n] = c
				queue.append(n)
	var route: Array[Vector2i] = []
	if not parent.has(to):
		return route
	var cur: Vector2i = to
	while cur != from:
		route.append(cur)
		cur = parent[cur]
	route.append(from)
	route.reverse()
	return route
