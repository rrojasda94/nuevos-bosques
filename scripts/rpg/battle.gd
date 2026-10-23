extends CanvasLayer
## Pantalla de combate (ADR 0009): dibuja un BattleLogic y le pasa las acciones del menú.
## Arriba el Único (monstruo de placeholder con los colores de su Bosque, ver UnicoArt), abajo el
## Adoc. Narración estilo Pokémon: un mensaje por acción, letra a letra; pulsar durante la
## escritura lo completa y pulsar después pasa al siguiente. Las barras cambian al mostrarse el
## mensaje que las cambia. El menú solo aparece cuando no queda ningún mensaje.
## No aplica nada a GameState: al terminar emite `finished` y Crossing aplica el resultado.

signal finished(logic: BattleLogic)

## Textos de placeholder; los revisa narrative-writer.
const TEXT_START: String = "¡El %s te cierra el paso!"
const TEXT_PROMPT: String = "¿Qué hará el Adoc?"
const TEXT_ATTACK: String = "Atacas: %d de daño."
const TEXT_DEFEND: String = "Te pones en guardia."
const TEXT_OFFER_LUZ: String = "Ofreces Luz: %d de daño."
const TEXT_FLEE_FAIL: String = "No logras huir."
const TEXT_FLEE_OK: String = "Huyes a tu lado del Bosque."
const TEXT_UNICO_ATTACK: String = "El Único te golpea: %d de daño."
const TEXT_VICTORY: String = "El Único vuelve a la Luz del Bosque."
const TEXT_VICTORY_LUZ: String = " (+%d Luz)"
const TEXT_DEFEAT: String = "Caes. Despertarás junto al Nujio de tu villa."
const OPTIONS: Array[String] = ["Atacar", "Defender", "Ofrecer Luz", "Huir"]

## Letras por segundo de la narración. AJUSTAR AQUÍ la velocidad del texto.
const TEXT_SPEED: float = 45.0
## Segundos que tarda una barra de PV en llegar a su nuevo valor.
const BAR_TIME: float = 0.35
## Tamaño del Único en casillas de 16 px.
const UNICO_TILES: int = 6
const BAR_WIDTH: float = 100.0

var _logic: BattleLogic
## Mensajes pendientes: { "text", y opcionalmente "unico_hp", "adoc_hp", "luz", "flash" }.
var _queue: Array[Dictionary] = []
var _typing: bool = false
var _chars: float = 0.0
var _blink: float = 0.0

@onready var _ground: ColorRect = $Ground
@onready var _unico: TextureRect = $Unico
@onready var _adoc: TextureRect = $Adoc
@onready var _unico_name: Label = $UnicoBox/Name
@onready var _unico_hp: Label = $UnicoBox/Hp
@onready var _unico_bar: ColorRect = $UnicoBox/Bar
@onready var _adoc_stats: Label = $AdocBox/Stats
@onready var _adoc_bar: ColorRect = $AdocBox/Bar
@onready var _narration: Label = $TextBox/Narration
@onready var _more: CanvasItem = $TextBox/More
@onready var _menu_box: Control = $MenuBox
@onready var _menu: OptionMenu = $MenuBox/Options


func begin(logic: BattleLogic, style: Dictionary, kind: UnicoArt.Kind) -> void:
	_logic = logic
	_ground.color = PlaceholderTileset.GROUNDS[int(style.get("ground", 0))][0]
	_unico.texture = UnicoArt.texture(kind, style, UNICO_TILES * PlaceholderTileset.TILE)
	_adoc.texture = PlayerWalker._make_texture(Vector2i.UP)
	_unico_name.text = logic.unico_name
	# Respiración del Único: sube y baja 2 px.
	var bob := create_tween().set_loops()
	bob.tween_property(_unico, "position:y", _unico.position.y - 2.0, 0.6)
	bob.tween_property(_unico, "position:y", _unico.position.y, 0.6)
	_set_bars({ "unico_hp": logic.unico_hp, "adoc_hp": logic.adoc_hp, "luz": logic.luz }, false)
	_show_messages([{ "text": TEXT_START % logic.unico_name }])


