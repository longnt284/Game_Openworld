class_name Gacha
extends RefCounted
## Kỳ Ngộ banner pulls and reward chests over data/gacha.json. Rates, pity and the pools
## are data, so the published rate screen and the roll read the same numbers.
## Pity record per banner: {"since_ssr", "since_sr", "guaranteed", "total"}.

const RARITIES: PackedStringArray = ["ssr", "sr", "r"]

static func data() -> Dictionary:
	return ContentDB.get_data("gacha")

static func banner(id: String) -> Dictionary:
	return (data().get("banners", {}) as Dictionary).get(id, {})

static func currency() -> String:
	return String(data().get("currency", {}).get("id", "ngoc_gio"))

static func shards() -> String:
	return String(data().get("shards", {}).get("id", "manh_ky_ngo"))

static func new_pity() -> Dictionary:
	return {"since_ssr": 0, "since_sr": 0, "guaranteed": false, "total": 0}

static func cost(banner_id: String, count: int) -> int:
	var info: Dictionary = banner(banner_id)
	return int(info.get("cost10", 1600)) if count == 10 else int(info.get("cost", 160)) * count

static func ssr_chance(info: Dictionary, since_ssr: int) -> float:
	## Chance of a top-rarity result on the pull after `since_ssr` misses: the base rate,
	## rising by soft_step per pull from soft_from, certain at the hard pity pull.
	var base: float = float(info["rates"]["ssr"])
	var pity: Dictionary = info.get("pity", {})
	var pull: int = since_ssr + 1
	if pull >= int(pity.get("hard", 1 << 30)):
		return 1.0
	if pull >= int(pity.get("soft_from", 1 << 30)):
		return minf(1.0, base + float(pull - int(pity["soft_from"]) + 1) * float(pity.get("soft_step", 0.0)))
	return base

static func consolidated_ssr(banner_id: String) -> float:
	## Long-run top-rarity rate including pity (published next to the base rate).
	var info: Dictionary = banner(banner_id)
	var survive: float = 1.0
	var expected: float = 0.0
	for pull: int in range(1, int(info.get("pity", {}).get("hard", 90)) + 1):
		var chance: float = ssr_chance(info, pull - 1)
		expected += pull * survive * chance
		survive *= 1.0 - chance
	return 1.0 / expected

