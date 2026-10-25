extends CanvasLayer
## Mapa de la región (tecla M, navegacion.md). Pausa el árbol (y con él WorldClock) y muestra la
## rejilla de chunks: los explorados con el color de hoja de su Bosque y el resto en niebla. Encima,
## los caminos principales vistos, la villa natal, las villas y refugios vistos, los Botarramas
## vistos (en su última posición; grises si su Bosque está abierto), el objetivo (si lo hay) y el
## jugador, que parpadea. Los Bosques explorados que no están sanos llevan una marca del color de
## su estado en la esquina de cada chunk (MapLogic.visible_states), con su fila en la leyenda. Se cierra con M o Esc. Este nodo sigue activo en pausa
## (process_mode ALWAYS). Solo lee GameState; qué se ve lo decide MapLogic.

## Lado de cada celda (un chunk) en píxeles. La región de 12×16 chunks ocupa 120×160.
const CELL: int = 10
const GRID_ORIGIN := Vector2(8, 15)
const LEGEND_ORIGIN := Vector2(142, 24)
const LEGEND_STEP: float = 13.0
const BLINK_TIME: float = 0.4
const FOG_COLOR := Color("262b44")
const ROAD_COLOR := Color("e8b796")
const HOME_COLOR := Color("feae34")
const VILLA_COLOR := Color("c0cbdc")
const REFUGE_COLOR := Color("b86f50")
const PLAYER_COLOR := Color("e43b44")
const OBJECTIVE_COLOR := Color("f6757a")
const MONSTER_COLOR := Color("b55088")
const MONSTER_PASSIVE_COLOR := Color("8b9bb4")
## Misión lejana (FarQuests): el Bosque que llama y su ruta de salvoconducto.
const FAR_QUEST_COLOR := Color("ffffff")
const FAR_ROUTE_COLOR := Color("2ce8f5")
## Marca de estado de Bosque (esquina superior derecha de cada chunk explorado).
const STATE_COLORS: Dictionary = {
	"enojado": Color("e43b44"), "corrupto": Color("b55088"), "muerto": Color("c0cbdc"), "necesita_ayuda": Color("f77622"),
}
const STATE_MARK: int = 3

var _bosques: BosqueMap
var _blink_on: bool = true
var _blink_left: float = BLINK_TIME
## Icono y texto de cada fila de la leyenda (la del objetivo solo si hay objetivo).
var _legend: Array[Dictionary] = []

@onready var _root: Control = $Root
@onready var _canvas: Control = $Root/Canvas
@onready var _title: Label = $Root/Title
@onready var _hint: Label = $Root/Hint
@onready var _legend_box: Control = $Root/Legend


func _ready() -> void:
	visible = false
	_canvas.draw.connect(_on_canvas_draw)
	_hint.text = Texts.get_text("map_close")


func is_open() -> bool:
	return visible


## Objetivo opcional en el mapa y en la brújula (lo usa la misión del Ofomni para su última
## posición conocida). Guarda en GameState; coord (-1, -1) lo quita.
func set_objective(coord: Vector2i, label: String, cell: Vector2i = Vector2i(-1, -1)) -> void:
	GameState.set_objective(coord, label, cell)
	if visible:
		_build_legend()
		_canvas.queue_redraw()


func open() -> void:
	if visible or get_tree().paused:
		return
	_bosques = MapLogic.current_bosques()
	var region: Dictionary = ChunkGenerator.load_region(GameState.region_id)
	_title.text = str(region.get("name", GameState.region_id))
	_build_legend()
	_blink_on = true
	_blink_left = BLINK_TIME
	visible = true
	get_tree().paused = true
	_canvas.queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed(&"open_map") or event.is_action_pressed(&"ui_cancel"):
			close()
		# Con el mapa abierto no pasa ninguna otra entrada al juego.
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"open_map") and not get_tree().paused:
		open()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_blink_left -= delta
	if _blink_left <= 0.0:
		_blink_left = BLINK_TIME
		_blink_on = not _blink_on
		_canvas.queue_redraw()


