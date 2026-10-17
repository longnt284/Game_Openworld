class_name WorldLayout
extends RefCounted
## Deterministic shape of the finite valley: regional elevation + noise, then
## designed features (flats, roads, rivers, chasms, ridges). Immutable after
## construction so chunk workers can sample it from other threads.

const PATH: String = "res://data/world/layout.json"
const PATH_BLEND: float = 5.0
const BANK: float = 6.0
const EDGE_CAP: float = 70.0
const KEEPOUT_CELL: float = 32.0
## Footprints flora keeps clear of (metres); unlisted props use DEFAULT_PROP_KEEPOUT.
const PROP_KEEPOUT: Dictionary = {
	"house_small": 5.5, "house_teal": 5.5, "house_long": 7.5, "smithy": 6.0, "gate_village": 4.5, "shrine_wind": 3.5, "watchtower": 4.0,
	"bridge_wood": 6.0, "dock": 6.0, "market_stall": 3.0, "tent": 3.0, "well": 2.2, "ruins_wall": 3.5, "seal_gate": 5.0, "rock_cliff": 4.0,
	"boat": 0.0, "gate_tam_quan": 5.0, "pagoda_bell_tower": 4.5, "rice_rack": 2.5, "haystack": 2.0, "lantern_string": 1.0,
	"flower_pot": 0.8, "basket_produce": 0.8, "prayer_banner": 1.0,
}
const DEFAULT_PROP_KEEPOUT: float = 1.6
const ENTITY_KEEPOUT: Dictionary = {"npc": 2.5, "shrine": 3.0, "chest": 2.5, "echo": 2.5, "diary": 2.5, "chime": 2.5, "memory_core": 3.0, "seal_gate": 4.0, "enemy": 1.5}

var source: Dictionary = {}
var noise: FastNoiseLite = FastNoiseLite.new()
var detail: FastNoiseLite = FastNoiseLite.new()
var bounds: Rect2
var elevation: Array = []
var amplitude: Array = []
var edge: Dictionary = {}
var regions: Array = []
var flats: Array = []
var paths: Array = []
var waters: Array = []
var chasms: Array = []
var ridges: Array = []
var biomes: Dictionary = {}
var clearings: Array = []
## Flora rules from data/world/flora.json; kind order seeds each kind's own RNG.
var flora: Dictionary = {}
var flora_kinds: Array = []
var cluster: FastNoiseLite = FastNoiseLite.new()
## KEEPOUT_CELL grid cell -> [[centre, radius, colliders_only], ...]
var keepouts: Dictionary = {}

static func load_default(world_seed: int) -> WorldLayout:
	## Main thread only: reads ContentDB, which is not thread-safe. The result is then immutable.
	var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
	var layout: WorldLayout = WorldLayout.new(parsed if parsed is Dictionary else {}, world_seed)
	layout.load_flora(ContentDB.get_data("flora"), ContentDB.get_data("entities"), ContentDB.get_data("props"))
	return layout

func load_flora(rules: Dictionary, entities: Dictionary, props: Dictionary) -> void:
	flora = rules.get("kinds", {})
	flora_kinds = flora.keys()
	for entity: Dictionary in entities.get("entities", []):
		var radius: float = float(ENTITY_KEEPOUT.get(String(entity.get("type", "")), 0.0))
		if radius <= 0.0:
			continue
		var spots: Array = [entity["pos"]] if entity.has("pos") else (entity.get("positions", []) as Array).map(func(rule: Dictionary) -> Array: return rule["pos"])
		for spot: Array in spots:
			_add_keepout(Vector2(float(spot[0]), float(spot[1])), radius, entity["type"] == "enemy")
	for prop: Dictionary in props.get("props", []):
		var radius: float = float(PROP_KEEPOUT.get(String(prop["model"]), DEFAULT_PROP_KEEPOUT))
		if radius > 0.0:
			_add_keepout(Vector2(float(prop["pos"][0]), float(prop["pos"][1])), radius, false)

