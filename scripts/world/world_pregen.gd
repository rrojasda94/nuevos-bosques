class_name WorldPregen
extends RefCounted
## Pregeneración de la región en hilos (ADR 0014 §6, "Pregeneración al crear la partida" y
## "Reglas de hilos"). Recibe el RegionPlan ya construido (pasada de región, un hilo) y genera
## todos sus chunks con un constructor inyectable:
##
##     builder: Callable(plan: RegionPlan, coord: Vector2i) -> WorldChunk
##
## 1. Anillo inicial: los chunks a <= RING_RADIUS (Chebyshev) de la villa natal, con
##    `OS.get_processor_count() - 1` tareas de WorkerThreadPool a la vez. La pantalla "Creando el
##    mundo…" (scenes/ui/world_loading.tscn) espera a ring_completed.
## 2. Resto de la región en segundo plano con `max(1, núcleos - 2)` tareas, por una cola de
##    prioridad: distancia al chunk del jugador, que se recalcula con set_player_chunk().
## 3. Cada chunk se lee de la WorldCache si es válido; si no, se construye y se guarda allí.
## 4. Los chunks se entregan al hilo principal por una cola con Mutex: poll() (que llama el dueño
##    cada fotograma, desde el hilo principal) los saca y emite las señales. Ninguna señal se emite
##    desde un hilo de trabajo.
## 5. get_chunk() de un chunk que aún no está: se construye en el acto en el hilo principal, con
##    un aviso en el registro (no debería pasar: el anillo de precarga va 2 chunks por delante).
##
## Reglas de hilos: el builder solo lee el plan (inmutable) y crea su propio ruido, RNG y A*; no
## toca el árbol de escena. El resultado no depende del orden ni del número de hilos (test).
## Esta clase no toca el árbol de escena ni GameState.
##
## Cómo se enchufa el ChunkBuilder real (M6+), en M12/M17:
##     var plan := RegionPlan.for_region(seed, region_id)
##     var cache := WorldCache.for_plan(plan, ChunkBuilder.VERSION)
##     var pregen := WorldPregen.new(plan, ChunkBuilder.build, cache)
##     pregen.start()
## (`ChunkBuilder.build` debe ser estática con la firma de arriba; si es de instancia, se pasa un
## Callable de una instancia sin estado mutable compartido.)
## El dueño debe llamar a stop() antes de soltarlo (o deja que PREDELETE espere a los hilos).

## Se entregó un chunk al hilo principal (de la caché o recién construido).
signal chunk_ready(coord: Vector2i, chunk: WorldChunk)
signal ring_progressed(done: int, total: int)
signal ring_completed
signal region_progressed(done: int, total: int)
signal region_completed

## Radio del anillo inicial y de precarga, en chunks (ADR 0014 §6: hasta 25 chunks).
const RING_RADIUS: int = 2
const TASK_NAME: String = "WorldPregen"

var plan: RegionPlan
## Chunks construidos en el acto por get_chunk() (aviso en el registro).
var on_demand_count: int = 0

var _builder: Callable
var _cache: WorldCache
## Sin caché, los chunks entregados se quedan en memoria para get_chunk().
var _memory: Dictionary = {}  # Vector2i -> WorldChunk
var _mutex: Mutex = Mutex.new()
# --- protegido por _mutex ---
var _pending: Array[Vector2i] = []
var _ring: Dictionary = {}  # Vector2i -> true
var _done: Dictionary = {}  # Vector2i -> true (producido; puede estar aún en _results)
var _results: Array[Array] = []  # [coord, chunk] esperando a poll()
var _focus: Vector2i = Vector2i.ZERO
var _limit: int = 0
var _background_limit: int = 1
var _running: int = 0
var _cancelled: bool = false
var _ring_left: int = 0
var _started_order: Array[Vector2i] = []
# --- solo hilo principal ---
var _tasks: Array[int] = []
var _total: int = 0
var _ring_total: int = 0
var _delivered: int = 0
var _ring_delivered: int = 0


