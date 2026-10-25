extends CanvasLayer
## Pantalla de combate (ADR 0009): dibuja un BattleLogic y le pasa las acciones del menú.
## Arriba el Único (monstruo de placeholder con los colores de su Bosque, ver UnicoArt), abajo el
## Adoc. Narración estilo Pokémon con DialogueBox: un mensaje por acción, letra a letra; pulsar
## durante la escritura lo completa y pulsar después pasa al siguiente. Las barras cambian al
## mostrarse el mensaje que las cambia. El menú solo aparece cuando no queda ningún mensaje.
## No aplica nada a GameState: al terminar emite `finished` y Crossing aplica el resultado.
## "Ofrecer N Luz" paga el peaje del Bosque con Luz suelta y el Único se va (en gris si no llega).
## "Ofrenda" abre un submenú con las ofrendas que alcanzan el peaje (ofrendas-v1.md). Contra un
## rival que no acepta pagos (appeasable: false, como el Ofomni descarriado) las dos salen en gris
## y, al elegirlas, explican por qué. Tras la
## victoria se anuncian la XP y cada nivel nuevo (progresion-adoc.md).

signal finished(logic: BattleLogic)

## Textos de placeholder; los revisa narrative-writer.
const TEXT_START: String = "¡%s te cierra el paso!"
const TEXT_PROMPT: String = "¿Qué hará el Adoc?"
const TEXT_ATTACK: String = "Atacas: %d de daño."
const TEXT_DEFEND: String = "Te pones en guardia."
const TEXT_FLEE_FAIL: String = "No logras huir."
const TEXT_FLEE_OK: String = "Huyes a tu lado del Bosque."
const TEXT_UNICO_ATTACK: String = "El Único te golpea: %d de daño."
const TEXT_SPECIAL_WARNING: String = "El Único se prepara para un golpe terrible..."
const TEXT_VICTORY: String = "El Único vuelve a la Luz del Bosque."
const TEXT_VICTORY_LUZ: String = " (+%d Luz)"
const TEXT_DEFEAT: String = "Caes. Despertarás junto a un Nujio."
const OPTIONS: Array[String] = ["Atacar", "Defender", "Ofrecer Luz", "Ofrenda", "Huir"]
## Índice de "Ofrecer Luz" en OPTIONS (su texto lleva el peaje).
const OFFER_LUZ_OPTION: int = 2
## Acción de cada opción del menú, en el mismo orden.
const MENU_ACTIONS: Array[BattleLogic.Action] = [
	BattleLogic.Action.ATTACK, BattleLogic.Action.DEFEND, BattleLogic.Action.OFFER_LUZ,
	BattleLogic.Action.OFRENDA, BattleLogic.Action.FLEE,
]
const TEXT_OFRENDA_ITEM: String = "%s (%d)"
const TEXT_OFRENDA_PLUS_LUZ: String = " + %d Luz"
const TEXT_OFRENDA_COUNT: String = " x%d"
const TEXT_BACK: String = "Volver"
## Submenú de ofrendas: caja ancha (sobre la del texto) a la izquierda.
const SUBMENU_LEFT: float = 4.0

## Segundos que tarda una barra de PV en llegar a su nuevo valor.
const BAR_TIME: float = 0.35
## Tamaño del Único en casillas de 16 px.
const UNICO_TILES: int = 6
const BAR_WIDTH: float = 100.0

var _logic: BattleLogic
var _kind: UnicoArt.Kind = UnicoArt.Kind.BOTARRAMAS
## Submenú de ofrendas abierto: índices de _logic.ofrendas de cada opción (sin la de volver).
var _ofrenda_choices: Array[int] = []
var _in_submenu: bool = false
var _menu_left: float = 0.0
var _options_right: float = 0.0

@onready var _ground: ColorRect = $Ground
@onready var _unico: TextureRect = $Unico
@onready var _adoc: TextureRect = $Adoc
@onready var _unico_name: Label = $UnicoBox/Name
@onready var _unico_hp: Label = $UnicoBox/Hp
@onready var _unico_bar: ColorRect = $UnicoBox/Bar
@onready var _adoc_stats: Label = $AdocBox/Stats
@onready var _adoc_bar: ColorRect = $AdocBox/Bar
## Mensajes: { "text", y opcionalmente "unico_hp", "adoc_hp", "luz", "flash" }.
@onready var _text_box: DialogueBox = $TextBox
@onready var _menu_box: Control = $MenuBox
@onready var _menu: OptionMenu = $MenuBox/Options


func _ready() -> void:
	_menu_left = _menu_box.offset_left
	_options_right = _menu.offset_right
	_menu.skip_disabled = false
	_text_box.line_started.connect(_on_message_started)
	_text_box.finished.connect(_on_messages_finished)