func _add_keepout(center: Vector2, radius: float, colliders_only: bool) -> void:
	var low: Vector2i = Vector2i(floori((center.x - radius) / KEEPOUT_CELL), floori((center.y - radius) / KEEPOUT_CELL))
	var high: Vector2i = Vector2i(floori((center.x + radius) / KEEPOUT_CELL), floori((center.y + radius) / KEEPOUT_CELL))
	for cz: int in range(low.y, high.y + 1):
		for cx: int in range(low.x, high.x + 1):
			var cell: Vector2i = Vector2i(cx, cz)
			if not keepouts.has(cell):
				keepouts[cell] = []
			keepouts[cell].append([center, radius, colliders_only])

func _init(data: Dictionary, world_seed: int) -> void:
	source = data
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail.seed = world_seed + 17
	detail.frequency = 0.09
	# Groves and flower drifts: flora kinds sample this at offsets so they cluster apart.
	cluster.seed = world_seed + 31
	cluster.frequency = 0.035
	var b: Dictionary = data.get("bounds", {"min_x": -132, "max_x": 132, "min_z": -462, "max_z": 100})
	bounds = Rect2(float(b["min_x"]), float(b["min_z"]), float(b["max_x"]) - float(b["min_x"]), float(b["max_z"]) - float(b["min_z"]))
	elevation = data.get("elevation", [[0, 0.0]])
	amplitude = data.get("noise_amplitude", [[0, 2.0]])
	edge = data.get("edge_rise", {})
	regions = data.get("regions", [])
	ridges = data.get("ridges", [])
	chasms = data.get("chasms", [])
	clearings = data.get("clearings", [])
	for biome: Dictionary in data.get("biomes", []):
		biomes[biome["region"]] = biome
	for flat: Dictionary in data.get("flats", []):
		var entry: Dictionary = flat.duplicate()
		if not entry.has("h"):
			entry["h"] = _shaped_base(float(flat["x"]), float(flat["z"]))
		flats.append(entry)
	for path: Dictionary in data.get("paths", []):
		paths.append(_prepare_line(path, func(x: float, z: float) -> float: return _with_flats(x, z, _shaped_base(x, z)), float(path["width"]) * 0.5 + PATH_BLEND))
	for water: Dictionary in data.get("waters", []):
		var entry: Dictionary = _prepare_line(water, func(x: float, z: float) -> float: return _with_paths(x, z, _with_flats(x, z, _shaped_base(x, z))), float(water["width"]) * 0.5 + BANK)
		if water.get("kind", "") == "stream":
			var levels: PackedFloat32Array = PackedFloat32Array()
			for value: float in entry["heights"]:
				levels.append(value - float(water["depth"]) + float(water.get("level_offset", 0.6)))
			entry["levels"] = levels
		waters.append(entry)

func _prepare_line(line: Dictionary, height_fn: Callable, reach: float) -> Dictionary:
	var points: PackedVector2Array = PackedVector2Array()
	var heights: PackedFloat32Array = PackedFloat32Array()
	var box: Rect2 = Rect2()
	for index: int in range(line["points"].size()):
		var raw: Array = line["points"][index]
		var point: Vector2 = Vector2(float(raw[0]), float(raw[1]))
		points.append(point)
		heights.append(height_fn.call(point.x, point.y))
		box = Rect2(point, Vector2.ZERO) if index == 0 else box.expand(point)
	var entry: Dictionary = line.duplicate()
	entry["pts"] = points
	entry["heights"] = heights
	entry["box"] = box.grow(reach)
	return entry

# ------------------------------------------------------------------ height

func _curve(table: Array, z: float) -> float:
	if table.is_empty():
		return 0.0
	if z >= float(table[0][0]):
		return float(table[0][1])
	for index: int in range(1, table.size()):
		var upper: Array = table[index - 1]
		var lower: Array = table[index]
		if z >= float(lower[0]):
			var t: float = (float(upper[0]) - z) / (float(upper[0]) - float(lower[0]))
			return lerpf(float(upper[1]), float(lower[1]), smoothstep(0.0, 1.0, t))
	return float(table[-1][1])

