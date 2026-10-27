extends GutTest
## Tablero táctico desde el relieve del Mundo 2.0 (TacticalRelief, combate-tactico.md "Alturas en el
## tablero"; PR T7a): compresión de riscos, desnivel normalizado, elección del recorte, recurso al
## llano, mapeo de escaleras, rampas, agua, vados y obstáculos, determinismo y una prueba de humo con
## chunks reales de 20 seeds.

const CFG: Dictionary = {
	"radius": 0, "step": 2, "max_span": 2, "min_walkable": 0.7, "relaxed_min_walkable": 0.5,
	"path_jump": 1, "path_drop": 2, "weight_walkable": 1.0, "weight_span": 0.1, "weight_distance": 0.5,
	"max_checks": 64,
}
const SMOKE_SEEDS: Array[int] = [42, 7, 1234, 1, 2, 3, 5, 8, 13, 21, 34, 55, 77, 89, 99, 144, 233, 377, 610, 987]
const REGION: StringName = &"valle_del_sara"


static func _cfg(over: Dictionary = {}) -> Dictionary:
	var c: Dictionary = CFG.duplicate()
	for k: Variant in over:
		c[k] = over[k]
	return c


## Area a mano: `levels`, una cadena por fila con el nivel (0–3) de cada casilla; `kinds`, mismas
## dimensiones (o vacío = todo suelo): . suelo, F cara, E borde, S escalera (en una cara), R rampa
## (en un borde), W agua honda, V vado, B puente, P cascada, T árbol, K roca, H árbol hueco
## (refugio), X chunk sin cargar.
static func _area(levels: Array, kinds: Array = [], origin: Vector2i = Vector2i.ZERO) -> WorldQuery.Area:
	var a := WorldQuery.Area.new()
	var h: int = levels.size()
	var w: int = (levels[0] as String).length()
	a.origin = origin
	a.size = Vector2i(w, h)
	var n: int = w * h
	a.loaded.resize(n)
	a.level.resize(n)
	a.blocked.resize(n)
	a.ground.resize(n)
	a.cliff.resize(n)
	a.crossing.resize(n)
	a.water.resize(n)
	a.object_kind.resize(n)
	a.loaded.fill(1)
	a.object_kind.fill(WorldChunk.NO_OBJECT)
	for y: int in h:
		for x: int in w:
			var i: int = y * w + x
			a.level[i] = int((levels[y] as String)[x])
			var k: String = "." if kinds.is_empty() else (kinds[y] as String)[x]
			match k:
				"F":
					a.cliff[i] = WorldChunk.Cliff.FACE
				"E":
					a.cliff[i] = WorldChunk.Cliff.EDGE
				"S":
					a.cliff[i] = WorldChunk.Cliff.STAIRS
					a.crossing[i] = WorldQuery.Crossing.STAIRS
				"R":
					a.cliff[i] = WorldChunk.Cliff.RAMP
					a.crossing[i] = WorldQuery.Crossing.RAMP
				"W":
					a.ground[i] = WorldChunk.Ground.RIVER_NARROW
					a.water[i] = WorldQuery.Water.DEEP
				"V":
					a.ground[i] = WorldChunk.Ground.FORD
					a.water[i] = WorldQuery.Water.FORD
				"B":
					a.ground[i] = WorldChunk.Ground.BRIDGE
					a.water[i] = WorldQuery.Water.BRIDGE
				"P":
					a.cliff[i] = WorldChunk.Cliff.WATERFALL
				"T":
					a.object_kind[i] = WorldChunk.ObjectKind.TREE
				"K":
					a.object_kind[i] = WorldChunk.ObjectKind.ROCK
				"H":
					a.object_kind[i] = WorldChunk.ObjectKind.REFUGE_TREE
				"X":
					a.loaded[i] = 0
			var g: int = a.ground[i]
			a.blocked[i] = 1 if (a.loaded[i] == 0 or WorldChunk.is_ground_blocking(g)
				or WorldChunk.is_cliff_blocking(a.cliff[i])
				or (a.object_kind[i] >= 0 and WorldChunk.is_object_blocking(a.object_kind[i]))) else 0
	return a


static func _rows(text: String, count: int) -> Array:
	var out: Array = []
	for k: int in count:
		out.append(text)
	return out


