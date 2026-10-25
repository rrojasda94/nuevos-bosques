extends RefCounted
## ChunkBuilder falso para los tests de M10 (WorldCache, WorldPregen) mientras no existe el real
## (M6+). Determinista por (plan.seed_value, coord) y seguro entre hilos: solo lee el plan y crea
## su propio ruido y RNG. Imita la forma de un chunk real para que el tamaño en caché sea
## orientativo: relieve, agua y caminos de los bloques gruesos del plan (ceros en un plan vacío),
## variantes de hierba y decoración por manchas de ruido de baja frecuencia, árboles 2×2 en
## manchas, un letrero y la colisión derivada. No es el generador del juego.

const NOISE_FREQUENCY: float = 0.035


static func build(plan: RegionPlan, coord: Vector2i) -> WorldChunk:
	var n: int = WorldCoords.MACROS_PER_CHUNK
	var chunk := WorldChunk.new()
	chunk.seed_value = plan.seed_value
	chunk.coord = coord
	var chunk_seed: int = hash([plan.seed_value, coord.x, coord.y])
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed
	var noise := FastNoiseLite.new()
	noise.seed = plan.seed_value
	noise.frequency = NOISE_FREQUENCY
	var origin: Vector2i = coord * WorldCoords.CHUNK
	var height: PackedByteArray = plan.chunk_block("height", coord)
	var water: PackedByteArray = plan.chunk_block("water", coord)
	var roads: PackedByteArray = plan.chunk_block("roads", coord)
	var forest := PackedFloat32Array()
	forest.resize(WorldChunk.CELLS)
	for i: int in WorldChunk.CELLS:
		var cell: Vector2i = WorldCoords.index_to_cell(i)
		var macro: Vector2i = WorldCoords.cell_to_macro(cell)
		var m: int = macro.y * n + macro.x
		var world: Vector2i = origin + cell
		var v: float = noise.get_noise_2d(world.x, world.y)
		forest[i] = v
		chunk.level[i] = mini(height[m], WorldChunk.MAX_LEVEL)
		if water[m] != 0:
			chunk.ground[i] = WorldChunk.Ground.LAKE if water[m] >= 3 else WorldChunk.Ground.RIVER_NARROW
		elif roads[m] != 0:
			chunk.ground[i] = WorldChunk.Ground.ROAD
		elif v < -0.45:
			chunk.ground[i] = WorldChunk.Ground.ROCKY
		else:
			chunk.ground[i] = WorldChunk.Ground.GRASS
		chunk.variant[i] = clampi(int((noise.get_noise_2d(world.y * 0.5, world.x * 0.5) + 1.0) * 2.0), 0, 3)
		if macro.y + 1 < n and height[m] > height[m + n] and cell.y % WorldCoords.MACRO >= WorldCoords.MACRO - 2:
			chunk.cliff[i] = WorldChunk.Cliff.FACE
		elif v > 0.0 and v < 0.25 and rng.randi_range(0, 5) == 0:
			chunk.decor[i] = rng.randi_range(1, 16)
	for y: int in range(0, WorldCoords.CHUNK - 1, 2):
		for x: int in range(0, WorldCoords.CHUNK - 1, 2):
			var cell := Vector2i(x + rng.randi_range(0, 1), y)
			if not WorldChunk.in_bounds(cell + Vector2i.ONE):
				continue
			var i: int = WorldCoords.cell_index(cell)
			if forest[i] > 0.3 and chunk.ground[i] == WorldChunk.Ground.GRASS and chunk.cliff[i] == 0:
				chunk.add_object(WorldChunk.ObjectKind.TREE, cell, Vector2i(2, 2), rng.randi_range(0, 7))
	chunk.hub = Vector2i(rng.randi_range(20, 59), rng.randi_range(20, 59))
	chunk.add_sign(chunk.hub + Vector2i.RIGHT, WorldChunk.SignKind.BOSQUE_VILLA, Vector2i.LEFT)
	chunk.rebuild_blocked()
	return chunk
