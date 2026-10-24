class_name SaveStore
extends RefCounted
## Versioned JSON saves: atomic write through .tmp, previous save kept as .bak,
## corrupt files fall back to the backup, older schemas are migrated on read one step
## at a time (v1 -> v2 -> v3 -> v4). v4 added the world clock and weather.

const SAVE_PATH: String = "user://world_save.json"
const SCHEMA_VERSION: int = 4
const MAX_BYTES: int = 1048576

static func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _valid_vector(value: Variant) -> bool:
	if not value is Array or (value as Array).size() != 3:
		return false
	for item: Variant in value:
		if not _is_number(item) or absf(float(item)) > 100000.0:
			return false
	return true

static func _valid_seed(value: Variant) -> bool:
	return _is_number(value) and absf(float(value)) <= 2147483647 and float(value) == floorf(float(value))

static func validate(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.get("version") != SCHEMA_VERSION and data.get("version") != float(SCHEMA_VERSION):
		return false
	if not _valid_seed(data.get("seed")):
		return false
	for key: String in ["position", "checkpoint"]:
		if not _valid_vector(data.get(key)):
			return false
	var state: Variant = data.get("state")
	if not state is Dictionary:
		return false
	for key: String in ["flags", "inventory", "quests", "skills"]:
		if not state.get(key, {}) is Dictionary:
			return false
	for key: String in ["level", "xp", "coins", "world_tier", "max_tier"]:
		if not _is_number(state.get(key, 0)) or float(state.get(key, 0)) < 0:
			return false
	for key: String in ["checkpoints", "discovered", "swords"]:
		if not state.get(key, []) is Array:
			return false
	if not state.get("sword", "") is String or not _is_number(state.get("equipped_uid", -1)):
		return false
	# Optional since v3 (added with the quick-use slot): absent means an empty slot.
	if not state.get("quick_item", "") is String:
		return false
	# Optional in v4 (the secondary sword): absent means none.
	if not state.get("sword_alt", "") is String or not _is_number(state.get("alt_uid", -1)):
		return false
	return _valid_clock(data)

static func _valid_clock(data: Dictionary) -> bool:
	## v4: the time of day (fraction of a day), the day count from 1, and the valley's weather
	## with the seconds it has left and its RNG (64-bit seed and state kept as text).
	var time: Variant = data.get("time_of_day")
	if not _is_number(time) or float(time) < 0.0 or float(time) > 1.0:
		return false
	if not _valid_seed(data.get("day")) or float(data["day"]) < 1.0:
		return false
	var weather: Variant = data.get("weather")
	if not weather is Dictionary or not weather.get("id") is String:
		return false
	if not _is_number(weather.get("remaining")) or float(weather["remaining"]) < 0.0:
		return false
	for key: String in ["seed", "state"]:
		if not weather.get(key) is String or not String(weather[key]).is_valid_int():
			return false
	return true

static func migrate(data: Variant) -> Dictionary:
	## Upgrades older schemas in place, one version at a time; returns {} when the data cannot
	## be trusted. Each step only adds what its version introduced.
	if not data is Dictionary:
		return {}
	var version: Variant = data.get("version")
	if version == 1 or version == 1.0:
		data = _v1_to_v2(data)
		if data.is_empty():
			return {}
		version = 2
	if version == 2 or version == 2.0:
		if not _v2_to_v3(data):
			return {}
		version = 3
	if version == 3 or version == 3.0:
		_v3_to_v4(data)
	return data if validate(data) else {}

static func _v1_to_v2(data: Dictionary) -> Dictionary:
	## The base project's save: only a lit beacon and a position survive into a fresh state.
	if not _valid_seed(data.get("seed")) or not data.get("beacon_active") is bool:
		return {}
	if not _valid_vector(data.get("position")) or not _valid_vector(data.get("checkpoint")):
		return {}
	var state: Dictionary = GameState.new().to_dict()
	state["flags"] = {"migrated_from_v1": true}
	if data["beacon_active"]:
		state["checkpoints"] = ["shrine_village"]
		state["checkpoint_id"] = "shrine_village"
	return {"version": 2, "seed": data["seed"], "position": data["position"], "checkpoint": data["checkpoint"],
		"yaw": 0.0, "state": state, "label": "Bản nền cũ", "saved_at": 0}

static func _v2_to_v3(data: Dictionary) -> bool:
	## v3 adds the owned-sword list, the equipped armory weapon and the world tier.
	if not data.get("state") is Dictionary:
		return false
	var state: Dictionary = data["state"]
	var sword: String = String(state.get("sword", "sword_old"))
	var owned: Array = ["sword_old"]
	for story: String in ["sword_bamboo", "sword_wind"]:
		if sword == story or (story == "sword_bamboo" and sword == "sword_wind"):
			owned.append(story)
	state["swords"] = owned
	state["equipped_uid"] = -1
	state["world_tier"] = 0
	state["max_tier"] = 0
	data["version"] = 3
	return true

static func _v3_to_v4(data: Dictionary) -> void:
	## v4 adds the world clock and weather: an older journey wakes on a clear morning of day 1,
	## its weather RNG seeded from the world seed.
	var world_seed: int = int(data.get("seed", 0)) if _valid_seed(data.get("seed")) else 0
	data.merge(WeatherDirector.initial_save(world_seed), true)
	data["version"] = 4

static func write_save(data: Dictionary, path: String = SAVE_PATH) -> Error:
	if not validate(data):
		return ERR_INVALID_DATA
	return atomic_write(path, JSON.stringify(data, "\t"))

static func atomic_write(path: String, text: String) -> Error:
	## Writes through path.tmp and keeps the previous file as path.bak (shared with ProfileStore).
	var temporary: String = path + ".tmp"
	var backup: String = path + ".bak"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		return error
	if FileAccess.file_exists(backup):
		error = DirAccess.remove_absolute(backup)
		if error != OK:
			return error
	if FileAccess.file_exists(path):
		error = DirAccess.rename_absolute(path, backup)
		if error != OK:
			return error
	error = DirAccess.rename_absolute(temporary, path)
	if error != OK and FileAccess.file_exists(backup):
		DirAccess.rename_absolute(backup, path)
	return error

static func read_save(path: String = SAVE_PATH) -> Dictionary:
	return read_json(path, migrate)

static func read_json(path: String, accept: Callable) -> Dictionary:
	## First of path / path.bak that parses and that accept() turns into a non-empty Dictionary.
	for candidate: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var file: FileAccess = FileAccess.open(candidate, FileAccess.READ)
		if file == null or file.get_length() > MAX_BYTES:
			continue
		var parser: JSON = JSON.new()
		if parser.parse(file.get_as_text()) == OK:
			var accepted: Dictionary = accept.call(parser.data)
			if not accepted.is_empty():
				return accepted
	return {}

static func has_save(path: String = SAVE_PATH) -> bool:
	return not read_save(path).is_empty()

static func to_array(point: Vector3) -> Array[float]:
	return [point.x, point.y, point.z]

static func to_vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
