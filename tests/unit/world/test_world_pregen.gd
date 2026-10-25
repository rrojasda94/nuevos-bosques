extends GutTest
## Pregeneración en hilos (WorldPregen, ADR 0014 §6, M10) con el ChunkBuilder falso: serie =
## paralelo byte a byte (en memoria y en la caché), anillo inicial y cola por prioridad
## recalculable, entrega por poll() con señales de progreso, generación en el acto con aviso,
## lectura de la caché y tamaño medio por chunk en caché (aviso, no fallo).

const FakeBuilder := preload("res://tests/unit/world/fake_chunk_builder.gd")
const ROOT: String = "user://test_world_pregen"

var _plan: RegionPlan


func before_all() -> void:
	_plan = _blank_plan(Vector2i(7, 6), Vector2i(2, 2))


func before_each() -> void:
	WorldCache.clean_unused([], ROOT)


func after_all() -> void:
	WorldCache.clean_unused([], ROOT)
	DirAccess.remove_absolute(ROOT)


func _blank_plan(size: Vector2i, home: Vector2i, seed_value: int = 42) -> RegionPlan:
	var plan := RegionPlan.new()
	plan.seed_value = seed_value
	plan.region_id = &"test"
	plan.size_chunks = size
	plan.home_chunk = home
	return plan


## Todos los chunks entregados, coord -> bytes de to_dict.
func _collect(pregen: WorldPregen) -> Dictionary:
	var out: Dictionary = {}
	pregen.chunk_ready.connect(func(coord: Vector2i, chunk: WorldChunk) -> void:
		out[coord] = var_to_bytes(chunk.to_dict()))
	return out


func _cache_files(cache: WorldCache, plan: RegionPlan) -> Dictionary:
	var out: Dictionary = {}
	for y: int in plan.size_chunks.y:
		for x: int in plan.size_chunks.x:
			out[Vector2i(x, y)] = FileAccess.get_file_as_bytes(cache.chunk_path(Vector2i(x, y)))
	return out


func test_initial_ring_and_workers() -> void:
	var ring: Array[Vector2i] = WorldPregen.initial_ring(_plan)
	assert_eq(ring.size(), 25, "5×5 alrededor de la villa natal")
	for c: Vector2i in ring:
		assert_true(maxi(absi(c.x - 2), absi(c.y - 2)) <= 2)
	var corner: Array[Vector2i] = WorldPregen.initial_ring(_blank_plan(Vector2i(7, 6), Vector2i(0, 0)))
	assert_eq(corner.size(), 9, "recortado por el borde de la región")
	assert_eq(WorldPregen.initial_workers(8), 7)
	assert_eq(WorldPregen.background_workers(8), 6)
	assert_eq(WorldPregen.initial_workers(1), 1, "nunca 0 tareas")
	assert_eq(WorldPregen.background_workers(2), 1)


func test_serial_equals_parallel_byte_for_byte() -> void:
	var serial := WorldPregen.new(_plan, FakeBuilder.build)
	var serial_bytes: Dictionary = _collect(serial)
	serial.run_serial()
	assert_eq(serial_bytes.size(), 42, "todos los chunks en serie")
	for workers: int in [2, 4, 8]:
		var parallel := WorldPregen.new(_plan, FakeBuilder.build)
		var parallel_bytes: Dictionary = _collect(parallel)
		parallel.start(workers, maxi(1, workers - 1))
		parallel.wait()
		assert_true(parallel.is_complete(), "%d hilos terminan" % workers)
		assert_eq(parallel_bytes.size(), 42)
		var same: bool = true
		for coord: Vector2i in serial_bytes:
			if parallel_bytes.get(coord) != serial_bytes[coord]:
				same = false
				fail_test("%s difiere con %d hilos" % [coord, workers])
				break
		assert_true(same, "serie = paralelo con %d hilos" % workers)


func test_serial_equals_parallel_in_cache_files() -> void:
	var serial_cache := WorldCache.new(77, ROOT + "/serie")
	var serial := WorldPregen.new(_plan, FakeBuilder.build, serial_cache)
	serial.run_serial()
	var parallel_cache := WorldCache.new(77, ROOT + "/paralelo")
	var parallel := WorldPregen.new(_plan, FakeBuilder.build, parallel_cache)
	parallel.start(4, 3)
	parallel.wait()
	var a: Dictionary = _cache_files(serial_cache, _plan)
	var b: Dictionary = _cache_files(parallel_cache, _plan)
	var same: bool = true
	for coord: Vector2i in a:
		if (a[coord] as PackedByteArray).is_empty() or a[coord] != b[coord]:
			same = false
	assert_true(same, "los archivos de caché son idénticos en serie y en paralelo")
	WorldCache.clean_unused([], ROOT + "/serie")
	WorldCache.clean_unused([], ROOT + "/paralelo")
	DirAccess.remove_absolute(ROOT + "/serie")
	DirAccess.remove_absolute(ROOT + "/paralelo")


