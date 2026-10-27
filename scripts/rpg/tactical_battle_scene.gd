class_name TacticalBattleScene
extends CanvasLayer
## Escena del combate táctico (combate-tactico.md, ADR 0016; PR T4): dibuja un TacticalBattle y
## lleva el turno del jugador con TacticalTurnFlow. Misma entrada y salida que la escena por menú
## (battle.gd): begin(logic, style, kind, ally_clothes) y, al acabar, `finished(logic)` con el
## BattleLogic ya actualizado (TacticalBridge.apply_to_logic); Crossing aplica el resultado. Solo se
## abre con tactical.enabled en balance.json (o desde las escenas de demo).
## - Tablero de cualquier tamaño (lo lee de TacticalBoard): casillas de 16 px, vista cenital con las
##   alturas por capas (cada nivel sube 4 px, con su cara más oscura hacia abajo y un borde en los
##   desniveles laterales), tono por nivel, agua, vados, escaleras y obstáculos. Si no cabe en la
##   vista, la cámara sigue con suavidad al cursor o a la unidad activa.
## - Unidades: el adoc con su sprite de 4 direcciones; los monstruos con su sprite y un indicador de
##   orientación. Barra de PV pequeña encima.
## - Arriba, la línea de orden de los próximos turnos (iconos; el primero, enmarcado).
## - Números de daño flotando ("Falla" si esquiva) y una línea corta con el nombre de la acción.
## - Turnos de la IA (T5): los enemigos siempre con TacticalAI; los aliados, cuando el jugador elige
##   Auto en su menú. Quien huye o se retira por el borde se desvanece.
## - Party y refuerzos (T1b): antes del combate, si la party no cabe en el cupo (board.max_per_side)
##   y no es una emboscada, abre TacticalPartyScreen (preseleccionada con GameState.last_party, que
##   guarda al confirmar: TacticalParty.save_choice). Quien no entra espera en su borde: la línea de
##   orden lo muestra a la derecha, apagado, tras la marca "Espera"; al entrar como refuerzo aparece
##   en su casilla con la línea corta "Refuerzo".
## - Especiales (T6): las casillas de un área anunciada (Latigazo múltiple) se marcan en naranja
##   hasta que golpea, con la línea corta del aviso al anunciarla; el golpe enseña el daño sobre cada
##   uno de los que seguían dentro. El ataque conjunto de los reparep, con su línea corta.
## - Apertura (T6): con sorpresa o emboscada (begin: `surprise`, `ambush`), la línea corta
##   "¡Sorpresa!" o "¡Emboscada!" se queda OPENING_TIME antes del primer turno.
## Solo toca GameState para guardar la party elegida.

signal finished(logic: BattleLogic)

## Vista del tablero (recorte) dentro de la pantalla y margen de la cámara.
const CAMERA_MARGIN: float = 24.0
const CAMERA_SPEED: float = 10.0
## Iconos de la línea de orden: cuántos, tamaño y paso.
const ORDER_COUNT: int = 12
const ORDER_ICON: float = 12.0
const ORDER_STEP: float = 13.0
## Separación y opacidad de los que esperan en la línea de orden (T1b).
const WAITING_GAP: float = 6.0
const WAITING_ALPHA: float = 0.45
const PARTY_SCENE: PackedScene = preload("res://scenes/rpg/tactical_party_screen.tscn")
## Tiempos de animación (segundos).
const STEP_TIME: float = 0.09
const FLOAT_TIME: float = 0.8
const ACTION_LINE_TIME: float = 0.9
const AI_THINK_TIME: float = 0.3
## Lo que dura la línea de la apertura (sorpresa o emboscada) antes del primer turno.
const OPENING_TIME: float = 1.4
## Barra de PV de cada unidad.
const BAR_W: float = 12.0
const BAR_H: float = 2.0
## z de las barras sobre la de su unidad (fila 0..n): por encima de todas, bajo la superposición (50).
const BAR_Z: int = 30
const LEVEL_PX: int = TacticalTurnFlow.LEVEL_PX
const TILE: int = TacticalTurnFlow.TILE_PX
const COLOR_MOVE := Color(0.0, 0.6, 0.86, 0.45)
const COLOR_TARGET := Color(0.89, 0.23, 0.27, 0.5)
const COLOR_SUPPORT := Color(0.39, 0.78, 0.3, 0.5)
const COLOR_CURSOR := Color("fee761")
const COLOR_PLAYER := Color("63c74d")
const COLOR_ENEMY := Color("e43b44")
const COLOR_BAR_BACK := Color("262b44")
const COLOR_OUTLINE := Color("181425")
const COLOR_WATER := Color("0099db")
const COLOR_WATER_LIGHT := Color("2ce8f5")
const COLOR_SAND := Color("ead4aa")
const COLOR_ROCK := Color("8b9bb4")
const COLOR_ROCK_DARK := Color("5a6988")
const COLOR_BLOCKED := Color("3a4466")
const COLOR_MISS := Color("fee761")
const COLOR_HEAL := Color("63c74d")
## Casillas de un área anunciada (relleno y borde).
const COLOR_DANGER := Color(0.97, 0.46, 0.13, 0.5)
const COLOR_DANGER_EDGE := Color("feae34")
## Orientación -> fila de la hoja del Adoc.
const FACING_DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var logic: BattleLogic
var battle: TacticalBattle
var flow: TacticalTurnFlow
var _style: Dictionary = {}
var _kind: UnicoArt.Kind = UnicoArt.Kind.BOTARRAMAS
var _ally_clothes: Array = []
## Por unidad: { node, sprite, bar, textures (4 o 1), name, foot_dy }.
var _views: Array[Dictionary] = []
var _busy: bool = false
var _ended: bool = false
var _cam := Vector2.ZERO
var _cam_ready: bool = false
## Celda que sigue la cámara cuando no hay cursor (unidad que se mueve).
var _follow: Vector2i = Vector2i(-1, -1)
## Entradas del menú abierto (ids de TacticalTurnFlow o índices de ofrenda).
var _menu_ids: Array = []
## Paso de elección de party abierto (T1b), o null.
var party_screen: TacticalPartyScreen
var _cfg: Dictionary = {}
var _board_override: TacticalBoard
var _opening: TacticalBattle.Opening = TacticalBattle.Opening.NORMAL

