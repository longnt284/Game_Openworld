class_name PlayerProfile
extends RefCounted
## Account-wide progress shared by every save slot (user://profile.json): gacha currency
## and pity, the armory of rolled weapons, skins, Endless Trial records, daily missions,
## the login streak and the gacha RNG state. The title-screen banner works before any
## save is loaded, so none of this lives in GameState.

signal changed(kind: String)

const PATH: String = "user://profile.json"
const VERSION: int = 1
const HISTORY_SIZE: int = 50

var currency: Dictionary = {"ngoc_gio": 0, "manh_ky_ngo": 0}
## banner id -> {"since_ssr", "since_sr", "guaranteed", "total"}
var pity: Dictionary = {}
## Newest first: {"banner", "rarity", "label", "time"}
var history: Array = []
## Rolled weapons: {"uid", "base", "rarity", "affixes": [[id, value], ...], "skin"}
var armory: Array = []
var next_uid: int = 1
var skins: Array = []
var equipped_skins: Dictionary = {"player": "", "weapon": ""}
var trial: Dictionary = {"best_wave": 0, "runs": 0, "milestones": []}
var daily: Dictionary = {"date": "", "missions": [], "bonus_claimed": false}
var login: Dictionary = {"last": "", "streak": 0, "claimed": ""}
var rng_seed: int = 0
var rng_state: int = 0

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
		"armory": armory.duplicate(true), "next_uid": next_uid, "skins": skins.duplicate(), "equipped_skins": equipped_skins.duplicate(),
		"trial": trial.duplicate(true), "daily": daily.duplicate(true), "login": login.duplicate(), "rng": {"seed": str(rng_seed), "state": str(rng_state)},
	}

static func validate(data: Variant) -> Dictionary:
	## Returns the data when it is a profile this version can read, else {}.
	if not data is Dictionary or int(data.get("version", 0)) != VERSION:
		return {}
	for key: String in ["currency", "pity", "equipped_skins", "trial", "daily", "login", "rng"]:
		if not data.get(key, {}) is Dictionary:
			return {}
	for key: String in ["history", "armory", "skins"]:
		if not data.get(key, []) is Array:
			return {}
	for item: Variant in data.get("armory", []):
		if not item is Dictionary or not item.get("affixes", []) is Array or not (item.get("uid") is float or item.get("uid") is int):
			return {}
	return data

static func load_file(path: String = PATH) -> PlayerProfile:
	var profile: PlayerProfile = PlayerProfile.new()
	var data: Dictionary = SaveStore.read_json(path, PlayerProfile.validate)
	if data.is_empty():
		return profile
	for id: String in data["currency"]:
		profile.currency[id] = maxi(0, int(data["currency"][id]))
	profile.pity = (data["pity"] as Dictionary).duplicate(true)
	profile.history = (data["history"] as Array).duplicate(true)
	profile.armory = []
	for item: Dictionary in data["armory"]:
		if not ContentDB.weapon(String(item.get("base", ""))).is_empty():
			var copy: Dictionary = item.duplicate(true)
			copy["uid"] = int(copy["uid"])
			profile.armory.append(copy)
	profile.next_uid = maxi(int(data.get("next_uid", 1)), 1)
	for item: Dictionary in profile.armory:
		profile.next_uid = maxi(profile.next_uid, int(item["uid"]) + 1)
	profile.skins = (data["skins"] as Array).duplicate()
	profile.equipped_skins = {"player": String(data["equipped_skins"].get("player", "")), "weapon": String(data["equipped_skins"].get("weapon", ""))}
	profile.trial = (data["trial"] as Dictionary).duplicate(true)
	profile.daily = (data["daily"] as Dictionary).duplicate(true)
	profile.login = (data["login"] as Dictionary).duplicate()
	# 64-bit RNG values are stored as strings: JSON numbers would round them.
	profile.rng_seed = str(data["rng"].get("seed", "0")).to_int()
	profile.rng_state = str(data["rng"].get("state", "0")).to_int()
	return profile

func save_file(path: String = PATH) -> Error:
	return SaveStore.atomic_write(path, JSON.stringify(to_dict(), "\t"))
