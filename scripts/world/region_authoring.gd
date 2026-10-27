class_name RegionAuthoring
extends RefCounted
## Autoría a mano de una región (ADR 0014 §4): lee las PNG por capas y la tabla de lugares que
## pinta el dueño en `data/world/regions/<id>/` y las valida.
## - Capas: altura.png, agua.png, caminos.png y bosques.png. Todas del mismo tamaño; 1 px = 1
##   celda gruesa (`macro`, 4×4 tiles) y un chunk son 20×20 px. El tamaño de la región sale de
##   la imagen.
## - Colores exactos de `data/world/authoring_palette.json`; los de bosques.png, de la columna
##   `color` de lugares.csv. Transparente (alfa 0) = sin pintar: decide el generador.
## - lugares.csv: id,nombre,tipo,x,y,color,estilo,notas, con x,y en píxeles de las PNG. La
##   villa natal sustituye a `start_chunk`.
## - Validación: colores desconocidos con coordenadas (suavizado), PNG de tamaños distintos,
##   lugares fuera del mapa, en el agua o en una cumbre, Bosques clave fuera de 4–16 chunks,
##   ríos que se cortan y villas sin acceso a pie (sobre la rejilla gruesa). Errores en español.
## - Una `ciudad` (Umun Mal) es una villa que ocupa su chunk entero: en tierra, con acceso a pie y
##   sin otra villa, villa natal ni ciudad en su chunk.
## - Un río une dos sitios: bordes del mapa, lago, mar, cumbre o un `manantial` (lugar de
##   lugares.csv en nivel 2 o 3, junto al río: nace en la montaña sin cumbre ni borde).
## Clase pura: no genera nada. La pasada de región (RegionPlan, M5) la consume; no la modifica.

const PALETTE_PATH: String = "res://data/world/authoring_palette.json"
const REGION_DIR: String = "res://data/world/regions/"
const PLACES_FILE: String = "lugares.csv"
# ponytail: mover a WorldCoords (M4)
## Tiles por lado de una celda gruesa (1 px de autoría).
const MACRO_TILES: int = 4
# ponytail: mover a WorldCoords (M4)
## Celdas gruesas (px de autoría) por lado de un chunk de 80 tiles.
const CHUNK_MACRO: int = 20
## Errores de color que se listan por capa; del resto solo se da el total.
const MAX_COLOR_ERRORS: int = 12

## Capas en orden de lectura: clave de la paleta.
const LAYERS: Array[String] = ["height", "water", "roads", "bosques"]
enum Height { NONE, LEVEL_0, LEVEL_1, LEVEL_2, LEVEL_3, PEAK }
enum Water { NONE, RIVER_NAVIGABLE, RIVER_NARROW, LAKE, SEA, FORD }
enum Road { NONE, ROAD, BRIDGE }
const PLACE_TYPES: Array[String] = ["villa", "villa_natal", "hito", "tarca", "bosque", "lugar", "manantial", "sicabi", "ciudad"]
## Tipos de lugar que son una villa (con Nujio, plaza y casas). La `ciudad` ocupa su chunk entero.
const VILLA_TYPES: Array[String] = ["villa_natal", "villa", "ciudad"]
const CSV_COLUMNS: Array[String] = ["id", "nombre", "tipo", "x", "y", "color", "estilo", "notas"]
const CSV_REQUIRED: Array[String] = ["id", "nombre", "tipo", "x", "y"]

## Tamaño de las PNG en píxeles (celdas gruesas).
var size_px: Vector2i = Vector2i.ZERO
## Por celda gruesa (fila a fila): valores de Height, Water y Road.
var height: PackedByteArray = PackedByteArray()
var water: PackedByteArray = PackedByteArray()
var roads: PackedByteArray = PackedByteArray()
## Por celda gruesa: índice en bosque_places() del Bosque clave pintado, o -1.
var bosque: PackedInt32Array = PackedInt32Array()
## Capa -> la PNG existe. Si falta agua.png, el generador usa el río procedural (ADR 0014 §5).
var has_layer: Dictionary = {}
## Lugares de lugares.csv: { id, name, type, cell: Vector2i, color: Color, style, notes, line }.
var places: Array[Dictionary] = []
## Errores legibles en español. Vacío = la autoría es válida.
var errors: Array[String] = []
## Celdas con error (para marcarlas en la vista previa).
var error_cells: Array[Vector2i] = []