static func _whole(area: WorldQuery.Area) -> Rect2i:
	return Rect2i(area.origin, area.size)


# --- Compresión de riscos -----------------------------------------------------------------------

func test_cliff_faces_become_a_jump_between_neighbours() -> void:
	# Meseta de nivel 2 arriba; sus 4 filas de cara (2 niveles de caída) están en el nivel 0 de abajo.
	var area := _area(
		["2222", "2222", "0000", "0000", "0000", "0000", "0000", "0000"],
		["....", "....", "FFFF", "FFFF", "FFFF", "FFFF", "....", "...."])
	var grid := TacticalRelief.compress(area)
	var board := TacticalRelief.board_for(grid, _whole(area))
	assert_eq(board.height, 8, "no se quitan filas")
	for y: int in range(2, 6):
		assert_true(board.is_walkable(Vector2i(1, y)), "la cara se pisa (fila %d)" % y)
		assert_eq(board.level_at(Vector2i(1, y)), 0, "la cara toma el nivel de abajo")
	assert_eq(board.level_at(Vector2i(1, 1)), 2)
	assert_false(board.can_step(Vector2i(1, 2), Vector2i(1, 1), 1, 2), "subir 2 con Salto 1, no")
	assert_true(board.can_step(Vector2i(1, 2), Vector2i(1, 1), 2, 3), "con Salto 2, sí")
	assert_true(board.can_step(Vector2i(1, 1), Vector2i(1, 2), 1, 2), "bajar 2 con bajada 2")
	assert_true(board.can_step(Vector2i(1, 2), Vector2i(1, 3), 1, 2), "entre filas de cara, llano")


func test_edges_keep_the_upper_level() -> void:
	# Meseta de nivel 1 con borde norte, este y oeste; alrededor, nivel 0.
	var area := _area(
		["000000", "011110", "011110", "011110", "000000"],
		["......", ".EEEE.", ".E..E.", ".E..E.", "......"])
	var board := TacticalRelief.board_for(TacticalRelief.compress(area), _whole(area))
	assert_true(board.is_walkable(Vector2i(1, 1)))
	assert_eq(board.level_at(Vector2i(1, 2)), 1, "el borde es de la meseta")
	assert_eq(board.level_at(Vector2i(0, 2)), 0)
	assert_true(board.can_step(Vector2i(0, 2), Vector2i(1, 2), 1, 2), "salto de 1 entre vecinas")


func test_peaks_and_waterfalls_still_block() -> void:
	var levels: Array = _rows("000033330000", 12)
	var kinds: Array = []
	for y: int in 12:
		kinds.append("....EEEE...." if y >= 4 and y < 8 else "............")
	# Meseta normal de nivel 3 en la celda gruesa (8..11, 0..3): borde solo en la fila 0 y los lados.
	for y: int in 4:
		levels[y] = "000033333333"
		kinds[y] = "....EEEEEEEE" if y == 0 else "....E..EE..E"
	levels[0] = "000033333333"
	kinds[10] = ".P.........."
	var area := _area(levels, kinds)
	var grid := TacticalRelief.compress(area)
	assert_eq(grid.walk[grid.index(Vector2i(5, 5))], 0, "cumbre: sigue bloqueando")
	assert_eq(grid.walk[grid.index(Vector2i(4, 7))], 0, "toda la celda gruesa de la cumbre")
	assert_eq(grid.walk[grid.index(Vector2i(8, 0))], 1, "el borde de una meseta normal se pisa")
	assert_eq(grid.walk[grid.index(Vector2i(11, 2))], 1)
	assert_eq(grid.water[grid.index(Vector2i(1, 10))], 1, "la cascada es agua")
	assert_eq(grid.walk[grid.index(Vector2i(1, 10))], 0)


func test_missing_chunks_block() -> void:
	var area := _area(["000", "000"], ["X..", "..."])
	var grid := TacticalRelief.compress(area)
	assert_eq(grid.walk[0], 0)
	assert_eq(grid.walk[1], 1)


# --- Desnivel -----------------------------------------------------------------------------------

