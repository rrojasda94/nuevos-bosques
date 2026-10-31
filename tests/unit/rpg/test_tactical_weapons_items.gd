extends GutTest
## P4 (ajustes-playtest-0.5.md, puntos 4 y 5; ADR 0017): armas con efecto en el combate táctico
## (lanza a 1–2 en línea, cuchillo con +2 por la espalda, honda a 2–3 y no a 1), ATQ con el arma en la
## ficha, casillas de alcance, Desenfundar en una emboscada, acción Objeto (fruto: 25%, adyacencia,
## gasta la acción y se consume), el puente con alcance y efectos, equipo inicial de una partida nueva
## (sin tocar las guardadas), de dónde salen el Cuchillo y la Honda, y humo IA contra IA con armas.
## Bloque tactical fijo de test sin evasión (los golpes aciertan) y tirada de daño 0.

const SAVE_SLOT: int = 94
const TACTICAL: Dictionary = {
	"board": { "width": 8, "height": 6, "deploy_columns": 2, "max_per_side": 3, "ford_cost": 1 },
	"movement": { "mov_base": 3, "mov_agi_ref": 5, "mov_agi_div": 2, "mov_min": 2, "mov_max": 6,
		"jump_base": 1, "jump_agi_div": 7, "drop_extra": 1 },
	"ct": { "threshold": 100, "start_per_agi": 10, "cost_move_and_act": 100, "cost_single": 80, "cost_wait": 60 },
	"actions": { "evasion_base": 0, "evasion_per_agi": 0, "flank_factor": 0.5, "back_factor": 0.0,
		"height_evasion": 0, "hit_min": 5, "hit_max": 100, "flank_bonus": 1, "back_bonus": 2,
		"height_bonus": 1, "support_range": 2 },
	"attack": { "roll_min": 0, "roll_max": 0, "min_damage": 1 },
	"defend_factor": 0.5,
	"finish_below": 0.3,
	"ai": { "help_below": 0.3, "finish_below": 0.3, "retreat_below": 0.2, "swarm_flee_below": 0.3,
		"tactical_retreat_below": 0.25 },
	"roles": {},
}
const P := TacticalBattle.SIDE_PLAYER
const E := TacticalBattle.SIDE_ENEMY
const EAST := TacticalBoard.Facing.EAST
const WEST := TacticalBoard.Facing.WEST
const LANZA: StringName = &"lanza_de_adoc"
const CUCHILLO: StringName = &"cuchillo"
const HONDA: StringName = &"honda"
const TARGET: int = 1


func before_each() -> void:
	WorldClock.set_process(false)
	GameState.new_game(42)
	GameState.bosque_state_overrides[str(TARGET)] = BosqueStates.SANO


func after_each() -> void:
	WorldClock.set_process(true)


func after_all() -> void:
	DirAccess.remove_absolute(SaveManager.slot_path(SAVE_SLOT))
	GameState.new_game(42)


func _unit(id: StringName, side: int, cell: Vector2i, extra: Dictionary = {}) -> Dictionary:
	var u: Dictionary = { "id": id, "side": side, "agi": 5, "cell": cell, "max_hp": 30, "atk": 8, "def": 3,
		"facing": EAST if side == P else WEST }
	u.merge(extra, true)
	return u


func _adoc(cell: Vector2i, weapon: StringName, sheathed: bool = false, extra: Dictionary = {}) -> Dictionary:
	var u: Dictionary = _unit(&"adoc", P, cell, { "leader": true, "atk": 6 })
	if weapon != &"":
		u.weapon = Items.weapon_profile(weapon)
		u.sheathed = sheathed
	u.merge(extra, true)
	return u


func _battle(fighters: Array, rng_seed: int = 1) -> TacticalBattle:
	return TacticalBattle.new(TACTICAL, TacticalBoard.from_config(TACTICAL.board), fighters, rng_seed)


func _turn(b: TacticalBattle, index: int) -> void:
	for i in b.units.size():
		b.set_ct(i, 0)
	b.set_ct(index, 100)
	assert_eq(b.begin_turn(), index)


# --- Datos ------------------------------------------------------------------------------------------

