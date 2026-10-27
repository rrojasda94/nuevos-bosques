class_name TacticalTurnFlow
extends RefCounted
## Máquina de estados del turno del jugador en la escena táctica (combate-tactico.md, ADR 0016; PR
## T4) y ayudas puras de la vista: entrada -> dirección, cursor sobre el tablero y cámara. La IA de
## los enemigos y del "Auto" está en TacticalAI (T5). No dibuja ni toca GameState: la escena (TacticalBattleScene) le pasa la entrada y
## anima lo que devuelve. Funciona con tableros de cualquier tamaño (lee width y height del
## TacticalBoard) y con cualquier número de combatientes por bando.
## Flujo del turno de un combatiente del jugador (el jugador lleva a todo su bando):
## - MENU: Mover / Actuar / Auto / Esperar ("Terminar" si ya movió o actuó) y, si hay aliados, la
##   orden al grupo ("Orden: Libre / Atacar / Defender"; cada pulsación pasa a la siguiente y no gasta
##   nada). Auto (T5, solo aliados, no el Adoc): ese aliado juega el turno con su IA de rol
##   (TacticalAI); el flujo pasa a IDLE y la escena lo ejecuta.
## - MOVE: casillas alcanzables resaltadas y un cursor libre; confirmar mueve (una vez por turno).
## - ACT: submenú con Atacar, Defender, Vendar / Animar / Cubrir (según el rol), Ofrecer Luz,
##   Ofrenda y Huir (solo en una casilla del borde; "Huir (45%)" con TacticalBattle.flee_chance; si
##   falla, el turno termina: devuelve { kind: KIND_END, failed: true } y pasa a IDLE).
## - TARGET: objetivos resaltados; las flechas saltan al objetivo más cercano en esa dirección.
## - OFRENDA: lista de ofrendas que alcanzan el peaje.
## - FACING: las flechas eligen la orientación; confirmar termina el turno (Esperar si no actuó).
## Tras mover o actuar vuelve a MENU, o pasa a FACING si ya hizo las dos cosas. Si el combate acaba,
## OVER. IDLE: no es turno del jugador (IA o animación).

enum State { IDLE, MENU, MOVE, ACT, TARGET, OFRENDA, FACING, OVER }

## Entradas del menú principal y del submenú Actuar (campo `id`).
const MAIN_MOVE: StringName = &"move"
const MAIN_ACT: StringName = &"act"
const MAIN_WAIT: StringName = &"wait"
const MAIN_AUTO: StringName = &"auto"
const MAIN_ORDER: StringName = &"order"
const ACT_ATTACK: StringName = &"attack"
const ACT_DEFEND: StringName = &"defend"
const ACT_BANDAGE: StringName = &"bandage"
const ACT_CHEER: StringName = &"cheer"
const ACT_COVER: StringName = &"cover"
const ACT_OFFER_LUZ: StringName = &"offer_luz"
const ACT_OFRENDA: StringName = &"ofrenda"
const ACT_FLEE: StringName = &"flee"
const ACT_BACK: StringName = &"back"
## Resultados que no son acciones de TacticalBattle (campo `kind`).
const KIND_MOVE: StringName = &"move"
const KIND_END: StringName = &"end"
## Tamaño de casilla y píxeles que sube cada nivel de altura al dibujarlo.
const TILE_PX: int = 16
const LEVEL_PX: int = 4

var battle: TacticalBattle
var state: State = State.IDLE
var cursor: Vector2i = Vector2i.ZERO
## Casillas resaltadas en MOVE (alcanzables) o TARGET (objetivos válidos).
var highlight: Array[Vector2i] = []
## Acción que espera objetivo en TARGET (ACT_ATTACK, ACT_BANDAGE, ACT_CHEER o ACT_COVER).
var pending: StringName = &""
## Orientación elegida en FACING.
var facing: TacticalBoard.Facing = TacticalBoard.Facing.EAST


func _init(tactical_battle: TacticalBattle) -> void:
	battle = tactical_battle


# --- Ayudas puras de la vista -------------------------------------------------------------------

## Dirección de un evento de flechas / WASD / cruceta (Vector2i.ZERO si no es una dirección).
static func dir_from_event(event: InputEvent) -> Vector2i:
	if event.is_action_pressed(&"ui_up", true) or event.is_action_pressed(&"move_up", true):
		return Vector2i.UP
	if event.is_action_pressed(&"ui_down", true) or event.is_action_pressed(&"move_down", true):
		return Vector2i.DOWN
	if event.is_action_pressed(&"ui_left", true) or event.is_action_pressed(&"move_left", true):
		return Vector2i.LEFT
	if event.is_action_pressed(&"ui_right", true) or event.is_action_pressed(&"move_right", true):
		return Vector2i.RIGHT
	return Vector2i.ZERO


