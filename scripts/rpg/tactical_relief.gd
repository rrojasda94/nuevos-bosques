class_name TacticalRelief
extends RefCounted
## Tablero táctico desde el relieve real del Mundo 2.0 (combate-tactico.md, "Alturas en el
## tablero"; ADR 0014 §3, ADR 0016; PR T7a). Lógica pura: lee un WorldQuery.Area (o un `get_chunk`
## y la casilla del encuentro), no toca GameState, la escena ni scripts/world. Números en
## balance.json (tactical.arena.relief).
##
## 1. Compresión de riscos (compress). En el mundo, cada nivel de caída ocupa 2 filas de cara
##    hacia el sur (en las casillas de arriba del nivel de abajo) y los bordes norte, este y oeste
##    están en la fila o columna del borde de la meseta (nivel de arriba). En el tablero esas
##    casillas dejan de bloquear y cada una conserva el nivel que ya guarda `level[]`: la cara, el
##    de abajo; el borde, el de arriba. No se quitan filas (el tablero no se deforma) y el risco
##    queda como un salto de altura entre dos casillas vecinas: la última fila de cara (nivel de
##    abajo) junto a la meseta, o el borde (nivel de arriba) junto al suelo de abajo.
##    Siguen bloqueando: las cumbres (risco EDGE en toda su celda gruesa de 4 x 4, nivel 3), las
##    cascadas (agua) y las casillas de chunks que no están cargados.
## 2. Mapeo al formato de TacticalBoard.from_cells:
##    - level: nivel 0–3 menos el mínimo de las casillas transitables del recorte (con desnivel
##      <= max_span quedan 0..2);
##    - water: agua honda (río, lago, mar) y cascada; ford: vado (agua que se pisa); un puente es
##      suelo normal;
##    - stair / ramp: las escaleras y rampas del mundo (se pasan sin gastar Salto);
##    - object_kind: el nombre del WorldChunk.ObjectKind en minúsculas (tree, rock, house...). Es
##      obstáculo salvo los que en el mundo no bloquean (refuge_tree, cave: walkable_objects). La
##      hierba alta, flores y matas son decoración plana (WorldChunk.decor): nunca estorban y no
##      llegan al tablero.
## 3. Elección del recorte (choose): se prueban recortes del tamaño del plan desplazados de `step` en
##    `step` casillas hasta `radius` (1 chunk) del encuentro (el desplazamiento 0 es el recorte
##    centrado). Proporción transitable y desnivel salen de sumas acumuladas (O(1) por recorte).
##    Válido: proporción >= min_walkable, desnivel <= max_span y camino a pie entre las columnas de
##    colocación de los dos bandos (TacticalBoard.has_walk_path con path_jump y path_drop). Gana el
##    de mayor puntuación (proporción, desnivel y distancia al encuentro; empate: el más cercano y
##    luego el de arriba a la izquierda). Determinista.
## 4. Recurso (mode): RELIEF si hay un recorte válido; si no, RELAXED, el mejor con desnivel <=
##    max_span, camino y proporción >= relaxed_min_walkable (el "claro más cercano" aunque tenga
##    menos del 70%); si tampoco, FLAT, el tablero llano de siempre. Los caminos se comprueban como
##    mucho en max_checks recortes por modo.
## 5. arena_config: todo junto para Crossing y la demo: tamaño por la proporción transitable
##    (comprimida) del recorte de 14 x 10 alrededor del encuentro (TacticalArena), recorte, tablero
##    y cupo contado sobre el tablero real (TacticalArena.quota_for_board).

const RELIEF: StringName = &"relief"
const RELAXED: StringName = &"relaxed"
const FLAT: StringName = &"flat"
## Valores de respaldo si balance.json no trae el bloque (los mismos que el JSON).
const FALLBACK: Dictionary = {
	"radius": 80, "step": 4, "max_span": 2, "min_walkable": 0.7, "relaxed_min_walkable": 0.5,
	"path_jump": 1, "path_drop": 2, "weight_walkable": 0.5, "weight_span": 0.0, "weight_distance": 1.0,
	"max_checks": 64,
}


