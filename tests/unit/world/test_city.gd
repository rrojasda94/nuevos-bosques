extends GutTest
## Ciudades (tipo `ciudad` de lugares.csv; generation.md, "Ciudad"). Umun Mal (dueño, 2026-10-27):
## "es una ciudad de piedra blanca, muy bonita y grande tiene la particularidad de ocupar todo un
## chunk", en el chunk (6, 14), justo al sur de Olss.
## - Plan: es una villa más (Bosque propio con villa y Nujio en su chunk, sin aldea) y su chunk está
##   aplanado a un solo nivel en la altura gruesa.
## - Chunk: casas de piedra blanca repartidas por todo el chunk (ninguna punta sin construir más
##   allá de un margen), plaza grande con el Nujio, calles de 3, todo accesible, un solo nivel, sin
##   bosque, rocas ni puntos de interés al azar, y mismos bytes al construirlo dos veces.

const REGION: StringName = &"valle_del_sara"
const SEEDS: Array[int] = [7, 42, 1]
const CITY: Vector2i = Vector2i(6, 14)
const SIZE: int = WorldChunk.SIZE
const K := WorldChunk.ObjectKind
## Casillas de margen: dentro de este margen de cada borde del chunk tiene que haber alguna casa.
const MARGIN: int = 14
## Lado de los cuadros en que se divide el chunk para ver que las casas lo llenan.
const SQUARE: int = 20
const MIN_HOUSES: int = 60
## Objetos que no hay en una ciudad: el bosque, las rocas sueltas y los objetos pequeños de bosque.
const NOT_IN_CITY: int = (1 << K.TREE) | (1 << K.TREE_DEAD) | (1 << K.TREE_BIG) | (1 << K.FRUIT_TREE) \
		| (1 << K.ROCK) | (1 << K.STUMP) | (1 << K.LOG) | (1 << K.CAVE)
const TRAIL: int = (1 << WorldChunk.Ground.PATH) | (1 << WorldChunk.Ground.ROAD) | (1 << WorldChunk.Ground.BRIDGE)

## seed -> { plan, chunk }
var _worlds: Dictionary = {}


func before_all() -> void:
	for seed_value: int in SEEDS:
		var plan: RegionPlan = RegionPlan.for_region(seed_value, REGION)
		_worlds[seed_value] = { "plan": plan, "chunk": ChunkBuilder.build(plan, CITY) }


# --- Plan --------------------------------------------------------------------------------------

func test_umun_mal_is_a_city_in_its_own_bosque() -> void:
	for seed_value: int in _worlds:
		var plan: RegionPlan = _worlds[seed_value].plan
		var v: Dictionary = plan.villa_in_chunk(CITY)
		assert_eq(v.get("name"), "Umun Mal", "seed %d" % seed_value)
		assert_eq(v.get("kind"), "ciudad")
		assert_true(plan.is_city(CITY))
		assert_false(plan.is_city(plan.home_chunk), "Olss no es ciudad")
		var id: int = plan.bosque_at(CITY)
		assert_true(plan.bosques.has_villa[id], "su Bosque tiene villa")
		assert_false(plan.bosques.has_aldea[id], "y no aldea")
		assert_eq(plan.bosques.nujio_chunk[id], CITY, "con el Nujio en la ciudad")
		assert_ne(id, plan.bosque_at(plan.home_chunk), "Bosque propio, no el de Olss")
		var count: int = 0
		for other: Dictionary in plan.villas():
			if other.chunk == CITY:
				count += 1
		assert_eq(count, 1, "nada más en su chunk")
		for s: Dictionary in plan.sicabis():
			var c: Vector2i = s.chunk
			assert_gte(maxi(absi(c.x - CITY.x), absi(c.y - CITY.y)), int(plan.sicabi_params().min_villa_distance_chunks),
					"sicabi lejos de la ciudad")


func test_city_chunk_is_flat_in_the_plan() -> void:
	var plan: RegionPlan = _worlds[7].plan
	var block: PackedByteArray = plan.chunk_block("height", CITY)
	for k: int in block.size():
		assert_eq(block[k], block[0], "un solo nivel en la celda %d" % k)
	assert_lte(block[0], RegionPlan.LEVEL_MAX, "sin cumbres")


# --- Chunk -------------------------------------------------------------------------------------

