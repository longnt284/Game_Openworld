class_name WorldChunk
extends Node3D
## Pooled terrain tile. `compute` is pure (safe on a worker thread);
## `apply` pushes the result into meshes, MultiMeshes and colliders on the main thread.

const FLORA_RULES: Dictionary = {
	"pine": {"min_scale": 0.8, "max_scale": 1.35, "collider": 0.3, "margin": 2.0},
	"maple": {"min_scale": 0.85, "max_scale": 1.25, "collider": 0.32, "margin": 2.5},
	"bamboo": {"min_scale": 0.8, "max_scale": 1.3, "collider": 0.55, "margin": 1.2},
	"rock": {"min_scale": 0.6, "max_scale": 1.6, "collider": 0.0, "margin": 1.0},
	"grass": {"min_scale": 0.7, "max_scale": 1.3, "collider": 0.0, "margin": 0.2},
}
const MAX_PER_KIND: Dictionary = {"pine": 8, "maple": 5, "bamboo": 18, "rock": 6, "grass": 32}

var coordinate: Vector2i
var ground: MeshInstance3D
var ground_shape: CollisionShape3D
var body: StaticBody3D
var batches: Dictionary = {}
var distant_trees: MultiMeshInstance3D
var trunk_shapes: Array[CollisionShape3D] = []
var rock_shapes: Array[CollisionShape3D] = []
var library: AssetLibrary

func initialize(settings: GameSettings, assets: AssetLibrary, ground_material: Material) -> void:
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
	for kind: String in FLORA_RULES:
		var kind_batches: Array[MultiMeshInstance3D] = []
		for part: Dictionary in assets.mesh_parts.get(kind, []):
			var batch: MultiMeshInstance3D = _new_batch(part["mesh"])
			if kind in ["pine", "maple", "bamboo"]:
				batch.visibility_range_end = settings.near_tree_distance
			elif kind == "grass":
				batch.visibility_range_end = 46.0
				batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				batch.visibility_range_end = 90.0
			kind_batches.append(batch)
		batches[kind] = kind_batches
	var low_mesh: CylinderMesh = CylinderMesh.new()
	low_mesh.top_radius = 0.0
	low_mesh.bottom_radius = 1.5
	low_mesh.height = 4.0
	low_mesh.radial_segments = 5
	low_mesh.material = Toon.flat_material(Color("4f7d55"))
	distant_trees = _new_batch(low_mesh)
	distant_trees.visibility_range_begin = settings.near_tree_distance
	distant_trees.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for index: int in range(MAX_PER_KIND["pine"] + MAX_PER_KIND["maple"] + MAX_PER_KIND["bamboo"]):
		trunk_shapes.append(_new_capsule())
	for index: int in range(MAX_PER_KIND["rock"]):
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
	batch.multimesh.mesh = mesh
	add_child(batch)
	return batch

func deactivate() -> void:
	visible = false
	ground_shape.disabled = true
	for shape: CollisionShape3D in trunk_shapes + rock_shapes:
		shape.disabled = true

