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

const REGION_DIR: String = "res://data/world/regions/"
## Radio del claro central (punto de aparición seguro).
const CENTER_CLEARING_RADIUS: int = 4
## Las entradas de cada borde quedan al menos a esta distancia de las esquinas.
const GATE_MARGIN: int = 6
## Probabilidad de que un sendero se desvíe en cada paso.
const PATH_WIGGLE: float = 0.3
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

	for side: Vector2i in ChunkData.SIDES:
		var gate: Vector2i = ChunkData.border_cell(side, gate_index(seed_value, coord, side))
		_carve_path(chunk, gate, -side, chunk.hub, rng)

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
	return chunk


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
## puentes, así que deja `from` conectado con `to`.
static func _carve_path(chunk: ChunkData, from: Vector2i, inward: Vector2i, to: Vector2i, rng: RandomNumberGenerator) -> void:
	var size: int = ChunkData.SIZE
	var cell: Vector2i = from
	# Los primeros pasos van rectos hacia dentro para que la entrada se vea clara.
	for _i: int in 3:
		_carve_cell(chunk, cell)
		cell += inward
	var steps: int = 0
	while cell != to:
		_carve_cell(chunk, cell)
		steps += 1
		var diff: Vector2i = to - cell
		var step: Vector2i
		if steps < 200 and rng.randf() < PATH_WIGGLE:
			step = ChunkData.SIDES[rng.randi() % ChunkData.SIDES.size()]
		elif absi(diff.x) >= absi(diff.y):
			step = Vector2i(signi(diff.x), 0)
		else:
			step = Vector2i(0, signi(diff.y))
		var next: Vector2i = cell + step
		if next.x < 1 or next.y < 1 or next.x > size - 2 or next.y > size - 2:
			continue
		cell = next
	_carve_cell(chunk, to)


static func _carve_cell(chunk: ChunkData, cell: Vector2i) -> void:
	var tile: int = chunk.get_tile(cell)
	if ChunkData.is_river(tile) or tile == ChunkData.Tile.BRIDGE:
		chunk.set_tile(cell, ChunkData.Tile.BRIDGE)
	elif tile != ChunkData.Tile.FORD:
		chunk.set_tile(cell, ChunkData.Tile.PATH)


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
