class_name PlayerController
extends CharacterBody3D
## Lâm An: movement (run, sprint, dodge, jump, khinh công leap and glide) and
## sword combat (3-hit combo, charged heavy, parry/block, two wind skills).

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal died
signal hazard(kind: String)
signal attack_landed(target: Node, amount: float)
signal parried(enemy: Node)
signal footstep(surface: String)
signal skill_used(skill: String, cooldown: float)
signal notice(text: String)

const SKILL_COOLDOWN: Dictionary = {"gust": 6.0, "cyclone": 14.0}
const HEAL_ITEMS: Array = [["tra_sen", 0.65], ["banh_ngai", 0.4]]

var settings: GameSettings
var assets: AssetLibrary
var game: GameState
var world: WorldManager
var visual: CharacterVisual
var camera_rig: CameraRig
var hurtbox: Area3D
var state: String = "loading"
var input_enabled: bool = true
var health: float = 120.0
var stamina: float = 100.0
var max_stamina: float = 100.0
var stamina_delay: float = 0.0
var facing: Vector3 = Vector3.FORWARD
var model_yaw: float = 0.0
var action: Dictionary = {}
var combo_index: int = 0
var buffered: String = ""
var buffer_time: float = 0.0
var attack_held: float = -1.0
var block_held: bool = false
var invulnerable: float = 0.0
var hit_cooldown: float = 0.0
var counter_bonus: float = 0.0
var cooldowns: Dictionary = {"gust": 0.0, "cyclone": 0.0}
var used_leap: bool = false
var gliding: bool = false
var sprinting: bool = false
var dodge_time: float = 0.0
var dodge_direction: Vector3 = Vector3.FORWARD
var hit_time: float = 0.0
var combat_timer: float = 99.0
var last_safe: Vector3 = Vector3.ZERO
var safe_timer: float = 0.0
var step_distance: float = 0.0
var was_on_floor: bool = true
var fall_speed: float = 0.0
var lock_target: Node3D

func initialize(config: GameSettings, library: AssetLibrary = null, state_data: GameState = null) -> void:
	settings = config
	assets = library
	game = state_data if state_data else GameState.new()
	collision_layer = Combat.LAYER_PLAYER
	collision_mask = Combat.LAYER_WORLD | Combat.LAYER_ENEMY | Combat.LAYER_NPC
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	visual = CharacterVisual.new()
	visual.name = "Visual"
	add_child(visual)
	if assets:
		visual.setup(assets, "lam_an", true)
		visual.attach_weapon(assets, game.sword)
	hurtbox = Combat.make_hurtbox(self, Combat.LAYER_HURT_PLAYER, 0.4, 1.7)
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.setup(self, get_rid())
	camera_rig.sensitivity = settings.mouse_sensitivity
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(48)
	health = game.health if game.health > 0.0 else game.max_health()
	last_safe = global_position

# ------------------------------------------------------------------ queries

func max_health() -> float:
	return game.max_health()

func is_dead() -> bool:
	return state == "dead"

func is_busy() -> bool:
	return state in ["action", "dodge", "hit", "dead", "disabled"]

func current_action() -> String:
	return String(action.get("name", ""))

func teleport(point: Vector3) -> void:
	global_position = point
	velocity = Vector3.ZERO
	last_safe = point
	if camera_rig:
		camera_rig.global_position = point + Vector3.UP * 1.45

func face_direction(direction: Vector3, instant: bool = false) -> void:
	direction.y = 0.0
	if direction.length() < 0.01:
		return
	facing = direction.normalized()
	var target_yaw: float = atan2(facing.x, facing.z)
	model_yaw = target_yaw if instant else lerp_angle(model_yaw, target_yaw, 0.35)
	if visual:
		visual.rotation.y = model_yaw

# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or state in ["dead", "disabled", "loading"]:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and (event is InputEventMouseButton):
		return
	if event.is_action_pressed("attack"):
		attack_held = 0.0
	elif event.is_action_released("attack"):
		if attack_held >= 0.0 and attack_held < 0.4:
			queue_input("attack")
		attack_held = -1.0
	elif event.is_action_pressed("block"):
		block_held = true
		queue_input("parry")
	elif event.is_action_released("block"):
		block_held = false
	elif event.is_action_pressed("sprint"):
		queue_input("dodge")
	elif event.is_action_pressed("skill_1"):
		queue_input("gust")
	elif event.is_action_pressed("skill_2"):
		queue_input("cyclone")
	elif event.is_action_pressed("heal"):
		queue_input("heal")
	elif event.is_action_pressed("lock_on"):
		toggle_lock()
	elif event.is_action_pressed("jump"):
		queue_input("jump")

