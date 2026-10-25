class_name BosqueMap
extends RefCounted
## Reparto de los chunks de una región en Bosques (escala: chunk < Bosque < área < región).
## Cada Bosque es un grupo contiguo de MIN_SIZE a MAX_SIZE chunks. Determinista por seed (ADR 0006):
## crecimiento aleatorio desde semillas sobre el grid de chunks y luego arreglo de los grupos
## pequeños (fusión con un vecino o cesión de chunks del borde de un vecino grande).
## Red de caminos principales (ADR 0006): árbol de expansión sobre la adyacencia de Bosques,
## enraizado en el Bosque natal, más un ROAD_EXTRA_PERCENT de aristas extra (ciclos). Cada arista
## se traduce en chunks contiguos entre los dos chunks de Nujio. Se calcula una vez por mapa.
## Estados de Bosque (bosques-y-relacion.md, #133): cada Bosque nace sano, enojado, corrupto,
## muerto o necesita_ayuda según la seed y el bloque "bosque_states" de la región. El natal y sus
## vecinos a safe_distance o menos son siempre sanos; los muertos no tienen Nujio (ni villa). Los
## cambios durante la partida no viven aquí: BosqueStates los guarda en GameState.
## Mundo 2.0 (ADR 0014 §5): build_planned() es el reparto que usa RegionPlan. Añade Bosques clave
## pintados (bosques.png + lugares.csv), villas del CSV (la natal sustituye a start_chunk), áreas
## (ADR 0007: 6-12 Bosques), aldeas (opción C de mundo-2.md §6) y caminos pintados. build() y
## for_region() siguen exactamente igual: el juego actual los usa.

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
## Reparto de refugios por la región (bloque "refuges" del JSON; ADR 0006). `per_bosque`: mínimo
## de refugios por Bosque (el primero, en su chunk de Nujio); `min_spacing`: distancia mínima
## (Manhattan, en chunks) entre los refugios del reparto general (2 = nunca en chunks vecinos,
## sale ~1 de cada 2-3 chunks); `max_distance`: ningún chunk queda más lejos de un refugio.
const DEFAULT_REFUGES: Dictionary = { "per_bosque": 1, "min_spacing": 2, "max_distance": 2 }
const SALT_REFUGE_ORDER: int = 19
const SALT_STATE_ORDER: int = 57
const SALT_STATE_COUNT: int = 58
## Estados de Bosque (bosques-y-relacion.md, modelo de datos: `state`).
const STATE_SANO: String = "sano"
const STATE_ENOJADO: String = "enojado"
const STATE_CORRUPTO: String = "corrupto"
const STATE_MUERTO: String = "muerto"
const STATE_NECESITA_AYUDA: String = "necesita_ayuda"
const STATES: Array[String] = [STATE_SANO, STATE_ENOJADO, STATE_CORRUPTO, STATE_MUERTO, STATE_NECESITA_AYUDA]
## Reparto de estados (bloque "bosque_states" de la región). `safe_distance`: el natal y los
## Bosques a esta distancia o menos (saltos de adyacencia) son siempre sanos. `necesita_ayuda`,
## `corrupto` y `muerto`: [mín, máx] Bosques con ese estado (los muertos, solo entre los que no
## tienen villa). `enojado_percent`: % de los candidatos que quedan que nacen enojados. El resto,
## sanos. Si no hay candidatos suficientes, salen menos.
const DEFAULT_STATES: Dictionary = {
	"safe_distance": 1, "necesita_ayuda": [1, 2], "corrupto": [1, 2], "muerto": [1, 2], "enojado_percent": 25,
}
## Área (ADR 0007): grupo contiguo de AREA_MIN a AREA_MAX Bosques. Ni los datos ni el código
## anterior la definían por geometría, así que build_planned() la reparte así (ver
## docs/design/world/generation.md). Los nombres de área ("areas" del JSON) no se asignan aquí.
const AREA_MIN: int = 6
const AREA_MAX: int = 12
## Aldeas (mundo-2.md §6, opción C): `chance` por Bosque sin villa con nombre ni vecino de una,
## como mucho `max_per_area` por área. Los Bosques muertos no tienen aldea (no tienen Nujio).
const DEFAULT_ALDEAS: Dictionary = { "max_per_area": 2 }
const SALT_AREA: int = 121
const SALT_ALDEA: int = 122
const SALT_ALDEA_ORDER: int = 123

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
var _refuges: Dictionary = {}  # Vector2i -> true (chunks con refugio)
## Estado de generación de cada Bosque (índice = id): uno de STATES.
var state: Array[String] = []
## Solo en build_planned() (vacíos en build()):
## Por Bosque: índice del Bosque clave en lugares.csv (RegionAuthoring.bosque_places()), o -1.
var key_index: PackedInt32Array = PackedInt32Array()
## Por Bosque: tiene una aldea (villa procedural sin nombre propio).
var has_aldea: Array[bool] = []
## Por Bosque: su área (0..area_count - 1).
var area_of: PackedInt32Array = PackedInt32Array()
var area_count: int = 0
var _locked: Dictionary = {}  # Vector2i -> true: chunk que no se cede (pintado o con villa)
var _anchors: Dictionary = {}  # Vector2i -> true: chunk con villa o de Bosque clave
var _painted_roads: Dictionary = {}  # Vector2i(a, b) -> true: aristas unidas ya por caminos pintados


