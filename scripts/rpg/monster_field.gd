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
## - ROLE_DUEL: rival de otro adoc (AdocEncounters): está a punto de pelear con él y no hace caso al
##   jugador. Con E se le ayuda.
## Grupos de reparep (BosquePatrols.reparep_group_of): un solo monstruo con `count` y un icono de
## varios cangrejos (UnicoArt.group_texture); su encuentro es un combate contra todo el grupo. No son
## Únicos del Bosque (outsider): en los Bosques muertos o que necesitan ayuda atacan siempre.
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
##
## Mundo 2.0 (ADR 0014 §2 "Monstruos" y "Encuentros", §7; populate_world): mundo continuo, todo en
## `world_cell`. Los monstruos de un chunk aparecen la primera vez que entra en los chunks activos
## (el del jugador y sus 8 vecinos, WorldStreamer.ACTIVE_RADIUS) y ya no se borran: al salir del
## anillo se duermen (OverworldMonster.set_asleep) sin perder estado, y al volver despiertan donde
## estaban. Se mueven en continuo (OverworldMonster.think_world); el encuentro es por píxeles entre
## las cajas de los pies (WorldEncounters, `engage_px`) y no a través de un risco. Los Botarramas
## se apostan solo en las puertas del RegionPlan (BotarramasPosts.posts_near_plan); si el jugador
## choca con el límite fuera de una puerta, acude el más cercano (summon_nearest). Los Únicos de la
## 0.3 (rondas, perseguidores, cazadores, captores, rivales y el Ofomni descarriado) son los mismos
## papeles, con la casilla en world_cell y su chunk como `home_rect`.
## ponytail: borrar en M17 la ruta vieja (populate, `player` PlayerWalker, casillas de área de 64).

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
const ROLE_DUEL: StringName = &"duel"
const REPAREP: StringName = &"reparep"

## Tamaño del placeholder procedural en píxeles (sin PNG): Botarramas algo mayor que una casilla;
## el Ofomni y Aledra, el doble. Con PNG manda el tamaño del PNG (16x24 y 32x32).
const BOTARRAMAS_PX: int = 22
const OFOMNI_PX: int = 32
## Distancia mínima al jugador al colocar al Ofomni.
const OFOMNI_MIN_GAP: int = 6
## Se cuenta como visto si está a esta distancia del jugador (aprox. media pantalla).
const SEEN_RANGE := Vector2i(10, 6)
## Sin casilla (búsquedas del Mundo 2.0).
const NO_CELL := Vector2i(-99999, -99999)

## (Vector2i área) -> bool: terreno transitable (con NPC) dentro del área dibujada.
var area_walkable: Callable = func(_c: Vector2i) -> bool: return false
## () -> bool: se puede empezar un encuentro (sin fundido de entrada en curso).
var can_engage: Callable = func() -> bool: return true
## () -> bool: el Adoc va oculto (camuflado, o colado sin que le hayan visto): ver o alcanzarle
## emite `spotted`.
var is_hidden: Callable = func() -> bool: return false
# ponytail: borrar en M17; el Mundo 2.0 usa world_player.
var player: PlayerWalker

## Mundo 2.0: jugador con movimiento libre. Con él, `area_walkable` recibe world_cell.
var world_player: PlayerController
## Mundo 2.0: (Vector2i world_cell) -> bool, colisión del terreno para el GridMover de los monstruos.
var terrain_blocked: Callable = func(_c: Vector2i) -> bool: return true
## Mundo 2.0: (Vector2i chunk) -> WorldChunk o null si no está cargado.
var chunk_at: Callable = func(_c: Vector2i) -> WorldChunk: return null

var _monsters: Array[OverworldMonster] = []
## Mundo 2.0 (populate_world): coordenadas globales, chunks activos y monstruos que duermen.
var _world: bool = false
var _plan: RegionPlan
## Chunk del jugador con el que se calcularon los chunks activos.
var _active_center: Vector2i = Vector2i(-99999, -99999)
## Chunks cuyos monstruos ya se pusieron (Vector2i -> true). No se repueblan.
var _populated: Dictionary = {}
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


