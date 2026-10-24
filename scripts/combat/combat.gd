class_name Combat
extends RefCounted
## Attack lookup and the swept-arc hit query shared by the player and enemies.
## Attack shapes live in data/attacks.json (arc angles in degrees around the attacker's
## facing, + = attacker's left); active windows come from data/anim_timings.json (the
## same file the Blender generator keys its strike poses from), so damage lines up with
## the animation.

const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_ENEMY: int = 4
const LAYER_NPC: int = 8
const LAYER_HURT_PLAYER: int = 16
const LAYER_HURT_ENEMY: int = 32
const LAYER_INTERACT: int = 64
## Flat "defense" (enemies and Lâm An alike) leaves 100 / (100 + defense) of a blow.
const DEFENSE_SCALE: float = 100.0
## Enemy sight never shrinks below this share, however thick the fog and dark the night.
const MIN_DETECT: float = 0.45

## The sky over the journey (main sets it while playing): rain and storms change elemental
## blows on every side, fog and night shorten enemy sight. Null (tests, the title) is neutral.
static var weather: WeatherDirector


static func weather_mult(element: String) -> float:
	## Rain: Lôi ×1.2, Hỏa ×0.8; storm: Lôi ×1.3, Phong ×1.15 (data/weather.json). 1 for plain steel.
	if element == "" or weather == null or not is_instance_valid(weather):
		return 1.0
	return weather.element_mult(element)


static func detect_mult() -> float:
	## Share of an enemy's sight range left by fog and night (never below MIN_DETECT).
	if weather == null or not is_instance_valid(weather):
		return 1.0
	return maxf(MIN_DETECT, weather.detect_mult())


class Damage:
	extends RefCounted
	var amount: float = 0.0
	var poise: float = 0.0
	var knockback: float = 0.0
	var direction: Vector3 = Vector3.FORWARD
	var source: Node3D
	var attack: String = ""
	var unblockable: bool = false
	var ranged: bool = false
	var hitstop: float = 0.05
	var shake: float = 0.0
	var position: Vector3 = Vector3.ZERO
	## Elemental payload: "" for plain steel. status is {"id", "stacks", "chance"}.
	var element: String = ""
	var status: Dictionary = {}
	## Attack power of the source, which scales damage-over-time from the status.
	var status_power: float = 0.0
	## Ticking areas hurt without making the target flinch, flash or freeze the frame.
	var flinch: bool = true
	## Flat enemy "defense" this blow ignores (Lâm An's armor_pen).
	var armor_pen: float = 0.0
	## Heavy swings (attack data "heavy": the charged attack and the finisher) shatter ice.
	var heavy: bool = false
	## The source's bonus to elemental reaction damage (Lâm An's reaction_dmg).
	var reaction_dmg: float = 0.0
	## The reaction this blow set off ("" for none); on a splash packet, the one that threw it.
	var reaction: String = ""
	## A reaction's own splash, spread or chain hit: it never sets off another reaction.
	var reaction_splash: bool = false
	## Finisher: the blow deals at least this share of the target's max health (before its
	## multipliers), but at most boss_cap of a boss's (after them); 0 leaves either alone.
	var hp_floor: float = 0.0
	var boss_cap: float = 0.0

static func attack(owner: String, name: String, clip: String = "", rate: float = 1.0) -> Dictionary:
	## Attack data merged with the timing of the clip it plays (data "clip", else its own
	## name), scaled by the attack's playback "speed" times `rate` (the attacker's attack speed).
	var data: Dictionary = (((ContentDB.get_data("attacks") as Dictionary).get(owner, {}) as Dictionary).get(name, {}) as Dictionary).duplicate(true)
	var timing: Dictionary = ContentDB.timing(owner, clip if clip != "" else String(data.get("clip", name)))
	var speed: float = maxf(float(data.get("speed", 1.0)) * rate, 0.01)
	for key: String in timing:
		if not data.has(key):
			data[key] = float(timing[key]) / speed
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

static func entities_in(node: Node3D, center: Vector3, radius: float, mask: int, max_results: int = 24) -> Array[Node]:
	## Every damageable entity (once each) whose hurtbox overlaps a sphere: area attacks and
	## the splash of elemental reactions.
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = radius
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = mask
	query.transform = Transform3D(Basis.IDENTITY, center)
	var found: Array[Node] = []
	for result: Dictionary in node.get_world_3d().direct_space_state.intersect_shape(query, max_results):
		var entity: Node = entity_of(result["collider"] as Area3D)
		if entity != null and not found.has(entity) and entity.has_method("take_damage"):
			found.append(entity)
	return found

static func defense_mult(defense: float) -> float:
	## Share of a blow left after flat defense; none (or less than none) is neutral.
	return DEFENSE_SCALE / (DEFENSE_SCALE + maxf(0.0, defense))

static func make_damage(source: Node3D, data: Dictionary, amount: float, target_position: Vector3) -> Damage:
	var damage: Damage = Damage.new()
	damage.amount = amount
	damage.poise = float(data.get("poise", 10))
	damage.knockback = float(data.get("knockback", 1.0))
	damage.source = source
	damage.unblockable = bool(data.get("unblockable", false))
	damage.ranged = bool(data.get("ranged", false))
	damage.hitstop = float(data.get("hitstop", 0.05))
	damage.shake = float(data.get("shake", 0.0))
	damage.element = String(data.get("element", ""))
	damage.status = data.get("status", {}) as Dictionary
	damage.flinch = bool(data.get("flinch", true))
	damage.heavy = bool(data.get("heavy", false))
	damage.hp_floor = float(data.get("hp_floor", 0.0))
	damage.boss_cap = float(data.get("boss_cap", 0.0))
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
