class_name AdocNpc
extends Node2D
## Otro adoc en el mundo (AdocEncounters, otros-adoc.md): la hoja del Adoc (PlayerController.SHEET_PATH)
## con otra ropa (los colores de su túnica cambiados por los de `clothes`), mirando hacia su rival y
## con un saltito de guardia. Bloquea su casilla como un NPC. Sin la hoja, el placeholder del Adoc
## recoloreado. Arte provisional hasta que pixel-artist dé su sprite.

## Colores de la túnica en la hoja del Adoc (claro y oscuro) que se sustituyen.
const TUNIC_LIGHT := Color("d77643")
const TUNIC_DARK := Color("be4a2f")
## Colores de la túnica del placeholder procedural.
const PLACEHOLDER_TUNIC := Color("e43b44")
## Segundos de cada medio saltito de guardia.
const GUARD_TIME: float = 0.35

## Casilla global (world_cell) que ocupa y bloquea.
var cell: Vector2i = Vector2i.ZERO
var encounter: Dictionary = {}


## Con los pies en el centro de la casilla global `at` (va en el nodo de objetos con orden en Y, como
## Npc.setup_world); el sprite de 16×16 queda encima.
func setup(e: Dictionary, at: Vector2i, facing: Vector2i) -> void:
	encounter = e
	cell = at
	position = WorldCoords.world_cell_to_world_pos(at)
	var sprite := Sprite2D.new()
	sprite.offset = Vector2(0, -PlayerController.TILE_SIZE * 0.5)
	sprite.texture = frame_texture(e.get("clothes", {}), facing)
	add_child(sprite)
	var t := sprite.create_tween().set_loops()
	t.tween_property(sprite, "position:y", -1.0, GUARD_TIME)
	t.tween_property(sprite, "position:y", 0.0, GUARD_TIME)


## Primer fotograma de la fila `dir` de la hoja del Adoc con la ropa de `clothes` ({ light, dark }).
static func frame_texture(clothes: Dictionary, dir: Vector2i) -> Texture2D:
	var light := Color(str(clothes.get("light", "0099db")))
	var dark := Color(str(clothes.get("dark", "124e89")))
	if not ResourceLoader.exists(PlayerController.SHEET_PATH):
		var ph: Image = PlayerController._make_texture(dir).get_image()
		return ImageTexture.create_from_image(_swap(ph, { PLACEHOLDER_TUNIC.to_rgba32(): light }))
	var sheet: Image = (load(PlayerController.SHEET_PATH) as Texture2D).get_image()
	if sheet.is_compressed():
		sheet.decompress()
	sheet.convert(Image.FORMAT_RGBA8)
	var size := Vector2i(sheet.get_width() / PlayerController.SHEET_FRAMES, sheet.get_height() / PlayerController.SHEET_ROWS.size())
	var row: int = maxi(0, PlayerController.SHEET_ROWS.find(dir))
	var frame: Image = sheet.get_region(Rect2i(Vector2i(0, size.y * row), size))
	return ImageTexture.create_from_image(_swap(frame, { TUNIC_LIGHT.to_rgba32(): light, TUNIC_DARK.to_rgba32(): dark }))


static func _swap(img: Image, mapping: Dictionary) -> Image:
	var out := img.duplicate() as Image
	out.convert(Image.FORMAT_RGBA8)
	for y: int in out.get_height():
		for x: int in out.get_width():
			var c: Color = out.get_pixel(x, y)
			if c.a > 0.0 and mapping.has(c.to_rgba32()):
				out.set_pixel(x, y, mapping[c.to_rgba32()])
	return out
