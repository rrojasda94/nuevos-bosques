extends Node2D
## Exploración del modo Aventura: dibuja el chunk actual y una franja de los chunks vecinos (para
## ver el color de la vegetación del Bosque de al lado), mueve al jugador y cambia al chunk vecino
## al salir por un borde (ADR 0006). Se entra libremente en el Bosque inicial y en los Bosques con
## el paso abierto; en el borde de uno cerrado se emite bosque_border_reached y el menú del borde
## (scenes/rpg/crossing.tscn, ADR 0009) decide si se cruza. Los chunks se regeneran desde la seed;
## la caché es solo para no recalcular durante la sesión.
## Con interact (E) se habla con los NPC, se leen letreros, se examinan refugios y se toma el
## fruto de los frutales (Interaction, FruitRules).
## Monstruos (MonsterField): los Botarramas de los tramos de frontera interceptan al jugador y su
## encuentro abre el menú del borde; el borde cerrado lo abre igual si nadie le persigue (red de
## seguridad). El Ofomni de la misión (QuestRunner) aparece en su chunk y su encuentro es el
## combate de misión.

const TILE_SIZE: int = 16
## Duración del fundido al cambiar de chunk.
const TRANSITION_TIME: float = 0.2
## Casillas de cada chunk vecino que se dibujan alrededor del actual.
const NEIGHBOUR_MARGIN: int = 12
## Dónde espera el Ofomni en la villa natal tras llegar: casillas al sur del hub.
const OFOMNI_VILLA_OFFSET := Vector2i(0, 12)

var _chunk: ChunkData
var _cache: Dictionary = {}
var _region: Dictionary = {}
var _bosques: BosqueMap
var _home_bosque: int = -1
var _nujio_textures: Dictionary = {}
## Evita repetir el aviso cada frame mientras se empuja contra un borde bloqueado.
var _blocked_dir: Vector2i = Vector2i.ZERO
## NPC del chunk actual: casilla -> id de datos. Bloquean el paso.
var _npcs: Dictionary = {}
## Dirección del último borde cerrado contra el que se empujó (la usa crossing_resolved).
var _pending_dir: Vector2i = Vector2i.ZERO
var _resting: bool = false
## Monstruo cuyo encuentro abrió el menú o el combate en curso (null = se empujó el borde).
var _pending_monster: OverworldMonster
## Frutales dibujados: casilla del TileMap -> [chunk, casilla del chunk, id del Bosque]. Para
## redibujarlos al tomar el fruto o al rebrotar.
var _fruit_cells: Dictionary = {}

@onready var _terrain: TileMapLayer = $Terrain
@onready var _nujios: Node2D = $Nujios
@onready var _npc_layer: Node2D = $Npcs
@onready var _field: MonsterField = $Monsters
@onready var _quest: QuestRunner = $QuestRunner
@onready var _region_map: Node = $RegionMap
@onready var _dialogue: DialogueBox = $Dialogue/DialogueBox
@onready var _player: PlayerWalker = $Player
@onready var _camera: Camera2D = $Player/Camera2D
@onready var _fade: ColorRect = $Transition/Fade


func _ready() -> void:
	_player.is_walkable = func(c: Vector2i) -> bool:
		return _chunk != null and _chunk.is_walkable(c) and not _npcs.has(c) and not _field.occupied(c)
	_player.edge_reached.connect(_on_edge_reached)
	_player.stepped.connect(_on_player_stepped)
	EventBus.crossing_resolved.connect(_on_crossing_resolved)
	EventBus.quest_battle_resolved.connect(_on_quest_battle_resolved)
	_field.player = _player
	_field.area_walkable = _area_walkable
	_field.can_engage = func() -> bool: return _fade.color.a <= 0.0
	_field.engaged.connect(_on_monster_engaged)
	_quest.setup(_dialogue, _region_map)
	_quest.ofomni_changed.connect(_sync_ofomni)
	_setup_riutash()


