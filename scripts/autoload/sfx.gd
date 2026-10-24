extends Node
## Efectos de sonido (autoload `Sfx`). Carga assets/audio/sfx/sfx_<nombre>.wav (los genera
## tools/audio/make_sfx.py) y los reproduce en el bus "SFX" con play(nombre). Cada efecto tiene
## su propia voz: repetirlo lo reinicia en vez de amontonarlo (como un canal de la NES).
## Escucha a EventBus para los sonidos del mundo (avisos y destello del riutash, subir de nivel).
## Un nombre sin archivo no hace nada: el juego nunca depende de que suene algo.
## Lista de efectos y su uso: docs/art/specs/primera-pasada.md.

const DIR: String = "res://assets/audio/sfx/"
const NAMES: Array[StringName] = [
	&"step", &"text_blip", &"hit", &"whip", &"riutash_warning", &"riutash", &"riutash_swish", &"level_up",
	&"menu_move", &"menu_accept",
]
const BUS: StringName = &"SFX"
## Volumen del bus si no viene de default_bus_layout.tres.
const BUS_VOLUME_DB: float = -6.0

var _players: Dictionary = {}


func _ready() -> void:
	# Suena también con el árbol en pausa (diálogos, menús, mapa).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus()
	for sfx_name: StringName in NAMES:
		var path: String = DIR + "sfx_%s.wav" % sfx_name
		if not ResourceLoader.exists(path):
			continue
		var player := AudioStreamPlayer.new()
		player.name = String(sfx_name)
		player.stream = load(path)
		player.bus = BUS
		add_child(player)
		_players[sfx_name] = player
	EventBus.riutash_warning.connect(func(_seconds_left: int) -> void: play(&"riutash_warning"))
	EventBus.riutash_passed.connect(func(_sheltered: bool) -> void: play(&"riutash"))
	EventBus.character_leveled_up.connect(func(_id: StringName, _level: int) -> void: play_level_up())


## Reproduce el efecto `sfx_name` (sin el prefijo "sfx_"). false si no existe.
func play(sfx_name: StringName) -> bool:
	var player: AudioStreamPlayer = _players.get(sfx_name)
	if player == null:
		return false
	player.play()
	return true


func has(sfx_name: StringName) -> bool:
	return _players.has(sfx_name)


## Subir de nivel. Ya suena con EventBus.character_leveled_up; queda pública por si la progresión
## necesita llamarla directamente.
func play_level_up() -> void:
	play(&"level_up")


func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_volume_db(index, BUS_VOLUME_DB)
	AudioServer.set_bus_send(index, &"Master")
