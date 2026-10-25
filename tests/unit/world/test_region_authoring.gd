extends GutTest
## Autoría de regiones (ADR 0014 §4): colores de la paleta, tamaño desde la imagen, lectura de
## lugares.csv y validación (suavizado, tamaños, lugares fuera o en el agua, Bosques clave fuera
## de 4–16 chunks, ríos cortados y villas sin acceso). Las imágenes se crean en memoria o en
## user://.

const HEADER: String = "id,nombre,tipo,x,y,color,estilo,notas"
const HOME_ROW: String = "villa_natal,Casa,villa_natal,1,1,,,"
const TMP_DIR: String = "user://test_region_authoring/"

var _palette: Dictionary


func before_all() -> void:
	_palette = RegionAuthoring.load_palette()


func _img(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


func _put(img: Image, cell: Vector2i, layer: String, key: String) -> void:
	img.set_pixelv(cell, RegionAuthoring.palette_color(_palette, layer, key))


func _csv(rows: Array) -> String:
	return "\n".join([HEADER] + rows) + "\n"


func _build(images: Dictionary, rows: Array = [HOME_ROW]) -> RegionAuthoring:
	return RegionAuthoring.from_sources(images, _csv(rows), _palette)


func _has_error(a: RegionAuthoring, fragment: String) -> bool:
	for e: String in a.errors:
		if e.contains(fragment):
			return true
	return false


# --- Paleta y colores --------------------------------------------------------------------------

func test_palette_colors_are_opaque_and_distinct_per_layer() -> void:
	for layer: String in ["height", "water", "roads"]:
		var keys: Array[String] = RegionAuthoring.layer_keys(layer)
		var seen: Dictionary = {}
		for k: int in range(1, keys.size()):
			var c: Color = RegionAuthoring.palette_color(_palette, layer, keys[k])
			assert_eq(c.a, 1.0, "%s.%s está en la paleta y es opaco" % [layer, keys[k]])
			assert_false(seen.has(c.to_html(false)), "%s.%s no repite color" % [layer, keys[k]])
			seen[c.to_html(false)] = true


func test_decodes_each_palette_color() -> void:
	var height := _img(20, 20)
	var water := _img(20, 20)
	var roads := _img(20, 20)
	_put(height, Vector2i(0, 0), "height", "level_0")
	_put(height, Vector2i(3, 0), "height", "level_3")
	_put(height, Vector2i(4, 0), "height", "peak")
	_put(water, Vector2i(5, 5), "water", "lake")
	_put(water, Vector2i(6, 5), "water", "ford")
	_put(roads, Vector2i(7, 7), "roads", "bridge")
	var a := _build({ "height": height, "water": water, "roads": roads })
	assert_eq(a.height_at(Vector2i(0, 0)), RegionAuthoring.Height.LEVEL_0)
	assert_eq(a.height_at(Vector2i(3, 0)), RegionAuthoring.Height.LEVEL_3)
	assert_eq(a.height_at(Vector2i(4, 0)), RegionAuthoring.Height.PEAK)
	assert_eq(a.height_at(Vector2i(9, 9)), RegionAuthoring.Height.NONE, "transparente = sin pintar")
	assert_eq(a.water_at(Vector2i(5, 5)), RegionAuthoring.Water.LAKE)
	assert_eq(a.water_at(Vector2i(6, 5)), RegionAuthoring.Water.FORD)
	assert_eq(a.road_at(Vector2i(7, 7)), RegionAuthoring.Road.BRIDGE)
	assert_true(a.has_layer.height and not a.has_layer.bosques, "capas presentes")


func test_size_comes_from_the_image() -> void:
	var a := _build({ "height": _img(60, 40) })
	assert_eq(a.size_px, Vector2i(60, 40))
	assert_eq(a.size_chunks(), Vector2i(3, 2), "20 px por chunk")
	assert_true(a.is_valid(), "sin errores: %s" % [a.errors])


func test_size_not_multiple_of_a_chunk_is_an_error() -> void:
	assert_true(_has_error(_build({ "height": _img(30, 40) }), "múltiplo de 20"))


func test_images_of_different_sizes_are_an_error() -> void:
	var a := _build({ "height": _img(40, 40), "water": _img(40, 60) })
	assert_true(_has_error(a, "tamaños distintos"), "%s" % [a.errors])
	assert_true(_has_error(a, "agua.png 40×60"), "dice qué PNG mide qué")


func test_no_images_is_an_error() -> void:
	assert_false(_build({}).is_valid())


# --- Suavizado ---------------------------------------------------------------------------------

func test_unknown_color_is_reported_with_coordinates() -> void:
	var height := _img(40, 40)
	_put(height, Vector2i(4, 6), "height", "level_0")
	height.set_pixel(5, 7, Color8(0x31, 0x31, 0x31))
	var a := _build({ "height": height })
	assert_true(_has_error(a, "altura.png: color desconocido #313131 en (5, 7)"), "%s" % [a.errors])
	assert_true(_has_error(a, "suavizado"), "explica la causa")
	assert_true(a.error_cells.has(Vector2i(5, 7)), "se marca en la vista previa")
	assert_eq(a.height_at(Vector2i(5, 7)), RegionAuthoring.Height.NONE)


func test_semitransparent_pixel_is_reported() -> void:
	var water := _img(20, 20)
	var c: Color = RegionAuthoring.palette_color(_palette, "water", "lake")
	c.a8 = 128
	water.set_pixel(2, 3, c)
	var a := _build({ "water": water })
	assert_true(_has_error(a, "semitransparente (alfa 128) en (2, 3)"), "%s" % [a.errors])


func test_many_bad_pixels_are_summarized() -> void:
	var height := _img(20, 20)
	height.fill(Color8(1, 2, 3))
	var a := _build({ "height": height })
	assert_true(_has_error(a, "400 píxeles"), "da el total")
	assert_lt(a.errors.size(), 20, "no lista los 400")


# --- Lugares -----------------------------------------------------------------------------------

func test_reads_places() -> void:
	var rows: Array = [
		HOME_ROW,
		"hito_1,Piedra \"alta\",hito,10,12,,,\"Nota, con coma\"",
		"bosque_a,Bosque A,bosque,30,30,#12ab34,conifera,",
	]
	var text: String = _csv(rows).replace("Piedra \"alta\"", "\"Piedra \"\"alta\"\"\"")
	var a := RegionAuthoring.from_sources({ "height": _img(60, 60) }, text, _palette)
	assert_eq(a.places.size(), 3)
	var hito: Dictionary = a.places[1]
	assert_eq(hito.id, "hito_1")
	assert_eq(hito.name, "Piedra \"alta\"", "comillas dobles escapadas")
	assert_eq(hito.type, "hito")
	assert_eq(hito.cell, Vector2i(10, 12))
	assert_eq(hito.notes, "Nota, con coma", "coma dentro de comillas")
	var bosque: Dictionary = a.bosque_places()[0]
	assert_eq(bosque.color, Color.html("#12ab34"))
	assert_eq(bosque.style, "conifera")
	assert_eq(a.home_villa().id, "villa_natal")
	assert_eq(a.home_chunk(), Vector2i(0, 0))


func test_reads_semicolon_csv_with_bom() -> void:
	var text: String = "﻿" + _csv([HOME_ROW, "v2,Otra,villa,25,5,,,"]).replace(",", ";")
	var a := RegionAuthoring.from_sources({ "height": _img(40, 20) }, text, _palette)
	assert_eq(a.places.size(), 2, "%s" % [a.errors])
	assert_eq(a.places[1].cell, Vector2i(25, 5))
	assert_eq(a.home_chunk(), Vector2i(0, 0))


func test_bad_rows_are_errors() -> void:
	var a := _build({ "height": _img(40, 40) }, [HOME_ROW, "x1,X,castillo,1,1,,,", "x2,X,hito,uno,1,,,",
			"x3,X,bosque,2,2,verde,,", "villa_natal,Repetida,villa,3,3,,,"])
	assert_true(_has_error(a, "tipo desconocido 'castillo'"))
	assert_true(_has_error(a, "x e y enteros"))
	assert_true(_has_error(a, "color #RRGGBB"))
	assert_true(_has_error(a, "repetido"))


func test_missing_home_villa_is_an_error() -> void:
	assert_true(_has_error(_build({ "height": _img(20, 20) }, []), "falta la villa natal"))


func test_place_outside_the_map_is_an_error() -> void:
	var a := _build({ "height": _img(40, 20) }, [HOME_ROW, "lejos,Lejos,lugar,40,5,,,"])
	assert_true(_has_error(a, "'lejos' está fuera del mapa en (40, 5)"), "%s" % [a.errors])


func test_place_in_water_is_an_error() -> void:
	var water := _img(20, 20)
	_put(water, Vector2i(5, 5), "water", "lake")
	var a := _build({ "water": water }, [HOME_ROW, "isla,Isla,hito,5,5,,,"])
	assert_true(_has_error(a, "'isla' está en el agua (un lago)"), "%s" % [a.errors])


# --- Bosques clave -----------------------------------------------------------------------------

## Pinta `count` chunks del Bosque (fila a fila) en un mapa de 5×5 chunks.
func _bosque_map(count: int) -> RegionAuthoring:
	var bosques := _img(100, 100)
	var color := Color.html("#12ab34")
	for k: int in count:
		var c := Vector2i(k % 5, k / 5)
		bosques.set_pixelv(c * 20 + Vector2i(3, 3), color)
	return _build({ "bosques": bosques }, [HOME_ROW, "bosque_a,A,bosque,3,3,#12ab34,,"])


func test_bosque_within_range_is_valid() -> void:
	var a := _bosque_map(6)
	assert_true(a.is_valid(), "%s" % [a.errors])
	assert_eq(a.bosque_at(Vector2i(3, 3)), 0)


func test_bosque_over_sixteen_chunks_is_an_error() -> void:
	var a := _bosque_map(17)
	assert_true(_has_error(a, "'bosque_a' ocupa 17 chunks; el máximo es 16"), "%s" % [a.errors])


func test_small_bosque_is_valid_if_it_can_grow() -> void:
	assert_true(_bosque_map(1).is_valid(), "el generador lo extiende a 4")


func test_small_bosque_without_room_is_an_error() -> void:
	var bosques := _img(40, 20)
	bosques.set_pixel(3, 3, Color.html("#12ab34"))
	var a := _build({ "bosques": bosques }, [HOME_ROW, "bosque_a,A,bosque,3,3,#12ab34,,"])
	assert_true(_has_error(a, "no le caben 4"), "%s" % [a.errors])


func test_split_bosque_is_an_error() -> void:
	var bosques := _img(100, 100)
	bosques.set_pixel(3, 3, Color.html("#12ab34"))
	bosques.set_pixel(83, 83, Color.html("#12ab34"))
	var a := _build({ "bosques": bosques }, [HOME_ROW, "bosque_a,A,bosque,3,3,#12ab34,,"])
	assert_true(_has_error(a, "partido"), "%s" % [a.errors])


func test_undeclared_bosque_color_is_unknown() -> void:
	var bosques := _img(20, 20)
	bosques.set_pixel(3, 3, Color.html("#ff00ff"))
	assert_true(_has_error(_build({ "bosques": bosques }), "bosques.png: color desconocido #ff00ff"))


# --- Ríos y acceso -----------------------------------------------------------------------------

func _river(w: int, h: int, from_y: int, to_y: int) -> Image:
	var water := _img(w, h)
	for y: int in range(from_y, to_y):
		_put(water, Vector2i(10, y), "water", "river_narrow")
	return water


func test_river_from_edge_to_edge_is_valid() -> void:
	var a := _build({ "water": _river(20, 40, 0, 40) })
	assert_true(a.is_valid(), "%s" % [a.errors])


func test_river_that_stops_is_an_error() -> void:
	var a := _build({ "water": _river(20, 40, 0, 25) })
	assert_true(_has_error(a, "el río se corta en (10, 24)"), "%s" % [a.errors])


func test_river_into_a_lake_is_valid() -> void:
	var water := _river(20, 40, 0, 25)
	_put(water, Vector2i(10, 25), "water", "lake")
	assert_true(_build({ "water": water }).is_valid())


func test_villa_closed_by_peaks_is_an_error() -> void:
	var height := _img(40, 20)
	for y: int in range(10, 15):
		for x: int in range(25, 30):
			if x == 25 or x == 29 or y == 10 or y == 14:
				_put(height, Vector2i(x, y), "height", "peak")
	var a := _build({ "height": height }, [HOME_ROW, "v2,Encerrada,villa,27,12,,,"])
	assert_true(_has_error(a, "'v2' en (27, 12) [chunk 1, 0] no tiene acceso a pie"), "%s" % [a.errors])


func test_villa_across_a_river_needs_a_ford_or_bridge() -> void:
	var water := _river(20, 20, 0, 20)
	var rows: Array = [HOME_ROW, "v2,Otra orilla,villa,15,5,,,"]
	assert_true(_has_error(_build({ "water": water }, rows), "no tiene acceso a pie"))
	_put(water, Vector2i(10, 8), "water", "ford")
	assert_true(_build({ "water": water }, rows).is_valid(), "por el vado")
	var bridged := _river(20, 20, 0, 20)
	var roads := _img(20, 20)
	_put(roads, Vector2i(10, 8), "roads", "bridge")
	assert_true(_build({ "water": bridged, "roads": roads }, rows).is_valid(), "por el puente")


# --- Archivos ----------------------------------------------------------------------------------

func test_load_dir_reads_pngs_and_csv() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	var height := _img(40, 20)
	_put(height, Vector2i(2, 2), "height", "level_1")
	height.save_png(TMP_DIR + "altura.png")
	var f := FileAccess.open(TMP_DIR + "lugares.csv", FileAccess.WRITE)
	f.store_string(_csv([HOME_ROW, "v2,Dos,villa,30,10,,,"]))
	f.close()
	var a := RegionAuthoring.load_dir(TMP_DIR, _palette)
	assert_true(a.is_valid(), "%s" % [a.errors])
	assert_eq(a.size_chunks(), Vector2i(2, 1))
	assert_eq(a.height_at(Vector2i(2, 2)), RegionAuthoring.Height.LEVEL_1)
	assert_false(a.has_layer.water, "sin agua.png: río procedural")
	assert_eq(a.places_of_type("villa").size(), 1)
	DirAccess.remove_absolute(TMP_DIR + "altura.png")
	DirAccess.remove_absolute(TMP_DIR + "lugares.csv")


func test_valle_del_sara_authoring_is_valid_and_matches_the_region() -> void:
	var region: Dictionary = ChunkGenerator.load_region(&"valle_del_sara")
	var a := RegionAuthoring.load_region(&"valle_del_sara")
	assert_true(a.is_valid(), "%s" % [a.errors])
	assert_eq(a.size_px, Vector2i(240, 320))
	assert_eq(a.size_chunks(), ChunkGenerator.region_size(region), "mismo tamaño que size_chunks")
	assert_eq(a.home_chunk(), ChunkGenerator.region_start_chunk(region), "la villa natal está en start_chunk")
	for layer: String in RegionAuthoring.LAYERS:
		assert_true(a.has_layer[layer], "existe %s" % RegionAuthoring.layer_file(_palette, layer))


## Afluentes del Sara (tools/world/paint_afluentes.py; sur-lenfi.md): la red de agua del valle es
## una sola y le llegan al menos 4 afluentes desde el oeste (Urd Gumnavis) y 3 desde el este
## (Gumnada Gumnavis). El Sara es el pasillo de agua de norte a sur: las celdas que están a 3 pasos
## o menos de más que el camino más corto entre los dos bordes. Lo que queda son los afluentes:
## cuenta cada trozo que toca el Sara y nace en una cumbre o en el borde oeste o este.
func test_valle_del_sara_has_the_sara_tributaries() -> void:
	var a := RegionAuthoring.load_region(&"valle_del_sara")
	var water: Dictionary = {}
	for y: int in a.size_px.y:
		for x: int in a.size_px.x:
			if a.water_at(Vector2i(x, y)) != RegionAuthoring.Water.NONE:
				water[Vector2i(x, y)] = true
	assert_false(water.is_empty(), "agua.png tiene agua")
	if water.is_empty():
		return
	assert_eq(_flood(water, [water.keys()[0]]).size(), water.size(), "la red de agua es conexa")
	var top: Array = water.keys().filter(func(c: Vector2i) -> bool: return c.y == 0)
	var bottom: Array = water.keys().filter(func(c: Vector2i) -> bool: return c.y == a.size_px.y - 1)
	assert_false(top.is_empty() or bottom.is_empty(), "el Sara va del borde norte al sur")
	if top.is_empty() or bottom.is_empty():
		return
	var from_top: Dictionary = _flood(water, top)
	var from_bottom: Dictionary = _flood(water, bottom)
	var shortest: int = 1 << 30
	for c: Vector2i in bottom:
		shortest = mini(shortest, from_top.get(c, 1 << 30))
	var sara: Dictionary = {}
	var rest: Dictionary = {}
	for c: Vector2i in water:
		if from_top.get(c, 1 << 30) + from_bottom.get(c, 1 << 30) <= shortest + 3:
			sara[c] = true
		else:
			rest[c] = true
	var west: int = 0
	var east: int = 0
	var done: Dictionary = {}
	for c: Vector2i in rest:
		if done.has(c):
			continue
		var part: Dictionary = _flood(rest, [c])
		var touches_sara: bool = false
		var source_x: int = -1
		for p: Vector2i in part:
			done[p] = true
			if p.x == 0 or p.x == a.size_px.x - 1:
				source_x = p.x
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				touches_sara = touches_sara or sara.has(p + d)
				if a.height_at(p + d) == RegionAuthoring.Height.PEAK:
					source_x = p.x
		if touches_sara and source_x >= 0:
			if source_x < a.size_px.x / 2:
				west += 1
			else:
				east += 1
	gut.p("Afluentes del Sara: %d al oeste, %d al este." % [west, east])
	assert_gte(west, 4, "afluentes del oeste (Urd Gumnavis)")
	assert_gte(east, 3, "afluentes del este (Gumnada Gumnavis)")


## Distancia en pasos (4-vecindad) desde `starts` a cada celda alcanzable de `cells`.
func _flood(cells: Dictionary, starts: Array) -> Dictionary:
	var dist: Dictionary = {}
	var queue: Array[Vector2i] = []
	for s: Vector2i in starts:
		dist[s] = 0
		queue.append(s)
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if cells.has(n) and not dist.has(n):
				dist[n] = dist[c] + 1
				queue.append(n)
	return dist
