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

## Id del Adoc en el TacticalBattle; los aliados y enemigos llevan ally_N / enemy_N.
const ADOC_ID: StringName = &"adoc"


static func is_enabled(balance_data: Dictionary) -> bool:
	return bool((balance_data.get("tactical", {}) as Dictionary).get("enabled", false))


## Combatientes del BattleLogic en el formato de TacticalBattle. BattleLogic ya sumó el bono de rol
## a ATQ y DEF; aquí se resta porque TacticalBattle lo vuelve a sumar.
## `chosen`: índices de los aliados elegidos (TacticalParty); null = todos en su orden, sin elección.
static func fighters_from_logic(logic: BattleLogic, chosen: Variant = null) -> Array:
	var roles: Dictionary = (logic.balance.get("tactics", {}) as Dictionary).get("roles", {})
	var out: Array = [{
		"id": ADOC_ID, "side": TacticalBattle.SIDE_PLAYER, "agi": logic.adoc_agi,
		"hp": logic.adoc_hp, "max_hp": logic.adoc_max_hp, "atk": logic.adoc_atk, "def": logic.adoc_def,
		"leader": true, "strong_every": logic.strong_every, "strong_factor": logic.strong_factor,
	}]
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
		out.append(f)
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
		chosen: Variant = null) -> TacticalBattle:
	if cfg.is_empty():
		cfg = TacticalBattle.config_from_balance(logic.balance)
	if board == null:
		board = TacticalBoard.from_config(cfg.get("board", {}))
	var battle := TacticalBattle.new(cfg, board, fighters_from_logic(logic, chosen), int(logic.rng.seed))
	battle.set_payment(logic.toll, logic.luz, logic.ofrendas)
	return battle


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
