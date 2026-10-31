class_name WorldExploration
extends Node2D
## Exploración del modo Aventura en el Mundo 2.0 (ADR 0014; M17a). Sustituye en el juego a la
## exploración vieja (exploration.gd, borrada en M17b):
## - El mundo es una WorldView (`standalone = false`): RegionPlan + WorldCache + WorldPregen con la
##   pantalla "Creando el mundo…" al crear o cargar la partida, y luego mundo continuo sin
##   fundidos. El jugador es un PlayerController con GridMover y aparece en su villa natal.
## - Todas las reglas cuelgan de `cell_changed` del jugador: chunk entrado (EventBus.chunk_entered,
##   chunks explorados), Bosque entrado (estado, arma, colarse, frutos sacados, persecuciones),
##   letreros (se leen al pasar junto a ellos), descanso en la villa y confinamiento de la primera
##   misión.
## - E (Interaction.find_world): sfida, letreros, refugios (dormir, registrar), frutales 2×2,
##   Nujio (ofrendas, dormir) y descanso en la villa; delante de un Único, enfrentarse a él.
## - Límite de Bosque (BosqueBorder): una casilla de otro Bosque cerrado bloquea; al chocar se abre
##   el menú del cruce (Crossing) y acude el Botarramas más cercano (MonsterField.summon_nearest).
##   Si al tocarlo nadie te ve, te cuelas sin menú; si te ve otro Único, te persigue; con E
##   contra el límite, el menú (Stealth.border_outcome, P3). Q enfunda o saca el arma.
## - Monstruos (MonsterField en modo mundo): encuentro -> el mismo flujo que la exploración vieja
##   (_on_field_engaged / _on_monster_engaged / _confront, aperturas del combate táctico T6),
##   derrota y reaparición junto a un Nujio, persecución tras un robo, cazadores del Bosque,
##   captores de la primera misión y el Ofomni descarriado de la misión.
## - Riutash, luz de luna, destello, HUD, brújula (MapLogic.player_pos) y mapa M
##   (MapLogic.set_region_plan).
## - Guardado rápido: F5 guarda en el slot 1 y F9 lo carga (partidas del mundo viejo: aviso).
## Pendiente para M17b o después (ver el PR): interior de las sicabis (E en la boca: texto
## provisional), incendios de Bosque (BosqueFires), encuentros con
## otros adoc (AdocEncounters) y el recoloreado por Bosque del arte del mundo.

## Slot del guardado rápido.
const QUICK_SLOT: int = 1
## Slot que usan F5 y F9 (los tests usan otro).
var quick_slot: int = QUICK_SLOT
## Dónde espera el Ofomni en la villa natal tras llegar: casillas al sur del hub.
const OFOMNI_VILLA_OFFSET := Vector2i(0, 12)
## Espera del aviso de relación y peaje tras el riutash (como en la exploración vieja).
const RIUTASH_RELATION_NOTICE_DELAY: float = 6.4
## Fundido al aparecer (partida nueva, carga, reaparición).
const FADE_IN_TIME: float = 0.3
const NO_CHUNK := Vector2i(-99999, -99999)

var plan: RegionPlan
var bosques: BosqueMap
var home_bosque: int = -1
## Hay mundo y jugador colocados (false mientras se crea el mundo).
var started: bool = false
## Chunk de los pies del jugador.
var chunk_coord: Vector2i = NO_CHUNK

var _border: BosqueBorder
var _field: MonsterField
## NPC: id -> world_pos (Interaction.find_world) y casillas que bloquean.
var _npcs: Dictionary = {}
var _npc_cells: Dictionary = {}
var _npc_nodes: Array[Node] = []
## P5: trueque con el Sarua y el Paruas (TradeDialog, reglas en Trade) y chunk de su villa.
var _trade: TradeDialog
var _trade_villa: Vector2i = Vector2i(-1, -1)
var _last_cell: Vector2i = NO_CHUNK
var _last_bosque: int = -1
var _resting: bool = false
var _pending_monster: OverworldMonster
var _chase := OfomniGuard.new()
var _capturing: bool = false
var _hunt := BosqueHunt.new()
var _entry_notices: PackedStringArray = []
var _theft_unseen: bool = false
var _ofomni_chunk: Vector2i = NO_CHUNK
## Lleva un arranque en curso (start() es una corrutina).
var _starting: bool = false

@onready var world: WorldView = $World
@onready var player: PlayerController = $World/Objects/Player
@onready var _quest: QuestRunner = $QuestRunner
@onready var _far: FarQuestRunner = $FarQuestRunner
@onready var _sleep_screen: SleepScreen = $SleepScreen
@onready var _region_map: Node = $RegionMap
@onready var _dialogue: DialogueBox = $Dialogue/DialogueBox
@onready var _crossing: Node = $Crossing
@onready var _fade: ColorRect = $Transition/Fade


func _ready() -> void:
	player.cell_changed.connect(_on_cell_changed)
	EventBus.crossing_resolved.connect(_on_crossing_resolved)
	EventBus.quest_battle_resolved.connect(_on_quest_battle_resolved)
	EventBus.unico_battle_resolved.connect(_on_unico_battle_resolved)
	EventBus.bosque_robbed.connect(_on_bosque_robbed)
	EventBus.bosque_state_changed.connect(_on_bosque_state_changed)
	EventBus.item_equipped.connect(_on_equipment_changed)
	EventBus.item_unequipped.connect(_on_equipment_changed)
	_field = MonsterField.new()
	_field.name = &"Monsters"
	_field.y_sort_enabled = true
	world.objects.add_child(_field)
	_field.world_player = player
	_field.can_engage = func() -> bool: return started and _fade.color.a <= 0.0
	_field.engaged.connect(_on_field_engaged)
	_field.is_hidden = _is_hidden
	_field.spotted.connect(_on_monster_spotted)
	_quest.setup(_dialogue, _region_map)
	_trade = TradeDialog.new(_dialogue)
	_quest.ofomni_changed.connect(_sync_ofomni)
	_far.setup(_dialogue)
	# Combate táctico: el tablero sale del relieve real alrededor del encuentro (WorldQuery.rect).
	_crossing.world_get_chunk = func(c: Vector2i) -> WorldChunk:
		return world.streamer.chunk(c) if world.streamer != null else null
	_crossing.world_player_cell = func() -> Vector2i: return player.mover.cell
	_setup_riutash()


