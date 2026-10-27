class_name MapLogic
extends RefCounted
## Lógica pura del mapa de la región (tecla M) y de la brújula del HUD (navegacion.md): qué chunks
## se han explorado y se ven, qué se dibuja encima y hacia dónde apunta la brújula. Sin nodos:
## la usan RegionMap, Compass y la exploración (para marcar chunks) y se prueba con GUT.
## No dibuja ni guarda: solo lee y modifica los arrays que recibe.
## Mundo 2.0 (ADR 0014 §7, M16): con un RegionPlan registrado (set_region_plan), el mapa dibuja una
## vista de la región (region_image) y la brújula apunta a un `world_pos` exacto (compass_world).
## Sin plan (mundo viejo, hasta M17), todo sigue como antes: cuadros de color y brújula por chunks.

## Índice de brújula cuando el jugador ya está en el objetivo ("Aquí").
const HERE: int = -1

# --- Vista de la región (ADR 0014 §7) ---
## Píxeles del mapa por chunk (el mismo lado que la celda de la rejilla vieja: la región de 12×16
## chunks ocupa 120×160 px en las dos vistas).
const PX_PER_CHUNK: int = 10
## Celdas gruesas por píxel del mapa (20 por chunk / 10 px).
const MACROS_PER_PX: int = WorldCoords.MACROS_PER_CHUNK / PX_PER_CHUNK
## Píxeles del mundo por píxel del mapa (1280 / 10 = 128).
const WORLD_PX_PER_MAP_PX: int = WorldCoords.CHUNK_PX / PX_PER_CHUNK
## Tonos de altura (paleta del juego): niveles 0..3 y cumbre (RegionPlan.LEVEL_PEAK).
const HEIGHT_COLORS: Array[Color] = [
	Color("265c42"), Color("3e8948"), Color("63c74d"), Color("c28569"), Color("c0cbdc"),
]
## Agua por tipo (RegionAuthoring.Water).
const WATER_COLORS: Dictionary = {
	RegionAuthoring.Water.RIVER_NAVIGABLE: Color("0099db"),
	RegionAuthoring.Water.RIVER_NARROW: Color("2ce8f5"),
	RegionAuthoring.Water.LAKE: Color("0099db"),
	RegionAuthoring.Water.SEA: Color("124e89"),
	RegionAuthoring.Water.FORD: Color("8b9bb4"),
}
## Camino y puente (RegionAuthoring.Road). La red procedural usa el color del camino.
const ROAD_COLORS: Dictionary = {
	RegionAuthoring.Road.ROAD: Color("e8b796"),
	RegionAuthoring.Road.BRIDGE: Color("ead4aa"),
}
## Línea de 1 px entre chunks de Bosques distintos.
const BORDER_COLOR := Color("181425")
## Cuánto tiñe el color de hoja del Bosque la altura (0 = nada). Bosque muerto: gris.
const LEAF_TINT: float = 0.25
const DEAD_TINT := Color("8b9bb4")
const DEAD_TINT_WEIGHT: float = 0.6
## Oscurecido del borde sur de un escalón (la cara del risco mira al sur).
const RELIEF_SHADE: float = 0.35
## Lugares de lugares.csv que se dibujan aparte de las villas (manantial: sin rótulo, no cabe).
const PLACE_TYPES: Array[String] = ["tarca", "hito", "lugar", "manantial"]
const UNLABELED_TYPES: Array[String] = ["manantial"]
## Distancia (píxeles del mapa) entre el punto del lugar y su rótulo.
const LABEL_GAP: int = 3

# --- Brújula en píxeles ---
## A menos de esta distancia (píxeles del mundo) del objetivo, la brújula dice "Aquí".
const HERE_RADIUS_PX: float = WorldCoords.TILE

static var _map: BosqueMap
static var _map_key: String = ""
static var _plan: RegionPlan = null
## Pies del jugador en píxeles del mundo (los fija la exploración del Mundo 2.0 cada tick de
## física). NAN = sin jugador: se usa el centro de GameState.chunk_coord + player_cell.
static var _player_pos: Vector2 = Vector2(NAN, NAN)


## Registra el RegionPlan de la partida (o null para volver al mundo viejo). Lo hará la
## exploración del Mundo 2.0 (M17) al crear o cargar la partida.
static func set_region_plan(plan: RegionPlan) -> void:
	_plan = plan


