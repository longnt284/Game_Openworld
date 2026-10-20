class_name Vfx
extends RefCounted
## Short-lived, readable effects built from simple meshes and CPU particles
## (GL Compatibility friendly). Every effect frees itself.

const WIND: Color = Color(0.62, 0.96, 0.88)
const SPARK: Color = Color(1.0, 0.86, 0.55)
const DANGER: Color = Color(1.0, 0.35, 0.22)
const SEAL: Color = Color(0.95, 0.32, 0.25)
## Group of effects timed to an enemy's blow: their tweens run at Enemy.time_dilation.
const ENEMY_CLOCK: String = "vfx_enemy_clock"

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

static func telegraph(parent: Node, position: Vector3, radius: float, duration: float, color: Color = DANGER, enemy_clock: bool = false) -> Node3D:
	## Ground warning that fills up until the attack lands (used for unblockable hits). An enemy's
	## warning (enemy_clock) slows with Tâm Nhãn so it still fills exactly as the blow lands.
	var holder: Node3D = Node3D.new()
	var tweens: Array[Tween] = []
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
			var grow: Tween = holder.create_tween()
			grow.tween_property(instance, "scale", Vector3(radius, 1, radius), duration)
			tweens.append(grow)
	var tween: Tween = holder.create_tween()
	tween.tween_interval(duration + 0.05)
	tween.tween_callback(holder.queue_free)
	tweens.append(tween)
	if enemy_clock:
		follow_enemy_clock(holder, tweens)
	return holder

static func follow_enemy_clock(holder: Node, tweens: Array[Tween]) -> void:
	## Runs an effect's tweens at the enemy clock rate now and whenever Tâm Nhãn changes it.
	holder.add_to_group(ENEMY_CLOCK)
	holder.set_meta("tweens", tweens)
	for tween: Tween in tweens:
		tween.set_speed_scale(Enemy.time_dilation)

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
	_float_text(parent, position + Vector3(randf_range(-0.3, 0.3), 0.4, randf_range(-0.3, 0.3)), str(roundi(value)), color, 52, 0.7)

static func label(parent: Node, position: Vector3, text: String, color: Color = SPARK) -> void:
	## A word that floats up and fades, larger and slower than a damage number ("Điện Giật!").
	_float_text(parent, position, text, color, 64, 1.0)

static func _float_text(parent: Node, position: Vector3, text: String, color: Color, font_size: int, life: float) -> void:
	var pop: Label3D = Label3D.new()
	pop.text = text
	pop.font_size = font_size
	pop.outline_size = 10
	pop.modulate = color
	pop.outline_modulate = Color(0.15, 0.1, 0.12, 0.9)
	pop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pop.no_depth_test = true
	pop.pixel_size = 0.006
	parent.add_child(pop)
	pop.global_position = position
	var tween: Tween = pop.create_tween().set_parallel(true)
	tween.tween_property(pop, "global_position", pop.global_position + Vector3.UP * 0.9 * life / 0.7, life).set_ease(Tween.EASE_OUT)
	tween.tween_property(pop, "modulate:a", 0.0, life).set_delay(0.25 * life / 0.7)
	tween.chain().tween_callback(pop.queue_free)

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

# ------------------------------------------------------------------ elemental effects

static func element_color(element: String) -> Color:
	return StyleBook.element_color(element) if element != "" else SPARK

static func _ribbon(points: PackedVector3Array, normals: PackedVector3Array, width: float, alphas: PackedFloat32Array) -> ArrayMesh:
	## Flat strip through points; each point is widened along its normal.
	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	for index: int in range(points.size()):
		vertices.append(points[index] + normals[index] * width * 0.5)
		vertices.append(points[index] - normals[index] * width * 0.5)
		colors.append(Color(1, 1, 1, alphas[index]))
		colors.append(Color(1, 1, 1, alphas[index] * 0.4))
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
	return mesh

static func _spawn_mesh(parent: Node, mesh: Mesh, position: Vector3, color: Color, duration: float, additive: bool = true) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	var material: StandardMaterial3D = _material(color, additive)
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	instance.global_position = position
	if duration > 0.0:
		_fade(instance, material, duration)
	return instance

