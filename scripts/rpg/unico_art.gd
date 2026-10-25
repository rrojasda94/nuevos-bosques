class_name UnicoArt
extends RefCounted
## Arte de los monstruos. Botarramas y Ofomni usan los PNG de pixel-artist recoloreados con su
## Bosque (sprite_sheet, battle_texture); si falta el PNG, y para el resto de tipos, queda el
## placeholder (ADR 0009, v1.1): dibujados por código con la combinación de
## colores de su Bosque (hojas y tronco) y un aura. Los guardianes de borde son siempre Botarramas
## (monstruos.md: ave sin plumas que renquea) y el Ofomni de la misión es el ojo con tentáculos
## (EYES). El resto de siluetas quedan para monstruos futuros.
## Lo sustituirá el arte de pixel-artist; los nombres reales son de narrative-writer.

enum Kind { QUADRUPED, SERPENT, HORNED, EYES, BIRD, BOTARRAMAS, REPAREP }
## Reparep (cangrejo fantasmal): opacidad del cuerpo y cuánto se aclara su color claro hacia el
## blanco. Placeholder procedural hasta el arte de pixel-artist (ver docs/art/specs).
const GHOST_ALPHA: float = 0.78
const GHOST_PALE: float = 0.45
## Tamaño de cada cangrejo en el icono de grupo del mundo (group_texture).
const GROUP_CRAB_PX: int = 15
const AURA := Color("fee761")

## Arte de pixel-artist (docs/art/specs/primera-pasada.md): hoja de 2 fotogramas en horizontal por
## tipo. Si falta el PNG se usa el placeholder procedural de texture().
const SPRITES: Dictionary = {
	Kind.BOTARRAMAS: "res://assets/sprites/sprite_botarramas_walk.png",
	Kind.EYES: "res://assets/sprites/sprite_ofomni_idle.png",
}
const SPRITE_FRAMES: int = 2
## Colores clave de los PNG de monstruos: se sustituyen por la hoja clara, la hoja oscura y el
## tronco del Bosque (PlaceholderTileset.LEAVES / TRUNKS). Iguales que en tools/art/make_sprites.py.
const KEY_LIGHT := Color("c0cbdc")
const KEY_DARK := Color("8b9bb4")
const KEY_TRUNK := Color("5a6988")

## Ojos por tipo: [u, v, radio], en fracciones del tamaño.
const EYES: Array = [
	[[0.15, 0.42, 0.035], [0.25, 0.42, 0.035]],
	[[0.44, 0.23, 0.035], [0.56, 0.23, 0.035]],
	[[0.45, 0.22, 0.035], [0.55, 0.22, 0.035]],
	[[0.38, 0.38, 0.06], [0.6, 0.36, 0.075], [0.48, 0.53, 0.05], [0.67, 0.53, 0.04], [0.31, 0.55, 0.04], [0.5, 0.24, 0.04]],
	[[0.46, 0.28, 0.03], [0.54, 0.28, 0.03]],
	[[0.3, 0.19, 0.035]],
	[[0.4, 0.24, 0.05], [0.6, 0.24, 0.05]],
]
## Colmillos por tipo: [u, v] (punta hacia abajo). La boca es una línea que los une.
const FANGS: Array = [
	[[0.15, 0.52], [0.23, 0.52]],
	[[0.46, 0.3], [0.54, 0.3]],
	[[0.46, 0.29], [0.54, 0.29]],
	[[0.41, 0.67], [0.5, 0.68], [0.59, 0.67]],
	[],
	[],
	[],
]


## Silueta de cada monstruo del mundo por su id de datos: Botarramas, Ofomni (los dos, el ojo con
## tentáculos) y Aledra (la serpiente). Otro id, el placeholder de cuadrúpedo.
static func kind_for(monster_id: StringName) -> Kind:
	match monster_id:
		&"botarramas":
			return Kind.BOTARRAMAS
		&"ofomni", &"ofomni_descarriado":
			return Kind.EYES
		&"aledra":
			return Kind.SERPENT
		&"reparep":
			return Kind.REPAREP
	return Kind.QUADRUPED