func queue_input(command: String) -> void:
	buffered = command
	buffer_time = 0.35

func move_axis() -> Vector2:
	if not input_enabled or state in ["dead", "disabled"]:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func move_direction() -> Vector3:
	var axis: Vector2 = move_axis()
	if axis.length_squared() < 0.01:
		return Vector3.ZERO
	var basis: Basis = Basis(Vector3.UP, camera_rig.yaw if camera_rig else 0.0)
	var direction: Vector3 = basis * Vector3(axis.x, 0, axis.y)
	return direction.normalized() * minf(1.0, axis.length())

# ------------------------------------------------------------------ main loop

func _physics_process(delta: float) -> void:
	if world == null or not world.is_position_ready(global_position):
		if state != "dead":
			state = "loading" if state in ["loading", "move"] else state
		velocity = Vector3.ZERO
		return
	if state == "loading":
		state = "move"
	_tick_timers(delta)
	# Button releases can be missed while paused, in dialogue or dead: trust the real button state.
	if not (input_enabled and Input.is_action_pressed("block")):
		block_held = false
	if attack_held >= 0.0 and not (input_enabled and Input.is_action_pressed("attack")):
		attack_held = -1.0
	fall_speed = velocity.y
	if attack_held >= 0.0 and input_enabled:
		attack_held += delta
		if attack_held >= 0.4 and state == "move" and is_on_floor():
			attack_held = -1.0
			_start_action("heavy")
	match state:
		"move":
			_physics_move(delta)
		"dodge":
			_physics_dodge(delta)
		"action":
			_physics_action(delta)
		"hit":
			_physics_hit(delta)
		"dead", "disabled":
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
			_apply_gravity(delta)
			move_and_slide()
	_after_move(delta)

func _tick_timers(delta: float) -> void:
	buffer_time -= delta
	if buffer_time <= 0.0:
		buffered = ""
	invulnerable = maxf(0.0, invulnerable - delta)
	hit_cooldown = maxf(0.0, hit_cooldown - delta)
	counter_bonus = maxf(0.0, counter_bonus - delta)
	combat_timer += delta
	for skill: String in cooldowns:
		cooldowns[skill] = maxf(0.0, cooldowns[skill] - delta)
	stamina_delay -= delta
	var draining: bool = (state == "move" and (sprinting or gliding)) or state == "dodge" or (state == "move" and block_held and is_on_floor() and current_action() == "")
	if stamina_delay <= 0.0 and not draining and stamina < max_stamina:
		set_stamina(stamina + 32.0 * delta)
	game.play_time += delta
	if lock_target and (not is_instance_valid(lock_target) or lock_target.is_queued_for_deletion() or (lock_target.has_method("is_dead") and lock_target.is_dead())
			or lock_target.global_position.distance_to(global_position) > 26.0):
		set_lock(null)
	if lock_target and camera_rig:
		var flick: int = camera_rig.consume_flick()
		if flick != 0:
			_switch_lock(flick)

func _apply_gravity(delta: float) -> void:
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = -0.5
	else:
		velocity.y -= settings.gravity * delta

func _physics_move(delta: float) -> void:
	var direction: Vector3 = move_direction()
	var on_floor: bool = is_on_floor()
	sprinting = Input.is_action_pressed("sprint") and input_enabled and direction != Vector3.ZERO and stamina > 1.0 and on_floor and not block_held
	if sprinting:
		set_stamina(stamina - 14.0 * delta)
		stamina_delay = 0.6
	var speed: float = settings.sprint_speed if sprinting else settings.walk_speed
	if block_held and on_floor:
		speed = 2.2
	var target: Vector3 = direction * speed
	var accel: float = settings.acceleration * (1.0 if on_floor else 0.45)
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	if on_floor:
		used_leap = false
		gliding = false
		if buffered == "jump":
			buffered = ""
			velocity.y = settings.jump_speed
			visual.set_state("jump")
			emit_signal("footstep", "jump")
		else:
			_apply_gravity(delta)
	else:
		_physics_air(delta, direction)
	if direction != Vector3.ZERO and not (lock_target and block_held):
		face_direction(direction)
	elif lock_target and block_held:
		face_direction(lock_target.global_position - global_position)
	move_and_slide()
	_consume_ground_commands(on_floor)
	_update_locomotion_visual()

