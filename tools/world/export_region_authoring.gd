extends SceneTree
## Exporta las PNG iniciales de autoría de una región desde el generador actual (ADR 0014 §4,
## "Punto de partida"), para que el dueño retoque algo en vez de pintar sobre un lienzo vacío.
## Uso: bash tools/world/export_region_authoring.sh [region_id] [seed] [--force]
## Si la región ya tiene agua.png (autoría pintada) no escribe nada salvo con --force.
## - Escala: el generador actual usa chunks de 64 tiles y la autoría, de 80 (20 celdas gruesas de
##   4 tiles). Cada celda gruesa (mx, my) se muestrea en (mx * 4 + 2) * 64 / 80, así que montañas,
##   río y caminos caen en el mismo chunk que hoy.
## - altura.png: ChunkGenerator.Terrain.elevation cuantizada en 4 niveles (umbrales del spike
##   -0.1 / 0.32 / 0.62, sin celdas sueltas) y cumbre donde los riscos (CLIFF) cubren casi toda la
##   celda, en grupos de PEAK_MIN_GROUP celdas o más.
## - agua.png: el río principal (sin los arroyos de montaña, que siguen siendo procedurales), con
##   sus vados.
## - caminos.png y lugares.csv: la red de caminos y las villas de la seed de referencia (la
##   primera seed cuya villa natal cae en start_chunk, o la que se pase). La villa natal
##   sustituye a start_chunk; las demás villas llevan el nombre provisional de esa seed.
## - bosques.png: vacía (hoy no hay Bosques clave).
## Determinista: misma región y seed = mismos archivos.

const HEIGHT_THRESHOLDS: Array[float] = [-0.1, 0.32, 0.62]
## Fracción de la celda gruesa cubierta de CLIFF para pintarla como cumbre.
const PEAK_COVER: float = 0.75
const PEAK_MIN_GROUP: int = 3
const SEED_SEARCH: int = 2000
## Nombres provisionales de villa (los de los letreros; Signpost.NAMES_PATH y SALT_VILLA_NAME).
const VILLA_NAMES_PATH: String = "res://data/text/nombres_villas.json"
const SALT_VILLA_NAME: int = 31
# ponytail: mover a WorldCoords (M4)
const NEW_CHUNK_TILES: int = 80


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var force: bool = args.has("--force")
	while args.has("--force"):
		args.remove_at(args.find("--force"))
	var region_id: StringName = StringName(args[0]) if args.size() > 0 else &"valle_del_sara"
	var region: Dictionary = ChunkGenerator.load_region(region_id)
	if region.is_empty():
		printerr("No existe la región %s" % region_id)
		quit(1)
		return
	var seed_value: int = args[1].to_int() if args.size() > 1 else _reference_seed(region)
	var dir: String = "res://data/world/regions/%s/" % region_id
	# La autoría ya pintada (p. ej. los afluentes del Sara) no se pisa sin pedirlo (autoria.md §8).
	if not force and FileAccess.file_exists(dir + "agua.png"):
		printerr("%s ya tiene autoría pintada (agua.png con trazos a mano o por script). Exportar la sobrescribe; si de verdad quieres empezar de cero, añade --force." % dir)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var exported: Dictionary = export_region(region, seed_value)
	for file: String in ["altura.png", "agua.png", "caminos.png", "bosques.png"]:
		var err: int = (exported[file] as Image).save_png(ProjectSettings.globalize_path(dir + file))
		if err != OK:
			printerr("No se pudo escribir %s (%d)" % [dir + file, err])
			quit(1)
			return
	var f := FileAccess.open(dir + "lugares.csv", FileAccess.WRITE)
	f.store_string(exported["lugares.csv"])
	f.close()
	print("Exportada %s con la seed %d en %s (%d×%d px)." % [region_id, seed_value, dir,
			(exported["altura.png"] as Image).get_width(), (exported["altura.png"] as Image).get_height()])
	var check := RegionAuthoring.load_dir(dir)
	for e: String in check.errors:
		printerr("  " + e)
	quit(0 if check.is_valid() else 1)


## Primera seed (desde 1) cuya villa natal (el Nujio del Bosque de start_chunk) está en start_chunk.
static func _reference_seed(region: Dictionary) -> int:
	var start: Vector2i = ChunkGenerator.region_start_chunk(region)
	for s: int in range(1, SEED_SEARCH):
		var map := BosqueMap.for_region(s, region)
		if map.nujio_chunk[map.home_bosque] == start:
			return s
	return 1


