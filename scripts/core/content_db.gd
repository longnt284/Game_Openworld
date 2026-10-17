class_name ContentDB
extends RefCounted
## Read-only game content authored as JSON in res://data (exported via include filter).

const FILES: Dictionary = {
	"items": "res://data/items.json",
	"quests": "res://data/quests.json",
	"dialogue": "res://data/dialogue.json",
	"entities": "res://data/world/entities.json",
	"props": "res://data/world/props.json",
	"enemies": "res://data/enemies.json",
	"timings": "res://data/anim_timings.json",
	"attacks": "res://data/attacks.json",
	"weapons": "res://data/weapons.json",
	"styles": "res://data/styles.json",
	"elements": "res://data/elements.json",
}

static var _cache: Dictionary = {}

static func get_data(name: String) -> Variant:
	if not _cache.has(name):
		var file: FileAccess = FileAccess.open(FILES[name], FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
		if parsed == null:
			push_error("Content file missing or invalid: " + FILES[name])
			parsed = {}
		_cache[name] = parsed
	return _cache[name]

static func item(id: String) -> Dictionary:
	return (get_data("items") as Dictionary).get(id, {"name": id, "kind": "misc", "description": ""})

static func quest(id: String) -> Dictionary:
	return (get_data("quests") as Dictionary).get(id, {})

static func enemy(id: String) -> Dictionary:
	return (get_data("enemies") as Dictionary).get(id, {})

static func timing(owner: String, attack: String) -> Dictionary:
	return ((get_data("timings") as Dictionary).get(owner, {}) as Dictionary).get(attack, {})

static func weapon(id: String) -> Dictionary:
	return (get_data("weapons") as Dictionary).get(id, {})

static func style(id: String) -> Dictionary:
	return (get_data("styles") as Dictionary).get(id, {})

static func element(id: String) -> Dictionary:
	return ((get_data("elements") as Dictionary).get("elements", {}) as Dictionary).get(id, {})

static func status(id: String) -> Dictionary:
	return ((get_data("elements") as Dictionary).get("statuses", {}) as Dictionary).get(id, {})

static func dialogue_node(id: String) -> Dictionary:
	return (get_data("dialogue") as Dictionary).get(id, {})
