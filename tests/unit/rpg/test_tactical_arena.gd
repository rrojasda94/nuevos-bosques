extends GutTest
## Tamaño del tablero, cupo por bando y colocación del combate táctico (combate-tactico.md, PR T1b;
## #189). Usa el bloque arena de balance.json (los valores de la ficha) y uno fijo de test.

const ARENA: Dictionary = {
	"sample": [14, 10], "large_at": 0.8, "medium_at": 0.6, "tie_margin": 0.02, "min_walkable_ratio": 0.7,
	"cells_per_unit": 8, "quota_min": 1, "quota_max": 6,
	"sizes": {
		"small": { "width": 8, "height": 6, "deploy_columns": 2, "latigazo": [3, 1] },
		"medium": { "width": 10, "height": 8, "deploy_columns": 2, "latigazo": [3, 1] },
		"large": { "width": 14, "height": 10, "deploy_columns": 3, "latigazo": [3, 2] },
	},
	"biome_size": { "pradera": "large", "bosque_denso": "small", "bosque": "medium" },
	"biome_ratio": { "default": 0.65, "pradera": 0.9, "bosque_denso": 0.5 },
}


func _tactical() -> Dictionary:
	return TacticalBattle.config_from_balance(AdventureRules.balance())


# --- Tamaño por proporción ----------------------------------------------------------------------

func test_size_by_walkable_ratio() -> void:
	assert_eq(TacticalArena.size_for_ratio(1.0, ARENA), TacticalArena.LARGE)
	assert_eq(TacticalArena.size_for_ratio(0.8, ARENA), TacticalArena.LARGE, ">= 80%: grande")
	assert_eq(TacticalArena.size_for_ratio(0.79, ARENA), TacticalArena.MEDIUM)
	assert_eq(TacticalArena.size_for_ratio(0.6, ARENA), TacticalArena.MEDIUM, ">= 60%: medio")
	assert_eq(TacticalArena.size_for_ratio(0.59, ARENA), TacticalArena.SMALL)
	assert_eq(TacticalArena.size_for_ratio(0.1, ARENA), TacticalArena.SMALL)


func test_biome_only_breaks_ties() -> void:
	assert_eq(TacticalArena.size_for_ratio(0.79, ARENA, &"pradera"), TacticalArena.LARGE, "cerca del 80%: la pradera prefiere grande")
	assert_eq(TacticalArena.size_for_ratio(0.81, ARENA, &"bosque"), TacticalArena.MEDIUM, "cerca del 80%: el bosque prefiere medio")
	assert_eq(TacticalArena.size_for_ratio(0.61, ARENA, &"bosque_denso"), TacticalArena.SMALL, "cerca del 60%: el denso prefiere pequeño")
	assert_eq(TacticalArena.size_for_ratio(0.7, ARENA, &"pradera"), TacticalArena.MEDIUM, "lejos de un umbral, manda la proporción")
	assert_eq(TacticalArena.size_for_ratio(0.95, ARENA, &"bosque_denso"), TacticalArena.LARGE, "el bioma no salta dos tamaños")
	assert_eq(TacticalArena.size_for_ratio(0.4, ARENA, &"pradera"), TacticalArena.SMALL)


func test_sample_ratio_reads_a_14x10_window_inside_the_chunk() -> void:
	# Mitad izquierda transitable (x < 32) en un "chunk" de 64 x 64.
	var half := func(c: Vector2i) -> bool: return c.x < 32
	var bounds := Rect2i(0, 0, 64, 64)
	assert_eq(TacticalArena.sample_rect(Vector2i(10, 10), Vector2i(14, 10), bounds), Rect2i(3, 5, 14, 10))
	assert_eq(TacticalArena.sample_rect(Vector2i(0, 63), Vector2i(14, 10), bounds), Rect2i(0, 54, 14, 10),
		"en la esquina, el recorte se desplaza dentro del chunk")
	assert_almost_eq(TacticalArena.sample_ratio(half, Vector2i(10, 10), Vector2i(14, 10), bounds), 1.0, 0.001)
	assert_almost_eq(TacticalArena.sample_ratio(half, Vector2i(32, 10), Vector2i(14, 10), bounds), 0.5, 0.001)
	assert_almost_eq(TacticalArena.sample_ratio(half, Vector2i(60, 10), Vector2i(14, 10), bounds), 0.0, 0.001)