func _shaped_base(x: float, z: float) -> float:
	var h: float = _curve(elevation, z) + noise.get_noise_2d(x, z) * _curve(amplitude, z)
	if not edge.is_empty():
		var rise: float = 0.0
		var over_x: float = absf(x) - float(edge["start_x"])
		if over_x > 0.0:
			rise += pow(over_x, float(edge["power"])) * float(edge["scale"])
		var over_north: float = float(edge["north_z"]) - z
		if over_north > 0.0:
			rise += pow(over_north, float(edge["power"])) * float(edge["scale"]) * 1.5
		var over_south: float = z - float(edge["south_z"])
		if over_south > 0.0:
			rise += pow(over_south, float(edge["power"])) * float(edge["scale"]) * 2.0
		# Saturate so the rim reads as mountains without turning into vertical walls.
		h += EDGE_CAP * tanh(rise / EDGE_CAP)
	for ridge: Dictionary in ridges:
		h += float(ridge["height"]) * _box_weight(x, z, ridge, float(ridge["edge"]))
	return h

func _box_weight(x: float, z: float, box: Dictionary, soft: float) -> float:
	var dx: float = maxf(float(box["min_x"]) - x, x - float(box["max_x"]))
	var dz: float = maxf(float(box["min_z"]) - z, z - float(box["max_z"]))
	var outside: float = maxf(dx, dz)
	if outside >= soft:
		return 0.0
	if outside <= 0.0:
		return 1.0
	return 1.0 - smoothstep(0.0, soft, outside)

func _with_flats(x: float, z: float, h: float) -> float:
	for flat: Dictionary in flats:
		var distance: float = Vector2(x - float(flat["x"]), z - float(flat["z"])).length()
		var reach: float = float(flat["r"]) + float(flat["blend"])
		if distance < reach:
			h = lerpf(h, float(flat["h"]), 1.0 - smoothstep(float(flat["r"]), reach, distance))
	return h

func _line_query(line: Dictionary, x: float, z: float) -> Vector3:
	## Returns (distance, segment index, t) to the polyline; distance INF when outside its box.
	if not (line["box"] as Rect2).has_point(Vector2(x, z)):
		return Vector3(INF, -1, 0)
	var best: Vector3 = Vector3(INF, -1, 0)
	var pts: PackedVector2Array = line["pts"]
	var p: Vector2 = Vector2(x, z)
	for index: int in range(pts.size() - 1):
		var a: Vector2 = pts[index]
		var ab: Vector2 = pts[index + 1] - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var distance: float = p.distance_to(a + ab * t)
		if distance < best.x:
			best = Vector3(distance, index, t)
	return best

func _line_value(line: Dictionary, key: String, hit: Vector3) -> float:
	var values: PackedFloat32Array = line[key]
	var index: int = int(hit.y)
	return lerpf(values[index], values[index + 1], hit.z)

func _with_paths(x: float, z: float, h: float) -> float:
	for path: Dictionary in paths:
		var hit: Vector3 = _line_query(path, x, z)
		var half: float = float(path["width"]) * 0.5
		if hit.x < half + PATH_BLEND:
			h = lerpf(h, _line_value(path, "heights", hit), 1.0 - smoothstep(half, half + PATH_BLEND, hit.x))
	return h

func _with_waters(x: float, z: float, h: float) -> float:
	for water: Dictionary in waters:
		var hit: Vector3 = _line_query(water, x, z)
		var half: float = float(water["width"]) * 0.5
		if hit.x >= half + BANK:
			continue
		var level: float = water_level_hit(water, hit)
		var depth: float = float(water["depth"])
		var profile: float
		if hit.x < half:
			var u: float = hit.x / half
			profile = level - 0.3 - (depth - 0.3) * (1.0 - u * u) if water.get("kind", "") == "river" else level - 0.7 - 0.5 * (1.0 - u * u)
		else:
			var bank_top: float = level + 0.35
			profile = lerpf(bank_top, h, smoothstep(0.0, BANK if water.get("kind", "") == "river" else 2.5, hit.x - half))
		h = minf(h, profile)
	return h

