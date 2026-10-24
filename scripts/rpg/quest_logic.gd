class_name QuestLogic
extends RefCounted
## Misiones (ficha mision-ofomni.md). Lógica pura sobre el diccionario de estado de una misión
## (el que se guarda en GameState.quests[id]) y la ruta del Ofomni por el grafo de Bosques.
## Estados: offered -> active -> completed -> rewarded, o active -> failed.
## Solo commit() toca GameState y emite EventBus.quest_state_changed. Números y textos en
## data/quests/<id>.json.

const QUEST_PATH: String = "res://data/quests/%s.json"
const PRIMERA_MISION: StringName = &"primera_mision"

const OFFERED: StringName = &"offered"
const ACTIVE: StringName = &"active"
const COMPLETED: StringName = &"completed"
const REWARDED: StringName = &"rewarded"
const FAILED: StringName = &"failed"
const TRANSITIONS: Dictionary = {
	&"offered": [&"active"],
	&"active": [&"completed", &"failed"],
	&"completed": [&"rewarded"],
}

const SALT_SPAWN: int = 31
const SALT_ROUTE: int = 32

static var _data: Dictionary = {}


static func data(quest_id: StringName) -> Dictionary:
	if not _data.has(quest_id):
		var path: String = QUEST_PATH % quest_id
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(parsed is Dictionary, "No se pudo leer %s" % path)
		_data[quest_id] = parsed
	return _data[quest_id]


## Estado inicial de una misión: ofrecida, con el Ofomni aún sin aparecer.
## declined: el jugador dijo "Aún no" (sigue offered). failed_told: el sfida ya contó el fracaso.
## target_defeated: el monstruo fue vencido (también después de fallar).
static func new_quest() -> Dictionary:
	return {
		"state": String(OFFERED),
		"declined": false,
		"ofomni_bosque": -1,
		"ofomni_elapsed": 0.0,
		"ofomni_d": 0,
		"target_defeated": false,
		"failed_told": false,
		"battle_attempts": 0,
	}


## Estado leído de un guardado (JSON: números como float). Rellena lo que falte.
static func sanitize(raw: Variant) -> Dictionary:
	var q: Dictionary = new_quest()
	if not raw is Dictionary:
		return q
	var state: StringName = StringName(str(raw.get("state", OFFERED)))
	q.state = String(state) if state in [OFFERED, ACTIVE, COMPLETED, REWARDED, FAILED] else String(OFFERED)
	q.declined = bool(raw.get("declined", false))
	q.ofomni_bosque = int(raw.get("ofomni_bosque", -1))
	q.ofomni_elapsed = maxf(0.0, float(raw.get("ofomni_elapsed", 0.0)))
	q.ofomni_d = int(raw.get("ofomni_d", 0))
	q.target_defeated = bool(raw.get("target_defeated", false))
	q.failed_told = bool(raw.get("failed_told", false))
	q.battle_attempts = int(raw.get("battle_attempts", 0))
	return q


static func state_of(q: Dictionary) -> StringName:
	return StringName(str(q.get("state", OFFERED)))


static func can_transition(from: StringName, to: StringName) -> bool:
	return (TRANSITIONS.get(from, []) as Array).has(to)


## Cambia el estado si la transición es válida. true si ha cambiado.
static func transition(q: Dictionary, to: StringName) -> bool:
	if not can_transition(state_of(q), to):
		return false
	q.state = String(to)
	return true


## Guarda la misión en GameState y, si su estado ha cambiado respecto a `before`, lo anuncia.
static func commit(quest_id: StringName, q: Dictionary, before: StringName) -> void:
	GameState.quests[quest_id] = q
	if state_of(q) != before:
		EventBus.quest_state_changed.emit(quest_id, state_of(q))


# --- Ofomni errante ---

## Bosque donde nace el Ofomni: a hops_min..hops_max saltos del natal, elegido por seed entre los
## candidatos ordenados por id. Si la región no tiene ninguno a esa distancia, el más lejano.
static func spawn_bosque(map: BosqueMap, seed_value: int, home: int, hops_min: int, hops_max: int) -> int:
	var candidates: Array[int] = []
	var farthest: int = -1
	var farthest_d: int = 0
	for id: int in map.count():
		if map.size_of(id) == 0:
			continue
		var d: int = map.distance(home, id)
		if d >= hops_min and d <= hops_max:
			candidates.append(id)
		if d > farthest_d and d <= hops_max:
			farthest_d = d
			farthest = id
	if candidates.is_empty():
		return farthest
	return candidates[ChunkGenerator.hash_ints([seed_value, home, SALT_SPAWN]) % candidates.size()]


