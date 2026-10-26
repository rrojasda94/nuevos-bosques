extends Node
## Captura del mapa M con la vista de la región (M16) para revisar la UI sin jugar. Con ventana
## (la UI no se prueba en headless):
##   godot --path . --resolution 960x540 res://tools/ui/capture_region_map.tscn -- [seed] [salida.png]
## (es una escena y no un `-s`: con `-s` los autoloads aún no existen al compilar.)
## Crea la partida de la seed en valle_del_sara, registra su RegionPlan, explora los chunks de
## alrededor de la villa natal y un pasillo hasta Azhin, pone un objetivo y abre el mapa. Guarda la
## pantalla de 320×180 escalada ×3 (vecino más próximo).

const REGION: StringName = &"valle_del_sara"
const SCALE: int = 3


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seed_value: int = args[0].to_int() if args.size() > 0 else 7
	var out_path: String = args[1] if args.size() > 1 else ProjectSettings.globalize_path("res://build/m16_mapa.png")
	var game_state: Node = GameState
	game_state.new_game(seed_value, REGION)
	var plan := RegionPlan.for_region(seed_value, REGION)
	MapLogic.set_region_plan(plan)
	print("Seed %d: %d villas y aldeas (%d aldeas), %d refugios." % [seed_value, plan.villas().size(), plan.aldeas().size(), plan.refuge_chunks().size()])
	var home: Vector2i = plan.home_chunk
	var explored: Array[Vector2i] = game_state.explored_chunks
	for y: int in range(home.y - 3, home.y + 3):
		for x: int in range(home.x - 3, home.x + 4):
			MapLogic.mark_explored(explored, Vector2i(x, y))
	for y: int in range(0, home.y):
		MapLogic.mark_explored(explored, Vector2i(home.x, y))
		MapLogic.mark_explored(explored, Vector2i(home.x - 1, y))
	for x: int in range(0, home.x):
		MapLogic.mark_explored(explored, Vector2i(x, 0))
		MapLogic.mark_explored(explored, Vector2i(x, 1))
	game_state.chunk_coord = home + Vector2i(0, -5)
	game_state.player_cell = Vector2i(40, 40)
	game_state.set_objective(home + Vector2i(-1, -9), "Ofomni", Vector2i(-1, -1))
	var map: Node = (load("res://scenes/ui/region_map.tscn") as PackedScene).instantiate()
	add_child(map)
	await get_tree().process_frame
	map.open()
	for i: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	print("Pantalla: %d×%d" % [img.get_width(), img.get_height()])
	if img.get_size() != Vector2i(320, 180):
		img.resize(320, 180, Image.INTERPOLATE_NEAREST)
	img.resize(320 * SCALE, 180 * SCALE, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var err: int = img.save_png(out_path)
	print("Captura: %s (%d)" % [out_path, err])
	get_tree().quit(0 if err == OK else 1)
