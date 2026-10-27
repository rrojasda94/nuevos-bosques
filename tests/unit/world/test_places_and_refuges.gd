extends GutTest
## Fuentes de los afluentes, entradas de sicabi y refugios garantizados (5 seeds, región entera).
## - Fuentes (mundo-2.md §4): un SPRING 3×3 en cada `manantial` de lugares.csv, con el agua en el
##   centro (bloquea), las 8 rocas que se pisan y se alcanzan, claro sin objetos y sendero que llega.
## - Sicabis (lugares-e-interiores.md): reparto del RegionPlan (≤ 1 por subregión, ≥ 2 chunks de
##   villas y aldeas, ≥ 4 entre ellas, nunca en un Bosque muerto, 2–6 por región en ≥ 4 de 5 seeds)
##   y entrada SICABI_GATE (lejos de caminos y senderos, boca alcanzable por un paso de 2).
## - Refugios (mundo-2.md §3): ninguna casilla que se pisa a más de 300 pasos de un refugio o de
##   la plaza de una villa, cruzando chunks. Antes dependía de la suerte (312 con la seed 42 al
##   añadir la tarca de Azhin); ahora lo garantiza ChunkBuilder._ensure_refuges.

const REGION: StringName = &"valle_del_sara"
const SEEDS: Array[int] = [42, 7, 1, 2, 3]
const SIZE: int = WorldChunk.SIZE
const K := WorldChunk.ObjectKind
const TRAIL: int = (1 << WorldChunk.Ground.PATH) | (1 << WorldChunk.Ground.ROAD) | (1 << WorldChunk.Ground.BRIDGE)
const FOREST: int = (1 << K.TREE) | (1 << K.TREE_DEAD) | (1 << K.FRUIT_TREE) | (1 << K.REFUGE_TREE) | (1 << K.TREE_BIG)

## seed -> { plan, chunks: { Vector2i: WorldChunk } }
var _worlds: Dictionary = {}


func before_all() -> void:
	for seed_value: int in SEEDS:
		var plan: RegionPlan = RegionPlan.for_region(seed_value, REGION)
		var chunks: Dictionary = {}
		for y: int in plan.size_chunks.y:
			for x: int in plan.size_chunks.x:
				chunks[Vector2i(x, y)] = ChunkBuilder.build(plan, Vector2i(x, y))
		_worlds[seed_value] = { "plan": plan, "chunks": chunks }


# --- Fuentes -----------------------------------------------------------------------------------

