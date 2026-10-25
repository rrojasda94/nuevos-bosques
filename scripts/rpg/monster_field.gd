class_name MonsterField
extends Node2D
## Monstruos del área visible (monstruos.md, mision-ofomni.md): los Botarramas de los tramos de
## frontera del chunk actual (también los apostados en el chunk vecino, que se ven en la franja),
## los Únicos que rondan por dentro del Bosque (BosquePatrols) y el Ofomni descarriado de la misión
## si está en este chunk. Cada fotograma los hace pensar, apunta dónde se han visto
## (GameState.seen_monsters, para el mapa) y avisa con `engaged` cuando uno alcanza al jugador.
## Se pausa con el árbol (menús, combate, diálogos, mapa). Las casillas son de área (relativas al
## chunk actual). No abre menús ni combates: eso lo decide la exploración.
## El Bosque recuerda (0.3): los Botarramas de un Bosque forzado siguen activos y ven más lejos
## según su hostilidad (AdventureRules.vision_radius); solo pagar los vuelve pasivos.
## Cada monstruo tiene un papel (OverworldMonster.role):
## - ROLE_GUARDIAN: Botarramas de un tramo de frontera. Ve al jugador si su Bosque no está pagado.
## - ROLE_QUEST: el Ofomni descarriado. Siempre ve.
## - ROLE_PATROL: Único que ronda dentro de su Bosque (Botarramas, Ofomni o Aledra, esta solo de
##   noche). Mira pasar al jugador; si el Bosque no está pagado, le persigue si le ve.
## - ROLE_CHASER: Ofomni que persigue tras un robo (OfomniGuard). Siempre ve, aunque el Bosque esté
##   pagado.
## - ROLE_HUNTER: Único que el Bosque envía mientras estás dentro sin pagar (BosqueHunt).
## - ROLE_CAPTOR: Ofomni del Bosque natal que devuelve al Adoc a la villa. Solo se ve.
## Estados de Bosque (BosqueStates): en un Bosque corrupto pagado, un Único que ronda a veces ataca
## igual (emboscada, por Momento); en uno muerto, el Único que ronda a veces va por su cuenta y te
## sale al paso a pedir Luz (la exploración pregunta; pagarle lo deja satisfecho este Momento); en
## uno que necesita ayuda, sus Únicos son amistosos.
## Sigilo (Stealth): el camuflaje del Adoc se resta a la visión de todos (guardian_config,
## inner_config; se recalcula al equipar o desequipar y cuando se rompe o vuelve). Cuando uno que
## puede detectarle empieza a perseguirle o se le echa encima mientras va oculto (`is_hidden`),
## avisa con `spotted` (la exploración rompe el camuflaje) y tarda Stealth.seen_grace en empezar el
## encuentro. Con el arma en la mano, los de un Bosque pagado (salvo el natal) le tratan como a
## quien no ha pagado (AdventureRules.is_welcome).
## Los perseguidores, cazadores y captores no se guardan; sus Ofomni llevan un aura de Luz que los
## distingue del descarriado. Ninguno de los que van por dentro sale del chunk (de su Bosque).

signal engaged(monster: OverworldMonster)
## Un monstruo que puede detectar al Adoc le ha visto mientras iba oculto (empieza a perseguirle o se
## le echa encima). La exploración decide si rompe el camuflaje.
signal spotted(monster: OverworldMonster)

const BOTARRAMAS: StringName = &"botarramas"
## Ofomni de un Bosque con Nujio (apaciguable).
const OFOMNI: StringName = &"ofomni"
## Ofomni descarriado de la misión (no acepta pagos). spawn_ofomni, ofomni() y remove_ofomni son suyos.
const OFOMNI_DESCARRIADO: StringName = &"ofomni_descarriado"
## Aledra: serpiente que solo ronda de noche y es fatal de noche (monstruos.md).
const ALEDRA: StringName = &"aledra"

const ROLE_GUARDIAN: StringName = &"guardian"
const ROLE_QUEST: StringName = &"quest"
const ROLE_PATROL: StringName = &"patrol"
const ROLE_CHASER: StringName = &"chaser"
const ROLE_HUNTER: StringName = &"hunter"
const ROLE_CAPTOR: StringName = &"captor"

