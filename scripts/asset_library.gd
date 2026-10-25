class_name AssetLibrary
extends RefCounted
## Loads every runtime GLB once (threaded when rendering, synchronous in headless),
## converts materials to the toon look and exposes mesh parts for MultiMesh flora.

const CHARACTERS: PackedStringArray = ["lam_an", "tieu_mac", "ba_luc", "chu_bay", "ba_hanh", "tich_phong", "tan_binh", "truc_tuong", "heo_gio",
	"cung_thu", "ho_ve", "phap_su", "hon_anh", "khoi_loi", "soi_suong", "soi_chua"]
const WEAPONS: PackedStringArray = ["sword_old", "sword_bamboo", "sword_wind", "sabre", "glaive", "sword_water", "sword_thunder", "sword_flame", "sword_frost",
	"spear", "staff"]
const PROPS: PackedStringArray = [
	"house_small", "house_long", "house_teal", "smithy", "gate_village", "shrine_wind", "bridge_wood", "dock", "boat", "lantern_stone",
	"lantern_post", "signboard", "table", "bench", "chest", "stele", "ruins_pillar", "ruins_wall", "well", "barrel", "crate", "fence_bamboo",
	"market_stall", "watchtower", "wind_chime_post", "seal_gate", "campfire", "tent", "steps_stone", "rock_cliff", "memory_stone",
	"karst_peak", "gate_tam_quan", "pagoda_bell_tower", "incense_burner", "stone_nghe", "prayer_banner", "rice_rack", "haystack",
	"lantern_string", "flower_pot", "basket_produce",
]

## flora kind -> model key, from data/world/flora.json
var flora: Dictionary = {}
var paths: Dictionary = {}
var scenes: Dictionary = {}
var mesh_parts: Dictionary = {}
## far group -> Mesh drawn for trees past the tree distance (data/world/flora.json "far")
var far_meshes: Dictionary = {}
var failure: String = ""
var headless: bool = DisplayServer.get_name() == "headless"
## Single-threaded web builds would load every request inline in one frame, so load one per frame.
var sync_load: bool = headless or OS.has_feature("nothreads")

func _init() -> void:
	var rules: Dictionary = ContentDB.get_data("flora")
	for kind: String in rules.get("kinds", {}):
		flora[kind] = String(rules["kinds"][kind]["model"])
		paths[flora[kind]] = "res://assets/models/%s.glb" % flora[kind]
	for group: String in rules.get("far", {}):
		var model: String = String(rules["far"][group])
		if model.begins_with("env/"):
			paths[model] = "res://assets/models/%s.glb" % model
	for name: String in CHARACTERS:
		paths["characters/" + name] = "res://assets/models/characters/%s.glb" % name
	for name: String in WEAPONS:
		paths["weapons/" + name] = "res://assets/models/weapons/%s.glb" % name
	for name: String in PROPS:
		paths["env/" + name] = "res://assets/models/env/%s.glb" % name

func request_all() -> void:
	# Avoid the headless RID failures observed with threaded GLB loading on 4.7.2.
	if sync_load:
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
		if sync_load:
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
		Toon.apply_to_scene(root, key.begins_with("characters/") or key.begins_with("weapons/"), Toon.is_foliage(key), Toon.is_ground_cover(key))
		for kind: String in flora:
			if flora[kind] == key:
				var parts: Array[Dictionary] = []
				_collect_meshes(root, Transform3D.IDENTITY, parts)
				if parts.is_empty():
					failure = "Model không có mesh: " + paths[key]
				mesh_parts[kind] = parts
		for group: String in ContentDB.get_data("flora").get("far", {}):
			if String(ContentDB.get_data("flora")["far"][group]) == key:
				var far_parts: Array[Dictionary] = []
				_collect_meshes(root, Transform3D.IDENTITY, far_parts)
				far_meshes[group] = far_parts[0]["mesh"]
		root.free()
		if not failure.is_empty():
			return false
		if not headless:
			return false
	if scenes.size() == paths.size() and not far_meshes.has("cone"):
		build_far_meshes()
	return scenes.size() == paths.size()

func part_transforms() -> Dictionary:
	## kind -> [Transform3D per mesh part]; read by chunk workers, so it is a detached copy.
	var result: Dictionary = {}
	for kind: String in mesh_parts:
		var transforms: Array = []
		for part: Dictionary in mesh_parts[kind]:
			transforms.append(part["transform"])
		result[kind] = transforms
	return result

func build_far_meshes() -> void:
	## Code-built stand-ins for distant trees, tinted per instance with the kind's crown colour.
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.6
	cone.height = 4.4
	cone.radial_segments = 6
	cone.rings = 1
	cone.material = Toon.make(Color.WHITE, {"use_vertex_color": true, "rim_strength": 0.0})
	far_meshes["cone"] = cone
	var crown: SphereMesh = SphereMesh.new()
	crown.radius = 2.0
	crown.height = 3.4
	crown.radial_segments = 7
	crown.rings = 4
	crown.material = cone.material
	far_meshes["round"] = crown

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