func test_every_spring_has_its_3x3_footprint_clearing_and_trail() -> void:
	var failures: Array[String] = []
	for seed_value: int in _worlds:
		var plan: RegionPlan = _worlds[seed_value].plan
		var springs: int = 0
		for coord: Vector2i in _worlds[seed_value].chunks:
			var c: WorldChunk = _worlds[seed_value].chunks[coord]
			var wanted: int = 0
			for p: Dictionary in plan.places_in_chunk(coord):
				wanted += int(p.type == "manantial")
			var found: Array[Dictionary] = c.objects_of(K.SPRING)
			springs += found.size()
			if found.size() != wanted:
				failures.append("seed %d %s: %d fuentes, %d manantiales" % [seed_value, coord, found.size(), wanted])
				continue
			var reach: PackedByteArray = c.reachable_from_hub()
			for s: Dictionary in found:
				var r := Rect2i(s.cell, s.size)
				if r.size != Vector2i(3, 3):
					failures.append("seed %d %s: fuente de %s" % [seed_value, coord, r.size])
					continue
				var mid: Vector2i = r.position + Vector2i.ONE
				if not c.is_blocked(mid) or not WorldChunk.is_ground_blocking(c.get_ground(mid)):
					failures.append("seed %d %s: el centro de la fuente no es agua que bloquea" % [seed_value, coord])
				for y: int in range(r.position.y, r.end.y):
					for x: int in range(r.position.x, r.end.x):
						var cell := Vector2i(x, y)
						if cell != mid and (c.is_blocked(cell) or reach[WorldCoords.cell_index(cell)] == 0):
							failures.append("seed %d %s: roca %s de la fuente no se pisa o no se alcanza" % [seed_value, coord, cell])
				# Claro de 4 casillas sin ningún otro objeto.
				var clear: Rect2i = r.grow(4).intersection(Rect2i(0, 0, SIZE, SIZE))
				for y: int in range(clear.position.y, clear.end.y):
					for x: int in range(clear.position.x, clear.end.x):
						var o: Dictionary = c.object_at(Vector2i(x, y))
						if not o.is_empty() and o.kind != K.SPRING:
							failures.append("seed %d %s: %s en el claro de la fuente" % [seed_value, coord, K.keys()[o.kind]])
				# Le llega sendero: un punto PLACE con su huella y sendero a ≤ 3 casillas.
				var listed: bool = false
				for p: Dictionary in c.points:
					listed = listed or (p.kind == WorldChunk.PointKind.PLACE and p.rect == r)
				if not listed:
					failures.append("seed %d %s: la fuente no está en points" % [seed_value, coord])
				var trail: bool = false
				var near: Rect2i = r.grow(3).intersection(Rect2i(0, 0, SIZE, SIZE))
				for y: int in range(near.position.y, near.end.y):
					for x: int in range(near.position.x, near.end.x):
						trail = trail or (TRAIL >> c.get_ground(Vector2i(x, y))) & 1 == 1
				if not trail:
					failures.append("seed %d %s: no llega sendero a la fuente" % [seed_value, coord])
		assert_eq(springs, 7, "seed %d: 7 fuentes" % seed_value)
	assert_eq(failures.size(), 0, "fuentes: %s" % [failures.slice(0, 8)])


# --- Sicabis: reparto --------------------------------------------------------------------------

static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func test_sicabis_are_rare_and_far_from_villas() -> void:
	var in_range: int = 0
	for seed_value: int in _worlds:
		var plan: RegionPlan = _worlds[seed_value].plan
		var params: Dictionary = plan.sicabi_params()
		var list: Array[Dictionary] = plan.sicabis()
		var per_sub: Dictionary = {}
		for s: Dictionary in list:
			per_sub[s.subregion] = int(per_sub.get(s.subregion, 0)) + 1
			assert_eq(plan.subregion_of(s.chunk), s.subregion, "subregión de la sicabi")
			var id: int = plan.bosque_at(s.chunk)
			assert_ne(plan.bosques.state_of(id), BosqueMap.STATE_MUERTO, "seed %d: sicabi en un Bosque muerto" % seed_value)
			for v: Dictionary in plan.villas():
				assert_true(_cheb(v.chunk, s.chunk) >= int(params.min_villa_distance_chunks),
						"seed %d: sicabi %s a %d chunks de %s" % [seed_value, s.chunk, _cheb(v.chunk, s.chunk), v.name])
			for o: Dictionary in list:
				if o.chunk != s.chunk:
					assert_true(_cheb(o.chunk, s.chunk) >= int(params.min_sicabi_distance_chunks),
							"seed %d: sicabis %s y %s a menos de 4 chunks" % [seed_value, s.chunk, o.chunk])
		for sub: Variant in per_sub:
			assert_true(int(per_sub[sub]) <= int(params.per_subregion_max), "seed %d: más de 1 sicabi en una subregión" % seed_value)
		gut.p("seed %d: %d sicabis en el plan (%s)" % [seed_value, list.size(), list.map(func(s: Dictionary) -> String:
				return "%s %s" % [plan.subregion_names()[s.subregion], s.chunk])])
		if list.size() >= 2 and list.size() <= 6:
			in_range += 1
	assert_true(in_range >= 4, "entre 2 y 6 sicabis por región en al menos 4 de 5 seeds (%d)" % in_range)


