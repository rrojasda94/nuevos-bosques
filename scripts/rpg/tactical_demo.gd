extends Node
## Demo del combate táctico para probarlo desde el editor (F6 sobre la escena; combate-tactico.md,
## PR T4). No toca GameState: monta un BattleLogic de prueba (el Adoc con aliados adoc contra
## reparep) y abre TacticalBattleScene con un tablero con alturas, agua, vado, escalera y
## obstáculos. Al acabar, vuelve a empezar.
## - tactical_demo.tscn: 3 contra 3 en 8 × 6 (los aliados con rol de apoyo y de defensor).
## - tactical_demo_big.tscn (`big`): 6 contra 6 en 14 × 10, para probar el desplazamiento de la
##   cámara y la línea de orden larga.
## Solo para desarrollo: los combates del juego los abre Crossing.

const SCENE: PackedScene = preload("res://scenes/rpg/tactical_battle_scene.tscn")
const STYLE: Dictionary = { "shape": 0, "leaf": 0, "trunk": 0, "ground": 0 }
const ROLES: Array[String] = ["support", "defender", "attacker", "", "support"]
const CLOTHES: Array[Dictionary] = [
	{ "light": "0099db", "dark": "124e89" }, { "light": "feae34", "dark": "f77622" },
	{ "light": "b55088", "dark": "68386c" }, { "light": "c0cbdc", "dark": "8b9bb4" },
	{ "light": "63c74d", "dark": "3e8948" },
]

## 6 contra 6 en 14 × 10 en vez de 3 contra 3 en 8 × 6.
@export var big: bool = false
@export var rng_seed: int = 7

var scene: TacticalBattleScene


func _ready() -> void:
	start()


func start() -> void:
	var balance: Dictionary = AdventureRules.balance()
	var per_side: int = 6 if big else 3
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
	if big:
		cfg.board = { "width": 14, "height": 10, "deploy_columns": 2, "max_per_side": 6, "ford_cost": 1 }
		board = big_board(cfg.board)
	else:
		board = small_board(cfg.board)
	scene = SCENE.instantiate()
	add_child(scene)
	scene.finished.connect(_on_finished)
	scene.begin(logic, STYLE, UnicoArt.Kind.REPAREP, CLOTHES, cfg, board)


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