func test_plan_without_sample_uses_the_biome() -> void:
	var t: Dictionary = { "arena": ARENA }
	assert_eq(TacticalArena.plan(t, -1.0, &"pradera").size, TacticalArena.LARGE)
	assert_eq(TacticalArena.plan(t, -1.0, &"bosque_denso").size, TacticalArena.SMALL)
	assert_eq(TacticalArena.plan(t, -1.0, &"").size, TacticalArena.MEDIUM, "default 0.65")


# --- Cupo ---------------------------------------------------------------------------------------

func test_quota_formula_matches_the_sheet_examples() -> void:
	assert_eq(TacticalArena.quota(floori(48 * 0.7), ARENA), 2, "8 x 6 al 70% -> 2")
	assert_eq(TacticalArena.quota(48, ARENA), 3, "8 x 6 al 100% -> 3")
	assert_eq(TacticalArena.quota(floori(80 * 0.8), ARENA), 4, "10 x 8 al 80% -> 4")
	assert_eq(TacticalArena.quota(floori(140 * 0.9), ARENA), 6, "14 x 10 al 90% -> 6 (tope)")
	assert_eq(TacticalArena.quota(5, ARENA), 1, "mínimo 1")
	assert_eq(TacticalArena.quota(10000, ARENA), 6, "máximo 6")


func test_estimated_walkable_on_a_flat_board() -> void:
	assert_eq(TacticalArena.estimated_walkable(48, 0.7, ARENA), 33)
	assert_eq(TacticalArena.estimated_walkable(48, 0.3, ARENA), 33, "el recorte se elige con al menos un 70%")
	assert_eq(TacticalArena.estimated_walkable(80, 0.8, ARENA), 64)
	assert_eq(TacticalArena.estimated_walkable(140, 0.9, ARENA), 126)


func test_plan_gives_size_quota_and_columns() -> void:
	var t: Dictionary = { "arena": ARENA }
	var small: Dictionary = TacticalArena.plan(t, 0.5)
	assert_eq([small.width, small.height, small.deploy_columns, small.quota], [8, 6, 2, 2])
	var medium: Dictionary = TacticalArena.plan(t, 0.79)
	assert_eq([medium.width, medium.height, medium.deploy_columns, medium.quota], [10, 8, 2, 3])
	var large: Dictionary = TacticalArena.plan(t, 0.9)
	assert_eq([large.width, large.height, large.deploy_columns, large.quota], [14, 10, 3, 6])


func test_quota_for_a_board_with_obstacles() -> void:
	var b := TacticalBoard.new(8, 6)
	assert_eq(TacticalArena.quota_for_board(b, ARENA), 3)
	for x: int in 8:
		b.set_cell(Vector2i(x, 0), 0, true)
		b.set_cell(Vector2i(x, 1), 0, true)
	assert_eq(TacticalArena.quota_for_board(b, ARENA), 2, "32 transitables")


func test_apply_plan_sets_the_board_and_same_quota_both_sides() -> void:
	var cfg: Dictionary = TacticalArena.apply_plan(_tactical(), TacticalArena.plan(_tactical(), 0.9))
	assert_eq(cfg.board.width, 14)
	assert_eq(cfg.board.height, 10)
	assert_eq(cfg.board.deploy_columns, 3)
	assert_eq(cfg.board.max_per_side, 6)
	var fighters: Array = []
	for k: int in 8:
		fighters.append({ "id": StringName("p%d" % k), "side": TacticalBattle.SIDE_PLAYER, "agi": 5 })
		fighters.append({ "id": StringName("e%d" % k), "side": TacticalBattle.SIDE_ENEMY, "agi": 5 })
	var b := TacticalBattle.new(cfg, TacticalBoard.from_config(cfg.board), fighters, 1)
	assert_eq(b.on_board(TacticalBattle.SIDE_PLAYER), 6)
	assert_eq(b.on_board(TacticalBattle.SIDE_ENEMY), 6, "el mismo cupo para los dos bandos")


# --- Colocación ---------------------------------------------------------------------------------

