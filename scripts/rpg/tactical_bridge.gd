class_name TacticalBridge
extends RefCounted
## Puente entre el combate de siempre (BattleLogic, que preparan AdventureRules y Crossing) y el
## combate táctico (TacticalBattle; combate-tactico.md, PR T4). Lógica pura:
## - is_enabled: el interruptor tactical.enabled de balance.json (false por defecto): con él,
##   Crossing abre la escena táctica en vez de la de menú, con las mismas entradas y salidas.
## - build_battle: un TacticalBattle con el Adoc (leader), sus aliados y los enemigos del
##   BattleLogic, sus PV, stats, AGI y roles, y el pago (peaje, Luz, ofrendas). Hasta
##   board.max_per_side (el cupo) por bando en el tablero; los demás esperan en su borde y entran
##   como refuerzo (T1b). Con `chosen` (TacticalParty), los aliados elegidos entran primero y los
##   demás esperan. El tablero, llano hasta el Mundo 2.0.
## - arena_config: el bloque tactical con el tamaño y el cupo de TacticalArena para un recorte
##   (proporción transitable) o un bioma.
## - apply_to_logic: devuelve al BattleLogic el resultado, los PV, la Luz, la ofrenda entregada y
##   quién huyó por el borde (gone; el reparep que huye no da su XP),
##   para que AdventureRules aplique victoria, pago, huida, derrota, XP y Bosque recuerda como
##   siempre.
## - end_lines: las líneas del final (resultado, XP, niveles nuevos, botín).
## - Especiales (T6): los enemigos llevan su especial (special_every, special_factor, special_area:
##   el Latigazo múltiple en área anunciada) y, en un grupo de ataque conjunto (logic.joint_attack,
##   los reparep), `joint`. build_battle aplica la apertura (TacticalBattle.Opening).
## - Arma y objetos (P4): el Adoc lleva su arma (Items.weapon_profile: ATQ, alcance, línea, bono por
##   la espalda y precisión). Si empieza enfundada (emboscada del enemigo, logic.weapon_sheathed),
##   pelea con alcance 1 y ATQ base hasta que la desenfunda. Sin arma, alcance 1 y ATQ base. Los
##   objetos de combate de la bolsa (logic.combat_items, hoy el fruto) pasan con su curación
##   (fruit.heal_pct) y su alcance (use_range); apply_to_logic devuelve los usados (used_items).
## - Apertura (T6): opening_for_engaged y opening_for_confront deciden, desde la exploración, si el
##   combate empieza con sorpresa (el Adoc aborda con E a un Único que no le persigue: no le ha
##   detectado, por Paso quedo, máscara o porque no mira) o con emboscada del enemigo (le alcanza un
##   cazador, que aparece fuera de la vista, o un Único fatal en ese Momento, Aledra de noche). Lo que
##   la ficha pide y aún no existe (un ataque al dormir) queda como gancho: opening_for_sleep.

## Id del Adoc en el TacticalBattle; los aliados y enemigos llevan ally_N / enemy_N.
const ADOC_ID: StringName = &"adoc"


static func is_enabled(balance_data: Dictionary) -> bool:
	return bool((balance_data.get("tactical", {}) as Dictionary).get("enabled", false))