func test_weapons_in_data() -> void:
	assert_eq(Items.atk_bonus(LANZA), 2)
	assert_eq(Items.weapon_range(LANZA), [1, 2] as Array[int])
	assert_true(Items.weapon_line(LANZA))
	assert_eq(Items.atk_bonus(CUCHILLO), 1)
	assert_eq(Items.back_bonus(CUCHILLO), 2)
	assert_eq(Items.sheathed_camo_penalty(CUCHILLO), 0, "el cuchillo no estorba al sigilo")
	assert_eq(Items.atk_bonus(HONDA), 1)
	assert_eq(Items.weapon_range(HONDA), [2, 3] as Array[int])
	assert_false(Items.weapon_line(HONDA))
	assert_eq(Items.short_name(LANZA), "Lanza")
	assert_true(Items.weapon_profile(Items.FRUIT_ID).is_empty(), "el fruto no es un arma")
	assert_true(Items.is_combat_usable(Items.FRUIT_ID))
	assert_eq(Items.use_range(Items.FRUIT_ID), 1)
	for id: StringName in [CUCHILLO, HONDA]:
		assert_eq(InventoryLogic.slot_for(id), InventoryLogic.SLOT_MAIN_HAND)
		assert_ne(Items.description(id), "")


# --- Alcance en el tablero ----------------------------------------------------------------------------

func test_spear_hits_at_one_and_two_in_line_only() -> void:
	var b := _battle([_adoc(Vector2i(1, 2), LANZA), _unit(&"e0", E, Vector2i(3, 2)),
		_unit(&"e1", E, Vector2i(2, 3)), _unit(&"e2", E, Vector2i(4, 2))])
	assert_true(b.can_attack(0, 1), "a 2 en línea")
	assert_false(b.can_attack(0, 2), "en diagonal (a 2 de Manhattan) no")
	assert_false(b.can_attack(0, 3), "a 3 no llega")
	b.units[1].cell = Vector2i(2, 2)
	assert_true(b.can_attack(0, 1), "a 1 también")


func test_spear_enemy_in_between_takes_the_hit_and_obstacles_block() -> void:
	var b := _battle([_adoc(Vector2i(1, 2), LANZA), _unit(&"near", E, Vector2i(2, 2)),
		_unit(&"far", E, Vector2i(3, 2))])
	assert_false(b.can_attack(0, 2), "el de detrás queda tapado")
	assert_true(b.can_attack(0, 1), "el golpe es para el de en medio")
	var board := TacticalBoard.from_config(TACTICAL.board)
	board.set_cell(Vector2i(2, 2), 0, true)
	var c := TacticalBattle.new(TACTICAL, board, [_adoc(Vector2i(1, 2), LANZA), _unit(&"far", E, Vector2i(3, 2))], 1)
	assert_false(c.can_attack(0, 1), "una casilla intransitable en medio bloquea")
	# Un aliado en medio no tapa (solo los enemigos reciben el golpe).
	var d := _battle([_adoc(Vector2i(1, 2), LANZA), _unit(&"ally", P, Vector2i(2, 2)),
		_unit(&"far", E, Vector2i(3, 2))])
	assert_true(d.can_attack(0, 2), "por encima de un aliado")


func test_honda_two_to_three_never_one_and_over_things() -> void:
	var b := _battle([_adoc(Vector2i(1, 2), HONDA), _unit(&"adj", E, Vector2i(2, 2)),
		_unit(&"diag", E, Vector2i(2, 3)), _unit(&"far", E, Vector2i(4, 2))])
	assert_false(b.can_attack(0, 1), "no ataca a 1 casilla")
	assert_true(b.can_attack(0, 2), "a 2 en diagonal (sin línea)")
	assert_true(b.can_attack(0, 3), "a 3, por encima del de en medio")
	b.units[3].cell = Vector2i(5, 2)
	assert_false(b.can_attack(0, 3), "a 4 no")


