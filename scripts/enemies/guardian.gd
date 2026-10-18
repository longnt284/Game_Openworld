class_name Guardian
extends Enemy
## Trúc Tướng, the bamboo guardian (miniboss). Phase 1: overhead slam (parryable),
## spinning sweep, leaping slam (unblockable, red telegraph). Below half health it
## roars, speeds up, sweeps throw wind blades and slams send out a shockwave ring.

signal phase_changed(phase: int)

var phase: int = 1
var slam_marker: Node3D
var shockwave_radius: float = -1.0
var shockwave_center: Vector3
var shockwave_hit: bool = false
var blades_thrown: bool = false

func _ready() -> void:
	boss = true

func _choose_attack(distance: float) -> String:
	var roll: float = randf()
	if distance > 4.2:
		return "slam"
	if phase == 2 and roll < 0.3:
		return "slam"
	if roll < 0.5:
		return "attack"
	return "sweep" if roll < 0.85 else "slam"

func _physics_chase(delta: float) -> void:
	if target and _flat_distance(target.global_position) < 9.0 and _flat_distance(target.global_position) > 4.2 and cooldown <= 0.0 and randf() < 0.02:
		_begin_attack("slam")
		return
	super._physics_chase(delta)

func _begin_attack(name: String) -> void:
	super._begin_attack(name)
	blades_thrown = false
	if name == "slam" and target:
		var landing: Vector3 = global_position + facing * 1.6
		var hit_start: float = float(attack_data.get("hit_start", 1.3)) / maxf(speed_scale, 0.1)
		slam_marker = Vfx.telegraph(get_parent(), Vector3(landing.x, world.height_at(landing.x, landing.z), landing.z), float(attack_data["hit_radius"]), hit_start)

func _physics_attack(delta: float) -> void:
	super._physics_attack(delta)
	if state != "attack":
		return
	var t: float = attack_clock
	if attack_name == "slam" and t >= float(attack_data.get("hit_start", 1.3)) and not attack_hits.has("landed"):
		attack_hits["landed"] = true
		Vfx.ring(get_parent(), global_position + facing * 1.6 + Vector3.UP * 0.2, float(attack_data["hit_radius"]), Color(1.0, 0.78, 0.35), 0.5, 0.25)
		Vfx.crack(get_parent(), global_position + facing * 1.6, float(attack_data["hit_radius"]) * 0.8)
		Vfx.burst(get_parent(), global_position + facing * 1.6, Color(1.0, 0.85, 0.5), 30, 7.0, 0.12, 0.6)
		if target:
			target.camera_rig.add_trauma(0.5)
		if phase == 2:
			shockwave_center = global_position + facing * 1.6
			shockwave_radius = 0.5
			shockwave_hit = false
	if attack_name == "sweep" and phase == 2 and not blades_thrown and t >= float(attack_data.get("hit_end", 1.4)):
		blades_thrown = true
		_throw_blades()

func _process(delta: float) -> void:
	if shockwave_radius < 0.0:
		return
	if state == "dead":
		shockwave_radius = -1.0  # a slain guardian's ring stops hurting the winner
		return
	shockwave_radius += 9.0 * delta
	if int(shockwave_radius * 4.0) % 3 == 0:
		Vfx.ring(get_parent(), shockwave_center + Vector3.UP * 0.15, shockwave_radius, Color(1.0, 0.55, 0.35, 0.8), 0.12, 0.06)
	if target and not shockwave_hit:
		var distance: float = Vector2(target.global_position.x - shockwave_center.x, target.global_position.z - shockwave_center.z).length()
		if absf(distance - shockwave_radius) < 0.7 and target.is_on_floor():
			shockwave_hit = true
			var wave: Dictionary = {"damage": 16, "poise": 20, "knockback": 6.0, "hitstop": 0.05, "shake": 0.3, "unblockable": true}
			target.take_damage(Combat.make_damage(self, wave, 16.0 * float(data.get("damage_scale", 1.0)), target.global_position))
	if shockwave_radius > 14.0:
		shockwave_radius = -1.0

func _throw_blades() -> void:
	if target == null:
		return
	var base: Vector3 = (target.global_position - global_position)
	base.y = 0.0
	base = base.normalized()
	for angle: float in [-0.35, 0.0, 0.35]:
		var blade: WindProjectile = WindProjectile.new()
		get_parent().add_child(blade)
		var wave: Dictionary = {"damage": 12, "poise": 10, "knockback": 3.0, "hitstop": 0.04, "shake": 0.2}
		blade.max_distance = 18.0
		blade.pierce = false
		blade.launch(global_position + Vector3.UP * 1.3, base.rotated(Vector3.UP, angle), 11.0, 12.0 * float(data.get("damage_scale", 1.0)), wave, Combat.LAYER_HURT_PLAYER, self, Color(1.0, 0.6, 0.45))

func take_damage(damage: Combat.Damage) -> Dictionary:
	var result: Dictionary = super.take_damage(damage)
	if phase == 1 and health > 0.0 and health <= max_health * 0.5:
		_enter_phase_two()
	return result

func _enter_phase_two() -> void:
	phase = 2
	base_speed_scale = 1.18
	poise = max_poise
	stagger_time = 0.0
	_release_token()
	invulnerable = true
	state = "roar"
	state_time = 0.0
	visual.play_action("roar")
	emit_signal("phase_changed", 2)
	Vfx.ring(get_parent(), global_position + Vector3.UP * 0.5, 7.0, Color(1.0, 0.5, 0.35), 0.8, 0.3)
	if target and _flat_distance(target.global_position) < 6.0:
		var push: Dictionary = {"damage": 8, "poise": 20, "knockback": 9.0, "hitstop": 0.05, "shake": 0.5, "unblockable": true}
		target.take_damage(Combat.make_damage(self, push, 8.0 * float(data.get("damage_scale", 1.0)), target.global_position))

func _think(delta: float) -> void:
	if state == "roar":
		_stop(delta)
		if state_time >= 1.6:
			invulnerable = false
			_set_state("chase")
		return
	super._think(delta)

func on_parried(_player: Node) -> void:
	if state == "dead":
		return
	poise -= 55.0
	if poise <= 0.0:
		poise = max_poise
		_stagger(2.4)
	else:
		state = "hit"
		state_time = 0.0
		visual.play_action("hit")
