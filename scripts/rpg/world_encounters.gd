class_name WorldEncounters
extends RefCounted
## Encuentros con los monstruos en el Mundo 2.0 (ADR 0014 §2 "Encuentros", mundo-2.md §5), en
## lógica pura: el encuentro empieza cuando la separación entre las cajas de los pies del monstruo
## y del jugador es de `engage_px` o menos (datos de cada monstruo, balance.json). La separación se
## mide entre los bordes, en Chebyshev: el mayor de los huecos en x y en y; 0 = se tocan o se
## solapan. La visión sigue en casillas (MonsterSteering.sees).
## Caso límite (propuesta de mundo-2.md): con los pies en casillas de distinto nivel (uno arriba
## del risco y otro al pie) no hay encuentro salvo que haya una escalera o rampa a
## `world_encounters.level_link_cells` casillas o menos de alguno de los dos.


## Hueco entre los bordes de dos cajas (px, Chebyshev). 0 si se tocan o se solapan.
static func box_gap(a: Rect2, b: Rect2) -> float:
	var gx: float = maxf(0.0, maxf(b.position.x - a.end.x, a.position.x - b.end.x))
	var gy: float = maxf(0.0, maxf(b.position.y - a.end.y, a.position.y - b.end.y))
	return maxf(gx, gy)


## Empieza el encuentro: puede detectar al jugador y las cajas están a engage_px o menos. El
## camuflaje no lo evita (como MonsterSteering.engages): de tan cerca, te ve igualmente.
static func engages(monster_box: Rect2, player_box: Rect2, can_detect: bool, cfg: Dictionary) -> bool:
	return can_detect and box_gap(monster_box, player_box) <= float(cfg.get("engage_px", 0))


## Casillas (Chebyshev) a las que una escalera o rampa une dos niveles para un encuentro.
static func level_link_cells() -> int:
	return int((AdventureRules.balance().get("world_encounters", {}) as Dictionary).get("level_link_cells", 0))


## Las dos casillas de los pies se pueden encontrar por nivel: mismo `level[]`, o una escalera o
## rampa a `radius` casillas o menos de alguna de las dos. `get_chunk`: (chunk) -> WorldChunk o
## null. Si falta un chunk, no se impide el encuentro (lo decide el resto de reglas).
static func levels_linked(a: Vector2i, b: Vector2i, get_chunk: Callable, radius: int) -> bool:
	var la: int = _level(a, get_chunk)
	var lb: int = _level(b, get_chunk)
	if la < 0 or lb < 0 or la == lb:
		return true
	return _crossing_near(a, get_chunk, radius) or _crossing_near(b, get_chunk, radius)


static func _level(world_cell: Vector2i, get_chunk: Callable) -> int:
	var chunk: WorldChunk = get_chunk.call(WorldCoords.world_cell_to_chunk(world_cell))
	if chunk == null:
		return -1
	return chunk.get_level(WorldCoords.world_cell_to_cell(world_cell))


static func _crossing_near(center: Vector2i, get_chunk: Callable, radius: int) -> bool:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var c: Vector2i = center + Vector2i(dx, dy)
			var chunk: WorldChunk = get_chunk.call(WorldCoords.world_cell_to_chunk(c))
			if chunk == null:
				continue
			var cliff: int = chunk.get_cliff(WorldCoords.world_cell_to_cell(c))
			if cliff == WorldChunk.Cliff.STAIRS or cliff == WorldChunk.Cliff.RAMP:
				return true
	return false
