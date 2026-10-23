class_name PlayerController
extends CharacterBody3D
## Lâm An: movement (run, sprint, dodge, jump, khinh công leap and glide) and
## sword combat (3-hit combo, charged heavy, parry/block, the three forms of the equipped
## sword's style on E, Q and X; X spends the full charge meter; F finishes a broken foe; a
## perfect dodge or parry opens Tâm Nhãn, slowing every enemy) and consumables (R: the
## strongest healing item, C: the Inventory's quick slot).

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal died
signal hazard(kind: String)
signal attack_landed(target: Node, amount: float)
signal parried(enemy: Node)
signal footstep(surface: String)
signal skill_used(skill: String, cooldown: float)
signal notice(text: String)
signal meter_changed(current: float, maximum: float)
signal status_applied(status: String)
## Lâm An's own buffs and debuffs started, ended or changed stacks.
signal statuses_changed
## A finisher's blow landed on its foe (amount dealt; killed when it ended the foe).
signal finisher_landed(target: Node, amount: float, killed: bool)
## Tâm Nhãn opened after a perfect "dodge" or "parry", and later closed again.
signal focus_started(kind: String)
signal focus_ended

const METER_MAX: float = 100.0
## Stamina a dodge costs (a perfect dodge that opens Tâm Nhãn gives it back).
const DODGE_COST: float = 20.0

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
## skill id -> seconds left / seconds at cast (for the HUD ratio)
var cooldowns: Dictionary = {}
var cooldown_max: Dictionary = {}
var meter: float = 0.0
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
## Buffs, debuffs and elemental statuses on Lâm An (same rules as on enemies); their "stats"
## reach GameState.stat through status_stats.
var statuses: StatusEffects = StatusEffects.new()
var status_revision: int = 0
## Bumped by every slow-motion beat, so only the latest one restores the time scale.
var slow_serial: int = 0
## Tâm Nhãn (data/attacks.json player "focus"): seconds of enemy slow motion left, and until a
## perfect dodge or parry can open it again. Both count Lâm An's own time, so pausing holds them.
var focus_time: float = 0.0
var focus_cooldown: float = 0.0

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
		visual.enable_trail()
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

func max_stamina() -> float:
	## Base 100 plus flat "max_stamina" from gear, blessings and buffs.
	return game.max_stamina()

func attack_rate() -> float:
	## Playback rate of attacks and forms from "attack_speed": clip and hit timing scale together.
	return clampf(1.0 + game.stat("attack_speed"), 0.5, 2.0)

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
		queue_input("skill_e")
	elif event.is_action_pressed("skill_2"):
		queue_input("skill_q")
	elif event.is_action_pressed("skill_ult"):
		queue_input("skill_x")
	elif event.is_action_pressed("heal"):
		queue_input("heal")
	elif event.is_action_pressed("use_item"):
		queue_input("item")
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
	# Dialogue and visions lock input: statuses hold still so poison cannot drain a conversation.
	if state not in ["dead", "disabled"] and input_enabled:
		_tick_statuses(delta)
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
	focus_cooldown = maxf(0.0, focus_cooldown - delta)
	if focus_time > 0.0:
		focus_time -= delta
		if focus_time <= 0.0:
			end_focus()
	combat_timer += delta
	for skill: String in cooldowns:
		cooldowns[skill] = maxf(0.0, cooldowns[skill] - delta)
	if combat_timer > 8.0 and meter > 0.0:
		set_meter(meter - 6.0 * delta)
	stamina_delay -= delta
	var draining: bool = (state == "move" and (sprinting or gliding)) or state == "dodge" or (state == "move" and block_held and is_on_floor() and current_action() == "")
	var top: float = max_stamina()
	if stamina > top:
		set_stamina(top)  # a stamina buff ran out
	elif stamina_delay <= 0.0 and not draining and stamina < top:
		set_stamina(stamina + 32.0 * maxf(0.2, 1.0 + game.stat("stamina_regen")) * delta)
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
	var target: Vector3 = direction * speed * move_speed_scale()
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
	elif command.begins_with("skill_"):
		buffered = ""
		_try_skill(command.substr(6))
	elif command == "heal" and on_floor:
		buffered = ""
		_try_heal()
	elif command == "item" and on_floor:
		buffered = ""
		_try_quick_item()

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
	set_stamina(stamina - DODGE_COST)
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
	var shaken: PackedStringArray = statuses.shed(1)
	if not shaken.is_empty():
		# Rolling clear shakes off a layer of bleeding.
		Vfx.burst(get_parent(), global_position + Vector3.UP * 0.9, Color(String(ContentDB.status(shaken[0]).get("color", "d23c3c"))), 8, 2.5, 0.08, 0.35)
		_sync_statuses()

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

