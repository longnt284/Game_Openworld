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
## A blow set off an elemental reaction on this enemy (splash false), or a reaction's splash,
## spread or chain hit it (splash true); amount is what this enemy lost.
signal reaction_hit(enemy: Enemy, reaction: String, amount: float, splash: bool)
## Poise ran out: the enemy is broken (a long stagger, open to a finisher).
signal poise_broken(enemy: Enemy)

## Attack slots per camp when the enemy data has no "max_attackers".
const MAX_ATTACKERS: int = 2
## Ordinary foes stay broken at least this long, whatever their "break_stagger".
const BROKEN_MIN: float = 2.2
## Bosses can be finished only early in their break unless their data has "finish_window".
const BOSS_FINISH_WINDOW: float = 1.5
## Seconds the overhead poise bar lingers after the last hit.
const POISE_BAR_LINGER: float = 3.0

static var tokens: Dictionary = {}
## Tâm Nhãn: the rate of every enemy's clock (AI, swings, animation, statuses, its missiles and
## areas); Lâm An keeps real time. 1.0 outside focus; set through set_time_dilation.
static var time_dilation: float = 1.0

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
## The current stagger came from a poise break; finish_time is how much of it is still open to
## a finisher (all of it for ordinary foes, the first BOSS_FINISH_WINDOW seconds for bosses).
var broken: bool = false
var finish_time: float = 0.0
## Seconds since a blow last landed (drives the overhead poise bar).
var since_hit: float = 99.0
## Overhead health and poise gauges, built the first time they are needed (never for bosses).
var poise_bar: PoiseBar

func setup(entity: Dictionary, library: AssetLibrary, world_manager: WorldManager) -> void:
	data = ContentDB.enemy(String(entity["enemy"]))
	kind = String(entity["enemy"])
	owner_key = String(data.get("owner", "bandit"))
	entity_id = String(entity["id"])
	camp = String(entity.get("camp", ""))
	persistent = bool(entity.get("persistent", false))
	# Minibosses (the golem, the wolf pack leader) fight like bosses: the HUD bar instead of the
	# overhead gauges, no waiting for attack slots, a short finisher window.
	if data.get("miniboss", false):
		boss = true
	assets = library
	world = world_manager
	max_health = float(data.get("hp", 60))
	health = max_health
	max_poise = float(data.get("poise", 30))
	poise = max_poise
	statuses.resist = float(data.get("status_resist", 0.0))
	statuses.no_freeze = bool(data.get("super_armor", false))
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
	# Palette recolour by material name, so one model serves several kinds (or one placed foe).
	var tint: Dictionary = entity.get("tint", data.get("tint", {}))
	if not tint.is_empty():
		visual.apply_tint(tint)
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

func is_broken() -> bool:
	## Staggered by a poise break: takes ×1.35 like any stagger, and the poise bars show it.
	return broken and state == "stagger"

func is_finishable() -> bool:
	## A finisher may start on this enemy now (F within reach, PlayerController.start_finisher).
	return is_broken() and finish_time > 0.0 and not invulnerable

func poise_ratio() -> float:
	## 0..1 poise left before the next break, for the poise bars; empty while broken.
	if is_broken() or max_poise <= 0.0:
		return 0.0
	return clampf(poise / max_poise, 0.0, 1.0)

func hold(seconds: float) -> void:
	## Keeps a staggered enemy down at least `seconds` longer, so a finisher on its way still lands.
	if state == "stagger":
		stagger_time = maxf(stagger_time, state_time + seconds)

static func set_time_dilation(value: float) -> void:
	## Tâm Nhãn slows every enemy to `value` of real time (1.0 restores it). Ground warnings
	## already on their way (Vfx "enemy_clock") follow at once, so they still fill as the blow lands.
	time_dilation = clampf(value, 0.05, 1.0)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for marker: Node in tree.get_nodes_in_group(Vfx.ENEMY_CLOCK):
		for tween: Variant in marker.get_meta("tweens", []):
			if (tween as Tween).is_valid():
				(tween as Tween).set_speed_scale(time_dilation)

# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	since_hit += delta
	update_poise_bar(delta)

func _physics_process(delta: float) -> void:
	if world == null or not world.is_position_ready(global_position):
		velocity = Vector3.ZERO
		return
	# Everything below runs on the enemy clock: slowed under Tâm Nhãn, real time otherwise.
	delta *= time_dilation
	visual.set_time_scale(time_dilation)
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
	_slide()
	_track_stuck(delta)

func _slide() -> void:
	## move_and_slide on the enemy clock: velocity stays in the enemy's own metres per second
	## (knockback, charges and gravity included), only the distance covered per frame slows.
	if time_dilation >= 1.0:
		move_and_slide()
		return
	velocity *= time_dilation
	move_and_slide()
	velocity /= time_dilation

func _tick_statuses(delta: float) -> void:
	var effects: Dictionary = statuses.tick(delta)
	# Buffs such as Cuồng nộ quicken the whole body, swings included.
	speed_scale = base_speed_scale * statuses.speed_mult() * maxf(0.3, 1.0 + statuses.stat_bonus("move_speed"))
	if float(effects["dot"]) > 0.0:
		apply_dot(float(effects["dot"]), String(effects["dot_id"]))
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
			finish_time = maxf(0.0, finish_time - delta)
			if state_time >= stagger_time:
				poise = max_poise
				_set_state("chase")
		"return":
			_physics_return(delta)

func _set_state(next: String) -> void:
	if state == "attack" and next != "attack":
		_release_token()
	if next != "stagger":
		broken = false
		finish_time = 0.0
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
	# Fog and night shorten the first sighting; a foe already alerted keeps its full range.
	if _can_see_target(float(data.get("detect", 13.0)) * (1.0 if boss else Combat.detect_mult())):
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
		_slide()
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
	var amount: float = float(attack.get("damage", 10)) * float(data.get("damage_scale", 1.0)) * maxf(0.2, 1.0 + statuses.stat_bonus("attack_bonus"))
	var damage: Combat.Damage = Combat.make_damage(self, attack, amount, (entity as Node3D).global_position)
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
	# A freeze or stun landing on a broken foe keeps it down for the rest of the break;
	# any other stagger starts unbroken.
	if state != "stagger":
		broken = false
		finish_time = 0.0
	stagger_time = maxf(duration, finish_time) if broken else duration
	_release_token()
	_set_state("stagger")
	Vfx.burst(get_parent(), global_position + Vector3.UP * float(data.get("height", 1.8)) * 0.8, Color(1, 0.95, 0.6), 10, 3.0)

func _break(duration: float = -1.0) -> void:
	## Poise ran out: a long stagger ("break_stagger", at least BROKEN_MIN for ordinary foes) in
	## which the enemy takes ×1.35 and can be finished ("finish_window"; bosses only briefly).
	poise = max_poise
	var hold_for: float = duration if duration > 0.0 else float(data.get("break_stagger", 1.4))
	if not boss:
		hold_for = maxf(hold_for, BROKEN_MIN)
	_stagger(hold_for)
	broken = true
	finish_time = float(data.get("finish_window", minf(hold_for, BOSS_FINISH_WINDOW) if boss else hold_for))
	Vfx.ring(get_parent(), global_position + Vector3.UP * float(data.get("height", 1.8)) * 0.55, float(data.get("radius", 0.4)) + 0.6, Color(1.0, 0.8, 0.4), 0.35, 0.12)
	emit_signal("poise_broken", self)

# ------------------------------------------------------------------ damage