static func has_sprite(kind: Kind) -> bool:
	return SPRITES.has(kind) and ResourceLoader.exists(SPRITES[kind])


## Fotogramas de la hoja del mundo: SPRITE_FRAMES con PNG, 1 con el placeholder.
static func frames_for(kind: Kind) -> int:
	return SPRITE_FRAMES if has_sprite(kind) else 1


## Hoja del PNG recoloreada con el Bosque de `style`, o null si no hay PNG.
static func sprite_sheet(kind: Kind, style: Dictionary) -> Texture2D:
	if not has_sprite(kind):
		return null
	var img: Image = (load(SPRITES[kind]) as Texture2D).get_image()
	return ImageTexture.create_from_image(recolor(img, style))


## Monstruo para el combate en un cuadro de `px` x `px`: el primer fotograma del PNG ampliado a
## escala entera y apoyado abajo en el centro; sin PNG, el placeholder procedural.
static func battle_texture(kind: Kind, style: Dictionary, px: int) -> Texture2D:
	if not has_sprite(kind):
		return texture(kind, style, px)
	var img: Image = recolor((load(SPRITES[kind]) as Texture2D).get_image(), style)
	var w: int = img.get_width() / SPRITE_FRAMES
	var h: int = img.get_height()
	var frame: Image = img.get_region(Rect2i(0, 0, w, h))
	var scale: int = maxi(1, mini(px / w, px / h))
	frame.resize(w * scale, h * scale, Image.INTERPOLATE_NEAREST)
	var out := Image.create(px, px, false, Image.FORMAT_RGBA8)
	out.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i((px - frame.get_width()) / 2, px - frame.get_height()))
	return ImageTexture.create_from_image(out)


## Colores clave -> colores del Bosque de `style` (claves en RGBA32).
static func recolor_map(style: Dictionary) -> Dictionary:
	var leaf: Array = PlaceholderTileset.LEAVES[int(style.get("leaf", 0))]
	return {
		KEY_LIGHT.to_rgba32(): leaf[1],
		KEY_DARK.to_rgba32(): leaf[0],
		KEY_TRUNK.to_rgba32(): PlaceholderTileset.TRUNKS[int(style.get("trunk", 0))],
	}


## Copia de `img` con los colores clave cambiados por los del Bosque; el resto (contorno, ojos)
## se queda igual.
static func recolor(img: Image, style: Dictionary) -> Image:
	var out := img.duplicate() as Image
	if out.is_compressed():
		out.decompress()
	out.convert(Image.FORMAT_RGBA8)
	var mapping: Dictionary = recolor_map(style)
	for y: int in out.get_height():
		for x: int in out.get_width():
			var c: Color = out.get_pixel(x, y)
			if c.a > 0.0 and mapping.has(c.to_rgba32()):
				out.set_pixel(x, y, mapping[c.to_rgba32()])
	return out


## Copia de `tex` (hoja del mundo o placeholder) con un aura de Luz punteada a 1 px del contorno: la
## marca de los Ofomni que sirven a su Bosque, frente al descarriado, que no la lleva. Provisional
## hasta que pixel-artist dé su sprite.
static func with_aura(tex: Texture2D) -> Texture2D:
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	_ring(img, 1, AURA, true)
	return ImageTexture.create_from_image(img)


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
	if kind == Kind.REPAREP:
		_ghost(img, leaf[1])
	return ImageTexture.create_from_image(img)


## Icono de un grupo de `count` reparep para el mundo (un solo monstruo que se ve como varios
## cangrejos juntos: el número se cuenta a la vista), en un cuadro de `px` x `px`.
static func group_texture(style: Dictionary, count: int, px: int) -> Texture2D:
	var crab: Image = texture(Kind.REPAREP, style, GROUP_CRAB_PX).get_image()
	var out := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c: int = GROUP_CRAB_PX
	var spots: Array[Vector2i] = [Vector2i(0, px - c), Vector2i(px - c, px - c), Vector2i((px - c) / 2, px - c - c / 2 - 2), Vector2i((px - c) / 2, 0)]
	if count <= 1:
		spots = [Vector2i((px - c) / 2, px - c)]
	for i: int in clampi(count, 1, spots.size()):
		out.blend_rect(crab, Rect2i(Vector2i.ZERO, crab.get_size()), spots[i])
	return ImageTexture.create_from_image(out)