func test_without_weapon_or_sheathed_range_one_and_base_atk() -> void:
	var b := _battle([_adoc(Vector2i(1, 2), LANZA, true), _unit(&"e0", E, Vector2i(3, 2))])
	assert_eq(int(b.units[0].atk), 6, "en la funda: ATQ base")
	assert_eq(int(b.units[0].range_max), 1)
	assert_false(b.can_attack(0, 1))
	var c := _battle([_adoc(Vector2i(1, 2), &""), _unit(&"e0", E, Vector2i(3, 2))])
	assert_eq(int(c.units[0].range_max), 1)
	assert_eq(int(c.units[0].atk), 6)


func test_strike_area_shows_the_cells_the_attack_reaches() -> void:
	var b := _battle([_adoc(Vector2i(1, 2), LANZA), _unit(&"e0", E, Vector2i(2, 2))])
	var area: Array[Vector2i] = b.strike_area(0)
	assert_true(area.has(Vector2i(2, 2)), "el enemigo de al lado")
	assert_false(area.has(Vector2i(3, 2)), "tapado por el enemigo")
	assert_true(area.has(Vector2i(1, 0)), "a 2 hacia arriba")
	assert_true(area.has(Vector2i(1, 4)))
	assert_false(area.has(Vector2i(2, 3)), "diagonal no")
	var h := _battle([_adoc(Vector2i(1, 2), HONDA), _unit(&"e0", E, Vector2i(6, 2))])
	var ring: Array[Vector2i] = h.strike_area(0)
	assert_false(ring.has(Vector2i(2, 2)), "la honda no a 1")
	assert_true(ring.has(Vector2i(2, 3)) and ring.has(Vector2i(4, 2)), "a 2 y a 3")


# --- Daño y precisión ----------------------------------------------------------------------------------

func test_knife_back_bonus() -> void:
	# Enemigo mirando al este; el adoc a su espalda (al oeste). DEF 3, ATQ 6 + 1.
	var fighters: Array = [_adoc(Vector2i(1, 2), CUCHILLO), _unit(&"e0", E, Vector2i(2, 2), { "facing": EAST })]
	var b := _battle(fighters)
	_turn(b, 0)
	var p: Dictionary = b.attack_preview(0, 1)
	assert_eq(int(p.relation), TacticalRules.Relation.BACK)
	assert_eq(int(p.bonus), 2 + 2, "espalda de siempre +2 y cuchillo +2")
	var res: Dictionary = b.attack(1)
	assert_eq(int(res.damage), 7 - 3 + 4)
	# De frente, sin el extra.
	var c := _battle([_adoc(Vector2i(1, 2), CUCHILLO), _unit(&"e0", E, Vector2i(2, 2))])
	_turn(c, 0)
	assert_eq(int(c.attack_preview(0, 1).bonus), 0)
	assert_eq(int(c.attack(1).damage), 7 - 3)


func test_honda_accuracy_penalty_and_spear_damage() -> void:
	var b := _battle([_adoc(Vector2i(1, 2), HONDA), _unit(&"e0", E, Vector2i(3, 2))])
	assert_eq(int(b.attack_preview(0, 1).hit_chance), 90, "honda −10")
	var c := _battle([_adoc(Vector2i(1, 2), LANZA), _unit(&"e0", E, Vector2i(3, 2))])
	_turn(c, 0)
	assert_eq(int(c.attack(1).damage), 6 + 2 - 3, "lanza +2 a 2 casillas")


# --- ATQ en la ficha ----------------------------------------------------------------------------------

func test_atk_line_shown() -> void:
	var b := _battle([_adoc(Vector2i(1, 2), LANZA), _unit(&"e0", E, Vector2i(5, 2))])
	assert_eq(TacticalTurnFlow.atk_line(b, 0), "ATQ 8 (Lanza +2)")
	assert_eq(TacticalTurnFlow.atk_line(b, 1), "ATQ 8")
	var s := _battle([_adoc(Vector2i(1, 2), CUCHILLO, true), _unit(&"e0", E, Vector2i(5, 2))])
	assert_eq(TacticalTurnFlow.atk_line(s, 0), "ATQ 6 (Cuchillo en la funda)")
	var n := _battle([_adoc(Vector2i(1, 2), &""), _unit(&"e0", E, Vector2i(5, 2))])
	assert_eq(TacticalTurnFlow.atk_line(n, 0), "ATQ 6 (sin arma)")


