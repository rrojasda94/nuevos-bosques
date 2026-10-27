extends Node
## Demo del combate táctico para probarlo desde el editor (F6 sobre la escena; combate-tactico.md,
## PR T4). No toca GameState: monta un BattleLogic de prueba (el Adoc con aliados adoc contra
## reparep) y abre TacticalBattleScene con un tablero con alturas, agua, vado, escalera y
## obstáculos. Al acabar, vuelve a empezar.
## - tactical_demo.tscn: 3 contra 3 en 8 × 6 (los aliados con rol de apoyo y de defensor).
## - tactical_demo_big.tscn (`big`): 6 contra 6 en 14 × 10, para probar el desplazamiento de la
##   cámara y la línea de orden larga.
## - tactical_demo_relief.tscn (`relief`, T7a): genera chunks del Mundo 2.0 con `world_seed`
##   (RegionPlan + ChunkBuilder, sin escena ni caché) y abre el combate sobre el relieve real
##   junto a la escalera o rampa del chunk `world_chunk` más cercana a su hub (TacticalRelief.arena_config: tamaño, recorte, riscos
##   comprimidos y cupo). Cada bando lleva el cupo. Desde la línea de órdenes (tras `--`):
##   --seed=N, --chunk=X,Y y --capture=ruta.png (guarda una captura tras unos fotogramas y sale).
## Solo para desarrollo: los combates del juego los abre Crossing.

const SCENE: PackedScene = preload("res://scenes/rpg/tactical_battle_scene.tscn")
const STYLE: Dictionary = { "shape": 0, "leaf": 0, "trunk": 0, "ground": 0 }
const ROLES: Array[String] = ["support", "defender", "attacker", "", "support"]
const CLOTHES: Array[Dictionary] = [
	{ "light": "0099db", "dark": "124e89" }, { "light": "feae34", "dark": "f77622" },
	{ "light": "b55088", "dark": "68386c" }, { "light": "c0cbdc", "dark": "8b9bb4" },
	{ "light": "63c74d", "dark": "3e8948" },
]
## Fotogramas antes de la captura de --capture.
const CAPTURE_FRAMES: int = 40

## 6 contra 6 en 14 × 10 en vez de 3 contra 3 en 8 × 6.
@export var big: bool = false
@export var rng_seed: int = 7
## Tablero desde el relieve del Mundo 2.0 (T7a).
@export var relief: bool = false
@export var world_seed: int = 42
@export var world_region: StringName = &"valle_del_sara"
@export var world_chunk: Vector2i = Vector2i(5, 1)

var scene: TacticalBattleScene
var _plan: RegionPlan
var _chunks: Dictionary = {}
var _capture: String = ""
var _frames: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			world_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--chunk="):
			var xy: PackedStringArray = arg.get_slice("=", 1).split(",")
			world_chunk = Vector2i(int(xy[0]), int(xy[1]))
		elif arg.begins_with("--capture="):
			_capture = arg.get_slice("=", 1)
	start()


func _process(_delta: float) -> void:
	if _capture == "":
		return
	_frames += 1
	if _frames == CAPTURE_FRAMES:
		get_viewport().get_texture().get_image().save_png(_capture)
		get_tree().quit()


## Chunk del Mundo 2.0 de la demo con relieve (se construye la primera vez que se pide).
func get_chunk(coord: Vector2i) -> WorldChunk:
	if _plan == null:
		_plan = RegionPlan.for_region(world_seed, world_region)
	if coord.x < 0 or coord.y < 0 or coord.x >= _plan.size_chunks.x or coord.y >= _plan.size_chunks.y:
		return null
	if not _chunks.has(coord):
		_chunks[coord] = ChunkBuilder.build(_plan, coord)
	return _chunks[coord]


