class_name PixelIcons
extends RefCounted
## Iconos placeholder de la UI dibujados píxel a píxel (flecha de la brújula y marcas del mapa)
## hasta que pixel-artist entregue los definitivos. Cada icono es una lista de filas: "." vacío,
## "o" contorno, "#" relleno y "+" brillo. Solo dibuja sobre el CanvasItem que recibe.

const OUTLINE := Color("181425")

## Flecha hacia el este (índice 0) y hacia el sureste (índice 1); el resto sale de girarlas.
const ARROW_EAST: Array[String] = [
	"....o....",
	"....oo...",
	"oooo#+o..",
	"o######o.",
	"o#######o",
	"o######o.",
	"oooo##o..",
	"....oo...",
	"....o....",
]
const ARROW_SOUTHEAST: Array[String] = [
	"ooo......",
	"o+#o.....",
	"o##+o.oo.",
	".o###o#o.",
	"..o####o.",
	"...o###o.",
	".oo####o.",
	".o#####o.",
	".oooooooo",
]
## "Aquí": un punto con anillo.
const HERE: Array[String] = [
	".........",
	"...ooo...",
	"..o###o..",
	".o##+##o.",
	".o#+#+#o.",
	".o##+##o.",
	"..o###o..",
	"...ooo...",
	".........",
]
const HOUSE: Array[String] = [
	"...o...",
	"..o#o..",
	".o###o.",
	"o#####o",
	".o#+#o.",
	".o#+#o.",
	".ooooo.",
]
const REFUGE: Array[String] = [
	".ooo.",
	"o###o",
	"o#o#o",
	"ooooo",
]
const PLAYER: Array[String] = [
	".ooo.",
	"o###o",
	"o#+#o",
	"o###o",
	".ooo.",
]
## Botarramas visto: cabecita de ave con pico.
const MONSTER: Array[String] = [
	".oo..",
	"o#+o.",
	"o##oo",
	".o##o",
	"..oo.",
]
const OBJECTIVE: Array[String] = [
	"oo.oo",
	"o#o#o",
	".o#o.",
	"o#o#o",
	"oo.oo",
]


## Patrón de la flecha de la brújula para un índice de ChunkGenerator.direction_index (0 = este,
## sentido horario) o MapLogic.HERE.
static func arrow(index: int) -> Array[String]:
	if index < 0:
		return HERE
	var base: Array[String] = ARROW_EAST if index % 2 == 0 else ARROW_SOUTHEAST
	return rotate_cw(base, index / 2)


## Gira un patrón cuadrado `turns` cuartos de vuelta en sentido horario (y crece hacia abajo).
static func rotate_cw(pattern: Array[String], turns: int) -> Array[String]:
	var out: Array[String] = pattern.duplicate()
	for t: int in posmod(turns, 4):
		var n: int = out.size()
		var rotated: Array[String] = []
		for y: int in n:
			var row: String = ""
			for x: int in n:
				row += out[n - 1 - x][y]
			rotated.append(row)
		out = rotated
	return out


## Tamaño en píxeles de un patrón.
static func size_of(pattern: Array[String]) -> Vector2i:
	return Vector2i(pattern[0].length() if not pattern.is_empty() else 0, pattern.size())


## Dibuja `pattern` en `canvas` con su esquina superior izquierda en `origin`.
static func draw(canvas: CanvasItem, pattern: Array[String], origin: Vector2, fill: Color, shine: Color = Color.WHITE) -> void:
	for y: int in pattern.size():
		var row: String = pattern[y]
		for x: int in row.length():
			var color: Color
			match row[x]:
				"o":
					color = OUTLINE
				"#":
					color = fill
				"+":
					color = shine
				_:
					continue
			canvas.draw_rect(Rect2(origin + Vector2(x, y), Vector2.ONE), color)


## Dibuja `pattern` centrado en `center`.
static func draw_centered(canvas: CanvasItem, pattern: Array[String], center: Vector2, fill: Color, shine: Color = Color.WHITE) -> void:
	var size: Vector2i = size_of(pattern)
	draw(canvas, pattern, (center - Vector2(size) / 2.0).floor(), fill, shine)