func test_levels_are_normalized_to_the_lowest_walkable() -> void:
	var area := _area(["33333333", "33333333", "22222222", "22222222", "11111111", "11111111"])
	var board := TacticalRelief.board_for(TacticalRelief.compress(area), _whole(area))
	assert_eq(board.level_at(Vector2i(0, 5)), 0, "el nivel 1 pasa a 0")
	assert_eq(board.level_at(Vector2i(0, 0)), 2, "el nivel 3 pasa a 2")
	assert_eq(board.level_span(), 2)
	# Un árbol en un nivel más bajo no cuenta para el mínimo.
	var area2 := _area(["0111", "1111"], ["T...", "...."])
	var board2 := TacticalRelief.board_for(TacticalRelief.compress(area2), _whole(area2))
	assert_eq(board2.level_at(Vector2i(1, 0)), 0)
	assert_eq(board2.level_at(Vector2i(0, 0)), 0, "por debajo del mínimo, 0")


func test_chosen_board_never_spans_more_than_two() -> void:
	# Mitad oeste nivel 0 y mitad este nivel 3: el recorte centrado (desnivel 3) no vale.
	var levels: Array = _rows("0".repeat(20) + "3".repeat(20), 20)
	var area := _area(levels)
	var grid := TacticalRelief.compress(area)
	var pick: Dictionary = TacticalRelief.board_from_grid(grid, Vector2i(20, 10), Vector2i(8, 6), 2,
		_cfg({ "radius": 8 }))
	assert_eq(pick.mode, TacticalRelief.RELIEF)
	assert_eq(pick.span, 0)
	assert_eq((pick.board as TacticalBoard).level_span(), 0)
	assert_eq((pick.rect as Rect2i).position, Vector2i(12, 7), "empate: el más cercano y el de la izquierda")


# --- Elección del recorte -----------------------------------------------------------------------

func test_picks_a_valid_rect_away_from_a_lake() -> void:
	# Lago en x < 30; el encuentro está en el lago.
	var kinds: Array = _rows("W".repeat(30) + ".".repeat(34), 40)
	var area := _area(_rows("0".repeat(64), 40), kinds)
	var grid := TacticalRelief.compress(area)
	var cfg := _cfg({ "radius": 24 })
	var pick: Dictionary = TacticalRelief.board_from_grid(grid, Vector2i(16, 20), Vector2i(8, 6), 2, cfg)
	assert_eq(pick.mode, TacticalRelief.RELIEF)
	assert_eq((pick.rect as Rect2i).position, Vector2i(30, 17), "el recorte claro más cercano")
	var board: TacticalBoard = pick.board
	assert_gte(board.walkable_ratio(), 0.7)
	assert_true(TacticalRelief.sides_connected(board, 2, cfg))


func test_rejects_rects_whose_sides_are_cut_by_a_river() -> void:
	# Río de norte a sur en x = 24 sin vado; el encuentro está junto a él.
	var kinds: Array = _rows(".".repeat(24) + "W" + ".".repeat(23), 20)
	var area := _area(_rows("0".repeat(48), 20), kinds)
	var grid := TacticalRelief.compress(area)
	var cfg := _cfg({ "radius": 0 })
	var centered: Dictionary = TacticalRelief.choose(grid, Vector2i(24, 10), Vector2i(8, 6), 2, cfg)
	assert_eq(centered.mode, TacticalRelief.FLAT, "sin moverse, el río corta los bandos: llano")
	cfg.radius = 8
	var pick: Dictionary = TacticalRelief.board_from_grid(grid, Vector2i(24, 10), Vector2i(8, 6), 2, cfg)
	assert_eq(pick.mode, TacticalRelief.RELIEF)
	assert_true(TacticalRelief.sides_connected(pick.board, 2, cfg))
	# Con un vado, el recorte centrado vale.
	kinds[10] = ".".repeat(24) + "V" + ".".repeat(23)
	var forded := TacticalRelief.compress(_area(_rows("0".repeat(48), 20), kinds))
	assert_eq(TacticalRelief.choose(forded, Vector2i(24, 10), Vector2i(8, 6), 2, _cfg()).mode, TacticalRelief.RELIEF)


