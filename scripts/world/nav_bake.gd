class_name NavBake
extends RefCounted
## Encounter navmeshes ("navzone" entities). Baking one parses every collider around the zone and
## runs Recast: a few hundred ms that single-threaded web builds spend in one frame. So the
## default valley's zones ship prebaked in assets/nav/ (tools/bake_navzones.gd writes them), and a
## zone only bakes live for another seed or when the world data no longer matches the bake.

const DIR: String = "res://assets/nav/"
const MANIFEST: String = DIR + "manifest.json"
## Bump when the bake settings below change, so old files are never mistaken for current ones.
const FORMAT: int = 1
## The files whose content shapes the walkable ground: terrain, props and flora colliders.
const SOURCES: PackedStringArray = ["res://data/world/layout.json", "res://data/world/props.json", "res://data/world/flora.json"]

static var _fingerprint: String = ""
static var _manifest: Dictionary = {}

static func make_mesh(data: Dictionary, ground: float) -> NavigationMesh:
	## The bake settings for one zone; `ground` is the terrain height at its centre.
	var size: float = float(data.get("size", 40.0))
	var center: Vector2 = Vector2(float(data["pos"][0]), float(data["pos"][1]))
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.agent_radius = 0.5
	mesh.agent_height = 2.0
	mesh.agent_max_climb = 0.5
	mesh.agent_max_slope = 42.0
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = Combat.LAYER_WORLD
	# Only terrain and props are walked, not characters, UI or the arena wind wall.
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = EntitySpawner.NAV_SOURCE
	mesh.filter_baking_aabb = AABB(Vector3(center.x - size * 0.5, ground - 20.0, center.y - size * 0.5), Vector3(size, 60.0, size))
	return mesh

static func fingerprint() -> String:
	## Format, the source files and the zones themselves: editing any of them retires the bake.
	if _fingerprint == "":
		var context: HashingContext = HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(("nav%d" % FORMAT).to_utf8_buffer())
		for source: String in SOURCES:
			# Line endings may differ per checkout (Windows), the content may not.
			context.update(FileAccess.get_file_as_string(source).replace("\r", "").to_utf8_buffer())
		for zone: Dictionary in zones():
			context.update(JSON.stringify(zone, "", true).to_utf8_buffer())
		_fingerprint = context.finish().hex_encode()
	return _fingerprint

static func zones() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entity: Dictionary in ContentDB.get_data("entities").get("entities", []):
		if String(entity.get("type", "")) == "navzone":
			found.append(entity)
	return found

static func path(id: String) -> String:
	return DIR + id + ".res"

static func prebaked(id: String, world_seed: int) -> NavigationMesh:
	## The shipped navmesh for this zone, or null when there is none for this seed and data.
	if _manifest.is_empty() and FileAccess.file_exists(MANIFEST):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		_manifest = parsed if parsed is Dictionary else {"invalid": true}
	if int(_manifest.get("seed", -1)) != world_seed or String(_manifest.get("fingerprint", "")) != fingerprint():
		return null
	if not (_manifest.get("zones", []) as Array).has(id) or not ResourceLoader.exists(path(id)):
		return null
	return load(path(id)) as NavigationMesh
