class_name WorldView
extends Node2D
## Vista del Mundo 2.0 (ADR 0014 §3 "Orden de dibujo" y §6 "Streaming en juego"): mundo continuo
## entre chunks, sin transiciones ni fundidos.
## - `Ground` (TileMapLayer): suelo, agua, caras, escaleras, rampas y cascadas.
## - `Overlay` (TileMapLayer): sombras y decoración plana.
## - `Objects` (Node2D con y_sort_enabled): árboles, rocas, casas, Nujio, letreros y el jugador,
##   todos con el origen en la base o en los pies.
## - `Camera2D`, hija del jugador: sigue su posición ya ajustada al píxel (PlayerController pone
##   `position = world_pos.round()`), sin suavizado, con límites en el borde de la región.
## Crea el RegionPlan, la WorldCache y la WorldPregen (anillo inicial antes de soltar al jugador)
## y delega el streaming en WorldStreamer, al que llama una vez por fotograma.
##
## No toca GameState (solo lee la seed si no se da otra). En el juego la usa WorldExploration
## (M17) con `standalone = false`: build_world(), teleport() y las reglas colgadas de
## `cell_changed` del jugador.
## Arranque: godot --path . res://scenes/world/world_view.tscn [-- --seed=N --chunk=x,y --cell=x,y --capture=<png>]
## (`--chunk` aparece en el hub de ese chunk en vez de en la villa natal; `--cell`, en esa
## casilla global.)

## La WorldPregen terminó el anillo inicial y los sectores de la vista están montados.
signal world_ready

const DEFAULT_SEED: int = 42
const LOADING_SCENE: PackedScene = preload("res://scenes/ui/world_loading.tscn")
## Capa de la pantalla "Creando el mundo…" en el juego.
const LOADING_LAYER: int = 11
const CAPTURE_SCALE: int = 3
const CAPTURE_WALK_FRAMES: int = 45

@export var region_id: StringName = &"valle_del_sara"
## 0 = la de GameState (o DEFAULT_SEED si tampoco hay).
@export var world_seed: int = 0

## Constructor de chunks y su versión (para la clave de la caché). Se pueden cambiar antes de
## añadir la escena al árbol (la ruta automática prueba también con el builder falso de los tests).
var builder: Callable = ChunkBuilder.build
var builder_version: int = ChunkBuilder.VERSION
var use_cache: bool = true

var plan: RegionPlan
var cache: WorldCache
var pregen: WorldPregen
var painter: WorldPainter
var streamer: WorldStreamer
var is_ready: bool = false
## Clave del mundo (WorldCache.key_for) del plan actual, con o sin caché en disco. 0 sin mundo.
var world_key: int = 0
## false: la exploración del juego (WorldExploration) la controla: no lee la línea de órdenes, no
## pone los ganchos de prueba (monstruos, E, letreros, `--borders`) y arranca con build_world() y
## teleport(). true: escena de prueba de M12 (`godot res://scenes/world/world_view.tscn`).
@export var standalone: bool = true
## Monstruos del Mundo 2.0 (gancho de M15) y límite de Bosque (null sin `--borders`).
var monsters: MonsterField
var border: BosqueBorder
## Desplazamiento del jugador en el último fotograma (píxeles).
var move_dir: Vector2 = Vector2.ZERO

var _last_pos: Vector2 = Vector2.ZERO
## Gancho de prueba de la interacción (M14), hasta que la exploración nueva (M17) abra diálogos:
## la última casilla de los pies y la línea que se muestra bajo el HUD de depuración.
var _last_cell: Vector2i = Vector2i.ZERO
var _notice: String = ""

@onready var ground: TileMapLayer = $Ground
@onready var overlay: TileMapLayer = $Overlay
@onready var objects: Node2D = $Objects
@onready var player: PlayerController = $Objects/Player
@onready var camera: Camera2D = $Objects/Player/Camera2D
@onready var _label: Label = $Hud/Label


func _ready() -> void:
	player.input_enabled = false
	_label.visible = standalone
	if standalone:
		_setup.call_deferred()


## Escena de prueba (standalone): mundo de la línea de órdenes, ganchos de M14 y M15 y captura.
func _setup() -> void:
	var seed_v: int = _arg_int("--seed=", world_seed)
	if seed_v == 0:
		seed_v = GameState.seed_value if GameState.seed_value != 0 else DEFAULT_SEED
	await build_world(seed_v)
	var start_chunk: Vector2i = _arg_vec("--chunk=", plan.home_chunk)
	start_chunk = WorldCoords.world_cell_to_chunk(_arg_vec("--cell=", WorldCoords.to_world_cell(start_chunk, Vector2i.ZERO)))
	var start: WorldChunk = pregen.get_chunk(start_chunk)
	player.is_blocked = streamer.is_blocked
	teleport(_arg_vec("--cell=", WorldCoords.to_world_cell(start_chunk, start.hub)))
	_setup_monsters()
	player.input_enabled = true
	_last_cell = player.mover.cell
	player.cell_changed.connect(_on_cell_changed)
	world_ready.emit()
	var capture_path: String = _arg_string("--capture=")
	if not capture_path.is_empty():
		_capture(capture_path)