# --- Desenfundar ----------------------------------------------------------------------------------------

func test_draw_in_an_ambush() -> void:
	var b := _battle([_adoc(Vector2i(1, 2), LANZA, true), _unit(&"e0", E, Vector2i(3, 2))])
	_turn(b, 0)
	var flow := TacticalTurnFlow.new(b)
	flow.begin_player_turn()
	flow.choose_main(TacticalTurnFlow.MAIN_ACT)
	var entries: Array[Dictionary] = flow.act_entries()
	assert_eq(entries[0].id, TacticalTurnFlow.ACT_DRAW, "Desenfundar, lo primero")
	var res: Dictionary = flow.choose_act(TacticalTurnFlow.ACT_DRAW)
	assert_eq(res.kind, TacticalBattle.KIND_DRAW)
	assert_true(b.active_acted, "gasta la acción")
	assert_eq(int(b.units[0].atk), 8)
	assert_eq(int(b.units[0].range_max), 2)
	assert_false(b.can_draw())
	assert_false(b.can_act(), "no ataca en el mismo turno")
	assert_true(b.can_hit_from(0, b.units[0].cell, 1), "el siguiente turno, ya a 2")
	# Sin arma en la funda no hay Desenfundar.
	var c := _battle([_adoc(Vector2i(1, 2), LANZA), _unit(&"e0", E, Vector2i(5, 2))])
	_turn(c, 0)
	var f2 := TacticalTurnFlow.new(c)
	f2.begin_player_turn()
	f2.choose_main(TacticalTurnFlow.MAIN_ACT)
	for e: Dictionary in f2.act_entries():
		assert_ne(e.id, TacticalTurnFlow.ACT_DRAW)


func test_ambush_from_game_state_starts_sheathed_and_shows_the_notice() -> void:
	GameState.equipped.main_hand = String(LANZA)
	GameState.weapon_drawn = false
	var logic: BattleLogic = AdventureRules.start_battle(TARGET, 1, &"botarramas", 1, [], true)
	assert_true(logic.weapon_sheathed)
	var b: TacticalBattle = TacticalBridge.build_battle(logic, {}, null, null, TacticalBattle.Opening.AMBUSH)
	assert_true(bool(b.units[0].sheathed))
	assert_eq(int(b.units[0].range_max), 1)
	var lines: PackedStringArray = TacticalBattleScene.opening_lines(b, logic)
	assert_eq(lines[lines.size() - 1], Texts.get_text("tactical_weapon_sheathed"))
	# Sin arma: "Peleas sin arma."
	GameState.equipped.main_hand = ""
	logic = AdventureRules.start_battle(TARGET, 1)
	b = TacticalBridge.build_battle(logic)
	assert_true(Array(TacticalBattleScene.opening_lines(b, logic)).has(Texts.get_text("battle_unarmed")))


# --- Puente ------------------------------------------------------------------------------------------

func test_bridge_carries_range_and_effects() -> void:
	var base: int = int(AdocGrowth.player_stats().atk)
	for id: StringName in [LANZA, CUCHILLO, HONDA]:
		GameState.equipped.main_hand = String(id)
		var logic: BattleLogic = AdventureRules.start_battle(TARGET, 1)
		assert_eq(logic.weapon_id, id)
		var b: TacticalBattle = TacticalBridge.build_battle(logic)
		var u: Dictionary = b.units[0]
		var r: Array[int] = Items.weapon_range(id)
		assert_eq(int(u.range_min), r[0], String(id))
		assert_eq(int(u.range_max), r[1], String(id))
		assert_eq(bool(u.range_line), Items.weapon_line(id))
		assert_eq(int(u.atk), base + Items.atk_bonus(id), "el ATQ del arma una sola vez")
		assert_eq(int(u.back_extra), Items.back_bonus(id))
		assert_eq(int(u.hit_mod), Items.hit_mod(id))
	GameState.equipped.main_hand = ""
	var bare: TacticalBattle = TacticalBridge.build_battle(AdventureRules.start_battle(TARGET, 1))
	assert_eq(int(bare.units[0].range_max), 1)
	assert_eq(int(bare.units[0].atk), base)


