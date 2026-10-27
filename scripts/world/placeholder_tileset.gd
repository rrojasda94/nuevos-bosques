class_name PlaceholderTileset
extends RefCounted
## Paleta y estilos del arte placeholder de los Bosques (forma de árbol, hojas, tronco y suelo, ver
## BosqueMap.styles), en colores de assets/palettes/palette_nuevos_bosques.gpl. Los usan WorldPainter
## (recoloreado de los PNG por Bosque), UnicoArt, el combate y el mapa.
## El atlas de casillas de ChunkData (make_source, variant_for, paint_tile) y TerrainTileset se
## borraron en M17b con el mundo viejo: el mundo lo dibuja WorldPainter con el arte de assets/tilesets/.
## Estados de Bosque (bosques-y-relacion.md, "Cómo se ve"): la vegetación de un Bosque enojado,
## corrupto o muerto se recolorea con la paleta (state_color): hojas más oscuras y rojizas, un
## matiz enfermo violáceo, o seca y gris. El fuego de los incendios es un sprite animado aparte
## (fire_frames).

const TILE: int = 16

# Paleta (Endesga 32).
const OUTLINE := Color("181425")
const GREEN_DARKEST := Color("193c3e")
const GREEN_DARK := Color("265c42")
const GREEN := Color("3e8948")
const GREEN_LIGHT := Color("63c74d")
const YELLOW := Color("fee761")
const WHITE := Color("ffffff")
const BROWN := Color("b86f50")
const BROWN_LIGHT := Color("e4a672")
const BROWN_DARK := Color("733e39")
const BLUE_DARK := Color("124e89")
const BLUE := Color("0099db")
const CYAN := Color("2ce8f5")
const SAND := Color("ead4aa")
const GREY_LIGHTEST := Color("c0cbdc")
const GREY_LIGHT := Color("8b9bb4")
const GREY := Color("5a6988")
const GREY_DARK := Color("3a4466")
const BLACKISH := Color("262b44")
const ROOF := Color("be4a2f")
const DOOR := Color("3e2731")

## Frutos: [color, sombra] candidatos (de la paleta), en orden de preferencia: rojo, amarillo,
## naranja, magenta, blanco y azul. Ver fruit_color.
const FRUIT_COLORS: Array = [
	[Color("e43b44"), Color("a22633")], [Color("fee761"), Color("feae34")], [Color("f77622"), Color("be4a2f")],
	[Color("b55088"), Color("68386c")], [Color("ffffff"), Color("c0cbdc")], [Color("0099db"), Color("124e89")],
]
## Distancia RGB mínima entre el fruto y las hojas (fruit_color).
const FRUIT_CONTRAST: float = 0.5


## Paleta completa (assets/palettes/palette_nuevos_bosques.gpl), para recolorear por estado.
const PALETTE: Array[Color] = [
	Color("be4a2f"), Color("d77643"), Color("ead4aa"), Color("e4a672"), Color("b86f50"), Color("733e39"),
	Color("3e2731"), Color("a22633"), Color("e43b44"), Color("f77622"), Color("feae34"), Color("fee761"),
	Color("63c74d"), Color("3e8948"), Color("265c42"), Color("193c3e"), Color("124e89"), Color("0099db"),
	Color("2ce8f5"), Color("ffffff"), Color("c0cbdc"), Color("8b9bb4"), Color("5a6988"), Color("3a4466"),
	Color("262b44"), Color("181425"), Color("ff0044"), Color("68386c"), Color("b55088"), Color("f6757a"),
	Color("e8b796"), Color("c28569"),
]
## Colores de un Bosque muerto: grises y pardos secos.
const DEAD_COLORS: Array[Color] = [
	Color("262b44"), Color("3a4466"), Color("5a6988"), Color("8b9bb4"), Color("c0cbdc"),
	Color("3e2731"), Color("733e39"), Color("c28569"),
]
## Colores de un Bosque corrupto: violetas enfermos mezclados con verdes apagados.
const CORRUPT_COLORS: Array[Color] = [
	Color("3e2731"), Color("68386c"), Color("b55088"), Color("193c3e"), Color("265c42"), Color("3e8948"),
	Color("f6757a"),
]
## Tinte de cada estado: hacia qué color se lleva (antes de buscar el más cercano de la paleta).
const ANGRY_TINT := Color("a22633")
const CORRUPT_TINT := Color("68386c")
const DEAD_TINT := Color("733e39")
## Fuego: fotogramas y velocidad (fotogramas por segundo).
const FIRE_FRAMES: int = 3
const FIRE_FPS: float = 6.0
const FIRE_COLORS: Array[Color] = [Color("a22633"), Color("e43b44"), Color("f77622"), Color("feae34"), Color("fee761")]

static var _fire_frames: Array[Texture2D] = []

enum Shape { ROUND, CONIFER, PALM, CACTUS, THORNY, WILLOW }
const SHAPE_COUNT: int = 6
const SHAPE_NAMES: Array[String] = ["copa redonda", "conífera", "palmera", "cactus", "espinoso", "sauce"]

