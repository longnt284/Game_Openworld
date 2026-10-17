class_name CharacterVisual
extends Node3D
## Wraps an imported rigged GLB: keeps its Skeleton3D/AnimationPlayer, drives it
## through an AnimationTree (locomotion blend + state transition + action one-shot),
## attaches weapons to the exported sockets and provides hit flash / hit-stop.

const LOOPING: PackedStringArray = ["idle", "walk", "run", "fall", "glide", "block", "talk", "work", "charge"]
const STATES: PackedStringArray = ["ground", "jump", "fall", "glide", "block", "dead"]

var model: Node3D
var player: AnimationPlayer
var tree: AnimationTree
var skeleton: Skeleton3D
var sword_socket: Node3D
var sheath_socket: Node3D
var weapon: Node3D
var weapon_key: String = ""
var action_node: AnimationNodeAnimation
var current_action: String = ""
var action_time: float = 0.0
var action_length: float = 0.0
var locomotion_speeds: Vector3 = Vector3(0.0, 1.8, 5.5)
var hitstop_left: float = 0.0
var flash_left: float = 0.0
var flash_material: StandardMaterial3D
## Elemental status glow kept on the meshes between hit flashes (null when none).
var status_material: StandardMaterial3D
var meshes: Array[MeshInstance3D] = []
var base_speed: float = 1.0
var has_tree: bool = false

func setup(assets: AssetLibrary, key: String, use_tree: bool = true) -> void:
	model = assets.instantiate("characters/" + key)
	add_child(model)
	player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	sword_socket = model.find_child("SwordSocket", true, false) as Node3D
	sheath_socket = model.find_child("SheathSocket", true, false) as Node3D
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	if player:
		for anim_name: StringName in player.get_animation_list():
			var animation: Animation = player.get_animation(anim_name)
			animation.loop_mode = Animation.LOOP_LINEAR if LOOPING.has(String(anim_name)) else Animation.LOOP_NONE
	flash_material = StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flash_material.albedo_color = Color(0.0, 0.0, 0.0)
	if use_tree and player:
		_build_tree()
	elif player:
		player.play("idle")

func has_animation(anim_name: String) -> bool:
	return player != null and player.has_animation(anim_name)

func animation_length(anim_name: String) -> float:
	return player.get_animation(anim_name).length if has_animation(anim_name) else 0.0

func _build_tree() -> void:
	var blend: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	var space: AnimationNodeBlendSpace1D = AnimationNodeBlendSpace1D.new()
	space.sync = true
	space.min_space = 0.0
	space.max_space = 9.0
	for entry: Array in [["idle", locomotion_speeds.x], ["walk", locomotion_speeds.y], ["run", locomotion_speeds.z]]:
		if has_animation(entry[0]):
			var clip: AnimationNodeAnimation = AnimationNodeAnimation.new()
			clip.animation = entry[0]
			space.add_blend_point(clip, entry[1], -1, StringName(entry[0]))
	blend.add_node("loco", space, Vector2(0, 0))
	var scale: AnimationNodeTimeScale = AnimationNodeTimeScale.new()
	blend.add_node("loco_scale", scale, Vector2(200, 0))
	blend.connect_node("loco_scale", 0, "loco")
	var transition: AnimationNodeTransition = AnimationNodeTransition.new()
	transition.xfade_time = 0.16
	for state: String in STATES:
		transition.add_input(state)
	blend.add_node("state", transition, Vector2(400, 0))
	blend.connect_node("state", 0, "loco_scale")
	for index: int in range(1, STATES.size()):
		var clip_name: String = {"jump": "jump", "fall": "fall", "glide": "glide", "block": "block", "dead": "death"}[STATES[index]]
		var clip: AnimationNodeAnimation = AnimationNodeAnimation.new()
		clip.animation = clip_name if has_animation(clip_name) else "idle"
		blend.add_node("clip_" + STATES[index], clip, Vector2(200, 120 * index))
		blend.connect_node("state", index, "clip_" + STATES[index])
	var one_shot: AnimationNodeOneShot = AnimationNodeOneShot.new()
	one_shot.fadein_time = 0.07
	one_shot.fadeout_time = 0.16
	blend.add_node("action", one_shot, Vector2(600, 0))
	action_node = AnimationNodeAnimation.new()
	action_node.animation = "idle"
	blend.add_node("action_clip", action_node, Vector2(400, 200))
	blend.connect_node("action", 0, "state")
	blend.connect_node("action", 1, "action_clip")
	var speed: AnimationNodeTimeScale = AnimationNodeTimeScale.new()
	blend.add_node("speed", speed, Vector2(800, 0))
	blend.connect_node("speed", 0, "action")
	blend.connect_node("output", 0, "speed")
	tree = AnimationTree.new()
	tree.tree_root = blend
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.active = true
	has_tree = true
	tree.set("parameters/speed/scale", 1.0)
	tree.set("parameters/loco_scale/scale", 1.0)