## Reparto de la región `region` (JSON) con su Bosque inicial (el de start_chunk) con villa.
static func for_region(seed_value: int, region: Dictionary) -> BosqueMap:
	return build(seed_value, ChunkGenerator.region_size(region), ChunkGenerator.region_start_chunk(region),
			region.get("refuges", {}), region.get("bosque_states", {}))


## `home_chunk`: chunk inicial de la partida. Su Bosque tiene siempre villa (el lugar natal del
## Adoc, ADR 0009), fuera del sorteo de 1 de cada VILLA_ODDS; el resto no cambia.
## `refuges`: parámetros del reparto de refugios (DEFAULT_REFUGES si faltan).
## `states`: parámetros del reparto de estados (DEFAULT_STATES si faltan).
static func build(seed_value: int, size: Vector2i, home_chunk: Vector2i = Vector2i(-1, -1),
		refuges: Dictionary = {}, states: Dictionary = {}) -> BosqueMap:
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
	map._assign_states(seed_value, DEFAULT_STATES.merged(states, true))
	map._build_roads(seed_value)
	map._assign_refuges(seed_value, DEFAULT_REFUGES.merged(refuges, true))
	return map


## Reparto del Mundo 2.0 (RegionPlan, ADR 0014 §5). `params`:
## - `key_chunks`: Array (uno por Bosque clave, en el orden de lugares.csv) de Array[Vector2i] con
##   sus chunks pintados. Esos chunks son fijos; si son menos de MIN_SIZE, el Bosque crece hasta
##   MIN_SIZE por chunks libres de alrededor.
## - `key_nujio`: Array[Vector2i], chunk del Nujio de cada Bosque clave (la fila del CSV).
## - `villa_chunks`: Array[Vector2i], chunks de las villas con nombre, la natal primero. Cada una
##   empieza su propio Bosque, así que dos villas no comparten Bosque salvo que no quepa otra cosa.
##   El Bosque con villa la tiene (sin el sorteo de 1 de cada VILLA_ODDS) y su Nujio va en ella.
## - `home_chunk`: chunk de la villa natal (raíz de la red de caminos).
## - `refuges`, `states`: como en build().
## - `procedural_villa_chance` (0 = sin aldeas) y `aldeas` ({ max_per_area }).
## - `painted_road_sides`: Dictionary chunk -> Array[Vector2i] de lados con camino pintado. Se
##   suman a road_sides() y la red procedural no duplica los tramos que ya unen.
static func build_planned(seed_value: int, size: Vector2i, params: Dictionary) -> BosqueMap:
	var map := BosqueMap.new()
	map.grid_size = size
	map.ids.resize(size.x * size.y)
	map.ids.fill(-1)
	var rng := RandomNumberGenerator.new()
	rng.seed = ChunkGenerator.hash_ints([seed_value, SALT_BOSQUE])
	var key_chunks: Array = params.get("key_chunks", [])
	var key_nujio: Array = params.get("key_nujio", [])
	var villa_chunks: Array = params.get("villa_chunks", [])
	var key_first: Array[Vector2i] = map._grow_planned(rng, key_chunks, villa_chunks)
	map._fix_small_groups_planned()
	map._compact()
	map._assign_traits(seed_value)
	map.key_index.resize(map.count())
	map.key_index.fill(-1)
	for k: int in key_first.size():
		var id: int = map.bosque_at(key_first[k])
		if id < 0 or map.key_index[id] >= 0:
			continue
		map.key_index[id] = k
		var nujio: Vector2i = key_nujio[k] if k < key_nujio.size() else Vector2i(-1, -1)
		if map.bosque_at(nujio) == id:
			map.nujio_chunk[id] = nujio
	map.has_villa.fill(false)
	for v: Vector2i in villa_chunks:
		var id: int = map.bosque_at(v)
		if id < 0 or map.has_villa[id]:
			continue
		map.has_villa[id] = true
		if map.key_index[id] < 0:
			map.nujio_chunk[id] = v
	var home_chunk: Vector2i = params.get("home_chunk", Vector2i(-1, -1))
	map.home_bosque = map.bosque_at(home_chunk) if map._in_grid(home_chunk) else map.bosque_at(size / 2)
	map._assign_states(seed_value, DEFAULT_STATES.merged(params.get("states", {}), true))
	map._assign_areas(seed_value)
	map._assign_aldeas(seed_value, float(params.get("procedural_villa_chance", 0.0)),
			DEFAULT_ALDEAS.merged(params.get("aldeas", {}), true))
	map._build_roads_planned(seed_value, params.get("painted_road_sides", {}))
	map._assign_refuges(seed_value, DEFAULT_REFUGES.merged(params.get("refuges", {}), true))
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