func style_id() -> String:
	return StyleBook.style_of(game.sword)

func cooldown_ratio(skill: String) -> float:
	return float(cooldowns.get(skill, 0.0)) / maxf(float(cooldown_max.get(skill, 0.0)), 0.01)

func set_meter(value: float) -> void:
	var next: float = clampf(value, 0.0, METER_MAX)
	if is_equal_approx(next, meter):
		return
	meter = next
	emit_signal("meter_changed", meter, METER_MAX)

func _try_skill(slot: String) -> void:
	var form: Dictionary = StyleBook.form(style_id(), slot)
	if form.is_empty():
		return
	var skill: String = String(form["skill"])
	if game.skill_level(skill) <= 0:
		emit_signal("notice", "Chưa lĩnh hội chiêu này")
		return
	if float(cooldowns.get(skill, 0.0)) > 0.0:
		return
	var cost: float = float(form.get("meter", 0.0))
	if cost > 0.0 and meter < cost:
		emit_signal("notice", "Nộ khí chưa đầy")
		return
	_start_action(String(form["attack"]), slot, skill)
	if state != "action" or current_action() != String(form["attack"]):
		return
	if cost > 0.0:
		set_meter(meter - cost)
		# The ultimate cannot be interrupted: Lâm An is untouchable until it lands.
		invulnerable = maxf(invulnerable, float((action["data"] as Dictionary).get("recover", 1.0)))
	var reduction: float = (1.0 - 0.15 * (game.skill_level(skill) - 1)) * maxf(0.4, 1.0 - game.stat("skill_cd"))
	cooldown_max[skill] = float(form.get("cooldown", 0.0)) * reduction
	cooldowns[skill] = cooldown_max[skill]
	emit_signal("skill_used", skill, cooldowns[skill])

func _try_heal() -> void:
	## R: the strongest healing item in the bag (data/items.json "effect" "heal").
	if health >= max_health() - 0.5:
		emit_signal("notice", "Khí huyết đang đầy")
		return
	var item: String = Consumables.best_heal(game)
	if item == "":
		emit_signal("notice", "Không còn thuốc hồi phục")
		return
	_begin_item(item)

func _try_quick_item() -> void:
	## C: the consumable placed on the quick slot from the Inventory.
	if game.quick_item == "":
		emit_signal("notice", "Chưa đặt vật phẩm vào ô nhanh (Túi đồ)")
		return
	var refusal: String = item_refusal(game.quick_item)
	if refusal != "":
		emit_signal("notice", refusal)
		return
	_begin_item(game.quick_item)

func _begin_item(item: String) -> void:
	## The same short interact motion for every consumable; the item is spent at 0.35 s.
	_start_action("interact")
	if current_action() == "interact":
		action["item"] = item

func item_refusal(id: String) -> String:
	## Why using this consumable now would be refused or wasted; "" when it would do something.
	var effect: Dictionary = Consumables.effect(id)
	var title: String = String(ContentDB.item(id).get("name", id))
	if effect.is_empty():
		return "Không dùng được " + title
	if game.count(id) <= 0:
		return "Đã hết " + title
	if effect.has("buff") or (float(effect.get("heal", 0.0)) > 0.0 and health < max_health() - 0.5):
		return ""
	for cured: Variant in effect.get("cleanse", []):
		if statuses.has(String(cured)):
			return ""
	return "Khí huyết đang đầy" if effect.has("heal") and not effect.has("cleanse") else "Lúc này chưa cần dùng " + title

