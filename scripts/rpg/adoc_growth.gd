class_name AdocGrowth
extends RefCounted
## Crecimiento del Adoc (moralidad-y-progresion.md, 0.5; sustituye a la tabla de progresion-adoc.md):
## - Stats automáticos por nivel: los del nivel 1 y, desde el 2, +auto_hp PV máx. y +1 ATQ en los
##   niveles impares o +1 DEF en los pares (auto_stats). Sirven también para los adoc NPC. La
##   Agilidad (agility) también sube sola: agi_base + ⌊nivel / agi_every⌋.
## - Puntos de stat: points_per_level por nivel, a mano. Cada compra cuesta lo que diga
##   balance.json (stat_points): ATQ y DEF 3 puntos por +1; Vigor 1 por +2 PV; Luz 1 por +1 al
##   límite de Luz suelta. GameState guarda los no gastados (stat_points) y los gastados por stat
##   (spent_points), y los stats del jugador salen de nivel + gastados (player_stats).
## - Skills: 1 punto en los niveles de skill_levels. Dos ramas en cadena (Sombra y Confianza); cada
##   skill exige la anterior de su rama y la Senda en su umbral. Lo aprendido se conserva aunque la
##   Senda cambie (GameState.skills).
## - Migración de partidas con la tabla antigua (v17 o anterior): mismo nivel, nada gastado y todos
##   los puntos del nivel por repartir (migrate_points).
## Escribe en GameState y avisa por EventBus (stat_points_spent, skill_learned). Números en
## data/combat/balance.json; nombres y descripciones en data/text/sistema.json.

const STAT_ATK: StringName = &"atk"
const STAT_DEF: StringName = &"def"
const STAT_VIGOR: StringName = &"vigor"
const STAT_LUZ: StringName = &"luz"

const SOMBRA: StringName = &"sombra"
const CONFIANZA: StringName = &"confianza"
const BRANCHES: Array[StringName] = [SOMBRA, CONFIANZA]

## Skills (ids de balance.json, bloque skills).
const PASO_QUEDO: StringName = &"paso_quedo"
const GOLPE_FUERTE: StringName = &"golpe_fuerte"
const BOTIN: StringName = &"botin"
const IMPONERSE: StringName = &"imponerse"
const PALABRA_SUAVE: StringName = &"palabra_suave"
const ROSTRO_CONOCIDO: StringName = &"rostro_conocido"
const DESCANSO_NUJIO: StringName = &"descanso_nujio"
const LLAMADA_BOSQUE: StringName = &"llamada_bosque"

## Estado de una skill en el árbol.
enum SkillState { LEARNED, AVAILABLE, NEEDS_POINT, NEEDS_SENDA, NEEDS_PREVIOUS }


static func levels() -> Dictionary:
	return AdventureRules.balance().levels


static func points_config() -> Dictionary:
	return AdventureRules.balance().stat_points


static func skills_config() -> Dictionary:
	return AdventureRules.balance().skills


# --- Stats ----------------------------------------------------------------------------------------

## Nivel tope.
static func max_level() -> int:
	return (levels().xp as Array).size()


## Stats automáticos de un nivel (sin puntos): { max_hp, atk, def }.
static func auto_stats(level: int) -> Dictionary:
	var l: Dictionary = levels()
	var lv: int = clampi(level, 1, max_level())
	var base: Dictionary = l.base
	var odd: int = 0
	var even: int = 0
	for n: int in range(2, lv + 1):
		if n % 2 == 1:
			odd += 1
		else:
			even += 1
	return {
		"max_hp": int(base.max_hp) + int(l.auto_hp) * (lv - 1),
		"atk": int(base.atk) + int(l.auto_atk_odd) * odd,
		"def": int(base.def) + int(l.auto_def_even) * even,
	}


## Agilidad de un adoc en un nivel (ia-de-combate.md): agi_base + ⌊nivel / agi_every⌋. Solo
## automática, sin puntos (#174). La usan el jugador y los adoc aliados.
static func agility(level: int) -> int:
	var l: Dictionary = levels()
	return int(l.get("agi_base", 5)) + clampi(level, 1, max_level()) / maxi(1, int(l.get("agi_every", 2)))


static func points_per_level() -> int:
	return int(levels().points_per_level)


## Puntos de stat que da llegar a `level` desde el nivel 1.
static func points_for_level(level: int) -> int:
	return points_per_level() * (clampi(level, 1, max_level()) - 1)


