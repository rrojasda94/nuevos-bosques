class_name MapLogic
extends RefCounted
## Lógica pura del mapa de la región (tecla M) y de la brújula del HUD (navegacion.md): qué chunks
## se han explorado y se ven, qué se dibuja encima y hacia dónde apunta la brújula. Sin nodos:
## la usan RegionMap, Compass y la exploración (para marcar chunks) y se prueba con GUT.
## No dibuja ni guarda: solo lee y modifica los arrays que recibe.

## Índice de brújula cuando el jugador ya está en el objetivo ("Aquí").
const HERE: int = -1

static var _map: BosqueMap
static var _map_key: String = ""


## Reparto en Bosques de la partida actual (seed + región), en caché mientras no cambien.
static func current_bosques() -> BosqueMap:
	var key: String = "%d:%s" % [GameState.seed_value, GameState.region_id]
	if key != _map_key or _map == null:
		_map = BosqueMap.for_region(GameState.seed_value, ChunkGenerator.load_region(GameState.region_id))
		_map_key = key
	return _map


## Marca `coord` como explorado. Devuelve true si es la primera vez.
static func mark_explored(explored: Array[Vector2i], coord: Vector2i) -> bool:
	if coord.x < 0 or coord.y < 0 or explored.has(coord):
		return false
	explored.append(coord)
	return true


static func is_explored(explored: Array[Vector2i], coord: Vector2i) -> bool:
	return explored.has(coord)


## Chunks explorados que están dentro de la región (los únicos que el mapa pinta).
static func visible_cells(bosques: BosqueMap, explored: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in explored:
		if bosques.bosque_at(c) >= 0:
			out.append(c)
	return out


## Índice de color de hoja (PlaceholderTileset.LEAVES) del chunk, o -1 si no se ve (niebla).
static func cell_leaf(bosques: BosqueMap, explored: Array[Vector2i], coord: Vector2i) -> int:
	var id: int = bosques.bosque_at(coord)
	if id < 0 or not explored.has(coord):
		return -1
	return int(bosques.styles[id].get("leaf", 0))


## Tramos de camino visibles: por cada chunk explorado con camino, los lados por los que sale.
## { Vector2i chunk: Array[Vector2i] lados }.
static func visible_roads(bosques: BosqueMap, explored: Array[Vector2i]) -> Dictionary:
	var out: Dictionary = {}
	for c: Vector2i in visible_cells(bosques, explored):
		if bosques.has_road(c):
			out[c] = bosques.road_sides(c)
	return out


## Refugios vistos: chunks explorados con refugio.
static func visible_refuges(bosques: BosqueMap, explored: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in visible_cells(bosques, explored):
		if bosques.has_refuge(c):
			out.append(c)
	return out


## Villas vistas (sin la natal): chunks de Nujio explorados de Bosques con villa.
static func visible_villas(bosques: BosqueMap, explored: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for id: int in bosques.count():
		var c: Vector2i = bosques.nujio_chunk[id]
		if id != bosques.home_bosque and bosques.has_villa[id] and explored.has(c):
			out.append(c)
	return out


## Botarramas vistos (GameState.seen_monsters), en su última posición vista: lista de
## { "chunk": Vector2i, "passive": bool } (passive = su Bosque ya está abierto). Varios en el mismo
## chunk se dibujan una vez; si alguno sigue activo, la marca es activa.
static func visible_monsters(bosques: BosqueMap, seen: Dictionary, open_bosques: Array[int]) -> Array[Dictionary]:
	var by_chunk: Dictionary = {}
	for key: Variant in seen:
		var e: Dictionary = seen[key]
		var c: Vector2i = GameState._to_vector2i(e.get("chunk", []), Vector2i(-1, -1))
		if bosques.bosque_at(c) < 0:
			continue
		var bosque_id: int = int(e.get("bosque_id", -1))
		var passive: bool = bosque_id == bosques.home_bosque or open_bosques.has(bosque_id)
		by_chunk[c] = bool(by_chunk.get(c, true)) and passive
	var out: Array[Dictionary] = []
	for c: Vector2i in by_chunk:
		out.append({ "chunk": c, "passive": by_chunk[c] })
	return out


## Chunk de la villa natal (siempre se muestra en el mapa), o (-1, -1) si no hay.
static func home_villa(bosques: BosqueMap) -> Vector2i:
	if bosques.home_bosque < 0:
		return Vector2i(-1, -1)
	return bosques.nujio_chunk[bosques.home_bosque]


## Dirección de la brújula: { "index": 0..7 (ChunkGenerator.direction_index) o HERE, "label" }.
## Apunta al objetivo si lo hay (`objective_chunk` >= 0) y, si no, a la villa natal. Se calcula de
## chunk a chunk; dentro del chunk del objetivo apunta a su casilla si se conoce, y dice "Aquí"
## si el jugador está encima o la casilla es desconocida.
static func compass(bosques: BosqueMap, chunk: Vector2i, cell: Vector2i, objective_chunk: Vector2i,
		objective_cell: Vector2i, objective_label: String) -> Dictionary:
	var target: Vector2i = objective_chunk
	var target_cell: Vector2i = objective_cell
	var label: String = objective_label
	if target.x < 0 or target.y < 0:
		target = home_villa(bosques)
		target_cell = Vector2i(-1, -1)
		label = Texts.get_text("compass_villa")
	if target.x < 0:
		return { "index": HERE, "label": Texts.get_text("compass_here") }
	if target != chunk:
		return { "index": ChunkGenerator.direction_index(target - chunk), "label": label }
	if target_cell.x < 0 or target_cell.y < 0 or target_cell == cell:
		return { "index": HERE, "label": Texts.get_text("compass_here") }
	return { "index": ChunkGenerator.direction_index(target_cell - cell), "label": label }
