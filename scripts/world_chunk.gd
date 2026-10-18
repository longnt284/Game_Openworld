class_name WorldChunk
extends Node3D
## Pooled terrain tile. `compute` is pure (safe on a worker thread);
## `apply` pushes the result into meshes, MultiMeshes and colliders on the main thread.
## Flora follows data/world/flora.json: each kind has its own RNG stream (so quality
## presets that thin grass never move a tree), gathers in noise-driven drifts, carries a
## per-instance tint and darkens the ground under its canopy.

## Floats per MultiMesh instance: 3x4 transform + RGBA colour.
const STRIDE: int = 16
const FAR_TREE_HEIGHT: float = 3.0

var coordinate: Vector2i
var ground: MeshInstance3D
var ground_shape: CollisionShape3D
var body: StaticBody3D
## kind -> Array[MultiMeshInstance3D], one per mesh part of the kind's model
var batches: Dictionary = {}
## far group ("cone", "round", "bamboo") -> MultiMeshInstance3D shown past the tree distance
var far_batches: Dictionary = {}
var trunk_shapes: Array[CollisionShape3D] = []
var rock_shapes: Array[CollisionShape3D] = []
var library: AssetLibrary

func initialize(settings: GameSettings, assets: AssetLibrary, ground_material: Material, layout: WorldLayout) -> void:
	library = assets
	ground = MeshInstance3D.new()
	ground.material_override = ground_material
	add_child(ground)
	body = StaticBody3D.new()
	body.collision_layer = 1
	body.set_meta("surface", "grass")
	add_child(body)
	ground_shape = CollisionShape3D.new()
	body.add_child(ground_shape)
	var trunk_slots: int = 0
	for kind: String in layout.flora_kinds:
		var rule: Dictionary = layout.flora[kind]
		var kind_batches: Array[MultiMeshInstance3D] = []
		for part: Dictionary in assets.mesh_parts.get(kind, []):
			var batch: MultiMeshInstance3D = _new_batch(part["mesh"])
			batch.set_meta("range", String(rule.get("range", "clutter")))
			if not rule.get("shadow", false):
				batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			kind_batches.append(batch)
		batches[kind] = kind_batches
		if rule.has("collider"):
			trunk_slots += int(rule.get("max", 0))
	for group: String in assets.far_meshes:
		var far: MultiMeshInstance3D = _new_batch(assets.far_meshes[group])
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		far.visibility_range_begin = settings.near_tree_distance
		far_batches[group] = far
	for index: int in range(trunk_slots):
		trunk_shapes.append(_new_capsule())
	for index: int in range(int(layout.flora.get("rock", {}).get("max", 0))):
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.shape = SphereShape3D.new()
		body.add_child(shape)
		rock_shapes.append(shape)
	deactivate()

func _new_capsule() -> CollisionShape3D:
	var trunk: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 3.0
	trunk.shape = capsule
	body.add_child(trunk)
	return trunk

func _new_batch(mesh: Mesh) -> MultiMeshInstance3D:
	var batch: MultiMeshInstance3D = MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.use_colors = true
	batch.multimesh.mesh = mesh
	add_child(batch)
	return batch

func deactivate() -> void:
	visible = false
	ground_shape.disabled = true
	for shape: CollisionShape3D in trunk_shapes + rock_shapes:
		shape.disabled = true

