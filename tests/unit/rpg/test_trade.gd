extends GutTest
## P5 (ajustes-playtest-0.5.md 5b, ADR 0017 §5): trueque mínimo con el Sarua y el Paruas de la villa
## natal. Catálogo por NPC, comprar con Luz y con ofrenda, sin fondos, límite diario y su reinicio con
## el día, armas que ya tienes ocultas, guardado v22 con su migración y colocación de los NPC en
## casillas libres de una villa generada.

const SAVE_SLOT: int = 89
const SARUA: StringName = &"sarua_natal"
const PARUAS: StringName = &"paruas_natal"
const VILLA: String = "3,4"


func before_each() -> void:
	WorldClock.set_process(false)
	GameState.new_game(42)


func after_each() -> void:
	WorldClock.set_process(true)


func after_all() -> void:
	DirAccess.remove_absolute(SaveManager.slot_path(SAVE_SLOT))
	GameState.new_game(42)


func _ids(entries: Array[Dictionary]) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Dictionary in entries:
		out.append(e.id)
	return out


## Primer objeto que el Sarua ofrece hoy.
func _first_sarua() -> Dictionary:
	return Trade.offer(SARUA, VILLA)[0]


func _empty_bag() -> void:
	GameState.bag = InventoryLogic.new_bag(Items.bag_size())


# --- Catálogo ------------------------------------------------------------------------------------

func test_catalog_per_npc_matches_the_design_table() -> void:
	assert_true(Trade.is_trader(SARUA))
	assert_true(Trade.is_trader(PARUAS))
	assert_false(Trade.is_trader(&"sfida_natal"), "el sfida no comercia")
	var sarua: Dictionary = {}
	for e: Dictionary in Trade.catalog(SARUA):
		sarua[e.id] = e.price
		assert_true(Items.kind_of(e.id) in [Items.KIND_MASK, Items.KIND_TALISMAN], "el Sarua: máscaras y talismanes")
	assert_eq(sarua, { &"talisman_de_semillas": 4, &"mascara_de_corteza": 4, &"mascara_de_musgo": 5,
		&"mascara_de_ceniza": 6, &"talisman_de_pluma": 6 })
	assert_eq(_ids(Trade.catalog(PARUAS)), [&"cuchillo", &"honda"] as Array[StringName], "el Paruas: las armas")
	assert_eq(Trade.price_of(PARUAS, &"cuchillo"), 5)
	assert_eq(Trade.price_of(PARUAS, &"honda"), 6)
	assert_eq(Trade.price_of(PARUAS, &"mascara_de_ceniza"), 0, "no es suyo")
	assert_eq(Trade.daily_stock(SARUA), 3)


func test_stock_is_three_by_seed_and_day() -> void:
	var a: Array[StringName] = _ids(Trade.stock(SARUA, 42, VILLA, 1))
	assert_eq(a.size(), 3, "3 objetos al día")
	assert_eq(_ids(Trade.stock(SARUA, 42, VILLA, 1)), a, "determinista")
	var varies: bool = false
	for day: int in range(2, 12):
		if _ids(Trade.stock(SARUA, 42, VILLA, day)) != a:
			varies = true
	assert_true(varies, "cambia con el día")
	assert_eq(Trade.stock(PARUAS, 42, VILLA, 1).size(), 2, "con 2 en el catálogo, los 2")


# --- Comprar -------------------------------------------------------------------------------------

func test_buy_with_luz() -> void:
	var e: Dictionary = _first_sarua()
	GameState.luz = 10
	var before: int = InventoryLogic.count(GameState.bag, e.id)
	watch_signals(EventBus)
	assert_eq(Trade.buy(SARUA, VILLA, e.id, { "kind": Trade.PAY_LUZ }), Trade.OK)
	assert_eq(GameState.luz, 10 - int(e.price), "se cobra el precio")
	assert_eq(InventoryLogic.count(GameState.bag, e.id), before + 1, "el objeto, a la bolsa")
	assert_signal_emitted(EventBus, "item_traded")
	assert_false(_ids(Trade.offer(SARUA, VILLA)).has(e.id), "cada objeto, una vez por día")
	assert_eq(Trade.buy(SARUA, VILLA, e.id), Trade.NOT_OFFERED)


