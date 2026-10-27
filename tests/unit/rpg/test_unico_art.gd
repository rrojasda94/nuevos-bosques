extends GutTest
## Arte de la primera pasada (docs/art/specs/primera-pasada.md): los PNG existen, tienen el tamaño
## de la spec, solo usan la paleta y el recoloreo por Bosque de los monstruos da sus colores.

const PALETTE_PATH: String = "res://assets/palettes/palette_nuevos_bosques.gpl"
const SIZES: Dictionary = {
	"res://assets/sprites/sprite_adoc_walk.png": Vector2i(32, 64),
	"res://assets/sprites/sprite_sfida_idle.png": Vector2i(32, 16),
	"res://assets/sprites/sprite_botarramas_walk.png": Vector2i(32, 24),
	"res://assets/sprites/sprite_ofomni_idle.png": Vector2i(64, 32),
	"res://assets/sprites/sprite_icon_sign.png": Vector2i(8, 8),
	"res://assets/sprites/sprite_icon_refuge.png": Vector2i(8, 8),
}


func _palette() -> Dictionary:
	var out: Dictionary = {}
	var f := FileAccess.open(PALETTE_PATH, FileAccess.READ)
	while not f.eof_reached():
		var parts: PackedStringArray = f.get_line().replace("\t", " ").split(" ", false)
		if parts.size() >= 3 and parts[0].is_valid_int() and parts[1].is_valid_int() and parts[2].is_valid_int():
			out[Color8(int(parts[0]), int(parts[1]), int(parts[2])).to_rgba32()] = true
	return out


func _image(path: String) -> Image:
	var img: Image = (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


func test_pngs_exist_with_spec_size() -> void:
	for path: String in SIZES:
		assert_true(ResourceLoader.exists(path), "existe %s" % path)
		var tex: Texture2D = load(path)
		assert_eq(Vector2i(tex.get_width(), tex.get_height()), SIZES[path], path)


func test_pngs_only_use_the_palette_and_full_alpha() -> void:
	var palette: Dictionary = _palette()
	assert_eq(palette.size(), 32, "la paleta tiene 32 colores")
	for path: String in SIZES:
		var img: Image = _image(path)
		var bad: int = 0
		for y: int in img.get_height():
			for x: int in img.get_width():
				var c: Color = img.get_pixel(x, y)
				if c.a8 == 0:
					continue
				if c.a8 != 255 or not palette.has(c.to_rgba32()):
					bad += 1
		assert_eq(bad, 0, "%s: píxeles fuera de paleta o con alfa parcial" % path)


func test_monsters_use_their_png() -> void:
	for kind: UnicoArt.Kind in [UnicoArt.Kind.BOTARRAMAS, UnicoArt.Kind.EYES]:
		assert_true(UnicoArt.has_sprite(kind))
		assert_eq(UnicoArt.frames_for(kind), UnicoArt.SPRITE_FRAMES)
	assert_eq(UnicoArt.frames_for(UnicoArt.Kind.SERPENT), 1, "sin PNG: placeholder de un fotograma")
	assert_null(UnicoArt.sprite_sheet(UnicoArt.Kind.SERPENT, {}), "sin PNG no hay hoja")


func test_recolor_paints_with_the_bosque_colors() -> void:
	var keys: Array = [UnicoArt.KEY_LIGHT.to_rgba32(), UnicoArt.KEY_DARK.to_rgba32(), UnicoArt.KEY_TRUNK.to_rgba32()]
	for kind: UnicoArt.Kind in [UnicoArt.Kind.BOTARRAMAS, UnicoArt.Kind.EYES]:
		for style: Dictionary in [{ "leaf": 0, "trunk": 0 }, { "leaf": 5, "trunk": 3 }, { "leaf": 9, "trunk": 6 }]:
			var leaf: Array = PlaceholderTileset.LEAVES[style.leaf]
			var trunk: Color = PlaceholderTileset.TRUNKS[style.trunk]
			var img: Image = (UnicoArt.sprite_sheet(kind, style) as Texture2D).get_image()
			var seen: Dictionary = {}
			for y: int in img.get_height():
				for x: int in img.get_width():
					var c: Color = img.get_pixel(x, y)
					if c.a8 > 0:
						seen[c.to_rgba32()] = true
			var where: String = "tipo %d, estilo %s" % [kind, style]
			assert_true(seen.has((leaf[0] as Color).to_rgba32()), "%s: hoja oscura" % where)
			assert_true(seen.has((leaf[1] as Color).to_rgba32()), "%s: hoja clara" % where)
			assert_true(seen.has(trunk.to_rgba32()), "%s: tronco" % where)
			assert_true(seen.has(PlaceholderTileset.OUTLINE.to_rgba32()), "%s: contorno fijo" % where)
			# Si el Bosque no usa un color clave, ese color ya no puede quedar en la imagen.
			var bosque: Array = [(leaf[0] as Color).to_rgba32(), (leaf[1] as Color).to_rgba32(), trunk.to_rgba32()]
			for k: int in keys:
				if not bosque.has(k):
					assert_false(seen.has(k), "%s: no queda el color clave %x" % [where, k])


func test_recolor_keeps_other_colors() -> void:
	var img := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, UnicoArt.KEY_LIGHT)
	img.set_pixel(1, 0, Color("e43b44"))
	var out: Image = UnicoArt.recolor(img, { "leaf": 2, "trunk": 1 })
	assert_eq(out.get_pixel(0, 0).to_html(false), (PlaceholderTileset.LEAVES[2][1] as Color).to_html(false))
	assert_eq(out.get_pixel(1, 0).to_html(false), "e43b44", "el iris no cambia")


func test_battle_texture_fits_the_box() -> void:
	for kind: UnicoArt.Kind in [UnicoArt.Kind.BOTARRAMAS, UnicoArt.Kind.EYES]:
		var tex: Texture2D = UnicoArt.battle_texture(kind, { "leaf": 1, "trunk": 0 }, 96)
		assert_eq(Vector2i(tex.get_width(), tex.get_height()), Vector2i(96, 96))


func test_adoc_back_texture_is_one_frame() -> void:
	var tex: Texture2D = PlayerController.back_texture()
	assert_eq(Vector2i(tex.get_width(), tex.get_height()), Vector2i(16, 16))