func test_city_fills_the_whole_chunk_with_white_stone_houses() -> void:
	for seed_value: int in _worlds:
		var c: WorldChunk = _worlds[seed_value].chunk
		assert_true(c.has_villa, "seed %d: la ciudad es villa (servicios, plaza)" % seed_value)
		var houses: Array[Dictionary] = c.objects_of(K.HOUSE)
		gut.p("seed %d: %d casas en Umun Mal" % [seed_value, houses.size()])
		assert_gte(houses.size(), MIN_HOUSES, "muchas casas")
		var lo := Vector2i(SIZE, SIZE)
		var hi := Vector2i(-1, -1)
		var squares: Dictionary = {}
		for h: Dictionary in houses:
			assert_eq(h.size, ChunkBuilder.HOUSE_SIZE)
			assert_eq(int(h.variant) / 2, ChunkBuilder.HouseMaterial.PIEDRA_BLANCA, "piedra blanca")
			var r := Rect2i(h.cell, h.size)
			lo = Vector2i(mini(lo.x, r.position.x), mini(lo.y, r.position.y))
			hi = Vector2i(maxi(hi.x, r.end.x - 1), maxi(hi.y, r.end.y - 1))
			for y: int in range(r.position.y, r.end.y):
				for x: int in range(r.position.x, r.end.x):
					squares[Vector2i(x, y) / SQUARE] = true
		assert_lte(lo.x, MARGIN, "casas hasta el oeste")
		assert_lte(lo.y, MARGIN, "casas hasta el norte")
		assert_gte(hi.x, SIZE - 1 - MARGIN, "casas hasta el este")
		assert_gte(hi.y, SIZE - 1 - MARGIN, "casas hasta el sur")
		var n: int = SIZE / SQUARE
		assert_eq(squares.size(), n * n, "seed %d: casas en los %d cuadros de %d×%d" % [seed_value, n * n, SQUARE, SQUARE])
		# Cada esquina del chunk tiene una casa cerca (ninguna punta sin construir).
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(SIZE - 1, 0), Vector2i(0, SIZE - 1), Vector2i(SIZE - 1, SIZE - 1)]:
			var near: bool = false
			for h: Dictionary in houses:
				var r := Rect2i(h.cell, h.size)
				var d: int = maxi(maxi(r.position.x - corner.x, corner.x - (r.end.x - 1)), maxi(r.position.y - corner.y, corner.y - (r.end.y - 1)))
				near = near or d <= MARGIN
			assert_true(near, "seed %d: casa cerca de la esquina %s" % [seed_value, corner])


func test_city_is_fully_accessible() -> void:
	for seed_value: int in _worlds:
		var c: WorldChunk = _worlds[seed_value].chunk
		assert_eq(ChunkBuilder.inaccessible(c), [] as Array[String], "seed %d" % seed_value)
		for h: Dictionary in c.objects_of(K.HOUSE):
			var r := Rect2i(h.cell, h.size)
			var front: bool = false
			for x: int in range(r.position.x, r.end.x):
				front = front or c.is_reachable(Vector2i(x, r.end.y))
			assert_true(front, "seed %d: casa %s con frente alcanzable" % [seed_value, r.position])
			for other: Dictionary in c.objects_of(K.HOUSE):
				if other != h:
					assert_false(r.grow(1).intersects(Rect2i(other.cell, other.size)), "casas pegadas en %s" % r.position)
			for y: int in range(r.position.y, r.end.y):
				for x: int in range(r.position.x, r.end.x):
					assert_eq((TRAIL >> c.get_ground(Vector2i(x, y))) & 1, 0, "casa sobre una calle en %s" % Vector2i(x, y))
		# Todo lo que se pisa dentro de la ronda exterior se alcanza desde el hub (no hay patios
		# encerrados entre casas).
		var reach: PackedByteArray = c.reachable_from_hub()
		var inner := Rect2i(Vector2i.ONE * (ChunkBuilder.CITY_OUTER * ChunkBuilder.MACRO + 1),
				Vector2i.ONE * ((ChunkBuilder.MACROS - 1 - 2 * ChunkBuilder.CITY_OUTER) * ChunkBuilder.MACRO + ChunkBuilder.ROAD_W))
		var shut: int = 0
		for y: int in range(inner.position.y, inner.end.y):
			for x: int in range(inner.position.x, inner.end.x):
				var i: int = y * SIZE + x
				if c.blocked[i] == 0 and reach[i] == 0:
					shut += 1
		assert_eq(shut, 0, "seed %d: casillas encerradas en la ciudad" % seed_value)