static func compute(coord: Vector2i, layout: WorldLayout, chunk_size: int, subdivisions: int, world_seed: int) -> Dictionary:
	var origin: Vector2 = Vector2(coord.x * chunk_size, coord.y * chunk_size)
	var count: int = subdivisions + 1
	var step: float = float(chunk_size) / subdivisions
	var grid: PackedFloat32Array = PackedFloat32Array()
	grid.resize((count + 2) * (count + 2))
	for z: int in range(-1, count + 1):
		for x: int in range(-1, count + 1):
			grid[(z + 1) * (count + 2) + x + 1] = layout.height_at(origin.x + x * step, origin.y + z * step)
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
			colors.append(layout.ground_color(origin.x + x * step, origin.y + z * step, height, 1.0 - normal.y * normal.y))
	for z: int in range(subdivisions):
		for x: int in range(subdivisions):
			var a: int = z * count + x
			# Godot front faces use clockwise winding; collision is one-sided.
			indices.append_array(PackedInt32Array([a, a + 1, a + count, a + 1, a + count + 1, a + count]))
	var faces: PackedVector3Array = PackedVector3Array()
	for index: int in indices:
		faces.append(vertices[index])
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash(Vector3i(coord.x, world_seed, coord.y))
	var flora: Dictionary = {}
	for kind: String in FLORA_RULES:
		flora[kind] = []
	var attempts: Dictionary = {"pine": 8, "maple": 5, "bamboo": 18, "rock": 6, "grass": 32}
	for kind: String in attempts:
		var rule: Dictionary = FLORA_RULES[kind]
		for attempt: int in range(attempts[kind]):
			var local: Vector2 = Vector2(random.randf_range(0.5, chunk_size - 0.5), random.randf_range(0.5, chunk_size - 0.5))
			var world: Vector2 = origin + local
			var roll: float = random.randf()
			var scale_factor: float = random.randf_range(rule["min_scale"], rule["max_scale"])
			var yaw: float = random.randf() * TAU
			var biome: Dictionary = layout.biomes.get(layout.region_at(world.y).get("id", ""), {})
			var density: float
			if kind in ["pine", "maple"]:
				density = float(biome.get("trees", {}).get(kind, 0)) / attempts[kind]
			else:
				density = float(biome.get(kind, 0)) / attempts[kind]
			if roll > density or not layout.is_clear(world.x, world.y, rule["margin"]):
				continue
			var height: float = layout.height_at(world.x, world.y)
			if kind != "rock" and kind != "grass" and absf(layout.height_at(world.x + 1.0, world.y) - height) > 1.4:
				continue
			var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_factor)
			flora[kind].append(Transform3D(basis, Vector3(local.x, height - 0.05, local.y)))
	return {"coord": coord, "vertices": vertices, "normals": normals, "colors": colors, "indices": indices, "faces": faces, "flora": flora}

func apply(data: Dictionary, chunk_size: int) -> void:
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
		_fill_batches(batches[kind], library.mesh_parts.get(kind, []), flora.get(kind, []))
	var trees: Array = flora.get("pine", []) + flora.get("maple", [])
	distant_trees.multimesh.instance_count = trees.size()
	for index: int in range(trees.size()):
		distant_trees.multimesh.set_instance_transform(index, (trees[index] as Transform3D) * Transform3D(Basis.IDENTITY, Vector3(0, 3, 0)))
	var trunks: Array = []
	for kind: String in ["pine", "maple", "bamboo"]:
		for transform_value: Transform3D in flora.get(kind, []):
			trunks.append([transform_value, FLORA_RULES[kind]["collider"]])
	for index: int in range(trunk_shapes.size()):
		var trunk: CollisionShape3D = trunk_shapes[index]
		trunk.disabled = index >= trunks.size()
		if index < trunks.size():
			var origin: Vector3 = (trunks[index][0] as Transform3D).origin
			(trunk.shape as CapsuleShape3D).radius = trunks[index][1]
			trunk.transform = Transform3D(Basis.IDENTITY, origin + Vector3(0, 1.5, 0))
	var rocks: Array = flora.get("rock", [])
	for index: int in range(rock_shapes.size()):
		var rock_shape: CollisionShape3D = rock_shapes[index]
		rock_shape.disabled = index >= rocks.size()
		if index < rocks.size():
			var rock: Transform3D = rocks[index]
			var scale_factor: float = rock.basis.get_scale().x
			(rock_shape.shape as SphereShape3D).radius = 0.62 * scale_factor
			rock_shape.transform = Transform3D(Basis.IDENTITY, rock.origin + Vector3(0, 0.25 * scale_factor, 0))
	visible = true

func _fill_batches(kind_batches: Array, parts: Array, transforms: Array) -> void:
	for index: int in range(kind_batches.size()):
		var multimesh: MultiMesh = (kind_batches[index] as MultiMeshInstance3D).multimesh
		multimesh.instance_count = transforms.size()
		for instance: int in range(transforms.size()):
			multimesh.set_instance_transform(instance, (transforms[instance] as Transform3D) * (parts[index]["transform"] as Transform3D))
