extends GutTest
## Elección de party antes del combate táctico (combate-tactico.md, "Tu party"; #188, PR T1b):
## preseleccionada con la última, el Adoc siempre entra, sin preguntar si cabe o en una emboscada,
## guardado en GameState (v19) y la pantalla de elección.

const TACTICAL_SCENE: PackedScene = preload("res://scenes/rpg/tactical_battle_scene.tscn")
const STYLE: Dictionary = { "leaf": 0, "trunk": 0, "ground": 0 }

var _saved_party: Array[String] = []


func before_each() -> void:
	_saved_party = GameState.last_party.duplicate()


func after_each() -> void:
	GameState.last_party = _saved_party


func _allies() -> Array:
	return [
		{ "name": "Tavra", "kind": "adoc", "max_hp": 15, "atk": 5, "def": 2, "agi": 6 },
		{ "name": "Botarramas aliado", "kind": "botarramas", "max_hp": 20, "atk": 5, "def": 3, "agi": 3 },
		{ "name": "Ilen", "kind": "adoc", "max_hp": 15, "atk": 5, "def": 2, "agi": 5 },
	]


func _logic(allies: Array, enemies: int = 2) -> BattleLogic:
	var adoc: Dictionary = { "max_hp": 20, "atk": 6, "def": 3, "agi": 5 }
	var logic := BattleLogic.new(AdventureRules.balance(), adoc, 20, 5,
		{ "name": "R1", "max_hp": 10, "atk": 4, "def": 1, "agi": 7 }, 42)
	for k: int in range(1, enemies):
		logic.add_enemy({ "name": "R%d" % (k + 1), "max_hp": 10, "atk": 4, "def": 1, "agi": 7 })
	for a: Dictionary in allies:
		logic.add_ally(a)
	return logic


func _cfg(quota: int) -> Dictionary:
	var cfg: Dictionary = TacticalBattle.config_from_balance(AdventureRules.balance())
	cfg.board = { "width": 8, "height": 6, "deploy_columns": 2, "max_per_side": quota, "ford_cost": 1 }
	return cfg


# --- Lógica -------------------------------------------------------------------------------------

func test_ally_keys_are_stable_by_kind() -> void:
	assert_eq(TacticalParty.ally_keys(_allies()), ["adoc:0", "botarramas:0", "adoc:1"] as Array[String])
	assert_eq(TacticalParty.ally_keys([{ "kind": "adoc", "party_key": "garelino:Ruk" }]), ["garelino:Ruk"] as Array[String])


func test_adoc_always_takes_a_slot() -> void:
	assert_eq(TacticalParty.ally_slots(3), 2)
	assert_eq(TacticalParty.ally_slots(1), 0, "cupo 1: solo el Adoc")
	var chosen: Array[int] = TacticalParty.preselect(TacticalParty.ally_keys(_allies()), [], 1)
	assert_true(chosen.is_empty())


func test_no_prompt_when_the_party_fits() -> void:
	assert_false(TacticalParty.needs_prompt(2, 3), "2 aliados + el Adoc caben en 3")
	assert_true(TacticalParty.needs_prompt(3, 3))
	assert_false(TacticalParty.needs_prompt(0, 1))
	var r: Dictionary = TacticalParty.resolve(_allies(), 4, [])
	assert_false(r.prompt)
	assert_eq(r.chosen, [0, 1, 2] as Array[int], "entran todos")


func test_preselected_with_the_last_choice() -> void:
	var keys: Array[String] = TacticalParty.ally_keys(_allies())
	assert_eq(TacticalParty.preselect(keys, ["adoc:1"], 2), [2] as Array[int])
	assert_eq(TacticalParty.preselect(keys, ["adoc:1", "botarramas:0"], 3), [1, 2] as Array[int])
	assert_eq(TacticalParty.preselect(keys, ["adoc:1"], 3), [0, 2] as Array[int], "plaza libre: se completa en orden")
	assert_eq(TacticalParty.preselect(keys, [], 2), [0] as Array[int], "sin elección: los primeros")
	assert_eq(TacticalParty.preselect(keys, ["otro:0"], 2), [0] as Array[int], "la última ya no está")


func test_ambush_enters_the_last_party_without_asking() -> void:
	var r: Dictionary = TacticalParty.resolve(_allies(), 2, ["botarramas:0"], true)
	assert_false(r.prompt, "en una emboscada no se pregunta")
	assert_eq(r.chosen, [1] as Array[int], "entra la última party guardada")


func test_toggle_respects_the_slots() -> void:
	var chosen: Array[int] = [0]
	assert_eq(TacticalParty.toggle(chosen, 2, 2), [0] as Array[int], "lleno: no entra otro")
	assert_eq(TacticalParty.toggle(chosen, 0, 2), [] as Array[int])
	assert_eq(TacticalParty.toggle([] as Array[int], 2, 2), [2] as Array[int])


func test_battle_order_puts_the_chosen_first() -> void:
	assert_eq(TacticalParty.battle_order(3, [2] as Array[int]), [2, 0, 1] as Array[int])


