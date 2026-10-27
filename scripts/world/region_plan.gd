class_name RegionPlan
extends RefCounted
## Pasada de región del Mundo 2.0 (ADR 0014 §5): lo que se decide una vez por partida para toda
## la región, antes de construir ningún chunk. Determinista por (seed, region_id, authoring_hash,
## GENERATOR_VERSION). Un solo hilo; objetivo ≤ 1,5 s.
## - Altura gruesa (1 valor por `macro`): lo pintado en altura.png manda; lo transparente sale de
##   la elevación de ChunkGenerator.Terrain cuantizada en 4 niveles (HEIGHT_THRESHOLDS), sin
##   celdas sueltas. LEVEL_PEAK = cumbre.
## - Agua: la de agua.png con meandro de ruido (±1 celda gruesa), sin cortar ríos; sin agua.png,
##   el río procedural de la ADR 0006. Los arroyos de montaña siguen en el chunk.
## - Bosques (BosqueMap.build_planned): Bosques clave de bosques.png y lugares.csv, el resto
##   procedural; villas del CSV (la natal sustituye a start_chunk), áreas y aldeas (opción C).
## - Caminos: los pintados (con puente donde el meandro los deja sobre el agua) más la red de
##   BosqueMap donde no hay camino pintado que una los Nujios.
## - Puertas entre chunks: con camino, siempre; si no, DOOR_PERCENT %; y un árbol de expansión de
##   bordes por Bosque abre las que falten para que todo Bosque se recorra a pie.
## - Refugios: el reparto de BosqueMap (ADR 0006), sin cambios. La garantía de ≤ 300 casillas a
##   pie la cierra el ChunkBuilder con refugios extra (generation.md, "Refugios garantizados").
## - Sicabis (lugares-e-interiores.md): como mucho 1 por subregión, con probabilidad
##   `sicabis.subregion_chance`, lejos de villas, aldeas y otras sicabis, nunca en un Bosque muerto.
##   Las subregiones salen del bloque `subregions` de la región o, si falta, de las áreas.
## Inmutable tras build(): las consultas solo leen y devuelven copias, así que los ChunkBuilder
## (M6+) pueden leerlo a la vez desde varios hilos. No construye chunks ni toca la escena.

const GENERATOR_VERSION: int = 3
## Umbrales de elevación de los niveles 1, 2 y 3 (los del spike).
const HEIGHT_THRESHOLDS: Array[float] = [-0.1, 0.32, 0.62]
const LEVEL_MAX: int = 3
## Cumbre: infranqueable (RegionAuthoring.Height.PEAK).
const LEVEL_PEAK: int = 4
## Probabilidad (%) de que un borde sin camino tenga puerta (sendero).
const DOOR_PERCENT: int = 70
## Casillas libres entre una puerta procedural y la esquina del chunk.
const DOOR_MARGIN: int = 8
## Ancho en casillas: sendero y camino (ADR 0014 §5, pasada de chunk, paso 4).
const PATH_WIDTH: int = 2
const ROAD_WIDTH: int = 3
## Meandro del agua pintada: frecuencia del ruido (por celda gruesa) y escala a celdas.
const MEANDER_FREQUENCY: float = 0.06
const MEANDER_GAIN: float = 2.2
## Celdas gruesas alrededor de un lugar del CSV donde el agua no se mueve (no lo inunda).
const MEANDER_KEEP: int = 3
## Tipos de lugar que solo ponen nombre (rótulos de río y nacimientos): no quitan el agua de su
## celda gruesa. El resto (villas, Bosques, hitos, tarcas) ocupa tierra.
const WATER_LABELS: Array[String] = ["lugar", "manantial"]
const NAMES_PATH: String = "res://data/text/nombres_villas.json"
## Aldeas: [mín, máx] casas (mundo-2.md §6: 2-4, frente a 5 o más de las villas con nombre).
const DEFAULT_ALDEA_HOUSES: Array = [2, 4]
## Prioridad del agua cuando dos celdas caen en la misma: un vado nunca se pierde.
const WATER_PRIORITY: Array[int] = [0, 4, 3, 2, 1, 5]

const SALT_PLAN: int = 130
const SALT_MEANDER_X: int = 131
const SALT_MEANDER_Y: int = 132
const SALT_DOOR: int = 133
const SALT_DOOR_OPEN: int = 134
const SALT_DOOR_TREE: int = 135
const SALT_ALDEA_NAME: int = 136
const SALT_ALDEA_HOUSES: int = 137
const SALT_SICABI_ROLL: int = 138
const SALT_SICABI_ORDER: int = 139
const SALT_SICABI_CHUNK: int = 158
## Sicabis por defecto (lugares-e-interiores.md, "Qué irían en data/"); la región los cambia con su
## bloque "sicabis". subregion_chance 0 = sin sicabis (regiones sin el bloque).
const DEFAULT_SICABIS: Dictionary = {
	"per_subregion_max": 1, "subregion_chance": 0.0, "min_villa_distance_chunks": 2,
	"min_sicabi_distance_chunks": 4, "min_road_distance": 10, "min_path_distance": 6,
	"access_width": 2, "forest_ratio": 0.7, "forest_radius": 6, "cliff_min_level": 2,
	"allow_dead_bosque": false,
}

