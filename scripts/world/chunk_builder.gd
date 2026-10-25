class_name ChunkBuilder
extends RefCounted
## Pasada de chunk del Mundo 2.0 (ADR 0014 §5): convierte un chunk del RegionPlan en un
## WorldChunk nuevo. Hoy (M6) hace los pasos 1 y 2: suelo base, pedregal y relieve. Los puntos de
## interés, la red de senderos, las formas grandes y la decoración llegan en M7–M8.
##
## Relieve (ADR 0014 §3, spec de arte docs/art/specs/mundo-2.md §3):
## - `level[]` = nivel de la celda gruesa (0..3; la cumbre cuenta como 3 y además bloquea entera).
## - Caras hacia el sur: 2 filas por nivel de caída, en las casillas de ARRIBA del nivel de abajo
##   (una caída de 3 niveles ocupa 6 filas, así que sigue en la celda gruesa siguiente).
## - Bordes norte, este y oeste en las casillas del borde de la meseta (nivel de arriba), con la
##   máscara de la spec (1 = norte, 2 = este, 8 = oeste).
## - Cascada: cara cuya celda gruesa y la de la meseta de encima tienen agua. Bloquea.
## - Escaleras y rampas: en las puertas del plan, y donde haga falta para que todas las puertas
##   queden unidas con el hub (provisional hasta la red de senderos de M7). Solo se convierten
##   caras enteras dentro del chunk, así que dos chunks vecinos nunca se contradicen.
## Por construcción, dos casillas transitables de distinto nivel no son vecinas ortogonales salvo
## por una escalera o una rampa (lo verifica tests/unit/world/test_relief.gd).
##
## Capas de dibujo: `variant` de una casilla con risco codifica la pieza (ver VARIANT_*); en las
## casillas sin risco queda para la variante de suelo de M8. `decor` lleva las sombras de la capa 2
## (Decor), porque una casilla solo tiene una pieza en esa capa (spec §3.6).
##
## Apto para hilos: solo lee el RegionPlan (inmutable), crea su propio FastNoiseLite y sus
## arreglos de trabajo, no usa randi() ni GameState y no toca el árbol de escena. El resultado
## depende solo de (plan, coord): da igual el orden o el hilo en que se construya.

## Piezas de la capa 2 (`WorldChunk.decor`). Se amplía añadiendo valores al final.
enum Decor { NONE, SHADOW_FOOT, SHADOW_EAST }

## Versión de la salida del ChunkBuilder: súbela con cualquier cambio que altere los bytes de un
## chunk. WorldCache la combina con RegionPlan.GENERATOR_VERSION y WorldChunk.FORMAT_VERSION
## (combined_generator_version), así que invalida la caché. Cabe en 16 bits.
const VERSION: int = 1

const SIZE: int = WorldCoords.CHUNK
const LAST: int = SIZE - 1
const MACRO: int = WorldCoords.MACRO
const MACROS: int = WorldCoords.MACROS_PER_CHUNK
## Filas de cara por nivel de caída (32 px por nivel).
const FACE_ROWS_PER_LEVEL: int = 2

## Máscara de borde (spec §3.2, bits de la 0.3). La cumbre usa EDGE_PEAK (máscara sin uso).
const EDGE_N: int = 1
const EDGE_E: int = 2
const EDGE_W: int = 8
const EDGE_SIDES: int = EDGE_E | EDGE_W
const EDGE_PEAK: int = 15

## `variant` de las caras, cascadas y escaleras: fila | (columna << VARIANT_COLUMN_SHIFT).
const VARIANT_COLUMN_SHIFT: int = 2
const ROW_LIP: int = 0
const ROW_MIDDLE: int = 1
const ROW_BASE: int = 2
## Columnas de una cara (spec §3.1): extremos, tres medios que alternan por hash y suelto.
const FACE_END_LEFT: int = 0
const FACE_MIDDLE_A: int = 1
const FACE_END_RIGHT: int = 4
const FACE_SINGLE: int = 5
const FACE_MIDDLES: int = 3
## Columnas de escaleras y cascadas (spec §3.4 y §3.5).
const COLUMN_LEFT: int = 0
const COLUMN_MIDDLE: int = 1
const COLUMN_RIGHT: int = 2
## `variant` de bordes y rampas: la máscara (EDGE_*).

