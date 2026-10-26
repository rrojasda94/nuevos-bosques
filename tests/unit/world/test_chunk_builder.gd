extends GutTest
## Pasos 3 a 5 de la pasada de chunk (ChunkBuilder, ADR 0014 §5, M7): puntos de interés, red de
## senderos y formas grandes. "Sin la X ni el grano": red conexa desde el hub, hub no central,
## sin árboles sueltos, puertas iguales vistas desde los dos chunks, puntos de interés distintos y
## lejos del centro, determinismo. El invariante de niveles sigue en test_relief.gd.
##
## Muestra: la región entera con 2 seeds (384 chunks).

const REGION: StringName = &"valle_del_sara"
const SEEDS: Array[int] = [42, 7]
const SIZE: int = WorldChunk.SIZE
const K := WorldChunk.ObjectKind
const P := WorldChunk.PointKind
const OPEN_CLIFFS: int = (1 << WorldChunk.Cliff.NONE) | (1 << WorldChunk.Cliff.STAIRS) | (1 << WorldChunk.Cliff.RAMP)
const TRAIL_GROUND: int = (1 << WorldChunk.Ground.PATH) | (1 << WorldChunk.Ground.ROAD) \
		| (1 << WorldChunk.Ground.BRIDGE) | (1 << WorldChunk.Ground.PLAZA)
## Un hub "central" está a menos de esto (Chebyshev) del centro del chunk.
const CENTRAL: int = 4

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


static func _door_cells(door: Dictionary, side: Vector2i) -> Array[Vector2i]:
	var along: Vector2i = Vector2i.DOWN if side.x != 0 else Vector2i.RIGHT
	var out: Array[Vector2i] = []
	for k: int in int(door.width):
		out.append((door.cell as Vector2i) + along * k)
	return out


static func _closed(c: WorldChunk, cell: Vector2i) -> bool:
	return (OPEN_CLIFFS >> c.get_cliff(cell)) & 1 == 0


# --- Red de senderos ---------------------------------------------------------------------------

func test_network_reaches_every_door_and_point_from_the_hub() -> void:
	var failures: Array[String] = []
	var checked: int = 0
	var closed: int = 0
	for seed_value: int in _worlds:
		var plan: RegionPlan = _worlds[seed_value].plan
		var chunks: Dictionary = _worlds[seed_value].chunks
		for coord: Vector2i in chunks:
			var c: WorldChunk = chunks[coord]
			if not c.is_walkable(c.hub):
				failures.append("seed %d chunk %s: hub %s bloqueado" % [seed_value, coord, c.hub])
				continue
			var doors: Dictionary = plan.doors_of(coord)
			for side: Vector2i in doors:
				for cell: Vector2i in _door_cells(doors[side], side):
					checked += 1
					if _closed(c, cell):
						closed += 1 # cumbre o cascada en la puerta
						continue
					if not c.is_reachable(cell):
						failures.append("seed %d chunk %s puerta %s" % [seed_value, coord, cell])
			for p: Dictionary in c.points:
				checked += 1
				if not c.is_reachable(p.cell):
					failures.append("seed %d chunk %s punto %s en %s" % [seed_value, coord, WorldChunk.POINT_IDS[p.kind], p.cell])
	gut.p("casillas revisadas: %d; puertas en cumbre o cascada: %d" % [checked, closed])
	assert_gt(checked, 3000)
	assert_lt(closed, checked / 50)
	assert_eq(failures.size(), 0, "sin unir al hub: %s" % [failures.slice(0, 8)])


func test_hub_is_not_central() -> void:
	var central: int = 0
	var total: int = 0
	var center: Vector2i = WorldChunk.center()
	for seed_value: int in _worlds:
		for c: WorldChunk in (_worlds[seed_value].chunks as Dictionary).values():
			total += 1
			if maxi(absi(c.hub.x - center.x), absi(c.hub.y - center.y)) < CENTRAL:
				central += 1
	gut.p("hubs a menos de %d casillas del centro: %d de %d" % [CENTRAL, central, total])
	assert_lte(central * 5, total, "hub central en más del 20 %% de los chunks")