func test_buy_with_an_ofrenda_completed_with_luz() -> void:
	# Trenza votiva (4) en la bolsa inicial.
	GameState.luz = 1
	var opts: Array[Dictionary] = Trade.pay_options(5)
	assert_eq(opts.size(), 1, "con 1 de Luz no llega solo con Luz; sí la trenza + 1")
	assert_eq(opts[0].kind, Trade.PAY_OFRENDA)
	assert_eq(opts[0].id, &"trenza_votiva")
	assert_eq(int(opts[0].luz), 1)
	GameState.luz = 2
	assert_eq(Trade.buy(PARUAS, VILLA, &"cuchillo", opts[0]), Trade.OK)
	assert_eq(GameState.luz, 1, "4 de la trenza + 1 de Luz")
	assert_eq(InventoryLogic.count(GameState.bag, &"trenza_votiva"), 0, "la ofrenda se deja entera")
	assert_eq(InventoryLogic.count(GameState.bag, &"cuchillo"), 1)


func test_ofrenda_surplus_is_lost() -> void:
	_empty_bag()
	InventoryLogic.add(GameState.bag, &"figura_sarua")
	GameState.luz = 0
	var e: Dictionary = _first_sarua()
	assert_eq(Trade.buy(SARUA, VILLA, e.id, { "kind": Trade.PAY_OFRENDA, "id": &"figura_sarua" }), Trade.OK)
	assert_eq(GameState.luz, 0, "la figura (8) paga sola y el resto se pierde")
	assert_eq(InventoryLogic.count(GameState.bag, &"figura_sarua"), 0)


func test_without_funds() -> void:
	_empty_bag()
	GameState.luz = 3
	var e: Dictionary = _first_sarua()
	assert_true(Trade.pay_options(int(e.price)).is_empty(), "ni Luz ni ofrendas")
	assert_false(Trade.can_afford(int(e.price)))
	assert_eq(Trade.buy(SARUA, VILLA, e.id), Trade.NO_FUNDS)
	assert_eq(Trade.buy(SARUA, VILLA, e.id, { "kind": Trade.PAY_OFRENDA, "id": &"trenza_votiva" }), Trade.NO_FUNDS,
		"una ofrenda que no llevas no paga")
	assert_eq(GameState.luz, 3, "no se cobra nada")
	assert_eq(InventoryLogic.count(GameState.bag, e.id), 0)
	var text: String = TradeDialog.result_text(Trade.NO_FUNDS, e.id, int(e.price))
	assert_string_contains(text, Items.display_name(e.id))
	assert_string_contains(text, str(e.price))


func test_bag_full_does_not_charge() -> void:
	for i: int in Items.bag_size():
		GameState.bag[i] = { "id": "cuchillo", "qty": 1 }
	GameState.luz = 10
	var e: Dictionary = _first_sarua()
	assert_eq(Trade.buy(SARUA, VILLA, e.id), Trade.BAG_FULL)
	assert_eq(GameState.luz, 10)


# --- Límite diario -------------------------------------------------------------------------------

func test_daily_limit_and_reset_with_the_day() -> void:
	GameState.luz = AdventureRules.luz_max()
	_empty_bag()
	for i: int in 3:
		var offer: Array[Dictionary] = Trade.offer(SARUA, VILLA)
		assert_eq(offer.size(), 3 - i)
		GameState.luz = AdventureRules.luz_max()
		assert_eq(Trade.buy(SARUA, VILLA, offer[0].id), Trade.OK)
	assert_true(Trade.limit_reached(SARUA, VILLA), "3 al día")
	assert_true(Trade.offer(SARUA, VILLA).is_empty())
	var any: StringName = Trade.catalog(SARUA)[0].id
	assert_eq(Trade.buy(SARUA, VILLA, any), Trade.LIMIT)
	assert_false(Trade.limit_reached(SARUA, "9,9"), "el límite es por villa")
	assert_false(Trade.limit_reached(PARUAS, VILLA), "y por artesano")
	# El día sube en el riutash del amanecer (DayManager).
	var days := DayManager.new()
	add_child_autofree(days)
	days.advance_days(1)
	assert_false(Trade.limit_reached(SARUA, VILLA), "se repone con el día")
	assert_eq(Trade.offer(SARUA, VILLA).size(), 3)
	assert_eq(Trade.sold_today(SARUA, VILLA).size(), 0)