## Arranca la exploración con el estado actual de GameState (partida nueva o cargada).
func start() -> void:
	_region = ChunkGenerator.load_region(GameState.region_id)
	_cache.clear()
	_nujio_textures.clear()
	_terrain.tile_set = PlaceholderTileset.make_tile_set()
	_bosques = BosqueMap.for_region(GameState.seed_value, _region)
	_home_bosque = AdventureRules.home_bosque(_bosques, _region)
	_chunk = null
	_quest.start(_bosques, _home_bosque, _get_chunk(_bosques.nujio_chunk[_home_bosque]))
	var coord: Vector2i = GameState.chunk_coord
	if not AdventureRules.is_passable(_bosques.bosque_at(coord), _home_bosque):
		_enter_home_villa()
	else:
		_enter_chunk(coord, GameState.player_cell)
	if _moon_tween != null:
		_moon_tween.kill()
	_set_moonlight(1.0 if WorldClock.is_night() else 0.0)


## El Adoc aparece (partida nueva) o despierta (derrota) en su villa natal, junto al Nujio:
## en la casilla justo al sur del Nujio, o en el hub si no fuese transitable.
func _enter_home_villa() -> void:
	var coord: Vector2i = _bosques.nujio_chunk[_home_bosque]
	var chunk: ChunkData = _get_chunk(coord)
	var rect: Rect2i = chunk.nujio_rect
	var cell := Vector2i(rect.position.x + rect.size.x / 2, rect.end.y)
	_enter_chunk(coord, cell if chunk.is_walkable(cell) else chunk.hub)


func _on_player_stepped(cell: Vector2i) -> void:
	GameState.player_cell = cell
	_blocked_dir = Vector2i.ZERO
	_check_villa_rest(cell)


func _enter_chunk(coord: Vector2i, cell: Vector2i) -> void:
	_blocked_dir = Vector2i.ZERO
	_chunk = _get_chunk(coord)
	GameState.chunk_coord = coord
	MapLogic.mark_explored(GameState.explored_chunks, coord)
	_draw_area()
	_place_npcs()
	_field.populate(_bosques, _home_bosque, coord, _get_chunk)
	if not _player.is_walkable.call(cell):
		cell = _chunk.hub
	GameState.player_cell = cell
	_player.place_at(cell)
	_sync_ofomni()
	# Aparecer en el lugar de descanso no repite el aviso; cuenta como ya dentro.
	_resting = AdventureRules.is_villa_rest(_chunk, cell)
	_camera.reset_smoothing()
	var bosque_id: int = _bosques.bosque_at(coord)
	# Frutos guardados de otro Bosque: su Bosque de origen nota que te los llevas (FruitRules).
	if FruitRules.bosque_entered(bosque_id) > 0:
		EventBus.notice_requested.emit(Texts.get_text("fruit_taken_out"))
	EventBus.chunk_entered.emit(coord, bosque_id, _bosques.size_of(bosque_id))
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, TRANSITION_TIME)


func _get_chunk(coord: Vector2i) -> ChunkData:
	if not _cache.has(coord):
		_cache[coord] = ChunkGenerator.generate(GameState.seed_value, coord, _region, _bosques)
		EventBus.chunk_generated.emit(GameState.region_id, GameState.seed_value)
	return _cache[coord]


## Dibuja el chunk actual, una franja de cada vecino dentro de la región y los Nujios visibles.
## Ajusta los límites de la cámara a lo dibujado.
func _draw_area() -> void:
	_terrain.clear()
	_fruit_cells.clear()
	for child: Node in _nujios.get_children():
		child.queue_free()
	var size: int = ChunkData.SIZE
	var m: int = NEIGHBOUR_MARGIN
	var limits := Rect2i(0, 0, size, size)
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var offset := Vector2i(dx, dy)
			var bosque_id: int = _bosques.bosque_at(_chunk.coord + offset)
			if bosque_id < 0:
				continue
			_ensure_source(bosque_id)
			var chunk: ChunkData = _get_chunk(_chunk.coord + offset)
			var from := Vector2i(0 if dx >= 0 else size - m, 0 if dy >= 0 else size - m)
			var to := Vector2i(size if dx <= 0 else m, size if dy <= 0 else m)
			_draw_chunk(chunk, bosque_id, offset * size, Rect2i(from, to - from))
			limits = limits.merge(Rect2i(offset * size + from, to - from))
	_camera.limit_left = limits.position.x * TILE_SIZE
	_camera.limit_top = limits.position.y * TILE_SIZE
	_camera.limit_right = limits.end.x * TILE_SIZE
	_camera.limit_bottom = limits.end.y * TILE_SIZE