@onready var _clip: Control = $Root/BoardClip
@onready var _board: Node2D = $Root/BoardClip/Board
@onready var _tiles: Node2D = $Root/BoardClip/Board/Tiles
@onready var _units: Node2D = $Root/BoardClip/Board/Units
@onready var _overlay: Node2D = $Root/BoardClip/Board/Overlay
@onready var _floaters: Node2D = $Root/BoardClip/Board/Floaters
@onready var _order_line: Control = $Root/OrderLine
@onready var _action_box: Panel = $Root/ActionBox
@onready var _action_label: Label = $Root/ActionBox/Text
@onready var _menu_box: Panel = $Root/MenuBox
@onready var _menu: OptionMenu = $Root/MenuBox/Options
@onready var _hint: Label = $Root/MenuBox/Hint
@onready var _info: Label = $Root/InfoBox/Text
@onready var _target_info: Label = $Root/TargetBox/Text
@onready var _end_box: Panel = $Root/EndBox
@onready var _end_label: Label = $Root/EndBox/Text


func _ready() -> void:
	_menu.skip_disabled = true
	_tiles.draw.connect(_draw_tiles)
	_overlay.draw.connect(_draw_overlay)
	_action_box.visible = false
	_end_box.visible = false


## Empieza el combate desde el BattleLogic que prepara Crossing (o la demo). `cfg` y `board`
## permiten elegir el tamaño y el cupo (TacticalArena, T1b) o probar otros en la demo; por defecto,
## los de balance.json y un tablero llano. Antes, la elección de party si hace falta; en una
## emboscada del enemigo (`ambush`, T6) entra la última party guardada sin preguntar y los enemigos
## juegan primero; con `surprise` (emboscada tuya), tu bando juega primero.
func begin(battle_logic: BattleLogic, style: Dictionary, kind: UnicoArt.Kind, ally_clothes: Array = [],
		cfg: Dictionary = {}, board: TacticalBoard = null, ambush: bool = false, surprise: bool = false) -> void:
	logic = battle_logic
	_opening = TacticalBattle.Opening.AMBUSH if ambush else (TacticalBattle.Opening.SURPRISE if surprise
		else TacticalBattle.Opening.NORMAL)
	_style = style
	_kind = kind
	_ally_clothes = ally_clothes
	_cfg = cfg if not cfg.is_empty() else TacticalBattle.config_from_balance(logic.balance)
	_board_override = board
	var quota: int = int((_cfg.get("board", {}) as Dictionary).get("max_per_side", 3))
	var party: Dictionary = TacticalParty.resolve(logic.allies, quota, TacticalParty.last_choice(), ambush)
	if party.prompt:
		party_screen = PARTY_SCENE.instantiate()
		add_child(party_screen)
		party_screen.open(logic.allies, quota, party.chosen)
		party_screen.confirmed.connect(_on_party_confirmed)
		return
	_start(party.chosen)


func _on_party_confirmed(chosen: Array[int]) -> void:
	TacticalParty.save_choice(logic.allies, chosen)
	party_screen.queue_free()
	party_screen = null
	_start(chosen)


func _start(chosen: Array[int]) -> void:
	battle = TacticalBridge.build_battle(logic, _cfg, _board_override, chosen, _opening)
	flow = TacticalTurnFlow.new(battle)
	_build_units()
	_tiles.queue_redraw()
	var key: StringName = battle.opening_text_key()
	if key != &"":
		_busy = true
		_follow = battle.units[0].cell
		_refresh()
		_show_action_line(Texts.get_text(String(key)), OPENING_TIME)
		# Un tween del propio nodo: si la escena se libera antes, no sigue.
		var t := create_tween()
		t.tween_interval(OPENING_TIME)
		t.tween_callback(_after_opening)
		return
	_next_turn()


func _after_opening() -> void:
	_busy = false
	_next_turn()


# --- Unidades -----------------------------------------------------------------------------------