func consume_item(id: String) -> bool:
	## Spends one consumable and applies its effect at once: heal, cleanse, then the buff.
	## Returns false, spending nothing, when the item has no effect or none is left.
	var effect: Dictionary = Consumables.effect(id)
	if effect.is_empty() or is_dead() or not game.remove_item(id):
		return false
	var ratio: float = float(effect.get("heal", 0.0))
	if ratio > 0.0:
		heal(max_health() * ratio * maxf(0.0, 1.0 + game.stat("heal_bonus")))
		Vfx.wisps(self, Color(0.7, 1.0, 0.75), 12, 0.6).emitting = true
	var cured: Array = effect.get("cleanse", [])
	if not cured.is_empty() and cleanse(cured) > 0:
		Vfx.burst(get_parent(), global_position + Vector3.UP, Color(0.85, 1.0, 0.85), 14, 3.0, 0.08, 0.5)
	var buff: String = String(effect.get("buff", ""))
	if buff != "":
		apply_status(buff, 1, 0.0, float(effect.get("duration", 0.0)))
	emit_signal("footstep", "heal")
	return true

# ------------------------------------------------------------------ finisher

func finisher_reach() -> float:
	return float(Combat.attack("player", "finisher").get("reach", 3.0))

func finisher_target() -> Enemy:
	## The finishable foe F would execute: within reach, the closest, preferring the one ahead.
	var best: Enemy = null
	var best_score: float = INF
	var reach: float = -1.0
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: Enemy = node as Enemy
		if enemy == null or not enemy.is_finishable() or absf(enemy.global_position.y - global_position.y) > 2.0:
			continue
		if reach < 0.0:
			reach = finisher_reach()  # read only once a broken foe is about
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance > reach:
			continue
		var score: float = distance - (offset.normalized().dot(facing) * 0.8 if distance > 0.01 else 0.0)
		if score < best_score:
			best_score = score
			best = enemy
	return best

func can_finish() -> bool:
	## On her feet and free, or once the current swing has landed (finishers cancel its recovery).
	if not is_on_floor() or not input_enabled:
		return false
	if state == "move":
		return true
	if state != "action" or current_action() in ["finisher", "interact"]:
		return false
	return float(action.get("t", 0.0)) >= float((action["data"] as Dictionary).get("hit_end", 0.0))

func start_finisher(enemy: Enemy) -> bool:
	## F next to a broken foe: snap to it and strike once for the kill (see "finisher" in
	## data/attacks.json), untouchable until the blow has landed and she has recovered.
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_finishable() or not can_finish():
		return false
	var offset: Vector3 = enemy.global_position - global_position
	offset.y = 0.0
	if offset.length() > finisher_reach():
		return false
	_start_action("finisher")
	if current_action() != "finisher":
		return false
	action["target"] = enemy
	face_direction(offset, true)
	var data: Dictionary = action["data"]
	invulnerable = maxf(invulnerable, float(data.get("recover", 1.0)))
	enemy.hold(float(data.get("hit_start", 0.5)) + 0.3)
	return true

func _finisher_victim() -> Enemy:
	## The foe the running finisher was aimed at, while it is still alive.
	var victim: Variant = action.get("target")
	if not is_instance_valid(victim) or (victim as Enemy).is_dead():
		return null
	return victim as Enemy

func _finisher_blow(data: Dictionary) -> void:
	## The blow lands on its chosen foe only (never a sweep), wherever the foe was knocked to.
	var victim: Enemy = _finisher_victim()
	if victim == null:
		return
	var result: Dictionary = strike(victim, data, 1.0)
	if not result.get("hit", false):
		return
	camera_rig.punch_fov(-9.0, 0.5)
	var center: Vector3 = victim.global_position + Vector3.UP * float(victim.data.get("height", 1.8)) * 0.6
	Vfx.ring(get_parent(), victim.global_position + Vector3.UP * 0.2, 2.2, Vfx.SPARK, 0.45, 0.22)
	Vfx.burst(get_parent(), center, Color(1.0, 0.85, 0.5), 30, 8.0, 0.1, 0.5)
	Vfx.crack(get_parent(), victim.global_position, 1.3)
	_slow_motion(float(data.get("slow_motion", 0.3)), float(data.get("slow_time", 0.25)))
	emit_signal("finisher_landed", victim, float(result.get("amount", 0.0)), bool(result.get("killed", false)))

# ------------------------------------------------------------------ Tâm Nhãn

func focus_rule() -> Dictionary:
	## Perfect windows, enemy clock rate, duration, cooldown and rewards (data/attacks.json player "focus").
	return Combat.attack("player", "focus")

func is_focused() -> bool:
	return focus_time > 0.0