static func streak(parent: Node, from: Vector3, to: Vector3, color: Color, width: float = 0.9, duration: float = 0.35) -> void:
	## Lingering trail along a dash path, slightly above the ground.
	var flat: Vector3 = to - from
	flat.y = 0.0
	if flat.length() < 0.1:
		return
	var side: Vector3 = flat.normalized().cross(Vector3.UP)
	var points: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var alphas: PackedFloat32Array = PackedFloat32Array()
	for index: int in range(9):
		var u: float = index / 8.0
		points.append((to - from) * u + Vector3.UP * (0.9 + sin(u * PI) * 0.25))
		normals.append(side.rotated(flat.normalized(), 0.6))
		alphas.append(sin(u * PI) * 0.9 + 0.1)
	_spawn_mesh(parent, _ribbon(points, normals, width, alphas), from, color, duration)

static func bolt(parent: Node, from: Vector3, to: Vector3, color: Color = Color("ffe066"), duration: float = 0.24, jitter: float = 0.45) -> void:
	## Jagged lightning between two points: a bright core inside a coloured sheath.
	var direction: Vector3 = to - from
	var length: float = direction.length()
	if length < 0.05:
		return
	var axis: Vector3 = direction / length
	var side: Vector3 = axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var up: Vector3 = side.cross(axis).normalized()
	var segments: int = clampi(int(length / 0.7), 4, 24)
	var points: PackedVector3Array = PackedVector3Array()
	for index: int in range(segments + 1):
		var u: float = float(index) / segments
		var offset: Vector3 = Vector3.ZERO
		if index > 0 and index < segments:
			offset = side * randf_range(-jitter, jitter) + up * randf_range(-jitter, jitter)
		points.append(direction * u + offset)
	for layer: Array in [[0.32, color], [0.1, Color(1, 1, 1, 1)]]:
		for normal: Vector3 in [side, up]:
			var normals: PackedVector3Array = PackedVector3Array()
			var alphas: PackedFloat32Array = PackedFloat32Array()
			for index: int in range(points.size()):
				normals.append(normal)
				alphas.append(1.0)
			_spawn_mesh(parent, _ribbon(points, normals, float(layer[0]), alphas), from, layer[1], duration)

static func pillar(parent: Node, position: Vector3, color: Color, height: float = 9.0, radius: float = 0.55, duration: float = 0.45) -> void:
	## Column of light (lightning strike, rarity reveal).
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = radius * 0.4
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 12
	cylinder.rings = 1
	var instance: MeshInstance3D = _spawn_mesh(parent, cylinder, position + Vector3.UP * height * 0.5, color, duration)
	instance.scale = Vector3(1.6, 1, 1.6)
	instance.create_tween().tween_property(instance, "scale", Vector3(0.2, 1, 0.2), duration).set_ease(Tween.EASE_IN)

static func lightning(parent: Node, position: Vector3, color: Color = Color("ffe066")) -> void:
	var sky: Vector3 = position + Vector3(randf_range(-1.5, 1.5), 16.0, randf_range(-1.5, 1.5))
	bolt(parent, sky, position, color, 0.28, 0.9)
	bolt(parent, sky + Vector3(0.6, 0, 0), position, Color(1, 1, 1, 0.8), 0.18, 1.2)
	pillar(parent, position, color, 3.5, 0.9, 0.3)
	ring(parent, position + Vector3.UP * 0.15, 2.6, color, 0.35, 0.2)
	burst(parent, position + Vector3.UP * 0.3, color, 26, 9.0, 0.08, 0.4)

