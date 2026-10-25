class_name PerfProbe
extends Node
## Opt-in frame timing for checking smoothness where no profiler reaches (the browser build):
## open the game with "?vkperf" in the URL (or set VK_PERF=1 on desktop) and every few seconds it
## prints a "VK_PERF" line: wall-clock frame time average, 95th percentile and worst (the engine
## caps the delta it hands out, so real time is read), frames over 50 ms, and the average and
## worst script time (Performance TIME_PROCESS). tools/web_smoke.cjs collects these lines.
## "?vkbench" also times, once at the title, the streaming work that used to stall single frames:
## a whole chunk against its slices, and a live navmesh bake against loading the shipped one.

const WINDOW: float = 5.0

var frames: PackedFloat32Array = PackedFloat32Array()
var scripts: PackedFloat32Array = PackedFloat32Array()
var last_usec: int = 0
var started_usec: int = 0
var label: String = ""

static func wanted(flag: String = "vkperf") -> bool:
	if OS.has_feature("web"):
		return String(JavaScriptBridge.eval("window.location.search", true)).contains(flag)
	return not OS.get_environment(flag.to_upper()).is_empty()

static func bench(world: WorldManager, root: Node) -> void:
	var settings: GameSettings = world.settings
	var whole: float = 0.0
	var slices: int = 0
	var worst_slice: float = 0.0
	var coords: Array[Vector2i] = [Vector2i(-1, 1), Vector2i(0, -3), Vector2i(-2, -7)]
	for coord: Vector2i in coords:
		var started: int = Time.get_ticks_usec()
		WorldChunk.compute(coord, world.layout, settings.chunk_size, settings.subdivisions, settings.world_seed, world.density_scale, world.part_transforms)
		whole += (Time.get_ticks_usec() - started) / 1000.0
		var job: ChunkJob = ChunkJob.new(coord, world.layout, settings.chunk_size, settings.subdivisions, settings.world_seed, world.density_scale, world.part_transforms)
		var done: bool = false
		while not done:
			var begun: int = Time.get_ticks_usec()
			done = job.step(begun + int(WorldManager.SLICE_BUDGET_MS * 1000.0))
			worst_slice = maxf(worst_slice, (Time.get_ticks_usec() - begun) / 1000.0)
			slices += 1
	var zone: Dictionary = NavBake.zones()[0]
	var center: Vector2 = Vector2(float(zone["pos"][0]), float(zone["pos"][1]))
	var started_bake: int = Time.get_ticks_usec()
	var mesh: NavigationMesh = NavBake.make_mesh(zone, world.height_at(center.x, center.y))
	var source: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, root)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var bake_ms: float = (Time.get_ticks_usec() - started_bake) / 1000.0
	var started_load: int = Time.get_ticks_usec()
	var shipped: NavigationMesh = NavBake.prebaked(String(zone["id"]), settings.world_seed)
	var load_ms: float = (Time.get_ticks_usec() - started_load) / 1000.0
	print("VK_BENCH chunk_whole=%.1fms chunk_slices=%d worst_slice=%.1fms nav_live_bake=%.1fms nav_shipped_load=%.1fms (%s)" % [whole / coords.size(),
		slices / coords.size(), worst_slice, bake_ms, load_ms, "shipped" if shipped else "none shipped"])

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if last_usec == 0:
		last_usec = now
		started_usec = now
		return
	frames.append((now - last_usec) / 1000.0)
	scripts.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	last_usec = now
	if now - started_usec < int(WINDOW * 1000000.0):
		return
	print("VK_PERF %s frames=%d %s script %s" % [label, frames.size(), _summary(frames, true), _summary(scripts, false)])
	frames.clear()
	scripts.clear()
	started_usec = now

static func _summary(values: PackedFloat32Array, with_spikes: bool) -> String:
	var sorted: PackedFloat32Array = values.duplicate()
	sorted.sort()
	var total: float = 0.0
	var spikes: int = 0
	for value: float in sorted:
		total += value
		if value > 50.0:
			spikes += 1
	var text: String = "avg=%.1fms p95=%.1fms worst=%.1fms" % [total / sorted.size(), sorted[int(sorted.size() * 0.95)], sorted[sorted.size() - 1]]
	return text + (" over50=%d" % spikes if with_spikes else "")
