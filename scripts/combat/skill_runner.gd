class_name SkillRunner
extends RefCounted
## Starts a sword form when its strike frame arrives. Sweeps, dashes and spinning ticks
## are resolved frame by frame in PlayerController; everything here (missiles, chain
## lightning, delayed strikes, rock fissures, novas, fields) runs on its own nodes after the
## cast. A form with "self_buff" also puts that buff on Lâm An as it fires.

static func fire(player: PlayerController, data: Dictionary, scale: float) -> void:
	var color: Color = form_color(data)
	var parent: Node = player.get_parent()
	var kind: String = String(data.get("kind", "sweep"))
	match kind:
		"projectile":
			_projectiles(player, data, scale, color)
		"chain":
			_chain(player, data, scale, color)
		"strikes":
			_strikes(player, data, scale, color)
		"fissure":
			_fissure(player, data, scale, color)
		"nova":
			var nova: AreaEffect = AreaEffect.spawn(player, data, scale, "nova", color)
			for pulse: int in range(int(data.get("pulses", 1))):
				nova.events.append({"time": pulse * float(data.get("pulse_interval", 0.15)), "position": player.global_position, "radius": float(data.get("nova_radius", 5.0))})
		"field":
			var center: Vector3 = player.global_position + player.facing * float(data.get("field_distance", 4.0))
			var effect: AreaEffect = AreaEffect.spawn(player, data, scale, "field", color)
			effect.start_field(center, float(data.get("field_radius", 4.0)), float(data.get("field_time", 3.0)))
		"tick":
			pass
		_:
			Vfx.slash(parent, player.global_position, player.facing, data, Color(color.r, color.g, color.b, 0.9) if data.has("element") else Color(1, 1, 1, 0.8))
	if data.has("self_buff"):
		player.apply_status(String(data["self_buff"]), 1, 0.0, float(data.get("buff_time", 0.0)))
	match String(data.get("vfx", "")):
		"flame_wheel":
			Vfx.flames(parent, player.global_position, float(data.get("radius", 2.0)), 0.6, 50)
			Vfx.ring(parent, player.global_position + Vector3.UP * 0.9, float(data.get("radius", 2.0)) + 0.4, color, 0.4, 0.2)

static func form_color(data: Dictionary) -> Color:
	return Vfx.element_color(String(data.get("element", ""))) if data.has("element") else Vfx.SPARK

static func tick_vfx(player: PlayerController, data: Dictionary) -> void:
	## One revolution of a spinning form (Toàn Phong and its elemental cousins).
	var color: Color = form_color(data)
	var parent: Node = player.get_parent()
	var radius: float = float(data.get("hit_radius", 3.0))
	Vfx.ring(parent, player.global_position + Vector3.UP * 0.6, radius, color, 0.25, 0.12)
	match String(data.get("vfx", "")):
		"whirlpool":
			Vfx.spiral(parent, player.global_position, radius * 0.8, color, 0.35, 1.0)
		"flame_spiral":
			Vfx.flames(parent, player.global_position, radius * 0.7, 0.4, 10)

static func _projectiles(player: PlayerController, data: Dictionary, scale: float, color: Color) -> void:
	var count: int = int(data.get("count", 1))
	var spread: float = deg_to_rad(float(data.get("spread", 0.0)))
	var shape: String = String(data.get("shape", "crescent"))
	if shape == "crescent":
		Vfx.slash(player.get_parent(), player.global_position, player.facing, data, Color(color.r, color.g, color.b, 0.9))
	for index: int in range(count):
		var offset: float = (index - (count - 1) * 0.5) * spread
		var missile: WindProjectile = WindProjectile.new()
		missile.process_mode = Node.PROCESS_MODE_PAUSABLE
		missile.radius = float(data.get("width", 1.6)) * 0.5
		missile.max_distance = float(data.get("range", 14.0))
		missile.pierce = bool(data.get("pierce", true))
		missile.strike_scale = scale
		player.get_parent().add_child(missile)
		var direction: Vector3 = player.facing.rotated(Vector3.UP, offset)
		var height: float = 0.2 if shape == "wave" else 1.1
		missile.launch(player.global_position + Vector3.UP * height + direction * 0.8, direction, float(data.get("missile_speed", 22.0)), 0.0, data, Combat.LAYER_HURT_ENEMY, player, color, shape)

