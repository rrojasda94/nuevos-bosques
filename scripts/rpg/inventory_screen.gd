extends CanvasLayer
## Pantalla de bolsa, equipo y estado (tecla I, acción open_inventory; roadmap-0.3.md #113,
## ofrendas-v1.md, progresion-adoc.md). Rejilla de COLUMNS × ROWS casillas de la bolsa, las 3
## ranuras de equipo (mano principal, máscara, talismán), la descripción del objeto marcado y la
## ficha del Adoc: nivel, XP, PV, ATQ (con el arma equipada), DEF, Luz suelta, fama y la relación
## con el Bosque en el que está y hasta cuándo dura su paso pagado (bosques-y-relacion.md).
## Cursor con flechas, WASD o cruceta. Aceptar (ui_accept o E) equipa el objeto de la bolsa o
## desequipa la ranura, o come un fruto guardado (solo en su Bosque de origen: fuera, su casilla
## se ve apagada y lo explica); las ofrendas no se usan aquí (se dejan en un Bosque). Cancelar o
## I cierra.
## Pausa el árbol (y con él WorldClock) mientras está abierta; sigue activa en pausa (process_mode
## ALWAYS). Las reglas están en InventoryLogic y AdventureRules. Iconos de placeholder: un cuadro
## con el color de su tipo y la inicial (hasta que pixel-artist haga los sprites).

## Textos de placeholder; los revisa narrative-writer.
const TEXT_TITLE: String = "Estado del Adoc"
const TEXT_EQUIPMENT: String = "Equipo"
const TEXT_LEVEL: String = "Nivel %d"
const TEXT_XP: String = "XP %d / %d"
const TEXT_XP_MAX: String = "XP %d (nivel máximo)"
const TEXT_HP: String = "PV %d/%d"
const TEXT_ATK_DEF: String = "ATQ %d   DEF %d"
const TEXT_ATK_BONUS_DEF: String = "ATQ %d (+%d)   DEF %d"
const TEXT_LUZ: String = "Luz suelta %d/%d"
const TEXT_FAMA: String = "Fama %d"
const TEXT_EMPTY_SLOT: String = "Casilla vacía"
const TEXT_EMPTY_EQUIP: String = "—"
const TEXT_SLOT_LINE: String = "%s: %s"
const TEXT_SLOT_NAMES: Dictionary = { &"main_hand": "Mano", &"mask": "Máscara", &"talisman": "Talismán" }
const TEXT_SLOT_EMPTY_DESC: String = "Nada equipado. Elige un objeto de la bolsa para equiparlo."
const TEXT_OFRENDA_VALUE: String = "Luz %d. "
const TEXT_ATK_VALUE: String = "ATQ +%d. "
const TEXT_EQUIPPED: String = "Te equipas: %s."
const TEXT_UNEQUIPPED: String = "Guardas: %s."
const TEXT_OFRENDA_USE: String = "Las ofrendas se dejan ante un Nujio."
const TEXT_HINT: String = "Aceptar: usar/equipar/guardar   I / Esc: cerrar"

const COLUMNS: int = 4
const ROWS: int = 3
const CELL: int = 20
const GAP: int = 2
const ICON: int = 12
## Casillas de la bolsa: 0 .. COLUMNS × ROWS - 1. Después, las ranuras de equipo.
const BAG_CELLS: int = COLUMNS * ROWS
const EQUIP_CELLS: int = 3
## Colores (paleta Endesga 32).
const COLOR_CELL := Color("262b44")
const COLOR_BORDER := Color("5a6988")
const COLOR_CURSOR := Color("fee761")
const COLOR_EQUIP_CELL := Color("3a4466")
const KIND_COLORS: Dictionary = {
	&"ofrenda": Color("feae34"), &"weapon": Color("c0cbdc"), &"mask": Color("b86f50"), &"talisman": Color("63c74d"),
	&"fruit": Color("e43b44"),
}
## Objeto que no se puede usar aquí (un fruto fuera de su Bosque).
const COLOR_DISABLED := Color(1, 1, 1, 0.35)

## Reparto en Bosques de la partida (para saber en qué Bosque está el Adoc), recalculado si
## cambian la seed o la región.
var _map: BosqueMap
var _map_key: String = ""
## Casilla marcada (0 .. BAG_CELLS + EQUIP_CELLS - 1).
var _cursor: int = 0
## Aviso de la última acción (se borra al mover el cursor).
var _message: String = ""
var _cells: Array[Panel] = []
var _relation: String = ""
## Bosque en el que está el Adoc al abrir (-1 si no se conoce).
var _bosque_id: int = -1