func _physics_air(delta: float, direction: Vector3) -> void:
	var khinh: bool = game.skill_level("khinh_cong") > 0
	if buffered == "jump" and khinh and not used_leap and stamina >= 20.0:
		buffered = ""
		used_leap = true
		set_stamina(stamina - 22.0)
		stamina_delay = 0.8
		velocity.y = 9.0
		var push: Vector3 = (direction if direction != Vector3.ZERO else facing) * maxf(Vector2(velocity.x, velocity.z).length(), 8.5)
		velocity.x = push.x
		velocity.z = push.z
		visual.play_action("air_leap")
		Vfx.ring(get_parent(), global_position + Vector3.UP * 0.2, 1.6, Vfx.WIND, 0.4)
		emit_signal("footstep", "leap")
		return
	gliding = khinh and Input.is_action_pressed("jump") and input_enabled and velocity.y < 0.0 and stamina > 0.5
	if gliding:
		velocity.y = maxf(velocity.y - settings.gravity * delta * 0.3, -2.4)
		var glide: Vector3 = (direction if direction != Vector3.ZERO else facing) * 7.0
		velocity.x = move_toward(velocity.x, glide.x, 10.0 * delta)
		velocity.z = move_toward(velocity.z, glide.z, 10.0 * delta)
		set_stamina(stamina - 10.0 * delta)
		stamina_delay = 0.6
	else:
		velocity.y -= settings.gravity * delta

func _consume_ground_commands(on_floor: bool) -> void:
	if buffered == "" or not input_enabled:
		return
	var command: String = buffered
	if command == "dodge" and on_floor and stamina >= 12.0:
		buffered = ""
		_start_dodge()
	elif command == "attack" and on_floor:
		buffered = ""
		_start_action("attack_1")
	elif command == "parry" and on_floor:
		buffered = ""
		_start_action("parry")
	elif command in ["gust", "cyclone"]:
		buffered = ""
		_try_skill(command)
	elif command == "heal" and on_floor:
		buffered = ""
		_try_heal()

func _update_locomotion_visual() -> void:
	var horizontal: float = Vector2(velocity.x, velocity.z).length()
	visual.set_locomotion(horizontal)
	if state == "move":
		if is_on_floor():
			visual.set_state("block" if block_held and current_action() == "" else "ground")
		elif gliding:
			visual.set_state("glide")
		elif velocity.y > 0.5:
			visual.set_state("jump")
		else:
			visual.set_state("fall")

# ------------------------------------------------------------------ dodge

func _start_dodge() -> void:
	set_stamina(stamina - 20.0)
	stamina_delay = 0.8
	state = "dodge"
	dodge_time = 0.0
	var direction: Vector3 = move_direction()
	dodge_direction = direction.normalized() if direction != Vector3.ZERO else facing
	face_direction(dodge_direction, true)
	action = {}
	visual.play_action("dodge")
	var timing: Dictionary = ContentDB.timing("player", "dodge")
	invulnerable = float(timing.get("hit_end", 0.34))
	emit_signal("footstep", "dodge")
	Vfx.burst(get_parent(), global_position + Vector3.UP * 0.2, Color(0.85, 0.9, 0.8, 0.6), 10, 2.0, 0.12, 0.4)

func _physics_dodge(delta: float) -> void:
	dodge_time += delta
	var length: float = float(ContentDB.timing("player", "dodge").get("length", 0.5))
	var speed: float = lerpf(12.5, 2.0, clampf(dodge_time / (length * 0.8), 0.0, 1.0))
	velocity.x = dodge_direction.x * speed
	velocity.z = dodge_direction.z * speed
	_apply_gravity(delta)
	move_and_slide()
	visual.set_locomotion(speed)
	if dodge_time >= float(ContentDB.timing("player", "dodge").get("recover", 0.4)):
		state = "move"
		if buffered == "attack":
			buffered = ""
			_start_action("attack_1")