## Rejilla comprimida de un WorldQuery.Area: mismas dimensiones y origen, capas fila a fila.
class Grid extends RefCounted:
	var origin: Vector2i = Vector2i.ZERO
	var size: Vector2i = Vector2i.ZERO
	var level := PackedByteArray()
	## 1 si la casilla bloquea por sí misma (cumbre, chunk sin cargar).
	var blocked := PackedByteArray()
	## WorldQuery.Crossing.
	var crossing := PackedByteArray()
	var water := PackedByteArray()
	var ford := PackedByteArray()
	## WorldChunk.ObjectKind o -1.
	var object_kind := PackedInt32Array()
	## 1 si se puede pisar en el tablero (tras comprimir).
	var walk := PackedByteArray()

	func index(world_cell: Vector2i) -> int:
		var local: Vector2i = world_cell - origin
		if local.x < 0 or local.y < 0 or local.x >= size.x or local.y >= size.y:
			return -1
		return local.y * size.x + local.x

	func rect() -> Rect2i:
		return Rect2i(origin, size)


## Bloque relief de un bloque arena (o el de respaldo, completado clave a clave).
static func relief_cfg(arena: Dictionary) -> Dictionary:
	var cfg: Dictionary = FALLBACK.duplicate()
	var own: Dictionary = arena.get("relief", {})
	for k: Variant in own:
		cfg[k] = own[k]
	return cfg


## Nombre de un WorldChunk.ObjectKind en el tablero (&"" si no hay objeto).
static func object_name(kind: int) -> StringName:
	if kind < 0 or kind >= WorldChunk.ObjectKind.size():
		return &""
	return StringName((WorldChunk.ObjectKind.keys()[kind] as String).to_lower())


## Objetos que no estorban en el tablero: los que tampoco bloquean en el mundo.
static func walkable_objects() -> Array[StringName]:
	var out: Array[StringName] = []
	for kind: int in WorldChunk.ObjectKind.size():
		if not WorldChunk.is_object_blocking(kind):
			out.append(object_name(kind))
	return out


## Comprime los riscos de un Area (ver 1 arriba).
static func compress(area: WorldQuery.Area) -> Grid:
	var g := Grid.new()
	g.origin = area.origin
	g.size = area.size
	var n: int = area.size.x * area.size.y
	var level := PackedByteArray()
	var blocked := PackedByteArray()
	var crossing := PackedByteArray()
	var water := PackedByteArray()
	var ford := PackedByteArray()
	var walk := PackedByteArray()
	var objs := PackedInt32Array()
	level.resize(n)
	blocked.resize(n)
	crossing.resize(n)
	water.resize(n)
	ford.resize(n)
	walk.resize(n)
	objs.resize(n)
	objs.fill(WorldChunk.NO_OBJECT)
	var a_loaded: PackedByteArray = area.loaded
	var a_level: PackedByteArray = area.level
	var a_cliff: PackedByteArray = area.cliff
	var a_cross: PackedByteArray = area.crossing
	var a_water: PackedByteArray = area.water
	var a_obj: PackedInt32Array = area.object_kind
	var peaks: Dictionary = {}
	for i: int in n:
		if a_loaded[i] == 0:
			blocked[i] = 1
			continue
		var lvl: int = a_level[i]
		level[i] = lvl
		crossing[i] = a_cross[i]
		var c: int = a_cliff[i]
		var w: int = a_water[i]
		if c == WorldChunk.Cliff.WATERFALL or w == WorldQuery.Water.DEEP:
			water[i] = 1
		elif w == WorldQuery.Water.FORD:
			water[i] = 1
			ford[i] = 1
		if c == WorldChunk.Cliff.EDGE and lvl == WorldChunk.MAX_LEVEL:
			var wc := Vector2i(area.origin.x + i % area.size.x, area.origin.y + i / area.size.x)
			if _is_peak(area, wc, peaks):
				blocked[i] = 1
		var obj: int = a_obj[i]
		objs[i] = obj
		var free: bool = blocked[i] == 0 and (water[i] == 0 or ford[i] == 1) \
				and (obj < 0 or not WorldChunk.is_object_blocking(obj))
		walk[i] = 1 if free else 0
	g.level = level
	g.blocked = blocked
	g.crossing = crossing
	g.water = water
	g.ford = ford
	g.walk = walk
	g.object_kind = objs
	return g


