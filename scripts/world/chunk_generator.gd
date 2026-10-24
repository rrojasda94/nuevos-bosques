class_name ChunkGenerator
extends RefCounted
## Genera un ChunkData determinista a partir de (seed, coordenadas del chunk en la región), los
## parámetros de la región y el reparto en Bosques. ADR 0006:
## - El terreno base se muestrea en coordenadas de mundo: relieve, ríos y bosque continúan entre
##   chunks vecinos.
## - Montañas al norte (gradiente norte-sur de la región) con afloramientos de roca irregulares.
## - El río principal es una línea serpenteante que cruza la región de norte a sur sin cortes,
##   con vados cada cierta distancia. Los arroyos del norte son curvas de nivel de un ruido.
## - Los árboles bloquean; hay huecos y pasillos naturales entre ellos.
## - Nujio en el centro del chunk más central de su Bosque (BosqueMap), en un claro o en el
##   centro de la villa si el Bosque la tiene.
## - La aleatoriedad local sale de un RNG propio sembrado con hash(seed, x, y). No se usa
##   GameState.rng ni randi()/randf() globales.
## - Cada borde tiene una entrada (sendero) en la misma posición vista desde los dos chunks.
## - Los lados con camino principal (BosqueMap.road_sides) llevan un ROAD de 2 casillas en vez
##   del sendero, con letreros hacia la villa natal.
## - Refugios (REFUGE) en los chunks que marca BosqueMap.has_refuge (todos los Bosques, con camino
##   o sin él): junto al Nujio, a un camino, sendero o claro, siempre alcanzables desde el hub.
## - Frutales (FRUIT_TREE) en los Bosques que dan fruto (bloque "fruit" de la región): unos pocos
##   árboles por chunk junto a claros y senderos, siempre con una casilla vecina alcanzable desde
##   el hub. Se eligen entre los TREE ya generados, así que no cambian por dónde se anda.

const REGION_DIR: String = "res://data/world/regions/"
## Radio del claro central (punto de aparición seguro).
const CENTER_CLEARING_RADIUS: int = 4
## Las entradas de cada borde quedan al menos a esta distancia de las esquinas.
const GATE_MARGIN: int = 6
## Probabilidad de que un sendero se desvíe en cada paso.
const PATH_WIGGLE: float = 0.3
## Camino principal: ancho, desvío (menos zigzag que un sendero) y tramo recto desde la puerta.
const ROAD_WIDTH: int = 2
const ROAD_WIGGLE: float = 0.08
const ROAD_STRAIGHT: int = 6
## Frecuencias del ruido (más alto = manchas más pequeñas).
const HEIGHT_FREQUENCY: float = 0.015
const OUTCROP_FREQUENCY: float = 0.045
const FOREST_FREQUENCY: float = 0.06
const CORRIDOR_FREQUENCY: float = 0.03
const MEANDER_FREQUENCY: float = 0.004
const STREAM_FREQUENCY: float = 0.012

# Sales para separar los distintos usos del hash.
const SALT_HEIGHT: int = 1
const SALT_FOREST: int = 2
const SALT_LOCAL: int = 3
const SALT_GATE: int = 4
const SALT_RIVER: int = 6
const SALT_STREAM: int = 7
const SALT_OUTCROP: int = 11
const SALT_CORRIDOR: int = 12
const SALT_TREE: int = 13
const SALT_FORD: int = 14
const SALT_REFUGE: int = 18
const SALT_FRUIT: int = 31

