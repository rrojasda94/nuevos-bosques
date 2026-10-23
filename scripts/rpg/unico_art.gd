class_name UnicoArt
extends RefCounted
## Placeholder de los Únicos (ADR 0009, v1.1): monstruos dibujados por código con la combinación de
## colores de su Bosque (hojas y tronco) y un aura. El tipo de monstruo se elige de forma
## determinista por seed + id del Bosque, sin depender de la silueta del árbol.
## Lo sustituirá el arte de pixel-artist; los nombres reales son de narrative-writer.

enum Kind { QUADRUPED, SERPENT, HORNED, EYES, BIRD }
## Descriptor provisional del nombre: "Único <descriptor>" (índice = Kind).
const KIND_NAMES: Array[String] = ["cuadrúpedo", "serpiente", "cornudo", "de muchos ojos", "alado"]
const SALT_KIND: int = 22
const AURA := Color("fee761")

## Ojos por tipo: [u, v, radio], en fracciones del tamaño.
const EYES: Array = [
	[[0.15, 0.42, 0.035], [0.25, 0.42, 0.035]],
	[[0.44, 0.23, 0.035], [0.56, 0.23, 0.035]],
	[[0.45, 0.22, 0.035], [0.55, 0.22, 0.035]],
	[[0.38, 0.38, 0.06], [0.6, 0.36, 0.075], [0.48, 0.53, 0.05], [0.67, 0.53, 0.04], [0.31, 0.55, 0.04], [0.5, 0.24, 0.04]],
	[[0.46, 0.28, 0.03], [0.54, 0.28, 0.03]],
]
## Colmillos por tipo: [u, v] (punta hacia abajo). La boca es una línea que los une.
const FANGS: Array = [
	[[0.15, 0.52], [0.23, 0.52]],
	[[0.46, 0.3], [0.54, 0.3]],
	[[0.46, 0.29], [0.54, 0.29]],
	[[0.41, 0.67], [0.5, 0.68], [0.59, 0.67]],
	[],
]


static func kind_for(seed_value: int, bosque_id: int) -> Kind:
	return (ChunkGenerator.hash_ints([seed_value, bosque_id, SALT_KIND]) % Kind.size()) as Kind


static func display_name(kind: Kind) -> String:
	return "Único %s" % KIND_NAMES[kind]


## Monstruo de `px` x `px` píxeles: cuerpo con los colores del Bosque, contorno, ojos, colmillos y
## un aura punteada alrededor.
static func texture(kind: Kind, style: Dictionary, px: int) -> Texture2D:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var leaf: Array = PlaceholderTileset.LEAVES[int(style.get("leaf", 0))]
	var colors: Array = [Color(0, 0, 0, 0), leaf[0], leaf[1], PlaceholderTileset.TRUNKS[int(style.get("trunk", 0))]]
	for y: int in px:
		for x: int in px:
			var k: int = _body(kind, Vector2((x + 0.5) / px, (y + 0.5) / px))
			if k > 0:
				img.set_pixel(x, y, colors[k])
	_ring(img, 1, PlaceholderTileset.OUTLINE, false)
	_draw_mouth(img, FANGS[kind], px)
	for e: Array in EYES[kind]:
		_draw_eye(img, Vector2(e[0], e[1]) * px, maxf(2.0, e[2] * px))
	_ring(img, 2, AURA, true)
	return ImageTexture.create_from_image(img)


