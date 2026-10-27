extends GutTest
## Pasos 3 a 5 de la pasada de chunk (ChunkBuilder, ADR 0014 §5, M7): puntos de interés, red de
## senderos y formas grandes. "Sin la X ni el grano": red conexa desde el hub, hub no central,
## sin árboles sueltos, puertas iguales vistas desde los dos chunks, puntos de interés distintos y
## lejos del centro, determinismo. El invariante de niveles sigue en test_relief.gd.
##
## M8: refugios (cueva o árbol hueco, a ≤ 6 de un sendero; los 300 pasos, en
## test_places_and_refuges.gd), frutales 2×2,
## variantes de árbol sin repetición, letreros, villa, decoración, hierba y ríos sin huecos.
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
## Objetos del bosque que salen de un árbol 2×2 de la rejilla (M8).
const TREE_KINDS: int = (1 << K.TREE) | (1 << K.TREE_DEAD) | (1 << K.FRUIT_TREE) | (1 << K.REFUGE_TREE) \
		| (1 << K.TREE_BIG)

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
						# Cuenta como vecino cualquier árbol del bosque en esa celda de la rejilla
						# (M8: secos, frutales, huecos y el grande salen de árboles 2×2).
						if (dx != 0 or dy != 0) and (TREE_KINDS >> c.object_at(cell + Vector2i(dx, dy)).get("kind", K.SIGN)) & 1 == 1:
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
			if obj.kind == K.ROCK and obj.size != Vector2i.ONE: # las de 1×1 son de M8
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


# --- M8: refugios ------------------------------------------------------------------------------

static func _refuges_of(c: WorldChunk) -> Array[Dictionary]:
	var out: Array[Dictionary] = c.objects_of(K.CAVE)
	out.append_array(c.objects_of(K.REFUGE_TREE))
	return out


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


static func _near_trail(c: WorldChunk, cell: Vector2i, reach: int) -> bool:
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var n: Vector2i = cell + Vector2i(dx, dy)
			if WorldChunk.in_bounds(n) and (TRAIL_GROUND >> c.get_ground(n)) & 1 == 1 and c.get_ground(n) != WorldChunk.Ground.PLAZA:
				return true
	return false


## "" si el refugio cumple las reglas del reparto (mundo-2.md §3); si no, el motivo.
static func _refuge_problem(c: WorldChunk, r: Dictionary) -> String:
	if r.size != Vector2i(2, 2):
		return "refugio de %s" % r.size
	var near: bool = false
	for cell: Vector2i in _shelter_cells(r):
		if not c.is_walkable(cell):
			return "no se entra en %s" % r.cell
		near = near or _near_trail(c, cell, ChunkBuilder.REFUGE_TRAIL_REACH)
		if c.nujio_rect.size != Vector2i.ZERO:
			var gap: int = maxi(maxi(c.nujio_rect.position.x - cell.x, cell.x - c.nujio_rect.end.x + 1),
					maxi(c.nujio_rect.position.y - cell.y, cell.y - c.nujio_rect.end.y + 1))
			if gap > ChunkBuilder.REFUGE_NUJIO_REACH:
				return "refugio %s a %d del Nujio" % [r.cell, gap]
	if not near:
		return "refugio %s lejos de un sendero" % r.cell
	if r.kind == K.CAVE:
		# Boca abierta en la base de una cara; la fila de arriba sigue siendo cara.
		var top: Vector2i = r.cell
		if c.get_cliff(top) != WorldChunk.Cliff.FACE or c.get_cliff(top + Vector2i.DOWN) != WorldChunk.Cliff.NONE:
			return "cueva %s sin techo o sin boca" % r.cell
	return ""