## Construye el mundo de `seed_v` (RegionPlan, WorldCache, WorldPregen) con la pantalla "Creando
## el mundo…" hasta que el anillo inicial está listo, y prepara el WorldStreamer. Si ya está el
## mismo mundo (misma seed y región), no hace nada. No coloca al jugador: después, teleport().
## Corrutina: `await build_world(seed)`.
func build_world(seed_v: int) -> void:
	if streamer != null and plan != null and plan.seed_value == seed_v and plan.region_id == region_id:
		return
	is_ready = false
	_teardown()
	var screen: CanvasLayer = LOADING_SCENE.instantiate()
	# Encima del HUD y del fundido de la exploración (capa 10), debajo de la pantalla de dormir.
	screen.layer = LOADING_LAYER
	add_child(screen)
	# Que la pantalla se vea antes de la pasada de región (bloquea el hilo principal un momento).
	await get_tree().process_frame
	await get_tree().process_frame
	plan = RegionPlan.for_region(seed_v, region_id)
	# Los Bosques de todo el juego (BosqueStates, AdventureRules, MapLogic, cruce) salen de este plan.
	MapLogic.set_region_plan(plan)
	world_key = WorldCache.for_plan(plan, builder_version).world_key
	if use_cache:
		cache = WorldCache.for_plan(plan, builder_version)
		var err: Error = cache.prepare(plan)
		if err != OK:
			push_warning("WorldView: sin caché del mundo (%s); los chunks se quedan en memoria." % error_string(err))
			cache = null
	pregen = WorldPregen.new(plan, builder, cache)
	pregen.start()
	screen.track(pregen)
	await get_tree().process_frame
	var home_style: Dictionary = {}
	var home_bosque: int = plan.bosque_at(plan.home_chunk)
	if home_bosque >= 0 and home_bosque < plan.bosques.styles.size():
		home_style = plan.bosques.styles[home_bosque]
	painter = WorldPainter.new(home_style)
	var ts: TileSet = painter.build_tile_set()
	ground.tile_set = ts
	overlay.tile_set = ts
	painter.build_textures()
	if not pregen.is_ring_complete():
		await screen.finished
	screen.queue_free()
	streamer = WorldStreamer.new(plan, pregen, cache, painter, ground, overlay, objects)
	var size_px: Vector2i = plan.size_chunks * WorldCoords.CHUNK_PX
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = size_px.x
	camera.limit_bottom = size_px.y


## Pone los pies del jugador en el centro de la casilla global `world_cell` y monta de golpe lo
## que se ve desde ahí (aparición, carga, reaparición). Sin cell_changed.
func teleport(world_cell: Vector2i) -> void:
	player.place_at_cell(world_cell)
	camera.reset_smoothing()
	camera.force_update_scroll()
	streamer.mount_all(player.position, view_rect())
	_last_pos = player.position
	is_ready = true


## Suelta el mundo actual (otra seed: partida nueva o cargada de otro mundo).
func _teardown() -> void:
	if streamer != null:
		streamer.dispose()
		streamer = null
	if pregen != null:
		pregen.stop()
		pregen = null
	cache = null
	plan = null
	world_key = 0


# ponytail: gancho de M15 para ver los monstruos del Mundo 2.0 hasta que M17 monte la exploración
# nueva (que conectará `engaged` y `bosque_border_reached` al cruce). Los monstruos salen siempre;
# el límite de Bosque solo con `-- --borders` (sin el menú del cruce no se podría salir del natal).
func _setup_monsters() -> void:
	var home: int = plan.bosque_at(plan.home_chunk)
	if OS.get_cmdline_user_args().has("--borders"):
		border = BosqueBorder.new(BosqueBorder.plan_bosque_at(plan),
			func(b: int) -> bool: return not AdventureRules.is_passable(b, home))
		player.is_blocked = border.blocks(streamer.is_blocked)
	monsters = MonsterField.new()
	monsters.name = &"Monsters"
	monsters.y_sort_enabled = true
	objects.add_child(monsters)
	monsters.world_player = player
	monsters.terrain_blocked = streamer.is_blocked
	monsters.area_walkable = func(c: Vector2i) -> bool: return not streamer.is_blocked(c)
	monsters.populate_world(plan, home, streamer.chunk)
	monsters.engaged.connect(func(m: OverworldMonster) -> void: m.calm(float(m.cfg.get("engage_cooldown", 3.0))))
	if border != null:
		border.contacted.connect(func(b: int, c: Vector2i) -> void: monsters.summon_nearest(b, c))