## Tamaño del placeholder procedural en píxeles (sin PNG): Botarramas algo mayor que una casilla;
## el Ofomni y Aledra, el doble. Con PNG manda el tamaño del PNG (16x24 y 32x32).
const BOTARRAMAS_PX: int = 22
const OFOMNI_PX: int = 32
## Distancia mínima al jugador al colocar al Ofomni.
const OFOMNI_MIN_GAP: int = 6
## Se cuenta como visto si está a esta distancia del jugador (aprox. media pantalla).
const SEEN_RANGE := Vector2i(10, 6)

## (Vector2i área) -> bool: terreno transitable (con NPC) dentro del área dibujada.
var area_walkable: Callable = func(_c: Vector2i) -> bool: return false
## () -> bool: se puede empezar un encuentro (sin fundido de entrada en curso).
var can_engage: Callable = func() -> bool: return true
## () -> bool: el Adoc va oculto (camuflado, o colado sin que le hayan visto): ver o alcanzarle
## emite `spotted`.
var is_hidden: Callable = func() -> bool: return false
var player: PlayerWalker

var _monsters: Array[OverworldMonster] = []
var _coord: Vector2i = Vector2i.ZERO
var _home: int = -1
var _textures: Dictionary = {}
## Contador para las claves de los monstruos que no se guardan.
var _serial: int = 0
var _bosques: BosqueMap
var _chunk: ChunkData
## Únicos independientes (Bosque muerto) ya pagados: "clave:riutash" -> true. No se guarda.
var _satisfied: Dictionary = {}


func _ready() -> void:
	# Equipar o quitarse una máscara, un talismán o el arma cambia lo que ven los Únicos.
	EventBus.item_equipped.connect(func(_s: StringName, _id: StringName) -> void: refresh_vision())
	EventBus.item_unequipped.connect(func(_s: StringName, _id: StringName) -> void: refresh_vision())
	EventBus.item_broken.connect(func(_id: StringName) -> void: refresh_vision())


func clear() -> void:
	for m: OverworldMonster in _monsters:
		m.queue_free()
	_monsters.clear()


## Coloca los Botarramas de los tramos del chunk `coord` y los Únicos que rondan por él.
## `chunk_at`: (Vector2i chunk) -> ChunkData.
func populate(bosques: BosqueMap, home: int, coord: Vector2i, chunk_at: Callable) -> void:
	clear()
	_coord = coord
	_home = home
	_bosques = bosques
	_chunk = chunk_at.call(coord)
	var cfg: Dictionary = AdventureRules.monster_config(BOTARRAMAS)
	for p: Dictionary in BotarramasPosts.posts_near(bosques, GameState.seed_value, home, coord):
		if GameState.defeated_monsters.has(String(p.id)):
			continue
		var chunk: ChunkData = chunk_at.call(p.chunk)
		var offset: Vector2i = (p.chunk - coord) * ChunkData.SIZE
		var at: Vector2i = offset + BotarramasPosts.post_cell(chunk, GameState.seed_value, p.side, int(cfg.post_depth))
		var axis: Vector2i = Vector2i.DOWN if p.side.x != 0 else Vector2i.RIGHT
		var m: OverworldMonster = _add(BOTARRAMAS, p.id, p.bosque_id, at, Rect2i(offset, Vector2i(ChunkData.SIZE, ChunkData.SIZE)),
			axis, guardian_config(cfg, int(p.bosque_id)), _texture_for(BOTARRAMAS, bosques.styles[p.bosque_id], false),
			UnicoArt.frames_for(UnicoArt.Kind.BOTARRAMAS))
		m.role = ROLE_GUARDIAN
	sync_patrols()