func test_refuges_follow_the_plan_and_sit_by_a_trail() -> void:
	var caves: int = 0
	var trees: int = 0
	var extras: int = 0
	var planned: int = 0
	var failures: Array[String] = []
	for seed_value: int in _worlds:
		var plan: RegionPlan = _worlds[seed_value].plan
		planned += plan.refuge_chunks().size()
		for coord: Vector2i in _worlds[seed_value].chunks:
			var c: WorldChunk = _worlds[seed_value].chunks[coord]
			var refuges: Array[Dictionary] = _refuges_of(c)
			# Los refugios extra de la garantía de 300 pasos son árboles huecos que van después
			# del del reparto (test_places_and_refuges.gd); aquí solo se mira el del reparto.
			if not plan.has_refuge(coord):
				for extra: Dictionary in refuges:
					if extra.kind != K.REFUGE_TREE:
						failures.append("seed %d %s: refugio extra que no es árbol hueco" % [seed_value, coord])
				extras += refuges.size()
				continue
			if refuges.is_empty():
				failures.append("seed %d %s: sin refugio" % [seed_value, coord])
				continue
			extras += refuges.size() - 1
			# El del reparto es uno que cumple todas las reglas (los extra pueden no cumplirlas).
			var why: Array[String] = []
			var r: Dictionary = {}
			for cand: Dictionary in refuges:
				var problem: String = _refuge_problem(c, cand)
				if problem.is_empty():
					r = cand
					break
				why.append(problem)
			if r.is_empty():
				failures.append("seed %d %s: %s" % [seed_value, coord, why])
				continue
			caves += int(r.kind == K.CAVE)
			trees += int(r.kind == K.REFUGE_TREE)
	gut.p("refugios: %d cuevas y %d árboles huecos del reparto; %d extra (reparto: %d)" % [caves, trees, extras, planned])
	assert_lt(extras, planned / 4, "los refugios extra son pocos frente al reparto")
	assert_gt(caves, 0, "sale alguna cueva")
	assert_gt(trees, 0, "sale algún árbol hueco")
	assert_eq(failures.size(), 0, "refugios: %s" % [failures.slice(0, 8)])


## La garantía de ≤ 300 pasos a un refugio se prueba con 5 seeds en test_places_and_refuges.gd.


# --- M8: frutales ------------------------------------------------------------------------------

func test_fruit_trees_are_2x2_spaced_and_reachable() -> void:
	var total: int = 0
	var fruit_chunks: int = 0
	var short: int = 0
	var failures: Array[String] = []
	var region: Dictionary = (_worlds[42].plan as RegionPlan).region_params
	var params: Dictionary = ChunkGenerator.fruit_params(region).merged(
			ChunkBuilder.DEFAULT_CHUNK_FRUIT.merged(region.get("chunk_fruit", {}), true), true)
	var spacing: int = int(params.min_spacing)
	assert_eq(spacing, 6, "mundo-2.md §3: separación 6 entre esquinas noroeste")
	for seed_value: int in _worlds:
		var plan: RegionPlan = _worlds[seed_value].plan
		for coord: Vector2i in _worlds[seed_value].chunks:
			var c: WorldChunk = _worlds[seed_value].chunks[coord]
			var fruits: Array[Dictionary] = c.objects_of(K.FRUIT_TREE)
			if not ChunkGenerator.bosque_gives_fruit(plan.region_params, plan.bosques, plan.bosque_at(coord)):
				if not fruits.is_empty():
					failures.append("seed %d %s: frutales en un Bosque sin fruto" % [seed_value, coord])
				continue
			fruit_chunks += 1
			total += fruits.size()
			if fruits.size() < int(params.per_chunk[0]):
				short += 1
			assert_lte(fruits.size(), int(params.per_chunk[1]))
			for f: Dictionary in fruits:
				assert_eq(f.size, Vector2i(2, 2))
				assert_eq((f.cell as Vector2i) % 2, Vector2i.ZERO, "frutal en la rejilla de árboles")
				assert_between(int(f.variant), 0, 3, "variante 0-1 y volteo")
				for g: Dictionary in fruits:
					if g != f:
						var d: Vector2i = (g.cell as Vector2i) - (f.cell as Vector2i)
						if maxi(absi(d.x), absi(d.y)) < spacing:
							failures.append("seed %d %s: frutales %s y %s pegados" % [seed_value, coord, f.cell, g.cell])
	gut.p("frutales: %d en %d chunks con fruto; con menos de %d: %d" % [total, fruit_chunks, int(params.per_chunk[0]), short])
	assert_gt(total, fruit_chunks * 2, "unos 3-6 por chunk")
	assert_lt(short * 10, fruit_chunks, "casi todos los chunks llegan al mínimo")
	assert_eq(failures.size(), 0, "frutales: %s" % [failures.slice(0, 8)])


## Comprobación de accesibilidad de todo lo interactivo (frutales desde una vecina, letreros,
## refugios, casas, Nujio y tarca), con `blocked` y todos los objetos puestos.
func test_everything_interactive_is_reachable() -> void:
	var failures: Array[String] = []
	for seed_value: int in _worlds:
		for coord: Vector2i in _worlds[seed_value].chunks:
			for f: String in ChunkBuilder.inaccessible(_worlds[seed_value].chunks[coord]):
				failures.append("seed %d %s: %s" % [seed_value, coord, f])
	assert_eq(failures.size(), 0, "inaccesible: %s" % [failures.slice(0, 8)])


