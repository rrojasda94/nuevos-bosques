class_name BosqueStates
extends RefCounted
## Estados de Bosque en la partida (bosques-y-relacion.md, #133; palabras del dueño: "hay bosques
## sanos, bosques enojados, bosques corruptos, bosques muertos y bosques en necesidad de ayuda").
## Lógica pura sobre ids de Bosque:
## - El estado de generación sale de BosqueMap.state (por seed). Los cambios de la partida viven en
##   GameState.bosque_state_overrides (se guardan) y mandan sobre el de generación.
## - sano: sin efecto nuevo.
## - enojado: no se puede pagar (el menú del borde solo ofrece enfrentar o retroceder, y sus
##   Únicos no aceptan Luz ni ofrendas); más Únicos rondando, cazadores desde que entras y más a
##   menudo, y sus Botarramas ven más lejos. Sigilo (Stealth): el camuflaje resta visión
##   (stealth_vision_bonus) y, con camuflaje alto o velocidad, sus cazadores tardan más
##   (stealth_hunt_factor).
## - corrupto: peaje × toll_factor; sus Únicos a veces atacan aunque hayas pagado (ambushes, por
##   Único y por Momento); riesgo de Iserald (solo el aviso al entrar: el Iserald llega más tarde).
## - muerto: sin Nujio y sin peaje; un solo Único que ronda y que, a veces, es "independiente": te
##   pide 1–2 de Luz al cruzarte y, si no pagas, te ataca. Sin frutos.
## - necesita_ayuda: sin peaje; da fruto; incendios (BosqueFires); sus Únicos son amistosos y no
##   persiguen. Gancho del combate en grupo (PR 7): allies_in_battle.
## - Un Bosque sano o que necesita ayuda pasa a enojado si la relación cae a angry_candidate_at o
##   menos (make_angry; nunca el natal).
## Escribe en GameState y avisa con EventBus.bosque_state_changed. Números en
## data/combat/balance.json (bloque bosque_states).

const SANO: String = BosqueMap.STATE_SANO
const ENOJADO: String = BosqueMap.STATE_ENOJADO
const CORRUPTO: String = BosqueMap.STATE_CORRUPTO
const MUERTO: String = BosqueMap.STATE_MUERTO
const NECESITA_AYUDA: String = BosqueMap.STATE_NECESITA_AYUDA
const SALT_AMBUSH: int = 61
const SALT_INDEPENDENT: int = 67
const SALT_INDEPENDENT_LUZ: int = 71


static func config() -> Dictionary:
	return AdventureRules.balance().get("bosque_states", {})


## Bloque de balance de un estado ({} si no tiene).
static func state_config(state: String) -> Dictionary:
	return config().get(state, {})


## Estado del Bosque ahora: el cambiado en la partida o, si no, el de generación. `map`: el reparto
## de la partida (si es null, el de MapLogic.current_bosques). "" fuera de la región.
static func state_of(bosque_id: int, map: BosqueMap = null) -> String:
	if bosque_id < 0:
		return ""
	var key: String = str(bosque_id)
	if GameState.bosque_state_overrides.has(key):
		return str(GameState.bosque_state_overrides[key])
	if map == null:
		map = MapLogic.current_bosques()
	return map.state_of(bosque_id)


## Cambia el estado del Bosque en la partida (se guarda) y avisa. Volver al de generación borra el
## cambio. false si no cambia nada.
static func set_state(bosque_id: int, state: String, map: BosqueMap = null) -> bool:
	if bosque_id < 0 or not BosqueMap.STATES.has(state) or state_of(bosque_id, map) == state:
		return false
	if map == null:
		map = MapLogic.current_bosques()
	if map.state_of(bosque_id) == state:
		GameState.bosque_state_overrides.erase(str(bosque_id))
	else:
		GameState.bosque_state_overrides[str(bosque_id)] = state
	EventBus.bosque_state_changed.emit(bosque_id, state)
	return true


## La relación ha caído a angry_candidate_at o menos: un Bosque sano o que necesita ayuda se enoja
## (el corrupto y el muerto siguen como están; el natal nunca). El paso pagado se pierde: un Bosque
## enojado no te quiere dentro. Devuelve si cambió.
static func make_angry(bosque_id: int, map: BosqueMap = null) -> bool:
	if map == null:
		map = MapLogic.current_bosques()
	if bosque_id < 0 or bosque_id == map.home_bosque:
		return false
	var state: String = state_of(bosque_id, map)
	if state != SANO and state != NECESITA_AYUDA:
		return false
	GameState.open_until.erase(str(bosque_id))
	return set_state(bosque_id, ENOJADO, map)


## Multiplicador del peaje por el estado (sano 1, corrupto 1,5; 0 = no cobra).
static func toll_factor(state: String) -> float:
	return float(state_config(state).get("toll_factor", 1.0))


## El Bosque no cobra peaje y su borde está abierto (muerto, necesita_ayuda).
static func is_free(state: String) -> bool:
	return toll_factor(state) <= 0.0