## Arranca la exploración con el estado actual de GameState (partida nueva o cargada): crea el
## mundo (o reutiliza el de la misma seed) y coloca al jugador. Corrutina.
func start() -> void:
	if _starting:
		return
	_starting = true
	started = false
	player.input_enabled = false
	_fade.color.a = 1.0
	if GameState.region_id == &"":
		GameState.region_id = &"valle_del_sara"
	world.region_id = GameState.region_id
	await world.build_world(GameState.seed_value)
	plan = world.plan
	MapLogic.set_region_plan(plan)
	bosques = plan.bosques
	home_bosque = plan.bosque_at(plan.home_chunk)
	GameState.world_key = WorldCache.key_to_name(world.world_key)
	_border = BosqueBorder.new(BosqueBorder.plan_bosque_at(plan), _is_closed)
	_border.contacted.connect(_on_border_contacted)
	# P3 (colarse): quién te ve al tocar el borde lo decide Stealth.border_outcome.
	_border.decide = _border_outcome
	_border.sneaked.connect(_on_border_sneaked)
	_border.seen.connect(_on_border_seen)
	player.is_blocked = _border.blocks(_terrain_blocked)
	_on_equipment_changed(&"", &"")
	_field.terrain_blocked = world.streamer.is_blocked
	_field.area_walkable = func(c: Vector2i) -> bool: return not world.streamer.is_blocked(c) and not _npc_cells.has(c)
	_field.populate_world(plan, home_bosque, world.streamer.chunk)
	_chase.clear()
	_hunt.clear()
	_capturing = false
	_entry_notices.clear()
	_last_bosque = -1
	_ofomni_chunk = NO_CHUNK
	_pending_monster = null
	var villa: WorldChunk = world.pregen.get_chunk(bosques.nujio_chunk[home_bosque])
	_place_npcs(villa)
	_quest.start(bosques, home_bosque, villa)
	_far.start(bosques, home_bosque)
	var start_cell: Vector2i = _saved_cell()
	if start_cell == NO_CHUNK:
		start_cell = _home_villa_cell()
	_place(start_cell)
	if _moon_tween != null:
		_moon_tween.kill()
	_set_moonlight(1.0 if WorldClock.is_night() else 0.0)
	_starting = false


## Casilla global guardada (chunk_coord + player_cell), o NO_CHUNK si no hay o cae en un Bosque que
## ya no se puede cruzar (entonces se aparece en la villa natal, como en la exploración vieja).
func _saved_cell() -> Vector2i:
	var c: Vector2i = GameState.chunk_coord
	var cell: Vector2i = GameState.player_cell
	if c.x < 0 or c.y < 0 or c.x >= plan.size_chunks.x or c.y >= plan.size_chunks.y \
			or not WorldCoords.in_chunk(cell):
		return NO_CHUNK
	if not AdventureRules.is_passable(plan.bosque_at(c), home_bosque):
		return NO_CHUNK
	return WorldCoords.to_world_cell(c, cell)


## Villa natal, junto al Nujio (Npc.villa_spawn_cell_world).
func _home_villa_cell() -> Vector2i:
	var coord: Vector2i = bosques.nujio_chunk[home_bosque]
	return WorldCoords.to_world_cell(coord, Npc.villa_spawn_cell_world(world.pregen.get_chunk(coord)))


## Pone al jugador en `world_cell` (o en el hub de su chunk si estuviera bloqueada), monta la vista
## y hace las entradas de chunk y de Bosque. Con un fundido corto.
func _place(world_cell: Vector2i) -> void:
	var coord: Vector2i = WorldCoords.world_cell_to_chunk(world_cell)
	var ch: WorldChunk = world.pregen.get_chunk(coord)
	if ch != null and ch.is_blocked(WorldCoords.world_cell_to_cell(world_cell)):
		world_cell = WorldCoords.to_world_cell(coord, ch.hub)
	world.teleport(world_cell)
	if GameState.player_facing != Vector2i.ZERO:
		player.mover.facing = GameState.player_facing
	_last_cell = world_cell
	chunk_coord = NO_CHUNK
	started = true
	_enter_cell(world_cell)
	var local: Vector2i = WorldCoords.world_cell_to_cell(world_cell)
	# Aparecer en el lugar de descanso no repite el aviso; cuenta como ya dentro.
	_resting = AdventureRules.is_villa_rest_world(world.streamer.chunk(coord), local)
	player.input_enabled = true
	MapLogic.set_player_pos(player.mover.world_pos)
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, FADE_IN_TIME)


func _exit_tree() -> void:
	MapLogic.set_player_pos(Vector2(NAN, NAN))
	if WorldClock.shelter_check == _shelter_check:
		WorldClock.shelter_check = Callable()


# --- Colisión y límite de Bosque ------------------------------------------------------------------

func _terrain_blocked(c: Vector2i) -> bool:
	return world.streamer.is_blocked(c) or _npc_cells.has(c)


## La frontera del Bosque está cerrada para el jugador. Colarse la abre al tocarla si nadie te ve
## (_border_outcome): el Bosque queda colado y pasa a ser transitable.
func _is_closed(bosque_id: int) -> bool:
	return not AdventureRules.is_passable(bosque_id, home_bosque)


func _physics_process(_delta: float) -> void:
	if not started:
		return
	var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	# Correr anula el camuflaje (Stealth.running): los Únicos ven de nuevo al cambiar.
	if Stealth.set_running(input != Vector2.ZERO and Input.is_action_pressed(&"run")):
		_field.refresh_vision()
	_border.tick(player.mover.cell, player.input_enabled and input != Vector2.ZERO)
	MapLogic.set_player_pos(player.mover.world_pos)


## Choque con el límite del Bosque `bosque_id` (antes de que Crossing abra su menú, por
## EventBus.bosque_border_reached): acude su Botarramas más cercano, que es el del cruce.
func _on_border_contacted(bosque_id: int, world_cell: Vector2i) -> void:
	_pending_monster = _field.summon_nearest(bosque_id, world_cell)


## P3: qué pasa al tocar el borde cerrado (Stealth.border_outcome con los vigías del Bosque). En
## `watcher` va el vigía que te ve, si lo hay.
func _border_outcome(bosque_id: int, _world_cell: Vector2i) -> Dictionary:
	var watchers: Array[Dictionary] = _field.border_watchers(bosque_id)
	var out: Dictionary = Stealth.border_outcome(watchers, player.mover.cell, Stealth.camouflage(),
		AdventureRules.is_armed(), _field.has_chaser())
	out.watcher = watchers[out.index] if int(out.index) >= 0 else {}
	return out


## P3: te has colado (BosqueBorder ya llamó a AdventureRules.sneak_into). Se avisa al entrar.
func _on_border_sneaked(_bosque_id: int, broken: Array[StringName]) -> void:
	_entry_notices.append(Texts.get_text("sneak_entered"))
	for id: StringName in broken:
		_entry_notices.append(Texts.get_text("item_broke") % Items.display_name(id))


## P3: te ha visto un Único del Bosque que no es Botarramas: te persigue, sin menú del borde.
func _on_border_seen(bosque_id: int, outcome: Dictionary) -> void:
	var m: OverworldMonster = outcome.watcher.get("monster") if not outcome.watcher.is_empty() else null
	AdventureRules.spotted(bosque_id)
	if m != null:
		_field.alert(m)
	EventBus.notice_requested.emit(Texts.get_text("stealth_spotted"))


# --- Casillas y chunks ----------------------------------------------------------------------------

