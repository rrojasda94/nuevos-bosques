class_name RiutashDial
extends RefCounted
## Dibujo del reloj del riutash píxel a píxel en una Image (placeholder hasta el arte de
## pixel-artist). Un disco con borde dorado y, dentro, una esfera que gira: la mitad de Gietos
## (cielo azul con el ojo dorado) y la de Riumna (cielo ultramarino oscuro con el ojo plateado
## roto y sus riumini). La línea clara que las separa es el riutash. Una marca fija arriba señala
## "ahora". No gira la imagen: recalcula cada píxel, así que el arte nunca se emborrona.
## Solo colores de la paleta (assets/palettes/palette_nuevos_bosques.gpl).

## Lado de la imagen y centro (en píxeles). Cabe el disco con el mayor crecimiento del pulso.
const SIZE: int = 33
const CENTER: int = 16
## Radio del borde dorado en reposo: disco de 23 px de diámetro con el contorno.
const BASE_RADIUS: int = 10

const OUTLINE := Color("181425")
const RIM := Color("feae34")
const RIM_LIGHT := Color("fee761")
const RIM_SHADE := Color("f77622")
const GIETOS_SKY := Color("0099db")
const RIUMNA_SKY := Color("262b44")
const RIUTASH := Color("ffffff")
const MARK := Color("ffffff")
const FLASH_DIAL := Color("ffffff")
const FLASH_RIM := Color("fee761")

## Ojo de Gietos: orbe dorado con rayos. "o" borde, "#" relleno, "+" brillo, "*" rayo.
const GIETOS_EYE: Array[String] = [
	"...*...",
	"..ooo..",
	".o+##o.",
	"*o###o*",
	".o###o.",
	"..ooo..",
	"...*...",
]
## Ojo de Riumna: orbe plateado, siempre lleno, con el rostro roto ("x" grieta).
const RIUMNA_EYE: Array[String] = [
	".ooo.",
	"o+#xo",
	"o#x#o",
	"ox##o",
	".ooo.",
]
const EYE_COLORS: Dictionary = {
	"o": Color("f77622"), "#": Color("feae34"), "+": Color("fee761"), "*": Color("fee761"),
}
const MOON_COLORS: Dictionary = {
	"o": Color("8b9bb4"), "#": Color("c0cbdc"), "+": Color("ffffff"), "x": Color("5a6988"),
}
## Riumini alrededor de Riumna: [ángulo en la esfera (grados), distancia (fracción del radio
## interior), color]. El ojo de Riumna está en el ángulo 270.
const RIUMINI: Array = [
	[222.0, 0.55, Color("c0cbdc")],
	[238.0, 0.92, Color("ffffff")],
	[300.0, 0.95, Color("2ce8f5")],
	[318.0, 0.55, Color("ffffff")],
	[250.0, 0.25, Color("2ce8f5")],
	[292.0, 0.25, Color("c0cbdc")],
	[335.0, 0.85, Color("c0cbdc")],
	[205.0, 0.85, Color("2ce8f5")],
]
## Marca de "ahora": "o" contorno, "#" relleno. La punta entra un píxel en la esfera.
const MARK_ROWS: Array[String] = [
	"ooooo",
	"o###o",
	".o#o.",
	"..o..",
]
## Ángulos de los ojos en la esfera: Gietos a mitad de su mitad, Riumna a mitad de la suya.
const GIETOS_ANGLE: float = 90.0
const RIUMNA_ANGLE: float = 270.0