## Pone o quita los Únicos que rondan el chunk actual según el Momento (Aledra solo de noche): al
## anochecer aparece, al amanecer se va. Los vencidos no vuelven.
func sync_patrols() -> void:
	if _bosques == null or _chunk == null:
		return
	var wanted: Dictionary = {}
	for p: Dictionary in BosquePatrols.patrols_in(_bosques, GameState.seed_value, _coord, GameState.clock_momento):
		if not GameState.defeated_monsters.has(String(p.id)):
			wanted[String(p.id)] = p
	for m: OverworldMonster in _monsters.duplicate():
		if m.role == ROLE_PATROL and not wanted.has(m.key) and m.state != MonsterSteering.State.CHASE:
			_monsters.erase(m)
			_fade_out(m, false)
	for m: OverworldMonster in _monsters:
		wanted.erase(m.key)
	for key: String in wanted:
		var p: Dictionary = wanted[key]
		var at: Vector2i = BosquePatrols.post_cell(_chunk, GameState.seed_value, key, func(c: Vector2i) -> bool: return _is_free(c, null))
		if at.x < 0:
			continue
		var id: StringName = p.monster
		var m: OverworldMonster = _add(id, key, int(p.bosque_id), at, Rect2i(Vector2i.ZERO, Vector2i(ChunkData.SIZE, ChunkData.SIZE)),
			Vector2i.RIGHT if ChunkGenerator.hash_ints([key.hash()]) % 2 == 0 else Vector2i.DOWN,
			inner_config(id, ROLE_PATROL), _texture_for(id, _bosques.styles[int(p.bosque_id)], id == OFOMNI), _frames_for(id))
		m.role = ROLE_PATROL


## Copia de la configuración de un Botarramas con la visión de la hostilidad de su Bosque. La correa
## nunca es menor que la visión: si no, perdería al jugador nada más verlo.
static func guardian_config(base: Dictionary, bosque_id: int) -> Dictionary:
	var cfg: Dictionary = base.duplicate()
	cfg.vision_radius = AdventureRules.vision_radius(bosque_id, int(base.vision_radius))
	cfg.leash = maxi(int(base.leash), int(cfg.vision_radius))
	return cfg


## Configuración de un Único que va por dentro del Bosque (ronda, persigue o caza): no sale del
## chunk (max_outside 0); la correa cubre el chunk para que no suelte al jugador dentro de él; al
## rondar usa patrol_wander si sus datos lo tienen.
static func inner_config(monster_id: StringName, role: StringName) -> Dictionary:
	var cfg: Dictionary = AdventureRules.monster_config(monster_id).duplicate()
	# Su visión, menos el camuflaje del Adoc (Stealth).
	cfg.vision_radius = Stealth.vision_against(int(cfg.get("vision_radius", 0)), Stealth.camouflage())
	cfg.max_outside = 0
	cfg.leash = maxi(int(cfg.get("leash", 0)), ChunkData.SIZE)
	if role == ROLE_PATROL:
		cfg.idle_wander = int(cfg.get("patrol_wander", cfg.get("idle_wander", 0)))
	return cfg


## Vuelve a calcular la visión de todos: la de los Botarramas de frontera con la hostilidad de su
## Bosque (tras una victoria ha subido) y la de todos con el camuflaje del Adoc (al equipar algo, o
## cuando se rompe o vuelve). El Ofomni descarriado no la cambia: su misión va aparte del sigilo.
func refresh_vision() -> void:
	var base: Dictionary = AdventureRules.monster_config(BOTARRAMAS)
	for m: OverworldMonster in _monsters:
		match m.role:
			ROLE_GUARDIAN:
				m.cfg = guardian_config(base, m.bosque_id)
			ROLE_PATROL, ROLE_CHASER, ROLE_HUNTER:
				m.cfg = inner_config(m.monster_id, m.role)


## Pone al Ofomni descarriado en el chunk actual cerca de `cell`, a OFOMNI_MIN_GAP o más del jugador.
func spawn_ofomni(quest_key: String, cell: Vector2i, chunk: ChunkData, style: Dictionary) -> void:
	if ofomni() != null:
		return
	var cfg: Dictionary = AdventureRules.monster_config(OFOMNI_DESCARRIADO)
	var at: Vector2i = _free_cell_near(cell, chunk)
	var tex: Texture2D = _texture(UnicoArt.Kind.EYES, style, OFOMNI_PX)
	var m: OverworldMonster = _add(OFOMNI_DESCARRIADO, quest_key, -1, at, Rect2i(Vector2i.ZERO, Vector2i(ChunkData.SIZE, ChunkData.SIZE)),
		Vector2i.RIGHT, cfg, tex, UnicoArt.frames_for(UnicoArt.Kind.EYES))
	m.role = ROLE_QUEST
	m.cooldown = float(cfg.engage_cooldown)