## Estado de generación del Bosque ("" fuera de la región). El de la partida (con los cambios)
## lo da BosqueStates.state_of.
func state_of(bosque_id: int) -> String:
	return state[bosque_id] if bosque_id >= 0 and bosque_id < state.size() else ""


## El Bosque tiene Nujio: todos menos los muertos.
func has_nujio(bosque_id: int) -> bool:
	return bosque_id >= 0 and bosque_id < count() and state_of(bosque_id) != STATE_MUERTO


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


## Crecimiento del Mundo 2.0: 1) chunks pintados de los Bosques clave; 2) un chunk por villa con
## nombre (fuera de los Bosques clave); 3) los Bosques clave pequeños crecen hasta MIN_SIZE;
## 4) cada villa crece hasta su objetivo; 5) el resto, como _grow. Devuelve, por Bosque clave, un
## chunk suyo (o (-1, -1) si no tiene ninguno libre) para encontrarlo tras _compact.
func _grow_planned(rng: RandomNumberGenerator, key_chunks: Array, villa_chunks: Array) -> Array[Vector2i]:
	var key_first: Array[Vector2i] = []
	var key_ids: Array[int] = []
	for k: int in key_chunks.size():
		var bosque_id: int = _groups.size()
		var group: Array[Vector2i] = []
		for c: Vector2i in key_chunks[k]:
			if _in_grid(c) and bosque_at(c) == -1:
				_set_id(c, bosque_id)
				group.append(c)
				_locked[c] = true
				_anchors[c] = true
		_groups.append(group)
		key_ids.append(bosque_id)
		key_first.append(group[0] if not group.is_empty() else Vector2i(-1, -1))
	var villa_ids: Array[int] = []
	for v: Vector2i in villa_chunks:
		if not _in_grid(v):
			continue
		_locked[v] = true
		_anchors[v] = true
		if bosque_at(v) != -1:
			continue
		var fresh: Array[Vector2i] = [v]
		_set_id(v, _groups.size())
		villa_ids.append(_groups.size())
		_groups.append(fresh)
	for bosque_id: int in key_ids:
		_grow_group(bosque_id, MIN_SIZE, rng)
	for bosque_id: int in villa_ids:
		_grow_group(bosque_id, rng.randi_range(GROW_MIN, GROW_MAX), rng)
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
		var fresh: Array[Vector2i] = [start]
		_set_id(start, _groups.size())
		_groups.append(fresh)
		_grow_group(_groups.size() - 1, rng.randi_range(GROW_MIN, GROW_MAX), rng)
	return key_first


## Añade al grupo chunks libres vecinos (al azar con `rng`) hasta `target` o hasta no poder más.
func _grow_group(bosque_id: int, target: int, rng: RandomNumberGenerator) -> void:
	var group: Array = _groups[bosque_id]
	var frontier: Array[Vector2i] = []
	for c: Vector2i in group:
		frontier.append_array(_free_neighbours(c))
	while group.size() < target and not frontier.is_empty():
		var c: Vector2i = frontier.pop_at(rng.randi() % frontier.size())
		if bosque_at(c) != -1:
			continue
		_set_id(c, bosque_id)
		group.append(c)
		frontier.append_array(_free_neighbours(c))