## Una casilla EDGE de nivel 3 es de cumbre si toda su celda gruesa (4 x 4, alineada al mundo) es
## EDGE de nivel 3: una meseta normal solo tiene borde en su primera fila y en sus columnas de los
## lados. Las casillas de la celda que caen fuera del Area no cuentan (el Area de choose lleva una
## celda gruesa de margen).
static func _is_peak(area: WorldQuery.Area, world_cell: Vector2i, cache: Dictionary) -> bool:
	var macro: Vector2i = WorldCoords.floor_div_v(world_cell, WorldCoords.MACRO)
	if cache.has(macro):
		return cache[macro]
	var base: Vector2i = macro * WorldCoords.MACRO
	var peak: bool = true
	for y: int in WorldCoords.MACRO:
		for x: int in WorldCoords.MACRO:
			var i: int = area.index(base + Vector2i(x, y))
			if i < 0:
				continue
			if area.loaded[i] == 1 and (area.cliff[i] != WorldChunk.Cliff.EDGE or area.level[i] != WorldChunk.MAX_LEVEL):
				peak = false
	cache[macro] = peak
	return peak


## Nivel mínimo de las casillas transitables de `rect` (0 si no hay ninguna).
static func min_level(grid: Grid, rect: Rect2i) -> int:
	var lo: int = WorldChunk.MAX_LEVEL + 1
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var i: int = grid.index(Vector2i(x, y))
			if i >= 0 and grid.walk[i] == 1:
				lo = mini(lo, grid.level[i])
	return 0 if lo > WorldChunk.MAX_LEVEL else lo


## Casillas de `rect` en el formato de TacticalBoard.from_cells (claves: world_cell), con el nivel
## normalizado al mínimo transitable del recorte.
static func cells_for(grid: Grid, rect: Rect2i) -> Dictionary:
	var base: int = min_level(grid, rect)
	var out: Dictionary = {}
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var wc := Vector2i(x, y)
			var i: int = grid.index(wc)
			if i < 0:
				out[wc] = { "blocked": true }
				continue
			out[wc] = {
				"level": clampi(int(grid.level[i]) - base, 0, TacticalBoard.MAX_LEVEL),
				"blocked": grid.blocked[i] == 1,
				"stair": grid.crossing[i] == WorldQuery.Crossing.STAIRS,
				"ramp": grid.crossing[i] == WorldQuery.Crossing.RAMP,
				"water": grid.water[i] == 1,
				"ford": grid.ford[i] == 1,
				"object_kind": object_name(grid.object_kind[i]),
			}
	return out


## Tablero de `rect` (tamaño del recorte; ford_cost de `board_cfg`).
static func board_for(grid: Grid, rect: Rect2i, board_cfg: Dictionary = {}) -> TacticalBoard:
	var board := TacticalBoard.from_cells(rect.size.x, rect.size.y, cells_for(grid, rect), rect.position,
		walkable_objects())
	board.ford_cost = maxi(int(board_cfg.get("ford_cost", 1)), 1)
	return board


## Hay camino a pie entre las columnas de colocación de los dos bandos (y casillas en las dos).
static func sides_connected(board: TacticalBoard, deploy_columns: int, cfg: Dictionary) -> bool:
	var left: Array[Vector2i] = board.deploy_cells(TacticalBoard.Side.LEFT, deploy_columns)
	var right: Array[Vector2i] = board.deploy_cells(TacticalBoard.Side.RIGHT, deploy_columns)
	if left.is_empty() or right.is_empty():
		return false
	return board.has_walk_path(left, right, int(cfg.get("path_jump", 1)), int(cfg.get("path_drop", 2)))


## Area alrededor del encuentro que cubre todos los recortes de `size` hasta `radius`, alineada a la
## celda gruesa y con una de margen (para reconocer las cumbres).
static func search_area(get_chunk: Callable, encounter: Vector2i, size: Vector2i, cfg: Dictionary) -> WorldQuery.Area:
	var radius: int = maxi(int(cfg.get("radius", 80)), 0)
	var m: int = WorldCoords.MACRO
	var first: Vector2i = encounter - size / 2 - Vector2i(radius, radius)
	var last: Vector2i = first + size + Vector2i(radius, radius) * 2
	var origin: Vector2i = WorldCoords.floor_div_v(first, m) * m - Vector2i(m, m)
	var end: Vector2i = (WorldCoords.floor_div_v(last - Vector2i.ONE, m) + Vector2i(2, 2)) * m
	return WorldQuery.rect(get_chunk, origin, end - origin)


