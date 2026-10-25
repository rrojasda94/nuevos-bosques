class_name BosqueFires
extends RefCounted
## Incendios de los Bosques que necesitan ayuda (bosques-y-relacion.md, #133: "pueden presentar
## incendios"). Lógica pura y determinista por seed:
## - Un chunk de un Bosque que necesita ayuda arde con probabilidad chunk_percent (su chunk central,
##   siempre, para que el Bosque tenga al menos uno). El fuego ocupa entre cells[0] y cells[1]
##   casillas contiguas: empieza en un árbol que da a una casilla alcanzable (para poder apagarlo
##   con E desde delante) y se extiende por árboles y hierba. Nunca corta un paso: una casilla
##   transitable solo arde si todo lo que se alcanzaba desde el hub se sigue alcanzando.
## - El fuego bloquea el paso. Apagarlo (E, "Apagar el fuego") apaga todo el incendio del chunk,
##   gasta time_seconds de reloj o luz_cost de Luz y sube la relación con el Bosque (+per_defense,
##   AdventureRules.reward_bosque_defense). Los incendios apagados se guardan
##   (GameState.extinguished_fires) y no vuelven.
## No dibuja: la exploración pone el fuego animado. Números en data/combat/balance.json
## (bosque_states.necesita_ayuda.fire).

const SALT_FIRE: int = 73
const SALT_FIRE_CELLS: int = 79
## Margen (casillas) al borde del chunk: el fuego no tapa las entradas.
const MARGIN: int = 4
## Orígenes que se prueban como mucho para que el fuego llegue al mínimo de casillas.
const ORIGIN_TRIES: int = 12


static func config() -> Dictionary:
	return BosqueStates.state_config(BosqueStates.NECESITA_AYUDA).get("fire", {})


static func time_seconds() -> float:
	return float(config().get("time_seconds", 30))


static func luz_cost() -> int:
	return int(config().get("luz_cost", 1))