func test_queue_order_ring_first_then_distance_to_player() -> void:
	var pregen := WorldPregen.new(_plan, FakeBuilder.build)
	pregen.run_serial()
	var order: Array[Vector2i] = pregen.started_order()
	assert_eq(order.size(), 42)
	var ring: Array[Vector2i] = WorldPregen.initial_ring(_plan)
	for i: int in ring.size():
		assert_true(order[i] in ring, "los 25 del anillo van primero (%d: %s)" % [i, order[i]])
	assert_eq(order[0], _plan.home_chunk, "empieza por la villa natal")
	_assert_non_decreasing(order, 0, ring.size(), _plan.home_chunk, "anillo")
	_assert_non_decreasing(order, ring.size(), order.size(), _plan.home_chunk, "segundo plano")


func test_queue_follows_player_when_recalculated() -> void:
	var pregen := WorldPregen.new(_plan, FakeBuilder.build)
	var far := Vector2i(6, 5)
	var switch_at: Array[int] = [-1]
	# El constructor falso corre en el mismo hilo en serie: tras el anillo, el jugador se mueve.
	var builder := func(plan: RegionPlan, coord: Vector2i) -> WorldChunk:
		if pregen.started_order().size() == 25 and switch_at[0] < 0:
			switch_at[0] = 25
			pregen.set_player_chunk(far)
		return FakeBuilder.build(plan, coord)
	pregen._builder = builder
	pregen.run_serial()
	pregen._builder = Callable()  # rompe el ciclo pregen <-> lambda
	var order: Array[Vector2i] = pregen.started_order()
	assert_eq(switch_at[0], 25)
	# El jugador se movió durante el último chunk del anillo: lo siguiente ya va hacia él.
	assert_eq(order[25], far, "lo primero tras moverse es el chunk del jugador")
	_assert_non_decreasing(order, 25, order.size(), far, "hacia el jugador")
	assert_eq(order.size(), 42)


func test_priority_key() -> void:
	var home := Vector2i(2, 2)
	var focus := Vector2i(5, 5)
	var k_ring: Vector4i = WorldPregen.priority_key(Vector2i(4, 4), true, home, focus)
	var k_near: Vector4i = WorldPregen.priority_key(Vector2i(5, 5), false, home, focus)
	assert_true(k_ring < k_near, "el anillo siempre antes")
	assert_true(WorldPregen.priority_key(Vector2i(5, 6), false, home, focus)
			< WorldPregen.priority_key(Vector2i(6, 7), false, home, focus), "más cerca, antes")
	assert_true(WorldPregen.priority_key(Vector2i(4, 5), false, home, focus)
			< WorldPregen.priority_key(Vector2i(6, 5), false, home, focus), "empate: por columna")


func test_progress_signals_and_ring_completed() -> void:
	var pregen := WorldPregen.new(_plan, FakeBuilder.build)
	var ring_events: Array[Vector2i] = []
	var region_events: Array[int] = []
	var flags: Dictionary = {"ring": 0, "region": 0}
	pregen.ring_progressed.connect(func(d: int, t: int) -> void: ring_events.append(Vector2i(d, t)))
	pregen.region_progressed.connect(func(d: int, _t: int) -> void: region_events.append(d))
	pregen.ring_completed.connect(func() -> void: flags.ring += 1)
	pregen.region_completed.connect(func() -> void: flags.region += 1)
	pregen.start(3, 2)
	pregen.wait()
	assert_eq(ring_events.size(), 25)
	assert_eq(ring_events.back(), Vector2i(25, 25))
	assert_eq(region_events.size(), 42)
	assert_eq(region_events.back(), 42)
	assert_eq(flags.ring, 1, "ring_completed una vez")
	assert_eq(flags.region, 1, "region_completed una vez")
	assert_true(pregen.is_ring_complete())
	assert_eq(pregen.done(), pregen.total())


func test_nothing_is_delivered_without_poll() -> void:
	var pregen := WorldPregen.new(_blank_plan(Vector2i(3, 3), Vector2i(1, 1)), FakeBuilder.build)
	var got: Array[Vector2i] = []
	pregen.chunk_ready.connect(func(c: Vector2i, _ch: WorldChunk) -> void: got.append(c))
	pregen.start(2, 1)
	for id: int in pregen._tasks:
		WorkerThreadPool.wait_for_task_completion(id)
	pregen._tasks.clear()
	assert_eq(got.size(), 0, "los hilos no emiten señales: se entrega en poll()")
	pregen.poll()
	assert_eq(got.size(), 9)