func _on_cell_changed(world_cell: Vector2i) -> void:
	if not started:
		return
	var near: Dictionary = Signpost.sign_entered(world.streamer.chunk, _last_cell, world_cell)
	_last_cell = world_cell
	_enter_cell(world_cell)
	if not near.is_empty():
		var line: Dictionary = _sign_line(world.streamer.chunk(near.coord), near.cell)
		if not line.is_empty():
			EventBus.notice_requested.emit(str(line.text))
	var local: Vector2i = WorldCoords.world_cell_to_cell(world_cell)
	_check_villa_rest(world.streamer.chunk(chunk_coord), local)
	if OfomniGuard.is_confined() and _is_near_home_exit(world_cell):
		_capture_home()


## Los pies están en `world_cell`: guarda la posición y, si cambia el chunk, entra en él.
func _enter_cell(world_cell: Vector2i) -> void:
	GameState.player_cell = WorldCoords.world_cell_to_cell(world_cell)
	GameState.player_facing = player.mover.facing
	var coord: Vector2i = WorldCoords.world_cell_to_chunk(world_cell)
	if coord != chunk_coord:
		_enter_chunk(coord)


func _enter_chunk(coord: Vector2i) -> void:
	var previous: Vector2i = chunk_coord
	chunk_coord = coord
	GameState.chunk_coord = coord
	MapLogic.mark_explored(GameState.explored_chunks, coord)
	var bosque_id: int = plan.bosque_at(coord)
	var bosque_changed: bool = bosque_id != _last_bosque
	if bosque_changed:
		_enter_bosque(bosque_id)
	elif previous != NO_CHUNK:
		# Otro chunk del mismo Bosque: los perseguidores y cazadores siguen viniendo (no salen de su
		# chunk, así que se ponen otros cerca).
		if _chase.is_active():
			_field.remove_roles([MonsterField.ROLE_CHASER] as Array[StringName])
			_spawn_chasers(_chase.count)
		if _hunt.bosque_id == bosque_id:
			_field.remove_roles([MonsterField.ROLE_HUNTER] as Array[StringName])
			for kind: StringName in _hunt.active:
				_spawn_hunter(kind)
	_sync_ofomni()
	if not _entry_notices.is_empty():
		EventBus.notice_requested.emit("\n".join(_entry_notices))
		_entry_notices.clear()
	EventBus.chunk_entered.emit(coord, bosque_id, bosques.size_of(bosque_id))


## Cambio de Bosque: colarse (si se ha entrado con el camuflaje), fin de la persecución y de la
## cacería, frutos sacados, estado del Bosque y arma en la mano.
func _enter_bosque(bosque_id: int) -> void:
	if _chase.bosque_entered(bosque_id):
		_field.remove_roles([MonsterField.ROLE_CHASER] as Array[StringName])
		EventBus.notice_requested.emit(Texts.get_text("ofomni_chase_gave_up"))
	if _hunt.bosque_id != bosque_id:
		if _hunt.bosque_id >= 0:
			_field.remove_roles([MonsterField.ROLE_HUNTER] as Array[StringName])
		_hunt.clear()
	if FruitRules.bosque_entered(bosque_id) > 0:
		EventBus.notice_requested.emit(Texts.get_text("fruit_taken_out"))
	AdventureRules.leave_sneaked(bosque_id)
	_last_bosque = bosque_id
	var state: String = BosqueStates.state_of(bosque_id, bosques)
	EventBus.bosque_entered.emit(bosque_id, state)
	var notice: String = BosqueStates.entry_notice(state)
	if notice != "":
		_entry_notices.append(notice)
	if AdventureRules.is_armed_against(bosque_id, home_bosque):
		_entry_notices.append(Texts.get_text("bosque_feels_weapon"))
	# P3: en un Bosque forzado o colado, su fruto no es tuyo.
	var fruit_notice: String = FruitRules.entry_notice(bosque_id, home_bosque)
	if fruit_notice != "":
		_entry_notices.append(fruit_notice)


## Primera misión sin aceptar: a confine_distance casillas o menos de otro Bosque.
func _is_near_home_exit(world_cell: Vector2i) -> bool:
	if plan.bosque_at(WorldCoords.world_cell_to_chunk(world_cell)) != home_bosque:
		return false
	var d: int = int(OfomniGuard.config().get("confine_distance", 3))
	for off: Vector2i in [Vector2i(-d, 0), Vector2i(d, 0), Vector2i(0, -d), Vector2i(0, d),
			Vector2i(-d, -d), Vector2i(d, -d), Vector2i(-d, d), Vector2i(d, d)]:
		var b: int = plan.bosque_at(WorldCoords.world_cell_to_chunk(world_cell + off))
		if b >= 0 and b != home_bosque:
			return true
	return false


## En la plaza de una villa o junto a su Nujio el Adoc descansa (una vez al entrar).
func _check_villa_rest(ch: WorldChunk, local: Vector2i) -> void:
	var resting: bool = ch != null and AdventureRules.is_villa_rest_world(ch, local)
	if resting and not _resting:
		AdventureRules.rest()
	_resting = resting


## NPC: el sfida en la plaza de la villa natal y, junto a él, el Sarua y el Paruas (P5,
## Npc.artisan_cells_world).
func _place_npcs(villa: WorldChunk) -> void:
	for n: Node in _npc_nodes:
		n.queue_free()
	_npc_nodes.clear()
	_npcs.clear()
	_npc_cells.clear()
	var at: Vector2i = Npc.sfida_cell_world(villa)
	if at.x < 0:
		return
	_trade_villa = villa.coord
	var cells: Dictionary = { &"sfida_natal": at }
	cells.merge(Npc.artisan_cells_world(villa))
	for id: StringName in cells:
		var cell: Vector2i = WorldCoords.to_world_cell(villa.coord, cells[id])
		var npc := Npc.new()
		npc.setup_world(id, cell)
		world.objects.add_child(npc)
		_npc_nodes.append(npc)
		_npcs[npc.npc_id] = npc.world_pos
		_npc_cells[cell] = true


# --- Interacción (E) ------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		_interact()
	elif event.is_action_pressed(&"toggle_weapon") and started and player.input_enabled:
		# P3: Q enfunda o saca el arma (AdventureRules.toggle_weapon) con un aviso corto.
		get_viewport().set_input_as_handled()
		var result: StringName = AdventureRules.toggle_weapon(plan.bosque_at(chunk_coord))
		EventBus.notice_requested.emit(Texts.get_text(AdventureRules.weapon_toggle_text(result)))
	elif event.is_action_pressed(&"quick_save"):
		get_viewport().set_input_as_handled()
		quick_save()
	elif event.is_action_pressed(&"quick_load"):
		get_viewport().set_input_as_handled()
		quick_load()
	elif event.is_action_pressed(&"new_seed") and started:
		# Elegir una seed nueva no es aleatoriedad de juego: se usa un RNG aparte, no GameState.rng.
		var picker := RandomNumberGenerator.new()
		picker.randomize()
		GameState.new_game(picker.randi_range(1, 999_999_999), GameState.region_id)
		start()


