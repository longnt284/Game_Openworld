class_name Enemy
extends CharacterBody3D
## Shared enemy brain: patrol → detect → chase → telegraphed attack → recover,
## with stagger, leash/return and death. Movement uses the navigation map when an
## encounter zone is baked, otherwise steering with obstacle probes. Never leaves
## loaded terrain, never walks into water or chasms.

signal defeated(enemy: Enemy)
signal health_changed(enemy: Enemy, current: float, maximum: float)
signal attack_started(enemy: Enemy, attack: String)
signal status_damage(enemy: Enemy, amount: float, status: String)

static var tokens: Dictionary = {}

var data: Dictionary = {}
var kind: String = ""
var owner_key: String = "bandit"
var entity_id: String = ""
var camp: String = ""
var home: Vector3
var world: WorldManager
var assets: AssetLibrary
var visual: CharacterVisual
var hurtbox: Area3D
var nav: NavigationAgent3D
var target: PlayerController
var health: float = 60.0
var max_health: float = 60.0
var poise: float = 30.0
var max_poise: float = 30.0
var state: String = "idle"
var state_time: float = 0.0
var attack_name: String = ""
var attack_data: Dictionary = {}
var attack_hits: Dictionary = {}
var attack_prev_u: float = -1.0
var telegraphed: bool = false
var cooldown: float = 1.0
var wander_target: Vector3
var stagger_time: float = 0.0
var facing: Vector3 = Vector3.FORWARD
var speed_scale: float = 1.0
## Speed before statuses: the guardian raises it in phase two; chill and soak slow it.
var base_speed_scale: float = 1.0
## Attack clock in animation seconds, so a slow mid-swing stretches the swing instead of rewinding it.
var attack_clock: float = 0.0
var statuses: StatusEffects = StatusEffects.new()
var shown_status: String = ""
var persistent: bool = false
var boss: bool = false
var invulnerable: bool = false
var death_timer: float = 0.0
var stuck_time: float = 0.0
var last_position: Vector3
var body_shape: CollisionShape3D
var blocked_time: float = 0.0
var quadruped: bool = false

