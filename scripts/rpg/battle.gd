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
## victoria se anuncian la XP y cada nivel nuevo (progresion-adoc.md), con el aviso de los puntos
## para crecer, y el botín de la skill Botín. El Golpe fuerte (skill) se narra en su ataque.
## Combate en grupo (monstruos.md, otros-adoc.md): con varios enemigos, el Único grande da paso a una
## fila de hasta 4, cada uno con su número y una barra de PV pequeña, y la caja de arriba muestra el
## grupo, cuántos quedan y la suma de sus PV; Atacar abre un submenú de objetivo (el cursor empieza
## en el de menos PV y una flecha lo marca en la fila). Los aliados (hasta 2: otro adoc con su ropa o
## un Único del Bosque) se dibujan junto al Adoc con su barra; el que se retira queda en gris. La
## narración nombra a cada actor ("Reparep 2 se deshace en niebla.", "Ataque conjunto de los
## reparep: 9 de daño.").
## IA de combate (ia-de-combate.md): "Táctica" abre un submenú con Defender, Apresurar, Esperar,
## cambiar de fila y, con aliados, la orden al grupo (que no gasta turno). Arriba a la izquierda, una
## línea de iconos con el orden de la próxima ronda. Con formación, cada bando se dibuja en dos filas
## separadas (el jugador: detrás a la izquierda, tras una raya; los enemigos: detrás, más arriba y a
## la derecha), con el icono del rol de cada aliado (A, D, +).

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
const OPTIONS: Array[String] = ["Atacar", "Táctica", "Ofrecer Luz", "Ofrenda", "Huir"]
## Índice de "Ofrecer Luz" en OPTIONS (su texto lleva el peaje).
const OFFER_LUZ_OPTION: int = 2
## Índice de "Táctica" en OPTIONS: abre el submenú (Defender, Apresurar, Esperar, fila, orden).
const TACTICS_OPTION: int = 1
## Entradas del submenú de táctica que no son una acción de BattleLogic.
const TACTIC_ORDER: int = -10
const TACTIC_BACK: int = -11
## Acción de cada opción del menú, en el mismo orden (la de Táctica es la primera de su submenú).
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
## Submenú de objetivo: caja algo más ancha que el menú, a la derecha.
const TARGET_MENU_LEFT: float = 150.0

## Segundos que tarda una barra de PV en llegar a su nuevo valor.
const BAR_TIME: float = 0.35
## Tamaño del Único en casillas de 16 px.
const UNICO_TILES: int = 6
const BAR_WIDTH: float = 100.0
## Fila de enemigos de un grupo: cuadro de cada uno, paso entre cuadros, borde derecho y alto de su
## sprite; barra pequeña debajo.
const ENEMY_PX: int = 40
const ENEMY_STEP: float = 42.0
const ENEMY_RIGHT: float = 318.0
const ENEMY_TOP: float = 40.0
const MINI_BAR_WIDTH: float = 30.0
const MINI_BAR_HEIGHT: float = 3.0
## Aliados junto al Adoc: cuadro, primera x, paso y alto.
const ALLY_PX: int = 32
const ALLY_LEFT: float = 88.0
const ALLY_STEP: float = 36.0
const ALLY_TOP: float = 90.0
const ALLY_UNICO_PX: int = 48
const COLOR_BAR_BACK := Color(0.227, 0.267, 0.4, 1)
const COLOR_ENEMY_BAR := Color(0.894, 0.231, 0.267, 1)
const COLOR_ALLY_BAR := Color(0.388, 0.78, 0.302, 1)
const COLOR_LABEL := Color(0.996, 0.906, 0.38, 1)
const TEXT_CURSOR: String = "v"
## Línea del orden de turnos: esquina, tamaño y paso de los iconos.
const ORDER_POS := Vector2(4.0, 35.0)
const ORDER_ICON: float = 12.0
const ORDER_STEP: float = 13.0
const COLOR_ORDER_BACK := Color(0.353, 0.412, 0.533, 1)
const COLOR_ORDER_FIRST := Color(0.996, 0.906, 0.38, 1)
## Filas del jugador: x del Adoc delante (como siempre), paso de cada miembro y raya entre filas.
const FRONT_LEFT: float = 36.0
const ADOC_STEP_FRONT: float = 52.0
const BACK_LEFT: float = 2.0
const BACK_STEP: float = 2.0
const ROW_GAP: float = 6.0
## Enemigos de detrás: más arriba y a la derecha, con un hueco entre filas.
const ENEMY_BACK_RISE: float = 12.0
const ENEMY_FRONT_DROP: float = 4.0
const ENEMY_ROW_GAP: float = 10.0
## Alto de una línea del menú (para que el submenú de táctica crezca hacia arriba).
const MENU_LINE: float = 10.0
const COLOR_ROLE := {
	&"attacker": Color(0.894, 0.231, 0.267, 1),
	&"defender": Color(0.6, 0.75, 1.0, 1),
	&"support": Color(0.388, 0.78, 0.302, 1),
}