func test_sicabi_plan_is_deterministic_and_subregions_cover_the_region() -> void:
	var plan: RegionPlan = _worlds[7].plan
	var again: RegionPlan = RegionPlan.for_region(7, REGION)
	assert_eq(again.sicabis(), plan.sicabis())
	assert_eq(plan.subregion_names().size(), 7, "las 7 subregiones del Valle del Sara")
	for y: int in plan.size_chunks.y:
		for x: int in plan.size_chunks.x:
			assert_between(plan.subregion_of(Vector2i(x, y)), 0, 6)
	# Azhin está en Lean (dueño, #182).
	assert_eq(plan.subregion_names()[plan.subregion_of(Vector2i(0, 0))], "lean")


# --- Sicabis: entrada --------------------------------------------------------------------------

func test_sicabi_gates_hide_off_trail_with_a_2_wide_access() -> void:
	var failures: Array[String] = []
	var gates: int = 0
	var planned: int = 0
	var variants: Dictionary = {}
	for seed_value: int in _worlds:
		var plan: RegionPlan = _worlds[seed_value].plan
		var params: Dictionary = plan.sicabi_params()
		planned += plan.sicabis().size()
		for coord: Vector2i in _worlds[seed_value].chunks:
			var c: WorldChunk = _worlds[seed_value].chunks[coord]
			var found: Array[Dictionary] = c.objects_of(K.SICABI_GATE)
			var info: Dictionary = plan.sicabi_in_chunk(coord)
			if info.is_empty():
				if not found.is_empty() or not c.sicabi.is_empty():
					failures.append("seed %d %s: entrada de sicabi sin reparto" % [seed_value, coord])
				continue
			if found.size() > 1:
				failures.append("seed %d %s: %d entradas" % [seed_value, coord, found.size()])
				continue
			if found.is_empty():
				assert_true(c.sicabi.is_empty())
				continue
			gates += 1
			var g: Dictionary = found[0]
			var cell: Vector2i = g.cell
			variants[int(g.variant) & 1] = true
			assert_eq(c.sicabi.id, info.id)
			assert_eq(c.sicabi.cell, cell + Vector2i.DOWN, "boca de la sicabi")
			var problem: String = _gate_problem(c, g, params)
			if not problem.is_empty():
				failures.append("seed %d %s: %s" % [seed_value, coord, problem])
			assert_eq(c.points.filter(func(p: Dictionary) -> bool: return Rect2i(p.rect).has_point(cell)).size(), 0,
					"la sicabi no es un punto de interés")
	gut.p("entradas de sicabi: %d de %d del plan; variantes %s" % [gates, planned, variants.keys()])
	assert_true(gates * 10 >= planned * 8, "al menos el 80 %% de las sicabis del plan tienen entrada (%d de %d)" % [gates, planned])
	assert_eq(failures.size(), 0, "entradas de sicabi: %s" % [failures.slice(0, 8)])