func remove_ofomni() -> void:
	var m: OverworldMonster = ofomni()
	if m != null:
		_monsters.erase(m)
		m.queue_free()


## El monstruo vencido vuelve a la Luz del Bosque: se desvanece en un destello. Los de puesto fijo
## (Botarramas de frontera, Únicos que rondan) se apuntan como vencidos y no reaparecen; los
## perseguidores y cazadores no se guardan.
func dissolve(m: OverworldMonster) -> void:
	if m == null or not _monsters.has(m):
		return
	_monsters.erase(m)
	if is_persistent(m):
		GameState.defeated_monsters.append(m.key)
	refresh_vision()
	_fade_out(m, true)


static func is_persistent(m: OverworldMonster) -> bool:
	return m.role == ROLE_GUARDIAN or m.role == ROLE_PATROL or m.role == ROLE_QUEST


func _fade_out(m: OverworldMonster, flash: bool) -> void:
	var tween: Tween = m.create_tween()
	if flash:
		tween.tween_property(m, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.15)
	tween.tween_property(m, "modulate:a", 0.0, 0.45)
	tween.tween_callback(m.queue_free)


## Pone perseguidores (Ofomni, ROLE_CHASER) del Bosque `bosque_id` en `cells` (de área, dentro del
## chunk actual), ya persiguiendo al jugador. Sin enfriamiento: aparecen fuera de la vista.
func spawn_chasers(bosque_id: int, cells: Array[Vector2i], style: Dictionary) -> void:
	for at: Vector2i in cells:
		_spawn_inner(OFOMNI, ROLE_CHASER, bosque_id, at, style)


## Pone un cazador del Bosque (BosqueHunt) en `at`, ya persiguiendo.
func spawn_hunter(monster_id: StringName, bosque_id: int, at: Vector2i, style: Dictionary) -> OverworldMonster:
	return _spawn_inner(monster_id, ROLE_HUNTER, bosque_id, at, style)


## Pone captores del Bosque `bosque_id` (primera misión) en `cells`: se ven, pero no persiguen.
func spawn_captors(bosque_id: int, cells: Array[Vector2i], style: Dictionary) -> void:
	for at: Vector2i in cells:
		_spawn_inner(OFOMNI, ROLE_CAPTOR, bosque_id, at, style)


func _spawn_inner(monster_id: StringName, role: StringName, bosque_id: int, at: Vector2i, style: Dictionary) -> OverworldMonster:
	_serial += 1
	var m: OverworldMonster = _add(monster_id, "%s_%d" % [role, _serial], bosque_id, at,
		Rect2i(Vector2i.ZERO, Vector2i(ChunkData.SIZE, ChunkData.SIZE)), Vector2i.RIGHT, inner_config(monster_id, role),
		_texture_for(monster_id, style, monster_id == OFOMNI), _frames_for(monster_id))
	m.role = role
	if role != ROLE_CAPTOR:
		m.state = MonsterSteering.State.CHASE
	return m


## Monstruos del área con ese papel.
func with_role(role: StringName) -> Array[OverworldMonster]:
	var out: Array[OverworldMonster] = []
	for m: OverworldMonster in _monsters:
		if m.role == role:
			out.append(m)
	return out


## Ofomni perseguidores tras un robo.
func chasers() -> Array[OverworldMonster]:
	return with_role(ROLE_CHASER)


func hunters() -> Array[OverworldMonster]:
	return with_role(ROLE_HUNTER)


## Quita (desvaneciéndose) a los monstruos con esos papeles. No cuentan como vencidos.
func remove_roles(roles: Array[StringName]) -> void:
	for m: OverworldMonster in _monsters.duplicate():
		if roles.has(m.role):
			_monsters.erase(m)
			_fade_out(m, false)


## Casilla libre para un Único que aparece: alcanzable en el chunk actual y sin nadie.
func can_place(c: Vector2i, chunk: ChunkData) -> bool:
	return chunk.is_reachable(c) and _is_free(c, null)


func ofomni() -> OverworldMonster:
	for m: OverworldMonster in _monsters:
		if m.monster_id == OFOMNI_DESCARRIADO:
			return m
	return null


## Monstruo en la casilla `c` (sin los captores), o null.
func monster_at(c: Vector2i) -> OverworldMonster:
	for m: OverworldMonster in _monsters:
		if m.cell == c and m.role != ROLE_CAPTOR:
			return m
	return null