## Imagen del reloj con la esfera en `phase` (0–1, ver RiutashClockLogic.phase), el radio crecido
## `grow` píxeles (pulso) y, si `flash`, la esfera encendida (destello del riutash).
static func render(phase: float, grow: int = 0, flash: bool = false) -> Image:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var r: int = BASE_RADIUS + maxi(0, grow)
	var turn: float = fposmod(phase, 1.0) * 360.0
	var seam: float = deg_to_rad(-turn)
	for y: int in SIZE:
		for x: int in SIZE:
			var dx: float = x - CENTER
			var dy: float = y - CENTER
			var d: float = sqrt(dx * dx + dy * dy)
			if d >= r + 1.5:
				continue
			if d >= r + 0.5:
				img.set_pixel(x, y, OUTLINE)
			elif d >= r - 0.5:
				img.set_pixel(x, y, FLASH_RIM if flash else _rim_color(dx, dy, r))
			elif flash:
				img.set_pixel(x, y, FLASH_DIAL)
			elif absf(dx * cos(seam) + dy * sin(seam)) < 0.5:
				img.set_pixel(x, y, RIUTASH)
			else:
				img.set_pixel(x, y, GIETOS_SKY if dial_angle(dx, dy, phase) < 180.0 else RIUMNA_SKY)
	if not flash:
		var inner: float = r - 1.0
		for star: Array in RIUMINI:
			var p: Vector2i = _dial_point(star[0], star[1] * inner, turn)
			_put_inside(img, p.x, p.y, star[2], r)
		_draw_sprite(img, RIUMNA_EYE, MOON_COLORS, _dial_point(RIUMNA_ANGLE, inner * 0.55, turn), r)
		_draw_sprite(img, GIETOS_EYE, EYE_COLORS, _dial_point(GIETOS_ANGLE, inner * 0.55, turn), r)
	_draw_mark(img, r)
	return img


## Ángulo (grados, 0–360) de la esfera que se ve en el píxel (dx, dy) respecto al centro.
## 0–180 es la mitad de Gietos y 180–360 la de Riumna. La marca de "ahora" está en dy < 0, dx = 0.
static func dial_angle(dx: float, dy: float, phase: float) -> float:
	var screen: float = rad_to_deg(atan2(dx, -dy))
	return fposmod(screen + fposmod(phase, 1.0) * 360.0, 360.0)


## Píxel de la imagen justo debajo de la punta de la marca, con el radio `r`.
static func now_pixel(grow: int = 0) -> Vector2i:
	return Vector2i(CENTER, CENTER - (BASE_RADIUS + maxi(0, grow)) + 2)


static func _rim_color(dx: float, dy: float, r: int) -> Color:
	if dx + dy < -r * 0.6:
		return RIM_LIGHT
	if dx + dy > r * 0.6:
		return RIM_SHADE
	return RIM


## Píxel de la imagen para un punto de la esfera en `angle` grados y `dist` píxeles del centro.
static func _dial_point(angle: float, dist: float, turn: float) -> Vector2i:
	var screen: float = deg_to_rad(angle - turn)
	return Vector2i(CENTER + roundi(dist * sin(screen)), CENTER - roundi(dist * cos(screen)))


static func _put_inside(img: Image, x: int, y: int, color: Color, r: int) -> void:
	var dx: float = x - CENTER
	var dy: float = y - CENTER
	if dx * dx + dy * dy < (r - 0.5) * (r - 0.5):
		img.set_pixel(x, y, color)


static func _draw_sprite(img: Image, rows: Array[String], colors: Dictionary, center: Vector2i, r: int) -> void:
	var half: int = rows.size() / 2
	for j: int in rows.size():
		for i: int in rows[j].length():
			var c: String = rows[j][i]
			if colors.has(c):
				_put_inside(img, center.x - half + i, center.y - half + j, colors[c], r)


static func _draw_mark(img: Image, r: int) -> void:
	var top: int = CENTER - r - 2
	var left: int = CENTER - MARK_ROWS[0].length() / 2
	for j: int in MARK_ROWS.size():
		for i: int in MARK_ROWS[j].length():
			var c: String = MARK_ROWS[j][i]
			var y: int = top + j
			if y < 0 or c == ".":
				continue
			img.set_pixel(left + i, y, OUTLINE if c == "o" else MARK)
