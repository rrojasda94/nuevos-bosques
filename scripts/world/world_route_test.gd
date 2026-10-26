extends Node
## Ruta automática de rendimiento del WorldView (M12, ADR 0014 §6): recorre la región andando y
## corriendo y mide el peor fotograma y el tiempo de montaje de cada sector. Imprime los
## resultados y sale con código 1 si hay fotogramas de más de FRAME_LIMIT_MS atribuibles al mundo
## (en ese fotograma o en el anterior se montó o desmontó un sector, se cargó un chunk en el hilo
## principal o el update del streamer pasó de BUDGET_MS) o si algún chunk se generó en el acto.
## Necesita render: se ejecuta con ventana, no en la CI.
##
##     godot --path . res://scenes/world/world_route_test.tscn [-- --seed=N --builder=fake --quick]
##
## - El jugador va sin colisión (is_blocked siempre false) para cubrir la región entera sin
##   depender de que haya camino: se mide el streaming, no la navegación.
## - La entrada se simula con Input.action_press, como si se pulsaran las teclas.
## - Tramos: andar (100 px/s), correr (200 px/s) y una serpentina por toda la región corriendo a
##   ×3 (600 px/s, más exigente que el juego: 3 veces más sectores por segundo).
## - `--builder=fake` usa tests/unit/world/fake_chunk_builder.gd, que pone árboles 2×2 y un
##   letrero por chunk, para medir también el pool de sprites mientras el ChunkBuilder real no
##   pone objetos (M7). Su caché va aparte (otra versión).
## - Se quita la sincronía vertical para medir el coste real de cada fotograma.

const VIEW_SCENE: PackedScene = preload("res://scenes/world/world_view.tscn")
const FAKE_BUILDER: String = "res://tests/unit/world/fake_chunk_builder.gd"
const FAKE_VERSION: int = 9000
const FRAME_LIMIT_MS: float = 20.0
const BUDGET_MS: float = 2.0
const ARRIVE_PX: float = 12.0
const WARMUP_FRAMES: int = 10
const SERPENTINE_SCALE: float = 3.0

var _view: WorldView
## Tramos: { target: Vector2, run: bool, scale: float, name: String }.
var _legs: Array[Dictionary] = []
var _leg: int = 0
var _running: bool = false
var _frames: int = 0
var _last_usec: int = 0
var _worst_frame_us: int = 0
var _worst_world_frame_us: int = 0
var _worst_update_us: int = 0
var _slow_world_frames: int = 0
var _slow_other_frames: int = 0
var _frame_us: PackedInt32Array = PackedInt32Array()
var _leg_start_ms: int = 0
var _sync_loads: int = 0
var _mount_frames_over: int = 0


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_view = VIEW_SCENE.instantiate()
	if OS.get_cmdline_user_args().has("--builder=fake"):
		_view.builder = Callable(load(FAKE_BUILDER), "build")
		_view.builder_version = FAKE_VERSION
	_view.world_ready.connect(_on_world_ready)
	add_child(_view)


func _on_world_ready() -> void:
	var player: PlayerController = _view.player
	player.is_blocked = func(_c: Vector2i) -> bool: return false
	var start: Vector2 = player.position
	var px: Vector2 = Vector2(_view.plan.size_chunks * WorldCoords.CHUNK_PX)
	var chunk_px: float = WorldCoords.CHUNK_PX
	var margin: float = chunk_px * 0.5
	var clampv := func(v: Vector2) -> Vector2:
		return v.clamp(Vector2(margin, margin), px - Vector2(margin, margin))
	_legs.append({"target": clampv.call(start + Vector2(1200, 0)), "run": false, "scale": 1.0, "name": "andar"})
	_legs.append({"target": clampv.call(start + Vector2(-1200, -1600)), "run": true, "scale": 1.0, "name": "correr"})
	if not OS.get_cmdline_user_args().has("--quick"):
		var rows: int = _view.plan.size_chunks.y
		var left: bool = false
		for cy: int in range(1, rows, 3):
			var y: float = (cy + 0.5) * chunk_px
			_legs.append({"target": Vector2(margin if left else px.x - margin, y), "run": true, "scale": SERPENTINE_SCALE, "name": "serpentina"})
			left = not left
	_leg = 0
	_begin_leg()
	_running = true
	_last_usec = Time.get_ticks_usec()


func _begin_leg() -> void:
	var leg: Dictionary = _legs[_leg]
	_view.player.speed_scale = leg.scale
	if leg.run:
		Input.action_press(&"run")
	else:
		Input.action_release(&"run")
	_leg_start_ms = Time.get_ticks_msec()
	print("tramo %d/%d: %s hacia %s" % [_leg + 1, _legs.size(), leg.name, leg.target])


