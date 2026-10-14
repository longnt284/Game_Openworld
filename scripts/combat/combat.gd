class_name Combat
extends RefCounted
## Attack definitions and the swept-arc hit query shared by the player and enemies.
## Active windows come from data/anim_timings.json (the same file the Blender
## generator keys its strike poses from), so damage lines up with the animation.

const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_ENEMY: int = 4
const LAYER_NPC: int = 8
const LAYER_HURT_PLAYER: int = 16
const LAYER_HURT_ENEMY: int = 32
const LAYER_INTERACT: int = 64

## arc angles in degrees around the attacker's facing (+ = attacker's left)
const ATTACKS: Dictionary = {
	"player/attack_1": {"mult": 1.0, "poise": 14, "arc": [-75, 80], "radius": 1.6, "height": 1.1, "hit_radius": 0.8, "hitstop": 0.055, "shake": 0.14, "knockback": 1.6, "lunge": 3.2, "sfx": "sword_swing_1"},
	"player/attack_2": {"mult": 1.05, "poise": 14, "arc": [75, -80], "radius": 1.6, "height": 1.2, "hit_radius": 0.8, "hitstop": 0.055, "shake": 0.14, "knockback": 1.6, "lunge": 2.8, "sfx": "sword_swing_2"},
	"player/attack_3": {"mult": 1.7, "poise": 32, "arc": [-28, 28], "radius": 1.9, "height": 0.9, "hit_radius": 1.0, "hitstop": 0.09, "shake": 0.35, "knockback": 4.0, "lunge": 6.5, "sfx": "sword_swing_3"},
	"player/heavy": {"mult": 2.3, "poise": 45, "arc": [-40, 320], "radius": 1.9, "height": 1.0, "hit_radius": 1.0, "hitstop": 0.085, "shake": 0.4, "knockback": 5.0, "lunge": 1.5, "stamina": 18, "sfx": "sword_heavy"},
	"player/skill_gust": {"mult": 1.6, "poise": 26, "arc": [-50, 50], "radius": 1.7, "height": 1.2, "hit_radius": 0.9, "hitstop": 0.07, "shake": 0.25, "knockback": 3.0, "lunge": 1.0, "projectile": true, "sfx": "wind_slash"},
	"player/skill_cyclone": {"mult": 0.5, "poise": 10, "arc": [0, 0], "radius": 0.0, "height": 0.8, "hit_radius": 3.3, "hitstop": 0.03, "shake": 0.12, "knockback": -2.0, "lunge": 0.0, "tick": 0.13, "sfx": "wind_cyclone"},
	"bandit/attack": {"damage": 14, "poise": 20, "arc": [-22, 22], "radius": 1.6, "height": 1.0, "hit_radius": 0.85, "hitstop": 0.06, "shake": 0.3, "knockback": 3.0, "lunge": 4.0, "sfx": "sabre_swing"},
	"boar/charge": {"damage": 18, "poise": 30, "arc": [0, 0], "radius": 0.9, "height": 0.6, "hit_radius": 0.95, "hitstop": 0.07, "shake": 0.45, "knockback": 7.0, "lunge": 0.0, "sfx": "boar_hit"},
	"guardian/attack": {"damage": 26, "poise": 40, "arc": [-26, 26], "radius": 2.6, "height": 0.8, "hit_radius": 1.25, "hitstop": 0.09, "shake": 0.5, "knockback": 5.0, "lunge": 5.0, "sfx": "glaive_slam"},
	"guardian/sweep": {"damage": 22, "poise": 35, "arc": [-40, 260], "radius": 3.1, "height": 1.0, "hit_radius": 1.3, "hitstop": 0.08, "shake": 0.4, "knockback": 5.5, "lunge": 0.0, "sfx": "glaive_sweep"},
	"guardian/slam": {"damage": 34, "poise": 60, "arc": [0, 0], "radius": 1.0, "height": 0.4, "hit_radius": 4.6, "hitstop": 0.1, "shake": 0.8, "knockback": 8.0, "lunge": 0.0, "unblockable": true, "sfx": "ground_slam"},
}

class Damage:
	extends RefCounted
	var amount: float = 0.0
	var poise: float = 0.0
	var knockback: float = 0.0
	var direction: Vector3 = Vector3.FORWARD
	var source: Node3D
	var attack: String = ""
	var unblockable: bool = false
	var hitstop: float = 0.05
	var shake: float = 0.0
	var position: Vector3 = Vector3.ZERO

static func attack(owner: String, name: String) -> Dictionary:
	var data: Dictionary = ATTACKS.get(owner + "/" + name, {}).duplicate()
	var timing: Dictionary = ContentDB.timing(owner, name)
	for key: String in timing:
		data[key] = timing[key]
	return data

static func arc_point(origin: Vector3, facing: Vector3, data: Dictionary, u: float) -> Vector3:
	var arc: Array = data.get("arc", [0, 0])
	var angle: float = deg_to_rad(lerpf(float(arc[0]), float(arc[1]), clampf(u, 0.0, 1.0)))
	var flat: Vector3 = Vector3(facing.x, 0.0, facing.z).normalized()
	return origin + flat.rotated(Vector3.UP, angle) * float(data.get("radius", 1.5)) + Vector3.UP * float(data.get("height", 1.0))

static func sweep(attacker: Node3D, facing: Vector3, data: Dictionary, u_from: float, u_to: float, mask: int, already: Dictionary) -> Array[Area3D]:
	## Samples spheres along the arc between two normalised times; each hurtbox is returned once per swing.
	var hits: Array[Area3D] = []
	var space: PhysicsDirectSpaceState3D = attacker.get_world_3d().direct_space_state
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = float(data.get("hit_radius", 0.8))
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = mask
	var steps: int = maxi(1, ceili(absf(u_to - u_from) * 8.0))
	for step: int in range(steps + 1):
		var u: float = lerpf(u_from, u_to, float(step) / steps)
		query.transform = Transform3D(Basis.IDENTITY, arc_point(attacker.global_position, facing, data, u))
		for result: Dictionary in space.intersect_shape(query, 12):
			var area: Area3D = result["collider"] as Area3D
			if area == null or already.has(area.get_instance_id()):
				continue
			already[area.get_instance_id()] = true
			hits.append(area)
	return hits

static func make_damage(source: Node3D, data: Dictionary, amount: float, target_position: Vector3) -> Damage:
	var damage: Damage = Damage.new()
	damage.amount = amount
	damage.poise = float(data.get("poise", 10))
	damage.knockback = float(data.get("knockback", 1.0))
	damage.source = source
	damage.unblockable = bool(data.get("unblockable", false))
	damage.hitstop = float(data.get("hitstop", 0.05))
	damage.shake = float(data.get("shake", 0.0))
	var direction: Vector3 = target_position - source.global_position
	direction.y = 0.0
	damage.direction = direction.normalized() if direction.length() > 0.01 else Vector3.FORWARD
	damage.position = target_position + Vector3.UP
	return damage

static func make_hurtbox(owner_node: Node3D, layer: int, radius: float, height: float) -> Area3D:
	var area: Area3D = Area3D.new()
	area.name = "Hurtbox"
	area.collision_layer = layer
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.set_meta("entity", owner_node)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(height, radius * 2.0)
	shape.shape = capsule
	shape.position.y = height * 0.5
	area.add_child(shape)
	owner_node.add_child(area)
	return area

static func entity_of(area: Area3D) -> Node:
	return area.get_meta("entity") if area.has_meta("entity") else null