func _build_legend() -> void:
	_legend = [
		{ "icon": PixelIcons.HOUSE, "color": HOME_COLOR, "text": Texts.get_text("map_legend_home") },
		{ "icon": PixelIcons.HOUSE, "color": VILLA_COLOR, "text": Texts.get_text("map_legend_villa") },
		{ "icon": PixelIcons.REFUGE, "color": REFUGE_COLOR, "text": Texts.get_text("map_legend_refuge") },
		{ "icon": [] as Array[String], "color": ROAD_COLOR, "text": Texts.get_text("map_legend_road") },
		{ "icon": PixelIcons.PLAYER, "color": PLAYER_COLOR, "text": Texts.get_text("map_legend_player") },
		{ "icon": [] as Array[String], "color": FOG_COLOR, "text": Texts.get_text("map_legend_fog") },
	]
	var seen_states: Array = MapLogic.visible_states(_bosques, GameState.explored_chunks).values()
	for state: String in STATE_COLORS:
		if seen_states.has(state):
			_legend.append({ "icon": [] as Array[String], "color": STATE_COLORS[state], "mark": true,
					"text": Texts.get_text("map_legend_state_" + state) })
	if not GameState.seen_monsters.is_empty():
		_legend.append({ "icon": PixelIcons.MONSTER, "color": MONSTER_COLOR, "text": Texts.get_text("map_legend_botarramas") })
	if GameState.has_objective():
		var label: String = GameState.objective_label
		_legend.append({ "icon": PixelIcons.OBJECTIVE, "color": OBJECTIVE_COLOR,
				"text": label if not label.is_empty() else Texts.get_text("map_legend_objective") })
	if not FarQuests.active_quests().is_empty():
		_legend.append({ "icon": PixelIcons.OBJECTIVE, "color": FAR_QUEST_COLOR, "text": Texts.get_text("map_legend_far_quest") })
		_legend.append({ "icon": [] as Array[String], "color": FAR_ROUTE_COLOR, "route": true, "text": Texts.get_text("map_legend_far_route") })
	for child: Node in _legend_box.get_children():
		child.queue_free()
	for i: int in _legend.size():
		var row := Label.new()
		row.text = _legend[i].text
		row.position = Vector2(12, i * LEGEND_STEP - 1)
		_legend_box.add_child(row)


func _cell_rect(coord: Vector2i) -> Rect2:
	return Rect2(GRID_ORIGIN + Vector2(coord * CELL), Vector2(CELL - 1, CELL - 1))


