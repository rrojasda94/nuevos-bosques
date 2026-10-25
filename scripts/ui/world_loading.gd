extends CanvasLayer
## Pantalla "Creando el mundo…" (ADR 0014 §6; wireframe en docs/design/ui/creando-el-mundo.md):
## título, barra de progreso del anillo inicial de la pregeneración y una pista, sobre un fondo
## opaco (MapPanel del tema) en la capa 2, encima de la luz de luna.
## La barra se dibuja a mano, al píxel y con colores de la paleta (como la brújula), porque el
## tema central aún no tiene estilo de ProgressBar; cuando lo tenga, se cambia por un ProgressBar.
##
## Uso (se enchufa al flujo de partida en M17):
##     var screen := preload("res://scenes/ui/world_loading.tscn").instantiate()
##     add_child(screen)
##     screen.track(pregen)          # WorldPregen ya arrancado con start()
##     await screen.finished         # anillo inicial listo: se puede entrar al mundo
## Mientras sigue un WorldPregen, llama a su poll() cada fotograma (alguien tiene que entregar los
## chunks al hilo principal mientras no hay mundo en pantalla) y deja de hacerlo al terminar el
## anillo: desde ahí lo hace el WorldStreamer (M12). No toca GameState.

## El anillo inicial está listo (o se llamó a set_progress con done >= total).
signal finished

## Paleta: borde, fondo de la barra (262b44) y relleno (fee761, el de TitleLabel).
const BORDER_COLOR := Color("ffffff")
const TRACK_COLOR := Color("262b44")
const FILL_COLOR := Color("fee761")

var _pregen: WorldPregen = null
var _finished: bool = false
var _done: int = 0
var _total: int = 1

@onready var _title: Label = $Root/Title
@onready var _hint: Label = $Root/Hint
@onready var _bar: Control = $Root/Bar


func _ready() -> void:
	_title.text = Texts.get_text("world_loading_title")
	_hint.text = Texts.get_text("world_loading_hint")
	_bar.draw.connect(_on_bar_draw)
	set_process(_pregen != null)


## Sigue el anillo inicial de `pregen` hasta ring_completed.
func track(pregen: WorldPregen) -> void:
	_pregen = pregen
	_finished = false
	pregen.ring_progressed.connect(set_progress)
	pregen.ring_completed.connect(_on_ring_completed)
	set_progress(pregen.ring_done(), pregen.ring_total())
	if pregen.is_ring_complete():
		_on_ring_completed()
	else:
		set_process(true)


## Progreso a mano (para otros usos de la pantalla o sin WorldPregen).
func set_progress(done: int, total: int) -> void:
	_total = maxi(1, total)
	_done = clampi(done, 0, _total)
	if _bar != null:
		_bar.queue_redraw()
	if total > 0 and done >= total and _pregen == null and not _finished:
		_finished = true
		finished.emit.call_deferred()


func _process(_delta: float) -> void:
	_pregen.poll()


func _on_ring_completed() -> void:
	set_process(false)
	if _pregen != null:
		if _pregen.ring_progressed.is_connected(set_progress):
			_pregen.ring_progressed.disconnect(set_progress)
		if _pregen.ring_completed.is_connected(_on_ring_completed):
			_pregen.ring_completed.disconnect(_on_ring_completed)
	_pregen = null
	if not _finished:
		_finished = true
		# Diferido: si el anillo ya estaba listo en track(), quien llama aún no ha hecho el await.
		finished.emit.call_deferred()


## Marco blanco de 1 px, fondo oscuro y relleno entero en píxeles (sin medios píxeles).
func _on_bar_draw() -> void:
	var size: Vector2i = Vector2i(_bar.size)
	_bar.draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR)
	var inner := Rect2i(Vector2i.ONE, size - Vector2i(2, 2))
	_bar.draw_rect(Rect2(inner), TRACK_COLOR)
	var width: int = inner.size.x * _done / _total
	if width > 0:
		_bar.draw_rect(Rect2(Rect2i(inner.position, Vector2i(width, inner.size.y))), FILL_COLOR)