## ponytail: borrar en M17 (exploración vieja por chunks de 64); el Mundo 2.0 usa populate_world.
## Coloca los Botarramas de los tramos del chunk `coord` y los Únicos que rondan por él.
## `get_chunk`: (Vector2i chunk) -> ChunkData.
func populate(bosques: BosqueMap, home: int, coord: Vector2i, get_chunk: Callable) -> void:
	clear()
	_world = false
	_coord = coord
	_home = home
	_bosques = bosques
	_chunk = get_chunk.call(coord)
	var cfg: Dictionary = AdventureRules.monster_config(BOTARRAMAS)
	for p: Dictionary in BotarramasPosts.posts_near(bosques, GameState.seed_value, home, coord):
		if GameState.defeated_monsters.has(String(p.id)):
			continue
		var chunk: ChunkData = get_chunk.call(p.chunk)
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
	if _world:
		_sync_patrols_world()
		return
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
			inner_config(id, ROLE_PATROL), _texture_for(id, _bosques.styles[int(p.bosque_id)], id == OFOMNI, int(p.get("count", 1))), _frames_for(id))
		m.role = ROLE_PATROL
		m.count = int(p.get("count", 1))


# --- Mundo 2.0 ------------------------------------------------------------------------------------

## Mundo 2.0: empieza el mundo continuo de la región del `plan`. Los monstruos aparecen por chunks
## activos alrededor de `world_player` (update_active, cada fotograma). `get_chunk`:
## (Vector2i chunk) -> WorldChunk o null (p. ej. WorldStreamer.chunk).
func populate_world(plan: RegionPlan, home: int, get_chunk: Callable) -> void:
	clear()
	_world = true
	_plan = plan
	_bosques = plan.bosques
	_home = home
	_chunk = null
	chunk_at = get_chunk
	_populated.clear()
	_active_center = Vector2i(-99999, -99999)


## Mundo 2.0: el chunk está en el anillo de chunks activos del jugador.
func is_active_chunk(chunk: Vector2i) -> bool:
	return WorldStreamer.chebyshev(chunk, _active_center) <= WorldStreamer.ACTIVE_RADIUS


## Mundo 2.0: chunks activos alrededor del chunk `center` (el del jugador y sus 8 vecinos).
func active_chunks(center: Vector2i) -> Array[Vector2i]:
	return WorldStreamer.chunk_ring(center, WorldStreamer.ACTIVE_RADIUS, _plan.size_chunks)


## Mundo 2.0: el jugador está en el chunk `center`. Pone los monstruos de los chunks activos que
## aún no los tenían (si ya están cargados; si no, en otra llamada), los Únicos que rondan según el
## Momento, y duerme o despierta a cada uno según su chunk.
func update_active(center: Vector2i) -> void:
	if not _world:
		return
	var moved: bool = center != _active_center
	_active_center = center
	var added: bool = false
	for c: Vector2i in active_chunks(center):
		if _populated.has(c):
			continue
		var wc: WorldChunk = chunk_at.call(c)
		if wc == null:
			continue
		_populated[c] = true
		_populate_guardians(c, wc)
		added = true
	if moved or added:
		_sync_patrols_world()
	for m: OverworldMonster in _monsters:
		m.set_asleep(not is_active_chunk(WorldCoords.world_cell_to_chunk(m.cell)))


func _chunk_rect(chunk: Vector2i) -> Rect2i:
	return Rect2i(chunk * WorldCoords.CHUNK, Vector2i(WorldCoords.CHUNK, WorldCoords.CHUNK))


## Rectángulo propio (max_outside) de un monstruo que aparece en `at`: su chunk (en world_cell) en el
## Mundo 2.0; el chunk actual en casillas de área en la exploración vieja.
func _home_rect(at: Vector2i) -> Rect2i:
	if _world:
		return _chunk_rect(WorldCoords.world_cell_to_chunk(at))
	return Rect2i(Vector2i.ZERO, Vector2i(ChunkData.SIZE, ChunkData.SIZE))


func _chunk_size() -> int:
	return WorldCoords.CHUNK if _world else ChunkData.SIZE


