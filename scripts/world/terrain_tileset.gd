class_name TerrainTileset
extends RefCounted
## Arte del terreno de pixel-artist (docs/art/specs/tileset-terreno.md): lee los PNG de
## assets/tilesets/, cambia sus colores clave por los del Bosque (suelo, hojas, tronco y fruto) y
## pinta con ellos las casillas del atlas que arma PlaceholderTileset.make_source. No decide qué
## variante lleva cada casilla (PlaceholderTileset.variant_for) ni genera nada: si falta el PNG de
## un grupo, paint() devuelve false y esa casilla se dibuja por código como antes.

const DIR: String = "res://assets/tilesets/"
const GROUPS: Dictionary = {
	&"suelo": "tileset_suelo.png",
	&"sendero": "tileset_sendero.png",
	&"camino": "tileset_camino.png",
	&"agua": "tileset_agua.png",
	&"puente": "tileset_puente.png",
	&"risco": "tileset_risco.png",
	&"plaza": "tileset_plaza.png",
	&"villa": "tileset_villa.png",
	&"letrero": "tileset_letrero.png",
	&"arboles": "tileset_arboles.png",
}

## Colores clave de los PNG (iguales que en tools/art/make_tiles.py).
const KEY_GRASS := Color("3e8948")
const KEY_GRASS_SPECK := Color("63c74d")
const KEY_GRASS_SHADOW := Color("265c42")
const KEY_CLEARING := Color("ead4aa")
const KEY_CLEARING_SPECK := Color("e4a672")
const KEY_LEAF_LIGHT := Color("c0cbdc")
const KEY_LEAF_DARK := Color("8b9bb4")
const KEY_TRUNK := Color("5a6988")
const KEY_FRUIT := Color("e43b44")
const KEY_FRUIT_SHADOW := Color("a22633")

## Qué claves cambia cada grupo: "grass" (hierba), "clearing" (claro), "tree" (hojas, tronco y
## fruto). Los demás colores del PNG son fijos.
const GROUP_KEYS: Dictionary = {
	&"suelo": ["grass", "clearing"],
	&"sendero": ["grass"],
	&"camino": ["grass"],
	&"risco": ["grass"],
	&"plaza": ["clearing"],
	&"villa": ["clearing"],
	&"arboles": ["tree"],
}

## Columnas del PNG de árboles: 0-3 árbol, 4-5 frutal con fruto, 6-7 vaciado, 8 árbol hueco.
const TREE_COL_FRUIT: int = 4
const TREE_COL_EMPTY: int = 6
const TREE_COL_HOLLOW: int = 8
## Fila del PNG del agua: tipo * 2 + fotograma.
const WATER_ROWS: Dictionary = {
	ChunkData.Tile.RIVER_NARROW: 0, ChunkData.Tile.RIVER_NAVIGABLE: 2, ChunkData.Tile.FORD: 4,
}
## Fondo del letrero (variant / 8): 0 = camino, 1 = sendero, 2 = hierba.
enum SignGround { ROAD, PATH, GRASS }

const T: int = 16

static var _raw: Dictionary = {}  # grupo -> Image (o null si no hay PNG)
static var _colored: Dictionary = {}  # "grupo:clave de colores" -> Image recoloreada


static func has_group(group: StringName) -> bool:
	return _raw_image(group) != null


## Pinta la casilla `tile` en su variante `variant` (y fotograma `frame` del agua) en `image`, en
## la esquina `o`, con los colores del Bosque de `style`. false si falta algún PNG que necesita.
static func paint(image: Image, tile: int, variant: int, o: Vector2i, style: Dictionary, frame: int = 0) -> bool:
	match tile:
		ChunkData.Tile.GRASS:
			return _blit(image, &"suelo", Vector2i(variant % 4, 0), o, style)
		ChunkData.Tile.ROCKY:
			return _blit(image, &"suelo", Vector2i(variant % 4, 1), o, style)
		ChunkData.Tile.CLEARING:
			return _blit(image, &"suelo", Vector2i(variant % 16, 2 + (variant / 16) % 2), o, style)
		ChunkData.Tile.NUJIO:
			return _blit(image, &"suelo", Vector2i(0, 2), o, style)
		ChunkData.Tile.PATH:
			return _blit(image, &"sendero", Vector2i(variant % 16, (variant / 16) % 2), o, style)
		ChunkData.Tile.ROAD:
			return _blit(image, &"camino", Vector2i(variant % 16, (variant / 16) % 2), o, style)
		ChunkData.Tile.CLIFF:
			return _blit(image, &"risco", Vector2i(variant % 16, (variant / 16) % 2), o, style)
		ChunkData.Tile.PLAZA:
			return _blit(image, &"plaza", Vector2i(variant % 16, (variant / 16) % 2), o, style)
		ChunkData.Tile.BUILDING:
			return _blit(image, &"villa", Vector2i(variant % 16, (variant / 16) % 2), o, style)
		ChunkData.Tile.RIVER_NARROW, ChunkData.Tile.RIVER_NAVIGABLE, ChunkData.Tile.FORD:
			return _blit(image, &"agua", Vector2i(variant % 16, int(WATER_ROWS[tile]) + frame % 2), o, style)
		ChunkData.Tile.BRIDGE:
			return _blit(image, &"puente", Vector2i(variant % 2, (variant / 2) % 2), o, style)
		ChunkData.Tile.TREE:
			return _on_grass(image, variant % 4, &"arboles", Vector2i(variant % 4, _shape(style)), o, style)
		ChunkData.Tile.FRUIT_TREE:
			var col: int = (TREE_COL_FRUIT if variant < PlaceholderTileset.FRUIT_EMPTY_VARIANT else TREE_COL_EMPTY) + variant % 2
			return _on_grass(image, variant % 2, &"arboles", Vector2i(col, _shape(style)), o, style)
		ChunkData.Tile.REFUGE:
			if variant % 2 == 1:
				return _on_grass(image, 0, &"risco", Vector2i(0, 2), o, style)
			return _on_grass(image, 0, &"arboles", Vector2i(TREE_COL_HOLLOW, _shape(style)), o, style)
		ChunkData.Tile.SIGN:
			var under: int = (variant / 8) % 3
			var ok: bool = false
			match under:
				SignGround.ROAD:
					ok = _blit(image, &"camino", Vector2i.ZERO, o, style)
				SignGround.PATH:
					ok = _blit(image, &"sendero", Vector2i.ZERO, o, style)
				_:
					ok = _blit(image, &"suelo", Vector2i.ZERO, o, style)
			return ok and _blend(image, &"letrero", Vector2i(variant % 8, 0), o, style)
	return false


