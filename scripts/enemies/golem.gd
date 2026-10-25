class_name Golem
extends Enemy
## Khôi lỗi đá, the stone golem guarding the eastern ruins (a miniboss with the HUD bar). It
## sleeps crouched ("dormant") until a foe comes near or strikes it, then rises (untouchable).
## Heavy armour ("defense", eased by Nứt giáp), never flinches. Hammer punch up close, a ground
## slam whose ring warns before it lands (unblockable), and a thrown boulder at range. Below half
## health it roars, quickens, and every slam also sends rock spikes bursting up around it.

signal phase_changed(phase: int)

const WAKE_RANGE: float = 9.0
const WAKE_TIME: float = 2.4

var phase: int = 1
var dormant: bool = false

func setup(entity: Dictionary, library: AssetLibrary, world_manager: WorldManager) -> void:
	super.setup(entity, library, world_manager)
	dormant = bool(data.get("dormant", false))

func activate(position_value: Vector3, player: PlayerController) -> void:
	super.activate(position_value, player)
	if dormant:
		state = "dormant"
		visual.play_loop("awaken", 0.0)
		visual.player.seek(0.0, true)
		visual.player.pause()

func is_dormant() -> bool:
	return state == "dormant"

func wake() -> void:
	if state != "dormant":
		return
	dormant = false
	state = "waking"
	state_time = 0.0
	invulnerable = true
	visual.play_action("awaken")
	Vfx.crack(get_parent(), global_position, 3.0, Color("ffb347"))
	Vfx.burst(get_parent(), global_position + Vector3.UP, Color(0.75, 0.68, 0.55), 30, 6.0, 0.15, 0.8)
	if target:
		target.camera_rig.add_trauma(0.4)
	emit_signal("attack_started", self, "awaken")

func _think(delta: float) -> void:
	match state:
		"dormant":
			_stop(delta)
			if target and not target.is_dead() and _flat_distance(target.global_position) < WAKE_RANGE:
				wake()
			return
		"waking":
			_stop(delta)
			if state_time >= WAKE_TIME:
				invulnerable = false
				_set_state("chase")
			return
		"roar":
			_stop(delta)
			if state_time >= 1.8:
				invulnerable = false
				_set_state("chase")
			return
	super._think(delta)

func _choose_attack(distance: float) -> String:
	if distance > 4.5:
		return "throw"
	return "slam" if randf() < (0.45 if phase == 2 else 0.3) else "punch"

func _physics_chase(delta: float) -> void:
	# The boulder: from mid range, when ready, without walking all the way in.
	if target and cooldown <= 0.0:
		var distance: float = _flat_distance(target.global_position)
		if distance > 6.0 and distance < float(data.get("throw_range", 18.0)) and _can_see_target(distance + 1.0):
			_begin_attack("throw")
			return
	super._physics_chase(delta)

func _begin_attack(name: String) -> void:
	super._begin_attack(name)
	if name == "slam":
		var slam: AreaEffect = AreaEffect.spawn(self, attack_data, float(data.get("damage_scale", 1.0)), "strikes", Color("ffb347"), Combat.LAYER_HURT_PLAYER)
		var center: Vector3 = global_position + facing * 1.4
		var lands: float = float(attack_data.get("hit_start", 1.4)) / maxf(speed_scale, 0.1)
		slam.add_strike(center, lands, float(attack_data.get("strike_radius", 4.2)))
		if phase == 2:
			# Rock spikes burst up in a ring a beat after the slam.
			for index: int in range(6):
				var angle: float = TAU * index / 6.0
				slam.add_strike(global_position + Vector3(cos(angle), 0, sin(angle)) * 6.0, lands + 0.35 + index * 0.05, 1.6)

func _attack_window(t: float, hit_start: float, hit_end: float) -> void:
	match attack_name:
		"slam":
			if not attack_hits.has("landed"):
				attack_hits["landed"] = true
				Vfx.crack(get_parent(), global_position + facing * 1.4, 3.4, Color("ffb347"))
				Vfx.rock_spikes(get_parent(), global_position + facing * 1.4, 3.0, 8, 1.6)
				if target:
					target.camera_rig.add_trauma(0.55)
		"throw":
			if not attack_hits.has("thrown"):
				attack_hits["thrown"] = true
				var hand: Vector3 = global_position + Vector3.UP * float(data.get("height", 3.4)) * 0.95 + facing * 0.6
				fire_missile(hand, aim_point(float(attack_data.get("missile_speed", 16.0)), 0.4) + Vector3.DOWN * 0.8, attack_data, "rock", Color(0.75, 0.68, 0.55))
		_:
			super._attack_window(t, hit_start, hit_end)

func take_damage(damage: Combat.Damage) -> Dictionary:
	if state == "dormant":
		wake()
		return {"hit": false}
	var result: Dictionary = super.take_damage(damage)
	if phase == 1 and health > 0.0 and health <= max_health * 0.5:
		_enter_phase_two()
	return result

func _enter_phase_two() -> void:
	phase = 2
	base_speed_scale = 1.2
	poise = max_poise
	broken = false
	finish_time = 0.0
	_release_token()
	invulnerable = true
	state = "roar"
	state_time = 0.0
	visual.play_action("roar")
	Vfx.ring(get_parent(), global_position + Vector3.UP * 0.5, 7.0, Color("ffb347"), 0.8, 0.3)
	Vfx.rock_spikes(get_parent(), global_position, 5.0, 12, 1.8, 1.4)
	emit_signal("phase_changed", 2)

func on_parried(_player: Node) -> void:
	if state == "dead":
		return
	poise -= 40.0
	if poise <= 0.0:
		_break(2.4)
