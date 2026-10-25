extends GutTest
## Relieve de la pasada de chunk (ChunkBuilder, ADR 0014 §3 y §5): niveles unidos solo por
## escaleras o rampas (dentro del chunk y entre chunks vecinos), puertas unidas al hub, cascadas
## donde el agua cruza una cara, caras de 2 filas por nivel, determinismo e independencia del
## orden y del hilo.
##
## Muestra (para no pasar de ~1 min en la CI): la región entera en FULL_SEEDS y las filas del norte
## (las de más relieve: montañas, cumbres y arroyos) en el resto. 20 seeds en total.

const REGION: StringName = &"valle_del_sara"
const FULL_SEEDS: Array[int] = [42, 7, 1234]
const SAMPLED_SEEDS: Array[int] = [1, 2, 3, 5, 8, 13, 21, 34, 55, 77, 89, 99, 144, 233, 377, 610, 987]
## Filas de chunks que se construyen en las seeds de muestra.
const SAMPLED_ROWS: int = 3
const SIZE: int = WorldChunk.SIZE
const OPEN_CLIFFS: int = (1 << WorldChunk.Cliff.NONE) | (1 << WorldChunk.Cliff.STAIRS) | (1 << WorldChunk.Cliff.RAMP)
const CROSSINGS: int = (1 << WorldChunk.Cliff.STAIRS) | (1 << WorldChunk.Cliff.RAMP)
const WATER: int = WorldChunk.GROUND_BLOCKING | (1 << WorldChunk.Ground.FORD)

## seed -> { plan, chunks: { Vector2i: WorldChunk } }
var _worlds: Dictionary = {}


func before_all() -> void:
	for seed_value: int in FULL_SEEDS + SAMPLED_SEEDS:
		var plan: RegionPlan = RegionPlan.for_region(seed_value, REGION)
		var rows: int = plan.size_chunks.y if FULL_SEEDS.has(seed_value) else mini(SAMPLED_ROWS, plan.size_chunks.y)
		var chunks: Dictionary = {}
		for y: int in rows:
			for x: int in plan.size_chunks.x:
				chunks[Vector2i(x, y)] = ChunkBuilder.build(plan, Vector2i(x, y))
		_worlds[seed_value] = { "plan": plan, "chunks": chunks }


func _bytes(chunk: WorldChunk) -> PackedByteArray:
	return var_to_bytes(chunk.to_dict())


## Dos casillas transitables vecinas de distinto nivel: una tiene que ser escalera o rampa.
static func _bad_pair(a: WorldChunk, i: int, b: WorldChunk, j: int) -> bool:
	if a.blocked[i] == 1 or b.blocked[j] == 1 or a.level[i] == b.level[j]:
		return false
	return (CROSSINGS >> a.cliff[i]) & 1 == 0 and (CROSSINGS >> b.cliff[j]) & 1 == 0


# --- Invariante de niveles ---------------------------------------------------------------------

func test_levels_meet_only_at_stairs_or_ramps() -> void:
	var checked: int = 0
	var failures: Array[String] = []
	for seed_value: int in _worlds:
		var chunks: Dictionary = _worlds[seed_value].chunks
		for coord: Vector2i in chunks:
			var c: WorldChunk = chunks[coord]
			var blocked: PackedByteArray = c.blocked
			var level: PackedByteArray = c.level
			var cliff: PackedByteArray = c.cliff
			for i: int in WorldChunk.CELLS:
				if blocked[i] == 1:
					continue
				var crossing: bool = (CROSSINGS >> cliff[i]) & 1 == 1
				var j: int = i + 1
				if i % SIZE < SIZE - 1 and blocked[j] == 0 and level[j] != level[i] \
						and not crossing and (CROSSINGS >> cliff[j]) & 1 == 0:
					failures.append("seed %d chunk %s casilla %s (este)" % [seed_value, coord, WorldCoords.index_to_cell(i)])
				j = i + SIZE
				if j < WorldChunk.CELLS and blocked[j] == 0 and level[j] != level[i] \
						and not crossing and (CROSSINGS >> cliff[j]) & 1 == 0:
					failures.append("seed %d chunk %s casilla %s (sur)" % [seed_value, coord, WorldCoords.index_to_cell(i)])
			checked += 1
	assert_gt(checked, 1000, "chunks revisados")
	assert_eq(failures.size(), 0, "niveles vecinos sin escalera ni rampa: %s" % [failures.slice(0, 8)])