## Archivo -> Image (o String para lugares.csv).
static func export_region(region: Dictionary, seed_value: int) -> Dictionary:
	var chunks: Vector2i = ChunkGenerator.region_size(region)
	var old: int = ChunkData.SIZE
	var size := Vector2i(chunks.x * RegionAuthoring.CHUNK_MACRO, chunks.y * RegionAuthoring.CHUNK_MACRO)
	var scale: float = float(old) / NEW_CHUNK_TILES
	var terrain := ChunkGenerator.Terrain.new(seed_value, region)
	var map := BosqueMap.for_region(seed_value, region)
	var palette: Dictionary = RegionAuthoring.load_palette()

	# Tiles del generador actual (con caminos, puentes y villas tallados).
	var tiles_w: int = chunks.x * old
	var tiles := PackedByteArray()
	tiles.resize(tiles_w * chunks.y * old)
	for cy: int in chunks.y:
		for cx: int in chunks.x:
			var chunk: ChunkData = ChunkGenerator.generate(seed_value, Vector2i(cx, cy), region, map)
			for y: int in old:
				for x: int in old:
					tiles[(cy * old + y) * tiles_w + cx * old + x] = chunk.tiles[y * old + x]

	var n: int = size.x * size.y
	var height := PackedByteArray()
	var water := PackedByteArray()
	var road := PackedByteArray()
	height.resize(n)
	water.resize(n)
	road.resize(n)
	var bridge_tile := PackedByteArray()
	bridge_tile.resize(n)
	var peak := PackedByteArray()
	peak.resize(n)
	var macro: float = RegionAuthoring.MACRO_TILES * scale
	for my: int in size.y:
		var ty0: int = floori(my * macro)
		var ty1: int = mini(ceili((my + 1) * macro), chunks.y * old) - 1
		var ford_row: bool = false
		for ty: int in range(ty0, ty1 + 1):
			ford_row = ford_row or terrain.is_ford_row(ty)
		for mx: int in size.x:
			var i: int = my * size.x + mx
			var tx0: int = floori(mx * macro)
			var tx1: int = mini(ceili((mx + 1) * macro), tiles_w) - 1
			var fx: float = (mx * RegionAuthoring.MACRO_TILES + RegionAuthoring.MACRO_TILES * 0.5) * scale
			var fy: float = (my * RegionAuthoring.MACRO_TILES + RegionAuthoring.MACRO_TILES * 0.5) * scale
			var e: float = terrain.elevation(fx, fy)
			var level: int = 0
			for t: float in HEIGHT_THRESHOLDS:
				if e >= t:
					level += 1
			height[i] = RegionAuthoring.Height.LEVEL_0 + level
			var river: bool = false
			var cliffs: int = 0
			var total: int = 0
			for ty: int in range(ty0, ty1 + 1):
				var span: Vector2i = terrain.river_span(ty)
				for tx: int in range(tx0, tx1 + 1):
					river = river or (tx >= span.x and tx <= span.y)
					var tile: int = tiles[ty * tiles_w + tx]
					total += 1
					if tile == ChunkData.Tile.CLIFF:
						cliffs += 1
					elif tile == ChunkData.Tile.ROAD:
						road[i] = RegionAuthoring.Road.ROAD
					elif tile == ChunkData.Tile.BRIDGE:
						bridge_tile[i] = 1
			if river:
				if ford_row:
					water[i] = RegionAuthoring.Water.FORD
				elif terrain.north_south(fy) >= float(terrain.rivers.navigable_from):
					water[i] = RegionAuthoring.Water.RIVER_NAVIGABLE
				else:
					water[i] = RegionAuthoring.Water.RIVER_NARROW
			elif cliffs >= total * PEAK_COVER:
				peak[i] = 1
	_remove_lone_levels(height, size)
	_keep_peak_groups(height, peak, size)
	_mark_bridges(road, water, bridge_tile, size)

	var out: Dictionary = {}
	out["altura.png"] = _paint(height, size, palette, "height")
	out["agua.png"] = _paint(water, size, palette, "water")
	out["caminos.png"] = _paint(road, size, palette, "roads")
	var empty := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	out["bosques.png"] = empty
	out["lugares.csv"] = _places_csv(map, region, seed_value)
	return out


## Sin celdas sueltas: una celda de nivel sin ningún vecino ortogonal de su nivel toma el nivel
## más común de sus vecinos (en empate, el más bajo). Las cumbres no cambian.
static func _remove_lone_levels(height: PackedByteArray, size: Vector2i) -> void:
	var src: PackedByteArray = height.duplicate()
	for y: int in size.y:
		for x: int in size.x:
			var h: int = src[y * size.x + x]
			if h == RegionAuthoring.Height.PEAK:
				continue
			var counts: Dictionary = {}
			var alone: bool = true
			for d: Vector2i in ChunkData.SIDES:
				var c := Vector2i(x, y) + d
				if c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y:
					continue
				var nh: int = src[c.y * size.x + c.x]
				if nh == h:
					alone = false
				elif nh != RegionAuthoring.Height.PEAK:
					counts[nh] = int(counts.get(nh, 0)) + 1
			if not alone or counts.is_empty():
				continue
			var best: int = h
			var best_n: int = 0
			for k: int in counts:
				if counts[k] > best_n or (counts[k] == best_n and k < best):
					best = k
					best_n = counts[k]
			height[y * size.x + x] = best