var _logic: BattleLogic
var _kind: UnicoArt.Kind = UnicoArt.Kind.BOTARRAMAS
## Submenú de ofrendas abierto: índices de _logic.ofrendas de cada opción (sin la de volver).
var _ofrenda_choices: Array[int] = []
var _in_submenu: bool = false
var _menu_left: float = 0.0
var _options_right: float = 0.0
## Submenú de objetivo abierto: índices de enemigos de cada opción (sin la de volver).
var _target_choices: Array[int] = []
var _in_target_menu: bool = false
## Fila de enemigos y aliados (combates en grupo o con aliados): sprite y barra de cada uno.
var _enemy_sprites: Array[TextureRect] = []
var _enemy_bars: Array[ColorRect] = []
var _ally_sprites: Array[TextureRect] = []
var _ally_bars: Array[ColorRect] = []
var _ally_bar_backs: Array[ColorRect] = []
var _ally_px: Array[int] = []
var _ally_roles: Array[Label] = []
var _enemy_bar_backs: Array[ColorRect] = []
var _enemy_numbers: Array[Label] = []
var _cursor: Label
## Submenú de táctica: lo que hace cada opción (una BattleLogic.Action, TACTIC_ORDER o TACTIC_BACK).
var _tactic_choices: Array[int] = []
var _in_tactics: bool = false
var _in_order_menu: bool = false
## Acción que espera objetivo en el submenú de objetivo (Atacar, Apresurar o Esperar).
var _pending_action: BattleLogic.Action = BattleLogic.Action.ATTACK
var _menu_top: float = 0.0
## Línea del orden de turnos y raya entre las filas del jugador.
var _order_line: Control
var _row_divider: ColorRect

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
	_menu_top = _menu_box.offset_top
	_options_right = _menu.offset_right
	_menu.skip_disabled = false
	_text_box.line_started.connect(_on_message_started)
	_text_box.finished.connect(_on_messages_finished)


## `ally_clothes`: ropa de los adoc aliados, en orden (los Únicos aliados se dibujan con el Bosque).
func begin(logic: BattleLogic, style: Dictionary, kind: UnicoArt.Kind, ally_clothes: Array = []) -> void:
	_logic = logic
	_kind = kind
	_ground.color = PlaceholderTileset.GROUNDS[int(style.get("ground", 0))][0]
	_adoc.texture = PlayerWalker.back_texture()
	if logic.is_group():
		_unico.visible = false
		_build_enemy_row(style)
		_unico_name.text = group_title(logic)
	else:
		_unico.texture = UnicoArt.battle_texture(kind, style, UNICO_TILES * PlaceholderTileset.TILE)
		_unico_name.text = logic.unico_name
		# Respiración del Único: sube y baja 2 px.
		var bob := create_tween().set_loops()
		bob.tween_property(_unico, "position:y", _unico.position.y - 2.0, 0.6)
		bob.tween_property(_unico, "position:y", _unico.position.y, 0.6)
	_build_allies(style, ally_clothes)
	_build_order_line()
	_layout_player()
	_set_bars(state_of(logic), false)
	_show_messages(start_messages(logic))


## Estado de las barras al empezar (con el formato de los eventos).
static func state_of(logic: BattleLogic) -> Dictionary:
	return {
		"unico_hp": logic.unico_hp, "adoc_hp": logic.adoc_hp, "luz": logic.luz,
		"enemy_hp": logic.enemies.map(func(e: Dictionary) -> int: return int(e.hp)),
		"ally_hp": logic.allies.map(func(a: Dictionary) -> int: return int(a.hp)),
	}


## Nombre de la caja de arriba en un grupo: "Reparep x3" (el nombre sin su número).
static func group_title(logic: BattleLogic) -> String:
	var base: String = str(logic.unico_name).rsplit(" ", true, 1)[0]
	return "%s x%d" % [base, logic.enemies.size()]


## Fila de enemigos: hasta 4 cuadros alineados a la derecha, con su número y su barra pequeña. Con
## formación, los de detrás van más arriba y a la derecha, separados de los de delante.
func _build_enemy_row(style: Dictionary) -> void:
	var n: int = _logic.enemies.size()
	var tex: Texture2D = UnicoArt.battle_texture(_kind, style, ENEMY_PX)
	var spots: Array[Vector2] = enemy_spots(_logic)
	for i: int in n:
		var at: Vector2 = spots[i]
		var sprite := TextureRect.new()
		sprite.texture = tex
		sprite.position = at
		sprite.size = Vector2(ENEMY_PX, ENEMY_PX)
		add_child(sprite)
		move_child(sprite, _unico.get_index())
		var bob := sprite.create_tween().set_loops()
		bob.tween_interval(0.15 * i + 0.01)
		bob.tween_property(sprite, "position:y", at.y - 2.0, 0.5)
		bob.tween_property(sprite, "position:y", at.y, 0.5)
		_enemy_sprites.append(sprite)
		var bar_x: float = at.x + (ENEMY_PX - MINI_BAR_WIDTH) / 2.0 + 3.0
		_enemy_bars.append(_mini_bar(Vector2(bar_x, at.y + ENEMY_PX + 3.0), COLOR_ENEMY_BAR)[1])
		var number := Label.new()
		number.text = str(i + 1)
		var role: StringName = _logic.enemies[i].get("role", &"")
		if role != &"":
			number.text += role_icon(role)
		number.add_theme_font_size_override(&"font_size", 8)
		number.add_theme_color_override(&"font_color", COLOR_ROLE.get(role, COLOR_LABEL))
		number.position = Vector2(bar_x - 7.0, at.y + ENEMY_PX - 3.0)
		add_child(number)
	_cursor = Label.new()
	_cursor.text = TEXT_CURSOR
	_cursor.add_theme_font_size_override(&"font_size", 8)
	_cursor.add_theme_color_override(&"font_color", COLOR_LABEL)
	_cursor.visible = false
	add_child(_cursor)


