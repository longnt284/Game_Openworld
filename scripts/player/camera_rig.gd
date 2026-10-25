class_name CameraRig
extends Node3D
## Third-person orbit camera: collision-aware spring arm, soft follow,
## stable lock-on with deliberate target switching and settings-scaled shake.

var target: Node3D
var pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var yaw: float = 0.0
var pitch: float = -0.3
var lock_target: Node3D
var switch_cooldown: float = 0.0
var flick: float = 0.0
var trauma: float = 0.0
var shake_scale: float = 1.0
var sensitivity: float = 0.0025
var invert_y: bool = false
var distance: float = 4.6
var noise: FastNoiseLite = FastNoiseLite.new()
var time: float = 0.0
var input_enabled: bool = true

func setup(follow: Node3D, exclude: RID) -> void:
	target = follow
	top_level = true
	pivot = Node3D.new()
	add_child(pivot)
	arm = SpringArm3D.new()
	arm.spring_length = distance
	arm.margin = 0.3
	arm.collision_mask = Combat.LAYER_WORLD
	arm.add_excluded_object(exclude)
	var probe: SphereShape3D = SphereShape3D.new()
	probe.radius = 0.25
	arm.shape = probe
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 62
	camera.far = 1500
	camera.near = 0.08
	arm.add_child(camera)
	camera.current = true
	noise.frequency = 1.4
	global_position = follow.global_position + Vector3.UP * 1.45

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not event is InputEventMouseMotion or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if lock_target:
		flick += motion.relative.x
		return
	yaw -= motion.relative.x * sensitivity
	pitch = clampf(pitch - motion.relative.y * sensitivity * (-1.0 if invert_y else 1.0), -1.15, 0.55)

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount * shake_scale, 0.0, 1.0)

func punch_fov(amount: float, duration: float) -> void:
	## Brief zoom-out kick (ultimates); returns to the resting field of view.
	var rest: float = 62.0
	var tween: Tween = camera.create_tween()
	tween.tween_property(camera, "fov", rest + amount, duration * 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "fov", rest, duration * 0.75).set_trans(Tween.TRANS_SINE)

func forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))

func set_lock(new_target: Node3D) -> void:
	lock_target = new_target
	flick = 0.0

func _process(delta: float) -> void:
	if target == null:
		return
	time += delta
	switch_cooldown = maxf(0.0, switch_cooldown - delta)
	var anchor: Vector3 = ((target as PlayerController).drawn_position() if target is PlayerController else target.global_position) + Vector3.UP * 1.45
	global_position = global_position.lerp(anchor, clampf(delta * 12.0, 0.0, 1.0))
	if lock_target and is_instance_valid(lock_target):
		var to_target: Vector3 = lock_target.global_position - global_position
		var desired_yaw: float = atan2(-to_target.x, -to_target.z)
		yaw = lerp_angle(yaw, desired_yaw, clampf(delta * 6.0, 0.0, 1.0))
		var flat: float = Vector2(to_target.x, to_target.z).length()
		var desired_pitch: float = clampf(-atan2(global_position.y - (lock_target.global_position.y + 1.0), flat) - 0.18, -0.7, 0.2)
		pitch = lerpf(pitch, desired_pitch, clampf(delta * 4.0, 0.0, 1.0))
	else:
		flick = 0.0
	pivot.rotation = Vector3(pitch, yaw, 0)
	arm.spring_length = lerpf(arm.spring_length, distance + (0.6 if lock_target else 0.0), clampf(delta * 3.0, 0.0, 1.0))
	trauma = maxf(0.0, trauma - delta * 1.6)
	var shake: float = trauma * trauma
	camera.h_offset = noise.get_noise_2d(time * 40.0, 0.0) * 0.25 * shake
	camera.v_offset = noise.get_noise_2d(0.0, time * 40.0) * 0.25 * shake
	camera.rotation.z = noise.get_noise_2d(time * 30.0, 50.0) * 0.04 * shake

func consume_flick() -> int:
	## Returns -1/+1 when the player flicked the mouse to switch targets.
	if switch_cooldown > 0.0 or absf(flick) < 140.0:
		flick = move_toward(flick, 0.0, 6.0)
		return 0
	var direction: int = 1 if flick > 0.0 else -1
	flick = 0.0
	switch_cooldown = 0.4
	return direction