func _try_focus(kind: String, damage: Combat.Damage) -> bool:
	## A perfect dodge or parry of an enemy's blow, missile or area opens Tâm Nhãn, unless the
	## last one is still cooling down.
	if focus_cooldown > 0.0 or not is_instance_valid(damage.source) or not (damage.source is Enemy):
		return false
	start_focus(kind)
	return true

func start_focus(kind: String) -> void:
	## Tâm Nhãn: every enemy slows to the rule's "enemy_time" (Enemy.time_dilation) for "duration"
	## seconds of Lâm An's own time while she keeps her pace. Her next blow lands as a counter
	## (×1.5), and a perfect dodge gives its stamina back. Never Engine.time_scale: that would slow her too.
	var rule: Dictionary = focus_rule()
	focus_time = float(rule.get("duration", 1.5))
	focus_cooldown = float(rule.get("cooldown", 4.0))
	Enemy.set_time_dilation(float(rule.get("enemy_time", 0.3)))
	counter_bonus = maxf(counter_bonus, float(rule.get("counter", 2.5)))
	if kind == "dodge":
		set_stamina(stamina + float(rule.get("stamina_refund", DODGE_COST)))
	var tint: Color = Color(String(rule.get("color", "8fd0f5")))
	Vfx.ring(get_parent(), global_position + Vector3.UP * 0.15, 2.6, tint, 0.45, 0.2)
	Vfx.burst(get_parent(), global_position + Vector3.UP * 1.1, tint, 18, 4.0, 0.08, 0.5)
	if camera_rig:
		camera_rig.punch_fov(-5.0, 0.4)
	emit_signal("focus_started", kind)

func end_focus() -> void:
	## One clock for everyone again: time ran out, Lâm An fell or woke, or left the Trial.
	var was_focused: bool = focus_time > 0.0 or not is_equal_approx(Enemy.time_dilation, 1.0)
	focus_time = 0.0
	Enemy.set_time_dilation(1.0)
	if was_focused:
		emit_signal("focus_ended")

func _exit_tree() -> void:
	# Enemy.time_dilation is static: never leave the next game slowed (quit mid-focus, tests).
	focus_time = 0.0
	Enemy.set_time_dilation(1.0)

func _slow_motion(scale: float, seconds: float) -> void:
	## A breath of real-time slow motion (ultimates, finishers); skipped headless.
	if DisplayServer.get_name() == "headless" or scale >= 1.0 or seconds <= 0.0:
		return
	slow_serial += 1
	var serial: int = slow_serial
	Engine.time_scale = scale
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		if serial == slow_serial:
			Engine.time_scale = 1.0)

func _start_action(anim_name: String, slot: String = "", skill: String = "") -> void:
	# Attack speed quickens swings and forms; parrying and using items keep their own pace.
	var rate: float = 1.0 if anim_name in ["parry", "interact"] else attack_rate()
	var data: Dictionary = Combat.attack("player", anim_name, "", rate)
	var clip: String = String(data.get("clip", anim_name))
	if not visual.has_animation(clip) and data.has("fallback_clip"):
		# The dedicated clip is not in this model yet: play a close cousin with its timings.
		clip = String(data["fallback_clip"])
		data = Combat.attack("player", anim_name, clip, rate)
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
	if slot != "":
		data["slot"] = slot
	action = {"name": anim_name, "data": data, "t": 0.0, "hits": {}, "prev_u": -1.0, "fired": false, "tick": 0.0, "used": false, "skill": skill, "start": global_position, "rate": rate}
	combat_timer = 0.0 if anim_name != "interact" else combat_timer
	visual.set_sheathed(false)
	visual.play_action(clip, float(data.get("speed", 1.0)) * rate)
	var aim: Vector3 = _aim_direction()
	if aim != Vector3.ZERO:
		face_direction(aim, true)
	if data.has("mult"):
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
	var victim: Enemy = _finisher_victim() if name == "finisher" else null
	if victim and t < hit_start:
		# Close in on the broken foe so the blow lands at arm's length.
		var gap: Vector3 = victim.global_position - global_position
		gap.y = 0.0
		face_direction(gap, true)
		push = clampf((gap.length() - float(victim.data.get("radius", 0.4)) - 0.9) / maxf(hit_start - t, 0.08), 0.0, 14.0)
	elif lock_target and t < hit_start and name != "interact":
		face_direction(lock_target.global_position - global_position)
	var target_velocity: Vector3 = facing * push
	if String(data.get("kind", "")) == "dash" and t >= hit_start and t <= hit_end:
		target_velocity = facing * float(data.get("dash_distance", 6.0)) / maxf(hit_end - hit_start, 0.05)
		if not _dash_clear(target_velocity * delta * 3.0):
			target_velocity = Vector3.ZERO
		if data.get("invulnerable", false):
			invulnerable = maxf(invulnerable, hit_end - t + 0.05)
		velocity.x = target_velocity.x
		velocity.z = target_velocity.z
	velocity.x = move_toward(velocity.x, target_velocity.x, 40.0 * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, 40.0 * delta)
	_apply_gravity(delta)
	if not visual.is_frozen():
		move_and_slide()
	if name == "interact":
		if t >= 0.35 and not action["used"] and action.has("item"):
			action["used"] = true
			consume_item(String(action["item"]))
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
		if next.begins_with("skill_"):
			buffered = ""
			_try_skill(next.substr(6))
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