func test_city_has_a_big_plaza_with_the_nujio_streets_and_one_level() -> void:
	for seed_value: int in _worlds:
		var c: WorldChunk = _worlds[seed_value].chunk
		var plan: RegionPlan = _worlds[seed_value].plan
		assert_eq(c.nujio_rect.size, Vector2i(ChunkBuilder.NUJIO_SIZE, ChunkBuilder.NUJIO_SIZE), "Nujio")
		var plaza: int = 0
		var road: int = 0
		var levels: Dictionary = {}
		for i: int in WorldChunk.CELLS:
			levels[c.level[i]] = true
			assert_eq(c.cliff[i], WorldChunk.Cliff.NONE, "seed %d: sin riscos en %s" % [seed_value, WorldCoords.index_to_cell(i)])
			if c.ground[i] == WorldChunk.Ground.PLAZA:
				plaza += 1
			elif c.ground[i] == WorldChunk.Ground.ROAD:
				road += 1
		assert_eq(levels.size(), 1, "un solo nivel")
		assert_gt(plaza, 300, "plaza grande (%d casillas)" % plaza)
		assert_gt(road, 1200, "calles de 3 (%d casillas)" % road)
		# Plaza alrededor del Nujio.
		for d: Vector2i in [Vector2i(-2, 0), Vector2i(ChunkBuilder.NUJIO_SIZE + 1, 0), Vector2i(0, -2)]:
			assert_eq(c.get_ground(c.nujio_rect.position + d), WorldChunk.Ground.PLAZA, "plaza junto al Nujio")
		# Refugio del reparto en un parterre de la plaza (cuenta como refugio también la plaza).
		if plan.has_refuge(CITY):
			var refuges: Array[Dictionary] = c.objects_of(K.REFUGE_TREE)
			assert_gt(refuges.size(), 0, "árbol hueco en la plaza")
			if not refuges.is_empty():
				var cell: Vector2i = refuges[0].cell
				var n: Rect2i = c.nujio_rect
				var gap: int = maxi(maxi(n.position.x - cell.x, cell.x + 1 - (n.end.x - 1)), maxi(n.position.y - cell.y, cell.y + 1 - (n.end.y - 1)))
				assert_lte(gap, ChunkBuilder.REFUGE_NUJIO_REACH, "a ≤ 6 del Nujio")


func test_city_has_no_forest_rocks_or_random_points() -> void:
	for seed_value: int in _worlds:
		var c: WorldChunk = _worlds[seed_value].chunk
		var trees: int = 0
		for obj: Dictionary in c.objects:
			assert_eq((NOT_IN_CITY >> int(obj.kind)) & 1, 0, "seed %d: %s en la ciudad" % [seed_value, K.keys()[obj.kind]])
			trees += int(obj.kind == K.TREE_YOUNG)
		assert_gt(trees, 0, "algún árbol de adorno")
		for p: Dictionary in c.points:
			assert_eq(p.kind, WorldChunk.PointKind.PLACE, "sin puntos de interés al azar")
		var huertos: int = 0
		for i: int in WorldChunk.CELLS:
			huertos += int(ChunkBuilder.decor_piece(c.decor[i]) == ChunkBuilder.DecorPiece.HUERTO)
		assert_gt(huertos, 0, "huertos")


func test_city_is_deterministic_and_survives_the_cache() -> void:
	var plan: RegionPlan = _worlds[7].plan
	var a: PackedByteArray = var_to_bytes(ChunkBuilder.build(plan, CITY).to_dict())
	assert_eq(a, var_to_bytes((_worlds[7].chunk as WorldChunk).to_dict()), "mismos bytes")
	var other: RegionPlan = RegionPlan.for_region(7, REGION)
	assert_eq(a, var_to_bytes(ChunkBuilder.build(other, CITY).to_dict()), "mismo plan, mismo chunk")
	var back: WorldChunk = WorldChunk.from_dict(bytes_to_var(a))
	assert_not_null(back)
	assert_eq(back.objects_of(K.HOUSE).size(), (_worlds[7].chunk as WorldChunk).objects_of(K.HOUSE).size())
