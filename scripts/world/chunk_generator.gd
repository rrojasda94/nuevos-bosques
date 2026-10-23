class_name ChunkGenerator
extends RefCounted
## Genera un ChunkData determinista a partir de (seed, coordenadas del chunk en la región) y los
## parámetros de la región. ADR 0006:
## - Todo el ruido se muestrea en coordenadas de mundo: relieve, ríos y bosque continúan entre
##   chunks vecinos.
## - El relieve sigue un gradiente norte-sur definido por la región (más agreste al norte).
##   Donde la pendiente es fuerte aparecen riscos (bloquean).
## - Los ríos son curvas de nivel de un ruido de baja frecuencia: líneas continuas, no charcos.
## - La aleatoriedad local sale de un RNG propio sembrado con hash(seed, x, y). No se usa
##   GameState.rng ni randi()/randf() globales.
## - Cada borde tiene una entrada (sendero) en la misma posición vista desde los dos chunks.

const REGION_DIR: String = "res://data/world/regions/"
## Radio del claro central (punto de aparición seguro).
const CENTER_CLEARING_RADIUS: int = 4
## Las entradas de cada borde quedan al menos a esta distancia de las esquinas.
const GATE_MARGIN: int = 6
## Probabilidad de árbol suelto en la hierba.
const SCATTER_TREE_CHANCE: float = 0.08
## Probabilidad de que un sendero se desvíe en cada paso.
const PATH_WIGGLE: float = 0.3
## Frecuencias del ruido (más alto = manchas más pequeñas).
const HEIGHT_FREQUENCY: float = 0.02
const FOREST_FREQUENCY: float = 0.07
const RIVER_FREQUENCY: float = 0.0035
## El ruido del río principal se estira en Y para que corra de norte a sur.
const RIVER_STRETCH_Y: float = 0.35
const STREAM_FREQUENCY: float = 0.012

# Sales para separar los distintos usos del hash.
const SALT_HEIGHT: int = 1
const SALT_FOREST: int = 2
const SALT_LOCAL: int = 3
const SALT_GATE: int = 4
const SALT_RIVER: int = 6
const SALT_STREAM: int = 7

## Valores por defecto de los parámetros de región (data/world/regions/*.json).
const DEFAULT_SIZE_CHUNKS: Array = [8, 8]
const DEFAULT_RELIEF: Dictionary = {
	"north_base": 0.0, "south_base": 0.0,
	"north_roughness": 0.6, "south_roughness": 0.6,
	"cliff_gradient": 0.012, "steep_gradient": 0.05, "terrace_step": 0.15, "rocky_level": 0.55,
}
const DEFAULT_RIVERS: Dictionary = {
	"main_width_north": 0.02, "main_width_south": 0.02, "navigable_from": 2.0,
	"stream_width": 0.0, "stream_until": 0.0,
	"riverside_clearing_from": 2.0, "riverside_clearing_factor": 2.5,
}


static func generate(seed_value: int, coord: Vector2i, region: Dictionary = {}) -> ChunkData:
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
			chunk.tiles[y * size + x] = terrain.tile_at(origin.x + x, origin.y + y, rng)

	var center: Vector2i = ChunkData.center()
	for side: Vector2i in ChunkData.SIDES:
		var gate: Vector2i = ChunkData.border_cell(side, gate_index(seed_value, coord, side))
		_carve_path(chunk, gate, -side, center, rng)
	_carve_clearing(chunk, center, CENTER_CLEARING_RADIUS)
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


