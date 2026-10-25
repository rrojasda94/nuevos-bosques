extends GutTest
## Arte del Mundo 2.0, primera pasada (M13; docs/art/specs/mundo-2.md §2.5, §8 y §9): cada atlas
## existe con el tamaño de la spec, solo usa la paleta con alfa 0/255, cada píxel es una clave de su
## grupo o uno de sus colores fijos (y ningún color fijo es clave del grupo), las piezas M13 tienen
## dibujo, las filas reservadas están vacías y las animaciones cambian entre fotogramas.
## Generado por tools/art/make_world2.py: si cambias una clave, cambia los dos.

const PALETTE_PATH: String = "res://assets/palettes/palette_nuevos_bosques.gpl"
const DIR: String = "res://assets/tilesets/"

const GRASS: Array[String] = ["3e8948", "63c74d", "265c42"]
const CLEAR: Array[String] = ["ead4aa", "e4a672"]
const TREE: Array[String] = ["c0cbdc", "8b9bb4", "5a6988", "3a4466"]
const FRUIT: Array[String] = ["e43b44", "a22633"]
const FLOWER: Array[String] = ["e43b44", "f6757a", "ff0044"]
const GREYS: Array[String] = ["c0cbdc", "8b9bb4", "5a6988", "3a4466", "262b44"]
const WATER: Array[String] = ["124e89", "0099db", "2ce8f5", "ffffff"]

## nombre: [tamaño, claves, fijos]
var atlases: Dictionary = {
	"tileset_hierba.png": [Vector2i(64, 16), GRASS, []],
	"tileset_relieve.png": [Vector2i(256, 192), GRASS, GREYS + ["181425", "e4a672", "b86f50", "733e39", "ead4aa"]],
	"tileset_cascada.png": [Vector2i(192, 64), GRASS, GREYS + WATER + ["181425"]],
	"tileset_sombras.png": [Vector2i(128, 48), GRASS, ["733e39", "e4a672", "124e89"]],
	"tileset_decoracion.png": [Vector2i(256, 48), GRASS + TREE + FLOWER, ["ffffff", "be4a2f", "e8b796", "733e39"]],
	"tileset_piedras.png": [Vector2i(64, 16), GRASS, GREYS],
	"tileset_puente_ancho.png": [Vector2i(96, 48), [], ["181425", "e4a672", "b86f50", "733e39", "3e2731", "124e89", "0099db"]],
	"sprite_arboles.png": [Vector2i(320, 192), GRASS + TREE + FRUIT, ["181425", "3e2731"]],
	"sprite_arbol_joven.png": [Vector2i(32, 96), GRASS + TREE + FRUIT, ["181425", "3e2731"]],
	"sprite_arbol_grande.png": [Vector2i(48, 288), GRASS + TREE + FRUIT, ["181425", "3e2731"]],
	"sprite_rocas.png": [Vector2i(96, 32), GRASS, GREYS + ["181425"]],
	"sprite_rocas_pequenas.png": [Vector2i(32, 16), GRASS, GREYS + ["181425"]],
	"sprite_madera.png": [Vector2i(96, 16), GRASS + TREE, ["181425", "e4a672", "b86f50"]],
	"sprite_casas.png": [Vector2i(128, 96), CLEAR, GREYS + ["181425", "e8b796", "c28569", "d77643", "b86f50", "733e39", "3e2731"]],
	"sprite_nujio.png": [Vector2i(128, 480), GRASS + TREE, ["181425", "2ce8f5", "ffffff"]],
}


func _palette() -> Dictionary:
	var out: Dictionary = {}
	var f := FileAccess.open(PALETTE_PATH, FileAccess.READ)
	while not f.eof_reached():
		var parts: PackedStringArray = f.get_line().replace("\t", " ").split(" ", false)
		if parts.size() >= 3 and parts[0].is_valid_int() and parts[1].is_valid_int() and parts[2].is_valid_int():
			out[Color8(int(parts[0]), int(parts[1]), int(parts[2])).to_html(false)] = true
	return out


func _image(name: String) -> Image:
	var tex: Texture2D = load(DIR + name)
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	return img


func _drawn(img: Image, rect: Rect2i) -> int:
	var n: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if img.get_pixel(x, y).a8 > 0:
				n += 1
	return n


func _count(img: Image, rect: Rect2i, hex: String) -> int:
	var n: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var c: Color = img.get_pixel(x, y)
			if c.a8 > 0 and c.to_html(false) == hex:
				n += 1
	return n