## Esquina de cada enemigo de un grupo: sin nadie detrás, la fila de siempre (alineada a la derecha);
## con fila de detrás, esa va a la derecha y más arriba, y la de delante a su izquierda, más abajo.
static func enemy_spots(logic: BattleLogic) -> Array[Vector2]:
	var n: int = logic.enemies.size()
	var front: Array[int] = []
	var back: Array[int] = []
	for i: int in n:
		if int(logic.enemies[i].get("row", BattleLogic.FRONT)) == BattleLogic.BACK:
			back.append(i)
		else:
			front.append(i)
	var out: Array[Vector2] = []
	out.resize(n)
	if back.is_empty():
		for i: int in n:
			out[i] = Vector2(ENEMY_RIGHT - ENEMY_STEP * (n - i), ENEMY_TOP)
		return out
	for k: int in back.size():
		out[back[k]] = Vector2(ENEMY_RIGHT - ENEMY_STEP * (back.size() - k), ENEMY_TOP - ENEMY_BACK_RISE)
	var right: float = ENEMY_RIGHT - ENEMY_STEP * back.size() - ENEMY_ROW_GAP
	for k: int in front.size():
		out[front[k]] = Vector2(right - ENEMY_STEP * (front.size() - k), ENEMY_TOP + ENEMY_FRONT_DROP)
	return out


## Icono del rol (texto de una letra de data/text/sistema.json; "" sin rol).
static func role_icon(role: StringName) -> String:
	return Texts.get_text("battle_role_icon_%s" % role) if role != &"" else ""


## Aliados junto al Adoc: el adoc con su ropa (de espaldas, como el Adoc) o el Único aliado, con su
## barra y el icono de su rol. Dónde va cada uno lo decide _layout_player.
func _build_allies(style: Dictionary, ally_clothes: Array) -> void:
	var adoc_index: int = 0
	for i: int in _logic.allies.size():
		var ally: Dictionary = _logic.allies[i]
		var tex: Texture2D
		var px: int = ALLY_PX
		if ally.kind == &"adoc":
			var clothes: Dictionary = ally_clothes[adoc_index] if adoc_index < ally_clothes.size() else {}
			adoc_index += 1
			tex = AdocNpc.frame_texture(clothes, Vector2i.UP)
		else:
			# El Único aliado, más alto que un adoc (su PNG se amplía a escala entera).
			px = ALLY_UNICO_PX
			tex = UnicoArt.battle_texture(UnicoArt.kind_for(ally.kind), style, px)
		var sprite := TextureRect.new()
		sprite.texture = tex
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.size = Vector2(px, px)
		add_child(sprite)
		move_child(sprite, _adoc.get_index())
		_ally_sprites.append(sprite)
		_ally_px.append(px)
		var bars: Array[ColorRect] = _mini_bar(Vector2.ZERO, COLOR_ALLY_BAR)
		_ally_bar_backs.append(bars[0])
		_ally_bars.append(bars[1])
		var role: StringName = ally.get("role", &"")
		var icon := Label.new()
		icon.text = role_icon(role)
		icon.add_theme_font_size_override(&"font_size", 8)
		icon.add_theme_color_override(&"font_color", COLOR_ROLE.get(role, COLOR_LABEL))
		icon.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 1))
		icon.add_theme_constant_override(&"outline_size", 2)
		add_child(icon)
		_ally_roles.append(icon)


## Coloca al Adoc y a sus aliados según su fila: los de detrás a la izquierda, una raya, y los de
## delante a la derecha (sin nadie detrás, como siempre: el Adoc en x = 36 y los aliados a su lado).
func _layout_player() -> void:
	var l: BattleLogic = _logic
	var members: Array[int] = [BattleLogic.TARGET_ADOC]
	for i: int in l.allies.size():
		members.append(i)
	var spots: Dictionary = {}
	var back_x: float = BACK_LEFT
	var divider_x: float = -1.0
	for ref: int in members:
		if _row_of(ref) == BattleLogic.BACK:
			spots[ref] = back_x
			divider_x = maxf(divider_x, back_x + _px_of(ref) - 4.0)
			back_x += _px_of(ref) + BACK_STEP
	var any_back: bool = divider_x >= 0.0
	var front_x: float = maxf(FRONT_LEFT, divider_x + ROW_GAP) if any_back else FRONT_LEFT
	for ref: int in members:
		if _row_of(ref) != BattleLogic.BACK:
			spots[ref] = front_x
			front_x += ADOC_STEP_FRONT if ref == BattleLogic.TARGET_ADOC else ALLY_STEP
	_adoc.position = Vector2(float(spots[BattleLogic.TARGET_ADOC]), _adoc.position.y)
	_adoc.modulate = Color(0.85, 0.85, 0.9, 1) if _row_of(BattleLogic.TARGET_ADOC) == BattleLogic.BACK else Color(1, 1, 1, 1)
	for i: int in l.allies.size():
		var px: int = _ally_px[i]
		var x: float = float(spots[i])
		var top: float = ALLY_TOP + ALLY_PX - px
		_ally_sprites[i].position = Vector2(x, top)
		var bar_at := Vector2(x + (px - MINI_BAR_WIDTH) / 2.0, top - 5.0)
		_ally_bar_backs[i].position = bar_at
		_ally_bars[i].position = bar_at
		_ally_roles[i].position = bar_at + Vector2(MINI_BAR_WIDTH + 2.0, -5.0)
	if _row_divider == null:
		_row_divider = ColorRect.new()
		_row_divider.color = COLOR_LABEL
		_row_divider.size = Vector2(1.0, 30.0)
		add_child(_row_divider)
		move_child(_row_divider, _adoc.get_index())
	_row_divider.visible = any_back and l.has_formation()
	_row_divider.position = Vector2(divider_x + ROW_GAP / 2.0, 92.0)


func _row_of(ref: int) -> int:
	return _logic.adoc_row if ref == BattleLogic.TARGET_ADOC else int(_logic.allies[ref].row)


