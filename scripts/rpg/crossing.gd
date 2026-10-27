extends CanvasLayer
## Menú del borde de un Bosque sin pagar (ADR 0009; cerrado o forzado): pagar Luz al Nujio, dejarle una ofrenda
## (submenú con las que alcanzan el peaje, completadas con Luz suelta; ofrendas-v1.md), enfrentar a
## su Botarramas o retroceder. Lo abre el encuentro con un Botarramas o, como red de seguridad, empujar el borde.
## Si el Bosque recuerda Botarramas vencidos, el peaje sube y el título lo avisa con una línea más;
## si la relación con el Bosque cambia el peaje (bosques-y-relacion.md), otra con su multiplicador.
## Estados de Bosque (BosqueStates): un Bosque enojado no acepta pagos (solo "Enfrentar" y
## "Retroceder", con su aviso en el título); uno corrupto lo dice junto a su peaje ×1,5. Los que no
## cobran (muerto, necesita_ayuda) tienen el borde abierto y el menú no se abre.
## Sigilo (sigilo-y-robo.md): con el arma en la mano el Bosque no deja pasar en paz aunque esté
## pagado: el menú se abre igual, sin pagos ("El Bosque siente tu arma.": enfrentar o retroceder).
## Con la skill Imponerse (moralidad-y-progresion.md) hay una opción más: si el nivel del Adoc llega
## a d + 2 y el Bosque no está enojado, el Botarramas se aparta sin pelear (cuenta como vencerlo).
## También lleva el combate de misión (Ofomni descarriado, EventBus.quest_battle_requested) y el
## combate directo contra un Único de dentro del Bosque (EventBus.unico_battle_requested: Ofomni
## que persiguen tras un robo, cazadores, los que rondan o el que se enfrenta a voluntad; sin menú,
## se puede apaciguar pagando el peaje del Bosque si el Único lo acepta) y el combate en grupo
## (EventBus.group_battle_requested: un grupo de reparep, con aliados si los hay).
## Mientras está abierto (o dura el combate) el árbol se pausa; este nodo y el combate siguen
## activos (process_mode ALWAYS). Al terminar emite EventBus.crossing_resolved (o
## quest_battle_resolved) y la exploración cruza, retrocede o despierta al Adoc junto a un Nujio aliado.
## Combate táctico (T1b): el tamaño del tablero y el cupo salen de la proporción transitable de un
## recorte de 14 x 10 alrededor del Adoc (TacticalArena). Por orden: `walkable_sampler` si se
## inyecta (tests); en el Mundo 2.0, WorldQuery.rect si el mundo activo da `world_get_chunk` y
## `world_player_cell`; si no, el chunk de exploración antiguo, regenerándolo con su seed
## (ChunkGenerator.generate, ~30 ms, una vez por combate); sin chunk, el bioma. El bioma
## (desempate) es "bosque" mientras no haya otros biomas. Tablero (T7a): en el Mundo 2.0, el del
## relieve real alrededor del Adoc (TacticalRelief.arena_config: recorte, riscos comprimidos, cupo
## contado sobre él); si no, llano.
## Apertura (T6): EventBus.battle_opening_set (lo emite la exploración al alcanzarle un Único o al
## enfrentarse a uno con E) dice si empieza con sorpresa o con emboscada; se gasta en el siguiente
## combate de misión, directo o en grupo (el del borde, tras el menú, y el de ayuda a otro adoc
## siempre son normales). Solo cuenta en el combate
## táctico: la escena por menú no tiene apertura.
## Solo escucha EventBus y lee GameState: no conoce la escena de exploración.

const BATTLE_SCENE: PackedScene = preload("res://scenes/rpg/battle.tscn")
## Escena del combate táctico (combate-tactico.md, T4): se abre en vez de la de menú con
## tactical.enabled en balance.json (TacticalBridge.is_enabled). Mismas entradas y salidas.
const TACTICAL_SCENE: PackedScene = preload("res://scenes/rpg/tactical_battle_scene.tscn")
## Textos de placeholder; los revisa narrative-writer.
const TITLE: String = "El Bosque te observa. Su Nujio exige Luz."
const TEXT_OFRENDA_MENU: String = "Ofrecer una ofrenda"
const TEXT_OFRENDA_PLUS_LUZ: String = " (+%d Luz)"
const TEXT_BACK: String = "Volver"
## Hueco que se abre para la primera línea extra del título (aprovecha el margen bajo el título) y
## para cada una de las siguientes (alto de línea del título): hostilidad, relación.
const EXTRA_LINE: float = 10.0
const NEXT_EXTRA_LINE: float = 15.0
## Opciones que caben en el panel sin crecer y alto de cada fila de más.
const BASE_OPTIONS: int = 4
const OPTION_ROW: float = 14.0
## Bioma del desempate del tamaño del tablero (TacticalArena) hasta que el mundo tenga biomas.
const ARENA_BIOME: StringName = &"bosque"
## Opciones del menú principal (las que se muestran están en _actions, en orden).
enum Option { PAY_LUZ, OFRENDA, FIGHT, RETREAT, IMPOSE }