var _palette: Dictionary = {}
var _bosque_places: Array[Dictionary] = []


## Autoría de la región `region_id`: su JSON indica la carpeta en la clave "authoring".
static func load_region(region_id: StringName) -> RegionAuthoring:
	var json_path: String = REGION_DIR + String(region_id) + ".json"
	var data: Variant = null
	if FileAccess.file_exists(json_path):
		data = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not data is Dictionary or not (data as Dictionary).has("authoring"):
		var empty := RegionAuthoring.new()
		empty._error("La región '%s' no tiene la clave \"authoring\" en %s." % [region_id, json_path])
		return empty
	return load_dir(REGION_DIR + String((data as Dictionary).authoring))


## Lee las PNG y lugares.csv de la carpeta `dir` (res:// o user://).
static func load_dir(dir: String, palette: Dictionary = {}) -> RegionAuthoring:
	if palette.is_empty():
		palette = load_palette()
	var images: Dictionary = {}
	var read_errors: Array[String] = []
	for layer: String in LAYERS:
		var path: String = dir.path_join(layer_file(palette, layer))
		if not FileAccess.file_exists(path):
			continue
		var img: Image = Image.load_from_file(path)
		if img == null or img.is_empty():
			read_errors.append("No se puede leer %s (¿es un PNG válido?)." % path)
			continue
		images[layer] = img
	var csv_path: String = dir.path_join(String(palette.get("places_file", PLACES_FILE)))
	var csv: String = FileAccess.get_file_as_string(csv_path) if FileAccess.file_exists(csv_path) else ""
	var out := from_sources(images, csv, palette)
	for e: String in read_errors:
		out.errors.push_front(e)
	return out


## Construye y valida desde imágenes ya cargadas (capa -> Image; faltan las capas sin PNG) y el
## texto de lugares.csv. Es lo que usan los tests.
static func from_sources(images: Dictionary, places_csv: String, palette: Dictionary = {}) -> RegionAuthoring:
	var out := RegionAuthoring.new()
	out._palette = palette if not palette.is_empty() else load_palette()
	out._parse_places(places_csv)
	if not out._read_size(images):
		return out
	out._decode_layers(images)
	out._validate_places()
	out._validate_bosques()
	out._validate_rivers()
	out._validate_villa_access()
	return out


static func load_palette() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PALETTE_PATH))
	return data if data is Dictionary else {}


## Nombre de archivo de una capa según la paleta (altura.png, agua.png...).
static func layer_file(palette: Dictionary, layer: String) -> String:
	return String(((palette.get("layers", {}) as Dictionary).get(layer, {}) as Dictionary).get("file", layer + ".png"))


## Color de la paleta para un valor de capa: layer "height" y key "level_0", por ejemplo.
static func palette_color(palette: Dictionary, layer: String, key: String) -> Color:
	var colors: Dictionary = ((palette.get("layers", {}) as Dictionary).get(layer, {}) as Dictionary).get("colors", {})
	return Color.html(String(colors[key])) if colors.has(key) else Color(0, 0, 0, 0)


## Clave de la paleta de cada valor de los enums (índice = valor; 0 = sin pintar).
static func layer_keys(layer: String) -> Array[String]:
	var names: Array = []
	match layer:
		"height":
			names = Height.keys()
		"water":
			names = Water.keys()
		"roads":
			names = Road.keys()
	var out: Array[String] = []
	for n: Variant in names:
		out.append(String(n).to_lower())
	return out


func is_valid() -> bool:
	return errors.is_empty()


## Tamaño de la región en chunks (redondeando hacia arriba).
func size_chunks() -> Vector2i:
	return Vector2i(ceili(size_px.x / float(CHUNK_MACRO)), ceili(size_px.y / float(CHUNK_MACRO)))


func in_map(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size_px.x and cell.y < size_px.y


static func chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(cell.x / float(CHUNK_MACRO)), floori(cell.y / float(CHUNK_MACRO)))