## Valores por defecto de los parámetros de región (data/world/regions/*.json).
const DEFAULT_SIZE_CHUNKS: Array = [8, 8]
const DEFAULT_RELIEF: Dictionary = {
	"north_base": 0.0, "south_base": 0.0,
	"north_roughness": 0.5, "south_roughness": 0.5,
	"mountain_level": 0.5, "mountain_ramp": 0.3,
	"outcrop_threshold": 0.35, "rocky_level": 0.3,
}
const DEFAULT_FOREST: Dictionary = {
	"density": 0.6, "fill": 0.7, "corridor_width": 0.07, "scatter": 0.05,
}
const DEFAULT_RIVERS: Dictionary = {
	"main_center": 0.5, "main_center_jitter": 0.15, "main_meander": 0.15,
	"main_width_north": 2.0, "main_width_south": 4.0, "navigable_from": 2.0,
	"ford_spacing": 48, "ford_length": 2,
	"stream_width": 0.0, "stream_until": 0.0,
	"riverside_clearing_from": 2.0, "riverside_band": 3.0,
}
## Frutales (bosques-y-relacion.md, sección Fruto). `bosque_state`: estado provisional de todos los
## Bosques con Nujio hasta que existan los estados por Bosque; `states`: estados que dan fruto;
## `per_chunk`: [mín, máx] frutales por chunk; `min_spacing`: distancia mínima (Chebyshev) entre
## dos frutales del mismo chunk.
const DEFAULT_FRUIT: Dictionary = {
	"bosque_state": "sano", "states": ["sano", "necesita_ayuda"],
	"per_chunk": [3, 6], "min_spacing": 5,
}
## Casillas libres de frutales alrededor de la plaza de la villa (además de la plaza).
const FRUIT_PLAZA_MARGIN: int = 2


static func generate(seed_value: int, coord: Vector2i, region: Dictionary = {}, bosques: BosqueMap = null) -> ChunkData:
	var size: int = ChunkData.SIZE
	var chunk := ChunkData.new()
	chunk.seed_value = seed_value
	chunk.coord = coord
	chunk.tiles.resize(size * size)

	var terrain := Terrain.new(seed_value, region)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_ints([seed_value, coord.x, coord.y, SALT_LOCAL])

	var origin: Vector2i = coord * size
	for y: int in size:
		for x: int in size:
			chunk.tiles[y * size + x] = terrain.tile_at(origin.x + x, origin.y + y)

	# Rasgos del Bosque: Nujio, villa y letreros.
	var bosque_id: int = bosques.bosque_at(coord) if bosques != null else -1
	var has_nujio: bool = bosque_id >= 0 and bosques.nujio_chunk[bosque_id] == coord
	var nujio_n: int = bosques.nujio_size[bosque_id] if has_nujio else 0
	var villa: bool = has_nujio and bosques.has_villa[bosque_id]
	var center: Vector2i = ChunkData.center()
	# El Nujio va en el centro del chunk; el hub queda justo al sur, en el claro o la plaza.
	if has_nujio:
		chunk.has_villa = villa
		chunk.hub = center + Vector2i(0, nujio_n / 2 + 1)

	var roads: Array[Vector2i] = []
	if bosques != null:
		roads = bosques.road_sides(coord)
	for side: Vector2i in ChunkData.SIDES:
		if roads.has(side):
			continue
		var gate: Vector2i = ChunkData.border_cell(side, gate_index(seed_value, coord, side))
		_carve_path(chunk, gate, -side, chunk.hub, rng)
	for side: Vector2i in ChunkData.SIDES:
		if not roads.has(side):
			continue
		var gate: Vector2i = ChunkData.border_cell(side, gate_index(seed_value, coord, side))
		_carve_path(chunk, gate, -side, chunk.hub, rng, ROAD_WIDTH, ChunkData.Tile.ROAD, ROAD_WIGGLE, ROAD_STRAIGHT)

	if villa:
		_build_villa(chunk, center, nujio_n, rng)
	elif has_nujio:
		_carve_clearing(chunk, center, nujio_n / 2 + 3, ChunkData.Tile.CLEARING)
		_place_nujio(chunk, center, nujio_n)
	else:
		_carve_clearing(chunk, center, CENTER_CLEARING_RADIUS, ChunkData.Tile.CLEARING)

	if bosque_id >= 0 and not villa and bosques.has_villa[bosque_id]:
		var to_villa: Vector2i = bosques.nujio_chunk[bosque_id] - coord
		var side: Vector2i = _side_towards(to_villa)
		var gate: Vector2i = ChunkData.border_cell(side, gate_index(seed_value, coord, side))
		chunk.set_tile(gate - side * 3, ChunkData.Tile.SIGN)

	if not roads.is_empty():
		var home_side: Vector2i = bosques.road_home_side(coord)
		if home_side != Vector2i.ZERO and (roads.size() >= 3 or posmod(coord.x + coord.y, 2) == 0):
			_place_home_sign(chunk, seed_value, coord, home_side)

	if bosques != null and bosques.has_refuge(coord):
		_place_refuge(chunk, seed_value, coord, nujio_n, villa)

	# Lo último: los frutales solo sustituyen árboles, ya con senderos, villa y refugio puestos.
	if bosque_gives_fruit(region, bosques, bosque_id):
		var plaza_radius: int = nujio_n / 2 + 3 + FRUIT_PLAZA_MARGIN if villa else -1
		_place_fruit_trees(chunk, seed_value, coord, fruit_params(region), center, plaza_radius)
	return chunk


