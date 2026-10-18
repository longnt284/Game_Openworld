class_name PlayerStats
extends RefCounted
## Folds the equipped armory weapon (rarity and affixes) and Endless Trial blessings into
## one flat bonus table for GameState.stats. Every key defaults to 0, which is neutral.
##   attack_bonus  +x attack power        crit_rate / crit_dmg   critical hits (base ×1.5)
##   melee_mult    +x basic-hit damage    element_dmg            +x elemental damage
##   status_chance +x status chance       skill_cd               -x skill cooldowns
##   meter_gain    +x charge gained       damage_taken           ±x damage received
##   heal_on_kill  heal x of max health per kill (Trial only)

const CRIT_BASE: float = 0.5
## Affix values are authored as whole percentages.
const AFFIX_STATS: Dictionary = {"atk_pct": "attack_bonus", "crit_rate": "crit_rate", "crit_dmg": "crit_dmg", "element_dmg": "element_dmg",
	"status_chance": "status_chance", "skill_cd": "skill_cd", "meter_gain": "meter_gain"}

static func compute(item: Dictionary, buffs: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	if not item.is_empty():
		var rarity: Dictionary = rarity_data(String(item.get("rarity", "r")))
		_add(result, "attack_bonus", float(rarity.get("attack", 0.0)))
		for affix: Array in item.get("affixes", []):
			_add(result, String(AFFIX_STATS.get(String(affix[0]), "")), float(affix[1]) / 100.0)
	for stat: String in buffs:
		_add(result, stat, float(buffs[stat]))
	result.erase("")
	return result

static func _add(table: Dictionary, key: String, value: float) -> void:
	table[key] = float(table.get(key, 0.0)) + value

static func rarity_data(rarity: String) -> Dictionary:
	return ((ContentDB.get_data("gacha") as Dictionary).get("rarity", {}) as Dictionary).get(rarity, {})

static func rarity_color(rarity: String) -> Color:
	return Color(String(rarity_data(rarity).get("color", "f3e6c8")))

static func affix_text(affix: Array) -> String:
	var data: Dictionary = (ContentDB.get_data("affixes") as Dictionary).get(String(affix[0]), {})
	return String(data.get("name", String(affix[0]) + " %d")) % int(affix[1])

static func weapon_label(item: Dictionary) -> String:
	## "Lôi Minh Kiếm · Cực phẩm" for armory items, the plain name for story swords.
	var base: String = String(item.get("base", ""))
	var name: String = String(ContentDB.weapon(base).get("name", base))
	return "%s · %s" % [name, rarity_data(String(item.get("rarity", "r"))).get("name", "")] if item.has("rarity") else name
