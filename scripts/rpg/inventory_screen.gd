extends CanvasLayer
## Pantalla de estado e inventario (tecla I, acción open_inventory; ofrendas-v1.md y
## progresion-adoc.md). Solo lectura: nivel, XP hasta el siguiente nivel, PV, ATQ, DEF, Luz suelta,
## fama, la relación con el Bosque en el que está (bosques-y-relacion.md) y la lista de ofrendas
## con su valor. Pausa el árbol (y con él WorldClock) mientras está
## abierta y se cierra con I o Esc. Sigue activa en pausa (process_mode ALWAYS). Solo lee GameState.

## Textos de placeholder; los revisa narrative-writer.
const TEXT_TITLE: String = "Estado del Adoc"
const TEXT_LEVEL: String = "Nivel %d"
const TEXT_XP: String = "XP %d / %d"
const TEXT_XP_MAX: String = "XP %d (nivel máximo)"
const TEXT_HP: String = "PV %d/%d"
const TEXT_ATK_DEF: String = "ATQ %d   DEF %d"
const TEXT_LUZ: String = "Luz suelta %d/%d"
const TEXT_FAMA: String = "Fama %d"
const TEXT_OFRENDAS: String = "Ofrendas"
const TEXT_NO_OFRENDAS: String = "Ninguna"
const TEXT_OFRENDA: String = "%s (%d)"
const TEXT_OFRENDA_COUNT: String = "%s (%d) x%d"
const TEXT_HINT: String = "I / Esc: cerrar"

## Reparto en Bosques de la partida (para saber en qué Bosque está el Adoc), recalculado si
## cambian la seed o la región.
var _map: BosqueMap
var _map_key: String = ""

@onready var _title: Label = $Root/Title
@onready var _stats: Label = $Root/Stats
@onready var _ofrendas_title: Label = $Root/OfrendasTitle
@onready var _ofrendas: Label = $Root/Ofrendas
@onready var _hint: Label = $Root/Hint


func _ready() -> void:
	visible = false
	_title.text = TEXT_TITLE
	_ofrendas_title.text = TEXT_OFRENDAS
	_hint.text = TEXT_HINT


func is_open() -> bool:
	return visible


## Líneas de estado del Adoc (puras sobre GameState: las usan la pantalla y los tests).
static func stat_lines() -> Array[String]:
	var stats: Dictionary = AdventureRules.adoc_stats(GameState.level)
	var lines: Array[String] = [TEXT_LEVEL % GameState.level]
	if GameState.level >= AdventureRules.max_level():
		lines.append(TEXT_XP_MAX % GameState.xp)
	else:
		lines.append(TEXT_XP % [GameState.xp, AdventureRules.xp_for_level(GameState.level + 1)])
	lines.append(TEXT_HP % [GameState.hp, int(stats.max_hp)])
	lines.append(TEXT_ATK_DEF % [int(stats.atk), int(stats.def)])
	lines.append(TEXT_LUZ % [GameState.luz, AdventureRules.luz_max()])
	lines.append(TEXT_FAMA % GameState.fama)
	return lines


## Línea de la relación con un Bosque ("" fuera de la región).
static func relation_line(bosque_id: int) -> String:
	if bosque_id < 0:
		return ""
	return Texts.get_text("inventory_bosque_relation") % AdventureRules.relation(bosque_id)


## Bosque del chunk actual (-1 si no se conoce).
func _current_bosque() -> int:
	if GameState.chunk_coord.x < 0:
		return -1
	var key: String = "%d:%s" % [GameState.seed_value, GameState.region_id]
	if key != _map_key:
		_map = BosqueMap.for_region(GameState.seed_value, ChunkGenerator.load_region(GameState.region_id))
		_map_key = key
	return _map.bosque_at(GameState.chunk_coord)


## Una línea por id de ofrenda (con cuántas hay), de menor a mayor valor.
static func ofrenda_lines(inventory: Array) -> Array[String]:
	var ids: Array[String] = []
	var values: Dictionary = {}
	for item: Variant in inventory:
		if item is Dictionary and not values.has(str(item.get("id", ""))):
			ids.append(str(item.id))
			values[str(item.id)] = int(item.get("luz", 0))
	ids.sort_custom(func(a: String, b: String) -> bool: return values[a] < values[b])
	var lines: Array[String] = []
	for id: String in ids:
		var shown: String = Ofrendas.display_name(StringName(id))
		var count: int = Ofrendas.count_of(inventory, id)
		lines.append(TEXT_OFRENDA_COUNT % [shown, values[id], count] if count > 1 else TEXT_OFRENDA % [shown, values[id]])
	if lines.is_empty():
		lines.append(TEXT_NO_OFRENDAS)
	return lines


func open() -> void:
	if visible or get_tree().paused:
		return
	var lines: Array[String] = stat_lines()
	var relation: String = relation_line(_current_bosque())
	if relation != "":
		lines.append(relation)
	_stats.text = "\n".join(lines)
	_ofrendas.text = "\n".join(ofrenda_lines(GameState.inventory))
	visible = true
	get_tree().paused = true


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed(&"open_inventory") or event.is_action_pressed(&"ui_cancel"):
			close()
		# Con la pantalla abierta no pasa ninguna otra entrada al juego.
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"open_inventory") and not get_tree().paused:
		open()
		get_viewport().set_input_as_handled()