## Confirmar: Enter / Espacio / botón A (ui_accept) o E (interact).
static func is_accept(event: InputEvent) -> bool:
	return event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"interact")


static func is_cancel(event: InputEvent) -> bool:
	return event.is_action_pressed(&"ui_cancel")


## Cursor movido un paso dentro de un tablero de `width` x `height`.
static func step_cursor(cell: Vector2i, dir: Vector2i, width: int, height: int) -> Vector2i:
	return Vector2i(clampi(cell.x + dir.x, 0, width - 1), clampi(cell.y + dir.y, 0, height - 1))


## La casilla de `cells` más cercana en la dirección `dir` desde `current` (la misma si no hay
## ninguna por ese lado). Para saltar entre objetivos con las flechas.
static func next_in_direction(cells: Array[Vector2i], current: Vector2i, dir: Vector2i) -> Vector2i:
	var best: Vector2i = current
	var best_score: int = 1 << 30
	for c: Vector2i in cells:
		var d: Vector2i = c - current
		var along: int = d.x * dir.x + d.y * dir.y
		if c == current or along <= 0:
			continue
		var across: int = absi(d.x * dir.y) + absi(d.y * dir.x)
		var score: int = along * 4 + across * 5
		if score < best_score:
			best_score = score
			best = c
	return best


## Orientación de una dirección de flechas.
static func facing_from_dir(dir: Vector2i, fallback: TacticalBoard.Facing) -> TacticalBoard.Facing:
	var i: int = TacticalBoard.NEIGHBOR_DIRS.find(dir)
	return fallback if i < 0 else i as TacticalBoard.Facing


## Esquina superior izquierda (en píxeles del tablero) de una casilla de nivel `level`. El tablero
## deja arriba MAX_LEVEL × LEVEL_PX de margen para que las casillas altas no se salgan.
static func cell_to_px(cell: Vector2i, level: int) -> Vector2:
	return Vector2(cell.x * TILE_PX, cell.y * TILE_PX + (TacticalBoard.MAX_LEVEL - level) * LEVEL_PX)


## Tamaño en píxeles del dibujo de un tablero.
static func board_px(width: int, height: int) -> Vector2:
	return Vector2(width * TILE_PX, height * TILE_PX + TacticalBoard.MAX_LEVEL * LEVEL_PX)


## Desplazamiento del tablero dentro de la vista (`view`) para que `focus` (centro de la casilla
## seguida, en píxeles del tablero) quede a `margin` de los bordes. Si el tablero cabe en un eje, se
## centra en ese eje; si no, se mueve lo justo y nunca enseña fuera del tablero.
static func camera_offset(focus: Vector2, board: Vector2, view: Vector2, current: Vector2, margin: float) -> Vector2:
	var out := Vector2.ZERO
	for axis: int in 2:
		if board[axis] <= view[axis]:
			out[axis] = floorf((view[axis] - board[axis]) / 2.0)
			continue
		var off: float = current[axis]
		var m: float = minf(margin, view[axis] / 2.0)
		if off + focus[axis] < m:
			off = m - focus[axis]
		elif off + focus[axis] > view[axis] - m:
			off = view[axis] - m - focus[axis]
		out[axis] = clampf(off, view[axis] - board[axis], 0.0)
	return out


# --- Turno del jugador --------------------------------------------------------------------------

## Empieza el turno del combatiente activo (del jugador): menú principal, cursor sobre él.
func begin_player_turn() -> void:
	state = State.MENU
	cursor = battle.units[battle.active].cell
	facing = battle.units[battle.active].facing
	highlight = []
	pending = &""


## Menú principal: [{ id, text, enabled }]. Auto, solo para los aliados (no el `leader`); la orden
## al grupo, solo si hay algún aliado en pie.
func main_entries() -> Array[Dictionary]:
	var did_something: bool = battle.active_moved or battle.active_acted
	var out: Array[Dictionary] = [
		{ "id": MAIN_MOVE, "text": Texts.get_text("tactical_menu_move"), "enabled": not battle.active_moved },
		{ "id": MAIN_ACT, "text": Texts.get_text("tactical_menu_act"), "enabled": battle.can_act() },
	]
	if not battle.units[battle.active].leader:
		out.append({ "id": MAIN_AUTO, "text": Texts.get_text("tactical_menu_auto"), "enabled": true })
	out.append({ "id": MAIN_WAIT, "text": Texts.get_text("tactical_menu_end" if did_something else "tactical_menu_wait"),
		"enabled": true })
	if has_allies():
		out.append({ "id": MAIN_ORDER, "text": Texts.get_text("battle_tactic_order") % order_name(battle.group_order),
			"enabled": true })
	return out