func _draw_chunk(chunk: ChunkData, bosque_id: int, offset: Vector2i, area: Rect2i) -> void:
	var sign_dir: int = _sign_direction_index(chunk.coord, bosque_id)
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var c := Vector2i(x, y)
			var tile: int = chunk.get_tile(c)
			if tile == ChunkData.Tile.FRUIT_TREE:
				_fruit_cells[offset + c] = [chunk.coord, c, bosque_id]
				_draw_fruit_tree(offset + c)
				continue
			_terrain.set_cell(offset + c, bosque_id, Vector2i(tile, PlaceholderTileset.variant_for(chunk, c, sign_dir)))
	if chunk.nujio_rect.size.x > 0:
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = _nujio_texture(bosque_id)
		sprite.position = Vector2((offset + chunk.nujio_rect.position) * TILE_SIZE)
		_nujios.add_child(sprite)


## Frutal dibujado en la casilla `at` del TileMap: con fruto o vaciado (FruitRules).
func _draw_fruit_tree(at: Vector2i) -> void:
	var info: Array = _fruit_cells[at]
	var chunk: ChunkData = _get_chunk(info[0])
	var variant: int = PlaceholderTileset.variant_for(chunk, info[1], 0)
	if not FruitRules.has_fruit(info[0], info[1]):
		variant += PlaceholderTileset.FRUIT_EMPTY_VARIANT
	_terrain.set_cell(at, info[2], Vector2i(ChunkData.Tile.FRUIT_TREE, variant))


func _refresh_fruit_trees() -> void:
	for at: Vector2i in _fruit_cells:
		_draw_fruit_tree(at)


func _ensure_source(bosque_id: int) -> void:
	var tile_set: TileSet = _terrain.tile_set
	if not tile_set.has_source(bosque_id):
		tile_set.add_source(PlaceholderTileset.make_source(_bosques.styles[bosque_id]), bosque_id)


func _nujio_texture(bosque_id: int) -> Texture2D:
	if not _nujio_textures.has(bosque_id):
		_nujio_textures[bosque_id] = PlaceholderTileset.nujio_texture(_bosques.styles[bosque_id], _bosques.nujio_size[bosque_id])
	return _nujio_textures[bosque_id]


## Índice de dirección (0 = este, sentido horario) hacia la villa del Bosque, o 0 si no hay.
func _sign_direction_index(coord: Vector2i, bosque_id: int) -> int:
	if not _bosques.has_villa[bosque_id]:
		return 0
	return ChunkGenerator.direction_index(_bosques.nujio_chunk[bosque_id] - coord)


## Línea del letrero (Signpost): villa de destino, flecha, dirección y tiempo de camino, con aviso
## si el camino dura más que lo que falta para el riutash (WorldClock).
func _sign_line(c: Vector2i) -> Dictionary:
	var dest: Dictionary = Signpost.destination(_bosques, _chunk, c, _home_bosque)
	var villa: String = Signpost.villa_name(GameState.seed_value, dest.bosque_id)
	var text: String = Signpost.text(villa, dest.to_home, dest.delta, dest.chunks, WorldClock.time_to_riutash())
	return { "speaker": "", "text": text, "arrow": dest.delta }


## NPC del chunk: por ahora, el sfida en la plaza de la villa natal.
func _place_npcs() -> void:
	_npcs.clear()
	for child: Node in _npc_layer.get_children():
		child.queue_free()
	if _chunk.coord != _bosques.nujio_chunk[_home_bosque]:
		return
	var at: Vector2i = Npc.sfida_cell(_chunk)
	if at.x < 0:
		return
	var npc := Npc.new()
	npc.setup(&"sfida_natal", at)
	_npc_layer.add_child(npc)
	_npcs[at] = npc.npc_id


