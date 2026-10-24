class_name AdventureRules
extends RefCounted
## Reglas del Adoc fuera del combate (ADR 0009): Luz, PV, nivel y XP (progresion-adoc.md), peaje
## entre Bosques (con Luz o con una ofrenda, ofrendas-v1.md), memoria del Bosque (hostilidad y
## relación: vencer a un Botarramas fuerza el Bosque sin abrirlo y encarece su peaje), Únicos (los Botarramas de borde),
## combate de misión (Ofomni descarriado), resultado de un combate (con monstruos fatales según el Momento,
## monstruos.md), recompensa de misión, hallazgos en refugios, villa dañada, descanso en una villa
## y efecto del riutash (ADR 0012). Escribe en GameState y avisa por EventBus. Los
## números viven en data/combat/balance.json y, los del riutash, en data/world/time.json.

const BALANCE_PATH: String = "res://data/combat/balance.json"
const SALT_BATTLE: int = 21
const SALT_QUEST_BATTLE: int = 23
const SALT_REFUGE_LOOT: int = 29
const ADOC_ID: StringName = &"adoc"

static var _balance: Dictionary = {}


static func balance() -> Dictionary:
	if _balance.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
		assert(data is Dictionary, "No se pudo leer %s" % BALANCE_PATH)
		_balance = data
	return _balance


## PV máximos del Adoc en su nivel actual.
static func max_hp() -> int:
	return int(adoc_stats(GameState.level).max_hp)


# --- Niveles (progresion-adoc.md) ---------------------------------------------------------------

static func _level_table() -> Array:
	return balance().levels.table


## Nivel tope (el último de la tabla).
static func max_level() -> int:
	return _level_table().size()


## XP acumulada para alcanzar un nivel (1 = 0).
static func xp_for_level(level: int) -> int:
	return int(_level_table()[clampi(level, 1, max_level()) - 1].xp)


## Nivel que corresponde a una XP acumulada (umbral inclusivo, con el tope).
static func level_for_xp(xp: int) -> int:
	var level: int = 1
	while level < max_level() and xp >= xp_for_level(level + 1):
		level += 1
	return level


## XP que falta para el siguiente nivel desde `xp`, o -1 en el tope.
static func xp_to_next(xp: int) -> int:
	var level: int = level_for_xp(xp)
	return -1 if level >= max_level() else xp_for_level(level + 1) - xp


## Stats del Adoc en un nivel: { max_hp, atk, def }.
static func adoc_stats(level: int) -> Dictionary:
	var row: Dictionary = _level_table()[clampi(level, 1, max_level()) - 1]
	return { "max_hp": int(row.max_hp), "atk": int(row.atk), "def": int(row.def) }


## Niveles que se alcanzan al pasar de `xp` a `xp + gained`, en orden (vacío si ninguno).
static func levels_gained(xp: int, gained: int) -> Array[int]:
	var out: Array[int] = []
	for level: int in range(level_for_xp(xp) + 1, level_for_xp(xp + gained) + 1):
		out.append(level)
	return out


## Suma XP al Adoc y aplica cada nivel nuevo: los PV actuales suben lo mismo que los máximos y se
## emite character_leveled_up por nivel. Devuelve los niveles alcanzados.
static func gain_xp(amount: int) -> Array[int]:
	var gained: int = maxi(0, amount)
	var levels: Array[int] = levels_gained(GameState.xp, gained)
	GameState.xp += gained
	for level: int in levels:
		var before: int = max_hp()
		GameState.level = level
		set_hp(GameState.hp + max_hp() - before)
		EventBus.character_leveled_up.emit(ADOC_ID, level)
	return levels


static func start_luz() -> int:
	return int(balance().adoc.start_luz)


## Tope de Luz suelta que puede llevar el Adoc.
static func luz_max() -> int:
	return int(balance().adoc.luz_max)


## Luz que exige el Nujio de un Bosque a distancia d del Bosque inicial (sin hostilidad).
static func toll_cost(d: int) -> int:
	var t: Dictionary = balance().toll
	return int(t.base) + int(t.per_d) * d


# --- El Bosque recuerda (reglas del dueño 0.3) --------------------------------------------------

static func _memory() -> Dictionary:
	return balance().bosque_memory


## Botarramas vencidos en el Bosque.
static func hostility(bosque_id: int) -> int:
	return int(GameState.bosque_hostility.get(str(bosque_id), 0))


