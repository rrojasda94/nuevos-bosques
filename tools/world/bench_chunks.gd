extends SceneTree
## Banco de rendimiento del generador de chunks (ADR 0014 §6): genera N chunks de una región con
## una seed y escribe la mediana y el p95 en ms. Objetivo del ChunkBuilder: mediana ≤ 80 ms.
##
## Uso (desde la raíz del proyecto, con el proyecto ya importado):
##   godot --headless --path . -s tools/world/bench_chunks.gd
##   godot --headless --path . -s tools/world/bench_chunks.gd -- --builder=legacy --count=50 --seed=42 --region=valle_del_sara
##
## Opciones (todas opcionales, detrás de `--`):
##   --builder=legacy  ChunkGenerator.generate (64×64, el actual). Por defecto.
##   --builder=world   ChunkBuilder.build(plan, coord) -> WorldChunk (M6+). El RegionPlan de la
##                     seed se construye una vez fuera de la medición, como en la partida.
##   --count=N         chunks medidos (50). Se recorre la región fila a fila desde (0, 0).
##   --seed=S          seed de la partida (42).
##   --region=ID       región de data/world/regions/ (valle_del_sara).
## Para cambiar de generador sin tocar la línea de comandos, edita DEFAULT_BUILDER.
## En la CI corre como aviso: nunca hace fallar el flujo, porque las máquinas varían.

const DEFAULT_BUILDER: String = "legacy"
const DEFAULT_COUNT: int = 50
const DEFAULT_SEED: int = 42
const DEFAULT_REGION: String = "valle_del_sara"


func _initialize() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var builder_name: String = args.get("builder", DEFAULT_BUILDER)
	var count: int = int(args.get("count", DEFAULT_COUNT))
	var seed_value: int = int(args.get("seed", DEFAULT_SEED))
	var region_id: String = args.get("region", DEFAULT_REGION)

	# La región, los Bosques y el plan se preparan fuera de la medición: el banco mide solo el chunk.
	var region: Dictionary = ChunkGenerator.load_region(StringName(region_id))
	var build: Callable
	var size_chunks: Vector2i = ChunkGenerator.region_size(region)
	match builder_name:
		"legacy":
			var bosques: BosqueMap = BosqueMap.for_region(seed_value, region)
			build = func(coord: Vector2i) -> void: ChunkGenerator.generate(seed_value, coord, region, bosques)
		"world":
			var plan: RegionPlan = RegionPlan.for_region(seed_value, StringName(region_id))
			size_chunks = plan.size_chunks
			build = func(coord: Vector2i) -> void: ChunkBuilder.build(plan, coord)
		_:
			printerr("bench_chunks: generador '%s' no disponible" % builder_name)
			quit(2)
			return
	var coords: Array[Vector2i] = _coords(size_chunks, count)

	build.call(coords[0]) # Calentamiento, no cuenta.
	var times: PackedFloat64Array = PackedFloat64Array()
	for coord: Vector2i in coords:
		var start: int = Time.get_ticks_usec()
		build.call(coord)
		times.append((Time.get_ticks_usec() - start) / 1000.0)
	times.sort()

	var total: float = 0.0
	for t: float in times:
		total += t
	print("bench_chunks: builder=%s region=%s seed=%d chunks=%d" % [builder_name, region_id, seed_value, times.size()])
	print("bench_chunks: mediana=%.2f ms p95=%.2f ms min=%.2f ms max=%.2f ms total=%.0f ms" % [
		_percentile(times, 0.5), _percentile(times, 0.95), times[0], times[times.size() - 1], total])
	quit(0)


## Los primeros `count` chunks de la región, fila a fila (se repite si la región es más pequeña).
func _coords(size_chunks: Vector2i, count: int) -> Array[Vector2i]:
	var width: int = maxi(1, size_chunks.x)
	var height: int = maxi(1, size_chunks.y)
	var out: Array[Vector2i] = []
	for i: int in maxi(1, count):
		var j: int = i % (width * height)
		out.append(Vector2i(j % width, j / width))
	return out


## Percentil por el método del rango más cercano sobre `sorted` ya ordenado.
func _percentile(sorted: PackedFloat64Array, p: float) -> float:
	var rank: int = clampi(ceili(p * sorted.size()) - 1, 0, sorted.size() - 1)
	return sorted[rank]


func _parse_args(raw: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for arg: String in raw:
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.substr(2).split("=", true, 1)
			out[parts[0]] = parts[1]
	return out