func setup(entity: Dictionary, library: AssetLibrary, world_manager: WorldManager) -> void:
	data = ContentDB.enemy(String(entity["enemy"]))
	kind = String(entity["enemy"])
	owner_key = String(data.get("owner", "bandit"))
	entity_id = String(entity["id"])
	camp = String(entity.get("camp", ""))
	persistent = bool(entity.get("persistent", false))
	assets = library
	world = world_manager
	max_health = float(data.get("hp", 60))
	health = max_health
	max_poise = float(data.get("poise", 30))
	poise = max_poise
	statuses.resist = float(data.get("status_resist", 0.0))
	statuses.no_freeze = bool(data.get("armor", false))
	collision_layer = Combat.LAYER_ENEMY
	collision_mask = Combat.LAYER_WORLD | Combat.LAYER_PLAYER | Combat.LAYER_ENEMY
	var radius: float = float(data.get("radius", 0.4))
	var height: float = float(data.get("height", 1.8))
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(height, radius * 2.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = height * 0.5
	quadruped = bool(data.get("quadruped", false))
	if quadruped:
		collision.rotation.x = PI * 0.5
		capsule.height = float(data.get("length", 1.4))
		collision.position.y = radius + 0.05
	add_child(collision)
	body_shape = collision
	visual = CharacterVisual.new()
	add_child(visual)
	visual.setup(assets, String(data["model"]), false)
	if data.has("weapon"):
		visual.attach_weapon(assets, String(data["weapon"]))
	hurtbox = Combat.make_hurtbox(self, Combat.LAYER_HURT_ENEMY, radius + 0.15, height)
	if data.get("quadruped", false):
		(hurtbox.get_child(0) as CollisionShape3D).rotation.x = PI * 0.5
		(hurtbox.get_child(0) as CollisionShape3D).position.y = radius + 0.1
		((hurtbox.get_child(0) as CollisionShape3D).shape as CapsuleShape3D).height = float(data.get("length", 1.4)) + 0.2
	nav = NavigationAgent3D.new()
	nav.path_desired_distance = 0.7
	nav.target_desired_distance = 1.0
	nav.radius = radius
	nav.height = height
	add_child(nav)
	add_to_group("enemy")
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.5
	var yaw: float = deg_to_rad(float(entity.get("yaw", randf() * 360.0)))
	facing = Vector3(sin(yaw), 0.0, cos(yaw))
	_apply_facing(true)
	cooldown = randf_range(0.6, 1.4)

func activate(position_value: Vector3, player: PlayerController) -> void:
	global_position = position_value
	home = position_value
	wander_target = position_value
	last_position = position_value
	target = player
	visual.play_loop("idle")

func is_dead() -> bool:
	return state == "dead"

func display_name() -> String:
	return String(data.get("name", kind))

# ------------------------------------------------------------------ loop

func _physics_process(delta: float) -> void:
	if world == null or not world.is_position_ready(global_position):
		velocity = Vector3.ZERO
		return
	if state == "dead":
		state_time += delta
		_physics_dead(delta)
		return
	_tick_statuses(delta)
	if state == "dead":
		return
	# Hit-stop freezes the animation, so the attack clock and cooldown freeze with it.
	if not visual.is_frozen():
		state_time += delta
		cooldown -= delta
		_think(delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5
	if visual.is_frozen():
		return
	_guard_edges()
	move_and_slide()
	_track_stuck(delta)

func _tick_statuses(delta: float) -> void:
	var effects: Dictionary = statuses.tick(delta)
	speed_scale = base_speed_scale * statuses.speed_mult()
	if float(effects["dot"]) > 0.0:
		apply_dot(float(effects["dot"]), "burn")
	if float(effects["stun"]) > 0.0 and state in ["idle", "alert", "chase", "recover", "return"] or (float(effects["stun"]) > 0.0 and state == "attack" and not boss):
		_stagger(float(effects["stun"]))
	var dominant: String = statuses.dominant()
	if dominant != shown_status:
		shown_status = dominant
		visual.set_status_tint(Color(String(ContentDB.status(dominant).get("color", "ffffff"))) if dominant != "" else Color(0, 0, 0, 0))

func apply_dot(amount: float, status: String) -> void:
	## Quiet damage from a status: no flinch, flash or hit-stop.
	if state == "dead" or invulnerable or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	emit_signal("health_changed", self, health, max_health)
	emit_signal("status_damage", self, amount, status)
	if health <= 0.0:
		var damage: Combat.Damage = Combat.Damage.new()
		damage.direction = -facing
		_die(damage)

func _think(delta: float) -> void:
	match state:
		"idle":
			_physics_idle(delta)
		"alert":
			_stop(delta)
			_face_target(delta, 8.0)
			if state_time >= 0.7:
				_set_state("chase")
		"chase":
			_physics_chase(delta)
		"attack":
			_physics_attack(delta)
		"recover":
			_stop(delta)
			if state_time >= 0.5:
				_set_state("chase")
		"hit":
			velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
			if state_time >= 0.4:
				_set_state("chase")
		"stagger":
			velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
			if state_time >= stagger_time:
				poise = max_poise
				_set_state("chase")
		"return":
			_physics_return(delta)

func _set_state(next: String) -> void:
	if state == "attack" and next != "attack":
		_release_token()
	state = next
	state_time = 0.0
	match next:
		"idle", "recover":
			visual.play_loop("idle")
		"alert":
			if visual.has_animation("alert"):
				visual.play_action("alert")
			_alert_camp()
		"chase", "return":
			visual.play_loop("run" if next == "chase" else "walk")
		"stagger":
			visual.play_action("stagger")

# ------------------------------------------------------------------ states

func _physics_idle(delta: float) -> void:
	if _can_see_target(float(data.get("detect", 13.0))):
		_set_state("alert")
		return
	if global_position.distance_to(wander_target) < 0.8 or state_time > 9.0:
		state_time = 0.0
		var offset: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(1.5, float(data.get("wander", 5.0)))
		wander_target = home + Vector3(offset.x, 0, offset.y)
	if state_time < 2.5:
		_stop(delta)
		visual.play_loop("idle")
		return
	visual.play_loop("walk")
	_move_toward(wander_target, float(data.get("speed", 2.0)), delta)

func _physics_chase(delta: float) -> void:
	if target == null or target.is_dead():
		_set_state("return")
		return
	var distance: float = _flat_distance(target.global_position)
	if distance > float(data.get("lose", 24.0)) or _flat_distance(home) > float(data.get("leash", 28.0)):
		_set_state("return")
		return
	var reach: float = float(data.get("attack_range", 1.9))
	var can_attack: bool = cooldown <= 0.0
	if distance <= reach + 0.2 and can_attack and _take_token():
		_begin_attack(_choose_attack(distance))
		return
	# Close in when ready and an attack slot is free; otherwise circle at a safe distance.
	if distance > reach * 0.85 and (boss or distance > 3.4 or _has_token() or (can_attack and _token_free())):
		visual.play_loop("run")
		_move_toward(target.global_position, float(data.get("run", 4.5)) * speed_scale, delta)
	else:
		visual.play_loop("walk" if not boss else "idle")
		var around: Vector3 = (global_position - target.global_position).normalized().rotated(Vector3.UP, 0.9 * delta)
		var keep: Vector3 = target.global_position + around * maxf(3.2, reach + 0.8)
		_move_toward(keep, float(data.get("speed", 2.0)), delta, false)
		_face_target(delta, 6.0)

func _physics_return(delta: float) -> void:
	health = minf(max_health, health + max_health * 0.25 * delta)
	emit_signal("health_changed", self, health, max_health)
	if _flat_distance(home) < 1.2:
		_set_state("idle")
		return
	if _flat_distance(home) < float(data.get("leash", 28.0)) * 0.7 and _can_see_target(float(data.get("detect", 13.0)) * 0.7):
		_set_state("chase")
		return
	_move_toward(home, float(data.get("speed", 2.0)) * 1.6, delta)

func _physics_dead(delta: float) -> void:
	death_timer += delta
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= 20.0 * delta
		move_and_slide()
	if death_timer > 3.0:
		visual.scale = visual.scale.lerp(Vector3.ONE * 0.01, clampf((death_timer - 3.0) * 1.6, 0.0, 1.0))
	if death_timer > 3.8:
		queue_free()

# ------------------------------------------------------------------ attacks

func _choose_attack(_distance: float) -> String:
	var options: Array = data.get("attacks", ["attack"])
	return String(options[randi() % options.size()])

func _begin_attack(name: String) -> void:
	attack_name = name
	attack_data = Combat.attack(owner_key, name)
	attack_hits = {}
	attack_prev_u = -1.0
	attack_clock = 0.0
	telegraphed = false
	state = "attack"
	state_time = 0.0
	visual.play_action(name, speed_scale)
	emit_signal("attack_started", self, name)

func _physics_attack(delta: float) -> void:
	attack_clock += delta * speed_scale
	var t: float = attack_clock
	var hit_start: float = float(attack_data.get("hit_start", 0.6))
	var hit_end: float = float(attack_data.get("hit_end", 0.7))
	if t < hit_start - 0.15 and attack_data.get("track", true):
		_face_target(delta, 5.0)
	if not telegraphed and t >= hit_start - 0.38:
		telegraphed = true
		_telegraph()
	var lunge: float = float(attack_data.get("lunge", 0.0))
	var push: float = lunge if t > hit_start - 0.12 and t < hit_end else 0.0
	velocity.x = move_toward(velocity.x, facing.x * push, 30.0 * delta)
	velocity.z = move_toward(velocity.z, facing.z * push, 30.0 * delta)
	if t >= hit_start and t <= hit_end + delta * speed_scale:
		_attack_window(t, hit_start, hit_end)
		if state != "attack":
			return  # parried or killed by the swing it just delivered
	if t >= float(attack_data.get("recover", 1.0)):
		cooldown = randf_range(float(data.get("cooldown", [1.2, 2.2])[0]), float(data.get("cooldown", [1.2, 2.2])[1])) / speed_scale
		_set_state("recover")

func _telegraph() -> void:
	var weapon_point: Vector3 = global_position + Vector3.UP * float(data.get("height", 1.8)) * 0.9 + facing * 0.4
	if visual.sword_socket:
		weapon_point = visual.sword_socket.global_position
	Vfx.glint(get_parent(), weapon_point, Vfx.DANGER if attack_data.get("unblockable", false) else Vfx.SPARK, 0.9)

func _attack_window(t: float, hit_start: float, hit_end: float) -> void:
	var u: float = clampf((t - hit_start) / maxf(hit_end - hit_start, 0.001), 0.0, 1.0)
	if attack_prev_u < 0.0:
		Vfx.slash(get_parent(), global_position, facing, attack_data, Color(1.0, 0.75, 0.6, 0.7), 0.28)
	var hits: Array[Area3D] = Combat.sweep(self, facing, attack_data, maxf(attack_prev_u, 0.0), u, Combat.LAYER_HURT_PLAYER, attack_hits)
	attack_prev_u = u
	for area: Area3D in hits:
		_deliver(area, attack_data)

func _deliver(area: Area3D, attack: Dictionary) -> void:
	var entity: Node = Combat.entity_of(area)
	if entity == null or not entity.has_method("take_damage"):
		return
	var damage: Combat.Damage = Combat.make_damage(self, attack, float(attack.get("damage", 10)) * float(data.get("damage_scale", 1.0)), (entity as Node3D).global_position)
	var result: Dictionary = entity.take_damage(damage)
	if result.get("hit", false):
		visual.hitstop(damage.hitstop * 0.8)
		if data.has("lifesteal") and state != "dead":
			# Hấp Huyết elites drink back part of the blow.
			health = minf(max_health, health + float(result.get("amount", damage.amount)) * float(data["lifesteal"]))
			emit_signal("health_changed", self, health, max_health)

func on_parried(_player: Node) -> void:
	if state == "dead":
		return
	_stagger(float(data.get("parry_stagger", 1.3)))

func _stagger(duration: float) -> void:
	stagger_time = duration
	_release_token()
	_set_state("stagger")
	Vfx.burst(get_parent(), global_position + Vector3.UP * float(data.get("height", 1.8)) * 0.8, Color(1, 0.95, 0.6), 10, 3.0)

# ------------------------------------------------------------------ damage

func take_damage(damage: Combat.Damage) -> Dictionary:
	if state == "dead" or invulnerable:
		return {"hit": false}
	var amount: float = damage.amount * (1.35 if state == "stagger" else 1.0) * element_mult(damage.element) * statuses.taken_mult(damage.element)
	health = maxf(0.0, health - amount)
	emit_signal("health_changed", self, health, max_health)
	if damage.flinch:
		visual.flash()
		visual.hitstop(damage.hitstop)
	if state in ["idle", "return"]:
		_alert_camp()
	if health <= 0.0:
		_die(damage)
		return {"hit": true, "amount": amount, "killed": true}
	var started: String = _roll_status(damage)
	if started == "freeze":
		velocity = Vector3.ZERO
		_stagger(statuses.stun_time("freeze"))
		Vfx.shards(get_parent(), global_position, Color("dff8ff"), 7, float(data.get("radius", 0.5)) + 0.4, float(data.get("height", 1.8)) * 0.7, statuses.stun_time("freeze"))
		return {"hit": true, "amount": amount, "status": started}
	if not damage.flinch:
		poise -= damage.poise * statuses.poise_mult()
		return {"hit": true, "amount": amount, "status": started}
	poise -= damage.poise * statuses.poise_mult()
	if poise <= 0.0 and state != "stagger":
		poise = max_poise
		velocity = damage.direction * damage.knockback
		_stagger(float(data.get("break_stagger", 1.4)))
	elif state != "stagger" and not (state == "attack" and data.get("armor", false)):
		if state == "attack":
			_release_token()
		velocity = damage.direction * damage.knockback * float(data.get("knockback_scale", 1.0))
		state = "hit"
		state_time = 0.0
		visual.play_action("hit")
	return {"hit": true, "amount": amount, "status": started}

func element_mult(element: String) -> float:
	return float((data.get("resist", {}) as Dictionary).get(element, 1.0)) if element != "" else 1.0

func _roll_status(damage: Combat.Damage) -> String:
	var status: String = String(damage.status.get("id", ""))
	if status == "":
		return ""
	if randf() >= float(damage.status.get("chance", 1.0)) * (1.0 - statuses.resist * 0.5):
		return ""
	return statuses.apply(status, int(damage.status.get("stacks", 1)), damage.status_power)

func _die(damage: Combat.Damage) -> void:
	_release_token()
	statuses.clear()
	if shown_status != "":
		shown_status = ""
		visual.set_status_tint(Color(0, 0, 0, 0))
	state = "dead"
	state_time = 0.0
	velocity = damage.direction * 2.0
	collision_layer = 0
	collision_mask = Combat.LAYER_WORLD
	hurtbox.collision_layer = 0
	remove_from_group("enemy")
	visual.play_action("death")
	emit_signal("defeated", self)

# ------------------------------------------------------------------ helpers

func _alert_camp() -> void:
	if state in ["idle", "return"]:
		_set_state("chase")
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var other: Enemy = node as Enemy
		if other and other != self and other.camp == camp and camp != "" and other.state in ["idle", "return"] and other.global_position.distance_to(global_position) < 20.0:
			other._set_state("alert")

func _take_token() -> bool:
	if boss or _has_token():
		return true
	var holders: Array = tokens.get(camp, [])
	holders = holders.filter(func(item: Variant) -> bool: return is_instance_valid(item) and (item as Enemy).state == "attack")
	if holders.size() >= 2:
		tokens[camp] = holders
		return false
	holders.append(self)
	tokens[camp] = holders
	return true

func _token_free() -> bool:
	var holders: Array = (tokens.get(camp, []) as Array).filter(func(item: Variant) -> bool: return is_instance_valid(item) and (item as Enemy).state == "attack")
	return holders.size() < 2

func _has_token() -> bool:
	return (tokens.get(camp, []) as Array).has(self)

func _release_token() -> void:
	if tokens.has(camp):
		(tokens[camp] as Array).erase(self)

func _can_see_target(radius: float) -> bool:
	if target == null or target.is_dead() or target.state == "disabled":
		return false
	if global_position.distance_to(target.global_position) > radius:
		return false
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var eye: Vector3 = global_position + Vector3.UP * 1.4
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, target.global_position + Vector3.UP * 1.2, Combat.LAYER_WORLD)
	return space.intersect_ray(query).is_empty()

func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()

func _stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)