func test_large_board_deploys_in_three_columns() -> void:
	var cfg: Dictionary = TacticalArena.apply_plan(_tactical(), TacticalArena.plan(_tactical(), 1.0))
	assert_eq(cfg.board.deploy_columns, 3)
	var fighters: Array = []
	for k: int in 6:
		fighters.append({ "id": StringName("p%d" % k), "side": TacticalBattle.SIDE_PLAYER, "agi": 5 })
		fighters.append({ "id": StringName("e%d" % k), "side": TacticalBattle.SIDE_ENEMY, "agi": 5 })
	var board := TacticalBoard.from_config(cfg.board)
	# Solo las filas 4 y 5 libres: 2 casillas por columna, así que 6 combatientes llenan 3 columnas.
	for y: int in 10:
		for x: int in 14:
			if y != 4 and y != 5:
				board.set_cell(Vector2i(x, y), 0, true)
	var b := TacticalBattle.new(cfg, board, fighters, 1)
	var player_cols: Array = []
	var enemy_cols: Array = []
	for u: Dictionary in b.units:
		var cols: Array = player_cols if u.side == TacticalBattle.SIDE_PLAYER else enemy_cols
		if not cols.has(u.cell.x):
			cols.append(u.cell.x)
	player_cols.sort()
	enemy_cols.sort()
	assert_eq(player_cols, [0, 1, 2], "el jugador en sus 3 columnas")
	assert_eq(enemy_cols, [11, 12, 13], "los enemigos en sus 3 columnas")
	assert_eq(b.units[0].cell.x, 2, "primero la columna interior (la tercera)")
	var gap: int = 11 - 2 - 1
	assert_eq(gap, 8, "quedan 8 columnas entre los bandos")


func test_small_and_medium_deploy_in_two_columns() -> void:
	for ratio: float in [0.5, 0.7]:
		var plan: Dictionary = TacticalArena.plan({ "arena": ARENA }, ratio)
		assert_eq(plan.deploy_columns, 2)


# --- Latigazo (dato para T6) --------------------------------------------------------------------

func test_latigazo_area_by_size_in_balance() -> void:
	var cfg: Dictionary = TacticalArena.arena_cfg(_tactical())
	assert_eq(TacticalArena.latigazo_area(TacticalArena.SMALL, cfg), Vector2i(3, 1))
	assert_eq(TacticalArena.latigazo_area(TacticalArena.MEDIUM, cfg), Vector2i(3, 1))
	assert_eq(TacticalArena.latigazo_area(TacticalArena.LARGE, cfg), Vector2i(3, 2))


func test_balance_arena_block_matches_the_sheet() -> void:
	var cfg: Dictionary = TacticalArena.arena_cfg(_tactical())
	assert_eq(int(cfg.cells_per_unit), 8)
	assert_eq(int(cfg.quota_min), 1)
	assert_eq(int(cfg.quota_max), 6)
	assert_eq(TacticalArena.sample_size(cfg), Vector2i(14, 10))
	assert_eq(int(_tactical().ct.reinforce_ct), 50)


# --- Recorte del Mundo 2.0 (WorldQuery.Area) ----------------------------------------------------

func test_area_ratio_counts_loaded_and_unblocked_cells() -> void:
	var area := WorldQuery.Area.new()
	area.size = Vector2i(4, 2)
	area.loaded.resize(8)
	area.blocked.resize(8)
	area.loaded.fill(1)
	area.blocked.fill(0)
	assert_almost_eq(TacticalArena.area_ratio(area), 1.0, 0.001)
	area.blocked[0] = 1
	area.blocked[1] = 1
	area.loaded[7] = 0
	assert_almost_eq(TacticalArena.area_ratio(area), 5.0 / 8.0, 0.001, "bloqueadas y sin cargar no cuentan")


func test_world_ratio_without_chunks_is_closed() -> void:
	var none := func(_c: Vector2i) -> WorldChunk: return null
	assert_almost_eq(TacticalArena.world_ratio(none, Vector2i(100, 100), Vector2i(14, 10)), 0.0, 0.001)
	assert_eq(TacticalArena.size_for_ratio(0.0, ARENA), TacticalArena.SMALL)


func test_crossing_prefers_the_world_query_when_the_world_gives_it() -> void:
	var crossing: Node = load("res://scripts/rpg/crossing.gd").new()
	crossing.world_get_chunk = func(_c: Vector2i) -> WorldChunk: return null
	crossing.world_player_cell = func() -> Vector2i: return Vector2i(40, 40)
	assert_almost_eq(float(crossing.encounter_ratio()), 0.0, 0.001, "Mundo 2.0: WorldQuery.rect")
	crossing.walkable_sampler = func() -> float: return 0.9
	assert_almost_eq(float(crossing.encounter_ratio()), 0.9, 0.001, "la fuente inyectada manda")
	crossing.free()