## Grupo con villa con nombre o Bosque clave: dos de estos solo se fusionan si no queda otra.
func _is_anchored(bosque_id: int) -> bool:
	for c: Vector2i in _groups[bosque_id]:
		if _anchors.has(c):
			return true
	return false


## Como _fix_small_groups, sin juntar dos grupos con villa o clave y sin ceder chunks fijos. Un
## grupo pequeño sin villa se fusiona con el vecino más pequeño en el que quepa; uno con villa
## primero roba chunks del borde a sus vecinos grandes.
func _fix_small_groups_planned() -> void:
	for bosque_id: int in _groups.size():
		var group: Array = _groups[bosque_id]
		if group.is_empty() or group.size() >= MIN_SIZE:
			continue
		var neighbours: Array[int] = _neighbour_ids(bosque_id)
		if neighbours.is_empty():
			continue
		var anchored: bool = _is_anchored(bosque_id)
		var into: int = -1
		for n: int in neighbours:
			if size_of(n) + group.size() <= MAX_SIZE and not (anchored and _is_anchored(n)):
				into = n
				break
		if into >= 0 and not anchored:
			_merge(bosque_id, into)
			continue
		while group.size() < MIN_SIZE and _steal_one(bosque_id):
			pass
		if group.size() < MIN_SIZE:
			_merge(bosque_id, into if into >= 0 else neighbours[0])


## Áreas (ADR 0007: 6-12 Bosques contiguos). Desde el Bosque natal y luego por id, cada área
## crece en anchura por los vecinos sin área hasta un objetivo por hash en AREA_MIN..AREA_MAX. Las
## que se quedan por debajo de AREA_MIN (rodeadas) se unen al área vecina más pequeña, aunque
## pase de AREA_MAX: una región pequeña no siempre se puede partir exacta.
func _assign_areas(seed_value: int) -> void:
	area_of.resize(count())
	area_of.fill(-1)
	var areas: Array = []
	var starts: Array[int] = []
	if home_bosque >= 0:
		starts.append(home_bosque)
	for id: int in count():
		starts.append(id)
	for start: int in starts:
		if area_of[start] >= 0:
			continue
		var a: int = areas.size()
		var target: int = AREA_MIN + ChunkGenerator.hash_ints([seed_value, a, SALT_AREA]) % (AREA_MAX - AREA_MIN + 1)
		var members: Array[int] = [start]
		area_of[start] = a
		var head: int = 0
		while head < members.size() and members.size() < target:
			var id: int = members[head]
			head += 1
			var near: Array[int] = _neighbour_ids(id)
			near.sort()
			for n: int in near:
				if members.size() >= target:
					break
				if area_of[n] < 0:
					area_of[n] = a
					members.append(n)
		areas.append(members)
	for a: int in areas.size():
		var members: Array = areas[a]
		if members.is_empty() or members.size() >= AREA_MIN or areas.size() == 1:
			continue
		var best: int = -1
		for id: int in members:
			for n: int in _neighbour_ids(id):
				var other: int = area_of[n]
				if other == a:
					continue
				var size_other: int = (areas[other] as Array).size()
				if best < 0 or size_other < (areas[best] as Array).size() or (size_other == (areas[best] as Array).size() and other < best):
					best = other
		if best < 0:
			continue
		for id: int in members:
			area_of[id] = best
			(areas[best] as Array).append(id)
		members.clear()
	var renumber: Dictionary = {}
	for a: int in areas.size():
		if not (areas[a] as Array).is_empty():
			renumber[a] = renumber.size()
	for id: int in count():
		area_of[id] = renumber[area_of[id]]
	area_count = renumber.size()


## Bosques de un área, por id.
func bosques_of_area(area: int) -> Array[int]:
	var out: Array[int] = []
	for id: int in area_of.size():
		if area_of[id] == area:
			out.append(id)
	return out