func water_level_hit(water: Dictionary, hit: Vector3) -> float:
	if water.has("levels"):
		return _line_value(water, "levels", hit)
	return float(water.get("level", 0.0))

func _with_chasms(x: float, z: float, h: float) -> float:
	for chasm: Dictionary in chasms:
		var weight: float = _box_weight(x, z, chasm, float(chasm["edge"]))
		if weight > 0.0:
			h -= float(chasm["depth"]) * weight
	return h

func height_at(x: float, z: float) -> float:
	var h: float = _shaped_base(x, z)
	h = _with_flats(x, z, h)
	h = _with_paths(x, z, h)
	h = _with_waters(x, z, h)
	return _with_chasms(x, z, h)

# ------------------------------------------------------------------ queries

func region_at(z: float) -> Dictionary:
	for region: Dictionary in regions:
		if z <= float(region["max_z"]) and z > float(region["min_z"]):
			return region
	return regions[0] if not regions.is_empty() else {}

func path_distance(x: float, z: float) -> float:
	var best: float = INF
	for path: Dictionary in paths:
		best = minf(best, _line_query(path, x, z).x - float(path["width"]) * 0.5)
	return best

func water_at(x: float, z: float) -> Dictionary:
	## {level, inside} for the river/stream covering (x, z), or empty.
	for water: Dictionary in waters:
		var hit: Vector3 = _line_query(water, x, z)
		if hit.x < float(water["width"]) * 0.5 + 0.5:
			return {"id": water["id"], "level": water_level_hit(water, hit), "kind": water.get("kind", "")}
	return {}

func in_chasm(x: float, z: float) -> bool:
	for chasm: Dictionary in chasms:
		if _box_weight(x, z, chasm, 0.01) > 0.5:
			return true
	return false

func flat_at(x: float, z: float) -> Dictionary:
	for flat: Dictionary in flats:
		if Vector2(x - float(flat["x"]), z - float(flat["z"])).length() < float(flat["r"]):
			return flat
	return {}

func inside_bounds(x: float, z: float) -> bool:
	return bounds.has_point(Vector2(x, z))

func is_clear(x: float, z: float, margin: float = 1.5) -> bool:
	if not bounds.grow(-2.0).has_point(Vector2(x, z)):
		return false
	if path_distance(x, z) < margin + 0.8:
		return false
	for flat: Dictionary in flats:
		if Vector2(x - float(flat["x"]), z - float(flat["z"])).length() < float(flat["r"]) + margin:
			return false
	for clearing: Dictionary in clearings:
		if Vector2(x - float(clearing["x"]), z - float(clearing["z"])).length() < float(clearing["r"]):
			return false
	for water: Dictionary in waters:
		if _line_query(water, x, z).x < float(water["width"]) * 0.5 + margin + 1.5:
			return false
	for chasm: Dictionary in chasms:
		if _box_weight(x, z, chasm, float(chasm["edge"]) + margin + 2.0) > 0.0:
			return false
	return true

func biome_density(z: float) -> Dictionary:
	return (biomes.get(region_at(z).get("id", ""), {}) as Dictionary).get("density", {})

func cluster_gate(x: float, z: float, kind_index: int, band: Array) -> float:
	## 0..2, averaging about 1: multiplies a kind's spawn chance so it gathers in drifts.
	var value: float = cluster.get_noise_2d(x + kind_index * 97.0, z - kind_index * 61.0) * 0.5 + 0.5
	return smoothstep(float(band[0]), float(band[1]), value) * 2.0