static func _living_enemies(player: PlayerController) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node: Node in player.get_tree().get_nodes_in_group("enemy"):
		var enemy: Node3D = node as Node3D
		if enemy and not (enemy.has_method("is_dead") and enemy.is_dead()):
			result.append(enemy)
	return result

static func _chain(player: PlayerController, data: Dictionary, scale: float, color: Color) -> void:
	var origin: Vector3 = player.global_position + Vector3.UP * 1.3
	var reach: float = float(data.get("range", 10.0))
	var current: Node3D = player.lock_target if player.lock_target and is_instance_valid(player.lock_target) else null
	if current == null:
		var best_score: float = -INF
		for enemy: Node3D in _living_enemies(player):
			var offset: Vector3 = enemy.global_position - player.global_position
			offset.y = 0.0
			if offset.length() > reach:
				continue
			var score: float = offset.normalized().dot(player.facing) * 2.0 - offset.length() * 0.15
			if score > best_score:
				best_score = score
				current = enemy
	if current == null:
		Vfx.bolt(player.get_parent(), origin, origin + player.facing * reach * 0.6, color, 0.2)
		return
	var hit: Dictionary = {}
	var factor: float = scale
	for jump: int in range(int(data.get("jumps", 3)) + 1):
		var target_point: Vector3 = current.global_position + Vector3.UP * 1.0
		Vfx.bolt(player.get_parent(), origin, target_point, color)
		Vfx.burst(player.get_parent(), target_point, color, 12, 5.0)
		var direction: Vector3 = target_point - origin
		direction.y = 0.0
		player.strike(current, data, factor, direction.normalized() if direction.length() > 0.05 else player.facing, true)
		hit[current] = true
		origin = target_point
		factor *= float(data.get("falloff", 0.8))
		var next: Node3D = null
		var nearest: float = float(data.get("jump_range", 6.0))
		for enemy: Node3D in _living_enemies(player):
			if hit.has(enemy):
				continue
			var distance: float = enemy.global_position.distance_to(current.global_position)
			if distance < nearest:
				nearest = distance
				next = enemy
		if next == null:
			break
		current = next

static func _fissure(player: PlayerController, data: Dictionary, scale: float, color: Color) -> void:
	## A line of rock spikes bursting out one after another ahead of Lâm An; a foe standing
	## where two spikes overlap is hit once ("hit_once").
	var effect: AreaEffect = AreaEffect.spawn(player, data, scale, "strikes", color)
	var step: float = float(data.get("step", 1.7))
	var origin: Vector3 = player.global_position
	for index: int in range(int(data.get("steps", 6))):
		var point: Vector3 = origin + player.facing * (float(data.get("start", 1.3)) + index * step)
		if player.world and (not player.world.layout.inside_bounds(point.x, point.z) or player.world.layout.in_chasm(point.x, point.z)):
			break
		effect.add_strike(point, 0.02 + index * float(data.get("interval", 0.06)), float(data.get("strike_radius", 1.4)))

static func _strikes(player: PlayerController, data: Dictionary, scale: float, color: Color) -> void:
	var effect: AreaEffect = AreaEffect.spawn(player, data, scale, "strikes", color)
	var reach: float = float(data.get("range", 12.0))
	var targets: Array[Node3D] = []
	for enemy: Node3D in _living_enemies(player):
		if enemy.global_position.distance_to(player.global_position) <= reach:
			targets.append(enemy)
	targets.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
	var count: int = int(data.get("targets", 4))
	var points: Array[Vector3] = []
	for index: int in range(mini(count, targets.size())):
		points.append(targets[index].global_position)
	# With few enemies around, the rest of the strikes land in a fan ahead of Lâm An.
	var spare: int = 0
	while points.size() < count:
		var angle: float = (spare - (count - 1) * 0.5) * 0.45
		points.append(player.global_position + player.facing.rotated(Vector3.UP, angle) * (3.0 + spare * 1.2))
		spare += 1
	for index: int in range(points.size()):
		effect.add_strike(points[index], float(data.get("delay", 0.3)) + index * float(data.get("interval", 0.1)), float(data.get("strike_radius", 2.2)))