# ------------------------------------------------------------------ actions

func _try_skill(skill: String) -> void:
	if game.skill_level(skill) <= 0:
		emit_signal("notice", "Chưa lĩnh hội chiêu này")
		return
	if cooldowns[skill] > 0.0:
		return
	_start_action("skill_gust" if skill == "gust" else "skill_cyclone")
	var reduction: float = 1.0 - 0.15 * (game.skill_level(skill) - 1)
	cooldowns[skill] = SKILL_COOLDOWN[skill] * reduction
	emit_signal("skill_used", skill, cooldowns[skill])

func _try_heal() -> void:
	if health >= max_health() - 0.5:
		emit_signal("notice", "Khí huyết đang đầy")
		return
	for entry: Array in HEAL_ITEMS:
		if game.count(entry[0]) > 0:
			_start_action("interact")
			action["heal_item"] = entry[0]
			action["heal_ratio"] = entry[1]
			return
	emit_signal("notice", "Không còn thuốc hồi phục")

func _start_action(anim_name: String) -> void:
	var data: Dictionary = Combat.attack("player", anim_name)
	if data.is_empty():
		data = {"length": visual.animation_length(anim_name), "hit_start": 99.0, "hit_end": 99.0, "combo_open": 99.0, "recover": visual.animation_length(anim_name)}
	if anim_name == "interact":
		data["length"] = 0.6
		data["recover"] = 0.55
	var cost: float = float(data.get("stamina", 0.0))
	if cost > 0.0:
		if stamina < cost * 0.5:
			emit_signal("notice", "Không đủ thể lực")
			return
		set_stamina(stamina - cost)
		stamina_delay = 0.8
	state = "action"
	action = {"name": anim_name, "data": data, "t": 0.0, "hits": {}, "prev_u": -1.0, "fired": false, "tick": 0.0, "healed": false}
	combat_timer = 0.0 if anim_name != "interact" else combat_timer
	visual.set_sheathed(false)
	visual.play_action(anim_name)
	var aim: Vector3 = _aim_direction()
	if aim != Vector3.ZERO:
		face_direction(aim, true)
	if anim_name.begins_with("attack") or anim_name in ["heavy", "skill_gust", "skill_cyclone"]:
		emit_signal("footstep", "swing")

func _aim_direction() -> Vector3:
	if lock_target and is_instance_valid(lock_target):
		return lock_target.global_position - global_position
	var input: Vector3 = move_direction()
	var best: Node3D = null
	var best_score: float = 0.0
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: Node3D = node as Node3D
		if enemy == null or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance > 4.5 or distance < 0.01:
			continue
		var reference: Vector3 = input if input != Vector3.ZERO else facing
		var score: float = offset.normalized().dot(reference.normalized()) - distance * 0.08
		if score > 0.3 and score > best_score:
			best_score = score
			best = enemy
	if best:
		return best.global_position - global_position
	return input