func _dash_clear(step: Vector3) -> bool:
	## Dashing forms stop at gorges, deep water and the valley walls instead of carrying Lâm An over.
	var ahead: Vector3 = global_position + step
	if world == null:
		return true
	return world.layout.inside_bounds(ahead.x, ahead.z) and not world.layout.in_chasm(ahead.x, ahead.z) and world.layout.water_at(ahead.x, ahead.z).is_empty()

func _finish_action() -> void:
	if String((action.get("data", {}) as Dictionary).get("kind", "")) == "dash":
		Vfx.streak(get_parent(), action.get("start", global_position), global_position, SkillRunner.form_color(action["data"]), 1.1, 0.5)
	if current_action() != "parry" or not block_held:
		visual.stop_action()
	action = {}
	state = "move"

func skill_bonus() -> float:
	## Each cultivation level of the casting form adds 25% damage.
	var skill: String = String(action.get("skill", ""))
	return 1.0 + 0.25 * (game.skill_level(skill) - 1) if skill != "" and game.skill_level(skill) > 0 else 1.0

func _resolve_hits(_name: String, data: Dictionary, t: float, hit_start: float, hit_end: float) -> void:
	var kind: String = String(data.get("kind", "sweep"))
	if not action["fired"]:
		action["fired"] = true
		if data.get("slot", "") == "x":
			_ultimate_flourish(data)
		SkillRunner.fire(self, data, skill_bonus())
		if kind == "projectile":
			emit_signal("footstep", "wind")
		elif kind == "finisher":
			_finisher_blow(data)
	match kind:
		"projectile", "chain", "strikes", "nova", "field", "finisher":
			return  # these deal damage through the nodes SkillRunner spawned (or once, above), never twice up close
		"tick":
			action["tick"] = float(action["tick"]) - get_physics_process_delta_time()
			if float(action["tick"]) <= 0.0:
				# A quicker channel ticks as often per turn, so it deals the same in less time.
				action["tick"] = float(data.get("tick", 0.13)) / float(action.get("rate", 1.0))
				action["hits"] = {}
				SkillRunner.tick_vfx(self, data)
				_hit_targets(Combat.sweep(self, facing, data, 0.0, 0.0, Combat.LAYER_HURT_ENEMY, action["hits"]), data, skill_bonus())
			return
		"dash":
			# The whole arc travels with Lâm An, so everything along the path is cut once.
			_hit_targets(Combat.sweep(self, facing, data, 0.0, 1.0, Combat.LAYER_HURT_ENEMY, action["hits"]), data, skill_bonus())
			return
	var u: float = clampf((t - hit_start) / maxf(hit_end - hit_start, 0.001), 0.0, 1.0)
	var previous: float = maxf(float(action["prev_u"]), 0.0)
	action["prev_u"] = u
	_hit_targets(Combat.sweep(self, facing, data, previous, u, Combat.LAYER_HURT_ENEMY, action["hits"]), data, skill_bonus())

func _hit_targets(areas: Array[Area3D], data: Dictionary, bonus: float) -> void:
	for area: Area3D in areas:
		var entity: Node = Combat.entity_of(area)
		if entity == null or entity == self or not entity.has_method("take_damage"):
			continue
		strike(entity, data, bonus)