var _bosque_id: int = -1
var _cost: int = 0
var _distance: int = 0
var _map: BosqueMap
var _battle: Node
## Misión del combate en curso (&"" = combate de borde).
var _quest_id: StringName = &""
## El combate en curso es directo contra un Único de dentro del Bosque.
var _chase: bool = false
## Ese combate ofende al Bosque (tenía el paso abierto).
var _offends: bool = false
var _home: int = -1
## Ropa de los adoc aliados del combate en curso, en orden (la escena los dibuja con ella).
var _ally_kinds: Array = []
## Submenú de ofrendas abierto: índices de AdventureRules.bag_ofrendas() de cada opción (sin la
## de volver).
var _ofrenda_choices: Array[int] = []
var _in_submenu: bool = false
## Opciones del menú principal que se muestran (Option), en orden.
var _actions: Array[int] = []
## Fuente inyectable del recorte del combate táctico: Callable() -> float con la proporción
## transitable (0..1) alrededor del encuentro, o < 0 si no la hay. Sin ella, el chunk actual.
var walkable_sampler: Callable
## Mundo 2.0 (los fija la escena del mundo activo): Callable(chunk_coord) -> WorldChunk y
## Callable() -> Vector2i con la world_cell del Adoc. Con los dos, el recorte sale de WorldQuery.rect.
var world_get_chunk: Callable
var world_player_cell: Callable
## Apertura del próximo combate (TacticalBattle.Opening; EventBus.battle_opening_set).
var _next_opening: int = TacticalBattle.Opening.NORMAL

@onready var _panel: Control = $Panel
@onready var _title: Label = $Panel/Title
@onready var _options: OptionMenu = $Panel/Options
var _options_top: float = 0.0
var _panel_top: float = 0.0


func _ready() -> void:
	_panel.visible = false
	_options_top = _options.offset_top
	_panel_top = _panel.offset_top
	EventBus.bosque_border_reached.connect(_on_bosque_border_reached)
	EventBus.quest_battle_requested.connect(_on_quest_battle_requested)
	EventBus.unico_battle_requested.connect(_on_unico_battle_requested)
	EventBus.group_battle_requested.connect(_on_group_battle_requested)
	EventBus.battle_opening_set.connect(_on_battle_opening_set)


func _on_battle_opening_set(opening: int) -> void:
	_next_opening = opening


## La apertura guardada para este combate (y vuelve a normal).
func take_opening() -> int:
	var out: int = _next_opening
	_next_opening = TacticalBattle.Opening.NORMAL
	return out


func _on_bosque_border_reached(bosque_id: int) -> void:
	if bosque_id < 0 or _panel.visible or _battle != null:
		return
	_ensure_map()
	var home: int = AdventureRules.current_home()
	# Un Bosque forzado se cruza, pero sus Botarramas siguen exigiendo el pago al alcanzarte. Con el
	# arma en la mano, tampoco uno pagado deja pasar en paz.
	if AdventureRules.is_welcome(bosque_id, home):
		return
	_home = home
	_bosque_id = bosque_id
	_next_opening = TacticalBattle.Opening.NORMAL
	_distance = maxi(1, _map.distance(home, bosque_id))
	_cost = AdventureRules.toll_for(bosque_id, _distance)
	_open_main_menu()
	_panel.visible = true
	get_tree().paused = true


func _open_main_menu() -> void:
	_in_submenu = false
	_title.text = title_for(_bosque_id, _home)
	var lines: int = _title.text.count("\n")
	var extra: float = 0.0 if lines == 0 else EXTRA_LINE + NEXT_EXTRA_LINE * (lines - 1)
	_options.offset_top = _options_top + extra
	_actions = actions_for(_bosque_id, _home)
	# El panel crece hacia arriba: abajo no cabe. Con más de BASE_OPTIONS opciones (Imponerte),
	# una fila más por cada una.
	_panel.offset_top = _panel_top - extra - OPTION_ROW * maxi(0, _actions.size() - BASE_OPTIONS)
	var texts: Array[String] = []
	var enabled: Array[bool] = []
	var has_ofrenda: bool = not Ofrendas.payable(AdventureRules.bag_ofrendas(), GameState.luz, _cost).is_empty()
	for action: int in _actions:
		match action:
			Option.PAY_LUZ:
				texts.append("Ofrecer %d Luz (tienes %d)" % [_cost, GameState.luz])
				enabled.append(GameState.luz >= _cost)
			Option.OFRENDA:
				texts.append(TEXT_OFRENDA_MENU)
				enabled.append(has_ofrenda)
			Option.FIGHT:
				texts.append("Enfrentar al Botarramas")
				enabled.append(true)
			Option.IMPOSE:
				texts.append(Texts.get_text("crossing_impose_option"))
				enabled.append(AdventureRules.can_impose(_bosque_id, _distance))
			Option.RETREAT:
				texts.append("Retroceder")
				enabled.append(true)
	_options.set_options(texts, enabled)