func _physics_action(delta: float) -> void:
	var data: Dictionary = action["data"]
	if not visual.is_frozen():
		action["t"] = float(action["t"]) + delta
	var t: float = action["t"]
	var hit_start: float = float(data.get("hit_start", 99.0))
	var hit_end: float = float(data.get("hit_end", 99.0))
	var name: String = action["name"]
	var lunge: float = float(data.get("lunge", 0.0))
	var push: float = lunge * (1.0 - clampf(t / maxf(hit_end, 0.01), 0.0, 1.0)) if t < hit_end else 0.0
	if name == "parry" or name == "interact":
		push = 0.0
	if lock_target and t < hit_start and name != "interact":
		face_direction(lock_target.global_position - global_position)
	var target_velocity: Vector3 = facing * push
	velocity.x = move_toward(velocity.x, target_velocity.x, 40.0 * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, 40.0 * delta)
	_apply_gravity(delta)
	if not visual.is_frozen():
		move_and_slide()
	if name == "interact":
		if t >= 0.35 and not action["healed"] and action.has("heal_item"):
			action["healed"] = true
			if game.remove_item(action["heal_item"]):
				heal(max_health() * float(action["heal_ratio"]))
				Vfx.wisps(self, Color(0.7, 1.0, 0.75), 12, 0.6).emitting = true
				emit_signal("footstep", "heal")
	elif name == "parry":
		if t > hit_end and block_held and t >= float(data.get("combo_open", 0.3)):
			_finish_action()
			return
	elif t >= hit_start and t <= hit_end + delta:
		_resolve_hits(name, data, t, hit_start, hit_end)
	if t >= float(data.get("combo_open", 99.0)) and buffered != "":
		var next: String = buffered
		if next == "attack" and name in ["attack_1", "attack_2"]:
			buffered = ""
			combo_index = 1 if name == "attack_1" else 2
			_start_action("attack_2" if name == "attack_1" else "attack_3")
			return
		if next == "attack" and name == "attack_3":
			buffered = ""
			_start_action("attack_1")
			return
		if next in ["gust", "cyclone"]:
			buffered = ""
			_try_skill(next)
			if state == "action" and current_action() != name:
				return
	if t >= hit_end and buffered == "dodge" and stamina >= 12.0 and is_on_floor():
		buffered = ""
		_start_dodge()
		return
	if t >= hit_end and buffered == "parry" and name != "parry" and is_on_floor():
		buffered = ""
		_start_action("parry")
		return
	if t >= float(data.get("recover", 0.5)) and (move_direction() != Vector3.ZERO or t >= float(data.get("length", 0.6))):
		_finish_action()

func _finish_action() -> void:
	if current_action() != "parry" or not block_held:
		visual.stop_action()
	action = {}
	state = "move"

func _resolve_hits(name: String, data: Dictionary, t: float, hit_start: float, hit_end: float) -> void:
	if not action["fired"]:
		action["fired"] = true
		if name != "skill_cyclone":
			Vfx.slash(get_parent(), global_position, facing, data, Color(0.85, 1.0, 0.95, 0.9) if name.begins_with("skill") else Color(1, 1, 1, 0.8))
		if data.get("projectile", false):
			var blade: WindProjectile = WindProjectile.new()
			get_parent().add_child(blade)
			var level_bonus: float = 1.0 + 0.25 * (game.skill_level("gust") - 1)
			blade.launch(global_position + Vector3.UP * 1.1 + facing * 0.8, facing, 22.0, game.attack_power() * float(data["mult"]) * level_bonus, data, Combat.LAYER_HURT_ENEMY, self)
			emit_signal("footstep", "wind")
	if data.get("projectile", false):
		return  # Phong Trảm damages only through its wind blade, never twice up close.
	if name == "skill_cyclone":
		action["tick"] = float(action["tick"]) - get_physics_process_delta_time()
		if float(action["tick"]) <= 0.0:
			action["tick"] = float(data.get("tick", 0.13))
			action["hits"] = {}
			Vfx.ring(get_parent(), global_position + Vector3.UP * 0.6, 3.3, Vfx.WIND, 0.25, 0.12)
			_hit_targets(Combat.sweep(self, facing, data, 0.0, 0.0, Combat.LAYER_HURT_ENEMY, action["hits"]), data, 1.0 + 0.25 * (game.skill_level("cyclone") - 1))
		return
	var u: float = clampf((t - hit_start) / maxf(hit_end - hit_start, 0.001), 0.0, 1.0)
	var previous: float = maxf(float(action["prev_u"]), 0.0)
	action["prev_u"] = u
	_hit_targets(Combat.sweep(self, facing, data, previous, u, Combat.LAYER_HURT_ENEMY, action["hits"]), data, 1.0)

func _hit_targets(areas: Array[Area3D], data: Dictionary, bonus: float) -> void:
	for area: Area3D in areas:
		var entity: Node = Combat.entity_of(area)
		if entity == null or entity == self or not entity.has_method("take_damage"):
			continue
		var amount: float = game.attack_power() * float(data.get("mult", 1.0)) * bonus
		if counter_bonus > 0.0:
			amount *= 1.5
			counter_bonus = 0.0
		var damage: Combat.Damage = Combat.make_damage(self, data, amount, (entity as Node3D).global_position)
		if float(data.get("knockback", 0.0)) < 0.0:
			damage.direction = -damage.direction
			damage.knockback = absf(damage.knockback)
		var result: Dictionary = entity.take_damage(damage)
		if result.get("hit", false):
			visual.hitstop(damage.hitstop)
			camera_rig.add_trauma(damage.shake)
			Vfx.burst(get_parent(), damage.position, Vfx.SPARK if not current_action().begins_with("skill") else Vfx.WIND, 16, 6.0)
			emit_signal("attack_landed", entity, float(result.get("amount", amount)))

