class_name BotarramasPosts
extends RefCounted
## Dónde se apostan los Botarramas (monstruos.md), en lógica pura y determinista por seed: uno por
## tramo de frontera de chunk (cada lado de 64 casillas que comparten dos chunks de Bosques
## distintos), en el lado del Bosque que guarda y junto a la puerta o el camino de ese tramo.
## Guarda el Bosque más lejano del natal (el que el jugador quiere abrir al alejarse de casa); a
## igual distancia decide la seed.
## Mundo 2.0 (ADR 0014 §7): posts_near_plan y post_cell_world ponen los puestos solo en los tramos
## con puerta del RegionPlan, junto a la puerta y sobre el WorldChunk (80×80).

const SALT_GUARD: int = 33
## Radio en el que se busca una casilla libre si la de la puerta no sirve.
const SEARCH_RADIUS: int = 8


## Bosque que guarda el tramo entre los Bosques a y b (distintos).
static func guarded_bosque(map: BosqueMap, seed_value: int, home: int, a: int, b: int) -> int:
	var da: int = map.distance(home, a)
	var db: int = map.distance(home, b)
	if da != db:
		return a if da > db else b
	var lo: int = mini(a, b)
	var hi: int = maxi(a, b)
	return lo if ChunkGenerator.hash_ints([seed_value, lo, hi, SALT_GUARD]) % 2 == 0 else hi


## Puestos de los tramos del chunk `coord`: uno por cada lado que da a otro Bosque. Cada puesto es
## { "id": String, "bosque_id": Bosque que guarda, "chunk": chunk donde está (el del Bosque que
## guarda: `coord` o su vecino), "side": lado de ese chunk que da al tramo }.
static func posts_near(map: BosqueMap, seed_value: int, home: int, coord: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var here: int = map.bosque_at(coord)
	if here < 0:
		return out
	for side: Vector2i in ChunkData.SIDES:
		var other: int = map.bosque_at(coord + side)
		if other < 0 or other == here:
			continue
		var guard: int = guarded_bosque(map, seed_value, home, here, other)
		var chunk: Vector2i = coord if guard == here else coord + side
		var s: Vector2i = side if guard == here else -side
		out.append({ "id": post_id(chunk, s), "bosque_id": guard, "chunk": chunk, "side": s })
	return out


static func post_id(chunk: Vector2i, side: Vector2i) -> String:
	return "%d,%d,%d,%d" % [chunk.x, chunk.y, side.x, side.y]


## Casilla del puesto dentro de su chunk: `depth` casillas hacia dentro desde la puerta del lado
## `side` (por donde pasa el sendero o el camino). Si no es transitable o no se llega desde el hub,
## la más cercana que sí (empates por fila y columna).
## ponytail: borrar en M17 (ChunkData); el Mundo 2.0 usa post_cell_world.
static func post_cell(chunk: ChunkData, seed_value: int, side: Vector2i, depth: int) -> Vector2i:
	var gate: Vector2i = ChunkData.border_cell(side, ChunkGenerator.gate_index(seed_value, chunk.coord, side))
	return _nearest_reachable(gate, gate - side * depth, chunk.is_reachable)


# --- Mundo 2.0 (ADR 0014 §7): puestos en las puertas del RegionPlan --------------------------------

## Puestos del chunk `coord` en el Mundo 2.0: los de posts_near, pero solo en los tramos con puerta
## (RegionPlan.door). En un tramo sin puerta no hay puesto: si el jugador lo cruza entre árboles,
## el límite (BosqueBorder) lanza el flujo del cruce y acude el Botarramas más cercano
## (MonsterField.summon_nearest).
static func posts_near_plan(plan: RegionPlan, seed_value: int, home: int, coord: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in posts_near(plan.bosques, seed_value, home, coord):
		if plan.has_door(p.chunk, p.side):
			out.append(p)
	return out


## Casilla de la puerta del lado `side` del chunk: la del medio de su anchura, en el borde del
## chunk (0..79). (-1, -1) si ese lado no tiene puerta.
static func door_cell(plan: RegionPlan, coord: Vector2i, side: Vector2i) -> Vector2i:
	var d: Dictionary = plan.door(coord, side)
	if d.is_empty():
		return Vector2i(-1, -1)
	return WorldChunk.border_cell(side, int(d.index) + int(d.width) / 2)


## Casilla del puesto (dentro del chunk, 0..79) en el Mundo 2.0: `depth` casillas hacia dentro desde
## el medio de la puerta del lado `side`. Si no se llega desde el hub, la más cercana que sí (empates
## por fila y columna), como post_cell. Sin puerta, desde el medio del lado.
static func post_cell_world(chunk: WorldChunk, plan: RegionPlan, side: Vector2i, depth: int) -> Vector2i:
	var gate: Vector2i = door_cell(plan, chunk.coord, side)
	if gate.x < 0:
		gate = WorldChunk.border_cell(side, WorldChunk.SIZE / 2)
	return _nearest_reachable(gate, gate - side * depth, chunk.is_reachable)


## `target` si se llega a él (`is_reachable`); si no, la casilla alcanzable más cercana a
## SEARCH_RADIUS o menos (empates por fila y columna); `gate` si no hay ninguna.
static func _nearest_reachable(gate: Vector2i, target: Vector2i, is_reachable: Callable) -> Vector2i:
	if is_reachable.call(target):
		return target
	var best: Vector2i = gate
	var best_score: int = 1 << 30
	for dy: int in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
		for dx: int in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
			var c: Vector2i = target + Vector2i(dx, dy)
			if not is_reachable.call(c):
				continue
			var score: int = (absi(dx) + absi(dy)) * 10_000 + c.y * 100 + c.x
			if score < best_score:
				best_score = score
				best = c
	return best