func test_doors_are_the_same_seen_from_both_chunks() -> void:
	var failures: Array[String] = []
	var pairs: int = 0
	for seed_value: int in _worlds:
		var plan: RegionPlan = _worlds[seed_value].plan
		var chunks: Dictionary = _worlds[seed_value].chunks
		for coord: Vector2i in chunks:
			for side: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				if not chunks.has(coord + side) or not plan.has_door(coord, side):
					continue
				var a: WorldChunk = chunks[coord]
				var b: WorldChunk = chunks[coord + side]
				var da: Dictionary = plan.door(coord, side)
				var db: Dictionary = plan.door(coord + side, -side)
				assert_eq(da.index, db.index)
				assert_eq(da.width, db.width)
				var ca: Array[Vector2i] = _door_cells(da, side)
				var cb: Array[Vector2i] = _door_cells(db, -side)
				for k: int in ca.size():
					pairs += 1
					if _closed(a, ca[k]) or _closed(b, cb[k]):
						continue
					if not a.is_walkable(ca[k]) or not b.is_walkable(cb[k]):
						failures.append("seed %d %s|%s casilla %d: se pisa %s / %s" % [seed_value, coord, coord + side, k,
								a.is_walkable(ca[k]), b.is_walkable(cb[k])])
					elif (TRAIL_GROUND >> a.get_ground(ca[k])) & 1 == 0 and a.get_ground(ca[k]) != WorldChunk.Ground.FORD:
						failures.append("seed %d %s puerta %s sin sendero" % [seed_value, coord, ca[k]])
					elif bool(da.road) and a.get_ground(ca[k]) == WorldChunk.Ground.PATH:
						failures.append("seed %d %s puerta de camino %s con suelo de sendero" % [seed_value, coord, ca[k]])
	assert_gt(pairs, 1000)
	assert_eq(failures.size(), 0, "puertas distintas a cada lado: %s" % [failures.slice(0, 8)])


func test_objects_never_sit_on_trails() -> void:
	var bad: int = 0
	for c: WorldChunk in (_worlds[42].chunks as Dictionary).values():
		for i: int in WorldChunk.CELLS:
			if c.occupant[i] != WorldChunk.NO_OBJECT and (TRAIL_GROUND >> c.ground[i]) & 1 == 1 \
					and c.ground[i] != WorldChunk.Ground.PLAZA:
				bad += 1
	assert_eq(bad, 0, "casillas de sendero tapadas por un objeto")


# --- Formas grandes ----------------------------------------------------------------------------

func test_no_lone_trees() -> void:
	var trees: int = 0
	var lone: Array[String] = []
	for seed_value: int in _worlds:
		for coord: Vector2i in _worlds[seed_value].chunks:
			var c: WorldChunk = _worlds[seed_value].chunks[coord]
			var at: Dictionary = {}
			for obj: Dictionary in c.objects:
				if obj.kind == K.TREE:
					assert_eq(obj.size, Vector2i(2, 2), "árbol de 2×2")
					assert_eq((obj.cell as Vector2i) % 2, Vector2i.ZERO, "en la rejilla de 2×2")
					at[obj.cell] = true
			for cell: Vector2i in at:
				trees += 1
				var n: int = 0
				for dy: int in range(-2, 3, 2):
					for dx: int in range(-2, 3, 2):
						if (dx != 0 or dy != 0) and at.has(cell + Vector2i(dx, dy)):
							n += 1
				if n < int(ChunkBuilder.DEFAULT_SHAPES.forest_min_neighbours):
					lone.append("seed %d chunk %s árbol %s (%d vecinos)" % [seed_value, coord, cell, n])
	gut.p("árboles 2×2: %d" % trees)
	assert_gt(trees, 10000)
	assert_eq(lone.size(), 0, "árboles sueltos: %s" % [lone.slice(0, 8)])


func test_rocks_on_rocky_ground_and_nujio_villa_shapes() -> void:
	var rocks: int = 0
	var houses: int = 0
	var villas: int = 0
	for c: WorldChunk in (_worlds[42].chunks as Dictionary).values():
		for obj: Dictionary in c.objects:
			if obj.kind == K.ROCK:
				rocks += 1
				assert_eq(obj.size, Vector2i(2, 2))
			elif obj.kind == K.HOUSE:
				houses += 1
				assert_eq(obj.size, ChunkBuilder.HOUSE_SIZE)
		if c.nujio_rect.size != Vector2i.ZERO:
			assert_eq(c.nujio_rect.size, Vector2i(ChunkBuilder.NUJIO_SIZE, ChunkBuilder.NUJIO_SIZE))
			assert_eq(c.object_at(c.nujio_rect.position).get("kind", -1), K.NUJIO, "Nujio en %s" % c.coord)
			# Zona del Nujio aplanada: la huella y su alrededor, a un nivel.
			var level: int = c.get_level(c.nujio_rect.position)
			for y: int in range(c.nujio_rect.position.y - 4, c.nujio_rect.end.y + 4):
				for x: int in range(c.nujio_rect.position.x - 4, c.nujio_rect.end.x + 4):
					assert_eq(c.get_level(Vector2i(x, y)), level, "zona del Nujio de %s aplanada" % c.coord)
		if c.has_villa:
			villas += 1
	gut.p("rocas: %d, casas: %d, villas: %d" % [rocks, houses, villas])
	assert_gt(rocks, 100)
	assert_gt(villas, 0)
	assert_gte(houses, villas * 2, "al menos 2 casas por villa")


# --- Puntos de interés -------------------------------------------------------------------------