# --- Objeto -------------------------------------------------------------------------------------------

func _items(n: int, slot: int = 0) -> Array:
	var out: Array = []
	for k: int in n:
		out.append({ "slot": slot, "id": Items.FRUIT_ID, "heal_pct": 25, "use_range": 1 })
	return out


func test_item_heals_quarter_adjacency_spends_action() -> void:
	var b := _battle([_adoc(Vector2i(1, 2), LANZA, false, { "hp": 10, "max_hp": 30 }),
		_unit(&"ally", P, Vector2i(1, 3), { "hp": 5, "max_hp": 22 }),
		_unit(&"far", P, Vector2i(1, 5), { "hp": 5 }), _unit(&"e0", E, Vector2i(6, 2))])
	b.set_items(_items(2))
	_turn(b, 0)
	assert_eq(b.item_targets(0), [0, 1] as Array[int], "el Adoc y el aliado adyacente, no el lejano")
	var res: Dictionary = b.use_item(0, 1)
	assert_eq(res.kind, TacticalBattle.KIND_ITEM)
	assert_eq(int(res.amount), 6, "25% de 22, hacia arriba")
	assert_eq(int(b.units[1].hp), 11)
	assert_true(b.active_acted, "gasta la acción")
	assert_true(b.use_item(1, 0).is_empty(), "una acción por turno")
	assert_eq(b.used_items, [0] as Array[int])


func test_item_only_the_leader_and_caps_at_max() -> void:
	var b := _battle([_adoc(Vector2i(1, 2), &"", false, { "hp": 28 }), _unit(&"ally", P, Vector2i(1, 3)),
		_unit(&"e0", E, Vector2i(6, 2))])
	b.set_items(_items(1))
	_turn(b, 1)
	assert_true(b.usable_items().is_empty(), "el aliado no lleva la bolsa")
	b.end_turn(EAST)
	_turn(b, 0)
	assert_eq(int(b.use_item(0, 0).amount), 2, "no pasa del máximo")


func test_item_flow_lists_only_usable_and_targets() -> void:
	var b := _battle([_adoc(Vector2i(1, 2), LANZA, false, { "hp": 10 }), _unit(&"e0", E, Vector2i(6, 2))])
	b.set_items(_items(3, 4))
	_turn(b, 0)
	var flow := TacticalTurnFlow.new(b)
	flow.begin_player_turn()
	flow.choose_main(TacticalTurnFlow.MAIN_ACT)
	var ids: Array = []
	for e: Dictionary in flow.act_entries():
		ids.append(e.id)
	assert_true(ids.has(TacticalTurnFlow.ACT_ITEM))
	flow.choose_act(TacticalTurnFlow.ACT_ITEM)
	assert_eq(flow.state, TacticalTurnFlow.State.ITEM)
	var choices: Array[Dictionary] = flow.item_choices()
	assert_eq(choices.size(), 1, "agrupados por casilla")
	assert_eq(int(choices[0].count), 3)
	assert_eq(str(choices[0].text), "Fruto del Bosque ×3")
	flow.choose_item(int(choices[0].item))
	assert_eq(flow.state, TacticalTurnFlow.State.TARGET)
	assert_eq(flow.cursor, Vector2i(1, 2), "empieza en el Adoc")
	var res: Dictionary = flow.confirm()
	assert_eq(res.kind, TacticalBattle.KIND_ITEM)
	assert_eq(int(b.units[0].hp), 18)
	# Sin objetos, no sale Objeto.
	var c := _battle([_adoc(Vector2i(1, 2), LANZA), _unit(&"e0", E, Vector2i(6, 2))])
	_turn(c, 0)
	var f2 := TacticalTurnFlow.new(c)
	f2.begin_player_turn()
	f2.choose_main(TacticalTurnFlow.MAIN_ACT)
	for e: Dictionary in f2.act_entries():
		assert_ne(e.id, TacticalTurnFlow.ACT_ITEM)


