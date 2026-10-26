class_name TacticalArena
extends RefCounted
## Tamaño del tablero y cupo por bando del combate táctico (combate-tactico.md, ADR 0016; PR T1b,
## #188, #189). Lógica pura: no toca GameState ni scripts/world. Números en balance.json
## (tactical.arena).
## - Tamaño: la proporción transitable de un recorte de `sample` (14 x 10) alrededor del encuentro
##   decide: >= large_at, grande (14 x 10); >= medium_at, medio (10 x 8); si no, pequeño (8 x 6).
##   El bioma solo desempata: si la proporción queda a tie_margin o menos de un umbral, gana el
##   tamaño que prefiere el bioma (biome_size) entre los dos de ese umbral.
## - De dónde sale la proporción: sample_ratio con una función `is_walkable(cell) -> bool`
##   inyectable (Crossing la da desde el chunk de exploración) o, en el Mundo 2.0, world_ratio con
##   WorldQuery.rect (casillas cargadas y no bloqueadas). Sin ninguna, biome_ratio del bioma.
## - Cupo por bando = clamp(floor(transitables / (cells_per_unit x 2)), quota_min, quota_max), el
##   mismo para los dos bandos. Con un tablero llano (antes del Mundo 2.0) las transitables se
##   estiman: casillas x max(proporción, min_walkable_ratio), porque el recorte se elige con al
##   menos un 70% transitable (T1). Con un tablero con relieve real, quota_for_board las cuenta.
## - Colocación: 2 columnas por bando en el pequeño y el medio, 3 en el grande (sizes.*.deploy_columns).
## - Latigazo múltiple (T6): área por tamaño (sizes.*.latigazo: 3 x 1 o 3 x 2). Solo el dato.

const SMALL: StringName = &"small"
const MEDIUM: StringName = &"medium"
const LARGE: StringName = &"large"
## Del más pequeño al más grande.
const SIZES: Array[StringName] = [SMALL, MEDIUM, LARGE]
## Valores de respaldo si balance.json no trae el bloque (los mismos que la ficha).
const FALLBACK: Dictionary = {
	"sample": [14, 10], "large_at": 0.8, "medium_at": 0.6, "tie_margin": 0.02, "min_walkable_ratio": 0.7,
	"cells_per_unit": 8, "quota_min": 1, "quota_max": 6,
	"sizes": {
		"small": { "width": 8, "height": 6, "deploy_columns": 2, "latigazo": [3, 1] },
		"medium": { "width": 10, "height": 8, "deploy_columns": 2, "latigazo": [3, 1] },
		"large": { "width": 14, "height": 10, "deploy_columns": 3, "latigazo": [3, 2] },
	},
	"biome_size": {}, "biome_ratio": { "default": 0.65 },
}


## Bloque arena de un bloque tactical (o el de respaldo).
static func arena_cfg(tactical: Dictionary) -> Dictionary:
	var cfg: Dictionary = tactical.get("arena", {})
	return cfg if not cfg.is_empty() else FALLBACK


## Tamaño del recorte que se mira (14 x 10).
static func sample_size(cfg: Dictionary) -> Vector2i:
	var s: Array = cfg.get("sample", [14, 10])
	return Vector2i(int(s[0]), int(s[1]))


## Proporción transitable (0..1) del recorte de `size` centrado en `center` y metido dentro de
## `bounds` (el chunk: el recorte se desplaza si se sale). `is_walkable`: Callable(cell) -> bool.
static func sample_ratio(is_walkable: Callable, center: Vector2i, size: Vector2i, bounds: Rect2i) -> float:
	var rect: Rect2i = sample_rect(center, size, bounds)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return 0.0
	var count: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if bool(is_walkable.call(Vector2i(x, y))):
				count += 1
	return float(count) / float(rect.size.x * rect.size.y)


## Recorte de `size` centrado en `center`, desplazado para quedar dentro de `bounds` (y recortado si
## `bounds` es más pequeño).
static func sample_rect(center: Vector2i, size: Vector2i, bounds: Rect2i) -> Rect2i:
	var w: int = mini(size.x, bounds.size.x)
	var h: int = mini(size.y, bounds.size.y)
	var x: int = clampi(center.x - w / 2, bounds.position.x, bounds.end.x - w)
	var y: int = clampi(center.y - h / 2, bounds.position.y, bounds.end.y - h)
	return Rect2i(x, y, w, h)


## Proporción transitable (0..1) de un recorte del Mundo 2.0 (WorldQuery.Area): casillas cargadas
## que no bloquean. La construcción del tablero desde el Area (riscos comprimidos...) es de T7.
static func area_ratio(area: WorldQuery.Area) -> float:
	var n: int = area.size.x * area.size.y
	if n <= 0:
		return 0.0
	var count: int = 0
	for i: int in n:
		if area.loaded[i] == 1 and area.blocked[i] == 0:
			count += 1
	return float(count) / float(n)