static func roll(banner_id: String, pity: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	## One pull: {"rarity", "reward", "featured", "pity"}; `pity` is not modified.
	var info: Dictionary = banner(banner_id)
	var state: Dictionary = new_pity()
	state.merge(pity, true)
	var ssr: float = ssr_chance(info, int(state["since_ssr"]))
	var roll_value: float = rng.randf()
	var rarity: String = "r"
	if roll_value < ssr:
		rarity = "ssr"
	elif roll_value < ssr + float(info["rates"]["sr"]) or int(state["since_sr"]) + 1 >= int(info.get("pity", {}).get("sr_every", 1 << 30)):
		rarity = "sr"
	state["total"] = int(state["total"]) + 1
	state["since_ssr"] = 0 if rarity == "ssr" else int(state["since_ssr"]) + 1
	state["since_sr"] = 0 if rarity != "r" else int(state["since_sr"]) + 1
	var reward: Dictionary = {}
	var featured: bool = false
	var spotlight: Dictionary = info.get("featured", {}).get(rarity, {})
	if not spotlight.is_empty():
		# 50/50 on the featured reward; losing it guarantees the next top-rarity result.
		featured = bool(state["guaranteed"]) or rng.randf() < float(info["featured"].get("rate_up", 0.5))
		state["guaranteed"] = not featured
		if featured:
			reward = spotlight
		else:
			var others: Array = (info["pool"][rarity] as Array).filter(func(entry: Dictionary) -> bool: return entry != spotlight)
			reward = others[rng.randi_range(0, others.size() - 1)]
	else:
		var pool: Array = info["pool"][rarity]
		reward = pool[rng.randi_range(0, pool.size() - 1)]
	return {"rarity": rarity, "reward": reward, "featured": featured, "pity": state}

static func roll_rates(rates: Dictionary, rng: RandomNumberGenerator) -> String:
	## Plain weighted rarity draw with no pity (reward chests).
	var roll_value: float = rng.randf()
	var edge: float = 0.0
	for rarity: String in RARITIES:
		edge += float(rates.get(rarity, 0.0))
		if roll_value < edge:
			return rarity
	return "r"

static func make_weapon(base: String, rarity: String, rng: RandomNumberGenerator) -> Array:
	## Distinct weighted affixes for a rolled weapon: [[id, value], ...].
	var table: Dictionary = ContentDB.get_data("affixes")
	var ids: Array = table.keys()
	var count: int = mini(int(PlayerStats.rarity_data(rarity).get("affixes", 1)), ids.size())
	var result: Array = []
	for index: int in range(count):
		var total: float = 0.0
		for id: String in ids:
			total += float(table[id].get("weight", 1))
		var pick: float = rng.randf() * total
		var chosen: String = ids[-1]
		for id: String in ids:
			pick -= float(table[id].get("weight", 1))
			if pick < 0.0:
				chosen = id
				break
		ids.erase(chosen)
		var span: Array = table[chosen].get("range", [1, 5])
		result.append([chosen, rng.randi_range(int(span[0]), int(span[1]))])
	return result

static func grant(profile: PlayerProfile, reward: Dictionary, rarity: String, rng: RandomNumberGenerator) -> Dictionary:
	## Hands one reward to the profile; returns {"rarity", "label", "type", ...} for the UI and history.
	var result: Dictionary = {"rarity": rarity, "type": String(reward.get("type", ""))}
	match result["type"]:
		"weapon":
			var base: String = String(reward["base"])
			var item: Dictionary = profile.add_weapon(base, rarity, make_weapon(base, rarity, rng))
			result["uid"] = item["uid"]
			result["label"] = PlayerStats.weapon_label(item)
			result["affixes"] = item["affixes"]
		"skin":
			var id: String = String(reward["id"])
			result["label"] = "Trang phục: " + String(ContentDB.skin(id).get("name", id))
			if profile.skins.has(id):
				var amount: int = int(data().get("duplicates", {}).get("skin", 40))
				profile.add_currency(shards(), amount)
				result["label"] += " (trùng → %d %s)" % [amount, data()["shards"]["name"]]
			else:
				profile.skins.append(id)
				profile.changed.emit("skins")
		"shards":
			var amount: int = int(reward.get("amount", 1))
			profile.add_currency(shards(), amount)
			result["label"] = "%s ×%d" % [data()["shards"]["name"], amount]
	return result

static func pull(profile: PlayerProfile, banner_id: String, count: int) -> Array:
	## Spends the cost and pulls `count` times; [] (and no change) when Ngọc Gió is short.
	if banner(banner_id).is_empty() or not profile.spend(currency(), cost(banner_id, count)):
		return []
	var rng: RandomNumberGenerator = profile.rng()
	var pity: Dictionary = profile.pity.get(banner_id, new_pity())
	var results: Array = []
	for index: int in range(count):
		var outcome: Dictionary = roll(banner_id, pity, rng)
		pity = outcome["pity"]
		var granted: Dictionary = grant(profile, outcome["reward"], outcome["rarity"], rng)
		granted["featured"] = outcome["featured"]
		results.append(granted)
		profile.record({"banner": banner_id, "rarity": granted["rarity"], "label": granted["label"], "time": Time.get_datetime_string_from_system(false, true)})
	profile.pity[banner_id] = pity
	profile.keep_rng(rng)
	return results

static func chest_rarity(profile: PlayerProfile, table_id: String) -> String:
	## Rolled when the chest appears, so it can glow in its rarity colour before it is opened.
	var table: Dictionary = (data().get("chests", {}) as Dictionary).get(table_id, {})
	if table.is_empty():
		return "r"
	var rng: RandomNumberGenerator = profile.rng()
	var rarity: String = roll_rates(table["rates"], rng)
	profile.keep_rng(rng)
	return rarity

static func open_chest(profile: PlayerProfile, table_id: String, rarity: String) -> Dictionary:
	var table: Dictionary = (data().get("chests", {}) as Dictionary).get(table_id, {})
	if table.is_empty():
		return {}
	var rng: RandomNumberGenerator = profile.rng()
	var pool: Array = banner(String(table.get("pool", "ngu_hanh")))["pool"][rarity]
	var result: Dictionary = grant(profile, pool[rng.randi_range(0, pool.size() - 1)], rarity, rng)
	profile.keep_rng(rng)
	return result

static func chest_supplies(table_id: String, rng: RandomNumberGenerator) -> Array:
	## Consumables a reward chest also holds: the table's "supplies" [[item, min, max, chance]]
	## (the enemy drop format) rolled into [[item, amount]]. They go to the save, not the profile.
	var table: Dictionary = (data().get("chests", {}) as Dictionary).get(table_id, {})
	var result: Array = []
	for entry: Array in table.get("supplies", []):
		if rng.randf() < float(entry[3]):
			result.append([String(entry[0]), rng.randi_range(int(entry[1]), int(entry[2]))])
	return result

static func exchange(profile: PlayerProfile, id: String) -> Dictionary:
	## Trades Mảnh Kỳ Ngộ for a fixed reward from the exchange list.
	for offer: Dictionary in data().get("exchange", []):
		if String(offer["id"]) != id:
			continue
		var reward: Dictionary = offer["reward"]
		if reward.get("type", "") == "skin" and profile.skins.has(String(reward["id"])):
			return {}
		if not profile.spend(shards(), int(offer["cost"])):
			return {}
		var rng: RandomNumberGenerator = profile.rng()
		var result: Dictionary = grant(profile, reward, String(reward.get("rarity", "sr")), rng)
		profile.keep_rng(rng)
		return result
	return {}
