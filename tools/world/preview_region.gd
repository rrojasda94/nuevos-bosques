extends SceneTree
## Vista previa de la autoría de una región (ADR 0014 §4, "Herramienta"). La lanza
## tools/world/preview_region.sh [region_id] [seed].
## 1. Valida con RegionAuthoring e imprime los errores.
## 2. Escribe build/preview_<region>_<seed>.png a 1 px = 1 tile: altura (verdes; las cumbres,
##    claras; las celdas sin pintar, a cuadros = decide el generador), agua, caminos, Bosques
##    clave (velo de su color), rejilla de chunks con sus coordenadas, lugares con su nombre y
##    los errores en rojo. La leyenda sale por consola.
## La seed aún no cambia la imagen: la pasada de región (RegionPlan) llega en M5 y se enchufa en
## _plan(). Mientras, se dibuja solo lo pintado.
## Sale con 1 si hay errores de autoría (la imagen se escribe igual) y con 2 si no puede escribirla.

const OUT_DIR: String = "res://build/"
# ponytail: mover a WorldCoords (M4)
const CHUNK_TILES: int = 80
const TEXT_SCALE: int = 2

const HEIGHT_COLORS: Array[Color] = [
	Color("#5b6b4e"),  # sin pintar (cuadros con UNPAINTED_ALT)
	Color("#3f7a35"), Color("#5f8f3c"), Color("#86994a"), Color("#a59a68"),
	Color("#ecebf2"),  # cumbre
]
const UNPAINTED_ALT: Color = Color("#4d5c42")
const GRID_COLOR: Color = Color(0, 0, 0, 0.45)
const ERROR_COLOR: Color = Color("#ff2020")
const TEXT_COLOR: Color = Color("#ffffff")
const SHADOW_COLOR: Color = Color("#000000")
const PLACE_COLORS: Dictionary = {
	"villa_natal": Color("#ffd23c"), "villa": Color("#ffffff"), "hito": Color("#ff8a3c"),
	"tarca": Color("#c070ff"), "bosque": Color("#60ff70"), "lugar": Color("#50e0ff"),
}
const PLACE_NAMES: Dictionary = {
	"villa_natal": "villa natal", "villa": "villa", "hito": "hito",
	"tarca": "tarca", "bosque": "Nujio de Bosque clave", "lugar": "lugar",
}

## Fuente de 3×5 (mayúsculas sin tildes, cifras y algo de puntuación). Filas de arriba abajo.
const FONT: Dictionary = {
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
	")": ".#...#..#..#.#.", "_": "............###", "?": "###..#.#.....#.", " ": "...............",
}
const ACCENTS: Dictionary = { "Á": "A", "É": "E", "Í": "I", "Ó": "O", "Ú": "U", "Ü": "U", "Ñ": "N" }


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var region_id: StringName = StringName(args[0]) if args.size() > 0 else &"valle_del_sara"
	var seed_value: int = args[1].to_int() if args.size() > 1 else 42
	var authoring := RegionAuthoring.load_region(region_id)
	var plan: Object = _plan(seed_value, region_id, authoring)
	print("Región %s, seed %d: %d×%d px de autoría = %d×%d chunks." % [region_id, seed_value,
			authoring.size_px.x, authoring.size_px.y, authoring.size_chunks().x, authoring.size_chunks().y])
	if plan == null:
		print("(La seed aún no cambia nada: la generación de la región llega con RegionPlan, M5. Se dibuja la autoría.)")
	if authoring.size_px == Vector2i.ZERO:
		for e: String in authoring.errors:
			printerr("ERROR: " + e)
		quit(2)
		return
	var img: Image = render(authoring)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# Que el editor no importe las vistas previas.
	if not FileAccess.file_exists(OUT_DIR + ".gdignore"):
		FileAccess.open(OUT_DIR + ".gdignore", FileAccess.WRITE).close()
	var out_path: String = OUT_DIR + "preview_%s_%d.png" % [region_id, seed_value]
	var err: int = img.save_png(ProjectSettings.globalize_path(out_path))
	if err != OK:
		printerr("No se pudo escribir %s (%d)" % [out_path, err])
		quit(2)
		return
	_print_legend(authoring)
	print("Vista previa: %s" % ProjectSettings.globalize_path(out_path))
	if authoring.is_valid():
		print("Autoría válida.")
		quit(0)
		return
	printerr("%d errores de autoría (marcados en rojo en la vista previa):" % authoring.errors.size())
	for e: String in authoring.errors:
		printerr("  - " + e)
	quit(1)