## Hay un monstruo que bloquea la casilla. Los pasivos (Botarramas de un Bosque ya abierto) se
## apartan: no cierran el paso.
func occupied(c: Vector2i) -> bool:
	for m: OverworldMonster in _monsters:
		if m.cell == c and can_detect(m):
			return true
	return false


## Algún guardián de frontera (o el descarriado) persigue ahora al jugador: el borde no abre el
## menú, lo abrirá el encuentro. Los que van por dentro del Bosque no cuentan: no guardan bordes.
func has_chaser() -> bool:
	for m: OverworldMonster in _monsters:
		if (m.role == ROLE_GUARDIAN or m.role == ROLE_QUEST) and m.state == MonsterSteering.State.CHASE \
				and can_detect(m) and m.cooldown <= 0.0:
			return true
	return false


## Puede ver al jugador (y por tanto perseguirle y alcanzarle): el descarriado y los perseguidores
## por robo siempre (el robo va aparte del peaje); los captores, nunca; los guardianes, los que
## rondan y los cazadores, mientras su Bosque no esté pagado (cerrado o forzado: el Bosque recuerda)
## o el Adoc lleve el arma en la mano (salvo en el natal, y salvo los amistosos).
func can_detect(m: OverworldMonster) -> bool:
	match m.role:
		ROLE_CAPTOR:
			return false
		ROLE_QUEST, ROLE_CHASER:
			return true
	if m.bosque_id < 0:
		return true
	var state: String = BosqueStates.state_of(m.bosque_id, _bosques)
	if BosqueStates.has_friendly_unicos(state):
		return false
	if AdventureRules.is_armed_against(m.bosque_id, _home):
		return true
	if m.role == ROLE_PATROL and m.bosque_id != _home:
		if state == BosqueStates.MUERTO:
			return is_independent(m)
		if state == BosqueStates.CORRUPTO and AdventureRules.is_paid(m.bosque_id, _home) 				and BosqueStates.ambushes(GameState.seed_value, m.key, GameState.riutash_count, state):
			return true
	return not AdventureRules.is_paid(m.bosque_id, _home)


## Algún Único del Bosque `bosque_id` mira la casilla `cell`: está a su visión (ya con el
## camuflaje) o a su distancia de encuentro, lo pueda perseguir o no (los que rondan un Bosque
## pagado también miran). Para el robo camuflado (OfomniGuard.is_alerted).
func is_watched(bosque_id: int, cell: Vector2i) -> bool:
	for m: OverworldMonster in _monsters:
		if m.bosque_id != bosque_id or m.role == ROLE_CAPTOR:
			continue
		var reach: int = maxi(int(m.cfg.get("vision_radius", 0)), int(m.cfg.get("engage_distance", 1)))
		if MonsterSteering.chebyshev(m.cell, cell) <= reach:
			return true
	return false


## Único de un Bosque muerto que este Momento va por su cuenta y pide Luz (y no se le ha pagado).
func is_independent(m: OverworldMonster) -> bool:
	if m == null or m.role != ROLE_PATROL or m.bosque_id < 0:
		return false
	var state: String = BosqueStates.state_of(m.bosque_id, _bosques)
	return BosqueStates.is_independent(GameState.seed_value, m.key, GameState.riutash_count, state) 		and not _satisfied.has(_satisfied_key(m))


## Se le pagó la Luz que pedía: deja de salir al paso este Momento.
func satisfy(m: OverworldMonster) -> void:
	_satisfied[_satisfied_key(m)] = true


static func _satisfied_key(m: OverworldMonster) -> String:
	return "%s:%d" % [m.key, GameState.riutash_count]


func _process(delta: float) -> void:
	if player == null:
		return
	for m: OverworldMonster in _monsters.duplicate():
		var was_chasing: bool = m.state == MonsterSteering.State.CHASE
		m.think(delta, player.cell, can_detect(m), func(c: Vector2i) -> bool: return _is_free(c, m))
		_note_seen(m)
		# Le ha visto (el camuflaje no basta) y empieza a perseguirle.
		if not was_chasing and m.state == MonsterSteering.State.CHASE and can_spot(m) and is_hidden.call():
			spotted.emit(m)
	if not can_engage.call():
		return
	for m: OverworldMonster in _monsters:
		if m.cooldown > 0.0 or m.engage_delay > 0.0 or not MonsterSteering.engages(m.cell, player.cell, can_detect(m), m.cfg):
			continue
		# Oculto, pero se le ha echado encima: le ve igualmente y tarda un instante en atacar.
		if can_spot(m) and is_hidden.call():
			spotted.emit(m)
			if m.engage_delay > 0.0:
				continue
		engaged.emit(m)
		return


