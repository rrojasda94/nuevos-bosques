extends Node2D
## Escena de muestra de la dirección de arte (docs/art/direccion-de-arte.md): un claro en un bosque
## extraño con copas que se mecen, niebla baja tramada, motas de luz y un acompañante etéreo que
## sigue al Adoc. No forma parte del juego: se abre sola para probar la atmósfera y sacar capturas.
## Todo es placeholder de código con la paleta de 32 colores.

const SIZE: int = ChunkData.SIZE
## Bosque de la muestra: hojas azul pizarra, tronco casi negro, hierba oscura (PlaceholderTileset).
const STYLE: Dictionary = {"shape": 0, "leaf": 10, "trunk": 5, "ground": 1}
## Radios del claro (casillas): suelo despejado dentro, hierba hasta el borde del bosque.
const CLEARING_RADIUS: float = 4.5
const GRASS_RADIUS: float = 7.5
## Color reservado para lo etéreo y su tono oscuro (parpadeo).
const ETHEREAL := Color("2ce8f5")
const ETHEREAL_DARK := Color("0099db")
const FOG_COLOR := Color("8b9bb4")
## Parte de la pantalla que tapa la niebla (0-1) y su velocidad en px/s.
const FOG_DENSITY: float = 0.12
const FOG_SPEED: float = 3.0
## Dónde flota el acompañante respecto al Adoc y cuánto tarda en alcanzarle.
const COMPANION_OFFSET := Vector2(-12, -14)
const COMPANION_FOLLOW: float = 1.8
const BAYER_4: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var _chunk := ChunkData.new()
var _fog_scroll: float = 0.0
var _companion_pos := Vector2.ZERO
var _companion_frames: Array[Texture2D] = []
var _time: float = 0.0

@onready var _ground: TileMapLayer = $Ground
@onready var _trees: TileMapLayer = $Trees
@onready var _fog: Sprite2D = $Fog
@onready var _player: PlayerWalker = $Player
@onready var _companion: Sprite2D = $Companion
@onready var _motes: CPUParticles2D = $Player/Camera2D/Motes


func _ready() -> void:
	_build_chunk()
	_draw_terrain()
	_fog.texture = _fog_texture()
	# 64 px de más a la derecha para que el desplazamiento no deje ver el borde.
	_fog.region_rect = Rect2(0, 0, SIZE * 16 + 64, SIZE * 16)
	_motes.texture = _pixel_texture()
	_motes.color_initial_ramp = _ramp([Color("fee761"), ETHEREAL, Color("c0cbdc")])
	_companion_frames = [_wisp_texture(ETHEREAL), _wisp_texture(ETHEREAL_DARK)]
	_companion.texture = _companion_frames[0]
	var trail: CPUParticles2D = $Companion/Trail
	trail.texture = _pixel_texture()
	trail.color_initial_ramp = _ramp([ETHEREAL, ETHEREAL_DARK])
	_player.is_walkable = _chunk.is_walkable
	_player.place_at(ChunkData.center())
	_companion_pos = _player.position + COMPANION_OFFSET
	var cam: Camera2D = $Player/Camera2D
	cam.limit_right = SIZE * 16
	cam.limit_bottom = SIZE * 16


func _process(delta: float) -> void:
	_time += delta
	# Niebla: se desliza en píxeles enteros.
	_fog_scroll += FOG_SPEED * delta
	_fog.position = Vector2(-roundf(fmod(_fog_scroll, 64.0)), 0)
	# Acompañante: sigue con retraso, flota y parpadea entre dos tonos.
	_companion_pos = _companion_pos.lerp(_player.position + COMPANION_OFFSET, minf(1.0, COMPANION_FOLLOW * delta))
	var bob: float = roundf(sin(_time * 2.2) * 2.0)
	_companion.position = (_companion_pos + Vector2(0, bob)).round()
	_companion.texture = _companion_frames[1 if fmod(_time, 1.3) > 1.1 else 0]


func _build_chunk() -> void:
	_chunk.tiles.resize(SIZE * SIZE)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.12
	var c := Vector2(ChunkData.center())
	for y: int in SIZE:
		for x: int in SIZE:
			# Claro algo ovalado y de borde irregular.
			var r: float = Vector2((x - c.x), (y - c.y) * 1.3).length() + noise.get_noise_2d(x, y) * 3.0
			var tile: int = ChunkData.Tile.TREE
			if r < CLEARING_RADIUS:
				tile = ChunkData.Tile.CLEARING
			elif r < GRASS_RADIUS:
				tile = ChunkData.Tile.GRASS
			_chunk.set_tile(Vector2i(x, y), tile)
	# Un sendero que entra al claro desde el sur.
	for y: int in range(int(c.y), SIZE):
		_chunk.set_tile(Vector2i(int(c.x) + int(noise.get_noise_1d(y * 4.0) * 2.0), y), ChunkData.Tile.PATH)


func _draw_terrain() -> void:
	var tile_set: TileSet = PlaceholderTileset.make_tile_set()
	tile_set.add_source(PlaceholderTileset.make_source(STYLE), 0)
	_ground.tile_set = tile_set
	_trees.tile_set = tile_set
	for y: int in SIZE:
		for x: int in SIZE:
			var cell := Vector2i(x, y)
			var tile: int = _chunk.get_tile(cell)
			var at := Vector2i(tile, PlaceholderTileset.variant_for(_chunk, cell, 0))
			if tile == ChunkData.Tile.TREE:
				_trees.set_cell(cell, 0, at)
			else:
				_ground.set_cell(cell, 0, at)


## Niebla tramada: ruido continuo convertido a píxel lleno o vacío con una matriz de Bayer 4x4,
## para no usar alfa parcial. Se repite sin costuras.
func _fog_texture() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.02
	noise.fractal_octaves = 2
	var src: Image = noise.get_seamless_image(128, 128)
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y: int in 128:
		for x: int in 128:
			# Solo las zonas más densas del ruido llevan niebla; el resto queda limpio.
			var v: float = (src.get_pixel(x, y).r - (1.0 - FOG_DENSITY * 2.0)) / (FOG_DENSITY * 2.0)
			if v * 16.0 > BAYER_4[(y % 4) * 4 + x % 4]:
				img.set_pixel(x, y, FOG_COLOR)
	var tex := ImageTexture.create_from_image(img)
	return tex


## Fuego fatuo de 7x7: rombo con núcleo blanco y contorno de su propio tono.
func _wisp_texture(color: Color) -> Texture2D:
	var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	for y: int in 7:
		for x: int in 7:
			var d: int = absi(x - 3) + absi(y - 3)
			if d <= 1:
				img.set_pixel(x, y, Color.WHITE)
			elif d <= 3:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


func _pixel_texture() -> Texture2D:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


## Rampa de color sin mezcla: cada partícula sale con uno de los colores, nunca con uno intermedio.
func _ramp(colors: Array[Color]) -> Gradient:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array(range(colors.size()).map(func(i: int) -> float: return float(i) / colors.size()))
	g.colors = PackedColorArray(colors)
	return g