## Colores clave -> colores del Bosque para el grupo `group` (claves en RGBA32).
static func recolor_map(group: StringName, style: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var ground: Array = PlaceholderTileset.GROUNDS[int(style.get("ground", 0))]
	for set_name: String in GROUP_KEYS.get(group, []):
		match set_name:
			"grass":
				out[KEY_GRASS.to_rgba32()] = ground[0]
				out[KEY_GRASS_SPECK.to_rgba32()] = ground[1]
				out[KEY_GRASS_SHADOW.to_rgba32()] = ground[4]
			"clearing":
				out[KEY_CLEARING.to_rgba32()] = ground[2]
				out[KEY_CLEARING_SPECK.to_rgba32()] = ground[3]
			"tree":
				var leaf: Array = PlaceholderTileset.LEAVES[int(style.get("leaf", 0))]
				var fruit: Array = PlaceholderTileset.fruit_color(style)
				out[KEY_LEAF_LIGHT.to_rgba32()] = leaf[1]
				out[KEY_LEAF_DARK.to_rgba32()] = leaf[0]
				out[KEY_TRUNK.to_rgba32()] = PlaceholderTileset.TRUNKS[int(style.get("trunk", 0))]
				out[KEY_FRUIT.to_rgba32()] = fruit[0]
				out[KEY_FRUIT_SHADOW.to_rgba32()] = fruit[1]
	return out


## PNG del grupo tal cual (RGBA8), o null si no existe.
static func raw_image(group: StringName) -> Image:
	return _raw_image(group)


static func _raw_image(group: StringName) -> Image:
	if not _raw.has(group):
		var path: String = DIR + String(GROUPS[group])
		var img: Image = null
		if ResourceLoader.exists(path):
			img = (load(path) as Texture2D).get_image()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
		_raw[group] = img
	return _raw[group]


## PNG del grupo recoloreado para el Bosque. Se guarda por combinación de colores: los grupos de
## suelo solo dependen del suelo del Bosque, así que se recolorean pocas veces.
static func _colored_image(group: StringName, style: Dictionary) -> Image:
	var raw: Image = _raw_image(group)
	if raw == null:
		return null
	var sets: Array = GROUP_KEYS.get(group, [])
	if sets.is_empty():
		return raw
	var key: String = String(group)
	if sets.has("grass") or sets.has("clearing"):
		key += ":g%d" % int(style.get("ground", 0))
	if sets.has("tree"):
		key += ":l%d:t%d" % [int(style.get("leaf", 0)), int(style.get("trunk", 0))]
	if not _colored.has(key):
		_colored[key] = _recolor(raw, recolor_map(group, style))
	return _colored[key]


static func _recolor(img: Image, mapping: Dictionary) -> Image:
	var out := img.duplicate() as Image
	for y: int in out.get_height():
		for x: int in out.get_width():
			var c: Color = out.get_pixel(x, y)
			if c.a > 0.0 and mapping.has(c.to_rgba32()):
				out.set_pixel(x, y, mapping[c.to_rgba32()])
	return out


static func _shape(style: Dictionary) -> int:
	return int(style.get("shape", 0)) % PlaceholderTileset.SHAPE_COUNT


static func _blit(image: Image, group: StringName, cell: Vector2i, o: Vector2i, style: Dictionary) -> bool:
	var src: Image = _colored_image(group, style)
	if src == null:
		return false
	image.blit_rect(src, Rect2i(cell * T, Vector2i(T, T)), o)
	return true


static func _blend(image: Image, group: StringName, cell: Vector2i, o: Vector2i, style: Dictionary) -> bool:
	var src: Image = _colored_image(group, style)
	if src == null:
		return false
	image.blend_rect(src, Rect2i(cell * T, Vector2i(T, T)), o)
	return true


## Hierba (variante `grass_variant`) con un dibujo de fondo transparente encima.
static func _on_grass(image: Image, grass_variant: int, group: StringName, cell: Vector2i, o: Vector2i, style: Dictionary) -> bool:
	if not has_group(&"suelo") or not has_group(group):
		return false
	_blit(image, &"suelo", Vector2i(grass_variant, 0), o, style)
	return _blend(image, group, cell, o, style)