static func shards(parent: Node, center: Vector3, color: Color = Color("bfefff"), count: int = 9, radius: float = 1.8, height: float = 1.6, duration: float = 0.9) -> void:
	## Ice prisms erupting from the ground in a ring.
	for index: int in range(count):
		var angle: float = TAU * index / count + randf_range(-0.2, 0.2)
		var prism: CylinderMesh = CylinderMesh.new()
		prism.top_radius = 0.0
		prism.bottom_radius = randf_range(0.18, 0.32)
		prism.height = height * randf_range(0.6, 1.2)
		prism.radial_segments = 4
		prism.rings = 1
		var point: Vector3 = center + Vector3(cos(angle), 0, sin(angle)) * radius * randf_range(0.5, 1.0)
		var instance: MeshInstance3D = _spawn_mesh(parent, prism, point, Color(color.r, color.g, color.b, 0.85), duration, false)
		instance.rotation = Vector3(randf_range(-0.35, 0.35), randf_range(0, TAU), randf_range(-0.35, 0.35))
		instance.scale = Vector3(1, 0.05, 1)
		instance.create_tween().tween_property(instance, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func ice_sword(parent: Node, position: Vector3, fall_time: float = 0.45) -> void:
	## Giant frost blade dropping from the sky; shatters into shards on impact.
	var holder: Node3D = Node3D.new()
	parent.add_child(holder)
	holder.global_position = position + Vector3.UP * 11.0
	holder.rotation.y = randf_range(0, TAU)
	var blade: BoxMesh = BoxMesh.new()
	blade.size = Vector3(0.55, 4.6, 0.12)
	var guard: BoxMesh = BoxMesh.new()
	guard.size = Vector3(1.6, 0.22, 0.3)
	for part: Array in [[blade, Vector3(0, -0.2, 0)], [guard, Vector3(0, 2.2, 0)]]:
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.mesh = part[0]
		instance.position = part[1]
		instance.material_override = _material(Color(0.78, 0.95, 1.0, 0.9))
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(instance)
	var tween: Tween = holder.create_tween()
	tween.tween_property(holder, "global_position", position + Vector3.UP * 1.9, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		shards(parent, position, Color("bfefff"), 10, 2.2, 1.8, 1.0)
		burst(parent, position + Vector3.UP * 0.4, Color(0.85, 0.97, 1.0), 30, 7.0, 0.09, 0.5)
		ring(parent, position + Vector3.UP * 0.1, 2.8, Color("bfefff"), 0.4, 0.2))
	tween.tween_interval(0.35)
	tween.tween_callback(holder.queue_free)

static func flames(parent: Node, position: Vector3, radius: float = 1.0, duration: float = 0.6, amount: int = 40) -> void:
	## Rising fire tongues over a disc.
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.6
	particles.amount = amount
	particles.lifetime = duration
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	particles.emission_ring_axis = Vector3.UP
	particles.emission_ring_radius = radius
	particles.emission_ring_inner_radius = radius * 0.6
	particles.emission_ring_height = 0.1
	particles.direction = Vector3.UP
	particles.spread = 15.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.5
	particles.gravity = Vector3(0, 2.0, 0)
	particles.scale_amount_min = 0.18
	particles.scale_amount_max = 0.42
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.0))
	particles.scale_amount_curve = curve
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	gradient.set_color(1, Color(0.9, 0.15, 0.05, 0.0))
	gradient.add_point(0.4, Color(1.0, 0.5, 0.15, 0.9))
	particles.color_ramp = gradient
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(1, 1.4)
	particles.mesh = mesh
	var material: StandardMaterial3D = _material(Color(1, 1, 1))
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	particles.material_override = material
	parent.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	var tween: Tween = particles.create_tween()
	tween.tween_interval(duration + 0.3)
	tween.tween_callback(particles.queue_free)

static func spiral(parent: Node, position: Vector3, radius: float, color: Color, duration: float = 0.5, turns: float = 1.5) -> void:
	## Rising helix ribbon (whirlpool, fire dragon, tornado layers).
	var points: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var alphas: PackedFloat32Array = PackedFloat32Array()
	var steps: int = 40
	for index: int in range(steps + 1):
		var u: float = float(index) / steps
		var angle: float = TAU * turns * u
		var r: float = radius * (1.0 - u * 0.35)
		points.append(Vector3(cos(angle) * r, u * 2.2, sin(angle) * r))
		normals.append(Vector3.UP)
		alphas.append(sin(u * PI))
	var instance: MeshInstance3D = _spawn_mesh(parent, _ribbon(points, normals, 0.45, alphas), position, color, duration)
	instance.create_tween().tween_property(instance, "rotation:y", TAU * 0.8, duration)

