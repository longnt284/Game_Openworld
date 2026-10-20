class_name PlayerStats
extends RefCounted
## Folds the equipped armory weapon (rarity and affixes), the worn talismans (Ngọc bội: main
## stat, substats, set bonuses) and Endless Trial blessings into one flat bonus table for
## GameState.stats. Every key defaults to 0, which is neutral.
##   attack_bonus  +x attack power        crit_rate / crit_dmg   critical hits (base ×1.5)
##   melee_mult    +x basic-hit damage    element_dmg            +x elemental damage
##   status_chance +x status chance       skill_cd               -x skill cooldowns
##   meter_gain    +x charge gained       damage_taken           ±x damage received
##   heal_on_kill  heal x of max health per kill (Trial blessing, Huyết Ngọc set)
##   reaction_dmg  +x of every elemental reaction bonus: the extra over the blow and the splash
##                 (Lôi Văn talismans; Reactions.bonus_mult)
##   defense       flat: blows keep 100 / (100 + defense)        armor_pen   flat: ignores enemy defense
##   lifesteal     heal x of the damage each direct hit deals (never damage over time)
##   attack_speed  +x speed of attacks and forms (clip and hit timing together)
##   res_<element> -x damage of that element and a lower chance of its status (wind, water, …)
##   status_resist lower chance and shorter time of harmful statuses
##   max_stamina   flat: over the base 100                       stamina_regen  +x stamina recovery
##   poise_dmg     +x poise damage dealt                         move_speed     +x run and walk speed
##   heal_bonus    +x healing from items

const CRIT_BASE: float = 0.5
## Affix id -> stat. Values are authored as whole percentages, or as plain points for affixes
## marked "flat" in data/affixes.json (defense, armor_pen, max_stamina).
const AFFIX_STATS: Dictionary = {"atk_pct": "attack_bonus", "crit_rate": "crit_rate", "crit_dmg": "crit_dmg", "element_dmg": "element_dmg",
	"status_chance": "status_chance", "skill_cd": "skill_cd", "meter_gain": "meter_gain", "defense": "defense", "armor_pen": "armor_pen",
	"max_stamina": "max_stamina", "lifesteal": "lifesteal", "attack_speed": "attack_speed", "stamina_regen": "stamina_regen",
	"poise_dmg": "poise_dmg", "move_speed": "move_speed", "heal_bonus": "heal_bonus", "status_resist": "status_resist", "reaction_dmg": "reaction_dmg"}
## Character sheet (Túi đồ → Nhân vật): groups of [stat, label, unit]. Units: "pct" a signed
## percentage (more is better), "less" one where less is better, "rate" a plain percentage,
## "flat" plain points; "power", "health", "stamina", "crit" and "defense" show a computed
## total; "elements" expands into one resistance row per element in data/elements.json.
const SHEET: Array = [
	["Tấn công", [["attack_bonus", "Công lực", "power"], ["melee_mult", "Sát thương đòn thường", "pct"], ["element_dmg", "Sát thương nguyên tố", "pct"],
		["reaction_dmg", "Sát thương phản ứng", "pct"], ["crit_rate", "Tỉ lệ bạo kích", "rate"], ["crit_dmg", "Sát thương bạo kích", "crit"], ["attack_speed", "Tốc độ ra đòn", "pct"],
		["poise_dmg", "Sức phá thế", "pct"], ["armor_pen", "Xuyên giáp", "flat"], ["lifesteal", "Hút máu", "rate"],
		["status_chance", "Tỉ lệ gây trạng thái", "pct"], ["meter_gain", "Nộ khí nhận được", "pct"], ["skill_cd", "Giảm hồi chiêu", "pct"]]],
	["Phòng thủ", [["", "Khí huyết tối đa", "health"], ["defense", "Phòng ngự", "defense"], ["damage_taken", "Sát thương phải nhận", "less"],
		["status_resist", "Kháng trạng thái", "rate"], ["", "", "elements"]]],
	["Thân pháp & hồi phục", [["max_stamina", "Thể lực tối đa", "stamina"], ["stamina_regen", "Hồi thể lực", "pct"], ["move_speed", "Tốc độ di chuyển", "pct"],
		["heal_bonus", "Hiệu quả hồi phục", "pct"], ["heal_on_kill", "Hồi khí huyết khi hạ địch", "rate"]]],
]
const FLAT_UNITS: PackedStringArray = ["flat", "defense", "stamina"]

static func compute(item: Dictionary, buffs: Dictionary = {}, talismans: Array = []) -> Dictionary:
	## `item` is the armory weapon ({} for a story sword), `buffs` the Trial blessing totals and
	## `talismans` the worn Ngọc bội (PlayerProfile.equipped_talismans).
	var result: Dictionary = {}
	if not item.is_empty():
		var rarity: Dictionary = rarity_data(String(item.get("rarity", "r")))
		_add(result, "attack_bonus", float(rarity.get("attack", 0.0)))
		for affix: Array in item.get("affixes", []):
			_add(result, String(AFFIX_STATS.get(String(affix[0]), "")), affix_value(affix))
	var worn: Dictionary = Talismans.stats(talismans)
	for stat: String in worn:
		_add(result, stat, float(worn[stat]))
	for stat: String in buffs:
		_add(result, stat, float(buffs[stat]))
	result.erase("")
	return result