# --- M8: variantes de árbol --------------------------------------------------------------------

func test_tree_variants_never_repeat_next_to_each_other() -> void:
	var pairs: int = 0
	var ortho: int = 0
	var diag: int = 0
	var diag_pairs: int = 0
	var seen_variants: Dictionary = {}
	for seed_value: int in _worlds:
		var chunks: Dictionary = _worlds[seed_value].chunks
		var at: Dictionary = {} # world_cell -> variante (incluye los vecinos de otros chunks)
		for coord: Vector2i in chunks:
			for obj: Dictionary in (chunks[coord] as WorldChunk).objects:
				if obj.kind == K.TREE:
					at[WorldCoords.to_world_cell(coord, obj.cell)] = int(obj.variant)
					seen_variants[int(obj.variant)] = true
		for cell: Vector2i in at:
			for d: Vector2i in [Vector2i(2, 0), Vector2i(0, 2)]:
				if at.has(cell + d):
					pairs += 1
					ortho += int(at[cell + d] == at[cell])
			for d: Vector2i in [Vector2i(2, 2), Vector2i(2, -2)]:
				if at.has(cell + d):
					diag_pairs += 1
					diag += int(at[cell + d] == at[cell])
	gut.p("árboles vecinos: %d pares ortogonales (%d repetidos), %d diagonales (%d repetidos)" % [pairs, ortho, diag_pairs, diag])
	assert_eq(seen_variants.size(), 8, "4 variantes × volteo")
	assert_gt(pairs, 10000)
	assert_eq(ortho, 0, "dos vecinos ortogonales con la misma variante y el mismo volteo")
	assert_lt(diag * 1000, diag_pairs * 3, "menos del 3 ‰ de diagonales repetidas (solo si los 8 vecinos ya usan los 8 aspectos)")


func test_young_big_dead_trees_and_small_blockers_are_rare() -> void:
	var count: Dictionary = {}
	var small_rocks: int = 0
	var chunks: Dictionary = _worlds[42].chunks
	for c: WorldChunk in chunks.values():
		for obj: Dictionary in c.objects:
			count[obj.kind] = int(count.get(obj.kind, 0)) + 1
			match int(obj.kind):
				K.TREE_YOUNG, K.STUMP:
					assert_eq(obj.size, Vector2i.ONE)
				K.LOG:
					assert_eq(obj.size, Vector2i(2, 1))
				K.TREE_BIG:
					assert_eq(obj.size, Vector2i(3, 3))
				K.ROCK:
					small_rocks += int(obj.size == Vector2i.ONE)
	var names: Array[String] = []
	for k: int in count:
		names.append("%s %d" % [WorldChunk.ObjectKind.keys()[k], count[k]])
	gut.p("objetos (seed 42): %s" % ", ".join(names))
	for k: int in [K.TREE_YOUNG, K.TREE_DEAD, K.TREE_BIG, K.STUMP, K.LOG]:
		assert_gt(int(count.get(k, 0)), 0, "sale %s" % WorldChunk.ObjectKind.keys()[k])
	assert_gt(small_rocks, 0, "rocas pequeñas")
	assert_lt(int(count.get(K.TREE_DEAD, 0)) * 30, int(count[K.TREE]), "secos raros")
	assert_lt(int(count.get(K.STUMP, 0)) + int(count.get(K.LOG, 0)), chunks.size() * 5, "tocones y troncos raros")


# --- M8: letreros ------------------------------------------------------------------------------