static func tornado(parent: Node, position: Vector3, radius: float, duration: float = 0.9, color: Color = WIND) -> void:
	for layer: int in range(3):
		spiral(parent, position + Vector3.UP * layer * 0.9, radius * (1.0 + layer * 0.35), color, duration, 1.2 + layer * 0.3)
	ring(parent, position + Vector3.UP * 0.2, radius, color, duration * 0.7, 0.12)
	burst(parent, position + Vector3.UP * 0.5, color, 24, 6.0, 0.07, 0.6)

static func wave_mesh(width: float) -> ArrayMesh:
	## Curling crest for the water wave projectile (local -Z is forward).
	var points: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var alphas: PackedFloat32Array = PackedFloat32Array()
	for index: int in range(17):
		var u: float = index / 16.0
		var x: float = (u - 0.5) * width
		points.append(Vector3(x, 0.9 + cos((u - 0.5) * PI) * 0.6, 0.25 * pow(absf(u - 0.5) * 2.0, 2.0)))
		normals.append(Vector3(0, 0.6, 0.8).normalized())
		alphas.append(sin(u * PI) * 0.9 + 0.1)
	return _ribbon(points, normals, 1.6, alphas)

static func crack(parent: Node, position: Vector3, radius: float, color: Color = Color(1.0, 0.78, 0.35)) -> void:
	## Glowing ground cracks plus thrown rock chips (heavy slams).
	for index: int in range(7):
		var angle: float = TAU * index / 7.0 + randf_range(-0.25, 0.25)
		var points: PackedVector3Array = PackedVector3Array()
		var normals: PackedVector3Array = PackedVector3Array()
		var alphas: PackedFloat32Array = PackedFloat32Array()
		var heading: float = angle
		var point: Vector3 = Vector3.UP * 0.06
		for step: int in range(6):
			points.append(point)
			normals.append(Vector3(cos(heading + PI * 0.5), 0, sin(heading + PI * 0.5)))
			alphas.append(1.0 - step / 6.0)
			heading += randf_range(-0.5, 0.5)
			point += Vector3(cos(heading), 0, sin(heading)) * radius / 6.0
		_spawn_mesh(parent, _ribbon(points, normals, 0.16, alphas), position, color, 0.9)
	var chips: CPUParticles3D = CPUParticles3D.new()
	chips.one_shot = true
	chips.explosiveness = 1.0
	chips.amount = 18
	chips.lifetime = 0.9
	chips.direction = Vector3.UP
	chips.spread = 55.0
	chips.initial_velocity_min = 4.0
	chips.initial_velocity_max = 8.0
	chips.gravity = Vector3(0, -18, 0)
	chips.scale_amount_min = 0.12
	chips.scale_amount_max = 0.3
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE * 0.5
	chips.mesh = box
	var rock: StandardMaterial3D = StandardMaterial3D.new()
	rock.albedo_color = Color(0.62, 0.58, 0.5)
	chips.material_override = rock
	parent.add_child(chips)
	chips.global_position = position + Vector3.UP * 0.2
	chips.emitting = true
	var tween: Tween = chips.create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(chips.queue_free)

static func field(parent: Node, position: Vector3, radius: float, color: Color, duration: float, enemy_clock: bool = false) -> Node3D:
	## Lingering ground disc with drifting mist (frost formation); enemy_clock as for telegraph.
	var holder: Node3D = Node3D.new()
	parent.add_child(holder)
	holder.global_position = position + Vector3.UP * 0.06
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 40
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = disc
	var material: StandardMaterial3D = _material(Color(color.r, color.g, color.b, 0.32))
	material.vertex_color_use_as_albedo = false
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(instance)
	var mist: CPUParticles3D = wisps(holder, color, 36, radius * 0.8)
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	mist.emission_ring_axis = Vector3.UP
	mist.emission_ring_radius = radius
	mist.emission_ring_inner_radius = 0.0
	mist.emission_ring_height = 0.1
	var tween: Tween = holder.create_tween()
	tween.tween_interval(maxf(0.0, duration - 0.4))
	var faded: Color = material.albedo_color
	faded.a = 0.0
	tween.tween_property(material, "albedo_color", faded, 0.4)
	tween.tween_callback(holder.queue_free)
	if enemy_clock:
		var timed: Array[Tween] = [tween]
		follow_enemy_clock(holder, timed)
	return holder