func test_levels_meet_only_at_stairs_or_ramps_across_chunks() -> void:
	var failures: Array[String] = []
	var borders: int = 0
	for seed_value: int in _worlds:
		var chunks: Dictionary = _worlds[seed_value].chunks
		for coord: Vector2i in chunks:
			var a: WorldChunk = chunks[coord]
			var east: WorldChunk = chunks.get(coord + Vector2i.RIGHT)
			var south: WorldChunk = chunks.get(coord + Vector2i.DOWN)
			for k: int in SIZE:
				if east != null and _bad_pair(a, k * SIZE + SIZE - 1, east, k * SIZE):
					failures.append("seed %d chunks %s|%s fila %d" % [seed_value, coord, coord + Vector2i.RIGHT, k])
				if south != null and _bad_pair(a, (SIZE - 1) * SIZE + k, south, k):
					failures.append("seed %d chunks %s/%s columna %d" % [seed_value, coord, coord + Vector2i.DOWN, k])
			borders += int(east != null) + int(south != null)
	assert_gt(borders, 1000, "bordes revisados")
	assert_eq(failures.size(), 0, "niveles vecinos entre chunks: %s" % [failures.slice(0, 8)])


func test_level_layer_matches_the_plan() -> void:
	var plan: RegionPlan = _worlds[42].plan
	var chunks: Dictionary = _worlds[42].chunks
	for coord: Vector2i in [Vector2i(0, 0), Vector2i(5, 3), Vector2i(11, 15)]:
		var c: WorldChunk = chunks[coord]
		for my: int in WorldCoords.MACROS_PER_CHUNK:
			for mx: int in WorldCoords.MACROS_PER_CHUNK:
				var expected: int = mini(plan.level_at(coord * WorldCoords.MACROS_PER_CHUNK + Vector2i(mx, my)), WorldChunk.MAX_LEVEL)
				var cell := Vector2i(mx, my) * WorldCoords.MACRO
				assert_eq(c.get_level(cell), expected, "nivel de %s en %s" % [cell, coord])


func test_faces_have_two_rows_per_level() -> void:
	var columns: int = 0
	for coord: Vector2i in _worlds[42].chunks:
		var c: WorldChunk = _worlds[42].chunks[coord]
		for x: int in SIZE:
			var y: int = 1
			while y < SIZE - 1:
				var cliff: int = c.cliff[y * SIZE + x]
				if cliff != WorldChunk.Cliff.FACE or c.cliff[(y - 1) * SIZE + x] == WorldChunk.Cliff.FACE:
					y += 1
					continue
				var top: int = y
				while y < SIZE and c.cliff[y * SIZE + x] == WorldChunk.Cliff.FACE:
					y += 1
				if y >= SIZE:
					break # La cara sigue en el chunk de abajo.
				var drop: int = c.level[(top - 1) * SIZE + x] - c.level[top * SIZE + x]
				assert_eq(y - top, ChunkBuilder.FACE_ROWS_PER_LEVEL * drop,
						"cara de %s en %s, columna %d" % [Vector2i(x, top), coord, x])
				columns += 1
	assert_gt(columns, 50, "columnas de cara revisadas")


func test_peaks_block() -> void:
	var peaks: int = 0
	var open: int = 0
	for coord: Vector2i in _worlds[42].chunks:
		var c: WorldChunk = _worlds[42].chunks[coord]
		for i: int in WorldChunk.CELLS:
			if c.cliff[i] == WorldChunk.Cliff.EDGE and c.variant[i] == ChunkBuilder.EDGE_PEAK:
				peaks += 1
				open += c.blocked[i] ^ 1
	assert_gt(peaks, 0, "la autoría del Valle del Sara tiene cumbres")
	assert_eq(open, 0, "casillas de cumbre que se pisan")


# --- Puertas -----------------------------------------------------------------------------------

