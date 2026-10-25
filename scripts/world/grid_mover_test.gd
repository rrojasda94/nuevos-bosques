extends Node2D
## Escena de prueba del movimiento libre (M11, ADR 0014 §2): rejilla con paredes, pasillo de 2
## casillas, esquinas y diagonales cerradas. Dibuja la caja de los pies y la casilla actual.
## Arranque: godot --path . res://scenes/world/grid_mover_test.tscn
## Captura: añadir `-- --capture=<ruta.png>` guarda la imagen ×3 tras unos fotogramas y sale.

const MAP: Array[String] = [
	"##############################",
	"#............................#",
	"#............................#",
	"#....######..######..........#",
	"#....######..######....#.....#",
	"#....######..######.....#....#",
	"#....######..######..........#",
	"#............................#",
	"#..........#.................#",
	"#...........#........#####...#",
	"#....................#...#...#",
	"#....................#.......#",
	"#....................#####...#",
	"#............................#",
	"##############################",
]
const START_CELL := Vector2i(9, 7)
const COLOR_FLOOR := Color("3e8948")
const COLOR_FLOOR_ALT := Color("265c42")
const COLOR_WALL := Color("5a6988")
const COLOR_WALL_TOP := Color("8b9bb4")
const COLOR_CELL := Color(1, 1, 1, 0.25)
const COLOR_BOX := Color("feae34")
const CAPTURE_FRAMES: int = 20
const CAPTURE_SCALE: int = 3

@onready var _player: PlayerController = $Player
@onready var _label: Label = $Hud/Label


func _ready() -> void:
	_player.is_blocked = is_blocked
	_player.place_at_cell(START_CELL)
	_player.cell_changed.connect(func(_c: Vector2i) -> void: queue_redraw())
	var capture_path: String = _capture_arg()
	if not capture_path.is_empty():
		_capture(capture_path)


func is_blocked(c: Vector2i) -> bool:
	if c.y < 0 or c.y >= MAP.size() or c.x < 0 or c.x >= MAP[c.y].length():
		return true
	return MAP[c.y][c.x] == "#"


func _physics_process(_delta: float) -> void:
	_label.text = "casilla %s  mira %s\nflechas/WASD, Shift corre" % [
		_player.mover.cell, _player.mover.facing]
	queue_redraw()


func _draw() -> void:
	var tile: int = GridMover.TILE
	for y: int in MAP.size():
		for x: int in MAP[y].length():
			var rect := Rect2(x * tile, y * tile, tile, tile)
			if MAP[y][x] == "#":
				draw_rect(rect, COLOR_WALL)
				draw_rect(Rect2(rect.position, Vector2(tile, 3)), COLOR_WALL_TOP)
			else:
				draw_rect(rect, COLOR_FLOOR if (x + y) % 2 == 0 else COLOR_FLOOR_ALT)
	var cell: Vector2i = _player.mover.cell
	draw_rect(Rect2(cell * tile, Vector2(tile, tile)), COLOR_CELL, false, 1.0)
	var box: Rect2 = _player.mover.get_rect()
	box.position = box.position.round()
	draw_rect(box, COLOR_BOX, false, 1.0)


func _capture_arg() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			return arg.trim_prefix("--capture=")
	return ""


func _capture(path: String) -> void:
	for _i: int in CAPTURE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.resize(img.get_width() * CAPTURE_SCALE, img.get_height() * CAPTURE_SCALE,
		Image.INTERPOLATE_NEAREST)
	var err: Error = img.save_png(path)
	print("captura %s: %s" % [path, error_string(err)])
	get_tree().quit()
