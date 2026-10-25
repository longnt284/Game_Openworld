class_name Mage
extends Enemy
## Lôi sư, the bandits' storm mage: keeps its distance, hurls thunder orbs that lead a running
## target ("cast"), calls lightning down on the spot the target stands on after a ground warning
## ("storm"), and blinks away in a crack of thunder when a foe gets close ("blink_cooldown").
## Spells do not wait for the camp's melee attack slots.

const BLINK_TIME: float = 0.6

var blink_cooldown: float = 0.0
var blink_target: Vector3
var blinked: bool = false
var storm_effect: AreaEffect

func _physics_chase(delta: float) -> void:
	if target == null or target.is_dead():
		_set_state("return")
		return
	var distance: float = _flat_distance(target.global_position)
	if distance > float(data.get("lose", 28.0)) or _flat_distance(home) > float(data.get("leash", 30.0)):
		_set_state("return")
		return
	blink_cooldown -= delta
	var band: Array = data.get("keep_range", [8.0, 13.0])
	if distance < float(data.get("blink_range", 3.6)) and blink_cooldown <= 0.0:
		_begin_blink()
		return
	if distance <= float(data.get("attack_range", 16.0)) and cooldown <= 0.0 and _can_see_target(distance + 1.0):
		_begin_attack("storm" if randf() < float(data.get("storm_chance", 0.4)) else "cast")
		return
	var away: Vector3 = global_position - target.global_position
	away.y = 0.0
	if distance > float(band[1]):
		visual.play_loop("run")
		_move_toward(target.global_position, float(data.get("run", 4.0)) * speed_scale, delta)
	elif distance < float(band[0]):
		visual.play_loop("walk")
		_move_toward(global_position + away.normalized() * 3.0, float(data.get("speed", 1.8)) * speed_scale, delta, false)
		_face_target(delta, 6.0)
	else:
		visual.play_loop("idle")
		_stop(delta)
		_face_target(delta, 6.0)

func _begin_attack(name: String) -> void:
	super._begin_attack(name)
	if name == "storm" and target:
		# The warning circle is drawn now, on the enemy clock, where the target stands.
		var spot: Vector3 = target.global_position
		storm_effect = AreaEffect.spawn(self, attack_data, float(data.get("damage_scale", 1.0)), "strikes", Color("ffe066"), Combat.LAYER_HURT_PLAYER)
		storm_effect.add_strike(spot, float(attack_data.get("hit_start", 1.0)) / maxf(speed_scale, 0.1), float(attack_data.get("strike_radius", 2.4)))

func _attack_window(_t: float, _hit_start: float, _hit_end: float) -> void:
	if attack_name != "cast" or attack_hits.has("cast"):
		return
	attack_hits["cast"] = true
	var origin: Vector3 = global_position + Vector3.UP * 1.6 + facing * 0.7
	fire_missile(origin, aim_point(float(attack_data.get("missile_speed", 13.0))), attack_data, "orb", Color("ffe066"))

func _begin_blink() -> void:
	blink_cooldown = float(data.get("blink_cooldown", 6.0))
	blinked = false
	_release_token()
	var away: Vector3 = global_position - target.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else -facing
	blink_target = global_position
	# The farthest safe spot of a few tries 7–9 m from the target, never into water, gorges or the leash's edge.
	for attempt: int in range(6):
		var candidate: Vector3 = target.global_position + away.rotated(Vector3.UP, randf_range(-1.1, 1.1)) * randf_range(7.0, 9.0)
		if world.is_position_ready(candidate) and world.layout.water_at(candidate.x, candidate.z).is_empty() and not world.layout.in_chasm(candidate.x, candidate.z) \
				and world.layout.inside_bounds(candidate.x, candidate.z) and Vector2(candidate.x - home.x, candidate.z - home.z).length() < float(data.get("leash", 30.0)):
			candidate.y = world.height_at(candidate.x, candidate.z) + 0.1
			blink_target = candidate
			break
	state = "blink"
	state_time = 0.0
	invulnerable = true
	visual.play_action("blink")
	Vfx.bolt(get_parent(), global_position + Vector3.UP * 7.0, global_position, Color("ffe066"), 0.2)

func _think(delta: float) -> void:
	if state == "blink":
		_stop(delta)
		if not blinked and state_time >= BLINK_TIME * 0.45:
			blinked = true
			Vfx.burst(get_parent(), global_position + Vector3.UP, Color("ffe066"), 18, 6.0)
			global_position = blink_target
			Vfx.bolt(get_parent(), global_position + Vector3.UP * 7.0, global_position, Color("ffe066"), 0.2)
			Vfx.ring(get_parent(), global_position + Vector3.UP * 0.15, 1.6, Color("ffe066"), 0.35, 0.15)
		if state_time >= BLINK_TIME:
			invulnerable = false
			_set_state("chase")
		return
	super._think(delta)

func _die(damage: Combat.Damage) -> void:
	invulnerable = false
	super._die(damage)