func _init(region_plan: RegionPlan, builder: Callable, cache: WorldCache = null) -> void:
	plan = region_plan
	_builder = builder
	_cache = cache
	_focus = plan.home_chunk
	for c: Vector2i in initial_ring(plan):
		_ring[c] = true
	for y: int in plan.size_chunks.y:
		for x: int in plan.size_chunks.x:
			_pending.append(Vector2i(x, y))
	_total = _pending.size()
	_ring_total = _ring.size()
	_ring_left = _ring_total


func _notification(what: int) -> void:
	# En PREDELETE no se pueden llamar métodos del script: se espera a los hilos aquí mismo.
	if what == NOTIFICATION_PREDELETE and not _tasks.is_empty():
		_mutex.lock()
		_cancelled = true
		_mutex.unlock()
		for id: int in _tasks:
			WorkerThreadPool.wait_for_task_completion(id)
		_tasks.clear()


## Chunks a <= `radius` (Chebyshev) de la villa natal que caen dentro de la región, por filas.
static func initial_ring(region_plan: RegionPlan, radius: int = RING_RADIUS) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var home: Vector2i = region_plan.home_chunk
	for y: int in range(home.y - radius, home.y + radius + 1):
		for x: int in range(home.x - radius, home.x + radius + 1):
			if x >= 0 and y >= 0 and x < region_plan.size_chunks.x and y < region_plan.size_chunks.y:
				out.append(Vector2i(x, y))
	return out


## Tareas a la vez en el anillo inicial y en segundo plano (ADR 0014 §6).
static func initial_workers(cores: int = OS.get_processor_count()) -> int:
	return maxi(1, cores - 1)


static func background_workers(cores: int = OS.get_processor_count()) -> int:
	return maxi(1, cores - 2)


## Clave de orden de la cola (menor = antes): el anillo inicial primero, por cercanía a la villa
## natal; después, por distancia al jugador (al cuadrado); empates por fila y columna.
static func priority_key(coord: Vector2i, is_ring: bool, home: Vector2i, focus: Vector2i) -> Vector4i:
	var d: Vector2i = coord - (home if is_ring else focus)
	return Vector4i(0 if is_ring else 1, d.x * d.x + d.y * d.y, coord.y, coord.x)


## Arranca los hilos. `initial` y `background` = tareas a la vez (por defecto, según los núcleos).
func start(initial: int = -1, background: int = -1) -> void:
	var first: int = initial if initial > 0 else initial_workers()
	_mutex.lock()
	_background_limit = background if background > 0 else background_workers()
	_limit = first if _ring_left > 0 else _background_limit
	var launch: int = _limit - _running
	_running += maxi(0, launch)
	_mutex.unlock()
	for i: int in launch:
		_tasks.append(WorkerThreadPool.add_task(_work, true, TASK_NAME))


## Todo en el hilo que llama, en el orden de la cola (tests y PC de un núcleo). Entrega al final.
func run_serial() -> void:
	while true:
		var coord: Variant = _take_next()
		if coord == null:
			break
		_finish(coord, _produce(coord))
	poll()


## El jugador entró en otro chunk: la cola del segundo plano se reordena hacia él.
func set_player_chunk(coord: Vector2i) -> void:
	_mutex.lock()
	_focus = coord
	_mutex.unlock()


## Hilo principal, una vez por fotograma: entrega los chunks terminados y emite las señales.
func poll() -> void:
	_mutex.lock()
	var batch: Array[Array] = _results
	_results = []
	_mutex.unlock()
	for item: Array in batch:
		_deliver(item[0], item[1])
	for i: int in range(_tasks.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_tasks[i]):
			WorkerThreadPool.wait_for_task_completion(_tasks[i])
			_tasks.remove_at(i)


## Bloquea hasta que terminan los hilos y entrega lo que quede (tests y cierre de la pantalla).
func wait() -> void:
	for id: int in _tasks:
		WorkerThreadPool.wait_for_task_completion(id)
	_tasks.clear()
	poll()


## Cancela lo pendiente y espera a los hilos (los chunks en curso se terminan y se guardan).
func stop() -> void:
	_cancel_and_wait()
	poll()