## Lo que hay delante con E (Interaction.find_world) y su acción.
func _interact() -> void:
	if not started or _fade.color.a > 0.0:
		return
	var monster: OverworldMonster = _monster_ahead()
	if monster != null and monster.role != MonsterField.ROLE_DUEL:
		_confront(monster)
		return
	var target: Dictionary = Interaction.find_world(world.streamer.chunk, player.mover.world_pos, player.mover.facing, _npcs)
	var ch: WorldChunk = world.streamer.chunk(target.chunk)
	match target.kind:
		Interaction.Kind.NPC:
			# Primero las líneas (según el estado de la misión) y luego el aviso, que aplica sus efectos.
			# P5: el Sarua y el Paruas abren el trueque (TradeDialog).
			if Trade.is_trader(target.npc_id):
				_trade.open(target.npc_id, _trade_villa)
			else:
				_dialogue.show_lines(NpcDialogue.lines_for(target.npc_id))
			EventBus.npc_talked.emit(target.npc_id)
		Interaction.Kind.SIGN:
			var line: Dictionary = _sign_line(ch, target.local)
			if not line.is_empty():
				_dialogue.show_lines([line])
		Interaction.Kind.REFUGE:
			_interact_refuge(target.cell)
		Interaction.Kind.FRUIT_TREE:
			_interact_fruit_tree(ch, target.local)
		Interaction.Kind.NUJIO:
			_interact_nujio(target.chunk)
		Interaction.Kind.REST:
			_ask_sleep(target.cell, Texts.get_text("rest_prompt"))
		Interaction.Kind.NONE:
			# P3: E contra la frontera cerrada abre el menú del borde aunque nadie te vea.
			var edge: Vector2i = player.mover.cell + player.mover.facing
			if _border.is_border(edge):
				_on_border_contacted(_border.bosque_at.call(edge), edge)
				EventBus.bosque_border_reached.emit(_border.bosque_at.call(edge))
			elif _is_at_sicabi():
				_dialogue.show_lines([Texts.get_text("sicabi_mouth")])


## Delante de (o en) la boca de una sicabi. ponytail: texto provisional hasta la escena interior.
func _is_at_sicabi() -> bool:
	var probe: Vector2i = WorldCoords.world_pos_to_world_cell(Interaction.probe_point(player.mover.world_pos, player.mover.facing))
	for c: Vector2i in [probe, player.mover.cell]:
		var ch: WorldChunk = world.streamer.chunk(WorldCoords.world_cell_to_chunk(c))
		if ch != null and int(ch.object_at(WorldCoords.world_cell_to_cell(c)).get("kind", -1)) == WorldChunk.ObjectKind.SICABI_GATE:
			return true
	return false


## Monstruo delante del Adoc: en la casilla del sondeo o en la de delante de los pies.
func _monster_ahead() -> OverworldMonster:
	var probe: Vector2i = WorldCoords.world_pos_to_world_cell(Interaction.probe_point(player.mover.world_pos, player.mover.facing))
	var m: OverworldMonster = _field.monster_at(probe)
	if m == null:
		m = _field.monster_at(player.mover.cell + player.mover.facing)
	return m


## Línea del letrero: villa de destino, flecha, dirección y tiempo de camino (con aviso si llega
## después del riutash). {} si el letrero no apunta a nada.
func _sign_line(ch: WorldChunk, local: Vector2i) -> Dictionary:
	if ch == null:
		return {}
	var dest: Dictionary = Signpost.destination_world(bosques, ch, local, home_bosque)
	if dest.is_empty() or dest.bosque_id < 0:
		return {}
	var villa: String = Signpost.villa_name(GameState.seed_value, dest.bosque_id)
	var text: String = Signpost.text_world(villa, dest.to_home, dest.delta, dest.chunks, WorldClock.time_to_riutash())
	return { "speaker": "", "text": text, "arrow": dest.delta }


## Nujio del chunk `coord`: "Dejar una ofrenda" (submenú) y, junto al de una villa, "Dormir".
func _interact_nujio(coord: Vector2i) -> void:
	var can_sleep: bool = _can_sleep_at(player.mover.cell)
	var has_ofrendas: bool = not AdventureRules.bag_ofrenda_ids().is_empty()
	if not has_ofrendas and not can_sleep:
		_dialogue.show_lines([Texts.get_text("nujio_no_ofrendas")])
		return
	var actions: Array[StringName] = []
	if has_ofrendas:
		actions.append(&"ofrenda")
	if can_sleep:
		actions.append(&"sleep")
	actions.append(&"back")
	var options: Array = actions.map(func(a: StringName) -> String:
		match a:
			&"ofrenda":
				return Texts.get_text("nujio_leave_ofrenda")
			&"sleep":
				return Texts.get_text("sleep_option")
		return Texts.get_text("nujio_back"))
	_dialogue.choice.connect(_on_nujio_choice.bind(actions, plan.bosque_at(coord)), CONNECT_ONE_SHOT)
	_dialogue.ask(Texts.get_text("nujio_prompt" if has_ofrendas else "nujio_no_ofrendas"), options)


func _on_nujio_choice(index: int, actions: Array[StringName], bosque_id: int) -> void:
	if index < 0 or index >= actions.size():
		return
	if actions[index] == &"sleep":
		_ask_sleep(player.mover.cell, Texts.get_text("rest_prompt"))
		return
	if actions[index] != &"ofrenda":
		return
	var ids: Array[StringName] = AdventureRules.bag_ofrenda_ids()
	var options: Array = ids.map(func(id: StringName) -> String: return AdventureRules.nujio_ofrenda_option(id))
	options.append(Texts.get_text("nujio_back"))
	_dialogue.choice.connect(_on_nujio_ofrenda_choice.bind(ids, bosque_id), CONNECT_ONE_SHOT)
	_dialogue.ask(Texts.get_text("nujio_ofrenda_prompt"), options)


func _on_nujio_ofrenda_choice(index: int, ids: Array[StringName], bosque_id: int) -> void:
	if index < 0 or index >= ids.size() or not AdventureRules.leave_ofrenda(bosque_id, ids[index]):
		return
	_dialogue.show_lines([
		Texts.get_text("nujio_ofrenda_left") % Ofrendas.display_name(ids[index]),
		Texts.get_text("nujio_relation_now") % AdventureRules.relation(bosque_id),
	])


## Frutal 2×2 (FruitRules, clave en su esquina noroeste): "Comerlo", "Guardarlo" o "Dejarlo"; si
## sería robo, la pregunta lo avisa (FruitRules.prompt).
func _interact_fruit_tree(ch: WorldChunk, local: Vector2i) -> void:
	if not FruitRules.has_fruit_world(ch, local):
		_dialogue.show_lines([Texts.get_text("fruit_empty")])
		return
	var bosque_id: int = plan.bosque_at(ch.coord)
	# P3: la pregunta (con el motivo del robo, "Robarlo" y el cursor en "Dejarlo") es de FruitRules.
	var p: Dictionary = FruitRules.prompt(bosque_id, home_bosque, FruitRules.can_store(bosque_id))
	_dialogue.choice.connect(_on_fruit_choice.bind(ch, local, p.actions), CONNECT_ONE_SHOT)
	_dialogue.ask(p.text, p.options, [], int(p.cursor))


