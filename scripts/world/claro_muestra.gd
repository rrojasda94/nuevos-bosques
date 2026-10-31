extends Node2D
## Escena de muestra de la dirección de arte (docs/art/direccion-de-arte.md): un claro en un bosque
## extraño con copas que se mecen, niebla atmosférica, motas de luz y mitahir (glosario: espíritus
## traviesos, Luces creadas por los Hijos). Uno aparece a ratos, sigue al Adoc un tiempo y se
## desvanece; si el Adoc se queda quieto, otros le miran desde las copas. No forma parte del juego:
## se abre sola para probar la atmósfera y sacar capturas. Placeholder de código con la paleta de 32.

const SIZE: int = ChunkData.SIZE
## Bosque de la muestra: hojas azul pizarra, tronco casi negro, hierba oscura (PlaceholderTileset).
const STYLE: Dictionary = {"shape": 0, "leaf": 10, "trunk": 5, "ground": 1}
## Radios del claro (casillas): suelo despejado dentro, hierba hasta el borde del bosque.
const CLEARING_RADIUS: float = 4.5
const GRASS_RADIUS: float = 7.5
## Color reservado para lo etéreo y su tono oscuro (parpadeo).
const ETHEREAL := Color("2ce8f5")
const ETHEREAL_DARK := Color("0099db")
## Niebla: color de la paleta con transparencia (excepción de atmósfera aprobada por el dueño, como
## la luz de luna del ADR 0012). Alfa mínimo (bruma en todas partes), máximo y escalones entre ellos.
const FOG_COLOR := Color("c0cbdc")
const FOG_ALPHA_MIN: float = 0.06
const FOG_ALPHA_MAX: float = 0.3
const FOG_LEVELS: int = 5
const FOG_SPEED: float = 3.0
const FOG_TEX: int = 256
## Mitahir errante: espera entre apariciones, cuánto te sigue, dónde flota y cuánto tarda en alcanzarte.
const WANDER_WAIT := Vector2(5.0, 12.0)
const WANDER_FOLLOW := Vector2(8.0, 14.0)
const WANDER_OFFSET := Vector2(-12, -14)
const WANDER_LERP: float = 1.8
## Parpadeo al aparecer o desvanecerse (segundos).
const BLINK_TIME: float = 0.8
## Mitahir de las copas: segundos quieto hasta que aparecen, cuántos y a qué distancia (casillas, la pantalla).
const STILL_TIME: float = 3.0
const WATCHERS: int = 5
const WATCH_RANGE := Vector2i(9, 5)
const WATCH_STAGGER: float = 0.7

enum Wander { HIDDEN, APPEARING, FOLLOWING, FADING }

var _chunk := ChunkData.new()
var _rng := RandomNumberGenerator.new()
var _fog_scroll: float = 0.0
var _time: float = 0.0
var _wisp_frames: Array[Texture2D] = []
var _wander: Wander = Wander.HIDDEN
var _wander_timer: float = 0.0
var _wander_pos := Vector2.ZERO
var _still: float = 0.0
var _last_player_pos := Vector2.ZERO
var _watching: bool = false

@onready var _ground: TileMapLayer = $Ground
@onready var _trees: TileMapLayer = $Trees
@onready var _fog: Sprite2D = $Fog
@onready var _player: PlayerWalker = $Player
@onready var _wisp: Sprite2D = $Mitahir
@onready var _trail: CPUParticles2D = $Mitahir/Trail
@onready var _watchers: Node2D = $Watchers
@onready var _motes: CPUParticles2D = $Player/Camera2D/Motes


func _ready() -> void:
	_build_chunk()
	_draw_terrain()
	_fog.texture = _fog_texture()
	# Una baldosa de niebla de más a la derecha para que el desplazamiento no deje ver el borde.
	_fog.region_rect = Rect2(0, 0, SIZE * 16 + FOG_TEX, SIZE * 16)
	_motes.texture = _pixel_texture()
	_motes.color_initial_ramp = _ramp([Color("fee761"), ETHEREAL, Color("c0cbdc")])
	_wisp_frames = [_wisp_texture(ETHEREAL), _wisp_texture(ETHEREAL_DARK)]
	_wisp.texture = _wisp_frames[0]
	_trail.texture = _pixel_texture()
	_trail.color_initial_ramp = _ramp([ETHEREAL, ETHEREAL_DARK])
	_player.is_walkable = _chunk.is_walkable
	_player.place_at(ChunkData.center())
	_last_player_pos = _player.position
	_hide_wisp()
	var cam: Camera2D = $Player/Camera2D
	cam.limit_right = SIZE * 16
	cam.limit_bottom = SIZE * 16


func _process(delta: float) -> void:
	_time += delta
	# Niebla: se desliza en píxeles enteros.
	_fog_scroll += FOG_SPEED * delta
	_fog.position = Vector2(-roundf(fmod(_fog_scroll, FOG_TEX)), 0)
	_update_wanderer(delta)
	_update_watchers(delta)


