class_name ChunkData
extends RefCounted
## Residuo del mundo viejo (ADR 0004/0006): el chunk de 64×64 casillas, su generador y su atlas se
## borraron en M17b; los chunks del juego son WorldChunk (80×80, ADR 0014). Quedan dos constantes
## que aún usa RegionPlan:
## - SIZE: casillas por lado del chunk viejo. ChunkGenerator.Terrain y ChunkGenerator.gate_index
##   siguen midiendo en esa escala, y RegionPlan la reescala a la de WorldCoords para que el relieve
##   y el río caigan donde caían (mismas seeds, mismo valle).
## - SIDES: los cuatro lados (igual que WorldChunk.SIDES, en el mismo orden).
## ponytail: borrar cuando region_plan.gd use WorldChunk.SIDES y lleve la escala vieja como
## constante propia.

const SIZE: int = 64
const SIDES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
