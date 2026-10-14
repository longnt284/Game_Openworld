class_name AssetLibrary
extends RefCounted
## Loads every runtime GLB once (threaded when rendering, synchronous in headless),
## converts materials to the toon look and exposes mesh parts for MultiMesh flora.

const FLORA: Dictionary = {
	"pine": "env/tree_pine", "maple": "env/tree_maple", "bamboo": "env/bamboo_cluster", "rock": "env/rock_moss", "grass": "env/grass_tuft",
}
const CHARACTERS: PackedStringArray = ["lam_an", "tieu_mac", "ba_luc", "chu_bay", "ba_hanh", "tich_phong", "tan_binh", "truc_tuong", "heo_gio"]
const WEAPONS: PackedStringArray = ["sword_old", "sword_bamboo", "sword_wind", "sabre", "glaive"]
const PROPS: PackedStringArray = [
	"house_small", "house_long", "house_teal", "smithy", "gate_village", "shrine_wind", "bridge_wood", "dock", "boat", "lantern_stone",
	"lantern_post", "signboard", "table", "bench", "chest", "stele", "ruins_pillar", "ruins_wall", "well", "barrel", "crate", "fence_bamboo",
	"market_stall", "watchtower", "wind_chime_post", "seal_gate", "campfire", "tent", "steps_stone", "rock_cliff", "memory_stone",
]

var paths: Dictionary = {}
var scenes: Dictionary = {}
var mesh_parts: Dictionary = {}
var failure: String = ""
var headless: bool = DisplayServer.get_name() == "headless"

func _init() -> void:
	for kind: String in FLORA:
		paths[FLORA[kind]] = "res://assets/models/%s.glb" % FLORA[kind]
	for name: String in CHARACTERS:
		paths["characters/" + name] = "res://assets/models/characters/%s.glb" % name
	for name: String in WEAPONS:
		paths["weapons/" + name] = "res://assets/models/weapons/%s.glb" % name
	for name: String in PROPS:
		paths["env/" + name] = "res://assets/models/env/%s.glb" % name

func request_all() -> void:
	# Avoid the headless RID failures observed with threaded GLB loading on 4.7.2.
	if headless:
		return
	for key: String in paths:
		var error: Error = ResourceLoader.load_threaded_request(paths[key], "PackedScene")
		if error != OK:
			failure = "Không thể yêu cầu model: " + paths[key]

func progress() -> float:
	return float(scenes.size()) / maxf(1.0, float(paths.size()))

func poll() -> bool:
	if not failure.is_empty():
		return false
	for key: String in paths:
		if scenes.has(key):
			continue
		var packed: PackedScene
		if headless:
			packed = ResourceLoader.load(paths[key], "PackedScene") as PackedScene
		else:
			var status: int = ResourceLoader.load_threaded_get_status(paths[key])
			if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				failure = "Không thể nhập model: " + paths[key]
				return false
			if status != ResourceLoader.THREAD_LOAD_LOADED:
				return false
			packed = ResourceLoader.load_threaded_get(paths[key]) as PackedScene
		if packed == null:
			failure = "Model không phải scene: " + paths[key]
			return false
		scenes[key] = packed
		var root: Node3D = packed.instantiate() as Node3D
		Toon.apply_to_scene(root, key.begins_with("characters/") or key.begins_with("weapons/"), Toon.is_foliage(key))
		for kind: String in FLORA:
			if FLORA[kind] == key:
				var parts: Array[Dictionary] = []
				_collect_meshes(root, Transform3D.IDENTITY, parts)
				if parts.is_empty():
					failure = "Model không có mesh: " + paths[key]
				mesh_parts[kind] = parts
		root.free()
		if not failure.is_empty():
			return false
		if not headless:
			return false
	return scenes.size() == paths.size()

func instantiate(key: String) -> Node3D:
	var packed: PackedScene = scenes.get(key)
	if packed == null:
		push_error("Missing asset " + key)
		return Node3D.new()
	return packed.instantiate() as Node3D

func _collect_meshes(node: Node, parent_transform: Transform3D, parts: Array[Dictionary]) -> void:
	var local_transform: Transform3D = parent_transform
	if node is Node3D:
		local_transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance.mesh != null:
			parts.append({"mesh": instance.mesh, "transform": local_transform})
	for child: Node in node.get_children():
		_collect_meshes(child, local_transform, parts)
