class_name ChunkJob
extends RefCounted
## One chunk's geometry and flora (WorldChunk.compute) built in resumable steps. Threaded builds
## run a job to the end on a worker; single-threaded web builds call `step` once a frame with a
## deadline, so a chunk spreads over a few frames instead of stalling one. The work and its order
## are the same however it is sliced, so a sliced build is identical to a whole one.

enum { GRID, FLORA, SURFACE, PACK, DONE }

## Attempts scattered between deadline checks.
const SCATTER_BATCH: int = 24

var coord: Vector2i
var layout: WorldLayout
var chunk_size: int
var world_seed: int
var density_scale: float
var part_transforms: Dictionary
var result: Dictionary = {}
var stage: int = GRID
## Steps taken so far (a test reads it to show the work was really spread out).
var steps: int = 0

var origin: Vector2
var count: int
var step_size: float
var grid: PackedFloat32Array = PackedFloat32Array()
var row: int = -1
var flora: Dictionary = {}
var canopies: Array = []
var kind_index: int = 0
var random: RandomNumberGenerator
var attempt: int = 0
var placed: Array = []
var vertices: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var colors: PackedColorArray = PackedColorArray()

func _init(chunk: Vector2i, full_layout: WorldLayout, size: int, subdivisions: int, seed_value: int, density: float = 1.0, parts: Dictionary = {}) -> void:
	coord = chunk
	chunk_size = size
	world_seed = seed_value
	density_scale = density
	part_transforms = parts
	origin = Vector2(coord.x * chunk_size, coord.y * chunk_size)
	# Only the roads, flats and waters near this chunk: identical results, far less work per sample.
	layout = full_layout.view(Rect2(origin - Vector2(4, 4), Vector2(chunk_size + 8, chunk_size + 8)))
	count = subdivisions + 1
	step_size = float(chunk_size) / subdivisions
	grid.resize((count + 2) * (count + 2))

func run() -> Dictionary:
	while not step(-1):
		pass
	return result

func step(deadline_usec: int) -> bool:
	## Works until the deadline (Time.get_ticks_usec; negative = no deadline) or the end of a stage
	## part; true once `result` is complete. Each call makes some progress, however late it is.
	steps += 1
	while stage != DONE:
		match stage:
			GRID:
				_grid_row()
			FLORA:
				_scatter_batch()
			SURFACE:
				_surface_row()
			PACK:
				_pack()
		if deadline_usec >= 0 and Time.get_ticks_usec() >= deadline_usec:
			break
	return stage == DONE

func _grid_row() -> void:
	## The height grid, one row per call, with a one-sample border for the normals.
	var z: int = row
	for x: int in range(-1, count + 1):
		grid[(z + 1) * (count + 2) + x + 1] = layout.height_at(origin.x + x * step_size, origin.y + z * step_size)
	row += 1
	if row > count:
		row = 0
		stage = FLORA
		_begin_kind()

func _begin_kind() -> void:
	if kind_index >= layout.flora_kinds.size():
		stage = SURFACE
		return
	random = RandomNumberGenerator.new()
	random.seed = hash(Vector4i(coord.x, coord.y, world_seed, kind_index))
	attempt = 0
	placed = []

func _scatter_batch() -> void:
	var kind: String = layout.flora_kinds[kind_index]
	var rule: Dictionary = layout.flora[kind]
	var attempts: int = int(rule.get("max", 0))
	var last: int = mini(attempt + SCATTER_BATCH, attempts)
	while attempt < last:
		WorldChunk.scatter_attempt(random, kind_index, rule, attempts, origin, layout, chunk_size, density_scale, placed)
		attempt += 1
	if attempt < attempts:
		return
	flora[kind] = placed
	if rule.has("canopy"):
		for entry: Array in placed:
			var at: Transform3D = entry[0]
			canopies.append(Vector3(at.origin.x, at.origin.z, float(rule["canopy"]) * at.basis.get_scale().x))
	kind_index += 1
	_begin_kind()

func _surface_row() -> void:
	## One row of vertices, normals and ground colours.
	var z: int = row
	for x: int in range(count):
		var index: int = (z + 1) * (count + 2) + x + 1
		var height: float = grid[index]
		vertices.append(Vector3(x * step_size, height, z * step_size))
		var dx: float = grid[index + 1] - grid[index - 1]
		var dz: float = grid[index + count + 2] - grid[index - count - 2]
		var normal: Vector3 = Vector3(-dx, 2.0 * step_size, -dz).normalized()
		normals.append(normal)
		var tint: Color = layout.ground_color(origin.x + x * step_size, origin.y + z * step_size, height, 1.0 - normal.y * normal.y)
		# Under a canopy the ground darkens (cheap ambient occlusion); alpha marks the
		# canopy so the terrain shader can dapple the sunlight there.
		var shade: float = 0.0
		for canopy: Vector3 in canopies:
			var reach: float = canopy.z
			var gap: float = Vector2(x * step_size - canopy.x, z * step_size - canopy.y).length()
			if gap < reach:
				shade = maxf(shade, 1.0 - gap / reach)
		tint = tint.darkened(shade * 0.28)
		tint.a = shade
		colors.append(tint)
	row += 1
	if row >= count:
		stage = PACK

func _pack() -> void:
	## Triangles, collision faces and the MultiMesh buffers.
	var subdivisions: int = count - 1
	var indices: PackedInt32Array = PackedInt32Array()
	for z: int in range(subdivisions):
		for x: int in range(subdivisions):
			var a: int = z * count + x
			# Godot front faces use clockwise winding; collision is one-sided.
			indices.append_array(PackedInt32Array([a, a + 1, a + count, a + 1, a + count + 1, a + count]))
	var faces: PackedVector3Array = PackedVector3Array()
	for index: int in indices:
		faces.append(vertices[index])
	var buffers: Dictionary = {}
	for kind: String in flora:
		var kind_buffers: Array = []
		for part: Transform3D in part_transforms.get(kind, [Transform3D.IDENTITY]):
			kind_buffers.append(WorldChunk.buffer(flora[kind], part))
		buffers[kind] = kind_buffers
	var far: Dictionary = {}
	for kind: String in flora:
		var group: String = String(layout.flora[kind].get("far", ""))
		if group == "":
			continue
		if not far.has(group):
			far[group] = []
		var far_tint: Color = Color(String(layout.flora[kind].get("far_color", "ffffff")))
		for entry: Array in flora[kind]:
			far[group].append([(entry[0] as Transform3D) * Transform3D(Basis.IDENTITY, Vector3(0, WorldChunk.FAR_TREE_HEIGHT if group != "bamboo" else 0.0, 0)), far_tint])
	var far_buffers: Dictionary = {}
	for group: String in far:
		far_buffers[group] = WorldChunk.buffer(far[group], Transform3D.IDENTITY)
	result = {"coord": coord, "vertices": vertices, "normals": normals, "colors": colors, "indices": indices, "faces": faces, "flora": flora,
		"buffers": buffers, "far": far_buffers}
	stage = DONE
