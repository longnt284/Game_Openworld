class_name PlayerProfile
extends RefCounted
## Account-wide progress shared by every save slot (user://profile.json): gacha currency
## and pity, the armory of rolled weapons, talismans (Ngọc bội) and their slots, skins,
## Endless Trial records, daily missions, the login streak and the gacha RNG state. The
## title-screen banner works before any save is loaded, so none of this lives in GameState.
## Version 2 added the talismans; validate() migrates a version 1 file in place.

signal changed(kind: String)

const PATH: String = "user://profile.json"
const VERSION: int = 2
const HISTORY_SIZE: int = 50

var currency: Dictionary = {"ngoc_gio": 0, "manh_ky_ngo": 0}
## banner id -> {"since_ssr", "since_sr", "guaranteed", "total"}
var pity: Dictionary = {}
## Newest first: {"banner", "rarity", "label", "time"}
var history: Array = []
## Rolled weapons: {"uid", "base", "rarity", "affixes": [[id, value], ...], "skin"}
var armory: Array = []
## Rolled talismans: {"uid", "piece", "rarity", "main": [affix, value], "subs": [[affix, value], ...]}
var talismans: Array = []
## Worn talisman uid per slot (data/talismans.json "slots" order: Thiên, Địa, Nhân); -1 is empty.
var talisman_equipped: Array = Talismans.empty_slots()
## Shared by weapons and talismans, so a uid names one item of either kind.
var next_uid: int = 1
var skins: Array = []
var equipped_skins: Dictionary = {"player": "", "weapon": ""}
var trial: Dictionary = {"best_wave": 0, "runs": 0, "milestones": []}
var daily: Dictionary = {"date": "", "missions": [], "bonus_claimed": false}
var login: Dictionary = {"last": "", "streak": 0, "claimed": ""}
var rng_seed: int = 0
var rng_state: int = 0
## Set once the first-run gift of Ngọc Gió has been granted.
var welcomed: bool = false

func balance(id: String) -> int:
	return int(currency.get(id, 0))

func add_currency(id: String, amount: int) -> void:
	currency[id] = maxi(0, balance(id) + amount)
	changed.emit("currency")

func spend(id: String, amount: int) -> bool:
	if balance(id) < amount:
		return false
	currency[id] = balance(id) - amount
	changed.emit("currency")
	return true

func add_weapon(base: String, rarity: String, affixes: Array) -> Dictionary:
	var item: Dictionary = {"uid": next_uid, "base": base, "rarity": rarity, "affixes": affixes, "skin": ""}
	next_uid += 1
	armory.append(item)
	changed.emit("armory")
	return item

func weapon(uid: int) -> Dictionary:
	for item: Dictionary in armory:
		if int(item["uid"]) == uid:
			return item
	return {}

func add_talisman(item: Dictionary) -> Dictionary:
	var kept: Dictionary = item.duplicate(true)
	kept["uid"] = next_uid
	next_uid += 1
	talismans.append(kept)
	changed.emit("talismans")
	return kept

func talisman(uid: int) -> Dictionary:
	for item: Dictionary in talismans:
		if int(item["uid"]) == uid:
			return item
	return {}

func is_worn(uid: int) -> bool:
	return uid >= 0 and talisman_equipped.has(uid)

func equipped_talismans() -> Array:
	## The worn talismans in slot order, empty slots skipped.
	var result: Array = []
	for uid: int in talisman_equipped:
		var item: Dictionary = talisman(uid) if uid >= 0 else {}
		if not item.is_empty():
			result.append(item)
	return result

func equip_talisman(uid: int) -> bool:
	## Wears a talisman in its piece's slot, replacing whatever was there.
	var slot: int = Talismans.slot_index(String(talisman(uid).get("piece", "")))
	if slot < 0 or slot >= talisman_equipped.size():
		return false
	talisman_equipped[slot] = uid
	changed.emit("talismans")
	return true

func unequip_talisman(slot: int) -> bool:
	if slot < 0 or slot >= talisman_equipped.size() or int(talisman_equipped[slot]) < 0:
		return false
	talisman_equipped[slot] = -1
	changed.emit("talismans")
	return true

func remove_talisman(uid: int) -> Dictionary:
	## Takes an unworn talisman out of the pouch; {} when it is worn or missing.
	var item: Dictionary = talisman(uid)
	if item.is_empty() or is_worn(uid):
		return {}
	talismans.erase(item)
	changed.emit("talismans")
	return item

func record(entry: Dictionary) -> void:
	history.push_front(entry)
	if history.size() > HISTORY_SIZE:
		history.resize(HISTORY_SIZE)

func rng() -> RandomNumberGenerator:
	## The gacha RNG resumes from its saved state, so reloading cannot reroll a result.
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	if rng_seed == 0:
		generator.randomize()
		rng_seed = int(generator.seed)
		rng_state = int(generator.state)
	generator.seed = rng_seed
	generator.state = rng_state
	return generator

func keep_rng(generator: RandomNumberGenerator) -> void:
	rng_state = int(generator.state)