## Botarramas de las puertas que están en el chunk `c` (cada tramo con puerta tiene uno, en el lado
## del Bosque que guarda; posts_near_plan lo da desde los dos chunks del tramo).
func _populate_guardians(c: Vector2i, wc: WorldChunk) -> void:
	var cfg: Dictionary = AdventureRules.monster_config(BOTARRAMAS)
	for p: Dictionary in BotarramasPosts.posts_near_plan(_plan, GameState.seed_value, _home, c):
		if p.chunk != c or GameState.defeated_monsters.has(String(p.id)) or _find(String(p.id)) != null:
			continue
		var local: Vector2i = BotarramasPosts.post_cell_world(wc, _plan, p.side, int(cfg.post_depth))
		var at: Vector2i = WorldCoords.to_world_cell(c, local)
		var axis: Vector2i = Vector2i.DOWN if p.side.x != 0 else Vector2i.RIGHT
		var m: OverworldMonster = _add(BOTARRAMAS, p.id, p.bosque_id, at, _chunk_rect(c), axis,
			guardian_config(cfg, int(p.bosque_id)), _texture_for(BOTARRAMAS, _bosques.styles[p.bosque_id], false),
			UnicoArt.frames_for(UnicoArt.Kind.BOTARRAMAS))
		m.role = ROLE_GUARDIAN


## Únicos que rondan los chunks ya poblados según el Momento (como sync_patrols). Los de chunks sin
## cargar se ponen cuando se carguen.
func _sync_patrols_world() -> void:
	if _plan == null:
		return
	var wanted: Dictionary = {}
	for c: Vector2i in _populated:
		for p: Dictionary in BosquePatrols.patrols_in(_bosques, GameState.seed_value, c, GameState.clock_momento):
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
		var c: Vector2i = p.chunk
		var wc: WorldChunk = chunk_at.call(c)
		if wc == null:
			continue
		var local: Vector2i = BosquePatrols.post_cell_world(wc, GameState.seed_value, key,
			func(l: Vector2i) -> bool: return _is_free(WorldCoords.to_world_cell(c, l), null))
		if local.x < 0:
			continue
		var id: StringName = p.monster
		var m: OverworldMonster = _add(id, key, int(p.bosque_id), WorldCoords.to_world_cell(c, local), _chunk_rect(c),
			Vector2i.RIGHT if ChunkGenerator.hash_ints([key.hash()]) % 2 == 0 else Vector2i.DOWN,
			inner_config(id, ROLE_PATROL, WorldCoords.CHUNK),
			_texture_for(id, _bosques.styles[int(p.bosque_id)], id == OFOMNI, int(p.get("count", 1))), _frames_for(id))
		m.role = ROLE_PATROL
		m.count = int(p.get("count", 1))


## Monstruo con esa clave, o null.
func _find(monster_key: String) -> OverworldMonster:
	for m: OverworldMonster in _monsters:
		if m.key == monster_key:
			return m
	return null


## Mundo 2.0, cruce fuera de puerta (ADR 0014 §7): el jugador ha chocado con el límite del Bosque
## `bosque_id` en `world_cell` (BosqueBorder.contacted). Acude el Botarramas de ese Bosque más
## cercano (despierto o dormido): se aposta en la casilla libre de su Bosque más cercana al choque y
## persigue. Si está más lejos que su correa, aparece fuera de la vista del jugador, dentro de su
## correa desde ese puesto. Devuelve el que acude, o null si el Bosque no tiene ninguno cerca.
func summon_nearest(bosque_id: int, world_cell: Vector2i) -> OverworldMonster:
	if not _world:
		return null
	var best: OverworldMonster = null
	var best_d: int = 1 << 30
	for m: OverworldMonster in _monsters:
		if m.role != ROLE_GUARDIAN or m.bosque_id != bosque_id:
			continue
		var d: int = MonsterSteering.chebyshev(m.cell, world_cell)
		if d < best_d:
			best_d = d
			best = m
	if best == null:
		return null
	var post_at: Vector2i = _free_cell_of_bosque(world_cell, bosque_id, BotarramasPosts.SEARCH_RADIUS, best,
		func(_c: Vector2i) -> bool: return true)
	if post_at == NO_CELL:
		return null
	best.post = post_at
	best.home_rect = _chunk_rect(WorldCoords.world_cell_to_chunk(post_at))
	if MonsterSteering.chebyshev(best.cell, post_at) > int(best.cfg.leash):
		var player_cell: Vector2i = _player_cell()
		var out_of_view: Callable = func(c: Vector2i) -> bool:
			var off: Vector2i = (c - player_cell).abs()
			return off.x > SEEN_RANGE.x or off.y > SEEN_RANGE.y
		var arrive: Vector2i = _free_cell_of_bosque(post_at, bosque_id, int(best.cfg.leash), best, out_of_view)
		best.place_at(arrive if arrive != NO_CELL else post_at)
	best.state = MonsterSteering.State.CHASE
	best.cooldown = 0.0
	best.set_asleep(not is_active_chunk(WorldCoords.world_cell_to_chunk(best.cell)))
	return best