func _px_of(ref: int) -> float:
	return _adoc.size.x if ref == BattleLogic.TARGET_ADOC else float(_ally_px[ref])


## Barra pequeña: [fondo, barra].
func _mini_bar(at: Vector2, color: Color) -> Array[ColorRect]:
	var back := ColorRect.new()
	back.color = COLOR_BAR_BACK
	back.position = at
	back.size = Vector2(MINI_BAR_WIDTH, MINI_BAR_HEIGHT)
	add_child(back)
	var bar := ColorRect.new()
	bar.color = color
	bar.position = at
	bar.size = Vector2(MINI_BAR_WIDTH, MINI_BAR_HEIGHT)
	add_child(bar)
	return [back, bar]


## Línea del orden de turnos (arriba a la izquierda, bajo la caja del rival).
func _build_order_line() -> void:
	_order_line = Control.new()
	_order_line.position = ORDER_POS
	add_child(_order_line)


## Dibuja el orden de la próxima ronda: un icono por hueco (el Adoc, cada aliado y cada enemigo o el
## grupo entero), el primero subrayado. Los enemigos de un grupo llevan su número.
func _draw_order() -> void:
	if _order_line == null:
		return
	for child: Node in _order_line.get_children():
		_order_line.remove_child(child)
		child.queue_free()
	var order: Array[Dictionary] = _logic.turn_order()
	var back := ColorRect.new()
	back.color = COLOR_ORDER_BACK
	back.size = Vector2(ORDER_STEP * order.size() + 2.0, ORDER_ICON + 4.0)
	back.position = Vector2(-2.0, -1.0)
	_order_line.add_child(back)
	for k: int in order.size():
		var slot: Dictionary = order[k]
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(ORDER_ICON, ORDER_ICON)
		icon.position = Vector2(ORDER_STEP * k, 0.0)
		var tag: String = ""
		match slot.side:
			BattleLogic.SLOT_ADOC:
				icon.texture = _adoc.texture
			BattleLogic.SLOT_ALLY:
				icon.texture = _ally_sprites[int(slot.index)].texture
			BattleLogic.SLOT_ENEMY:
				icon.texture = _enemy_sprites[int(slot.index)].texture if _logic.is_group() else _unico.texture
				if _logic.is_group():
					tag = str(int(slot.index) + 1)
			BattleLogic.SLOT_GROUP:
				icon.texture = _enemy_sprites[0].texture if _logic.is_group() else _unico.texture
				if _logic.is_group():
					tag = "x%d" % _logic.alive_enemies().size()
		_order_line.add_child(icon)
		if tag != "":
			var label := Label.new()
			label.text = tag
			label.add_theme_font_size_override(&"font_size", 8)
			label.add_theme_color_override(&"font_color", COLOR_LABEL)
			label.position = Vector2(ORDER_STEP * k + 6.0, 4.0)
			_order_line.add_child(label)
		if k == 0:
			var mark := ColorRect.new()
			mark.color = COLOR_ORDER_FIRST
			mark.size = Vector2(ORDER_ICON, 1.0)
			mark.position = Vector2(0.0, ORDER_ICON + 1.0)
			_order_line.add_child(mark)


## Mensajes del comienzo: "¡X te cierra el paso!" (o, contra un grupo, "¡Te rodean los reparep! Son
## 3."), uno por aliado ("Tavra pelea a tu lado.") y, si el Adoc no lleva arma, "Peleas sin arma"
## (ATQ base; sigilo-y-robo.md, #131 provisional).
static func start_messages(logic: BattleLogic) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if logic.is_group():
		var texts: Dictionary = texts_for(logic)
		out.append({ "text": Texts.get_text("battle_group_start") % [str(texts.group_name), logic.enemies.size()] })
	else:
		out.append({ "text": TEXT_START % logic.unico_name })
	for ally: Dictionary in logic.allies:
		out.append({ "text": Texts.get_text("battle_ally_joins") % str(ally.name) })
	if logic.unarmed:
		out.append({ "text": Texts.get_text("battle_unarmed") })
	return out


## Textos propios del rival, ya leídos de data/text/sistema.json (ver messages_for). Un combate
## fatal cambia el mensaje de derrota por el de game over. Lleva además los nombres de los actores
## (enemy_names, ally_names), el nombre del grupo (group_name) y si es un grupo (is_group).
static func texts_for(logic: BattleLogic) -> Dictionary:
	var out: Dictionary = {}
	for key: String in logic.unico_texts:
		out[key] = Texts.get_text(str(logic.unico_texts[key]))
	if logic.fatal:
		out.defeat = Texts.get_text("defeat_fatal_game_over") % logic.unico_name
	out.enemy_names = logic.enemies.map(func(e: Dictionary) -> String: return str(e.name))
	out.ally_names = logic.allies.map(func(a: Dictionary) -> String: return str(a.name))
	out.group_name = str(out.get("plural", logic.unico_name))
	out.is_group = logic.is_group()
	out.luz_max = logic.luz_max
	return out