## Aldeas (mundo-2.md §6, opción C): en orden de hash, cada Bosque con Nujio (no muerto), sin villa
## con nombre y que no es vecino de uno con villa con nombre tiene aldea con probabilidad `chance`,
## hasta `max_per_area` por área.
func _assign_aldeas(seed_value: int, chance: float, params: Dictionary) -> void:
	has_aldea.resize(count())
	has_aldea.fill(false)
	if chance <= 0.0:
		return
	var near_villa: Dictionary = {}
	for id: int in count():
		if has_villa[id]:
			near_villa[id] = true
			for n: int in _neighbour_ids(id):
				near_villa[n] = true
	var order: Array[int] = []
	var keys: Dictionary = {}
	for id: int in count():
		order.append(id)
		keys[id] = ChunkGenerator.hash_ints([seed_value, id, SALT_ALDEA_ORDER])
	order.sort_custom(func(a: int, b: int) -> bool: return keys[a] < keys[b] or (keys[a] == keys[b] and a < b))
	var cap: int = int(params.max_per_area)
	var threshold: int = roundi(clampf(chance, 0.0, 1.0) * 1000.0)
	var per_area: Dictionary = {}
	for id: int in order:
		if near_villa.has(id) or not has_nujio(id):
			continue
		if ChunkGenerator.hash_ints([seed_value, id, SALT_ALDEA]) % 1000 >= threshold:
			continue
		var area: int = area_of[id] if id < area_of.size() else 0
		if int(per_area.get(area, 0)) >= cap:
			continue
		per_area[area] = int(per_area.get(area, 0)) + 1
		has_aldea[id] = true


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
			if _locked.has(c) or not _touches(c, bosque_id):
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


## Reparto determinista de estados. Candidatos: los Bosques a más de safe_distance del natal, en
## orden de hash. Por orden se reparten necesita_ayuda, corrupto y muerto (este, sin villa: un
## Bosque muerto no tiene Nujio) y, de los que quedan, enojado_percent % pasan a enojados. El
## resto (y el natal con sus vecinos) son sanos.
func _assign_states(seed_value: int, params: Dictionary) -> void:
	state.resize(count())
	state.fill(STATE_SANO)
	var safe: int = int(params.safe_distance)
	var candidates: Array[int] = []
	var keys: Dictionary = {}
	for id: int in count():
		if id == home_bosque or (home_bosque >= 0 and distance(home_bosque, id) <= safe):
			continue
		candidates.append(id)
		keys[id] = ChunkGenerator.hash_ints([seed_value, id, SALT_STATE_ORDER])
	candidates.sort_custom(func(a: int, b: int) -> bool: return keys[a] < keys[b] or (keys[a] == keys[b] and a < b))
	var kinds: Array[String] = [STATE_NECESITA_AYUDA, STATE_CORRUPTO, STATE_MUERTO]
	for k: int in kinds.size():
		var kind: String = kinds[k]
		var range_n: Array = params.get(kind, [0, 0])
		var lo: int = int(range_n[0])
		var hi: int = maxi(lo, int(range_n[1]))
		var wanted: int = lo + ChunkGenerator.hash_ints([seed_value, k, SALT_STATE_COUNT]) % (hi - lo + 1)
		for id: int in candidates:
			if wanted <= 0:
				break
			if state[id] != STATE_SANO or (kind == STATE_MUERTO and has_villa[id]):
				continue
			state[id] = kind
			wanted -= 1
	var rest: Array[int] = []
	for id: int in candidates:
		if state[id] == STATE_SANO:
			rest.append(id)
	var angry: int = roundi(rest.size() * float(params.enojado_percent) / 100.0)
	for i: int in mini(angry, rest.size()):
		state[rest[i]] = STATE_ENOJADO


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


## El chunk tiene un refugio (ChunkGenerator lo coloca siempre: casilla REFUGE alcanzable).
func has_refuge(coord: Vector2i) -> bool:
	return _refuges.has(coord)


## Chunks con refugio, en orden de fila.
func refuge_chunks() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in grid_size.y:
		for x: int in grid_size.x:
			if _refuges.has(Vector2i(x, y)):
				out.append(Vector2i(x, y))
	return out


## Distancia (Manhattan, en chunks) del chunk al refugio más cercano; -1 si no hay ninguno.
func refuge_distance(coord: Vector2i) -> int:
	var best: int = -1
	for r: Vector2i in _refuges:
		var d: int = absi(r.x - coord.x) + absi(r.y - coord.y)
		if best < 0 or d < best:
			best = d
	return best


