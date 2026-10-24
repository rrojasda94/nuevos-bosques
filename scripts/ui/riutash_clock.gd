extends CanvasLayer
## Reloj del riutash (HUD, esquina inferior derecha): un disco al estilo del reloj de Minecraft
## cuya esfera gira con WorldClock. La mitad de Gietos y la de Riumna pasan bajo la marca de
## "ahora"; el borde entre ellas es el riutash. Sin números.
## En los últimos segundos late (crece y encoge) cada vez más deprisa y suena el swish en los
## avisos; al pasar el riutash destella. Solo lee WorldClock y escucha EventBus.
## La lógica está en RiutashClockLogic y el dibujo en RiutashDial.

## Pasos de la esfera por vuelta (unos 1 px por paso en el borde del disco).
const STEPS: int = 64
## Píxeles que crece el radio en el pico del pulso (10 -> 13 px, unas 1,25 veces).
const MAX_GROW: int = 3
## Duración de un pulso (crece y vuelve).
const PULSE_LENGTH: float = 0.36
## Destello al pasar el riutash: duración y medio periodo del parpadeo.
const FLASH_TIME: float = 1.2
const FLASH_HALF_PERIOD: float = 0.15
const SWISH: StringName = &"riutash_swish"

var _textures: Dictionary = {}
var _key: int = -1
var _marks: Array[int] = []
var _first_warning: float = 0.0
var _last_warning: float = 0.0
## Segundos que faltaban en el frame anterior; < 0 hasta el primer frame (al cargar no suena).
var _previous_left: float = -1.0
var _since_pulse: float = 0.0
## Tiempo dentro del pulso actual; < 0 si no hay pulso.
var _pulse_t: float = -1.0
var _flash_left: float = 0.0

@onready var _dial: TextureRect = $Root/Dial


func _ready() -> void:
	var warnings: Array[int] = TimeConfig.warnings()
	_marks = RiutashClockLogic.swish_marks(warnings)
	if not warnings.is_empty():
		_first_warning = warnings.front()
		_last_warning = warnings.back()
	EventBus.riutash_passed.connect(_on_riutash_passed)
	EventBus.momento_changed.connect(func(_m: StringName) -> void: _update_tooltip())
	_update_tooltip()
	_redraw()


func _process(delta: float) -> void:
	var left: float = WorldClock.time_to_riutash()
	if _previous_left >= 0.0 and RiutashClockLogic.crossed_mark(_previous_left, left, _marks):
		Sfx.play(SWISH)
		_start_pulse()
	else:
		var interval: float = RiutashClockLogic.pulse_interval(left, _first_warning, _last_warning)
		if interval > 0.0:
			_since_pulse += delta
			if _since_pulse >= interval:
				_start_pulse()
		else:
			_since_pulse = 0.0
	_previous_left = left
	if _pulse_t >= 0.0:
		_pulse_t += delta
		if _pulse_t >= PULSE_LENGTH:
			_pulse_t = -1.0
	_flash_left = maxf(0.0, _flash_left - delta)
	_redraw()


func _start_pulse() -> void:
	_since_pulse = 0.0
	_pulse_t = 0.0


func _on_riutash_passed(_sheltered: bool) -> void:
	_pulse_t = -1.0
	_flash_left = FLASH_TIME


## Cambia la textura solo cuando cambia el paso, el crecimiento o el destello.
func _redraw() -> void:
	var phase: float = RiutashClockLogic.phase(WorldClock.momento(), WorldClock.time_to_riutash(),
			TimeConfig.duration(TimeConfig.GIETOS), TimeConfig.duration(TimeConfig.RIUMNA))
	var step: int = RiutashClockLogic.step(phase, STEPS)
	var grow: int = RiutashClockLogic.pulse_grow(_pulse_t, PULSE_LENGTH, MAX_GROW)
	var flash: bool = _flash_left > 0.0 and fposmod(_flash_left, FLASH_HALF_PERIOD * 2.0) >= FLASH_HALF_PERIOD
	var key: int = step + STEPS * (grow + (MAX_GROW + 1) * int(flash))
	if key == _key:
		return
	_key = key
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(RiutashDial.render(float(step) / STEPS, grow, flash))
	_dial.texture = _textures[key]


## Para quien use el ratón: el nombre del Momento al pasar por encima.
func _update_tooltip() -> void:
	_dial.tooltip_text = Texts.get_text("hud_momento_%s" % WorldClock.momento())
