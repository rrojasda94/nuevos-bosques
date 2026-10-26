class_name PixelFont
extends RefCounted
## Fuente de 3×5 píxeles para los rótulos del mapa M (nombres de villas, aldeas y lugares), con
## contorno de 1 px para que se lean sobre cualquier fondo a 320×180. Solo mayúsculas: las
## minúsculas se pasan a mayúsculas y las vocales con tilde, a su vocal (no caben en 5 filas).
## Placeholder hasta que pixel-artist entregue la fuente pixel del juego (assets/fonts/).
## Mismo juego de glifos que tools/world/preview_region.gd.

const GLYPH_W: int = 3
const GLYPH_H: int = 5
## Avance por carácter (glifo + 1 px de separación).
const ADVANCE: int = GLYPH_W + 1
const OUTLINE := Color("181425")

## Filas de arriba abajo, "#" = píxel encendido.
const GLYPHS: Dictionary = {
	"0": "####.##.##.####", "1": ".#.##..#..#.###", "2": "###..#####..###", "3": "###..#.##..####",
	"4": "#.##.####..#..#", "5": "####..###..####", "6": "####..####.####", "7": "###..#.#..#..#.",
	"8": "####.#####.####", "9": "####.####..####", "A": ".#.#.#####.##.#", "B": "##.#.###.#.###.",
	"C": ".###..#..#...##", "D": "##.#.##.##.###.", "E": "####..##.#..###", "F": "####..##.#..#..",
	"G": ".###..#.##.#.##", "H": "#.##.#####.##.#", "I": "###.#..#..#.###", "J": "..#..#..##.#.#.",
	"K": "#.##.###.#.##.#", "L": "#..#..#..#..###", "M": "#.########.##.#", "N": "##.#.##.##.##.#",
	"O": ".#.#.##.##.#.#.", "P": "##.#.###.#..#..", "Q": ".#.#.##.###..##", "R": "##.#.###.#.##.#",
	"S": ".###...#...###.", "T": "###.#..#..#..#.", "U": "#.##.##.##.####", "V": "#.##.##.##.#.#.",
	"W": "#.##.########.#", "X": "#.##.#.#.#.##.#", "Y": "#.##.#.#..#..#.", "Z": "###..#.#.#..###",
	",": "..........#.#..", "-": "......###......", ".": ".............#.", "(": ".#.#..#..#...#.",
	")": ".#...#..#..#.#.", "'": ".#..#..........", "?": "###..#.#.....#.", " ": "...............",
}
const ACCENTS: Dictionary = { "Á": "A", "É": "E", "Í": "I", "Ó": "O", "Ú": "U", "Ü": "U", "Ñ": "N" }


## Ancho en píxeles del texto (sin el contorno).
static func width_of(text: String) -> int:
	return maxi(text.length() * ADVANCE - 1, 0)


## Tamaño del rótulo con su contorno de 1 px a cada lado.
static func box_size(text: String) -> Vector2i:
	return Vector2i(width_of(text) + 2, GLYPH_H + 2)


## Glifo del carácter (en mayúsculas y sin tilde); "?" si no está.
static func glyph(ch: String) -> String:
	var up: String = ch.to_upper()
	return GLYPHS.get(ACCENTS.get(up, up), GLYPHS["?"])


## Dibuja `text` con la esquina superior izquierda del primer glifo en `at` (el contorno queda
## 1 px por fuera).
static func draw(canvas: CanvasItem, text: String, at: Vector2, color: Color) -> void:
	for pass_i: int in 2:
		var x: float = at.x
		for i: int in text.length():
			var g: String = glyph(text[i])
			for row: int in GLYPH_H:
				for col: int in GLYPH_W:
					if g[row * GLYPH_W + col] != "#":
						continue
					var px := Vector2(x + col, at.y + row)
					if pass_i == 0:
						canvas.draw_rect(Rect2(px - Vector2.ONE, Vector2(3, 3)), OUTLINE)
					else:
						canvas.draw_rect(Rect2(px, Vector2.ONE), color)
			x += ADVANCE