func _on_fruit_choice(index: int, ch: WorldChunk, local: Vector2i, actions: Array[StringName]) -> void:
	if index < 0 or index >= actions.size() or actions[index] == &"leave":
		return
	var store: bool = actions[index] == &"store"
	var result: Dictionary = FruitRules.take_world(ch, local, plan.bosque_at(ch.coord), home_bosque, store)
	if result.is_empty():
		return
	world.streamer.refresh_fruit()
	var lines: Array = [Texts.get_text("fruit_stored") if store else Texts.get_text("fruit_taken") % int(result.healed)]
	if bool(result.theft):
		lines.append(Texts.get_text("fruit_theft_unseen" if _theft_unseen else "fruit_theft_seen"))
		if _chase.is_active():
			lines.append(Texts.get_text("ofomni_chase_alert"))
	_dialogue.show_lines(lines)


## Refugio (árbol hueco o cueva, `world_cell` = su esquina noroeste): "Dormir", "Registrar el
## refugio" o "Volver".
func _interact_refuge(world_cell: Vector2i) -> void:
	var actions: Array[StringName] = [&"sleep", &"search", &"back"]
	var options: Array = [Texts.get_text("sleep_option"), Texts.get_text("refuge_search_option"), Texts.get_text("refuge_back_option")]
	_dialogue.choice.connect(_on_refuge_choice.bind(world_cell, actions), CONNECT_ONE_SHOT)
	_dialogue.ask(Texts.get_text("refuge_prompt"), options)


func _on_refuge_choice(index: int, world_cell: Vector2i, actions: Array[StringName]) -> void:
	if index < 0 or index >= actions.size():
		return
	match actions[index]:
		&"sleep":
			_ask_sleep(world_cell, Texts.get_text("refuge_prompt"))
		&"search":
			_dialogue.show_lines(_refuge_lines(WorldCoords.world_cell_to_chunk(world_cell)))


## Refugio (ofrendas-v1.md): si guarda una ofrenda se recoge una vez; después, "No queda nada".
func _refuge_lines(coord: Vector2i) -> Array:
	if AdventureRules.refuge_ofrenda(GameState.seed_value, coord) == &"":
		return [Texts.get_text("refuge_empty")]
	var item: Dictionary = AdventureRules.loot_refuge(coord)
	if item.is_empty():
		return [Texts.get_text("refuge_looted")]
	var found: String = "%s (%d)" % [Ofrendas.display_name(StringName(str(item.id))), int(item.luz)]
	if not bool(item.taken):
		return [Texts.get_text("refuge_found") % found, Texts.get_text("bag_full")]
	return [Texts.get_text("refuge_found") % found, Texts.get_text("refuge_empty")]


# --- Cruce, monstruos y combates (el mismo flujo que exploration.gd) -----------------------------

## Resultado del menú del borde (ADR 0009). Pagar o vencer abre el paso (el límite deja de
## bloquear); vencer además disuelve al Botarramas que lo guardaba.
func _on_crossing_resolved(_bosque_id: int, outcome: StringName) -> void:
	var monster: OverworldMonster = _pending_monster
	_pending_monster = null
	match outcome:
		&"paid", &"won":
			if monster != null and outcome == &"won":
				_field.dissolve(monster)
		&"defeated":
			_respawn()
		&"game_over":
			_game_over()
		_:
			_retreat_from(monster, outcome == &"fled")


func _on_quest_battle_resolved(_quest_id: StringName, outcome: StringName) -> void:
	var monster: OverworldMonster = _pending_monster
	_pending_monster = null
	match outcome:
		&"victory":
			_field.remove_ofomni()
			_ofomni_chunk = NO_CHUNK
		&"defeat":
			_respawn()
		&"game_over":
			_game_over()
		_:
			_retreat_from(monster, outcome == &"fled")


## Un Único alcanza al Adoc: apertura del combate táctico (T6; emboscada si es un cazador o un Único
## fatal ahora, TacticalBridge) y el encuentro.
func _on_field_engaged(monster: OverworldMonster) -> void:
	EventBus.battle_opening_set.emit(TacticalBridge.opening_for_engaged(monster.role,
		AdventureRules.is_fatal(monster.cfg.get("fatal_at", []), GameState.clock_momento)))
	_on_monster_engaged(monster)


## Encuentro con un monstruo: el Ofomni descarriado empieza el combate de misión; un Botarramas de
## frontera, el menú del borde del Bosque que guarda; uno de dentro del Bosque, su combate directo.
func _on_monster_engaged(monster: OverworldMonster) -> void:
	_pending_monster = monster
	if monster.role == MonsterField.ROLE_QUEST or monster.monster_id == MonsterField.OFOMNI_DESCARRIADO:
		EventBus.quest_battle_requested.emit(QuestRunner.QUEST)
	elif monster.role == MonsterField.ROLE_GUARDIAN:
		EventBus.bosque_border_reached.emit(monster.bosque_id)
	elif _field.is_independent(monster):
		_ask_independent(monster)
	else:
		_request_unico_battle(monster, false)


## E frente a un Único (enfrentarse a voluntad), como en la exploración vieja.
func _confront(monster: OverworldMonster) -> void:
	# T6: sorpresa si no le persigue (no ha detectado al Adoc); el independiente pide Luz antes.
	EventBus.battle_opening_set.emit(TacticalBridge.opening_for_confront(
		monster.state == MonsterSteering.State.CHASE or _field.is_independent(monster)))
	var active: bool = _field.can_detect(monster)
	if active and _field.is_independent(monster):
		_ask_independent(monster)
		return
	if monster.role == MonsterField.ROLE_QUEST or (monster.role == MonsterField.ROLE_GUARDIAN and active) \
			or monster.role == MonsterField.ROLE_CHASER or monster.role == MonsterField.ROLE_HUNTER:
		_on_monster_engaged(monster)
		return
	var offends: bool = AdventureRules.is_paid(monster.bosque_id, home_bosque)
	var text: String = Texts.get_text("unico_confront_prompt") % AdventureRules.monster_name(monster.monster_id)
	if offends:
		text += "\n" + Texts.get_text("unico_confront_offends")
	_dialogue.choice.connect(_on_confront_choice.bind(monster, offends), CONNECT_ONE_SHOT)
	_dialogue.ask(text, [Texts.get_text("unico_confront_yes"), Texts.get_text("unico_confront_no")])


func _on_confront_choice(index: int, monster: OverworldMonster, offends: bool) -> void:
	if index != 0 or not is_instance_valid(monster):
		return
	_pending_monster = monster
	_request_unico_battle(monster, offends)


## Combate directo contra un Único. Si perder sería fatal (Aledra de noche), avisa primero.
func _request_unico_battle(monster: OverworldMonster, offends: bool) -> void:
	var fatal_at: Array = monster.cfg.get("fatal_at", [])
	if monster.count > 1:
		EventBus.group_battle_requested.emit(monster.bosque_id, monster.monster_id, monster.count, offends, "")
		return
	if not AdventureRules.is_fatal(fatal_at, GameState.clock_momento):
		EventBus.unico_battle_requested.emit(monster.bosque_id, monster.monster_id, offends)
		return
	_pending_monster = monster
	_dialogue.choice.connect(_on_fatal_choice.bind(monster, offends), CONNECT_ONE_SHOT)
	_dialogue.ask(Texts.get_text("aledra_night_warning"), [Texts.get_text("aledra_fight"), Texts.get_text("aledra_flee")])


