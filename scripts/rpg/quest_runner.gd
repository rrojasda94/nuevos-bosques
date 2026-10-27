class_name QuestRunner
extends Node
## Lleva la misión del Ofomni en la exploración (mision-ofomni.md): la ofrece al empezar, mueve al
## Ofomni con el reloj de Aventura (se para con la pausa del árbol), actualiza el objetivo de la
## brújula y del mapa en cada riutash, aplica el fracaso al llegar a la villa natal y lleva la
## charla con el sfida (pregunta "Acepto" / "Aún no" y recompensa). Las reglas están en QuestLogic
## y AdventureRules; los textos, en data/quests/primera_mision.json.

## Se emite cuando el Ofomni cambia de Bosque, aparece o desaparece (la exploración lo coloca).
signal ofomni_changed

const QUEST: StringName = QuestLogic.PRIMERA_MISION
## Espera antes del aviso del Nujio, para no pisar el aviso del cambio de Momento del HUD.
const HEARS_NOTICE_DELAY: float = 3.2

var _dialogue: DialogueBox
var _region_map: Node
var _bosques: BosqueMap
var _home: int = -1
## Chunk de la villa natal: WorldChunk (Mundo 2.0) o ChunkData (exploración vieja, hasta M17b).
var _villa: Object


func setup(dialogue: DialogueBox, region_map: Node) -> void:
	_dialogue = dialogue
	_region_map = region_map
	EventBus.riutash_passed.connect(_on_riutash_passed)
	EventBus.npc_talked.connect(_on_npc_talked)
	EventBus.quest_battle_resolved.connect(_on_quest_battle_resolved)


## Partida nueva o cargada. Sin misión guardada, la ofrece y la brújula apunta al sfida.
func start(bosques: BosqueMap, home: int, villa: Object) -> void:
	_bosques = bosques
	_home = home
	_villa = villa
	if not GameState.quests.has(QUEST):
		QuestLogic.commit(QUEST, QuestLogic.new_quest(), &"")
		_point_to_sfida()
	ofomni_changed.emit()


func quest() -> Dictionary:
	return GameState.quests.get(QUEST, {})


## Chunk donde está ahora el Ofomni, o (-1, -1) si no está en el mundo.
func ofomni_chunk() -> Vector2i:
	var q: Dictionary = quest()
	if q.is_empty() or not QuestLogic.ofomni_present(q):
		return Vector2i(-1, -1)
	return QuestLogic.ofomni_chunk(_bosques, int(q.ofomni_bosque), _home)


func _process(delta: float) -> void:
	advance_time(delta)


## La misión está activa: el Ofomni descarriado avanza con el reloj (también mientras duermes).
func is_ofomni_active() -> bool:
	return QuestLogic.state_of(quest()) == QuestLogic.ACTIVE


## Avanza al Ofomni `seconds` segundos de reloj: cada frame y, de golpe, al dormir (SleepRules).
## Si llega a la villa natal, la misión falla y la villa queda dañada.
func advance_time(seconds: float) -> void:
	var q: Dictionary = quest()
	if _bosques == null or QuestLogic.state_of(q) != QuestLogic.ACTIVE:
		return
	var every: float = float(QuestLogic.data(QUEST).ofomni.advance_seconds)
	var moves: int = QuestLogic.advance(q, seconds, _bosques, GameState.seed_value, _home, every)
	QuestLogic.commit(QUEST, q, QuestLogic.ACTIVE)
	if QuestLogic.state_of(q) == QuestLogic.FAILED:
		AdventureRules.damage_villa(float(QuestLogic.data(QUEST).ofomni.failed_luz_factor))
		_set_objective(QuestLogic.ofomni_chunk(_bosques, _home, _home), Texts.get_text("compass_ofomni_descarriado"))
		EventBus.notice_requested.emit(Texts.get_text("villa_damaged"))
	if moves > 0:
		ofomni_changed.emit()


