class_name Npc
extends StaticBody3D
## Villager / story NPC: rigged model with idle/talk/walk loops, optional patrol,
## faces the player while talking and shows short barks above the head.

var entity: Dictionary = {}
var entity_id: String = ""
var display_name: String = ""
var visual: CharacterVisual
var bark_label: Label3D
var bark_timer: float = 0.0
var talking: bool = false
var patrol: Array = []
var patrol_index: int = 0
var patrol_wait: float = 0.0
var layout: WorldLayout
var home_yaw: float = 0.0
var player: Node3D
var idle_anim: String = "idle"

func setup(data: Dictionary, assets: AssetLibrary, world_layout: WorldLayout) -> void:
	entity = data
	entity_id = String(data["id"])
	display_name = String(data.get("name", ""))
	layout = world_layout
	collision_layer = Combat.LAYER_NPC
	collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	visual = CharacterVisual.new()
	add_child(visual)
	visual.setup(assets, String(data["npc"]), false)
	if data.has("tint"):
		_apply_tint(data["tint"])
	if data.get("ghost", false):
		_make_ghost()
	idle_anim = String(data.get("anim", "idle"))
	visual.play_loop(idle_anim)
	if visual.player:
		visual.player.seek(randf() * 1.5, true)
	bark_label = Label3D.new()
	bark_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bark_label.font_size = 40
	bark_label.outline_size = 8
	bark_label.pixel_size = 0.005
	bark_label.position.y = 2.25
	bark_label.modulate = Color(1.0, 0.97, 0.88)
	bark_label.outline_modulate = Color(0.1, 0.12, 0.12, 0.85)
	bark_label.visible = false
	add_child(bark_label)
	patrol = data.get("patrol", [])
	add_to_group("npc")

func place(position_value: Vector3, yaw_degrees: float) -> void:
	global_position = position_value
	home_yaw = deg_to_rad(yaw_degrees)
	visual.rotation.y = home_yaw

func _apply_tint(tints: Dictionary) -> void:
	visual.apply_tint(tints)

func _make_ghost() -> void:
	var ghost: StandardMaterial3D = StandardMaterial3D.new()
	ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.albedo_color = Color(0.6, 0.95, 0.9, 0.42)
	ghost.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	for mesh: MeshInstance3D in visual.meshes:
		mesh.material_override = ghost
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	collision_layer = 0
	Vfx.wisps(self, Vfx.WIND, 18, 0.9)

func prompt() -> String:
	return "Nói chuyện với " + display_name

func bark(text: String, duration: float = 3.0) -> void:
	bark_label.text = text
	bark_label.visible = true
	bark_timer = duration

func set_talking(value: bool, target: Node3D = null) -> void:
	talking = value
	player = target
	if value and visual.has_animation("talk"):
		visual.play_loop("talk", 0.25)
	elif not value:
		visual.play_loop(idle_anim, 0.3)

func _process(delta: float) -> void:
	if bark_timer > 0.0:
		bark_timer -= delta
		if bark_timer <= 0.0:
			bark_label.visible = false
	if talking and player:
		var direction: Vector3 = player.global_position - global_position
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), clampf(delta * 6.0, 0.0, 1.0))
		return
	if patrol.size() > 1:
		_patrol(delta)
	else:
		visual.rotation.y = lerp_angle(visual.rotation.y, home_yaw, clampf(delta * 2.0, 0.0, 1.0))

func _patrol(delta: float) -> void:
	if patrol_wait > 0.0:
		patrol_wait -= delta
		visual.play_loop("idle")
		return
	var point: Array = patrol[patrol_index]
	var goal: Vector3 = Vector3(float(point[0]), 0.0, float(point[1]))
	var flat: Vector3 = Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
	if flat.length() < 0.3:
		patrol_index = (patrol_index + 1) % patrol.size()
		patrol_wait = randf_range(2.0, 5.0)
		return
	var step: Vector3 = flat.normalized() * minf(flat.length(), 1.4 * delta)
	var next: Vector3 = global_position + step
	next.y = layout.height_at(next.x, next.z)
	global_position = next
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(flat.x, flat.z), clampf(delta * 5.0, 0.0, 1.0))
	visual.play_loop("walk")