func _physics_process(_delta: float) -> void:
	if not _running:
		return
	var d: Vector2 = (_legs[_leg].target as Vector2) - _view.player.position
	if d.length() < ARRIVE_PX:
		_leg += 1
		if _leg >= _legs.size():
			_finish()
			return
		_begin_leg()
		return
	var dir: Vector2 = d.normalized()
	_press(&"move_right", maxf(dir.x, 0.0))
	_press(&"move_left", maxf(-dir.x, 0.0))
	_press(&"move_down", maxf(dir.y, 0.0))
	_press(&"move_up", maxf(-dir.y, 0.0))


func _press(action: StringName, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _process(_delta: float) -> void:
	if not _running:
		return
	var now: int = Time.get_ticks_usec()
	var frame_us: int = now - _last_usec
	_last_usec = now
	_frames += 1
	var s: WorldStreamer = _view.streamer
	var world: bool = s.last_update_usec > BUDGET_MS * 1000.0 or s.sync_loads > _sync_loads
	_sync_loads = s.sync_loads
	_worst_update_us = maxi(_worst_update_us, s.last_update_usec)
	if _frames <= WARMUP_FRAMES:
		return
	_frame_us.append(frame_us)
	_worst_frame_us = maxi(_worst_frame_us, frame_us)
	var attributable: bool = world
	if s.mounted_last > 0 or s.unmounted_last > 0:
		_worst_world_frame_us = maxi(_worst_world_frame_us, frame_us)
	if s.last_update_usec > BUDGET_MS * 1000.0:
		_mount_frames_over += 1
	if frame_us > FRAME_LIMIT_MS * 1000.0:
		print("  fotograma lento: %.2f ms en el fotograma %d (tramo %d, pies %s; montados %d, desmontados %d, mundo %.2f ms)" % [
			frame_us / 1000.0, _frames, _leg + 1, _view.player.position, s.mounted_last, s.unmounted_last,
			s.last_update_usec / 1000.0])
		if attributable:
			_slow_world_frames += 1
		else:
			_slow_other_frames += 1


func _finish() -> void:
	_running = false
	for a: StringName in [&"move_right", &"move_left", &"move_up", &"move_down", &"run"]:
		Input.action_release(a)
	var s: WorldStreamer = _view.streamer
	var mounts: PackedInt32Array = s.mount_usec.duplicate()
	mounts.sort()
	var frames: PackedInt32Array = _frame_us.duplicate()
	frames.sort()
	var total: int = 0
	for m: int in mounts:
		total += m
	var mean_ms: float = (total / float(maxi(1, mounts.size()))) / 1000.0
	var on_demand: int = _view.pregen.on_demand_count
	print("--- Ruta automática WorldView ---")
	print("fotogramas: %d  mediana %.2f ms  p99 %.2f ms  peor %.2f ms" % [
		frames.size(), _pct(frames, 0.5), _pct(frames, 0.99), _worst_frame_us / 1000.0])
	print("peor fotograma en el que se montó o desmontó un sector: %.2f ms" % (_worst_world_frame_us / 1000.0))
	print("fotogramas con el mundo por encima de %.0f ms: %d" % [BUDGET_MS, _mount_frames_over])
	print("fotogramas > %.0f ms: %d atribuibles al mundo, %d no (el mundo tardó < %.0f ms en ellos)" % [
		FRAME_LIMIT_MS, _slow_world_frames, _slow_other_frames, BUDGET_MS])
	print("sectores montados (hilo principal): %d  media %.2f ms  p95 %.2f ms  peor %.2f ms" % [
		mounts.size(), mean_ms, _pct(mounts, 0.95), (mounts[-1] if not mounts.is_empty() else 0) / 1000.0])
	var paints: PackedInt32Array = s.paint_usec.duplicate()
	paints.sort()
	print("piezas de sector (hilos): mediana %.2f ms  p95 %.2f ms" % [_pct(paints, 0.5), _pct(paints, 0.95)])
	print("peor update del streamer (todo lo del mundo en un fotograma): %.2f ms" % (_worst_update_us / 1000.0))
	print("chunks obligatorios en el hilo principal: %d  generados en el acto: %d" % [s.sync_loads, on_demand])
	var failed: bool = _slow_world_frames > 0 or on_demand > 0
	print("RESULTADO: %s" % ("FALLA" if failed else "OK"))
	get_tree().quit(1 if failed else 0)


static func _pct(sorted: PackedInt32Array, p: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[clampi(int(p * (sorted.size() - 1)), 0, sorted.size() - 1)] / 1000.0
