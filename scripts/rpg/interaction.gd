class_name Interaction
extends RefCounted
## Qué hay al pulsar interact (E) en exploración (navegacion.md, mision-ofomni.md): un NPC, un
## letrero o un refugio. Mira primero la casilla de delante (cell + facing) y luego la propia,
## porque sobre los letreros y los refugios también se puede estar de pie.
## Lógica pura: no dibuja ni abre diálogos; la usa la exploración y los tests.

enum Kind { NONE, NPC, SIGN, REFUGE }


static func target_cell(cell: Vector2i, facing: Vector2i) -> Vector2i:
	return cell + facing


## Objetivo de la interacción: { "kind": Kind, "cell": Vector2i, "npc_id": StringName }.
## `npcs`: casilla -> id de NPC del chunk actual.
static func find(chunk: ChunkData, cell: Vector2i, facing: Vector2i, npcs: Dictionary) -> Dictionary:
	var ahead: Vector2i = target_cell(cell, facing)
	if npcs.has(ahead):
		return { "kind": Kind.NPC, "cell": ahead, "npc_id": npcs[ahead] }
	for c: Vector2i in [ahead, cell]:
		if not ChunkData.in_bounds(c):
			continue
		match chunk.get_tile(c):
			ChunkData.Tile.SIGN:
				return { "kind": Kind.SIGN, "cell": c, "npc_id": &"" }
			ChunkData.Tile.REFUGE:
				return { "kind": Kind.REFUGE, "cell": c, "npc_id": &"" }
	return { "kind": Kind.NONE, "cell": ahead, "npc_id": &"" }