func _build_units() -> void:
	for i in battle.units.size():
		var u: Dictionary = battle.units[i]
		var id: StringName = u.id
		var k: int = TacticalBridge.logic_index(id)
		var textures: Array[Texture2D] = []
		var unit_name: String = Texts.get_text("tactical_adoc_name")
		if id == TacticalBridge.ADOC_ID:
			for dir: Vector2i in FACING_DIRS:
				textures.append(_adoc_texture(dir))
		elif String(id).begins_with("ally_"):
			var ally: Dictionary = logic.allies[k]
			unit_name = str(ally.name)
			if StringName(str(ally.get("kind", "adoc"))) == &"adoc":
				# La ropa va por el orden de los adoc en logic.allies (la party puede cambiar el orden).
				var adoc_index: int = _adoc_rank(k)
				var clothes: Dictionary = _ally_clothes[adoc_index] if adoc_index < _ally_clothes.size() else {}
				for dir: Vector2i in FACING_DIRS:
					textures.append(AdocNpc.frame_texture(clothes, dir))
			else:
				textures.append(monster_texture(UnicoArt.kind_for(StringName(str(ally.kind))), _style))
		else:
			unit_name = str(logic.enemies[k].name)
			textures.append(monster_texture(_kind, _style))
		var node := Node2D.new()
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = textures[0]
		var size: Vector2 = textures[0].get_size()
		sprite.offset = Vector2(-floorf(size.x / 2.0), -size.y)
		node.add_child(sprite)
		var back := ColorRect.new()
		back.color = COLOR_BAR_BACK
		back.size = Vector2(BAR_W + 2.0, BAR_H + 2.0)
		back.position = Vector2(-BAR_W / 2.0 - 1.0, 0.0)
		# Las barras, por encima de todas las unidades (y bajo el cursor).
		back.z_index = BAR_Z
		node.add_child(back)
		var bar := ColorRect.new()
		bar.color = COLOR_PLAYER if u.side == TacticalBattle.SIDE_PLAYER else COLOR_ENEMY
		bar.size = Vector2(BAR_W, BAR_H)
		bar.position = back.position + Vector2.ONE
		bar.z_index = BAR_Z
		node.add_child(bar)
		_units.add_child(node)
		_views.append({ "node": node, "sprite": sprite, "bar": bar, "back": back, "textures": textures,
			"name": unit_name, "height": size.y })
		_place_unit(i)


## Cuántos aliados adoc hay antes del aliado `k` de logic.allies.
func _adoc_rank(k: int) -> int:
	var n: int = 0
	for j: int in k:
		if StringName(str((logic.allies[j] as Dictionary).get("kind", "adoc"))) == &"adoc":
			n += 1
	return n


## El Adoc del jugador mirando hacia `dir` (fila de su hoja o el placeholder).
static func _adoc_texture(dir: Vector2i) -> Texture2D:
	if not ResourceLoader.exists(PlayerWalker.SHEET_PATH):
		return PlayerWalker._make_texture(dir)
	var sheet: Texture2D = load(PlayerWalker.SHEET_PATH)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	var size := Vector2(sheet.get_width() / PlayerWalker.SHEET_FRAMES, sheet.get_height() / PlayerWalker.SHEET_ROWS.size())
	atlas.region = Rect2(Vector2(0, size.y * PlayerWalker.SHEET_ROWS.find(dir)), size)
	return atlas


## Monstruo en el tablero: el primer fotograma de su PNG a tamaño real (recoloreado con su Bosque),
## o el placeholder de 16 px. Sin sprite de 4 direcciones: la orientación la marca un indicador.
static func monster_texture(kind: UnicoArt.Kind, style: Dictionary) -> Texture2D:
	if not UnicoArt.has_sprite(kind):
		return UnicoArt.texture(kind, style, TILE)
	var img: Image = UnicoArt.recolor((load(UnicoArt.SPRITES[kind]) as Texture2D).get_image(), style)
	var w: int = img.get_width() / UnicoArt.SPRITE_FRAMES
	return ImageTexture.create_from_image(img.get_region(Rect2i(0, 0, w, img.get_height())))


## Pies de una unidad en su casilla (centro abajo, a la altura de su nivel).
func _foot_of(cell: Vector2i) -> Vector2:
	return TacticalTurnFlow.cell_to_px(cell, battle.board.level_at(cell)) + Vector2(TILE / 2.0, TILE - 4.0)


func _place_unit(i: int) -> void:
	var u: Dictionary = battle.units[i]
	var v: Dictionary = _views[i]
	var node: Node2D = v.node
	node.visible = u.alive
	node.position = _foot_of(u.cell)
	node.z_index = int(u.cell.y)
	_update_unit(i)


func _update_unit(i: int) -> void:
	var u: Dictionary = battle.units[i]
	var v: Dictionary = _views[i]
	var textures: Array[Texture2D] = v.textures
	if textures.size() == 4:
		(v.sprite as Sprite2D).texture = textures[int(u.facing)]
	(v.bar as ColorRect).size.x = roundf(BAR_W * int(u.hp) / maxi(1, int(u.max_hp)))


# --- Turnos -------------------------------------------------------------------------------------

func _next_turn() -> void:
	if battle.is_over():
		_finish()
		return
	var i: int = battle.begin_turn()
	if i == TacticalBattle.NONE:
		_finish()
		return
	for entered: int in battle.last_entries:
		(_views[entered].node as Node2D).modulate.a = 1.0
		_place_unit(entered)
	if not battle.last_entries.is_empty():
		_show_action_line(Texts.get_text("tactical_reinforce"))
	_follow = battle.units[i].cell
	_draw_order()
	_refresh()
	if battle.units[i].side == TacticalBattle.SIDE_PLAYER:
		flow.begin_player_turn()
		_show_state()
	else:
		flow.state = TacticalTurnFlow.State.IDLE
		_show_state()
		_run_ai(i)