## Proporción transitable (comprimida) de `rect`.
static func walk_ratio(grid: Grid, rect: Rect2i) -> float:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return 0.0
	var count: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var i: int = grid.index(Vector2i(x, y))
			if i >= 0 and grid.walk[i] == 1:
				count += 1
	return float(count) / float(rect.size.x * rect.size.y)


## Elige el recorte de `size` (ver 3 y 4 arriba). { mode, rect, ratio, span, score }; con FLAT, rect
## es el recorte centrado (solo informativo) y ratio y span, los suyos.
static func choose(grid: Grid, encounter: Vector2i, size: Vector2i, deploy_columns: int, cfg: Dictionary) -> Dictionary:
	var radius: int = maxi(int(cfg.get("radius", 80)), 0)
	var step: int = maxi(int(cfg.get("step", 4)), 1)
	var max_span: int = int(cfg.get("max_span", 2))
	var min_walk: float = float(cfg.get("min_walkable", 0.7))
	var relaxed_walk: float = float(cfg.get("relaxed_min_walkable", 0.5))
	var w_walk: float = float(cfg.get("weight_walkable", 0.5))
	var w_span: float = float(cfg.get("weight_span", 0.0))
	var w_dist: float = float(cfg.get("weight_distance", 1.0))
	var max_checks: int = maxi(int(cfg.get("max_checks", 64)), 1)
	var gw: int = grid.size.x
	var gh: int = grid.size.y
	# Sumas acumuladas (gw + 1) x (gh + 1): transitables y transitables de cada nivel.
	var stride: int = gw + 1
	var plane: int = stride * (gh + 1)
	var walk_sum := PackedInt32Array()
	walk_sum.resize(plane)
	var levels: int = WorldChunk.MAX_LEVEL + 1
	var level_sum := PackedInt32Array()
	level_sum.resize(plane * levels)
	var walk: PackedByteArray = grid.walk
	var lev: PackedByteArray = grid.level
	var row_l := PackedInt32Array()
	row_l.resize(levels)
	for y: int in gh:
		var row_w: int = 0
		row_l.fill(0)
		for x: int in gw:
			var i: int = y * gw + x
			var k: int = (y + 1) * stride + x + 1
			if walk[i] == 1:
				row_w += 1
				row_l[mini(lev[i], WorldChunk.MAX_LEVEL)] += 1
			walk_sum[k] = walk_sum[k - stride] + row_w
			for l: int in levels:
				level_sum[l * plane + k] = level_sum[l * plane + k - stride] + row_l[l]
	var center_origin: Vector2i = encounter - size / 2
	var strict: Array[Dictionary] = []
	var relaxed: Array[Dictionary] = []
	var reach: int = radius / step
	for oy: int in range(-reach, reach + 1):
		for ox: int in range(-reach, reach + 1):
			var off := Vector2i(ox * step, oy * step)
			var rect := Rect2i(center_origin + off, size)
			var lx: int = rect.position.x - grid.origin.x
			var ly: int = rect.position.y - grid.origin.y
			if lx < 0 or ly < 0 or lx + size.x > gw or ly + size.y > gh:
				continue
			var count: int = _box(walk_sum, 0, stride, lx, ly, size)
			var ratio: float = float(count) / float(size.x * size.y)
			if ratio < relaxed_walk or count == 0:
				continue
			var lo: int = -1
			var hi: int = -1
			for l: int in levels:
				if _box(level_sum, l * plane, stride, lx, ly, size) > 0:
					if lo < 0:
						lo = l
					hi = l
			var span: int = hi - lo
			if span > max_span:
				continue
			var dist: float = Vector2(off).length()
			var cand: Dictionary = {
				"rect": rect, "ratio": ratio, "span": span, "dist": dist,
				"score": ratio * w_walk - span * w_span - (dist / maxf(radius, 1.0)) * w_dist,
			}
			if ratio >= min_walk:
				strict.append(cand)
			else:
				relaxed.append(cand)
	var better := func(a: Dictionary, b: Dictionary) -> bool: return _better(a, b)
	strict.sort_custom(better)
	relaxed.sort_custom(better)
	for pair: Array in [[strict, RELIEF], [relaxed, RELAXED]]:
		var list: Array = pair[0]
		var checks: int = 0
		for cand: Dictionary in list:
			if checks >= max_checks:
				break
			checks += 1
			var board: TacticalBoard = board_for(grid, cand.rect)
			if sides_connected(board, deploy_columns, cfg):
				return { "mode": pair[1], "rect": cand.rect, "ratio": cand.ratio, "span": cand.span, "score": cand.score }
	var center := Rect2i(center_origin, size)
	return { "mode": FLAT, "rect": center, "ratio": walk_ratio(grid, center), "span": 0, "score": 0.0 }


