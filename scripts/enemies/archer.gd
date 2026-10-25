class_name Archer
extends Enemy
## Bandit archer: keeps a firing distance ("keep_range"), looses arrows that lead a running
## target after a visible draw (a glint at the bow before the release), hops back when a foe
## closes in and swipes with the bow when cornered ("melee_range"). Arrows can be blocked,
## parried or dodged; shooting does not wait for the camp's melee attack slots.

const HOP_TIME: float = 0.5
const HOP_SPEED: float = 7.0

var hop_cooldown: float = 0.0
var hop_direction: Vector3 = Vector3.BACK

func _physics_chase(delta: float) -> void:
	if target == null or target.is_dead():
		_set_state("return")
		return
	var distance: float = _flat_distance(target.global_position)
	if distance > float(data.get("lose", 28.0)) or _flat_distance(home) > float(data.get("leash", 30.0)):
		_set_state("return")
		return
	hop_cooldown -= delta
	var band: Array = data.get("keep_range", [7.0, 13.0])
	var melee: float = float(data.get("melee_range", 2.2))
	if distance <= melee and cooldown <= 0.0:
		_begin_attack("bash")
		return
	if distance < float(band[0]) * 0.65 and hop_cooldown <= 0.0 and is_on_floor():
		_begin_hop()
		return
	if distance > melee and distance <= float(data.get("attack_range", 16.0)) and cooldown <= 0.0 and _can_see_target(distance + 1.0):
		_begin_attack("shoot")
		return
	var away: Vector3 = global_position - target.global_position
	away.y = 0.0
	if distance > float(band[1]):
		visual.play_loop("run")
		_move_toward(target.global_position, float(data.get("run", 4.6)) * speed_scale, delta)
	elif distance < float(band[0]):
		visual.play_loop("walk")
		_move_toward(global_position + away.normalized() * 3.0, float(data.get("speed", 2.0)) * speed_scale, delta, false)
		_face_target(delta, 6.0)
	else:
		# Sidestep around the target between shots, always facing it.
		visual.play_loop("walk")
		var around: Vector3 = away.normalized().rotated(Vector3.UP, 0.7 * delta * (1.0 if int(get_instance_id()) % 2 == 0 else -1.0))
		_move_toward(target.global_position + around * distance, float(data.get("speed", 2.0)) * speed_scale, delta, false)
		_face_target(delta, 6.0)

func _begin_hop() -> void:
	hop_cooldown = float(data.get("hop_cooldown", 4.0))
	hop_direction = global_position - target.global_position
	hop_direction.y = 0.0
	hop_direction = hop_direction.normalized().rotated(Vector3.UP, randf_range(-0.5, 0.5))
	state = "hop"
	state_time = 0.0
	visual.play_action("hop")

func _think(delta: float) -> void:
	if state == "hop":
		_face_target(delta, 8.0)
		var speed: float = HOP_SPEED * (1.0 - clampf(state_time / HOP_TIME, 0.0, 1.0))
		velocity.x = hop_direction.x * speed
		velocity.z = hop_direction.z * speed
		if state_time >= HOP_TIME:
			_set_state("chase")
		return
	super._think(delta)

func _attack_window(t: float, hit_start: float, hit_end: float) -> void:
	if attack_name != "shoot":
		super._attack_window(t, hit_start, hit_end)
		return
	if attack_hits.has("loosed"):
		return
	attack_hits["loosed"] = true
	var origin: Vector3 = global_position + Vector3.UP * float(data.get("height", 1.8)) * 0.78 + facing * 0.6
	fire_missile(origin, aim_point(float(attack_data.get("missile_speed", 26.0))), attack_data, "arrow", Color(1.0, 0.9, 0.7))

func _telegraph() -> void:
	# The glint shows at the drawn bow, ahead of the shoulder, where the arrow leaves.
	var bow: Vector3 = global_position + Vector3.UP * float(data.get("height", 1.8)) * 0.8 + facing * 0.7
	Vfx.glint(get_parent(), bow, Vfx.DANGER if attack_data.get("unblockable", false) else Vfx.SPARK, 0.9)
