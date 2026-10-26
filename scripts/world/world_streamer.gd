class_name WorldStreamer
extends RefCounted
## Streaming del Mundo 2.0 en juego (ADR 0014 §6, "Streaming en juego"). Lo usa WorldView, que
## llama a update() una vez por fotograma desde el hilo principal.
##
## - En memoria: el chunk del jugador y sus 8 vecinos (ACTIVE_RADIUS) son obligatorios; el anillo
##   de prefetch de 5×5 (PREFETCH_RADIUS) se lee de la WorldCache en hilos de WorkerThreadPool; los
##   que pasan de EVICT_RADIUS se sueltan (histéresis de un chunk). Los chunks recién generados
##   llegan por WorldPregen.chunk_ready; esta clase llama a WorldPregen.poll() en cada update() y
##   le pasa el chunk del jugador (set_player_chunk) para ordenar la cola del segundo plano.
## - Dibujados: los sectores que toca la vista más SECTOR_MARGIN; se desmontan al salir de
##   SECTOR_KEEP (un sector más de histéresis), como mucho UNMOUNTS_PER_FRAME por fotograma.
## - Montaje en dos partes, primero el sector que va hacia donde se mueve el jugador
##   (mount_priority):
##   1. Piezas, en hilos de WorkerThreadPool: WorldPainter.paint_sector (puro, ~1,4 ms) sobre una
##      copia del diccionario de chunks (los WorldChunk no cambian). Hasta PAINTS_PER_FRAME
##      tareas nuevas por fotograma.
##   2. En el hilo principal, como mucho MOUNTS_PER_FRAME sector ya pintado por fotograma: solo
##      set_cell (~0,15 ms por capa) y Sprite2D del pool. No se construyen nodos fuera del árbol en
##      los hilos: el sector no es un nodo propio sino un trozo de dos TileMapLayer compartidos (un
##      sector = un cuadrante de dibujo de 16×16), y set_cell no es seguro fuera del hilo principal.
## - Objetos con altura: Sprite2D de un pool, hijos del nodo con orden en Y. Se ocultan al
##   desmontar y se reutilizan.
## La lógica que se puede separar (sectores con histéresis, prioridad, anillos de chunks, índice
## de objetos por sector) son funciones estáticas puras, testeadas en test_world_streamer.gd.

const ACTIVE_RADIUS: int = 1
const PREFETCH_RADIUS: int = 2
const EVICT_RADIUS: int = 3
const SECTOR_MARGIN: int = 1
const SECTOR_KEEP: int = SECTOR_MARGIN + 1
const MOUNTS_PER_FRAME: int = 1
const PAINTS_PER_FRAME: int = 4
const UNMOUNTS_PER_FRAME: int = 2
## Cuánto adelanta un sector que está en la dirección de la marcha (0 = solo distancia).
const AHEAD_WEIGHT: float = 0.75
const POOL_PREWARM: int = 384
const TASK_NAME: String = "WorldStreamer"

var plan: RegionPlan
var pregen: WorldPregen
var cache: WorldCache
var painter: WorldPainter
var ground: TileMapLayer
var overlay: TileMapLayer
var objects_root: Node2D
## Tamaño de la región en sectores.
var region_sectors: Vector2i

# --- estadísticas (para la ruta automática y el HUD de depuración) ---
## Tiempo de update() del último fotograma, en µs.
var last_update_usec: int = 0
## Sectores montados y desmontados en el último update().
var mounted_last: int = 0
var unmounted_last: int = 0
## Tiempo de cada montaje de sector en el hilo principal, en µs (sin el inicial).
var mount_usec: PackedInt32Array = PackedInt32Array()
## Tiempo de cada paint_sector en los hilos, en µs.
var paint_usec: PackedInt32Array = PackedInt32Array()
## Chunks obligatorios que hubo que leer o construir en el hilo principal.
var sync_loads: int = 0
## Sectores pendientes de montar tras el último update().
var pending_mounts: int = 0

