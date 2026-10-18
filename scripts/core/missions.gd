class_name Missions
extends RefCounted
## Daily missions and the 7-day login calendar over data/daily.json, stored in the profile.
## Dates are "YYYY-MM-DD" strings from the system clock (offline game: the player's clock).

static func today() -> String:
	return Time.get_date_string_from_system()

static func refresh(profile: PlayerProfile, date: String) -> bool:
	## Rolls a new set of missions when the day changed; true when it did.
	if String(profile.daily.get("date", "")) == date:
		return false
	var table: Dictionary = ContentDB.get_data("daily")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(date)
	var pool: Array = (table.get("pool", []) as Array).duplicate()
	var missions: Array = []
	for index: int in range(mini(int(table.get("per_day", 4)), pool.size())):
		var entry: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var goal: int = rng.randi_range(int(entry["goal"][0]), int(entry["goal"][1]))
		missions.append({"id": entry["id"], "event": entry["event"], "name": String(entry["name"]) % goal, "goal": goal, "progress": 0,
			"reward": int(entry["reward"]), "claimed": false})
	profile.daily = {"date": date, "missions": missions, "bonus_claimed": false}
	return true

static func notify(profile: PlayerProfile, event: String, amount: int = 1) -> Array:
	## Adds progress; returns the names of missions this call completed.
	var finished: Array = []
	for mission: Dictionary in profile.daily.get("missions", []):
		if String(mission["event"]) != event or int(mission["progress"]) >= int(mission["goal"]):
			continue
		mission["progress"] = mini(int(mission["goal"]), int(mission["progress"]) + amount)
		if int(mission["progress"]) >= int(mission["goal"]):
			finished.append(mission["name"])
	return finished

static func claim(profile: PlayerProfile, index: int) -> int:
	var missions: Array = profile.daily.get("missions", [])
	if index < 0 or index >= missions.size():
		return 0
	var mission: Dictionary = missions[index]
	if mission["claimed"] or int(mission["progress"]) < int(mission["goal"]):
		return 0
	mission["claimed"] = true
	profile.add_currency(Gacha.currency(), int(mission["reward"]))
	return int(mission["reward"])

static func all_claimed(profile: PlayerProfile) -> bool:
	var missions: Array = profile.daily.get("missions", [])
	return not missions.is_empty() and missions.all(func(mission: Dictionary) -> bool: return mission["claimed"])

static func claim_bonus(profile: PlayerProfile) -> int:
	if profile.daily.get("bonus_claimed", false) or not all_claimed(profile):
		return 0
	profile.daily["bonus_claimed"] = true
	var amount: int = int(ContentDB.get_data("daily").get("all_done", 80))
	profile.add_currency(Gacha.currency(), amount)
	return amount

static func login_day(profile: PlayerProfile, date: String) -> int:
	## Calendar day (1-7) a claim today would give; consecutive days continue the streak.
	var streak: int = int(profile.login.get("streak", 0))
	var last: String = String(profile.login.get("last", ""))
	return (streak % 7) + 1 if last != "" and last == _previous_day(date) else 1

static func can_claim_login(profile: PlayerProfile, date: String) -> bool:
	return String(profile.login.get("claimed", "")) != date

static func claim_login(profile: PlayerProfile, date: String) -> int:
	if not can_claim_login(profile, date):
		return 0
	var day: int = login_day(profile, date)
	var rewards: Array = ContentDB.get_data("daily").get("login", [60])
	var amount: int = int(rewards[mini(day, rewards.size()) - 1])
	profile.login = {"last": date, "streak": day, "claimed": date}
	profile.add_currency(Gacha.currency(), amount)
	return amount

static func _previous_day(date: String) -> String:
	var unix: int = Time.get_unix_time_from_datetime_string(date + "T12:00:00")
	return Time.get_date_string_from_unix_time(unix - 86400)
