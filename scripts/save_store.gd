class_name SaveStore
extends RefCounted

const SAVE_PATH: String = "user://world_save.json"
const SCHEMA_VERSION: int = 1

static func validate(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.get("version") != SCHEMA_VERSION or not data.get("seed") is float and not data.get("seed") is int:
		return false
	if not is_finite(float(data["seed"])) or absf(float(data["seed"])) > 2147483647 or float(data["seed"]) != floorf(float(data["seed"])):
		return false
	if not data.get("beacon_active") is bool:
		return false
	for key: String in ["position", "checkpoint"]:
		var coordinates: Variant = data.get(key)
		if not coordinates is Array or coordinates.size() != 3:
			return false
		for value: Variant in coordinates:
			if not (value is float or value is int) or not is_finite(float(value)) or absf(float(value)) > 100000.0:
				return false
	return true

static func write_save(data: Dictionary, path: String = SAVE_PATH) -> Error:
	if not validate(data):
		return ERR_INVALID_DATA
	var temporary: String = path + ".tmp"
	var backup: String = path + ".bak"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
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
	for candidate: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var file: FileAccess = FileAccess.open(candidate, FileAccess.READ)
		if file == null or file.get_length() > 16384:
			continue
		var parser: JSON = JSON.new()
		if parser.parse(file.get_as_text()) == OK and validate(parser.data):
			return parser.data as Dictionary
	return {}

static func to_array(point: Vector3) -> Array[float]:
	return [point.x, point.y, point.z]

static func to_vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
