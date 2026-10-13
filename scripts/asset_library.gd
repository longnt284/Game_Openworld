class_name AssetLibrary
extends RefCounted

const PATHS: Dictionary = {
	"tree": "res://assets/models/tree.glb",
	"rock": "res://assets/models/rock.glb",
	"beacon": "res://assets/models/beacon.glb"
}
var scenes: Dictionary = {}
var mesh_parts: Dictionary = {}
var failure: String = ""
var headless: bool = DisplayServer.get_name() == "headless"

func request_all() -> void:
	# Avoid the headless RID failures observed with threaded GLB loading on 4.7.2.
	if headless:
		return
	for key: String in PATHS:
		var error: Error = ResourceLoader.load_threaded_request(PATHS[key], "PackedScene")
		if error != OK:
			failure = "Không thể yêu cầu model: " + PATHS[key]

func poll() -> bool:
	if not failure.is_empty():
		return false
	for key: String in PATHS:
		if scenes.has(key):
			continue
		var packed: PackedScene
		if headless:
			packed = ResourceLoader.load(PATHS[key], "PackedScene") as PackedScene
		else:
			var status: int = ResourceLoader.load_threaded_get_status(PATHS[key])
			if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				failure = "Không thể nhập model: " + PATHS[key]
				return false
			if status != ResourceLoader.THREAD_LOAD_LOADED:
				return false
			packed = ResourceLoader.load_threaded_get(PATHS[key]) as PackedScene
		if packed == null:
			failure = "Model không phải scene: " + PATHS[key]
			return false
		scenes[key] = packed
		var root: Node3D = packed.instantiate() as Node3D
		var parts: Array[Dictionary] = []
		_collect_meshes(root, Transform3D.IDENTITY, parts)
		root.free()
		if parts.is_empty():
			failure = "Model không có mesh: " + PATHS[key]
			return false
		mesh_parts[key] = parts
	return scenes.size() == PATHS.size()

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