## Casilla libre del Bosque `bosque_id` más cercana a `center` (Chebyshev, empates por fila y
## columna) a `radius` o menos que cumpla `extra`. NO_CELL si no hay.
func _free_cell_of_bosque(center: Vector2i, bosque_id: int, radius: int, me: OverworldMonster, extra: Callable) -> Vector2i:
	var best: Vector2i = NO_CELL
	var best_score: int = 1 << 30
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var c: Vector2i = center + Vector2i(dx, dy)
			var chunk: Vector2i = WorldCoords.world_cell_to_chunk(c)
			if _plan.bosque_at(chunk) != bosque_id or not _is_free(c, me) or not extra.call(c):
				continue
			var wc: WorldChunk = chunk_at.call(chunk)
			if wc == null or not wc.is_reachable(WorldCoords.world_cell_to_cell(c)):
				continue
			var score: int = maxi(absi(dx), absi(dy)) * 1_000_000 + (dy + radius) * 1000 + (dx + radius)
			if score < best_score:
				best_score = score
				best = c
	return best


## Mundo 2.0: pone al Ofomni descarriado cerca de `world_cell` (en su chunk), a OFOMNI_MIN_GAP o más
## del jugador.
func spawn_ofomni_world(quest_key: String, world_cell: Vector2i, style: Dictionary) -> void:
	if ofomni() != null:
		return
	var cfg: Dictionary = AdventureRules.monster_config(OFOMNI_DESCARRIADO)
	var chunk: Vector2i = WorldCoords.world_cell_to_chunk(world_cell)
	var at: Vector2i = world_cell
	var best_score: int = 1 << 30
	var wc: WorldChunk = chunk_at.call(chunk)
	if wc != null:
		for i: int in WorldChunk.CELLS:
			var local: Vector2i = WorldCoords.index_to_cell(i)
			var c: Vector2i = WorldCoords.to_world_cell(chunk, local)
			if MonsterSteering.chebyshev(c, _player_cell()) < OFOMNI_MIN_GAP or not wc.is_reachable(local) or not _is_free(c, null):
				continue
			var score: int = MonsterSteering.chebyshev(c, world_cell) * 10_000 + local.y * 100 + local.x
			if score < best_score:
				best_score = score
				at = c
	var m: OverworldMonster = _add(OFOMNI_DESCARRIADO, quest_key, -1, at, _home_rect(at), Vector2i.RIGHT, cfg,
		_texture(UnicoArt.Kind.EYES, style, OFOMNI_PX), UnicoArt.frames_for(UnicoArt.Kind.EYES))
	m.role = ROLE_QUEST
	m.cooldown = float(cfg.engage_cooldown)


## Mundo 2.0: casilla libre para un Único que aparece en `world_cell`: alcanzable en su chunk
## (cargado) y sin nadie.
func can_place_world(world_cell: Vector2i) -> bool:
	var wc: WorldChunk = chunk_at.call(WorldCoords.world_cell_to_chunk(world_cell))
	return wc != null and wc.is_reachable(WorldCoords.world_cell_to_cell(world_cell)) and _is_free(world_cell, null)