## Mensajes de un turno, uno por evento y en orden, con el estado que muestran las barras.
## `texts`: textos propios del rival (attack, warning, special, special_defended, defeat; en un
## grupo, group y plural) que sustituyen a los genéricos, y los nombres de texts_for. Pura: la usan
## la escena y los tests.
static func messages_for(events: Array[Dictionary], balance: Dictionary, texts: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var enemy_names: Array = texts.get("enemy_names", [])
	var ally_names: Array = texts.get("ally_names", [])
	var group: bool = bool(texts.get("is_group", false))
	var group_name: String = str(texts.get("group_name", ""))
	for e: Dictionary in events:
		var m: Dictionary = { "unico_hp": e.unico_hp, "adoc_hp": e.adoc_hp, "luz": e.luz }
		if e.has("enemy_hp"):
			m.enemy_hp = e.enemy_hp
			m.ally_hp = e.ally_hp
		var actor: int = int(e.get("actor", 0))
		var target: int = int(e.get("target", BattleLogic.TARGET_ADOC))
		match e.kind:
			&"attack":
				if group and target >= 0 and target < enemy_names.size():
					m.text = Texts.get_text("battle_attack_target") % [enemy_names[target], e.amount]
					m.flash = &"enemy"
					m.index = target
				else:
					m.text = TEXT_ATTACK % e.amount
					m.flash = &"unico"
				if e.get("strong", false):
					m.text = Texts.get_text("battle_strong_hit") + " " + m.text
				if e.get("hasten", false):
					m.text = Texts.get_text("battle_hasten") + " " + m.text
				if e.get("wait", false):
					m.text = Texts.get_text("battle_wait") + " " + m.text
			&"ally_attack":
				m.text = Texts.get_text("battle_ally_attack") % [_name(ally_names, actor), _name(enemy_names, target), e.amount]
				m.flash = &"enemy" if group else &"unico"
				m.index = target
				if e.get("finish", false):
					m.text = Texts.get_text("battle_finish") + " " + m.text
			&"switch_row":
				var back: bool = int(e.get("row", BattleLogic.FRONT)) == BattleLogic.BACK
				if actor == BattleLogic.TARGET_ADOC:
					m.text = Texts.get_text("battle_row_back_adoc" if back else "battle_row_front_adoc")
				else:
					m.text = Texts.get_text("battle_row_back_ally" if back else "battle_row_front_ally") % _name(ally_names, actor)
				m.relayout = true
			&"ally_defend":
				m.text = Texts.get_text("battle_ally_defend") % _name(ally_names, actor)
			&"cover":
				if target == BattleLogic.TARGET_ADOC:
					m.text = Texts.get_text("battle_cover_adoc") % _name(ally_names, actor)
				else:
					m.text = Texts.get_text("battle_cover") % [_name(ally_names, actor), _name(ally_names, target)]
			&"bandage":
				if target == BattleLogic.TARGET_ADOC:
					m.text = Texts.get_text("battle_bandage_adoc") % [_name(ally_names, actor), e.amount]
				elif target == actor:
					m.text = Texts.get_text("battle_bandage_self") % [_name(ally_names, actor), e.amount]
				else:
					m.text = Texts.get_text("battle_bandage") % [_name(ally_names, actor), _name(ally_names, target), e.amount]
			&"cheer":
				if target == BattleLogic.TARGET_ADOC:
					m.text = Texts.get_text("battle_cheer_adoc") % [_name(ally_names, actor), e.amount]
				else:
					m.text = Texts.get_text("battle_cheer") % [_name(ally_names, actor), _name(ally_names, target), e.amount]
			&"enemy_flees", &"enemy_retreats":
				m.text = Texts.get_text("battle_" + String(e.kind)) % _name(enemy_names, actor)
				m.flash = &"down"
				m.index = actor
			&"enemy_cover":
				m.text = Texts.get_text("battle_enemy_cover") % [_name(enemy_names, actor), _name(enemy_names, target)]
			&"enemy_bandage":
				m.text = Texts.get_text("battle_enemy_bandage") % [_name(enemy_names, actor), _name(enemy_names, target), e.amount]
			&"enemy_down":
				m.text = Texts.get_text("battle_enemy_down") % _name(enemy_names, target)
				m.flash = &"down"
				m.index = target
			&"group_attack":
				var one: bool = int(e.get("attackers", 2)) == 1
				var alone: String = _first_alive(e, enemy_names)
				if target >= 0:
					if one:
						m.text = Texts.get_text("battle_enemy_attack_ally") % [alone, _name(ally_names, target), e.amount]
					else:
						m.text = Texts.get_text("battle_group_attack_ally") % [group_name, _name(ally_names, target), e.amount]
					m.flash = &"ally"
					m.index = target
				else:
					if e.get("defended", false):
						m.text = Texts.get_text("battle_group_attack_defended") % [group_name, e.amount]
					elif one:
						m.text = str(texts.get("attack", Texts.get_text("battle_enemy_attack"))) % [alone, e.amount]
					else:
						m.text = str(texts.get("group", Texts.get_text("reparep_group_attack"))) % [group_name, e.amount]
					m.flash = &"adoc"
			&"ally_retires":
				m.text = Texts.get_text("battle_ally_retires") % _name(ally_names, actor)
				m.flash = &"retire"
				m.index = actor
			&"defend":
				m.text = TEXT_DEFEND
			&"offer_luz":
				m.text = Texts.get_text("battle_offer_luz_paid") % e.amount
			&"flee_fail":
				m.text = TEXT_FLEE_FAIL
			&"flee_ok":
				m.text = TEXT_FLEE_OK
			&"unico_attack":
				if target >= 0:
					m.text = Texts.get_text("battle_enemy_attack_ally") % [_name(enemy_names, actor), _name(ally_names, target), e.amount]
					m.flash = &"ally"
					m.index = target
				elif group:
					m.text = Texts.get_text("battle_enemy_attack") % [_name(enemy_names, actor), e.amount]
					m.flash = &"adoc"
				else:
					m.text = str(texts.get("attack", TEXT_UNICO_ATTACK)) % e.amount
					m.flash = &"adoc"
			&"unico_special":
				var key: String = "special_defended" if e.get("defended", false) else "special"
				m.text = str(texts.get(key, TEXT_UNICO_ATTACK)) % e.amount
				m.flash = &"adoc"
				if target >= 0:
					m.text = Texts.get_text("battle_enemy_attack_ally") % [_name(enemy_names, actor), _name(ally_names, target), e.amount]
					m.flash = &"ally"
					m.index = target
			&"special_warning":
				m.text = str(texts.get("warning", TEXT_SPECIAL_WARNING))
			&"victory":
				# La Luz suelta tiene tope: con la Luz al máximo no se anuncia el +1.
				var gained: int = mini(int(balance.victory_luz), int(texts.get("luz_max", balance.adoc.luz_max)) - int(e.luz))
				var victory_text: String = Texts.get_text("battle_group_victory") if group else TEXT_VICTORY
				m.text = victory_text + (TEXT_VICTORY_LUZ % gained if gained > 0 else "")
				m.luz = int(e.luz) + maxi(0, gained)
				m.flash = &"vanish"
				out.append(m)
				# Después de la victoria: la XP y un mensaje por nivel nuevo (sin tocar las barras).
				if int(e.get("xp", 0)) > 0:
					out.append({ "text": Texts.get_text("xp_gained") % int(e.xp) })
				for level: Variant in e.get("level_ups", []):
					out.append({ "text": Texts.get_text("level_up") % int(level) })
				if not (e.get("level_ups", []) as Array).is_empty():
					out.append({ "text": Texts.get_text("growth_points_hint") })
				if str(e.get("loot", "")) != "":
					out.append({ "text": Texts.get_text("battle_loot") % Ofrendas.display_name(StringName(str(e.loot))) })
				continue
			&"ofrenda":
				m.text = Texts.get_text("battle_ofrenda_used") % Ofrendas.display_name(StringName(str(e.get("id", ""))))
			&"unico_leaves":
				m.text = Texts.get_text("battle_group_leave") if group else Texts.get_text("battle_ofrenda_unico_leaves")
				m.flash = &"vanish"
			&"defeat":
				m.text = str(texts.get("defeat", TEXT_DEFEAT))
		if e.has("covered"):
			_cover_text(m, e, enemy_names, ally_names)
		out.append(m)
	return out


## Golpe que se lleva un defensor (Cubrir): el del jugador o un aliado contra un enemigo cubierto, o
## el de un enemigo contra alguien del bando del jugador.
static func _cover_text(m: Dictionary, e: Dictionary, enemy_names: Array, ally_names: Array) -> void:
	var covered: int = int(e.covered)
	var target: int = int(e.get("target", BattleLogic.TARGET_ADOC))
	if e.kind == &"attack" or e.kind == &"ally_attack":
		m.text = Texts.get_text("battle_enemy_covered") % [_name(enemy_names, target), _name(enemy_names, covered), e.amount]
		return
	if covered == BattleLogic.TARGET_ADOC:
		m.text = Texts.get_text("battle_covered_hit_adoc") % [_name(ally_names, target), e.amount]
	else:
		m.text = Texts.get_text("battle_covered_hit") % [_name(ally_names, target), _name(ally_names, covered), e.amount]
	m.flash = &"ally"
	m.index = target


static func _name(names: Array, index: int) -> String:
	return str(names[index]) if index >= 0 and index < names.size() else ""


## Nombre del primer enemigo que sigue en pie según el estado del evento (el que ataca solo).
static func _first_alive(e: Dictionary, names: Array) -> String:
	var hp: Array = e.get("enemy_hp", [])
	for i: int in hp.size():
		if int(hp[i]) > 0:
			return _name(names, i)
	return _name(names, 0)


func _unhandled_input(event: InputEvent) -> void:
	if _logic == null or event is InputEventMouseMotion:
		return
	get_viewport().set_input_as_handled()
	if _menu_box.visible:
		if _in_submenu:
			_handle_submenu(_menu.handle(event))
			return
		if _in_target_menu:
			_handle_target_menu(_menu.handle(event))
			return
		if _in_order_menu:
			_handle_order_menu(_menu.handle(event))
			return
		if _in_tactics:
			_handle_tactics(_menu.handle(event))
			return
		var choice: int = _menu.handle(event)
		var blocked: String = blocked_text(_logic, MENU_ACTIONS[_menu.index]) if choice == OptionMenu.DISABLED else ""
		if blocked != "":
			_show_messages([{ "text": blocked }])
		elif choice == TACTICS_OPTION:
			_open_tactics()
		elif choice >= 0 and MENU_ACTIONS[choice] == BattleLogic.Action.OFRENDA:
			_open_submenu()
		elif choice >= 0 and MENU_ACTIONS[choice] == BattleLogic.Action.ATTACK and _logic.alive_enemies().size() > 1:
			_pending_action = BattleLogic.Action.ATTACK
			_open_target_menu()
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
	texts[TACTICS_OPTION] = Texts.get_text("battle_menu_tactics")
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


## Submenú de táctica: [{ text, enabled, choice }] (choice: una BattleLogic.Action, TACTIC_ORDER o
## TACTIC_BACK). Defender, Apresurar y Esperar siempre; cambiar de fila solo con formación (si no,
## en gris); la orden al grupo solo con aliados (en gris si ya se dio en esta ronda).
static func tactics_entries(logic: BattleLogic) -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{ "text": Texts.get_text("battle_tactic_defend"), "enabled": true, "choice": BattleLogic.Action.DEFEND },
		{ "text": Texts.get_text("battle_tactic_hasten"), "enabled": true, "choice": BattleLogic.Action.HASTEN },
		{ "text": Texts.get_text("battle_tactic_wait"), "enabled": true, "choice": BattleLogic.Action.WAIT },
		{ "text": Texts.get_text("battle_tactic_row_front" if logic.adoc_row == BattleLogic.BACK else "battle_tactic_row_back"),
			"enabled": logic.can_switch_row(), "choice": BattleLogic.Action.SWITCH_ROW },
	]
	if not logic.allies.is_empty():
		out.append({ "text": Texts.get_text("battle_tactic_order") % order_name(logic.group_order),
			"enabled": logic.can_change_order(), "choice": TACTIC_ORDER })
	out.append({ "text": TEXT_BACK, "enabled": true, "choice": TACTIC_BACK })
	return out