func begin(logic: BattleLogic, style: Dictionary, kind: UnicoArt.Kind) -> void:
	_logic = logic
	_kind = kind
	_ground.color = PlaceholderTileset.GROUNDS[int(style.get("ground", 0))][0]
	_unico.texture = UnicoArt.battle_texture(kind, style, UNICO_TILES * PlaceholderTileset.TILE)
	_adoc.texture = PlayerWalker.back_texture()
	_unico_name.text = logic.unico_name
	# Respiración del Único: sube y baja 2 px.
	var bob := create_tween().set_loops()
	bob.tween_property(_unico, "position:y", _unico.position.y - 2.0, 0.6)
	bob.tween_property(_unico, "position:y", _unico.position.y, 0.6)
	_set_bars({ "unico_hp": logic.unico_hp, "adoc_hp": logic.adoc_hp, "luz": logic.luz }, false)
	_show_messages(start_messages(logic))


## Mensajes del comienzo: "¡X te cierra el paso!" y, si el Adoc no lleva arma, "Peleas sin arma"
## (ATQ base; sigilo-y-robo.md, #131 provisional).
static func start_messages(logic: BattleLogic) -> Array[Dictionary]:
	var out: Array[Dictionary] = [{ "text": TEXT_START % logic.unico_name }]
	if logic.unarmed:
		out.append({ "text": Texts.get_text("battle_unarmed") })
	return out


## Textos propios del rival, ya leídos de data/text/sistema.json (ver messages_for). Un combate
## fatal cambia el mensaje de derrota por el de game over.
static func texts_for(logic: BattleLogic) -> Dictionary:
	var out: Dictionary = {}
	for key: String in logic.unico_texts:
		out[key] = Texts.get_text(str(logic.unico_texts[key]))
	if logic.fatal:
		out.defeat = Texts.get_text("defeat_fatal_game_over") % logic.unico_name
	return out


## Mensajes de un turno, uno por evento y en orden, con el estado que muestran las barras.
## `texts`: textos propios del rival (attack, warning, special, special_defended, defeat) que
## sustituyen a los genéricos. Pura: la usan la escena y los tests.
static func messages_for(events: Array[Dictionary], balance: Dictionary, texts: Dictionary = {}) -> Array[Dictionary]:
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
				m.text = Texts.get_text("battle_offer_luz_paid") % e.amount
			&"flee_fail":
				m.text = TEXT_FLEE_FAIL
			&"flee_ok":
				m.text = TEXT_FLEE_OK
			&"unico_attack":
				m.text = str(texts.get("attack", TEXT_UNICO_ATTACK)) % e.amount
				m.flash = &"adoc"
			&"unico_special":
				var key: String = "special_defended" if e.get("defended", false) else "special"
				m.text = str(texts.get(key, TEXT_UNICO_ATTACK)) % e.amount
				m.flash = &"adoc"
			&"special_warning":
				m.text = str(texts.get("warning", TEXT_SPECIAL_WARNING))
			&"victory":
				# La Luz suelta tiene tope: con la Luz al máximo no se anuncia el +1.
				var gained: int = mini(int(balance.victory_luz), int(balance.adoc.luz_max) - int(e.luz))
				m.text = TEXT_VICTORY + (TEXT_VICTORY_LUZ % gained if gained > 0 else "")
				m.luz = int(e.luz) + maxi(0, gained)
				m.flash = &"vanish"
				out.append(m)
				# Después de la victoria: la XP y un mensaje por nivel nuevo (sin tocar las barras).
				if int(e.get("xp", 0)) > 0:
					out.append({ "text": Texts.get_text("xp_gained") % int(e.xp) })
				for level: Variant in e.get("level_ups", []):
					out.append({ "text": Texts.get_text("level_up") % int(level) })
				continue
			&"ofrenda":
				m.text = Texts.get_text("battle_ofrenda_used") % Ofrendas.display_name(StringName(str(e.get("id", ""))))
			&"unico_leaves":
				m.text = Texts.get_text("battle_ofrenda_unico_leaves")
				m.flash = &"vanish"
			&"defeat":
				m.text = str(texts.get("defeat", TEXT_DEFEAT))
		out.append(m)
	return out