func start() -> void:
	var balance: Dictionary = AdventureRules.balance()
	var per_side: int = 6 if big else 3
	var arena: Dictionary = {}
	if relief:
		var encounter: Vector2i = world_chunk * WorldCoords.CHUNK + relief_cell(get_chunk(world_chunk))
		arena = TacticalRelief.arena_config(balance, get_chunk, encounter, &"bosque")
		per_side = clampi(int((arena.cfg.board as Dictionary).max_per_side), 1, 6)
		print("Demo con relieve: seed %d, chunk %s, encuentro %s, modo %s, recorte %s, proporción %.2f, desnivel %d, cupo %d" % [
			world_seed, world_chunk, encounter, arena.mode, arena.rect, arena.ratio, arena.span, per_side])
	var monster: Dictionary = AdventureRules.make_monster(&"reparep", 2)
	var base_name: String = AdventureRules.monster_name(&"reparep")
	var adoc: Dictionary = { "max_hp": 22, "atk": 6, "def": 3, "agi": 6 }
	var first: Dictionary = monster.duplicate(true)
	first.name = "%s 1" % base_name
	var logic := BattleLogic.new(balance, adoc, 22, 6, first, rng_seed)
	for k: int in range(1, per_side):
		var e: Dictionary = monster.duplicate(true)
		e.name = "%s %d" % [base_name, k + 1]
		logic.add_enemy(e)
	var adoc_name: String = Texts.get_text("tactical_adoc_name")
	for k: int in per_side - 1:
		logic.add_ally({ "name": "%s %d" % [adoc_name, k + 2], "max_hp": 16, "atk": 5, "def": 2,
			"kind": "adoc", "agi": 5 + k % 3, "role": ROLES[k % ROLES.size()] })
	logic.toll = 3
	logic.victory_xp = 12
	var cfg: Dictionary = TacticalBattle.config_from_balance(balance)
	var board: TacticalBoard
	if relief:
		cfg = arena.cfg
		board = arena.board
	elif big:
		cfg.board = { "width": 14, "height": 10, "deploy_columns": 2, "max_per_side": 6, "ford_cost": 1 }
		board = big_board(cfg.board)
	else:
		board = small_board(cfg.board)
	scene = SCENE.instantiate()
	add_child(scene)
	scene.finished.connect(_on_finished)
	scene.begin(logic, STYLE, UnicoArt.Kind.REPAREP, CLOTHES, cfg, board)


## Casilla del encuentro de la demo con relieve: la transitable junto a una escalera o rampa más
## cercana al hub (para que se vea un desnivel); si el chunk no tiene, el hub.
static func relief_cell(chunk: WorldChunk) -> Vector2i:
	var best: Vector2i = chunk.hub
	var best_d: int = -1
	for y: int in WorldChunk.SIZE:
		for x: int in WorldChunk.SIZE:
			var c := Vector2i(x, y)
			var cl: int = chunk.get_cliff(c)
			if cl != WorldChunk.Cliff.STAIRS and cl != WorldChunk.Cliff.RAMP:
				continue
			for dir: Vector2i in TacticalBoard.NEIGHBOR_DIRS:
				var n: Vector2i = c + dir
				if not WorldChunk.in_bounds(n) or chunk.is_blocked(n) or chunk.get_cliff(n) != WorldChunk.Cliff.NONE:
					continue
				var d: int = absi(n.x - chunk.hub.x) + absi(n.y - chunk.hub.y)
				if best_d < 0 or d < best_d:
					best = n
					best_d = d
	return best


## 8 × 6: un altozano de niveles 1 y 2 con escalera, un arroyo con vado, un árbol y una roca.
static func small_board(board_cfg: Dictionary) -> TacticalBoard:
	var b := TacticalBoard.from_config(board_cfg)
	for x: int in range(2, 6):
		b.set_cell(Vector2i(x, 4), 1)
		b.set_cell(Vector2i(x, 5), 1)
	b.set_cell(Vector2i(3, 5), 2)
	b.set_cell(Vector2i(4, 5), 2)
	b.set_cell(Vector2i(2, 3), 0, false, true)
	b.set_cell(Vector2i(4, 0), 0, false, false, true)
	b.set_cell(Vector2i(4, 1), 0, false, false, true, true)
	b.set_cell(Vector2i(5, 2), 0, false, false, false, false, &"tree")
	b.set_cell(Vector2i(2, 1), 0, false, false, false, false, &"rock")
	return b


## 14 × 10: un río de norte a sur con dos vados, una colina de niveles 1 a 3 con escalera y
## árboles y rocas sueltos.
static func big_board(board_cfg: Dictionary) -> TacticalBoard:
	var b := TacticalBoard.from_config(board_cfg)
	for y: int in 10:
		b.set_cell(Vector2i(9, y), 0, false, false, true, y == 2 or y == 7)
	for y: int in range(3, 8):
		for x: int in range(4, 8):
			var level: int = 1
			if y >= 4 and y <= 6 and x >= 5 and x <= 6:
				level = 2
			if y == 5 and x == 5:
				level = 3
			b.set_cell(Vector2i(x, y), level)
	b.set_cell(Vector2i(4, 5), 1, false, true)
	b.set_cell(Vector2i(6, 5), 2, false, true)
	for c: Vector2i in [Vector2i(3, 1), Vector2i(10, 8), Vector2i(6, 0), Vector2i(11, 4)]:
		b.set_cell(c, 0, false, false, false, false, &"tree")
	for c: Vector2i in [Vector2i(2, 8), Vector2i(8, 1)]:
		b.set_cell(c, 0, false, false, false, false, &"rock")
	return b


func _on_finished(_logic: BattleLogic) -> void:
	scene.queue_free()
	start()
