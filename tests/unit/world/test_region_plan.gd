extends GutTest
## Pasada de región (RegionPlan, ADR 0014 §5): determinismo, Bosques de 4-16 chunks recorribles
## por puertas, puertas simétricas, villas del CSV, aldeas de la opción C (mundo-2.md §6), altura
## procedural sin celdas sueltas, agua con meandro sin cortes y tiempo de la pasada (aviso).

const HEADER: String = "id,nombre,tipo,x,y,color,estilo,notas"
const BUDGET_MSEC: int = 1500
const SEEDS: Array[int] = [1, 2, 3, 5, 8, 13, 21, 42, 77, 1234]

var _region: Dictionary
var _authoring: RegionAuthoring
var _palette: Dictionary
var _plan42: RegionPlan


func before_all() -> void:
	_region = ChunkGenerator.load_region(&"valle_del_sara")
	_authoring = RegionAuthoring.load_region(&"valle_del_sara")
	_palette = RegionAuthoring.load_palette()
	_plan42 = _build(42)


func _build(seed_value: int, region: Dictionary = _region, authoring: RegionAuthoring = _authoring) -> RegionPlan:
	return RegionPlan.build(seed_value, &"valle_del_sara", region, authoring)


func _all_doors(plan: RegionPlan) -> Dictionary:
	var out: Dictionary = {}
	for y: int in plan.size_chunks.y:
		for x: int in plan.size_chunks.x:
			var c := Vector2i(x, y)
			var doors: Dictionary = plan.doors_of(c)
			for side: Vector2i in doors:
				out[[c, side]] = doors[side]
	return out


## Región sintética de `chunks` chunks: sin altura ni agua pintadas, solo la villa natal.
func _blank_authoring(chunks: Vector2i, rows: Array = [], with_water: bool = false) -> RegionAuthoring:
	var px: Vector2i = chunks * WorldCoords.MACROS_PER_CHUNK
	var images: Dictionary = { "roads": Image.create_empty(px.x, px.y, false, Image.FORMAT_RGBA8) }
	if with_water:
		images["water"] = Image.create_empty(px.x, px.y, false, Image.FORMAT_RGBA8)
	var csv: String = "\n".join([HEADER, "villa_natal,Casa,villa_natal,%d,%d,,," % [px.x / 2 + 3, px.y / 2 + 3]] + rows) + "\n"
	return RegionAuthoring.from_sources(images, csv, _palette)


# --- Determinismo ------------------------------------------------------------------------------

func test_same_inputs_give_the_same_plan() -> void:
	var a := _build(42)
	assert_eq(a.authoring_hash, _plan42.authoring_hash)
	assert_eq(a.plan_seed, _plan42.plan_seed)
	assert_eq(a.height_layer(), _plan42.height_layer(), "altura gruesa")
	assert_eq(a.water_layer(), _plan42.water_layer(), "agua")
	assert_eq(a.road_layer(), _plan42.road_layer(), "caminos pintados")
	assert_eq(a.bosques.ids, _plan42.bosques.ids, "Bosques")
	assert_eq(a.bosques.state, _plan42.bosques.state, "estados")
	assert_eq(a.bosques.area_of, _plan42.bosques.area_of, "áreas")
	assert_eq(a.villas(), _plan42.villas(), "villas y aldeas")
	assert_eq(a.refuge_chunks(), _plan42.refuge_chunks(), "refugios")
	assert_eq(_all_doors(a), _all_doors(_plan42), "puertas")
	for y: int in a.size_chunks.y:
		for x: int in a.size_chunks.x:
			assert_eq(a.road_sides(Vector2i(x, y)), _plan42.road_sides(Vector2i(x, y)))


func test_seed_and_authoring_change_the_plan() -> void:
	var other := _build(43)
	assert_ne(other.bosques.ids, _plan42.bosques.ids, "otra seed, otros Bosques")
	assert_eq(other.authoring_hash, _plan42.authoring_hash, "la autoría no depende de la seed")
	var moved := RegionAuthoring.from_sources({ "roads": Image.create_empty(240, 320, false, Image.FORMAT_RGBA8) },
			HEADER + "\nvilla_natal,Casa,villa_natal,130,271,,,\n", _palette)
	assert_ne(RegionPlan.authoring_hash_of(moved), _plan42.authoring_hash, "mover un lugar cambia el hash")


