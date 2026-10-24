class_name BotarramasPosts
extends RefCounted
## Dónde se apostan los Botarramas (monstruos.md), en lógica pura y determinista por seed: uno por
## tramo de frontera de chunk (cada lado de 64 casillas que comparten dos chunks de Bosques
## distintos), en el lado del Bosque que guarda y junto a la puerta o el camino de ese tramo.
## Guarda el Bosque más lejano del natal (el que el jugador quiere abrir al alejarse de casa); a
## igual distancia decide la seed.

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
static func post_cell(chunk: ChunkData, seed_value: int, side: Vector2i, depth: int) -> Vector2i:
	var gate: Vector2i = ChunkData.border_cell(side, ChunkGenerator.gate_index(seed_value, chunk.coord, side))
	var target: Vector2i = gate - side * depth
	if chunk.is_reachable(target):
		return target
	var best: Vector2i = gate
	var best_score: int = 1 << 30
	for dy: int in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
		for dx: int in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
			var c: Vector2i = target + Vector2i(dx, dy)
			if not chunk.is_reachable(c):
				continue
			var score: int = (absi(dx) + absi(dy)) * 10_000 + c.y * 100 + c.x
			if score < best_score:
				best_score = score
				best = c
	return best
