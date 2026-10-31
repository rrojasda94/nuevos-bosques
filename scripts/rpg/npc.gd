class_name Npc
extends Node2D
## Personaje no jugador en exploración: una casilla que bloquea el paso, un sprite de 16x16 (la
## hoja SFIDA_SHEET de 2 fotogramas de reposo o, si falta, el placeholder procedural de
## make_texture) y un id de datos (data/npcs/<id>.json). Lo que
## dice lo decide NpcDialogue. También calcula dónde espera el sfida en la villa natal y, desde
## P5 (trueque, ajustes-playtest-0.5.md 5b), dónde esperan el Sarua y el Paruas, junto a él.
## Los NPC sin hoja de sprite usan el placeholder de make_texture con los colores y el objeto en la
## mano ("placeholder" de su JSON en data/npcs/).

const TILE_SIZE: int = 16
## Casillas al este de la casilla de aparición (al sur del Nujio) donde se busca sitio al sfida.
const SFIDA_OFFSET: Vector2i = Vector2i(3, 0)
## P5: casillas (desde la de aparición) donde se busca sitio al Sarua y al Paruas, a los lados del
## sfida. Se colocan en este orden, después del sfida.
const ARTISAN_OFFSETS: Dictionary = {
	&"sarua_natal": Vector2i(6, 0),
	&"paruas_natal": Vector2i(3, 3),
}
## Distancia mínima (Chebyshev) entre dos NPC de la plaza: entre ellos queda al menos una casilla
## libre para pasar y hablarles.
const NPC_SPACING: int = 2
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
## Mundo 2.0: pies del NPC en píxeles globales (el origen del nodo, para el orden en Y) y su
## casilla global, que bloquea el paso. Los pone setup_world().
var world_pos: Vector2 = Vector2.ZERO
var world_cell: Vector2i = Vector2i.ZERO


## Mundo 2.0 (ADR 0014 §7): el NPC con los pies en el centro de la casilla global `at`. El nodo
## está en los pies (va en el nodo de objetos con orden en Y) y el sprite de 16×16 queda encima.
## Se habla con él con Interaction.find_world (npcs: npc_id -> world_pos).
func setup_world(id: StringName, at: Vector2i, facing: Vector2i = Vector2i.DOWN) -> void:
	npc_id = id
	world_cell = at
	world_pos = WorldCoords.world_cell_to_world_pos(at)
	position = world_pos
	_add_sprite(facing, Vector2(0, -TILE_SIZE * 0.5))