## Cumbres: solo los grupos (4-conectados) de PEAK_MIN_GROUP celdas o más; las sueltas son
## riscos que el generador ya pone con su ruido.
static func _keep_peak_groups(height: PackedByteArray, peak: PackedByteArray, size: Vector2i) -> void:
	var seen := PackedByteArray()
	seen.resize(peak.size())
	for start: int in peak.size():
		if peak[start] == 0 or seen[start] == 1:
			continue
		var group: Array[int] = [start]
		seen[start] = 1
		var head: int = 0
		while head < group.size():
			var c := Vector2i(group[head] % size.x, group[head] / size.x)
			head += 1
			for d: Vector2i in ChunkData.SIDES:
				var nc: Vector2i = c + d
				if nc.x < 0 or nc.y < 0 or nc.x >= size.x or nc.y >= size.y:
					continue
				var j: int = nc.y * size.x + nc.x
				if peak[j] == 1 and seen[j] == 0:
					seen[j] = 1
					group.append(j)
		if group.size() >= PEAK_MIN_GROUP:
			for i: int in group:
				height[i] = RegionAuthoring.Height.PEAK


## Camino sobre río = puente; y los puentes del generador pegados a un camino o a otro puente
## también (un puente de varias celdas sobre un río ancho).
static func _mark_bridges(road: PackedByteArray, water: PackedByteArray, bridge_tile: PackedByteArray, size: Vector2i) -> void:
	var is_river := func(w: int) -> bool:
		return w == RegionAuthoring.Water.RIVER_NARROW or w == RegionAuthoring.Water.RIVER_NAVIGABLE
	for i: int in road.size():
		if road[i] == RegionAuthoring.Road.ROAD and is_river.call(water[i]):
			road[i] = RegionAuthoring.Road.BRIDGE
	var changed: bool = true
	while changed:
		changed = false
		for y: int in size.y:
			for x: int in size.x:
				var i: int = y * size.x + x
				if road[i] != RegionAuthoring.Road.NONE or bridge_tile[i] == 0 or not is_river.call(water[i]):
					continue
				for d: Vector2i in ChunkData.SIDES:
					var c := Vector2i(x, y) + d
					if c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y and road[c.y * size.x + c.x] != RegionAuthoring.Road.NONE:
						road[i] = RegionAuthoring.Road.BRIDGE
						changed = true
						break


static func _paint(codes: PackedByteArray, size: Vector2i, palette: Dictionary, layer: String) -> Image:
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var keys: Array[String] = RegionAuthoring.layer_keys(layer)
	for y: int in size.y:
		for x: int in size.x:
			var code: int = codes[y * size.x + x]
			if code > 0:
				img.set_pixel(x, y, RegionAuthoring.palette_color(palette, layer, keys[code]))
	return img


## Igual que Signpost.villa_name (no se puede usar desde -s: depende de autoloads).
static func _villa_name(seed_value: int, bosque_id: int) -> String:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VILLA_NAMES_PATH))
	var names: Array = data.villas
	return str(names[ChunkGenerator.hash_ints([seed_value, bosque_id, SALT_VILLA_NAME]) % names.size()])


static func _places_csv(map: BosqueMap, region: Dictionary, seed_value: int) -> String:
	var home: int = map.home_bosque
	var lines: PackedStringArray = [",".join(RegionAuthoring.CSV_COLUMNS)]
	var center: int = RegionAuthoring.CHUNK_MACRO / 2
	var order: Array[int] = [home]
	for b: int in map.count():
		if b != home and map.has_villa[b] and map.has_nujio(b):
			order.append(b)
	var k: int = 1
	for b: int in order:
		var c: Vector2i = map.nujio_chunk[b] * RegionAuthoring.CHUNK_MACRO + Vector2i(center, center)
		var natal: bool = b == home
		var id: String = "villa_natal" if natal else "villa_%d" % k
		var notes: String = ("Exportada del generador (seed %d). Sustituye a start_chunk." % seed_value) if natal \
				else "Exportada del generador (seed %d) con su nombre provisional: ponle nombre, muévela o bórrala." % seed_value
		lines.append(",".join([id, _villa_name(seed_value, b), "villa_natal" if natal else "villa",
				str(c.x), str(c.y), "", "", "\"%s\"" % notes]))
		if not natal:
			k += 1
	return "\n".join(lines) + "\n"