var seed_value: int = 0
var region_id: StringName = &""
## Hash de lo pintado y de lugares.csv (ver authoring_hash_of).
var authoring_hash: int = 0
## Semilla de la pasada: hash de (seed, region_id, authoring_hash, GENERATOR_VERSION).
var plan_seed: int = 0
## Tamaño en celdas gruesas y en chunks.
var size_macro: Vector2i = Vector2i.ZERO
var size_chunks: Vector2i = Vector2i.ZERO
## Chunk de la villa natal (sustituye a start_chunk).
var home_chunk: Vector2i = Vector2i(-1, -1)
## Bosques, villas, áreas, caminos y refugios. Solo lectura.
var bosques: BosqueMap = null
## Tiempo que tardó build(), en microsegundos.
var build_usec: int = 0
## JSON de la región (copia profunda, solo lectura): parámetros que lee la pasada de chunk.
var region_params: Dictionary = {}

var _height: PackedByteArray = PackedByteArray()
var _water: PackedByteArray = PackedByteArray()
var _roads: PackedByteArray = PackedByteArray()
var _villas: Array[Dictionary] = []
var _villa_at: Dictionary = {}  # Vector2i chunk -> índice en _villas
var _places: Array[Dictionary] = []
var _crossings: Dictionary = {}  # Vector3i borde -> celda gruesa (0..19) por donde lo cruza el camino pintado
var _doors: Dictionary = {}  # Vector3i borde -> { index, width, road, forced }
var _subregion: PackedInt32Array = PackedInt32Array()  # por chunk (fila a fila): índice en _subregion_names
var _subregion_names: Array[String] = []
var _sicabis: Array[Dictionary] = []
var _sicabi_at: Dictionary = {}  # Vector2i chunk -> índice en _sicabis


## Plan de la región `region_id` con su JSON y su autoría (data/world/regions/).
static func for_region(seed_v: int, id: StringName) -> RegionPlan:
	return build(seed_v, id, ChunkGenerator.load_region(id), RegionAuthoring.load_region(id))


static func build(seed_v: int, id: StringName, region: Dictionary, authoring: RegionAuthoring) -> RegionPlan:
	var t0: int = Time.get_ticks_usec()
	var plan := RegionPlan.new()
	plan.seed_value = seed_v
	plan.region_id = id
	plan.size_macro = authoring.size_px
	if plan.size_macro == Vector2i.ZERO:
		plan.size_macro = ChunkGenerator.region_size(region) * WorldCoords.MACROS_PER_CHUNK
	plan.size_chunks = Vector2i(ceili(plan.size_macro.x / float(WorldCoords.MACROS_PER_CHUNK)),
			ceili(plan.size_macro.y / float(WorldCoords.MACROS_PER_CHUNK)))
	plan.authoring_hash = authoring_hash_of(authoring)
	plan.plan_seed = ChunkGenerator.hash_ints([seed_v, String(id).sha256_buffer().decode_u32(0),
			plan.authoring_hash, GENERATOR_VERSION, SALT_PLAN])
	plan.region_params = region.duplicate(true)
	plan.home_chunk = authoring.home_chunk()
	if not plan._in_chunks(plan.home_chunk):
		plan.home_chunk = ChunkGenerator.region_start_chunk(region)
	for p: Dictionary in authoring.places:
		plan._places.append(p.duplicate())
	var terrain_region: Dictionary = region.duplicate()
	terrain_region["size_chunks"] = [plan.size_chunks.x, plan.size_chunks.y]
	plan._build_height(authoring, terrain_region)
	plan._build_water(authoring, terrain_region)
	plan._build_roads(authoring)
	plan._build_bosques(region, authoring)
	plan._build_villas(region)
	plan._build_doors()
	plan._build_subregions(region)
	plan._build_sicabis(region)
	plan.build_usec = Time.get_ticks_usec() - t0
	return plan


## Hash estable (SHA-256, 63 bits) de las capas decodificadas y de los lugares: cambia si el dueño
## repinta o mueve algo, no si guarda la misma PNG con otra compresión.
static func authoring_hash_of(a: RegionAuthoring) -> int:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(("%d,%d|" % [a.size_px.x, a.size_px.y]).to_utf8_buffer())
	for layer: PackedByteArray in [a.height, a.water, a.roads, a.bosque.to_byte_array()]:
		ctx.update(("%d|" % layer.size()).to_utf8_buffer())
		if not layer.is_empty():
			ctx.update(layer)
	var lines: PackedStringArray = []
	for p: Dictionary in a.places:
		lines.append("%s|%s|%s|%d|%d|%s|%s" % [p.id, p.name, p.type, p.cell.x, p.cell.y,
				(p.color as Color).to_html(false), p.style])
	ctx.update("\n".join(lines).to_utf8_buffer())
	return ctx.finish().decode_u64(0) & 0x7FFFFFFFFFFFFFFF


# --- Consultas (solo lectura) ------------------------------------------------------------------

func in_macro(macro: Vector2i) -> bool:
	return macro.x >= 0 and macro.y >= 0 and macro.x < size_macro.x and macro.y < size_macro.y


func _in_chunks(chunk: Vector2i) -> bool:
	return chunk.x >= 0 and chunk.y >= 0 and chunk.x < size_chunks.x and chunk.y < size_chunks.y


## Nivel 0..3 de la celda gruesa, LEVEL_PEAK en una cumbre, -1 fuera de la región.
func level_at(macro: Vector2i) -> int:
	return _height[macro.y * size_macro.x + macro.x] if in_macro(macro) else -1


## Agua de la celda gruesa (RegionAuthoring.Water; NONE fuera).
func water_at(macro: Vector2i) -> int:
	return _water[macro.y * size_macro.x + macro.x] if in_macro(macro) else RegionAuthoring.Water.NONE