func test_points_are_distinct_and_away_from_the_center() -> void:
	var empty: int = 0
	var open_chunks: int = 0
	var count: Dictionary = {}
	var center: Vector2i = WorldChunk.center()
	for seed_value: int in _worlds:
		var plan: RegionPlan = _worlds[seed_value].plan
		for coord: Vector2i in _worlds[seed_value].chunks:
			var c: WorldChunk = _worlds[seed_value].chunks[coord]
			var kinds: Dictionary = {}
			var procedural: int = 0
			for p: Dictionary in c.points:
				if p.kind == P.PLACE:
					continue
				assert_false(kinds.has(p.kind), "dos %s en %s" % [WorldChunk.POINT_IDS[p.kind], coord])
				kinds[p.kind] = true
				procedural += 1
				count[p.kind] = int(count.get(p.kind, 0)) + 1
				var r: Rect2i = p.rect
				var mid: Vector2i = r.get_center()
				assert_false(r.has_point(center), "punto de interés en el centro de %s" % coord)
				assert_gte(maxi(absi(mid.x - center.x), absi(mid.y - center.y)), ChunkBuilder.CENTER_CLEAR)
				for q: Dictionary in c.points:
					if q != p:
						assert_false(r.intersects(q.rect), "puntos solapados en %s" % coord)
			if c.nujio_rect.size != Vector2i.ZERO:
				assert_lte(procedural, 1, "chunk de Nujio o villa con más de 1 punto: %s" % coord)
			else:
				open_chunks += 1
				assert_lte(procedural, 3)
				if c.points.is_empty():
					empty += 1
			assert_true(plan != null)
	var names: Array[String] = []
	for k: int in count:
		names.append("%s %d" % [WorldChunk.POINT_IDS[k], count[k]])
	gut.p("puntos de interés: %s; chunks sin ninguno: %d de %d" % [", ".join(names), empty, open_chunks])
	assert_eq(count.size(), ChunkBuilder.RANDOM_POINTS, "salen todos los tipos")
	assert_lt(empty * 10, open_chunks, "menos del 10 %% de chunks sin punto de interés")


func test_latitude_weights_show() -> void:
	var north: Dictionary = {}
	var south: Dictionary = {}
	for seed_value: int in _worlds:
		var rows: int = (_worlds[seed_value].plan as RegionPlan).size_chunks.y
		for coord: Vector2i in _worlds[seed_value].chunks:
			var c: WorldChunk = _worlds[seed_value].chunks[coord]
			var half: Dictionary = north if coord.y < rows / 2 else south
			for p: Dictionary in c.points:
				half[p.kind] = int(half.get(p.kind, 0)) + 1
	gut.p("norte: %s; sur: %s" % [north, south])
	assert_gt(int(north.get(P.HILL, 0)), int(south.get(P.HILL, 0)), "más colinas al norte")
	assert_gt(int(south.get(P.POND, 0)) + int(south.get(P.MEADOW, 0)),
			int(north.get(P.POND, 0)) + int(north.get(P.MEADOW, 0)), "más lagunas y praderas al sur")


func test_hill_has_stairs_on_its_south_face() -> void:
	var hills: int = 0
	for c: WorldChunk in (_worlds[42].chunks as Dictionary).values():
		for p: Dictionary in c.points:
			if p.kind != P.HILL:
				continue
			hills += 1
			var r: Rect2i = p.rect
			var inner: Vector2i = r.get_center()
			assert_eq(c.get_level(inner), c.get_level(Vector2i(r.position.x + 1, r.end.y + 3)) + 1, "colina +1 nivel")
			assert_eq(c.get_cliff(Vector2i(p.cell.x, r.end.y)), WorldChunk.Cliff.STAIRS, "escalera en la cara sur")
			assert_eq(c.object_at(inner + Vector2i(0, -2)).get("kind", -1), K.TREE_BIG, "árbol hito encima")
	assert_gt(hills, 5)


# --- Determinismo ------------------------------------------------------------------------------

func test_same_chunk_twice_gives_the_same_bytes() -> void:
	var plan: RegionPlan = _worlds[7].plan
	for coord: Vector2i in [Vector2i(0, 0), Vector2i(4, 12), Vector2i(6, 13), Vector2i(11, 15)]:
		var a: PackedByteArray = var_to_bytes(ChunkBuilder.build(plan, coord).to_dict())
		assert_eq(a, var_to_bytes(ChunkBuilder.build(plan, coord).to_dict()), "chunk %s" % coord)
		assert_eq(a, var_to_bytes((_worlds[7].chunks[coord] as WorldChunk).to_dict()), "chunk %s frente al de before_all" % coord)


func test_points_survive_the_cache_format() -> void:
	var c: WorldChunk = _worlds[42].chunks[Vector2i(4, 13)]
	var back: WorldChunk = WorldChunk.from_dict(bytes_to_var(var_to_bytes(c.to_dict())))
	assert_not_null(back)
	assert_eq(back.points, c.points)