## Pies del jugador en píxeles del mundo (brújula). La exploración los fija; NAN los olvida.
static func set_player_pos(pos: Vector2) -> void:
	_player_pos = pos


## Pies del jugador: los fijados con set_player_pos o, si no hay, el centro de la casilla de
## GameState (chunk_coord + player_cell).
static func player_pos() -> Vector2:
	if not is_nan(_player_pos.x):
		return _player_pos
	return WorldCoords.cell_to_world_pos(GameState.chunk_coord, GameState.player_cell)


## Plan de la partida actual, o null si el juego aún usa el mundo viejo.
static func region_plan() -> RegionPlan:
	return _plan


## Reparto en Bosques de la partida actual (seed + región), en caché mientras no cambien. Con
## RegionPlan, el suyo.
static func current_bosques() -> BosqueMap:
	if _plan != null:
		return _plan.bosques
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


## Estado de los Bosques explorados que no están sanos (bosques-y-relacion.md: "El letrero y el
## mapa (M) podrían indicar el estado"): { Vector2i chunk explorado: estado } (BosqueStates).
static func visible_states(bosques: BosqueMap, explored: Array[Vector2i]) -> Dictionary:
	var out: Dictionary = {}
	for c: Vector2i in visible_cells(bosques, explored):
		var state: String = BosqueStates.state_of(bosques.bosque_at(c), bosques)
		if state != "" and state != BosqueStates.SANO:
			out[c] = state
	return out


## Chunk de la villa natal (siempre se muestra en el mapa), o (-1, -1) si no hay.
static func home_villa(bosques: BosqueMap) -> Vector2i:
	if bosques.home_bosque < 0:
		return Vector2i(-1, -1)
	return bosques.nujio_chunk[bosques.home_bosque]


# ponytail: borrar en M17 (la sustituye compass_world).
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


# --- Vista de la región (Mundo 2.0) -------------------------------------------------------------

## Esquina superior izquierda del chunk en el mapa (píxeles, relativos al origen de la rejilla).
static func chunk_to_map_px(chunk: Vector2i) -> Vector2i:
	return chunk * PX_PER_CHUNK


## Chunk bajo un píxel del mapa (relativo al origen de la rejilla).
static func map_px_to_chunk(px: Vector2i) -> Vector2i:
	return WorldCoords.floor_div_v(px, PX_PER_CHUNK)


## Píxel del mapa de una celda gruesa.
static func macro_to_map_px(macro: Vector2i) -> Vector2i:
	return WorldCoords.floor_div_v(macro, MACROS_PER_PX)


## Punto del mapa (con decimales) de una posición del mundo.
static func world_pos_to_map_px(world_pos: Vector2) -> Vector2:
	return world_pos / float(WORLD_PX_PER_MAP_PX)


## Color de un píxel del terreno: el camino tapa al agua y el agua a la altura; la altura lleva el
## velo del color de hoja de su Bosque (`leaf`, transparente = sin Bosque) o el gris si está muerto.
static func terrain_color(level: int, water: int, road: int, leaf: Color = Color(0, 0, 0, 0), dead: bool = false) -> Color:
	if road != RegionAuthoring.Road.NONE:
		return ROAD_COLORS.get(road, ROAD_COLORS[RegionAuthoring.Road.ROAD])
	if water != RegionAuthoring.Water.NONE:
		return WATER_COLORS.get(water, WATER_COLORS[RegionAuthoring.Water.RIVER_NAVIGABLE])
	var color: Color = HEIGHT_COLORS[clampi(level, 0, HEIGHT_COLORS.size() - 1)]
	if dead:
		return color.lerp(DEAD_TINT, DEAD_TINT_WEIGHT)
	if leaf.a > 0.0:
		return color.lerp(Color(leaf, 1.0), LEAF_TINT)
	return color


