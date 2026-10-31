class_name FarQuestRunner
extends Node
## Lleva las misiones lejanas en la exploración (FarQuests, bosques-y-relacion.md, #136): tras
## dormir de noche decide si hay visión de Pensamiento y su texto, pregunta "Acudir" / "Dejarlo
## pasar" y crea la misión con su ruta de salvoconducto; recalcula la ruta al salir de ella o si uno
## de sus Bosques deja de ser bueno; y cumple o falla la misión cuando toca (relación, fama y Luz).
## La brújula y el mapa leen GameState.far_quests directamente. Las reglas están en FarQuests; los
## textos, en data/text/sistema.json.

var _dialogue: DialogueBox
var _bosques: BosqueMap
var _home: int = -1
## Callable(chunk: Vector2i) -> WorldChunk, para comprobar que un incendio arde de verdad.
var _chunk_at: Callable = Callable()


func setup(dialogue: DialogueBox) -> void:
	_dialogue = dialogue
	EventBus.bosque_entered.connect(_on_bosque_entered)
	EventBus.bosque_state_changed.connect(func(_id: int, _state: String) -> void: _refresh_routes())
	EventBus.bosque_relation_changed.connect(func(_id: int, _relation: int) -> void: _refresh_routes())


func start(bosques: BosqueMap, home: int, chunk_at: Callable = Callable()) -> void:
	_bosques = bosques
	_home = home
	_chunk_at = chunk_at


## Visión tras dormir de noche el día `day` en el Bosque `from_bosque` ({} si no hay). La anota en
## GameState.last_vision_day. Una sola por día.
func vision_after_sleep(day: int, from_bosque: int) -> Dictionary:
	if _bosques == null or GameState.last_vision_day == day:
		return {}
	var has_fire: Callable = Callable()
	if _chunk_at.is_valid():
		has_fire = func(c: Vector2i) -> bool:
			var id: int = _bosques.bosque_at(c)
			return not BosqueFires.fire_cells(_chunk_at.call(c), GameState.seed_value, BosqueStates.state_of(id, _bosques), true).is_empty()
	var vision: Dictionary = FarQuests.vision_for(_bosques, GameState.seed_value, day, from_bosque, has_fire)
	if not vision.is_empty():
		GameState.last_vision_day = day
		vision.day = day
		vision.from = from_bosque
	return vision


## Texto de la visión: qué pasa, a cuántos Bosques y hacia dónde.
func vision_text(vision: Dictionary) -> String:
	var key: String = "pensamiento_vision_fire"
	if str(vision.type) == FarQuests.TYPE_REPAREP:
		var corrupt: bool = BosqueStates.state_of(int(vision.bosque), _bosques) == BosqueStates.CORRUPTO
		key = "pensamiento_vision_corrupto" if corrupt else "pensamiento_vision_reparep"
	var dir: String = ChunkGenerator.direction_name((vision.target_chunk as Vector2i) - GameState.chunk_coord)
	return Texts.get_text(key) % [int(vision.hops), dir]


## Pregunta si se acude a la llamada; si sí, crea la misión con su ruta.
func offer(vision: Dictionary) -> void:
	_dialogue.choice.connect(_on_offer_choice.bind(vision), CONNECT_ONE_SHOT)
	_dialogue.ask(Texts.get_text("far_quest_prompt"), [Texts.get_text("far_quest_accept"), Texts.get_text("far_quest_decline")])


func _on_offer_choice(index: int, vision: Dictionary) -> void:
	if index != 0:
		_dialogue.show_lines([Texts.get_text("far_quest_declined")])
		return
	var here: int = _bosques.bosque_at(GameState.chunk_coord)
	var q: Dictionary = accept(vision, here)
	if q.is_empty():
		return
	var lines: Array = [Texts.get_text("far_quest_accepted")]
	lines.append(Texts.get_text("far_quest_route" if FarQuests.route_of(q).size() > 1 else "far_quest_no_route"))
	_dialogue.show_lines(lines)


## Acepta la visión desde el Bosque `from_bosque` (también lo usan los tests).
func accept(vision: Dictionary, from_bosque: int) -> Dictionary:
	return FarQuests.accept(_bosques, vision, from_bosque, int(vision.get("day", GameState.day)))


func _process(_delta: float) -> void:
	if _bosques == null or (_dialogue != null and _dialogue.is_open()):
		return
	check()


## Cumple o falla las misiones activas. Devuelve las líneas que se han mostrado (vacío si nada).
func check() -> Array:
	var lines: Array = []
	for q: Dictionary in FarQuests.active_quests():
		if FarQuests.is_accomplished(q):
			var got: Dictionary = FarQuests.complete(q)
			lines.append(Texts.get_text("far_quest_done") % [int(got.relation), int(got.fama), int(got.luz)])
			lines.append(Texts.get_text("far_quest_safe_conduct_ends"))
		elif FarQuests.has_failed(q, _bosques):
			FarQuests.fail(q)
			lines.append(Texts.get_text("far_quest_failed"))
			lines.append(Texts.get_text("far_quest_safe_conduct_ends"))
	if not lines.is_empty() and _dialogue != null:
		_dialogue.show_lines(lines)
	return lines


func _on_bosque_entered(_bosque_id: int, _state: String) -> void:
	_refresh_routes()


## Recalcula las rutas que ya no sirven desde el Bosque actual y lo avisa.
func _refresh_routes() -> void:
	if _bosques == null or GameState.chunk_coord.x < 0:
		return
	var here: int = _bosques.bosque_at(GameState.chunk_coord)
	var changed: bool = false
	for q: Dictionary in FarQuests.active_quests():
		changed = FarQuests.refresh_route(_bosques, q, here) or changed
	if changed:
		EventBus.notice_requested.emit(Texts.get_text("far_quest_route_changed"))