func _face_target(delta: float, rate: float) -> void:
	if target:
		var direction: Vector3 = target.global_position - global_position
		direction.y = 0.0
		if direction.length() > 0.05:
			facing = facing.slerp(direction.normalized(), clampf(delta * rate, 0.0, 1.0)).normalized()
			_apply_facing()

func _apply_facing(_instant: bool = false) -> void:
	visual.rotation.y = atan2(facing.x, facing.z)
	if quadruped:
		# Long body capsules lie along the facing so walls and hurtboxes match the model.
		body_shape.rotation = Vector3(PI * 0.5, visual.rotation.y, 0.0)
		(hurtbox.get_child(0) as CollisionShape3D).rotation = Vector3(PI * 0.5, visual.rotation.y, 0.0)

func _move_toward(point: Vector3, speed: float, delta: float, turn: bool = true) -> void:
	var next: Vector3 = point
	var map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0 and not NavigationServer3D.map_get_regions(map).is_empty():
		# Path only while standing on a baked encounter zone and when the path really reaches the
		# goal; otherwise (zone not baked yet, goal off the mesh) steer straight with obstacle probes.
		if NavigationServer3D.map_get_closest_point(map, global_position).distance_to(global_position) < 1.5:
			nav.target_position = point
			var candidate: Vector3 = nav.get_next_path_position()
			var reaches: bool = Vector2(nav.get_final_position().x - point.x, nav.get_final_position().z - point.z).length() < 1.5
			if reaches and candidate.distance_to(global_position) > 0.05:
				next = candidate
	var direction: Vector3 = next - global_position
	direction.y = 0.0
	if direction.length() < 0.1:
		_stop(delta)
		return
	direction = _avoid(direction.normalized())
	velocity.x = move_toward(velocity.x, direction.x * speed, 18.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 18.0 * delta)
	if turn:
		facing = facing.slerp(direction, clampf(delta * 8.0, 0.0, 1.0)).normalized()
		_apply_facing()