func test_day_resets_through_the_dawn_riutash() -> void:
	GameState.luz = 10
	assert_eq(Trade.buy(PARUAS, VILLA, &"honda"), Trade.OK)
	var days := DayManager.new()
	add_child_autofree(days)
	var day: int = GameState.day
	EventBus.momento_changed.emit(TimeConfig.RIUMNA)
	assert_eq(GameState.day, day, "al anochecer no cambia")
	EventBus.momento_changed.emit(TimeConfig.GIETOS)
	assert_eq(GameState.day, day + 1)
	assert_true(Trade.sold_today(PARUAS, VILLA).is_empty(), "lo de ayer no cuenta")


# --- Armas que ya tienes -------------------------------------------------------------------------

func test_owned_weapons_are_hidden() -> void:
	assert_eq(_ids(Trade.offer(PARUAS, VILLA)), [&"cuchillo", &"honda"] as Array[StringName])
	AdventureRules.give_weapon(&"cuchillo")
	assert_eq(_ids(Trade.offer(PARUAS, VILLA)), [&"honda"] as Array[StringName], "en la bolsa: no sale")
	GameState.equipped.main_hand = "honda"
	assert_true(Trade.offer(PARUAS, VILLA).is_empty(), "equipada: tampoco")
	assert_eq(Trade.buy(PARUAS, VILLA, &"honda"), Trade.NOT_OFFERED)
	assert_false(Trade.limit_reached(PARUAS, VILLA), "sin nada que ofrecer no es el límite")


func test_masks_you_own_are_still_offered() -> void:
	# La máscara de ceniza se rompe: se vuelve a por otra (5b).
	for day: int in range(1, 40):
		GameState.day = day
		if _ids(Trade.offer(SARUA, VILLA)).has(&"mascara_de_ceniza"):
			InventoryLogic.add(GameState.bag, &"mascara_de_ceniza")
			assert_true(_ids(Trade.offer(SARUA, VILLA)).has(&"mascara_de_ceniza"))
			return
	fail_test("la máscara de ceniza no sale en 40 días")


# --- Diálogo -------------------------------------------------------------------------------------

func test_dialog_texts() -> void:
	var offer: Array[Dictionary] = Trade.offer(PARUAS, VILLA)
	var options: Array[String] = TradeDialog.item_options(offer)
	assert_eq(options, ["Cuchillo (5)", "Honda (6)", Texts.get_text("trade_leave")] as Array[String])
	GameState.luz = 3
	var pays: Array[Dictionary] = Trade.pay_options(5)
	assert_eq(TradeDialog.pay_labels(pays, 5), ["Trenza votiva (4) + 1 Luz", Texts.get_text("trade_cancel")] as Array[String])
	assert_string_contains(TradeDialog.prompt_text(SARUA), "3")
	assert_eq(TradeDialog.result_text(Trade.OK, &"honda", 6), Texts.get_text("trade_done") % "Honda")
	for key: String in ["trade_limit", "trade_nothing", "trade_bag_full", "trade_pay_prompt"]:
		assert_ne(Texts.get_text(key), key, "texto %s en sistema.json" % key)


# --- Guardado ------------------------------------------------------------------------------------

func test_save_keeps_what_was_sold_today() -> void:
	assert_eq(GameState.SAVE_VERSION, 22)
	GameState.luz = 10
	assert_eq(Trade.buy(PARUAS, VILLA, &"honda"), Trade.OK)
	assert_eq(SaveManager.save_game(SAVE_SLOT), OK)
	GameState.new_game(42)
	assert_true(Trade.sold_today(PARUAS, VILLA).is_empty(), "partida nueva: nada vendido")
	assert_eq(SaveManager.load_game(SAVE_SLOT), OK)
	assert_eq(Trade.sold_today(PARUAS, VILLA), [&"honda"] as Array[StringName], "vuelve tras cargar")


func test_migration_from_v21_and_sanitize() -> void:
	var data: Dictionary = GameState.to_dict()
	data.save_version = 21
	data.erase("trade_sold")
	var migrated: Dictionary = SaveManager.migrate(data)
	assert_eq(migrated.trade_sold, {}, "v21: nada cambiado")
	GameState.trade_sold = { "x": { "day": 1, "sold": ["honda"] } }
	GameState.from_dict(migrated)
	assert_eq(GameState.trade_sold, {})
	var dirty: Dictionary = { "1,1:paruas_natal": { "day": 3, "sold": ["honda", "honda", "nada"] },
		"bad": { "day": 0, "sold": [] }, "worse": 5 }
	assert_eq(Trade.sanitize_sold(dirty), { "1,1:paruas_natal": { "day": 3, "sold": ["honda"] } })