## Hay algún aliado en pie en el bando del jugador (alguien que no es el `leader`).
func has_allies() -> bool:
	for u: Dictionary in battle.units:
		if u.alive and int(u.side) == TacticalBattle.SIDE_PLAYER and not u.leader:
			return true
	return false


## Nombre de una orden al grupo (BattleLogic.GroupOrder; textos del combate por menú).
static func order_name(order: int) -> String:
	match order:
		BattleLogic.GroupOrder.ATTACK:
			return Texts.get_text("battle_order_attack")
		BattleLogic.GroupOrder.DEFEND:
			return Texts.get_text("battle_order_defend")
	return Texts.get_text("battle_order_free")


func choose_main(id: StringName) -> void:
	if state != State.MENU:
		return
	match id:
		MAIN_MOVE:
			if battle.active_moved:
				return
			state = State.MOVE
			highlight = _cells_of(battle.reachable_for(battle.active).keys())
			cursor = battle.units[battle.active].cell
		MAIN_ACT:
			if battle.can_act():
				state = State.ACT
		MAIN_WAIT:
			_go_facing()
		MAIN_AUTO:
			if not battle.units[battle.active].leader:
				state = State.IDLE
				highlight = []
		MAIN_ORDER:
			if has_allies():
				battle.set_group_order((battle.group_order + 1) % 3)


## Submenú Actuar: [{ id, text, enabled }]. Vendar y Animar solo con rol de apoyo, Cubrir con el de
## defensor, Huir solo en una casilla del borde.
func act_entries() -> Array[Dictionary]:
	var me: Dictionary = battle.units[battle.active]
	var out: Array[Dictionary] = [
		{ "id": ACT_ATTACK, "text": Texts.get_text("tactical_act_attack"),
			"enabled": not battle.attack_targets(battle.active).is_empty() },
		{ "id": ACT_DEFEND, "text": Texts.get_text("tactical_act_defend"), "enabled": battle.can_act() },
	]
	if me.role == TacticalBattle.ROLE_SUPPORT:
		out.append({ "id": ACT_BANDAGE, "text": Texts.get_text("tactical_act_bandage"),
			"enabled": not support_targets(ACT_BANDAGE).is_empty() })
		out.append({ "id": ACT_CHEER, "text": Texts.get_text("tactical_act_cheer"),
			"enabled": not support_targets(ACT_CHEER).is_empty() })
	if me.role == TacticalBattle.ROLE_DEFENDER:
		out.append({ "id": ACT_COVER, "text": Texts.get_text("tactical_act_cover"),
			"enabled": not support_targets(ACT_COVER).is_empty() })
	var luz_text: String = Texts.get_text("tactical_act_offer_luz") % battle.toll if battle.toll > 0 \
		else Texts.get_text("tactical_act_offer_luz_plain")
	out.append({ "id": ACT_OFFER_LUZ, "text": luz_text, "enabled": battle.can_offer_luz() })
	out.append({ "id": ACT_OFRENDA, "text": Texts.get_text("tactical_act_ofrenda"),
		"enabled": not battle.payable_ofrendas().is_empty() })
	if battle.can_flee_now():
		out.append({ "id": ACT_FLEE, "text": Texts.get_text("tactical_act_flee_chance") % battle.flee_chance(),
			"enabled": true })
	out.append({ "id": ACT_BACK, "text": Texts.get_text("tactical_back"), "enabled": true })
	return out