var _chunks: Dictionary = {}  # Vector2i -> WorldChunk
var _sector_objects: Dictionary = {}  # Vector2i chunk -> Array[PackedInt32Array] (25)
var _delivered: Dictionary = {}  # Vector2i -> true: WorldPregen lo entregó (sin caché, está en su memoria)
var _loading: Dictionary = {}  # Vector2i -> id de tarea
var _mutex: Mutex = Mutex.new()
var _results: Array[Array] = []  # [coord, chunk, índice de objetos], protegido por _mutex
var _mounted: Dictionary = {}  # Vector2i sector -> Array[Sprite2D]
var _painting: Dictionary = {}  # Vector2i sector -> id de tarea
var _painted: Dictionary = {}  # Vector2i sector -> resultado de paint_sector
var _paint_results: Array[Array] = []  # [sector, resultado, µs], protegido por _mutex
var _pool: Array[Sprite2D] = []
var _nujios: Dictionary = {}  # Sprite2D -> true
var _player_chunk: Vector2i = Vector2i(-1048576, -1048576)
var _initial: bool = false


func _init(p_plan: RegionPlan, p_pregen: WorldPregen, p_cache: WorldCache, p_painter: WorldPainter,
		p_ground: TileMapLayer, p_overlay: TileMapLayer, p_objects: Node2D) -> void:
	plan = p_plan
	pregen = p_pregen
	cache = p_cache
	painter = p_painter
	ground = p_ground
	overlay = p_overlay
	objects_root = p_objects
	region_sectors = plan.size_chunks * WorldCoords.SECTORS_PER_CHUNK
	pregen.chunk_ready.connect(_on_chunk_ready)
	for i: int in POOL_PREWARM:
		_pool.append(_new_sprite())


# --- lógica pura -----------------------------------------------------------------------------

## Sectores (globales) que toca el rectángulo `view` (píxeles del mundo), ampliado `margin`
## sectores y recortado a la región. Vacío si no se cruzan.
static func sector_range(view: Rect2, margin: int, sectors: Vector2i) -> Rect2i:
	var a: Vector2i = WorldCoords.cell_to_sector(WorldCoords.world_pos_to_world_cell(view.position))
	var b: Vector2i = WorldCoords.cell_to_sector(WorldCoords.world_pos_to_world_cell(view.end - Vector2(0.01, 0.01)))
	a = (a - Vector2i(margin, margin)).max(Vector2i.ZERO)
	b = (b + Vector2i(margin, margin)).min(sectors - Vector2i.ONE)
	if b.x < a.x or b.y < a.y:
		return Rect2i()
	return Rect2i(a, b - a + Vector2i.ONE)


## Qué montar y qué desmontar: se quieren los sectores de la vista + SECTOR_MARGIN; se quitan
## solo los montados que salen de la vista + SECTOR_KEEP (histéresis). `mounted`: sector -> algo.
static func plan_sectors(mounted: Dictionary, view: Rect2, sectors: Vector2i) -> Dictionary:
	var want: Rect2i = sector_range(view, SECTOR_MARGIN, sectors)
	var keep: Rect2i = sector_range(view, SECTOR_KEEP, sectors)
	var mount: Array[Vector2i] = []
	var unmount: Array[Vector2i] = []
	for y: int in range(want.position.y, want.end.y):
		for x: int in range(want.position.x, want.end.x):
			var s := Vector2i(x, y)
			if not mounted.has(s):
				mount.append(s)
	for s: Vector2i in mounted:
		if not keep.has_point(s):
			unmount.append(s)
	return {"mount": mount, "unmount": unmount}


## Centro del sector en píxeles del mundo.
static func sector_center(sector: Vector2i) -> Vector2:
	var half := Vector2i(WorldCoords.SECTOR / 2, WorldCoords.SECTOR / 2)
	return WorldCoords.world_cell_origin(WorldCoords.sector_origin(sector) + half)


## Prioridad de montaje (menor = antes): distancia al jugador, rebajada para los sectores que
## están hacia donde se mueve (`move_dir`, sin normalizar; cero = quieto).
static func mount_priority(sector: Vector2i, focus: Vector2, move_dir: Vector2) -> float:
	var d: Vector2 = sector_center(sector) - focus
	var dir: Vector2 = move_dir.normalized() if move_dir.length_squared() > 0.0 else Vector2.ZERO
	return d.length() - AHEAD_WEIGHT * d.dot(dir)


## Ordena la cola de montaje por prioridad (estable: empates por fila y columna).
static func sort_queue(queue: Array[Vector2i], focus: Vector2, move_dir: Vector2) -> void:
	queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var pa: float = mount_priority(a, focus, move_dir)
		var pb: float = mount_priority(b, focus, move_dir)
		if pa != pb:
			return pa < pb
		return a.y < b.y or (a.y == b.y and a.x < b.x))


