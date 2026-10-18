class_name UserSettings
extends RefCounted
## Player preferences (controls, audio, camera, quality) stored outside saves in user://settings.cfg.

const PATH: String = "user://settings.cfg"
const REBINDABLE: PackedStringArray = [
	"move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "attack", "block", "skill_1", "skill_2", "skill_ult",
	"interact", "heal", "lock_on", "open_map", "open_journal", "open_inventory",
]
const ACTION_NAMES: Dictionary = {
	"move_forward": "Đi tới", "move_back": "Lùi", "move_left": "Sang trái", "move_right": "Sang phải", "jump": "Nhảy / Khinh công",
	"sprint": "Né / Chạy nhanh", "attack": "Đánh (giữ: trọng kích)", "block": "Đỡ / Phản đòn", "skill_1": "Chiêu thức 1", "skill_2": "Chiêu thức 2",
	"skill_ult": "Tuyệt kỹ (đủ nộ khí)",
	"interact": "Tương tác", "heal": "Dùng thuốc", "lock_on": "Khóa mục tiêu", "open_map": "Bản đồ", "open_journal": "Nhật ký",
	"open_inventory": "Túi đồ",
}
## Distances in metres. density thins grass, flowers and ground cover only (trees never move);
## view_radius is the streamed area in chunks around the player; ambient is the particle budget.
const QUALITY: Dictionary = {
	"low": {"shadow": 0.0, "shadow_atlas": 2048, "msaa": Viewport.MSAA_DISABLED, "scale": 0.85, "view_radius": 2, "tree_distance": 60.0, "bamboo": 48.0,
		"grass": 28.0, "clutter": 24.0, "rock": 70.0, "density": 0.5, "glow": false, "ambient": 0.0, "label": "Thấp"},
	"medium": {"shadow": 70.0, "shadow_atlas": 2048, "msaa": Viewport.MSAA_2X, "scale": 1.0, "view_radius": 2, "tree_distance": 82.0, "bamboo": 64.0,
		"grass": 44.0, "clutter": 36.0, "rock": 90.0, "density": 1.0, "glow": true, "ambient": 0.5, "label": "Trung bình"},
	"high": {"shadow": 120.0, "shadow_atlas": 4096, "msaa": Viewport.MSAA_4X, "scale": 1.0, "view_radius": 3, "tree_distance": 120.0, "bamboo": 90.0,
		"grass": 62.0, "clutter": 50.0, "rock": 120.0, "density": 1.4, "glow": true, "ambient": 1.0, "label": "Cao"},
}

var mouse_sensitivity: float = 0.0025
var invert_y: bool = false
var music_volume: float = 0.8
var sfx_volume: float = 0.9
var ambience_volume: float = 0.8
var camera_shake: float = 1.0
var quality: String = "medium"
var debug_hud: bool = false
var fullscreen: bool = false
var damage_numbers: bool = true
var bindings: Dictionary = {}

func load_file(path: String = PATH) -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		if OS.has_feature("web"):
			# First visit in a browser: software or integrated GPUs are common there.
			quality = "low"
		return
	mouse_sensitivity = clampf(float(config.get_value("controls", "mouse_sensitivity", mouse_sensitivity)), 0.0005, 0.01)
	invert_y = bool(config.get_value("controls", "invert_y", invert_y))
	music_volume = clampf(float(config.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	ambience_volume = clampf(float(config.get_value("audio", "ambience", ambience_volume)), 0.0, 1.0)
	camera_shake = clampf(float(config.get_value("camera", "shake", camera_shake)), 0.0, 1.0)
	var stored_quality: String = String(config.get_value("video", "quality", quality))
	quality = stored_quality if QUALITY.has(stored_quality) else "medium"
	fullscreen = bool(config.get_value("video", "fullscreen", fullscreen))
	debug_hud = bool(config.get_value("video", "debug_hud", debug_hud))
	damage_numbers = bool(config.get_value("video", "damage_numbers", damage_numbers))
	var stored: Variant = config.get_value("controls", "bindings", {})
	bindings = stored if stored is Dictionary else {}

func save_file(path: String = PATH) -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("controls", "invert_y", invert_y)
	config.set_value("controls", "bindings", bindings)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "ambience", ambience_volume)
	config.set_value("camera", "shake", camera_shake)
	config.set_value("video", "quality", quality)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "debug_hud", debug_hud)
	config.set_value("video", "damage_numbers", damage_numbers)
	return config.save(path)

func apply_input() -> void:
	for action: String in bindings:
		if not InputMap.has_action(action) or not REBINDABLE.has(action):
			continue
		var event: InputEvent = event_from(bindings[action])
		if event == null:
			continue
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)

func rebind(action: String, event: InputEvent) -> void:
	var description: Dictionary = describe(event)
	if description.is_empty():
		return
	for other: String in REBINDABLE:
		if other != action and bindings.has(other) and bindings[other] == description:
			bindings.erase(other)
	bindings[action] = description
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)

func reset_bindings() -> void:
	bindings.clear()
	InputMap.load_from_project_settings()

static func describe(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		return {"type": "key", "code": int(key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button": int((event as InputEventMouseButton).button_index)}
	return {}

static func event_from(data: Variant) -> InputEvent:
	if not data is Dictionary:
		return null
	if data.get("type") == "key":
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = int(data.get("code", 0)) as Key
		return key
	if data.get("type") == "mouse":
		var button: InputEventMouseButton = InputEventMouseButton.new()
		button.button_index = int(data.get("button", 1)) as MouseButton
		button.pressed = true
		return button
	return null

static func event_label(action: String) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty():
		return "—"
	var event: InputEvent = events[0]
	if event is InputEventMouseButton:
		return {1: "Chuột trái", 2: "Chuột phải", 3: "Chuột giữa"}.get(int((event as InputEventMouseButton).button_index), "Chuột")
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return OS.get_keycode_string(code).replace("Space", "Space").replace("Shift", "Shift")
	return event.as_text()

func preset() -> Dictionary:
	return QUALITY[quality]