func set_locomotion(speed: float) -> void:
	if not has_tree:
		return
	tree.set("parameters/loco/blend_position", speed)
	var scale: float = 1.0
	if speed > locomotion_speeds.z:
		scale = clampf(speed / locomotion_speeds.z, 1.0, 1.45)
	elif speed > locomotion_speeds.y:
		scale = 1.0
	elif speed > 0.2:
		scale = clampf(speed / locomotion_speeds.y, 0.6, 1.2)
	tree.set("parameters/loco_scale/scale", scale)

func set_state(state: String) -> void:
	if has_tree:
		tree.set("parameters/state/transition_request", state)
	elif player:
		var clip: String = {"ground": "idle", "jump": "jump", "fall": "fall", "glide": "glide", "block": "block", "dead": "death"}.get(state, "idle")
		if has_animation(clip) and player.current_animation != clip:
			player.play(clip, 0.15)

func play_action(anim_name: String, speed: float = 1.0) -> void:
	if not has_animation(anim_name):
		return
	current_action = anim_name
	action_time = 0.0
	action_length = animation_length(anim_name) / maxf(speed, 0.01)
	base_speed = speed
	if has_tree:
		action_node.animation = anim_name
		tree.set("parameters/speed/scale", speed)
		tree.set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	else:
		player.play(anim_name, 0.1, speed)

func stop_action() -> void:
	current_action = ""
	if has_tree:
		tree.set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		tree.set("parameters/speed/scale", 1.0)

func play_loop(anim_name: String, blend_time: float = 0.2, speed: float = 1.0) -> void:
	## Direct AnimationPlayer playback for tree-less characters (NPCs, enemies).
	if player and has_animation(anim_name) and (player.current_animation != anim_name or not player.is_playing()):
		player.play(anim_name, blend_time, speed)

func attach_weapon(assets: AssetLibrary, key: String, sheathed: bool = false) -> void:
	if weapon:
		weapon.queue_free()
	weapon_key = key
	# Swords name their model in data/weapons.json; a missing model falls back to the wind sword.
	var model_key: String = "weapons/" + String(ContentDB.weapon(key).get("model", key))
	weapon = assets.instantiate(model_key if assets.scenes.has(model_key) else "weapons/sword_wind")
	var socket: Node3D = sheath_socket if sheathed and sheath_socket else sword_socket
	if socket:
		socket.add_child(weapon)
	else:
		add_child(weapon)

func set_sheathed(sheathed: bool) -> void:
	if weapon == null or sheath_socket == null or sword_socket == null:
		return
	var target: Node3D = sheath_socket if sheathed else sword_socket
	if weapon.get_parent() != target:
		weapon.reparent(target, false)
		weapon.transform = Transform3D.IDENTITY

func flash(color: Color = Color(1.0, 0.92, 0.8), duration: float = 0.09) -> void:
	flash_left = duration
	flash_material.albedo_color = color * 0.55
	for mesh: MeshInstance3D in meshes:
		mesh.material_overlay = flash_material

func set_status_tint(color: Color) -> void:
	if color.a <= 0.0:
		status_material = null
	else:
		if status_material == null:
			status_material = StandardMaterial3D.new()
			status_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			status_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			status_material.rim_enabled = false
		status_material.albedo_color = Color(color.r * 0.35, color.g * 0.35, color.b * 0.35)
	if flash_left <= 0.0:
		for mesh: MeshInstance3D in meshes:
			mesh.material_overlay = status_material

func hitstop(duration: float) -> void:
	hitstop_left = maxf(hitstop_left, duration)

func is_frozen() -> bool:
	return hitstop_left > 0.0

func _process(delta: float) -> void:
	if hitstop_left > 0.0:
		hitstop_left -= delta
		_set_playback_speed(0.04)
		if hitstop_left <= 0.0:
			_set_playback_speed(1.0)
	elif current_action != "":
		action_time += delta
		if action_time >= action_length:
			current_action = ""
	if flash_left > 0.0:
		flash_left -= delta
		if flash_left <= 0.0:
			for mesh: MeshInstance3D in meshes:
				mesh.material_overlay = status_material

func _set_playback_speed(factor: float) -> void:
	if has_tree:
		tree.set("parameters/speed/scale", base_speed * factor)
		tree.set("parameters/loco_scale/scale", factor if factor < 1.0 else 1.0)
	elif player:
		player.speed_scale = factor