func strike(entity: Node, data: Dictionary, scale: float, direction: Vector3 = Vector3.ZERO, ranged: bool = false) -> Dictionary:
	## Every player hit goes through here: melee sweeps, missiles, chains, novas and fields.
	var amount: float = game.attack_power() * float(data.get("mult", 1.0)) * scale
	if counter_bonus > 0.0:
		amount *= 1.5
		counter_bonus = 0.0
	var slot: String = String(data.get("slot", ""))
	if slot == "" and not ranged:
		amount *= 1.0 + game.stat("melee_mult")
	var critical: bool = game.stat("crit_rate") > 0.0 and randf() < game.stat("crit_rate")
	if critical:
		amount *= 1.0 + PlayerStats.CRIT_BASE + game.stat("crit_dmg")
	var damage: Combat.Damage = Combat.make_damage(self, data, amount, (entity as Node3D).global_position)
	damage.status_power = game.attack_power()
	damage.armor_pen = game.stat("armor_pen")
	damage.reaction_dmg = game.stat("reaction_dmg")
	damage.poise *= maxf(0.0, 1.0 + game.stat("poise_dmg"))
	if direction != Vector3.ZERO:
		damage.direction = direction
	if float(data.get("knockback", 0.0)) < 0.0:
		damage.direction = -damage.direction
		damage.knockback = absf(damage.knockback)
	damage.ranged = ranged
	if damage.element == "":
		_apply_sword_element(damage)
	if damage.element != "":
		damage.amount *= 1.0 + game.stat("element_dmg")
	if not damage.status.is_empty() and game.stat("status_chance") > 0.0:
		# The status dictionary can be the shared attack data: change a copy.
		damage.status = damage.status.duplicate()
		damage.status["chance"] = float(damage.status.get("chance", 1.0)) + game.stat("status_chance")
	var result: Dictionary = entity.take_damage(damage)
	if critical:
		result["critical"] = true
	if result.get("hit", false):
		if not ranged:
			visual.hitstop(damage.hitstop)
			camera_rig.add_trauma(damage.shake)
		Vfx.burst(get_parent(), damage.position, Vfx.element_color(damage.element) if damage.element != "" else Vfx.SPARK, 16, 6.0)
		set_meter(meter + float(data.get("meter_gain", 0.0 if slot == "x" else (2.0 if slot != "" else 5.0))) * (1.0 + game.stat("meter_gain")))
		if game.stat("lifesteal") > 0.0 and not is_dead():
			# Only blows drink: burns and other damage over time never pass through strike.
			heal(float(result.get("amount", 0.0)) * game.stat("lifesteal"))
		emit_signal("attack_landed", entity, float(result.get("amount", amount)))
		if result.has("status") and String(result["status"]) != "":
			emit_signal("status_applied", String(result["status"]))
	return result

func _apply_sword_element(damage: Combat.Damage) -> void:
	## Plain strikes of an elemental sword carry its element and sometimes its status.
	var weapon: Dictionary = ContentDB.weapon(game.sword)
	var element: String = String(weapon.get("element", ""))
	if element == "":
		return
	damage.element = element
	damage.status = {"id": String(ContentDB.element(element).get("status", "")), "chance": float(weapon.get("status_chance", 0.0))}

func _ultimate_flourish(data: Dictionary) -> void:
	camera_rig.add_trauma(float(data.get("shake", 0.5)))
	camera_rig.punch_fov(10.0, 0.45)
	Vfx.pillar(get_parent(), global_position, SkillRunner.form_color(data), 10.0, 1.2, 0.5)
	# A breath of slow motion sells the ultimate; real time keeps it short at any time scale.
	_slow_motion(0.35, 0.22)

# ------------------------------------------------------------------ damage