func take_damage(damage: Combat.Damage) -> Dictionary:
	if state == "dead" or invulnerable:
		return {"hit": false}
	since_hit = 0.0
	# A finisher deals at least its share of this foe's health, before the reaction and multipliers.
	damage.amount = maxf(damage.amount, max_health * damage.hp_floor)
	# Judged on what the blow found: a reaction may consume the status that made this target take
	# more of the element, and a freeze it starts is no stagger for the blow that started it.
	var multiplier: float = (1.35 if state == "stagger" else 1.0) * element_mult(damage.element) * statuses.taken_mult(damage.element) * Combat.weather_mult(damage.element)
	var reaction: Dictionary = Reactions.check(statuses, damage)
	if not reaction.is_empty():
		Reactions.apply(self, damage, reaction)
	var amount: float = damage.amount * multiplier * Combat.defense_mult(defense() - damage.armor_pen)
	if boss and damage.boss_cap > 0.0:
		amount = minf(amount, max_health * damage.boss_cap)
	health = maxf(0.0, health - amount)
	emit_signal("health_changed", self, health, max_health)
	if damage.flinch:
		visual.flash()
		visual.hitstop(damage.hitstop)
	if state in ["idle", "return"]:
		_alert_camp()
	var result: Dictionary = {"hit": true, "amount": amount}
	if damage.reaction != "":
		result["reaction"] = damage.reaction
		emit_signal("reaction_hit", self, damage.reaction, amount, damage.reaction_splash)
	if health <= 0.0:
		_die(damage)
		result["killed"] = true
		return result
	# A reaction's own status (Đông Kết's freeze, Hỏa Lốc's burn) replaces the blow's roll.
	var started: String = Reactions.apply_status(self, reaction, damage.status_power) if reaction.has("apply") else _roll_status(damage)
	result["status"] = started
	if started == "freeze":
		return result
	poise -= damage.poise * statuses.poise_mult()
	if not damage.flinch:
		return result
	# A reaction that breaks (Vỡ Băng) knocks down a foe the ice was already holding.
	if poise <= 0.0 and (state != "stagger" or reaction.get("break", false)):
		velocity = damage.direction * damage.knockback
		_break()
	elif state != "stagger" and not (state == "attack" and data.get("super_armor", false)):
		if state == "attack":
			_release_token()
		velocity = damage.direction * damage.knockback * float(data.get("knockback_scale", 1.0))
		state = "hit"
		state_time = 0.0
		visual.play_action("hit")
	return result

func element_mult(element: String) -> float:
	return float((data.get("resist", {}) as Dictionary).get(element, 1.0)) if element != "" else 1.0

func defense() -> float:
	## Flat damage reduction from data "defense" (0 by default) plus any status that grants it;
	## blows keep 100 / (100 + defense − their armor_pen). Not "super_armor", which only stops flinching.
	return float(data.get("defense", 0.0)) + statuses.stat_bonus("defense")

func _roll_status(damage: Combat.Damage) -> String:
	var status: String = String(damage.status.get("id", ""))
	if status == "":
		return ""
	if randf() >= float(damage.status.get("chance", 1.0)) * (1.0 - statuses.resist * 0.5):
		return ""
	return apply_status(status, int(damage.status.get("stacks", 1)), damage.status_power)

func apply_status(id: String, stacks: int = 1, power: float = 0.0) -> String:
	## Puts a status on this enemy (a blow's roll, a reaction); a freeze holds it in place at once.
	## Returns the status that started, like StatusEffects.apply.
	var started: String = statuses.apply(id, stacks, power)
	if started == "freeze":
		velocity = Vector3.ZERO
		_stagger(statuses.stun_time("freeze"))
		Vfx.shards(get_parent(), global_position, Color("dff8ff"), 7, float(data.get("radius", 0.5)) + 0.4, float(data.get("height", 1.8)) * 0.7, statuses.stun_time("freeze"))
	return started

func _die(damage: Combat.Damage) -> void:
	_release_token()
	broken = false
	finish_time = 0.0
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

# ------------------------------------------------------------------ poise bar

func poise_bar_wanted() -> bool:
	## The overhead poise bar shows over ordinary foes only (bosses use the HUD): while Lâm An is
	## locked on, for POISE_BAR_LINGER seconds after a hit, and all through a break.
	if boss or state == "dead" or max_poise <= 0.0:
		return false
	return (target != null and target.lock_target == self) or since_hit < POISE_BAR_LINGER or is_broken()

