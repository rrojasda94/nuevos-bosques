class_name WorldPainter
extends RefCounted
## Arte del Mundo 2.0 para WorldView (ADR 0014 §3 "Orden de dibujo"; atlas de M13 en
## docs/art/specs/mundo-2.md §8). Tres cosas:
## 1. build_tile_set(): un TileSet con un TileSetAtlasSource por atlas, recoloreado con los
##    colores de un Bosque. Los grupos con hierba (hierba, relieve, sombras) llevan DOS fuentes:
##    normal y alta (GROUNDS_HIGH, casillas con level >= HIGH_LEVEL; spec §2.4).
## 2. Texturas recoloreadas de los sprites de objetos y setup_sprite() (origen en la base, §7).
## 3. paint_sector(): lógica pura que, de los WorldChunk ya cargados, decide qué pieza va en cada
##    casilla de un sector en las dos capas planas (suelo y sombras/decoración). No toca nodos:
##    se puede llamar desde un hilo (los chunks son inmutables) y se testea con GUT.
##
## ponytail: recolor por Bosque. Hoy todo el mundo se pinta con el estilo de UN Bosque (el de la
## villa natal). El paso siguiente (M14–M17) es una pareja de fuentes normal/alta por estilo,
## recoloreada en un hilo cuando un chunk de un Bosque nuevo entra en el anillo de prefetch, con
## `source_base(style)` en el código de cada casilla. El código ya separa fuente y pieza.
## ponytail: los suelos de la 0.3 (claro, pedregal, sendero, camino, agua, puente, plaza) usan
## sus PNG de la 0.3 con su máscara de bordes, sin la variante alta, hasta M18.

## Fuentes del TileSet. Las *_HIGH son la misma rejilla con GROUNDS_HIGH.
enum Src {
	GRASS, GRASS_HIGH, RELIEF, RELIEF_HIGH, WATERFALL, SHADOWS, SHADOWS_HIGH, DECOR, PEBBLES,
	SUELO, PATH, ROAD, WATER, BRIDGE, PLAZA,
}

const DIR: String = "res://assets/tilesets/"
const TILE: int = WorldCoords.TILE
## Nivel desde el que la hierba usa la tabla alta (spec §2.4).
const HIGH_LEVEL: int = 2
const NONE: int = -1
const WATER_FPS_FRAME: float = 0.5
const WATERFALL_FRAME: float = 0.25

const KEY_GRASS: int = 0x3e8948ff
const KEY_GRASS_SPECK: int = 0x63c74dff
const KEY_GRASS_SHADOW: int = 0x265c42ff
const KEY_CLEARING: int = 0xead4aaff
const KEY_CLEARING_SPECK: int = 0xe4a672ff
const KEY_LEAF_LIGHT: int = 0xc0cbdcff
const KEY_LEAF_DARK: int = 0x8b9bb4ff
const KEY_TRUNK: int = 0x5a6988ff
const KEY_FRUIT: int = 0xe43b44ff
const KEY_FRUIT_SHADOW: int = 0xa22633ff
const KEY_LEAF_SHADOW: int = 0x3a4466ff
const KEY_FLOWER_2: int = 0xf6757aff
const KEY_FLOWER_3: int = 0xff0044ff

## Sombra de hoja por `leaf` (spec §2.2).
const LEAF_SHADOW: Array[String] = [
	"193c3e", "265c42", "262b44", "124e89", "3e2731", "68386c",
	"3e2731", "733e39", "d77643", "5a6988", "262b44", "3e2731",
]
## Hierba de las mesetas altas por `ground`: [hierba, brizna, sombra] (spec §2.4).
const GROUNDS_HIGH: Array = [
	["63c74d", "3e8948", "3e8948"], ["3e8948", "63c74d", "265c42"],
	["ead4aa", "e4a672", "e4a672"], ["e8b796", "c28569", "c28569"],
]
## Preferencia de colores de flor 2 y 3 (spec §2.3; sin el acento místico 2ce8f5).
const FLOWER_PREFS: Array[String] = ["fee761", "ffffff", "f6757a", "b55088", "feae34", "f77622", "0099db", "e43b44"]