func test_plan_is_not_changed_by_queries() -> void:
	var before: Array[Dictionary] = _plan42.villas()
	before[0].name = "otro"
	var d: Dictionary = _plan42.door(Vector2i(1, 1), Vector2i.RIGHT)
	if not d.is_empty():
		d.index = -5
	assert_ne(_plan42.villas()[0].name, "otro", "villas() devuelve copias")
	assert_ne(int(_plan42.door(Vector2i(1, 1), Vector2i.RIGHT).get("index", 0)), -5, "door() devuelve copias")


# --- Bosques y puertas -------------------------------------------------------------------------

func test_bosques_have_4_to_16_contiguous_chunks() -> void:
	for s: int in SEEDS:
		var plan := _build(s)
		var map: BosqueMap = plan.bosques
		assert_false(map.ids.has(-1), "seed %d: todo chunk tiene Bosque" % s)
		for id: int in map.count():
			var n: int = map.size_of(id)
			if n < BosqueMap.MIN_SIZE or n > BosqueMap.MAX_SIZE or not map.is_contiguous(id):
				fail_test("seed %d: Bosque %d con %d chunks (contiguo: %s)" % [s, id, n, map.is_contiguous(id)])
	pass_test("Bosques de 4-16 chunks")


func test_every_bosque_is_walkable_through_its_doors() -> void:
	for s: int in SEEDS:
		var plan := _build(s)
		var map: BosqueMap = plan.bosques
		for id: int in map.count():
			var chunks: Array[Vector2i] = map.chunks_of(id)
			var seen: Dictionary = { chunks[0]: true }
			var queue: Array[Vector2i] = [chunks[0]]
			while not queue.is_empty():
				var c: Vector2i = queue.pop_back()
				for side: Vector2i in ChunkData.SIDES:
					if map.bosque_at(c + side) == id and plan.has_door(c, side) and not seen.has(c + side):
						seen[c + side] = true
						queue.append(c + side)
			if seen.size() != chunks.size():
				fail_test("seed %d: Bosque %d, %d de %d chunks a pie" % [s, id, seen.size(), chunks.size()])
	pass_test("todo Bosque se recorre por puertas")


func test_doors_are_symmetric_and_inside_the_border() -> void:
	var plan := _plan42
	for y: int in plan.size_chunks.y:
		for x: int in plan.size_chunks.x:
			var c := Vector2i(x, y)
			for side: Vector2i in ChunkData.SIDES:
				var d: Dictionary = plan.door(c, side)
				var n: Vector2i = c + side
				var inside: bool = n.x >= 0 and n.y >= 0 and n.x < plan.size_chunks.x and n.y < plan.size_chunks.y
				if not inside:
					assert_true(d.is_empty(), "sin puerta hacia fuera de la región en %s %s" % [c, side])
					continue
				var o: Dictionary = plan.door(n, -side)
				assert_eq(d.is_empty(), o.is_empty(), "puerta en los dos lados de %s %s" % [c, side])
				if d.is_empty():
					continue
				assert_eq([d.index, d.width, d.road], [o.index, o.width, o.road], "misma puerta vista desde %s" % n)
				assert_between(int(d.index), 0, WorldCoords.CHUNK - int(d.width), "dentro del borde")
				var cell: Vector2i = d.cell
				var other: Vector2i = o.cell
				assert_eq(WorldCoords.to_world_cell(c, cell) + side, WorldCoords.to_world_cell(n, other), "casillas enfrentadas")


func test_road_sides_always_have_a_road_door() -> void:
	for s: int in [42, 7]:
		var plan := _build(s)
		for y: int in plan.size_chunks.y:
			for x: int in plan.size_chunks.x:
				for side: Vector2i in plan.road_sides(Vector2i(x, y)):
					var d: Dictionary = plan.door(Vector2i(x, y), side)
					assert_true(not d.is_empty() and d.road and d.width == RegionPlan.ROAD_WIDTH,
							"seed %d: camino en %s hacia %s con puerta de camino" % [s, Vector2i(x, y), side])


func test_about_70_percent_of_borders_have_doors() -> void:
	var open: int = 0
	var total: int = 0
	for y: int in _plan42.size_chunks.y:
		for x: int in _plan42.size_chunks.x:
			for side: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var n: Vector2i = Vector2i(x, y) + side
				if n.x < _plan42.size_chunks.x and n.y < _plan42.size_chunks.y:
					total += 1
					open += 1 if _plan42.has_door(Vector2i(x, y), side) else 0
	var ratio: float = float(open) / total
	assert_between(ratio, 0.65, 0.95, "puertas abiertas: %.2f (70 %% más caminos y árbol)" % ratio)


