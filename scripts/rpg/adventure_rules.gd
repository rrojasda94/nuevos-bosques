class_name AdventureRules
extends RefCounted
## Reglas del Adoc fuera del combate (ADR 0009): Luz, PV, nivel y XP (progresion-adoc.md), peaje
## entre Bosques (con Luz o con una ofrenda, ofrendas-v1.md), memoria del Bosque (hostilidad y
## relación: vencer a un Botarramas fuerza el Bosque sin abrirlo y encarece su peaje), relación con
## cada Bosque (bosques-y-relacion.md: el pago caduca al segundo riutash salvo con amistad alta, la
## relación multiplica el peaje y sube con ofrendas ante el Nujio, misiones, defensa y descansos junto
## al Nujio), Únicos (los Botarramas de borde),
## combate de misión (Ofomni descarriado), resultado de un combate (con monstruos fatales según el Momento,
## monstruos.md), reaparición tras una derrota no fatal junto al Nujio aliado más cercano
## (cruce-y-combate-v2.md), recompensa de misión, hallazgos en refugios, bolsa y equipo (el arma equipada
## suma ATQ), villa dañada, descanso en una villa y efecto del riutash (ADR 0012). Los estados de
## Bosque (BosqueStates) cambian el peaje (corrupto ×1,5; muerto y necesita_ayuda no cobran y su
## borde está abierto; el enojado no acepta pagos) y la visión de sus Botarramas, y un Bosque que
## cae a angry_candidate_at de relación se enoja. Sigilo (Stealth, sigilo-y-robo.md): con un arma
## en la mano ningún Bosque salvo el natal te deja pasar en paz (is_welcome), colarse deja el
## Bosque colado (sneak_into) y la máscara pesada resta DEF. Senda y skills (0.5,
## moralidad-y-progresion.md): los actos que ya pasan aquí mueven la Senda (Senda.record) y las
## skills aprendidas (AdocGrowth) cambian la visión de los Únicos, el peaje, el combate (golpe
## fuerte, botín, Únicos aliados), el menú del borde (imponerse) y el riutash. Los stats del Adoc
## salen de su nivel y de los puntos gastados (AdocGrowth.player_stats). Escribe en GameState y
## avisa por EventBus. Los números viven en data/combat/balance.json y, los del riutash, en
## data/world/time.json.

const BALANCE_PATH: String = "res://data/combat/balance.json"
const SALT_BATTLE: int = 21
const SALT_QUEST_BATTLE: int = 23
const SALT_REFUGE_LOOT: int = 29
const SALT_GROUP: int = 31
const SALT_LOOT: int = 37
const ADOC_ID: StringName = &"adoc"
## Valor de GameState.open_until para un paso pagado que no caduca (amistad alta).
const OPEN_PERMANENT: int = -1
## Combate en grupo: hasta 4 enemigos y 2 aliados (lo que cabe en la pantalla a 320×180).
const MAX_ENEMIES: int = 4
const MAX_ALLIES: int = 2

static var _balance: Dictionary = {}


static func balance() -> Dictionary:
	if _balance.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
		assert(data is Dictionary, "No se pudo leer %s" % BALANCE_PATH)
		_balance = data
	return _balance


## PV máximos del Adoc: los de su nivel más el Vigor comprado.
static func max_hp() -> int:
	return int(AdocGrowth.player_stats().max_hp)


# --- Niveles (progresion-adoc.md; stats de moralidad-y-progresion.md) ----------------------------

static func _level_xp() -> Array:
	return balance().levels.xp


## Nivel tope (el último de la lista de XP).
static func max_level() -> int:
	return _level_xp().size()


## XP acumulada para alcanzar un nivel (1 = 0).
static func xp_for_level(level: int) -> int:
	return int(_level_xp()[clampi(level, 1, max_level()) - 1])


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


## Stats automáticos de un adoc en un nivel, sin puntos repartidos: { max_hp, atk, def }. Los
## usan los adoc NPC; el jugador suma sus puntos (AdocGrowth.player_stats).
static func adoc_stats(level: int) -> Dictionary:
	return AdocGrowth.auto_stats(level)


# --- Equipo (roadmap-0.3.md #113, sigilo-y-robo.md) ---------------------------------------------

## Arma equipada en la mano principal (&"" = ninguna).
static func weapon() -> StringName:
	return InventoryLogic.equipped_in(GameState.equipped, InventoryLogic.SLOT_MAIN_HAND)


## El Adoc lleva un arma equipada. Para el sigilo: con el arma equipada, el Bosque no le deja pasar
## (sigilo-y-robo.md, regla 2); desequipada, no cierra el paso.
static func is_armed() -> bool:
	return weapon() != &""


## ATQ que suma el arma equipada (0 sin arma).
static func weapon_atk_bonus() -> int:
	return Items.atk_bonus(weapon())


## Stats con los que pelea el Adoc ahora: los de su nivel y sus puntos, más el ATQ del arma equipada
## y menos la DEF que restan las máscaras pesadas (Stealth.def_penalty, sin bajar de 0).
static func adoc_combat_stats() -> Dictionary:
	var stats: Dictionary = AdocGrowth.player_stats()
	stats.atk = int(stats.atk) + weapon_atk_bonus()
	stats.def = maxi(0, int(stats.def) - Stealth.def_penalty())
	return stats


## Con el arma en la mano, el Bosque `bosque_id` no le deja pasar en paz (sigilo-y-robo.md, regla
## 2: "Llevar armas equipadas hace que el bosque no te deje pasar"). El natal, sí; y los que no
## cobran (muerto: sin Nujio; necesita_ayuda: te ayuda), que tienen el borde abierto. `home` < 0:
## el natal de la partida actual.
static func is_armed_against(bosque_id: int, home: int = -1) -> bool:
	if not is_armed() or bosque_id < 0 or is_free_pass(bosque_id):
		return false
	return bosque_id != (home if home >= 0 else current_home())


## Bosque natal de la partida actual (seed y región de GameState).
static func current_home() -> int:
	return home_bosque(MapLogic.current_bosques(), ChunkGenerator.load_region(GameState.region_id))


## El Bosque deja pasar en paz: está pagado (o es el natal, o no cobra) y el Adoc no va armado
## contra él. Si no, sus Únicos le tratan como a quien no ha pagado: le ven, le persiguen y le cazan.
static func is_welcome(bosque_id: int, home: int) -> bool:
	return is_paid(bosque_id, home) and not is_armed_against(bosque_id, home)