func test_on_demand_builds_missing_chunk() -> void:
	var pregen := WorldPregen.new(_plan, FakeBuilder.build)
	var coord := Vector2i(6, 0)
	var chunk: WorldChunk = pregen.get_chunk(coord)
	assert_not_null(chunk)
	assert_eq(pregen.on_demand_count, 1, "se genera en el acto con aviso")
	assert_eq(var_to_bytes(chunk.to_dict()), var_to_bytes(FakeBuilder.build(_plan, coord).to_dict()),
			"igual que el de la pregeneración")
	assert_eq(pregen.done(), 1, "cuenta en el progreso")
	pregen.run_serial()
	assert_false(coord in pregen.started_order(), "no se vuelve a generar")
	assert_eq(pregen.done(), 42)
	assert_eq(pregen.get_chunk(coord), chunk, "sin caché se queda en memoria")
	assert_eq(pregen.on_demand_count, 1, "ya generado: sin aviso")


func test_on_demand_with_cache_reads_after_pregen() -> void:
	var cache := WorldCache.new(5, ROOT)
	var pregen := WorldPregen.new(_plan, FakeBuilder.build, cache)
	pregen.start(4, 2)
	pregen.wait()
	var chunk: WorldChunk = pregen.get_chunk(Vector2i(5, 5))
	assert_not_null(chunk)
	assert_eq(pregen.on_demand_count, 0, "estaba en la caché")
	# Si alguien borra el archivo, se regenera en el acto.
	DirAccess.remove_absolute(cache.chunk_path(Vector2i(4, 4)))
	assert_not_null(pregen.get_chunk(Vector2i(4, 4)))
	assert_eq(pregen.on_demand_count, 1)
	assert_true(cache.has_chunk(Vector2i(4, 4)), "y se vuelve a guardar")


func test_second_run_reads_the_cache() -> void:
	var cache := WorldCache.new(6, ROOT)
	var first := WorldPregen.new(_plan, FakeBuilder.build, cache)
	first.start(4, 2)
	first.wait()
	var built: Array[int] = [0]
	var counting := func(plan: RegionPlan, coord: Vector2i) -> WorldChunk:
		built[0] += 1
		return FakeBuilder.build(plan, coord)
	# Un chunk corrupto en medio: solo se regenera ese.
	var path: String = cache.chunk_path(Vector2i(3, 3))
	var bad: PackedByteArray = FileAccess.get_file_as_bytes(path)
	bad[bad.size() / 2] ^= 0xFF
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bad)
	f.close()
	var second := WorldPregen.new(_plan, counting, cache)
	var bytes: Dictionary = _collect(second)
	second.run_serial()
	assert_eq(built[0], 1, "solo se regenera el chunk corrupto")
	assert_eq(bytes[Vector2i(3, 3)], var_to_bytes(FakeBuilder.build(_plan, Vector2i(3, 3)).to_dict()))


func test_stop_cancels_pending() -> void:
	var pregen := WorldPregen.new(_plan, FakeBuilder.build)
	pregen.start(1, 1)
	pregen.stop()
	assert_true(pregen.done() <= pregen.total())
	assert_true(pregen._tasks.is_empty(), "no deja hilos vivos")


func test_average_cache_size_on_real_region() -> void:
	# Tamaño orientativo: el builder es falso, pero el plan es el real del Valle del Sara.
	var plan: RegionPlan = RegionPlan.for_region(42, &"valle_del_sara")
	var cache := WorldCache.for_plan(plan, 0, ROOT)
	var pregen := WorldPregen.new(plan, FakeBuilder.build, cache)
	var t0: int = Time.get_ticks_msec()
	pregen.start()
	pregen.wait()
	var elapsed: int = Time.get_ticks_msec() - t0
	var total_bytes: int = 0
	var count: int = 0
	for y: int in plan.size_chunks.y:
		for x: int in plan.size_chunks.x:
			total_bytes += FileAccess.get_file_as_bytes(cache.chunk_path(Vector2i(x, y))).size()
			count += 1
	assert_eq(count, pregen.total())
	assert_true(pregen.is_complete())
	var average: int = total_bytes / maxi(1, count)
	gut.p("Caché: %d chunks, %d bytes de media (%.1f KB), %.2f MB en total; %d ms con %d núcleos" % [
			count, average, average / 1024.0, total_bytes / 1048576.0, elapsed,
			OS.get_processor_count()])
	if average > 16 * 1024:
		gut.p("AVISO: más de 16 KB por chunk (ADR 0014 estima 5–8 KB)")
	assert_true(average > 0)


func _assert_non_decreasing(order: Array[Vector2i], from: int, to: int, center: Vector2i, label: String) -> void:
	var previous: int = -1
	var ok: bool = true
	for i: int in range(from, to):
		var d: Vector2i = order[i] - center
		var dist: int = d.x * d.x + d.y * d.y
		if dist < previous:
			ok = false
			fail_test("%s: %s (d²=%d) después de d²=%d" % [label, order[i], dist, previous])
			break
		previous = dist
	assert_true(ok, "%s ordenado por distancia" % label)