## Parámetros de suelo por defecto; la región los cambia con su bloque "chunk_ground".
## rocky_by_level: umbral del ruido de pedregal por nivel (por encima, pedregal; ≥ 1, nunca).
const DEFAULT_GROUND: Dictionary = {
	"rocky_frequency": 0.045,
	"rocky_by_level": [1.0, 0.6, 0.3, -0.05],
}
## Suelo de cada valor de RegionAuthoring.Water.
const WATER_GROUND: Array[int] = [
	WorldChunk.Ground.GRASS, WorldChunk.Ground.RIVER_NAVIGABLE, WorldChunk.Ground.RIVER_NARROW,
	WorldChunk.Ground.LAKE, WorldChunk.Ground.SEA, WorldChunk.Ground.FORD,
]
## Riscos que se pisan (bit = valor de WorldChunk.Cliff).
const CLIFF_OPEN: int = (1 << WorldChunk.Cliff.NONE) | (1 << WorldChunk.Cliff.STAIRS) \
		| (1 << WorldChunk.Cliff.RAMP)

## Coste de la búsqueda de escaleras: casilla normal, casilla de agua (M7 pondrá el puente) y
## casilla de risco que se convertiría en escalera o rampa.
const COST_STEP: int = 1
const COST_WATER: int = 4
const COST_CLIFF: int = 6
## Hacia dónde se ensancha una escalera o rampa (a 2 casillas, como un sendero).
const WIDEN_STEPS: Array[int] = [1, -1]

## Celdas gruesas de margen alrededor del chunk: 3 al norte (una caída de 3 niveles baja 6 filas
## y la casilla de margen del norte necesita su origen), 2 a los lados y 1 al sur.
const PAD_W: int = 2
const PAD_N: int = 3
const MACRO_W: int = MACROS + 2 * PAD_W
const MACRO_H: int = MACROS + PAD_N + 1
## Casillas con 1 de margen alrededor (vecinos de las del borde del chunk).
const TILE_W: int = SIZE + 2

const SALT_ROCKY: int = 140
const SALT_FACE_COLUMN: int = 141


## Construye el chunk `coord` del plan. Nunca devuelve null.
static func build(plan: RegionPlan, coord: Vector2i) -> WorldChunk:
	return _Build.new(plan, coord).run()


