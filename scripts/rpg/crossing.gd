extends CanvasLayer
## Menú del borde de un Bosque sin pagar (ADR 0009; cerrado o forzado): pagar Luz al Nujio, dejarle una ofrenda
## (submenú con las que alcanzan el peaje, completadas con Luz suelta; ofrendas-v1.md), enfrentar a
## su Botarramas o retroceder. Lo abre el encuentro con un Botarramas o, como red de seguridad, empujar el borde.
## Si el Bosque recuerda Botarramas vencidos, el peaje sube y el título lo avisa con una línea más;
## si la relación con el Bosque cambia el peaje (bosques-y-relacion.md), otra con su multiplicador.
## También lleva el combate de misión (Ofomni descarriado, EventBus.quest_battle_requested).
## Mientras está abierto (o dura el combate) el árbol se pausa; este nodo y el combate siguen
## activos (process_mode ALWAYS). Al terminar emite EventBus.crossing_resolved (o
## quest_battle_resolved) y la exploración cruza, retrocede o despierta al Adoc en su villa.
## Solo escucha EventBus y lee GameState: no conoce la escena de exploración.

const BATTLE_SCENE: PackedScene = preload("res://scenes/rpg/battle.tscn")
## Textos de placeholder; los revisa narrative-writer.
const TITLE: String = "El Bosque te observa. Su Nujio exige Luz."
const TEXT_OFRENDA_MENU: String = "Ofrecer una ofrenda"
const TEXT_OFRENDA_PLUS_LUZ: String = " (+%d Luz)"
const TEXT_BACK: String = "Volver"
## Hueco que se abre para la primera línea extra del título (aprovecha el margen bajo el título) y
## para cada una de las siguientes (alto de línea del título): hostilidad, relación.
const EXTRA_LINE: float = 10.0
const NEXT_EXTRA_LINE: float = 15.0
## Opciones del menú principal, en orden.
enum Option { PAY_LUZ, OFRENDA, FIGHT, RETREAT }

var _bosque_id: int = -1
var _cost: int = 0
var _distance: int = 0
var _map: BosqueMap
var _map_key: String = ""
var _battle: Node
## Misión del combate en curso (&"" = combate de borde).
var _quest_id: StringName = &""
## Submenú de ofrendas abierto: índices de AdventureRules.bag_ofrendas() de cada opción (sin la
## de volver).
var _ofrenda_choices: Array[int] = []
var _in_submenu: bool = false

@onready var _panel: Control = $Panel
@onready var _title: Label = $Panel/Title
@onready var _options: OptionMenu = $Panel/Options
var _options_top: float = 0.0
var _panel_top: float = 0.0


func _ready() -> void:
	_panel.visible = false
	_options_top = _options.offset_top
	_panel_top = _panel.offset_top
	EventBus.bosque_border_reached.connect(_on_bosque_border_reached)
	EventBus.quest_battle_requested.connect(_on_quest_battle_requested)


func _on_bosque_border_reached(bosque_id: int) -> void:
	if bosque_id < 0 or _panel.visible or _battle != null:
		return
	var region: Dictionary = ChunkGenerator.load_region(GameState.region_id)
	_ensure_map(region)
	var home: int = AdventureRules.home_bosque(_map, region)
	# Un Bosque forzado se cruza, pero sus Botarramas siguen exigiendo el pago al alcanzarte.
	if AdventureRules.is_paid(bosque_id, home):
		return
	_bosque_id = bosque_id
	_distance = maxi(1, _map.distance(home, bosque_id))
	_cost = AdventureRules.toll_for(bosque_id, _distance)
	_open_main_menu()
	_panel.visible = true
	get_tree().paused = true


func _open_main_menu() -> void:
	_in_submenu = false
	_title.text = title_for(_bosque_id)
	var lines: int = _title.text.count("\n")
	var extra: float = 0.0 if lines == 0 else EXTRA_LINE + NEXT_EXTRA_LINE * (lines - 1)
	_options.offset_top = _options_top + extra
	# El panel crece hacia arriba: abajo no cabe.
	_panel.offset_top = _panel_top - extra
	var texts: Array[String] = [
		"Ofrecer %d Luz (tienes %d)" % [_cost, GameState.luz],
		TEXT_OFRENDA_MENU,
		"Enfrentar al Botarramas",
		"Retroceder",
	]
	var has_ofrenda: bool = not Ofrendas.payable(AdventureRules.bag_ofrendas(), GameState.luz, _cost).is_empty()
	var enabled: Array[bool] = [GameState.luz >= _cost, has_ofrenda, true, true]
	_options.set_options(texts, enabled)


## Título del menú: el de siempre; si el Bosque recuerda Botarramas vencidos, su aviso; y si la
## relación multiplica el peaje, cuánto (con amistad alta, que el paso será permanente).
static func title_for(bosque_id: int) -> String:
	var lines: PackedStringArray = [TITLE]
	if AdventureRules.hostility(bosque_id) > 0:
		lines.append(Texts.get_text("crossing_bosque_remembers"))
	var relation_text: String = relation_line_for(bosque_id)
	if relation_text != "":
		lines.append(relation_text)
	return "\n".join(lines)


