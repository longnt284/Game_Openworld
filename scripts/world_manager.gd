class_name WorldManager
extends Node3D

var settings: GameSettings
var assets: AssetLibrary
var target: Node3D
var noise: FastNoiseLite = FastNoiseLite.new()
var active: Dictionary = {}
var pool: Array[WorldChunk] = []
var pending: Array[Vector2i] = []
var center: Vector2i = Vector2i(2147483647, 2147483647)
var last_build_ms: float = 0.0

func initialize(config: GameSettings, library: AssetLibrary, player: Node3D) -> void:
	settings = config
	assets = library
	target = player
	_configure_noise()
	for index: int in range(settings.chunk_capacity()):
		var chunk: WorldChunk = WorldChunk.new()
		add_child(chunk)
		chunk.initialize(settings, assets)
		pool.append(chunk)

func _configure_noise() -> void:
	noise.seed = settings.world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = settings.terrain_frequency
	noise.fractal_octaves = 3
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM

func height_at(x: float, z: float) -> float:
	return noise.get_noise_2d(x, z) * settings.terrain_amplitude

func coord_at(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / settings.chunk_size), floori(point.z / settings.chunk_size))

func is_position_ready(point: Vector3) -> bool:
	return active.has(coord_at(point))

func reset_seed(seed_value: int) -> void:
	settings.world_seed = seed_value
	_configure_noise()
	for chunk: WorldChunk in active.values():
		chunk.deactivate()
		pool.append(chunk)
	active.clear()
	pending.clear()
	center = Vector2i(2147483647, 2147483647)

func _process(_delta: float) -> void:
	if target == null:
		return
	var next_center: Vector2i = coord_at(target.global_position)
	if next_center != center:
		_recenter(next_center)
	if not pending.is_empty() and not pool.is_empty():
		var start: int = Time.get_ticks_usec()
		var coordinate: Vector2i = pending.pop_front()
		var chunk: WorldChunk = pool.pop_back()
		chunk.configure(coordinate, self, assets)
		active[coordinate] = chunk
		last_build_ms = (Time.get_ticks_usec() - start) / 1000.0

func _recenter(next_center: Vector2i) -> void:
	center = next_center
	for key: Vector2i in active.keys():
		if absi(key.x - center.x) > settings.view_radius or absi(key.y - center.y) > settings.view_radius:
			var chunk: WorldChunk = active[key]
			chunk.deactivate()
			pool.append(chunk)
			active.erase(key)
	pending.clear()
	for z: int in range(center.y - settings.view_radius, center.y + settings.view_radius + 1):
		for x: int in range(center.x - settings.view_radius, center.x + settings.view_radius + 1):
			var coordinate: Vector2i = Vector2i(x, z)
			if not active.has(coordinate):
				pending.append(coordinate)
	pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_squared_to(center) < b.distance_squared_to(center))