## Nombre visible de una orden al grupo.
static func order_name(order: BattleLogic.GroupOrder) -> String:
	match order:
		BattleLogic.GroupOrder.ATTACK:
			return Texts.get_text("battle_order_attack")
		BattleLogic.GroupOrder.DEFEND:
			return Texts.get_text("battle_order_defend")
	return Texts.get_text("battle_order_free")


## Abre un submenú con `lines` opciones: la caja crece hacia arriba para que quepan.
func _grow_menu(lines: int) -> void:
	_menu_box.offset_top = minf(_menu_top, _menu_box.offset_bottom - lines * MENU_LINE - 4.0)
	_menu.offset_bottom = _menu_box.offset_bottom - _menu_box.offset_top - 1.0


func _restore_menu_size() -> void:
	_menu_box.offset_top = _menu_top
	_menu.offset_bottom = _menu_box.offset_bottom - _menu_box.offset_top - 1.0


func _open_tactics() -> void:
	var entries: Array[Dictionary] = tactics_entries(_logic)
	var texts: Array[String] = []
	var enabled: Array[bool] = []
	_tactic_choices = []
	for entry: Dictionary in entries:
		texts.append(str(entry.text))
		enabled.append(bool(entry.enabled))
		_tactic_choices.append(int(entry.choice))
	_in_tactics = true
	_grow_menu(texts.size())
	_menu.set_options(texts, enabled)


