class_name Talismans
extends RefCounted
## Ngọc bội over data/talismans.json: rolled talismans worn in three slots (Thiên, Địa, Nhân).
## Each piece has a set, a slot and a main stat named by an affix id; rarity scales the main
## stat and adds substats from the shared affix pool (data/affixes.json, "gear" filter). Two or
## three worn pieces of one set add its set bonuses. Rolls use the profile's saved RNG like Kỳ
## Ngộ, so reloading cannot reroll a drop; the Kỳ Ngộ banner never holds talismans.
## Item: {"uid", "piece", "rarity", "main": [affix, value], "subs": [[affix, value], ...]}.

## Enemy drop entry in data/enemies.json "drops": ["talisman", 1, 1, chance].
const DROP: String = "talisman"
## Set bonus tiers: pieces of one set worn at once.
const TIERS: PackedStringArray = ["2", "3"]
const RANK: Dictionary = {"r": 0, "sr": 1, "ssr": 2}

static func data() -> Dictionary:
	return ContentDB.get_data("talismans")

static func piece(id: String) -> Dictionary:
	return (data().get("pieces", {}) as Dictionary).get(id, {})

static func set_info(id: String) -> Dictionary:
	return (data().get("sets", {}) as Dictionary).get(id, {})

static func rarity_info(rarity: String) -> Dictionary:
	return (data().get("rarity", {}) as Dictionary).get(rarity, {})

static func slots() -> Array:
	return data().get("slots", [])

static func empty_slots() -> Array:
	var result: Array = []
	for slot: Variant in slots():
		result.append(-1)
	return result

static func slot_index(piece_id: String) -> int:
	var slot: String = String(piece(piece_id).get("slot", ""))
	var all: Array = slots()
	for index: int in range(all.size()):
		if String(all[index].get("id", "")) == slot:
			return index
	return -1

static func capacity() -> int:
	return int(data().get("capacity", 60))

static func salvage_value(rarity: String) -> int:
	return int(rarity_info(rarity).get("salvage", 0))

static func rank(item: Dictionary) -> int:
	return int(RANK.get(String(item.get("rarity", "r")), 0))

# ------------------------------------------------------------------ text and colour

static func label(item: Dictionary) -> String:
	## "Huyết Ngọc Bội · Hiếm".
	var id: String = String(item.get("piece", ""))
	return "%s · %s" % [piece(id).get("name", id), PlayerStats.rarity_data(String(item.get("rarity", "r"))).get("name", "")]

static func set_of(item: Dictionary) -> String:
	return String(piece(String(item.get("piece", ""))).get("set", ""))

static func color(item: Dictionary) -> Color:
	## The set's colour (a piece may override it), used for the icon square.
	var info: Dictionary = piece(String(item.get("piece", "")))
	return Color(String(info.get("color", set_info(String(info.get("set", ""))).get("color", "f3e6c8"))))

static func glyph(item: Dictionary) -> String:
	## The slot's letter (T, Đ, N) drawn on the icon square.
	var index: int = slot_index(String(item.get("piece", "")))
	return String(slots()[index].get("glyph", "?")) if index >= 0 else "?"

static func slot_name(index: int) -> String:
	return String(slots()[index].get("name", "")) if index >= 0 and index < slots().size() else ""

static func main_span(piece_id: String, rarity: String) -> Vector2i:
	## Lowest and highest main-stat value a piece can roll at a rarity.
	var main: Array = piece(piece_id).get("main", ["", 0, 0])
	var scale: float = float(rarity_info(rarity).get("main_scale", 1.0))
	return Vector2i(roundi(float(main[1]) * scale), roundi(float(main[2]) * scale))

# ------------------------------------------------------------------ rolls

static func make(piece_id: String, rarity: String, rng: RandomNumberGenerator) -> Dictionary:
	## One talisman of a known piece and rarity; it has no uid until a profile keeps it.
	var main: Array = piece(piece_id).get("main", ["atk_pct", 1, 1])
	var scale: float = float(rarity_info(rarity).get("main_scale", 1.0))
	var value: int = roundi(float(rng.randi_range(int(main[1]), int(main[2]))) * scale)
	var subs: Array = Gacha.roll_affixes(int(rarity_info(rarity).get("substats", 1)), rng, "talisman", [String(main[0])])
	return {"piece": piece_id, "rarity": rarity, "main": [String(main[0]), value], "subs": subs}

