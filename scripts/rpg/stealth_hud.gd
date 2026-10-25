class_name StealthHud
extends Control
## Iconos del HUD del sigilo (sigilo-y-robo.md, pilar 3: llevar máscara o no y llevar arma o no son
## estados visibles): una máscara verde cuando el camuflaje funciona ("oculto"), roja mientras está
## roto (te han visto) y una lanza cuando llevas un arma en la mano ("armado"). Placeholder dibujado
## píxel a píxel con PixelIcons hasta que pixel-artist haga los definitivos. Solo lee GameState a
## través de Stealth y AdventureRules.

const MASK: Array[String] = [
	".ooooooo.",
	"o#######o",
	"o#oo#oo#o",
	"o#oo#oo#o",
	"o###+###o",
	".o#####o.",
	"..o###o..",
	"...ooo...",
]
const SPEAR: Array[String] = [
	"......ooo",
	".....o++o",
	"....o##o.",
	"...o##o..",
	"..o#oo...",
	".o#o.....",
	"o#o......",
	"oo.......",
]
const COLOR_HIDDEN := Color("63c74d")
const COLOR_EXPOSED := Color("e43b44")
const COLOR_ARMED := Color("c0cbdc")
const GAP: float = 2.0

enum Mask { NONE, HIDDEN, EXPOSED }

var _mask: Mask = Mask.NONE
var _armed: bool = false


## Estado del icono de la máscara: oculto (el camuflaje funciona), roto (te han visto y llevas
## camuflaje sin arma) o ninguno.
static func mask_state() -> Mask:
	if Stealth.is_hidden():
		return Mask.HIDDEN
	if Stealth.is_exposed() and Stealth.gear_camouflage() > 0 and not AdventureRules.is_armed():
		return Mask.EXPOSED
	return Mask.NONE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var mask: Mask = mask_state()
	var armed: bool = AdventureRules.is_armed()
	if mask != _mask or armed != _armed:
		_mask = mask
		_armed = armed
		queue_redraw()


func _draw() -> void:
	var x: float = 0.0
	if _mask != Mask.NONE:
		PixelIcons.draw(self, MASK, Vector2(x, 0), COLOR_HIDDEN if _mask == Mask.HIDDEN else COLOR_EXPOSED)
		x += PixelIcons.size_of(MASK).x + GAP
	if _armed:
		PixelIcons.draw(self, SPEAR, Vector2(x, 0), COLOR_ARMED)