## Opciones del menú del borde del Bosque: pagar (Luz u ofrenda), enfrentar y retroceder; si no
## acepta pagos (enojado, o el Adoc lleva el arma en la mano), solo enfrentar y retroceder. Con la
## skill Imponerse, "Imponerte" tras enfrentar (desactivada si no se puede: nivel o Bosque enojado).
static func actions_for(bosque_id: int, home: int = -1) -> Array[int]:
	var out: Array[int] = [Option.PAY_LUZ, Option.OFRENDA, Option.FIGHT, Option.RETREAT]
	if not AdventureRules.can_pay_toll(bosque_id) or AdventureRules.is_armed_against(bosque_id, home):
		out = [Option.FIGHT, Option.RETREAT]
	if AdocGrowth.has_skill(AdocGrowth.IMPONERSE):
		out.insert(out.find(Option.FIGHT) + 1, Option.IMPOSE)
	return out


## Título del menú: el de siempre; si el Bosque recuerda Botarramas vencidos, su aviso; y si la
## relación multiplica el peaje, cuánto (con amistad alta, que el paso será permanente). Con el arma
## en la mano, el aviso del arma (manda sobre los demás: no hay peaje que ofrecer).
static func title_for(bosque_id: int, home: int = -1) -> String:
	var state: String = AdventureRules.bosque_state(bosque_id)
	if AdventureRules.is_armed_against(bosque_id, home):
		return "\n".join(PackedStringArray([Texts.get_text("crossing_armed_title"), Texts.get_text("crossing_armed_line")]))
	if not AdventureRules.can_pay_toll(bosque_id):
		var angry: PackedStringArray = [Texts.get_text("crossing_angry_title"), Texts.get_text("crossing_angry_line")]
		return "\n".join(angry)
	var lines: PackedStringArray = [TITLE]
	if state == BosqueStates.CORRUPTO:
		lines.append(Texts.get_text("crossing_corrupt_line") % format_factor(BosqueStates.toll_factor(state)))
	if AdventureRules.hostility(bosque_id) > 0:
		lines.append(Texts.get_text("crossing_bosque_remembers"))
	var relation_text: String = relation_line_for(bosque_id)
	if relation_text != "":
		lines.append(relation_text)
	return "\n".join(lines)


## Línea del multiplicador de la relación ("" si no cambia el peaje).
static func relation_line_for(bosque_id: int) -> String:
	var factor: float = AdventureRules.relation_toll_factor(bosque_id)
	if is_equal_approx(factor, 1.0):
		return ""
	var key: String = "crossing_relation_surcharge"
	if factor < 1.0:
		key = "crossing_relation_friend" if AdventureRules.relation(bosque_id) >= AdventureRules.permanent_at() else "crossing_relation_discount"
	return Texts.get_text(key) % format_factor(factor)


## Multiplicador en español: 0.75 -> "×0,75", 1.5 -> "×1,5".
static func format_factor(factor: float) -> String:
	return "×" + String.num(factor, 2).replace(".", ",")


## Una opción del submenú: "Ofrecer <ofrenda> (<valor>) por un paso de <N>", con la Luz suelta
## que la completa si no llega.
static func ofrenda_option(item: Dictionary, cost: int) -> String:
	var value: int = int(item.luz)
	var text: String = Texts.get_text("crossing_ofrenda_option") % [Ofrendas.display_name(StringName(str(item.id))), value, cost]
	var luz: int = Ofrendas.luz_needed(value, cost)
	if luz > 0:
		text += TEXT_OFRENDA_PLUS_LUZ % luz
	return text


