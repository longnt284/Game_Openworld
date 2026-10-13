class_name PlayerController
extends CharacterBody3D

var settings: GameSettings
var world: WorldManager
var pivot: Node3D
var visual: MeshInstance3D
var state: String = "idle"

func initialize(config: GameSettings) -> void:
	settings = config
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	visual = MeshInstance3D.new()
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = capsule.radius
	mesh.height = capsule.height
	visual.mesh = mesh
	visual.position.y = 0.9
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("e8b76a")
	material.roughness = 0.8
	visual.material_override = material
	add_child(visual)
	pivot = Node3D.new()
	pivot.position.y = 1.5
	pivot.rotation.x = -0.24
	add_child(pivot)
	var arm: SpringArm3D = SpringArm3D.new()
	arm.spring_length = 6.0
	arm.margin = 0.25
	arm.add_excluded_object(get_rid())
	pivot.add_child(arm)
	var camera: Camera3D = Camera3D.new()
	camera.current = true
	camera.fov = 65
	camera.far = 220
	arm.add_child(camera)
	floor_snap_length = 0.45

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		pivot.rotation.y -= motion.relative.x * settings.mouse_sensitivity
		pivot.rotation.x = clampf(pivot.rotation.x - motion.relative.y * settings.mouse_sensitivity, -0.9, 0.6)

func _physics_process(delta: float) -> void:
	if world == null or not world.is_position_ready(global_position):
		state = "loading"
		velocity = Vector3.ZERO
		return
	var axis: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = Basis(Vector3.UP, pivot.rotation.y) * Vector3(axis.x, 0, axis.y)
	var speed: float = settings.sprint_speed if Input.is_action_pressed("sprint") else settings.walk_speed
	velocity.x = move_toward(velocity.x, direction.x * speed, settings.acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, settings.acceleration * delta)
	if is_on_floor():
		velocity.y = 0.0
		if Input.is_action_just_pressed("jump"):
			velocity.y = settings.jump_speed
	else:
		velocity.y -= settings.gravity * delta
	move_and_slide()
	if not is_on_floor():
		state = "airborne"
	elif axis.length_squared() > 0.01:
		state = "sprint" if speed == settings.sprint_speed else "walk"
	else:
		state = "idle"

func teleport(point: Vector3) -> void:
	global_position = point
	velocity = Vector3.ZERO