## Mundo 2.0: hay encuentro con `m` ahora (sin enfriamientos): puede detectar, las cajas de los pies
## a su engage_px y sin un risco en medio (WorldEncounters).
func engages_world(m: OverworldMonster) -> bool:
	var box: Rect2 = world_player.mover.get_rect()
	return WorldEncounters.engages(m.get_rect(), box, can_detect(m), m.cfg) \
		and WorldEncounters.levels_linked(m.mover.cell, world_player.mover.cell, chunk_at, WorldEncounters.level_link_cells())


## Copia de la configuración de un Botarramas con la visión de la hostilidad de su Bosque. La correa
## nunca es menor que la visión: si no, perdería al jugador nada más verlo.
static func guardian_config(base: Dictionary, bosque_id: int) -> Dictionary:
	var cfg: Dictionary = base.duplicate()
	cfg.vision_radius = AdventureRules.vision_radius(bosque_id, int(base.vision_radius))
	cfg.leash = maxi(int(base.leash), int(cfg.vision_radius))
	return cfg


## Configuración de un Único que va por dentro del Bosque (ronda, persigue o caza): no sale del
## chunk (max_outside 0); la correa cubre el chunk para que no suelte al jugador dentro de él; al
## rondar usa patrol_wander si sus datos lo tienen. `chunk_size`: casillas por lado del chunk (64 en
## la exploración vieja, 80 en el Mundo 2.0).
static func inner_config(monster_id: StringName, role: StringName, chunk_size: int = ChunkData.SIZE) -> Dictionary:
	var cfg: Dictionary = AdventureRules.monster_config(monster_id).duplicate()
	# Su visión, menos el camuflaje del Adoc (Stealth).
	cfg.vision_radius = Stealth.vision_against(int(cfg.get("vision_radius", 0)), Stealth.camouflage())
	cfg.max_outside = 0
	cfg.leash = maxi(int(cfg.get("leash", 0)), chunk_size)
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
				m.cfg = inner_config(m.monster_id, m.role, _chunk_size())


## ponytail: borrar en M17 (ChunkData); el Mundo 2.0 usa spawn_ofomni_world.
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


## Pone al rival de un encuentro con otro adoc (ROLE_DUEL) en `at`: no persigue ni ataca al jugador.
func spawn_duel(e: Dictionary, at: Vector2i, style: Dictionary) -> OverworldMonster:
	var id: StringName = e.enemy
	var m: OverworldMonster = _add(id, "duel:%s" % e.id, int(e.bosque_id), at, _home_rect(at),
		Vector2i.RIGHT, inner_config(id, ROLE_DUEL, _chunk_size()), _texture_for(id, style, id == OFOMNI, int(e.count)), _frames_for(id))
	m.cfg.idle_wander = 0
	m.role = ROLE_DUEL
	m.count = int(e.count)
	m.encounter = e
	return m


## Quita al rival del encuentro con otro adoc (resuelto), sin contarlo como vencido.
func remove_duel(flash: bool = false) -> void:
	for m: OverworldMonster in with_role(ROLE_DUEL):
		_monsters.erase(m)
		_fade_out(m, flash)


