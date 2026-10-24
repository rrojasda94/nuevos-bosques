class_name Npc
extends Node2D
## Personaje no jugador en exploración: una casilla que bloquea el paso, un sprite de 16x16 (la
## hoja SFIDA_SHEET de 2 fotogramas de reposo o, si falta, el placeholder procedural de
## make_texture) y un id de datos (data/npcs/<id>.json). Lo que
## dice lo decide NpcDialogue. También calcula dónde espera el sfida en la villa natal.

const TILE_SIZE: int = 16
## Casillas al este de la casilla de aparición (al sur del Nujio) donde se busca sitio al sfida.
const SFIDA_OFFSET: Vector2i = Vector2i(3, 0)
## Colores de placeholder del sfida (paleta del proyecto): túnica larga violeta con cinta dorada
## y pelo gris de anciano.
const SFIDA_COLORS: Dictionary = {
	"robe": Color("68386c"),
	"trim": Color("feae34"),
	"hair": Color("8b9bb4"),
	"skin": Color("e8b796"),
}

## Hoja del sfida (docs/art/specs/primera-pasada.md): 2 fotogramas de reposo, mirando abajo.
const SFIDA_SHEET: String = "res://assets/sprites/sprite_sfida_idle.png"
const SHEET_FRAMES: int = 2
## Segundos de cada fotograma de reposo.
const IDLE_FRAME_TIME: float = 0.8

var npc_id: StringName = &""
var cell: Vector2i = Vector2i.ZERO


func setup(id: StringName, at: Vector2i, facing: Vector2i = Vector2i.DOWN) -> void:
	npc_id = id
	cell = at
	position = PlayerWalker.cell_to_position(at)
	var sprite := Sprite2D.new()
	add_child(sprite)
	if not ResourceLoader.exists(SFIDA_SHEET):
		sprite.texture = make_texture(SFIDA_COLORS, facing)
		return
	sprite.texture = load(SFIDA_SHEET)
	sprite.hframes = SHEET_FRAMES
	var timer := Timer.new()
	timer.wait_time = IDLE_FRAME_TIME
	timer.autostart = true
	timer.timeout.connect(func() -> void: sprite.frame = (sprite.frame + 1) % SHEET_FRAMES)
	add_child(timer)


## Casilla de aparición del Adoc en su villa: justo al sur del Nujio.
static func villa_spawn_cell(chunk: ChunkData) -> Vector2i:
	var rect: Rect2i = chunk.nujio_rect
	return Vector2i(rect.position.x + rect.size.x / 2, rect.end.y)


## Sitio determinista del sfida en la villa: la casilla de PLAZA más cercana a la de aparición
## + SFIDA_OFFSET (empates por fila y columna) que no sea el hub ni la de aparición, a la que se
## llegue desde el hub y con sus 8 vecinas transitables, para que bloquearla nunca corte el paso.
## (-1, -1) si el chunk no tiene villa.
static func sfida_cell(chunk: ChunkData) -> Vector2i:
	if not chunk.has_villa or chunk.nujio_rect.size.x == 0:
		return Vector2i(-1, -1)
	var spawn: Vector2i = villa_spawn_cell(chunk)
	var target: Vector2i = spawn + SFIDA_OFFSET
	var best := Vector2i(-1, -1)
	var best_score: int = 1 << 30
	for y: int in ChunkData.SIZE:
		for x: int in ChunkData.SIZE:
			var c := Vector2i(x, y)
			if chunk.get_tile(c) != ChunkData.Tile.PLAZA or c == chunk.hub or c == spawn:
				continue
			var score: int = (absi(c.x - target.x) + absi(c.y - target.y)) * ChunkData.SIZE * ChunkData.SIZE \
				+ y * ChunkData.SIZE + x
			if score >= best_score or not chunk.is_reachable(c) or not _is_open_around(chunk, c):
				continue
			best = c
			best_score = score
	return best


static func _is_open_around(chunk: ChunkData, c: Vector2i) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if not chunk.is_walkable(c + Vector2i(dx, dy)):
				return false
	return true


## Sprite de placeholder 16x16: túnica hasta los pies con cinta, cabeza y pelo.
static func make_texture(colors: Dictionary, dir: Vector2i) -> Texture2D:
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var skin: Color = colors.skin
	var hair: Color = colors.hair
	var robe: Color = colors.robe
	var trim: Color = colors.trim
	var outline := Color("181425")
	img.fill_rect(Rect2i(5, 2, 6, 6), skin)
	img.fill_rect(Rect2i(5, 1, 6, 2), hair)
	if dir == Vector2i.UP:
		img.fill_rect(Rect2i(5, 1, 6, 7), hair)
	img.fill_rect(Rect2i(4, 8, 8, 7), robe)
	img.fill_rect(Rect2i(3, 13, 10, 2), robe)
	img.fill_rect(Rect2i(7, 8, 2, 7), trim)
	if dir == Vector2i.DOWN:
		img.set_pixel(6, 5, outline)
		img.set_pixel(9, 5, outline)
	PlayerWalker.add_outline(img, outline)
	return ImageTexture.create_from_image(img)
