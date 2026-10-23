class_name AdventureRules
extends RefCounted
## Reglas del Adoc fuera del combate (ADR 0009): Luz, PV, peaje entre Bosques, Únicos,
## resultado de un combate y descanso en una villa. Escribe en GameState y avisa por EventBus.
## Los números viven en data/combat/balance.json.

const BALANCE_PATH: String = "res://data/combat/balance.json"
const SALT_BATTLE: int = 21

static var _balance: Dictionary = {}


static func balance() -> Dictionary:
	if _balance.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
		assert(data is Dictionary, "No se pudo leer %s" % BALANCE_PATH)
		_balance = data
	return _balance


static func max_hp() -> int:
	return int(balance().adoc.max_hp)


static func start_luz() -> int:
	return int(balance().adoc.start_luz)


## Tope de Luz suelta que puede llevar el Adoc.
static func luz_max() -> int:
	return int(balance().adoc.luz_max)


## Luz que exige el Nujio de un Bosque a distancia d del Bosque inicial.
static func toll_cost(d: int) -> int:
	var t: Dictionary = balance().toll
	return int(t.base) + int(t.per_d) * d


## Stats del Único del Bosque a distancia d. Deterministas: solo dependen de d y del tipo de árbol.
static func make_unico(d: int, tree_name: String) -> Dictionary:
	var u: Dictionary = balance().unico
	var dc: int = clampi(d, 0, int(u.d_max))
	return {
		"name": "Único de %s" % tree_name,
		"max_hp": int(u.hp_base) + int(u.hp_per_d) * dc,
		"atk": int(u.atk_base) + int(u.atk_per_d) * dc,
		"def": mini(int(u.def_max), int(u.def_base) + floori(float(u.def_per_d) * dc)),
	}


## Semilla del RNG de un combate: seed de partida + Bosque + número de intento.
static func battle_seed(seed_value: int, bosque_id: int, attempt: int) -> int:
	return ChunkGenerator.hash_ints([seed_value, bosque_id, attempt, SALT_BATTLE])


static func home_bosque(map: BosqueMap, region: Dictionary) -> int:
	return map.bosque_at(ChunkGenerator.region_start_chunk(region))


## Se puede entrar libremente: el Bosque inicial o uno con el paso abierto.
static func is_passable(bosque_id: int, home: int) -> bool:
	return bosque_id >= 0 and (bosque_id == home or GameState.open_bosques.has(bosque_id))


static func open_bosque(bosque_id: int) -> void:
	if not GameState.open_bosques.has(bosque_id):
		GameState.open_bosques.append(bosque_id)


static func set_luz(value: int) -> void:
	GameState.luz = clampi(value, 0, luz_max())
	EventBus.luz_changed.emit(GameState.luz)


static func set_hp(value: int) -> void:
	GameState.hp = clampi(value, 0, max_hp())
	EventBus.hp_changed.emit(GameState.hp, max_hp())


## Paga el peaje y abre el paso. false si no hay Luz suficiente.
static func pay_toll(bosque_id: int, cost: int) -> bool:
	if GameState.luz < cost:
		return false
	set_luz(GameState.luz - cost)
	open_bosque(bosque_id)
	return true


## Prepara un combate nuevo contra el Único del Bosque. Cuenta el intento (cambia la semilla) y
## el Único empieza siempre con todos sus PV: huir o retroceder no conserva el daño hecho.
static func start_battle(bosque_id: int, d: int, tree_name: String) -> BattleLogic:
	var key: String = str(bosque_id)
	var attempt: int = int(GameState.battle_attempts.get(key, 0))
	GameState.battle_attempts[key] = attempt + 1
	var logic := BattleLogic.new(balance(), GameState.hp, GameState.luz, make_unico(d, tree_name),
		battle_seed(GameState.seed_value, bosque_id, attempt))
	EventBus.battle_started.emit(bosque_id)
	return logic


## Aplica a GameState el final de un combate. Devuelve el resultado como StringName
## (&"victory", &"defeat", &"fled").
static func finish_battle(logic: BattleLogic, bosque_id: int) -> StringName:
	var b: Dictionary = balance()
	var outcome: StringName = &"fled"
	match logic.result:
		BattleLogic.Result.VICTORY:
			outcome = &"victory"
			set_hp(logic.adoc_hp)
			set_luz(logic.luz + int(b.victory_luz))
			open_bosque(bosque_id)
		BattleLogic.Result.DEFEAT:
			outcome = &"defeat"
			set_hp(max_hp())
			set_luz(floori(logic.luz * float(b.defeat_luz_factor)))
		_:
			set_hp(logic.adoc_hp)
			set_luz(logic.luz)
	EventBus.battle_ended.emit(bosque_id, outcome)
	return outcome


## La casilla toca (también en diagonal) la huella del Nujio del chunk.
static func is_next_to_nujio(chunk: ChunkData, cell: Vector2i) -> bool:
	return chunk.nujio_rect.size.x > 0 and chunk.nujio_rect.grow(1).has_point(cell) \
		and not chunk.nujio_rect.has_point(cell)


## Se descansa en una villa: en su plaza o junto al Nujio de un Bosque con villa. Un Nujio sin
## villa no cura (más adelante también curará el riutash, cuando haya día y noche).
static func is_villa_rest(chunk: ChunkData, cell: Vector2i) -> bool:
	if not chunk.has_villa or not ChunkData.in_bounds(cell):
		return false
	return chunk.get_tile(cell) == ChunkData.Tile.PLAZA or is_next_to_nujio(chunk, cell)


## Descanso en la villa: PV al máximo.
static func rest() -> void:
	set_hp(max_hp())
	EventBus.rested_in_villa.emit()
