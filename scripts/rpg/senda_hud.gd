class_name SendaHud
extends Control
## Iconos de la Senda y del bando (moralidad-y-progresion.md: "un icono de Senda con tres estados";
## dos-caminos.md: el bando "con un icono junto al de la Senda"). Sin número ni barra:
## - Senda violenta: fauces rojas; neutral: círculo a medias, gris; respetuosa: hoja verde.
## - Bando fiel: árbol; en duda: interrogación amarilla; garelino: estrella azul (Estrella Azul).
## - Con puntos de stat o de skill sin gastar, un "+" amarillo detrás (se reparten en la pantalla I).
## Se usa en el HUD de la exploración y en la pantalla I. Placeholder dibujado píxel a píxel con
## PixelIcons hasta que pixel-artist haga los definitivos. Solo lee GameState a través de Senda.

const FANGS: Array[String] = [
	"ooooooooo",
	"o###+###o",
	"o##o.o##o",
	".o#o.o#o.",
	".o#o.o#o.",
	"..o...o..",
]
const HALF: Array[String] = [
	"..ooooo..",
	".o##+..o.",
	"o###....o",
	"o###....o",
	"o###....o",
	".o##...o.",
	"..ooooo..",
]
const LEAF: Array[String] = [
	"......oo.",
	"....oo#+o",
	"...o###+o",
	"..o###+#o",
	".o##+##o.",
	".o#+##o..",
	"o+ooo....",
	"o........",
]
const TREE: Array[String] = [
	"...ooo...",
	"..o###o..",
	".o##+##o.",
	"o###+###o",
	".oo###oo.",
	"...o#o...",
	"...o#o...",
	"..ooooo..",
]
const DOUBT: Array[String] = [
	"..oooo..",
	".o####o.",
	".o#oo#o.",
	"..o.o#o.",
	"...o#o..",
	"...ooo..",
	"...o#o..",
	"...ooo..",
]
const STAR: Array[String] = [
	"....o....",
	"...o#o...",
	"oooo#oooo",
	"o###+###o",
	".o#####o.",
	"..o###o..",
	".o##o##o.",
	".oo...oo.",
]
const PLUS: Array[String] = [
	".ooo.",
	"oo#oo",
	"o###o",
	"oo#oo",
	".ooo.",
]
const SENDA_ICONS: Array = [FANGS, HALF, LEAF]
const SENDA_COLORS: Array[Color] = [Color("e43b44"), Color("8b9bb4"), Color("63c74d")]
const BANDO_ICONS: Dictionary = { &"fiel": TREE, &"en_duda": DOUBT, &"garelino": STAR }
const BANDO_COLORS: Dictionary = { &"fiel": Color("3e8948"), &"en_duda": Color("fee761"), &"garelino": Color("0099db") }
const COLOR_POINTS := Color("fee761")
const COLOR_BACKING := Color("8b9bb4")
const GAP: float = 2.0

## Dibujar el "+" de los puntos sin gastar (en la pantalla I no hace falta).
@export var show_points: bool = true
## Fondo claro detrás de cada icono (sobre los paneles oscuros, donde el contorno no se ve).
@export var backing: bool = false

var _senda: int = -1
var _bando: StringName = &""
var _points: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sigue al día aunque el juego esté en pausa (menú del borde, combate, pantalla I).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_process(0.0)


## Hay puntos de stat o de skill por gastar.
static func has_points() -> bool:
	return GameState.stat_points > 0 or GameState.skill_points > 0


func _process(_delta: float) -> void:
	var senda: int = Senda.icon()
	var points: bool = show_points and has_points()
	if senda != _senda or GameState.bando != _bando or points != _points:
		_senda = senda
		_bando = GameState.bando
		_points = points
		queue_redraw()


func _draw() -> void:
	var x: float = 0.0
	var senda_icon: Array[String] = []
	senda_icon.assign(SENDA_ICONS[_senda])
	_back(senda_icon, x)
	PixelIcons.draw(self, senda_icon, Vector2(x, 0), SENDA_COLORS[_senda])
	x += PixelIcons.size_of(senda_icon).x + GAP
	var bando_icon: Array[String] = []
	bando_icon.assign(BANDO_ICONS.get(_bando, TREE))
	_back(bando_icon, x)
	PixelIcons.draw(self, bando_icon, Vector2(x, 0), BANDO_COLORS.get(_bando, BANDO_COLORS[&"fiel"]))
	x += PixelIcons.size_of(bando_icon).x + GAP
	if _points:
		PixelIcons.draw(self, PLUS, Vector2(x, 1), COLOR_POINTS)


func _back(icon: Array[String], x: float) -> void:
	if backing:
		draw_rect(Rect2(Vector2(x - 1, -1), Vector2(PixelIcons.size_of(icon)) + Vector2(2, 2)), COLOR_BACKING)