static func _make_noise(noise_seed: int, frequency: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed & 0x7FFFFFFF
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	noise.fractal_octaves = octaves
	return noise


## Sendero serpenteante desde una entrada del borde hasta el centro. Garantiza que cada entrada
## está conectada con el claro central: atraviesa riscos y cruza los ríos con puentes.
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
	else:
		chunk.set_tile(cell, ChunkData.Tile.PATH)


static func _carve_clearing(chunk: ChunkData, center: Vector2i, radius: int) -> void:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius + radius:
				chunk.set_tile(center + Vector2i(dx, dy), ChunkData.Tile.CLEARING)


## Terreno base en coordenadas de mundo (antes de tallar senderos y el claro central).
class Terrain:
	var height: FastNoiseLite
	var forest: FastNoiseLite
	var river: FastNoiseLite
	var stream: FastNoiseLite
	var region_height_tiles: float
	var relief: Dictionary
	var rivers: Dictionary
	var tree_threshold: float
	var clearing_threshold: float

	func _init(seed_value: int, region: Dictionary) -> void:
		height = ChunkGenerator._make_noise(ChunkGenerator.hash_ints([seed_value, SALT_HEIGHT]), HEIGHT_FREQUENCY, 3)
		forest = ChunkGenerator._make_noise(ChunkGenerator.hash_ints([seed_value, SALT_FOREST]), FOREST_FREQUENCY, 2)
		river = ChunkGenerator._make_noise(ChunkGenerator.hash_ints([seed_value, SALT_RIVER]), RIVER_FREQUENCY, 1)
		stream = ChunkGenerator._make_noise(ChunkGenerator.hash_ints([seed_value, SALT_STREAM]), STREAM_FREQUENCY, 1)
		region_height_tiles = float(ChunkGenerator.region_size(region).y * ChunkData.SIZE)
		relief = DEFAULT_RELIEF.merged(region.get("relief", {}), true)
		rivers = DEFAULT_RIVERS.merged(region.get("rivers", {}), true)
		var forest_density: float = float(region.get("forest_density", 0.6))
		tree_threshold = 0.3 - forest_density * 0.45
		clearing_threshold = tree_threshold - 0.35

	## 0 en el borde norte de la región, 1 en el sur.
	func north_south(wy: float) -> float:
		return clampf(wy / region_height_tiles, 0.0, 1.0)

	func elevation(wx: float, wy: float) -> float:
		var t: float = north_south(wy)
		var base: float = lerpf(float(relief.north_base), float(relief.south_base), t)
		var rough: float = lerpf(float(relief.north_roughness), float(relief.south_roughness), t)
		return base + rough * height.get_noise_2d(wx, wy)

	func tile_at(x: int, y: int, rng: RandomNumberGenerator) -> int:
		var wx: float = x
		var wy: float = y
		var t: float = north_south(wy)
		# Ríos: |ruido| cerca de 0 dibuja líneas continuas.
		var main: float = absf(river.get_noise_2d(wx, wy * RIVER_STRETCH_Y))
		var main_width: float = lerpf(float(rivers.main_width_north), float(rivers.main_width_south), t)
		if main < main_width:
			return ChunkData.Tile.RIVER_NAVIGABLE if t >= float(rivers.navigable_from) else ChunkData.Tile.RIVER_NARROW
		# Arroyos de montaña: ancho constante (estrecharlos los rompe en charcos) y solo al norte
		# de stream_until; terminan en seco en esa latitud.
		if t < float(rivers.stream_until) and absf(stream.get_noise_2d(wx, wy)) < float(rivers.stream_width):
			return ChunkData.Tile.RIVER_NARROW
		# Riscos: bordes de terraza (curvas de nivel) donde la ladera es empinada; línea de 1 tile.
		# Pendientes pronunciadas: gradiente muy fuerte, en manchas.
		var e: float = elevation(wx, wy)
		var e_right: float = elevation(wx + 1.0, wy)
		var e_left: float = elevation(wx - 1.0, wy)
		var e_down: float = elevation(wx, wy + 1.0)
		var e_up: float = elevation(wx, wy - 1.0)
		var gradient: float = Vector2(e_right - e_left, e_down - e_up).length() * 0.5
		if gradient > float(relief.steep_gradient):
			return ChunkData.Tile.CLIFF
		if gradient > float(relief.cliff_gradient):
			var step: float = float(relief.terrace_step)
			var level: float = floorf(e / step)
			var lower_neighbour: bool = level > floorf(e_right / step) or level > floorf(e_left / step)
			lower_neighbour = lower_neighbour or level > floorf(e_down / step) or level > floorf(e_up / step)
			if lower_neighbour:
				return ChunkData.Tile.CLIFF
		var f: float = forest.get_noise_2d(wx, wy)
		if t >= float(rivers.riverside_clearing_from) and main < main_width * float(rivers.riverside_clearing_factor):
			return ChunkData.Tile.CLEARING
		if e > float(relief.rocky_level):
			return ChunkData.Tile.FOREST if f > tree_threshold + 0.15 else ChunkData.Tile.ROCKY
		if f > tree_threshold:
			return ChunkData.Tile.FOREST
		if f < clearing_threshold:
			return ChunkData.Tile.CLEARING
		if rng.randf() < SCATTER_TREE_CHANCE:
			return ChunkData.Tile.FOREST
		return ChunkData.Tile.GRASS