## Mitahir errante: oculto -> aparece parpadeando en el borde del bosque -> sigue al Adoc un rato
## -> se desvanece parpadeando -> oculto otra vez.
func _update_wanderer(delta: float) -> void:
	_wander_timer -= delta
	match _wander:
		Wander.HIDDEN:
			if _wander_timer <= 0.0:
				_wander = Wander.APPEARING
				_wander_timer = BLINK_TIME
				var side := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized()
				_wander_pos = _player.position + side * 90.0
				_wisp.show()
				_trail.emitting = true
			return
		Wander.APPEARING:
			_blink()
			if _wander_timer <= 0.0:
				_wander = Wander.FOLLOWING
				_wander_timer = _rng.randf_range(WANDER_FOLLOW.x, WANDER_FOLLOW.y)
				_wisp.visible = true
		Wander.FOLLOWING:
			if _wander_timer <= 0.0:
				_wander = Wander.FADING
				_wander_timer = BLINK_TIME
		Wander.FADING:
			_blink()
			if _wander_timer <= 0.0:
				_hide_wisp()
				return
	# Sigue con retraso; al irse, se queda donde está.
	if _wander != Wander.FADING:
		_wander_pos = _wander_pos.lerp(_player.position + WANDER_OFFSET, minf(1.0, WANDER_LERP * delta))
	var bob: float = roundf(sin(_time * 2.2) * 2.0)
	_wisp.position = (_wander_pos + Vector2(0, bob)).round()
	_wisp.texture = _wisp_frames[1 if fmod(_time, 1.3) > 1.1 else 0]


func _hide_wisp() -> void:
	_wander = Wander.HIDDEN
	_wander_timer = _rng.randf_range(WANDER_WAIT.x, WANDER_WAIT.y)
	_wisp.hide()
	_trail.emitting = false


## Parpadeo de aparición y desvanecimiento: visible e invisible a saltos, sin alfa.
func _blink() -> void:
	_wisp.visible = int(_time * 12.0) % 2 == 0


## Mitahir de las copas: tras STILL_TIME sin moverse aparecen ojos en los árboles cercanos, uno a
## uno, mirando al Adoc. Al moverse se apagan todos.
func _update_watchers(delta: float) -> void:
	if _player.position != _last_player_pos or _player.is_moving():
		_last_player_pos = _player.position
		_still = 0.0
		if _watching:
			_watching = false
			for eyes: Node in _watchers.get_children():
				eyes.queue_free()
		return
	_still += delta
	if not _watching and _still >= STILL_TIME:
		_watching = true
		_spawn_watchers()


func _spawn_watchers() -> void:
	var here: Vector2i = _player.cell
	var trees: Array[Vector2i] = []
	for y: int in range(here.y - WATCH_RANGE.y, here.y + WATCH_RANGE.y + 1):
		for x: int in range(here.x - WATCH_RANGE.x, here.x + WATCH_RANGE.x + 1):
			var c := Vector2i(x, y)
			if ChunkData.in_bounds(c) and _chunk.get_tile(c) == ChunkData.Tile.TREE:
				trees.append(c)
	trees.shuffle()
	for i: int in mini(WATCHERS, trees.size()):
		var cell: Vector2i = trees[i]
		var eyes := Sprite2D.new()
		eyes.texture = _eyes_texture(Vector2(here - cell).sign())
		# En la copa: mitad alta de la casilla, con algo de variación.
		eyes.position = Vector2(cell * 16) + Vector2(8, 4 + _rng.randi_range(0, 3))
		eyes.visible = false
		_watchers.add_child(eyes)
		get_tree().create_timer(i * WATCH_STAGGER).timeout.connect(func() -> void:
			if is_instance_valid(eyes):
				eyes.visible = true)


## Dos ojos de 2x2 separados por 1 px; la pupila blanca mira hacia el Adoc (`look`: -1, 0 o 1 en x e y).
func _eyes_texture(look: Vector2) -> Texture2D:
	var img := Image.create(5, 2, false, Image.FORMAT_RGBA8)
	var px: int = 1 if look.x > 0 else 0
	var py: int = 1 if look.y > 0 else 0
	for ox: int in [0, 3]:
		img.fill_rect(Rect2i(ox, 0, 2, 2), ETHEREAL_DARK)
		img.set_pixel(ox + px, py, Color.WHITE)
	return ImageTexture.create_from_image(img)


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


## Niebla atmosférica: ruido amplio y suave, un solo color con alfa en pocos escalones (para que
## se lea pixelada, no como degradado). Bruma leve en todas partes y bancos algo más densos.
func _fog_texture() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.008
	noise.fractal_octaves = 3
	var src: Image = noise.get_seamless_image(FOG_TEX, FOG_TEX)
	var img := Image.create(FOG_TEX, FOG_TEX, false, Image.FORMAT_RGBA8)
	for y: int in FOG_TEX:
		for x: int in FOG_TEX:
			var v: float = clampf((src.get_pixel(x, y).r - 0.35) / 0.4, 0.0, 1.0)
			var step: float = floorf(v * (FOG_LEVELS - 1) + 0.5) / (FOG_LEVELS - 1)
			img.set_pixel(x, y, Color(FOG_COLOR, lerpf(FOG_ALPHA_MIN, FOG_ALPHA_MAX, step)))
	return ImageTexture.create_from_image(img)


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
