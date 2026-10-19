class_name AreaEffect
extends Node3D
## Timed area attacks: novas pulsing around the caster, delayed strikes on chosen spots and
## lingering fields that tick. The player's sword forms hit through PlayerController.strike;
## any other caster (an enemy) deals its attack "damage" × strike_scale straight to take_damage.

var caster: Node3D
## Hurtboxes the area hits: enemies' for the player's forms, the player's for enemy casters.
var mask: int = Combat.LAYER_HURT_ENEMY
var data: Dictionary = {}
## Player: skill multiplier passed to strike. Other casters: multiplier on data "damage".
var strike_scale: float = 1.0
var color: Color = Vfx.WIND
var mode: String = "nova"
## Pending hits: {"time", "position", "radius"}
var events: Array[Dictionary] = []
var clock: float = 0.0
var field_left: float = 0.0
var tick_left: float = 0.0
var field_radius: float = 0.0

static func spawn(owner_node: Node3D, attack: Dictionary, scale: float, kind: String, tint: Color, hit_mask: int = Combat.LAYER_HURT_ENEMY) -> AreaEffect:
	var effect: AreaEffect = AreaEffect.new()
	effect.caster = owner_node
	effect.mask = hit_mask
	effect.data = attack
	effect.strike_scale = scale
	effect.mode = kind
	effect.color = tint
	effect.process_mode = Node.PROCESS_MODE_PAUSABLE
	owner_node.get_parent().add_child(effect)
	effect.global_position = owner_node.global_position
	return effect

func add_strike(point: Vector3, delay: float, radius: float) -> void:
	events.append({"time": delay, "position": point, "radius": radius})
	var world: WorldManager = caster.get("world") as WorldManager
	var ground: Vector3 = Vector3(point.x, world.height_at(point.x, point.z) if world else point.y, point.z)
	Vfx.telegraph(get_parent(), ground, radius, delay, color)
	if String(data.get("vfx", "")) == "ice_sword":
		Vfx.ice_sword(get_parent(), ground, delay)

func start_field(center: Vector3, radius: float, duration: float) -> void:
	global_position = center
	field_radius = radius
	field_left = duration
	tick_left = 0.0
	Vfx.field(get_parent(), center, radius, color, duration)

func _physics_process(delta: float) -> void:
	# A slain enemy's area stops hurting the winner, like the guardian's shockwave.
	if not is_instance_valid(caster) or (caster is Enemy and (caster as Enemy).is_dead()):
		queue_free()
		return
	clock += delta
	for event: Dictionary in events.duplicate():
		if clock >= float(event["time"]):
			events.erase(event)
			_land(event["position"], float(event["radius"]))
	if mode == "field" and field_left > 0.0:
		field_left -= delta
		tick_left -= delta
		if tick_left <= 0.0:
			tick_left = float(data.get("tick", 0.5))
			_hit_area(global_position, field_radius)
			Vfx.shards(get_parent(), global_position, color, 4, field_radius * 0.8, 0.8, 0.5)
	if events.is_empty() and field_left <= 0.0:
		queue_free()

func _land(point: Vector3, radius: float) -> void:
	match String(data.get("vfx", "")):
		"lightning":
			Vfx.lightning(get_parent(), point, color)
		"tornado":
			Vfx.tornado(get_parent(), point, radius * 0.55, 0.6, color)
		"sun":
			Vfx.pillar(get_parent(), point, color, 7.0, radius * 0.35, 0.5)
			Vfx.flames(get_parent(), point, radius * 0.75, 0.9, 70)
			Vfx.ring(get_parent(), point + Vector3.UP * 0.2, radius, color, 0.5, 0.25)
			Vfx.burst(get_parent(), point + Vector3.UP, Color(1.0, 0.85, 0.5), 40, 10.0, 0.1, 0.6)
		"ice_sword":
			pass  # the falling blade already shatters on its own clock
		_:
			Vfx.ring(get_parent(), point + Vector3.UP * 0.2, radius, color, 0.4, 0.2)
	if caster is PlayerController and (caster as PlayerController).camera_rig:
		(caster as PlayerController).camera_rig.add_trauma(float(data.get("shake", 0.3)) * 0.6)
	_hit_area(point, radius)

func _hit_area(center: Vector3, radius: float) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = radius
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = mask
	query.transform = Transform3D(Basis.IDENTITY, center + Vector3.UP * 0.8)
	var seen: Dictionary = {}
	for result: Dictionary in space.intersect_shape(query, 24):
		var entity: Node = Combat.entity_of(result["collider"] as Area3D)
		if entity == null or entity == caster or seen.has(entity) or not entity.has_method("take_damage"):
			continue
		seen[entity] = true
		var away: Vector3 = (entity as Node3D).global_position - center
		away.y = 0.0
		var direction: Vector3 = away.normalized() if away.length() > 0.05 else _caster_facing()
		if caster is PlayerController:
			(caster as PlayerController).strike(entity, data, strike_scale, direction, true)
		else:
			_hurt(entity, direction)

func _hurt(entity: Node, direction: Vector3) -> void:
	## A non-player caster's hit: the attack's own damage, pushed away from the centre (or
	## pulled in for negative knockback). Ranged, so parrying it never staggers the caster.
	var damage: Combat.Damage = Combat.make_damage(caster, data, float(data.get("damage", 10)) * strike_scale, (entity as Node3D).global_position)
	damage.direction = direction
	if damage.knockback < 0.0:
		damage.direction = -direction
		damage.knockback = absf(damage.knockback)
	damage.ranged = true
	entity.take_damage(damage)

func _caster_facing() -> Vector3:
	var value: Variant = caster.get("facing")
	return value if value is Vector3 else Vector3.FORWARD