func to_dict() -> Dictionary:
	return {
		"version": VERSION, "currency": currency.duplicate(), "pity": pity.duplicate(true), "history": history.duplicate(true),
		"armory": armory.duplicate(true), "talismans": talismans.duplicate(true), "talisman_equipped": talisman_equipped.duplicate(),
		"next_uid": next_uid, "skins": skins.duplicate(), "equipped_skins": equipped_skins.duplicate(),
		"trial": trial.duplicate(true), "daily": daily.duplicate(true), "login": login.duplicate(), "rng": {"seed": str(rng_seed), "state": str(rng_state)},
		"welcomed": welcomed,
	}

static func validate(data: Variant) -> Dictionary:
	## Returns the data when it is a profile this version can read, else {}. An older version is
	## migrated in place first, adding only what it lacked, so nothing it held is lost.
	if not data is Dictionary or not (data.get("version") is float or data.get("version") is int):
		return {}
	if int(data["version"]) == 1:
		_migrate_v1(data)
	if int(data["version"]) != VERSION:
		return {}
	for key: String in ["currency", "pity", "equipped_skins", "trial", "daily", "login", "rng"]:
		if not data.get(key, {}) is Dictionary:
			return {}
	for key: String in ["history", "armory", "skins", "talismans", "talisman_equipped"]:
		if not data.get(key, []) is Array:
			return {}
	for item: Variant in data.get("armory", []):
		if not item is Dictionary or not item.get("affixes", []) is Array or not (item.get("uid") is float or item.get("uid") is int):
			return {}
	for item: Variant in data.get("talismans", []):
		if (not item is Dictionary or not (item.get("uid") is float or item.get("uid") is int) or not item.get("main") is Array
				or (item["main"] as Array).size() != 2 or not (item["main"][1] is float or item["main"][1] is int) or not item.get("subs", []) is Array):
			return {}
	return data

static func _migrate_v1(data: Dictionary) -> void:
	## v1 -> v2 (Ngọc bội): an empty pouch and empty slots. Currency, pity, history, the armory
	## and everything else stay as they were; the next save keeps the v1 file as the .bak.
	data["talismans"] = []
	data["talisman_equipped"] = Talismans.empty_slots()
	data["version"] = 2

static func load_file(path: String = PATH) -> PlayerProfile:
	var profile: PlayerProfile = PlayerProfile.new()
	var data: Dictionary = SaveStore.read_json(path, PlayerProfile.validate)
	if data.is_empty():
		return profile
	for id: String in data["currency"]:
		profile.currency[id] = maxi(0, int(data["currency"][id]))
	for banner: String in data["pity"]:
		var record: Variant = data["pity"][banner]
		if record is Dictionary:
			# JSON numbers come back as floats; pity counters are whole pulls.
			profile.pity[banner] = {"since_ssr": int(record.get("since_ssr", 0)), "since_sr": int(record.get("since_sr", 0)),
				"guaranteed": bool(record.get("guaranteed", false)), "total": int(record.get("total", 0))}
	profile.history = (data["history"] as Array).duplicate(true)
	profile.armory = []
	for item: Dictionary in data["armory"]:
		if not ContentDB.weapon(String(item.get("base", ""))).is_empty():
			var copy: Dictionary = item.duplicate(true)
			copy["uid"] = int(copy["uid"])
			profile.armory.append(copy)
	profile.talismans = []
	for item: Dictionary in data["talismans"]:
		if Talismans.piece(String(item.get("piece", ""))).is_empty():
			continue
		# JSON numbers come back as floats; uids and rolled values are whole numbers.
		var subs: Array = []
		for affix: Variant in item.get("subs", []):
			if affix is Array and (affix as Array).size() == 2 and (affix[1] is float or affix[1] is int):
				subs.append([String(affix[0]), int(affix[1])])
		profile.talismans.append({"uid": int(item["uid"]), "piece": String(item["piece"]), "rarity": String(item.get("rarity", "r")),
			"main": [String(item["main"][0]), int(item["main"][1])], "subs": subs})
	profile.next_uid = maxi(int(data.get("next_uid", 1)), 1)
	for item: Dictionary in profile.armory + profile.talismans:
		profile.next_uid = maxi(profile.next_uid, int(item["uid"]) + 1)
	var worn: Array = data["talisman_equipped"]
	for slot: int in range(mini(worn.size(), profile.talisman_equipped.size())):
		var uid: int = int(worn[slot]) if worn[slot] is float or worn[slot] is int else -1
		if uid >= 0 and Talismans.slot_index(String(profile.talisman(uid).get("piece", ""))) == slot:
			profile.talisman_equipped[slot] = uid
	profile.skins = (data["skins"] as Array).duplicate()
	profile.equipped_skins = {"player": String(data["equipped_skins"].get("player", "")), "weapon": String(data["equipped_skins"].get("weapon", ""))}
	profile.trial = (data["trial"] as Dictionary).duplicate(true)
	profile.daily = (data["daily"] as Dictionary).duplicate(true)
	profile.login = (data["login"] as Dictionary).duplicate()
	# 64-bit RNG values are stored as strings: JSON numbers would round them.
	profile.rng_seed = str(data["rng"].get("seed", "0")).to_int()
	profile.rng_state = str(data["rng"].get("state", "0")).to_int()
	profile.welcomed = bool(data.get("welcomed", false))
	return profile

func save_file(path: String = PATH) -> Error:
	return SaveStore.atomic_write(path, JSON.stringify(to_dict(), "\t"))