## "" si la entrada cumple la ficha; si no, el motivo.
static func _gate_problem(c: WorldChunk, g: Dictionary, params: Dictionary) -> String:
	var cell: Vector2i = g.cell
	if g.size != Vector2i(2, 2):
		return "entrada de %s" % g.size
	var reach: PackedByteArray = c.reachable_from_hub()
	for x: int in [cell.x, cell.x + 1]:
		if not c.is_blocked(Vector2i(x, cell.y)):
			return "la fila de arriba de la entrada se pisa"
		var mouth := Vector2i(x, cell.y + 1)
		if c.is_blocked(mouth) or reach[WorldCoords.cell_index(mouth)] == 0:
			return "la boca %s no se pisa o no se alcanza" % mouth
	# Lejos de caminos (≥ 10) y senderos (≥ 6), en Chebyshev.
	var road: int = int(params.min_road_distance)
	var trail: int = int(params.min_path_distance)
	var gate := Rect2i(cell, Vector2i(2, 2))
	var area: Rect2i = gate.grow(road).intersection(Rect2i(0, 0, SIZE, SIZE))
	if area != gate.grow(road):
		return "la entrada está a menos de %d del borde" % road
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var ground: int = c.get_ground(Vector2i(x, y))
			var d: int = maxi(maxi(cell.x - x, x - cell.x - 1), maxi(cell.y - y, y - cell.y - 1))
			if ground == WorldChunk.Ground.ROAD and d < road:
				return "camino a %d casillas" % d
			if (ground == WorldChunk.Ground.PATH or ground == WorldChunk.Ground.BRIDGE) and d < trail:
				return "sendero a %d casillas" % d
	if int(g.variant) & 1 == ChunkBuilder.SICABI_FOREST:
		var near: Rect2i = gate.grow(int(params.forest_radius))
		var trees: int = 0
		for y: int in range(near.position.y, near.end.y):
			for x: int in range(near.position.x, near.end.x):
				var o: Dictionary = c.object_at(Vector2i(x, y))
				trees += int(not o.is_empty() and (FOREST >> int(o.kind)) & 1 == 1)
		var ratio: float = float(trees) / float(near.get_area() - 4)
		if ratio < float(params.forest_ratio):
			return "bosque poco tupido (%.2f)" % ratio
	else:
		if c.get_cliff(cell) != WorldChunk.Cliff.FACE:
			return "la grieta no está en una cara"
		var y: int = cell.y
		while y > 0 and c.get_cliff(Vector2i(cell.x, y)) == WorldChunk.Cliff.FACE:
			y -= 1
		if c.get_level(Vector2i(cell.x, y)) < int(params.cliff_min_level):
			return "risco de nivel %d" % c.get_level(Vector2i(cell.x, y))
	# Paso libre de 2: celdas 2×2 de la rejilla que se pisan enteras, de la de debajo de la boca a
	# una con sendero.
	var start := Vector2i(cell.x / 2, cell.y / 2 + 1)
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var gate_g := Vector2i(cell.x / 2, cell.y / 2)
	while not queue.is_empty():
		var q: Vector2i = queue.pop_front()
		var open: bool = true
		var on_trail: bool = false
		for k: int in 4:
			var t := Vector2i(q.x * 2 + (k & 1), q.y * 2 + (k >> 1))
			open = open and not c.is_blocked(t)
			on_trail = on_trail or (TRAIL >> c.get_ground(t)) & 1 == 1
		if not open:
			continue
		if on_trail:
			return ""
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = q + d
			if n != gate_g and n.x >= 0 and n.y >= 0 and n.x < SIZE / 2 and n.y < SIZE / 2 and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return "sin paso libre de 2 casillas hasta un sendero"


func test_sicabi_chunks_are_deterministic_and_survive_the_cache() -> void:
	var plan: RegionPlan = _worlds[42].plan
	for s: Dictionary in plan.sicabis():
		var a: WorldChunk = ChunkBuilder.build(plan, s.chunk)
		assert_eq(var_to_bytes(a.to_dict()), var_to_bytes((_worlds[42].chunks[s.chunk] as WorldChunk).to_dict()), "chunk %s" % s.chunk)
		var back: WorldChunk = WorldChunk.from_dict(bytes_to_var(var_to_bytes(a.to_dict())))
		assert_not_null(back)
		assert_eq(back.sicabi, a.sicabi)
		back.rebuild_blocked()
		assert_eq(back.blocked, a.blocked, "la boca y el arco se rehacen igual desde la caché")


# --- Refugios garantizados ---------------------------------------------------------------------

