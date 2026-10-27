extends GutTest
## P6 (ajustes-playtest-0.5.md §1b, ADR 0017): sprint de los Únicos (MonsterSteering.sprint_tick,
## speed_px) y calma separada tras huir (flee_cooldown) o retroceder (retreat_cooldown). La
## persecución usa el OverworldMonster del Mundo 2.0 de verdad (GridMover, think_world) contra un
## jugador que corre en línea recta por un campo abierto.

const S := MonsterSteering.State
const DT: float = 1.0 / 60.0
## Campo abierto enorme: el puesto y max_outside no cortan la persecución.
const HOME := Rect2i(-1000, -1000, 4000, 4000)


func _cfg(id: StringName) -> Dictionary:
	return AdventureRules.monster_config(id)


func _tex() -> Texture2D:
	return ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))


## Caja de los pies (MovementConfig.hitbox, centrada en x y apoyada en los pies) con los pies en `pos`.
func _box(pos: Vector2) -> Rect2:
	var hb: Vector2 = MovementConfig.hitbox()
	return Rect2(pos.x - hb.x * 0.5, pos.y - hb.y, hb.x, hb.y)


## Persecución en línea recta: el monstruo `id` empieza persiguiendo a `gap_cells` casillas por
## detrás de un jugador que corre hacia la derecha a `player_speed`. Devuelve
## { "caught": segundos hasta el encuentro (-1 si no), "trace": posiciones del monstruo,
##   "max_speed": velocidad máxima del monstruo }.
func _chase(id: StringName, gap_cells: int, player_speed: float, seconds: float = 4.0) -> Dictionary:
	var cfg: Dictionary = _cfg(id)
	var m: OverworldMonster = autofree(OverworldMonster.new())
	var start := Vector2i(0, 0)
	m.setup_world(id, "prueba", -1, start, HOME, Vector2i.DOWN, cfg, _tex())
	m.state = S.CHASE
	var player_pos: Vector2 = WorldCoords.world_cell_to_world_pos(start + Vector2i(gap_cells, 0))
	var no_block: Callable = func(_c: Vector2i) -> bool: return false
	var trace: Array[Vector2] = []
	var max_speed: float = 0.0
	var t: float = 0.0
	while t < seconds:
		player_pos.x += player_speed * DT
		var pcell: Vector2i = WorldCoords.world_pos_to_world_cell(player_pos)
		var walkable: Callable = func(c: Vector2i) -> bool: return c != pcell
		m.think_world(DT, player_pos, pcell, true, walkable, no_block)
		max_speed = maxf(max_speed, m.speed())
		trace.append(m.world_pos())
		t += DT
		if WorldEncounters.engages(m.get_rect(), _box(player_pos), true, cfg):
			return { "caught": t, "trace": trace, "max_speed": max_speed }
	return { "caught": -1.0, "trace": trace, "max_speed": max_speed }


# --- Datos ----------------------------------------------------------------------------------------

func test_sprint_data_matches_the_design_table() -> void:
	for id: StringName in [&"ofomni", &"ofomni_descarriado"]:
		var c: Dictionary = _cfg(id)
		assert_eq(int(c.sprint_trigger), 4, id)
		assert_almost_eq(float(c.sprint_px), 240.0, 0.001, id)
		assert_almost_eq(float(c.sprint_seconds), 1.5, 0.001, id)
		assert_almost_eq(float(c.sprint_cooldown), 4.0, 0.001, id)
	var a: Dictionary = _cfg(&"aledra")
	assert_eq([int(a.sprint_trigger), float(a.sprint_px), float(a.sprint_seconds), float(a.sprint_cooldown)],
		[3, 250.0, 1.0, 5.0])
	var r: Dictionary = _cfg(&"reparep")
	assert_eq([int(r.sprint_trigger), float(r.sprint_px), float(r.sprint_seconds), float(r.sprint_cooldown)],
		[3, 220.0, 1.0, 4.0])
	for id: StringName in [&"botarramas", &"ofomni_descarriado", &"ofomni", &"reparep", &"aledra"]:
		assert_almost_eq(MonsterSteering.calm_seconds(_cfg(id), true), 1.5, 0.001, "huir: %s" % id)
		assert_almost_eq(MonsterSteering.calm_seconds(_cfg(id), false), 3.0, 0.001, "retroceder: %s" % id)


# --- Sprint puro ----------------------------------------------------------------------------------

func test_sprint_starts_lasts_and_rests() -> void:
	var cfg: Dictionary = _cfg(&"ofomni")
	var s := Vector2.ZERO
	s = MonsterSteering.sprint_tick(s, DT, true, 5, cfg)
	assert_eq(s, Vector2.ZERO, "a 5 casillas no esprinta")
	s = MonsterSteering.sprint_tick(s, DT, false, 2, cfg)
	assert_eq(s, Vector2.ZERO, "sin perseguir no esprinta")
	s = MonsterSteering.sprint_tick(s, DT, true, 4, cfg)
	assert_almost_eq(s.x, 1.5, 0.0001, "a 4 casillas arranca")
	assert_almost_eq(MonsterSteering.speed_px(cfg, S.CHASE, s.x > 0.0), 240.0, 0.001)
	var t: float = 0.0
	while s.x > 0.0:
		s = MonsterSteering.sprint_tick(s, 0.1, true, 1, cfg)
		t += 0.1
	assert_almost_eq(t, 1.5, 0.11, "dura sprint_seconds")
	assert_almost_eq(s.y, 4.0, 0.0001, "y descansa sprint_cooldown")
	assert_almost_eq(MonsterSteering.speed_px(cfg, S.CHASE, false), 80.0, 0.001, "vuelve a speed_px")
	t = 0.0
	while s.x <= 0.0:
		s = MonsterSteering.sprint_tick(s, 0.1, true, 1, cfg)
		t += 0.1
	assert_almost_eq(t, 4.1, 0.11, "tras el descanso vuelve a esprintar")


