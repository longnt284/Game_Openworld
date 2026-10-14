class_name Backdrop
extends Node3D
## Distant mountain silhouettes, kept outside the playable area for depth.

func build(center: Vector2, seed_value: int) -> void:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value + 91
	noise.frequency = 1.6
	for layer: Array in [[620.0, 70.0, 150.0, Color("6f8f86")], [860.0, 120.0, 260.0, Color("9fb4b6")]]:
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.mesh = _ring(center, layer[0], layer[1], layer[2], noise, layer[0])
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = layer[3]
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)

func _ring(center: Vector2, radius: float, low: float, high: float, noise: FastNoiseLite, offset: float) -> ArrayMesh:
	var segments: int = 160
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for index: int in range(segments + 1):
		var angle: float = TAU * index / segments
		var ridge: float = lerpf(low, high, clampf(noise.get_noise_2d(cos(angle) + offset, sin(angle)) * 0.5 + 0.5 + absf(noise.get_noise_1d(angle * 3.0 + offset)) * 0.4, 0.0, 1.0))
		var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		vertices.append(Vector3(point.x, -40.0, point.y))
		vertices.append(Vector3(point.x, ridge, point.y))
		if index > 0:
			var a: int = (index - 1) * 2
			indices.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