func test_refuges_follow_adr_0006() -> void:
	var map: BosqueMap = _plan42.bosques
	for id: int in map.count():
		assert_true(_plan42.has_refuge(map.nujio_chunk[id]), "refugio en el chunk de Nujio del Bosque %d" % id)
	for y: int in _plan42.size_chunks.y:
		for x: int in _plan42.size_chunks.x:
			assert_lte(map.refuge_distance(Vector2i(x, y)), 2, "refugio a ≤ 2 chunks de %s" % Vector2i(x, y))


# --- Villas y aldeas ---------------------------------------------------------------------------

func test_csv_villas_are_in_the_plan() -> void:
	for s: int in SEEDS:
		var plan := _build(s)
		var by_id: Dictionary = {}
		for v: Dictionary in plan.villas():
			by_id[v.id] = v
		for kind: String in ["villa_natal", "villa", "ciudad"]:
			for p: Dictionary in _authoring.places_of_type(kind):
				assert_true(by_id.has(p.id), "seed %d: está %s" % [s, p.id])
				var v: Dictionary = by_id.get(p.id, {})
				var chunk: Vector2i = RegionAuthoring.chunk_of(p.cell)
				assert_eq(v.get("chunk"), chunk, "en su chunk")
				assert_eq(v.get("name"), p.name, "con su nombre")
				assert_true(plan.bosques.has_villa[plan.bosque_at(chunk)], "su Bosque tiene villa")
		assert_eq(plan.home_chunk, _authoring.home_chunk(), "la villa natal sustituye a start_chunk")
		assert_eq(plan.bosques.home_bosque, plan.bosque_at(plan.home_chunk), "Bosque natal")
		var bosques_with_villa: Dictionary = {}
		for v: Dictionary in plan.villas():
			if v.kind != "aldea":
				bosques_with_villa[v.bosque_id] = true
		assert_eq(bosques_with_villa.size(), _authoring.places_of_type("villa").size() + _authoring.places_of_type("ciudad").size() + 1,
				"seed %d: cada villa con nombre en su propio Bosque" % s)


func _check_option_c(plan: RegionPlan, label: String) -> int:
	var map: BosqueMap = plan.bosques
	var per_area: Dictionary = {}
	var names: Dictionary = {}
	var aldeas: Array[Dictionary] = plan.aldeas()
	for v: Dictionary in plan.villas():
		if v.kind != "aldea":
			names[v.name] = true
	for v: Dictionary in aldeas:
		var id: int = v.bosque_id
		assert_false(map.has_villa[id], "%s: aldea %s no en un Bosque con villa" % [label, v.name])
		for n: int in map.neighbours_of(id):
			assert_false(map.has_villa[n], "%s: aldea %s no junto a una villa con nombre" % [label, v.name])
		assert_ne(map.state_of(id), BosqueMap.STATE_MUERTO, "%s: no en un Bosque muerto" % label)
		assert_eq(v.chunk, map.nujio_chunk[id], "en el chunk del Nujio")
		assert_between(int(v.houses), 2, 4, "2-4 casas")
		assert_ne(String(v.name), "", "con nombre tentativo")
		assert_false(names.has(v.name), "%s: nombre %s sin repetir" % [label, v.name])
		names[v.name] = true
		per_area[map.area_of[id]] = int(per_area.get(map.area_of[id], 0)) + 1
	for area: int in per_area:
		assert_lte(int(per_area[area]), 2, "%s: como mucho 2 aldeas en el área %d" % [label, area])
	return aldeas.size()


func test_aldeas_follow_option_c_in_the_valle() -> void:
	assert_eq(float(_region.get("procedural_villa_chance", 0.0)), 0.2, "opción C: 0,2")
	var total: int = 0
	for s: int in range(1, 41):
		total += _check_option_c(_build(s), "seed %d" % s)
	assert_gt(total, 0, "salen aldeas en alguna seed")


func test_aldeas_cap_per_area_with_chance_one() -> void:
	var region: Dictionary = _region.duplicate(true)
	region["procedural_villa_chance"] = 1.0
	var authoring := _blank_authoring(Vector2i(12, 16))
	var total: int = 0
	for s: int in [1, 2, 3]:
		var plan := _build(s, region, authoring)
		total += _check_option_c(plan, "seed %d (chance 1)" % s)
		var map: BosqueMap = plan.bosques
		for id: int in map.count():
			var n: int = map.bosques_of_area(map.area_of[id]).size()
			assert_true(n >= BosqueMap.AREA_MIN or map.area_count == 1, "área de %d Bosques" % n)
	assert_gt(total, 0, "con probabilidad 1 hay aldeas")