static func roll_rarity(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total: float = 0.0
	for rarity: String in Gacha.RARITIES:
		total += float(weights.get(rarity, 0.0))
	var pick: float = rng.randf() * total
	for rarity: String in Gacha.RARITIES:
		pick -= float(weights.get(rarity, 0.0))
		if pick < 0.0:
			return rarity
	return "r"

static func source_weights(source: String) -> Dictionary:
	## Rarity weights for a drop source ("enemy", "elite", "boss"); the base table when it has none.
	var weights: Dictionary = (data().get("sources", {}) as Dictionary).get(source, {}).get("weights", {})
	if not weights.is_empty():
		return weights
	var base: Dictionary = {}
	for rarity: String in data().get("rarity", {}):
		base[rarity] = float(rarity_info(rarity).get("weight", 0.0))
	return base

static func roll(source: String, rng: RandomNumberGenerator) -> Dictionary:
	## A random piece at a rarity weighted for the source.
	var ids: Array = (data().get("pieces", {}) as Dictionary).keys()
	if ids.is_empty():
		return {}
	var rarity: String = roll_rarity(source_weights(source), rng)
	return make(String(ids[rng.randi_range(0, ids.size() - 1)]), rarity, rng)

static func drop(profile: PlayerProfile, source: String, chance: float) -> Dictionary:
	## An enemy's talisman: {} or a rolled talisman not yet kept. Elites multiply the chance by
	## their source's "chance_mult". Uses and advances the profile RNG.
	var rng: RandomNumberGenerator = profile.rng()
	var result: Dictionary = {}
	var odds: float = chance * float((data().get("sources", {}) as Dictionary).get(source, {}).get("chance_mult", 1.0))
	if rng.randf() < odds:
		result = roll(source, rng)
	profile.keep_rng(rng)
	return result

static func from_chest(profile: PlayerProfile, table: String, rarity: String) -> Dictionary:
	## A reward chest's talisman ("chests" chance per chest table), at the chest's own rarity.
	var chance: float = float((data().get("chests", {}) as Dictionary).get(table, 0.0))
	var ids: Array = (data().get("pieces", {}) as Dictionary).keys()
	if chance <= 0.0 or ids.is_empty():
		return {}
	var rng: RandomNumberGenerator = profile.rng()
	var result: Dictionary = {}
	if rng.randf() < chance:
		result = make(String(ids[rng.randi_range(0, ids.size() - 1)]), rarity, rng)
	profile.keep_rng(rng)
	return result

# ------------------------------------------------------------------ pouch

static func grant(profile: PlayerProfile, item: Dictionary) -> Dictionary:
	## Keeps a new talisman. A full pouch salvages the lowest-rarity candidate instead: the new
	## one itself, unless an unworn talisman ranks lower (the oldest such goes first). Worn ones
	## are never touched. Returns {"item" (with its uid when kept), "kept", "salvaged" ({} or the
	## talisman turned into Đồng), "coins"}; the caller adds the coins to the save.
	var result: Dictionary = {"item": item, "kept": true, "salvaged": {}, "coins": 0}
	if profile.talismans.size() >= capacity():
		var victim: Dictionary = {}
		var lowest: int = rank(item)
		for owned: Dictionary in profile.talismans:
			if not profile.is_worn(int(owned["uid"])) and rank(owned) < lowest:
				victim = owned
				lowest = rank(owned)
		if victim.is_empty():
			result["kept"] = false
			result["salvaged"] = item
			result["coins"] = salvage_value(String(item.get("rarity", "r")))
			return result
		profile.remove_talisman(int(victim["uid"]))
		result["salvaged"] = victim
		result["coins"] = salvage_value(String(victim.get("rarity", "r")))
	result["item"] = profile.add_talisman(item)
	return result

static func salvage(profile: PlayerProfile, uid: int) -> int:
	## Turns an unworn talisman into its Đồng value; 0 (and no change) when it is worn or missing.
	var item: Dictionary = profile.talisman(uid)
	if item.is_empty() or profile.is_worn(uid):
		return 0
	profile.remove_talisman(uid)
	return salvage_value(String(item.get("rarity", "r")))

# ------------------------------------------------------------------ stats

static func stats(items: Array) -> Dictionary:
	## Main stats, substats and set bonuses of the worn talismans as one stat table.
	var result: Dictionary = {}
	for item: Dictionary in items:
		var lines: Array = [item.get("main", [])]
		lines.append_array(item.get("subs", []))
		for affix: Array in lines:
			if affix.size() >= 2:
				var stat: String = String(PlayerStats.AFFIX_STATS.get(String(affix[0]), ""))
				result[stat] = float(result.get(stat, 0.0)) + PlayerStats.affix_value(affix)
	var counts: Dictionary = set_counts(items)
	for set_id: String in counts:
		for tier: String in TIERS:
			if int(counts[set_id]) < int(tier):
				continue
			var bonus: Dictionary = set_info(set_id).get(tier, {}).get("stats", {})
			for stat: String in bonus:
				result[stat] = float(result.get(stat, 0.0)) + float(bonus[stat])
	result.erase("")
	return result

static func set_counts(items: Array) -> Dictionary:
	var counts: Dictionary = {}
	for item: Dictionary in items:
		var set_id: String = set_of(item)
		if set_id != "":
			counts[set_id] = int(counts.get(set_id, 0)) + 1
	return counts

static func set_summary(items: Array) -> Array[Dictionary]:
	## Worn sets for the UI: {"set", "name", "color", "count", "tiers": [{"pieces", "desc", "active"}]}.
	var result: Array[Dictionary] = []
	var counts: Dictionary = set_counts(items)
	for set_id: String in counts:
		var info: Dictionary = set_info(set_id)
		var tiers: Array[Dictionary] = []
		for tier: String in TIERS:
			if info.has(tier):
				tiers.append({"pieces": int(tier), "desc": String(info[tier].get("desc", "")), "active": int(counts[set_id]) >= int(tier)})
		result.append({"set": set_id, "name": String(info.get("name", set_id)), "color": Color(String(info.get("color", "f3e6c8"))),
			"count": int(counts[set_id]), "tiers": tiers})
	return result
