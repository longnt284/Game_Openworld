class_name WaterBodies
extends Node3D
## River and stream surfaces built once from the layout polylines.

func build(layout: WorldLayout) -> void:
	var material: ShaderMaterial = Toon.water_material()
	for water: Dictionary in layout.waters:
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.name = String(water["id"])
		instance.mesh = _strip(layout, water)
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)

func _strip(layout: WorldLayout, water: Dictionary) -> ArrayMesh:
	var points: PackedVector2Array = _resample(water["pts"], 3.0)
	var half: float = float(water["width"]) * 0.5 + (2.0 if water.get("kind", "") == "river" else 0.6)
	var vertices: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var travelled: float = 0.0
	for index: int in range(points.size()):
		var point: Vector2 = points[index]
		var ahead: Vector2 = points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]
		var side: Vector2 = Vector2(-ahead.y, ahead.x).normalized() * half
		if index > 0:
			travelled += point.distance_to(points[index - 1])
		var level: float = layout.water_at(point.x, point.y).get("level", float(water.get("level", 0.0)))
		for k: int in [0, 1]:
			var edge: Vector2 = point + side * (1.0 if k == 0 else -1.0)
			vertices.append(Vector3(edge.x, level, edge.y))
			uvs.append(Vector2(travelled / 6.0, float(k)))
			normals.append(Vector3.UP)
		if index > 0:
			var a: int = (index - 1) * 2
			indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _resample(points: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for index: int in range(points.size() - 1):
		var a: Vector2 = points[index]
		var b: Vector2 = points[index + 1]
		var steps: int = maxi(1, ceili(a.distance_to(b) / spacing))
		for step: int in range(steps):
			result.append(a.lerp(b, float(step) / steps))
	result.append(points[-1])
	return result