## Equipa el objeto de la casilla `index` de la bolsa (el que había en su ranura vuelve a la bolsa).
## false si no se puede (casilla vacía, objeto que no se equipa o sin sitio para el anterior).
static func equip_from_bag(index: int) -> bool:
	var id: StringName = InventoryLogic.id_at(GameState.bag, index)
	var slot: StringName = InventoryLogic.slot_for(id)
	var previous: StringName = InventoryLogic.equipped_in(GameState.equipped, slot)
	if not InventoryLogic.equip(GameState.bag, GameState.equipped, index):
		return false
	if previous != &"":
		EventBus.item_unequipped.emit(slot, previous)
	EventBus.item_equipped.emit(slot, id)
	return true


## Desequipa una ranura (su objeto vuelve a la bolsa). false si estaba vacía o la bolsa está llena.
static func unequip_slot(slot: StringName) -> bool:
	var id: StringName = InventoryLogic.equipped_in(GameState.equipped, slot)
	if not InventoryLogic.unequip(GameState.bag, GameState.equipped, slot):
		return false
	EventBus.item_unequipped.emit(slot, id)
	return true


## Ofrendas de la bolsa como lista { id, luz } (una por unidad), la que usan el peaje y el combate.
static func bag_ofrendas() -> Array:
	return Ofrendas.from_bag(GameState.bag)


## Niveles que se alcanzan al pasar de `xp` a `xp + gained`, en orden (vacío si ninguno).
static func levels_gained(xp: int, gained: int) -> Array[int]:
	var out: Array[int] = []
	for level: int in range(level_for_xp(xp) + 1, level_for_xp(xp + gained) + 1):
		out.append(level)
	return out


## Suma XP al Adoc y aplica cada nivel nuevo: los PV actuales suben lo mismo que los máximos, llegan
## los puntos de stat (y de skill en los niveles pares, AdocGrowth.level_reached) y se emite
## character_leveled_up por nivel. Devuelve los niveles alcanzados.
static func gain_xp(amount: int) -> Array[int]:
	var gained: int = maxi(0, amount)
	var levels: Array[int] = levels_gained(GameState.xp, gained)
	GameState.xp += gained
	for level: int in levels:
		var before: int = max_hp()
		GameState.level = level
		AdocGrowth.level_reached(level)
		set_hp(GameState.hp + max_hp() - before)
		EventBus.character_leveled_up.emit(ADOC_ID, level)
	return levels


static func start_luz() -> int:
	return int(balance().adoc.start_luz)


## Tope de Luz suelta que puede llevar el Adoc: el de los datos más los puntos de Luz gastados.
static func luz_max() -> int:
	return int(balance().adoc.luz_max) + int(AdocGrowth.bonuses().luz_max)


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


## Suma `delta` a la relación con el Bosque, dentro de -relation_max .. relation_max. Si el paso
## está pagado, la amistad alta lo vuelve permanente y perderla le devuelve la caducidad (desde
## ahora). Con la relación en angry_candidate_at o menos, el Bosque queda marcado como candidato a
## enojarse (la marca no se borra).
static func change_relation(bosque_id: int, delta: int) -> void:
	var value: int = clampi(relation(bosque_id) + delta, -relation_max(), relation_max())
	GameState.bosque_relation[str(bosque_id)] = value
	if is_open(bosque_id):
		if value >= permanent_at():
			GameState.open_until[str(bosque_id)] = OPEN_PERMANENT
		elif is_open_permanent(bosque_id):
			GameState.open_until[str(bosque_id)] = GameState.riutash_count + paid_riutash()
	if value <= angry_candidate_at() and not GameState.angry_candidate.has(bosque_id):
		GameState.angry_candidate.append(bosque_id)
	EventBus.bosque_relation_changed.emit(bosque_id, value)
	# Relación <= angry_candidate_at con la marca de candidato: el Bosque se enoja (BosqueStates).
	if value <= angry_candidate_at() and is_angry_candidate(bosque_id):
		BosqueStates.make_angry(bosque_id)


# --- Relación con cada Bosque (bosques-y-relacion.md, #134 y #135) ------------------------------

static func _relation_cfg() -> Dictionary:
	return balance().bosque_relation


## Relación desde la que el paso pagado es permanente y el peaje más barato (amistad alta).
static func permanent_at() -> int:
	return int(_relation_cfg().permanent_at)


## Riutash que dura un pago: abre hasta el riutash número actual + este.
static func paid_riutash() -> int:
	return int(_relation_cfg().paid_riutash)


## Relación desde la que (hacia abajo) el Bosque queda marcado como candidato a enojarse.
static func angry_candidate_at() -> int:
	return int(_relation_cfg().angry_candidate_at)


static func is_angry_candidate(bosque_id: int) -> bool:
	return GameState.angry_candidate.has(bosque_id)


## Multiplicador del peaje por la relación: el primero de toll_factors que cumple (1 si ninguno).
static func relation_toll_factor(bosque_id: int) -> float:
	var r: int = relation(bosque_id)
	for f: Dictionary in _relation_cfg().toll_factors:
		if (f.has("min") and r >= int(f.min)) or (f.has("max") and r <= int(f.max)):
			return float(f.factor)
	return 1.0


## Peaje del Bosque a distancia d: 3 + d + hostility_toll × hostilidad (la hostilidad no lo sube por
## encima de toll_max; si la distancia ya lo supera, se queda en el de d) y, sobre eso, los
## multiplicadores del estado (corrupto ×1,5, BosqueStates.toll_factor) y de la relación
## (redondeado, 1 como mínimo) y, con la skill Palabra suave, menos su descuento (1 como mínimo).
## 0 si el estado no cobra (muerto, necesita_ayuda) o con salvoconducto
## (FarQuests.covers). El enojado tiene
## precio pero no lo acepta (can_pay_toll).
static func toll_for(bosque_id: int, d: int) -> int:
	if FarQuests.covers(bosque_id):
		return 0
	var state_factor: float = BosqueStates.toll_factor(bosque_state(bosque_id))
	if state_factor <= 0.0:
		return 0
	var base: int = toll_cost(d)
	var raised: int = base + int(_memory().hostility_toll) * hostility(bosque_id)
	var with_hostility: int = maxi(base, mini(raised, int(_memory().toll_max)))
	var toll: int = maxi(1, roundi(with_hostility * state_factor * relation_toll_factor(bosque_id)))
	return maxi(1, toll - AdocGrowth.toll_discount())