## Imagen de la región a PX_PER_CHUNK píxeles por chunk: altura en tonos con su sombra al sur,
## agua, caminos pintados y de la red procedural, y la frontera entre Bosques. Cada píxel resume
## MACROS_PER_PX × MACROS_PER_PX celdas gruesas: el camino y el agua ganan si hay alguno (los ríos
## de una celda no desaparecen) y la altura es la mayor. Se genera una vez por plan (son ~77 000
## consultas: no es para cada fotograma).
static func region_image(plan: RegionPlan) -> Image:
	var size: Vector2i = plan.size_chunks * PX_PER_CHUNK
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var levels := PackedInt32Array()
	levels.resize(size.x * size.y)
	var flat := PackedByteArray()  # 1 = agua o camino (sin sombra de relieve)
	flat.resize(size.x * size.y)
	var map: BosqueMap = plan.bosques
	var n: int = MACROS_PER_PX
	for y: int in size.y:
		for x: int in size.x:
			var level: int = -1
			var water: int = RegionAuthoring.Water.NONE
			var road: int = RegionAuthoring.Road.NONE
			for dy: int in n:
				for dx: int in n:
					var m := Vector2i(x * n + dx, y * n + dy)
					level = maxi(level, plan.level_at(m))
					water = _stronger_water(water, plan.water_at(m))
					road = maxi(road, plan.road_at(m))
			var b: int = map.bosque_at(map_px_to_chunk(Vector2i(x, y)))
			var leaf := Color(0, 0, 0, 0)
			var dead: bool = false
			if b >= 0:
				dead = map.state_of(b) == BosqueMap.STATE_MUERTO
				leaf = (PlaceholderTileset.LEAVES[int(map.styles[b].get("leaf", 0))] as Array)[1]
			levels[y * size.x + x] = maxi(level, 0)
			flat[y * size.x + x] = 1 if water != RegionAuthoring.Water.NONE or road != RegionAuthoring.Road.NONE else 0
			img.set_pixel(x, y, terrain_color(maxi(level, 0), water, road, leaf, dead))
	for y: int in size.y - 1:
		for x: int in size.x:
			var i: int = y * size.x + x
			if flat[i] == 0 and levels[i] > levels[i + size.x]:
				img.set_pixel(x, y, img.get_pixel(x, y).darkened(RELIEF_SHADE))
	_draw_procedural_roads(img, plan)
	_draw_bosque_borders(img, map, plan.size_chunks)
	return img


## Lo que más se ve del agua de un píxel: el mar sobre el lago y el lago sobre el río; un vado
## solo si no hay más agua.
static func _stronger_water(a: int, b: int) -> int:
	const RANK: Array[int] = [0, 3, 2, 4, 5, 1]  # NONE, NAVIGABLE, NARROW, LAKE, SEA, FORD
	return b if RANK[b] > RANK[a] else a


## Tramos de la red procedural (lados de chunk sin camino pintado): del centro del chunk a su
## puerta, en L y de 1 px.
static func _draw_procedural_roads(img: Image, plan: RegionPlan) -> void:
	var color: Color = ROAD_COLORS[RegionAuthoring.Road.ROAD]
	var half := Vector2i(PX_PER_CHUNK / 2, PX_PER_CHUNK / 2)
	for cy: int in plan.size_chunks.y:
		for cx: int in plan.size_chunks.x:
			var c := Vector2i(cx, cy)
			for side: Vector2i in plan.road_sides(c):
				var d: Dictionary = plan.door(c, side)
				if d.is_empty() or _painted_side(plan, c, side, d):
					continue
				var door_px: Vector2i = WorldCoords.floor_div_v((d.cell as Vector2i) * PX_PER_CHUNK, WorldCoords.CHUNK)
				_line(img, chunk_to_map_px(c) + half, chunk_to_map_px(c) + door_px, color)


## El lado del chunk lleva camino pintado a los dos lados de la puerta (ya está en la capa).
static func _painted_side(plan: RegionPlan, c: Vector2i, side: Vector2i, d: Dictionary) -> bool:
	var m: int = WorldCoords.MACROS_PER_CHUNK
	var k: int = WorldCoords.floor_div(int(d.index), WorldCoords.MACRO)
	var inside: Vector2i
	if side.x != 0:
		inside = Vector2i(c.x * m + (0 if side.x < 0 else m - 1), c.y * m + k)
	else:
		inside = Vector2i(c.x * m + k, c.y * m + (0 if side.y < 0 else m - 1))
	return plan.road_at(inside) != RegionAuthoring.Road.NONE and plan.road_at(inside + side) != RegionAuthoring.Road.NONE