## En cada riutash el Nujio vuelve a oír al Ofomni: objetivo y aviso con la dirección.
func _on_riutash_passed(_sheltered: bool) -> void:
	if QuestLogic.state_of(quest()) != QuestLogic.ACTIVE:
		return
	var chunk: Vector2i = ofomni_chunk()
	_set_objective(chunk, Texts.get_text("compass_ofomni_descarriado"))
	var text: String = str(QuestLogic.data(QUEST).texts.nujio_hears.text) % ChunkGenerator.direction_name(chunk - GameState.chunk_coord)
	await get_tree().create_timer(HEARS_NOTICE_DELAY).timeout
	EventBus.notice_requested.emit(text)


## Efectos de hablar con el sfida. Las líneas ya las eligió NpcDialogue.lines_for.
func _on_npc_talked(npc_id: StringName) -> void:
	var data: Dictionary = QuestLogic.data(QUEST)
	if npc_id != StringName(str(data.giver)):
		return
	var q: Dictionary = quest()
	match QuestLogic.state_of(q):
		QuestLogic.OFFERED:
			_dialogue.finished.connect(_ask_accept, CONNECT_ONE_SHOT)
		QuestLogic.COMPLETED:
			# Con la bolsa llena, el sfida guarda la recompensa hasta que vuelvas con sitio.
			if not AdventureRules.can_take_reward(data.get("reward", {})):
				EventBus.notice_requested.emit(Texts.get_text("bag_full"))
				return
			# La misión del sfida es para la villa natal: la relación con el Bosque natal sube.
			AdventureRules.apply_quest_reward(QuestLogic.claim_reward(q, QUEST), _home)
			QuestLogic.commit(QUEST, q, QuestLogic.COMPLETED)
			EventBus.notice_requested.emit(Texts.get_text("fama_gained"))
			_set_objective(Vector2i(-1, -1), "")
		QuestLogic.FAILED:
			q.failed_told = true
			if bool(q.target_defeated):
				_set_objective(Vector2i(-1, -1), "")
			QuestLogic.commit(QUEST, q, QuestLogic.FAILED)


func _ask_accept() -> void:
	var prompt: Dictionary = QuestLogic.data(QUEST).texts.accept_prompt
	var options: Array = []
	for o: Dictionary in prompt.options:
		options.append(o.text)
	_dialogue.choice.connect(_on_accept_choice, CONNECT_ONE_SHOT)
	_dialogue.ask({ "speaker": prompt.speaker, "text": prompt.text }, options)


func _on_accept_choice(index: int) -> void:
	var data: Dictionary = QuestLogic.data(QUEST)
	var q: Dictionary = quest()
	if index == 0 and QuestLogic.accept(q, _bosques, GameState.seed_value, _home):
		QuestLogic.commit(QUEST, q, QuestLogic.OFFERED)
		_set_objective(ofomni_chunk(), Texts.get_text("compass_ofomni_descarriado"))
		ofomni_changed.emit()
		_dialogue.show_lines(data.texts.accepted.lines)
		return
	q.declined = true
	QuestLogic.commit(QUEST, q, QuestLogic.OFFERED)
	_dialogue.show_lines(data.texts.declined.lines)


func _on_quest_battle_resolved(quest_id: StringName, outcome: StringName) -> void:
	if quest_id != QUEST or outcome != &"victory":
		return
	_point_to_sfida()
	ofomni_changed.emit()
	_dialogue.show_lines(QuestLogic.data(QUEST).texts.victory_battle.lines)


func _point_to_sfida() -> void:
	var cell := Vector2i(-1, -1)
	if _villa is WorldChunk:
		cell = Npc.sfida_cell_world(_villa)
	elif _villa is ChunkData:
		cell = Npc.sfida_cell(_villa)
	_set_objective(_bosques.nujio_chunk[_home], Texts.get_text("compass_sfida"), cell)


func _set_objective(coord: Vector2i, label: String, cell: Vector2i = Vector2i(-1, -1)) -> void:
	if _region_map != null:
		_region_map.set_objective(coord, label, cell)
	else:
		GameState.set_objective(coord, label, cell)