## Puntos de skill que da llegar a `level` (uno por cada nivel de skill_levels alcanzado).
static func skill_points_for_level(level: int) -> int:
	var n: int = 0
	for l: Variant in levels().get("skill_levels", []):
		if int(l) <= level:
			n += 1
	return n


## Stats en el orden del reparto (atk, def, vigor, luz).
static func stat_order() -> Array[StringName]:
	var out: Array[StringName] = []
	for s: Variant in points_config().get("order", ["atk", "def", "vigor", "luz"]):
		out.append(StringName(str(s)))
	return out


static func cost(stat: StringName) -> int:
	return int((points_config().get(String(stat), {}) as Dictionary).get("cost", 1))


static func gain(stat: StringName) -> int:
	return int((points_config().get(String(stat), {}) as Dictionary).get("gain", 0))


static func spent(stat: StringName, spent_points: Dictionary = GameState.spent_points) -> int:
	return int(spent_points.get(String(stat), 0))


## Lo que suma un stat con `points` gastados (solo cuentan las compras enteras).
static func bonus_of(stat: StringName, points: int) -> int:
	return (maxi(0, points) / maxi(1, cost(stat))) * gain(stat)


## Bonos de los puntos gastados: { max_hp, atk, def, luz_max }.
static func bonuses(spent_points: Dictionary = GameState.spent_points) -> Dictionary:
	return {
		"max_hp": bonus_of(STAT_VIGOR, spent(STAT_VIGOR, spent_points)),
		"atk": bonus_of(STAT_ATK, spent(STAT_ATK, spent_points)),
		"def": bonus_of(STAT_DEF, spent(STAT_DEF, spent_points)),
		"luz_max": bonus_of(STAT_LUZ, spent(STAT_LUZ, spent_points)),
	}


## Stats del jugador: los automáticos de su nivel más los puntos gastados.
static func player_stats(level: int = GameState.level, spent_points: Dictionary = GameState.spent_points) -> Dictionary:
	var s: Dictionary = auto_stats(level)
	var b: Dictionary = bonuses(spent_points)
	return { "max_hp": int(s.max_hp) + int(b.max_hp), "atk": int(s.atk) + int(b.atk), "def": int(s.def) + int(b.def) }


## Se puede comprar una vez el stat con `available` puntos.
static func can_buy(stat: StringName, available: int = GameState.stat_points) -> bool:
	return stat_order().has(stat) and available >= cost(stat)


## Puntos que costaría un reparto { stat: compras }.
static func draft_cost(draft: Dictionary) -> int:
	var total: int = 0
	for stat: Variant in draft:
		total += cost(StringName(str(stat))) * maxi(0, int(draft[stat]))
	return total


## Gastados por stat tras aplicar un reparto { stat: compras } (pura, para la vista previa).
static func spent_with(draft: Dictionary, spent_points: Dictionary = GameState.spent_points) -> Dictionary:
	var out: Dictionary = spent_points.duplicate()
	for stat: Variant in draft:
		var key: String = str(stat)
		out[key] = int(out.get(key, 0)) + cost(StringName(key)) * maxi(0, int(draft[stat]))
	return out


## Compra el stat una vez con los puntos sin gastar: Vigor sube también los PV actuales; Luz, el
## límite de Luz suelta. false si no llegan los puntos.
static func buy(stat: StringName) -> bool:
	if not can_buy(stat):
		return false
	var before_hp: int = AdventureRules.max_hp()
	GameState.stat_points -= cost(stat)
	GameState.spent_points[String(stat)] = spent(stat) + cost(stat)
	if stat == STAT_VIGOR:
		AdventureRules.set_hp(GameState.hp + AdventureRules.max_hp() - before_hp)
	elif stat == STAT_LUZ:
		AdventureRules.set_luz(GameState.luz)
	EventBus.stat_points_spent.emit(stat, cost(stat))
	return true


## Aplica un reparto entero { stat: compras } (pantalla Crecer, al confirmar). false (y nada
## cambia) si no llegan los puntos.
static func apply_draft(draft: Dictionary) -> bool:
	if draft_cost(draft) > GameState.stat_points:
		return false
	for stat: StringName in stat_order():
		for i: int in maxi(0, int(draft.get(stat, draft.get(String(stat), 0)))):
			buy(stat)
	return true