func _add_sprite(facing: Vector2i, offset: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.position = offset
	add_child(sprite)
	var placeholder: Dictionary = placeholder_of(npc_id)
	if not placeholder.is_empty():
		sprite.texture = make_texture(placeholder.colors, facing, placeholder.prop)
		return
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


# --- Mundo 2.0 (WorldChunk) ---------------------------------------------------------------------

## Casilla (del chunk) donde aparece el Adoc en su villa: la de AdventureRules.respawn_cell_world
## (transitable junto al Nujio, lo más al sur de su centro).
static func villa_spawn_cell_world(chunk: WorldChunk) -> Vector2i:
	return AdventureRules.respawn_cell_world(chunk)


## Como sfida_cell, con un WorldChunk: casilla de suelo PLAZA más cercana a la de aparición +
## SFIDA_OFFSET (empates por fila y columna) que no sea el hub ni la de aparición, alcanzable desde
## el hub y con sus 8 vecinas transitables y sin objetos. (-1, -1) si el chunk no tiene villa.
static func sfida_cell_world(chunk: WorldChunk) -> Vector2i:
	return plaza_cell_world(chunk, SFIDA_OFFSET)


## P5: casillas del Sarua y del Paruas en la plaza de la villa { id: casilla del chunk }, con las
## mismas condiciones que la del sfida, cada una lo más cerca posible de la de aparición +
## ARTISAN_OFFSETS[id] y a NPC_SPACING o más del sfida y del otro artesano. Sin villa o sin sitio,
## el NPC no sale en el diccionario.
static func artisan_cells_world(chunk: WorldChunk) -> Dictionary:
	var out: Dictionary = {}
	var sfida: Vector2i = sfida_cell_world(chunk)
	if sfida.x < 0:
		return out
	var taken: Array[Vector2i] = [sfida]
	for id: StringName in ARTISAN_OFFSETS:
		var at: Vector2i = plaza_cell_world(chunk, ARTISAN_OFFSETS[id], taken)
		if at.x >= 0:
			out[id] = at
			taken.append(at)
	return out


## Casilla de suelo PLAZA más cercana a la de aparición + `offset` (empates por fila y columna) que
## no sea el hub ni la de aparición, alcanzable desde el hub, con sus 8 vecinas transitables y sin
## objetos, y a NPC_SPACING o más (Chebyshev) de las casillas `taken`. (-1, -1) si no hay.
static func plaza_cell_world(chunk: WorldChunk, offset: Vector2i, taken: Array[Vector2i] = []) -> Vector2i:
	if not chunk.has_villa or chunk.nujio_rect.size.x == 0:
		return Vector2i(-1, -1)
	var spawn: Vector2i = villa_spawn_cell_world(chunk)
	var target: Vector2i = spawn + offset
	var best := Vector2i(-1, -1)
	var best_score: int = 1 << 30
	for y: int in WorldChunk.SIZE:
		for x: int in WorldChunk.SIZE:
			var c := Vector2i(x, y)
			if chunk.get_ground(c) != WorldChunk.Ground.PLAZA or c == chunk.hub or c == spawn:
				continue
			var score: int = (absi(c.x - target.x) + absi(c.y - target.y)) * WorldChunk.CELLS \
				+ y * WorldChunk.SIZE + x
			if score >= best_score or not chunk.is_reachable(c) or not _is_open_around_world(chunk, c) 					or _too_close(c, taken):
				continue
			best = c
			best_score = score
	return best


static func _too_close(c: Vector2i, taken: Array[Vector2i]) -> bool:
	for t: Vector2i in taken:
		if maxi(absi(c.x - t.x), absi(c.y - t.y)) < NPC_SPACING:
			return true
	return false


## Colores y objeto en la mano del placeholder de un NPC ("placeholder" en data/npcs/<id>.json):
## { colors: { robe, trim, hair, skin }, prop }. {} si no tiene (el sfida usa su hoja).
static func placeholder_of(id: StringName) -> Dictionary:
	if id == &"" or not FileAccess.file_exists(NpcDialogue.NPC_PATH % id):
		return {}
	var raw: Variant = NpcDialogue.data(id).get("placeholder", {})
	if not raw is Dictionary or not raw.has("colors"):
		return {}
	var colors: Dictionary = {}
	for key: String in SFIDA_COLORS:
		colors[key] = Color(str(raw.colors.get(key, SFIDA_COLORS[key].to_html(false))))
	return { "colors": colors, "prop": StringName(str(raw.get("prop", ""))) }


static func _is_open_around_world(chunk: WorldChunk, c: Vector2i) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var n: Vector2i = c + Vector2i(dx, dy)
			if not chunk.is_walkable(n) or chunk.object_index_at(n) != WorldChunk.NO_OBJECT:
				return false
	return true


## Sprite de placeholder 16x16: túnica hasta los pies con cinta, cabeza y pelo. `prop` (P5,
## placeholder hasta el arte del pixel-artist): &"mask" = una máscara clara en la mano (Sarua) y un
## pañuelo en la cabeza; &"tool" = un mazo de madera (Paruas) y un delantal en lugar de la cinta.
static func make_texture(colors: Dictionary, dir: Vector2i, prop: StringName = &"") -> Texture2D:
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
	match prop:
		&"mask":
			img.fill_rect(Rect2i(4, 0, 8, 2), trim)
			img.fill_rect(Rect2i(11, 8, 4, 4), Color("ead4aa"))
			img.set_pixel(12, 9, outline)
			img.set_pixel(14, 9, outline)
		&"tool":
			img.fill_rect(Rect2i(5, 10, 6, 5), trim)
			img.fill_rect(Rect2i(13, 6, 1, 7), Color("733e39"))
			img.fill_rect(Rect2i(12, 5, 3, 2), Color("8b9bb4"))
	PlayerController.add_outline(img, outline)
	return ImageTexture.create_from_image(img)