## Casillas de los aliados a los que se puede Vendar, Animar o Cubrir ahora.
func support_targets(kind: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in battle.units.size():
		var ok: bool = false
		match kind:
			ACT_BANDAGE:
				ok = battle.can_bandage(i)
			ACT_CHEER:
				ok = battle.can_cheer(i)
			ACT_COVER:
				ok = battle.can_cover(i)
		if ok:
			out.append(battle.units[i].cell)
	return out


## Elige en el submenú Actuar. Devuelve el resultado de la acción si se ejecuta ya (Defender,
## Ofrecer Luz, Huir), o {} si abre otro paso (objetivo, ofrendas) o vuelve.
func choose_act(id: StringName) -> Dictionary:
	if state != State.ACT:
		return {}
	match id:
		ACT_ATTACK:
			var cells: Array[Vector2i] = []
			for t: int in battle.attack_targets(battle.active):
				cells.append(battle.units[t].cell)
			_go_target(id, cells)
		ACT_BANDAGE, ACT_CHEER, ACT_COVER:
			_go_target(id, support_targets(id))
		ACT_DEFEND:
			return _after(battle.defend())
		ACT_OFFER_LUZ:
			return _after(battle.offer_luz())
		ACT_FLEE:
			var actor: int = battle.active
			var fled: Dictionary = battle.flee()
			if fled.get("failed", false):
				# P1: fallar la huida termina el turno (TacticalBattle ya lo cobró).
				fled.kind = KIND_END
				fled.actor = actor
				state = State.IDLE
				highlight = []
				return fled
			return _after(fled)
		ACT_OFRENDA:
			if not battle.payable_ofrendas().is_empty():
				state = State.OFRENDA
		ACT_BACK:
			state = State.MENU
	return {}


## Ofrendas que se pueden dar (índices de battle.ofrendas), para el submenú.
func ofrenda_choices() -> Array[int]:
	return battle.payable_ofrendas()


func choose_ofrenda(index: int) -> Dictionary:
	if state != State.OFRENDA:
		return {}
	return _after(battle.offer_ofrenda(index))


## Flechas en el paso actual: cursor libre (MOVE), salto entre objetivos (TARGET) u orientación
## (FACING). Devuelve si cambió algo.
func move_cursor(dir: Vector2i) -> bool:
	if dir == Vector2i.ZERO:
		return false
	match state:
		State.MOVE:
			var next: Vector2i = step_cursor(cursor, dir, battle.board.width, battle.board.height)
			var changed: bool = next != cursor
			cursor = next
			return changed
		State.TARGET:
			var next: Vector2i = next_in_direction(highlight, cursor, dir)
			var changed: bool = next != cursor
			cursor = next
			return changed
		State.FACING:
			var f: TacticalBoard.Facing = facing_from_dir(dir, facing)
			var changed: bool = f != facing
			facing = f
			return changed
	return false


## Confirmar en MOVE, TARGET o FACING. Resultado: { kind: KIND_MOVE, path } al moverse, el de la
## acción en TARGET, { kind: KIND_END, ... } al terminar el turno, o {} si no vale.
func confirm() -> Dictionary:
	match state:
		State.MOVE:
			if not highlight.has(cursor) or cursor == battle.units[battle.active].cell:
				return {}
			var actor: int = battle.active
			var path: Array[Vector2i] = battle.move_active(cursor)
			if path.is_empty():
				return {}
			return _after({ "kind": KIND_MOVE, "actor": actor, "path": path })
		State.TARGET:
			var target: int = battle.unit_at(cursor)
			if target == TacticalBattle.NONE or not highlight.has(cursor):
				return {}
			var out: Dictionary = {}
			match pending:
				ACT_ATTACK:
					out = battle.attack(target, battle.can_finish(target))
				ACT_BANDAGE:
					out = battle.bandage(target)
				ACT_CHEER:
					out = battle.cheer(target)
				ACT_COVER:
					out = battle.cover(target)
			return _after(out)
		State.FACING:
			var actor: int = battle.active
			var acted: bool = battle.active_acted
			var out: Dictionary
			if acted:
				out = { "kind": KIND_END, "actor": actor, "ct_cost": battle.end_turn(facing),
					"text_key": &"" }
			else:
				out = battle.wait_turn(facing)
				out.kind = KIND_END
			state = State.OVER if battle.is_over() else State.IDLE
			highlight = []
			return out
	return {}


## Volver un paso. Desde FACING solo si todavía se puede mover o actuar.
func cancel() -> void:
	match state:
		State.MOVE, State.ACT:
			state = State.MENU
			highlight = []
			cursor = battle.units[battle.active].cell
		State.TARGET, State.OFRENDA:
			state = State.ACT
			highlight = []
			cursor = battle.units[battle.active].cell
		State.FACING:
			if not battle.active_moved or not battle.active_acted:
				state = State.MENU
				facing = battle.units[battle.active].facing


## Precisión y relación con el objetivo bajo el cursor en TARGET de Atacar ({} si no aplica).
func cursor_preview() -> Dictionary:
	if state != State.TARGET or pending != ACT_ATTACK:
		return {}
	var target: int = battle.unit_at(cursor)
	if target == TacticalBattle.NONE:
		return {}
	var p: Dictionary = battle.attack_preview(battle.active, target)
	p.target = target
	return p


func _go_target(kind: StringName, cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	state = State.TARGET
	pending = kind
	highlight = cells
	cursor = cells[0]


func _go_facing() -> void:
	state = State.FACING
	highlight = []
	facing = battle.units[battle.active].facing


## Después de mover o actuar: fin del combate, orientación si ya hizo las dos cosas, o el menú.
func _after(result: Dictionary) -> Dictionary:
	if result.is_empty():
		return result
	highlight = []
	pending = &""
	if battle.is_over():
		state = State.OVER
	elif battle.active_moved and battle.active_acted:
		_go_facing()
	else:
		state = State.MENU
		cursor = battle.units[battle.active].cell
	return result


static func _cells_of(keys: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k: Variant in keys:
		out.append(k as Vector2i)
	out.sort_custom(func(a: Vector2i, c: Vector2i) -> bool: return a.y < c.y or (a.y == c.y and a.x < c.x))
	return out
