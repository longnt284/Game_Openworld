class_name Interactable
extends Node3D
## World objects the player can use with the interact key. State lives in GameState
## flags keyed by the stable entity id, so reloading or re-streaming never resets them.

var entity: Dictionary = {}
var entity_id: String = ""
var kind: String = ""
var model: Node3D
var glow: MeshInstance3D
var lid: Node3D
var wisps: CPUParticles3D
var radius: float = 2.6
var main: Node

func setup(data: Dictionary, assets: AssetLibrary, owner_main: Node) -> void:
	entity = data
	entity_id = String(data["id"])
	kind = String(data["type"])
	main = owner_main
	var model_key: String = {"shrine": "shrine_wind", "chest": "chest", "chime": "wind_chime_post", "memory_core": "memory_stone", "seal_gate": "seal_gate"}.get(kind, "")
	if model_key != "":
		model = assets.instantiate("env/" + model_key)
		add_child(model)
		for body: Node in model.find_children("*", "StaticBody3D", true, false):
			(body as StaticBody3D).collision_layer = Combat.LAYER_WORLD
			body.set_meta("surface", "stone")
		glow = model.find_child("Glow", true, false) as MeshInstance3D
		lid = model.find_child("Lid", true, false) as Node3D
	if kind in ["echo", "diary"]:
		wisps = Vfx.wisps(self, Vfx.WIND if kind == "echo" else Color(1.0, 0.9, 0.6), 16, 0.5)
		wisps.position.y = 1.2 if kind == "echo" else 1.0
		var core: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.16
		sphere.height = 0.32
		core.mesh = sphere
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.75, 1.0, 0.95) if kind == "echo" else Color(1.0, 0.92, 0.7)
		core.material_override = material
		core.position.y = 1.25 if kind == "echo" else 0.95
		add_child(core)
		radius = 2.2
	if kind == "seal_gate":
		_build_seal_barrier()
		radius = 4.5
	if kind == "chime":
		radius = 2.4
	add_to_group("interactable")
	refresh()

func _build_seal_barrier() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = Combat.LAYER_WORLD
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(18.0, 12.0, 1.0)
	shape.shape = box
	shape.position = Vector3(0, 5.0, 0)
	body.add_child(shape)
	add_child(body)
	var barrier: MeshInstance3D = model.find_child("Barrier", true, false) as MeshInstance3D
	if barrier:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.albedo_color = Color(1.0, 0.35, 0.28, 0.35)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		barrier.material_override = material
	Vfx.wisps(self, Vfx.SEAL, 24, 2.5).position.y = 2.5

func flag_key() -> String:
	return {"chest": "opened:", "shrine": "lit:", "echo": "echo_seen:", "diary": "read:", "memory_core": "memory:"}.get(kind, "used:") + entity_id

func is_used() -> bool:
	return main.state.has_flag(flag_key())

func refresh() -> void:
	if kind == "chest" and lid:
		lid.rotation.x = -1.9 if is_used() else 0.0
	if kind == "shrine" and glow:
		glow.visible = is_used()
	if kind in ["echo", "diary"]:
		visible = not is_used()
	if kind == "memory_core" and glow:
		glow.visible = not is_used()

func can_interact() -> bool:
	if kind in ["echo", "diary", "chest", "memory_core"] and is_used():
		return false
	return true

func prompt() -> String:
	match kind:
		"shrine":
			return "Nghỉ chân tại Miếu Gió" if is_used() else "Thắp Miếu Gió"
		"chest":
			return "Mở rương"
		"echo":
			return "Lắng nghe tiếng vọng"
		"diary":
			return "Đọc nhật ký"
		"chime":
			return "Gõ " + String(entity.get("title", "chuông")).to_lower()
		"memory_core":
			return "Chạm vào ký ức"
		"seal_gate":
			return "Xem cổng phong ấn"
	return "Tương tác"

func interact() -> void:
	main.on_interact(self)

func open_lid() -> void:
	if lid:
		var tween: Tween = create_tween()
		tween.tween_property(lid, "rotation:x", -1.9, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Vfx.burst(get_parent(), global_position + Vector3.UP * 0.7, Color(1.0, 0.88, 0.5), 22, 4.0, 0.08, 0.6)