static func relation(bosque_id: int) -> int:
	return int(GameState.bosque_relation.get(str(bosque_id), 0))


static func relation_max() -> int:
	return int(_memory().relation_max)


## Suma `delta` a la relación con el Bosque, dentro de -relation_max .. relation_max.
static func change_relation(bosque_id: int, delta: int) -> void:
	GameState.bosque_relation[str(bosque_id)] = clampi(relation(bosque_id) + delta, -relation_max(), relation_max())


## Peaje del Bosque a distancia d con su hostilidad: 3 + d + hostility_toll × hostilidad. La
## hostilidad no lo sube por encima de toll_max (si la distancia ya lo supera, se queda en el de d).
static func toll_for(bosque_id: int, d: int) -> int:
	var base: int = toll_cost(d)
	var raised: int = base + int(_memory().hostility_toll) * hostility(bosque_id)
	return maxi(base, mini(raised, int(_memory().toll_max)))


## Radio de visión de un Botarramas del Bosque: el de sus datos + hostility_vision × hostilidad,
## con un extra de vision_max_bonus como mucho ("mira, observa").
static func vision_radius(bosque_id: int, base: int) -> int:
	var m: Dictionary = _memory()
	return base + mini(int(m.vision_max_bonus), int(m.hostility_vision) * hostility(bosque_id))


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


## Configuración de un monstruo del mundo (balance.json, bloque monsters: "botarramas", "ofomni",
## "ofomni_descarriado").
static func monster_config(monster_id: StringName) -> Dictionary:
	return (balance().get("monsters", {}) as Dictionary).get(String(monster_id), {})


## Nombre visible de un monstruo (su name_key en data/text/sistema.json).
static func monster_name(monster_id: StringName) -> String:
	return Texts.get_text(str(monster_config(monster_id).get("name_key", monster_id)))


## El monstruo acepta Luz u ofrendas para irse (appeasable en sus datos; por defecto, sí).
static func is_appeasable(cfg: Dictionary) -> bool:
	return bool(cfg.get("appeasable", true))


## Rival de un monstruo a distancia d: stats de su bloque de fórmulas y su ataque especial.
static func make_monster(monster_id: StringName, d: int) -> Dictionary:
	var cfg: Dictionary = monster_config(monster_id)
	var unico: Dictionary = make_unico(d, monster_name(monster_id), str(cfg.get("stats", "unico")))
	unico.max_hp = maxi(1, roundi(int(unico.max_hp) * float(cfg.get("hp_factor", 1.0))))
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


## Se puede cruzar su frontera: el Bosque inicial, uno pagado o uno forzado.
static func is_passable(bosque_id: int, home: int) -> bool:
	return is_paid(bosque_id, home) or is_forced(bosque_id)


## El Bosque inicial o uno con el peaje pagado: sus Botarramas quedan pasivos.
static func is_paid(bosque_id: int, home: int) -> bool:
	return bosque_id >= 0 and (bosque_id == home or GameState.open_bosques.has(bosque_id))


## Forzado: se venció a alguno de sus Botarramas sin pagar. Se cruza, pero los demás siguen activos.
static func is_forced(bosque_id: int) -> bool:
	return bosque_id >= 0 and GameState.forced_bosques.has(bosque_id)


## Marca el Bosque como pagado (deja de estar forzado).
static func open_bosque(bosque_id: int) -> void:
	if not GameState.open_bosques.has(bosque_id):
		GameState.open_bosques.append(bosque_id)
	GameState.forced_bosques.erase(bosque_id)


## Pago del peaje (Luz, ofrenda u Ofrecer Luz en combate): abre el Bosque y mejora la relación.
## "El bosque olvida con ofrendas" (dueño, #147): pagar con una ofrenda baja además 1 la hostilidad
## (sin bajar de 0); pagar con Luz no la borra.
static func _paid(bosque_id: int, with_ofrenda: bool) -> void:
	open_bosque(bosque_id)
	change_relation(bosque_id, int(_memory().relation_per_payment))
	if with_ofrenda and hostility(bosque_id) > 0:
		GameState.bosque_hostility[str(bosque_id)] = hostility(bosque_id) - 1