@onready var _root: Control = $Root
@onready var _title: Label = $Root/Title
@onready var _stats: Label = $Root/Stats
@onready var _equip_title: Label = $Root/EquipTitle
@onready var _equip_list: Label = $Root/EquipList
@onready var _item_name: Label = $Root/ItemName
@onready var _item_desc: Label = $Root/ItemDesc
@onready var _hint: Label = $Root/Hint
@onready var _grid: Control = $Root/Grid
@onready var _equip_row: Control = $Root/EquipRow


func _ready() -> void:
	visible = false
	_title.text = TEXT_TITLE
	_equip_title.text = TEXT_EQUIPMENT
	_hint.text = TEXT_HINT
	for i: int in BAG_CELLS:
		_cells.append(_make_cell(_grid, Vector2((i % COLUMNS) * (CELL + GAP), (i / COLUMNS) * (CELL + GAP))))
	for i: int in EQUIP_CELLS:
		_cells.append(_make_cell(_equip_row, Vector2(i * (CELL + GAP), 0)))


func is_open() -> bool:
	return visible


# --- Lógica de presentación (pura sobre GameState: la usan la pantalla y los tests) -------------

## Líneas de estado del Adoc. El ATQ incluye el arma equipada (y muestra cuánto suma).
static func stat_lines() -> Array[String]:
	var stats: Dictionary = AdventureRules.adoc_combat_stats()
	var bonus: int = AdventureRules.weapon_atk_bonus()
	var lines: Array[String] = [TEXT_LEVEL % GameState.level]
	if GameState.level >= AdventureRules.max_level():
		lines.append(TEXT_XP_MAX % GameState.xp)
	else:
		lines.append(TEXT_XP % [GameState.xp, AdventureRules.xp_for_level(GameState.level + 1)])
	lines.append(TEXT_HP % [GameState.hp, int(stats.max_hp)])
	if bonus > 0:
		lines.append(TEXT_ATK_BONUS_DEF % [int(stats.atk), bonus, int(stats.def)])
	else:
		lines.append(TEXT_ATK_DEF % [int(stats.atk), int(stats.def)])
	lines.append(TEXT_LUZ % [GameState.luz, AdventureRules.luz_max()])
	lines.append(TEXT_FAMA % GameState.fama)
	return lines


## Línea de la relación con un Bosque ("" fuera de la región).
static func relation_line(bosque_id: int) -> String:
	if bosque_id < 0:
		return ""
	return Texts.get_text("inventory_bosque_relation") % AdventureRules.relation(bosque_id)


## Línea del paso pagado del Bosque: hasta qué riutash dura o si es permanente ("" si no está
## pagado o fuera de la región).
static func toll_line(bosque_id: int) -> String:
	var left: int = AdventureRules.open_riutash_left(bosque_id)
	if bosque_id < 0 or left == 0:
		return ""
	if left == AdventureRules.OPEN_PERMANENT:
		return Texts.get_text("inventory_toll_permanent")
	if left == 1:
		return Texts.get_text("inventory_toll_next")
	return Texts.get_text("inventory_toll_until") % left