## Proporción transitable del recorte de `size` centrado en `world_cell` del Mundo 2.0.
## `get_chunk`: Callable(chunk_coord) -> WorldChunk (WorldStreamer / WorldPregen).
static func world_ratio(get_chunk: Callable, world_cell: Vector2i, size: Vector2i) -> float:
	return area_ratio(WorldQuery.rect(get_chunk, world_cell - size / 2, size))


## Proporción transitable típica de un bioma, cuando no hay recorte que leer.
static func biome_ratio(biome: StringName, cfg: Dictionary) -> float:
	var table: Dictionary = cfg.get("biome_ratio", {})
	return float(table.get(String(biome), table.get("default", 0.65)))


## Tamaño del tablero por la proporción transitable; el bioma solo desempata cerca de un umbral.
static func size_for_ratio(ratio: float, cfg: Dictionary, biome: StringName = &"") -> StringName:
	var large_at: float = float(cfg.get("large_at", 0.8))
	var medium_at: float = float(cfg.get("medium_at", 0.6))
	var margin: float = float(cfg.get("tie_margin", 0.0))
	var by_ratio: StringName = LARGE if ratio >= large_at else (MEDIUM if ratio >= medium_at else SMALL)
	var prefer: StringName = StringName(str((cfg.get("biome_size", {}) as Dictionary).get(String(biome), "")))
	if prefer == &"":
		return by_ratio
	if absf(ratio - large_at) <= margin and (prefer == LARGE or prefer == MEDIUM):
		return prefer
	if absf(ratio - medium_at) <= margin and (prefer == MEDIUM or prefer == SMALL):
		return prefer
	return by_ratio


## Datos de un tamaño: { width, height, deploy_columns, latigazo }.
static func size_cfg(size: StringName, cfg: Dictionary) -> Dictionary:
	var sizes: Dictionary = cfg.get("sizes", FALLBACK.sizes)
	return sizes.get(String(size), (FALLBACK.sizes as Dictionary)[String(size) if SIZES.has(size) else "small"])


## Cupo por bando para `walkable` casillas transitables.
static func quota(walkable: int, cfg: Dictionary) -> int:
	var per_unit: int = maxi(int(cfg.get("cells_per_unit", 8)), 1)
	return clampi(floori(float(walkable) / float(per_unit * 2)), int(cfg.get("quota_min", 1)), int(cfg.get("quota_max", 6)))


## Transitables estimadas de un tablero llano de `cells` casillas cuyo recorte tiene `ratio`.
static func estimated_walkable(cells: int, ratio: float, cfg: Dictionary) -> int:
	return floori(cells * maxf(clampf(ratio, 0.0, 1.0), float(cfg.get("min_walkable_ratio", 0.7))) + 0.0001)


## Cupo de un tablero con relieve real (cuenta sus casillas transitables).
static func quota_for_board(board: TacticalBoard, cfg: Dictionary) -> int:
	return quota(roundi(board.walkable_ratio() * board.width * board.height), cfg)


## Área del Latigazo múltiple del Ofomni en un tamaño: Vector2i(ancho, fondo) (T6 la ejecuta).
static func latigazo_area(size: StringName, cfg: Dictionary) -> Vector2i:
	var a: Array = size_cfg(size, cfg).get("latigazo", [3, 1])
	return Vector2i(int(a[0]), int(a[1]))


## Plan del tablero: { size, ratio, width, height, deploy_columns, walkable, quota, latigazo }.
## `ratio` < 0: no hay recorte; se usa el del bioma.
static func plan(tactical: Dictionary, ratio: float, biome: StringName = &"") -> Dictionary:
	var cfg: Dictionary = arena_cfg(tactical)
	if ratio < 0.0:
		ratio = biome_ratio(biome, cfg)
	var size: StringName = size_for_ratio(ratio, cfg, biome)
	var s: Dictionary = size_cfg(size, cfg)
	var w: int = int(s.get("width", 8))
	var h: int = int(s.get("height", 6))
	var walkable: int = estimated_walkable(w * h, ratio, cfg)
	return {
		"size": size, "ratio": ratio, "width": w, "height": h,
		"deploy_columns": int(s.get("deploy_columns", 2)), "walkable": walkable,
		"quota": quota(walkable, cfg), "latigazo": latigazo_area(size, cfg),
	}


## Bloque tactical con el tablero del plan (board: width, height, deploy_columns y max_per_side =
## cupo; el resto, como estaba). Para TacticalBridge.build_battle y la escena.
static func apply_plan(tactical: Dictionary, arena_plan: Dictionary) -> Dictionary:
	var out: Dictionary = tactical.duplicate(true)
	var board: Dictionary = (out.get("board", {}) as Dictionary).duplicate()
	board.width = int(arena_plan.width)
	board.height = int(arena_plan.height)
	board.deploy_columns = int(arena_plan.deploy_columns)
	board.max_per_side = int(arena_plan.quota)
	out.board = board
	out.arena_plan = arena_plan
	return out