func test_signs_sit_by_the_trail_and_point_the_right_way() -> void:
	var expected: int = 0
	var placed: int = 0
	var failures: Array[String] = []
	for seed_value: int in _worlds:
		var plan: RegionPlan = _worlds[seed_value].plan
		var b: BosqueMap = plan.bosques
		for coord: Vector2i in _worlds[seed_value].chunks:
			var c: WorldChunk = _worlds[seed_value].chunks[coord]
			var want: Dictionary = {}
			var id: int = plan.bosque_at(coord)
			if (b.has_villa[id] or b.has_aldea[id]) and b.nujio_chunk[id] != coord:
				want[WorldChunk.SignKind.BOSQUE_VILLA] = ChunkGenerator._side_towards(b.nujio_chunk[id] - coord)
			var roads: Array[Vector2i] = plan.road_sides(coord)
			var home: Vector2i = b.road_home_side(coord)
			if not roads.is_empty() and home != Vector2i.ZERO and (roads.size() >= 3 or posmod(coord.x + coord.y, 2) == 0):
				want[WorldChunk.SignKind.HOME_VILLA] = home
			expected += want.size()
			for s: Dictionary in c.signs:
				placed += 1
				var cell: Vector2i = s.cell
				if not want.has(s.kind):
					failures.append("seed %d %s: letrero de más (%d)" % [seed_value, coord, s.kind])
					continue
				if s.direction != want[s.kind]:
					failures.append("seed %d %s: letrero %d señala %s y no %s" % [seed_value, coord, s.kind, s.direction, want[s.kind]])
				assert_eq(c.object_at(cell).get("kind", -1), K.SIGN)
				var beside: bool = false
				for d: Vector2i in WorldChunk.SIDES:
					var n: Vector2i = cell + d
					if not WorldChunk.in_bounds(n) or not c.is_reachable(n):
						continue
					var g: int = c.get_ground(n)
					if s.kind == WorldChunk.SignKind.HOME_VILLA:
						beside = beside or g == WorldChunk.Ground.ROAD
					else:
						beside = beside or (TRAIL_GROUND >> g) & 1 == 1
				if not beside:
					failures.append("seed %d %s: letrero %s no está junto al sendero o camino" % [seed_value, coord, cell])
				if s.kind == WorldChunk.SignKind.HOME_VILLA:
					var door: Dictionary = plan.door(coord, s.direction)
					assert_true(bool(door.get("road", false)), "seed %d %s: la puerta hacia casa es de camino" % [seed_value, coord])
	gut.p("letreros: %d de %d esperados" % [placed, expected])
	assert_gt(expected, 50)
	assert_gte(placed * 100, expected * 95, "al menos el 95 % de los letreros tienen sitio")
	assert_eq(failures.size(), 0, "letreros: %s" % [failures.slice(0, 8)])


# --- M8: villa ---------------------------------------------------------------------------------

func test_villa_houses_frame_the_plaza_without_cutting_trails() -> void:
	var villas: int = 0
	var huertos: int = 0
	var failures: Array[String] = []
	for seed_value: int in _worlds:
		var plan: RegionPlan = _worlds[seed_value].plan
		for coord: Vector2i in _worlds[seed_value].chunks:
			var c: WorldChunk = _worlds[seed_value].chunks[coord]
			var houses: Array[Dictionary] = c.objects_of(K.HOUSE)
			if not c.has_villa:
				assert_eq(houses.size(), 0, "casas fuera de una villa en %s" % coord)
				continue
			villas += 1
			var v: Dictionary = plan.villa_in_chunk(coord)
			var wanted: int = int(v.houses) if int(v.get("houses", 0)) > 0 else ChunkBuilder.VILLA_HOUSES
			if houses.size() < mini(wanted, 2):
				failures.append("seed %d %s: %d casas de %d" % [seed_value, coord, houses.size(), wanted])
			for hse: Dictionary in houses:
				var r := Rect2i(hse.cell, hse.size)
				for other: Dictionary in houses:
					if other != hse and r.grow(1).intersects(Rect2i(other.cell, other.size)):
						failures.append("seed %d %s: casas pegadas en %s" % [seed_value, coord, r.position])
				for y: int in range(r.position.y, r.end.y):
					for x: int in range(r.position.x, r.end.x):
						if (TRAIL_GROUND >> c.get_ground(Vector2i(x, y))) & 1 == 1:
							failures.append("seed %d %s: casa sobre un sendero en %s" % [seed_value, coord, Vector2i(x, y)])
				var front: bool = false
				for x: int in range(r.position.x, r.end.x):
					front = front or c.is_reachable(Vector2i(x, r.end.y))
				if not front:
					failures.append("seed %d %s: casa %s sin acceso" % [seed_value, coord, r.position])
			# Plaza alrededor del Nujio (refugio de la villa, AdventureRules.is_villa_rest), alcanzable.
			var plaza: int = 0
			for i: int in WorldChunk.CELLS:
				if ChunkBuilder.decor_piece(c.decor[i]) == ChunkBuilder.DecorPiece.HUERTO:
					huertos += 1
				if c.ground[i] != WorldChunk.Ground.PLAZA:
					continue
				plaza += 1
				if c.blocked[i] == 0 and not c.is_reachable(WorldCoords.index_to_cell(i)):
					failures.append("seed %d %s: plaza aislada en %s" % [seed_value, coord, WorldCoords.index_to_cell(i)])
			assert_gt(plaza, 0, "la villa de %s tiene plaza" % coord)
	gut.p("villas y aldeas: %d; casillas de huerto: %d" % [villas, huertos])
	assert_gt(villas, 5)
	assert_gt(huertos, 0, "hay huertos")
	assert_eq(failures.size(), 0, "villas: %s" % [failures.slice(0, 8)])