func take_damage(damage: Combat.Damage) -> Dictionary:
	if state in ["dead", "disabled", "loading"]:
		return {"hit": false}
	var from_front: bool = facing.dot(-damage.direction) > 0.2
	var parry_window: bool = current_action() == "parry" and float(action.get("t", 9.0)) <= float((action["data"] as Dictionary).get("hit_end", 0.2))
	var parries: bool = parry_window and from_front and not damage.unblockable
	if invulnerable > 0.0 and not parries:
		var dodged: bool = state == "dodge"
		# Caught in the first instant of the roll: a perfect dodge opens Tâm Nhãn.
		var perfect_dodge: bool = dodged and dodge_time <= float(focus_rule().get("perfect_dodge", 0.15)) and _try_focus("dodge", damage)
		return {"hit": false, "dodged": dodged, "perfect": perfect_dodge}
	if parries:
		# Met in the first instant of the guard: a perfect parry opens Tâm Nhãn as well.
		var instant: bool = float(action.get("t", 9.0)) <= float(focus_rule().get("perfect_parry", 0.1))
		visual.hitstop(0.12)
		camera_rig.add_trauma(0.25)
		Vfx.burst(get_parent(), global_position + Vector3.UP * 1.2 + facing * 0.6, Color(1.0, 0.95, 0.7), 26, 7.0, 0.07)
		Vfx.glint(get_parent(), global_position + Vector3.UP * 1.3 + facing * 0.7, Color(1, 1, 0.85), 1.2)
		counter_bonus = 2.5
		set_stamina(stamina + 12.0)
		set_meter(meter + 15.0)
		# Deflecting a projectile protects the player but does not stagger the distant thrower.
		if damage.source and damage.source.has_method("on_parried") and not damage.ranged:
			damage.source.on_parried(self)
		emit_signal("parried", damage.source)
		return {"hit": false, "parried": true, "perfect": instant and _try_focus("parry", damage)}
	if game.stat("damage_taken") != 0.0:
		damage.amount *= maxf(0.2, 1.0 + game.stat("damage_taken"))
	# Flat defense, then the blow's element against her matching resistance (both neutral at 0).
	damage.amount *= Combat.defense_mult(game.stat("defense")) * element_damage_mult(damage.element)
	# A soaked Lâm An conducts thunder just like a soaked bandit; rain and storms change elements.
	damage.amount *= statuses.taken_mult(damage.element) * Combat.weather_mult(damage.element)
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
		# A guarded blow only grazes: its status sticks at half the chance.
		var guarded: String = _roll_status(damage, 0.5)
		var guard_stun: float = statuses.stun_time(guarded) if guarded != "" else 0.0
		if stamina <= 0.0:
			_enter_hit(damage, maxf(0.8, guard_stun))
			emit_signal("notice", "Phá thế đỡ!")
		elif guard_stun > 0.0:
			stun(guard_stun, damage)
		return {"hit": true, "blocked": true, "amount": chip, "status": guarded}
	_apply_damage(damage.amount)
	set_meter(meter + 4.0)
	visual.flash(Color(1.0, 0.55, 0.45))
	camera_rig.add_trauma(damage.shake + 0.15)
	Vfx.burst(get_parent(), global_position + Vector3.UP * 1.1, Color(1.0, 0.5, 0.4), 12, 4.0)
	if health <= 0.0:
		_die()
		return {"hit": true, "amount": damage.amount}
	var started: String = _roll_status(damage, 1.0)
	var stun_for: float = statuses.stun_time(started) if started != "" else 0.0
	if stun_for > 0.0:
		stun(maxf(0.35, stun_for), damage)
	elif hit_cooldown <= 0.0:
		_enter_hit(damage, 0.35)
	return {"hit": true, "amount": damage.amount, "status": started}

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
	Engine.time_scale = 1.0
	end_focus()
	set_meter(0.0)
	set_lock(null)
	statuses.clear()
	_sync_statuses()
	visual.stop_action()
	visual.set_state("dead")
	emit_signal("died")

func heal(amount: float) -> void:
	health = minf(max_health(), health + amount)
	game.health = health
	emit_signal("health_changed", health, max_health())

func set_stamina(value: float) -> void:
	stamina = clampf(value, 0.0, max_stamina())
	emit_signal("stamina_changed", stamina, max_stamina())

func revive(point: Vector3) -> void:
	teleport(point)
	health = max_health()
	game.health = health
	stamina = max_stamina()
	state = "move"
	action = {}
	invulnerable = 1.5
	# Waking at a shrine (or starting over, or loading) restores one clock with a fresh Tâm Nhãn
	# and washes off every buff and debuff.
	end_focus()
	focus_cooldown = 0.0
	statuses.clear()
	_sync_statuses()
	visual.stop_action()
	visual.set_state("ground")
	emit_signal("health_changed", health, max_health())
	emit_signal("stamina_changed", stamina, max_stamina())

# ------------------------------------------------------------------ statuses

