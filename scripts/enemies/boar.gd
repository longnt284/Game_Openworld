class_name Boar
extends Enemy
## Charging beast: scrapes the ground (telegraph), then rushes in a straight line.
## Hitting a wall or being parried leaves it dazed and open to punishment.

var charge_direction: Vector3 = Vector3.FORWARD
var charge_distance: float = 0.0
var charge_hit: bool = false

func _physics_chase(delta: float) -> void:
	if target == null or target.is_dead():
		_set_state("return")
		return
	var distance: float = _flat_distance(target.global_position)
	if distance > float(data.get("lose", 26.0)) or _flat_distance(home) > float(data.get("leash", 32.0)):
		_set_state("return")
		return
	if distance <= float(data.get("attack_range", 9.0)) and cooldown <= 0.0 and _take_token():
		_begin_windup()
		return
	if distance > 5.0:
		visual.play_loop("run")
		_move_toward(target.global_position, float(data.get("run", 4.2)), delta)
	else:
		visual.play_loop("walk")
		var away: Vector3 = global_position - target.global_position
		away.y = 0.0
		_move_toward(global_position + away.normalized() * 2.0, float(data.get("speed", 1.8)), delta, false)
		_face_target(delta, 4.0)

func _begin_windup() -> void:
	state = "attack"
	state_time = 0.0
	attack_name = "windup"
	attack_data = Combat.attack("boar", "charge")
	telegraphed = false
	visual.play_action("windup")
	emit_signal("attack_started", self, "charge")

func _physics_attack(delta: float) -> void:
	var windup: float = float(ContentDB.timing("boar", "windup").get("length", 0.9))
	if attack_name == "windup":
		_stop(delta)
		_face_target(delta, 7.0)
		if not telegraphed and state_time >= windup - 0.45:
			telegraphed = true
			Vfx.glint(get_parent(), global_position + Vector3.UP * 0.9 + facing * 0.9, Vfx.SPARK, 0.9)
			Vfx.burst(get_parent(), global_position + Vector3.UP * 0.1, Color(0.75, 0.65, 0.5, 0.7), 12, 2.5, 0.12, 0.6)
		if state_time >= windup:
			attack_name = "charge"
			state_time = 0.0
			charge_direction = facing
			charge_distance = 0.0
			charge_hit = false
			attack_hits = {}
			visual.play_loop("charge", 0.05)
		return
	var speed: float = float(data.get("charge_speed", 13.0))
	velocity.x = charge_direction.x * speed
	velocity.z = charge_direction.z * speed
	charge_distance += speed * delta
	for area: Area3D in Combat.sweep(self, charge_direction, attack_data, 0.0, 0.0, Combat.LAYER_HURT_PLAYER, attack_hits):
		_deliver(area, attack_data)
		charge_hit = true
	if state != "attack":
		return  # parried mid-charge
	if is_on_wall() and state_time > 0.15:
		Vfx.burst(get_parent(), global_position + Vector3.UP * 0.6 + charge_direction, Color(0.8, 0.75, 0.6), 18, 5.0)
		_daze(1.6)
		return
	if charge_distance >= float(data.get("charge_length", 14.0)) or (charge_hit and state_time > 0.25):
		cooldown = randf_range(1.6, 2.6)
		_set_state("recover")

func on_parried(_player: Node) -> void:
	if state != "dead":
		_daze(1.8)

func _daze(duration: float) -> void:
	## Stops the rush dead so the dazed boar stays in front of the player, open to punishment.
	velocity.x = 0.0
	velocity.z = 0.0
	_stagger(duration)
