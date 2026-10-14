class_name Vfx
extends RefCounted
## Short-lived, readable effects built from simple meshes and CPU particles
## (GL Compatibility friendly). Every effect frees itself.

const WIND: Color = Color(0.62, 0.96, 0.88)
const SPARK: Color = Color(1.0, 0.86, 0.55)
const DANGER: Color = Color(1.0, 0.35, 0.22)
const SEAL: Color = Color(0.95, 0.32, 0.25)

static func _material(color: Color, additive: bool = true) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	return material

static func _fade(node: GeometryInstance3D, material: StandardMaterial3D, duration: float) -> void:
	var tween: Tween = node.create_tween()
	var target: Color = material.albedo_color
	target.a = 0.0
	tween.tween_property(material, "albedo_color", target, duration)
	tween.tween_callback(node.queue_free)

static func slash(parent: Node, origin: Vector3, facing: Vector3, data: Dictionary, color: Color = Color(0.95, 0.98, 1.0, 0.85), width: float = 0.5) -> void:
	var arc: Array = data.get("arc", [0, 0])
	var samples: int = clampi(int(absf(float(arc[1]) - float(arc[0])) / 8.0), 6, 40)
	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	for index: int in range(samples + 1):
		var u: float = float(index) / samples
		var point: Vector3 = Combat.arc_point(Vector3.ZERO, facing, data, u)
		var outward: Vector3 = Vector3(point.x, 0, point.z).normalized()
		var alpha: float = smoothstep(0.0, 0.35, u) * (1.0 - smoothstep(0.85, 1.0, u)) + 0.15
		vertices.append(point + outward * width * 0.5 + Vector3.UP * 0.05)
		vertices.append(point - outward * width * 0.5)
		colors.append(Color(1, 1, 1, alpha))
		colors.append(Color(1, 1, 1, alpha * 0.3))
		if index > 0:
			var a: int = (index - 1) * 2
			indices.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	var material: StandardMaterial3D = _material(color, false)
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	instance.global_position = origin
	_fade(instance, material, 0.26)

static func burst(parent: Node, position: Vector3, color: Color = SPARK, amount: int = 18, speed: float = 6.0, size: float = 0.09, life: float = 0.35) -> void:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = amount
	particles.lifetime = life
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -9.0, 0)
	particles.scale_amount_min = size * 0.6
	particles.scale_amount_max = size
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	particles.mesh = mesh
	var material: StandardMaterial3D = _material(color)
	material.vertex_color_use_as_albedo = false
	particles.material_override = material
	parent.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	var tween: Tween = particles.create_tween()
	tween.tween_interval(life + 0.2)
	tween.tween_callback(particles.queue_free)

static func ring(parent: Node, position: Vector3, radius: float, color: Color = WIND, duration: float = 0.45, thickness: float = 0.18) -> void:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = maxf(0.05, 1.0 - thickness)
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 6
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = torus
	var material: StandardMaterial3D = _material(color)
	material.vertex_color_use_as_albedo = false
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	instance.global_position = position
	instance.scale = Vector3(0.2, 0.3, 0.2)
	var tween: Tween = instance.create_tween().set_parallel(true)
	tween.tween_property(instance, "scale", Vector3(radius, 0.4, radius), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var target: Color = color
	target.a = 0.0
	tween.tween_property(material, "albedo_color", target, duration)
	tween.chain().tween_callback(instance.queue_free)

static func telegraph(parent: Node, position: Vector3, radius: float, duration: float, color: Color = DANGER) -> Node3D:
	## Ground warning that fills up until the attack lands (used for unblockable hits).
	var holder: Node3D = Node3D.new()
	parent.add_child(holder)
	holder.global_position = position + Vector3.UP * 0.08
	for index: int in range(2):
		var disc: CylinderMesh = CylinderMesh.new()
		disc.top_radius = 1.0
		disc.bottom_radius = 1.0
		disc.height = 0.02
		disc.radial_segments = 32
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.mesh = disc
		var material: StandardMaterial3D = _material(Color(color.r, color.g, color.b, 0.22 if index == 0 else 0.4), false)
		material.vertex_color_use_as_albedo = false
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(instance)
		if index == 0:
			instance.scale = Vector3(radius, 1, radius)
		else:
			instance.scale = Vector3(0.1, 1, 0.1)
			instance.position.y = 0.01
			holder.create_tween().tween_property(instance, "scale", Vector3(radius, 1, radius), duration)
	var tween: Tween = holder.create_tween()
	tween.tween_interval(duration + 0.05)
	tween.tween_callback(holder.queue_free)
	return holder

static func glint(parent: Node, position: Vector3, color: Color = SPARK, size: float = 0.5) -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size, size)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = quad
	var material: StandardMaterial3D = _material(color)
	material.vertex_color_use_as_albedo = false
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	instance.material_override = material
	parent.add_child(instance)
	instance.global_position = position
	instance.scale = Vector3.ONE * 0.2
	var tween: Tween = instance.create_tween()
	tween.tween_property(instance, "scale", Vector3.ONE * 1.4, 0.12)
	tween.tween_property(instance, "scale", Vector3.ONE * 0.1, 0.18)
	tween.tween_callback(instance.queue_free)

static func number(parent: Node, position: Vector3, value: float, color: Color = Color(1, 0.95, 0.8)) -> void:
	var label: Label3D = Label3D.new()
	label.text = str(roundi(value))
	label.font_size = 52
	label.outline_size = 10
	label.modulate = color
	label.outline_modulate = Color(0.15, 0.1, 0.12, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.006
	parent.add_child(label)
	label.global_position = position + Vector3(randf_range(-0.3, 0.3), 0.4, randf_range(-0.3, 0.3))
	var tween: Tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector3.UP * 0.9, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)

static func wisps(parent: Node3D, color: Color = WIND, amount: int = 14, radius: float = 0.6) -> CPUParticles3D:
	## Persistent drifting motes (memory echoes, shrines, wind barrier).
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 2.4
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius
	particles.direction = Vector3.UP
	particles.spread = 25.0
	particles.initial_velocity_min = 0.2
	particles.initial_velocity_max = 0.6
	particles.gravity = Vector3(0, 0.15, 0)
	particles.scale_amount_min = 0.04
	particles.scale_amount_max = 0.09
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	particles.mesh = mesh
	var material: StandardMaterial3D = _material(color)
	material.vertex_color_use_as_albedo = false
	particles.material_override = material
	parent.add_child(particles)
	return particles
