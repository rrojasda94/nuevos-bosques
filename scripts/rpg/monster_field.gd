class_name MonsterField
extends Node2D
## Monstruos del área visible (monstruos.md, mision-ofomni.md): los Botarramas de los tramos de
## frontera del chunk actual (también los apostados en el chunk vecino, que se ven en la franja) y
## el Ofomni si está en este chunk. Cada fotograma los hace pensar, apunta dónde se han visto
## (GameState.seen_monsters, para el mapa) y avisa con `engaged` cuando uno alcanza al jugador.
## Se pausa con el árbol (menús, combate, diálogos, mapa). Las casillas son de área (relativas al
## chunk actual). No abre menús ni combates: eso lo decide la exploración.

signal engaged(monster: OverworldMonster)

const BOTARRAMAS: StringName = &"botarramas"
const OFOMNI: StringName = &"ofomni"
## Tamaño del placeholder procedural en píxeles (sin PNG): Botarramas algo mayor que una casilla;
## el Ofomni, el doble. Con PNG manda el tamaño del PNG (16x24 y 32x32).
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
var player: PlayerWalker

var _monsters: Array[OverworldMonster] = []
var _coord: Vector2i = Vector2i.ZERO
var _home: int = -1
var _textures: Dictionary = {}


func clear() -> void:
	for m: OverworldMonster in _monsters:
		m.queue_free()
	_monsters.clear()


## Coloca los Botarramas de los tramos del chunk `coord`. `chunk_at`: (Vector2i chunk) -> ChunkData.
func populate(bosques: BosqueMap, home: int, coord: Vector2i, chunk_at: Callable) -> void:
	clear()
	_coord = coord
	_home = home
	var cfg: Dictionary = AdventureRules.monster_config(BOTARRAMAS)
	for p: Dictionary in BotarramasPosts.posts_near(bosques, GameState.seed_value, home, coord):
		var chunk: ChunkData = chunk_at.call(p.chunk)
		var offset: Vector2i = (p.chunk - coord) * ChunkData.SIZE
		var at: Vector2i = offset + BotarramasPosts.post_cell(chunk, GameState.seed_value, p.side, int(cfg.post_depth))
		var axis: Vector2i = Vector2i.DOWN if p.side.x != 0 else Vector2i.RIGHT
		var tex: Texture2D = _texture(UnicoArt.Kind.BOTARRAMAS, bosques.styles[p.bosque_id], BOTARRAMAS_PX)
		_add(BOTARRAMAS, p.id, p.bosque_id, at, Rect2i(offset, Vector2i(ChunkData.SIZE, ChunkData.SIZE)), axis, cfg, tex,
			UnicoArt.frames_for(UnicoArt.Kind.BOTARRAMAS))


## Pone al Ofomni en el chunk actual cerca de `cell`, a OFOMNI_MIN_GAP o más del jugador.
func spawn_ofomni(quest_key: String, cell: Vector2i, chunk: ChunkData, style: Dictionary) -> void:
	if ofomni() != null:
		return
	var cfg: Dictionary = AdventureRules.monster_config(OFOMNI)
	var at: Vector2i = _free_cell_near(cell, chunk)
	var tex: Texture2D = _texture(UnicoArt.Kind.EYES, style, OFOMNI_PX)
	var m: OverworldMonster = _add(OFOMNI, quest_key, -1, at, Rect2i(Vector2i.ZERO, Vector2i(ChunkData.SIZE, ChunkData.SIZE)),
		Vector2i.RIGHT, cfg, tex, UnicoArt.frames_for(UnicoArt.Kind.EYES))
	m.cooldown = float(cfg.engage_cooldown)


func remove_ofomni() -> void:
	var m: OverworldMonster = ofomni()
	if m != null:
		_monsters.erase(m)
		m.queue_free()


func ofomni() -> OverworldMonster:
	for m: OverworldMonster in _monsters:
		if m.monster_id == OFOMNI:
			return m
	return null


## Hay un monstruo en la casilla (bloquea al jugador).
func occupied(c: Vector2i) -> bool:
	for m: OverworldMonster in _monsters:
		if m.cell == c:
			return true
	return false


## Algún monstruo persigue ahora al jugador (el borde no abre el menú: lo abrirá el encuentro).
func has_chaser() -> bool:
	for m: OverworldMonster in _monsters:
		if m.state == MonsterSteering.State.CHASE and _can_detect(m) and m.cooldown <= 0.0:
			return true
	return false


## Puede ver al jugador: el Ofomni siempre; un Botarramas, solo si su Bosque sigue cerrado.
func _can_detect(m: OverworldMonster) -> bool:
	return m.bosque_id < 0 or not AdventureRules.is_passable(m.bosque_id, _home)


func _process(delta: float) -> void:
	if player == null:
		return
	for m: OverworldMonster in _monsters:
		m.think(delta, player.cell, _can_detect(m), func(c: Vector2i) -> bool: return _is_free(c, m))
		_note_seen(m)
	if not can_engage.call():
		return
	for m: OverworldMonster in _monsters:
		if m.cooldown <= 0.0 and MonsterSteering.engages(m.cell, player.cell, _can_detect(m), m.cfg):
			engaged.emit(m)
			return


func _is_free(c: Vector2i, me: OverworldMonster) -> bool:
	if c == player.cell or not area_walkable.call(c):
		return false
	for m: OverworldMonster in _monsters:
		if m != me and m.cell == c:
			return false
	return true


## Última posición vista de cada Botarramas, en chunk global (mapa con M).
func _note_seen(m: OverworldMonster) -> void:
	if m.monster_id != BOTARRAMAS:
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


func _texture(kind: UnicoArt.Kind, style: Dictionary, px: int) -> Texture2D:
	var k: String = "%d:%d:%d:%d" % [kind, int(style.get("leaf", 0)), int(style.get("trunk", 0)), px]
	if not _textures.has(k):
		var sheet: Texture2D = UnicoArt.sprite_sheet(kind, style)
		_textures[k] = sheet if sheet != null else UnicoArt.texture(kind, style, px)
	return _textures[k]
