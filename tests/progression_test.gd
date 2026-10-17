extends SceneTree
## Account and long-term progression: save schema v3 migration and validation, the
## account profile (currency, armory, RNG state) and its backup recovery. Later
## sections cover gacha, world tiers, the Endless Trial and daily missions.

var failures: int = 0
const PROFILE: String = "user://progression_test_profile.json"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _remove(path: String) -> void:
	for candidate: String in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)

func _run() -> void:
	_saves()
	_profile()
	print("PROGRESSION RESULT: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)

func _saves() -> void:
	var v2_state: Dictionary = GameState.new().to_dict()
	for key: String in ["swords", "equipped_uid", "world_tier", "max_tier"]:
		v2_state.erase(key)
	v2_state["sword"] = "sword_wind"
	var v2: Dictionary = {"version": 2, "seed": 284, "position": [1.0, 2.0, 3.0], "checkpoint": [1.0, 2.0, 3.0], "yaw": 0.0, "state": v2_state}
	var migrated: Dictionary = SaveStore.migrate(v2)
	check(not migrated.is_empty() and int(migrated["version"]) == SaveStore.SCHEMA_VERSION, "Version 2 saves migrate to version 3")
	if not migrated.is_empty():
		var state: GameState = GameState.new()
		state.from_dict(migrated["state"])
		check(state.swords == ["sword_old", "sword_bamboo", "sword_wind"] and state.sword == "sword_wind" and state.world_tier == 0, "Migration keeps the forged swords and starts at world tier 0")
	var broken: Dictionary = {"version": SaveStore.SCHEMA_VERSION, "seed": 284, "position": [1.0, 2.0, 3.0], "checkpoint": [1.0, 2.0, 3.0], "state": GameState.new().to_dict()}
	broken["state"]["swords"] = "sword_old"
	check(not SaveStore.validate(broken), "A v3 save with a non-array sword list is rejected")
	broken["state"]["swords"] = ["sword_old"]
	broken["state"]["world_tier"] = -1
	check(not SaveStore.validate(broken), "A negative world tier is rejected")
	var state: GameState = GameState.new()
	check(state.grant_sword("sword_flame") and state.skill_level("viem_e") == 1 and state.skill_level("viem_q") == 1 and state.skill_level("viem_x") == 0,
		"The first elemental sword teaches its style's E and Q forms")
	check(not state.grant_sword("sword_flame"), "A sword is only granted once")
	state.skill_points = 2
	check(state.learn_ultimate("viem_x", "viem_q") and state.skill_level("viem_x") == 1 and state.skill_points == 0, "Ultimates cost two cultivation points")

func _profile() -> void:
	_remove(PROFILE)
	var profile: PlayerProfile = PlayerProfile.load_file(PROFILE)
	check(profile.balance("ngoc_gio") == 0 and profile.armory.is_empty(), "A missing profile starts empty")
	profile.add_currency("ngoc_gio", 480)
	check(not profile.spend("ngoc_gio", 500) and profile.balance("ngoc_gio") == 480, "Spending more than the balance is refused")
	var item: Dictionary = profile.add_weapon("sword_flame", "ssr", [["crit_rate", 6]])
	var rng: RandomNumberGenerator = profile.rng()
	rng.randi()
	profile.keep_rng(rng)
	var expected_next: int = profile.rng().randi()
	check(profile.save_file(PROFILE) == OK, "Profile saves")
	var loaded: PlayerProfile = PlayerProfile.load_file(PROFILE)
	check(loaded.balance("ngoc_gio") == 480 and loaded.weapon(int(item["uid"])).get("rarity") == "ssr" and loaded.next_uid == profile.next_uid, "Profile reloads currency and armory")
	check(loaded.rng().randi() == expected_next, "The gacha RNG resumes exactly where it stopped")
	loaded.add_currency("ngoc_gio", 20)
	loaded.save_file(PROFILE)
	var file: FileAccess = FileAccess.open(PROFILE, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(PlayerProfile.load_file(PROFILE).balance("ngoc_gio") == 480, "A corrupt profile falls back to its backup")
	_remove(PROFILE)
