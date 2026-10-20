class_name WindProjectile
extends Node3D
## Elemental missile travelling in a straight line (wind crescent, water wave, ice shard);
## hits each hurtbox once and stops on terrain or props.

var velocity: Vector3 = Vector3.ZERO
var data: Dictionary = {}
var amount: float = 10.0
var mask: int = Combat.LAYER_HURT_ENEMY
var source: Node3D
var travelled: float = 0.0
var max_distance: float = 14.0
var radius: float = 0.8
var hit_ids: Dictionary = {}
var color: Color = Vfx.WIND
var pierce: bool = true
## Player missiles deal damage through PlayerController.strike with this scale (skill level bonus).
var strike_scale: float = -1.0
## Thrown by an enemy: flies on the enemy clock, so Tâm Nhãn slows it too.
var enemy_owned: bool = false

func launch(origin: Vector3, direction: Vector3, speed: float, damage_amount: float, attack_data: Dictionary, hit_mask: int, owner_node: Node3D, tint: Color = Vfx.WIND, shape: String = "crescent") -> void:
	global_position = origin
	velocity = direction.normalized() * speed
	amount = damage_amount
	data = attack_data
	mask = hit_mask
	source = owner_node
	enemy_owned = owner_node is Enemy
	color = tint
	look_at(origin + velocity, Vector3.UP)
	var body: MeshInstance3D = MeshInstance3D.new()
	match shape:
		"wave":
			body.mesh = Vfx.wave_mesh(radius * 2.0)
			body.position.y = -1.0
		"shard":
			var prism: CylinderMesh = CylinderMesh.new()
			prism.top_radius = 0.0
			prism.bottom_radius = 0.16
			prism.height = 1.1
			prism.radial_segments = 4
			prism.rings = 1
			body.mesh = prism
			body.rotation.x = -PI * 0.5
		_:
			var torus: TorusMesh = TorusMesh.new()
			torus.inner_radius = 0.75
			torus.outer_radius = 1.0
			torus.rings = 24
			torus.ring_segments = 4
			body.mesh = torus
			body.scale = Vector3(1.2, 0.25, 0.6)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = shape == "wave"
	material.albedo_color = Color(color.r, color.g, color.b, 0.85)
	body.material_override = material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	Vfx.wisps(self, color, 18 if shape == "wave" else 10, radius * 0.6)

func _physics_process(delta: float) -> void:
	if enemy_owned:
		delta *= Enemy.time_dilation
	var step: Vector3 = velocity * delta
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, global_position + step, Combat.LAYER_WORLD)
	var blocked: Dictionary = space.intersect_ray(ray)
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = radius
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = mask
	query.transform = Transform3D(Basis.IDENTITY, global_position + step * 0.5)
	for result: Dictionary in space.intersect_shape(query, 8):
		var area: Area3D = result["collider"] as Area3D
		if area == null or hit_ids.has(area.get_instance_id()):
			continue
		hit_ids[area.get_instance_id()] = true
		var entity: Node = Combat.entity_of(area)
		if entity and entity.has_method("take_damage") and is_instance_valid(source):
			if strike_scale >= 0.0 and source.has_method("strike"):
				source.strike(entity, data, strike_scale, velocity.normalized(), true)
			else:
				var damage: Combat.Damage = Combat.make_damage(source, data, amount, (entity as Node3D).global_position)
				damage.direction = velocity.normalized()
				damage.ranged = true
				var outcome: Dictionary = entity.take_damage(damage)
				if outcome.get("hit", false) and source.has_signal("attack_landed"):
					source.emit_signal("attack_landed", entity, float(outcome.get("amount", amount)))
			Vfx.burst(get_parent(), (entity as Node3D).global_position + Vector3.UP, color, 14, 5.0)
		if not pierce:
			queue_free()
			return
	global_position += step
	travelled += step.length()
	if not blocked.is_empty() or travelled >= max_distance:
		Vfx.burst(get_parent(), global_position, color, 10, 3.0)
		queue_free()