## Estado del Bosque en la partida (BosqueStates.state_of con el reparto de la partida actual).
static func bosque_state(bosque_id: int) -> String:
	return BosqueStates.state_of(bosque_id)


## Se le puede pagar el paso al Bosque: no si está enojado ("no cobran entrada pero no eres
## bienvenido") ni si no cobra (muerto, necesita_ayuda: ya está abierto).
static func can_pay_toll(bosque_id: int) -> bool:
	return bosque_id >= 0 and BosqueStates.can_pay(bosque_state(bosque_id))


## El Bosque no cobra peaje por su estado y su borde está abierto (muerto, necesita_ayuda).
static func is_free_pass(bosque_id: int) -> bool:
	return bosque_id >= 0 and BosqueStates.is_free(bosque_state(bosque_id))


## El paso pagado del Bosque sigue abierto (no cuenta el Bosque inicial, que siempre lo está).
static func is_open(bosque_id: int) -> bool:
	var key: String = str(bosque_id)
	if bosque_id < 0 or not GameState.open_until.has(key):
		return false
	var until: int = int(GameState.open_until[key])
	return until == OPEN_PERMANENT or GameState.riutash_count < until


static func is_open_permanent(bosque_id: int) -> bool:
	return GameState.open_until.has(str(bosque_id)) and int(GameState.open_until[str(bosque_id)]) == OPEN_PERMANENT


## Riutash que faltan para que caduque el paso: 2 = hasta el segundo riutash, 1 = hasta el
## próximo, OPEN_PERMANENT si no caduca y 0 si no está abierto.
static func open_riutash_left(bosque_id: int) -> int:
	if not is_open(bosque_id):
		return 0
	if is_open_permanent(bosque_id):
		return OPEN_PERMANENT
	return int(GameState.open_until[str(bosque_id)]) - GameState.riutash_count


## Ids de los Bosques con el paso pagado y abierto ahora (sin el inicial).
static func paid_bosques() -> Array[int]:
	var out: Array[int] = []
	for key: String in GameState.open_until:
		if is_open(int(key)):
			out.append(int(key))
	return out


## Borra los pasos caducados (tras un riutash): cada Bosque vuelve a cerrado, o a forzado si lo
## estaba, y sus Botarramas vuelven a estar activos. Avisa con bosque_toll_expired. Devuelve sus ids.
static func expire_tolls() -> Array[int]:
	var expired: Array[int] = []
	for key: String in GameState.open_until.keys():
		if not is_open(int(key)):
			GameState.open_until.erase(key)
			expired.append(int(key))
	for id: int in expired:
		EventBus.bosque_toll_expired.emit(id)
	return expired


## Deja una ofrenda de la bolsa ante el Nujio del Bosque, sin pagar nada con ella: sale de la
## bolsa, la relación sube su valor en Luz y la hostilidad baja 1 (sin bajar de 0), como al pagar
## con una ofrenda ("el bosque olvida con ofrendas"). false si no es una ofrenda de la bolsa.
static func leave_ofrenda(bosque_id: int, item_id: StringName) -> bool:
	if bosque_id < 0 or not Ofrendas.is_ofrenda(item_id) or InventoryLogic.count(GameState.bag, item_id) <= 0:
		return false
	InventoryLogic.remove(GameState.bag, item_id)
	_ofrenda_given(bosque_id, Items.luz_of(item_id))
	Senda.record(Senda.OFRENDA_LEFT)
	EventBus.bosque_ofrenda_left.emit(bosque_id, item_id)
	return true


## Tipos de ofrenda de la bolsa, uno por id, en el orden de las casillas (submenú del Nujio).
static func bag_ofrenda_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for item: Dictionary in bag_ofrendas():
		var id: StringName = StringName(str(item.id))
		if not out.has(id):
			out.append(id)
	return out


## Opción del submenú del Nujio: "<ofrenda> (<valor> Luz) ×<cantidad>".
static func nujio_ofrenda_option(item_id: StringName) -> String:
	var text: String = Texts.get_text("nujio_ofrenda_option") % [Ofrendas.display_name(item_id), Items.luz_of(item_id)]
	var qty: int = InventoryLogic.count(GameState.bag, item_id)
	if qty > 1:
		text += Texts.get_text("nujio_ofrenda_qty") % qty
	return text


static func _ofrenda_given(bosque_id: int, value: int) -> void:
	change_relation(bosque_id, value)
	if hostility(bosque_id) > 0:
		GameState.bosque_hostility[str(bosque_id)] = hostility(bosque_id) - 1


## Misión cumplida para el Bosque: relación + per_mission. Hoy, la del sfida (Bosque natal).
static func reward_bosque_mission(bosque_id: int) -> void:
	change_relation(bosque_id, int(_relation_cfg().per_mission))


## Defender el Bosque de un incendio o un ataque: relación + per_defense (BosqueFires.extinguish) y
## la Senda sube (salvar un Bosque).
static func reward_bosque_defense(bosque_id: int) -> void:
	change_relation(bosque_id, int(_relation_cfg().per_defense))
	Senda.record(Senda.BOSQUE_SAVED)


## Distancia (Chebyshev) de una casilla a la huella del Nujio del chunk (-1 si no hay Nujio).
static func distance_to_nujio(chunk: ChunkData, cell: Vector2i) -> int:
	var rect: Rect2i = chunk.nujio_rect
	if rect.size.x <= 0:
		return -1
	var dx: int = maxi(0, maxi(rect.position.x - cell.x, cell.x - (rect.end.x - 1)))
	var dy: int = maxi(0, maxi(rect.position.y - cell.y, cell.y - (rect.end.y - 1)))
	return maxi(dx, dy)


## Lugar de descanso junto al Nujio: a nujio_rest_radius casillas o menos de su huella, o la plaza
## de su villa (en un chunk con Nujio).
static func is_near_nujio(chunk: ChunkData, cell: Vector2i) -> bool:
	if chunk == null or not ChunkData.in_bounds(cell):
		return false
	var d: int = distance_to_nujio(chunk, cell)
	if d < 0:
		return false
	return d <= int(_relation_cfg().nujio_rest_radius) or (chunk.has_villa and chunk.get_tile(cell) == ChunkData.Tile.PLAZA)