func _cell_center(coord: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(coord * CELL) + Vector2(CELL / 2, CELL / 2)


func _on_canvas_draw() -> void:
	if _bosques == null:
		return
	var explored: Array[Vector2i] = GameState.explored_chunks
	var states: Dictionary = MapLogic.visible_states(_bosques, explored)
	# Rejilla: niebla o color de hoja del Bosque (con el tinte de su estado, como en el mundo).
	for y: int in _bosques.grid_size.y:
		for x: int in _bosques.grid_size.x:
			var c := Vector2i(x, y)
			var leaf: int = MapLogic.cell_leaf(_bosques, explored, c)
			var color: Color = FOG_COLOR if leaf < 0 else (PlaceholderTileset.LEAVES[leaf] as Array)[0]
			if states.has(c):
				color = PlaceholderTileset.state_color(color, states[c])
			_canvas.draw_rect(_cell_rect(c), color)
	# Caminos: del centro de cada celda vista hacia cada lado por el que sale.
	var roads: Dictionary = MapLogic.visible_roads(_bosques, explored)
	for c: Vector2i in roads:
		var center: Vector2 = _cell_center(c) - Vector2.ONE
		for side: Vector2i in roads[c]:
			var block := Rect2(center, Vector2(2, 2))
			_canvas.draw_rect(block.merge(Rect2(center + Vector2(side * (CELL / 2)), Vector2(2, 2))), ROAD_COLOR)
	for c: Vector2i in states:
		var r: Rect2 = _cell_rect(c)
		_canvas.draw_rect(Rect2(r.position + Vector2(r.size.x - STATE_MARK, 0), Vector2(STATE_MARK, STATE_MARK)), STATE_COLORS.get(states[c], FOG_COLOR))
	for c: Vector2i in MapLogic.visible_refuges(_bosques, explored):
		PixelIcons.draw(_canvas, PixelIcons.REFUGE, _cell_rect(c).position + Vector2(CELL - 6, CELL - 5), REFUGE_COLOR)
	for c: Vector2i in MapLogic.visible_villas(_bosques, explored):
		PixelIcons.draw_centered(_canvas, PixelIcons.HOUSE, _cell_center(c), VILLA_COLOR)
	for m: Dictionary in MapLogic.visible_monsters(_bosques, GameState.seen_monsters, AdventureRules.paid_bosques()):
		PixelIcons.draw(_canvas, PixelIcons.MONSTER, _cell_rect(m.chunk).position,
				MONSTER_PASSIVE_COLOR if m.passive else MONSTER_COLOR)
	var home: Vector2i = MapLogic.home_villa(_bosques)
	if home.x >= 0:
		PixelIcons.draw_centered(_canvas, PixelIcons.HOUSE, _cell_center(home), HOME_COLOR)
	_draw_far_quests()
	if GameState.has_objective():
		PixelIcons.draw_centered(_canvas, PixelIcons.OBJECTIVE, _cell_center(GameState.objective_chunk), OBJECTIVE_COLOR)
	if _blink_on and GameState.chunk_coord.x >= 0:
		PixelIcons.draw_centered(_canvas, PixelIcons.PLAYER, _cell_center(GameState.chunk_coord), PLAYER_COLOR)
	_draw_legend_icons()


## Rutas de salvoconducto (línea de chunk en chunk, de Nujio a Nujio) y el objetivo de cada misión
## lejana activa, con su propia marca. Se ven aunque estén en la niebla: llegaron en Pensamiento.
func _draw_far_quests() -> void:
	for q: Dictionary in FarQuests.active_quests():
		var path: Array[Vector2i] = FarQuests.map_path(_bosques, q)
		for i: int in range(1, path.size()):
			_canvas.draw_line(_cell_center(path[i - 1]) - Vector2(0.5, 0.5), _cell_center(path[i]) - Vector2(0.5, 0.5), FAR_ROUTE_COLOR, 1.0)
		for id: int in FarQuests.route_of(q):
			var c: Vector2 = _cell_center(_bosques.nujio_chunk[id]) - Vector2.ONE
			_canvas.draw_rect(Rect2(c, Vector2(2, 2)), FAR_ROUTE_COLOR)
		PixelIcons.draw_centered(_canvas, PixelIcons.OBJECTIVE, _cell_center(FarQuests.target_chunk(q)), FAR_QUEST_COLOR)


func _draw_legend_icons() -> void:
	for i: int in _legend.size():
		var center: Vector2 = LEGEND_ORIGIN + Vector2(4, i * LEGEND_STEP + 4)
		var entry: Dictionary = _legend[i]
		var icon: Array[String] = []
		icon.assign(entry.icon)
		if not icon.is_empty():
			PixelIcons.draw_centered(_canvas, icon, center, entry.color)
		elif bool(entry.get("route", false)):
			_canvas.draw_line(center + Vector2(-4, 0), center + Vector2(4, 0), FAR_ROUTE_COLOR, 1.0)
		elif bool(entry.get("mark", false)):
			_canvas.draw_rect(Rect2(center - Vector2(4, 4), Vector2(CELL - 1, CELL - 1)), Color("3e8948"))
			_canvas.draw_rect(Rect2(center + Vector2(CELL - 5 - STATE_MARK, -4), Vector2(STATE_MARK, STATE_MARK)), entry.color)
		elif entry.color == ROAD_COLOR:
			_canvas.draw_rect(Rect2(center + Vector2(-4, -1), Vector2(9, 2)), ROAD_COLOR)
		else:
			_canvas.draw_rect(Rect2(center - Vector2(4, 4), Vector2(CELL - 1, CELL - 1)), entry.color)