## Una línea por ranura de equipo: "Mano: Lanza de adoc", "Máscara: —".
static func equipment_lines(equipped: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for slot: StringName in InventoryLogic.SLOTS:
		var id: StringName = InventoryLogic.equipped_in(equipped, slot)
		lines.append(TEXT_SLOT_LINE % [TEXT_SLOT_NAMES[slot], Items.display_name(id) if id != &"" else TEXT_EMPTY_EQUIP])
	return lines


## Id del objeto bajo el cursor: casilla de la bolsa o ranura de equipo (&"" si está vacía).
static func id_under(cursor: int, bag: Array, equipped: Dictionary) -> StringName:
	if cursor < BAG_CELLS:
		return InventoryLogic.id_at(bag, cursor)
	return InventoryLogic.equipped_in(equipped, slot_of(cursor))


## Ranura de equipo de una posición del cursor (&"" si es de la bolsa).
static func slot_of(cursor: int) -> StringName:
	var i: int = cursor - BAG_CELLS
	return InventoryLogic.SLOTS[i] if i >= 0 and i < EQUIP_CELLS else &""


## Texto de la casilla `index` de la bolsa estando en el Bosque `bosque_id`: la descripción y, si
## es un fruto que no se puede comer aquí, por qué.
static func describe_at(index: int, bosque_id: int) -> String:
	var id: StringName = InventoryLogic.id_at(GameState.bag, index)
	var text: String = describe(id)
	if id == Items.FRUIT_ID and not FruitRules.can_eat(index, bosque_id):
		text = Texts.get_text("fruit_eat_elsewhere")
	return text


## Nombre y descripción del objeto (con su valor en Luz o su ATQ delante).
static func describe(id: StringName) -> String:
	var prefix: String = ""
	if Ofrendas.is_ofrenda(id):
		prefix = TEXT_OFRENDA_VALUE % Items.luz_of(id)
	elif Items.atk_bonus(id) > 0:
		prefix = TEXT_ATK_VALUE % Items.atk_bonus(id)
	return prefix + Items.description(id)


## Mueve el cursor en `dir` (sin dar la vuelta). La fila de equipo va debajo de la bolsa, alineada
## con sus columnas 0..EQUIP_CELLS-1 (desde las columnas de más a la derecha se baja a la última
## ranura).
static func move_cursor(cursor: int, dir: Vector2i) -> int:
	if cursor < BAG_CELLS:
		var col: int = cursor % COLUMNS
		var row: int = cursor / COLUMNS
		if dir.x != 0:
			return row * COLUMNS + clampi(col + dir.x, 0, COLUMNS - 1)
		if dir.y < 0:
			return cursor if row == 0 else cursor - COLUMNS
		if dir.y > 0:
			return cursor + COLUMNS if row < ROWS - 1 else BAG_CELLS + mini(col, EQUIP_CELLS - 1)
		return cursor
	var i: int = cursor - BAG_CELLS
	if dir.x != 0:
		return BAG_CELLS + clampi(i + dir.x, 0, EQUIP_CELLS - 1)
	if dir.y < 0:
		return (ROWS - 1) * COLUMNS + i
	return cursor


## Aceptar sobre el cursor: equipa (bolsa) o desequipa (ranura). Devuelve el aviso que se muestra
## ("" si no pasa nada). `bosque_id`: Bosque en el que está el Adoc (para comer frutos). Escribe en
## GameState a través de AdventureRules y FruitRules.
static func activate(cursor: int, bosque_id: int = -1) -> String:
	if cursor >= BAG_CELLS:
		var slot: StringName = slot_of(cursor)
		var worn: StringName = InventoryLogic.equipped_in(GameState.equipped, slot)
		if worn == &"":
			return ""
		if AdventureRules.unequip_slot(slot):
			return TEXT_UNEQUIPPED % Items.display_name(worn)
		return Texts.get_text("bag_full")
	var id: StringName = InventoryLogic.id_at(GameState.bag, cursor)
	if id == &"":
		return ""
	if Ofrendas.is_ofrenda(id):
		return TEXT_OFRENDA_USE
	if id == Items.FRUIT_ID:
		var healed: int = FruitRules.eat_from_bag(cursor, bosque_id)
		return Texts.get_text("fruit_eat_elsewhere") if healed < 0 else Texts.get_text("fruit_eaten") % healed
	if AdventureRules.equip_from_bag(cursor):
		return TEXT_EQUIPPED % Items.display_name(id)
	return Texts.get_text("bag_full")


# --- Escena ----------------------------------------------------------------------------------------

func open() -> void:
	if visible or get_tree().paused:
		return
	_bosque_id = _current_bosque()
	_relation = relation_line(_bosque_id)
	var toll: String = toll_line(_bosque_id)
	if toll != "":
		_relation += "\n" + toll
	_cursor = 0
	_message = ""
	visible = true
	get_tree().paused = true
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed(&"open_inventory") and not get_tree().paused:
			open()
			get_viewport().set_input_as_handled()
		return
	# Con la pantalla abierta no pasa ninguna otra entrada al juego.
	get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"open_inventory") or event.is_action_pressed(&"ui_cancel"):
		close()
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"interact"):
		_message = activate(_cursor, _bosque_id)
		Sfx.play(&"menu_accept")
		_refresh()
		return
	var dir := Vector2i.ZERO
	if event.is_action_pressed(&"ui_up", true) or event.is_action_pressed(&"move_up", true):
		dir = Vector2i.UP
	elif event.is_action_pressed(&"ui_down", true) or event.is_action_pressed(&"move_down", true):
		dir = Vector2i.DOWN
	elif event.is_action_pressed(&"ui_left", true) or event.is_action_pressed(&"move_left", true):
		dir = Vector2i.LEFT
	elif event.is_action_pressed(&"ui_right", true) or event.is_action_pressed(&"move_right", true):
		dir = Vector2i.RIGHT
	if dir == Vector2i.ZERO:
		return
	var next: int = move_cursor(_cursor, dir)
	if next != _cursor:
		_cursor = next
		_message = ""
		Sfx.play(&"menu_move")
		_refresh()