## Parámetros de frutales de la región, con los valores por defecto.
static func fruit_params(region: Dictionary) -> Dictionary:
	return DEFAULT_FRUIT.merged(region.get("fruit", {}), true)


## Estado del Bosque para los frutales. Provisional: todos los Bosques con Nujio tienen el
## `bosque_state` de la región (hoy "sano"); los estados por Bosque llegan en otro PR.
static func bosque_state(region: Dictionary, bosques: BosqueMap, bosque_id: int) -> String:
	if bosques == null or bosque_id < 0:
		return ""
	return str(fruit_params(region).bosque_state)


## El Bosque da fruto según su estado (sano y necesita_ayuda, bosques-y-relacion.md).
static func bosque_gives_fruit(region: Dictionary, bosques: BosqueMap, bosque_id: int) -> bool:
	var state: String = bosque_state(region, bosques, bosque_id)
	return state != "" and (fruit_params(region).states as Array).has(state)


## Convierte en FRUIT_TREE entre per_chunk[0] y per_chunk[1] árboles (número por hash del chunk).
## Candidatos: TREE que no están en el borde, fuera de la plaza (radio `plaza_radius` desde
## `center`, -1 = sin villa) y con una casilla vecina transitable y alcanzable desde el hub (se
## toma el fruto desde ahí). Primero los que dan a un claro o un sendero; separados entre sí al
## menos min_spacing. Un TREE ya bloquea, así que el cambio no corta ningún paso.
static func _place_fruit_trees(chunk: ChunkData, seed_value: int, coord: Vector2i, params: Dictionary,
		center: Vector2i, plaza_radius: int) -> void:
	var size: int = ChunkData.SIZE
	var range_n: Array = params.per_chunk
	var lo: int = int(range_n[0])
	var hi: int = maxi(lo, int(range_n[1]))
	var spacing: int = int(params.min_spacing)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_ints([seed_value, coord.x, coord.y, SALT_FRUIT])
	var wanted: int = rng.randi_range(lo, hi)
	if wanted <= 0:
		return
	var reach: PackedByteArray = chunk.reachable_from_hub()
	var near_open: Array[Vector2i] = []
	var others: Array[Vector2i] = []
	for y: int in range(1, size - 1):
		for x: int in range(1, size - 1):
			var c := Vector2i(x, y)
			if chunk.get_tile(c) != ChunkData.Tile.TREE:
				continue
			if plaza_radius >= 0 and (c - center).length_squared() <= plaza_radius * plaza_radius:
				continue
			var opens: bool = false
			var by_clearing: bool = false
			for d: Vector2i in ChunkData.SIDES:
				var n: Vector2i = c + d
				if chunk.is_walkable(n) and reach[n.y * size + n.x] == 1:
					opens = true
					var t: int = chunk.get_tile(n)
					by_clearing = by_clearing or t == ChunkData.Tile.CLEARING or t == ChunkData.Tile.PATH
			if by_clearing:
				near_open.append(c)
			elif opens:
				others.append(c)
	_shuffle(near_open, rng)
	_shuffle(others, rng)
	var picked: Array[Vector2i] = []
	for pool: Array[Vector2i] in [near_open, others]:
		for c: Vector2i in pool:
			if picked.size() >= wanted:
				break
			var far: bool = true
			for p: Vector2i in picked:
				if maxi(absi(p.x - c.x), absi(p.y - c.y)) < spacing:
					far = false
					break
			if far:
				picked.append(c)
	for c: Vector2i in picked:
		chunk.set_tile(c, ChunkData.Tile.FRUIT_TREE)
	chunk.fruit_trees = picked