## Un Botarramas del Bosque ha sido vencido: el Bosque queda forzado (si no estaba pagado), lo
## recuerda (+1 de hostilidad) y la relación baja.
static func guardian_defeated(bosque_id: int) -> void:
	if not GameState.open_bosques.has(bosque_id) and not GameState.forced_bosques.has(bosque_id):
		GameState.forced_bosques.append(bosque_id)
	GameState.bosque_hostility[str(bosque_id)] = hostility(bosque_id) + 1
	change_relation(bosque_id, int(_memory().relation_per_kill))


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
	_paid(bosque_id, false)
	return true


## Paga el peaje con la ofrenda `index` del inventario (ofrendas-v1.md): se deja entera, se
## completa con Luz suelta si no llega y el excedente se pierde. Abre el paso. false si no alcanza.
static func pay_toll_with_ofrenda(bosque_id: int, cost: int, index: int) -> bool:
	if index < 0 or index >= GameState.inventory.size():
		return false
	var value: int = int(GameState.inventory[index].get("luz", 0))
	if not Ofrendas.can_pay(value, GameState.luz, cost):
		return false
	GameState.inventory.remove_at(index)
	set_luz(GameState.luz - Ofrendas.luz_needed(value, cost))
	_paid(bosque_id, true)
	return true


## Prepara un combate nuevo contra el Botarramas que guarda el Bosque. Cuenta el intento (cambia la
## semilla) y el rival empieza siempre con todos sus PV: huir o retroceder no conserva el daño hecho.
static func start_battle(bosque_id: int, d: int, monster_id: StringName = &"botarramas") -> BattleLogic:
	var key: String = str(bosque_id)
	var attempt: int = int(GameState.battle_attempts.get(key, 0))
	GameState.battle_attempts[key] = attempt + 1
	var logic := BattleLogic.new(balance(), adoc_stats(GameState.level), GameState.hp, GameState.luz,
		make_monster(monster_id, d), battle_seed(GameState.seed_value, bosque_id, attempt))
	_prepare(logic, monster_config(monster_id), d)
	logic.toll = toll_for(bosque_id, d)
	logic.ofrendas = GameState.inventory.duplicate(true)
	EventBus.battle_started.emit(bosque_id)
	return logic


## Aplica a GameState el final de un combate de borde. Devuelve el resultado como StringName
## (&"victory", &"defeat", &"fled", &"appeased" si el Único se fue con Luz o una ofrenda o
## &"game_over" si el rival era fatal). Apaciguar paga el peaje (abre el Bosque); vencer lo fuerza
## y el Bosque lo recuerda.
static func finish_battle(logic: BattleLogic, bosque_id: int) -> StringName:
	var outcome: StringName = _apply_result(logic)
	if outcome == &"appeased":
		_paid(bosque_id, logic.ofrenda_index >= 0)
	elif outcome == &"victory":
		guardian_defeated(bosque_id)
	EventBus.battle_ended.emit(bosque_id, outcome)
	return outcome


## Combate de misión contra su monstruo (`target` del JSON de la misión, p. ej. el Ofomni descarriado) con su d
## fija. No abre Bosques y su contador de intentos (semilla) es el de la misión.
static func start_quest_battle(quest_id: StringName, d: int) -> BattleLogic:
	var q: Dictionary = GameState.quests.get(quest_id, {})
	var attempt: int = int(q.get("battle_attempts", 0))
	q.battle_attempts = attempt + 1
	GameState.quests[quest_id] = q
	var target: StringName = StringName(str(QuestLogic.data(quest_id).get("target", "")))
	var rng_seed: int = ChunkGenerator.hash_ints([GameState.seed_value, String(quest_id).hash(), attempt, SALT_QUEST_BATTLE])
	var logic := BattleLogic.new(balance(), adoc_stats(GameState.level), GameState.hp, GameState.luz,
		make_monster(target, d), rng_seed)
	# Sin Bosque que cobre: no hay peaje que ofrecer. El Ofomni descarriado, además, no acepta pagos.
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
	# Acepta Luz u ofrendas para irse salvo que sus datos digan lo contrario (el Ofomni descarriado).
	logic.accepts_payment = is_appeasable(cfg)
	logic.fatal = is_fatal(cfg.get("fatal_at", []), GameState.clock_momento)
	logic.victory_xp = victory_xp(d)
	logic.level_ups = levels_gained(GameState.xp, logic.victory_xp)