func update_poise_bar(delta: float) -> void:
	var wanted: bool = poise_bar_wanted()
	if poise_bar == null:
		if not wanted:
			return
		poise_bar = PoiseBar.new()
		poise_bar.name = "PoiseBar"
		add_child(poise_bar)
		poise_bar.setup(float(data.get("height", 1.8)))
	poise_bar.show_poise(wanted, poise_ratio(), is_finishable(), delta, health / maxf(max_health, 1.0))

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
	if holders.size() >= max_attackers():
		tokens[camp] = holders
		return false
	holders.append(self)
	tokens[camp] = holders
	return true

func _token_free() -> bool:
	var holders: Array = (tokens.get(camp, []) as Array).filter(func(item: Variant) -> bool: return is_instance_valid(item) and (item as Enemy).state == "attack")
	return holders.size() < max_attackers()

func max_attackers() -> int:
	## How many of this enemy's camp may swing at once before it waits its turn (bosses never wait).
	return int(data.get("max_attackers", MAX_ATTACKERS))

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

func fire_missile(origin: Vector3, aim: Vector3, attack: Dictionary, shape: String, tint: Color) -> WindProjectile:
	## Looses one missile of this attack (data "damage", "missile_speed", "range", "gravity") at
	## `aim`: straight, or lobbed on a ballistic arc that lands on the aim point when "gravity" is set.
	var missile: WindProjectile = WindProjectile.new()
	missile.process_mode = Node.PROCESS_MODE_PAUSABLE
	missile.radius = float(attack.get("width", 0.5)) * 0.5
	missile.max_distance = float(attack.get("range", 28.0))
	missile.pierce = false
	get_parent().add_child(missile)
	var speed: float = float(attack.get("missile_speed", 22.0))
	var direction: Vector3 = (aim - origin).normalized()
	var gravity: float = float(attack.get("gravity", 0.0))
	if gravity > 0.0:
		var flat: Vector3 = Vector3(aim.x - origin.x, 0.0, aim.z - origin.z)
		var time: float = maxf(0.35, flat.length() / speed)
		var rise: float = (aim.y - origin.y + 0.5 * gravity * time * time) / time
		var launch_velocity: Vector3 = flat / time + Vector3.UP * rise
		missile.gravity = gravity
		missile.max_distance = maxf(missile.max_distance, launch_velocity.length() * time * 1.5)
		speed = launch_velocity.length()
		direction = launch_velocity.normalized()
	missile.launch(origin, direction, speed, float(attack.get("damage", 10)) * float(data.get("damage_scale", 1.0)) * maxf(0.2, 1.0 + statuses.stat_bonus("attack_bonus")),
		attack, Combat.LAYER_HURT_PLAYER, self, tint, shape)
	return missile

func aim_point(speed: float, lead: float = 0.6) -> Vector3:
	## Where to aim a missile at the target: its chest, led by part of its run over the flight.
	if target == null:
		return global_position + facing * 10.0 + Vector3.UP
	var chest: Vector3 = target.global_position + Vector3.UP * 1.1
	var flight: float = global_position.distance_to(chest) / maxf(speed, 1.0)
	var run: Vector3 = Vector3(target.velocity.x, 0.0, target.velocity.z)
	return chest + run * flight * lead

func _face_target(delta: float, rate: float) -> void:
	rate *= float(data.get("turn_rate", 1.0))
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
		facing = facing.slerp(direction, clampf(delta * 8.0 * float(data.get("turn_rate", 1.0)), 0.0, 1.0)).normalized()
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
	blocked_time += get_physics_process_delta_time() * time_dilation
	# A target across water or a gorge cannot be reached: give up and walk home.
	if state == "chase" and blocked_time > 2.5:
		blocked_time = 0.0
		_set_state("return")

func _track_stuck(delta: float) -> void:
	# Judged on the distance really covered, which Tâm Nhãn shortens.
	if state in ["chase", "return"] and Vector2(velocity.x, velocity.z).length() * time_dilation > 0.5:
		if global_position.distance_to(last_position) < 0.02:
			stuck_time += delta
			if stuck_time > 2.5 and state == "return":
				global_position = home
				stuck_time = 0.0
		else:
			stuck_time = 0.0
	last_position = global_position