func test_no_aldeas_when_chance_is_zero() -> void:
	var region: Dictionary = _region.duplicate(true)
	region.erase("procedural_villa_chance")
	assert_eq(_build(7, region).aldeas().size(), 0, "por defecto 0: solo villas con nombre (ADR 0014)")


func test_key_bosque_from_png_grows_to_min_size() -> void:
	var px := Vector2i(6, 6) * WorldCoords.MACROS_PER_CHUNK
	var bosques := Image.create_empty(px.x, px.y, false, Image.FORMAT_RGBA8)
	var color := Color("#ff00ff")
	for y: int in range(0, 20):
		for x: int in range(0, 40):
			bosques.set_pixel(x, y, color)
	var csv: String = "\n".join([HEADER, "villa_natal,Casa,villa_natal,90,90,,,",
			"sombra,Bosque Sombra,bosque,25,10,#ff00ff,,"]) + "\n"
	var authoring := RegionAuthoring.from_sources({ "bosques": bosques }, csv, _palette)
	assert_true(authoring.is_valid(), "autoría válida: %s" % [authoring.errors])
	for s: int in [1, 2, 3, 4]:
		var plan := _build(s, _region, authoring)
		var id: int = plan.bosque_at(Vector2i(0, 0))
		assert_eq(plan.bosque_at(Vector2i(1, 0)), id, "los dos chunks pintados, en el mismo Bosque")
		assert_eq(plan.bosques.key_index[id], 0, "es el Bosque clave del CSV")
		assert_eq(plan.bosques.nujio_chunk[id], Vector2i(1, 0), "Nujio donde dice el CSV")
		assert_between(plan.bosques.size_of(id), BosqueMap.MIN_SIZE, BosqueMap.MAX_SIZE, "crece hasta 4-16")


# --- Altura y agua -----------------------------------------------------------------------------

func test_painted_height_wins() -> void:
	for y: int in range(0, _plan42.size_macro.y, 7):
		for x: int in range(0, _plan42.size_macro.x, 5):
			var h: int = _authoring.height_at(Vector2i(x, y))
			if h != RegionAuthoring.Height.NONE:
				assert_eq(_plan42.level_at(Vector2i(x, y)), h - RegionAuthoring.Height.LEVEL_0)


func test_unpainted_height_is_procedural_without_lone_cells() -> void:
	var authoring := _blank_authoring(Vector2i(4, 6))
	var plan := _build(42, _region, authoring)
	var levels: Dictionary = {}
	var lone: int = 0
	for y: int in plan.size_macro.y:
		for x: int in plan.size_macro.x:
			var c := Vector2i(x, y)
			var l: int = plan.level_at(c)
			levels[l] = true
			assert_between(l, 0, RegionPlan.LEVEL_MAX, "nivel 0-3")
			var alone: bool = true
			for d: Vector2i in ChunkData.SIDES:
				if plan.level_at(c + d) == l:
					alone = false
			lone += 1 if alone else 0
	assert_eq(lone, 0, "sin celdas sueltas")
	assert_gt(levels.size(), 1, "el relieve tiene varios niveles")
	assert_ne(plan.height_layer(), _build(43, _region, authoring).height_layer(), "la seed cambia el relieve")


func test_procedural_river_only_without_agua_png() -> void:
	var plan := _build(42, _region, _blank_authoring(Vector2i(3, 4)))
	for y: int in plan.size_macro.y:
		var has_river: bool = false
		for x: int in plan.size_macro.x:
			has_river = has_river or plan.water_at(Vector2i(x, y)) != RegionAuthoring.Water.NONE
		assert_true(has_river, "el río de la ADR 0006 cruza la fila %d" % y)
	var dry := _build(42, _region, _blank_authoring(Vector2i(3, 4), [], true))
	assert_false(dry.water_layer().has(RegionAuthoring.Water.RIVER_NARROW) or dry.water_layer().has(RegionAuthoring.Water.RIVER_NAVIGABLE),
			"con agua.png vacía no hay río procedural")