## Mensajes de un turno, uno por evento y en orden, con el estado que muestran las barras.
## Pura: la usan la escena y los tests.
static func messages_for(events: Array[Dictionary], balance: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in events:
		var m: Dictionary = { "unico_hp": e.unico_hp, "adoc_hp": e.adoc_hp, "luz": e.luz }
		match e.kind:
			&"attack":
				m.text = TEXT_ATTACK % e.amount
				m.flash = &"unico"
			&"defend":
				m.text = TEXT_DEFEND
			&"offer_luz":
				m.text = TEXT_OFFER_LUZ % e.amount
				m.flash = &"unico"
			&"flee_fail":
				m.text = TEXT_FLEE_FAIL
			&"flee_ok":
				m.text = TEXT_FLEE_OK
			&"unico_attack":
				m.text = TEXT_UNICO_ATTACK % e.amount
				m.flash = &"adoc"
			&"victory":
				# La Luz suelta tiene tope: con la Luz al máximo no se anuncia el +1.
				var gained: int = mini(int(balance.victory_luz), int(balance.adoc.luz_max) - int(e.luz))
				m.text = TEXT_VICTORY + (TEXT_VICTORY_LUZ % gained if gained > 0 else "")
				m.luz = int(e.luz) + maxi(0, gained)
				m.flash = &"vanish"
			&"defeat":
				m.text = TEXT_DEFEAT
		out.append(m)
	return out


func _process(delta: float) -> void:
	if _typing:
		_chars += delta * TEXT_SPEED
		_narration.visible_characters = int(_chars)
		if _narration.visible_characters >= _narration.get_total_character_count():
			_finish_typing()
	elif not _menu_box.visible and _logic != null:
		_blink += delta
		_more.visible = fmod(_blink, 0.6) < 0.4


func _unhandled_input(event: InputEvent) -> void:
	if _logic == null or event is InputEventMouseMotion:
		return
	get_viewport().set_input_as_handled()
	if _menu_box.visible:
		var choice: int = _menu.handle(event)
		if choice >= 0:
			var events: Array[Dictionary] = _logic.play_turn(choice as BattleLogic.Action)
			if not events.is_empty():
				_show_messages(messages_for(events, _logic.balance))
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		if _typing:
			_finish_typing()
		else:
			_next_message()


func _show_messages(messages: Array[Dictionary]) -> void:
	_queue = messages
	_menu_box.visible = false
	_next_message()


## Muestra el siguiente mensaje; sin mensajes, abre el menú o, si el combate acabó, lo cierra.
func _next_message() -> void:
	if _queue.is_empty():
		if _logic.is_over():
			finished.emit(_logic)
		else:
			_open_menu()
		return
	var m: Dictionary = _queue.pop_front()
	_narration.text = m.text
	_narration.visible_characters = 0
	_chars = 0.0
	_typing = true
	_more.visible = false
	if m.has("unico_hp"):
		_set_bars(m, true)
	match m.get("flash", &""):
		&"unico":
			_flash(_unico)
		&"adoc":
			_flash(_adoc)
		&"vanish":
			create_tween().tween_property(_unico, "modulate:a", 0.0, 0.8)


func _finish_typing() -> void:
	_typing = false
	_narration.visible_characters = -1
	_blink = 0.0
	_more.visible = true


func _open_menu() -> void:
	_narration.text = TEXT_PROMPT
	_narration.visible_characters = -1
	_more.visible = false
	var enabled: Array[bool] = [true, true, _logic.can_offer_luz(), true]
	_menu.set_options(OPTIONS, enabled, true)
	_menu_box.visible = true


## Barras y cifras con el estado de un mensaje. `animate`: las barras bajan (o suben) con un tween.
func _set_bars(state: Dictionary, animate: bool) -> void:
	var l: BattleLogic = _logic
	_unico_hp.text = "PV %d/%d" % [state.unico_hp, l.unico_max_hp]
	_adoc_stats.text = "Adoc   PV %d/%d   Luz %d/%d" % [state.adoc_hp, l.adoc_max_hp, state.luz, int(l.balance.adoc.luz_max)]
	var targets: Dictionary = {
		_unico_bar: roundf(BAR_WIDTH * int(state.unico_hp) / l.unico_max_hp),
		_adoc_bar: roundf(BAR_WIDTH * int(state.adoc_hp) / l.adoc_max_hp),
	}
	for bar: ColorRect in targets:
		if animate and bar.size.x != targets[bar]:
			create_tween().tween_property(bar, "size:x", targets[bar], BAR_TIME)
		else:
			bar.size.x = targets[bar]


func _flash(node: CanvasItem) -> void:
	var t := create_tween()
	for i: int in 2:
		t.tween_property(node, "modulate", Color(1, 1, 1, 0.2), 0.06)
		t.tween_property(node, "modulate", Color(1, 1, 1, 1), 0.06)