# ------------------------------------------------------------------ damage

func take_damage(damage: Combat.Damage) -> Dictionary:
	if state in ["dead", "disabled", "loading"]:
		return {"hit": false}
	var from_front: bool = facing.dot(-damage.direction) > 0.2
	var parry_window: bool = current_action() == "parry" and float(action.get("t", 9.0)) <= float((action["data"] as Dictionary).get("hit_end", 0.2))
	var parries: bool = parry_window and from_front and not damage.unblockable
	if invulnerable > 0.0 and not parries:
		return {"hit": false, "dodged": state == "dodge"}
	if parries:
		visual.hitstop(0.12)
		camera_rig.add_trauma(0.25)
		Vfx.burst(get_parent(), global_position + Vector3.UP * 1.2 + facing * 0.6, Color(1.0, 0.95, 0.7), 26, 7.0, 0.07)
		Vfx.glint(get_parent(), global_position + Vector3.UP * 1.3 + facing * 0.7, Color(1, 1, 0.85), 1.2)
		counter_bonus = 2.5
		set_stamina(stamina + 12.0)
		# Deflecting a projectile protects the player but does not stagger the distant thrower.
		if damage.source and damage.source.has_method("on_parried") and not damage.ranged:
			damage.source.on_parried(self)
		emit_signal("parried", damage.source)
		return {"hit": false, "parried": true}
	var blocking: bool = (current_action() == "parry" or (state == "move" and block_held and is_on_floor())) and from_front
	if blocking and not damage.unblockable:
		var chip: float = damage.amount * 0.15
		set_stamina(stamina - damage.amount * 1.2)
		stamina_delay = 1.0
		_apply_damage(chip)
		if health <= 0.0:
			_die()
			return {"hit": true, "blocked": true, "amount": chip, "killed": true}
		velocity += damage.direction * damage.knockback * 0.6
		camera_rig.add_trauma(0.15)
		Vfx.burst(get_parent(), global_position + Vector3.UP * 1.2 + facing * 0.6, Color(0.9, 0.95, 1.0), 12, 4.0, 0.06)
		emit_signal("footstep", "block")
		if stamina <= 0.0:
			_enter_hit(damage, 0.8)
			emit_signal("notice", "Phá thế đỡ!")
		return {"hit": true, "blocked": true, "amount": chip}
	_apply_damage(damage.amount)
	visual.flash(Color(1.0, 0.55, 0.45))
	camera_rig.add_trauma(damage.shake + 0.15)
	Vfx.burst(get_parent(), global_position + Vector3.UP * 1.1, Color(1.0, 0.5, 0.4), 12, 4.0)
	if health <= 0.0:
		_die()
	elif hit_cooldown <= 0.0:
		_enter_hit(damage, 0.35)
	return {"hit": true, "amount": damage.amount}

func _apply_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	game.health = health
	emit_signal("health_changed", health, max_health())

func _enter_hit(damage: Combat.Damage, duration: float) -> void:
	state = "hit"
	hit_time = duration
	hit_cooldown = duration + 0.5
	invulnerable = 0.25
	action = {}
	velocity = damage.direction * damage.knockback
	velocity.y = 1.5 if damage.knockback > 4.0 else velocity.y
	face_direction(-damage.direction, true)
	visual.play_action("hit")

func _physics_hit(delta: float) -> void:
	hit_time -= delta
	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
	_apply_gravity(delta)
	move_and_slide()
	if hit_time <= 0.0:
		state = "move"

func _die() -> void:
	state = "dead"
	action = {}
	set_lock(null)
	visual.stop_action()
	visual.set_state("dead")
	emit_signal("died")

func heal(amount: float) -> void:
	health = minf(max_health(), health + amount)
	game.health = health
	emit_signal("health_changed", health, max_health())

func set_stamina(value: float) -> void:
	stamina = clampf(value, 0.0, max_stamina)
	emit_signal("stamina_changed", stamina, max_stamina)