## Atlas de las capas planas: fuente -> [archivo, juegos de claves, alta].
const TILE_ATLASES: Dictionary = {
	Src.GRASS: ["tileset_hierba.png", ["grass"]],
	Src.GRASS_HIGH: ["tileset_hierba.png", ["grass_high"]],
	Src.RELIEF: ["tileset_relieve.png", ["grass"]],
	Src.RELIEF_HIGH: ["tileset_relieve.png", ["grass_high"]],
	Src.WATERFALL: ["tileset_cascada.png", ["grass"]],
	Src.SHADOWS: ["tileset_sombras.png", ["grass"]],
	Src.SHADOWS_HIGH: ["tileset_sombras.png", ["grass_high"]],
	Src.DECOR: ["tileset_decoracion.png", ["grass", "tree", "flower"]],
	Src.PEBBLES: ["tileset_piedras.png", ["grass"]],
	Src.SUELO: ["tileset_suelo.png", ["grass", "clearing"]],
	Src.PATH: ["tileset_sendero.png", ["grass"]],
	Src.ROAD: ["tileset_camino.png", ["grass"]],
	Src.WATER: ["tileset_agua.png", []],
	Src.BRIDGE: ["tileset_puente.png", []],
	Src.PLAZA: ["tileset_plaza.png", ["clearing"]],
}
## Sprites de objetos: nombre -> [archivo, juegos de claves].
const SPRITE_ATLASES: Dictionary = {
	&"arboles": ["sprite_arboles.png", ["grass", "tree", "fruit", "leaf_shadow"]],
	&"joven": ["sprite_arbol_joven.png", ["grass", "tree", "fruit", "leaf_shadow"]],
	&"grande": ["sprite_arbol_grande.png", ["grass", "tree", "fruit", "leaf_shadow"]],
	&"rocas": ["sprite_rocas.png", ["grass"]],
	&"rocas_pequenas": ["sprite_rocas_pequenas.png", ["grass"]],
	&"madera": ["sprite_madera.png", ["grass", "tree", "leaf_shadow"]],
	&"casas": ["sprite_casas.png", ["clearing"]],
	&"nujio": ["sprite_nujio.png", ["grass", "tree", "leaf_shadow"]],
	&"letrero": ["tileset_letrero.png", []],
}
## Columnas del relieve (spec §8).
const FACE_LEFT: int = 0
const FACE_MID: int = 1
const FACE_RIGHT: int = 4
const FACE_SINGLE: int = 5
const STAIRS_COL: int = 6
const CAVE_LIP_COL: int = 9
const CAVE_COL: int = 11
const EDGE_ROW: int = 3
const RAMP_N_ROW: int = 5
const ROW_MASK: int = (1 << ChunkBuilder.VARIANT_COLUMN_SHIFT) - 1
## Primer valor de `decor` que es decoración (los de antes son sombras, ChunkBuilder.Decor).
## ponytail: el catálogo de decoración lo fija M8; hasta entonces decor >= DECOR_FIRST se lee
## como el catálogo común de la spec (§6.2) en orden, empezando en 1.
const DECOR_FIRST: int = 3
const VALID_EDGE_MASKS: Array[int] = [1, 2, 3, 8, 9, 10, 11]
## Bits de máscara de bordes (los de la 0.3).
const N: int = 1
const E: int = 2
const S: int = 4
const W: int = 8
## Nujio: 2 fotogramas a 1 fps (spec §5).
const NUJIO_FRAME_W: int = 64

## Rejilla local con 1 casilla de margen alrededor del sector.
const _W: int = WorldCoords.SECTOR + 2
const _FACE_FAMILY: int = (1 << WorldChunk.Cliff.FACE) | (1 << WorldChunk.Cliff.STAIRS) | (1 << WorldChunk.Cliff.WATERFALL)
const _WATER: int = (1 << WorldChunk.Ground.RIVER_NARROW) | (1 << WorldChunk.Ground.RIVER_NAVIGABLE) \
		| (1 << WorldChunk.Ground.LAKE) | (1 << WorldChunk.Ground.SEA) | (1 << WorldChunk.Ground.FORD)
const _GRASSY: int = (1 << WorldChunk.Ground.GRASS) | (1 << WorldChunk.Ground.ROCKY) | (1 << WorldChunk.Ground.CLEARING)