## Más puntuación primero; empate: más cerca, luego el de arriba y el de la izquierda.
static func _better(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(float(a.score), float(b.score)):
		return float(a.score) > float(b.score)
	if not is_equal_approx(float(a.dist), float(b.dist)):
		return float(a.dist) < float(b.dist)
	var pa: Vector2i = (a.rect as Rect2i).position
	var pb: Vector2i = (b.rect as Rect2i).position
	return pa.y < pb.y if pa.y != pb.y else pa.x < pb.x


static func _box(sum: PackedInt32Array, base: int, stride: int, x: int, y: int, size: Vector2i) -> int:
	var x2: int = x + size.x
	var y2: int = y + size.y
	return sum[base + y2 * stride + x2] - sum[base + y * stride + x2] - sum[base + y2 * stride + x] 			+ sum[base + y * stride + x]


## Tablero de un tamaño ya decidido: { mode, rect, ratio, span, board }. Con FLAT, el llano.
static func board_from_grid(grid: Grid, encounter: Vector2i, size: Vector2i, deploy_columns: int,
		cfg: Dictionary, board_cfg: Dictionary = {}) -> Dictionary:
	var pick: Dictionary = choose(grid, encounter, size, deploy_columns, cfg)
	var board: TacticalBoard
	if pick.mode == FLAT:
		board = TacticalBoard.new(size.x, size.y)
		board.ford_cost = maxi(int(board_cfg.get("ford_cost", 1)), 1)
	else:
		board = board_for(grid, pick.rect, board_cfg)
	pick.board = board
	return pick


## Bloque tactical (con lo compartido, como TacticalBridge.arena_config) y tablero con relieve para un
## encuentro en `encounter` (world_cell) del Mundo 2.0. `get_chunk`: Callable(chunk_coord) ->
## WorldChunk o null. { cfg, board, mode, rect, ratio, span }.
static func arena_config(balance_data: Dictionary, get_chunk: Callable, encounter: Vector2i,
		biome: StringName = &"") -> Dictionary:
	var cfg: Dictionary = TacticalBattle.config_from_balance(balance_data)
	var arena: Dictionary = TacticalArena.arena_cfg(cfg)
	var relief: Dictionary = relief_cfg(arena)
	var sample: Vector2i = TacticalArena.sample_size(arena)
	# El Area cubre el recorte más grande (14 x 10) en todo el radio: sirve para cualquier tamaño.
	var big: Vector2i = Vector2i(maxi(sample.x, 14), maxi(sample.y, 10))
	var grid: Grid = compress(search_area(get_chunk, encounter, big, relief))
	var plan: Dictionary = TacticalArena.plan(cfg, walk_ratio(grid, Rect2i(encounter - sample / 2, sample)), biome)
	var size := Vector2i(int(plan.width), int(plan.height))
	var pick: Dictionary = board_from_grid(grid, encounter, size, int(plan.deploy_columns), relief,
		cfg.get("board", {}))
	var board: TacticalBoard = pick.board
	if pick.mode != FLAT:
		plan.walkable = roundi(board.walkable_ratio() * board.width * board.height)
		plan.quota = TacticalArena.quota_for_board(board, arena)
	plan.relief = pick.mode
	plan.relief_origin = (pick.rect as Rect2i).position
	return {
		"cfg": TacticalArena.apply_plan(cfg, plan), "board": board, "mode": pick.mode,
		"rect": pick.rect, "ratio": pick.ratio, "span": pick.span,
	}