func apply_status(id: String, stacks: int = 1, power: float = 0.0, duration: float = 0.0) -> String:
	## Puts a buff or debuff on Lâm An directly (potions, shrines, auras). Returns the status
	## that started ("" when refused), like StatusEffects.apply; duration > 0 replaces the rule's.
	if state in ["dead", "disabled", "loading"]:
		return ""
	statuses.resist = clampf(game.stat("status_resist"), 0.0, 0.9)
	var started: String = statuses.apply(id, stacks, power, duration)
	if started != "":
		_status_started(started)
		var stun_for: float = statuses.stun_time(started)
		if stun_for > 0.0:
			stun(stun_for)
	_sync_statuses()
	return started

func cleanse(ids: Array) -> int:
	## Removes the listed statuses (antidotes, cleansing tea); returns how many were active.
	var removed: int = statuses.cleanse(ids)
	_sync_statuses()
	return removed

func status_resistance(element: String) -> float:
	## 0..0.9 lower chance for an enemy's status to stick: status_resist plus the matching
	## res_<element> (both 0 until gear or buffs grant them).
	return clampf(game.stat("status_resist") + (game.stat("res_" + element) if element != "" else 0.0), 0.0, 0.9)

func element_damage_mult(element: String) -> float:
	## Share of an elemental blow left after res_<element>; plain steel and 0 resistance keep it all.
	return 1.0 - clampf(game.stat("res_" + element), -1.0, 0.9) if element != "" else 1.0

func move_speed_scale() -> float:
	## Chill and soak slow Lâm An like they slow enemies; Khinh thân and gear "move_speed" quicken her.
	return statuses.speed_mult() * maxf(0.3, 1.0 + game.stat("move_speed"))

func stun(duration: float, damage: Combat.Damage = null) -> void:
	## Choáng, đóng băng, tê liệt: Lâm An reels in the hit state, unable to act. A blow carries
	## its knockback; a status from nowhere holds her in place. Never cuts a longer stun short.
	if state in ["dead", "disabled", "loading"] or duration <= 0.0:
		return
	if damage == null:
		damage = Combat.Damage.new()
		damage.direction = -facing
	_enter_hit(damage, maxf(duration, hit_time if state == "hit" else 0.0))

func apply_dot(amount: float, _status: String) -> void:
	## Quiet damage from a status: no flinch, flash or meter, but it can still finish her off.
	if state in ["dead", "disabled", "loading"] or amount <= 0.0:
		return
	_apply_damage(amount)
	if health <= 0.0:
		_die()

func _roll_status(damage: Combat.Damage, scale: float) -> String:
	## An enemy blow's status sticks like it does on enemies, lowered by Lâm An's resistances.
	var id: String = String(damage.status.get("id", ""))
	if id == "" or state == "dead":
		return ""
	if randf() >= float(damage.status.get("chance", 1.0)) * scale * (1.0 - status_resistance(damage.element)):
		return ""
	statuses.resist = clampf(game.stat("status_resist"), 0.0, 0.9)
	var started: String = statuses.apply(id, int(damage.status.get("stacks", 1)), damage.status_power)
	if started != "":
		_status_started(started)
	_sync_statuses()
	return started

func _tick_statuses(delta: float) -> void:
	if statuses.active.is_empty() and statuses.immune.is_empty():
		return
	var effects: Dictionary = statuses.tick(delta, max_health())
	if float(effects["heal"]) > 0.0 and health < max_health():
		heal(float(effects["heal"]))
	if float(effects["dot"]) > 0.0:
		apply_dot(float(effects["dot"]), String(effects["dot_id"]))
	if float(effects["stun"]) > 0.0:
		stun(float(effects["stun"]))
	_sync_statuses()

func _status_started(id: String) -> void:
	var color: Color = Color(String(ContentDB.status(id).get("color", "ffffff")))
	if StatusEffects.kind_of(id) == "buff":
		Vfx.ring(get_parent(), global_position + Vector3.UP * 0.15, 1.2, color, 0.5)
	else:
		Vfx.burst(get_parent(), global_position + Vector3.UP * 1.2, color, 10, 3.0, 0.08, 0.4)

func _sync_statuses() -> void:
	## Pushes the live status bonuses into GameState.stat and tells listeners the list changed.
	if status_revision == statuses.revision:
		return
	status_revision = statuses.revision
	game.status_stats = statuses.stat_table()
	emit_signal("statuses_changed")

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