## Casillas alcanzables desde el hub sin cruzar riscos; el agua no corta (los puentes son de M7).
static func _reach_ignoring_water(c: WorldChunk) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(WorldChunk.CELLS)
	var start: int = WorldCoords.cell_index(c.hub)
	if (OPEN_CLIFFS >> c.cliff[start]) & 1 == 0:
		return seen
	var queue := PackedInt32Array([start])
	seen[start] = 1
	var head: int = 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var x: int = i % SIZE
		for n: int in [i - 1 if x > 0 else -1, i + 1 if x < SIZE - 1 else -1, i - SIZE, i + SIZE]:
			if n >= 0 and n < WorldChunk.CELLS and seen[n] == 0 and (OPEN_CLIFFS >> c.cliff[n]) & 1 == 1:
				seen[n] = 1
				queue.append(n)
	return seen


func test_every_door_reaches_the_hub() -> void:
	var doors: int = 0
	var closed: int = 0
	var failures: Array[String] = []
	for seed_value: int in _worlds:
		var plan: RegionPlan = _worlds[seed_value].plan
		var chunks: Dictionary = _worlds[seed_value].chunks
		for coord: Vector2i in chunks:
			var c: WorldChunk = chunks[coord]
			assert_true(c.is_walkable(c.hub), "hub transitable en %s" % coord)
			var seen: PackedByteArray = _reach_ignoring_water(c)
			var found: Dictionary = plan.doors_of(coord)
			for side: Vector2i in found:
				var door: Dictionary = found[side]
				var along: Vector2i = Vector2i.DOWN if side.x != 0 else Vector2i.RIGHT
				for k: int in int(door.width):
					var i: int = WorldCoords.cell_index(door.cell + along * k)
					doors += 1
					if (OPEN_CLIFFS >> c.cliff[i]) & 1 == 0:
						closed += 1 # Cumbre o cascada en la puerta: lo resuelve M7 (puente o desvío).
						continue
					if seen[i] == 0:
						failures.append("seed %d chunk %s puerta %s" % [seed_value, coord, door.cell + along * k])
	gut.p("casillas de puerta: %d; en cumbre o cascada: %d" % [doors, closed])
	assert_gt(doors, 1000)
	assert_lt(closed, doors / 50, "casi ninguna puerta cae en una cumbre o una cascada")
	assert_eq(failures.size(), 0, "puertas sin unir al hub: %s" % [failures.slice(0, 8)])


func test_doors_in_cliffs_become_stairs_or_ramps_on_both_sides() -> void:
	# Con todas las puertas abiertas, una puerta vista desde los dos chunks se pisa a los dos lados.
	var plan: RegionPlan = _worlds[42].plan
	var chunks: Dictionary = _worlds[42].chunks
	var crossings: int = 0
	for coord: Vector2i in chunks:
		for side: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			if not chunks.has(coord + side) or not plan.has_door(coord, side):
				continue
			var door: Dictionary = plan.door(coord, side)
			var other: Dictionary = plan.door(coord + side, -side)
			var along: Vector2i = Vector2i.DOWN if side.x != 0 else Vector2i.RIGHT
			for k: int in int(door.width):
				var a: int = WorldCoords.cell_index(door.cell + along * k)
				var b: int = WorldCoords.cell_index(other.cell + along * k)
				var ca: WorldChunk = chunks[coord]
				var cb: WorldChunk = chunks[coord + side]
				if (OPEN_CLIFFS >> ca.cliff[a]) & 1 == 0 or (OPEN_CLIFFS >> cb.cliff[b]) & 1 == 0:
					continue
				if ca.level[a] != cb.level[b]:
					crossings += 1
					assert_true((CROSSINGS >> ca.cliff[a]) & 1 == 1 or (CROSSINGS >> cb.cliff[b]) & 1 == 1,
							"puerta %s de %s cambia de nivel sin escalera ni rampa" % [door.cell, coord])
	gut.p("puertas con cambio de nivel en el borde (seed 42): %d" % crossings)


# --- Cascadas ----------------------------------------------------------------------------------