## M5 enchufa aquí la pasada de región: devolver RegionPlan.build(seed_value, region, authoring) y
## dibujarlo en render() en vez de (o sobre) la autoría. Hasta entonces, null.
func _plan(_seed_value: int, _region_id: StringName, _authoring: RegionAuthoring) -> Object:
	return null


static func render(a: RegionAuthoring) -> Image:
	var t: int = RegionAuthoring.MACRO_TILES
	var img := Image.create_empty(a.size_px.x * t, a.size_px.y * t, false, Image.FORMAT_RGBA8)
	var palette: Dictionary = RegionAuthoring.load_palette()
	var water_keys: Array[String] = RegionAuthoring.layer_keys("water")
	var road_keys: Array[String] = RegionAuthoring.layer_keys("roads")
	var bosques: Array[Dictionary] = a.bosque_places()
	for y: int in a.size_px.y:
		for x: int in a.size_px.x:
			var cell := Vector2i(x, y)
			var h: int = a.height_at(cell)
			var color: Color = HEIGHT_COLORS[h]
			if h == RegionAuthoring.Height.NONE and (x + y) % 2 == 1:
				color = UNPAINTED_ALT
			var b: int = a.bosque_at(cell)
			if b >= 0:
				color = color.lerp(bosques[b].color, 0.45)
			var w: int = a.water_at(cell)
			if w != RegionAuthoring.Water.NONE:
				color = RegionAuthoring.palette_color(palette, "water", water_keys[w])
			var r: int = a.road_at(cell)
			if r != RegionAuthoring.Road.NONE:
				color = RegionAuthoring.palette_color(palette, "roads", road_keys[r])
			img.fill_rect(Rect2i(cell * t, Vector2i(t, t)), color)
			# Relieve: borde oscuro al sur de un escalón (la cara del risco mira al sur).
			var south: int = a.height_at(cell + Vector2i.DOWN)
			if w == RegionAuthoring.Water.NONE and r == RegionAuthoring.Road.NONE and a.in_map(cell + Vector2i.DOWN) \
					and _rank(h) > _rank(south) and south != RegionAuthoring.Height.NONE:
				img.fill_rect(Rect2i(cell * t + Vector2i(0, t - 1), Vector2i(t, 1)), color.darkened(0.45))
	_draw_grid(img, a)
	for p: Dictionary in a.places:
		if a.in_map(p.cell):
			_draw_place(img, p)
	for c: Vector2i in a.error_cells:
		_outline(img, Rect2i(c * t - Vector2i(4, 4), Vector2i(t + 8, t + 8)), ERROR_COLOR)
		_outline(img, Rect2i(c * t - Vector2i(5, 5), Vector2i(t + 10, t + 10)), ERROR_COLOR)
	return img


## Orden de altura para la sombra (cumbre por encima del nivel 3).
static func _rank(h: int) -> int:
	return h


static func _draw_grid(img: Image, a: RegionAuthoring) -> void:
	var size := img.get_size()
	for x: int in range(0, size.x, CHUNK_TILES):
		for y: int in size.y:
			_blend(img, Vector2i(x, y), GRID_COLOR)
	for y: int in range(0, size.y, CHUNK_TILES):
		for x: int in size.x:
			_blend(img, Vector2i(x, y), GRID_COLOR)
	var chunks: Vector2i = a.size_chunks()
	for cy: int in chunks.y:
		for cx: int in chunks.x:
			_text(img, "%d,%d" % [cx, cy], Vector2i(cx, cy) * CHUNK_TILES + Vector2i(3, 3), TEXT_COLOR)