# --- M8: hierba y decoración -------------------------------------------------------------------

func test_decor_never_on_trails_shadows_or_blocking() -> void:
	var pieces: int = 0
	var used: Dictionary = {}
	var failures: Array[String] = []
	for seed_value: int in _worlds:
		for coord: Vector2i in _worlds[seed_value].chunks:
			var c: WorldChunk = _worlds[seed_value].chunks[coord]
			for i: int in WorldChunk.CELLS:
				var g: int = c.ground[i]
				var piece: int = ChunkBuilder.decor_piece(c.decor[i])
				if piece < 0:
					continue
				pieces += 1
				used[piece] = true
				if (TRAIL_GROUND >> g) & 1 == 1 or c.cliff[i] != WorldChunk.Cliff.NONE or c.occupant[i] != WorldChunk.NO_OBJECT \
						or c.blocked[i] == 1:
					failures.append("seed %d %s: decoración %d en %s" % [seed_value, coord, piece, WorldCoords.index_to_cell(i)])
	gut.p("piezas de decoración: %d (%d distintas)" % [pieces, used.size()])
	assert_gt(pieces, 384 * 100, "unas 100 o más por chunk")
	assert_gte(used.size(), 16, "al menos 16 piezas distintas (spec §6.2)")
	assert_eq(failures.size(), 0, "decoración mal puesta: %s" % [failures.slice(0, 8)])


func test_grass_variants_come_in_large_patches() -> void:
	var same: int = 0
	var pairs: int = 0
	var counts := PackedInt32Array([0, 0, 0, 0])
	for c: WorldChunk in (_worlds[42].chunks as Dictionary).values():
		for y: int in SIZE:
			for x: int in SIZE - 1:
				var i: int = y * SIZE + x
				if c.ground[i] != WorldChunk.Ground.GRASS or c.cliff[i] != WorldChunk.Cliff.NONE:
					continue
				counts[c.variant[i]] += 1
				if c.ground[i + 1] == WorldChunk.Ground.GRASS and c.cliff[i + 1] == WorldChunk.Cliff.NONE:
					pairs += 1
					same += int(c.variant[i] == c.variant[i + 1])
	gut.p("hierba: variantes %s; vecinas iguales %d de %d" % [counts, same, pairs])
	for k: int in 4:
		assert_gt(counts[k] * 8, pairs, "la variante %d sale en manchas de verdad" % k)
	assert_gt(same * 10, pairs * 8, "manchas grandes (ruido de baja frecuencia), no grano")


# --- M8: ríos ----------------------------------------------------------------------------------

## Los rótulos de afluentes (`lugar`) y los `manantial` no dejan un hueco seco en el río.
func test_rivers_have_no_gaps_at_their_labels() -> void:
	const WET: int = WorldChunk.GROUND_BLOCKING | (1 << WorldChunk.Ground.FORD) | (1 << WorldChunk.Ground.BRIDGE)
	var authoring := RegionAuthoring.load_region(REGION)
	var checked: int = 0
	var failures: Array[String] = []
	for seed_value: int in _worlds:
		var plan: RegionPlan = _worlds[seed_value].plan
		var chunks: Dictionary = _worlds[seed_value].chunks
		for p: Dictionary in authoring.places:
			if not RegionPlan.WATER_LABELS.has(String(p.type)):
				continue
			for dy: int in range(-3, 4):
				for dx: int in range(-3, 4):
					var m: Vector2i = (p.cell as Vector2i) + Vector2i(dx, dy)
					if plan.water_at(m) == RegionAuthoring.Water.NONE:
						continue
					var coord: Vector2i = WorldCoords.floor_div_v(m, WorldCoords.MACROS_PER_CHUNK)
					if not chunks.has(coord):
						continue
					var c: WorldChunk = chunks[coord]
					var origin: Vector2i = m * WorldCoords.MACRO - coord * SIZE
					for ty: int in WorldCoords.MACRO:
						for tx: int in WorldCoords.MACRO:
							var cell: Vector2i = origin + Vector2i(tx, ty)
							checked += 1
							if (WET >> c.get_ground(cell)) & 1 == 0 and c.get_cliff(cell) != WorldChunk.Cliff.WATERFALL:
								failures.append("seed %d %s: casilla seca %s del río junto a %s" % [seed_value, coord, cell, p.id])
	gut.p("casillas de río junto a rótulos y manantiales: %d" % checked)
	assert_gt(checked, 100)
	assert_eq(failures.size(), 0, "huecos en el río: %s" % [failures.slice(0, 8)])