func _open_submenu() -> void:
	_in_submenu = true
	var ofrendas: Array = AdventureRules.bag_ofrendas()
	_ofrenda_choices = Ofrendas.payable(ofrendas, GameState.luz, _cost)
	var texts: Array[String] = []
	var enabled: Array[bool] = []
	for i: int in _ofrenda_choices:
		texts.append(ofrenda_option(ofrendas[i], _cost))
		enabled.append(true)
	texts.append(TEXT_BACK)
	enabled.append(true)
	_options.set_options(texts, enabled)


## El reparto en Bosques de la partida: el del RegionPlan del Mundo 2.0 o, en el mundo viejo, el
## de seed + región (MapLogic.current_bosques, en caché mientras no cambien).
func _ensure_map() -> void:
	_map = MapLogic.current_bosques()


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	get_viewport().set_input_as_handled()
	var choice: int = _options.handle(event)
	# En el menú principal, el índice de la opción pasa a su Option (el enojado no muestra pagos).
	if not _in_submenu and choice >= 0 and choice < _actions.size():
		choice = _actions[choice]
	if _in_submenu:
		if choice == OptionMenu.CANCEL or choice == _ofrenda_choices.size():
			_open_main_menu()
		elif choice >= 0 and AdventureRules.pay_toll_with_ofrenda(_bosque_id, _cost, _ofrenda_choices[choice]):
			_close(&"paid")
		return
	match choice:
		Option.PAY_LUZ:
			if AdventureRules.pay_toll(_bosque_id, _cost):
				_close(&"paid")
		Option.OFRENDA:
			_open_submenu()
		Option.FIGHT:
			_start_battle()
		Option.IMPOSE:
			if AdventureRules.impose(_bosque_id, _distance):
				EventBus.notice_requested.emit(Texts.get_text("crossing_imposed"))
				_close(&"won")
		Option.RETREAT, OptionMenu.CANCEL:
			_close(&"retreated")


func _start_battle() -> void:
	_panel.visible = false
	_quest_id = &""
	_chase = false
	var logic: BattleLogic = AdventureRules.start_battle(_bosque_id, _distance)
	_open_battle(logic, _map.styles[_bosque_id], UnicoArt.Kind.BOTARRAMAS)


## Combate de misión contra el Ofomni descarriado, con la d fijada al aparecer y los colores de su Bosque.
func _on_quest_battle_requested(quest_id: StringName) -> void:
	if _panel.visible or _battle != null or not GameState.quests.has(quest_id):
		return
	var q: Dictionary = GameState.quests[quest_id]
	_ensure_map()
	_quest_id = quest_id
	_chase = false
	get_tree().paused = true
	var logic: BattleLogic = AdventureRules.start_quest_battle(quest_id, int(q.ofomni_d))
	_open_battle(logic, _map.styles[maxi(0, int(q.ofomni_bosque))], UnicoArt.Kind.EYES, take_opening())


## Combate directo contra un Único `monster_id` del Bosque `bosque_id`: a la d del Bosque (como
## mínimo 1) y con su peaje como precio para apaciguarlo.
func _on_unico_battle_requested(bosque_id: int, monster_id: StringName, offends: bool) -> void:
	_on_group_battle_requested(bosque_id, monster_id, 1, offends, "")


## Combate directo contra un grupo (`count` monstruos `monster_id`, los reparep) y, con
## `encounter_id`, con el adoc de ese encuentro como aliado (AdocEncounters). Los Únicos del Bosque
## que necesita ayuda se suman solos (AdventureRules.bosque_allies).
func _on_group_battle_requested(bosque_id: int, monster_id: StringName, count: int, offends: bool, encounter_id: String) -> void:
	if bosque_id < 0 or _panel.visible or _battle != null:
		return
	_ensure_map()
	_home = AdventureRules.current_home()
	_bosque_id = bosque_id
	_distance = maxi(1, _map.distance(_home, bosque_id))
	_quest_id = &""
	_chase = true
	_offends = offends
	get_tree().paused = true
	var allies: Array[Dictionary] = []
	_ally_kinds = []
	if encounter_id != "":
		var e: Dictionary = AdocEncounters.encounter_of(_map, GameState.seed_value, bosque_id)
		if not e.is_empty() and str(e.id) == encounter_id:
			allies.append(AdocEncounters.ally_of(e))
			_ally_kinds.append(e.get("clothes", {}))
	var opening: int = take_opening() if encounter_id == "" else TacticalBattle.Opening.NORMAL
	_next_opening = TacticalBattle.Opening.NORMAL
	var logic: BattleLogic = AdventureRules.start_battle(bosque_id, _distance, monster_id, count, allies)
	_open_battle(logic, _map.styles[bosque_id], UnicoArt.kind_for(monster_id), opening)