func test_atlases_exist_with_spec_size() -> void:
	for name: String in atlases:
		assert_true(ResourceLoader.exists(DIR + name), "existe %s" % name)
		assert_eq(_image(name).get_size(), atlases[name][0], name)


func test_only_palette_full_alpha_and_group_colors() -> void:
	var palette: Dictionary = _palette()
	assert_eq(palette.size(), 32, "la paleta tiene 32 colores")
	for name: String in atlases:
		var keys: Array = atlases[name][1]
		var fixed: Array = atlases[name][2]
		for c: String in fixed:
			assert_false(keys.has(c), "%s: el color fijo %s es clave del grupo" % [name, c])
			assert_true(palette.has(c), "%s: %s de la paleta" % [name, c])
		var img: Image = _image(name)
		var bad: Dictionary = {}
		var partial: int = 0
		for y: int in img.get_height():
			for x: int in img.get_width():
				var c: Color = img.get_pixel(x, y)
				if c.a8 == 0:
					continue
				if c.a8 != 255:
					partial += 1
					continue
				var hex: String = c.to_html(false)
				if not palette.has(hex) or not (keys.has(hex) or fixed.has(hex)):
					bad[hex] = true
		assert_eq(partial, 0, "%s: alfa parcial" % name)
		assert_eq(bad.keys(), [], "%s: colores que no son ni clave ni fijo del grupo" % name)


func test_ground_pieces_are_opaque_and_reserved_rows_empty() -> void:
	var relieve: Image = _image("tileset_relieve.png")
	# Caras (filas 0-2, cols 0-8), bordes y rampas: piezas de suelo opacas.
	for row: int in 3:
		for col: int in 9:
			assert_eq(_drawn(relieve, Rect2i(col * 16, row * 16, 16, 16)), 256, "relieve fila %d col %d opaca" % [row, col])
	for mask: int in [1, 2, 3, 8, 9, 10, 11]:
		assert_eq(_drawn(relieve, Rect2i(mask * 16, 48, 16, 16)), 256, "borde %d opaco" % mask)
	for mask: int in [0, 4, 5, 6, 7, 12, 13, 14, 15]:
		assert_eq(_drawn(relieve, Rect2i(mask * 16, 48, 16, 16)), 0, "máscara %d sin uso, transparente" % mask)
	for col: int in 4:
		assert_eq(_drawn(relieve, Rect2i(col * 16, 64, 16, 16)), 256, "unión fila 4 col %d" % col)
	for col: int in 6:
		assert_eq(_drawn(relieve, Rect2i(col * 16, 80, 16, 16)), 256, "rampa norte %d" % col)
	for row: int in range(5, 8):
		for col: int in range(6, 10):
			assert_eq(_drawn(relieve, Rect2i(col * 16, row * 16, 16, 16)), 256, "rampa lateral %d,%d" % [col, row])
	assert_eq(_drawn(relieve, Rect2i(144, 0, 64, 32)), 64 * 32, "cuevas opacas")
	assert_eq(_drawn(relieve, Rect2i(0, 128, 256, 64)), 0, "filas 8-11 reservadas (esquinas interiores y diagonales)")
	assert_eq(_drawn(_image("tileset_hierba.png"), Rect2i(0, 0, 64, 16)), 64 * 16, "hierba opaca")
	assert_eq(_drawn(_image("tileset_cascada.png"), Rect2i(0, 0, 192, 64)), 192 * 64, "cascada opaca")
	assert_eq(_drawn(_image("tileset_puente_ancho.png"), Rect2i(0, 0, 96, 48)), 96 * 48, "puente opaco")


func test_grass_variants_share_a_plain_border() -> void:
	var img: Image = _image("tileset_hierba.png")
	var base: Color = Color("3e8948")
	for v: int in 4:
		for i: int in 16:
			for p: Vector2i in [Vector2i(i, 0), Vector2i(i, 15), Vector2i(0, i), Vector2i(15, i)]:
				assert_eq(img.get_pixel(v * 16 + p.x, p.y), base, "hierba %d borde %s" % [v, p])
	var a: Image = img.get_region(Rect2i(0, 0, 16, 16))
	for v: int in range(1, 4):
		assert_ne(img.get_region(Rect2i(v * 16, 0, 16, 16)).get_data(), a.get_data(), "variante %d distinta de A" % v)


