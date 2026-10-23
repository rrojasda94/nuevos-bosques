extends CanvasLayer
## Pantalla de combate (ADR 0009): dibuja un BattleLogic y le pasa las acciones del menú.
## Arriba el Único (silueta del árbol de su Bosque, en grande, con ojos y aura), abajo el Adoc.
## No aplica nada a GameState: al terminar emite `finished` y Crossing aplica el resultado.

signal finished(logic: BattleLogic)

## Textos de placeholder; los revisa narrative-writer.
const TEXT_START: String = "¡El %s te cierra el paso!"
const TEXT_ATTACK: String = "Atacas: %d de daño."
const TEXT_DEFEND: String = "Te pones en guardia."
const TEXT_OFFER_LUZ: String = "Ofreces Luz: %d de daño."
const TEXT_FLEE_FAIL: String = "No logras huir."
const TEXT_FLEE_OK: String = "Huyes a tu lado del Bosque."
const TEXT_UNICO_ATTACK: String = "El Único te golpea: %d de daño."
const TEXT_VICTORY: String = "El Único vuelve a la Luz del Bosque. (+%d Luz)"
const TEXT_DEFEAT: String = "Caes. Despertarás junto al Nujio de tu Bosque."
const TEXT_CONTINUE: String = "  [Aceptar]"
const OPTIONS: Array[String] = ["Atacar", "Defender", "Ofrecer Luz", "Huir"]
## Tamaño del Único en casillas de 16 px.
const UNICO_TILES: int = 6
const BAR_WIDTH: float = 100.0
## Posición de los ojos (u, v) por silueta (orden de PlaceholderTileset.Shape).
const EYES_V: Array[float] = [0.40, 0.50, 0.28, 0.34, 0.50, 0.33]
const EYE_SPREAD: float = 0.1
const AURA := Color("fee761")

var _logic: BattleLogic
var _ended: bool = false

@onready var _ground: ColorRect = $Ground
@onready var _unico: TextureRect = $Unico
@onready var _adoc: TextureRect = $Adoc
@onready var _unico_name: Label = $UnicoBox/Name
@onready var _unico_hp: Label = $UnicoBox/Hp
@onready var _unico_bar: ColorRect = $UnicoBox/Bar
@onready var _adoc_stats: Label = $AdocBox/Stats
@onready var _adoc_bar: ColorRect = $AdocBox/Bar
@onready var _narration: Label = $TextBox/Narration
@onready var _menu: OptionMenu = $MenuBox/Options


func begin(logic: BattleLogic, style: Dictionary) -> void:
	_logic = logic
	_ground.color = PlaceholderTileset.GROUNDS[int(style.get("ground", 0))][0]
	_unico.texture = unico_texture(style, UNICO_TILES * PlaceholderTileset.TILE)
	_adoc.texture = PlayerWalker._make_texture(Vector2i.UP)
	_unico_name.text = logic.unico_name
	_narration.text = TEXT_START % logic.unico_name
	# Respiración del Único: sube y baja 2 px.
	var bob := create_tween().set_loops()
	bob.tween_property(_unico, "position:y", _unico.position.y - 2.0, 0.6)
	bob.tween_property(_unico, "position:y", _unico.position.y, 0.6)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _logic == null or event is InputEventMouseMotion:
		return
	get_viewport().set_input_as_handled()
	if _ended:
		if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
			finished.emit(_logic)
		return
	var choice: int = _menu.handle(event)
	if choice < 0:
		return
	var events: Array[Dictionary] = _logic.play_turn(choice as BattleLogic.Action)
	if events.is_empty():
		return
	_narrate(events)
	_refresh()


func _narrate(events: Array[Dictionary]) -> void:
	var lines: Array[String] = []
	for e: Dictionary in events:
		match e.kind:
			&"attack":
				lines.append(TEXT_ATTACK % e.amount)
				_flash(_unico)
			&"defend":
				lines.append(TEXT_DEFEND)
			&"offer_luz":
				lines.append(TEXT_OFFER_LUZ % e.amount)
				_flash(_unico)
			&"flee_fail":
				lines.append(TEXT_FLEE_FAIL)
			&"flee_ok":
				lines.append(TEXT_FLEE_OK)
			&"unico_attack":
				lines.append(TEXT_UNICO_ATTACK % e.amount)
				_flash(_adoc)
			&"victory":
				lines.append(TEXT_VICTORY % int(_logic.balance.victory_luz))
				create_tween().tween_property(_unico, "modulate:a", 0.0, 0.8)
			&"defeat":
				lines.append(TEXT_DEFEAT)
	if _logic.is_over():
		_ended = true
		lines[lines.size() - 1] += TEXT_CONTINUE
	_narration.text = "\n".join(lines)


func _refresh() -> void:
	var l: BattleLogic = _logic
	_unico_hp.text = "PV %d/%d" % [l.unico_hp, l.unico_max_hp]
	_unico_bar.size.x = roundf(BAR_WIDTH * l.unico_hp / l.unico_max_hp)
	_adoc_stats.text = "Adoc   PV %d/%d   Luz %d/%d" % [l.adoc_hp, l.adoc_max_hp, l.luz, int(l.balance.adoc.luz_max)]
	_adoc_bar.size.x = roundf(BAR_WIDTH * l.adoc_hp / l.adoc_max_hp)
	var enabled: Array[bool] = [true, true, l.can_offer_luz(), true]
	_menu.set_options(OPTIONS, enabled, true)
	_menu.visible = not _ended


func _flash(node: CanvasItem) -> void:
	var t := create_tween()
	for i: int in 2:
		t.tween_property(node, "modulate", Color(1, 1, 1, 0.2), 0.06)
		t.tween_property(node, "modulate", Color(1, 1, 1, 1), 0.06)


## Silueta del árbol del Bosque a `px` píxeles, con ojos y un aura punteada alrededor.
static func unico_texture(style: Dictionary, px: int) -> Texture2D:
	var img: Image = PlaceholderTileset.nujio_texture(style, px / PlaceholderTileset.TILE).get_image()
	var shape: int = int(style.get("shape", 0))
	var eye: int = maxi(2, px / 12)
	var ey: int = roundi(EYES_V[shape] * px)
	for side: int in [-1, 1]:
		var ex: int = roundi((0.5 + side * EYE_SPREAD) * px) - eye / 2
		img.fill_rect(Rect2i(ex - 1, ey - 1, eye + 2, eye + 2), PlaceholderTileset.OUTLINE)
		img.fill_rect(Rect2i(ex, ey, eye, eye), PlaceholderTileset.WHITE)
		img.fill_rect(Rect2i(ex + eye / 2, ey + eye / 2, eye / 2, eye / 2), PlaceholderTileset.OUTLINE)
	# Aura: casillas vacías a 2 px de la silueta, en damero.
	var solid := img.duplicate() as Image
	for y: int in px:
		for x: int in px:
			if solid.get_pixel(x, y).a > 0.0 or (x + y) % 2 == 1:
				continue
			for d: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				var p := Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < px and p.y < px and solid.get_pixelv(p).a > 0.0:
					img.set_pixel(x, y, AURA)
					break
	return ImageTexture.create_from_image(img)
