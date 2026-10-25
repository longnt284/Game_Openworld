class_name StyleBook
extends RefCounted
## Kiếm Quyết (data/styles.json): six elemental sword arts, each with three forms for the E
## (skill_1), Q (skill_2) and X (skill_ult, costs the full charge meter) keys. Each style is
## learned through its own quest ("unlock") and bound per key in GameState.loadout; a sword only
## names the style it is attuned to ("style" in data/weapons.json). Story swords lean to Phong.

const SLOTS: PackedStringArray = ["e", "q", "x"]
const SLOT_ACTIONS: Dictionary = {"e": "skill_1", "q": "skill_2", "x": "skill_ult"}
const DEFAULT_STYLE: String = "phong"
## Learning an ultimate costs this many cultivation points and needs the style's Q form.
const ULT_COST: int = 2
## A form landing with the same element as the sword in hand deals this much more.
const ATTUNE_BONUS: float = 0.15

static func style_of(sword: String) -> String:
	var style: String = String(ContentDB.weapon(sword).get("style", DEFAULT_STYLE))
	return style if not ContentDB.style(style).is_empty() else DEFAULT_STYLE

static func form(style: String, slot: String) -> Dictionary:
	return (ContentDB.style(style).get("forms", {}) as Dictionary).get(slot, {})

static func styles() -> Array:
	return (ContentDB.get_data("styles") as Dictionary).keys()

static func all_skill_ids() -> Array[String]:
	var result: Array[String] = []
	for style: String in styles():
		for slot: String in SLOTS:
			var skill: String = String(form(style, slot).get("skill", ""))
			if skill != "" and not result.has(skill):
				result.append(skill)
	return result

static func find(skill: String) -> Dictionary:
	## {"style", "slot", "form"} for a skill id, or {} when it is not a sword form.
	for style: String in styles():
		for slot: String in SLOTS:
			if String(form(style, slot).get("skill", "")) == skill:
				return {"style": style, "slot": slot, "form": form(style, slot)}
	return {}

static func skill_name(skill: String) -> String:
	if skill == "khinh_cong":
		return "Khinh công"
	return String(find(skill).get("form", {}).get("name", skill))

static func color(style: String) -> Color:
	return Color(String(ContentDB.style(style).get("color", "9ff5e0")))

static func element_color(element: String) -> Color:
	return Color(String(ContentDB.element(element).get("color", "ffffff"))) if element != "" else Color(1, 1, 1)

static func unlock_quest(style: String) -> String:
	## The quest whose completion teaches this style ("" when none is named).
	return String((ContentDB.style(style).get("unlock", {}) as Dictionary).get("quest", ""))

static func unlock_hint(style: String) -> String:
	return String((ContentDB.style(style).get("unlock", {}) as Dictionary).get("hint", ""))

static func style_for_quest(quest: String) -> String:
	## The style a quest teaches when it completes, or "".
	for style: String in styles():
		if unlock_quest(style) == quest:
			return style
	return ""