func _river_components(plan_water: Callable, size: Vector2i) -> int:
	var seen: Dictionary = {}
	var count: int = 0
	for y: int in size.y:
		for x: int in size.x:
			var c := Vector2i(x, y)
			if seen.has(c) or not plan_water.call(c):
				continue
			count += 1
			var stack: Array[Vector2i] = [c]
			seen[c] = true
			while not stack.is_empty():
				var cur: Vector2i = stack.pop_back()
				for d: Vector2i in ChunkData.SIDES:
					var n: Vector2i = cur + d
					if n.x >= 0 and n.y >= 0 and n.x < size.x and n.y < size.y and not seen.has(n) and plan_water.call(n):
						seen[n] = true
						stack.append(n)
	return count


func test_painted_water_meanders_without_cutting_rivers() -> void:
	var size: Vector2i = _plan42.size_macro
	var painted: int = _river_components(func(c: Vector2i) -> bool: return _authoring.water_at(c) != RegionAuthoring.Water.NONE, size)
	var planned: int = _river_components(func(c: Vector2i) -> bool: return _plan42.water_at(c) != RegionAuthoring.Water.NONE, size)
	assert_eq(planned, painted, "mismas masas de agua que lo pintado")
	assert_ne(_plan42.water_layer(), _authoring.water, "el meandro mueve el agua")
	var far: int = 0
	for y: int in size.y:
		for x: int in size.x:
			if _plan42.water_at(Vector2i(x, y)) == RegionAuthoring.Water.NONE:
				continue
			var near: bool = false
			for dy: int in range(-2, 3):
				for dx: int in range(-2, 3):
					near = near or _authoring.water_at(Vector2i(x + dx, y + dy)) != RegionAuthoring.Water.NONE
			far += 0 if near else 1
	assert_eq(far, 0, "el agua no se aleja más de 2 celdas de lo pintado")
	for p: Dictionary in _authoring.places:
		assert_eq(_plan42.water_at(p.cell), RegionAuthoring.Water.NONE, "%s fuera del agua" % p.id)


## Fallo heredado de M7: un rótulo de río (`lugar`) o un `manantial` sobre el agua no la borra
## (no deja un hueco seco en el río); un lugar que ocupa tierra (aquí, un hito) sí.
func test_water_labels_keep_their_water() -> void:
	var water := Image.create_empty(60, 80, false, Image.FORMAT_RGBA8)
	var river: Color = RegionAuthoring.palette_color(_palette, "water", "river_narrow")
	for y: int in 80:
		water.set_pixel(10, y, river)
	var images: Dictionary = { "roads": Image.create_empty(60, 80, false, Image.FORMAT_RGBA8), "water": water }
	var csv: String = "\n".join([HEADER, "villa_natal,Casa,villa_natal,40,40,,,",
			"afluente_x,1ro de prueba,lugar,10,20,,,", "manantial_x,Nacimiento,manantial,10,50,,,",
			"hito_x,Hito,hito,10,70,,,"]) + "\n"
	var plan := _build(42, _region, RegionAuthoring.from_sources(images, csv, _palette))
	assert_eq(plan.water_at(Vector2i(10, 20)), RegionAuthoring.Water.RIVER_NARROW, "el rótulo no seca el río")
	assert_eq(plan.water_at(Vector2i(10, 50)), RegionAuthoring.Water.RIVER_NARROW, "el manantial no seca el río")
	assert_eq(plan.water_at(Vector2i(10, 70)), RegionAuthoring.Water.NONE, "un hito no queda en el agua")


func test_painted_roads_over_water_are_bridges() -> void:
	for y: int in _plan42.size_macro.y:
		for x: int in _plan42.size_macro.x:
			var c := Vector2i(x, y)
			if _plan42.road_at(c) == RegionAuthoring.Road.ROAD:
				var w: int = _plan42.water_at(c)
				assert_true(w == RegionAuthoring.Water.NONE or w == RegionAuthoring.Water.FORD, "camino sobre agua honda en %s" % c)


# --- Tiempo ------------------------------------------------------------------------------------

## Aviso, no fallo: las máquinas de CI varían (ADR 0014 §6).
func test_build_time_is_reported() -> void:
	var t0: int = Time.get_ticks_msec()
	var plan := _build(42)
	var ms: int = Time.get_ticks_msec() - t0
	gut.p("Pasada de región (valle_del_sara, seed 42): %d ms (build_usec %d)" % [ms, plan.build_usec])
	if ms > BUDGET_MSEC:
		push_warning("RegionPlan tarda %d ms; el objetivo es ≤ %d ms (ADR 0014 §5)." % [ms, BUDGET_MSEC])
	pass_test("tiempo medido: %d ms" % ms)