## Chunks a <= `radius` (Chebyshev) de `center` dentro de la región, por filas.
static func chunk_ring(center: Vector2i, radius: int, size: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in range(maxi(center.y - radius, 0), mini(center.y + radius, size.y - 1) + 1):
		for x: int in range(maxi(center.x - radius, 0), mini(center.x + radius, size.x - 1) + 1):
			out.append(Vector2i(x, y))
	return out


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Chunks que se sueltan: los de `loaded` a más de EVICT_RADIUS del jugador.
static func chunks_to_evict(loaded: Array, player_chunk: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in loaded:
		if chebyshev(c, player_chunk) > EVICT_RADIUS:
			out.append(c)
	return out


## Índices de `chunk.objects` por sector local del chunk (25 listas, índice = y * 5 + x), según
## la casilla noroeste de cada objeto. La cueva no va: se dibuja en la capa de suelo.
static func objects_by_sector(chunk: WorldChunk) -> Array[PackedInt32Array]:
	var per: int = WorldCoords.SECTORS_PER_CHUNK
	var out: Array[PackedInt32Array] = []
	out.resize(per * per)
	for k: int in out.size():
		out[k] = PackedInt32Array()
	for i: int in chunk.objects.size():
		var obj: Dictionary = chunk.objects[i]
		if obj.kind == WorldChunk.ObjectKind.CAVE:
			continue
		var s: Vector2i = WorldCoords.cell_to_sector(obj.cell)
		out[s.y * per + s.x].append(i)
	return out


# --- en juego --------------------------------------------------------------------------------

## Chunk en memoria (o null).
func chunk(coord: Vector2i) -> WorldChunk:
	return _chunks.get(coord)


func loaded_chunks() -> Array:
	return _chunks.keys()


func mounted_sectors() -> Array:
	return _mounted.keys()


## La casilla global no se puede pisar. Fuera de la región o sin chunk cargado, bloquea.
func is_blocked(world_cell: Vector2i) -> bool:
	var c: WorldChunk = _chunks.get(WorldCoords.world_cell_to_chunk(world_cell))
	if c == null:
		return true
	return c.blocked[WorldCoords.cell_index(WorldCoords.world_cell_to_cell(world_cell))] == 1


## Carga los chunks obligatorios y monta todos los sectores de la vista de golpe (pantalla de
## carga, aparición). No cuenta en las estadísticas de montaje.
func mount_all(focus: Vector2, view: Rect2) -> void:
	_initial = true
	pregen.poll()
	_drain_loads()
	_set_player_chunk(WorldCoords.world_pos_to_chunk(focus))
	_ensure_active()
	var plan_s: Dictionary = plan_sectors(_mounted, view, region_sectors)
	for s: Vector2i in plan_s.unmount:
		_unmount(s)
	for s: Vector2i in plan_s.mount:
		var paint: Dictionary = WorldPainter.paint_sector(s, _chunks)
		if not paint.is_empty():
			_apply(s, paint)
	_initial = false


## Una vez por fotograma (hilo principal). `focus`: pies del jugador; `view`: rectángulo que ve la
## cámara, en píxeles del mundo; `move_dir`: hacia dónde se mueve (cero si está quieto).
func update(focus: Vector2, view: Rect2, move_dir: Vector2) -> void:
	var t0: int = Time.get_ticks_usec()
	mounted_last = 0
	unmounted_last = 0
	pregen.poll()
	_drain_loads()
	var pc: Vector2i = WorldCoords.world_pos_to_chunk(focus)
	if pc != _player_chunk:
		_set_player_chunk(pc)
	_ensure_active()
	var plan_s: Dictionary = plan_sectors(_mounted, view, region_sectors)
	var unmount: Array[Vector2i] = plan_s.unmount
	for k: int in mini(unmount.size(), UNMOUNTS_PER_FRAME):
		_unmount(unmount[k])
		unmounted_last += 1
	var queue: Array[Vector2i] = plan_s.mount
	sort_queue(queue, focus, move_dir)
	_drain_paints(view)
	pending_mounts = queue.size()
	var launched: int = 0
	var snapshot: Dictionary = {}
	for s: Vector2i in queue:
		if _painted.has(s):
			if mounted_last < MOUNTS_PER_FRAME:
				_apply(s, _painted[s])
				_painted.erase(s)
				mounted_last += 1
				pending_mounts -= 1
		elif not _painting.has(s) and launched < PAINTS_PER_FRAME 				and _chunks.has(WorldCoords.world_cell_to_chunk(WorldCoords.sector_origin(s))):
			if snapshot.is_empty():
				snapshot = _chunks.duplicate()
			_painting[s] = WorkerThreadPool.add_task(_paint_task.bind(s, snapshot), false, TASK_NAME)
			launched += 1
	last_update_usec = Time.get_ticks_usec() - t0


## Fotograma del Nujio (2 a 1 fps).
func animate(time_sec: float) -> void:
	var x: int = (int(time_sec) % 2) * WorldPainter.NUJIO_FRAME_W
	for sp: Sprite2D in _nujios:
		var r: Rect2 = sp.region_rect
		if int(r.position.x) != x:
			r.position.x = x
			sp.region_rect = r


## Espera a los hilos de lectura. Llamar antes de soltar el streamer.
func stop() -> void:
	for c: Vector2i in _loading:
		WorkerThreadPool.wait_for_task_completion(_loading[c])
	_loading.clear()
	for sector: Vector2i in _painting:
		WorkerThreadPool.wait_for_task_completion(_painting[sector])
	_painting.clear()
	_mutex.lock()
	_results.clear()
	_paint_results.clear()
	_mutex.unlock()


# --- chunks ----------------------------------------------------------------------------------

func _set_player_chunk(pc: Vector2i) -> void:
	_player_chunk = pc
	pregen.set_player_chunk(pc)
	for c: Vector2i in chunks_to_evict(_chunks.keys(), pc):
		_chunks.erase(c)
		_sector_objects.erase(c)
	for c: Vector2i in chunk_ring(pc, PREFETCH_RADIUS, plan.size_chunks):
		if not _chunks.has(c) and not _loading.has(c):
			_start_load(c)


func _start_load(c: Vector2i) -> void:
	if cache == null:
		# Sin caché, WorldPregen guarda en memoria lo que ya entregó.
		if _delivered.has(c):
			_store(c, pregen.get_chunk(c))
		return
	_loading[c] = WorkerThreadPool.add_task(_load_task.bind(c), false, TASK_NAME)


## Hilo de trabajo: lee y descomprime el chunk de la caché y prepara su índice de objetos.
func _load_task(c: Vector2i) -> void:
	var loaded: WorldChunk = cache.load_chunk(c)
	var index: Array[PackedInt32Array] = []
	if loaded != null:
		index = objects_by_sector(loaded)
	_mutex.lock()
	_results.append([c, loaded, index])
	_mutex.unlock()


func _drain_loads() -> void:
	_mutex.lock()
	var batch: Array[Array] = _results
	_results = []
	_mutex.unlock()
	for item: Array in batch:
		var c: Vector2i = item[0]
		if _loading.has(c):
			WorkerThreadPool.wait_for_task_completion(_loading[c])
			_loading.erase(c)
		if item[1] != null and not _chunks.has(c) and chebyshev(c, _player_chunk) <= EVICT_RADIUS:
			_chunks[c] = item[1]
			_sector_objects[c] = item[2]


func _on_chunk_ready(c: Vector2i, ready_chunk: WorldChunk) -> void:
	_delivered[c] = true
	if not _chunks.has(c) and chebyshev(c, _player_chunk) <= PREFETCH_RADIUS:
		_store(c, ready_chunk)


func _store(c: Vector2i, value: WorldChunk) -> void:
	if value == null:
		return
	_chunks[c] = value
	_sector_objects[c] = objects_by_sector(value)


## Los chunks obligatorios tienen que estar: si falta uno, se espera a su lectura o se pide a
## WorldPregen en el acto (que lo construye con un aviso si aún no existe).
func _ensure_active() -> void:
	for c: Vector2i in chunk_ring(_player_chunk, ACTIVE_RADIUS, plan.size_chunks):
		if _chunks.has(c):
			continue
		if _loading.has(c):
			WorkerThreadPool.wait_for_task_completion(_loading[c])
			_loading.erase(c)
			_drain_loads()
			if _chunks.has(c):
				if not _initial:
					sync_loads += 1
				continue
		_store(c, pregen.get_chunk(c))
		if not _initial:
			sync_loads += 1


# --- sectores --------------------------------------------------------------------------------

## Hilo de trabajo: piezas del sector sobre una copia del diccionario de chunks.
func _paint_task(sector: Vector2i, chunks: Dictionary) -> void:
	var t0: int = Time.get_ticks_usec()
	var paint: Dictionary = WorldPainter.paint_sector(sector, chunks)
	var us: int = Time.get_ticks_usec() - t0
	_mutex.lock()
	_paint_results.append([sector, paint, us])
	_mutex.unlock()


## Recoge las piezas terminadas. Las de sectores que ya no hacen falta se tiran.
func _drain_paints(view: Rect2) -> void:
	_mutex.lock()
	var batch: Array[Array] = _paint_results
	_paint_results = []
	_mutex.unlock()
	var keep: Rect2i = sector_range(view, SECTOR_KEEP, region_sectors)
	for item: Array in batch:
		var s: Vector2i = item[0]
		if _painting.has(s):
			WorkerThreadPool.wait_for_task_completion(_painting[s])
			_painting.erase(s)
		paint_usec.append(item[2])
		var paint: Dictionary = item[1]
		if not paint.is_empty() and keep.has_point(s) and not _mounted.has(s):
			_painted[s] = paint
	for s: Vector2i in _painted.keys():
		if not keep.has_point(s):
			_painted.erase(s)


## Hilo principal: pone las piezas del sector y saca sus sprites del pool.
func _apply(sector: Vector2i, paint: Dictionary) -> void:
	var t0: int = Time.get_ticks_usec()
	var origin: Vector2i = WorldCoords.sector_origin(sector)
	var sz: int = WorldCoords.SECTOR
	var g: PackedInt32Array = paint.ground
	var o: PackedInt32Array = paint.overlay
	for i: int in sz * sz:
		var cell := Vector2i(origin.x + i % sz, origin.y + i / sz)
		var code: int = g[i]
		ground.set_cell(cell, code >> 24, Vector2i((code >> 16) & 255, (code >> 8) & 255), code & 255)
		code = o[i]
		if code != WorldPainter.NONE:
			overlay.set_cell(cell, code >> 24, Vector2i((code >> 16) & 255, (code >> 8) & 255), code & 255)
	# Que el TileMapLayer rehaga su cuadrante ahora y no al final del fotograma: así su coste
	# entra en el presupuesto medido.
	ground.update_internals()
	overlay.update_internals()
	var sprites: Array[Sprite2D] = []
	var cc: Vector2i = WorldCoords.world_cell_to_chunk(origin)
	var ch: WorldChunk = _chunks[cc]
	var ls: Vector2i = WorldCoords.cell_to_sector(WorldCoords.world_cell_to_cell(origin))
	var index: Array = _sector_objects.get(cc, [])
	if not index.is_empty():
		for oi: int in index[ls.y * WorldCoords.SECTORS_PER_CHUNK + ls.x]:
			var obj: Dictionary = ch.objects[oi]
			var sp: Sprite2D = _pool.pop_back() if not _pool.is_empty() else _new_sprite()
			var dir: Vector2i = Vector2i.ZERO
			if obj.kind == WorldChunk.ObjectKind.SIGN:
				dir = ch.sign_at(obj.cell).get("direction", Vector2i.ZERO)
			if painter.setup_sprite(sp, obj, cc, dir):
				sprites.append(sp)
				if obj.kind == WorldChunk.ObjectKind.NUJIO:
					_nujios[sp] = true
			else:
				_pool.append(sp)
	_mounted[sector] = sprites
	if not _initial:
		mount_usec.append(Time.get_ticks_usec() - t0)


func _unmount(sector: Vector2i) -> void:
	var origin: Vector2i = WorldCoords.sector_origin(sector)
	var sz: int = WorldCoords.SECTOR
	for y: int in sz:
		for x: int in sz:
			var cell := Vector2i(origin.x + x, origin.y + y)
			ground.erase_cell(cell)
			overlay.erase_cell(cell)
	ground.update_internals()
	overlay.update_internals()
	for sp: Sprite2D in _mounted.get(sector, []):
		sp.visible = false
		_nujios.erase(sp)
		_pool.append(sp)
	_mounted.erase(sector)


func _new_sprite() -> Sprite2D:
	var sp := Sprite2D.new()
	sp.visible = false
	sp.centered = false
	objects_root.add_child(sp)
	return sp