func _on_fatal_choice(index: int, monster: OverworldMonster, offends: bool) -> void:
	if not is_instance_valid(monster):
		_pending_monster = null
		return
	if index == 0:
		_pending_monster = monster
		EventBus.unico_battle_requested.emit(monster.bosque_id, monster.monster_id, offends)
		return
	_pending_monster = null
	_retreat_from(monster)


## Un Único independiente de un Bosque muerto pide 1-2 de Luz: pagar lo deja tranquilo este Momento.
func _ask_independent(monster: OverworldMonster) -> void:
	_pending_monster = monster
	var luz: int = BosqueStates.independent_luz(GameState.seed_value, monster.key, GameState.riutash_count)
	var options: Array = [Texts.get_text("independent_pay") % luz, Texts.get_text("independent_refuse")]
	_dialogue.choice.connect(_on_independent_choice.bind(monster, luz), CONNECT_ONE_SHOT)
	_dialogue.ask(Texts.get_text("independent_prompt") % [AdventureRules.monster_name(monster.monster_id), luz], options)


func _on_independent_choice(index: int, monster: OverworldMonster, luz: int) -> void:
	if not is_instance_valid(monster):
		_pending_monster = null
		return
	if index == 0 and BosqueStates.pay_independent(luz):
		_pending_monster = null
		_field.satisfy(monster)
		monster.calm(MonsterSteering.calm_seconds(monster.cfg, false))
		EventBus.notice_requested.emit(Texts.get_text("independent_paid"))
		return
	if index == 0:
		EventBus.notice_requested.emit(Texts.get_text("independent_no_luz"))
	_request_unico_battle(monster, false)


## Fin de un combate directo contra un Único (como en la exploración vieja).
func _on_unico_battle_resolved(_bosque_id: int, outcome: StringName) -> void:
	var monster: OverworldMonster = _pending_monster
	_pending_monster = null
	match outcome:
		&"victory":
			if monster != null:
				if monster.role == MonsterField.ROLE_CHASER:
					_chase.chaser_defeated()
				elif monster.role == MonsterField.ROLE_HUNTER:
					_hunt.hunter_defeated(monster.monster_id)
			_field.dissolve(monster)
		&"appeased":
			_field.remove_roles([MonsterField.ROLE_CHASER, MonsterField.ROLE_HUNTER] as Array[StringName])
			_chase.clear()
			_hunt.clear()
		&"defeat":
			_respawn()
		&"game_over":
			_game_over()
		_:
			_retreat_from(monster, outcome == &"fled")


## Retroceder o huir: retreat_cells casillas alejándose del monstruo (o del límite que se empujaba)
## y el monstruo deja de ver al jugador un rato: flee_cooldown si `fled` (huida con éxito),
## retreat_cooldown si no (Retroceder, rechazar el combate). MonsterSteering.calm_seconds.
func _retreat_from(monster: OverworldMonster, fled: bool = false) -> void:
	var cfg: Dictionary = monster.cfg if monster != null else AdventureRules.monster_config(MonsterField.BOTARRAMAS)
	var here: Vector2i = player.mover.cell
	var dirs: Array[Vector2i] = [-player.mover.facing]
	if monster != null:
		monster.calm(MonsterSteering.calm_seconds(cfg, fled))
		var away: Vector2i = here - monster.cell
		var main := Vector2i(signi(away.x), 0) if absi(away.x) >= absi(away.y) else Vector2i(0, signi(away.y))
		var other := Vector2i(0, signi(away.y)) if main.x != 0 else Vector2i(signi(away.x), 0)
		dirs = [main, other, -player.mover.facing]
	for dir: Vector2i in dirs:
		if dir == Vector2i.ZERO:
			continue
		var reached: Vector2i = here
		for i: int in int(cfg.retreat_cells):
			if player.is_blocked.call(reached + dir):
				break
			reached += dir
		if reached != here:
			player.place_at_cell(reached)
			_last_cell = reached
			_enter_cell(reached)
			return


## Derrota no fatal (cruce-y-combate-v2.md): despierta junto al Nujio aliado (o el del último
## Bosque pagado) más cercano, o en la villa natal, y lo avisa.
func _respawn() -> void:
	_chase.clear()
	_hunt.clear()
	_field.remove_roles([MonsterField.ROLE_CHASER, MonsterField.ROLE_HUNTER] as Array[StringName])
	var target: int = AdventureRules.respawn_target(bosques, GameState.chunk_coord, home_bosque)
	var coord: Vector2i = bosques.nujio_chunk[target]
	_place(WorldCoords.to_world_cell(coord, AdventureRules.respawn_cell_world(world.pregen.get_chunk(coord))))
	EventBus.notice_requested.emit(AdventureRules.respawn_notice(bosques, target))
	# Despertar en una villa cura del todo.
	if AdventureRules.is_villa_rest_world(world.streamer.chunk(chunk_coord), GameState.player_cell):
		AdventureRules.rest()


## Derrota contra un monstruo fatal: la partida termina y empieza otra.
func _game_over() -> void:
	GameState.new_game(0, GameState.region_id)
	start()


# --- Robo, persecución, cacería, sigilo y confinamiento -------------------------------------------

func _on_bosque_robbed(bosque_id: int) -> void:
	_theft_unseen = false
	if not started or bosque_id != plan.bosque_at(chunk_coord):
		return
	var hidden: bool = Stealth.is_hidden()
	var watched: bool = hidden and _field.is_watched(bosque_id, player.mover.cell)
	_theft_unseen = hidden and not watched
	if not OfomniGuard.is_alerted(0.0, hidden, watched):
		return
	if watched:
		AdventureRules.spotted(bosque_id)
		_field.refresh_vision()
	var n: int = OfomniGuard.chase_count(GameState.seed_value, bosque_id, AdventureRules.hostility(bosque_id))
	var added: int = _chase.alert(bosque_id, n)
	if added > 0:
		_spawn_chasers(added)


func _chunk_rect(coord: Vector2i) -> Rect2i:
	return Rect2i(coord * WorldCoords.CHUNK, Vector2i(WorldCoords.CHUNK, WorldCoords.CHUNK))


func _spawn_chasers(n: int) -> void:
	var cells: Array[Vector2i] = OfomniGuard.spawn_cells(player.mover.cell, n, _field.can_place_world, _chunk_rect(chunk_coord))
	_field.spawn_chasers(_chase.bosque_id, cells, bosques.styles[_chase.bosque_id])


func _spawn_hunter(kind: StringName) -> void:
	var bosque_id: int = plan.bosque_at(chunk_coord)
	var cells: Array[Vector2i] = OfomniGuard.spawn_cells(player.mover.cell, 1, _field.can_place_world, _chunk_rect(chunk_coord))
	if not cells.is_empty():
		_field.spawn_hunter(kind, bosque_id, cells[0], bosques.styles[bosque_id])