## Bosque del chunk actual (-1 si no se conoce).
func _current_bosque() -> int:
	if GameState.chunk_coord.x < 0:
		return -1
	var key: String = "%d:%s" % [GameState.seed_value, GameState.region_id]
	if key != _map_key:
		_map = BosqueMap.for_region(GameState.seed_value, ChunkGenerator.load_region(GameState.region_id))
		_map_key = key
	return _map.bosque_at(GameState.chunk_coord)


func _refresh() -> void:
	var lines: Array[String] = stat_lines()
	if _relation != "":
		lines.append(_relation)
	_stats.text = "\n".join(lines)
	_equip_list.text = "\n".join(equipment_lines(GameState.equipped))
	for i: int in _cells.size():
		var id: StringName = id_under(i, GameState.bag, GameState.equipped)
		var qty: int = InventoryLogic.qty_at(GameState.bag, i) if i < BAG_CELLS else 1
		var usable: bool = id != Items.FRUIT_ID or FruitRules.can_eat(i, _bosque_id)
		_draw_cell(_cells[i], id, qty, i == _cursor, i >= BAG_CELLS, usable)
	var id: StringName = id_under(_cursor, GameState.bag, GameState.equipped)
	if id != &"":
		_item_name.text = Items.display_name(id)
		_item_desc.text = describe_at(_cursor, _bosque_id) if _cursor < BAG_CELLS else describe(id)
	elif _cursor >= BAG_CELLS:
		_item_name.text = TEXT_SLOT_NAMES[slot_of(_cursor)]
		_item_desc.text = TEXT_SLOT_EMPTY_DESC
	else:
		_item_name.text = TEXT_EMPTY_SLOT
		_item_desc.text = ""
	if _message != "":
		_item_desc.text = _message


func _make_cell(parent: Control, pos: Vector2) -> Panel:
	var cell := Panel.new()
	cell.position = pos
	cell.size = Vector2(CELL, CELL)
	var icon := ColorRect.new()
	icon.name = "Icon"
	icon.position = Vector2((CELL - ICON) / 2, (CELL - ICON) / 2)
	icon.size = Vector2(ICON, ICON)
	cell.add_child(icon)
	var letter := Label.new()
	letter.name = "Letter"
	letter.position = Vector2.ZERO
	letter.size = Vector2(CELL, CELL)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.add_child(letter)
	var qty := Label.new()
	qty.name = "Qty"
	qty.position = Vector2(0, CELL - 10)
	qty.size = Vector2(CELL - 1, 10)
	qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cell.add_child(qty)
	parent.add_child(cell)
	return cell


func _draw_cell(cell: Panel, id: StringName, qty: int, selected: bool, is_equip: bool, usable: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_EQUIP_CELL if is_equip else COLOR_CELL
	style.set_border_width_all(1)
	style.border_color = COLOR_CURSOR if selected else COLOR_BORDER
	cell.add_theme_stylebox_override(&"panel", style)
	var icon := cell.get_node("Icon") as ColorRect
	var letter := cell.get_node("Letter") as Label
	var qty_label := cell.get_node("Qty") as Label
	icon.visible = id != &""
	icon.modulate = Color.WHITE if usable else COLOR_DISABLED
	letter.modulate = icon.modulate
	icon.color = KIND_COLORS.get(Items.kind_of(id), COLOR_BORDER)
	letter.text = Items.display_name(id).left(1) if id != &"" else ""
	qty_label.text = str(qty) if id != &"" and qty > 1 else ""
