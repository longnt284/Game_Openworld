class_name PropPlacer
extends Node3D
## Places the hand-authored static props (houses, bridge, dock, ruins…) from
## data/world/props.json onto the terrain. Colliders come from the GLB import
## (*-convcolonly); `surface` drives footstep sounds. Props that carry a flame (lanterns, the
## smithy's forge, the campfire: props.json "lights") also list where their light sits, for
## NightLights.

const DRAW_DISTANCE: Dictionary = {
	"house_small": 220.0, "house_long": 220.0, "house_teal": 220.0, "smithy": 200.0, "gate_village": 220.0, "watchtower": 260.0,
	"seal_gate": 300.0, "bridge_wood": 200.0, "dock": 200.0, "rock_cliff": 220.0, "ruins_wall": 140.0, "ruins_pillar": 160.0,
	"gate_tam_quan": 320.0, "pagoda_bell_tower": 360.0, "prayer_banner": 140.0, "lantern_string": 110.0, "flower_pot": 60.0, "basket_produce": 50.0,
}

var placed: Array[Node3D] = []
## Every flame of the placed props: {"position" (world), "color", "energy", "range"}.
var lights: Array[Dictionary] = []

func build(assets: AssetLibrary, layout: WorldLayout) -> void:
	var lamps: Dictionary = ContentDB.get_data("props").get("lights", {})
	var lamp_defaults: Dictionary = lamps.get("default", {})
	for entry: Dictionary in ContentDB.get_data("props").get("props", []):
		var node: Node3D = assets.instantiate("env/" + String(entry["model"]))
		node.name = "%s_%d" % [entry["model"], placed.size()]
		add_child(node)
		var x: float = float(entry["pos"][0])
		var z: float = float(entry["pos"][1])
		var y: float = layout.height_at(x, z)
		if entry.has("y_abs"):
			y = float(entry["y_abs"])
		elif entry.has("y_span"):
			var total: float = 0.0
			for point: Array in entry["y_span"]:
				total += layout.height_at(float(point[0]), float(point[1]))
			y = total / (entry["y_span"] as Array).size()
		else:
			y = minf(y, _footprint_low(layout, x, z, 1.2))
		node.position = Vector3(x, y + float(entry.get("y", 0.0)), z)
		node.rotation.y = deg_to_rad(float(entry.get("yaw", 0.0)))
		node.scale = Vector3.ONE * float(entry.get("scale", 1.0))
		var range_end: float = DRAW_DISTANCE.get(entry["model"], 90.0)
		for mesh: Node in node.find_children("*", "GeometryInstance3D", true, false):
			(mesh as GeometryInstance3D).visibility_range_end = range_end
			(mesh as GeometryInstance3D).visibility_range_end_margin = 8.0
		var surface: String = String(entry.get("surface", "wood" if String(entry["model"]) in ["table", "bench", "crate", "barrel", "fence_bamboo"] else "stone"))
		for body: Node in node.find_children("*", "StaticBody3D", true, false):
			body.set_meta("surface", surface)
			(body as StaticBody3D).collision_layer = Combat.LAYER_WORLD
		placed.append(node)
		var lamp: Dictionary = (lamps.get("models", {}) as Dictionary).get(entry["model"], {})
		for point: Array in lamp.get("points", []):
			lights.append({"position": node.transform * Vector3(float(point[0]), float(point[1]), float(point[2])),
				"color": Color(String(lamp.get("color", lamp_defaults.get("color", "ffb25a")))),
				"energy": float(lamp.get("energy", lamp_defaults.get("energy", 1.6))), "range": float(lamp.get("range", lamp_defaults.get("range", 7.0)))})

func _footprint_low(layout: WorldLayout, x: float, z: float, radius: float) -> float:
	## Sink props to the lowest nearby ground so they never float on slopes.
	var low: float = layout.height_at(x, z)
	for offset: Vector2 in [Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
		low = minf(low, layout.height_at(x + offset.x, z + offset.y))
	return low