## Va oculto: camuflado, o colado en este Bosque sin que le hayan visto.
func _is_hidden() -> bool:
	if Stealth.is_hidden():
		return true
	return started and AdventureRules.is_sneaking_unseen(plan.bosque_at(chunk_coord))


func _on_monster_spotted(monster: OverworldMonster) -> void:
	if not _is_hidden():
		return
	AdventureRules.spotted(monster.bosque_id)
	monster.state = MonsterSteering.State.CHASE
	monster.engage_delay = Stealth.seen_grace()
	_field.refresh_vision()
	EventBus.notice_requested.emit(Texts.get_text("stealth_spotted"))


## Equipar o quitarse algo: la velocidad del talismán de viaje y, si saca el arma dentro de un
## Bosque en el que se ha colado, el Bosque lo siente.
func _on_equipment_changed(slot: StringName, _item_id: StringName) -> void:
	player.speed_scale = PlayerWalker.STEP_TIME / Stealth.step_time(PlayerWalker.STEP_TIME)
	if not started or slot != InventoryLogic.SLOT_MAIN_HAND or not AdventureRules.is_armed():
		return
	var here: int = plan.bosque_at(chunk_coord)
	if AdventureRules.is_sneaking_unseen(here):
		GameState.sneaked_bosques[str(here)] = true


## Cacería del Bosque sin pagar y camuflaje roto: corren con el árbol (se paran con menús,
## combates y diálogos).
func _process(delta: float) -> void:
	if not started or _capturing or _fade.color.a > 0.0:
		return
	if Stealth.tick(delta):
		_field.refresh_vision()
		if Stealth.is_hidden():
			EventBus.notice_requested.emit(Texts.get_text("stealth_hidden_again"))
	var bosque_id: int = plan.bosque_at(chunk_coord)
	var was_hunting: bool = _hunt.bosque_id >= 0
	var kind: StringName = _hunt.tick(delta, bosque_id, home_bosque, GameState.seed_value)
	if was_hunting and _hunt.bosque_id < 0:
		_field.remove_roles([MonsterField.ROLE_HUNTER] as Array[StringName])
	if kind == &"":
		return
	_spawn_hunter(kind)
	if _hunt.is_first():
		EventBus.notice_requested.emit(Texts.get_text("bosque_hunt_started"))


## Primera misión sin aceptar (OfomniGuard): los Ofomni del Bosque natal le devuelven a la villa.
func _capture_home() -> void:
	if _capturing:
		return
	_capturing = true
	var cells: Array[Vector2i] = []
	for d: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
			Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var c: Vector2i = player.mover.cell + d
		if cells.size() < 2 and not _terrain_blocked(c) and _field.monster_at(c) == null:
			cells.append(c)
	_field.spawn_captors(home_bosque, cells, bosques.styles[home_bosque])
	_dialogue.finished.connect(_finish_capture, CONNECT_ONE_SHOT)
	_dialogue.show_lines([Texts.get_text("ofomni_capture")])


func _finish_capture() -> void:
	_capturing = false
	_chase.clear()
	_field.remove_roles([MonsterField.ROLE_CAPTOR] as Array[StringName])
	var coord: Vector2i = bosques.nujio_chunk[home_bosque]
	_place(WorldCoords.to_world_cell(coord, world.pregen.get_chunk(coord).hub))


## Pone o quita al Ofomni de la misión: está en el mundo si su chunk es uno de los activos (el del
## jugador y sus vecinos). Al verlo, el objetivo pasa a su casilla.
func _sync_ofomni() -> void:
	if not started:
		return
	var oc: Vector2i = _quest.ofomni_chunk()
	var near: bool = oc.x >= 0 and WorldStreamer.chebyshev(oc, chunk_coord) <= WorldStreamer.ACTIVE_RADIUS
	if not near or oc != _ofomni_chunk:
		_field.remove_ofomni()
		_ofomni_chunk = NO_CHUNK
	if not near or _field.ofomni() != null:
		return
	var ch: WorldChunk = world.streamer.chunk(oc)
	if ch == null:
		return
	var at: Vector2i = ch.hub + (OFOMNI_VILLA_OFFSET if ch.has_villa else Vector2i.ZERO)
	_field.spawn_ofomni_world(String(QuestRunner.QUEST), WorldCoords.to_world_cell(oc, at), bosques.styles[plan.bosque_at(oc)])
	_ofomni_chunk = oc
	var m: OverworldMonster = _field.ofomni()
	if m != null:
		_region_map.set_objective(oc, Texts.get_text("compass_ofomni_descarriado"), WorldCoords.world_cell_to_cell(m.cell))


## Un Bosque cambia de estado: se avisa si es el Bosque en el que está el Adoc.
## ponytail: el tinte por estado del arte del mundo (recoloreado por Bosque) llega con M18.
func _on_bosque_state_changed(bosque_id: int, state: String) -> void:
	if not started or bosque_id != plan.bosque_at(chunk_coord):
		return
	var notice: String = BosqueStates.entry_notice(state)
	if notice != "":
		EventBus.notice_requested.emit(notice)


# --- Guardado rápido -------------------------------------------------------------------------------

## Guarda la partida en el slot rápido (posición: chunk + casilla de los pies + orientación).
func quick_save() -> int:
	if not started:
		return ERR_UNAVAILABLE
	GameState.chunk_coord = chunk_coord
	GameState.player_cell = WorldCoords.world_cell_to_cell(player.mover.cell)
	GameState.player_facing = player.mover.facing
	var err: Error = SaveManager.save_game(quick_slot)
	EventBus.notice_requested.emit(Texts.get_text("save_done" if err == OK else "save_failed"))
	return err


## Carga el slot rápido. Una partida del mundo viejo no se carga: lo avisa (ADR 0014 §7).
func quick_load() -> int:
	if not started:
		return ERR_UNAVAILABLE
	var err: int = SaveManager.load_game(quick_slot)
	match err:
		OK:
			EventBus.notice_requested.emit(Texts.get_text("load_done"))
			start()
		SaveManager.ERR_SAVE_OLD_WORLD:
			_dialogue.show_lines([Texts.get_text("save_old_world")])
		ERR_FILE_NOT_FOUND:
			EventBus.notice_requested.emit(Texts.get_text("load_none"))
		_:
			EventBus.notice_requested.emit(Texts.get_text("load_failed"))
	return err


## Al arrancar el juego: si el slot rápido es del mundo viejo, lo avisa (no hay menú principal).
func warn_old_save() -> void:
	if SaveManager.check_slot(quick_slot) == SaveManager.ERR_SAVE_OLD_WORLD:
		_dialogue.show_lines([Texts.get_text("save_old_world")])


# --- Dormir (SleepRules) y Pensamiento (FarQuestRunner) -------------------------------------------

## Se puede dormir en la casilla global: refugio, plaza de una villa o junto a su Nujio.
func _can_sleep_at(world_cell: Vector2i) -> bool:
	var ch: WorldChunk = world.streamer.chunk(WorldCoords.world_cell_to_chunk(world_cell))
	return AdventureRules.is_riutash_shelter_world(ch, WorldCoords.world_cell_to_cell(world_cell))


