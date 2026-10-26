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
## No toca GameState (solo lee la seed si no se da otra). La exploración nueva (M17) la
## instanciará en lugar de la vieja y le conectará `cell_changed` del jugador a las reglas.
## Arranque: godot --path . res://scenes/world/world_view.tscn [-- --seed=N --chunk=x,y --cell=x,y --capture=<png>]
## (`--chunk` aparece en el hub de ese chunk en vez de en la villa natal; `--cell`, en esa
## casilla global.)

## La WorldPregen terminó el anillo inicial y los sectores de la vista están montados.
signal world_ready

const DEFAULT_SEED: int = 42
const LOADING_SCENE: PackedScene = preload("res://scenes/ui/world_loading.tscn")
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
## Desplazamiento del jugador en el último fotograma (píxeles).
var move_dir: Vector2 = Vector2.ZERO

var _last_pos: Vector2 = Vector2.ZERO

@onready var ground: TileMapLayer = $Ground
@onready var overlay: TileMapLayer = $Overlay
@onready var objects: Node2D = $Objects
@onready var player: PlayerController = $Objects/Player
@onready var camera: Camera2D = $Objects/Player/Camera2D
@onready var _label: Label = $Hud/Label


func _ready() -> void:
	player.input_enabled = false
	_setup.call_deferred()


func _setup() -> void:
	var seed_v: int = _arg_int("--seed=", world_seed)
	if seed_v == 0:
		seed_v = GameState.seed_value if GameState.seed_value != 0 else DEFAULT_SEED
	plan = RegionPlan.for_region(seed_v, region_id)
	if use_cache:
		cache = WorldCache.for_plan(plan, builder_version)
		var err: Error = cache.prepare(plan)
		if err != OK:
			push_warning("WorldView: sin caché del mundo (%s); los chunks se quedan en memoria." % error_string(err))
			cache = null
	pregen = WorldPregen.new(plan, builder, cache)
	pregen.start()
	var screen: Node = LOADING_SCENE.instantiate()
	add_child(screen)
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
	var start_chunk: Vector2i = _arg_vec("--chunk=", plan.home_chunk)
	start_chunk = WorldCoords.world_cell_to_chunk(_arg_vec("--cell=", WorldCoords.to_world_cell(start_chunk, Vector2i.ZERO)))
	var start: WorldChunk = pregen.get_chunk(start_chunk)
	player.place_at_cell(_arg_vec("--cell=", WorldCoords.to_world_cell(start_chunk, start.hub)))
	player.is_blocked = streamer.is_blocked
	var size_px: Vector2i = plan.size_chunks * WorldCoords.CHUNK_PX
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = size_px.x
	camera.limit_bottom = size_px.y
	camera.reset_smoothing()
	camera.force_update_scroll()
	streamer.mount_all(player.position, view_rect())
	_last_pos = player.position
	player.input_enabled = true
	is_ready = true
	world_ready.emit()
	var capture_path: String = _arg_string("--capture=")
	if not capture_path.is_empty():
		_capture(capture_path)


func _exit_tree() -> void:
	if streamer != null:
		streamer.stop()
	if pregen != null:
		pregen.stop()


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