## Sube al nivel `level`: puntos de stat y, si toca, uno de skill.
static func level_reached(level: int) -> void:
	GameState.stat_points += points_per_level()
	if is_skill_level(level):
		GameState.skill_points += 1


static func is_skill_level(level: int) -> bool:
	for l: Variant in levels().get("skill_levels", []):
		if int(l) == level:
			return true
	return false


## Partida con la tabla antigua (v17 o anterior): nada gastado, todos los puntos del nivel por
## repartir y los de skill del nivel.
static func migrate_points(level: int) -> void:
	GameState.spent_points = {}
	GameState.stat_points = points_for_level(level)
	GameState.skill_points = skill_points_for_level(level)
	GameState.skills = []


# --- Skills ---------------------------------------------------------------------------------------

## Skills de una rama, en orden.
static func branch(branch_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: Variant in (skills_config().branches as Dictionary).get(String(branch_id), []):
		out.append(StringName(str(id)))
	return out


static func branch_of(skill: StringName) -> StringName:
	for b: StringName in BRANCHES:
		if branch(b).has(skill):
			return b
	return &""


static func skill_config(skill: StringName) -> Dictionary:
	return skills_config().get(String(skill), {})


static func has_skill(skill: StringName) -> bool:
	return GameState.skills.has(String(skill))


## La anterior de su rama (&"" si es la primera).
static func previous(skill: StringName) -> StringName:
	var list: Array[StringName] = branch(branch_of(skill))
	var i: int = list.find(skill)
	return list[i - 1] if i > 0 else &""


## La Senda `value` llega al umbral de la skill (≤ senda_max en Sombra, ≥ senda_min en Confianza).
static func senda_allows(skill: StringName, value: int = GameState.senda) -> bool:
	var cfg: Dictionary = skill_config(skill)
	if cfg.has("senda_max"):
		return value <= int(cfg.senda_max)
	if cfg.has("senda_min"):
		return value >= int(cfg.senda_min)
	return true


## Umbral de Senda de la skill (con signo).
static func threshold(skill: StringName) -> int:
	var cfg: Dictionary = skill_config(skill)
	return int(cfg.get("senda_max", cfg.get("senda_min", 0)))


## Estado de la skill en el árbol: aprendida, disponible o qué le falta (por orden: la anterior de
## la rama, la Senda, un punto).
static func skill_state(skill: StringName) -> SkillState:
	if has_skill(skill):
		return SkillState.LEARNED
	var prev: StringName = previous(skill)
	if prev != &"" and not has_skill(prev):
		return SkillState.NEEDS_PREVIOUS
	if not senda_allows(skill):
		return SkillState.NEEDS_SENDA
	if GameState.skill_points <= 0:
		return SkillState.NEEDS_POINT
	return SkillState.AVAILABLE


static func can_learn(skill: StringName) -> bool:
	return branch_of(skill) != &"" and skill_state(skill) == SkillState.AVAILABLE


## Aprende la skill con un punto. false si no se puede.
static func learn(skill: StringName) -> bool:
	if not can_learn(skill):
		return false
	GameState.skill_points -= 1
	GameState.skills.append(String(skill))
	EventBus.skill_learned.emit(skill)
	return true


static func skill_name(skill: StringName) -> String:
	return Texts.get_text("skill_%s_name" % skill)


static func skill_description(skill: StringName) -> String:
	return Texts.get_text("skill_%s_desc" % skill)


# --- Efectos (los leen AdventureRules, BattleLogic y Crossing) -------------------------------------

## S1 Paso quedo: casillas que se restan a la visión de los Únicos.
static func vision_reduction() -> int:
	return int(skill_config(PASO_QUEDO).get("vision", 0)) if has_skill(PASO_QUEDO) else 0


## C1 Palabra suave: Luz que se resta del peaje.
static func toll_discount() -> int:
	return int(skill_config(PALABRA_SUAVE).get("toll", 0)) if has_skill(PALABRA_SUAVE) else 0


## C3 Descanso del Nujio: % de los PV que faltan que cura el riutash en refugio dentro de un Bosque
## pagado (-1 = sin la skill).
static func nujio_rest_heal_pct() -> int:
	return int(skill_config(DESCANSO_NUJIO).get("heal_pct", -1)) if has_skill(DESCANSO_NUJIO) else -1