## Camino pintado de la celda gruesa (RegionAuthoring.Road). Los tramos de la red procedural no
## están aquí: son lados de chunk (road_sides) y los traza el ChunkBuilder.
func road_at(macro: Vector2i) -> int:
	return _roads[macro.y * size_macro.x + macro.x] if in_macro(macro) else RegionAuthoring.Road.NONE


## Capas completas (copias), fila a fila, size_macro.x de ancho. Para la vista previa y el mapa M.
func height_layer() -> PackedByteArray:
	return _height.duplicate()


func water_layer() -> PackedByteArray:
	return _water.duplicate()


func road_layer() -> PackedByteArray:
	return _roads.duplicate()


## Bloque de 20×20 celdas gruesas del chunk (fila a fila) de una capa: "height", "water" o "roads".
func chunk_block(layer: String, chunk: Vector2i) -> PackedByteArray:
	var src: PackedByteArray = _height if layer == "height" else (_water if layer == "water" else _roads)
	var n: int = WorldCoords.MACROS_PER_CHUNK
	var out := PackedByteArray()
	out.resize(n * n)
	var origin: Vector2i = chunk * n
	for y: int in n:
		var row: int = (origin.y + y) * size_macro.x + origin.x
		for x: int in n:
			out[y * n + x] = src[row + x] if in_macro(origin + Vector2i(x, y)) else 0
	return out


func bosque_at(chunk: Vector2i) -> int:
	return bosques.bosque_at(chunk)


## Villas con nombre (lugares.csv) y aldeas: { id, name, kind ("villa_natal", "villa", "aldea"),
## chunk, macro, bosque_id, houses (solo aldeas: 2-4; 0 = lo decide el ChunkBuilder) }.
func villas() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v: Dictionary in _villas:
		out.append(v.duplicate())
	return out


func aldeas() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v: Dictionary in _villas:
		if v.kind == "aldea":
			out.append(v.duplicate())
	return out


## Villa o aldea del chunk ({} si no hay).
func villa_in_chunk(chunk: Vector2i) -> Dictionary:
	return (_villas[_villa_at[chunk]] as Dictionary).duplicate() if _villa_at.has(chunk) else {}