## Cangrejo fantasmal: el cuerpo se vuelve semitransparente y su color claro, pálido.
static func _ghost(img: Image, light: Color) -> void:
	var pale: Color = light.lerp(PlaceholderTileset.WHITE, GHOST_PALE)
	for y: int in img.get_height():
		for x: int in img.get_width():
			var p: Color = img.get_pixel(x, y)
			if p.a <= 0.0 or p == AURA or p == PlaceholderTileset.WHITE or p == PlaceholderTileset.OUTLINE:
				continue
			if p == light:
				p = pale
			p.a = GHOST_ALPHA
			img.set_pixel(x, y, p)


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
		Kind.BOTARRAMAS:
			# Pico, patas (la derecha doblada: renquea) y muñón de cola en color tronco.
			if _seg(p, Vector2(0.24, 0.21), Vector2(0.08, 0.26)) < 0.03 					or _seg(p, Vector2(0.44, 0.7), Vector2(0.44, 0.92)) < 0.025 					or _seg(p, Vector2(0.38, 0.92), Vector2(0.5, 0.92)) < 0.02 					or _seg(p, Vector2(0.6, 0.7), Vector2(0.7, 0.8)) < 0.025 					or _seg(p, Vector2(0.7, 0.8), Vector2(0.64, 0.87)) < 0.025 					or _seg(p, Vector2(0.72, 0.5), Vector2(0.84, 0.4)) < 0.03:
				return 3
			# Cabeza y cuello pelados, en el color claro del Bosque.
			if _ellipse(p, Vector2(0.31, 0.2), Vector2(0.09, 0.08)) or _seg(p, Vector2(0.38, 0.48), Vector2(0.31, 0.25)) < 0.045:
				return 2
			# Muñón de ala, oscuro.
			if _ellipse(p, Vector2(0.56, 0.5), Vector2(0.11, 0.06)):
				return 1
			# Cuerpo desplumado: piel clara con granos oscuros.
			if _ellipse(p, Vector2(0.52, 0.56), Vector2(0.22, 0.16)):
				return 1 if fmod(p.x * 17.0, 1.0) < 0.25 and fmod(p.y * 17.0, 1.0) < 0.25 else 2
		Kind.REPAREP:
			# Pinzas y caparazón de cangrejo; patas y tallos de los ojos en color tronco.
			for side: float in [-1.0, 1.0]:
				if _ellipse(p, Vector2(0.5 + side * 0.36, 0.3), Vector2(0.1, 0.08)):
					return 2 if p.y < 0.28 else 1
				if _seg(p, Vector2(0.5 + side * 0.22, 0.52), Vector2(0.5 + side * 0.34, 0.36)) < 0.035:
					return 3
				for k: int in 3:
					var y0: float = 0.6 + k * 0.06
					if _seg(p, Vector2(0.5 + side * 0.24, y0), Vector2(0.5 + side * (0.38 + k * 0.03), y0 + 0.2)) < 0.025:
						return 3
				if _seg(p, Vector2(0.5 + side * 0.1, 0.45), Vector2(0.5 + side * 0.1, 0.28)) < 0.02:
					return 3
			if _ellipse(p, Vector2(0.5, 0.58), Vector2(0.27, 0.16)):
				return 2 if p.y < 0.53 else 1
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
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y: int in h:
		for x: int in w:
			if solid.get_pixel(x, y).a > 0.0 or (dotted and (x + y) % 2 == 1):
				continue
			for d: Vector2i in ChunkData.SIDES:
				var q := Vector2i(x, y) + d * dist
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and solid.get_pixelv(q).a > 0.0:
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