func test_item_is_consumed_from_the_bag_after_the_battle() -> void:
	GameState.hp = 5
	InventoryLogic.add_stacked(GameState.bag, Items.FRUIT_ID, 2, Items.stack_max(Items.FRUIT_ID), TARGET)
	var logic: BattleLogic = AdventureRules.start_battle(TARGET, 1)
	assert_eq(logic.combat_items.size(), 2, "uno por fruto")
	var b: TacticalBattle = TacticalBridge.build_battle(logic)
	assert_eq(int(b.items[0].heal_pct), int(AdventureRules.balance().fruit.heal_pct))
	b.set_ct(0, 100)
	for i in range(1, b.units.size()):
		b.set_ct(i, 0)
	assert_eq(b.begin_turn(), 0)
	var before: int = int(b.units[0].hp)
	assert_false(b.use_item(0, 0).is_empty())
	assert_gt(int(b.units[0].hp), before)
	b.result = TacticalBattle.Result.FLED
	TacticalBridge.apply_to_logic(b, logic)
	assert_eq(logic.used_items.size(), 1)
	AdventureRules.finish_battle(logic, TARGET)
	assert_eq(InventoryLogic.count(GameState.bag, Items.FRUIT_ID), 1, "el fruto comido sale de la bolsa")
	assert_eq(GameState.hp, int(b.units[0].hp), "y la curación se queda")


# --- Equipo inicial -------------------------------------------------------------------------------------

func test_new_game_starting_equipment() -> void:
	assert_eq(GameState.equipped.main_hand, String(LANZA), "la lanza equipada")
	assert_false(GameState.weapon_drawn, "y enfundada")
	assert_eq(GameState.equipped.mask, "mascara_de_corteza", "la máscara de corteza puesta")
	assert_eq(GameState.equipped.talisman, "")
	assert_eq(InventoryLogic.count(GameState.bag, &"trenza_votiva"), 1, "una trenza votiva en la bolsa")
	assert_eq(InventoryLogic.count(GameState.bag, LANZA), 0, "la lanza ya no va en la bolsa")
	assert_eq(InventoryLogic.free_slots(GameState.bag), Items.bag_size() - 1)


func test_saved_games_keep_their_equipment() -> void:
	GameState.equipped = InventoryLogic.new_equipped()
	GameState.weapon_drawn = false
	GameState.bag = InventoryLogic.new_bag(Items.bag_size())
	InventoryLogic.add(GameState.bag, LANZA)
	assert_eq(SaveManager.save_game(SAVE_SLOT), OK)
	GameState.new_game(42)
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	assert_eq(GameState.equipped.main_hand, "", "la guardada sigue sin arma equipada")
	assert_eq(GameState.equipped.mask, "")
	assert_eq(InventoryLogic.count(GameState.bag, LANZA), 1)
	assert_eq(InventoryLogic.count(GameState.bag, &"trenza_votiva"), 0, "sin trenza nueva")


# --- De dónde salen el Cuchillo y la Honda -------------------------------------------------------------

func test_knife_in_some_refuges_with_a_find() -> void:
	var with_find: int = 0
	var with_knife: Vector2i = Vector2i(-1, -1)
	for x: int in 40:
		for y: int in 10:
			var c := Vector2i(x, y)
			if AdventureRules.refuge_ofrenda(GameState.seed_value, c) == &"":
				assert_eq(AdventureRules.refuge_weapon(GameState.seed_value, c), &"", "solo donde hay hallazgo")
				continue
			with_find += 1
			if AdventureRules.refuge_weapon(GameState.seed_value, c) == CUCHILLO and with_knife.x < 0:
				with_knife = c
	assert_gt(with_find, 0)
	assert_gt(with_knife.x, -1, "alguno guarda el cuchillo")
	watch_signals(EventBus)
	var item: Dictionary = AdventureRules.loot_refuge(with_knife)
	assert_true(bool(item.taken))
	assert_eq(item.weapon, CUCHILLO)
	assert_eq(InventoryLogic.count(GameState.bag, CUCHILLO), 1)
	assert_signal_emitted(EventBus, "notice_requested")
	assert_false(AdventureRules.give_weapon(CUCHILLO), "si ya lo tienes, no otro")