func revive(point: Vector3) -> void:
	teleport(point)
	health = max_health()
	game.health = health
	stamina = max_stamina
	state = "move"
	action = {}
	invulnerable = 1.5
	visual.stop_action()
	visual.set_state("ground")
	emit_signal("health_changed", health, max_health())
	emit_signal("stamina_changed", stamina, max_stamina)

# ------------------------------------------------------------------ lock-on

func toggle_lock() -> void:
	if lock_target:
		set_lock(null)
		return
	set_lock(_find_lock_candidate(0))

func set_lock(target: Node3D) -> void:
	lock_target = target
	if camera_rig:
		camera_rig.set_lock(target)

func _lock_candidates() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: Node3D = node as Node3D
		if enemy and not (enemy.has_method("is_dead") and enemy.is_dead()) and enemy.global_position.distance_to(global_position) < 20.0:
			result.append(enemy)
	return result

func _find_lock_candidate(side: int) -> Node3D:
	var forward: Vector3 = camera_rig.forward() if camera_rig else facing
	var best: Node3D = null
	var best_score: float = -INF
	for enemy: Node3D in _lock_candidates():
		if enemy == lock_target:
			continue
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		var angle: float = forward.signed_angle_to(offset.normalized(), Vector3.UP)
		if side == 0 and absf(angle) > 1.1:
			continue
		if side != 0 and sign(-angle) != side:
			continue
		var score: float = -absf(angle) * 4.0 - offset.length() * 0.15
		if score > best_score:
			best_score = score
			best = enemy
	return best

func _switch_lock(side: int) -> void:
	var next: Node3D = _find_lock_candidate(side)
	if next:
		set_lock(next)

# ------------------------------------------------------------------ after move

func _after_move(delta: float) -> void:
	var on_floor: bool = is_on_floor()
	if on_floor and not was_on_floor and state == "move":
		emit_signal("footstep", "land")
		if fall_speed < -9.0:
			visual.play_action("land")
	was_on_floor = on_floor
	var horizontal: float = Vector2(velocity.x, velocity.z).length()
	if on_floor and state in ["move", "dodge"] and horizontal > 0.8:
		step_distance += horizontal * delta
		var stride: float = 1.7 if sprinting else 1.25
		if step_distance >= stride:
			step_distance = 0.0
			emit_signal("footstep", surface_under())
	if combat_timer > 6.0 and state == "move" and visual and visual.weapon and visual.weapon.get_parent() == visual.sword_socket:
		var calm: bool = true
		for node: Node in get_tree().get_nodes_in_group("enemy"):
			if (node as Node3D).global_position.distance_to(global_position) < 16.0 and not (node.has_method("is_dead") and node.is_dead()):
				calm = false
				break
		if calm:
			visual.set_sheathed(true)
	_check_hazards(delta, on_floor)

func surface_under() -> String:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.4, global_position + Vector3.DOWN * 0.6, Combat.LAYER_WORLD)
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit["collider"]
		var node: Node = collider as Node
		while node:
			if node.has_meta("surface"):
				var surface: String = node.get_meta("surface")
				if surface != "grass":
					return surface
				break
			node = node.get_parent()
	return world.layout.surface_at(global_position.x, global_position.z)

func _check_hazards(delta: float, on_floor: bool) -> void:
	if state in ["dead", "disabled", "loading"]:
		return
	var water: Dictionary = world.layout.water_at(global_position.x, global_position.z)
	if not water.is_empty() and global_position.y < float(water["level"]) - 0.75:
		emit_signal("hazard", "water")
		return
	var ground: float = world.height_at(global_position.x, global_position.z)
	var chasm: bool = world.layout.in_chasm(global_position.x, global_position.z)
	if global_position.y < ground - 6.0 or global_position.y < -60.0 or (chasm and global_position.y < last_safe.y - 4.5):
		emit_signal("hazard", "fall")
		return
	safe_timer -= delta
	if on_floor and safe_timer <= 0.0 and water.is_empty() and not world.layout.in_chasm(global_position.x, global_position.z):
		safe_timer = 0.5
		var near_edge: bool = world.layout.in_chasm(global_position.x, global_position.z + 3.0) or world.layout.in_chasm(global_position.x, global_position.z - 3.0)
		if not near_edge:
			last_safe = global_position