func _open_battle(logic: BattleLogic, style: Dictionary, kind: UnicoArt.Kind,
		opening: int = TacticalBattle.Opening.NORMAL) -> void:
	var balance_data: Dictionary = AdventureRules.balance()
	_battle = battle_scene(balance_data).instantiate()
	add_child(_battle)
	_battle.finished.connect(_on_battle_finished)
	if TacticalBridge.is_enabled(balance_data):
		var arena: Dictionary = encounter_arena(logic.balance)
		_battle.begin(logic, style, kind, _ally_kinds, arena.cfg, arena.board,
			opening == TacticalBattle.Opening.AMBUSH, opening == TacticalBattle.Opening.SURPRISE)
	else:
		_battle.begin(logic, style, kind, _ally_kinds)
	_ally_kinds = []


## Bloque tactical y tablero del combate táctico: { cfg, board }. En el Mundo 2.0 (el mundo activo da
## `world_get_chunk` y `world_player_cell`, y no hay `walkable_sampler` inyectado), el tablero sale
## del relieve real alrededor del Adoc (TacticalRelief, T7a); si no, board = null (llano) y el tamaño
## sale de encounter_ratio.
func encounter_arena(balance_data: Dictionary) -> Dictionary:
	if not walkable_sampler.is_valid() and world_get_chunk.is_valid() and world_player_cell.is_valid():
		var relief: Dictionary = TacticalRelief.arena_config(balance_data, world_get_chunk,
			world_player_cell.call(), ARENA_BIOME)
		return { "cfg": relief.cfg, "board": relief.board }
	return { "cfg": TacticalBridge.arena_config(balance_data, encounter_ratio(), ARENA_BIOME), "board": null }


## Proporción transitable del recorte del combate táctico alrededor del Adoc (TacticalArena), o -1
## si no se puede leer (el tamaño lo decide entonces el bioma).
func encounter_ratio() -> float:
	if walkable_sampler.is_valid():
		return float(walkable_sampler.call())
	if world_get_chunk.is_valid() and world_player_cell.is_valid():
		var cfg: Dictionary = TacticalArena.arena_cfg(AdventureRules.balance().get("tactical", {}))
		return TacticalArena.world_ratio(world_get_chunk, world_player_cell.call(), TacticalArena.sample_size(cfg))
	if GameState.chunk_coord.x < 0 or GameState.chunk_coord.y < 0:
		return -1.0
	var region: Dictionary = ChunkGenerator.load_region(GameState.region_id)
	_ensure_map()
	var chunk: ChunkData = ChunkGenerator.generate(GameState.seed_value, GameState.chunk_coord, region, _map)
	return chunk_ratio(chunk, GameState.player_cell)


## Proporción transitable del recorte de 14 x 10 (tactical.arena.sample) de un chunk alrededor de
## `cell` (desplazado para quedar dentro del chunk).
static func chunk_ratio(chunk: ChunkData, cell: Vector2i) -> float:
	var cfg: Dictionary = TacticalArena.arena_cfg(AdventureRules.balance().get("tactical", {}))
	return TacticalArena.sample_ratio(chunk.is_walkable, cell, TacticalArena.sample_size(cfg),
		Rect2i(0, 0, ChunkData.SIZE, ChunkData.SIZE))


## Escena de combate según el interruptor tactical.enabled de balance.json.
static func battle_scene(balance_data: Dictionary) -> PackedScene:
	return TACTICAL_SCENE if TacticalBridge.is_enabled(balance_data) else BATTLE_SCENE


func _on_battle_finished(logic: BattleLogic) -> void:
	_battle.queue_free()
	_battle = null
	if _quest_id != &"":
		var quest_outcome: StringName = AdventureRules.finish_quest_battle(logic, _quest_id)
		get_tree().paused = false
		EventBus.quest_battle_resolved.emit(_quest_id, quest_outcome)
		_quest_id = &""
		return
	if _chase:
		_chase = false
		var chase_outcome: StringName = AdventureRules.finish_unico_battle(logic, _bosque_id, _home, _offends)
		get_tree().paused = false
		EventBus.unico_battle_resolved.emit(_bosque_id, chase_outcome)
		return
	var outcome: StringName = AdventureRules.finish_battle(logic, _bosque_id)
	# Apaciguar en combate (Luz u ofrenda) paga el paso (ADR 0010); vencer solo lo fuerza.
	var resolved: StringName = { &"victory": &"won", &"appeased": &"paid", &"defeat": &"defeated", &"game_over": &"game_over" }.get(outcome, &"fled")
	_close(resolved)


func _close(outcome: StringName) -> void:
	_panel.visible = false
	get_tree().paused = false
	EventBus.crossing_resolved.emit(_bosque_id, outcome)