func test_every_m13_piece_has_a_drawing() -> void:
	var cells: Dictionary = {
		"tileset_sombras.png": [Vector2i(16, 16), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
			Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
			Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]],
		"tileset_piedras.png": [Vector2i(16, 16), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]],
		"sprite_rocas.png": [Vector2i(32, 32), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]],
		"sprite_rocas_pequenas.png": [Vector2i(16, 16), [Vector2i(0, 0), Vector2i(1, 0)]],
		"sprite_casas.png": [Vector2i(64, 48), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]],
	}
	var deco: Array = []
	for col: int in 16:
		deco.append(Vector2i(col, 0))
	for col: int in 4:
		deco.append(Vector2i(col, 1))
	cells["tileset_decoracion.png"] = [Vector2i(16, 16), deco]
	for shape: int in 6:
		for col: int in 10:
			cells.get_or_add("sprite_arboles.png", [Vector2i(32, 32), []])[1].append(Vector2i(col, shape))
		for col: int in 2:
			cells.get_or_add("sprite_arbol_joven.png", [Vector2i(16, 16), []])[1].append(Vector2i(col, shape))
			cells.get_or_add("sprite_nujio.png", [Vector2i(64, 80), []])[1].append(Vector2i(col, shape))
		cells.get_or_add("sprite_arbol_grande.png", [Vector2i(48, 48), []])[1].append(Vector2i(0, shape))
	var wood: Image = _image("sprite_madera.png")
	for r: Rect2i in [Rect2i(0, 0, 16, 16), Rect2i(16, 0, 16, 16), Rect2i(32, 0, 32, 16), Rect2i(64, 0, 32, 16)]:
		assert_gt(_drawn(wood, r), 20, "madera %s" % r)
	for name: String in cells:
		var img: Image = _image(name)
		var size: Vector2i = cells[name][0]
		for c: Vector2i in cells[name][1]:
			assert_gt(_drawn(img, Rect2i(c * size, size)), 8, "%s pieza %s con dibujo" % [name, c])
	# Decoración: las propias por silueta (M18) y la fila 2 siguen vacías.
	var deco_img: Image = _image("tileset_decoracion.png")
	assert_eq(_drawn(deco_img, Rect2i(64, 16, 192, 16)), 0, "propias por silueta: M18")
	assert_eq(_drawn(deco_img, Rect2i(0, 32, 256, 16)), 0, "fila 2 libre")


func test_fruit_only_on_fruit_columns() -> void:
	var img: Image = _image("sprite_arboles.png")
	for shape: int in 6:
		for col: int in 10:
			var rect := Rect2i(col * 32, shape * 32, 32, 32)
			var fruit: int = _count(img, rect, "e43b44")
			if col == 4 or col == 5:
				assert_between(fruit, 4 * 3, 6 * 3, "silueta %d frutal %d: 4-6 frutos de 2x2" % [shape, col])
				assert_between(_count(img, rect, "a22633"), 4, 6, "silueta %d frutal %d: sombra del fruto" % [shape, col])
			else:
				assert_eq(fruit, 0, "silueta %d col %d sin fruto" % [shape, col])
		# El árbol seco no lleva hoja clara.
		assert_eq(_count(img, Rect2i(9 * 32, shape * 32, 32, 32), "c0cbdc"), 0, "silueta %d seco sin hoja clara" % shape)


func test_animated_frames_differ() -> void:
	var cascade: Image = _image("tileset_cascada.png")
	for piece: int in 3:
		for row: int in 4:
			var f0: PackedByteArray = cascade.get_region(Rect2i(piece * 64, row * 16, 16, 16)).get_data()
			for f: int in range(1, 4):
				var fn: PackedByteArray = cascade.get_region(Rect2i(piece * 64 + f * 16, row * 16, 16, 16)).get_data()
				assert_ne(fn, f0, "cascada pieza %d fila %d fotograma %d" % [piece, row, f])
	var nujio: Image = _image("sprite_nujio.png")
	for shape: int in 6:
		assert_ne(nujio.get_region(Rect2i(0, shape * 80, 64, 80)).get_data(),
			nujio.get_region(Rect2i(64, shape * 80, 64, 80)).get_data(), "Nujio %d: las motas cambian" % shape)
		assert_gt(_count(nujio, Rect2i(0, shape * 80, 64, 80), "2ce8f5"), 0, "Nujio %d: acento místico" % shape)