func _close_tactics() -> void:
	_in_tactics = false
	_restore_menu_size()


func _handle_tactics(choice: int) -> void:
	if choice == OptionMenu.DISABLED:
		var what: int = _tactic_choices[_menu.index]
		var why: String = Texts.get_text("battle_order_once") if what == TACTIC_ORDER else Texts.get_text("battle_row_solo")
		_close_tactics()
		_show_messages([{ "text": why }])
		return
	if choice == OptionMenu.CANCEL or (choice >= 0 and _tactic_choices[choice] == TACTIC_BACK):
		_close_tactics()
		_open_menu()
		return
	if choice < 0:
		return
	var what: int = _tactic_choices[choice]
	_close_tactics()
	if what == TACTIC_ORDER:
		_open_order_menu()
		return
	var action: BattleLogic.Action = what as BattleLogic.Action
	if (action == BattleLogic.Action.HASTEN or action == BattleLogic.Action.WAIT) and _logic.alive_enemies().size() > 1:
		_pending_action = action
		_open_target_menu()
		return
	_play(_logic.play_turn(action))


## Órdenes al grupo: Libre, Atacar, Defender (el cursor en la actual). No gasta turno.
func _open_order_menu() -> void:
	var texts: Array[String] = [order_name(BattleLogic.GroupOrder.FREE), order_name(BattleLogic.GroupOrder.ATTACK),
		order_name(BattleLogic.GroupOrder.DEFEND), TEXT_BACK]
	var enabled: Array[bool] = [true, true, true, true]
	_in_order_menu = true
	_grow_menu(texts.size())
	_menu.index = int(_logic.group_order)
	_menu.set_options(texts, enabled, true)


func _handle_order_menu(choice: int) -> void:
	if choice == OptionMenu.NONE:
		return
	_in_order_menu = false
	_restore_menu_size()
	if choice < 0 or choice == 3:
		_open_tactics()
		return
	var order: BattleLogic.GroupOrder = choice as BattleLogic.GroupOrder
	if _logic.set_group_order(order):
		_show_messages([{ "text": Texts.get_text("battle_order_set") % order_name(order) }])
	else:
		_show_messages([{ "text": Texts.get_text("battle_order_once") }])


## Opciones del submenú de objetivo: un enemigo vivo por línea, con sus PV.
static func target_options(logic: BattleLogic, choices: Array[int]) -> Array[String]:
	var out: Array[String] = []
	for i: int in choices:
		out.append(Texts.get_text("battle_target_option") % [str(logic.enemies[i].name), int(logic.enemies[i].hp)])
	return out


## Submenú de objetivo: los enemigos vivos, con el cursor en el de menos PV.
func _open_target_menu() -> void:
	_target_choices = _logic.alive_enemies()
	var texts: Array[String] = target_options(_logic, _target_choices)
	texts.append(TEXT_BACK)
	var enabled: Array[bool] = []
	for t: String in texts:
		enabled.append(true)
	_in_target_menu = true
	_text_box.show_static(Texts.get_text("battle_target_prompt"))
	_menu_box.offset_left = TARGET_MENU_LEFT
	_menu.offset_right = _options_right + _menu_left - TARGET_MENU_LEFT
	_menu.index = maxi(0, _target_choices.find(_logic.default_target()))
	_menu.set_options(texts, enabled, true)
	_update_cursor()


func _close_target_menu() -> void:
	_in_target_menu = false
	_cursor.visible = false
	_menu_box.offset_left = _menu_left
	_menu.offset_right = _options_right