## E: habla con el NPC de delante, o lee el letrero o examina el refugio (delante o debajo).
func _interact() -> void:
	# Durante el fundido de entrada no: el diálogo pausa el árbol y lo dejaría a oscuras.
	if _chunk == null or _player.is_moving() or _fade.color.a > 0.0:
		return
	var target: Dictionary = Interaction.find(_chunk, _player.cell, _player.facing, _npcs)
	match target.kind:
		Interaction.Kind.NPC:
			# Primero las líneas (según el estado de la misión) y luego el aviso, que aplica sus efectos.
			_dialogue.show_lines(NpcDialogue.lines_for(target.npc_id))
			EventBus.npc_talked.emit(target.npc_id)
		Interaction.Kind.SIGN:
			_dialogue.show_lines([_sign_line(target.cell)])
		Interaction.Kind.REFUGE:
			_dialogue.show_lines(_refuge_lines())
		Interaction.Kind.FRUIT_TREE:
			_interact_fruit_tree(target.cell)


## Frutal (FruitRules): sin fruto, avisa; con fruto, pregunta "Comerlo", "Guardarlo" (solo si
## cabe en la bolsa) o "Dejarlo". Si sería robo (Bosque sin permiso, o ya dio su fruto en este
## Momento), la pregunta lo avisa.
func _interact_fruit_tree(cell: Vector2i) -> void:
	if not FruitRules.has_fruit(_chunk.coord, cell):
		_dialogue.show_lines([Texts.get_text("fruit_empty")])
		return
	var bosque_id: int = _bosques.bosque_at(_chunk.coord)
	var prompt: String = "fruit_prompt"
	if FruitRules.is_theft(bosque_id, _home_bosque):
		prompt = "fruit_one_per_momento" if FruitRules.has_permission(bosque_id, _home_bosque) else "fruit_no_permission"
	var actions: Array[StringName] = [&"eat"]
	if FruitRules.can_store(bosque_id):
		actions.append(&"store")
	actions.append(&"leave")
	var options: Array = actions.map(func(a: StringName) -> String: return Texts.get_text("fruit_" + String(a)))
	_dialogue.choice.connect(_on_fruit_choice.bind(cell, actions), CONNECT_ONE_SHOT)
	_dialogue.ask(Texts.get_text(prompt), options)


## "Comerlo" cura y "Guardarlo" lo mete en la bolsa (ambos cuentan para el límite y el robo);
## "Dejarlo" (o cancelar) no hace nada.
func _on_fruit_choice(index: int, cell: Vector2i, actions: Array[StringName]) -> void:
	if index < 0 or index >= actions.size() or actions[index] == &"leave":
		return
	_take_fruit(cell, actions[index] == &"store")


func _take_fruit(cell: Vector2i, store: bool) -> void:
	var result: Dictionary = FruitRules.take(_chunk.coord, cell, _bosques.bosque_at(_chunk.coord), _home_bosque, store)
	if result.is_empty():
		return
	_refresh_fruit_trees()
	var lines: Array = [Texts.get_text("fruit_stored") if store else Texts.get_text("fruit_taken") % int(result.healed)]
	if bool(result.theft):
		lines.append(Texts.get_text("fruit_theft_seen"))
	_dialogue.show_lines(lines)


## Refugio (ofrendas-v1.md): si guarda una ofrenda se recoge una vez; después, "No queda nada".
func _refuge_lines() -> Array:
	var coord: Vector2i = _chunk.coord
	if AdventureRules.refuge_ofrenda(GameState.seed_value, coord) == &"":
		return [Texts.get_text("refuge_empty")]
	var item: Dictionary = AdventureRules.loot_refuge(coord)
	if item.is_empty():
		return [Texts.get_text("refuge_looted")]
	var found: String = "%s (%d)" % [Ofrendas.display_name(StringName(str(item.id))), int(item.luz)]
	# Bolsa llena: se ve, pero no se toma; el refugio la guarda para otra vez.
	if not bool(item.taken):
		return [Texts.get_text("refuge_found") % found, Texts.get_text("bag_full")]
	return [Texts.get_text("refuge_found") % found, Texts.get_text("refuge_empty")]