static func _apply_result(logic: BattleLogic) -> StringName:
	var b: Dictionary = balance()
	match logic.result:
		BattleLogic.Result.VICTORY:
			set_hp(logic.adoc_hp)
			set_luz(logic.luz + int(b.victory_luz))
			gain_xp(logic.victory_xp)
			return &"victory"
		BattleLogic.Result.APPEASED:
			set_hp(logic.adoc_hp)
			set_luz(logic.luz)
			_remove_offered(logic)
			return &"appeased"
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


## Quita del inventario la ofrenda entregada en combate (la misma posición si sigue ahí; si no,
## la primera con su id).
static func _remove_offered(logic: BattleLogic) -> void:
	if logic.ofrenda_index < 0 or logic.ofrenda_index >= logic.ofrendas.size():
		return
	var id: String = str(logic.ofrendas[logic.ofrenda_index].id)
	var inv: Array = GameState.inventory
	if logic.ofrenda_index < inv.size() and str(inv[logic.ofrenda_index].get("id", "")) == id:
		inv.remove_at(logic.ofrenda_index)
		return
	for i: int in inv.size():
		if str(inv[i].get("id", "")) == id:
			inv.remove_at(i)
			return


## Recompensa de una misión (mision-ofomni.md): Luz al tope, una ofrenda al inventario como
## { id, luz }, XP y fama. `reward` es el bloque "reward" del JSON de la misión. Si la XP sube de
## nivel, lo anuncia en el HUD (fuera del combate no hay narración).
static func apply_quest_reward(reward: Dictionary) -> void:
	if bool(reward.get("refill_luz_to_max", false)):
		set_luz(luz_max())
	if reward.has("ofrenda"):
		GameState.inventory.append({ "id": str(reward.ofrenda), "luz": int(reward.get("ofrenda_luz", 0)) })
	GameState.fama += int(reward.get("fama", 0))
	var lines: PackedStringArray = []
	for level: int in gain_xp(int(reward.get("xp", 0))):
		lines.append(Texts.get_text("level_up") % level)
	if not lines.is_empty():
		EventBus.notice_requested.emit("\n".join(lines))


# --- Hallazgos en refugios (ofrendas-v1.md) -----------------------------------------------------

## Ofrenda que guarda el refugio del chunk (&"" = ninguna). Determinista por seed y chunk: uno de
## cada `one_in` refugios, repartidos a partes iguales entre las ofrendas de origen "refuge".
static func refuge_ofrenda(seed_value: int, coord: Vector2i) -> StringName:
	var cfg: Dictionary = balance().refuge_loot
	var ids: Array[StringName] = Ofrendas.ids_from(str(cfg.source))
	var one_in: int = maxi(1, int(cfg.one_in))
	var h: int = ChunkGenerator.hash_ints([seed_value, coord.x, coord.y, SALT_REFUGE_LOOT])
	if ids.is_empty() or h % one_in != 0:
		return &""
	return ids[(h / one_in) % ids.size()]


static func is_refuge_looted(coord: Vector2i) -> bool:
	return GameState.looted_refuges.has(coord)


## Recoge el hallazgo del refugio del chunk: lo añade al inventario y lo marca, una sola vez por
## partida. Devuelve el elemento { id, luz } o {} si no había nada o ya se recogió.
static func loot_refuge(coord: Vector2i) -> Dictionary:
	var id: StringName = refuge_ofrenda(GameState.seed_value, coord)
	if id == &"" or is_refuge_looted(coord):
		return {}
	var item: Dictionary = Ofrendas.make_item(id)
	GameState.inventory.append(item)
	GameState.looted_refuges.append(coord)
	return item


# --- Robo al Bosque (bosques-y-relacion.md, sigilo-y-robo.md) ---------------------------------

## Robo al Bosque `bosque_id` (hoy: tomar fruto sin permiso o un segundo fruto del mismo Bosque
## en el mismo Momento, FruitRules).
## El Bosque lo recuerda: hostilidad + hostility_per_theft (1) y relación + relation_per_theft
## (−20), bloque bosque_memory. Avisa con bosque_robbed: ahí se engancha la persecución de los
## Ofomni por robo (otro PR).
static func record_theft(bosque_id: int) -> void:
	GameState.bosque_hostility[str(bosque_id)] = hostility(bosque_id) + int(_memory().hostility_per_theft)
	change_relation(bosque_id, int(_memory().relation_per_theft))
	EventBus.bosque_robbed.emit(bosque_id)


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