## El riutash pasa con el Adoc en (chunk, cell) del Bosque `bosque_id`: si estaba refugiado junto
## a su Nujio, relación + per_nujio_rest (una vez por riutash: se llama una vez en cada uno).
## Devuelve si sumó.
static func riutash_near_nujio(chunk: ChunkData, cell: Vector2i, bosque_id: int, sheltered: bool) -> bool:
	if not sheltered or bosque_id < 0 or not is_near_nujio(chunk, cell):
		return false
	change_relation(bosque_id, int(_relation_cfg().per_nujio_rest))
	return true


## Radio de visión de un Botarramas del Bosque: el de sus datos + hostility_vision × hostilidad,
## con un extra de vision_max_bonus como mucho ("mira, observa"), más el del estado (enojado:
## detectan más lejos), menos la skill Paso quedo y menos el camuflaje del Adoc (Stealth). Sin
## camuflaje, 1 como mínimo; con él puede llegar a 0 (solo te ve si te echa encima, a su
## engage_distance).
static func vision_radius(bosque_id: int, base: int) -> int:
	var m: Dictionary = _memory()
	var radius: int = base + mini(int(m.vision_max_bonus), int(m.hostility_vision) * hostility(bosque_id))
	radius += BosqueStates.vision_bonus(bosque_state(bosque_id))
	radius -= AdocGrowth.vision_reduction()
	return Stealth.vision_against(maxi(1, radius), BosqueStates.stealth_vision_bonus())