## Combatientes del BattleLogic en el formato de TacticalBattle. BattleLogic ya sumó el bono de rol
## a ATQ y DEF; aquí se resta porque TacticalBattle lo vuelve a sumar.
## `chosen`: índices de los aliados elegidos (TacticalParty); null = todos en su orden, sin elección.
static func fighters_from_logic(logic: BattleLogic, chosen: Variant = null) -> Array:
	var roles: Dictionary = (logic.balance.get("tactics", {}) as Dictionary).get("roles", {})
	var adoc: Dictionary = {
		"id": ADOC_ID, "side": TacticalBattle.SIDE_PLAYER, "agi": logic.adoc_agi,
		"hp": logic.adoc_hp, "max_hp": logic.adoc_max_hp, "atk": logic.adoc_atk, "def": logic.adoc_def,
		"leader": true, "strong_every": logic.strong_every, "strong_factor": logic.strong_factor,
	}
	var weapon: Dictionary = adoc_weapon(logic)
	if not weapon.is_empty():
		adoc.weapon = weapon
		adoc.sheathed = logic.weapon_sheathed
		# BattleLogic ya sumó el ATQ del arma desenfundada; TacticalBattle lo vuelve a sumar.
		if not logic.weapon_sheathed:
			adoc.atk = logic.adoc_atk - int(weapon.atk_bonus)
	var out: Array = [adoc]
	var order: Array = range(logic.allies.size())
	if chosen is Array:
		var picked: Array[int] = []
		for i: Variant in chosen:
			picked.append(int(i))
		order = TacticalParty.battle_order(logic.allies.size(), picked)
	for i: int in order:
		var a: Dictionary = logic.allies[i]
		if a.get("retired", false):
			continue
		var f: Dictionary = _fighter(a, StringName("ally_%d" % i), TacticalBattle.SIDE_PLAYER, roles, true)
		if chosen is Array and not (chosen as Array).has(i):
			f.reserve = true
		out.append(f)
	for i: int in logic.enemies.size():
		var e: Dictionary = logic.enemies[i]
		if e.get("gone", false) or int(e.hp) <= 0:
			continue
		var f: Dictionary = _fighter(e, StringName("enemy_%d" % i), TacticalBattle.SIDE_ENEMY, roles, logic.accepts_payment)
		f.special_every = int(e.get("special_every", 0))
		f.special_factor = float(e.get("special_factor", 1.0))
		f.special_area = bool(e.get("special_area", false))
		f.attack_range = e.get("attack_range", [1, 1])
		f.joint = logic.joint_attack
		out.append(f)
	return out


## Perfil del arma del Adoc para el táctico ({} sin arma o si no lo es).
static func adoc_weapon(logic: BattleLogic) -> Dictionary:
	if logic.weapon_id == &"":
		return {}
	return Items.weapon_profile(logic.weapon_id)


## Objetos de combate del BattleLogic en el formato de TacticalBattle.set_items: [{ slot, id,
## heal_pct, use_range }]. El fruto cura fruit.heal_pct de balance.json.
static func items_from_logic(logic: BattleLogic) -> Array:
	var heal: int = int((logic.balance.get("fruit", {}) as Dictionary).get("heal_pct", 25))
	var out: Array = []
	for it: Dictionary in logic.combat_items:
		var id: StringName = StringName(str(it.get("id", "")))
		out.append({ "slot": int(it.get("slot", -1)), "id": id, "use_range": Items.use_range(id),
			"heal_pct": heal if id == Items.FRUIT_ID else 0 })
	return out


static func _fighter(c: Dictionary, id: StringName, side: int, roles: Dictionary, accepts: bool) -> Dictionary:
	var role: StringName = StringName(str(c.get("role", "")))
	var bonus: Dictionary = roles.get(String(role), {}) if role != &"" else {}
	return {
		"id": id, "side": side, "agi": int(c.get("agi", 0)), "hp": int(c.hp), "max_hp": int(c.max_hp),
		"atk": int(c.atk) - int(bonus.get("atk_bonus", 0)), "def": int(c.def) - int(bonus.get("def_bonus", 0)),
		"role": role, "accepts_payment": accepts, "ai": StringName(str(c.get("ai", ""))),
	}


## TacticalBattle de un BattleLogic. `cfg`: bloque tactical (por defecto, el de logic.balance con lo
## compartido, TacticalBattle.config_from_balance); `board`: por defecto, llano del tamaño de cfg.
static func build_battle(logic: BattleLogic, cfg: Dictionary = {}, board: TacticalBoard = null,
		chosen: Variant = null, opening: TacticalBattle.Opening = TacticalBattle.Opening.NORMAL) -> TacticalBattle:
	if cfg.is_empty():
		cfg = TacticalBattle.config_from_balance(logic.balance)
	if board == null:
		board = TacticalBoard.from_config(cfg.get("board", {}))
	var battle := TacticalBattle.new(cfg, board, fighters_from_logic(logic, chosen), int(logic.rng.seed))
	battle.set_payment(logic.toll, logic.luz, logic.ofrendas)
	battle.set_items(items_from_logic(logic))
	battle.apply_opening(opening)
	return battle


## Apertura cuando un Único alcanza al Adoc (MonsterField.engaged): emboscada si es un cazador
## (aparece fuera de la vista) o si perder con él ahora sería fatal (`fatal_now`: Aledra de noche);
## si no, normal (le vio venir).
static func opening_for_engaged(role: StringName, fatal_now: bool) -> TacticalBattle.Opening:
	if role == MonsterField.ROLE_HUNTER or fatal_now:
		return TacticalBattle.Opening.AMBUSH
	return TacticalBattle.Opening.NORMAL