## Lugares de lugares.csv que caen en el chunk (copias, en el orden del CSV).
func places_in_chunk(chunk: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in _places:
		if WorldCoords.floor_div_v(p.cell, WorldCoords.MACROS_PER_CHUNK) == chunk:
			out.append(p.duplicate())
	return out


## Lados (dirección hacia fuera) con camino: pintado o de la red de BosqueMap.
func road_sides(chunk: Vector2i) -> Array[Vector2i]:
	return bosques.road_sides(chunk)


## Puerta del borde `side` del chunk ({} si el borde está cerrado o es el de la región):
## { index (casilla 0-79 a lo largo del borde donde empieza), width (casillas), road (camino),
##   forced (la abrió el árbol del Bosque), cell (primera casilla de la puerta en este chunk) }.
## Vista desde el chunk vecino es la misma puerta (mismo index y width).
func door(chunk: Vector2i, side: Vector2i) -> Dictionary:
	var edge: Vector3i = edge_of(chunk, side)
	if not _doors.has(edge):
		return {}
	var d: Dictionary = (_doors[edge] as Dictionary).duplicate()
	var last: int = WorldCoords.CHUNK - 1
	match side:
		Vector2i.LEFT:
			d.cell = Vector2i(0, d.index)
		Vector2i.RIGHT:
			d.cell = Vector2i(last, d.index)
		Vector2i.UP:
			d.cell = Vector2i(d.index, 0)
		_:
			d.cell = Vector2i(d.index, last)
	return d


func has_door(chunk: Vector2i, side: Vector2i) -> bool:
	return _doors.has(edge_of(chunk, side))


## Puertas del chunk: lado -> puerta (ver door()).
func doors_of(chunk: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	for side: Vector2i in ChunkData.SIDES:
		if has_door(chunk, side):
			out[side] = door(chunk, side)
	return out


## Subregión del chunk (índice en subregion_names()), -1 fuera de la región.
func subregion_of(chunk: Vector2i) -> int:
	return _subregion[chunk.y * size_chunks.x + chunk.x] if _in_chunks(chunk) else -1


## Ids de las subregiones: los del bloque `subregions` y "area_<n>" para las que salen de las áreas.
func subregion_names() -> Array[String]:
	return _subregion_names.duplicate()


## Sicabis de la región: { id, chunk, subregion, csv (la pintó el dueño), macro (solo csv) }.
func sicabis() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in _sicabis:
		out.append(s.duplicate())
	return out


## Sicabi del chunk ({} si no hay).
func sicabi_in_chunk(chunk: Vector2i) -> Dictionary:
	return (_sicabis[_sicabi_at[chunk]] as Dictionary).duplicate() if _sicabi_at.has(chunk) else {}


## Parámetros de las sicabis (DEFAULT_SICABIS con el bloque "sicabis" de la región encima).
func sicabi_params() -> Dictionary:
	return DEFAULT_SICABIS.merged(region_params.get("sicabis", {}), true)


func has_refuge(chunk: Vector2i) -> bool:
	return bosques.has_refuge(chunk)


func refuge_chunks() -> Array[Vector2i]:
	return bosques.refuge_chunks()


## Borde compartido por el chunk y su vecino en `side`: (x, y, 0) = borde oeste del chunk (x, y);
## (x, y, 1) = borde norte. Igual que ChunkGenerator.gate_index.
static func edge_of(chunk: Vector2i, side: Vector2i) -> Vector3i:
	match side:
		Vector2i.RIGHT:
			return Vector3i(chunk.x + 1, chunk.y, 0)
		Vector2i.UP:
			return Vector3i(chunk.x, chunk.y, 1)
		Vector2i.DOWN:
			return Vector3i(chunk.x, chunk.y + 1, 1)
	return Vector3i(chunk.x, chunk.y, 0)


## El borde separa dos chunks de la región (no es el borde exterior).
func is_inner_edge(edge: Vector3i) -> bool:
	if edge.z == 0:
		return edge.x >= 1 and edge.x < size_chunks.x and edge.y >= 0 and edge.y < size_chunks.y
	return edge.y >= 1 and edge.y < size_chunks.y and edge.x >= 0 and edge.x < size_chunks.x


# --- Altura ------------------------------------------------------------------------------------

func _build_height(authoring: RegionAuthoring, terrain_region: Dictionary) -> void:
	var n: int = size_macro.x * size_macro.y
	_height.resize(n)
	var procedural := PackedByteArray()
	procedural.resize(n)
	var src: PackedByteArray = authoring.height
	var any: bool = false
	for i: int in n:
		var h: int = src[i] if i < src.size() else RegionAuthoring.Height.NONE
		if h == RegionAuthoring.Height.NONE:
			procedural[i] = 1
			any = true
		else:
			_height[i] = h - RegionAuthoring.Height.LEVEL_0
	if not any:
		return
	# Igual que tools/world/export_region_authoring.gd: la celda gruesa se muestrea en su centro en
	# las casillas del generador actual (chunks de ChunkData.SIZE), así que borrar lo pintado da lo
	# mismo que exportó la herramienta.
	var terrain := ChunkGenerator.Terrain.new(seed_value, terrain_region)
	var scale: float = float(ChunkData.SIZE) / WorldCoords.CHUNK
	var half: float = WorldCoords.MACRO * 0.5
	for my: int in size_macro.y:
		var fy: float = (my * WorldCoords.MACRO + half) * scale
		for mx: int in size_macro.x:
			var i: int = my * size_macro.x + mx
			if procedural[i] == 0:
				continue
			var e: float = terrain.elevation((mx * WorldCoords.MACRO + half) * scale, fy)
			var level: int = 0
			for t: float in HEIGHT_THRESHOLDS:
				if e >= t:
					level += 1
			_height[i] = level
	_remove_lone_levels(procedural)


## Sin celdas sueltas: una celda procedural sin vecino ortogonal de su nivel toma el nivel más común
## de sus vecinos (en empate, el más bajo). En el sitio: al cambiar una celda suelta nadie que
## dependiera de su nivel anterior queda suelto, así que basta una pasada. Lo pintado no cambia.
func _remove_lone_levels(procedural: PackedByteArray) -> void:
	var w: int = size_macro.x
	var h: int = size_macro.y
	var counts := PackedInt32Array()
	counts.resize(LEVEL_MAX + 1)
	for y: int in h:
		for x: int in w:
			var i: int = y * w + x
			if procedural[i] == 0:
				continue
			var level: int = _height[i]
			var alone: bool = true
			var seen: bool = false
			counts.fill(0)
			for k: int in 4:
				var nx: int = x + (-1 if k == 0 else (1 if k == 1 else 0))
				var ny: int = y + (-1 if k == 2 else (1 if k == 3 else 0))
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var nl: int = _height[ny * w + nx]
				if nl == level:
					alone = false
					break
				if nl <= LEVEL_MAX:
					counts[nl] += 1
					seen = true
			if not alone or not seen:
				continue
			var best: int = 0
			for l: int in range(1, LEVEL_MAX + 1):
				if counts[l] > counts[best]:
					best = l
			_height[i] = best


# --- Agua --------------------------------------------------------------------------------------

func _build_water(authoring: RegionAuthoring, terrain_region: Dictionary) -> void:
	_water.resize(size_macro.x * size_macro.y)
	if bool(authoring.has_layer.get("water", false)):
		_meander(authoring.water)
	else:
		_procedural_river(terrain_region)
	# Ningún lugar del CSV que ocupa tierra queda en el agua (el validador ya lo exige de lo
	# pintado). Los que solo nombran el agua (WATER_LABELS: los rótulos de afluentes y los
	# manantiales) no la borran, para no dejar un hueco seco en el río.
	for p: Dictionary in _places:
		if in_macro(p.cell) and not WATER_LABELS.has(String(p.type)):
			_water[p.cell.y * size_macro.x + p.cell.x] = RegionAuthoring.Water.NONE


## Desplaza cada celda de agua pintada ±1 celda gruesa según dos ruidos suaves (x e y) y une con
## una L las celdas que eran vecinas, así que un río no se corta ni cambia de forma de red. Cerca
## de un lugar (MEANDER_KEEP) el agua se queda donde se pintó, y también junto a una cumbre (el
## nacimiento de un río al pie de Larr o de su cumbre: si se moviera, caería en la cumbre y el
## trozo de río de al lado quedaría suelto). No pisa las cumbres.
func _meander(src: PackedByteArray) -> void:
	var w: int = size_macro.x
	var n: int = size_macro.x * size_macro.y
	if src.size() != n:
		return
	var noise_x: FastNoiseLite = ChunkGenerator._make_noise(ChunkGenerator.hash_ints([plan_seed, SALT_MEANDER_X]), MEANDER_FREQUENCY, 2)
	var noise_y: FastNoiseLite = ChunkGenerator._make_noise(ChunkGenerator.hash_ints([plan_seed, SALT_MEANDER_Y]), MEANDER_FREQUENCY, 2)
	var keep := PackedByteArray()
	keep.resize(n)
	for p: Dictionary in _places:
		var c: Vector2i = p.cell
		for y: int in range(maxi(0, c.y - MEANDER_KEEP), mini(size_macro.y, c.y + MEANDER_KEEP + 1)):
			for x: int in range(maxi(0, c.x - MEANDER_KEEP), mini(w, c.x + MEANDER_KEEP + 1)):
				keep[y * w + x] = 1
	var dest := PackedInt32Array()
	dest.resize(n)
	for i: int in n:
		if src[i] == RegionAuthoring.Water.NONE:
			continue
		var x: int = i % w
		var y: int = i / w
		if keep[i] == 0 and not _next_to_peak(x, y):
			x = clampi(x + clampi(roundi(noise_x.get_noise_2d(x, y) * MEANDER_GAIN), -1, 1), 0, w - 1)
			y = clampi(y + clampi(roundi(noise_y.get_noise_2d(x, y) * MEANDER_GAIN), -1, 1), 0, size_macro.y - 1)
		dest[i] = y * w + x
		_put_water(dest[i], src[i])
	for i: int in n:
		if src[i] == RegionAuthoring.Water.NONE:
			continue
		var x: int = i % w
		if x + 1 < w and src[i + 1] != RegionAuthoring.Water.NONE:
			_water_line(dest[i], dest[i + 1], _stronger(src[i], src[i + 1]))
		if i + w < n and src[i + w] != RegionAuthoring.Water.NONE:
			_water_line(dest[i], dest[i + w], _stronger(src[i], src[i + w]))


func _next_to_peak(x: int, y: int) -> bool:
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var c := Vector2i(x, y) + d
		if in_macro(c) and _height[c.y * size_macro.x + c.x] == LEVEL_PEAK:
			return true
	return false


static func _stronger(a: int, b: int) -> int:
	return a if WATER_PRIORITY[a] >= WATER_PRIORITY[b] else b


func _put_water(i: int, kind: int) -> void:
	if _height[i] == LEVEL_PEAK:
		return
	if WATER_PRIORITY[kind] > WATER_PRIORITY[_water[i]]:
		_water[i] = kind


## L de celdas 4-conectadas de `a` a `b` (primero en x, luego en y).
func _water_line(a: int, b: int, kind: int) -> void:
	var w: int = size_macro.x
	var x: int = a % w
	var y: int = a / w
	var bx: int = b % w
	var by: int = b / w
	while x != bx:
		x += signi(bx - x)
		_put_water(y * w + x, kind)
	while y != by:
		y += signi(by - y)
		_put_water(y * w + x, kind)


## Río principal de la ADR 0006 (ChunkGenerator.Terrain) sobre la rejilla gruesa, como lo exporta
## tools/world/export_region_authoring.gd: sin los arroyos, que siguen siendo del chunk.
func _procedural_river(terrain_region: Dictionary) -> void:
	var terrain := ChunkGenerator.Terrain.new(seed_value, terrain_region)
	var old: int = ChunkData.SIZE
	var macro: float = WorldCoords.MACRO * float(old) / WorldCoords.CHUNK
	var tiles_w: int = size_chunks.x * old
	var tiles_h: int = size_chunks.y * old
	for my: int in size_macro.y:
		var ty0: int = floori(my * macro)
		var ty1: int = mini(ceili((my + 1) * macro), tiles_h) - 1
		var ford: bool = false
		var spans: Array[Vector2i] = []
		for ty: int in range(ty0, ty1 + 1):
			ford = ford or terrain.is_ford_row(ty)
			spans.append(terrain.river_span(ty))
		var navigable: bool = terrain.north_south((my + 0.5) * macro) >= float(terrain.rivers.navigable_from)
		for mx: int in size_macro.x:
			var tx0: int = floori(mx * macro)
			var tx1: int = mini(ceili((mx + 1) * macro), tiles_w) - 1
			var river: bool = false
			for span: Vector2i in spans:
				river = river or (tx1 >= span.x and tx0 <= span.y)
			if not river:
				continue
			var kind: int = RegionAuthoring.Water.FORD if ford else (RegionAuthoring.Water.RIVER_NAVIGABLE if navigable else RegionAuthoring.Water.RIVER_NARROW)
			_put_water(my * size_macro.x + mx, kind)


static func _is_deep(kind: int) -> bool:
	return kind == RegionAuthoring.Water.RIVER_NAVIGABLE or kind == RegionAuthoring.Water.RIVER_NARROW or kind == RegionAuthoring.Water.LAKE or kind == RegionAuthoring.Water.SEA


# --- Caminos pintados --------------------------------------------------------------------------

## Caminos de caminos.png: puente donde (tras el meandro) pasan sobre agua honda, camino donde no.
## Y los cruces de borde de chunk: celdas de camino a los dos lados del borde.
func _build_roads(authoring: RegionAuthoring) -> void:
	var n: int = size_macro.x * size_macro.y
	_roads.resize(n)
	var src: PackedByteArray = authoring.roads
	if src.size() != n:
		return
	for i: int in n:
		if src[i] != RegionAuthoring.Road.NONE:
			_roads[i] = RegionAuthoring.Road.BRIDGE if _is_deep(_water[i]) else RegionAuthoring.Road.ROAD
	var m: int = WorldCoords.MACROS_PER_CHUNK
	for axis: int in 2:
		for cy: int in size_chunks.y:
			for cx: int in size_chunks.x:
				var edge := Vector3i(cx, cy, axis)
				if not is_inner_edge(edge):
					continue
				# Celdas a los dos lados del borde: oeste/este (axis 0) o norte/sur (axis 1).
				var best_start: int = -1
				var best_len: int = 0
				var run: int = 0
				for k: int in m + 1:
					var both: bool = false
					if k < m:
						var a: Vector2i
						var b: Vector2i
						if axis == 0:
							a = Vector2i(cx * m - 1, cy * m + k)
							b = Vector2i(cx * m, cy * m + k)
						else:
							a = Vector2i(cx * m + k, cy * m - 1)
							b = Vector2i(cx * m + k, cy * m)
						both = road_at(a) != RegionAuthoring.Road.NONE and road_at(b) != RegionAuthoring.Road.NONE
					if both:
						run += 1
						continue
					if run > best_len:
						best_len = run
						best_start = k - run
					run = 0
				if best_len > 0:
					_crossings[edge] = best_start + best_len / 2


## Lados de chunk con camino pintado, para BosqueMap.
func _painted_road_sides() -> Dictionary:
	var out: Dictionary = {}
	for edge: Vector3i in _crossings:
		var a := Vector2i(edge.x, edge.y)
		var side: Vector2i = Vector2i.LEFT if edge.z == 0 else Vector2i.UP
		for pair: Array in [[a, side], [a + side, -side]]:
			var c: Vector2i = pair[0]
			if not out.has(c):
				var fresh: Array[Vector2i] = []
				out[c] = fresh
			(out[c] as Array).append(pair[1])
	return out


# --- Bosques, villas y aldeas ------------------------------------------------------------------

func _build_bosques(region: Dictionary, authoring: RegionAuthoring) -> void:
	var keys: Array[Dictionary] = authoring.bosque_places()
	var key_chunks: Array = []
	var seen: Array[Dictionary] = []
	for k: int in keys.size():
		key_chunks.append([] as Array[Vector2i])
		seen.append({})
	if not authoring.bosque.is_empty():
		for y: int in size_macro.y:
			for x: int in size_macro.x:
				var k: int = authoring.bosque[y * size_macro.x + x]
				if k < 0 or k >= keys.size():
					continue
				var c: Vector2i = WorldCoords.floor_div_v(Vector2i(x, y), WorldCoords.MACROS_PER_CHUNK)
				if not seen[k].has(c):
					seen[k][c] = true
					(key_chunks[k] as Array).append(c)
	var key_nujio: Array[Vector2i] = []
	for k: int in keys.size():
		var nujio: Vector2i = WorldCoords.floor_div_v(keys[k].cell, WorldCoords.MACROS_PER_CHUNK)
		key_nujio.append(nujio)
		if (key_chunks[k] as Array).is_empty():
			(key_chunks[k] as Array).append(nujio)
	var villa_chunks: Array[Vector2i] = []
	for p: Dictionary in _named_villas():
		villa_chunks.append(WorldCoords.floor_div_v(p.cell, WorldCoords.MACROS_PER_CHUNK))
	bosques = BosqueMap.build_planned(plan_seed, size_chunks, {
		"key_chunks": key_chunks,
		"key_nujio": key_nujio,
		"villa_chunks": villa_chunks,
		"home_chunk": home_chunk,
		"refuges": region.get("refuges", {}),
		"states": region.get("bosque_states", {}),
		"procedural_villa_chance": float(region.get("procedural_villa_chance", 0.0)),
		"aldeas": region.get("aldeas", {}),
		"painted_road_sides": _painted_road_sides(),
	})


## Villas con nombre del CSV: la natal primero y luego las demás en el orden del CSV.
func _named_villas() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for kind: String in ["villa_natal", "villa"]:
		for p: Dictionary in _places:
			if p.type == kind and in_macro(p.cell):
				out.append(p)
	return out


func _build_villas(region: Dictionary) -> void:
	var taken: Dictionary = {}
	for p: Dictionary in _named_villas():
		var chunk: Vector2i = WorldCoords.floor_div_v(p.cell, WorldCoords.MACROS_PER_CHUNK)
		taken[String(p.name)] = true
		_add_villa({ "id": String(p.id), "name": String(p.name), "kind": String(p.type), "chunk": chunk,
				"macro": p.cell, "bosque_id": bosques.bosque_at(chunk), "houses": 0 })
	var names: Array = []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(NAMES_PATH)) if FileAccess.file_exists(NAMES_PATH) else null
	if data is Dictionary:
		for name: Variant in (data as Dictionary).get("villas", []):
			if not taken.has(String(name)):
				names.append(String(name))
	var houses: Array = (region.get("aldeas", {}) as Dictionary).get("houses", DEFAULT_ALDEA_HOUSES)
	var lo: int = int(houses[0])
	var hi: int = maxi(lo, int(houses[1]))
	var half: int = WorldCoords.MACROS_PER_CHUNK / 2
	var k: int = 0
	for id: int in bosques.count():
		if not bosques.has_aldea[id]:
			continue
		k += 1
		var chunk: Vector2i = bosques.nujio_chunk[id]
		var name: String = ""
		if not names.is_empty():
			var at: int = ChunkGenerator.hash_ints([plan_seed, id, SALT_ALDEA_NAME]) % names.size()
			name = names[at]
			names.remove_at(at)
		_add_villa({ "id": "aldea_%d" % k, "name": name, "kind": "aldea", "chunk": chunk,
				"macro": chunk * WorldCoords.MACROS_PER_CHUNK + Vector2i(half, half), "bosque_id": id,
				"houses": lo + ChunkGenerator.hash_ints([plan_seed, id, SALT_ALDEA_HOUSES]) % (hi - lo + 1) })


func _add_villa(v: Dictionary) -> void:
	if not _villa_at.has(v.chunk):
		_villa_at[v.chunk] = _villas.size()
	_villas.append(v)


# --- Puertas -----------------------------------------------------------------------------------

## 1) Borde con camino: puerta de camino (donde cruza el pintado o, si es de la red, por hash).
## 2) Si no, puerta de sendero con DOOR_PERCENT %. 3) Por Bosque, Kruskal sobre sus bordes
## interiores: las puertas abiertas unen y los bordes cerrados, en orden de hash, se abren solo
## si unen dos partes aún separadas. Así todo Bosque se recorre a pie de puerta en puerta.
func _build_doors() -> void:
	for axis: int in 2:
		for cy: int in size_chunks.y:
			for cx: int in size_chunks.x:
				var edge := Vector3i(cx, cy, axis)
				if not is_inner_edge(edge):
					continue
				var a := Vector2i(cx, cy)
				var side: Vector2i = Vector2i.LEFT if axis == 0 else Vector2i.UP
				if bosques.road_sides(a).has(side):
					_doors[edge] = _make_door(edge, true, false)
				elif ChunkGenerator.hash_ints([plan_seed, edge.x, edge.y, edge.z, SALT_DOOR_OPEN]) % 100 < DOOR_PERCENT:
					_doors[edge] = _make_door(edge, false, false)
	for id: int in bosques.count():
		var chunks: Array[Vector2i] = bosques.chunks_of(id)
		var parent: Dictionary = {}
		for c: Vector2i in chunks:
			parent[c] = c
		var closed: Array[Vector3i] = []
		for c: Vector2i in chunks:
			for side: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				if bosques.bosque_at(c + side) != id:
					continue
				var edge: Vector3i = edge_of(c, side)
				if _doors.has(edge):
					_union(parent, c, c + side)
				else:
					closed.append(edge)
		var weight: Dictionary = {}
		for e: Vector3i in closed:
			weight[e] = ChunkGenerator.hash_ints([plan_seed, e.x, e.y, e.z, SALT_DOOR_TREE])
		closed.sort_custom(func(p: Vector3i, q: Vector3i) -> bool: return weight[p] < weight[q] or (weight[p] == weight[q] and p < q))
		for e: Vector3i in closed:
			var a := Vector2i(e.x, e.y)
			var b: Vector2i = a + (Vector2i.LEFT if e.z == 0 else Vector2i.UP)
			if _find(parent, a) != _find(parent, b):
				_union(parent, a, b)
				_doors[e] = _make_door(e, false, true)


static func _find(parent: Dictionary, c: Vector2i) -> Vector2i:
	var root: Vector2i = c
	while parent[root] != root:
		root = parent[root]
	while parent[c] != root:
		var next: Vector2i = parent[c]
		parent[c] = root
		c = next
	return root


static func _union(parent: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var ra: Vector2i = _find(parent, a)
	var rb: Vector2i = _find(parent, b)
	if ra < rb:
		parent[rb] = ra
	elif rb < ra:
		parent[ra] = rb


func _make_door(edge: Vector3i, road: bool, forced: bool) -> Dictionary:
	var width: int = ROAD_WIDTH if road else PATH_WIDTH
	var index: int
	if road and _crossings.has(edge):
		# Donde cruza el camino pintado: centrado en su celda gruesa.
		index = clampi(int(_crossings[edge]) * WorldCoords.MACRO + (WorldCoords.MACRO - width) / 2, 0, WorldCoords.CHUNK - width)
	else:
		index = _hashed_door_index(edge, width)
	return { "index": index, "width": width, "road": road, "forced": forced }


## Posición por hash del borde, dentro de DOOR_MARGIN de las esquinas. Si cae en una cumbre o en
## agua honda a algún lado del borde, prueba las siguientes en orden; si no hay ninguna buena, se
## queda la primera (el ChunkBuilder pondrá un puente).
func _hashed_door_index(edge: Vector3i, width: int) -> int:
	var span: int = WorldCoords.CHUNK - 2 * DOOR_MARGIN - width + 1
	var start: int = ChunkGenerator.hash_ints([plan_seed, edge.x, edge.y, edge.z, SALT_DOOR]) % span
	for k: int in span:
		var index: int = DOOR_MARGIN + (start + k) % span
		if _door_fits(edge, index, width):
			return index
	return DOOR_MARGIN + start


func _door_fits(edge: Vector3i, index: int, width: int) -> bool:
	var m: int = WorldCoords.MACROS_PER_CHUNK
	var k0: int = WorldCoords.floor_div(index, WorldCoords.MACRO)
	var k1: int = WorldCoords.floor_div(index + width - 1, WorldCoords.MACRO)
	for k: int in range(k0, k1 + 1):
		var a: Vector2i
		var b: Vector2i
		if edge.z == 0:
			a = Vector2i(edge.x * m - 1, edge.y * m + k)
			b = Vector2i(edge.x * m, edge.y * m + k)
		else:
			a = Vector2i(edge.x * m + k, edge.y * m - 1)
			b = Vector2i(edge.x * m + k, edge.y * m)
		for c: Vector2i in [a, b]:
			if level_at(c) == LEVEL_PEAK or _is_deep(water_at(c)):
				return false
	return true


# --- Subregiones y sicabis ---------------------------------------------------------------------

## Subregión de cada chunk. Con el bloque `subregions` de la región ([{ id, name, rects: [[x, y,
## w, h], ...] }] en chunks; el primero que contiene el chunk manda), esa. Los chunks que no cubre
## ninguno, y toda la región si no hay bloque, usan el área de su Bosque (BosqueMap, ADR 0007),
## como subregión "area_<n>".
func _build_subregions(region: Dictionary) -> void:
	var n: int = size_chunks.x * size_chunks.y
	_subregion.resize(n)
	_subregion.fill(-1)
	for entry: Variant in region.get("subregions", []):
		if not entry is Dictionary:
			continue
		var index: int = _subregion_names.size()
		_subregion_names.append(String((entry as Dictionary).get("id", "subregion_%d" % index)))
		for r: Variant in (entry as Dictionary).get("rects", []):
			var a: Array = r
			if a.size() < 4:
				continue
			for y: int in range(int(a[1]), int(a[1]) + int(a[3])):
				for x: int in range(int(a[0]), int(a[0]) + int(a[2])):
					if _in_chunks(Vector2i(x, y)) and _subregion[y * size_chunks.x + x] < 0:
						_subregion[y * size_chunks.x + x] = index
	var area_base: int = _subregion_names.size()
	var used_area: bool = false
	for y: int in size_chunks.y:
		for x: int in size_chunks.x:
			var i: int = y * size_chunks.x + x
			if _subregion[i] >= 0:
				continue
			var id: int = bosques.bosque_at(Vector2i(x, y))
			var area: int = bosques.area_of[id] if id >= 0 and id < bosques.area_of.size() else 0
			_subregion[i] = area_base + maxi(area, 0)
			used_area = true
	if used_area:
		for a: int in maxi(bosques.area_count, 1):
			_subregion_names.append("area_%d" % a)


## Reparto de sicabis (lugares-e-interiores.md, "Cómo se encuentran en el mundo"): primero las del
## CSV (tipo `sicabi`), que cuentan para el tope de su subregión; después, en orden de hash, cada
## subregión por debajo del tope tiene una con probabilidad subregion_chance, en un chunk (por
## hash) que cumple sicabi_chunk_ok. Si no hay ninguno, la subregión se queda sin sicabi. Las
## villas y las aldeas ya están puestas: la sicabi es la que se aparta. El sitio exacto (bosque
## tupido o risco) lo busca el ChunkBuilder; si no lo encuentra, ese chunk se queda sin entrada.
func _build_sicabis(region: Dictionary) -> void:
	var params: Dictionary = DEFAULT_SICABIS.merged(region.get("sicabis", {}), true)
	var cap: int = int(params.per_subregion_max)
	var per_sub: Dictionary = {}
	for p: Dictionary in _places:
		if p.type != "sicabi" or not in_macro(p.cell):
			continue
		var chunk: Vector2i = WorldCoords.floor_div_v(p.cell, WorldCoords.MACROS_PER_CHUNK)
		if _sicabi_at.has(chunk):
			continue
		var sub: int = subregion_of(chunk)
		per_sub[sub] = int(per_sub.get(sub, 0)) + 1
		_add_sicabi({ "id": String(p.id), "chunk": chunk, "subregion": sub, "csv": true, "macro": p.cell })
	var chance: float = float(params.subregion_chance)
	if chance <= 0.0 or cap <= 0:
		return
	var subs: Array[int] = []
	var order: Dictionary = {}
	for s: int in _subregion_names.size():
		subs.append(s)
		order[s] = ChunkGenerator.hash_ints([plan_seed, s, SALT_SICABI_ORDER])
	subs.sort_custom(func(a: int, b: int) -> bool: return order[a] < order[b] or (order[a] == order[b] and a < b))
	var by_sub: Dictionary = {}
	for y: int in size_chunks.y:
		for x: int in size_chunks.x:
			var s: int = subregion_of(Vector2i(x, y))
			if not by_sub.has(s):
				by_sub[s] = []
			(by_sub[s] as Array).append(Vector2i(x, y))
	var k: int = 0
	for s: int in subs:
		var placed: int = int(per_sub.get(s, 0))
		while placed < cap:
			if ChunkGenerator.hash_ints([plan_seed, s, placed, SALT_SICABI_ROLL]) % 1000 >= int(chance * 1000.0):
				break
			var cands: Array = []
			var weight: Dictionary = {}
			for c: Vector2i in by_sub.get(s, []):
				if sicabi_chunk_ok(c, params):
					cands.append(c)
					weight[c] = ChunkGenerator.hash_ints([plan_seed, c.x, c.y, SALT_SICABI_CHUNK])
			if cands.is_empty():
				break
			cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return weight[a] < weight[b] or (weight[a] == weight[b] and a < b))
			k += 1
			_add_sicabi({ "id": "sicabi_%d" % k, "chunk": cands[0], "subregion": s, "csv": false })
			placed += 1


## El chunk puede tener sicabi: lejos de villas, aldeas y otras sicabis, y no en un Bosque muerto.
func sicabi_chunk_ok(chunk: Vector2i, params: Dictionary) -> bool:
	if _sicabi_at.has(chunk):
		return false
	var id: int = bosques.bosque_at(chunk)
	if not bool(params.allow_dead_bosque) and id >= 0 and bosques.state_of(id) == BosqueMap.STATE_MUERTO:
		return false
	var dv: int = int(params.min_villa_distance_chunks)
	for v: Dictionary in _villas:
		var c: Vector2i = v.chunk
		if maxi(absi(c.x - chunk.x), absi(c.y - chunk.y)) < dv:
			return false
	var ds: int = int(params.min_sicabi_distance_chunks)
	for other: Dictionary in _sicabis:
		var c: Vector2i = other.chunk
		if maxi(absi(c.x - chunk.x), absi(c.y - chunk.y)) < ds:
			return false
	return true


func _add_sicabi(s: Dictionary) -> void:
	_sicabi_at[s.chunk] = _sicabis.size()
	_sicabis.append(s)
