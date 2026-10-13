class_name WorldChunk
extends Node3D

var coordinate: Vector2i
var ground: MeshInstance3D
var ground_shape: CollisionShape3D
var tree_batches: Array[MultiMeshInstance3D] = []
var rock_batches: Array[MultiMeshInstance3D] = []
var distant_trees: MultiMeshInstance3D
var trunk_shapes: Array[CollisionShape3D] = []

func initialize(settings: GameSettings, assets: AssetLibrary) -> void:
	ground = MeshInstance3D.new()
	add_child(ground)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ground.material_override = material
	var body: StaticBody3D = StaticBody3D.new()
	add_child(body)
	ground_shape = CollisionShape3D.new()
	body.add_child(ground_shape)
	for part: Dictionary in assets.mesh_parts["tree"]:
		var batch: MultiMeshInstance3D = _new_batch(part["mesh"])
		batch.visibility_range_end = settings.near_tree_distance
		tree_batches.append(batch)
	for part: Dictionary in assets.mesh_parts["rock"]:
		rock_batches.append(_new_batch(part["mesh"]))
	var low_mesh: CylinderMesh = CylinderMesh.new()
	low_mesh.top_radius = 0.0
	low_mesh.bottom_radius = 1.5
	low_mesh.height = 4.0
	low_mesh.radial_segments = 5
	var low_material: StandardMaterial3D = StandardMaterial3D.new()
	low_material.albedo_color = Color("345d49")
	low_material.roughness = 1.0
	low_mesh.material = low_material
	distant_trees = _new_batch(low_mesh)
	distant_trees.visibility_range_begin = settings.near_tree_distance
	distant_trees.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for index: int in range(settings.trees_per_chunk):
		var trunk: CollisionShape3D = CollisionShape3D.new()
		var capsule: CapsuleShape3D = CapsuleShape3D.new()
		capsule.radius = 0.22
		capsule.height = 2.8
		trunk.shape = capsule
		body.add_child(trunk)
		trunk_shapes.append(trunk)
	deactivate()

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
	for trunk: CollisionShape3D in trunk_shapes:
		trunk.disabled = true

func configure(coord: Vector2i, world: WorldManager, assets: AssetLibrary) -> void:
	coordinate = coord
	var settings: GameSettings = world.settings
	position = Vector3(coord.x * settings.chunk_size, 0, coord.y * settings.chunk_size)
	var count: int = settings.subdivisions + 1
	var step: float = float(settings.chunk_size) / settings.subdivisions
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	for z: int in range(count):
		for x: int in range(count):
			var px: float = position.x + x * step
			var pz: float = position.z + z * step
			var height: float = world.height_at(px, pz)
			vertices.append(Vector3(x * step, height, z * step))
			var dx: float = (world.height_at(px + 0.5, pz) - world.height_at(px - 0.5, pz))
			var dz: float = (world.height_at(px, pz + 0.5) - world.height_at(px, pz - 0.5))
			normals.append(Vector3(-dx, 1.0, -dz).normalized())
			var blend: float = clampf((height + 3.0) / 9.0, 0.0, 1.0)
			colors.append(Color("789267").lerp(Color("b1b98a"), blend))
	for z: int in range(settings.subdivisions):
		for x: int in range(settings.subdivisions):
			var a: int = z * count + x
			# Godot front faces use clockwise winding; collision is one-sided.
			indices.append_array(PackedInt32Array([a, a + 1, a + count, a + 1, a + count + 1, a + count]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	ground.mesh = mesh
	ground_shape.shape = mesh.create_trimesh_shape()
	ground_shape.disabled = false
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = hash(Vector3i(coord.x, settings.world_seed, coord.y))
	var tree_transforms: Array[Transform3D] = []
	for index: int in range(settings.trees_per_chunk):
		var local_x: float = random.randf_range(1.0, settings.chunk_size - 1.0)
		var local_z: float = random.randf_range(1.0, settings.chunk_size - 1.0)
		var wp: Vector2 = Vector2(position.x + local_x, position.z + local_z)
		if wp.length() < 10.0 or wp.distance_to(Vector2(3, -8)) < 5.0:
			continue
		var scale_factor: float = random.randf_range(0.75, 1.3)
		var basis: Basis = Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * scale_factor)
		tree_transforms.append(Transform3D(basis, Vector3(local_x, world.height_at(wp.x, wp.y), local_z)))
	_fill_batches(tree_batches, assets.mesh_parts["tree"], tree_transforms)
	distant_trees.multimesh.instance_count = tree_transforms.size()
	for index: int in range(tree_transforms.size()):
		var transform_value: Transform3D = tree_transforms[index]
		distant_trees.multimesh.set_instance_transform(index, transform_value * Transform3D(Basis.IDENTITY, Vector3(0, 3, 0)))
	for index: int in range(trunk_shapes.size()):
		trunk_shapes[index].disabled = index >= tree_transforms.size()
		if index < tree_transforms.size():
			trunk_shapes[index].transform = tree_transforms[index] * Transform3D(Basis.IDENTITY, Vector3(0, 1.4, 0))
	var rocks: Array[Transform3D] = []
	for index: int in range(3):
		var rx: float = random.randf_range(1, settings.chunk_size - 1)
		var rz: float = random.randf_range(1, settings.chunk_size - 1)
		var scale_factor: float = random.randf_range(0.6, 1.5)
		rocks.append(Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * scale_factor), Vector3(rx, world.height_at(position.x + rx, position.z + rz), rz)))
	_fill_batches(rock_batches, assets.mesh_parts["rock"], rocks)
	visible = true

func _fill_batches(batches: Array[MultiMeshInstance3D], parts: Array, transforms: Array[Transform3D]) -> void:
	for index: int in range(batches.size()):
		var multimesh: MultiMesh = batches[index].multimesh
		multimesh.instance_count = transforms.size()
		for instance: int in range(transforms.size()):
			multimesh.set_instance_transform(instance, transforms[instance] * (parts[index]["transform"] as Transform3D))
