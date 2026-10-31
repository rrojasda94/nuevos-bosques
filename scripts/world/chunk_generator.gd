class_name ChunkGenerator
extends RefCounted
## Utilidades del mundo compartidas por el Mundo 2.0 (ADR 0014 §7: "se reutilizan Terrain, hash_ints
## y la lógica de puertas"). El generador de chunks de 64×64 (generate, ChunkData) se borró en M17b;
## los chunks los hace ChunkBuilder sobre RegionPlan. Queda:
## - Hash estable (hash_ints) y ruido (_make_noise) con los que se siembra todo lo determinista.
## - Datos de región (load_region, region_size, region_start_chunk, fruit_params) y direcciones
##   (direction_name, direction_index, _side_towards, gate_index).
## - Estado de fruto de un Bosque (bosque_state, bosque_gives_fruit).
## - Terrain: relieve y río principal de la ADR 0006, de los que parte RegionPlan.
## ponytail: mover a una clase con nombre propio (p. ej. WorldHash + RegionTerrain) cuando
## chunk_builder.gd y region_plan.gd estén libres; hoy dependen de este nombre.

const REGION_DIR: String = "res://data/world/regions/"
## Las entradas de cada borde quedan al menos a esta distancia de las esquinas (gate_index).
const GATE_MARGIN: int = 6
## Frecuencias del ruido (más alto = manchas más pequeñas).
const HEIGHT_FREQUENCY: float = 0.015
const MEANDER_FREQUENCY: float = 0.004

# Sales para separar los distintos usos del hash.
const SALT_HEIGHT: int = 1
const SALT_GATE: int = 4
const SALT_RIVER: int = 6
const SALT_FORD: int = 14

## Valores por defecto de los parámetros de región (data/world/regions/*.json).
const DEFAULT_SIZE_CHUNKS: Array = [8, 8]
const DEFAULT_RELIEF: Dictionary = {
	"north_base": 0.0, "south_base": 0.0,
	"north_roughness": 0.5, "south_roughness": 0.5,
	"mountain_level": 0.5, "mountain_ramp": 0.3,
	"outcrop_threshold": 0.35, "rocky_level": 0.3,
}
const DEFAULT_RIVERS: Dictionary = {
	"main_center": 0.5, "main_center_jitter": 0.15, "main_meander": 0.15,
	"main_width_north": 2.0, "main_width_south": 4.0, "navigable_from": 2.0,
	"ford_spacing": 48, "ford_length": 2,
	"stream_width": 0.0, "stream_until": 0.0,
	"riverside_clearing_from": 2.0, "riverside_band": 3.0,
}
## Frutales (bosques-y-relacion.md, sección Fruto). `states`: estados de Bosque (BosqueMap.state)
## que dan fruto; `per_chunk`: [mín, máx] frutales por chunk; `min_spacing`: distancia mínima
## (Chebyshev) entre dos frutales del mismo chunk.
const DEFAULT_FRUIT: Dictionary = {
	"states": ["sano", "necesita_ayuda"],
	"per_chunk": [3, 6], "min_spacing": 5,
}


## Parámetros de frutales de la región, con los valores por defecto.
static func fruit_params(region: Dictionary) -> Dictionary:
	return DEFAULT_FRUIT.merged(region.get("fruit", {}), true)


## Estado de generación del Bosque (BosqueMap.state, por seed). Decide los frutales y el Nujio.
## Los cambios de estado durante la partida (BosqueStates) no regeneran el chunk.
static func bosque_state(_region: Dictionary, bosques: BosqueMap, bosque_id: int) -> String:
	if bosques == null or bosque_id < 0:
		return ""
	return bosques.state_of(bosque_id)


## El Bosque da fruto según su estado (sano y necesita_ayuda, bosques-y-relacion.md).
static func bosque_gives_fruit(region: Dictionary, bosques: BosqueMap, bosque_id: int) -> bool:
	var state: String = bosque_state(region, bosques, bosque_id)
	return state != "" and (fruit_params(region).states as Array).has(state)


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


## Relieve y río principal de la ADR 0006 en casillas del mundo viejo (chunks de ChunkData.SIZE).
## RegionPlan cuantiza `elevation` en niveles y toma de aquí el trazado del río.
class Terrain:
	var seed_value: int
	var height: FastNoiseLite
	var meander: FastNoiseLite
	var region_size_tiles: Vector2
	var relief: Dictionary
	var rivers: Dictionary
	var river_center_x: float

	func _init(seed_v: int, region: Dictionary) -> void:
		seed_value = seed_v
		height = ChunkGenerator._make_noise(ChunkGenerator.hash_ints([seed_v, SALT_HEIGHT]), HEIGHT_FREQUENCY, 3)
		meander = ChunkGenerator._make_noise(ChunkGenerator.hash_ints([seed_v, SALT_RIVER]), MEANDER_FREQUENCY, 2)
		region_size_tiles = Vector2(ChunkGenerator.region_size(region) * ChunkData.SIZE)
		relief = DEFAULT_RELIEF.merged(region.get("relief", {}), true)
		rivers = DEFAULT_RIVERS.merged(region.get("rivers", {}), true)
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