## Apertura cuando el Adoc se enfrenta con E a un Único: sorpresa si el Único no le persigue (no le
## ha detectado); normal si ya le perseguía.
static func opening_for_confront(chasing: bool) -> TacticalBattle.Opening:
	return TacticalBattle.Opening.NORMAL if chasing else TacticalBattle.Opening.SURPRISE


## Gancho (combate-tactico.md: "un ataque al dormir"): aún no hay ataques mientras el Adoc duerme.
## Cuando los haya, su combate empezará con esta apertura.
static func opening_for_sleep() -> TacticalBattle.Opening:
	return TacticalBattle.Opening.AMBUSH


## Bloque tactical (con lo compartido) con el tablero y el cupo de TacticalArena: `ratio`, la
## proporción transitable del recorte (< 0 si no hay recorte: la del bioma); `biome`, desempate.
static func arena_config(balance_data: Dictionary, ratio: float, biome: StringName = &"") -> Dictionary:
	var cfg: Dictionary = TacticalBattle.config_from_balance(balance_data)
	return TacticalArena.apply_plan(cfg, TacticalArena.plan(cfg, ratio, biome))


## Índice en el BattleLogic de un combatiente táctico (-1 = el Adoc), por su id.
static func logic_index(id: StringName) -> int:
	var s: String = String(id)
	if s.begins_with("ally_") or s.begins_with("enemy_"):
		return int(s.get_slice("_", 1))
	return BattleLogic.TARGET_ADOC


## Devuelve el desenlace al BattleLogic (mismo orden de Result en las dos clases).
static func apply_to_logic(battle: TacticalBattle, logic: BattleLogic) -> void:
	logic.result = int(battle.result) as BattleLogic.Result
	logic.luz = battle.luz
	logic.ofrenda_index = battle.ofrenda_index
	logic.used_items = battle.used_items.duplicate()
	for u: Dictionary in battle.units:
		# Quien esperaba en el borde (refuerzo que no llegó a entrar) conserva sus PV.
		var hp: int = int(u.hp) if (u.alive or u.get("waiting", false)) else 0
		var s: String = String(u.id)
		if u.id == ADOC_ID:
			logic.adoc_hp = hp
		elif s.begins_with("ally_"):
			var a: Dictionary = logic.allies[logic_index(u.id)]
			a.hp = hp
			a.retired = hp <= 0
		elif s.begins_with("enemy_"):
			var e: Dictionary = logic.enemies[logic_index(u.id)]
			if u.fled:
				# Huyó o se retiró por el borde: sigue con sus PV y no está en pie (BattleLogic.gone).
				e.hp = int(u.hp)
				e.gone = true
				if u.ai == BattleLogic.AI_SWARM:
					# El reparep que huye no da su XP (como en el combate por menú).
					logic.victory_xp = maxi(0, logic.victory_xp - logic.enemy_xp)
					logic.level_ups = logic.level_ups_fled.duplicate()
			else:
				e.hp = hp


## Líneas del final: el resultado y, tras una victoria, la XP, cada nivel nuevo, el aviso de puntos
## y el botín (como el combate por menú).
static func end_lines(logic: BattleLogic) -> Array[String]:
	var out: Array[String] = []
	match logic.result:
		BattleLogic.Result.VICTORY:
			out.append(Texts.get_text("tactical_victory"))
			if logic.victory_xp > 0:
				out.append(Texts.get_text("xp_gained") % logic.victory_xp)
			for level: int in logic.level_ups:
				out.append(Texts.get_text("level_up") % level)
			if not logic.level_ups.is_empty():
				out.append(Texts.get_text("growth_points_hint"))
			if logic.loot_id != &"":
				out.append(Texts.get_text("battle_loot") % Ofrendas.display_name(logic.loot_id))
		BattleLogic.Result.DEFEAT:
			out.append(Texts.get_text("defeat_fatal_game_over") % logic.unico_name if logic.fatal
				else Texts.get_text("tactical_defeat"))
		BattleLogic.Result.FLED:
			out.append(Texts.get_text("tactical_fled"))
		BattleLogic.Result.APPEASED:
			out.append(Texts.get_text("tactical_appeased"))
	return out
