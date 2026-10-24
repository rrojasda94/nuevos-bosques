class_name AdventureRules
extends RefCounted
## Reglas del Adoc fuera del combate (ADR 0009): Luz, PV, peaje entre Bosques, Únicos (los
## Botarramas de borde), combate de misión (Ofomni), resultado de un combate (con monstruos fatales
## según el Momento, monstruos.md), XP de victoria, recompensa de misión, villa dañada, descanso en
## una villa y efecto del riutash (ADR 0012). Escribe en GameState y avisa por EventBus. Los
## números viven en data/combat/balance.json y, los del riutash, en data/world/time.json.

const BALANCE_PATH: String = "res://data/combat/balance.json"
const SALT_BATTLE: int = 21
const SALT_QUEST_BATTLE: int = 23

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


## Stats del Único del Bosque a distancia d (deterministas: solo dependen de d). `unico_name`:
## nombre provisional, ver UnicoArt.display_name.
static func make_unico(d: int, unico_name: String, stats_block: String = "unico") -> Dictionary:
	var u: Dictionary = balance()[stats_block]
	var dc: int = clampi(d, 0, int(u.d_max))
	return {
		"name": unico_name,
		"max_hp": int(u.hp_base) + int(u.hp_per_d) * dc,
		"atk": int(u.atk_base) + int(u.atk_per_d) * dc,
		"def": mini(int(u.def_max), int(u.def_base) + floori(float(u.def_per_d) * dc)),
	}


## Configuración de un monstruo del mundo (balance.json, bloque monsters: "botarramas", "ofomni").
static func monster_config(monster_id: StringName) -> Dictionary:
	return (balance().get("monsters", {}) as Dictionary).get(String(monster_id), {})


## Nombre visible de un monstruo (su name_key en data/text/sistema.json).
static func monster_name(monster_id: StringName) -> String:
	return Texts.get_text(str(monster_config(monster_id).get("name_key", monster_id)))


## Rival de un monstruo a distancia d: stats de su bloque de fórmulas y su ataque especial.
static func make_monster(monster_id: StringName, d: int) -> Dictionary:
	var cfg: Dictionary = monster_config(monster_id)
	var unico: Dictionary = make_unico(d, monster_name(monster_id), str(cfg.get("stats", "unico")))
	unico.special_every = int(cfg.get("special_every", 0))
	unico.special_factor = float(cfg.get("special_factor", 1.0))
	unico.texts = cfg.get("texts", {})
	return unico


## XP de una victoria a distancia d (progresion-adoc.md: 4 + 3·d, con el tope d_max).
static func victory_xp(d: int) -> int:
	var x: Dictionary = balance().xp
	return int(x.victory_base) + int(x.victory_per_d) * clampi(d, 0, int(balance().unico.d_max))


## Perder es game over si el Momento en que empieza el combate está en `fatal_at` (monstruos.md).
static func is_fatal(fatal_at: Array, momento: StringName) -> bool:
	for m: Variant in fatal_at:
		if StringName(str(m)) == momento:
			return true
	return false


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


## Prepara un combate nuevo contra el Botarramas que guarda el Bosque. Cuenta el intento (cambia la
## semilla) y el rival empieza siempre con todos sus PV: huir o retroceder no conserva el daño hecho.
static func start_battle(bosque_id: int, d: int, monster_id: StringName = &"botarramas") -> BattleLogic:
	var key: String = str(bosque_id)
	var attempt: int = int(GameState.battle_attempts.get(key, 0))
	GameState.battle_attempts[key] = attempt + 1
	var logic := BattleLogic.new(balance(), GameState.hp, GameState.luz, make_monster(monster_id, d),
		battle_seed(GameState.seed_value, bosque_id, attempt))
	_prepare(logic, monster_config(monster_id), d)
	EventBus.battle_started.emit(bosque_id)
	return logic


## Aplica a GameState el final de un combate de borde. Devuelve el resultado como StringName
## (&"victory", &"defeat", &"fled" o &"game_over" si el rival era fatal).
static func finish_battle(logic: BattleLogic, bosque_id: int) -> StringName:
	var outcome: StringName = _apply_result(logic)
	if outcome == &"victory":
		open_bosque(bosque_id)
	EventBus.battle_ended.emit(bosque_id, outcome)
	return outcome


## Combate de misión contra su monstruo (`target` del JSON de la misión, p. ej. el Ofomni) con su d
## fija. No abre Bosques y su contador de intentos (semilla) es el de la misión.
static func start_quest_battle(quest_id: StringName, d: int) -> BattleLogic:
	var q: Dictionary = GameState.quests.get(quest_id, {})
	var attempt: int = int(q.get("battle_attempts", 0))
	q.battle_attempts = attempt + 1
	GameState.quests[quest_id] = q
	var target: StringName = StringName(str(QuestLogic.data(quest_id).get("target", "")))
	var rng_seed: int = ChunkGenerator.hash_ints([GameState.seed_value, String(quest_id).hash(), attempt, SALT_QUEST_BATTLE])
	var logic := BattleLogic.new(balance(), GameState.hp, GameState.luz, make_monster(target, d), rng_seed)
	_prepare(logic, monster_config(target), d)
	return logic


