extends CanvasLayer
## Mapa de la región (tecla M, navegacion.md). Pausa el árbol (y con él WorldClock) y muestra la
## vista de la región del RegionPlan de la exploración (MapLogic.region_plan; ADR 0014 §7, M16):
## altura, agua, caminos y límites de Bosque (la imagen se genera una vez por plan), con niebla
## translúcida sobre los chunks no explorados. Encima, las villas, aldeas y lugares vistos con su
## nombre (fuente de 3×5), los refugios vistos, los Botarramas vistos (en su última posición; grises
## si su Bosque está abierto), el objetivo (si lo hay) y el jugador, que parpadea. Los Bosques
## explorados que no están sanos llevan una marca del color de su estado en la esquina de cada chunk
## (MapLogic.visible_states), con su fila en la leyenda. Se cierra con M o Esc. Este nodo sigue
## activo en pausa (process_mode ALWAYS). Solo lee GameState; qué se ve lo decide MapLogic.

## Lado de cada celda (un chunk) en píxeles. La región de 12×16 chunks ocupa 120×160.
const CELL: int = MapLogic.PX_PER_CHUNK
const GRID_ORIGIN := Vector2(8, 15)
const LEGEND_ORIGIN := Vector2(142, 24)
const LEGEND_STEP: float = 13.0
## Filas de la leyenda por columna; con más, se reparte en dos columnas de LEGEND_COLUMN px.
const LEGEND_ROWS: int = 9
const LEGEND_COLUMN: float = 88.0
const BLINK_TIME: float = 0.4
const FOG_COLOR := Color("262b44")
## Niebla de la vista de la región: deja ver muy apagada la forma del valle.
const FOG_ALPHA: float = 0.85
const ROAD_COLOR := Color("e8b796")
const HOME_COLOR := Color("feae34")
const VILLA_COLOR := Color("c0cbdc")
const ALDEA_COLOR := Color("f77622")
const PLACE_COLOR := Color("ffffff")
const WATER_LABEL_COLOR := Color("2ce8f5")
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
## Color del rótulo por tipo de lugar (vista de la región).
const LABEL_COLORS: Dictionary = {
	"villa_natal": HOME_COLOR, "villa": VILLA_COLOR, "ciudad": VILLA_COLOR, "aldea": ALDEA_COLOR, "lugar": WATER_LABEL_COLOR,
	"tarca": PLACE_COLOR, "hito": PLACE_COLOR,
}

var _bosques: BosqueMap
var _plan: RegionPlan
## Vista de la región del plan (_texture_plan): se rehace solo si cambia el plan.
var _texture: ImageTexture
var _texture_plan: RegionPlan
var _places: Array[Dictionary] = []
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
	_plan = MapLogic.region_plan()
	_bosques = MapLogic.current_bosques()
	if _plan != null and _texture_plan != _plan:
		_texture = ImageTexture.create_from_image(MapLogic.region_image(_plan))
		_places = MapLogic.region_places(_plan)
		_texture_plan = _plan
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
	]
	var seen_kinds: Dictionary = {}
	for p: Dictionary in MapLogic.visible_places(_places, GameState.explored_chunks):
		seen_kinds[p.kind] = true
	if seen_kinds.has("aldea"):
		_legend.append({ "icon": PixelIcons.ALDEA, "color": ALDEA_COLOR, "text": Texts.get_text("map_legend_aldea") })
	_legend.append({ "icon": PixelIcons.REFUGE, "color": REFUGE_COLOR, "text": Texts.get_text("map_legend_refuge") })
	_legend.append({ "icon": [] as Array[String], "color": ROAD_COLOR, "text": Texts.get_text("map_legend_road") })
	_legend.append({ "icon": [] as Array[String], "color": MapLogic.WATER_COLORS[RegionAuthoring.Water.RIVER_NAVIGABLE],
			"text": Texts.get_text("map_legend_water") })
	_legend.append({ "icon": [] as Array[String], "color": MapLogic.BORDER_COLOR, "border": true,
			"text": Texts.get_text("map_legend_border") })
	if seen_kinds.has("lugar") or seen_kinds.has("tarca") or seen_kinds.has("hito") or seen_kinds.has("manantial"):
		_legend.append({ "icon": PixelIcons.PLACE, "color": PLACE_COLOR, "text": Texts.get_text("map_legend_place") })
	_legend.append({ "icon": PixelIcons.PLAYER, "color": PLAYER_COLOR, "text": Texts.get_text("map_legend_player") })
	_legend.append({ "icon": [] as Array[String], "color": FOG_COLOR, "text": Texts.get_text("map_legend_fog") })
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
		row.position = _legend_offset(i) + Vector2(12, -1)
		_legend_box.add_child(row)