func test_relaxed_when_nothing_reaches_seventy_percent() -> void:
	# Una fila de árboles de cada tres en columnas alternas: ~60% transitable, pero conexo.
	var kinds: Array = []
	for y: int in 18:
		kinds.append("T.T.T.T.T.T.T.T.T.T." if y % 3 == 0 else "....................")
	for y: int in 18:
		if y % 3 == 1:
			kinds[y] = "T.T.T.T.T.T.T.T.T.T."
	var area := _area(_rows("0".repeat(20), 18), kinds)
	var grid := TacticalRelief.compress(area)
	var pick: Dictionary = TacticalRelief.choose(grid, Vector2i(10, 9), Vector2i(8, 6), 2, _cfg({ "radius": 4 }))
	assert_lt(float(pick.ratio), 0.7)
	assert_eq(pick.mode, TacticalRelief.RELAXED, "el mejor disponible con camino")


func test_flat_when_there_is_no_valid_rect() -> void:
	var area := _area(_rows("0".repeat(30), 20), _rows("W".repeat(30), 20))
	var grid := TacticalRelief.compress(area)
	var pick: Dictionary = TacticalRelief.board_from_grid(grid, Vector2i(15, 10), Vector2i(10, 8), 2,
		_cfg({ "radius": 8 }), { "ford_cost": 2 })
	assert_eq(pick.mode, TacticalRelief.FLAT)
	var board: TacticalBoard = pick.board
	assert_eq(Vector2i(board.width, board.height), Vector2i(10, 8))
	assert_almost_eq(board.walkable_ratio(), 1.0, 0.001, "llano y todo transitable")
	assert_eq(board.level_span(), 0)
	assert_eq(board.ford_cost, 2)


func test_world_without_chunks_falls_back_to_flat() -> void:
	var none := func(_c: Vector2i) -> WorldChunk: return null
	var out: Dictionary = TacticalRelief.arena_config(AdventureRules.balance(), none, Vector2i(100, 100))
	assert_eq(out.mode, TacticalRelief.FLAT)
	assert_not_null(out.board)
	assert_eq(str((out.cfg.arena_plan as Dictionary).relief), String(TacticalRelief.FLAT))


func test_crossing_uses_the_relief_board_in_world_2() -> void:
	var crossing: Node = load("res://scripts/rpg/crossing.gd").new()
	crossing.world_get_chunk = func(_c: Vector2i) -> WorldChunk: return null
	crossing.world_player_cell = func() -> Vector2i: return Vector2i(40, 40)
	var arena: Dictionary = crossing.encounter_arena(AdventureRules.balance())
	assert_not_null(arena.board, "Mundo 2.0: tablero de TacticalRelief")
	assert_true((arena.cfg.arena_plan as Dictionary).has("relief"))
	crossing.walkable_sampler = func() -> float: return 0.9
	arena = crossing.encounter_arena(AdventureRules.balance())
	assert_null(arena.board, "con la fuente inyectada, llano como antes")
	crossing.free()


# --- Mapeo --------------------------------------------------------------------------------------

func test_maps_stairs_ramps_water_fords_and_objects() -> void:
	var area := _area(
		["11111111", "00000000", "00000000", "00000000", "00000000", "00000000"],
		["..R.....", "SS......", "WVB.....", "TKH.....", "........", "........"])
	var board := TacticalRelief.board_for(TacticalRelief.compress(area), _whole(area))
	assert_true(board.is_stair(Vector2i(0, 1)), "escalera")
	assert_true(board.is_stair(Vector2i(2, 0)), "rampa")
	assert_true(board.can_step(Vector2i(0, 1), Vector2i(0, 0), 0, 0), "la escalera no gasta Salto")
	assert_true(board.is_water(Vector2i(0, 2)))
	assert_false(board.is_walkable(Vector2i(0, 2)), "agua honda")
	assert_true(board.is_ford(Vector2i(1, 2)))
	assert_true(board.is_walkable(Vector2i(1, 2)), "el vado se pisa")
	assert_false(board.is_water(Vector2i(2, 2)), "el puente es suelo")
	assert_true(board.is_walkable(Vector2i(2, 2)))
	assert_eq(board.object_at(Vector2i(0, 3)), &"tree")
	assert_true(board.is_obstacle(Vector2i(0, 3)))
	assert_eq(board.object_at(Vector2i(1, 3)), &"rock")
	assert_true(board.is_obstacle(Vector2i(1, 3)))
	assert_eq(board.object_at(Vector2i(2, 3)), &"refuge_tree")
	assert_false(board.is_obstacle(Vector2i(2, 3)), "el árbol hueco no bloquea en el mundo")
	assert_true(board.is_walkable(Vector2i(2, 3)))


