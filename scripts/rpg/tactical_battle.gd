class_name TacticalBattle
extends RefCounted
## Turnos CT, movimiento y orientación del combate táctico (combate-tactico.md, ADR 0016; PR T2).
## Lógica pura sobre un TacticalBoard: no toca GameState ni la escena, y no sustituye todavía a
## BattleLogic (el combate por menú sigue en uso hasta T8). Las acciones (atacar, Defender, Huir…)
## llegan en T3: aquí solo se marca que el combatiente actuó (mark_acted) para el coste de CT.
## Números en data/combat/balance.json (bloque tactical).
## - Combatientes: [{ id, side, agi, cell?, facing? }] (side: SIDE_PLAYER o SIDE_ENEMY). Hasta
##   board.max_per_side por bando (los demás se ignoran). Sin `cell`, se colocan en las columnas de
##   su lado (el jugador en `player_side`, los enemigos en el opuesto). Sin `facing`, miran al
##   bando contrario.
## - Mov = mov_base + floor((AGI − mov_agi_ref) / mov_agi_div), entre mov_min y mov_max; Salto =
##   jump_base + floor(AGI / jump_agi_div); se baja hasta Salto + drop_extra.
## - CT: inicial AGI × start_per_agi; cada tick CT += AGI (al menos 1, para que nadie se quede
##   parado); juega quien tenga CT ≥ threshold. Si varios: más CT primero; empate, el bando del
##   jugador; dentro de un bando, un orden fijo sorteado con la seed (determinista). Tras el turno,
##   CT −= cost_move_and_act, cost_single o cost_wait. El sobrante de CT se conserva.
## - Turno: begin_turn() elige quién juega; move_active() mueve dentro de lo alcanzable (una vez);
##   mark_acted() (T3); end_turn(facing) fija la orientación y cobra el CT.
## - Por las casillas de los aliados se pasa, pero no se para; por las de los enemigos, ni eso.
## - preview_order(n): los próximos n turnos sin tocar el estado (línea de iconos de la UI).

const SIDE_PLAYER: int = 0
const SIDE_ENEMY: int = 1
## Ningún combatiente en su turno.
const NONE: int = -1
## Sal del RNG del desempate (se suma a la semilla del combate).
const TIE_SALT: int = 4271

var board: TacticalBoard
var movement_cfg: Dictionary
var ct_cfg: Dictionary
var board_cfg: Dictionary
## Lado por donde llegó el jugador (sus columnas de colocación).
var player_side: TacticalBoard.Side = TacticalBoard.Side.LEFT
## Combatientes: [{ id, side, agi, mov, jump, drop, cell, facing, ct, tie, alive }].
var units: Array[Dictionary] = []
## Índice del combatiente en su turno (NONE fuera de un turno).
var active: int = NONE
var active_moved: bool = false
var active_acted: bool = false
## Turnos jugados (para la UI y los tests).
var turn_count: int = 0


func _init(tactical: Dictionary, battle_board: TacticalBoard, fighters: Array, rng_seed: int,
		arrival_side: TacticalBoard.Side = TacticalBoard.Side.LEFT) -> void:
	board = battle_board
	movement_cfg = tactical.get("movement", {})
	ct_cfg = tactical.get("ct", {})
	board_cfg = tactical.get("board", {})
	player_side = arrival_side
	var tie_rng := RandomNumberGenerator.new()
	tie_rng.seed = rng_seed + TIE_SALT
	var max_side: int = int(board_cfg.get("max_per_side", 3))
	var per_side: Array[int] = [0, 0]
	for f: Variant in fighters:
		var data: Dictionary = f
		var side: int = SIDE_ENEMY if int(data.get("side", SIDE_PLAYER)) == SIDE_ENEMY else SIDE_PLAYER
		if per_side[side] >= max_side:
			continue
		per_side[side] += 1
		var agi: int = int(data.get("agi", 0))
		var jump: int = jump_height(agi, movement_cfg)
		units.append({
			"id": data.get("id", &""),
			"side": side,
			"agi": agi,
			"mov": move_range(agi, movement_cfg),
			"jump": jump,
			"drop": jump + int(movement_cfg.get("drop_extra", 1)),
			"cell": data.get("cell", Vector2i(-1, -1)),
			"facing": data.get("facing", -1),
			"ct": agi * int(ct_cfg.get("start_per_agi", 10)),
			"tie": tie_rng.randi(),
			"alive": true,
		})
	_place_units()