func _on_edge_reached(direction: Vector2i) -> void:
	var next_coord: Vector2i = GameState.chunk_coord + direction
	var next_bosque: int = _bosques.bosque_at(next_coord)
	if not AdventureRules.is_passable(next_bosque, _home_bosque):
		# Si un Botarramas ya viene a por el jugador, el menú lo abrirá su encuentro.
		if direction != _blocked_dir and not _field.has_chaser():
			_blocked_dir = direction
			_pending_dir = direction
			_pending_monster = null
			EventBus.bosque_border_reached.emit(next_bosque)
		return
	_cross(direction)


func _cross(direction: Vector2i) -> void:
	var next_coord: Vector2i = GameState.chunk_coord + direction
	var along: int = _player.cell.y if direction.x != 0 else _player.cell.x
	var entry: Vector2i = _get_chunk(next_coord).find_entry(-direction, along)
	_enter_chunk(next_coord, entry)


## Resultado del menú del borde (ADR 0009). Si lo abrió un Botarramas, pagar o vencer no cruza
## (pagar deja sus Botarramas pasivos; vencer disuelve al vencido y fuerza el Bosque, cuyos demás
## Botarramas siguen activos); si se empujó el borde, se cruza.
func _on_crossing_resolved(_bosque_id: int, outcome: StringName) -> void:
	var monster: OverworldMonster = _pending_monster
	_pending_monster = null
	match outcome:
		&"paid", &"won":
			if monster == null:
				_cross(_pending_dir)
			elif outcome == &"won":
				_field.dissolve(monster)
		&"defeated":
			_enter_home_villa()
		&"game_over":
			_game_over()
		_:
			_retreat_from(monster)


func _on_quest_battle_resolved(_quest_id: StringName, outcome: StringName) -> void:
	var monster: OverworldMonster = _pending_monster
	_pending_monster = null
	match outcome:
		&"victory":
			_field.remove_ofomni()
		&"defeat":
			_enter_home_villa()
		&"game_over":
			_game_over()
		_:
			_retreat_from(monster)


## Encuentro con un monstruo: el Ofomni descarriado empieza el combate de misión; un Botarramas, el menú del
## borde del Bosque que guarda.
func _on_monster_engaged(monster: OverworldMonster) -> void:
	_pending_monster = monster
	if monster.monster_id == MonsterField.OFOMNI_DESCARRIADO:
		EventBus.quest_battle_requested.emit(QuestRunner.QUEST)
	else:
		EventBus.bosque_border_reached.emit(monster.bosque_id)


## Retroceder o huir: retroceder retreat_cells casillas (alejándose del monstruo o, si se empujó
## el borde, hacia dentro del Bosque) y el monstruo deja de ver al jugador un rato.
func _retreat_from(monster: OverworldMonster) -> void:
	_blocked_dir = Vector2i.ZERO
	var cfg: Dictionary = monster.cfg if monster != null else AdventureRules.monster_config(MonsterField.BOTARRAMAS)
	var dirs: Array[Vector2i] = [-_pending_dir]
	if monster != null:
		monster.calm(float(cfg.engage_cooldown))
		var away: Vector2i = _player.cell - monster.cell
		var main := Vector2i(signi(away.x), 0) if absi(away.x) >= absi(away.y) else Vector2i(0, signi(away.y))
		var other := Vector2i(0, signi(away.y)) if main.x != 0 else Vector2i(signi(away.x), 0)
		dirs = [main, other, -_player.facing]
	for dir: Vector2i in dirs:
		if dir == Vector2i.ZERO:
			continue
		var reached: Vector2i = _player.cell
		for i: int in int(cfg.retreat_cells):
			if not _player.is_walkable.call(reached + dir):
				break
			reached += dir
		if reached != _player.cell:
			_player.place_at(reached)
			GameState.player_cell = reached
			return


## Derrota contra un monstruo fatal (monstruos.md): la partida termina y empieza otra.
func _game_over() -> void:
	GameState.new_game(0, GameState.region_id)
	start()