## Línea del multiplicador de la relación ("" si no cambia el peaje).
static func relation_line_for(bosque_id: int) -> String:
	var factor: float = AdventureRules.relation_toll_factor(bosque_id)
	if is_equal_approx(factor, 1.0):
		return ""
	var key: String = "crossing_relation_surcharge"
	if factor < 1.0:
		key = "crossing_relation_friend" if AdventureRules.relation(bosque_id) >= AdventureRules.permanent_at() else "crossing_relation_discount"
	return Texts.get_text(key) % format_factor(factor)


## Multiplicador en español: 0.75 -> "×0,75", 1.5 -> "×1,5".
static func format_factor(factor: float) -> String:
	return "×" + String.num(factor, 2).replace(".", ",")


## Una opción del submenú: "Ofrecer <ofrenda> (<valor>) por un paso de <N>", con la Luz suelta
## que la completa si no llega.
static func ofrenda_option(item: Dictionary, cost: int) -> String:
	var value: int = int(item.luz)
	var text: String = Texts.get_text("crossing_ofrenda_option") % [Ofrendas.display_name(StringName(str(item.id))), value, cost]
	var luz: int = Ofrendas.luz_needed(value, cost)
	if luz > 0:
		text += TEXT_OFRENDA_PLUS_LUZ % luz
	return text


func _open_submenu() -> void:
	_in_submenu = true
	var ofrendas: Array = AdventureRules.bag_ofrendas()
	_ofrenda_choices = Ofrendas.payable(ofrendas, GameState.luz, _cost)
	var texts: Array[String] = []
	var enabled: Array[bool] = []
	for i: int in _ofrenda_choices:
		texts.append(ofrenda_option(ofrendas[i], _cost))
		enabled.append(true)
	texts.append(TEXT_BACK)
	enabled.append(true)
	_options.set_options(texts, enabled)


## El reparto en Bosques se deriva de seed + región; se recalcula solo si cambian.
func _ensure_map(region: Dictionary) -> void:
	var key: String = "%d:%s" % [GameState.seed_value, GameState.region_id]
	if key != _map_key:
		_map = BosqueMap.for_region(GameState.seed_value, region)
		_map_key = key


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	get_viewport().set_input_as_handled()
	var choice: int = _options.handle(event)
	if _in_submenu:
		if choice == OptionMenu.CANCEL or choice == _ofrenda_choices.size():
			_open_main_menu()
		elif choice >= 0 and AdventureRules.pay_toll_with_ofrenda(_bosque_id, _cost, _ofrenda_choices[choice]):
			_close(&"paid")
		return
	match choice:
		Option.PAY_LUZ:
			if AdventureRules.pay_toll(_bosque_id, _cost):
				_close(&"paid")
		Option.OFRENDA:
			_open_submenu()
		Option.FIGHT:
			_start_battle()
		Option.RETREAT, OptionMenu.CANCEL:
			_close(&"retreated")


func _start_battle() -> void:
	_panel.visible = false
	_quest_id = &""
	var logic: BattleLogic = AdventureRules.start_battle(_bosque_id, _distance)
	_open_battle(logic, _map.styles[_bosque_id], UnicoArt.Kind.BOTARRAMAS)


## Combate de misión contra el Ofomni descarriado, con la d fijada al aparecer y los colores de su Bosque.
func _on_quest_battle_requested(quest_id: StringName) -> void:
	if _panel.visible or _battle != null or not GameState.quests.has(quest_id):
		return
	var q: Dictionary = GameState.quests[quest_id]
	_ensure_map(ChunkGenerator.load_region(GameState.region_id))
	_quest_id = quest_id
	get_tree().paused = true
	var logic: BattleLogic = AdventureRules.start_quest_battle(quest_id, int(q.ofomni_d))
	_open_battle(logic, _map.styles[maxi(0, int(q.ofomni_bosque))], UnicoArt.Kind.EYES)


func _open_battle(logic: BattleLogic, style: Dictionary, kind: UnicoArt.Kind) -> void:
	_battle = BATTLE_SCENE.instantiate()
	add_child(_battle)
	_battle.finished.connect(_on_battle_finished)
	_battle.begin(logic, style, kind)


func _on_battle_finished(logic: BattleLogic) -> void:
	_battle.queue_free()
	_battle = null
	if _quest_id != &"":
		var quest_outcome: StringName = AdventureRules.finish_quest_battle(logic, _quest_id)
		get_tree().paused = false
		EventBus.quest_battle_resolved.emit(_quest_id, quest_outcome)
		_quest_id = &""
		return
	var outcome: StringName = AdventureRules.finish_battle(logic, _bosque_id)
	# Apaciguar en combate (Luz u ofrenda) paga el paso (ADR 0010); vencer solo lo fuerza.
	var resolved: StringName = { &"victory": &"won", &"appeased": &"paid", &"defeat": &"defeated", &"game_over": &"game_over" }.get(outcome, &"fled")
	_close(resolved)


func _close(outcome: StringName) -> void:
	_panel.visible = false
	get_tree().paused = false
	EventBus.crossing_resolved.emit(_bosque_id, outcome)