## Fisher-Yates con el RNG local (Array.shuffle usaría el RNG global).
static func _shuffle(cells: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i: int in range(cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp


## Letrero hacia la villa natal junto al tramo recto del camino que lleva a casa (lado `side`).
## Un chunk de cada dos del camino (paridad de x + y: alterna en chunks contiguos) y los cruces.
static func _place_home_sign(chunk: ChunkData, seed_value: int, coord: Vector2i, side: Vector2i) -> void:
	var gate: Vector2i = ChunkData.border_cell(side, gate_index(seed_value, coord, side))
	var lateral := Vector2i(1, 0) if side.y != 0 else Vector2i(0, 1)
	# Si no hay sitio a los lados, el letrero va sobre el propio camino (también se camina).
	var cell: Vector2i = gate - side * 4
	var candidates: Array[Vector2i] = []
	for depth: int in [4, 3, 5, 2]:
		for lane: int in [-1, ROAD_WIDTH]:
			candidates.append(Vector2i(depth, lane))
	for k: Vector2i in candidates:
		var c: Vector2i = gate - side * k.x + lateral * k.y
		var beside: Vector2i = gate - side * k.x + lateral * clampi(k.y, 0, ROAD_WIDTH - 1)
		if ChunkData.in_bounds(c) and _is_free_ground(chunk.get_tile(c)) and chunk.is_walkable(beside):
			cell = c
			break
	chunk.set_tile(cell, ChunkData.Tile.SIGN)
	chunk.home_sign = cell
	chunk.home_direction = side


## Distancia (Chebyshev) en casillas de un refugio al Nujio para contar como "junto al Nujio"
## (bosques-y-relacion.md: refugio a <= 3 casillas del Nujio).
const REFUGE_NUJIO_REACH: int = 3


## Refugio (árbol hueco o cueva) del chunk. Nunca falla: busca por niveles de preferencia y, si
## un nivel no tiene sitio, pasa al siguiente. Toda casilla candidata es suelo natural (o, en el
## último nivel, un sendero) con una vecina transitable y alcanzable desde el hub, así que el
## refugio (que no bloquea) siempre se alcanza a pie. Nunca en la plaza, el camino ni el agua.
## Niveles:
## 0. Chunk de Nujio sin villa: en el claro, a <= REFUGE_NUJIO_REACH casillas del Nujio.
##    Resto: un árbol o una roca (árbol hueco o cueva) junto a un camino, sendero o claro, lejos
##    del hub.
## 1. Un árbol o una roca con acceso, lejos del hub.
## 2. Cualquier suelo natural con acceso (sin la casilla del hub).
## 3. Cualquier sendero alcanzable (sin la casilla del hub).
## Las rocas se dibujan como cueva y los árboles como árbol hueco (PlaceholderTileset).
static func _place_refuge(chunk: ChunkData, seed_value: int, coord: Vector2i, nujio_n: int, villa: bool) -> Vector2i:
	var size: int = ChunkData.SIZE
	var reach: PackedByteArray = chunk.reachable_from_hub()
	var keep_away: int = CENTER_CLEARING_RADIUS + 4
	var near_nujio_zone: bool = nujio_n > 0 and not villa
	var tiers: Array = [[], [], [], []]
	for y: int in range(2, size - 2):
		for x: int in range(2, size - 2):
			var c := Vector2i(x, y)
			if c == chunk.hub:
				continue
			var tile: int = chunk.get_tile(c)
			var natural: bool = _is_free_ground(tile)
			if not natural and tile != ChunkData.Tile.PATH:
				continue
			var access: bool = false
			var by_open: bool = false
			var by_sign: bool = false
			for d: Vector2i in ChunkData.SIDES:
				var n: Vector2i = c + d
				var t: int = chunk.get_tile(n)
				by_sign = by_sign or t == ChunkData.Tile.SIGN
				if chunk.is_walkable(n) and reach[n.y * size + n.x] == 1:
					access = true
					by_open = by_open or t == ChunkData.Tile.ROAD or t == ChunkData.Tile.PATH or t == ChunkData.Tile.CLEARING
			if by_sign or not (access or reach[y * size + x] == 1):
				continue
			if not natural:
				(tiers[3] as Array).append(c)
				continue
			if not access:
				continue
			var solid: bool = tile == ChunkData.Tile.TREE or tile == ChunkData.Tile.CLIFF or tile == ChunkData.Tile.ROCKY
			var far: bool = absi(c.x - chunk.hub.x) + absi(c.y - chunk.hub.y) > keep_away
			if near_nujio_zone:
				if tile == ChunkData.Tile.CLEARING and _nujio_gap(chunk.nujio_rect, c) <= REFUGE_NUJIO_REACH:
					(tiers[0] as Array).append(c)
					continue
			elif solid and far and by_open:
				(tiers[0] as Array).append(c)
				continue
			(tiers[1 if solid and far else 2] as Array).append(c)
	for pool: Array in tiers:
		if pool.is_empty():
			continue
		var pick: Vector2i = pool[hash_ints([seed_value, coord.x, coord.y, SALT_REFUGE]) % pool.size()]
		chunk.set_tile(pick, ChunkData.Tile.REFUGE)
		return pick
	push_error("Chunk %s sin sitio para su refugio" % coord)
	return Vector2i(-1, -1)


## Casillas (Chebyshev) entre `cell` y el rectángulo del Nujio (0 = dentro).
static func _nujio_gap(rect: Rect2i, cell: Vector2i) -> int:
	var dx: int = maxi(0, maxi(rect.position.x - cell.x, cell.x - (rect.end.x - 1)))
	var dy: int = maxi(0, maxi(rect.position.y - cell.y, cell.y - (rect.end.y - 1)))
	return maxi(dx, dy)


## Suelo natural donde se puede poner un letrero o un refugio (no agua, ni camino, ni villa).
static func _is_free_ground(tile: int) -> bool:
	return tile == ChunkData.Tile.TREE or tile == ChunkData.Tile.GRASS or tile == ChunkData.Tile.CLEARING 		or tile == ChunkData.Tile.ROCKY or tile == ChunkData.Tile.CLIFF


## Tamaño de la región en chunks.
static func region_size(region: Dictionary) -> Vector2i:
	var s: Array = region.get("size_chunks", DEFAULT_SIZE_CHUNKS)
	return Vector2i(int(s[0]), int(s[1]))


## Chunk donde empieza la partida en la región.
static func region_start_chunk(region: Dictionary) -> Vector2i:
	var size: Vector2i = region_size(region)
	var s: Array = region.get("start_chunk", [size.x / 2, size.y / 2])
	return Vector2i(int(s[0]), int(s[1]))


## Posición (fila o columna) de la entrada del borde `side`. Un borde lo comparten dos chunks
## y se identifica igual desde ambos, así que los dos senderos coinciden.
static func gate_index(seed_value: int, coord: Vector2i, side: Vector2i) -> int:
	var edge := Vector3i(coord.x, coord.y, 0)
	if side == Vector2i.RIGHT:
		edge = Vector3i(coord.x + 1, coord.y, 0)
	elif side == Vector2i.UP:
		edge = Vector3i(coord.x, coord.y, 1)
	elif side == Vector2i.DOWN:
		edge = Vector3i(coord.x, coord.y + 1, 1)
	var span: int = ChunkData.SIZE - 2 * GATE_MARGIN
	return GATE_MARGIN + hash_ints([seed_value, edge.x, edge.y, edge.z, SALT_GATE]) % span


## Dirección en palabras (norte arriba) de un desplazamiento entre chunks.
static func direction_name(delta: Vector2i) -> String:
	if delta == Vector2i.ZERO:
		return "aquí"
	var names: Array[String] = ["este", "sureste", "sur", "suroeste", "oeste", "noroeste", "norte", "noreste"]
	return names[direction_index(delta)]


## Octante de un desplazamiento: 0 = este y sentido horario (y crece hacia el sur).
static func direction_index(delta: Vector2i) -> int:
	return posmod(roundi(atan2(float(delta.y), float(delta.x)) / (PI / 4.0)), 8)


static func load_region(region_id: StringName) -> Dictionary:
	var path: String = REGION_DIR + String(region_id) + ".json"
	if not FileAccess.file_exists(path):
		push_warning("Región sin datos: %s" % path)
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


## Hash entero estable (no depende de la plataforma ni del orden de ejecución). Devuelve >= 0.
static func hash_ints(values: Array) -> int:
	var h: int = 0x811C9DC5
	for v: Variant in values:
		var n: int = int(v)
		h = _mix32((h ^ _mix32(n ^ (n >> 32))) + 0x9E3779B9)
	return h


static func _mix32(value: int) -> int:
	var x: int = value & 0xFFFFFFFF
	x = (((x >> 16) ^ x) * 0x45D9F3B) & 0xFFFFFFFF
	x = (((x >> 16) ^ x) * 0x45D9F3B) & 0xFFFFFFFF
	return (x >> 16) ^ x


static func _make_noise(noise_seed: int, frequency: float, octaves: int, fractal: int = FastNoiseLite.FRACTAL_FBM) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed & 0x7FFFFFFF
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = fractal if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	noise.fractal_octaves = octaves
	return noise


static func _side_towards(delta: Vector2i) -> Vector2i:
	if absi(delta.x) >= absi(delta.y):
		return Vector2i(signi(delta.x), 0)
	return Vector2i(0, signi(delta.y))


## Sendero serpenteante desde `from` hasta `to`. Atraviesa árboles y riscos y cruza los ríos con
## puentes, así que deja `from` conectado con `to`. `width` x `width` casillas por paso (hacia +x
## y +y, así la puerta ocupa las mismas casillas del borde vista desde los dos chunks).
static func _carve_path(chunk: ChunkData, from: Vector2i, inward: Vector2i, to: Vector2i, rng: RandomNumberGenerator,
		width: int = 1, tile: int = ChunkData.Tile.PATH, wiggle: float = PATH_WIGGLE, straight: int = 3) -> void:
	var size: int = ChunkData.SIZE
	var cell: Vector2i = from
	# Los primeros pasos van rectos hacia dentro para que la entrada se vea clara.
	for _i: int in straight:
		_carve_cell(chunk, cell, tile, width)
		cell += inward
	var steps: int = 0
	while cell != to:
		_carve_cell(chunk, cell, tile, width)
		steps += 1
		var diff: Vector2i = to - cell
		var step: Vector2i
		if steps < 200 and rng.randf() < wiggle:
			step = ChunkData.SIDES[rng.randi() % ChunkData.SIDES.size()]
		elif absi(diff.x) >= absi(diff.y):
			step = Vector2i(signi(diff.x), 0)
		else:
			step = Vector2i(0, signi(diff.y))
		var next: Vector2i = cell + step
		if next.x < 1 or next.y < 1 or next.x > size - 2 or next.y > size - 2:
			continue
		cell = next
	_carve_cell(chunk, to, tile, width)


## Talla un bloque de `width` x `width` desde `cell`: puente sobre los ríos, respeta los vados y
## un sendero nunca pisa un camino principal.
static func _carve_cell(chunk: ChunkData, cell: Vector2i, tile: int = ChunkData.Tile.PATH, width: int = 1) -> void:
	for dy: int in width:
		for dx: int in width:
			var c: Vector2i = cell + Vector2i(dx, dy)
			if not ChunkData.in_bounds(c):
				continue
			var current: int = chunk.get_tile(c)
			if ChunkData.is_river(current) or current == ChunkData.Tile.BRIDGE:
				chunk.set_tile(c, ChunkData.Tile.BRIDGE)
			elif current != ChunkData.Tile.FORD and not (current == ChunkData.Tile.ROAD and tile == ChunkData.Tile.PATH):
				chunk.set_tile(c, tile)


static func _carve_clearing(chunk: ChunkData, center: Vector2i, radius: int, tile: int) -> void:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var c: Vector2i = center + Vector2i(dx, dy)
			if dx * dx + dy * dy <= radius * radius + radius and ChunkData.in_bounds(c):
				chunk.set_tile(c, tile)


static func _place_nujio(chunk: ChunkData, center: Vector2i, n: int) -> void:
	chunk.nujio_rect = Rect2i(center - Vector2i(n / 2, n / 2), Vector2i(n, n))
	for y: int in range(chunk.nujio_rect.position.y, chunk.nujio_rect.end.y):
		for x: int in range(chunk.nujio_rect.position.x, chunk.nujio_rect.end.x):
			chunk.set_tile(Vector2i(x, y), ChunkData.Tile.NUJIO)


## Villa: claro amplio, plaza abierta alrededor del Nujio y edificios pequeños (2x2 o 3x2)
## repartidos en anillo, con al menos una casilla libre entre ellos.
static func _build_villa(chunk: ChunkData, center: Vector2i, n: int, rng: RandomNumberGenerator) -> void:
	var plaza_radius: int = n / 2 + 3
	_carve_clearing(chunk, center, plaza_radius + 9, ChunkData.Tile.CLEARING)
	_carve_clearing(chunk, center, plaza_radius, ChunkData.Tile.PLAZA)
	var count: int = rng.randi_range(4, 7)
	var start_angle: float = rng.randf() * TAU
	for k: int in count:
		var angle: float = start_angle + TAU * k / count + rng.randf_range(-0.2, 0.2)
		var size := Vector2i(3, 2) if rng.randf() < 0.5 else Vector2i(2, 2)
		var at: Vector2i = center + Vector2i(roundi(cos(angle) * (plaza_radius + 3)), roundi(sin(angle) * (plaza_radius + 3)))
		var rect := Rect2i(at - size / 2, size)
		if _area_is(chunk, rect.grow(1), ChunkData.Tile.CLEARING):
			for y: int in range(rect.position.y, rect.end.y):
				for x: int in range(rect.position.x, rect.end.x):
					chunk.set_tile(Vector2i(x, y), ChunkData.Tile.BUILDING)
	_place_nujio(chunk, center, n)


static func _area_is(chunk: ChunkData, rect: Rect2i, tile: int) -> bool:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if not ChunkData.in_bounds(c) or chunk.get_tile(c) != tile:
				return false
	return true


## Terreno base en coordenadas de mundo (antes de tallar senderos, claros, villa y Nujio).
class Terrain:
	var seed_value: int
	var height: FastNoiseLite
	var outcrop: FastNoiseLite
	var forest: FastNoiseLite
	var corridor: FastNoiseLite
	var meander: FastNoiseLite
	var stream: FastNoiseLite
	var region_size_tiles: Vector2
	var relief: Dictionary
	var forest_params: Dictionary
	var rivers: Dictionary
	var tree_threshold: float
	var river_center_x: float
	var tree_salt: int
	# Caché por fila (tile_at se llama fila a fila).
	var _row: int = -999_999_999
	var _row_span: Vector2i
	var _row_axis: float
	var _row_width: float
	var _row_ford: bool

	func _init(seed_v: int, region: Dictionary) -> void:
		seed_value = seed_v
		tree_salt = ChunkGenerator.hash_ints([seed_v, SALT_TREE])
		height = ChunkGenerator._make_noise(ChunkGenerator.hash_ints([seed_v, SALT_HEIGHT]), HEIGHT_FREQUENCY, 3)
		outcrop = ChunkGenerator._make_noise(ChunkGenerator.hash_ints([seed_v, SALT_OUTCROP]), OUTCROP_FREQUENCY, 3, FastNoiseLite.FRACTAL_RIDGED)
		forest = ChunkGenerator._make_noise(ChunkGenerator.hash_ints([seed_v, SALT_FOREST]), FOREST_FREQUENCY, 2)
		corridor = ChunkGenerator._make_noise(ChunkGenerator.hash_ints([seed_v, SALT_CORRIDOR]), CORRIDOR_FREQUENCY, 1)
		meander = ChunkGenerator._make_noise(ChunkGenerator.hash_ints([seed_v, SALT_RIVER]), MEANDER_FREQUENCY, 2)
		stream = ChunkGenerator._make_noise(ChunkGenerator.hash_ints([seed_v, SALT_STREAM]), STREAM_FREQUENCY, 1)
		region_size_tiles = Vector2(ChunkGenerator.region_size(region) * ChunkData.SIZE)
		relief = DEFAULT_RELIEF.merged(region.get("relief", {}), true)
		rivers = DEFAULT_RIVERS.merged(region.get("rivers", {}), true)
		forest_params = DEFAULT_FOREST.merged(region.get("forest", {}), true)
		tree_threshold = 0.3 - float(forest_params.density) * 0.45
		var jitter: float = float(ChunkGenerator.hash_ints([seed_v, SALT_RIVER]) % 1000) / 1000.0 * 2.0 - 1.0
		river_center_x = region_size_tiles.x * (float(rivers.main_center) + jitter * float(rivers.main_center_jitter))

	## 0 en el borde norte de la región, 1 en el sur.
	func north_south(wy: float) -> float:
		return clampf(wy / region_size_tiles.y, 0.0, 1.0)

	func elevation(wx: float, wy: float) -> float:
		var t: float = north_south(wy)
		var base: float = lerpf(float(relief.north_base), float(relief.south_base), t)
		var rough: float = lerpf(float(relief.north_roughness), float(relief.south_roughness), t)
		return base + rough * height.get_noise_2d(wx, wy)

	## X (en casillas de mundo) del eje del río principal a la altura wy.
	func river_x(wy: float) -> float:
		return river_center_x + meander.get_noise_1d(wy) * region_size_tiles.x * float(rivers.main_meander)

	func river_width(wy: float) -> float:
		return lerpf(float(rivers.main_width_north), float(rivers.main_width_south), north_south(wy))

	## Columnas [desde, hasta] del río principal en la fila wy. Une el eje de esta fila con el de la
	## siguiente, así filas consecutivas siempre se tocan: el río no se corta nunca.
	func river_span(wy: int) -> Vector2i:
		var a: float = river_x(wy)
		var b: float = river_x(wy + 1)
		var half: float = river_width(wy) * 0.5
		return Vector2i(floori(minf(a, b) - half + 0.5), floori(maxf(a, b) + half - 0.5))

	func is_ford_row(wy: int) -> bool:
		var spacing: int = int(rivers.ford_spacing)
		var length: int = int(rivers.ford_length)
		var segment: int = floori(float(wy) / spacing)
		var start: int = segment * spacing + ChunkGenerator.hash_ints([seed_value, segment, SALT_FORD]) % (spacing - length)
		return wy >= start and wy < start + length

	func tile_at(x: int, y: int) -> int:
		var wx: float = x
		var wy: float = y
		var t: float = north_south(wy)
		if y != _row:
			_row = y
			_row_span = river_span(y)
			_row_axis = river_x(wy)
			_row_width = river_width(wy)
			_row_ford = is_ford_row(y)
		# Río principal (continuo) con vados.
		if x >= _row_span.x and x <= _row_span.y:
			if _row_ford:
				return ChunkData.Tile.FORD
			return ChunkData.Tile.RIVER_NAVIGABLE if t >= float(rivers.navigable_from) else ChunkData.Tile.RIVER_NARROW
		# Arroyos de montaña: ancho constante, solo al norte de stream_until (terminan en seco).
		if t < float(rivers.stream_until) and absf(stream.get_noise_2d(wx, wy)) < float(rivers.stream_width):
			return ChunkData.Tile.RIVER_NARROW
		# Montañas: afloramientos de roca irregulares (ruido de crestas) donde el relieve es alto.
		var mountain: float = clampf((elevation(wx, wy) - float(relief.mountain_level)) / float(relief.mountain_ramp), 0.0, 1.0)
		if mountain > 0.0:
			var o: float = outcrop.get_noise_2d(wx, wy)
			if o > float(relief.outcrop_threshold) + (1.0 - mountain) * 0.6:
				return ChunkData.Tile.CLIFF
		# Claros ribereños al sur.
		var river_distance: float = absf(wx - _row_axis) - _row_width * 0.5
		if t >= float(rivers.riverside_clearing_from) and river_distance < float(rivers.riverside_band):
			return ChunkData.Tile.CLEARING
		var rocky: bool = mountain > float(relief.rocky_level)
		# Árboles: masas por ruido con huecos, pasillos naturales y árboles sueltos.
		var in_corridor: bool = absf(corridor.get_noise_2d(wx, wy)) < float(forest_params.corridor_width)
		var cell_roll: float = float(ChunkGenerator._mix32(tree_salt ^ (x * 73856093) ^ (y * 19349663)) % 10000) / 10000.0
		var f: float = forest.get_noise_2d(wx, wy)
		if not in_corridor:
			var fill: float = float(forest_params.fill) * (0.4 if rocky else 1.0)
			if f > tree_threshold and cell_roll < fill:
				return ChunkData.Tile.TREE
			if cell_roll < float(forest_params.scatter):
				return ChunkData.Tile.TREE
		if rocky:
			return ChunkData.Tile.ROCKY
		if f < tree_threshold - 0.35:
			return ChunkData.Tile.CLEARING
		return ChunkData.Tile.GRASS