func test_losing_the_chase_ends_the_sprint_and_rests() -> void:
	var cfg: Dictionary = _cfg(&"aledra")
	var s: Vector2 = MonsterSteering.sprint_tick(Vector2.ZERO, DT, true, 3, cfg)
	assert_almost_eq(s.x, 1.0, 0.0001)
	s = MonsterSteering.sprint_tick(s, DT, false, 3, cfg)
	assert_eq(s, Vector2(0.0, 5.0))


func test_botarramas_never_sprints() -> void:
	var cfg: Dictionary = _cfg(&"botarramas")
	assert_false(MonsterSteering.can_sprint(cfg))
	var s := Vector2.ZERO
	for i: int in 300:
		s = MonsterSteering.sprint_tick(s, DT, true, 1, cfg)
		assert_eq(s, Vector2.ZERO)
	assert_almost_eq(MonsterSteering.speed_px(cfg, S.CHASE, true), float(cfg.speed_px), 0.001)
	assert_lt(_chase(&"botarramas", 3, MovementConfig.run_speed()).max_speed, MovementConfig.walk_speed(),
		"renquea: ni siquiera alcanza al que anda")


func test_sprint_only_applies_while_chasing() -> void:
	var cfg: Dictionary = _cfg(&"ofomni")
	assert_almost_eq(MonsterSteering.speed_px(cfg, S.RETURN, true), 80.0, 0.001)
	assert_almost_eq(MonsterSteering.speed_px(cfg, S.IDLE, true), float(cfg.idle_speed_px), 0.001)


# --- Persecución en el Mundo 2.0 ------------------------------------------------------------------

func test_sprinting_ofomni_catches_a_running_player_at_4_cells() -> void:
	var run: float = MovementConfig.run_speed()
	assert_almost_eq(run, 200.0, 0.001)
	var r: Dictionary = _chase(&"ofomni", 4, run)
	assert_almost_eq(float(r.max_speed), 240.0, 0.001, "esprinta")
	assert_gt(float(r.caught), 0.0, "le alcanza")
	assert_lte(float(r.caught), 1.5, "dentro del sprint")


func test_ofomni_without_sprint_never_catches_a_running_player() -> void:
	var cfg: Dictionary = _cfg(&"ofomni").duplicate()
	cfg.erase("sprint_px")
	assert_false(MonsterSteering.can_sprint(cfg))
	assert_lt(float(cfg.speed_px), MovementConfig.run_speed(), "sin sprint, correr basta (el problema de P6)")


func test_feather_talisman_outruns_the_sprint() -> void:
	var bonus: float = Items.speed_bonus(&"talisman_de_pluma")
	assert_almost_eq(bonus, 0.3, 0.0001)
	var r: Dictionary = _chase(&"ofomni", 4, MovementConfig.run_speed() * (1.0 + bonus))
	assert_almost_eq(float(r.max_speed), 240.0, 0.001, "esprinta igualmente")
	assert_eq(float(r.caught), -1.0, "con la pluma (260 px/s) escapa")


func test_walking_player_is_caught() -> void:
	assert_gt(float(_chase(&"aledra", 3, MovementConfig.walk_speed()).caught), 0.0)
	assert_gt(float(_chase(&"reparep", 3, MovementConfig.walk_speed()).caught), 0.0)


func test_chase_is_deterministic() -> void:
	var a: Dictionary = _chase(&"ofomni", 5, MovementConfig.run_speed())
	var b: Dictionary = _chase(&"ofomni", 5, MovementConfig.run_speed())
	assert_eq(a.caught, b.caught)
	assert_eq(a.trace, b.trace)


# --- Calma separada -------------------------------------------------------------------------------

func test_calm_cuts_the_sprint_and_flee_is_shorter_than_retreat() -> void:
	var cfg: Dictionary = _cfg(&"ofomni")
	var m: OverworldMonster = autofree(OverworldMonster.new())
	m.setup_world(&"ofomni", "prueba", -1, Vector2i.ZERO, HOME, Vector2i.DOWN, cfg, _tex())
	m.state = S.CHASE
	m.sprint = Vector2(1.0, 0.0)
	m.calm(MonsterSteering.calm_seconds(cfg, true))
	assert_false(m.is_sprinting())
	assert_eq(m.state, S.RETURN)
	assert_almost_eq(m.cooldown, 1.5, 0.0001, "huir: flee_cooldown")
	m.calm(MonsterSteering.calm_seconds(cfg, false))
	assert_almost_eq(m.cooldown, 3.0, 0.0001, "retroceder: retreat_cooldown")


func test_calm_falls_back_to_engage_cooldown() -> void:
	var cfg: Dictionary = { "engage_cooldown": 2.0 }
	assert_almost_eq(MonsterSteering.calm_seconds(cfg, true), 2.0, 0.0001)
	assert_almost_eq(MonsterSteering.calm_seconds(cfg, false), 2.0, 0.0001)