func test_waterfalls_where_water_crosses_a_face() -> void:
	var waterfalls: int = 0
	var failures: Array[String] = []
	for seed_value: int in FULL_SEEDS:
		var chunks: Dictionary = _worlds[seed_value].chunks
		for coord: Vector2i in chunks:
			var c: WorldChunk = chunks[coord]
			for x: int in SIZE:
				for y: int in range(1, SIZE):
					var i: int = y * SIZE + x
					var cliff: int = c.cliff[i]
					var above: int = c.cliff[i - SIZE]
					if (cliff != WorldChunk.Cliff.FACE and cliff != WorldChunk.Cliff.WATERFALL) or above == cliff:
						continue
					# Primera fila de una columna de cara: la casilla de encima es la meseta.
					var wet_top: bool = (WATER >> c.ground[i - SIZE]) & 1 == 1
					var yy: int = y
					while yy < SIZE and c.cliff[yy * SIZE + x] == cliff:
						var j: int = yy * SIZE + x
						var expected: bool = wet_top and (WATER >> c.ground[j]) & 1 == 1
						if expected != (cliff == WorldChunk.Cliff.WATERFALL):
							failures.append("seed %d chunk %s casilla %s" % [seed_value, coord, Vector2i(x, yy)])
						if cliff == WorldChunk.Cliff.WATERFALL:
							waterfalls += 1
							if c.blocked[j] == 0:
								failures.append("cascada que se pisa: seed %d chunk %s" % [seed_value, coord])
						yy += 1
	gut.p("casillas de cascada: %d" % waterfalls)
	assert_gt(waterfalls, 0, "hay ríos que cruzan caras")
	assert_eq(failures.size(), 0, "cascadas mal puestas: %s" % [failures.slice(0, 8)])


func test_shadows_sit_at_the_foot_of_faces() -> void:
	var shadows: int = 0
	var misplaced: int = 0
	for coord: Vector2i in _worlds[42].chunks:
		var c: WorldChunk = _worlds[42].chunks[coord]
		for i: int in range(SIZE, WorldChunk.CELLS):
			if c.decor[i] == ChunkBuilder.Decor.SHADOW_FOOT:
				shadows += 1
				if c.cliff[i - SIZE] != WorldChunk.Cliff.FACE or c.cliff[i] != WorldChunk.Cliff.NONE:
					misplaced += 1
	assert_gt(shadows, 0)
	assert_eq(misplaced, 0, "sombras al pie que no están bajo una cara")


# --- Determinismo ------------------------------------------------------------------------------

func test_same_chunk_twice_gives_the_same_bytes() -> void:
	var plan: RegionPlan = _worlds[42].plan
	for coord: Vector2i in [Vector2i(3, 0), Vector2i(6, 7), Vector2i(11, 15)]:
		var a: WorldChunk = ChunkBuilder.build(plan, coord)
		var b: WorldChunk = ChunkBuilder.build(plan, coord)
		assert_eq(_bytes(a), _bytes(b), "chunk %s" % coord)
		assert_eq(_bytes(a), _bytes(_worlds[42].chunks[coord]), "chunk %s frente al de before_all" % coord)


func test_same_seed_new_plan_gives_the_same_chunk() -> void:
	var plan: RegionPlan = RegionPlan.for_region(42, REGION)
	assert_eq(_bytes(ChunkBuilder.build(plan, Vector2i(4, 1))), _bytes(_worlds[42].chunks[Vector2i(4, 1)]))


func test_build_order_does_not_matter() -> void:
	var plan: RegionPlan = _worlds[7].plan
	var coords: Array[Vector2i] = []
	for y: int in range(0, 4):
		for x: int in range(2, 6):
			coords.append(Vector2i(x, y))
	var reversed: Array[Vector2i] = coords.duplicate()
	reversed.reverse()
	for coord: Vector2i in reversed:
		assert_eq(_bytes(ChunkBuilder.build(plan, coord)), _bytes(_worlds[7].chunks[coord]), "chunk %s" % coord)


func test_parallel_build_matches_serial() -> void:
	var plan: RegionPlan = _worlds[1234].plan
	var coords: Array[Vector2i] = []
	for y: int in range(0, 3):
		for x: int in range(0, 4):
			coords.append(Vector2i(x, y))
	var results: Array = []
	results.resize(coords.size())
	var mutex := Mutex.new()
	var task: int = WorkerThreadPool.add_group_task(func(k: int) -> void:
		var bytes: PackedByteArray = var_to_bytes(ChunkBuilder.build(plan, coords[k]).to_dict())
		mutex.lock()
		results[k] = bytes
		mutex.unlock(), coords.size())
	WorkerThreadPool.wait_for_group_task_completion(task)
	for k: int in coords.size():
		assert_eq(results[k], _bytes(_worlds[1234].chunks[coords[k]]), "chunk %s en paralelo" % coords[k])