## Final de un combate de misión. Victoria: la misión pasa a completed (o, si ya había fallado,
## se marca el monstruo como vencido). Mismos resultados que finish_battle.
static func finish_quest_battle(logic: BattleLogic, quest_id: StringName) -> StringName:
	var outcome: StringName = _apply_result(logic)
	if outcome == &"victory":
		var q: Dictionary = GameState.quests.get(quest_id, {})
		var before: StringName = QuestLogic.state_of(q)
		QuestLogic.target_defeated(q)
		QuestLogic.commit(quest_id, q, before)
	return outcome


static func _prepare(logic: BattleLogic, cfg: Dictionary, d: int) -> void:
	logic.fatal = is_fatal(cfg.get("fatal_at", []), GameState.clock_momento)
	logic.victory_xp = victory_xp(d)


static func _apply_result(logic: BattleLogic) -> StringName:
	var b: Dictionary = balance()
	match logic.result:
		BattleLogic.Result.VICTORY:
			set_hp(logic.adoc_hp)
			set_luz(logic.luz + int(b.victory_luz))
			GameState.xp += logic.victory_xp
			return &"victory"
		BattleLogic.Result.DEFEAT:
			if logic.fatal:
				EventBus.game_ended.emit(&"fatal_defeat")
				return &"game_over"
			set_hp(max_hp())
			set_luz(floori(logic.luz * float(b.defeat_luz_factor)))
			return &"defeat"
	set_hp(logic.adoc_hp)
	set_luz(logic.luz)
	return &"fled"


## Recompensa de una misión (mision-ofomni.md): Luz al tope, una ofrenda al inventario como
## { id, luz }, XP y fama. `reward` es el bloque "reward" del JSON de la misión.
static func apply_quest_reward(reward: Dictionary) -> void:
	if bool(reward.get("refill_luz_to_max", false)):
		set_luz(luz_max())
	if reward.has("ofrenda"):
		GameState.inventory.append({ "id": str(reward.ofrenda), "luz": int(reward.get("ofrenda_luz", 0)) })
	GameState.xp += int(reward.get("xp", 0))
	GameState.fama += int(reward.get("fama", 0))


## Villa natal dañada (misión fallida): pierde Luz suelta (redondeo hacia abajo) y queda marcada.
static func damage_villa(luz_factor: float) -> void:
	set_luz(floori(GameState.luz * luz_factor))
	GameState.villa_damaged = true


## La casilla toca (también en diagonal) la huella del Nujio del chunk.
static func is_next_to_nujio(chunk: ChunkData, cell: Vector2i) -> bool:
	return chunk.nujio_rect.size.x > 0 and chunk.nujio_rect.grow(1).has_point(cell) \
		and not chunk.nujio_rect.has_point(cell)


## Se descansa en una villa: en su plaza o junto al Nujio de un Bosque con villa. Un Nujio sin
## villa no cura.
static func is_villa_rest(chunk: ChunkData, cell: Vector2i) -> bool:
	if not chunk.has_villa or not ChunkData.in_bounds(cell):
		return false
	return chunk.get_tile(cell) == ChunkData.Tile.PLAZA or is_next_to_nujio(chunk, cell)


## Descanso en la villa: PV al máximo.
static func rest() -> void:
	set_hp(max_hp())
	EventBus.rested_in_villa.emit()


## Refugio frente al riutash: una casilla REFUGE o un lugar de descanso de villa.
static func is_riutash_shelter(chunk: ChunkData, cell: Vector2i) -> bool:
	return chunk != null and ChunkData.in_bounds(cell) and (chunk.is_refuge(cell) or is_villa_rest(chunk, cell))


## PV tras el riutash (pura). Expuesto: pierde el % de los PV máximos (redondeo hacia abajo) sin
## bajar nunca de 1. En refugio: recupera el % de los PV que faltan (redondeo hacia arriba).
static func riutash_hp(hp: int, hp_max: int, sheltered: bool) -> int:
	if sheltered:
		var missing: int = maxi(0, hp_max - hp)
		return mini(hp_max, hp + ceili(missing * TimeConfig.riutash_heal_pct() / 100.0))
	var damage: int = floori(hp_max * TimeConfig.riutash_damage_pct() / 100.0)
	return mini(hp, maxi(1, hp - damage))


## Aplica el riutash al Adoc. Devuelve el cambio de PV (negativo si hiere).
static func apply_riutash(sheltered: bool) -> int:
	var before: int = GameState.hp
	set_hp(riutash_hp(before, max_hp(), sheltered))
	return GameState.hp - before