## Esquina de la fila `i` de la leyenda (relativa a la caja): una columna hasta LEGEND_ROWS filas.
func _legend_offset(i: int) -> Vector2:
	var rows: int = LEGEND_ROWS if _legend.size() > LEGEND_ROWS else _legend.size()
	@warning_ignore("integer_division")
	var rows_per_col: int = maxi(rows, (_legend.size() + 1) / 2)
	@warning_ignore("integer_division")
	return Vector2((i / rows_per_col) * LEGEND_COLUMN, (i % rows_per_col) * LEGEND_STEP)


func _cell_rect(coord: Vector2i) -> Rect2:
	return Rect2(GRID_ORIGIN + Vector2(coord * CELL), Vector2(CELL - 1, CELL - 1))


func _cell_center(coord: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(coord * CELL) + Vector2(CELL / 2, CELL / 2)


func _on_canvas_draw() -> void:
	if _bosques == null or _plan == null:
		return
	var explored: Array[Vector2i] = GameState.explored_chunks
	var states: Dictionary = MapLogic.visible_states(_bosques, explored)
	_draw_region_view(explored)
	for c: Vector2i in states:
		var r: Rect2 = _cell_rect(c)
		_canvas.draw_rect(Rect2(r.position + Vector2(r.size.x - STATE_MARK, 0), Vector2(STATE_MARK, STATE_MARK)), STATE_COLORS.get(states[c], FOG_COLOR))
	for c: Vector2i in MapLogic.visible_refuges(_bosques, explored):
		PixelIcons.draw(_canvas, PixelIcons.REFUGE, _cell_rect(c).position + Vector2(CELL - 6, CELL - 5), REFUGE_COLOR)
	_draw_places(explored)
	for m: Dictionary in MapLogic.visible_monsters(_bosques, GameState.seen_monsters, AdventureRules.paid_bosques()):
		PixelIcons.draw(_canvas, PixelIcons.MONSTER, _cell_rect(m.chunk).position,
				MONSTER_PASSIVE_COLOR if m.passive else MONSTER_COLOR)
	_draw_far_quests()
	if GameState.has_objective():
		PixelIcons.draw_centered(_canvas, PixelIcons.OBJECTIVE, _cell_center(GameState.objective_chunk), OBJECTIVE_COLOR)
	if _blink_on and GameState.chunk_coord.x >= 0:
		PixelIcons.draw_centered(_canvas, PixelIcons.PLAYER, _cell_center(GameState.chunk_coord), PLAYER_COLOR)
	_draw_legend_icons()


## Vista de la región (imagen del plan) con niebla translúcida en los chunks sin explorar.
func _draw_region_view(explored: Array[Vector2i]) -> void:
	_canvas.draw_texture(_texture, GRID_ORIGIN)
	var fog := Color(FOG_COLOR, FOG_ALPHA)
	for y: int in _plan.size_chunks.y:
		for x: int in _plan.size_chunks.x:
			var c := Vector2i(x, y)
			if not explored.has(c):
				_canvas.draw_rect(Rect2(GRID_ORIGIN + Vector2(MapLogic.chunk_to_map_px(c)), Vector2(CELL, CELL)), fog)


## Villas, aldeas y lugares vistos, en su posición exacta, con su rótulo.
func _draw_places(explored: Array[Vector2i]) -> void:
	var seen: Array[Dictionary] = MapLogic.visible_places(_places, explored)
	for p: Dictionary in seen:
		var at: Vector2 = GRID_ORIGIN + Vector2(p.px as Vector2i)
		match String(p.kind):
			"villa_natal":
				PixelIcons.draw_centered(_canvas, PixelIcons.HOUSE, at, HOME_COLOR)
			"villa", "ciudad":
				PixelIcons.draw_centered(_canvas, PixelIcons.HOUSE, at, VILLA_COLOR)
			"aldea":
				PixelIcons.draw_centered(_canvas, PixelIcons.ALDEA, at, ALDEA_COLOR)
			_:
				PixelIcons.draw_centered(_canvas, PixelIcons.PLACE, at, LABEL_COLORS.get(p.kind, PLACE_COLOR))
	var bounds := Rect2i(Vector2i.ZERO, _plan.size_chunks * CELL)
	for l: Dictionary in MapLogic.layout_labels(seen, bounds):
		PixelFont.draw(_canvas, l.text, GRID_ORIGIN + Vector2(l.at as Vector2i), LABEL_COLORS.get(l.kind, PLACE_COLOR))


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
		var center: Vector2 = LEGEND_ORIGIN + _legend_offset(i) + Vector2(4, 4)
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
		elif bool(entry.get("border", false)):
			_canvas.draw_rect(Rect2(center - Vector2(4, 4), Vector2(CELL - 1, CELL - 1)), MapLogic.HEIGHT_COLORS[1])
			_canvas.draw_rect(Rect2(center + Vector2(0, -4), Vector2(1, CELL - 1)), entry.color)
		elif entry.color == ROAD_COLOR:
			_canvas.draw_rect(Rect2(center + Vector2(-4, -1), Vector2(9, 2)), ROAD_COLOR)
		else:
			_canvas.draw_rect(Rect2(center - Vector2(4, 4), Vector2(CELL - 1, CELL - 1)), entry.color)