func test_save_choice_writes_game_state() -> void:
	TacticalParty.save_choice(_allies(), [0, 2] as Array[int])
	assert_eq(GameState.last_party, ["adoc:0", "adoc:1"] as Array[String])
	assert_eq(TacticalParty.last_choice(), ["adoc:0", "adoc:1"] as Array[String])


func test_bridge_puts_unchosen_allies_in_reserve() -> void:
	var logic := _logic(_allies())
	var b: TacticalBattle = TacticalBridge.build_battle(logic, _cfg(2), null, [2] as Array[int])
	assert_eq(b.units[0].id, TacticalBridge.ADOC_ID, "el Adoc siempre entra")
	assert_true(b.units[0].alive)
	assert_eq(b.units[1].id, &"ally_2", "el elegido entra")
	assert_true(b.units[1].alive)
	var waiting: Array[int] = b.waiting_units(TacticalBattle.SIDE_PLAYER)
	assert_eq(waiting.size(), 2, "los otros dos esperan en el borde")
	assert_eq(b.units[waiting[0]].id, &"ally_0")


func test_bridge_keeps_hp_of_allies_that_never_entered() -> void:
	var logic := _logic(_allies())
	var b: TacticalBattle = TacticalBridge.build_battle(logic, _cfg(2), null, [0] as Array[int])
	b.result = TacticalBattle.Result.FLED
	TacticalBridge.apply_to_logic(b, logic)
	assert_eq(int(logic.allies[1].hp), 20, "esperó en el borde: sigue con sus PV")
	assert_false(logic.allies[1].get("retired", false))


# --- Guardado (v19) -----------------------------------------------------------------------------

func test_last_party_round_trips_in_the_save() -> void:
	GameState.last_party = ["adoc:0", "botarramas:0"] as Array[String]
	var data: Dictionary = GameState.to_dict()
	assert_gte(int(data.save_version), 19, "last_party desde la v19")
	GameState.last_party = []
	GameState.from_dict(data)
	assert_eq(GameState.last_party, ["adoc:0", "botarramas:0"] as Array[String])


func test_migration_from_v18_has_no_party() -> void:
	var data: Dictionary = GameState.to_dict()
	data.save_version = 18
	data.erase("last_party")
	var migrated: Dictionary = SaveManager.migrate(data)
	assert_true(migrated.has("last_party"))
	assert_eq((migrated.last_party as Array).size(), 0)
	assert_false(data.has("last_party"), "no toca los datos originales")
	GameState.last_party = ["adoc:0"] as Array[String]
	GameState.from_dict(migrated)
	assert_true(GameState.last_party.is_empty(), "una partida v18 carga sin party elegida")


# --- Escena -------------------------------------------------------------------------------------

func test_scene_skips_the_screen_when_the_party_fits() -> void:
	var scene: TacticalBattleScene = TACTICAL_SCENE.instantiate()
	add_child_autofree(scene)
	scene.begin(_logic(_allies().slice(0, 1)), STYLE, UnicoArt.Kind.REPAREP, [], _cfg(3))
	assert_null(scene.party_screen)
	assert_not_null(scene.battle, "sin preguntar")


func test_scene_skips_the_screen_in_an_ambush() -> void:
	GameState.last_party = ["adoc:1"] as Array[String]
	var scene: TacticalBattleScene = TACTICAL_SCENE.instantiate()
	add_child_autofree(scene)
	scene.begin(_logic(_allies()), STYLE, UnicoArt.Kind.REPAREP, [], _cfg(2), null, true)
	assert_null(scene.party_screen)
	assert_eq(scene.battle.units[1].id, &"ally_2", "entra la última party guardada")


func test_scene_asks_preselected_and_saves_on_confirm() -> void:
	GameState.last_party = ["botarramas:0"] as Array[String]
	var scene: TacticalBattleScene = TACTICAL_SCENE.instantiate()
	add_child_autofree(scene)
	scene.begin(_logic(_allies()), STYLE, UnicoArt.Kind.REPAREP, [], _cfg(2))
	assert_not_null(scene.party_screen, "3 aliados y 1 plaza: pregunta")
	assert_null(scene.battle, "el combate espera a la elección")
	var screen: TacticalPartyScreen = scene.party_screen
	assert_eq(screen.chosen, [1] as Array[int], "preseleccionada con la última")
	screen.choose(1)
	assert_eq(screen.chosen, [1] as Array[int], "lleno: Tavra no entra sin quitar a otro")
	screen.choose(2)
	assert_eq(screen.chosen, [] as Array[int], "la opción 2 es el aliado 1 (la 0 es el Adoc)")
	screen.choose(0)
	assert_eq(screen.chosen, [] as Array[int], "el Adoc no se puede quitar")
	screen.choose(3)
	assert_eq(screen.chosen, [2] as Array[int])
	screen.choose(screen.confirm_index())
	assert_null(scene.party_screen)
	assert_not_null(scene.battle)
	assert_eq(scene.battle.units[1].id, &"ally_2")
	assert_eq(GameState.last_party, ["adoc:1"] as Array[String], "guarda la elección")