## Casillas donde se está refugiado: las del árbol hueco o la boca de la cueva.
static func _shelter_cells(obj: Dictionary) -> Array[Vector2i]:
	var cell: Vector2i = obj.cell
	var out: Array[Vector2i] = []
	var rows: Array[int] = [cell.y + 1]
	if obj.kind != K.CAVE:
		rows = [cell.y, cell.y + 1]
	for y: int in rows:
		for x: int in [cell.x, cell.x + 1]:
			out.append(Vector2i(x, y))
	return out


## mundo-2.md §3: desde cualquier casilla que se pisa (alcanzable desde el hub de su chunk), el
## refugio más cercano (o la plaza de una villa) está a ≤ 300 casillas a pie, cruzando chunks.
func test_every_cell_is_at_most_300_steps_from_a_refuge() -> void:
	const LIMIT: int = 300
	for seed_value: int in _worlds:
		var plan: RegionPlan = _worlds[seed_value].plan
		var chunks: Dictionary = _worlds[seed_value].chunks
		var w: int = plan.size_chunks.x * SIZE
		var h: int = plan.size_chunks.y * SIZE
		var blocked := PackedByteArray()
		blocked.resize(w * h)
		var target := PackedByteArray()
		target.resize(w * h)
		var dist := PackedInt32Array()
		dist.resize(w * h)
		dist.fill(-1)
		var queue := PackedInt32Array()
		queue.resize(w * h)
		var tail: int = 0
		var refuges: int = 0
		for coord: Vector2i in chunks:
			var c: WorldChunk = chunks[coord]
			var reach: PackedByteArray = c.reachable_from_hub()
			var o: int = coord.y * SIZE * w + coord.x * SIZE
			for y: int in SIZE:
				for x: int in SIZE:
					var i: int = y * SIZE + x
					var g: int = o + y * w + x
					blocked[g] = c.blocked[i]
					target[g] = reach[i]
					if c.has_villa and c.ground[i] == WorldChunk.Ground.PLAZA and c.blocked[i] == 0:
						dist[g] = 0
						queue[tail] = g
						tail += 1
			var found: Array[Dictionary] = c.objects_of(K.CAVE)
			found.append_array(c.objects_of(K.REFUGE_TREE))
			refuges += found.size()
			for r: Dictionary in found:
				for cell: Vector2i in _shelter_cells(r):
					var g: int = o + cell.y * w + cell.x
					if dist[g] < 0:
						dist[g] = 0
						queue[tail] = g
						tail += 1
		var head: int = 0
		while head < tail:
			var g: int = queue[head]
			head += 1
			var x: int = g % w
			var d: int = dist[g] + 1
			if x > 0 and dist[g - 1] < 0 and blocked[g - 1] == 0:
				dist[g - 1] = d
				queue[tail] = g - 1
				tail += 1
			if x < w - 1 and dist[g + 1] < 0 and blocked[g + 1] == 0:
				dist[g + 1] = d
				queue[tail] = g + 1
				tail += 1
			if g >= w and dist[g - w] < 0 and blocked[g - w] == 0:
				dist[g - w] = d
				queue[tail] = g - w
				tail += 1
			if g < w * h - w and dist[g + w] < 0 and blocked[g + w] == 0:
				dist[g + w] = d
				queue[tail] = g + w
				tail += 1
		var worst: int = 0
		var over: int = 0
		var cut_off: int = 0
		var cells: int = 0
		for g: int in w * h:
			if target[g] == 0:
				continue
			cells += 1
			if dist[g] < 0:
				cut_off += 1
			elif dist[g] > LIMIT:
				over += 1
			worst = maxi(worst, dist[g])
		gut.p("seed %d: %d casillas; %d refugios (reparto %d); peor distancia %d; > %d: %d; sin camino: %d" % [
				seed_value, cells, refuges, plan.refuge_chunks().size(), worst, LIMIT, over, cut_off])
		assert_eq(cut_off, 0, "seed %d: casillas sin camino a ningún refugio" % seed_value)
		assert_eq(over, 0, "seed %d: casillas a más de %d pasos de un refugio" % [seed_value, LIMIT])