var style: Dictionary = {}
var textures: Dictionary = {}  # StringName -> ImageTexture (sprites)
var _flowers: Array[Color] = []


func _init(bosque_style: Dictionary = {}) -> void:
	style = bosque_style
	_flowers = flower_colors(style)


# --- Recoloreado ---------------------------------------------------------------------------

## Colores de flor del Bosque (spec §2.3).
## ponytail: falta el criterio de contraste sobre la hierba y la regla del centro blanco.
static func flower_colors(bosque_style: Dictionary) -> Array[Color]:
	var first: Color = PlaceholderTileset.fruit_color(bosque_style)[0]
	var out: Array[Color] = [first]
	for hex: String in FLOWER_PREFS:
		var c := Color(hex)
		if out.size() < 3 and not out.has(c):
			out.append(c)
	return out


## Clave RGBA32 -> color del Bosque para los juegos de claves `sets`.
func key_map(sets: Array) -> Dictionary:
	var out: Dictionary = {}
	var g: int = int(style.get("ground", 0)) % PlaceholderTileset.GROUNDS.size()
	var ground: Array = PlaceholderTileset.GROUNDS[g]
	var leaf_i: int = int(style.get("leaf", 0)) % PlaceholderTileset.LEAVES.size()
	var leaf: Array = PlaceholderTileset.LEAVES[leaf_i]
	var fruit: Array = PlaceholderTileset.fruit_color(style)
	for set_name: String in sets:
		match set_name:
			"grass":
				out[KEY_GRASS] = ground[0]
				out[KEY_GRASS_SPECK] = ground[1]
				out[KEY_GRASS_SHADOW] = ground[4]
			"grass_high":
				var high: Array = GROUNDS_HIGH[g]
				out[KEY_GRASS] = Color(high[0])
				out[KEY_GRASS_SPECK] = Color(high[1])
				out[KEY_GRASS_SHADOW] = Color(high[2])
			"clearing":
				out[KEY_CLEARING] = ground[2]
				out[KEY_CLEARING_SPECK] = ground[3]
			"tree":
				out[KEY_LEAF_LIGHT] = leaf[1]
				out[KEY_LEAF_DARK] = leaf[0]
				out[KEY_TRUNK] = PlaceholderTileset.TRUNKS[int(style.get("trunk", 0)) % PlaceholderTileset.TRUNKS.size()]
				out[KEY_LEAF_SHADOW] = Color(LEAF_SHADOW[leaf_i])
			"leaf_shadow":
				out[KEY_LEAF_SHADOW] = Color(LEAF_SHADOW[leaf_i])
			"fruit":
				out[KEY_FRUIT] = fruit[0]
				out[KEY_FRUIT_SHADOW] = fruit[1]
			"flower":
				out[KEY_FRUIT] = _flowers[0]
				out[KEY_FLOWER_2] = _flowers[1]
				out[KEY_FLOWER_3] = _flowers[2]
	return out


## Cambia en una pasada cada clave por su color (alfa 0 se salta). Devuelve una imagen nueva.
static func recolor(img: Image, mapping: Dictionary) -> Image:
	if mapping.is_empty():
		return img
	var data: PackedByteArray = img.get_data()
	for i: int in range(0, data.size(), 4):
		if data[i + 3] == 0:
			continue
		var key: int = (data[i] << 24) | (data[i + 1] << 16) | (data[i + 2] << 8) | data[i + 3]
		var c: Variant = mapping.get(key)
		if c != null:
			var col: Color = c
			data[i] = col.r8
			data[i + 1] = col.g8
			data[i + 2] = col.b8
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)


