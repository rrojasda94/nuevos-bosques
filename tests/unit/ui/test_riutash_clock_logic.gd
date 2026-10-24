extends GutTest
## Reloj del riutash: posición de la esfera según el Momento y el tiempo que falta, ritmo del
## pulso, crecimiento del disco, marcas del swish y dibujo (qué mitad queda bajo la marca).

const G: StringName = &"gietos"
const R: StringName = &"riumna"
const DAY: float = 480.0
const NIGHT: float = 300.0


func test_phase_dawn_is_zero() -> void:
	assert_almost_eq(RiutashClockLogic.phase(G, DAY, DAY, NIGHT), 0.0, 0.0001)


func test_phase_midday_is_quarter() -> void:
	assert_almost_eq(RiutashClockLogic.phase(G, DAY / 2.0, DAY, NIGHT), 0.25, 0.0001)


func test_phase_dusk_is_half_from_both_sides() -> void:
	assert_almost_eq(RiutashClockLogic.phase(G, 0.0, DAY, NIGHT), 0.5, 0.0001)
	assert_almost_eq(RiutashClockLogic.phase(R, NIGHT, DAY, NIGHT), 0.5, 0.0001)


func test_phase_midnight_is_three_quarters() -> void:
	assert_almost_eq(RiutashClockLogic.phase(R, NIGHT / 2.0, DAY, NIGHT), 0.75, 0.0001)


func test_phase_end_of_night_wraps_to_dawn() -> void:
	assert_almost_eq(RiutashClockLogic.phase(R, 0.0, DAY, NIGHT), 0.0, 0.0001)


func test_phase_never_goes_backwards_within_momento() -> void:
	var previous: float = -1.0
	for i: int in range(0, 481, 10):
		var p: float = RiutashClockLogic.phase(G, DAY - i, DAY, NIGHT)
		assert_true(p >= previous, "avanza en t=%d" % i)
		previous = p


func test_step_reaches_border_only_at_riutash() -> void:
	# Un instante antes del atardecer la esfera aún no ha llegado al paso del borde (32 de 64).
	assert_eq(RiutashClockLogic.step(RiutashClockLogic.phase(G, 0.5, DAY, NIGHT), 64), 31)
	assert_eq(RiutashClockLogic.step(RiutashClockLogic.phase(G, 0.0, DAY, NIGHT), 64), 32)
	assert_eq(RiutashClockLogic.step(RiutashClockLogic.phase(R, 0.0, DAY, NIGHT), 64), 0)
	assert_eq(RiutashClockLogic.step(0.999, 64), 63)


func test_no_pulse_outside_warning() -> void:
	assert_eq(RiutashClockLogic.pulse_interval(61.0, 60.0, 15.0), 0.0)
	assert_eq(RiutashClockLogic.pulse_interval(300.0, 60.0, 15.0), 0.0)
	assert_eq(RiutashClockLogic.pulse_interval(0.0, 60.0, 15.0), 0.0)


func test_pulse_accelerates() -> void:
	assert_almost_eq(RiutashClockLogic.pulse_interval(60.0, 60.0, 15.0), RiutashClockLogic.PULSE_SLOW, 0.0001)
	var mid: float = RiutashClockLogic.pulse_interval(37.5, 60.0, 15.0)
	assert_true(mid < RiutashClockLogic.PULSE_SLOW and mid > RiutashClockLogic.PULSE_MID, "entre lento y medio")
	assert_eq(RiutashClockLogic.pulse_interval(15.0, 60.0, 15.0), RiutashClockLogic.PULSE_FAST)
	assert_eq(RiutashClockLogic.pulse_interval(1.0, 60.0, 15.0), RiutashClockLogic.PULSE_FAST)
	assert_almost_eq(RiutashClockLogic.PULSE_SLOW, 2.0, 0.0001, "cada 2 s al empezar")
	assert_almost_eq(RiutashClockLogic.PULSE_FAST, 0.5, 0.0001, "cada 0,5 s al final")


func test_pulse_grow_goes_up_and_back() -> void:
	assert_eq(RiutashClockLogic.pulse_grow(-1.0, 0.36, 3), 0, "sin pulso")
	assert_eq(RiutashClockLogic.pulse_grow(0.0, 0.36, 3), 0)
	assert_eq(RiutashClockLogic.pulse_grow(0.18, 0.36, 3), 3, "pico a mitad")
	assert_eq(RiutashClockLogic.pulse_grow(0.36, 0.36, 3), 0, "termina")
	assert_true(RiutashClockLogic.pulse_grow(0.09, 0.36, 3) in [1, 2])


func test_swish_marks_are_warnings_and_last_seconds() -> void:
	var warnings: Array[int] = [60, 15]
	assert_eq(RiutashClockLogic.swish_marks(warnings), [60, 15, 10, 5] as Array[int])


func test_crossed_mark_only_going_down() -> void:
	var marks: Array[int] = [60, 15, 10, 5]
	assert_true(RiutashClockLogic.crossed_mark(60.01, 59.99, marks))
	assert_true(RiutashClockLogic.crossed_mark(15.2, 15.0, marks))
	assert_false(RiutashClockLogic.crossed_mark(59.9, 59.8, marks))
	assert_false(RiutashClockLogic.crossed_mark(0.01, 300.0, marks), "el salto al Momento siguiente no cruza")


func test_dial_shows_gietos_by_day_and_riumna_by_night() -> void:
	# Fases lejos de los ojos y los riumini, para leer el cielo bajo la marca.
	var at: Vector2i = RiutashDial.now_pixel()
	assert_eq(RiutashDial.render(0.1).get_pixelv(at), RiutashDial.GIETOS_SKY)
	assert_eq(RiutashDial.render(0.7).get_pixelv(at), RiutashDial.RIUMNA_SKY)


func test_eyes_under_mark_at_midday_and_midnight() -> void:
	var at: Vector2i = RiutashDial.now_pixel()
	assert_ne(RiutashDial.render(0.25).get_pixelv(at), RiutashDial.GIETOS_SKY, "el ojo de Gietos a mediodía")
	var below: Vector2i = at + Vector2i(0, 2)
	assert_ne(RiutashDial.render(0.75).get_pixelv(below), RiutashDial.RIUMNA_SKY, "el ojo de Riumna a medianoche")


func test_dial_border_under_mark_at_riutash() -> void:
	var at: Vector2i = RiutashDial.now_pixel()
	assert_eq(RiutashDial.render(0.0).get_pixelv(at), RiutashDial.RIUTASH)
	assert_eq(RiutashDial.render(0.5).get_pixelv(at), RiutashDial.RIUTASH)


func test_dial_grows_with_pulse() -> void:
	var calm: Image = RiutashDial.render(0.25, 0)
	var big: Image = RiutashDial.render(0.25, 3)
	var c: int = RiutashDial.CENTER
	var edge: int = c + RiutashDial.BASE_RADIUS + 3
	assert_eq(calm.get_pixel(edge, c).a, 0.0, "en reposo no llega")
	assert_true(big.get_pixel(edge, c) in [RiutashDial.RIM, RiutashDial.RIM_LIGHT, RiutashDial.RIM_SHADE],
			"en el pico, borde dorado más afuera")
	assert_eq(big.get_size(), calm.get_size(), "misma imagen: el pivote queda en el centro")


func test_dial_flash_lights_dial() -> void:
	var img: Image = RiutashDial.render(0.25, 0, true)
	assert_eq(img.get_pixel(RiutashDial.CENTER, RiutashDial.CENTER + 2), RiutashDial.FLASH_DIAL)