func _unhandled_input(event: InputEvent) -> void:
	if _logic == null or event is InputEventMouseMotion:
		return
	get_viewport().set_input_as_handled()
	if _menu_box.visible:
		if _in_submenu:
			_handle_submenu(_menu.handle(event))
			return
		var choice: int = _menu.handle(event)
		var blocked: String = blocked_text(_logic, MENU_ACTIONS[_menu.index]) if choice == OptionMenu.DISABLED else ""
		if blocked != "":
			_show_messages([{ "text": blocked }])
		elif choice >= 0 and MENU_ACTIONS[choice] == BattleLogic.Action.OFRENDA:
			_open_submenu()
		elif choice >= 0:
			_play(_logic.play_turn(MENU_ACTIONS[choice]))
		return
	_text_box.handle(event)


## Explicación al elegir un pago desactivado porque el rival no los acepta ("" si no aplica).
## Los textos son los del monstruo (texts.offer_luz_blocked y texts.ofrenda_blocked).
static func blocked_text(logic: BattleLogic, action: BattleLogic.Action) -> String:
	if logic.accepts_payment:
		return ""
	var key: String = ""
	match action:
		BattleLogic.Action.OFFER_LUZ:
			key = "offer_luz_blocked"
		BattleLogic.Action.OFRENDA:
			key = "ofrenda_blocked"
	if key == "":
		return ""
	return Texts.get_text(str(logic.unico_texts.get(key, "battle_payment_refused")))


## Opciones del menú de combate: "Ofrecer Luz" lleva el peaje si el rival acepta pagos.
static func menu_options(logic: BattleLogic) -> Array[String]:
	var texts: Array[String] = OPTIONS.duplicate()
	if logic.accepts_payment and logic.toll > 0:
		texts[OFFER_LUZ_OPTION] = Texts.get_text("battle_offer_luz_option") % logic.toll
	return texts


func _play(events: Array[Dictionary]) -> void:
	if not events.is_empty():
		_show_messages(messages_for(events, _logic.balance, texts_for(_logic)))


## Texto de una ofrenda en el submenú: nombre y valor, cuántas hay y la Luz suelta que la completa.
static func ofrenda_option(item: Dictionary, count: int, toll: int) -> String:
	var text: String = TEXT_OFRENDA_ITEM % [Ofrendas.display_name(StringName(str(item.id))), int(item.luz)]
	if count > 1:
		text += TEXT_OFRENDA_COUNT % count
	var luz: int = Ofrendas.luz_needed(int(item.luz), toll)
	if luz > 0:
		text += TEXT_OFRENDA_PLUS_LUZ % luz
	return text


func _open_submenu() -> void:
	_ofrenda_choices = _logic.payable_ofrendas()
	var texts: Array[String] = []
	var enabled: Array[bool] = []
	for i: int in _ofrenda_choices:
		var item: Dictionary = _logic.ofrendas[i]
		texts.append(ofrenda_option(item, Ofrendas.count_of(_logic.ofrendas, str(item.id)), _logic.toll))
		enabled.append(true)
	texts.append(TEXT_BACK)
	enabled.append(true)
	_in_submenu = true
	_menu_box.offset_left = SUBMENU_LEFT
	_menu.offset_right = _options_right + _menu_left - SUBMENU_LEFT
	_menu.set_options(texts, enabled)


func _close_submenu() -> void:
	_in_submenu = false
	_menu_box.offset_left = _menu_left
	_menu.offset_right = _options_right


func _handle_submenu(choice: int) -> void:
	if choice == OptionMenu.CANCEL or choice == _ofrenda_choices.size():
		_close_submenu()
		_open_menu()
	elif choice >= 0:
		_close_submenu()
		_play(_logic.offer_ofrenda(_ofrenda_choices[choice]))


func _show_messages(messages: Array[Dictionary]) -> void:
	_menu_box.visible = false
	_text_box.show_lines(messages)


## Al mostrarse cada mensaje: barras y destellos con el estado que trae.
func _on_message_started(m: Dictionary) -> void:
	if m.has("unico_hp"):
		_set_bars(m, true)
	match m.get("flash", &""):
		&"unico":
			_flash(_unico)
			Sfx.play(&"hit")
		&"adoc":
			_flash(_adoc)
			# El Ofomni ataca con látigos (monstruos.md).
			Sfx.play(&"whip" if _kind == UnicoArt.Kind.EYES else &"hit")
		&"vanish":
			create_tween().tween_property(_unico, "modulate:a", 0.0, 0.8)


## Sin mensajes pendientes: abre el menú o, si el combate acabó, lo cierra.
func _on_messages_finished() -> void:
	if _logic.is_over():
		finished.emit(_logic)
	else:
		_open_menu()


func _open_menu() -> void:
	_text_box.show_static(TEXT_PROMPT)
	var enabled: Array[bool] = [true, true, _logic.can_offer_luz(), _logic.can_offer_ofrenda(), true]
	_menu.set_options(menu_options(_logic), enabled, true)
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