func _spawn_inner(monster_id: StringName, role: StringName, bosque_id: int, at: Vector2i, style: Dictionary) -> OverworldMonster:
	_serial += 1
	var m: OverworldMonster = _add(monster_id, "%s_%d" % [role, _serial], bosque_id, at,
		_home_rect(at), Vector2i.RIGHT, inner_config(monster_id, role, _chunk_size()),
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


## ponytail: borrar en M17 (ChunkData); el Mundo 2.0 usa can_place_world.
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
		if m.cell == c and (can_detect(m) or m.role == ROLE_DUEL):
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
		ROLE_CAPTOR, ROLE_DUEL:
			return false
		ROLE_QUEST, ROLE_CHASER:
			return true
	if m.bosque_id < 0:
		return true
	var state: String = BosqueStates.state_of(m.bosque_id, _bosques)
	if AdventureRules.is_outsider(m.monster_id) and m.bosque_id != _home:
		# Los reparep no son del Bosque: donde no hay peaje que pagar (muerto, necesita ayuda), atacan.
		if BosqueStates.is_free(state):
			return true
		return AdventureRules.is_armed_against(m.bosque_id, _home) or not AdventureRules.is_paid(m.bosque_id, _home)
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


## Mundo 2.0: los GridMover van a 60 Hz, como el del jugador (ADR 0014 §2).
func _physics_process(delta: float) -> void:
	if _world and world_player != null:
		_process_world(delta)


func _process(delta: float) -> void:
	if _world:
		return
	# ponytail: borrar en M17 (exploración vieja por casillas).
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


## Mundo 2.0: un fotograma. Duerme o despierta según los chunks activos; solo piensan y encuentran
## los despiertos.
func _process_world(delta: float) -> void:
	var pc: Vector2i = world_player.mover.cell
	var ppos: Vector2 = world_player.mover.world_pos
	update_active(WorldCoords.world_cell_to_chunk(pc))
	for m: OverworldMonster in _monsters.duplicate():
		if m.asleep:
			continue
		var was_chasing: bool = m.state == MonsterSteering.State.CHASE
		m.think_world(delta, ppos, pc, can_detect(m), func(c: Vector2i) -> bool: return _is_free(c, m), terrain_blocked)
		_note_seen(m)
		if not was_chasing and m.state == MonsterSteering.State.CHASE and can_spot(m) and is_hidden.call():
			spotted.emit(m)
	if not can_engage.call():
		return
	for m: OverworldMonster in _monsters:
		if m.asleep or m.cooldown > 0.0 or m.engage_delay > 0.0 or not engages_world(m):
			continue
		if can_spot(m) and is_hidden.call():
			spotted.emit(m)
			if m.engage_delay > 0.0:
				continue
		engaged.emit(m)
		return


## Casilla del jugador (world_cell en el Mundo 2.0, de área en la exploración vieja).
func _player_cell() -> Vector2i:
	if world_player != null:
		return world_player.mover.cell
	return player.cell if player != null else Vector2i(-99999, -99999)


func _is_free(c: Vector2i, me: OverworldMonster) -> bool:
	if c == _player_cell() or not area_walkable.call(c):
		return false
	for m: OverworldMonster in _monsters:
		if m != me and m.cell == c:
			return false
	return true


## Última posición vista de cada Botarramas de frontera, en chunk global (mapa con M).
func _note_seen(m: OverworldMonster) -> void:
	if m.role != ROLE_GUARDIAN:
		return
	var d: Vector2i = (m.cell - _player_cell()).abs()
	if d.x > SEEN_RANGE.x or d.y > SEEN_RANGE.y:
		return
	var chunk: Vector2i = WorldCoords.world_cell_to_chunk(m.cell) if _world \
		else _coord + Vector2i(floori(m.cell.x / float(ChunkData.SIZE)), floori(m.cell.y / float(ChunkData.SIZE)))
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
	if _world:
		m.setup_world(id, monster_key, bosque_id, at, rect, axis, cfg, tex, frames)
	else:
		m.setup(id, monster_key, bosque_id, at, rect, axis, cfg, tex, frames)
	add_child(m)
	_monsters.append(m)
	return m


## Textura de un monstruo por id, con los colores de su Bosque. `aura`: los Ofomni que sirven a su
## Bosque llevan el aura de Luz (UnicoArt.with_aura).
## `count`: un grupo de reparep se dibuja como varios cangrejos juntos.
func _texture_for(monster_id: StringName, style: Dictionary, aura: bool, count: int = 1) -> Texture2D:
	var kind: UnicoArt.Kind = UnicoArt.kind_for(monster_id)
	if kind == UnicoArt.Kind.REPAREP:
		var k: String = "group:%d:%d:%d" % [int(style.get("leaf", 0)), int(style.get("trunk", 0)), count]
		if not _textures.has(k):
			_textures[k] = UnicoArt.group_texture(style, count, OFOMNI_PX)
		return _textures[k]
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
