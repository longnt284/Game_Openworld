class_name Arena
extends Node3D
## Wind barrier around the Trúc Hải arena. Closed before the chime puzzle is solved
## (keeps the guardian out of reach) and while the boss fight is running.

signal fight_started
signal fight_reset

const BARRIER_SHADER: Shader = preload("res://shaders/barrier.gdshader")
const IDLE_TINT: Color = Color(0.55, 0.95, 0.85)
const FIGHT_TINT: Color = Color(1.0, 0.55, 0.4)

var radius: float = 24.0
var body: StaticBody3D
var wall: MeshInstance3D
var wall_material: ShaderMaterial
var closed: bool = false
var fighting: bool = false

func setup(data: Dictionary, layout: WorldLayout) -> void:
	radius = float(data.get("radius", 24.0))
	var center: Vector2 = Vector2(float(data["pos"][0]), float(data["pos"][1]))
	global_position = Vector3(center.x, layout.height_at(center.x, center.y), center.y)
	body = StaticBody3D.new()
	body.collision_layer = Combat.LAYER_WORLD | Combat.LAYER_ENEMY
	add_child(body)
	var segments: int = 32
	for index: int in range(segments):
		var angle: float = TAU * index / segments
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(TAU * radius / segments + 0.6, 16.0, 0.8)
		shape.shape = box
		shape.position = Vector3(sin(angle) * radius, 4.0, cos(angle) * radius)
		shape.rotation.y = angle
		body.add_child(shape)
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 9.0
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	cylinder.radial_segments = 48
	wall = MeshInstance3D.new()
	wall.mesh = cylinder
	wall.position.y = 3.0
	wall_material = ShaderMaterial.new()
	wall_material.shader = BARRIER_SHADER
	wall_material.set_shader_parameter("wall_height", cylinder.height)
	_set_wall_tint(IDLE_TINT, 0.35)
	wall.material_override = wall_material
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wall)
	var motes: CPUParticles3D = Vfx.wisps(self, Vfx.WIND, 40, radius)
	motes.position.y = 2.0
	set_closed(true)

func set_closed(value: bool) -> void:
	closed = value
	body.process_mode = Node.PROCESS_MODE_INHERIT
	for shape: Node in body.get_children():
		(shape as CollisionShape3D).set_deferred("disabled", not value)
	wall.visible = value

func contains(point: Vector3) -> bool:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length() < radius - 3.0

func start_fight() -> void:
	if fighting:
		return
	fighting = true
	set_closed(true)
	_set_wall_tint(FIGHT_TINT, 0.6)
	emit_signal("fight_started")

func end_fight(victory: bool) -> void:
	fighting = false
	_set_wall_tint(IDLE_TINT, 0.35)
	set_closed(false)
	if not victory:
		emit_signal("fight_reset")

func _set_wall_tint(tint: Color, strength: float) -> void:
	wall_material.set_shader_parameter("tint", tint)
	wall_material.set_shader_parameter("strength", strength)

func _process(_delta: float) -> void:
	if wall.visible:
		wall.rotation.y += 0.002