func _handle_target_menu(choice: int) -> void:
	if choice == OptionMenu.CANCEL or choice == _target_choices.size():
		_close_target_menu()
		_open_menu()
	elif choice >= 0:
		_close_target_menu()
		_play(_logic.play_turn(_pending_action, _target_choices[choice]))
	else:
		_update_cursor()


## Flecha sobre el enemigo marcado en el submenú de objetivo.
func _update_cursor() -> void:
	if _cursor == null:
		return
	var i: int = _menu.index
	_cursor.visible = i < _target_choices.size()
	if _cursor.visible:
		var sprite: TextureRect = _enemy_sprites[_target_choices[i]]
		_cursor.position = Vector2(sprite.position.x + ENEMY_PX / 2.0 - 3.0, enemy_spots(_logic)[_target_choices[i]].y - 12.0)


func _show_messages(messages: Array[Dictionary]) -> void:
	_menu_box.visible = false
	_text_box.show_lines(messages)


## Al mostrarse cada mensaje: barras y destellos con el estado que trae.
func _on_message_started(m: Dictionary) -> void:
	if m.has("unico_hp"):
		_set_bars(m, true)
	if m.get("relayout", false):
		_layout_player()
	match m.get("flash", &""):
		&"unico":
			_flash(_unico)
			Sfx.play(&"hit")
		&"adoc":
			_flash(_adoc)
			# El Ofomni ataca con látigos (monstruos.md).
			Sfx.play(&"whip" if _kind == UnicoArt.Kind.EYES else &"hit")
		&"vanish":
			if _logic.is_group():
				for sprite: TextureRect in _enemy_sprites:
					create_tween().tween_property(sprite, "modulate:a", 0.0, 0.8)
			else:
				create_tween().tween_property(_unico, "modulate:a", 0.0, 0.8)
		&"enemy":
			if int(m.index) < _enemy_sprites.size():
				_flash(_enemy_sprites[int(m.index)])
			Sfx.play(&"hit")
		&"down":
			if int(m.index) < _enemy_sprites.size():
				create_tween().tween_property(_enemy_sprites[int(m.index)], "modulate:a", 0.0, 0.6)
		&"ally":
			if int(m.index) < _ally_sprites.size():
				_flash(_ally_sprites[int(m.index)])
			Sfx.play(&"hit")
		&"retire":
			if int(m.index) < _ally_sprites.size():
				create_tween().tween_property(_ally_sprites[int(m.index)], "modulate", Color(0.5, 0.5, 0.5, 0.35), 0.5)


## Sin mensajes pendientes: abre el menú o, si el combate acabó, lo cierra.
func _on_messages_finished() -> void:
	if _logic.is_over():
		finished.emit(_logic)
	else:
		_open_menu()


func _open_menu() -> void:
	_text_box.show_static(TEXT_PROMPT)
	_draw_order()
	var enabled: Array[bool] = [true, true, _logic.can_offer_luz(), _logic.can_offer_ofrenda(), true]
	_menu.set_options(menu_options(_logic), enabled, true)
	_menu_box.visible = true


## Barras y cifras con el estado de un mensaje. `animate`: las barras bajan (o suben) con un tween.
## En un grupo, la caja de arriba cuenta los que quedan y su barra es la suma de sus PV.
func _set_bars(state: Dictionary, animate: bool) -> void:
	var l: BattleLogic = _logic
	_set_mini_bars(state, animate)
	_adoc_stats.text = "Adoc   PV %d/%d   Luz %d/%d" % [state.adoc_hp, l.adoc_max_hp, state.luz, l.luz_max]
	_tween_bar(_adoc_bar, roundf(BAR_WIDTH * int(state.adoc_hp) / l.adoc_max_hp), animate)
	if not l.is_group():
		_unico_hp.text = "PV %d/%d" % [state.unico_hp, l.unico_max_hp]
		_tween_bar(_unico_bar, roundf(BAR_WIDTH * int(state.unico_hp) / l.unico_max_hp), animate)
		return
	var hp: Array = state.get("enemy_hp", [])
	var alive: int = 0
	var total: int = 0
	var total_max: int = 0
	for i: int in l.enemies.size():
		var v: int = int(hp[i]) if i < hp.size() else 0
		alive += 1 if v > 0 else 0
		total += v
		total_max += int(l.enemies[i].max_hp)
	_unico_hp.text = "%d/%d" % [alive, l.enemies.size()]
	_tween_bar(_unico_bar, roundf(BAR_WIDTH * total / maxi(1, total_max)), animate)


## Barras pequeñas de la fila de enemigos y de los aliados.
func _set_mini_bars(state: Dictionary, animate: bool) -> void:
	var hp: Array = state.get("enemy_hp", [])
	for i: int in mini(hp.size(), _enemy_bars.size()):
		_tween_bar(_enemy_bars[i], roundf(MINI_BAR_WIDTH * int(hp[i]) / maxi(1, int(_logic.enemies[i].max_hp))), animate)
	var ally_hp: Array = state.get("ally_hp", [])
	for i: int in mini(ally_hp.size(), _ally_bars.size()):
		_tween_bar(_ally_bars[i], roundf(MINI_BAR_WIDTH * int(ally_hp[i]) / maxi(1, int(_logic.allies[i].max_hp))), animate)


func _tween_bar(bar: ColorRect, width: float, animate: bool) -> void:
	if animate and bar.size.x != width:
		create_tween().tween_property(bar, "size:x", width, BAR_TIME)
	else:
		bar.size.x = width


func _flash(node: CanvasItem) -> void:
	var t := create_tween()
	for i: int in 2:
		t.tween_property(node, "modulate", Color(1, 1, 1, 0.2), 0.06)
		t.tween_property(node, "modulate", Color(1, 1, 1, 1), 0.06)