func test_honda_for_winning_with_another_adoc_once() -> void:
	var e: Dictionary = { "id": "test_adoc", "bosque_id": TARGET, "name": "Amaru" }
	var lines: PackedStringArray = AdocEncounters.finish(e, &"victory")
	assert_eq(InventoryLogic.count(GameState.bag, HONDA), 1)
	assert_true(Array(lines).has(Texts.get_text("adoc_encounter_weapon") % ["Amaru", "honda"]))
	var again: PackedStringArray = AdocEncounters.finish({ "id": "test_adoc_2", "bosque_id": TARGET,
		"name": "Ilse" }, &"victory")
	assert_eq(InventoryLogic.count(GameState.bag, HONDA), 1, "solo una")
	assert_eq(again.size(), lines.size() - 1)


# --- Humo IA contra IA con armas -----------------------------------------------------------------------

func test_smoke_ai_vs_ai_with_weapons_and_ambush_never_loops() -> void:
	var weapons: Array[StringName] = [LANZA, CUCHILLO, HONDA, &""]
	var stuck: Array = []
	for k: int in 120:
		var rng := RandomNumberGenerator.new()
		rng.seed = 500 + k
		var weapon: StringName = weapons[k % weapons.size()]
		var sheathed: bool = k % 3 == 0
		var fighters: Array = [_adoc(Vector2i(-1, -1), weapon, sheathed, { "cell": Vector2i(-1, -1),
			"agi": rng.randi_range(4, 8) })]
		fighters[0].erase("facing")
		fighters.append({ "id": &"ally_0", "side": P, "agi": rng.randi_range(4, 8), "max_hp": 20, "atk": 6, "def": 2 })
		var profiles: Array = ["aggressive", "swarm", "guardian", "whip", "ambusher", "berserk"]
		for e: int in 3:
			var p: String = profiles[rng.randi_range(0, profiles.size() - 1)]
			fighters.append({ "id": StringName("enemy_%d" % e), "side": E, "agi": rng.randi_range(3, 8),
				"max_hp": rng.randi_range(12, 26), "atk": rng.randi_range(4, 8), "def": rng.randi_range(1, 3),
				"ai": p, "attack_range": [1, 2] if p == "whip" else [1, 1], "joint": p == "swarm" })
		var b := _battle(fighters, 500 + k)
		b.apply_opening(TacticalBattle.Opening.AMBUSH if sheathed else TacticalBattle.Opening.NORMAL)
		# El Adoc lo lleva la IA en lugar del jugador, con la orden Atacar: así no se dan los "todos se
		# retiran" con poca vida que un jugador nunca haría (el Adoc no tiene Auto).
		b.set_group_order(BattleLogic.GroupOrder.ATTACK)
		for turn: int in 600:
			if b.is_over():
				break
			var i: int = b.begin_turn()
			if i == TacticalBattle.NONE:
				break
			var plan: Dictionary = TacticalAI.plan(b, i)
			if not b.reachable_for(i).has(plan.move_to):
				fail_test("seed %d: casilla inalcanzable" % (500 + k))
				return
			if plan.move_to != b.units[i].cell:
				b.move_active(plan.move_to)
			var res: Dictionary = TacticalAI.apply_action(b, plan)
			if StringName(plan.action) != TacticalAI.KIND_NONE and res.is_empty():
				fail_test("seed %d: acción que no se ejecuta %s" % [500 + k, plan])
				return
			if not b.is_over():
				TacticalAI.finish_turn(b)
		if not b.is_over():
			var hp: Array = []
			for u: Dictionary in b.units:
				hp.append([u.id, u.cell, u.hp, u.alive, u.ai])
			stuck.append([500 + k, weapon, sheathed, hp])
		if sheathed and weapon != &"":
			assert_false(bool(b.units[0].sheathed) and b.units[0].alive and b.turn_count > 20,
				"seed %d: el Adoc desenfunda" % (500 + k))
	assert_eq(stuck, [], "todos terminan sin bucles")