## Reparto determinista de refugios, en tres pasadas:
## 1. Cada Bosque tiene `per_bosque` refugios: el primero en su chunk de Nujio (descansar el
##    riutash cerca del Nujio sube la relación, bosques-y-relacion.md); los demás, en chunks del
##    Bosque en orden de hash, lo más separados posible.
## 2. Reparto general por toda la región (con camino o sin él) en orden de hash: un chunk recibe
##    refugio si queda a `min_spacing` chunks o más de todos los anteriores.
## 3. Cobertura: todo chunk a más de `max_distance` de un refugio recibe uno.
func _assign_refuges(seed_value: int, params: Dictionary) -> void:
	var spacing: int = int(params.min_spacing)
	var max_distance: int = int(params.max_distance)
	var order: Array[Vector2i] = []
	for y: int in grid_size.y:
		for x: int in grid_size.x:
			order.append(Vector2i(x, y))
	var keys: Dictionary = {}
	for c: Vector2i in order:
		keys[c] = ChunkGenerator.hash_ints([seed_value, c.x, c.y, SALT_REFUGE_ORDER])
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return keys[a] < keys[b] or (keys[a] == keys[b] and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	for id: int in count():
		_refuges[nujio_chunk[id]] = true
		var wanted: int = int(params.per_bosque) - 1
		for min_gap: int in [spacing, 1]:
			for c: Vector2i in order:
				if wanted <= 0:
					break
				if bosque_at(c) == id and not _refuges.has(c) and refuge_distance(c) >= min_gap:
					_refuges[c] = true
					wanted -= 1
	for c: Vector2i in order:
		if refuge_distance(c) >= spacing:
			_refuges[c] = true
	for c: Vector2i in order:
		if refuge_distance(c) > max_distance:
			_refuges[c] = true


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
	_build_road_distance()


## Red del Mundo 2.0: los lados con camino pintado más la red de _build_roads (Prim desde el
## Bosque natal + ROAD_EXTRA_PERCENT de ciclos). Una arista cuyos dos Nujios ya están unidos por
## caminos pintados pesa 0 y no se traza (no se duplica el camino del dueño).
func _build_roads_planned(seed_value: int, painted_sides: Dictionary) -> void:
	for c: Vector2i in painted_sides:
		for side: Vector2i in painted_sides[c]:
			if _in_grid(c) and _in_grid(c + side):
				_add_road_side(c, side)
	if home_bosque < 0:
		return
	# Componentes de chunks unidos por caminos pintados.
	var comp: Dictionary = {}
	for y: int in grid_size.y:
		for x: int in grid_size.x:
			var start := Vector2i(x, y)
			if comp.has(start) or not _road_sides.has(start):
				continue
			var label: int = comp.size()
			comp[start] = label
			var queue: Array[Vector2i] = [start]
			var head: int = 0
			while head < queue.size():
				var c: Vector2i = queue[head]
				head += 1
				for d: Vector2i in _road_sides[c]:
					if not comp.has(c + d):
						comp[c + d] = label
						queue.append(c + d)
	var joined := func(a: int, b: int) -> bool:
		return comp.has(nujio_chunk[a]) and comp.has(nujio_chunk[b]) and comp[nujio_chunk[a]] == comp[nujio_chunk[b]]
	var in_tree: Dictionary = { home_bosque: true }
	var tree: Dictionary = {}
	while in_tree.size() < count():
		var best := Vector2i(-1, -1)
		var best_w: int = 1 << 62
		for a: int in in_tree:
			for b: int in _neighbour_ids(a):
				if in_tree.has(b):
					continue
				var w: int = 0 if joined.call(a, b) else _edge_weight(seed_value, a, b, SALT_ROAD)
				if w < best_w or (w == best_w and _edge(a, b) < best):
					best_w = w
					best = Vector2i(a, b)
		if best.x < 0:
			break
		in_tree[best.y] = true
		tree[_edge(best.x, best.y)] = true
	for a: int in count():
		for b: int in _neighbour_ids(a):
			var e: Vector2i = _edge(a, b)
			if a > b or tree.has(e) or joined.call(a, b):
				continue
			if _edge_weight(seed_value, a, b, SALT_ROAD_EXTRA) % 100 < ROAD_EXTRA_PERCENT:
				tree[e] = true
	for e: Vector2i in tree:
		road_edges.append(e)
	road_edges.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return p.x < q.x or (p.x == q.x and p.y < q.y))
	for e: Vector2i in road_edges:
		if joined.call(e.x, e.y):
			_painted_roads[e] = true
			continue
		var route: Array[Vector2i] = _chunk_route(seed_value, e.x, e.y)
		for i: int in route.size() - 1:
			_add_road_side(route[i], route[i + 1] - route[i])
			_add_road_side(route[i + 1], route[i] - route[i + 1])
	_build_road_distance()


## La arista de road_edges la cubren caminos pintados (no se trazó).
func is_painted_road_edge(edge: Vector2i) -> bool:
	return _painted_roads.has(_edge(edge.x, edge.y))


## Distancia por camino a la villa natal y lado del siguiente tramo hacia casa.
func _build_road_distance() -> void:
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