static func compute(coord: Vector2i, layout: WorldLayout, chunk_size: int, subdivisions: int, world_seed: int, density_scale: float = 1.0,
		part_transforms: Dictionary = {}) -> Dictionary:
	var origin: Vector2 = Vector2(coord.x * chunk_size, coord.y * chunk_size)
	var count: int = subdivisions + 1
	var step: float = float(chunk_size) / subdivisions
	var grid: PackedFloat32Array = PackedFloat32Array()
	grid.resize((count + 2) * (count + 2))
	for z: int in range(-1, count + 1):
		for x: int in range(-1, count + 1):
			grid[(z + 1) * (count + 2) + x + 1] = layout.height_at(origin.x + x * step, origin.y + z * step)
	var flora: Dictionary = {}
	var canopies: Array = []
	for kind_index: int in range(layout.flora_kinds.size()):
		var kind: String = layout.flora_kinds[kind_index]
		var rule: Dictionary = layout.flora[kind]
		flora[kind] = _scatter(kind, kind_index, rule, coord, origin, layout, chunk_size, world_seed, density_scale)
		if rule.has("canopy"):
			for entry: Array in flora[kind]:
				var placed: Transform3D = entry[0]
				canopies.append(Vector3(placed.origin.x, placed.origin.z, float(rule["canopy"]) * placed.basis.get_scale().x))
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	for z: int in range(count):
		for x: int in range(count):
			var row: int = (z + 1) * (count + 2) + x + 1
			var height: float = grid[row]
			vertices.append(Vector3(x * step, height, z * step))
			var dx: float = grid[row + 1] - grid[row - 1]
			var dz: float = grid[row + count + 2] - grid[row - count - 2]
			var normal: Vector3 = Vector3(-dx, 2.0 * step, -dz).normalized()
			normals.append(normal)
			var tint: Color = layout.ground_color(origin.x + x * step, origin.y + z * step, height, 1.0 - normal.y * normal.y)
			# Under a canopy the ground darkens (cheap ambient occlusion); alpha marks the
			# canopy so the terrain shader can dapple the sunlight there.
			var shade: float = 0.0
			for canopy: Vector3 in canopies:
				var reach: float = canopy.z
				var gap: float = Vector2(x * step - canopy.x, z * step - canopy.y).length()
				if gap < reach:
					shade = maxf(shade, 1.0 - gap / reach)
			tint = tint.darkened(shade * 0.28)
			tint.a = shade
			colors.append(tint)
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
			kind_buffers.append(_buffer(flora[kind], part))
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
			far[group].append([(entry[0] as Transform3D) * Transform3D(Basis.IDENTITY, Vector3(0, FAR_TREE_HEIGHT if group != "bamboo" else 0.0, 0)), far_tint])
	var far_buffers: Dictionary = {}
	for group: String in far:
		far_buffers[group] = _buffer(far[group], Transform3D.IDENTITY)
	return {"coord": coord, "vertices": vertices, "normals": normals, "colors": colors, "indices": indices, "faces": faces, "flora": flora,
		"buffers": buffers, "far": far_buffers}

static func _scatter(kind: String, kind_index: int, rule: Dictionary, coord: Vector2i, origin: Vector2, layout: WorldLayout, chunk_size: int,
		world_seed: int, density_scale: float) -> Array:
	## [Transform3D, Color] per instance. Every attempt draws the same random numbers whether or
	## not it spawns, so density changes never reshuffle the kinds that keep their count.
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash(Vector4i(coord.x, coord.y, world_seed, kind_index))
	var placed: Array = []
	var attempts: int = int(rule.get("max", 0))
	var scale_range: Array = rule.get("scale", [1.0, 1.0])
	var tints: Array = rule.get("tints", [])
	var density_scaled: bool = rule.get("dense", false)
	for attempt: int in range(attempts):
		var local: Vector2 = Vector2(random.randf_range(0.5, chunk_size - 0.5), random.randf_range(0.5, chunk_size - 0.5))
		var roll: float = random.randf()
		var scale_factor: float = random.randf_range(float(scale_range[0]), float(scale_range[1]))
		var yaw: float = random.randf() * TAU
		var pick: float = random.randf()
		var world: Vector2 = origin + local
		var chance: float = float(layout.biome_density(world.y).get(kind, 0.0)) / maxf(attempts, 1)
		if density_scaled:
			chance *= density_scale
		if chance <= 0.0:
			continue
		if rule.has("cluster"):
			chance *= layout.cluster_gate(world.x, world.y, kind_index, rule["cluster"])
		if roll > chance:
			continue
		if not layout.flora_clear(world.x, world.y, rule):
			continue
		var height: float = layout.height_at(world.x, world.y)
		if rule.has("slope") and absf(layout.height_at(world.x + 1.0, world.y) - height) > float(rule["slope"]):
			continue
		var tint: Color = Color.WHITE
		if rule.get("tint", "") == "ground":
			# Pale blades take the colour of the ground they grow from, a shade lighter.
			tint = layout.ground_color(world.x, world.y, height, 0.0).lightened(0.3)
		elif not tints.is_empty():
			tint = Color(String(tints[int(pick * tints.size()) % tints.size()]))
		var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_factor)
		# Flora meshes are imported, so their shader takes colours as linear: match the tint.
		placed.append([Transform3D(basis, Vector3(local.x, height - 0.05, local.y)), tint.srgb_to_linear()])
	return placed