## Estado de una construcción: todo lo mutable vive aquí, uno por llamada.
class _Build:
	var plan: RegionPlan
	var coord: Vector2i
	var chunk: WorldChunk
	# Celdas gruesas con margen (MACRO_W × MACRO_H).
	var m_level := PackedByteArray()
	var m_peak := PackedByteArray()
	var m_water := PackedByteArray()
	var m_face_rows := PackedByteArray() # filas de cara arriba de la celda (0..4)
	var m_face_start := PackedByteArray() # fila de la cara en la que empieza la celda (0 o 4)
	var m_face_len := PackedByteArray() # filas de la cara entera (2 por nivel de caída)
	var m_face_wet := PackedByteArray() # cascada
	# Casillas con margen (TILE_W × TILE_W): relieve antes de escaleras y rampas.
	var t_cliff := PackedByteArray()
	var t_aux := PackedByteArray() # cara: fila dentro de la cara; borde: máscara
	var t_len := PackedByteArray() # cara: filas de la cara entera
	# Búsqueda.
	var has_relief: bool = false
	var reached := PackedByteArray()
	var cost_h := PackedByteArray()
	var cost_v := PackedByteArray()
	var dist := PackedInt32Array()
	var prev := PackedInt32Array()
	var heap := PackedInt32Array()
	var heap_size: int = 0
	var queue := PackedInt32Array()

	func _init(p: RegionPlan, c: Vector2i) -> void:
		plan = p
		coord = c

	func run() -> WorldChunk:
		chunk = WorldChunk.new()
		chunk.seed_value = plan.seed_value
		chunk.coord = coord
		_load_macros()
		_classify()
		_fill()
		var required: PackedInt32Array = _open_doors()
		_place_hub()
		_connect(required)
		_paint_variants()
		_paint_shadows()
		chunk.rebuild_blocked()
		return chunk

	# --- Celdas gruesas -------------------------------------------------------------------------

	func _load_macros() -> void:
		var n: int = MACRO_W * MACRO_H
		m_level.resize(n)
		m_peak.resize(n)
		m_water.resize(n)
		m_face_rows.resize(n)
		m_face_start.resize(n)
		m_face_len.resize(n)
		m_face_wet.resize(n)
		var origin: Vector2i = coord * MACROS
		var max_x: int = plan.size_macro.x - 1
		var max_y: int = plan.size_macro.y - 1
		for j: int in MACRO_H:
			# Fuera de la región se repite la última celda: el borde de la región es llano.
			var my: int = clampi(origin.y + j - PAD_N, 0, max_y)
			for i: int in MACRO_W:
				var m := Vector2i(clampi(origin.x + i - PAD_W, 0, max_x), my)
				var level: int = plan.level_at(m)
				var k: int = j * MACRO_W + i
				m_peak[k] = 1 if level == RegionPlan.LEVEL_PEAK else 0
				m_level[k] = mini(level, RegionPlan.LEVEL_MAX)
				m_water[k] = plan.water_at(m)
		var max_rows: int = FACE_ROWS_PER_LEVEL * RegionPlan.LEVEL_MAX
		for j: int in range(2, MACRO_H):
			for i: int in MACRO_W:
				var k: int = j * MACRO_W + i
				if m_peak[k] == 1:
					continue
				var low: int = m_level[k]
				var north: int = m_level[k - MACRO_W]
				var source: int = -1
				if north > low:
					m_face_len[k] = (north - low) * FACE_ROWS_PER_LEVEL
					m_face_rows[k] = mini(m_face_len[k], MACRO)
					source = k - MACRO_W
				elif north == low and max_rows > MACRO:
					# Una caída de más de 2 niveles sigue en esta celda.
					var len: int = (m_level[k - 2 * MACRO_W] - low) * FACE_ROWS_PER_LEVEL
					if len > MACRO:
						m_face_len[k] = len
						m_face_rows[k] = len - MACRO
						m_face_start[k] = MACRO
						source = k - 2 * MACRO_W
				if source >= 0 and m_water[k] != RegionAuthoring.Water.NONE \
						and m_water[source] != RegionAuthoring.Water.NONE:
					m_face_wet[k] = 1

	# --- Relieve por casilla (con 1 de margen) --------------------------------------------------

	func _classify() -> void:
		var n: int = TILE_W * TILE_W
		t_cliff.resize(n)
		t_aux.resize(n)
		t_len.resize(n)
		var col_macro := PackedInt32Array()
		var col_rx := PackedInt32Array()
		col_macro.resize(TILE_W)
		col_rx.resize(TILE_W)
		for t: int in TILE_W:
			var mx: int = WorldCoords.floor_div(t - 1, MACRO)
			col_macro[t] = mx + PAD_W
			col_rx[t] = t - 1 - mx * MACRO
		for ty: int in TILE_W:
			var my: int = WorldCoords.floor_div(ty - 1, MACRO)
			var ry: int = ty - 1 - my * MACRO
			var row_k: int = (my + PAD_N) * MACRO_W
			var row_t: int = ty * TILE_W
			for tx: int in TILE_W:
				var k: int = row_k + col_macro[tx]
				var t: int = row_t + tx
				if m_peak[k] == 1:
					t_cliff[t] = WorldChunk.Cliff.EDGE
					t_aux[t] = EDGE_PEAK
					continue
				if ry < m_face_rows[k]:
					t_cliff[t] = WorldChunk.Cliff.WATERFALL if m_face_wet[k] == 1 else WorldChunk.Cliff.FACE
					t_aux[t] = m_face_start[k] + ry
					t_len[t] = m_face_len[k]
					continue
				var level: int = m_level[k]
				var mask: int = 0
				if ry == 0 and m_level[k - MACRO_W] < level:
					mask |= EDGE_N
				var rx: int = col_rx[tx]
				if rx == MACRO - 1 and m_level[k + 1] < level:
					mask |= EDGE_E
				if rx == 0 and m_level[k - 1] < level:
					mask |= EDGE_W
				if mask != 0:
					t_cliff[t] = WorldChunk.Cliff.EDGE
					t_aux[t] = mask

	## Suelo base, pedregal, nivel y riscos del chunk desde las capas con margen.
	func _fill() -> void:
		var params: Dictionary = DEFAULT_GROUND.merged(plan.region_params.get("chunk_ground", {}), true)
		var rocky: Array = params.rocky_by_level
		var thresholds := PackedFloat32Array()
		thresholds.resize(RegionPlan.LEVEL_MAX + 1)
		var any_rocky: bool = false
		for l: int in thresholds.size():
			thresholds[l] = float(rocky[mini(l, rocky.size() - 1)])
			any_rocky = any_rocky or thresholds[l] < 1.0
		var noise: FastNoiseLite = ChunkGenerator._make_noise(
				ChunkGenerator.hash_ints([plan.plan_seed, SALT_ROCKY]), float(params.rocky_frequency), 2)
		var wx0: int = coord.x * SIZE
		var wy0: int = coord.y * SIZE
		for y: int in SIZE:
			var my: int = y / MACRO + PAD_N
			var row_t: int = (y + 1) * TILE_W + 1
			var row_c: int = y * SIZE
			for x: int in SIZE:
				var k: int = my * MACRO_W + x / MACRO + PAD_W
				var c: int = row_c + x
				var level: int = m_level[k]
				chunk.level[c] = level
				var cliff: int = t_cliff[row_t + x]
				chunk.cliff[c] = cliff
				has_relief = has_relief or cliff != WorldChunk.Cliff.NONE
				var water: int = m_water[k]
				if water != RegionAuthoring.Water.NONE:
					chunk.ground[c] = WATER_GROUND[water]
				elif any_rocky and thresholds[level] < 1.0 \
						and noise.get_noise_2d(wx0 + x, wy0 + y) > thresholds[level]:
					chunk.ground[c] = WorldChunk.Ground.ROCKY

	# --- Puertas, hub y conexión -----------------------------------------------------------------

	## Abre las casillas de cada puerta (escalera o rampa si caen en un risco). Devuelve las
	## casillas de las puertas (índices del chunk), que tienen que quedar unidas al hub.
	func _open_doors() -> PackedInt32Array:
		var required := PackedInt32Array()
		for side: Vector2i in WorldChunk.SIDES:
			if not plan.has_door(coord, side):
				continue
			var door: Dictionary = plan.door(coord, side)
			var along: Vector2i = Vector2i.DOWN if side.x != 0 else Vector2i.RIGHT
			var first: Vector2i = door.cell
			for k: int in int(door.width):
				var cell: Vector2i = first + along * k
				var i: int = cell.y * SIZE + cell.x
				var cliff: int = chunk.cliff[i]
				if cliff == WorldChunk.Cliff.FACE:
					_stairs_column(i)
				elif cliff == WorldChunk.Cliff.EDGE and _aux(i) != EDGE_PEAK:
					_open_cell(i, WorldChunk.Cliff.RAMP)
				required.append(i)
		return required

	## La casilla transitable más cercana al centro (en M7 el hub pasa al ancla del chunk). Busca
	## por anillos (Chebyshev) y, dentro del primero con alguna, la más cercana en línea recta.
	func _place_hub() -> void:
		var center: Vector2i = WorldChunk.center()
		for r: int in SIZE / 2 + 1:
			var best: int = -1
			var best_d: int = 1 << 30
			for y: int in range(maxi(center.y - r, 0), mini(center.y + r, LAST) + 1):
				var dy: int = y - center.y
				var step: int = 1 if absi(dy) == r else maxi(2 * r, 1)
				for x: int in range(center.x - r, center.x + r + 1, step):
					if x < 0 or x > LAST:
						continue
					var i: int = y * SIZE + x
					if (CLIFF_OPEN >> chunk.cliff[i]) & 1 == 0 or (WorldChunk.GROUND_BLOCKING >> chunk.ground[i]) & 1 == 1:
						continue
					var dx: int = x - center.x
					var d: int = dx * dx + dy * dy
					if d < best_d:
						best_d = d
						best = i
			if best >= 0:
				chunk.hub = Vector2i(best % SIZE, best / SIZE)
				return

	## Pone escaleras y rampas hasta que todas las puertas abiertas se alcanzan desde el hub (el
	## agua cuenta como abierta: los puentes son de M7).
	func _connect(required: PackedInt32Array) -> void:
		if not has_relief:
			return # Sin riscos todo está unido (el agua no corta).
		reached.resize(WorldChunk.CELLS)
		queue.resize(WorldChunk.CELLS)
		_build_costs()
		var flooded: bool = false
		for r: int in required:
			if (CLIFF_OPEN >> chunk.cliff[r]) & 1 == 0:
				continue # Cumbre o cascada: no hay paso posible.
			if not flooded:
				_flood()
				flooded = true
			if reached[r] == 1:
				continue
			if dist.is_empty():
				dist.resize(WorldChunk.CELLS)
				prev.resize(WorldChunk.CELLS)
				heap.resize(WorldChunk.CELLS)
			var end: int = _search(r)
			if end >= 0:
				_carve(end)
				flooded = false

	## Coste de entrar o salir de cada casilla en horizontal y en vertical (0 = imposible). Una
	## cara se cruza en vertical y solo si cabe entera en el chunk; un borde, en el eje de su
	## máscara; cumbres y cascadas, nunca.
	func _build_costs() -> void:
		cost_h.resize(WorldChunk.CELLS)
		cost_v.resize(WorldChunk.CELLS)
		for i: int in WorldChunk.CELLS:
			var cliff: int = chunk.cliff[i]
			if (CLIFF_OPEN >> cliff) & 1 == 1:
				var c: int = COST_WATER if (WorldChunk.GROUND_BLOCKING >> chunk.ground[i]) & 1 == 1 else COST_STEP
				cost_h[i] = c
				cost_v[i] = c
			elif cliff == WorldChunk.Cliff.FACE:
				var top: int = i / SIZE - _aux(i)
				cost_v[i] = COST_CLIFF if top >= 0 and top + _len(i) - 1 <= LAST else 0
			elif cliff == WorldChunk.Cliff.EDGE:
				var mask: int = _aux(i)
				if mask != EDGE_PEAK:
					cost_v[i] = COST_CLIFF if mask & EDGE_N != 0 else 0
					cost_h[i] = COST_CLIFF if mask & EDGE_SIDES != 0 else 0

	## Casillas alcanzables desde el hub sin cruzar riscos (el agua no corta).
	func _flood() -> void:
		reached.fill(0)
		var start: int = chunk.hub.y * SIZE + chunk.hub.x
		if (CLIFF_OPEN >> chunk.cliff[start]) & 1 == 0:
			return
		reached[start] = 1
		queue[0] = start
		var head: int = 0
		var tail: int = 1
		while head < tail:
			var i: int = queue[head]
			head += 1
			var x: int = i % SIZE
			var n: int = i - 1
			if x > 0 and reached[n] == 0 and (CLIFF_OPEN >> chunk.cliff[n]) & 1 == 1:
				reached[n] = 1
				queue[tail] = n
				tail += 1
			n = i + 1
			if x < LAST and reached[n] == 0 and (CLIFF_OPEN >> chunk.cliff[n]) & 1 == 1:
				reached[n] = 1
				queue[tail] = n
				tail += 1
			n = i - SIZE
			if n >= 0 and reached[n] == 0 and (CLIFF_OPEN >> chunk.cliff[n]) & 1 == 1:
				reached[n] = 1
				queue[tail] = n
				tail += 1
			n = i + SIZE
			if n < WorldChunk.CELLS and reached[n] == 0 and (CLIFF_OPEN >> chunk.cliff[n]) & 1 == 1:
				reached[n] = 1
				queue[tail] = n
				tail += 1

	## Dijkstra desde la puerta `start` hasta lo ya alcanzado desde el hub. Devuelve la primera
	## casilla alcanzada (su cadena `prev` lleva a la puerta) o -1.
	func _search(start: int) -> int:
		dist.fill(1 << 30)
		prev.fill(-1)
		heap_size = 0
		dist[start] = 0
		_push(start)
		while heap_size > 0:
			var top: int = _pop()
			var d: int = top >> 13
			var i: int = top & 8191
			if d != dist[i]:
				continue
			if reached[i] == 1:
				return i
			var x: int = i % SIZE
			if cost_h[i] > 0:
				if x > 0:
					_relax(i, i - 1, d, cost_h[i - 1])
				if x < LAST:
					_relax(i, i + 1, d, cost_h[i + 1])
			if cost_v[i] > 0:
				if i >= SIZE:
					_relax(i, i - SIZE, d, cost_v[i - SIZE])
				if i < WorldChunk.CELLS - SIZE:
					_relax(i, i + SIZE, d, cost_v[i + SIZE])
		return -1

	func _relax(from: int, to: int, d: int, cost: int) -> void:
		if cost > 0 and d + cost < dist[to]:
			dist[to] = d + cost
			prev[to] = from
			_push(to)

	## Convierte en escalera o rampa los riscos del camino de `end` a la puerta.
	func _carve(end: int) -> void:
		var i: int = end
		while i >= 0:
			var next: int = prev[i]
			var cliff: int = chunk.cliff[i]
			if cliff == WorldChunk.Cliff.FACE:
				_stairs_column(i)
				_widen_stairs(i)
			elif cliff == WorldChunk.Cliff.EDGE:
				# Un borde siempre está entre dos casillas del camino: los extremos están abiertos.
				_open_cell(i, WorldChunk.Cliff.RAMP)
				_widen_ramp(i, absi(next - i) == SIZE)
			i = next

	## Abre una casilla de risco (escalera o rampa) y actualiza sus costes si ya existen.
	func _open_cell(i: int, cliff: int) -> void:
		chunk.cliff[i] = cliff
		if not cost_h.is_empty():
			var c: int = COST_WATER if (WorldChunk.GROUND_BLOCKING >> chunk.ground[i]) & 1 == 1 else COST_STEP
			cost_h[i] = c
			cost_v[i] = c

	## La columna entera de la cara de `i` (dentro del chunk) pasa a escalera.
	func _stairs_column(i: int) -> void:
		var x: int = i % SIZE
		var top: int = i / SIZE - _aux(i)
		var bottom: int = top + _len(i) - 1
		for y: int in range(maxi(top, 0), mini(bottom, LAST) + 1):
			var c: int = y * SIZE + x
			if chunk.cliff[c] == WorldChunk.Cliff.FACE:
				_open_cell(c, WorldChunk.Cliff.STAIRS)

	## Segunda columna de escalera al lado (sendero de 2), si la cara vecina es igual y tiene
	## suelo abierto arriba y abajo.
	func _widen_stairs(i: int) -> void:
		var x: int = i % SIZE
		var top: int = i / SIZE - _aux(i)
		var bottom: int = top + _len(i) - 1
		if top < 1 or bottom > LAST - 1:
			return
		for step: int in WIDEN_STEPS:
			var nx: int = x + step
			if nx < 0 or nx > LAST:
				continue
			var n: int = i + step
			if chunk.cliff[n] != WorldChunk.Cliff.FACE or _aux(n) != _aux(i) or _len(n) != _len(i):
				continue
			if chunk.cliff[(top - 1) * SIZE + nx] != WorldChunk.Cliff.NONE \
					or chunk.cliff[(bottom + 1) * SIZE + nx] != WorldChunk.Cliff.NONE:
				continue
			_stairs_column(n)
			return

	## Segunda casilla de rampa a lo largo del borde (sendero de 2), si tiene la misma máscara.
	func _widen_ramp(i: int, vertical: bool) -> void:
		var x: int = i % SIZE
		var y: int = i / SIZE
		for step: int in WIDEN_STEPS:
			var n: int = -1
			if vertical and x + step >= 0 and x + step <= LAST:
				n = i + step
			elif not vertical and y + step >= 0 and y + step <= LAST:
				n = i + step * SIZE
			if n >= 0 and chunk.cliff[n] == WorldChunk.Cliff.EDGE and _aux(n) == _aux(i):
				_open_cell(n, WorldChunk.Cliff.RAMP)
				return

	# --- Piezas de dibujo ------------------------------------------------------------------------

	func _paint_variants() -> void:
		var middles := PackedByteArray()
		middles.resize(SIZE)
		var wx0: int = coord.x * SIZE
		for x: int in SIZE:
			middles[x] = FACE_MIDDLE_A + ChunkGenerator.hash_ints([plan.plan_seed, wx0 + x, SALT_FACE_COLUMN]) % FACE_MIDDLES
		for y: int in SIZE:
			for x: int in SIZE:
				var i: int = y * SIZE + x
				var cliff: int = chunk.cliff[i]
				if cliff == WorldChunk.Cliff.NONE:
					continue
				if cliff == WorldChunk.Cliff.EDGE or cliff == WorldChunk.Cliff.RAMP:
					chunk.variant[i] = _aux(i)
					continue
				var pos: int = _aux(i)
				var row: int = ROW_LIP if pos == 0 else (ROW_BASE if pos == _len(i) - 1 else ROW_MIDDLE)
				var left: bool = _cliff_at(x - 1, y) == cliff
				var right: bool = _cliff_at(x + 1, y) == cliff
				var column: int
				if cliff == WorldChunk.Cliff.FACE:
					if left and right:
						column = middles[x]
					elif right:
						column = FACE_END_LEFT
					elif left:
						column = FACE_END_RIGHT
					else:
						column = FACE_SINGLE
				else:
					column = COLUMN_MIDDLE if left == right else (COLUMN_LEFT if right else COLUMN_RIGHT)
				chunk.variant[i] = row | (column << VARIANT_COLUMN_SHIFT)

	## Sombra al pie de las caras y al este de los bordes este (capa 2). Fuera del chunk se mira el
	## relieve del margen.
	func _paint_shadows() -> void:
		for y: int in SIZE:
			var row_t: int = (y + 1) * TILE_W + 1
			for x: int in SIZE:
				var i: int = y * SIZE + x
				if chunk.cliff[i] != WorldChunk.Cliff.NONE:
					continue
				var north: int = row_t + x - TILE_W
				var north_cliff: int = chunk.cliff[i - SIZE] if y > 0 else t_cliff[north]
				if north_cliff == WorldChunk.Cliff.FACE and t_aux[north] == t_len[north] - 1:
					chunk.decor[i] = Decor.SHADOW_FOOT
					continue
				var west: int = row_t + x - 1
				var west_cliff: int = chunk.cliff[i - 1] if x > 0 else t_cliff[west]
				var mask: int = t_aux[west]
				if west_cliff == WorldChunk.Cliff.EDGE and mask != EDGE_PEAK and mask & EDGE_E != 0:
					chunk.decor[i] = Decor.SHADOW_EAST

	# --- Ayudas ----------------------------------------------------------------------------------

	## Risco de una casilla del chunk o de su margen (el margen, sin escaleras de los vecinos).
	func _cliff_at(x: int, y: int) -> int:
		if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
			return chunk.cliff[y * SIZE + x]
		return t_cliff[(y + 1) * TILE_W + x + 1]

	func _aux(i: int) -> int:
		return t_aux[(i / SIZE + 1) * TILE_W + i % SIZE + 1]

	func _len(i: int) -> int:
		return t_len[(i / SIZE + 1) * TILE_W + i % SIZE + 1]

	# Montículo binario de (distancia << 13 | casilla).
	func _push(i: int) -> void:
		var value: int = (dist[i] << 13) | i
		var k: int = heap_size
		heap_size += 1
		if heap_size > heap.size():
			heap.resize(heap_size * 2)
		while k > 0:
			var parent: int = (k - 1) >> 1
			if heap[parent] <= value:
				break
			heap[k] = heap[parent]
			k = parent
		heap[k] = value

	func _pop() -> int:
		var top: int = heap[0]
		heap_size -= 1
		var last: int = heap[heap_size]
		var k: int = 0
		while true:
			var child: int = 2 * k + 1
			if child >= heap_size:
				break
			if child + 1 < heap_size and heap[child + 1] < heap[child]:
				child += 1
			if heap[child] >= last:
				break
			heap[k] = heap[child]
			k = child
		heap[k] = last
		return top