func flora_clear(x: float, z: float, rule: Dictionary) -> bool:
	## Like is_clear, per flora rule: soft kinds (grass, flowers) also grow on earthen flats and
	## in clearings; near_water kinds only grow on the banks; everything avoids keep-outs.
	var margin: float = float(rule.get("margin", 1.0))
	var soft: bool = rule.get("soft", false)
	if not bounds.grow(-2.0).has_point(Vector2(x, z)):
		return false
	if path_distance(x, z) < margin + (0.4 if soft else 0.8):
		return false
	for flat: Dictionary in flats:
		if soft and flat.get("surface", "") != "stone":
			continue
		if Vector2(x - float(flat["x"]), z - float(flat["z"])).length() < float(flat["r"]) + margin:
			return false
	if not soft:
		for clearing: Dictionary in clearings:
			if Vector2(x - float(clearing["x"]), z - float(clearing["z"])).length() < float(clearing["r"]):
				return false
	var near: Array = rule.get("near_water", [])
	var banked: bool = near.is_empty()
	for water: Dictionary in waters:
		var edge: float = _line_query(water, x, z).x - float(water["width"]) * 0.5
		if near.is_empty():
			if edge < margin + 1.5:
				return false
		elif edge >= float(near[0]) and edge <= float(near[1]):
			banked = true
	if not banked:
		return false
	for chasm: Dictionary in chasms:
		if _box_weight(x, z, chasm, float(chasm["edge"]) + margin + 2.0) > 0.0:
			return false
	var collider: bool = rule.has("collider") or rule.has("rock_collider")
	for keepout: Array in keepouts.get(Vector2i(floori(x / KEEPOUT_CELL), floori(z / KEEPOUT_CELL)), []):
		if keepout[2] and not collider:
			continue
		if Vector2(x, z).distance_to(keepout[0]) < float(keepout[1]) + margin * 0.5:
			return false
	return true

func surface_at(x: float, z: float) -> String:
	if not water_at(x, z).is_empty():
		return "water"
	if path_distance(x, z) < 0.6:
		return "dirt"
	var flat: Dictionary = flat_at(x, z)
	if flat.has("surface"):
		return flat["surface"]
	var region: String = region_at(z).get("id", "")
	if region == "truc_hai":
		return "leaves"
	if region == "den_tich_phong":
		return "stone"
	return "grass"

func ground_color(x: float, z: float, h: float, slope: float) -> Color:
	var region: Dictionary = region_at(z)
	var palette: Array = region.get("grass", ["7d9c58", "b8bf78"])
	var variation: float = detail.get_noise_2d(x, z) * 0.5 + 0.5
	var base: Color = Color(palette[0]).lerp(Color(palette[1]), clampf(variation * 0.8 + (h - _curve(elevation, z)) * 0.04, 0.0, 1.0))
	var path_gap: float = path_distance(x, z)
	if path_gap < 1.2:
		base = base.lerp(Color("c9b38a"), 1.0 - smoothstep(0.0, 1.2, path_gap) * 0.9)
	var flat: Dictionary = flat_at(x, z)
	if flat.get("surface", "") == "stone":
		# Packed sandy earth with tufts of grass surviving at the edges of trodden ground.
		var patch: float = smoothstep(0.55, 0.7, cluster.get_noise_2d(x * 2.0, z * 2.0) * 0.5 + 0.5)
		base = base.lerp(Color("d2b886"), (0.85 - variation * 0.15) * (1.0 - patch * 0.7))
	for water: Dictionary in waters:
		var hit: Vector3 = _line_query(water, x, z)
		var half: float = float(water["width"]) * 0.5
		if hit.x < half + 3.0:
			base = base.lerp(Color("cdbf98") if water.get("kind", "") == "river" else Color("8f9a86"), 1.0 - smoothstep(half - 2.0, half + 3.0, hit.x))
	if slope > 0.55:
		base = base.lerp(Color("8e8a78"), smoothstep(0.55, 0.8, slope))
	if in_chasm(x, z):
		# Darken the gorge walls with depth so the drop reads clearly from the path.
		var depth: float = _curve(elevation, z) - h
		base = base.lerp(Color("2f3b37"), clampf((depth - 1.0) / 16.0, 0.0, 0.85))
	return base