func _avoid(direction: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin: Vector3 = global_position + Vector3.UP * 0.6
	for angle: float in [0.0, 0.6, -0.6, 1.2, -1.2]:
		var probe: Vector3 = direction.rotated(Vector3.UP, angle)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + probe * 1.4, Combat.LAYER_WORLD)
		query.exclude = [get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or (hit["normal"] as Vector3).y > 0.6:
			return probe
	return direction

func _guard_edges() -> void:
	## Stop before stepping into water, chasms, drops or unloaded chunks. Terrain triangles are
	## about 1.3 m wide, so the physical edge begins before the analytic one: look a cell ahead.
	var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() < 0.05:
		return
	var probe: Vector3 = global_position + flat.normalized() * maxf(flat.length() * 0.25, 1.6)
	for point: Vector3 in [global_position + flat * 0.25, probe]:
		if not world.is_position_ready(point) or not world.layout.water_at(point.x, point.z).is_empty() or world.layout.in_chasm(point.x, point.z) or not world.layout.inside_bounds(point.x, point.z):
			_block_move()
			return
	if is_on_floor():
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(probe + Vector3.UP * 1.5, probe + Vector3.DOWN * 3.0, Combat.LAYER_WORLD)
		if space.intersect_ray(query).is_empty():
			_block_move()
			return
	blocked_time = 0.0

func _block_move() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	blocked_time += get_physics_process_delta_time()
	# A target across water or a gorge cannot be reached: give up and walk home.
	if state == "chase" and blocked_time > 2.5:
		blocked_time = 0.0
		_set_state("return")

func _track_stuck(delta: float) -> void:
	if state in ["chase", "return"] and Vector2(velocity.x, velocity.z).length() > 0.5:
		if global_position.distance_to(last_position) < 0.02:
			stuck_time += delta
			if stuck_time > 2.5 and state == "return":
				global_position = home
				stuck_time = 0.0
		else:
			stuck_time = 0.0
	last_position = global_position