static func _draw_place(img: Image, p: Dictionary) -> void:
	var t: int = RegionAuthoring.MACRO_TILES
	var center: Vector2i = (p.cell as Vector2i) * t + Vector2i(t / 2, t / 2)
	var color: Color = PLACE_COLORS.get(p.type, Color.WHITE)
	var half: int = 5 if p.type == "villa_natal" else 4
	img.fill_rect(Rect2i(center - Vector2i(half + 1, half + 1), Vector2i(half * 2 + 3, half * 2 + 3)), SHADOW_COLOR)
	img.fill_rect(Rect2i(center - Vector2i(half, half), Vector2i(half * 2 + 1, half * 2 + 1)), color)
	if p.type == "bosque":
		img.fill_rect(Rect2i(center - Vector2i(2, 2), Vector2i(5, 5)), p.color)
	var label: String = String(p.name) if String(p.name) != "" else String(p.id)
	var width: int = _text_width(label)
	_text(img, label, center + Vector2i(-width / 2, half + 4), color)


static func _text_width(text: String) -> int:
	return text.length() * 4 * TEXT_SCALE - TEXT_SCALE


## Texto en la fuente de 3×5, con sombra de 1 px de grosor alrededor para que se lea sobre todo.
static func _text(img: Image, text: String, at: Vector2i, color: Color) -> void:
	var s: int = TEXT_SCALE
	var upper: String = text.to_upper()
	for pass_i: int in 2:
		var x: int = at.x
		for i: int in upper.length():
			var ch: String = ACCENTS.get(upper[i], upper[i])
			var glyph: String = FONT.get(ch, FONT["?"])
			for row: int in 5:
				for col: int in 3:
					if row * 3 + col >= glyph.length() or glyph[row * 3 + col] != "#":
						continue
					var px := Vector2i(x + col * s, at.y + row * s)
					if pass_i == 0:
						_fill_clipped(img, Rect2i(px - Vector2i(1, 1), Vector2i(s + 2, s + 2)), SHADOW_COLOR)
					else:
						_fill_clipped(img, Rect2i(px, Vector2i(s, s)), color)
			x += 4 * s


static func _fill_clipped(img: Image, rect: Rect2i, color: Color) -> void:
	var r: Rect2i = rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.has_area():
		img.fill_rect(r, color)


static func _outline(img: Image, rect: Rect2i, color: Color) -> void:
	_fill_clipped(img, Rect2i(rect.position, Vector2i(rect.size.x, 1)), color)
	_fill_clipped(img, Rect2i(rect.position + Vector2i(0, rect.size.y - 1), Vector2i(rect.size.x, 1)), color)
	_fill_clipped(img, Rect2i(rect.position, Vector2i(1, rect.size.y)), color)
	_fill_clipped(img, Rect2i(rect.position + Vector2i(rect.size.x - 1, 0), Vector2i(1, rect.size.y)), color)


static func _blend(img: Image, p: Vector2i, color: Color) -> void:
	img.set_pixelv(p, img.get_pixelv(p).blend(color))


static func _print_legend(a: RegionAuthoring) -> void:
	print("Leyenda: verdes = niveles 0-3 (más claro = más alto), blanco = cumbre, cuadros = sin pintar (decide el generador),")
	print("  azules = agua, marrón = caminos y puentes, velo de color = Bosque clave, rojo = error.")
	print("Lugares (%d):" % a.places.size())
	for p: Dictionary in a.places:
		var c: Vector2i = RegionAuthoring.chunk_of(p.cell)
		print("  [%s] %s (%s) en px (%d, %d), chunk (%d, %d)" % [PLACE_NAMES.get(p.type, p.type), p.name, p.id,
				p.cell.x, p.cell.y, c.x, c.y])
