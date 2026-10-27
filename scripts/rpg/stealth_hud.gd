class_name StealthHud
extends Control
## Iconos del HUD del sigilo (sigilo-y-robo.md, pilar 3: llevar máscara o no y llevar arma o no son
## estados visibles): una máscara verde cuando el camuflaje funciona ("oculto"), roja mientras está
## roto (te han visto) o mientras corres, y una lanza cuando llevas un arma: clara en la mano
## ("armado"), apagada enfundada. Y el permiso del fruto del Bosque en el que estás
## (ajustes-playtest-0.5.md, punto 2): fruto verde (permiso), gris (ya tomado este Momento) o rojo
## (sin permiso: forzado, colado o cerrado). Placeholder dibujado píxel a píxel con PixelIcons hasta
## que pixel-artist haga los definitivos. Solo lee GameState a través de Stealth, AdventureRules y
## FruitRules.

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
const FRUIT: Array[String] = [
	"....oo...",
	"...o+o...",
	"..ooooo..",
	".o#####o.",
	"o###+###o",
	"o#######o",
	".o#####o.",
	"..ooooo..",
]
const COLOR_HIDDEN := Color("63c74d")
const COLOR_EXPOSED := Color("e43b44")
const COLOR_ARMED := Color("c0cbdc")
const COLOR_SHEATHED := Color("5a6988")
const COLOR_FRUIT_GRANTED := Color("63c74d")
const COLOR_FRUIT_USED := Color("8b9bb4")
const COLOR_FRUIT_DENIED := Color("e43b44")
const GAP: float = 2.0

enum Mask { NONE, HIDDEN, EXPOSED }
enum Weapon { NONE, SHEATHED, DRAWN }

var _mask: Mask = Mask.NONE
var _weapon: Weapon = Weapon.NONE
var _fruit: StringName = &""


## Estado del icono de la máscara: oculto (el camuflaje funciona), roto (te han visto, o corres, y
## llevas camuflaje sin el arma en la mano) o ninguno.
static func mask_state() -> Mask:
	if Stealth.is_hidden():
		return Mask.HIDDEN
	if (Stealth.is_exposed() or Stealth.running) and Stealth.gear_camouflage() > 0 and not AdventureRules.is_armed():
		return Mask.EXPOSED
	return Mask.NONE


## Estado del icono del arma: en la mano, enfundada o sin arma.
static func weapon_state() -> Weapon:
	if AdventureRules.is_armed():
		return Weapon.DRAWN
	return Weapon.SHEATHED if AdventureRules.has_weapon() else Weapon.NONE


## Color del icono del fruto para un estado de FruitRules.permission_state (transparente sin estado).
static func fruit_color(state: StringName) -> Color:
	match state:
		FruitRules.GRANTED:
			return COLOR_FRUIT_GRANTED
		FruitRules.USED:
			return COLOR_FRUIT_USED
		FruitRules.FORCED, FruitRules.SNEAKED, FruitRules.CLOSED:
			return COLOR_FRUIT_DENIED
	return Color.TRANSPARENT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var mask: Mask = mask_state()
	var weapon: Weapon = weapon_state()
	var fruit: StringName = FruitRules.current_permission_state()
	if mask != _mask or weapon != _weapon or fruit != _fruit:
		_mask = mask
		_weapon = weapon
		_fruit = fruit
		queue_redraw()


func _draw() -> void:
	var x: float = 0.0
	if _mask != Mask.NONE:
		PixelIcons.draw(self, MASK, Vector2(x, 0), COLOR_HIDDEN if _mask == Mask.HIDDEN else COLOR_EXPOSED)
		x += PixelIcons.size_of(MASK).x + GAP
	if _weapon != Weapon.NONE:
		PixelIcons.draw(self, SPEAR, Vector2(x, 0), COLOR_ARMED if _weapon == Weapon.DRAWN else COLOR_SHEATHED)
		x += PixelIcons.size_of(SPEAR).x + GAP
	if _fruit != &"":
		PixelIcons.draw(self, FRUIT, Vector2(x, 0), fruit_color(_fruit))