static func _add(table: Dictionary, key: String, value: float) -> void:
	table[key] = float(table.get(key, 0.0)) + value

static func affix_value(affix: Array) -> float:
	## The bonus one rolled affix adds: whole percentages become fractions, "flat" points stay as is.
	return float(affix[1]) if affix_data(String(affix[0])).get("flat", false) else float(affix[1]) / 100.0

static func affix_data(id: String) -> Dictionary:
	return (ContentDB.get_data("affixes") as Dictionary).get(id, {})

static func affix_allowed(id: String, gear: String) -> bool:
	## Whether an affix may roll on "sword" or "talisman"; data "gear" narrows it, absent means both.
	return (affix_data(id).get("gear", ["sword", "talisman"]) as Array).has(gear)

static func rarity_data(rarity: String) -> Dictionary:
	return ((ContentDB.get_data("gacha") as Dictionary).get("rarity", {}) as Dictionary).get(rarity, {})

static func rarity_color(rarity: String) -> Color:
	return Color(String(rarity_data(rarity).get("color", "f3e6c8")))

static func affix_text(affix: Array) -> String:
	var data: Dictionary = affix_data(String(affix[0]))
	return String(data.get("name", String(affix[0]) + (" +%d" if data.get("flat", false) else " +%d%%"))) % int(affix[1])

static func weapon_label(item: Dictionary) -> String:
	## "Lôi Minh Kiếm · Cực phẩm" for armory items, the plain name for story swords.
	var base: String = String(item.get("base", ""))
	var name: String = String(ContentDB.weapon(base).get("name", base))
	return "%s · %s" % [name, rarity_data(String(item.get("rarity", "r"))).get("name", "")] if item.has("rarity") else name

# ------------------------------------------------------------------ character sheet

static func sheet(state: GameState) -> Array[Dictionary]:
	## Every stat totalled through GameState.stat, so the sword, talismans, blessings and live
	## buffs all count: {"header"} rows open a group, then {"stat", "label", "value", "detail",
	## "tone"} with tone 1 for a bonus, -1 for a penalty and 0 when neutral. Stats nobody listed
	## yet land in a last "Khác" group instead of vanishing.
	var rows: Array[Dictionary] = []
	var listed: Dictionary = {}
	for group: Array in SHEET:
		rows.append({"header": String(group[0])})
		for entry: Array in group[1]:
			if String(entry[2]) != "elements":
				rows.append(_row(state, String(entry[0]), String(entry[1]), String(entry[2])))
				listed[String(entry[0])] = true
				continue
			for element: String in (ContentDB.get_data("elements") as Dictionary).get("elements", {}):
				rows.append(_row(state, "res_" + element, "Kháng " + String(ContentDB.element(element).get("name", element)), "rate"))
				listed["res_" + element] = true
	var extra: Dictionary = {}
	for key: String in state.stats.keys() + state.status_stats.keys():
		if not listed.has(key) and not extra.has(key):
			extra[key] = true
	if not extra.is_empty():
		rows.append({"header": "Khác"})
		for key: String in extra:
			rows.append(_row(state, key, key, "pct"))
	return rows

static func _row(state: GameState, stat: String, label: String, unit: String) -> Dictionary:
	var value: float = state.stat(stat) if stat != "" else 0.0
	var tone: int = 0 if is_zero_approx(value) else (1 if value > 0.0 else -1)
	var notes: PackedStringArray = []
	var text: String = signed_pct(value)
	match unit:
		"power":
			text = "%d" % roundi(state.attack_power())
			if tone != 0:
				notes.append("tổng " + signed_pct(value))
		"health":
			text = "%d" % roundi(state.max_health())
		"stamina":
			text = "%d" % roundi(state.max_stamina())
		"defense":
			text = "%d" % roundi(value)
			if value > 0.0:
				notes.append("giảm %d%% sát thương" % roundi((1.0 - Combat.defense_mult(value)) * 100.0))
		"flat":
			text = "%d" % roundi(value)
		"rate":
			text = "%d%%" % roundi(value * 100.0)
		"crit":
			text = signed_pct(CRIT_BASE + value)
		"less":
			tone = -tone
	var live: float = float(state.status_stats.get(stat, 0.0)) if stat != "" else 0.0
	if not is_zero_approx(live):
		notes.append("từ trạng thái " + (signed_flat(live) if FLAT_UNITS.has(unit) else signed_pct(live)))
	return {"stat": stat, "label": label, "value": text, "detail": "  •  ".join(notes), "tone": tone}

static func signed_pct(value: float) -> String:
	## "+15%", "-12%", "0%".
	var number: int = roundi(value * 100.0)
	return "0%" if number == 0 else ("+%d%%" % number if number > 0 else "-%d%%" % -number)

static func signed_flat(value: float) -> String:
	var number: int = roundi(value)
	return "0" if number == 0 else ("+%d" % number if number > 0 else "-%d" % -number)