## Stats del Único del Bosque a distancia d (deterministas: solo dependen de d). `unico_name`:
## nombre provisional, ver UnicoArt.display_name.
static func make_unico(d: int, unico_name: String, stats_block: String = "unico") -> Dictionary:
	var u: Dictionary = balance()[stats_block]
	var dc: int = clampi(d, 0, int(u.d_max))
	return {
		"name": unico_name,
		"max_hp": int(u.hp_base) + floori(float(u.hp_per_d) * dc),
		"atk": int(u.atk_base) + floori(float(u.atk_per_d) * dc),
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


## XP de vencer a un monstruo a distancia d: la suya si sus datos la fijan (xp_base + xp_per_d × d,
## los reparep), si no la de un Único (victory_xp).
static func monster_xp(monster_id: StringName, d: int) -> int:
	var cfg: Dictionary = monster_config(monster_id)
	if not cfg.has("xp_base"):
		return victory_xp(d)
	return int(cfg.xp_base) + int(cfg.get("xp_per_d", 0)) * clampi(d, 0, int(balance().unico.d_max))


## Tamaño de un grupo del monstruo (group_min .. group_max de sus datos), por `key` y seed. 1 si no
## va en grupo.
static func group_size(monster_id: StringName, seed_value: int, key: String) -> int:
	var cfg: Dictionary = monster_config(monster_id)
	var lo: int = int(cfg.get("group_min", 1))
	var hi: int = maxi(lo, int(cfg.get("group_max", lo)))
	return lo + ChunkGenerator.hash_ints([seed_value, key.hash(), SALT_GROUP]) % (hi - lo + 1)


## El monstruo no es un Único del Bosque (outsider, los reparep): no le importa el peaje en los
## Bosques sin Nujio o que necesitan ayuda, y allí los Únicos pelean a tu lado contra él.
static func is_outsider(monster_id: StringName) -> bool:
	return bool(monster_config(monster_id).get("outsider", false))


## Únicos aliados del Bosque en un combate dentro de él contra `monster_id` (bosques-y-relacion.md,
## "necesita ayuda": "algunos Únicos pelean junto a ti"): BosqueStates.allies_in_battle de su
## estado, solo contra quien no es un Único suyo (outsider). Stats de ally_monster a la d del Bosque.
static func bosque_allies(bosque_id: int, monster_id: StringName, d: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if bosque_id < 0 or not is_outsider(monster_id):
		return out
	var state: String = bosque_state(bosque_id)
	var n: int = BosqueStates.allies_in_battle(state)
	var kind: StringName = StringName(str(BosqueStates.state_config(state).get("ally_monster", "botarramas")))
	for i: int in n:
		var u: Dictionary = make_monster(kind, d)
		out.append({ "name": Texts.get_text("battle_ally_unico_name") % u.name, "max_hp": u.max_hp,
			"atk": u.atk, "def": u.def, "kind": kind })
	return out


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


## Se puede cruzar su frontera: el Bosque inicial, uno pagado, uno forzado o uno en el que el Adoc
## se ha colado y en el que sigue.
static func is_passable(bosque_id: int, home: int) -> bool:
	return is_paid(bosque_id, home) or is_forced(bosque_id) or is_sneaked(bosque_id)


# --- Colarse (Stealth, sigilo-y-robo.md) ---------------------------------------------------------

## El Adoc se ha colado en el Bosque y sigue dentro (lo hayan visto o no).
static func is_sneaked(bosque_id: int) -> bool:
	return bosque_id >= 0 and GameState.sneaked_bosques.has(str(bosque_id))


## Colado y sin que ningún Único le haya visto dentro: el Bosque no le caza.
static func is_sneaking_unseen(bosque_id: int) -> bool:
	return is_sneaked(bosque_id) and not bool(GameState.sneaked_bosques[str(bosque_id)])


## Se cuela en el Bosque cerrado `bosque_id`: queda colado (ni pagado ni forzado) y cada objeto
## equipado que se rompe gasta un uso. Avisa con bosque_sneaked (e item_broken por cada objeto
## que se deshace). Devuelve los ids de los objetos rotos. No comprueba si se puede
## (Stealth.can_sneak_into).
static func sneak_into(bosque_id: int) -> Array[StringName]:
	GameState.sneaked_bosques[str(bosque_id)] = false
	var broken: Array[StringName] = Stealth.spend_uses()
	EventBus.bosque_sneaked.emit(bosque_id)
	for id: StringName in broken:
		EventBus.item_broken.emit(id)
	return broken


## Un Único ha visto al Adoc: el camuflaje se rompe un rato y, si estaba colado en ese Bosque,
## el Bosque ya sabe que está dentro (le caza). Avisa con adoc_spotted.
static func spotted(bosque_id: int) -> void:
	Stealth.expose()
	if is_sneaked(bosque_id):
		GameState.sneaked_bosques[str(bosque_id)] = true
	EventBus.adoc_spotted.emit(bosque_id)


## El Adoc está en el Bosque `bosque_id`: deja de estar colado en los demás (hay que volver a
## colarse para entrar otra vez).
static func leave_sneaked(bosque_id: int) -> void:
	for key: String in GameState.sneaked_bosques.keys():
		if int(key) != bosque_id:
			GameState.sneaked_bosques.erase(key)


## El Bosque inicial, uno con el peaje pagado y sin caducar, uno que no cobra por su estado
## (muerto, necesita_ayuda) o uno con salvoconducto (el que llama o uno de la ruta de una misión
## lejana activa, FarQuests.covers): sus Botarramas quedan pasivos y da permiso para el fruto.
static func is_paid(bosque_id: int, home: int) -> bool:
	return bosque_id >= 0 and (bosque_id == home or is_open(bosque_id) or is_free_pass(bosque_id) 		or FarQuests.covers(bosque_id))


## Forzado: se venció a alguno de sus Botarramas sin pagar (o el pago ha caducado). Se cruza, pero
## los demás siguen activos.
static func is_forced(bosque_id: int) -> bool:
	return bosque_id >= 0 and GameState.forced_bosques.has(bosque_id) and not is_open(bosque_id)


## Abre el paso del Bosque: hasta el riutash número actual + paid_riutash, o para siempre con
## amistad alta (relación >= permanent_at). La marca de forzado se queda para cuando caduque.
static func open_bosque(bosque_id: int) -> void:
	if relation(bosque_id) >= permanent_at():
		GameState.open_until[str(bosque_id)] = OPEN_PERMANENT
	else:
		GameState.open_until[str(bosque_id)] = GameState.riutash_count + paid_riutash()


## Pago del peaje (Luz, ofrenda u Ofrecer Luz en combate): mejora la relación y abre el Bosque
## (después: si la relación llega a la amistad alta, el paso es permanente) y queda como el último
## Bosque pagado (destino de reaparición, respawn_target). Con Luz, la relación
## sube relation_per_payment. Con una ofrenda (`ofrenda_value` >= 0) sube su valor y la hostilidad
## baja 1, sin bajar de 0 ("el bosque olvida con ofrendas", dueño, #147).
static func _paid(bosque_id: int, ofrenda_value: int = -1) -> void:
	GameState.last_paid_bosque = bosque_id
	if ofrenda_value >= 0:
		_ofrenda_given(bosque_id, ofrenda_value)
	else:
		change_relation(bosque_id, int(_memory().relation_per_payment))
	_senda_paid(ofrenda_value)
	open_bosque(bosque_id)


## La Senda sube al pagar: con Luz (pay_luz) o con una ofrenda (`ofrenda_value` >= 0, pay_ofrenda).
static func _senda_paid(ofrenda_value: int) -> void:
	Senda.record(Senda.PAY_OFRENDA if ofrenda_value >= 0 else Senda.PAY_LUZ)


## Un Botarramas del Bosque ha sido vencido (o se ha apartado ante Imponerse): el Bosque queda
## forzado (si no estaba pagado), lo recuerda (+1 de hostilidad), la relación baja y la Senda también.
static func guardian_defeated(bosque_id: int) -> void:
	if not is_open(bosque_id) and not GameState.forced_bosques.has(bosque_id):
		GameState.forced_bosques.append(bosque_id)
	GameState.bosque_hostility[str(bosque_id)] = hostility(bosque_id) + 1
	change_relation(bosque_id, int(_memory().relation_per_kill))
	Senda.record(Senda.GUARDIAN_DEFEATED)


# --- Imponerse (skill S4, moralidad-y-progresion.md) ------------------------------------------------

## Con la skill Imponerse, el Botarramas del Bosque a distancia d se aparta sin pelear: el nivel del
## Adoc llega a d + level_margin y el Bosque no está enojado ("no funciona").
static func can_impose(bosque_id: int, d: int) -> bool:
	if not AdocGrowth.has_skill(AdocGrowth.IMPONERSE) or bosque_id < 0:
		return false
	if bosque_state(bosque_id) == BosqueStates.ENOJADO:
		return false
	var margin: int = int(AdocGrowth.skill_config(AdocGrowth.IMPONERSE).get("level_margin", 2))
	return GameState.level >= d + margin


## Se impone al Botarramas: cuenta como vencerlo (Bosque forzado, hostilidad +1, relación y Senda a
## la baja), sin XP ni Luz. false si no puede.
static func impose(bosque_id: int, d: int) -> bool:
	if not can_impose(bosque_id, d):
		return false
	guardian_defeated(bosque_id)
	return true


## Fija el estado de bando (dos-caminos.md). Garelino solo lo fija el encuentro de historia (otro
## PR); fiel y en duda los mueve la Senda sola (Senda.update_bando).
static func set_bando(bando: StringName) -> bool:
	return Senda.set_bando(bando)


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
	_paid(bosque_id)
	return true


## Paga el peaje con la ofrenda `index` de bag_ofrendas() (ofrendas-v1.md): se deja entera (sale
## de la bolsa), se completa con Luz suelta si no llega y el excedente se pierde. Abre el paso.
## false si no alcanza.
static func pay_toll_with_ofrenda(bosque_id: int, cost: int, index: int) -> bool:
	var ofrendas: Array = bag_ofrendas()
	if index < 0 or index >= ofrendas.size():
		return false
	var value: int = int(ofrendas[index].luz)
	if not Ofrendas.can_pay(value, GameState.luz, cost):
		return false
	InventoryLogic.remove(GameState.bag, StringName(str(ofrendas[index].id)))
	set_luz(GameState.luz - Ofrendas.luz_needed(value, cost))
	_paid(bosque_id, value)
	return true


## Prepara un combate nuevo contra el Botarramas que guarda el Bosque. Cuenta el intento (cambia la
## semilla) y el rival empieza siempre con todos sus PV: huir o retroceder no conserva el daño hecho.
## Combate en grupo (monstruos.md): `count` enemigos del mismo tipo (numerados si son más de uno;
## los de joint_attack atacan juntos) y XP por cada uno. Aliados: `allies` (p. ej. un adoc NPC,
## AdocEncounters) y los Únicos del Bosque si su estado los da (bosque_allies), 2 como mucho.
static func start_battle(bosque_id: int, d: int, monster_id: StringName = &"botarramas", count: int = 1,
		allies: Array[Dictionary] = []) -> BattleLogic:
	var key: String = str(bosque_id)
	var attempt: int = int(GameState.battle_attempts.get(key, 0))
	GameState.battle_attempts[key] = attempt + 1
	var logic := BattleLogic.new(balance(), adoc_combat_stats(), GameState.hp, GameState.luz,
		make_monster(monster_id, d), battle_seed(GameState.seed_value, bosque_id, attempt))
	var cfg: Dictionary = monster_config(monster_id)
	count = clampi(count, 1, MAX_ENEMIES)
	for i: int in count - 1:
		logic.add_enemy(make_monster(monster_id, d))
	if count > 1:
		for i: int in count:
			logic.enemies[i].name = Texts.get_text("battle_enemy_numbered") % [logic.enemies[i].name, i + 1]
	logic.joint_attack = bool(cfg.get("joint_attack", false))
	logic.monster_id = monster_id
	var all_allies: Array[Dictionary] = allies.duplicate()
	all_allies.append_array(bosque_allies(bosque_id, monster_id, d))
	all_allies.append_array(called_allies(bosque_id, monster_id, d))
	for ally: Dictionary in all_allies.slice(0, MAX_ALLIES):
		logic.add_ally(ally)
	_prepare(logic, cfg, d)
	logic.victory_xp = monster_xp(monster_id, d) * count
	logic.level_ups = levels_gained(GameState.xp, logic.victory_xp)
	if not is_outsider(monster_id):
		logic.loot_id = loot_for(GameState.seed_value, bosque_id, attempt)
	logic.toll = toll_for(bosque_id, d)
	# Un Bosque enojado no acepta pagos; uno que no cobra no tiene peaje que ofrecer.
	logic.accepts_payment = logic.accepts_payment and can_pay_toll(bosque_id)
	logic.ofrendas = bag_ofrendas()
	EventBus.battle_started.emit(bosque_id)
	return logic


## Aplica a GameState el final de un combate de borde. Devuelve el resultado como StringName
## (&"victory", &"defeat", &"fled", &"appeased" si el Único se fue con Luz o una ofrenda o
## &"game_over" si el rival era fatal). Apaciguar paga el peaje (abre el Bosque); vencer lo fuerza
## y el Bosque lo recuerda.
static func finish_battle(logic: BattleLogic, bosque_id: int) -> StringName:
	var outcome: StringName = _apply_result(logic)
	if outcome == &"appeased":
		var value: int = -1
		if logic.ofrenda_index >= 0 and logic.ofrenda_index < logic.ofrendas.size():
			value = int(logic.ofrendas[logic.ofrenda_index].luz)
		_paid(bosque_id, value)
	elif outcome == &"victory":
		guardian_defeated(bosque_id)
	EventBus.battle_ended.emit(bosque_id, outcome)
	return outcome


## Final de un combate directo contra un Único de dentro del Bosque (perseguidor por robo, cazador,
## uno que ronda o uno al que el Adoc se enfrenta a voluntad). Apaciguarlo (Ofrecer Luz u ofrenda)
## paga el peaje de su Bosque, como con un Botarramas; en el Bosque natal (que no cobra paso) solo
## cuenta para la relación, sin abrir nada. Vencerlo: unico_defeated. Mismos resultados que
## finish_battle.
static func finish_unico_battle(logic: BattleLogic, bosque_id: int, home: int, offends: bool = false) -> StringName:
	var outcome: StringName = _apply_result(logic)
	if outcome == &"appeased":
		var value: int = -1
		if logic.ofrenda_index >= 0 and logic.ofrenda_index < logic.ofrendas.size():
			value = int(logic.ofrendas[logic.ofrenda_index].luz)
		if bosque_id != home:
			_paid(bosque_id, value)
		else:
			if value >= 0:
				_ofrenda_given(bosque_id, value)
			else:
				change_relation(bosque_id, int(_memory().relation_per_payment))
			_senda_paid(value)
	elif outcome == &"victory" and not is_outsider(logic.monster_id):
		# Vencer a quien no es un Único del Bosque (los reparep) no ofende al Bosque.
		unico_defeated(bosque_id, home, offends)
	EventBus.battle_ended.emit(bosque_id, outcome)
	return outcome


## Un Único de dentro del Bosque ha sido vencido: el Bosque lo recuerda (+1 de hostilidad) y la
## relación baja relation_per_kill, como con un Botarramas, y la Senda baja (unico_defeated; y además
## offend si se le atacó con el paso abierto). Con `offends` (se le atacó a voluntad con el paso
## abierto), un Bosque pagado que no sea el natal pasa a forzado: el pago se pierde.
static func unico_defeated(bosque_id: int, home: int, offends: bool = false) -> void:
	GameState.bosque_hostility[str(bosque_id)] = hostility(bosque_id) + 1
	change_relation(bosque_id, int(_memory().relation_per_kill))
	Senda.record(Senda.UNICO_DEFEATED)
	if offends:
		Senda.record(Senda.OFFEND)
	if offends and bosque_id != home and is_open(bosque_id):
		GameState.open_until.erase(str(bosque_id))
		if not GameState.forced_bosques.has(bosque_id):
			GameState.forced_bosques.append(bosque_id)


## Combate de misión contra su monstruo (`target` del JSON de la misión, p. ej. el Ofomni descarriado) con su d
## fija. No abre Bosques y su contador de intentos (semilla) es el de la misión.
static func start_quest_battle(quest_id: StringName, d: int) -> BattleLogic:
	var q: Dictionary = GameState.quests.get(quest_id, {})
	var attempt: int = int(q.get("battle_attempts", 0))
	q.battle_attempts = attempt + 1
	GameState.quests[quest_id] = q
	var target: StringName = StringName(str(QuestLogic.data(quest_id).get("target", "")))
	var rng_seed: int = ChunkGenerator.hash_ints([GameState.seed_value, String(quest_id).hash(), attempt, SALT_QUEST_BATTLE])
	var logic := BattleLogic.new(balance(), adoc_combat_stats(), GameState.hp, GameState.luz,
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
	# Sin arma se pelea con el ATQ base (y el combate lo avisa: "Peleas sin arma").
	logic.unarmed = not is_armed()
	logic.victory_xp = victory_xp(d)
	logic.level_ups = levels_gained(GameState.xp, logic.victory_xp)
	logic.luz_max = luz_max()
	# Skill Golpe fuerte (S2): pasiva, el primer ataque disponible hace factor× de daño, como mucho
	# uno cada `every` turnos.
	if AdocGrowth.has_skill(AdocGrowth.GOLPE_FUERTE):
		var strong: Dictionary = AdocGrowth.skill_config(AdocGrowth.GOLPE_FUERTE)
		logic.strong_every = int(strong.get("every", 3))
		logic.strong_factor = float(strong.get("factor", 1.5))


# --- Skills en combate (moralidad-y-progresion.md) ------------------------------------------------

## Skill Botín (S3): ofrenda que deja el Único si se le vence (&"" = ninguna). Determinista por seed,
## Bosque e intento: `chance` de una ofrenda al azar entre las del catálogo con valor en `values`.
static func loot_for(seed_value: int, bosque_id: int, attempt: int) -> StringName:
	if not AdocGrowth.has_skill(AdocGrowth.BOTIN):
		return &""
	var cfg: Dictionary = AdocGrowth.skill_config(AdocGrowth.BOTIN)
	var h: int = ChunkGenerator.hash_ints([seed_value, bosque_id, attempt, SALT_LOOT])
	if float(h % 1000) >= float(cfg.get("chance", 0.0)) * 1000.0:
		return &""
	var values: Array = cfg.get("values", [3, 4])
	var ids: Array[StringName] = []
	for entry: Variant in Ofrendas.catalog():
		var luz: int = int((entry as Dictionary).get("luz", 0))
		if luz >= int(values[0]) and luz <= int(values[values.size() - 1]):
			ids.append(StringName(str(entry.id)))
	if ids.is_empty():
		return &""
	return ids[(h / 1000) % ids.size()]


## Skill Llamada del Bosque (C4): en un Bosque con relación >= relation, `allies` Únicos suyos pelean a
## tu lado contra quien no es un Único del Bosque (outsider, como los reparep). Stats de Botarramas
## a la d del Bosque, como los aliados de un Bosque que necesita ayuda.
static func called_allies(bosque_id: int, monster_id: StringName, d: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not AdocGrowth.has_skill(AdocGrowth.LLAMADA_BOSQUE) or bosque_id < 0 or not is_outsider(monster_id):
		return out
	var cfg: Dictionary = AdocGrowth.skill_config(AdocGrowth.LLAMADA_BOSQUE)
	if relation(bosque_id) < int(cfg.get("relation", 30)) or bosque_state(bosque_id) == BosqueStates.MUERTO:
		return out
	for i: int in int(cfg.get("allies", 1)):
		var u: Dictionary = make_monster(&"botarramas", d)
		out.append({ "name": Texts.get_text("battle_ally_unico_name") % u.name, "max_hp": u.max_hp,
			"atk": u.atk, "def": u.def, "kind": &"botarramas" })
	return out


static func _apply_result(logic: BattleLogic) -> StringName:
	var b: Dictionary = balance()
	match logic.result:
		BattleLogic.Result.VICTORY:
			set_hp(logic.adoc_hp)
			set_luz(logic.luz + int(b.victory_luz))
			gain_xp(logic.victory_xp)
			# Botín (S3): la ofrenda va a la bolsa si cabe (si no, se queda en el Bosque).
			if logic.loot_id != &"":
				logic.loot_taken = InventoryLogic.add(GameState.bag, logic.loot_id)
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
			set_hp(respawn_hp(max_hp()))
			set_luz(floori(logic.luz * float(b.defeat_luz_factor)))
			return &"defeat"
	set_hp(logic.adoc_hp)
	set_luz(logic.luz)
	return &"fled"


# --- Reaparición tras una derrota no fatal (cruce-y-combate-v2.md) ------------------------------

static func _respawn_cfg() -> Dictionary:
	return balance().respawn


## PV con que se despierta tras una derrota no fatal: hp_pct de los PV máximos (redondeo hacia
## arriba, mínimo 1).
static func respawn_hp(max_value: int) -> int:
	return clampi(ceili(max_value * float(_respawn_cfg().hp_pct) / 100.0), 1, maxi(1, max_value))


## Aliado para reaparecer: el Bosque natal, o uno con relación >= ally_relation que no esté
## forzado (vencer a un Botarramas sin pagar no lo hace aliado) ni muerto (no tiene Nujio).
static func is_ally(bosque_id: int, home: int) -> bool:
	if bosque_id < 0:
		return false
	if bosque_id == home:
		return true
	return relation(bosque_id) >= int(_respawn_cfg().ally_relation) and not is_forced(bosque_id) 		and bosque_state(bosque_id) != BosqueStates.MUERTO


## Bosque en cuyo Nujio se despierta tras caer en el chunk `fell_at`: el más cercano (chunks,
## Manhattan, hasta su chunk de Nujio) entre los aliados (is_ally, con el natal) y el último Bosque
## pagado (GameState.last_paid_bosque). Empates: el natal, luego el último pagado, luego el id más
## bajo. Sin ninguno válido, el natal (villa natal).
static func respawn_target(map: BosqueMap, fell_at: Vector2i, home: int) -> int:
	var best: int = home
	var best_key: int = 1 << 30
	var last_paid: int = GameState.last_paid_bosque
	for id: int in map.count():
		if id != last_paid and not is_ally(id, home):
			continue
		# Sin Nujio (Bosque muerto) no hay junto a quién despertar.
		if not map.has_nujio(id):
			continue
		var c: Vector2i = map.nujio_chunk[id]
		var dist: int = absi(c.x - fell_at.x) + absi(c.y - fell_at.y)
		var rank: int = 0 if id == home else (1 if id == last_paid else 2)
		var key: int = (dist * 3 + rank) * (map.count() + 1) + id
		if key < best_key:
			best = id
			best_key = key
	return best


## Casilla donde se despierta en el chunk del Nujio: una transitable junto a su huella (también en
## diagonal) y a la que se llega desde el hub, la más cercana a la casilla al sur de su centro
## (empates por fila y columna). Sin ninguna, el hub (en un Bosque con villa, la plaza).
static func respawn_cell(chunk: ChunkData) -> Vector2i:
	var rect: Rect2i = chunk.nujio_rect
	if rect.size.x <= 0:
		return chunk.hub
	var south := Vector2i(rect.position.x + rect.size.x / 2, rect.end.y)
	var ring: Rect2i = rect.grow(1)
	var best: Vector2i = chunk.hub
	var best_score: int = 1 << 30
	for y: int in range(ring.position.y, ring.end.y):
		for x: int in range(ring.position.x, ring.end.x):
			var c := Vector2i(x, y)
			if rect.has_point(c) or not chunk.is_walkable(c) or not chunk.is_reachable(c):
				continue
			var score: int = (absi(c.x - south.x) + absi(c.y - south.y)) * ChunkData.SIZE * ChunkData.SIZE 				+ y * ChunkData.SIZE + x
			if score < best_score:
				best = c
				best_score = score
	return best


## Aviso de dónde se despierta: "Despiertas junto al Nujio de <villa>." si el Bosque tiene villa;
## si no, el del Bosque sin villa.
static func respawn_notice(map: BosqueMap, bosque_id: int) -> String:
	if bosque_id >= 0 and map.has_villa[bosque_id]:
		return Texts.get_text("respawn_villa") % Signpost.villa_name(GameState.seed_value, bosque_id)
	return Texts.get_text("respawn_bosque")


## Quita de la bolsa la ofrenda entregada en combate (una unidad de su id).
static func _remove_offered(logic: BattleLogic) -> void:
	if logic.ofrenda_index < 0 or logic.ofrenda_index >= logic.ofrendas.size():
		return
	InventoryLogic.remove(GameState.bag, StringName(str(logic.ofrendas[logic.ofrenda_index].id)))


## La ofrenda de la recompensa (si la hay) cabe en la bolsa. Si no, quien la da espera a que haya
## sitio (QuestRunner avisa "Tu bolsa está llena" y no la entrega).
static func can_take_reward(reward: Dictionary) -> bool:
	return not reward.has("ofrenda") or InventoryLogic.can_add(GameState.bag, StringName(str(reward.ofrenda)))


## Recompensa de una misión (mision-ofomni.md): Luz al tope, una ofrenda a la bolsa, XP y fama.
## `reward` es el bloque "reward" del JSON de la misión (el valor en Luz sale del catálogo). Si la
## XP sube de nivel, lo anuncia en el HUD (fuera del combate no hay narración). `bosque_id`: el
## Bosque para el que era la misión (la del sfida, el natal), que sube la relación con él
## (reward_bosque_mission); -1 = ninguno.
static func apply_quest_reward(reward: Dictionary, bosque_id: int = -1) -> void:
	if bosque_id >= 0:
		reward_bosque_mission(bosque_id)
	if bool(reward.get("refill_luz_to_max", false)):
		set_luz(luz_max())
	if reward.has("ofrenda"):
		InventoryLogic.add(GameState.bag, StringName(str(reward.ofrenda)))
	GameState.fama += int(reward.get("fama", 0))
	var lines: PackedStringArray = []
	for level: int in gain_xp(int(reward.get("xp", 0))):
		lines.append(Texts.get_text("level_up") % level)
	if not lines.is_empty():
		lines.append(Texts.get_text("growth_points_hint"))
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


## Recoge el hallazgo del refugio del chunk: lo añade a la bolsa y lo marca, una sola vez por
## partida. Devuelve { id, luz, taken } o {} si no había nada o ya se recogió. Con la bolsa llena,
## taken = false: el objeto se queda y el refugio no se marca como saqueado.
static func loot_refuge(coord: Vector2i) -> Dictionary:
	var id: StringName = refuge_ofrenda(GameState.seed_value, coord)
	if id == &"" or is_refuge_looted(coord):
		return {}
	var item: Dictionary = Ofrendas.make_item(id)
	item.taken = InventoryLogic.add(GameState.bag, id)
	if item.taken:
		GameState.looted_refuges.append(coord)
	return item


# --- Robo al Bosque (bosques-y-relacion.md, sigilo-y-robo.md) ---------------------------------

## Robo al Bosque `bosque_id` (hoy: tomar fruto sin permiso o un segundo fruto del mismo Bosque
## en el mismo Momento, FruitRules).
## El Bosque lo recuerda: hostilidad + hostility_per_theft (1) y relación + relation_per_theft
## (−20), bloque bosque_memory. Avisa con bosque_robbed: la exploración despierta a los Ofomni que
## persiguen (OfomniGuard).
static func record_theft(bosque_id: int) -> void:
	GameState.bosque_hostility[str(bosque_id)] = hostility(bosque_id) + int(_memory().hostility_per_theft)
	change_relation(bosque_id, int(_memory().relation_per_theft))
	Senda.record(Senda.THEFT)
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


## Aplica el riutash al Adoc. Devuelve el cambio de PV (negativo si hiere). Con la skill Descanso del
## Nujio (C3), en refugio dentro de un Bosque pagado (o el natal) cura su heal_pct de lo que falta.
## `bosque_id` < -1: el del chunk actual (GameState.chunk_coord).
static func apply_riutash(sheltered: bool, bosque_id: int = -2) -> int:
	var before: int = GameState.hp
	var pct: int = AdocGrowth.nujio_rest_heal_pct()
	if sheltered and pct >= 0:
		var map: BosqueMap = MapLogic.current_bosques() if bosque_id < -1 else null
		var id: int = map.bosque_at(GameState.chunk_coord) if map != null and GameState.chunk_coord.x >= 0 else bosque_id
		if id >= 0 and is_paid(id, current_home()):
			set_hp(rest_heal_hp(before, max_hp(), pct))
			return GameState.hp - before
	set_hp(riutash_hp(before, max_hp(), sheltered))
	return GameState.hp - before


## PV tras un riutash en refugio que cura `pct` % de lo que falta (redondeo hacia arriba).
static func rest_heal_hp(hp: int, hp_max: int, pct: int) -> int:
	return mini(hp_max, hp + ceili(maxi(0, hp_max - hp) * pct / 100.0))