## Turno de la IA (enemigo, o aliado en Auto): plan de TacticalAI, mover, actuar y orientarse.
func _run_ai(i: int) -> void:
	_busy = true
	_menu_box.visible = not _ended
	_menu.visible = false
	_hint.text = _hint_text()
	await get_tree().create_timer(AI_THINK_TIME).timeout
	var plan: Dictionary = TacticalAI.plan(battle, i)
	if plan.move_to != battle.units[i].cell:
		var path: Array[Vector2i] = battle.move_active(plan.move_to)
		await _animate_path(i, path)
	var res: Dictionary = TacticalAI.apply_action(battle, plan)
	if not res.is_empty():
		await _show_result(res)
	if battle.is_over():
		_busy = false
		_finish()
		return
	TacticalAI.finish_turn(battle)
	_update_unit(i)
	if battle.last_announce == i:
		_show_action_line(Texts.get_text(String(TacticalBattle.TEXT_AREA_WARNING)))
		_refresh()
		await get_tree().create_timer(ACTION_LINE_TIME).timeout
	_busy = false
	_next_turn()


## Anima un resultado del flujo del jugador o de la IA y sigue.
func _play(res: Dictionary) -> void:
	if res.is_empty():
		_show_state()
		return
	_busy = true
	_menu_box.visible = false
	if res.get("kind", &"") == TacticalTurnFlow.KIND_MOVE:
		await _animate_path(int(res.actor), res.path)
	elif res.get("kind", &"") == TacticalTurnFlow.KIND_END:
		_update_unit(int(res.actor))
		if StringName(res.get("text_key", &"")) != &"":
			_show_action_line(Texts.get_text(String(res.text_key)))
	else:
		await _show_result(res)
	_busy = false
	if battle.is_over():
		_finish()
	elif res.get("kind", &"") == TacticalTurnFlow.KIND_END:
		_next_turn()
	else:
		_show_state()


func _animate_path(i: int, path: Array[Vector2i]) -> void:
	var node: Node2D = _views[i].node
	for k: int in range(1, path.size()):
		battle.units[i].facing = TacticalBoard.facing_toward(path[k - 1], path[k], battle.units[i].facing)
		var real_facing: int = battle.units[i].facing
		_update_unit(i)
		_follow = path[k]
		node.z_index = maxi(path[k].y, path[k - 1].y)
		var t := node.create_tween()
		t.tween_property(node, "position", _foot_of(path[k]), STEP_TIME)
		await t.finished
		battle.units[i].facing = real_facing
	_place_unit(i)
	_refresh()


## Número flotante, línea de acción, barras y caídos de un resultado de TacticalBattle.
func _show_result(res: Dictionary) -> void:
	var key: StringName = res.get("text_key", &"")
	var kind: StringName = res.get("kind", &"")
	var line_key: StringName = TacticalBattle.TEXT_ATTACK if key == TacticalBattle.TEXT_MISS else key
	if line_key != &"":
		_show_action_line(Texts.get_text(String(line_key)))
	var actor: int = int(res.get("actor", TacticalBattle.NONE))
	if actor != TacticalBattle.NONE:
		_update_unit(actor)
	if kind == TacticalBattle.KIND_ATTACK or kind == TacticalBattle.KIND_FINISH:
		var receiver: int = int(res.get("receiver", res.target))
		if res.missed:
			_float_text(int(res.target), Texts.get_text(String(TacticalBattle.TEXT_MISS)), COLOR_MISS)
			Sfx.play(&"menu_move")
		else:
			_float_text(receiver, str(int(res.damage)), Color.WHITE)
			_flash(_views[receiver].sprite)
			Sfx.play(&"hit")
		_update_unit(receiver)
		_target_info.text = _unit_text(receiver, false)
		await get_tree().create_timer(FLOAT_TIME).timeout
		if res.get("down", false):
			var node: Node2D = _views[receiver].node
			var t := node.create_tween()
			t.tween_property(node, "modulate:a", 0.0, 0.4)
			await t.finished
			_place_unit(receiver)
	elif kind == TacticalBattle.KIND_AREA:
		_refresh()
		var hits: Array = res.get("hits", [])
		if hits.is_empty():
			Sfx.play(&"menu_move")
		for h: Dictionary in hits:
			_float_text(int(h.receiver), str(int(h.damage)), Color.WHITE)
			_flash(_views[int(h.receiver)].sprite)
			_update_unit(int(h.receiver))
		if not hits.is_empty():
			Sfx.play(&"hit")
		await get_tree().create_timer(FLOAT_TIME).timeout
		for h: Dictionary in hits:
			if h.down:
				var node: Node2D = _views[int(h.receiver)].node
				var t := node.create_tween()
				t.tween_property(node, "modulate:a", 0.0, 0.4)
				await t.finished
				_place_unit(int(h.receiver))
	elif kind == TacticalBattle.KIND_LEAVE:
		var gone: Node2D = _views[int(res.target)].node
		var fade := gone.create_tween()
		fade.tween_property(gone, "modulate:a", 0.0, 0.4)
		await fade.finished
		_place_unit(int(res.target))
	elif kind == TacticalBattle.KIND_BANDAGE:
		_float_text(int(res.target), "+%d" % int(res.get("amount", 0)), COLOR_HEAL)
		_update_unit(int(res.target))
		await get_tree().create_timer(FLOAT_TIME).timeout
	else:
		await get_tree().create_timer(ACTION_LINE_TIME * 0.6).timeout
	_refresh()