## Pregunta si dormir en `world_cell` (como en la exploración vieja).
func _ask_sleep(world_cell: Vector2i, place: String) -> void:
	if not _can_sleep_at(world_cell):
		return
	var lines: PackedStringArray = [place]
	var confirm: String = Texts.get_text("sleep_confirm")
	if SleepRules.is_night():
		lines.append(Texts.get_text("sleep_prompt_night"))
	else:
		var cost: int = SleepRules.cost_now()
		lines = [Texts.get_text("sleep_prompt_day") % cost]
		confirm = Texts.get_text("sleep_confirm_day") % cost
		if not SleepRules.can_afford():
			lines.append(Texts.get_text("sleep_no_luz") % GameState.luz)
	if _quest.is_ofomni_active():
		lines.append(Texts.get_text("sleep_ofomni_warning"))
	_dialogue.choice.connect(_on_sleep_choice.bind(world_cell), CONNECT_ONE_SHOT)
	_dialogue.ask("\n".join(lines), [confirm, Texts.get_text("sleep_cancel")], [SleepRules.can_afford(), true])


func _on_sleep_choice(index: int, world_cell: Vector2i) -> void:
	if index != 0 or not SleepRules.can_afford():
		return
	# Se duerme dentro del refugio (si se le hablaba desde fuera): ahí pasa el riutash a cubierto.
	if world_cell != player.mover.cell:
		player.place_at_cell(world_cell)
		_last_cell = world_cell
		_enter_cell(world_cell)
	_sleep_screen.blacked_out.connect(_on_sleep_blacked_out, CONNECT_ONE_SHOT)
	_sleep_screen.play(Texts.get_text("sleep_fade_night" if SleepRules.is_night() else "sleep_fade_day"))


func _on_sleep_blacked_out() -> void:
	var slept: Dictionary = sleep_now()
	if slept.is_empty():
		_sleep_screen.wake("")
		return
	var vision: Dictionary = slept.vision
	if vision.is_empty():
		_sleep_screen.wake(slept.wake_text)
		return
	_sleep_screen.finished.connect(_far.offer.bind(vision), CONNECT_ONE_SHOT)
	_sleep_screen.show_vision(_far.vision_text(vision), slept.wake_text)


## Duerme ya, sin pantalla (como exploration.sleep_now).
func sleep_now() -> Dictionary:
	if not started or not _can_sleep_at(player.mover.cell):
		return {}
	var in_villa: bool = AdventureRules.is_villa_rest_world(world.streamer.chunk(chunk_coord), GameState.player_cell)
	var slept: Dictionary = SleepRules.sleep(in_villa, _quest.advance_time)
	if slept.is_empty():
		return {}
	slept.vision = {}
	if bool(slept.night):
		slept.vision = _far.vision_after_sleep(int(slept.day), plan.bosque_at(chunk_coord))
		slept.wake_text = Texts.get_text("sleep_woke_villa" if in_villa else "sleep_woke_night")
	else:
		slept.wake_text = Texts.get_text("sleep_woke_day_villa" if in_villa else "sleep_woke_day") % int(slept.cost)
	_resting = in_villa
	return slept


# --- Reloj y riutash (ADR 0012) -------------------------------------------------------------------
const MOONLIGHT_SHADER: Shader = preload("res://assets/shaders/moonlight.gdshader")
## Capa del post-proceso de luz de luna: encima del mundo y debajo de toda la UI (capa 2 o más).
const MOONLIGHT_LAYER: int = 1
const FLASH_IN_TIME: float = 0.08
const FLASH_OUT_TIME: float = 0.5
const FLASH_ALPHA: float = 0.85

var _moonlight: ColorRect
var _moon_tween: Tween
var _flash: ColorRect
## Comprobación de refugio que esta exploración presta a WorldClock mientras está en el árbol.
var _shelter_check: Callable


func _setup_riutash() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Moonlight"
	layer.layer = MOONLIGHT_LAYER
	add_child(layer)
	$DebugHud.layer = maxi($DebugHud.layer, MOONLIGHT_LAYER + 1)
	_moonlight = ColorRect.new()
	_moonlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	_moonlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = MOONLIGHT_SHADER
	var uniforms: Dictionary = TimeConfig.moonlight_uniforms()
	for key: String in uniforms:
		material.set_shader_parameter(key, uniforms[key])
	_moonlight.material = material
	layer.add_child(_moonlight)
	_set_moonlight(0.0)
	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	$Transition.add_child(_flash)
	EventBus.riutash_passed.connect(_on_riutash_passed)
	EventBus.momento_changed.connect(_on_momento_changed)


func _enter_tree() -> void:
	_shelter_check = func() -> bool: return started and _can_sleep_at(player.mover.cell)
	WorldClock.shelter_check = _shelter_check


func _set_moonlight(value: float) -> void:
	_moonlight.material.set_shader_parameter(&"intensity", value)
	_moonlight.visible = value > 0.0


func _on_riutash_passed(sheltered: bool) -> void:
	AdventureRules.apply_riutash(sheltered)
	_riutash_relation(sheltered)
	FruitRules.regrow()
	if world.streamer != null:
		world.streamer.refresh_fruit()
	var tween: Tween = create_tween()
	tween.tween_property(_flash, "color:a", FLASH_ALPHA, FLASH_IN_TIME)
	tween.tween_property(_flash, "color:a", 0.0, FLASH_OUT_TIME)


## Relación y peaje en el riutash (como en la exploración vieja).
func _riutash_relation(sheltered: bool) -> void:
	if not started:
		return
	var bosque_id: int = plan.bosque_at(chunk_coord)
	var lines: PackedStringArray = []
	var ch: WorldChunk = world.streamer.chunk(chunk_coord)
	if ch != null and AdventureRules.riutash_near_nujio_world(ch, GameState.player_cell, bosque_id, sheltered):
		lines.append(Texts.get_text("nujio_rest_relation"))
	var expired: Array[int] = AdventureRules.expire_tolls()
	if expired.has(bosque_id):
		lines.append(Texts.get_text("toll_expired_here"))
	elif not expired.is_empty():
		lines.append(Texts.get_text("toll_expired"))
	if lines.is_empty():
		return
	get_tree().create_timer(RIUTASH_RELATION_NOTICE_DELAY).timeout.connect(
		Callable(EventBus, &"emit_signal").bind(&"notice_requested", "\n".join(lines)))


func _on_momento_changed(momento: StringName) -> void:
	# Aledra sale al anochecer y se va al amanecer (BosquePatrols).
	_field.sync_patrols()
	if _moon_tween != null:
		_moon_tween.kill()
	var from: float = float(_moonlight.material.get_shader_parameter(&"intensity"))
	var to: float = 1.0 if momento == TimeConfig.RIUMNA else 0.0
	_moon_tween = create_tween()
	_moon_tween.tween_method(_set_moonlight, from, to, TimeConfig.moonlight_fade_seconds())