static func _buffer(entries: Array, part: Transform3D) -> PackedFloat32Array:
	var buffer: PackedFloat32Array = PackedFloat32Array()
	buffer.resize(entries.size() * STRIDE)
	var offset: int = 0
	for entry: Array in entries:
		var t: Transform3D = (entry[0] as Transform3D) * part
		var c: Color = entry[1]
		var values: Array[float] = [t.basis.x.x, t.basis.y.x, t.basis.z.x, t.origin.x, t.basis.x.y, t.basis.y.y, t.basis.z.y, t.origin.y,
			t.basis.x.z, t.basis.y.z, t.basis.z.z, t.origin.z, c.r, c.g, c.b, c.a]
		for value: float in values:
			buffer[offset] = value
			offset += 1
	return buffer

func apply(data: Dictionary, chunk_size: int, layout: WorldLayout) -> void:
	coordinate = data["coord"]
	position = Vector3(coordinate.x * chunk_size, 0, coordinate.y * chunk_size)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_COLOR] = data["colors"]
	arrays[Mesh.ARRAY_INDEX] = data["indices"]
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	ground.mesh = mesh
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(data["faces"])
	ground_shape.shape = shape
	ground_shape.disabled = false
	var flora: Dictionary = data["flora"]
	for kind: String in batches:
		var kind_buffers: Array = data["buffers"].get(kind, [])
		for index: int in range(batches[kind].size()):
			_fill(batches[kind][index], kind_buffers[index] if index < kind_buffers.size() else PackedFloat32Array())
	for group: String in far_batches:
		_fill(far_batches[group], data["far"].get(group, PackedFloat32Array()))
	var trunks: Array = []
	for kind: String in flora:
		var rule: Dictionary = layout.flora[kind]
		if rule.has("collider"):
			for entry: Array in flora[kind]:
				trunks.append([(entry[0] as Transform3D).origin, float(rule["collider"])])
	for index: int in range(trunk_shapes.size()):
		var trunk: CollisionShape3D = trunk_shapes[index]
		trunk.disabled = index >= trunks.size()
		if index < trunks.size():
			(trunk.shape as CapsuleShape3D).radius = trunks[index][1]
			trunk.transform = Transform3D(Basis.IDENTITY, (trunks[index][0] as Vector3) + Vector3(0, 1.5, 0))
	var rocks: Array = flora.get("rock", [])
	var rock_radius: float = float(layout.flora.get("rock", {}).get("rock_collider", 0.62))
	for index: int in range(rock_shapes.size()):
		var rock_shape: CollisionShape3D = rock_shapes[index]
		rock_shape.disabled = index >= rocks.size()
		if index < rocks.size():
			var rock: Transform3D = rocks[index][0]
			var scale_factor: float = rock.basis.get_scale().x
			(rock_shape.shape as SphereShape3D).radius = rock_radius * scale_factor
			rock_shape.transform = Transform3D(Basis.IDENTITY, rock.origin + Vector3(0, 0.25 * scale_factor, 0))
	visible = true

func _fill(batch: MultiMeshInstance3D, buffer: PackedFloat32Array) -> void:
	var multimesh: MultiMesh = batch.multimesh
	multimesh.instance_count = buffer.size() / STRIDE
	if multimesh.instance_count > 0:
		multimesh.buffer = buffer
	batch.visible = multimesh.instance_count > 0