## Se le puede pagar el paso (Luz u ofrendas). El enojado no acepta pagos; el que no cobra, tampoco
## los necesita.
static func can_pay(state: String) -> bool:
	return bool(state_config(state).get("can_pay", true)) and not is_free(state)


## Únicos que rondan un Bosque con ese estado, a partir del número base (BosquePatrols): el
## muerto tiene patrol_count fijo; el enojado, base × patrol_factor.
static func patrol_count(state: String, base: int) -> int:
	var cfg: Dictionary = state_config(state)
	if cfg.has("patrol_count"):
		return int(cfg.patrol_count)
	return base * int(cfg.get("patrol_factor", 1))


## Segundos entre cazadores con ese estado a partir de los de la hostilidad (enojado: × factor).
static func hunt_interval(state: String, base: float) -> float:
	return base * float(state_config(state).get("hunt_interval_factor", 1.0))


## Segundos hasta el primer cazador al entrar (enojado: casi enseguida). -1 = el intervalo normal.
static func hunt_first_seconds(state: String) -> float:
	return float(state_config(state).get("hunt_first_seconds", -1.0))


## Cazadores extra a la vez (enojado).
static func max_hunters_bonus(state: String) -> int:
	return int(state_config(state).get("max_hunters_bonus", 0))


## Casillas extra de visión de sus Botarramas (enojado).
static func vision_bonus(state: String) -> int:
	return int(state_config(state).get("vision_bonus", 0))


## Casillas que se restan a la visión de los Únicos por el camuflaje del Adoc (Stealth.camouflage:
## máscara y talismán, sin arma y sin que le hayan visto). 0 sin camuflaje.
static func stealth_vision_bonus() -> int:
	return Stealth.camouflage()


## Multiplicador del tiempo hasta cada cazador en un Bosque con ese estado por el sigilo del Adoc:
## "tener algo que aumente tu velocidad o te camufle muy muy bien" (enojado). Con camuflaje alto
## (Stealth.hides_well) o con velocidad extra, stealth_hunt_factor; si no, 1.
static func stealth_hunt_factor(state: String) -> float:
	var factor: float = float(state_config(state).get("stealth_hunt_factor", 1.0))
	if factor != 1.0 and (Stealth.hides_well() or Stealth.speed_bonus() > 0.0):
		return factor
	return 1.0


## Un Único del Bosque corrupto ataca este Momento aunque hayas pagado ("atacan a veces"):
## ambush_chance por Único (`key`) y por Momento (riutash), determinista.
static func ambushes(seed_value: int, key: String, riutash: int, state: String) -> bool:
	var chance: float = float(state_config(state).get("ambush_chance", 0.0))
	return chance > 0.0 and ChunkGenerator.hash_ints([seed_value, key.hash(), riutash, SALT_AMBUSH]) % 1000 < roundi(chance * 1000.0)


## El Único (`key`) de un Bosque muerto va por su cuenta este Momento: te pide Luz al cruzarte.
static func is_independent(seed_value: int, key: String, riutash: int, state: String) -> bool:
	var chance: float = float(state_config(state).get("independent_chance", 0.0))
	return chance > 0.0 and ChunkGenerator.hash_ints([seed_value, key.hash(), riutash, SALT_INDEPENDENT]) % 1000 < roundi(chance * 1000.0)


## Luz que pide un Único independiente (independent_luz: [mín, máx], por Único y Momento).
static func independent_luz(seed_value: int, key: String, riutash: int) -> int:
	var range_n: Array = state_config(MUERTO).get("independent_luz", [1, 2])
	var lo: int = int(range_n[0])
	var hi: int = maxi(lo, int(range_n[1]))
	return lo + ChunkGenerator.hash_ints([seed_value, key.hash(), riutash, SALT_INDEPENDENT_LUZ]) % (hi - lo + 1)


## Paga al Único independiente: quita la Luz. false si no alcanza.
static func pay_independent(luz: int) -> bool:
	if GameState.luz < luz:
		return false
	AdventureRules.set_luz(GameState.luz - luz)
	return true


## El Bosque está al borde de soltar a su Iserald (corrupto). Hoy solo se avisa.
static func has_iserald_risk(state: String) -> bool:
	return bool(state_config(state).get("iserald_risk", false))


## Sus Únicos son amistosos: no persiguen ni cazan (necesita_ayuda).
static func has_friendly_unicos(state: String) -> bool:
	return bool(state_config(state).get("friendly_unicos", false))


## Gancho del combate en grupo (PR 7): Únicos del Bosque que pelean a tu lado ("algunos Únicos
## pelean junto a ti"). Todavía no se usa: el combate es uno contra uno.
static func allies_in_battle(state: String) -> int:
	return int(state_config(state).get("allies_in_battle", 0))


## Nombre visible del estado ("sano", "enojado"...).
static func display_name(state: String) -> String:
	return Texts.get_text("bosque_state_" + state) if state != "" else ""


## Aviso al entrar en un Bosque con ese estado ("" si no hay: sano). El corrupto avisa del Iserald.
static func entry_notice(state: String) -> String:
	if state == "" or state == SANO:
		return ""
	return Texts.get_text("bosque_state_enter_" + state)