# --- Derivados de AGI ---------------------------------------------------------------------------

## Mov (casillas por turno) según la AGI.
static func move_range(agi: int, cfg: Dictionary) -> int:
	var div: int = maxi(int(cfg.get("mov_agi_div", 2)), 1)
	var raw: int = int(cfg.get("mov_base", 3)) + floori(float(agi - int(cfg.get("mov_agi_ref", 5))) / div)
	return clampi(raw, int(cfg.get("mov_min", 2)), int(cfg.get("mov_max", 6)))


## Salto (niveles que se suben entre dos casillas vecinas) según la AGI.
static func jump_height(agi: int, cfg: Dictionary) -> int:
	var div: int = maxi(int(cfg.get("jump_agi_div", 7)), 1)
	return int(cfg.get("jump_base", 1)) + floori(float(agi) / div)


# --- Colocación ---------------------------------------------------------------------------------

func _place_units() -> void:
	var columns: int = int(board_cfg.get("deploy_columns", 2))
	var enemy_side: TacticalBoard.Side = TacticalBoard.Side.RIGHT if player_side == TacticalBoard.Side.LEFT \
		else TacticalBoard.Side.LEFT
	var taken: Dictionary = {}
	for u: Dictionary in units:
		if board.in_bounds(u.cell):
			taken[u.cell] = true
	for side: int in [SIDE_PLAYER, SIDE_ENEMY]:
		var board_side: TacticalBoard.Side = player_side if side == SIDE_PLAYER else enemy_side
		var cells: Array[Vector2i] = board.deploy_cells(board_side, columns, _count_side(side) + taken.size())
		for u: Dictionary in units:
			if u.side != side:
				continue
			if not board.in_bounds(u.cell):
				for c: Vector2i in cells:
					if not taken.has(c):
						u.cell = c
						break
				taken[u.cell] = true
			if int(u.facing) < 0:
				u.facing = TacticalBoard.Facing.EAST if board_side == TacticalBoard.Side.LEFT \
					else TacticalBoard.Facing.WEST


func _count_side(side: int) -> int:
	var n: int = 0
	for u: Dictionary in units:
		if u.side == side:
			n += 1
	return n


# --- Turnos CT ----------------------------------------------------------------------------------

## CT de un combatiente.
func ct_of(index: int) -> int:
	return int(units[index].ct)


## Fija el CT (sorpresa y emboscada, T6: CT 100 para un bando).
func set_ct(index: int, value: int) -> void:
	units[index].ct = value


## Retira a un combatiente (caído o huido): deja de jugar y de ocupar casilla.
func remove_unit(index: int) -> void:
	units[index].alive = false
	if active == index:
		active = NONE


## Empieza el turno del siguiente combatiente (avanza ticks si nadie llega al umbral) y devuelve su
## índice, o NONE si no queda nadie en pie.
func begin_turn() -> int:
	assert(active == NONE, "Termina el turno antes de empezar otro")
	var cts: Array[int] = _cts()
	var next: int = _advance(cts)
	for i in units.size():
		units[i].ct = cts[i]
	active = next
	active_moved = false
	active_acted = false
	return next


## Casillas alcanzables por el combatiente en su turno: { Vector2i: coste }. Vacío si ya se movió.
func reachable_for(index: int) -> Dictionary:
	if index == active and active_moved:
		return { units[index].cell: 0 }
	var u: Dictionary = units[index]
	return board.reachable(u.cell, int(u.mov), int(u.jump), int(u.drop), _enemy_cells(u.side),
		_occupied_cells(index))


## Camino del combatiente hasta `to` (vacío si no llega).
func path_for(index: int, to: Vector2i) -> Array[Vector2i]:
	var u: Dictionary = units[index]
	return board.path_to(u.cell, to, int(u.mov), int(u.jump), int(u.drop), _enemy_cells(u.side),
		_occupied_cells(index))