## PNG tal cual (RGBA8). Si falta, un cuadro magenta del tamaño pedido (se ve el hueco).
static func load_image(file: String, fallback_size: Vector2i = Vector2i(TILE, TILE)) -> Image:
	var path: String = DIR + file
	if ResourceLoader.exists(path):
		var img: Image = (load(path) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		return img
	push_warning("WorldPainter: falta %s; se dibuja un placeholder." % path)
	var ph := Image.create(fallback_size.x, fallback_size.y, false, Image.FORMAT_RGBA8)
	ph.fill(Color("ff00ff"))
	return ph


# --- TileSet y texturas ----------------------------------------------------------------------

func build_tile_set() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var raw: Dictionary = {}
	for src: int in TILE_ATLASES:
		var entry: Array = TILE_ATLASES[src]
		var file: String = entry[0]
		if not raw.has(file):
			raw[file] = load_image(file, Vector2i(256, 192))
		var img: Image = recolor(raw[file], key_map(entry[1]))
		var atlas := TileSetAtlasSource.new()
		atlas.texture = ImageTexture.create_from_image(img)
		atlas.texture_region_size = Vector2i(TILE, TILE)
		var grid := Vector2i(img.get_width() / TILE, img.get_height() / TILE)
		match src:
			Src.WATER:
				# Fila = tipo * 2 + fotograma: el segundo fotograma va debajo (1 columna).
				for y: int in range(0, grid.y, 2):
					for x: int in grid.x:
						_animated_tile(atlas, Vector2i(x, y), 2, 1, WATER_FPS_FRAME)
			Src.WATERFALL:
				# 3 piezas × 4 fotogramas seguidos por fila.
				for y: int in grid.y:
					for x: int in range(0, grid.x, 4):
						_animated_tile(atlas, Vector2i(x, y), 4, 0, WATERFALL_FRAME)
			_:
				for y: int in grid.y:
					for x: int in grid.x:
						atlas.create_tile(Vector2i(x, y))
						if src == Src.DECOR or src == Src.PEBBLES:
							var alt: int = atlas.create_alternative_tile(Vector2i(x, y))
							atlas.get_tile_data(Vector2i(x, y), alt).flip_h = true
		ts.add_source(atlas, src)
	return ts


static func _animated_tile(atlas: TileSetAtlasSource, coords: Vector2i, frames: int, columns: int, duration: float) -> void:
	atlas.create_tile(coords)
	atlas.set_tile_animation_columns(coords, columns)
	atlas.set_tile_animation_frames_count(coords, frames)
	for f: int in frames:
		atlas.set_tile_animation_frame_duration(coords, f, duration)


## Texturas recoloreadas de los sprites (una vez, al cargar).
func build_textures() -> void:
	for id: StringName in SPRITE_ATLASES:
		var entry: Array = SPRITE_ATLASES[id]
		textures[id] = ImageTexture.create_from_image(recolor(load_image(entry[0], Vector2i(64, 64)), key_map(entry[1])))


## Fila de la silueta del Bosque en los atlas de árboles y Nujio.
func shape_row() -> int:
	return int(style.get("shape", 0)) % PlaceholderTileset.SHAPE_COUNT


## Posición de dibujo (base de la huella, spec §7) de un objeto con esquina noroeste `nw`
## (casilla global) y tamaño `size` en casillas.
static func object_base(nw: Vector2i, size: Vector2i) -> Vector2:
	return WorldCoords.world_cell_origin(nw + Vector2i(0, size.y)) + Vector2(size.x * TILE * 0.5, 0.0)


## Dirección del letrero -> columna del atlas (0 = este, sentido horario).
static func sign_column(direction: Vector2i) -> int:
	if direction == Vector2i.ZERO:
		return 0
	var angle: float = Vector2(direction).angle()
	return posmod(roundi(angle / (PI / 4.0)), 8)


## Prepara un Sprite2D del pool para el objeto `obj` del chunk `chunk_coord`. false si el
## objeto no se dibuja como sprite (la cueva va en la capa de suelo).
func setup_sprite(sp: Sprite2D, obj: Dictionary, chunk_coord: Vector2i, sign_dir: Vector2i = Vector2i.ZERO) -> bool:
	var kind: int = obj.kind
	var size: Vector2i = obj.size
	var v: int = obj.variant
	var shape: int = shape_row()
	var tex: StringName
	var region: Rect2i
	var flip: bool = false
	match kind:
		WorldChunk.ObjectKind.TREE:
			tex = &"arboles"
			region = Rect2i((v % 4) * 32, shape * 32, 32, 32)
			flip = (v / 4) % 2 == 1
		WorldChunk.ObjectKind.FRUIT_TREE:
			# ponytail: el frutal vaciado (cols 6–7) sale de GameState en M14.
			tex = &"arboles"
			region = Rect2i((4 + v % 2) * 32, shape * 32, 32, 32)
			flip = (v / 2) % 2 == 1
		WorldChunk.ObjectKind.REFUGE_TREE:
			tex = &"arboles"
			region = Rect2i(8 * 32, shape * 32, 32, 32)
			flip = v % 2 == 1
		WorldChunk.ObjectKind.TREE_DEAD:
			tex = &"arboles"
			region = Rect2i(9 * 32, shape * 32, 32, 32)
			flip = v % 2 == 1
		WorldChunk.ObjectKind.TREE_YOUNG:
			tex = &"joven"
			region = Rect2i((v % 2) * 16, shape * 16, 16, 16)
			flip = (v / 2) % 2 == 1
		WorldChunk.ObjectKind.TREE_BIG, WorldChunk.ObjectKind.LANDMARK:
			# ponytail: el hito 3×3 no tiene pieza en M13; se dibuja como árbol grande.
			tex = &"grande"
			region = Rect2i(0, shape * 48, 48, 48)
			flip = v % 2 == 1
		WorldChunk.ObjectKind.ROCK:
			if size.x >= 2:
				tex = &"rocas"
				region = Rect2i((v % 3) * 32, 0, 32, 32)
			else:
				tex = &"rocas_pequenas"
				region = Rect2i((v % 2) * 16, 0, 16, 16)
		WorldChunk.ObjectKind.STUMP:
			tex = &"madera"
			region = Rect2i((v % 2) * 16, 0, 16, 16)
			flip = (v / 2) % 2 == 1
		WorldChunk.ObjectKind.LOG:
			tex = &"madera"
			region = Rect2i(32 + (v % 2) * 32, 0, 32, 16)
			flip = (v / 2) % 2 == 1
		WorldChunk.ObjectKind.HOUSE:
			tex = &"casas"
			region = Rect2i((v % 2) * 64, ((v / 2) % 2) * 48, 64, 48)
		WorldChunk.ObjectKind.NUJIO:
			tex = &"nujio"
			region = Rect2i(0, shape * 80, 64, 80)
			flip = v % 2 == 1
		WorldChunk.ObjectKind.SIGN:
			tex = &"letrero"
			region = Rect2i(sign_column(sign_dir) * 16, 0, 16, 16)
		_:
			return false
	sp.texture = textures.get(tex)
	sp.centered = false
	sp.region_enabled = true
	sp.region_rect = Rect2(region)
	sp.offset = Vector2(-region.size.x / 2.0, -region.size.y)
	sp.flip_h = flip
	sp.position = object_base(WorldCoords.to_world_cell(chunk_coord, obj.cell), size)
	sp.visible = true
	return true


# --- Piezas de las capas planas (lógica pura) ------------------------------------------------

## Código de una casilla de TileMapLayer: fuente, columna y fila del atlas y alternativa.
static func encode(src: int, x: int, y: int, alt: int = 0) -> int:
	return (src << 24) | (x << 16) | (y << 8) | alt


static func code_source(code: int) -> int:
	return code >> 24


static func code_atlas(code: int) -> Vector2i:
	return Vector2i((code >> 16) & 255, (code >> 8) & 255)


static func code_alt(code: int) -> int:
	return code & 255


## Pieza de decoración plana para `decor` 1–24 (catálogo común, spec §6.2 y §8): 1–16 fila 0
## del atlas de decoración, 17–20 fila 1 (setas y raíces), 21–24 piedras. -1 si no hay.
static func decor_atlas(value: int) -> Vector3i:
	if value >= 1 and value <= 16:
		return Vector3i(Src.DECOR, value - 1, 0)
	if value >= 17 and value <= 20:
		return Vector3i(Src.DECOR, value - 17, 1)
	if value >= 21 and value <= 24:
		return Vector3i(Src.PEBBLES, value - 21, 0)
	return Vector3i(-1, 0, 0)


static func cell_hash(x: int, y: int) -> int:
	var h: int = (x * 73856093) ^ (y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff


## Piezas del sector global `sector` a partir de los chunks en memoria (`chunks`: Vector2i ->
## WorldChunk; tiene que estar el del sector). Devuelve { ground: PackedInt32Array(256),
## overlay: PackedInt32Array(256) } con códigos de encode() (NONE = casilla vacía), fila a fila,
## o {} si falta el chunk. Los vecinos de otros chunks se leen si están; si no, se copia la
## casilla de dentro (no se dibuja borde).
static func paint_sector(sector: Vector2i, chunks: Dictionary) -> Dictionary:
	var sz: int = WorldCoords.SECTOR
	var origin: Vector2i = WorldCoords.sector_origin(sector)
	var chunk_coord: Vector2i = WorldCoords.world_cell_to_chunk(origin)
	var ch: WorldChunk = chunks.get(chunk_coord)
	if ch == null:
		return {}
	var local: Vector2i = WorldCoords.world_cell_to_cell(origin)
	var n: int = _W * _W
	var gg := PackedByteArray()
	var gl := PackedByteArray()
	var gc := PackedByteArray()
	var go := PackedInt32Array()
	gg.resize(n)
	gl.resize(n)
	gc.resize(n)
	go.resize(n)
	# Interior: un solo chunk (los sectores no cruzan chunks).
	for ly: int in sz:
		var row: int = (local.y + ly) * WorldChunk.SIZE + local.x
		var k0: int = (ly + 1) * _W + 1
		for lx: int in sz:
			var i: int = row + lx
			var k: int = k0 + lx
			gg[k] = ch.ground[i]
			gl[k] = ch.level[i]
			gc[k] = ch.cliff[i]
			go[k] = ch.occupant[i]
	# Margen: de los chunks vecinos si están.
	for ly: int in range(-1, sz + 1):
		for lx: int in range(-1, sz + 1):
			if lx >= 0 and lx < sz and ly >= 0 and ly < sz:
				continue
			var k: int = (ly + 1) * _W + lx + 1
			var wc: Vector2i = origin + Vector2i(lx, ly)
			var cc: Vector2i = WorldCoords.world_cell_to_chunk(wc)
			var other: WorldChunk = ch if cc == chunk_coord else chunks.get(cc)
			if other == null:
				var kin: int = (clampi(ly, 0, sz - 1) + 1) * _W + clampi(lx, 0, sz - 1) + 1
				gg[k] = gg[kin]
				gl[k] = gl[kin]
				gc[k] = gc[kin]
				go[k] = WorldChunk.NO_OBJECT
				continue
			var i: int = WorldCoords.cell_index(WorldCoords.world_cell_to_cell(wc))
			gg[k] = other.ground[i]
			gl[k] = other.level[i]
			gc[k] = other.cliff[i]
			go[k] = other.occupant[i] if other == ch else WorldChunk.NO_OBJECT
	var ground := PackedInt32Array()
	var overlay := PackedInt32Array()
	ground.resize(sz * sz)
	overlay.resize(sz * sz)
	for ly: int in sz:
		var row: int = (local.y + ly) * WorldChunk.SIZE + local.x
		for lx: int in sz:
			var k: int = (ly + 1) * _W + lx + 1
			var i: int = row + lx
			var wx: int = origin.x + lx
			var wy: int = origin.y + ly
			var h: int = cell_hash(wx, wy)
			ground[ly * sz + lx] = _ground_code(ch, gg, gl, gc, go, k, i, wx, h)
			overlay[ly * sz + lx] = _overlay_code(ch, gg, gl, gc, go, k, i, h)
	return {"ground": ground, "overlay": overlay}


static func _fam(gc: PackedByteArray, k: int) -> bool:
	return (_FACE_FAMILY >> gc[k]) & 1 == 1


static func _is_water(g: int) -> bool:
	return (_WATER >> g) & 1 == 1


static func _ground_code(ch: WorldChunk, gg: PackedByteArray, gl: PackedByteArray, gc: PackedByteArray,
		go: PackedInt32Array, k: int, i: int, wx: int, h: int) -> int:
	var c: int = gc[k]
	var l: int = gl[k]
	var high: bool = l >= HIGH_LEVEL
	var relief: int = Src.RELIEF_HIGH if high else Src.RELIEF
	var occ: int = go[k]
	if occ != WorldChunk.NO_OBJECT and ch.objects[occ].kind == WorldChunk.ObjectKind.CAVE:
		return _cave_code(ch, occ, i, relief)
	# Las piezas de risco las decide ChunkBuilder en `variant` (fila | columna << 2; bordes y
	# rampas: la máscara).
	var v: int = ch.variant[i]
	var row: int = v & ROW_MASK
	var piece: int = v >> ChunkBuilder.VARIANT_COLUMN_SHIFT
	match c:
		WorldChunk.Cliff.FACE:
			return encode(relief, piece, row)
		WorldChunk.Cliff.STAIRS:
			return encode(relief, STAIRS_COL + piece, row)
		WorldChunk.Cliff.WATERFALL:
			return encode(Src.WATERFALL, piece * 4, row)
		WorldChunk.Cliff.EDGE:
			if v == ChunkBuilder.EDGE_PEAK:
				# ponytail: la cumbre no tiene pieza en M13; se dibuja como roca de cara.
				return encode(relief, FACE_MID + posmod(wx, 3), 1)
			if VALID_EDGE_MASKS.has(v):
				return encode(relief, v, EDGE_ROW)
		WorldChunk.Cliff.RAMP:
			var road: bool = gg[k] == WorldChunk.Ground.ROAD
			if v & N != 0:
				var ls: bool = gc[k - 1] == WorldChunk.Cliff.RAMP
				var rs: bool = gc[k + 1] == WorldChunk.Cliff.RAMP
				var col: int = 1
				if rs and not ls:
					col = 0
				elif ls and not rs:
					col = 2
				return encode(relief, col + (3 if road else 0), RAMP_N_ROW)
			if v & (E | W) != 0:
				var us: bool = gc[k - _W] == WorldChunk.Cliff.RAMP
				var ds: bool = gc[k + _W] == WorldChunk.Cliff.RAMP
				var ramp_row: int = RAMP_N_ROW + 1
				if ds and not us:
					ramp_row = RAMP_N_ROW
				elif us and not ds:
					ramp_row = RAMP_N_ROW + 2
				return encode(relief, (6 if v & W != 0 else 8) + (1 if road else 0), ramp_row)
	var g: int = gg[k]
	match g:
		WorldChunk.Ground.GRASS:
			return encode(Src.GRASS_HIGH if high else Src.GRASS, ch.variant[i] % 4, 0)
		WorldChunk.Ground.ROCKY:
			return encode(Src.SUELO, h % 4, 1)
		WorldChunk.Ground.CLEARING:
			return encode(Src.SUELO, _mask_outside(gg, gc, k, _GRASSY & ~(1 << WorldChunk.Ground.CLEARING)), 2 + h % 2)
		WorldChunk.Ground.PATH:
			return encode(Src.PATH, _mask_outside(gg, gc, k, _GRASSY), h % 2)
		WorldChunk.Ground.ROAD:
			return encode(Src.ROAD, _mask_outside(gg, gc, k, _GRASSY), h % 2)
		WorldChunk.Ground.PLAZA:
			return encode(Src.PLAZA, _mask_not(gg, k, 1 << WorldChunk.Ground.PLAZA), h % 2)
		WorldChunk.Ground.BRIDGE:
			var sideways: bool = _is_water(gg[k - 1]) or _is_water(gg[k + 1])
			return encode(Src.BRIDGE, 0 if sideways else 1, h % 2)
	if _is_water(g):
		if gc[k - _W] == WorldChunk.Cliff.WATERFALL:
			return encode(Src.WATERFALL, _waterfall_col(gc, k - _W), 3)
		var water_row: int = 4 if g == WorldChunk.Ground.FORD else (0 if g == WorldChunk.Ground.RIVER_NARROW else 2)
		var keep: int = _WATER | (1 << WorldChunk.Ground.BRIDGE)
		return encode(Src.WATER, _mask_not(gg, k, keep), water_row)
	return encode(Src.GRASS_HIGH if high else Src.GRASS, ch.variant[i] % 4, 0)


static func _waterfall_col(gc: PackedByteArray, k: int) -> int:
	var left: bool = _fam(gc, k - 1)
	var right: bool = _fam(gc, k + 1)
	if right and not left:
		return 0
	if left and not right:
		return 8
	return 4


static func _cave_code(ch: WorldChunk, occ: int, i: int, relief: int) -> int:
	var obj: Dictionary = ch.objects[occ]
	var cell: Vector2i = WorldCoords.index_to_cell(i)
	var d: Vector2i = cell - (obj.cell as Vector2i)
	var top: Vector2i = obj.cell
	var above: Vector2i = top + Vector2i.UP
	var lip: bool = not WorldChunk.in_bounds(above) or (_FACE_FAMILY >> ch.get_cliff(above)) & 1 == 0
	return encode(relief, (CAVE_LIP_COL if lip else CAVE_COL) + clampi(d.x, 0, 1), clampi(d.y, 0, 1))


## Máscara N/E/S/O de los vecinos cuyo suelo está en `outside` o que son risco (cara o borde).
static func _mask_outside(gg: PackedByteArray, gc: PackedByteArray, k: int, outside: int) -> int:
	var m: int = 0
	var cliffs: int = (1 << WorldChunk.Cliff.FACE) | (1 << WorldChunk.Cliff.EDGE)
	if (outside >> gg[k - _W]) & 1 == 1 or (cliffs >> gc[k - _W]) & 1 == 1:
		m |= N
	if (outside >> gg[k + 1]) & 1 == 1 or (cliffs >> gc[k + 1]) & 1 == 1:
		m |= E
	if (outside >> gg[k + _W]) & 1 == 1 or (cliffs >> gc[k + _W]) & 1 == 1:
		m |= S
	if (outside >> gg[k - 1]) & 1 == 1 or (cliffs >> gc[k - 1]) & 1 == 1:
		m |= W
	return m


## Máscara de los vecinos cuyo suelo NO está en `keep`.
static func _mask_not(gg: PackedByteArray, k: int, keep: int) -> int:
	var m: int = 0
	if (keep >> gg[k - _W]) & 1 == 0:
		m |= N
	if (keep >> gg[k + 1]) & 1 == 0:
		m |= E
	if (keep >> gg[k + _W]) & 1 == 0:
		m |= S
	if (keep >> gg[k - 1]) & 1 == 0:
		m |= W
	return m


## Capa 2: sombra al pie de una cara, sombra este, sombra de objeto o decoración (una pieza).
static func _overlay_code(ch: WorldChunk, gg: PackedByteArray, gl: PackedByteArray, gc: PackedByteArray,
		go: PackedInt32Array, k: int, i: int, h: int) -> int:
	if _fam(gc, k) or gc[k] == WorldChunk.Cliff.EDGE:
		return NONE
	var g: int = gg[k]
	var under: int = -1
	if (_GRASSY >> g) & 1 == 1 or g == WorldChunk.Ground.PLAZA:
		under = h % 2
	elif g == WorldChunk.Ground.PATH:
		under = 2
	elif g == WorldChunk.Ground.ROAD or g == WorldChunk.Ground.BRIDGE:
		under = 3
	elif _is_water(g):
		under = 4
	var src: int = Src.SHADOWS_HIGH if gl[k] >= HIGH_LEVEL else Src.SHADOWS
	var d: int = ch.decor[i]
	if under >= 0 and d == ChunkBuilder.Decor.SHADOW_FOOT:
		return encode(src, under, 0)
	if under >= 0 and d == ChunkBuilder.Decor.SHADOW_EAST:
		return encode(src, under, 1)
	var above: int = go[k - _W]
	if above != WorldChunk.NO_OBJECT and above != go[k] and under >= 0 and under <= 1:
		var kind: int = ch.objects[above].kind
		if kind == WorldChunk.ObjectKind.HOUSE or kind == WorldChunk.ObjectKind.NUJIO:
			var col: int = 1
			if go[k - _W - 1] != above:
				col = 0
			elif go[k - _W + 1] != above:
				col = 3
			return encode(src, col, 2)
	if d >= DECOR_FIRST and ch.blocked[i] == 0:
		var a: Vector3i = decor_atlas(d - DECOR_FIRST + 1)
		if a.x >= 0:
			return encode(a.x, a.y, a.z, (h >> 3) & 1)
	return NONE
