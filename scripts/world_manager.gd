class_name WorldManager
extends Node3D
## Streams a bounded pool of terrain chunks around the player. Heights come from
## WorldLayout; chunk geometry is computed on WorkerThreadPool and applied here.

## Without threads a task runs inline on the main thread, so build one chunk per frame there.
var max_tasks: int = 1 if OS.has_feature("nothreads") else 2

var settings: GameSettings
var assets: AssetLibrary
var layout: WorldLayout
var target: Node3D
var active: Dictionary = {}
var pool: Array[WorldChunk] = []
var pending: Array[Vector2i] = []
var building: Dictionary = {}
var center: Vector2i = Vector2i(2147483647, 2147483647)
var last_build_ms: float = 0.0
var ground_material: ShaderMaterial

func initialize(config: GameSettings, library: AssetLibrary, player: Node3D) -> void:
	settings = config
	assets = library
	target = player
	layout = WorldLayout.load_default(settings.world_seed)
	ground_material = Toon.terrain_material()
	for index: int in range(settings.chunk_capacity()):
		var chunk: WorldChunk = WorldChunk.new()
		add_child(chunk)
		chunk.initialize(settings, assets, ground_material)
		pool.append(chunk)
	if OS.get_environment("NO_BOUNDS").is_empty():
		_build_bounds()

func _build_bounds() -> void:
	var walls: StaticBody3D = StaticBody3D.new()
	walls.name = "Bounds"
	add_child(walls)
	var rect: Rect2 = layout.bounds
	var center_point: Vector2 = rect.get_center()
	for spec: Array in [[Vector2(rect.position.x, center_point.y), Vector2(1, rect.size.y)], [Vector2(rect.end.x, center_point.y), Vector2(1, rect.size.y)],
			[Vector2(center_point.x, rect.position.y), Vector2(rect.size.x, 1)], [Vector2(center_point.x, rect.end.y), Vector2(rect.size.x, 1)]]:
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3((spec[1] as Vector2).x, 400, (spec[1] as Vector2).y)
		shape.shape = box
		shape.position = Vector3((spec[0] as Vector2).x, 100, (spec[0] as Vector2).y)
		walls.add_child(shape)

func height_at(x: float, z: float) -> float:
	return layout.height_at(x, z)

func coord_at(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / settings.chunk_size), floori(point.z / settings.chunk_size))

func is_position_ready(point: Vector3) -> bool:
	return active.has(coord_at(point))

func reset_seed(seed_value: int) -> void:
	settings.world_seed = seed_value
	layout = WorldLayout.load_default(seed_value)
	_wait_for_builds()
	for chunk: WorldChunk in active.values():
		chunk.deactivate()
		pool.append(chunk)
	active.clear()
	pending.clear()
	center = Vector2i(2147483647, 2147483647)

func _wait_for_builds() -> void:
	for coordinate: Vector2i in building.keys():
		var job: Dictionary = building[coordinate]
		WorkerThreadPool.wait_for_task_completion(job["task"])
		(job["chunk"] as WorldChunk).deactivate()
		pool.append(job["chunk"])
	building.clear()

func _exit_tree() -> void:
	_wait_for_builds()

func _process(_delta: float) -> void:
	if target == null:
		return
	var next_center: Vector2i = coord_at(target.global_position)
	if next_center != center:
		_recenter(next_center)
	_collect_builds()
	while not pending.is_empty() and not pool.is_empty() and building.size() < max_tasks:
		var coordinate: Vector2i = pending.pop_front()
		var chunk: WorldChunk = pool.pop_back()
		var job: Dictionary = {"chunk": chunk, "result": {}, "layout": layout}
		var size: int = settings.chunk_size
		var subdivisions: int = settings.subdivisions
		var world_seed: int = settings.world_seed
		var job_layout: WorldLayout = layout
		job["task"] = WorkerThreadPool.add_task(func() -> void:
			job["result"] = WorldChunk.compute(coordinate, job_layout, size, subdivisions, world_seed))
		building[coordinate] = job

func _collect_builds() -> void:
	for coordinate: Vector2i in building.keys():
		var job: Dictionary = building[coordinate]
		if not WorkerThreadPool.is_task_completed(job["task"]):
			continue
		WorkerThreadPool.wait_for_task_completion(job["task"])
		building.erase(coordinate)
		var chunk: WorldChunk = job["chunk"]
		if job["layout"] != layout or not _in_range(coordinate) or active.has(coordinate):
			chunk.deactivate()
			pool.append(chunk)
			continue
		var start: int = Time.get_ticks_usec()
		chunk.apply(job["result"], settings.chunk_size)
		active[coordinate] = chunk
		last_build_ms = (Time.get_ticks_usec() - start) / 1000.0

func _in_range(coordinate: Vector2i) -> bool:
	return absi(coordinate.x - center.x) <= settings.view_radius and absi(coordinate.y - center.y) <= settings.view_radius

func _recenter(next_center: Vector2i) -> void:
	center = next_center
	for key: Vector2i in active.keys():
		if not _in_range(key):
			var chunk: WorldChunk = active[key]
			chunk.deactivate()
			pool.append(chunk)
			active.erase(key)
	pending.clear()
	for z: int in range(center.y - settings.view_radius, center.y + settings.view_radius + 1):
		for x: int in range(center.x - settings.view_radius, center.x + settings.view_radius + 1):
			var coordinate: Vector2i = Vector2i(x, z)
			if not active.has(coordinate) and not building.has(coordinate):
				pending.append(coordinate)
	pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_squared_to(center) < b.distance_squared_to(center))