func test_object_names_and_walkable_objects() -> void:
	assert_eq(TacticalRelief.object_name(WorldChunk.ObjectKind.TREE_BIG), &"tree_big")
	assert_eq(TacticalRelief.object_name(-1), &"")
	var free: Array[StringName] = TacticalRelief.walkable_objects()
	assert_true(free.has(&"refuge_tree"))
	assert_true(free.has(&"cave"))
	assert_false(free.has(&"tree"))
	assert_false(free.has(&"rock"))


# --- Determinismo y mundo real ------------------------------------------------------------------

func test_is_deterministic() -> void:
	var levels: Array = []
	var kinds: Array = []
	for y: int in 30:
		var l: String = ""
		var k: String = ""
		for x: int in 40:
			l += str((x / 10 + y / 12) % 3)
			k += "T" if (x * 7 + y * 13) % 11 == 0 else "."
		levels.append(l)
		kinds.append(k)
	var cfg := _cfg({ "radius": 10 })
	var a: Dictionary = TacticalRelief.choose(TacticalRelief.compress(_area(levels, kinds)), Vector2i(20, 15), Vector2i(10, 8), 2, cfg)
	var b: Dictionary = TacticalRelief.choose(TacticalRelief.compress(_area(levels, kinds)), Vector2i(20, 15), Vector2i(10, 8), 2, cfg)
	assert_eq(a.rect, b.rect)
	assert_eq(a.mode, b.mode)
	var grid := TacticalRelief.compress(_area(levels, kinds))
	assert_eq(TacticalRelief.cells_for(grid, a.rect), TacticalRelief.cells_for(grid, b.rect))


func test_real_chunks_give_valid_boards() -> void:
	var balance: Dictionary = AdventureRules.balance()
	var relief: Dictionary = TacticalRelief.relief_cfg(TacticalArena.arena_cfg(TacticalBattle.config_from_balance(balance)))
	var modes: Dictionary = {}
	for seed_value: int in SMOKE_SEEDS:
		var plan: RegionPlan = RegionPlan.for_region(seed_value, REGION)
		var chunks: Dictionary = {}
		var get_chunk := func(c: Vector2i) -> WorldChunk:
			if c.x < 0 or c.y < 0 or c.x >= plan.size_chunks.x or c.y >= plan.size_chunks.y:
				return null
			if not chunks.has(c):
				chunks[c] = ChunkBuilder.build(plan, c)
			return chunks[c]
		# Las filas del norte, las de más relieve.
		var coord := Vector2i(seed_value % plan.size_chunks.x, (seed_value / plan.size_chunks.x) % 3)
		var chunk: WorldChunk = get_chunk.call(coord)
		var encounter: Vector2i = coord * WorldCoords.CHUNK + chunk.hub
		var out: Dictionary = TacticalRelief.arena_config(balance, get_chunk, encounter, &"bosque")
		var board: TacticalBoard = out.board
		var cols: int = int((out.cfg.board as Dictionary).deploy_columns)
		modes[out.mode] = int(modes.get(out.mode, 0)) + 1
		assert_ne(out.mode, TacticalRelief.FLAT, "seed %d: hay recorte con relieve" % seed_value)
		assert_lte(board.level_span(), 2, "seed %d: desnivel" % seed_value)
		assert_true(TacticalRelief.sides_connected(board, cols, relief), "seed %d: camino entre bandos" % seed_value)
		var rect: Rect2i = out.rect
		assert_lte(maxi(absi(rect.get_center().x - encounter.x), absi(rect.get_center().y - encounter.y)),
			int(relief.radius) + 8, "seed %d: a 1 chunk como mucho" % seed_value)
		assert_eq(int((out.cfg.board as Dictionary).max_per_side), TacticalArena.quota_for_board(board, TacticalArena.arena_cfg(out.cfg)))
		if seed_value == SMOKE_SEEDS[0]:
			var t0: int = Time.get_ticks_usec()
			var again: Dictionary = TacticalRelief.arena_config(balance, get_chunk, encounter, &"bosque")
			gut.p("arena_config con los chunks ya hechos: %d ms" % ((Time.get_ticks_usec() - t0) / 1000))
			assert_eq(again.rect, rect, "determinista con chunks reales")
	gut.p("modos: %s" % modes)