func _physics_process(_delta: float) -> void:
	if border != null and is_ready:
		var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		border.tick(player.mover.cell, player.input_enabled and input != Vector2.ZERO)


func _exit_tree() -> void:
	if streamer != null:
		streamer.stop()
	if pregen != null:
		pregen.stop()
	if plan != null and MapLogic.region_plan() == plan:
		MapLogic.set_region_plan(null)


## Rectángulo del mundo que ve la cámara, en píxeles.
func view_rect() -> Rect2:
	var size: Vector2 = get_viewport_rect().size / camera.zoom
	var center: Vector2 = camera.get_screen_center_position()
	# Antes del primer fotograma la cámara aún no ha calculado su centro.
	if not camera.is_inside_tree() or center == Vector2.ZERO:
		center = player.position
	return Rect2(center - size * 0.5, size)


func _process(_delta: float) -> void:
	if not is_ready:
		return
	move_dir = player.position - _last_pos
	_last_pos = player.position
	streamer.update(player.position, view_rect(), move_dir)
	streamer.animate(Time.get_ticks_msec() / 1000.0)
	if _label.visible:
		var cell: Vector2i = player.mover.cell
		_label.text = "%d fps  chunk %s  casilla %s\nsectores %d (+%d)  chunks %d  mundo %.2f ms" % [
			Engine.get_frames_per_second(), WorldCoords.world_cell_to_chunk(cell),
			WorldCoords.world_cell_to_cell(cell), streamer.mounted_sectors().size(),
			streamer.pending_mounts, streamer.loaded_chunks().size(), streamer.last_update_usec / 1000.0]
		if not _notice.is_empty():
			_label.text += "\n" + _notice


# --- Gancho de prueba de la interacción (M14). La exploración nueva (M17) lo sustituye. --------

## Letreros por cell_changed (ADR 0014 §2): al llegar junto a uno, se lee.
func _on_cell_changed(world_cell: Vector2i) -> void:
	var near: Dictionary = Signpost.sign_entered(streamer.chunk, _last_cell, world_cell)
	_last_cell = world_cell
	if not near.is_empty():
		_notice = _sign_text(streamer.chunk(near.coord), near.cell)


func _unhandled_input(event: InputEvent) -> void:
	if standalone and is_ready and event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		_notice = interact_text()


## Lo que diría la interacción con E desde la posición del jugador (sin tocar GameState).
func interact_text() -> String:
	var target: Dictionary = Interaction.find_world(streamer.chunk, player.mover.world_pos, player.mover.facing)
	var chunk: WorldChunk = streamer.chunk(target.chunk)
	match target.kind:
		Interaction.Kind.SIGN:
			return _sign_text(chunk, target.local)
		Interaction.Kind.REFUGE:
			return Texts.get_text("refuge_prompt")
		Interaction.Kind.FRUIT_TREE:
			return Texts.get_text("fruit_prompt" if FruitRules.has_fruit_world(chunk, target.local) else "fruit_empty")
		Interaction.Kind.NUJIO:
			return Texts.get_text("nujio_prompt")
		Interaction.Kind.REST:
			return Texts.get_text("rest_prompt")
	return ""


func _sign_text(chunk: WorldChunk, cell: Vector2i) -> String:
	var home: int = plan.bosque_at(plan.home_chunk)
	var dest: Dictionary = Signpost.destination_world(plan.bosques, chunk, cell, home)
	if dest.is_empty() or dest.bosque_id < 0:
		return ""
	var villa: String = Signpost.villa_name(plan.seed_value, dest.bosque_id)
	return Signpost.text_world(villa, dest.to_home, dest.delta, dest.chunks)


func _arg_string(prefix: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""


## "x,y" -> Vector2i (o `fallback`).
func _arg_vec(prefix: String, fallback: Vector2i) -> Vector2i:
	var parts: PackedStringArray = _arg_string(prefix).split(",")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		return Vector2i(int(parts[0]), int(parts[1]))
	return fallback


func _arg_int(prefix: String, fallback: int) -> int:
	var s: String = _arg_string(prefix)
	return int(s) if s.is_valid_int() else fallback


## Anda unos pasos hacia la izquierda y abajo, guarda la imagen ×CAPTURE_SCALE y sale.
func _capture(path: String) -> void:
	_label.visible = false
	Input.action_press(&"move_left", 1.0)
	Input.action_press(&"move_down", 0.4)
	for _i: int in CAPTURE_WALK_FRAMES:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.resize(img.get_width() * CAPTURE_SCALE, img.get_height() * CAPTURE_SCALE, Image.INTERPOLATE_NEAREST)
	var err: Error = img.save_png(path)
	print("captura %s: %s" % [path, error_string(err)])
	Input.action_release(&"move_left")
	Input.action_release(&"move_down")
	get_tree().quit()