## Línea en L de 1 px (primero en x, luego en y), recortada a la imagen.
static func _line(img: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	var bounds := Rect2i(Vector2i.ZERO, img.get_size())
	var a := Rect2i(Vector2i(mini(from.x, to.x), from.y), Vector2i(absi(to.x - from.x) + 1, 1)).intersection(bounds)
	var b := Rect2i(Vector2i(to.x, mini(from.y, to.y)), Vector2i(1, absi(to.y - from.y) + 1)).intersection(bounds)
	if a.has_area():
		img.fill_rect(a, color)
	if b.has_area():
		img.fill_rect(b, color)


## Frontera de 1 px en el borde oeste y norte de cada chunk cuyo vecino es de otro Bosque.
static func _draw_bosque_borders(img: Image, map: BosqueMap, chunks: Vector2i) -> void:
	for cy: int in chunks.y:
		for cx: int in chunks.x:
			var c := Vector2i(cx, cy)
			var b: int = map.bosque_at(c)
			var origin: Vector2i = chunk_to_map_px(c)
			if b < 0:
				continue
			var west: int = map.bosque_at(c + Vector2i.LEFT)
			var north: int = map.bosque_at(c + Vector2i.UP)
			if cx > 0 and west >= 0 and west != b:
				img.fill_rect(Rect2i(origin, Vector2i(1, PX_PER_CHUNK)), BORDER_COLOR)
			if cy > 0 and north >= 0 and north != b:
				img.fill_rect(Rect2i(origin, Vector2i(PX_PER_CHUNK, 1)), BORDER_COLOR)


## Villas (natal, ciudades, con nombre y aldeas) y lugares con nombre de la región, en orden de
## prioridad de rótulo: { kind ("villa_natal", "ciudad", "villa", "aldea", "tarca", "hito", "lugar",
## "manantial"), name,
## chunk, macro, px (píxel del mapa), label (bool: lleva rótulo) }.
static func region_places(plan: RegionPlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var villas: Array[Dictionary] = plan.villas()
	for kind: String in ["villa_natal", "ciudad", "villa", "aldea"]:
		for v: Dictionary in villas:
			if v.kind == kind:
				out.append(_place(kind, String(v.name), v.macro))
	var places: Array[Dictionary] = []
	for cy: int in plan.size_chunks.y:
		for cx: int in plan.size_chunks.x:
			places.append_array(plan.places_in_chunk(Vector2i(cx, cy)))
	for kind: String in PLACE_TYPES:
		for p: Dictionary in places:
			if String(p.type) == kind:
				out.append(_place(kind, String(p.name), p.cell))
	return out


static func _place(kind: String, place_name: String, macro: Vector2i) -> Dictionary:
	return { "kind": kind, "name": place_name, "macro": macro,
			"chunk": WorldCoords.floor_div_v(macro, WorldCoords.MACROS_PER_CHUNK), "px": macro_to_map_px(macro),
			"label": not UNLABELED_TYPES.has(kind) and not place_name.is_empty() }


## Lugares que se ven: la villa natal siempre; el resto, si su chunk está explorado.
static func visible_places(places: Array[Dictionary], explored: Array[Vector2i]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in places:
		if p.kind == "villa_natal" or explored.has(p.chunk):
			out.append(p)
	return out


## Coloca los rótulos de `places` (los que llevan label) sin que se pisen ni salgan de `bounds`
## (píxeles del mapa): prueba debajo del punto, encima, a la derecha y a la izquierda; si no cabe
## en ninguno, ese rótulo no se dibuja (los primeros tienen prioridad). Devuelve
## [{ text, kind, at (Vector2i, esquina del primer glifo) }].
static func layout_labels(places: Array[Dictionary], bounds: Rect2i) -> Array[Dictionary]:
	var taken: Array[Rect2i] = []
	var out: Array[Dictionary] = []
	for p: Dictionary in places:
		if not bool(p.label):
			continue
		var text: String = String(p.name)
		var w: int = PixelFont.width_of(text)
		var h: int = PixelFont.GLYPH_H
		var px: Vector2i = p.px
		var tries: Array[Vector2i] = [
			Vector2i(px.x - w / 2, px.y + LABEL_GAP + 1), Vector2i(px.x - w / 2, px.y - LABEL_GAP - h),
			Vector2i(px.x + LABEL_GAP + 2, px.y - h / 2), Vector2i(px.x - LABEL_GAP - 1 - w, px.y - h / 2),
		]
		for at: Vector2i in tries:
			# Dentro del mapa con su contorno de 1 px.
			var clamped := Vector2i(clampi(at.x, bounds.position.x + 1, bounds.end.x - 1 - w),
					clampi(at.y, bounds.position.y + 1, bounds.end.y - 1 - h))
			var box := Rect2i(clamped - Vector2i.ONE, PixelFont.box_size(text))
			var free: bool = true
			for r: Rect2i in taken:
				if r.intersects(box):
					free = false
					break
			if free:
				taken.append(box)
				out.append({ "text": text, "kind": p.kind, "at": clamped })
				break
	return out


# --- Brújula en píxeles (Mundo 2.0) -------------------------------------------------------------

## Ángulo (radianes, 0 = este, positivo hacia el sur) de `from` a `to`, en píxeles del mundo.
static func compass_angle(from: Vector2, to: Vector2) -> float:
	return (to - from).angle()


## Índice de 8 direcciones de un ángulo (como ChunkGenerator.direction_index: 0 = este, sentido
## horario).
static func angle_to_index(angle: float) -> int:
	return posmod(roundi(angle / (PI / 4.0)), 8)


## Brújula hacia un `world_pos` exacto: { "index": 0..7 o HERE, "label", "angle" (radianes) }.
## "Aquí" a menos de HERE_RADIUS_PX.
static func compass_px(player_pos: Vector2, target_pos: Vector2, label: String) -> Dictionary:
	if player_pos.distance_to(target_pos) < HERE_RADIUS_PX:
		return { "index": HERE, "label": Texts.get_text("compass_here"), "angle": 0.0 }
	var angle: float = compass_angle(player_pos, target_pos)
	return { "index": angle_to_index(angle), "label": label, "angle": angle }


## `world_pos` de un objetivo guardado por chunk + casilla (lo que se conserva en el guardado):
## el centro de la casilla, o el del chunk si la casilla es desconocida.
static func objective_world_pos(chunk: Vector2i, cell: Vector2i) -> Vector2:
	if cell.x < 0 or cell.y < 0:
		return Vector2(chunk * WorldCoords.CHUNK_PX) + Vector2.ONE * (WorldCoords.CHUNK_PX * 0.5)
	return WorldCoords.cell_to_world_pos(chunk, cell)


## `world_pos` de la villa natal del plan (centro de su celda gruesa) o, si no hay, del centro de
## home_chunk. Vector2(-1, -1) si el plan no tiene ninguna de las dos.
static func home_world_pos(plan: RegionPlan) -> Vector2:
	for v: Dictionary in plan.villas():
		if v.kind == "villa_natal":
			var origin: Vector2i = WorldCoords.macro_origin(v.macro)
			return WorldCoords.world_cell_origin(origin) + Vector2.ONE * (WorldCoords.MACRO * WorldCoords.TILE * 0.5)
	if plan.home_chunk.x < 0:
		return Vector2(-1, -1)
	return objective_world_pos(plan.home_chunk, Vector2i(-1, -1))


## Brújula del Mundo 2.0: hacia el objetivo (`objective_chunk` >= 0, con su casilla si se conoce) o,
## si no hay, hacia la villa natal del plan. Como la vieja, dentro del chunk de un objetivo de
## casilla desconocida dice "Aquí".
static func compass_world(plan: RegionPlan, player_pos: Vector2, objective_chunk: Vector2i,
		objective_cell: Vector2i, objective_label: String) -> Dictionary:
	if objective_chunk.x >= 0 and objective_chunk.y >= 0:
		if (objective_cell.x < 0 or objective_cell.y < 0) and WorldCoords.world_pos_to_chunk(player_pos) == objective_chunk:
			return { "index": HERE, "label": Texts.get_text("compass_here"), "angle": 0.0 }
		return compass_px(player_pos, objective_world_pos(objective_chunk, objective_cell), objective_label)
	var home: Vector2 = home_world_pos(plan)
	if home.x < 0:
		return { "index": HERE, "label": Texts.get_text("compass_here"), "angle": 0.0 }
	return compass_px(player_pos, home, Texts.get_text("compass_villa"))
