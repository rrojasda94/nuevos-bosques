extends CanvasLayer
## Menú del borde de un Bosque cerrado (ADR 0009): pagar Luz al Nujio, enfrentar a su Único o
## retroceder. Mientras está abierto (o dura el combate) el árbol se pausa; este nodo y el combate
## siguen activos (process_mode ALWAYS). Al terminar emite EventBus.crossing_resolved y la
## exploración cruza, retrocede o despierta al Adoc en el Nujio inicial.
## Solo escucha EventBus y lee GameState: no conoce la escena de exploración.

const BATTLE_SCENE: PackedScene = preload("res://scenes/rpg/battle.tscn")
## Texto de placeholder; lo revisa narrative-writer.
const TITLE: String = "El Bosque te observa. Su Nujio exige Luz."

var _bosque_id: int = -1
var _cost: int = 0
var _distance: int = 0
var _map: BosqueMap
var _map_key: String = ""
var _battle: Node

@onready var _panel: Control = $Panel
@onready var _title: Label = $Panel/Title
@onready var _options: OptionMenu = $Panel/Options


func _ready() -> void:
	_panel.visible = false
	EventBus.bosque_border_reached.connect(_on_bosque_border_reached)


func _on_bosque_border_reached(bosque_id: int) -> void:
	if bosque_id < 0 or _panel.visible or _battle != null:
		return
	var region: Dictionary = ChunkGenerator.load_region(GameState.region_id)
	_ensure_map(region)
	var home: int = AdventureRules.home_bosque(_map, region)
	if AdventureRules.is_passable(bosque_id, home):
		return
	_bosque_id = bosque_id
	_distance = maxi(1, _map.distance(home, bosque_id))
	_cost = AdventureRules.toll_cost(_distance)
	_title.text = TITLE
	var texts: Array[String] = [
		"Ofrecer %d Luz (tienes %d)" % [_cost, GameState.luz],
		"Enfrentar a sus Únicos",
		"Retroceder",
	]
	var enabled: Array[bool] = [GameState.luz >= _cost, true, true]
	_options.set_options(texts, enabled)
	_panel.visible = true
	get_tree().paused = true


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
	match _options.handle(event):
		0:
			if AdventureRules.pay_toll(_bosque_id, _cost):
				_close(&"paid")
		1:
			_start_battle()
		2, OptionMenu.CANCEL:
			_close(&"retreated")


func _start_battle() -> void:
	_panel.visible = false
	var style: Dictionary = _map.styles[_bosque_id]
	var tree_name: String = PlaceholderTileset.SHAPE_NAMES[int(style.shape)]
	var logic: BattleLogic = AdventureRules.start_battle(_bosque_id, _distance, tree_name)
	_battle = BATTLE_SCENE.instantiate()
	add_child(_battle)
	_battle.finished.connect(_on_battle_finished)
	_battle.begin(logic, style)


func _on_battle_finished(logic: BattleLogic) -> void:
	_battle.queue_free()
	_battle = null
	var outcome: StringName = AdventureRules.finish_battle(logic, _bosque_id)
	var resolved: StringName = { &"victory": &"won", &"defeat": &"defeated" }.get(outcome, &"fled")
	_close(resolved)


func _close(outcome: StringName) -> void:
	_panel.visible = false
	get_tree().paused = false
	EventBus.crossing_resolved.emit(_bosque_id, outcome)