## Hojas: [oscuro, claro]. Todas de la paleta.
const LEAVES: Array = [
	[Color("265c42"), Color("3e8948")], [Color("3e8948"), Color("63c74d")],
	[Color("124e89"), Color("0099db")], [Color("0099db"), Color("2ce8f5")],
	[Color("68386c"), Color("b55088")], [Color("b55088"), Color("f6757a")],
	[Color("a22633"), Color("e43b44")], [Color("be4a2f"), Color("f77622")],
	[Color("feae34"), Color("fee761")], [Color("8b9bb4"), Color("ffffff")],
	[Color("3a4466"), Color("5a6988")], [Color("733e39"), Color("b86f50")],
]
const TRUNKS: Array = [
	Color("733e39"), Color("3e2731"), Color("ffffff"), Color("f77622"),
	Color("c0cbdc"), Color("262b44"), Color("e8b796"), Color("a22633"),
]
## Suelo: [hierba, motas de hierba, claro, motas de claro, sombra de la hierba].
const GROUNDS: Array = [
	[Color("3e8948"), Color("63c74d"), Color("63c74d"), Color("3e8948"), Color("265c42")],
	[Color("265c42"), Color("3e8948"), Color("3e8948"), Color("63c74d"), Color("193c3e")],
	[Color("e4a672"), Color("ead4aa"), Color("ead4aa"), Color("e4a672"), Color("c28569")],
	[Color("c28569"), Color("e8b796"), Color("e8b796"), Color("c28569"), Color("b86f50")],
]



## El estado cambia los colores del Bosque.
static func is_tinted_state(state: String) -> bool:
	return state == BosqueMap.STATE_ENOJADO or state == BosqueMap.STATE_CORRUPTO or state == BosqueMap.STATE_MUERTO


## Color de un píxel en un Bosque con ese estado, siempre de la paleta. Transparente y contorno no
## cambian. Enojado: más oscuro y rojizo. Corrupto: hacia el violeta (matiz enfermo). Muerto: gris
## y pardo (seco), solo con DEAD_COLORS.
static func state_color(c: Color, state: String) -> Color:
	if c.a == 0.0 or c == OUTLINE:
		return c
	var target: Color = c
	var pool: Array[Color] = PALETTE
	match state:
		BosqueMap.STATE_ENOJADO:
			target = c.darkened(0.35).lerp(ANGRY_TINT, 0.15)
		BosqueMap.STATE_CORRUPTO:
			target = c.lerp(CORRUPT_TINT, 0.5)
			pool = CORRUPT_COLORS
		BosqueMap.STATE_MUERTO:
			var l: float = c.get_luminance()
			target = Color(l, l, l).lerp(DEAD_TINT, 0.2)
			pool = DEAD_COLORS
		_:
			return c
	var best: Color = pool[0]
	var best_d: float = INF
	for p: Color in pool:
		var d: float = _rgb_distance(p, target)
		if d < best_d:
			best_d = d
			best = p
	return Color(best.r, best.g, best.b, c.a)


## Recolorea `rect` de `img` con state_color. `cache`: color original (RGBA32) -> color nuevo.
static func tint_rect(img: Image, rect: Rect2i, state: String, cache: Dictionary) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var c: Color = img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var k: int = c.to_rgba32()
			if not cache.has(k):
				cache[k] = state_color(c, state)
			img.set_pixel(x, y, cache[k])


## Fotogramas del fuego (16 x 16, fondo transparente, colores de la paleta): llamas que suben y
## bajan sobre una base de ceniza.
static func fire_frames() -> Array[Texture2D]:
	if not _fire_frames.is_empty():
		return _fire_frames
	for f: int in FIRE_FRAMES:
		var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
		var heights: Array[int] = []
		for x: int in TILE:
			var edge: float = 1.0 - absf(x - 7.5) / 8.0
			heights.append(roundi(3 + edge * 9 + ChunkGenerator.hash_ints([x, f, 17]) % 4))
		for x: int in TILE:
			var h: int = clampi((heights[maxi(0, x - 1)] + heights[x] * 2 + heights[mini(TILE - 1, x + 1)]) / 4, 1, TILE - 1)
			for k: int in h:
				var y: int = TILE - 1 - k
				var t: float = float(k) / h
				var core: float = 1.0 - absf(x - 7.5) / 8.0
				var idx: int = clampi(roundi((1.0 - t) * 2.0 + core * 2.5) - 1, 0, FIRE_COLORS.size() - 1)
				img.set_pixel(x, y, FIRE_COLORS[idx])
			img.set_pixel(x, TILE - 1 - h, OUTLINE)
		img.fill_rect(Rect2i(0, TILE - 2, TILE, 2), Color("3e2731"))
		for x: int in range(1 + f, TILE, 4):
			img.set_pixel(x, TILE - 2, Color("5a6988"))
		_fire_frames.append(ImageTexture.create_from_image(img))
	return _fire_frames


## Colores de fruto del Bosque ([color, sombra]): el primer par de FRUIT_COLORS (en orden de
## preferencia) que se aleja al menos FRUIT_CONTRAST (RGB) de sus dos colores de hoja; si ninguno
## llega, el que más se aleja.
static func fruit_color(style: Dictionary) -> Array:
	var leaf: Array = LEAVES[int(style.get("leaf", 0))]
	var best: Array = FRUIT_COLORS[0]
	var best_d: float = -1.0
	for pair: Array in FRUIT_COLORS:
		var d: float = minf(_rgb_distance(pair[0], leaf[0]), _rgb_distance(pair[0], leaf[1]))
		if d >= FRUIT_CONTRAST:
			return pair
		if d > best_d:
			best_d = d
			best = pair
	return best


static func _rgb_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