## Casilla de área (relativa al chunk actual; puede caer en la franja de un vecino) transitable
## para los monstruos: dentro de lo dibujado, en la región y sin NPC.
func _area_walkable(c: Vector2i) -> bool:
	var m: int = NEIGHBOUR_MARGIN
	if _chunk == null or c.x < -m or c.y < -m or c.x >= ChunkData.SIZE + m or c.y >= ChunkData.SIZE + m:
		return false
	var off := Vector2i(floori(c.x / float(ChunkData.SIZE)), floori(c.y / float(ChunkData.SIZE)))
	var coord: Vector2i = _chunk.coord + off
	if _bosques.bosque_at(coord) < 0:
		return false
	var local: Vector2i = c - off * ChunkData.SIZE
	if off == Vector2i.ZERO and _npcs.has(local):
		return false
	return _get_chunk(coord).is_walkable(local)


## Pone o quita al Ofomni según su chunk (QuestRunner). Al verlo, el objetivo pasa a su casilla.
func _sync_ofomni() -> void:
	if _chunk == null:
		return
	if _quest.ofomni_chunk() != _chunk.coord:
		_field.remove_ofomni()
		return
	if _field.ofomni() != null:
		return
	# En la villa espera al sur de la plaza; en otro chunk, en su claro central.
	var near: Vector2i = _chunk.hub + (OFOMNI_VILLA_OFFSET if _chunk.has_villa else Vector2i.ZERO)
	_field.spawn_ofomni(String(QuestRunner.QUEST), near, _chunk, _bosques.styles[_bosques.bosque_at(_chunk.coord)])
	_region_map.set_objective(_chunk.coord, Texts.get_text("compass_ofomni_descarriado"), _field.ofomni().cell)


## En la plaza de una villa o junto a su Nujio el Adoc descansa: PV al máximo y aviso en el HUD
## (una vez al entrar en el lugar de descanso).
func _check_villa_rest(cell: Vector2i) -> void:
	var resting: bool = AdventureRules.is_villa_rest(_chunk, cell)
	if resting and not _resting:
		AdventureRules.rest()
	_resting = resting


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		_interact()
	elif event.is_action_pressed(&"new_seed"):
		# Elegir una seed nueva no es aleatoriedad de juego: se usa un RNG aparte, no GameState.rng.
		var picker := RandomNumberGenerator.new()
		picker.randomize()
		GameState.new_game(picker.randi_range(1, 999_999_999), GameState.region_id)
		start()


# --- Reloj y riutash (ADR 0012) -------------------------------------------------------------
const MOONLIGHT_SHADER: Shader = preload("res://assets/shaders/moonlight.gdshader")
## Capa del post-proceso de luz de luna: encima del mundo (canvas 0) y debajo de toda la UI, que
## debe ir en la capa 2 o más (el HUD se sube a MOONLIGHT_LAYER + 1 al crearla).
const MOONLIGHT_LAYER: int = 1
## Destello blanco del riutash: subida y bajada.
const FLASH_IN_TIME: float = 0.08
const FLASH_OUT_TIME: float = 0.5
const FLASH_ALPHA: float = 0.85

var _moonlight: ColorRect
var _moon_tween: Tween
var _flash: ColorRect


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
	WorldClock.shelter_check = func() -> bool: return AdventureRules.is_riutash_shelter(_chunk, _player.cell)
	EventBus.riutash_passed.connect(_on_riutash_passed)
	EventBus.momento_changed.connect(_on_momento_changed)


## Intensidad de la luz de luna (0 = día, 1 = noche). De día el rect se oculta y no lee la pantalla.
func _set_moonlight(value: float) -> void:
	_moonlight.material.set_shader_parameter(&"intensity", value)
	_moonlight.visible = value > 0.0


func _on_riutash_passed(sheltered: bool) -> void:
	AdventureRules.apply_riutash(sheltered)
	FruitRules.regrow()
	_refresh_fruit_trees()
	var tween: Tween = create_tween()
	tween.tween_property(_flash, "color:a", FLASH_ALPHA, FLASH_IN_TIME)
	tween.tween_property(_flash, "color:a", 0.0, FLASH_OUT_TIME)


func _on_momento_changed(momento: StringName) -> void:
	if _moon_tween != null:
		_moon_tween.kill()
	var from: float = float(_moonlight.material.get_shader_parameter(&"intensity"))
	var to: float = 1.0 if momento == TimeConfig.RIUMNA else 0.0
	_moon_tween = create_tween()
	_moon_tween.tween_method(_set_moonlight, from, to, TimeConfig.moonlight_fade_seconds())