## Mueve al combatiente en su turno a `to`. Devuelve el camino recorrido ([] si no puede: fuera de
## lo alcanzable, ya se movió o no es su turno). La orientación pasa a la del último paso.
func move_active(to: Vector2i) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if active == NONE or active_moved or to == units[active].cell:
		return none
	var path: Array[Vector2i] = path_for(active, to)
	if path.is_empty():
		return none
	units[active].cell = to
	units[active].facing = TacticalBoard.facing_toward(path[path.size() - 2], to)
	active_moved = true
	return path


## El combatiente en su turno actuó (atacar, Defender, objeto…; las acciones llegan en T3).
func mark_acted() -> void:
	if active != NONE:
		active_acted = true


## Coste de CT según lo que hizo en el turno.
func turn_cost(moved: bool, acted: bool) -> int:
	if moved and acted:
		return int(ct_cfg.get("cost_move_and_act", 100))
	if moved or acted:
		return int(ct_cfg.get("cost_single", 80))
	return int(ct_cfg.get("cost_wait", 60))


## Termina el turno: fija la orientación (4 direcciones) y cobra el CT. Devuelve el coste cobrado.
func end_turn(facing: TacticalBoard.Facing) -> int:
	if active == NONE:
		return 0
	var cost: int = turn_cost(active_moved, active_acted)
	units[active].facing = facing
	units[active].ct = int(units[active].ct) - cost
	active = NONE
	turn_count += 1
	return cost


## Los próximos `count` turnos (índices de combatiente) sin tocar el estado. Si alguien está en su
## turno, se supone que cobra `active_cost` (por defecto, mover y actuar) y se cuenta desde ahí.
func preview_order(count: int, active_cost: int = -1) -> Array[int]:
	var cts: Array[int] = _cts()
	var out: Array[int] = []
	if active != NONE:
		cts[active] -= active_cost if active_cost >= 0 else turn_cost(true, true)
	var full: int = turn_cost(true, true)
	while out.size() < count:
		var next: int = _advance(cts)
		if next == NONE:
			break
		out.append(next)
		cts[next] -= full
	return out


## Puede huir (T3): está en una casilla del borde (#184, "Cualquier borde, seguro").
func can_flee(index: int) -> bool:
	return units[index].alive and board.is_edge(units[index].cell)


## Índice del combatiente en una casilla (NONE si está libre).
func unit_at(cell: Vector2i) -> int:
	for i in units.size():
		if units[i].alive and units[i].cell == cell:
			return i
	return NONE


func _cts() -> Array[int]:
	var cts: Array[int] = []
	for u: Dictionary in units:
		cts.append(int(u.ct))
	return cts


## Avanza `cts` hasta que alguien llega al umbral y devuelve quién juega (NONE sin nadie en pie).
func _advance(cts: Array[int]) -> int:
	var threshold: int = int(ct_cfg.get("threshold", 100))
	var any_alive: bool = false
	for u: Dictionary in units:
		any_alive = any_alive or bool(u.alive)
	if not any_alive:
		return NONE
	while true:
		var best: int = NONE
		for i in units.size():
			if not units[i].alive or cts[i] < threshold:
				continue
			if best == NONE or _goes_before(i, best, cts):
				best = i
		if best != NONE:
			return best
		for i in units.size():
			if units[i].alive:
				cts[i] += maxi(int(units[i].agi), 1)
	return NONE


## `a` juega antes que `b` con los mismos ticks: más CT; empate, el bando del jugador; luego el orden
## sorteado con la seed; luego el índice.
func _goes_before(a: int, b: int, cts: Array[int]) -> bool:
	if cts[a] != cts[b]:
		return cts[a] > cts[b]
	if units[a].side != units[b].side:
		return units[a].side == SIDE_PLAYER
	if units[a].tie != units[b].tie:
		return int(units[a].tie) > int(units[b].tie)
	return a < b


func _enemy_cells(side: int) -> Dictionary:
	var out: Dictionary = {}
	for u: Dictionary in units:
		if u.alive and u.side != side:
			out[u.cell] = true
	return out


func _occupied_cells(except: int) -> Dictionary:
	var out: Dictionary = {}
	for i in units.size():
		if i != except and units[i].alive:
			out[units[i].cell] = true
	return out
