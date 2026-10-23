class_name BosqueMap
extends RefCounted
## Reparto de los chunks de una región en Bosques (escala: chunk < Bosque < área < región).
## Cada Bosque es un grupo contiguo de MIN_SIZE a MAX_SIZE chunks. Determinista por seed (ADR 0006):
## crecimiento aleatorio desde semillas sobre el grid de chunks y luego arreglo de los grupos
## pequeños (fusión con un vecino o cesión de chunks del borde de un vecino grande).

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


static func build(seed_value: int, size: Vector2i) -> BosqueMap:
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