# --- Colocación en la villa ----------------------------------------------------------------------

func test_artisans_stand_on_free_plaza_cells() -> void:
	for s: int in [42, 7, 1234]:
		var plan := RegionPlan.for_region(s, &"valle_del_sara")
		var chunk: WorldChunk = ChunkBuilder.build(plan, plan.home_chunk)
		var sfida: Vector2i = Npc.sfida_cell_world(chunk)
		var cells: Dictionary = Npc.artisan_cells_world(chunk)
		assert_eq(cells.keys(), [SARUA, PARUAS], "seed %d: los dos" % s)
		assert_eq(Npc.artisan_cells_world(ChunkBuilder.build(plan, plan.home_chunk)), cells, "seed %d: determinista" % s)
		var spawn: Vector2i = Npc.villa_spawn_cell_world(chunk)
		var placed: Array[Vector2i] = [sfida]
		for id: StringName in cells:
			var at: Vector2i = cells[id]
			assert_eq(chunk.get_ground(at), WorldChunk.Ground.PLAZA, "seed %d %s: en la plaza" % [s, id])
			assert_true(chunk.is_reachable(at), "seed %d %s: alcanzable" % [s, id])
			assert_ne(at, chunk.hub)
			assert_ne(at, spawn)
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var n: Vector2i = at + Vector2i(dx, dy)
					assert_true(chunk.is_walkable(n) and chunk.object_index_at(n) == WorldChunk.NO_OBJECT,
						"seed %d %s: libre alrededor" % [s, id])
			for other: Vector2i in placed:
				assert_gte(maxi(absi(at.x - other.x), absi(at.y - other.y)), Npc.NPC_SPACING,
					"seed %d %s: con sitio entre NPC" % [s, id])
			placed.append(at)
		assert_lte(absi(cells[SARUA].x - sfida.x) + absi(cells[SARUA].y - sfida.y), 8, "seed %d: junto al sfida" % s)


func test_artisan_placeholder_differs_from_the_sfida() -> void:
	var p: Dictionary = Npc.placeholder_of(SARUA)
	assert_false(p.is_empty())
	assert_eq(p.prop, &"mask")
	assert_eq(Npc.placeholder_of(PARUAS).prop, &"tool")
	assert_true(Npc.placeholder_of(&"sfida_natal").is_empty(), "el sfida usa su hoja")
	var a: Image = Npc.make_texture(p.colors, Vector2i.DOWN, p.prop).get_image()
	var b: Image = Npc.make_texture(Npc.SFIDA_COLORS, Vector2i.DOWN).get_image()
	assert_ne(a.get_data(), b.get_data())
	var npc := Npc.new()
	add_child_autofree(npc)
	npc.setup_world(SARUA, Vector2i(10, 10))
	assert_eq(npc.npc_id, SARUA)


# --- Gancho en la exploración ----------------------------------------------------------------------

func test_e_on_the_paruas_opens_the_trade_and_buys() -> void:
	var expl: WorldExploration = load("res://scenes/world/world_exploration.tscn").instantiate()
	add_child_autoqfree(expl)
	await expl.start()
	var npcs: Dictionary = expl.get("_npcs")
	var at: Vector2i = WorldCoords.world_pos_to_world_cell(npcs[PARUAS])
	GameState.player_facing = Vector2i.RIGHT
	expl._place(at + Vector2i.LEFT)
	expl._fade.color.a = 0.0
	GameState.luz = 10
	expl._interact()
	assert_true(expl._dialogue.is_open(), "E abre el trueque")
	expl._dialogue.choice.emit(0)
	assert_true(expl._dialogue.is_open(), "pregunta con qué pagar")
	expl._dialogue.choice.emit(0)
	assert_eq(InventoryLogic.count(GameState.bag, &"cuchillo"), 1, "el Cuchillo, a la bolsa")
	assert_eq(GameState.luz, 5)
	var villa: String = Trade.villa_key(WorldCoords.world_cell_to_chunk(at))
	assert_eq(Trade.sold_today(PARUAS, villa), [&"cuchillo"] as Array[StringName], "por la villa natal")
	assert_true(expl._dialogue.is_open(), "avisa de lo recibido")
	# El aviso pausa el árbol (pause_tree): se cierra para no dejar pausados los tests siguientes.
	expl._dialogue._close()
	get_tree().paused = false