## Casillas de fuego del chunk tal como lo generó la seed (sin mirar si se apagó). Vacío si el
## Bosque no necesita ayuda o el chunk no arde. `always`: el chunk arde seguro (el central).
static func fire_cells(chunk: ChunkData, seed_value: int, state: String, always: bool = false) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if state != BosqueStates.NECESITA_AYUDA or chunk == null:
		return out
	var cfg: Dictionary = config()
	var coord: Vector2i = chunk.coord
	var h: int = ChunkGenerator.hash_ints([seed_value, coord.x, coord.y, SALT_FIRE])
	if not always and h % 100 >= int(cfg.get("chunk_percent", 40)):
		return out
	var range_n: Array = cfg.get("cells", [3, 5])
	var lo: int = int(range_n[0])
	var wanted: int = lo + (h >> 8) % (maxi(lo, int(range_n[1])) - lo + 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = ChunkGenerator.hash_ints([seed_value, coord.x, coord.y, SALT_FIRE_CELLS])
	# Origen: un árbol junto a una casilla alcanzable (desde ahí se apaga).
	var origins: Array[Vector2i] = []
	for y: int in range(MARGIN, ChunkData.SIZE - MARGIN):
		for x: int in range(MARGIN, ChunkData.SIZE - MARGIN):
			var c := Vector2i(x, y)
			if chunk.get_tile(c) == ChunkData.Tile.TREE and _touches_reachable(chunk, c):
				origins.append(c)
	if origins.is_empty():
		return out
	var before: int = _reachable_count(chunk, {})
	# Un árbol suelto puede no tener por dónde extenderse: se prueban orígenes hasta que el fuego
	# llega al mínimo (si ninguno llega, el más grande).
	for attempt: int in ORIGIN_TRIES:
		var start: Vector2i = origins[rng.randi() % origins.size()]
		var cells: Array[Vector2i] = _grow_fire(chunk, start, wanted, before, rng)
		if cells.size() > out.size():
			out = cells
		if out.size() >= lo:
			break
	return out


## Fuego desde `start` hasta `wanted` casillas por árboles y hierba, sin cortar pasos.
static func _grow_fire(chunk: ChunkData, start: Vector2i, wanted: int, before: int,
		rng: RandomNumberGenerator) -> Array[Vector2i]:
	var out: Array[Vector2i] = [start]
	var blocked: Dictionary = {}
	var frontier: Array[Vector2i] = _burnable_neighbours(chunk, start, out)
	while out.size() < wanted and not frontier.is_empty():
		var c: Vector2i = frontier.pop_at(rng.randi() % frontier.size())
		if out.has(c):
			continue
		if chunk.is_walkable(c):
			# Una casilla transitable solo arde si no deja nada sin alcanzar.
			var trial: Dictionary = blocked.duplicate()
			trial[c] = true
			var lost: int = 1 if chunk.is_reachable(c) else 0
			for b: Vector2i in blocked:
				lost += 1 if chunk.is_reachable(b) else 0
			if chunk.is_reachable(c) and _reachable_count(chunk, trial) != before - lost:
				continue
			blocked = trial
		out.append(c)
		frontier.append_array(_burnable_neighbours(chunk, c, out))
	return out


## Casillas que arden ahora en el chunk: las de la seed, salvo que ya se apagara.
static func active_cells(chunk: ChunkData, seed_value: int, state: String, always: bool = false) -> Array[Vector2i]:
	if chunk == null or is_extinguished(chunk.coord):
		var none: Array[Vector2i] = []
		return none
	return fire_cells(chunk, seed_value, state, always)


static func is_extinguished(coord: Vector2i) -> bool:
	return GameState.extinguished_fires.has(coord)


## Apaga el incendio del chunk `coord` del Bosque `bosque_id`: con Luz (`by_luz`, luz_cost) o con
## tiempo (avanza el reloj time_seconds). Sube la relación (+per_defense) y lo guarda. false si ya
## estaba apagado o no hay Luz suficiente.
static func extinguish(coord: Vector2i, bosque_id: int, by_luz: bool) -> bool:
	if is_extinguished(coord):
		return false
	if by_luz:
		if GameState.luz < luz_cost():
			return false
		AdventureRules.set_luz(GameState.luz - luz_cost())
	GameState.extinguished_fires.append(coord)
	AdventureRules.reward_bosque_defense(bosque_id)
	EventBus.bosque_fire_extinguished.emit(bosque_id, coord)
	if not by_luz:
		WorldClock.advance(time_seconds())
	return true


static func _touches_reachable(chunk: ChunkData, c: Vector2i) -> bool:
	for d: Vector2i in ChunkData.SIDES:
		if chunk.is_reachable(c + d):
			return true
	return false


## Vecinos que pueden arder: árboles y hierba dentro del margen y que no están ya en `taken`.
static func _burnable_neighbours(chunk: ChunkData, c: Vector2i, taken: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in ChunkData.SIDES:
		var n: Vector2i = c + d
		if n.x < MARGIN or n.y < MARGIN or n.x >= ChunkData.SIZE - MARGIN or n.y >= ChunkData.SIZE - MARGIN:
			continue
		var t: int = chunk.get_tile(n)
		if (t == ChunkData.Tile.TREE or t == ChunkData.Tile.GRASS) and not taken.has(n) and n != chunk.hub:
			out.append(n)
	return out


## Casillas alcanzables desde el hub sin pisar las de `blocked`.
static func _reachable_count(chunk: ChunkData, blocked: Dictionary) -> int:
	var size: int = ChunkData.SIZE
	var seen := PackedByteArray()
	seen.resize(size * size)
	if not chunk.is_walkable(chunk.hub) or blocked.has(chunk.hub):
		return 0
	var queue: Array[Vector2i] = [chunk.hub]
	seen[chunk.hub.y * size + chunk.hub.x] = 1
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for d: Vector2i in ChunkData.SIDES:
			var n: Vector2i = cell + d
			if chunk.is_walkable(n) and not blocked.has(n) and seen[n.y * size + n.x] == 0:
				seen[n.y * size + n.x] = 1
				queue.append(n)
	return queue.size()