## 0 = vacío, 1 = color oscuro, 2 = color claro (hojas del Bosque), 3 = tronco (cuernos, patas...).
static func _body(kind: Kind, p: Vector2) -> int:
	match kind:
		Kind.QUADRUPED:
			for x: float in [0.33, 0.45, 0.65, 0.77]:
				if absf(p.x - x) < 0.04 and p.y > 0.6 and p.y < 0.86:
					return 3
			if _seg(p, Vector2(0.84, 0.5), Vector2(0.95, 0.32)) < 0.025 \
					or _seg(p, Vector2(0.15, 0.36), Vector2(0.1, 0.24)) < 0.025 \
					or _seg(p, Vector2(0.27, 0.36), Vector2(0.29, 0.24)) < 0.025:
				return 3
			if _ellipse(p, Vector2(0.2, 0.45), Vector2(0.13, 0.11)):
				return 2 if p.y < 0.39 else 1
			if _ellipse(p, Vector2(0.55, 0.55), Vector2(0.3, 0.15)):
				return 2 if p.y < 0.49 else 1
		Kind.SERPENT:
			if _seg(p, Vector2(0.5, 0.33), Vector2(0.5, 0.41)) < 0.012 \
					or _seg(p, Vector2(0.5, 0.41), Vector2(0.46, 0.45)) < 0.012 \
					or _seg(p, Vector2(0.5, 0.41), Vector2(0.54, 0.45)) < 0.012:
				return 3
			if _ellipse(p, Vector2(0.5, 0.25), Vector2(0.14, 0.1)):
				return 2 if p.y < 0.21 else 1
			if _ellipse(p, Vector2(0.5, 0.32), Vector2(0.23, 0.08)):
				return 3
			if p.y > 0.35 and p.y < 0.93:
				var cu: float = 0.5 + 0.2 * sin((p.y - 0.35) * 11.0)
				var hw: float = 0.075 + 0.04 * (p.y - 0.35)
				if absf(p.x - cu) < hw:
					return 2 if p.x < cu - hw * 0.3 else 1
		Kind.HORNED:
			for side: float in [-1.0, 1.0]:
				if _seg(p, Vector2(0.5 + side * 0.08, 0.17), Vector2(0.5 + side * 0.2, 0.03)) < 0.035 - 0.15 * (0.17 - p.y):
					return 3
				if _seg(p, Vector2(0.5 + side * 0.32, 0.66), Vector2(0.5 + side * 0.34, 0.72)) < 0.03:
					return 3
				if _seg(p, Vector2(0.5 + side * 0.18, 0.42), Vector2(0.5 + side * 0.31, 0.65)) < 0.05:
					return 1
				if _ellipse(p, Vector2(0.5 + side * 0.1, 0.93), Vector2(0.08, 0.03)):
					return 3
				if absf(p.x - (0.5 + side * 0.1)) < 0.06 and p.y > 0.66 and p.y < 0.92:
					return 1
			if _ellipse(p, Vector2(0.5, 0.24), Vector2(0.12, 0.11)):
				return 2 if p.y < 0.18 else 1
			if _ellipse(p, Vector2(0.5, 0.55), Vector2(0.1, 0.12)):
				return 2
			if _ellipse(p, Vector2(0.5, 0.52), Vector2(0.2, 0.2)):
				return 1
		Kind.EYES:
			for i: int in 6:
				var cu2: float = 0.28 + i * 0.088 + 0.03 * sin(p.y * 25.0 + i)
				if absf(p.x - cu2) < 0.025 and p.y > 0.7 and p.y < 0.96:
					return 3
			var c := Vector2(0.5, 0.48)
			var a: float = atan2(p.y - c.y, p.x - c.x)
			if p.distance_to(c) < 0.3 + 0.04 * sin(a * 5.0):
				return 2 if p.distance_to(Vector2(0.38, 0.3)) < 0.1 else 1
		Kind.BIRD:
			if _seg(p, Vector2(0.5, 0.21), Vector2(0.45, 0.1)) < 0.02 or _seg(p, Vector2(0.52, 0.21), Vector2(0.57, 0.12)) < 0.02:
				return 3
			if p.y > 0.33 and p.y < 0.45 and absf(p.x - 0.5) < 0.045 * (0.45 - p.y) / 0.12:
				return 3
			for x: float in [0.45, 0.55]:
				if absf(p.x - x) < 0.015 and p.y > 0.72 and p.y < 0.9:
					return 3
			if _ellipse(p, Vector2(0.5, 0.3), Vector2(0.1, 0.09)):
				return 1
			if _ellipse(p, Vector2(0.5, 0.58), Vector2(0.08, 0.12)):
				return 2
			if _ellipse(p, Vector2(0.5, 0.55), Vector2(0.14, 0.2)):
				return 1
			var w: float = absf(p.x - 0.5)
			if w > 0.1 and w < 0.45:
				var top: float = 0.45 - (w - 0.1) * 0.7
				var bottom: float = 0.55 - (w - 0.1) * 0.15
				if p.y > top and p.y < bottom and (p.y < bottom - 0.05 or fmod(w * 20.0, 1.0) < 0.6):
					return 2 if p.y < top + 0.05 else 1
			if p.y > 0.72 and p.y < 0.82 and w < 0.03 + (p.y - 0.72) * 0.8:
				return 2
	return 0


static func _ellipse(p: Vector2, c: Vector2, r: Vector2) -> bool:
	return ((p - c) / r).length_squared() <= 1.0


## Distancia de p al segmento a-b.
static func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Pinta las casillas vacías a `dist` px (en cruz) de algo pintado. `dotted`: solo en damero.
static func _ring(img: Image, dist: int, color: Color, dotted: bool) -> void:
	var solid := img.duplicate() as Image
	var px: int = img.get_width()
	for y: int in px:
		for x: int in px:
			if solid.get_pixel(x, y).a > 0.0 or (dotted and (x + y) % 2 == 1):
				continue
			for d: Vector2i in ChunkData.SIDES:
				var q := Vector2i(x, y) + d * dist
				if q.x >= 0 and q.y >= 0 and q.x < px and q.y < px and solid.get_pixelv(q).a > 0.0:
					img.set_pixel(x, y, color)
					break


static func _draw_eye(img: Image, c: Vector2, r: float) -> void:
	var pupil: float = r * 0.5
	for y: int in range(floori(c.y - r - 1), ceili(c.y + r + 1)):
		for x: int in range(floori(c.x - r - 1), ceili(c.x + r + 1)):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= pupil:
				img.set_pixel(x, y, PlaceholderTileset.OUTLINE)
			elif d <= r:
				img.set_pixel(x, y, PlaceholderTileset.WHITE)
			elif d <= r + 1.0:
				img.set_pixel(x, y, PlaceholderTileset.OUTLINE)


static func _draw_mouth(img: Image, fangs: Array, px: int) -> void:
	if fangs.is_empty():
		return
	var y: int = roundi(float(fangs[0][1]) * px)
	var x0: int = roundi((float(fangs[0][0]) - 0.04) * px)
	var x1: int = roundi((float(fangs.back()[0]) + 0.04) * px)
	img.fill_rect(Rect2i(x0, y - 1, x1 - x0, 2), PlaceholderTileset.OUTLINE)
	var h: int = maxi(3, roundi(px * 0.05))
	for f: Array in fangs:
		var fx: int = roundi(float(f[0]) * px)
		for row: int in h:
			var half: int = (h - row) / 2
			img.fill_rect(Rect2i(fx - half, y + 1 + row, half * 2 + 1, 1), PlaceholderTileset.WHITE)