## Puede romper el camuflaje al ver al Adoc: los que guardan, rondan o cazan en su Bosque.
static func can_spot(m: OverworldMonster) -> bool:
	return m.role == ROLE_GUARDIAN or m.role == ROLE_PATROL or m.role == ROLE_HUNTER


func _is_free(c: Vector2i, me: OverworldMonster) -> bool:
	if c == player.cell or not area_walkable.call(c):
		return false
	for m: OverworldMonster in _monsters:
		if m != me and m.cell == c:
			return false
	return true


## Última posición vista de cada Botarramas de frontera, en chunk global (mapa con M).
func _note_seen(m: OverworldMonster) -> void:
	if m.role != ROLE_GUARDIAN:
		return
	var d: Vector2i = (m.cell - player.cell).abs()
	if d.x > SEEN_RANGE.x or d.y > SEEN_RANGE.y:
		return
	var chunk: Vector2i = _coord + Vector2i(floori(m.cell.x / float(ChunkData.SIZE)), floori(m.cell.y / float(ChunkData.SIZE)))
	var entry: Dictionary = { "monster": String(m.monster_id), "bosque_id": m.bosque_id, "chunk": [chunk.x, chunk.y] }
	if GameState.seen_monsters.get(m.key, {}) != entry:
		GameState.seen_monsters[m.key] = entry


func _free_cell_near(cell: Vector2i, chunk: ChunkData) -> Vector2i:
	var best: Vector2i = cell
	var best_score: int = 1 << 30
	for y: int in ChunkData.SIZE:
		for x: int in ChunkData.SIZE:
			var c := Vector2i(x, y)
			if MonsterSteering.chebyshev(c, player.cell) < OFOMNI_MIN_GAP or not chunk.is_reachable(c) or not _is_free(c, null):
				continue
			var score: int = MonsterSteering.chebyshev(c, cell) * 10_000 + y * 100 + x
			if score < best_score:
				best_score = score
				best = c
	return best


func _add(id: StringName, monster_key: String, bosque_id: int, at: Vector2i, rect: Rect2i, axis: Vector2i,
		cfg: Dictionary, tex: Texture2D, frames: int = 1) -> OverworldMonster:
	var m := OverworldMonster.new()
	m.setup(id, monster_key, bosque_id, at, rect, axis, cfg, tex, frames)
	add_child(m)
	_monsters.append(m)
	return m


## Textura de un monstruo por id, con los colores de su Bosque. `aura`: los Ofomni que sirven a su
## Bosque llevan el aura de Luz (UnicoArt.with_aura).
func _texture_for(monster_id: StringName, style: Dictionary, aura: bool) -> Texture2D:
	var kind: UnicoArt.Kind = UnicoArt.kind_for(monster_id)
	return _texture(kind, style, BOTARRAMAS_PX if kind == UnicoArt.Kind.BOTARRAMAS else OFOMNI_PX, aura)


func _frames_for(monster_id: StringName) -> int:
	return UnicoArt.frames_for(UnicoArt.kind_for(monster_id))


## Textura del monstruo con los colores de su Bosque. `aura`: con el aura de Luz (UnicoArt.with_aura).
func _texture(kind: UnicoArt.Kind, style: Dictionary, px: int, aura: bool = false) -> Texture2D:
	var k: String = "%d:%d:%d:%d:%s" % [kind, int(style.get("leaf", 0)), int(style.get("trunk", 0)), px, aura]
	if not _textures.has(k):
		var sheet: Texture2D = UnicoArt.sprite_sheet(kind, style)
		var tex: Texture2D = sheet if sheet != null else UnicoArt.texture(kind, style, px)
		_textures[k] = UnicoArt.with_aura(tex) if aura else tex
	return _textures[k]