## Siguiente Bosque del Ofomni: un vecino un salto más cerca del natal (desempate por seed).
static func next_bosque(map: BosqueMap, seed_value: int, from: int, home: int) -> int:
	var d: int = map.distance(from, home)
	if d <= 0:
		return from
	var closer: Array[int] = []
	for n: int in map.neighbours_of(from):
		if map.distance(n, home) == d - 1:
			closer.append(n)
	closer.sort()
	return closer[ChunkGenerator.hash_ints([seed_value, from, SALT_ROUTE]) % closer.size()]


## Ruta completa desde `from` hasta el natal (incluidos los dos).
static func route(map: BosqueMap, seed_value: int, from: int, home: int) -> Array[int]:
	var out: Array[int] = [from]
	while out.back() != home and out.size() <= map.count():
		out.append(next_bosque(map, seed_value, out.back(), home))
	return out


## Acepta la misión: pasa a active y hace aparecer al Ofomni con su d fija (saltos + 1).
static func accept(q: Dictionary, map: BosqueMap, seed_value: int, home: int) -> bool:
	if not transition(q, ACTIVE):
		return false
	var cfg: Dictionary = data(PRIMERA_MISION).ofomni
	var bosque: int = spawn_bosque(map, seed_value, home, int(cfg.spawn_hops_min), int(cfg.spawn_hops_max))
	q.ofomni_bosque = bosque
	q.ofomni_elapsed = 0.0
	q.ofomni_d = maxi(1, map.distance(bosque, home)) + 1
	return true


## Avanza el reloj del Ofomni `seconds` segundos: un Bosque cada `every` hacia el natal, solo con
## la misión active. Al entrar en el natal la misión pasa a failed. Devuelve los Bosques avanzados.
static func advance(q: Dictionary, seconds: float, map: BosqueMap, seed_value: int, home: int, every: float) -> int:
	if state_of(q) != ACTIVE or int(q.ofomni_bosque) < 0 or every <= 0.0:
		return 0
	var moves: int = 0
	q.ofomni_elapsed = float(q.ofomni_elapsed) + seconds
	while float(q.ofomni_elapsed) >= every and int(q.ofomni_bosque) != home:
		q.ofomni_elapsed = float(q.ofomni_elapsed) - every
		q.ofomni_bosque = next_bosque(map, seed_value, int(q.ofomni_bosque), home)
		moves += 1
	if int(q.ofomni_bosque) == home:
		q.ofomni_elapsed = 0.0
		transition(q, FAILED)
	return moves


## El Ofomni está en el mundo: misión active, o fallida y aún sin vencer (espera en la villa).
static func ofomni_present(q: Dictionary) -> bool:
	var state: StringName = state_of(q)
	return int(q.get("ofomni_bosque", -1)) >= 0 and (state == ACTIVE or (state == FAILED and not bool(q.target_defeated)))


## Chunk donde se ve al Ofomni: el de su Bosque más cercano a la villa natal (empates por fila y
## columna). En el Bosque natal, el chunk de la villa.
static func ofomni_chunk(map: BosqueMap, bosque: int, home: int) -> Vector2i:
	var villa: Vector2i = map.nujio_chunk[home]
	if bosque == home:
		return villa
	var best := Vector2i(-1, -1)
	var best_score: int = 1 << 30
	for c: Vector2i in map.chunks_of(bosque):
		var score: int = (c - villa).length_squared() * 10_000 + c.y * 100 + c.x
		if score < best_score:
			best_score = score
			best = c
	return best


## Vencido el monstruo de la misión: active -> completed. Si ya había fallado, se marca vencido.
static func target_defeated(q: Dictionary) -> void:
	q.target_defeated = true
	transition(q, COMPLETED)


## Cobra la recompensa: completed -> rewarded y devuelve el bloque "reward". Una sola vez: en
## cualquier otro estado devuelve {}.
static func claim_reward(q: Dictionary, quest_id: StringName = PRIMERA_MISION) -> Dictionary:
	if not transition(q, REWARDED):
		return {}
	return data(quest_id).get("reward", {})


## Bloque de texto (texts.<bloque> del JSON) que dice quien da la misión según su estado.
static func giver_block(q: Dictionary) -> String:
	match state_of(q):
		OFFERED:
			return "offer"
		ACTIVE:
			return "reminder"
		COMPLETED:
			return "completed_return"
		REWARDED:
			return "rewarded_idle"
		FAILED:
			if bool(q.target_defeated):
				return "failed_victory_return"
			return "failed_reminder" if bool(q.failed_told) else "failed"
	return ""