## Chunk de la región (hilo principal). Si aún no está generado, se genera en el acto con aviso.
func get_chunk(coord: Vector2i) -> WorldChunk:
	poll()
	if _memory.has(coord):
		return _memory[coord]
	_mutex.lock()
	var done: bool = _done.has(coord)
	_mutex.unlock()
	if done and _cache != null:
		var cached: WorldChunk = _cache.load_chunk(coord)
		if cached != null:
			return cached
	push_warning("WorldPregen: el chunk %s no está listo (ni generado ni en la caché); se genera en el acto." % coord)
	on_demand_count += 1
	_mutex.lock()
	_pending.erase(coord)
	_mutex.unlock()
	var chunk: WorldChunk = _build_and_save(coord)
	_finish(coord, chunk)
	poll()
	return chunk


func is_ring_complete() -> bool:
	return _ring_delivered >= _ring_total


func is_complete() -> bool:
	return _delivered >= _total


func ring_total() -> int:
	return _ring_total


func ring_done() -> int:
	return _ring_delivered


func total() -> int:
	return _total


func done() -> int:
	return _delivered


## Coordenadas en el orden en que empezaron a generarse (para los tests de la cola).
func started_order() -> Array[Vector2i]:
	_mutex.lock()
	var out: Array[Vector2i] = _started_order.duplicate()
	_mutex.unlock()
	return out


# --- hilos ---------------------------------------------------------------------------------

func _work() -> void:
	while true:
		_mutex.lock()
		if _cancelled or _running > _limit:
			_running -= 1
			_mutex.unlock()
			return
		_mutex.unlock()
		var coord: Variant = _take_next()
		if coord == null:
			_mutex.lock()
			_running -= 1
			_mutex.unlock()
			return
		_finish(coord, _produce(coord))


## Saca de la cola el chunk de mayor prioridad (o null si no queda). Seguro entre hilos.
func _take_next() -> Variant:
	_mutex.lock()
	if _pending.is_empty():
		_mutex.unlock()
		return null
	var best: int = 0
	var best_key: Vector4i = priority_key(_pending[0], _ring.has(_pending[0]), plan.home_chunk, _focus)
	for i: int in range(1, _pending.size()):
		var key: Vector4i = priority_key(_pending[i], _ring.has(_pending[i]), plan.home_chunk, _focus)
		if key < best_key:
			best_key = key
			best = i
	var coord: Vector2i = _pending[best]
	_pending.remove_at(best)
	_started_order.append(coord)
	_mutex.unlock()
	return coord


## De la caché si vale; si no, se construye y se guarda. Se ejecuta en un hilo de trabajo.
func _produce(coord: Vector2i) -> WorldChunk:
	if _cache != null:
		var cached: WorldChunk = _cache.load_chunk(coord)
		if cached != null:
			return cached
	return _build_and_save(coord)


func _build_and_save(coord: Vector2i) -> WorldChunk:
	var chunk: WorldChunk = _builder.call(plan, coord)
	if _cache != null and chunk != null:
		var err: Error = _cache.save_chunk(chunk)
		if err != OK:
			push_warning("WorldPregen: no se pudo guardar el chunk %s en la caché (%s)." % [coord, error_string(err)])
	return chunk


## Apunta el chunk como hecho y lo deja en la cola de entrega (una sola vez por coordenada).
func _finish(coord: Vector2i, chunk: WorldChunk) -> void:
	_mutex.lock()
	if not _done.has(coord):
		_done[coord] = true
		_results.append([coord, chunk])
		if _ring.has(coord):
			_ring_left -= 1
			if _ring_left == 0:
				_limit = _background_limit
	_mutex.unlock()


func _deliver(coord: Vector2i, chunk: WorldChunk) -> void:
	if _cache == null:
		_memory[coord] = chunk
	_delivered += 1
	chunk_ready.emit(coord, chunk)
	if _ring.has(coord):
		_ring_delivered += 1
		ring_progressed.emit(_ring_delivered, _ring_total)
		if _ring_delivered == _ring_total:
			ring_completed.emit()
	region_progressed.emit(_delivered, _total)
	if _delivered == _total:
		region_completed.emit()


func _cancel_and_wait() -> void:
	_mutex.lock()
	_cancelled = true
	_mutex.unlock()
	for id: int in _tasks:
		WorkerThreadPool.wait_for_task_completion(id)
	_tasks.clear()
