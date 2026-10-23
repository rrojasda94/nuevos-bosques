class_name ChunkGenerator
extends RefCounted
## Genera un ChunkData determinista a partir de (seed, coordenadas del chunk) y los parámetros
## de la región. ADR 0006:
## - El ruido se muestrea en coordenadas de mundo, así el terreno continúa entre chunks vecinos.
## - La aleatoriedad local sale de un RNG propio sembrado con hash(seed, x, y). No se usa
##   GameState.rng ni randi()/randf() globales: un chunk sale igual se visite en el orden que sea.
## - Cada borde tiene una entrada (sendero) en la misma posición vista desde los dos chunks.

const REGION_DIR: String = "res://data/world/regions/"
## Radio del claro central (punto de aparición seguro).
const CENTER_CLEARING_RADIUS: int = 4
## Las entradas de cada borde quedan al menos a esta distancia de las esquinas.
const GATE_MARGIN: int = 6
## Probabilidad de árbol suelto en la hierba.
const SCATTER_TREE_CHANCE: float = 0.04
## Probabilidad de que un sendero se desvíe en cada paso.
const PATH_WIGGLE: float = 0.3
## Frecuencias del ruido (más alto = manchas más pequeñas).
const HEIGHT_FREQUENCY: float = 0.03
const FOREST_FREQUENCY: float = 0.07

# Sales para separar los distintos usos del hash.
const SALT_HEIGHT: int = 1
const SALT_FOREST: int = 2
const SALT_LOCAL: int = 3
const SALT_GATE: int = 4


static func generate(seed_value: int, coord: Vector2i, region: Dictionary = {}) -> ChunkData:
	var size: int = ChunkData.SIZE
	var chunk := ChunkData.new()
	chunk.seed_value = seed_value
	chunk.coord = coord
	chunk.tiles.resize(size * size)

	var forest_density: float = float(region.get("forest_density", 0.6))
	var water_amount: float = float(region.get("water", 0.1))
	var water_threshold: float = -0.6 + water_amount * 1.2
	var tree_threshold: float = 0.3 - forest_density * 0.45
	var clearing_threshold: float = tree_threshold - 0.35

	var height: FastNoiseLite = _make_noise(hash_ints([seed_value, SALT_HEIGHT]), HEIGHT_FREQUENCY, 3)
	var forest: FastNoiseLite = _make_noise(hash_ints([seed_value, SALT_FOREST]), FOREST_FREQUENCY, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_ints([seed_value, coord.x, coord.y, SALT_LOCAL])

	var origin: Vector2i = coord * size
	for y: int in size:
		for x: int in size:
			var wx: float = origin.x + x
			var wy: float = origin.y + y
			var tile: int = ChunkData.Tile.GRASS
			if height.get_noise_2d(wx, wy) < water_threshold:
				tile = ChunkData.Tile.WATER
			else:
				var f: float = forest.get_noise_2d(wx, wy)
				if f > tree_threshold:
					tile = ChunkData.Tile.TREE
				elif f < clearing_threshold:
					tile = ChunkData.Tile.CLEARING
				elif rng.randf() < SCATTER_TREE_CHANCE:
					tile = ChunkData.Tile.TREE
			chunk.tiles[y * size + x] = tile

	var center: Vector2i = ChunkData.center()
	for side: Vector2i in ChunkData.SIDES:
		var gate: Vector2i = ChunkData.border_cell(side, gate_index(seed_value, coord, side))
		_carve_path(chunk, gate, -side, center, rng)
	_carve_clearing(chunk, center, CENTER_CLEARING_RADIUS)
	return chunk


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
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	return noise


## Sendero serpenteante desde una entrada del borde hasta el centro. Garantiza que cada entrada
## está conectada con el claro central.
static func _carve_path(chunk: ChunkData, from: Vector2i, inward: Vector2i, to: Vector2i, rng: RandomNumberGenerator) -> void:
	var size: int = ChunkData.SIZE
	var cell: Vector2i = from
	# Los primeros pasos van rectos hacia dentro para que la entrada se vea clara.
	for _i: int in 3:
		chunk.set_tile(cell, ChunkData.Tile.PATH)
		cell += inward
	var steps: int = 0
	while cell != to:
		chunk.set_tile(cell, ChunkData.Tile.PATH)
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
	chunk.set_tile(to, ChunkData.Tile.PATH)


static func _carve_clearing(chunk: ChunkData, center: Vector2i, radius: int) -> void:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius + radius:
				chunk.set_tile(center + Vector2i(dx, dy), ChunkData.Tile.CLEARING)