func _float_text(i: int, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(40.0, 10.0)
	var head: Vector2 = _foot_of(battle.units[i].cell) - Vector2(20.0, float(_views[i].height) + 6.0)
	label.position = head
	label.z_index = 100
	_floaters.add_child(label)
	var t := label.create_tween()
	t.tween_property(label, "position:y", head.y - 10.0, FLOAT_TIME)
	t.parallel().tween_property(label, "modulate:a", 0.0, FLOAT_TIME).set_delay(FLOAT_TIME * 0.5)
	t.tween_callback(label.queue_free)


func _show_action_line(text: String, time: float = ACTION_LINE_TIME) -> void:
	_action_label.text = text
	_action_box.visible = true
	var t := _action_box.create_tween()
	t.tween_interval(time)
	t.tween_callback(func() -> void: _action_box.visible = false)


func _flash(node: CanvasItem) -> void:
	var t := node.create_tween()
	for k: int in 2:
		t.tween_property(node, "modulate", Color(1, 1, 1, 0.2), 0.06)
		t.tween_property(node, "modulate", Color(1, 1, 1, 1), 0.06)


func _finish() -> void:
	if _ended:
		return
	_ended = true
	flow.state = TacticalTurnFlow.State.OVER
	TacticalBridge.apply_to_logic(battle, logic)
	_menu_box.visible = false
	_end_label.text = "\n".join(TacticalBridge.end_lines(logic))
	_end_box.visible = true
	_refresh()


# --- Entrada ------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if battle == null or event is InputEventMouseMotion or not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	if _ended:
		if TacticalTurnFlow.is_accept(event) or TacticalTurnFlow.is_cancel(event):
			finished.emit(logic)
		return
	if _busy:
		return
	handle_input(event)


## Entrada en el turno del jugador (también para las capturas y los tests de la escena).
func handle_input(event: InputEvent) -> void:
	match flow.state:
		TacticalTurnFlow.State.MENU, TacticalTurnFlow.State.ACT, TacticalTurnFlow.State.OFRENDA:
			var choice: int = _menu_choice(event)
			if choice == OptionMenu.CANCEL:
				flow.cancel()
				_show_state()
			elif choice >= 0:
				_choose(choice)
		TacticalTurnFlow.State.MOVE, TacticalTurnFlow.State.TARGET, TacticalTurnFlow.State.FACING:
			if TacticalTurnFlow.is_accept(event):
				_play(flow.confirm())
			elif TacticalTurnFlow.is_cancel(event):
				flow.cancel()
				_show_state()
			elif flow.move_cursor(TacticalTurnFlow.dir_from_event(event)):
				Sfx.play(&"menu_move")
				if flow.state == TacticalTurnFlow.State.FACING:
					battle.units[battle.active].facing = flow.facing
					_update_unit(battle.active)
				_refresh()


## Opción del menú: E también acepta (OptionMenu solo mira ui_accept).
func _menu_choice(event: InputEvent) -> int:
	if event.is_action_pressed(&"interact") and not event.is_action_pressed(&"ui_accept"):
		return _menu.index if _menu_ids.size() > _menu.index else OptionMenu.NONE
	return _menu.handle(event)


func _choose(choice: int) -> void:
	var id: Variant = _menu_ids[choice]
	match flow.state:
		TacticalTurnFlow.State.MENU:
			flow.choose_main(id)
			if flow.state == TacticalTurnFlow.State.IDLE:
				_run_ai(battle.active)
				return
			if flow.state == TacticalTurnFlow.State.FACING:
				flow.facing = battle.units[battle.active].facing
			_show_state(id == TacticalTurnFlow.MAIN_ORDER)
		TacticalTurnFlow.State.ACT:
			var res: Dictionary = flow.choose_act(id)
			if res.is_empty():
				_show_state()
			else:
				_play(res)
		TacticalTurnFlow.State.OFRENDA:
			if int(id) < 0:
				flow.cancel()
				_show_state()
			else:
				_play(flow.choose_ofrenda(int(id)))


# --- Interfaz -----------------------------------------------------------------------------------

## Menú o ayuda según el paso del turno.
func _show_state(keep_cursor: bool = false) -> void:
	var texts: Array[String] = []
	var enabled: Array[bool] = []
	_menu_ids = []
	match flow.state:
		TacticalTurnFlow.State.MENU:
			_fill(flow.main_entries(), texts, enabled)
		TacticalTurnFlow.State.ACT:
			_fill(flow.act_entries(), texts, enabled)
		TacticalTurnFlow.State.OFRENDA:
			for idx: int in flow.ofrenda_choices():
				var item: Dictionary = battle.ofrendas[idx]
				texts.append(ofrenda_text(item))
				enabled.append(true)
				_menu_ids.append(idx)
			texts.append(Texts.get_text("tactical_back"))
			enabled.append(true)
			_menu_ids.append(-1)
	var has_menu: bool = not texts.is_empty()
	_menu_box.visible = not _ended
	_menu.visible = has_menu
	if has_menu:
		_menu.set_options(texts, enabled, keep_cursor)
	_hint.text = _hint_text()
	_refresh()


## Texto de una ofrenda en el submenú: nombre y valor.
static func ofrenda_text(item: Dictionary) -> String:
	return "%s (%d)" % [Ofrendas.display_name(StringName(str(item.id))), int(item.luz)]


func _fill(entries: Array[Dictionary], texts: Array[String], enabled: Array[bool]) -> void:
	for e: Dictionary in entries:
		texts.append(str(e.text))
		enabled.append(bool(e.enabled))
		_menu_ids.append(e.id)


func _hint_text() -> String:
	match flow.state:
		TacticalTurnFlow.State.MOVE:
			return Texts.get_text("tactical_hint_move")
		TacticalTurnFlow.State.TARGET:
			return Texts.get_text("tactical_hint_target")
		TacticalTurnFlow.State.FACING:
			return Texts.get_text("tactical_hint_facing")
		TacticalTurnFlow.State.IDLE:
			if battle.active != TacticalBattle.NONE:
				return Texts.get_text("tactical_enemy_turn") % str(_views[battle.active].name)
			return ""
	return Texts.get_text("tactical_hint_menu")


## Redibuja tablero, superposición y cajas de datos.
func _refresh() -> void:
	_tiles.queue_redraw()
	_overlay.queue_redraw()
	if battle == null:
		return
	if battle.active != TacticalBattle.NONE:
		_info.text = _unit_text(battle.active)
	var shown: int = TacticalBattle.NONE
	var preview: Dictionary = flow.cursor_preview()
	match flow.state:
		TacticalTurnFlow.State.MOVE, TacticalTurnFlow.State.TARGET:
			shown = battle.unit_at(flow.cursor)
	var text: String = ""
	if shown != TacticalBattle.NONE:
		text = _unit_text(shown, false)
		if not preview.is_empty():
			text += "\n" + Texts.get_text("tactical_hit_chance") % int(preview.hit_chance) \
				+ " " + relation_text(preview.relation)
	_target_info.text = text


func _unit_text(i: int, with_moves: bool = true) -> String:
	var u: Dictionary = battle.units[i]
	var line: String = Texts.get_text("tactical_unit_hp") % [str(_views[i].name), int(u.hp), int(u.max_hp)]
	if with_moves:
		line += "\n" + Texts.get_text("tactical_unit_moves") % [int(u.mov), int(u.jump)]
	return line


## Texto corto de por dónde llega el golpe.
static func relation_text(rel: int) -> String:
	match rel:
		TacticalRules.Relation.BACK:
			return Texts.get_text("tactical_relation_back")
		TacticalRules.Relation.FLANK:
			return Texts.get_text("tactical_relation_flank")
	return Texts.get_text("tactical_relation_front")


func _draw_order() -> void:
	for child: Node in _order_line.get_children():
		_order_line.remove_child(child)
		child.queue_free()
	var order: Array[int] = [battle.active]
	order.append_array(battle.preview_order(ORDER_COUNT - 1))
	var back := ColorRect.new()
	back.color = COLOR_BAR_BACK
	back.size = Vector2(ORDER_STEP * order.size() + 2.0, ORDER_ICON + 4.0)
	back.position = Vector2(-2.0, -1.0)
	_order_line.add_child(back)
	for k: int in order.size():
		var i: int = order[k]
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var textures: Array[Texture2D] = _views[i].textures
		icon.texture = textures[2] if textures.size() == 4 else textures[0]
		icon.size = Vector2(ORDER_ICON, ORDER_ICON)
		icon.position = Vector2(ORDER_STEP * k, 0.0)
		_order_line.add_child(icon)
		var mark := ColorRect.new()
		mark.color = COLOR_PLAYER if battle.units[i].side == TacticalBattle.SIDE_PLAYER else COLOR_ENEMY
		mark.size = Vector2(ORDER_ICON, 1.0)
		mark.position = Vector2(ORDER_STEP * k, ORDER_ICON + 1.0)
		_order_line.add_child(mark)
		if k == 0:
			mark.color = COLOR_CURSOR
			mark.size.y = 2.0
	_draw_waiting(ORDER_STEP * order.size() + WAITING_GAP, back)


## Los que esperan en el borde (T1b): tras la línea de orden, la marca "Espera" y sus iconos
## apagados (primero los del jugador), con la raya de su bando.
func _draw_waiting(x: float, back: ColorRect) -> void:
	var waiting: Array[int] = battle.waiting_units(TacticalBattle.SIDE_PLAYER)
	waiting.append_array(battle.waiting_units(TacticalBattle.SIDE_ENEMY))
	if waiting.is_empty():
		return
	var label := Label.new()
	label.text = Texts.get_text("tactical_waiting")
	label.theme_type_variation = &"HintLabel"
	label.position = Vector2(x, -1.0)
	label.size = Vector2(28.0, ORDER_ICON)
	_order_line.add_child(label)
	x += label.get_minimum_size().x + 2.0
	for k: int in waiting.size():
		var i: int = waiting[k]
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var textures: Array[Texture2D] = _views[i].textures
		icon.texture = textures[2] if textures.size() == 4 else textures[0]
		icon.size = Vector2(ORDER_ICON, ORDER_ICON)
		icon.position = Vector2(x + ORDER_STEP * k, 0.0)
		icon.modulate.a = WAITING_ALPHA
		_order_line.add_child(icon)
		var mark := ColorRect.new()
		mark.color = COLOR_PLAYER if battle.units[i].side == TacticalBattle.SIDE_PLAYER else COLOR_ENEMY
		mark.color.a = WAITING_ALPHA
		mark.size = Vector2(ORDER_ICON, 1.0)
		mark.position = Vector2(x + ORDER_STEP * k, ORDER_ICON + 1.0)
		_order_line.add_child(mark)
	back.size.x = x + ORDER_STEP * waiting.size() + 2.0


# --- Dibujo del tablero -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if battle == null:
		return
	var focus_cell: Vector2i = _follow
	match flow.state:
		TacticalTurnFlow.State.MOVE, TacticalTurnFlow.State.TARGET:
			focus_cell = flow.cursor
		_:
			if battle.active != TacticalBattle.NONE and not _busy:
				focus_cell = battle.units[battle.active].cell
	var focus: Vector2 = TacticalTurnFlow.cell_to_px(focus_cell, battle.board.level_at(focus_cell)) + Vector2(TILE, TILE) / 2.0
	var size: Vector2 = TacticalTurnFlow.board_px(battle.board.width, battle.board.height)
	var target: Vector2 = TacticalTurnFlow.camera_offset(focus, size, _clip.size, _cam, CAMERA_MARGIN)
	if not _cam_ready:
		_cam = target
		_cam_ready = true
	else:
		_cam = _cam.lerp(target, 1.0 - exp(-CAMERA_SPEED * delta))
		if _cam.distance_to(target) < 0.5:
			_cam = target
	_board.position = _cam.round()


func _ground() -> Array:
	return PlaceholderTileset.GROUNDS[int(_style.get("ground", 0)) % PlaceholderTileset.GROUNDS.size()]


## Color de la cara de arriba de una casilla según su nivel (más claro cuanto más alto).
func _top_color(level: int) -> Color:
	var g: Array = _ground()
	return (g[0] as Color).lerp(g[1] as Color, level / float(TacticalBoard.MAX_LEVEL)).lightened(0.04 * level)


func _draw_tiles() -> void:
	if battle == null:
		return
	var b: TacticalBoard = battle.board
	var marks: Dictionary = {}
	var mark_color: Color = COLOR_MOVE
	if flow.state == TacticalTurnFlow.State.TARGET:
		mark_color = COLOR_TARGET if flow.pending == TacticalTurnFlow.ACT_ATTACK else COLOR_SUPPORT
	for c: Vector2i in flow.highlight:
		marks[c] = true
	var danger: Dictionary = announced_cells()
	for y in b.height:
		for x in b.width:
			var c := Vector2i(x, y)
			var level: int = b.level_at(c)
			var top: Vector2 = TacticalTurnFlow.cell_to_px(c, level)
			var rect := Rect2(top, Vector2(TILE, TILE))
			var base: Color = _top_color(level)
			# Cara hacia abajo hasta la casilla de abajo (o hasta el nivel 0 en el último borde).
			var below: int = b.level_at(c + Vector2i.DOWN) if y + 1 < b.height else 0
			var face: int = (level - below) * LEVEL_PX if y + 1 < b.height else level * LEVEL_PX + 2
			if face > 0:
				_tiles.draw_rect(Rect2(top + Vector2(0, TILE), Vector2(TILE, face)), base.darkened(0.45))
				_tiles.draw_rect(Rect2(top + Vector2(0, TILE), Vector2(TILE, 1)), base.darkened(0.25))
			if b.is_water(c):
				base = COLOR_WATER
			elif _is_blocked(b, c):
				base = COLOR_BLOCKED
			_tiles.draw_rect(rect, base)
			# Cuadrícula suave y bordes de desnivel a los lados y arriba.
			_tiles.draw_rect(Rect2(top, Vector2(TILE, 1)), base.lightened(0.12))
			_tiles.draw_rect(Rect2(top + Vector2(0, TILE - 1), Vector2(TILE, 1)), base.darkened(0.12))
			if x > 0 and b.level_at(c + Vector2i.LEFT) < level:
				_tiles.draw_rect(Rect2(top, Vector2(1, TILE)), COLOR_OUTLINE)
			if x + 1 < b.width and b.level_at(c + Vector2i.RIGHT) < level:
				_tiles.draw_rect(Rect2(top + Vector2(TILE - 1, 0), Vector2(1, TILE)), COLOR_OUTLINE)
			if y > 0 and b.level_at(c + Vector2i.UP) > level:
				_tiles.draw_rect(Rect2(top, Vector2(TILE, 2)), base.darkened(0.3))
			_draw_cell_detail(b, c, top, base)
			if danger.has(c):
				_tiles.draw_rect(rect, COLOR_DANGER)
			if marks.has(c):
				_tiles.draw_rect(rect.grow(-1), mark_color)
				_tiles.draw_rect(rect.grow(-1), mark_color.lightened(0.4), false)


## Casillas de las áreas anunciadas (de cualquier bando): { Vector2i: quién la anunció }.
func announced_cells() -> Dictionary:
	var out: Dictionary = {}
	if battle == null:
		return out
	for i in battle.units.size():
		var u: Dictionary = battle.units[i]
		if u.alive:
			for c: Variant in u.announce:
				out[c] = i
	return out


func _is_blocked(b: TacticalBoard, c: Vector2i) -> bool:
	return not b.is_walkable(c) and not b.is_water(c) and not b.is_obstacle(c)


func _draw_cell_detail(b: TacticalBoard, c: Vector2i, top: Vector2, base: Color) -> void:
	if b.is_water(c):
		_tiles.draw_rect(Rect2(top + Vector2(3, 5), Vector2(4, 1)), COLOR_WATER_LIGHT)
		_tiles.draw_rect(Rect2(top + Vector2(9, 10), Vector2(4, 1)), COLOR_WATER_LIGHT)
		if b.is_ford(c):
			for k: int in 3:
				_tiles.draw_rect(Rect2(top + Vector2(2 + k * 5, 7), Vector2(3, 3)), COLOR_SAND)
	if b.is_stair(c):
		for k: int in 3:
			_tiles.draw_rect(Rect2(top + Vector2(3, 3 + k * 4), Vector2(10, 2)), base.darkened(0.35))
	match b.object_at(c):
		&"":
			pass
		&"tree":
			_tiles.draw_rect(Rect2(top + Vector2(7, 9), Vector2(2, 5)), Color("733e39"))
			_tiles.draw_circle(top + Vector2(8, 7), 5.0, Color("265c42"))
			_tiles.draw_circle(top + Vector2(7, 6), 3.0, Color("3e8948"))
		_:
			if b.is_obstacle(c):
				_tiles.draw_circle(top + Vector2(8, 9), 5.0, COLOR_ROCK_DARK)
				_tiles.draw_circle(top + Vector2(7, 8), 3.5, COLOR_ROCK)


## Cursor, marca del activo e indicadores de orientación.
func _draw_overlay() -> void:
	if battle == null:
		return
	for i in battle.units.size():
		var u: Dictionary = battle.units[i]
		if not u.alive:
			continue
		var foot: Vector2 = _foot_of(u.cell)
		if (_views[i].textures as Array).size() != 4 or i == battle.active:
			_draw_facing(foot, int(u.facing), i == battle.active)
	# El borde de las áreas anunciadas, por encima de las unidades (la casilla puede quedar tapada).
	for c: Variant in announced_cells():
		var cell: Vector2i = c
		var r := Rect2(TacticalTurnFlow.cell_to_px(cell, battle.board.level_at(cell)), Vector2(TILE, TILE))
		_overlay.draw_rect(r.grow(-1), COLOR_DANGER_EDGE, false)
	if battle.active != TacticalBattle.NONE and not _ended:
		var head: Vector2 = _foot_of(battle.units[battle.active].cell) - Vector2(0, float(_views[battle.active].height) + 1.0)
		_overlay.draw_colored_polygon(PackedVector2Array([head + Vector2(-3, -3), head + Vector2(3, -3), head + Vector2(0, 0)]), COLOR_CURSOR)
	match flow.state:
		TacticalTurnFlow.State.MOVE, TacticalTurnFlow.State.TARGET:
			# Los objetivos, también con un marco encima de la unidad (la casilla queda tapada).
			if flow.state == TacticalTurnFlow.State.TARGET:
				var frame: Color = COLOR_TARGET if flow.pending == TacticalTurnFlow.ACT_ATTACK else COLOR_SUPPORT
				frame.a = 1.0
				for c: Vector2i in flow.highlight:
					var r := Rect2(TacticalTurnFlow.cell_to_px(c, battle.board.level_at(c)), Vector2(TILE, TILE))
					_overlay.draw_rect(r.grow(-1), frame, false)
			var top: Vector2 = TacticalTurnFlow.cell_to_px(flow.cursor, battle.board.level_at(flow.cursor))
			_draw_corners(Rect2(top, Vector2(TILE, TILE)), COLOR_CURSOR)


## Flecha pequeña de orientación junto a los pies (más grande en el turno de elegirla).
func _draw_facing(foot: Vector2, facing: int, big: bool) -> void:
	var dir := Vector2(TacticalBoard.NEIGHBOR_DIRS[facing])
	var side := Vector2(-dir.y, dir.x)
	var center: Vector2 = foot + Vector2(0, -5) + dir * 7.0
	var s: float = 3.0 if big else 2.0
	var tip: Vector2 = center + dir * s
	var pts := PackedVector2Array([tip, center + side * s, center - side * s])
	_overlay.draw_colored_polygon(pts, COLOR_OUTLINE)
	_overlay.draw_colored_polygon(PackedVector2Array([tip - dir, center + side * (s - 1.0), center - side * (s - 1.0)]), COLOR_CURSOR)


func _draw_corners(r: Rect2, color: Color) -> void:
	var l: float = 4.0
	for corner: Vector2 in [r.position, r.position + Vector2(r.size.x, 0), r.position + Vector2(0, r.size.y), r.end]:
		var sx: float = 1.0 if corner.x == r.position.x else -1.0
		var sy: float = 1.0 if corner.y == r.position.y else -1.0
		var o: Vector2 = corner + Vector2(0 if sx > 0 else -1, 0 if sy > 0 else -1)
		_overlay.draw_rect(Rect2(o + Vector2(0 if sx > 0 else 1 - l, 0), Vector2(l, 1)), color)
		_overlay.draw_rect(Rect2(o + Vector2(0, 0 if sy > 0 else 1 - l), Vector2(1, l)), color)