func height_at(cell: Vector2i) -> int:
	return height[_idx(cell)] if in_map(cell) and not height.is_empty() else Height.NONE


func water_at(cell: Vector2i) -> int:
	return water[_idx(cell)] if in_map(cell) and not water.is_empty() else Water.NONE


func road_at(cell: Vector2i) -> int:
	return roads[_idx(cell)] if in_map(cell) and not roads.is_empty() else Road.NONE


## Índice en bosque_places() del Bosque clave pintado en la celda, o -1.
func bosque_at(cell: Vector2i) -> int:
	return bosque[_idx(cell)] if in_map(cell) and not bosque.is_empty() else -1


## Lugares de tipo `bosque` (Bosques clave), en el orden del CSV.
func bosque_places() -> Array[Dictionary]:
	return _bosque_places


func places_of_type(type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in places:
		if p.type == type:
			out.append(p)
	return out


## La villa natal ({} si no hay). Sustituye a `start_chunk`.
func home_villa() -> Dictionary:
	var homes: Array[Dictionary] = places_of_type("villa_natal")
	return homes[0] if homes.size() == 1 else {}


## Chunk de la villa natal, o (-1, -1).
func home_chunk() -> Vector2i:
	var home: Dictionary = home_villa()
	return chunk_of(home.cell) if not home.is_empty() else Vector2i(-1, -1)


## La celda gruesa se puede cruzar a pie: no es cumbre y no es agua salvo vado, camino o puente.
func is_walkable(cell: Vector2i) -> bool:
	if not in_map(cell) or height_at(cell) == Height.PEAK:
		return false
	var w: int = water_at(cell)
	return w == Water.NONE or w == Water.FORD or road_at(cell) != Road.NONE


func _idx(cell: Vector2i) -> int:
	return cell.y * size_px.x + cell.x


func _error(text: String, cell: Vector2i = Vector2i(-1, -1)) -> void:
	errors.append(text)
	if cell.x >= 0:
		error_cells.append(cell)


static func _where(cell: Vector2i) -> String:
	var c: Vector2i = chunk_of(cell)
	return "(%d, %d) [chunk %d, %d]" % [cell.x, cell.y, c.x, c.y]


# --- Lectura -----------------------------------------------------------------------------------

func _read_size(images: Dictionary) -> bool:
	if images.is_empty():
		_error("No hay ninguna PNG de autoría (altura.png, agua.png, caminos.png o bosques.png): no se sabe el tamaño de la región.")
		return false
	var sizes: Dictionary = {}
	for layer: String in LAYERS:
		has_layer[layer] = images.has(layer)
		if images.has(layer):
			sizes[layer] = (images[layer] as Image).get_size()
	var first: Vector2i = sizes.values()[0]
	var same: bool = true
	for s: Vector2i in sizes.values():
		same = same and s == first
	if not same:
		var parts: PackedStringArray = []
		for layer: String in sizes:
			var s: Vector2i = sizes[layer]
			parts.append("%s %d×%d" % [layer_file(_palette, layer), s.x, s.y])
		_error("Las PNG tienen tamaños distintos (%s): todas tienen que medir lo mismo." % ", ".join(parts))
		return false
	size_px = first
	if size_px.x % CHUNK_MACRO != 0 or size_px.y % CHUNK_MACRO != 0:
		_error("Las PNG miden %d×%d px: cada lado tiene que ser múltiplo de %d (un chunk = %d×%d px)."
				% [size_px.x, size_px.y, CHUNK_MACRO, CHUNK_MACRO, CHUNK_MACRO])
	return true


func _decode_layers(images: Dictionary) -> void:
	var n: int = size_px.x * size_px.y
	height.resize(n)
	water.resize(n)
	roads.resize(n)
	height.fill(0)
	water.fill(0)
	roads.fill(0)
	bosque.resize(n)
	bosque.fill(-1)
	for layer: String in ["height", "water", "roads"]:
		if not images.has(layer):
			continue
		var colors: Dictionary = {}
		var keys: Array[String] = layer_keys(layer)
		for code: int in range(1, keys.size()):
			var c: Color = palette_color(_palette, layer, keys[code])
			if c.a > 0.0:
				colors[_rgb(c)] = code
		var codes: PackedInt32Array = _decode(layer, images[layer], colors)
		var target: PackedByteArray = height if layer == "height" else (water if layer == "water" else roads)
		for i: int in n:
			target[i] = maxi(codes[i], 0)
	if images.has("bosques"):
		var colors: Dictionary = {}
		for i: int in _bosque_places.size():
			colors[_rgb(_bosque_places[i].color)] = i + 1
		var codes: PackedInt32Array = _decode("bosques", images["bosques"], colors)
		for i: int in n:
			bosque[i] = codes[i] - 1 if codes[i] > 0 else -1


## Códigos por píxel: 0 = transparente, -1 = color desconocido (se informa), >0 = valor.
func _decode(layer: String, source: Image, colors: Dictionary) -> PackedInt32Array:
	var img: Image = source
	if img.get_format() != Image.FORMAT_RGBA8:
		img = source.duplicate() as Image
		img.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = img.get_data()
	var w: int = size_px.x
	var codes := PackedInt32Array()
	codes.resize(w * size_px.y)
	var bad: int = 0
	var file: String = layer_file(_palette, layer)
	for i: int in codes.size():
		var o: int = i * 4
		var a: int = data[o + 3]
		if a == 0:
			codes[i] = 0
			continue
		var rgb: int = (data[o] << 16) | (data[o + 1] << 8) | data[o + 2]
		if a == 255 and colors.has(rgb):
			codes[i] = colors[rgb]
			continue
		codes[i] = -1
		bad += 1
		if bad <= MAX_COLOR_ERRORS:
			var cell := Vector2i(i % w, i / w)
			var what: String = "color desconocido #%06x" % rgb if a == 255 else "píxel semitransparente (alfa %d)" % a
			_error("%s: %s en %s." % [file, what, _where(cell)], cell)
	if bad > 0:
		_error(("%s: %d píxeles con colores que no están en la paleta%s. Suele ser el suavizado "
				+ "(antialiasing): pinta con lápiz de 1 px sin suavizado y solo con los colores de la paleta.")
				% [file, bad, " (arriba, los %d primeros)" % MAX_COLOR_ERRORS if bad > MAX_COLOR_ERRORS else ""])
	return codes


static func _rgb(c: Color) -> int:
	return (c.r8 << 16) | (c.g8 << 8) | c.b8


## Lee lugares.csv. Acepta coma o punto y coma (Excel en español), BOM, comillas y líneas en
## blanco o que empiezan por '#'.
func _parse_places(text: String) -> void:
	var rows: Array[PackedStringArray] = parse_csv(text)
	if rows.is_empty():
		return
	var header: PackedStringArray = rows[0]
	var col: Dictionary = {}
	for i: int in header.size():
		col[header[i].strip_edges().to_lower()] = i
	for column: String in CSV_REQUIRED:
		if not col.has(column):
			_error("%s: falta la columna '%s' en la cabecera (columnas: %s)." % [PLACES_FILE, column, ",".join(CSV_COLUMNS)])
			return
	var ids: Dictionary = {}
	for r: int in range(1, rows.size()):
		var row: PackedStringArray = rows[r]
		var line: int = r + 1
		var get_col := func(column: String) -> String:
			return row[col[column]].strip_edges() if col.has(column) and col[column] < row.size() else ""
		if "".join(row).strip_edges() == "" or String(row[0]).strip_edges().begins_with("#"):
			continue
		var id: String = get_col.call("id")
		var type: String = get_col.call("tipo").to_lower()
		var sx: String = get_col.call("x")
		var sy: String = get_col.call("y")
		var label: String = "%s, línea %d" % [PLACES_FILE, line]
		if id == "":
			_error("%s: falta el id." % label)
			continue
		if ids.has(id):
			_error("%s: el id '%s' está repetido (también en la línea %d)." % [label, id, ids[id]])
			continue
		ids[id] = line
		if not PLACE_TYPES.has(type):
			_error("%s: '%s' tiene un tipo desconocido '%s' (tipos: %s)." % [label, id, type, ", ".join(PLACE_TYPES)])
			continue
		if not sx.is_valid_int() or not sy.is_valid_int():
			_error("%s: '%s' necesita x e y enteros en píxeles (tiene x='%s', y='%s')." % [label, id, sx, sy])
			continue
		var place: Dictionary = {
			"id": id, "name": get_col.call("nombre"), "type": type,
			"cell": Vector2i(sx.to_int(), sy.to_int()), "color": Color(0, 0, 0, 0),
			"style": get_col.call("estilo"), "notes": get_col.call("notas"), "line": line,
		}
		if type == "bosque":
			var hex: String = get_col.call("color")
			if not hex.begins_with("#") or hex.length() != 7 or not Color.html_is_valid(hex):
				_error("%s: el Bosque '%s' necesita un color #RRGGBB en la columna color (tiene '%s')." % [label, id, hex])
				continue
			place.color = Color.html(hex)
			for other: Dictionary in _bosque_places:
				if _rgb(other.color) == _rgb(place.color):
					_error("%s: el Bosque '%s' usa el mismo color %s que '%s'." % [label, id, hex, other.id])
			_bosque_places.append(place)
		places.append(place)


## CSV sencillo: separador ',' o ';' (el que aparezca en la cabecera), comillas dobles con ""
## escapado y saltos de línea dentro de comillas.
static func parse_csv(text: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	if text.begins_with("﻿"):
		text = text.substr(1)
	var first_line: String = text.get_slice("\n", 0)
	var sep: String = ";" if first_line.count(";") > first_line.count(",") else ","
	var row := PackedStringArray()
	var field: String = ""
	var quoted: bool = false
	var i: int = 0
	while i < text.length():
		var ch: String = text[i]
		if quoted:
			if ch == "\"":
				if i + 1 < text.length() and text[i + 1] == "\"":
					field += "\""
					i += 1
				else:
					quoted = false
			else:
				field += ch
		elif ch == "\"":
			quoted = true
		elif ch == sep:
			row.append(field)
			field = ""
		elif ch == "\n":
			row.append(field)
			rows.append(row)
			row = PackedStringArray()
			field = ""
		elif ch != "\r":
			field += ch
		i += 1
	if field != "" or not row.is_empty():
		row.append(field)
		rows.append(row)
	return rows


# --- Validación --------------------------------------------------------------------------------

func _validate_places() -> void:
	var homes: Array[Dictionary] = places_of_type("villa_natal")
	if homes.is_empty():
		_error("%s: falta la villa natal (una fila con tipo villa_natal; sustituye a start_chunk)." % PLACES_FILE)
	elif homes.size() > 1:
		_error("%s: hay %d villas natales; tiene que haber una sola." % [PLACES_FILE, homes.size()])
	var water_names: Array[String] = ["", "un río navegable", "un río estrecho", "un lago", "el mar", "un vado"]
	for p: Dictionary in places:
		var cell: Vector2i = p.cell
		var label: String = "%s, línea %d: '%s'" % [PLACES_FILE, p.line, p.id]
		if not in_map(cell):
			_error("%s está fuera del mapa en (%d, %d); el mapa mide %d×%d px (x de 0 a %d, y de 0 a %d)."
					% [label, cell.x, cell.y, size_px.x, size_px.y, size_px.x - 1, size_px.y - 1])
			continue
		var w: int = water_at(cell)
		if w != Water.NONE:
			_error("%s está en el agua (%s) en %s." % [label, water_names[w], _where(cell)], cell)
		if height_at(cell) == Height.PEAK:
			_error("%s está en una cumbre en %s." % [label, _where(cell)], cell)
		elif p.type == "manantial":
			var h: int = height_at(cell)
			if has_layer.get("height", false) and h != Height.LEVEL_2 and h != Height.LEVEL_3:
				_error("%s: un manantial tiene que estar en la montaña (nivel 2 o 3) en %s." % [label, _where(cell)], cell)
			var touches: bool = false
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				touches = touches or _is_river(water_at(cell + d))
			if has_layer.get("water", false) and not touches:
				_error("%s: el manantial no toca ningún río (pon el río pegado a él, por un lado) en %s." % [label, _where(cell)], cell)
	_validate_cities()


## Una ciudad ocupa su chunk entero: ninguna otra villa, villa natal ni ciudad en ese chunk.
func _validate_cities() -> void:
	for p: Dictionary in places_of_type("ciudad"):
		if not in_map(p.cell):
			continue
		var chunk: Vector2i = chunk_of(p.cell)
		for other: Dictionary in places:
			if other == p or not VILLA_TYPES.has(String(other.type)) or not in_map(other.cell):
				continue
			if chunk_of(other.cell) == chunk:
				_error("%s, línea %d: la ciudad '%s' ocupa el chunk %s entero y ahí está también '%s' (%s, línea %d): muévela a otro chunk."
						% [PLACES_FILE, p.line, p.id, chunk, other.id, other.type, other.line], p.cell)


## Bosques clave: cada uno ocupa los chunks donde está pintado su color (o, si no se pinta, el
## chunk de su Nujio). Contiguos, sin compartir chunk con otro y de 4–16 chunks; si tiene menos
## de 4, tiene que haber chunks libres alrededor para que el generador lo extienda.
func _validate_bosques() -> void:
	if _bosque_places.is_empty():
		return
	var owner: Dictionary = {}  # chunk -> índice de Bosque
	var chunks: Array[Dictionary] = []  # por Bosque: chunk -> true
	for i: int in _bosque_places.size():
		chunks.append({})
	var reported: Dictionary = {}
	for y: int in size_px.y:
		for x: int in size_px.x:
			var b: int = bosque[y * size_px.x + x]
			if b < 0:
				continue
			var c: Vector2i = chunk_of(Vector2i(x, y))
			chunks[b][c] = true
			if owner.has(c) and owner[c] != b and not reported.has(c):
				reported[c] = true
				_error("bosques.png: el chunk (%d, %d) tiene dos Bosques, '%s' y '%s'; cada chunk es de un solo Bosque."
						% [c.x, c.y, _bosque_places[owner[c]].id, _bosque_places[b].id], Vector2i(x, y))
			elif not owner.has(c):
				owner[c] = b
	for i: int in _bosque_places.size():
		var p: Dictionary = _bosque_places[i]
		var own: Dictionary = chunks[i]
		if not in_map(p.cell):
			continue
		if own.is_empty():
			own[chunk_of(p.cell)] = true
			if owner.has(chunk_of(p.cell)):
				_error("%s, línea %d: el Nujio de '%s' en %s cae en el Bosque '%s'."
						% [PLACES_FILE, p.line, p.id, _where(p.cell), _bosque_places[owner[chunk_of(p.cell)]].id], p.cell)
				continue
			owner[chunk_of(p.cell)] = i
		elif bosque_at(p.cell) != i:
			_error("%s, línea %d: el Nujio de '%s' en %s está fuera de su color en bosques.png."
					% [PLACES_FILE, p.line, p.id, _where(p.cell)], p.cell)
		var n: int = own.size()
		var any: Vector2i = own.keys()[0]
		if n > BosqueMap.MAX_SIZE:
			_error("bosques.png: el Bosque '%s' ocupa %d chunks; el máximo es %d." % [p.id, n, BosqueMap.MAX_SIZE], any * CHUNK_MACRO)
		if _flood_chunks(any, func(c: Vector2i) -> bool: return own.has(c)).size() != n:
			_error("bosques.png: el Bosque '%s' está partido; sus chunks tienen que tocarse por un lado." % p.id, any * CHUNK_MACRO)
		elif n < BosqueMap.MIN_SIZE:
			var grid: Vector2i = size_chunks()
			var room: int = _flood_chunks(any, func(c: Vector2i) -> bool:
				return c.x >= 0 and c.y >= 0 and c.x < grid.x and c.y < grid.y and (not owner.has(c) or owner[c] == i)).size()
			if room < BosqueMap.MIN_SIZE:
				_error("bosques.png: el Bosque '%s' tiene %d chunks y no le caben %d (lo rodean otros Bosques o el borde)."
						% [p.id, n, BosqueMap.MIN_SIZE], any * CHUNK_MACRO)


func _flood_chunks(from: Vector2i, allowed: Callable) -> Dictionary:
	var seen: Dictionary = { from: true }
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not seen.has(n) and allowed.call(n):
				seen[n] = true
				queue.append(n)
	return seen


func _is_river(w: int) -> bool:
	return w == Water.RIVER_NAVIGABLE or w == Water.RIVER_NARROW or w == Water.FORD


## Un río (navegable, estrecho y sus vados, 4-conectado) tiene que tener al menos dos
## desembocaduras distintas: borde del mapa, lago, mar, cumbre o manantial (nacimiento). Si solo tiene una
## o ninguna, se corta: se señala la celda del río más lejana a su desembocadura.
func _validate_rivers() -> void:
	if not has_layer.get("water", false):
		return
	var w: int = size_px.x
	var seen := PackedByteArray()
	seen.resize(w * size_px.y)
	for start: int in seen.size():
		if seen[start] == 1 or not _is_river(water[start]):
			continue
		var comp: Array[Vector2i] = []
		var queue: Array[Vector2i] = [Vector2i(start % w, start / w)]
		seen[start] = 1
		while not queue.is_empty():
			var c: Vector2i = queue.pop_back()
			comp.append(c)
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = c + d
				if in_map(n) and seen[_idx(n)] == 0 and _is_river(water[_idx(n)]):
					seen[_idx(n)] = 1
					queue.append(n)
		var in_comp: Dictionary = {}
		for c: Vector2i in comp:
			in_comp[c] = true
		var mouths: Dictionary = {}
		for c: Vector2i in comp:
			if _is_mouth(c):
				mouths[c] = true
		var clusters: int = 0
		var clustered: Dictionary = {}
		for m: Vector2i in mouths:
			if clustered.has(m):
				continue
			clusters += 1
			var stack: Array[Vector2i] = [m]
			clustered[m] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				for dy: int in range(-1, 2):
					for dx: int in range(-1, 2):
						var n: Vector2i = c + Vector2i(dx, dy)
						if mouths.has(n) and not clustered.has(n):
							clustered[n] = true
							stack.append(n)
		if clusters >= 2:
			continue
		var end: Vector2i = _farthest(comp[0] if mouths.is_empty() else mouths.keys()[0], in_comp)
		_error("agua.png: el río se corta en %s. Un río tiene que unir dos sitios: bordes del mapa, un lago, el mar, una cumbre o un manantial."
				% _where(end), end)


func _is_mouth(c: Vector2i) -> bool:
	if c.x == 0 or c.y == 0 or c.x == size_px.x - 1 or c.y == size_px.y - 1:
		return true
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var n: Vector2i = c + d
		var nw: int = water_at(n)
		if nw == Water.LAKE or nw == Water.SEA or height_at(n) == Height.PEAK:
			return true
	for p: Dictionary in places_of_type("manantial"):
		if absi(p.cell.x - c.x) + absi(p.cell.y - c.y) == 1:
			return true
	return false


## Celda del conjunto más lejana (en pasos) a `from`.
func _farthest(from: Vector2i, cells: Dictionary) -> Vector2i:
	var seen: Dictionary = { from: true }
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if cells.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return queue[queue.size() - 1]


## Toda villa se alcanza a pie desde la villa natal por la rejilla gruesa (is_walkable).
func _validate_villa_access() -> void:
	var home: Dictionary = home_villa()
	if home.is_empty() or not is_walkable(home.cell):
		return
	var reach := PackedByteArray()
	reach.resize(size_px.x * size_px.y)
	var queue: Array[Vector2i] = [home.cell]
	reach[_idx(home.cell)] = 1
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if in_map(n) and reach[_idx(n)] == 0 and is_walkable(n):
				reach[_idx(n)] = 1
				queue.append(n)
	for p: Dictionary in places_of_type("villa") + places_of_type("ciudad"):
		if in_map(p.cell) and is_walkable(p.cell) and reach[_idx(p.cell)] == 0:
			_error("%s, línea %d: la villa '%s' en %s no tiene acceso a pie desde la villa natal (la cierran cumbres o agua sin vado ni puente)."
					% [PLACES_FILE, p.line, p.id, _where(p.cell)], p.cell)
