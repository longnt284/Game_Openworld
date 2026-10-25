extends SceneTree
## Account and long-term progression: save migration (v2 -> current) and validation, the
## account profile (currency, armory, RNG state) and its backup recovery. Later
## sections cover gacha, world tiers, the Endless Trial, daily missions, consumables
## (heal pick, buffs, cures, quick slot), the village medicine counter, flat and percent
## affixes, the defense curve, the character sheet and the Ngọc bội talismans (rolls, slots,
## set bonuses, the v1 -> v2 profile migration, the full pouch, drops and the armory tab).

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
	_gacha()
	_stats()
	_talismans()
	_missions()
	_consumables()
	await _scene()
	print("PROGRESSION RESULT: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)

func frames(count: int) -> void:
	for index: int in range(count):
		await physics_frame
		await process_frame

func _saves() -> void:
	var v2_state: Dictionary = GameState.new().to_dict()
	for key: String in ["swords", "equipped_uid", "world_tier", "max_tier"]:
		v2_state.erase(key)
	v2_state["sword"] = "sword_wind"
	var v2: Dictionary = {"version": 2, "seed": 284, "position": [1.0, 2.0, 3.0], "checkpoint": [1.0, 2.0, 3.0], "yaw": 0.0, "state": v2_state}
	var migrated: Dictionary = SaveStore.migrate(v2)
	check(not migrated.is_empty() and int(migrated["version"]) == SaveStore.SCHEMA_VERSION, "Version 2 saves migrate to the current version (%d)" % SaveStore.SCHEMA_VERSION)
	if not migrated.is_empty():
		var state: GameState = GameState.new()
		state.from_dict(migrated["state"])
		check(state.swords == ["sword_old", "sword_bamboo", "sword_wind"] and state.sword == "sword_wind" and state.world_tier == 0, "Migration keeps the forged swords and starts at world tier 0")
	var broken: Dictionary = {"version": SaveStore.SCHEMA_VERSION, "seed": 284, "position": [1.0, 2.0, 3.0], "checkpoint": [1.0, 2.0, 3.0], "state": GameState.new().to_dict()}
	broken.merge(WeatherDirector.initial_save(284))
	check(SaveStore.validate(broken), "A current save with the world clock validates")
	broken["state"]["swords"] = "sword_old"
	check(not SaveStore.validate(broken), "A save with a non-array sword list is rejected")
	broken["state"]["swords"] = ["sword_old"]
	broken["state"]["world_tier"] = -1
	check(not SaveStore.validate(broken), "A negative world tier is rejected")
	var state: GameState = GameState.new()
	check(state.grant_sword("sword_flame") and state.skill_level("viem_e") == 0 and not state.style_learned("viem"),
		"An elemental sword brings its element, not its Kiếm Quyết (those come from quests)")
	check(not state.grant_sword("sword_flame"), "A sword is only granted once")
	check(state.learn_style("viem") and state.skill_level("viem_e") == 1 and state.skill_level("viem_q") == 1 and state.skill_level("viem_x") == 0 and not state.learn_style("viem"),
		"A quest teaches a style's E and Q forms once")
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

func _gacha() -> void:
	var banner: String = "ngu_hanh"
	var info: Dictionary = Gacha.banner(banner)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2840
	var pity: Dictionary = Gacha.new_pity()
	var pulls: int = 200000
	var ssr: int = 0
	var longest_ssr: int = 0
	var longest_sr: int = 0
	var featured: int = 0
	var guarantee_kept: bool = true
	for index: int in range(pulls):
		var guaranteed: bool = pity["guaranteed"]
		var outcome: Dictionary = Gacha.roll(banner, pity, rng)
		longest_ssr = maxi(longest_ssr, int(pity["since_ssr"]) + 1)
		longest_sr = maxi(longest_sr, int(pity["since_sr"]) + 1)
		if outcome["rarity"] == "ssr":
			ssr += 1
			featured += 1 if outcome["featured"] else 0
			guarantee_kept = guarantee_kept and (not guaranteed or outcome["featured"])
		pity = outcome["pity"]
	var rate: float = float(ssr) / pulls
	var expected: float = Gacha.consolidated_ssr(banner)
	check(absf(rate - expected) < 0.002, "Top-rarity rate over 200,000 pulls matches the published consolidated rate (%.4f vs %.4f)" % [rate, expected])
	check(longest_ssr <= int(info["pity"]["hard"]), "No streak goes past the hard pity pull (%d)" % longest_ssr)
	check(longest_sr <= int(info["pity"]["sr_every"]), "Every %d pulls hold at least one rare result" % int(info["pity"]["sr_every"]))
	check(guarantee_kept and float(featured) / ssr > 0.6, "A lost 50/50 guarantees the featured sword next time (%.2f featured)" % (float(featured) / ssr))
	_remove(PROFILE)
	var profile: PlayerProfile = PlayerProfile.load_file(PROFILE)
	# Seeded so the ten-pull below is the same on every run.
	var seeded: RandomNumberGenerator = RandomNumberGenerator.new()
	seeded.seed = 2841
	profile.rng_seed = 2841
	profile.rng_state = seeded.state
	check(Gacha.pull(profile, banner, 1).is_empty() and profile.pity.is_empty(), "A pull without enough Ngọc Gió is refused and changes nothing")
	profile.add_currency(Gacha.currency(), Gacha.cost(banner, 10))
	var results: Array = Gacha.pull(profile, banner, 10)
	check(results.size() == 10 and profile.balance(Gacha.currency()) == 0 and int(profile.pity[banner]["total"]) == 10 and profile.history.size() == 10,
		"A ten-pull spends 1600 Ngọc Gió, records pity and history")
	check(results.any(func(result: Dictionary) -> bool: return result["rarity"] != "r"), "A ten-pull holds at least one rare result")
	profile.save_file(PROFILE)
	var loaded: PlayerProfile = PlayerProfile.load_file(PROFILE)
	check(loaded.pity[banner] == profile.pity[banner] and loaded.armory.size() == profile.armory.size(), "Pity and rolled weapons survive a profile reload")
	if not profile.skins.has("lam_an_huyet_phong"):
		profile.skins.append("lam_an_huyet_phong")
	var before: int = profile.balance(Gacha.shards())
	Gacha.grant(profile, {"type": "skin", "id": "lam_an_huyet_phong"}, "sr", rng)
	check(profile.balance(Gacha.shards()) == before + 40 and profile.skins.count("lam_an_huyet_phong") == 1, "A duplicate outfit turns into shards")
	var ranges_ok: bool = true
	var counts_ok: bool = true
	var table: Dictionary = ContentDB.get_data("affixes")
	for rarity: String in ["r", "sr", "ssr"]:
		for attempt: int in range(200):
			var affixes: Array = Gacha.make_weapon("sword_flame", rarity, rng)
			var ids: Dictionary = {}
			counts_ok = counts_ok and affixes.size() == int(PlayerStats.rarity_data(rarity)["affixes"])
			for affix: Array in affixes:
				var span: Array = table[affix[0]]["range"]
				ranges_ok = ranges_ok and int(affix[1]) >= int(span[0]) and int(affix[1]) <= int(span[1]) and not ids.has(affix[0])
				ids[affix[0]] = true
	check(ranges_ok and counts_ok, "Rolled affixes are distinct, in range, and number 1/2/3 by rarity")
	_remove(PROFILE)

func _stats() -> void:
	check(PlayerStats.compute({}).is_empty(), "No armory weapon and no blessing means neutral stats")
	var stats: Dictionary = PlayerStats.compute({"base": "sword_flame", "rarity": "ssr", "affixes": [["atk_pct", 10], ["crit_rate", 5]]}, {"melee_mult": 0.15})
	check(is_equal_approx(float(stats["attack_bonus"]), 0.30) and is_equal_approx(float(stats["crit_rate"]), 0.05) and is_equal_approx(float(stats["melee_mult"]), 0.15),
		"Rarity, affixes and blessings fold into one bonus table")
	var state: GameState = GameState.new()
	var plain: float = state.attack_power()
	state.stats = {"attack_bonus": 0.3}
	check(is_equal_approx(state.attack_power(), plain * 1.3), "Attack bonus scales attack power")
	# Flat affixes (defense, armor_pen, max_stamina) add points; the rest are whole percentages.
	var table: Dictionary = ContentDB.get_data("affixes")
	var mapped: bool = table.keys().all(func(id: String) -> bool: return PlayerStats.AFFIX_STATS.has(id)) and PlayerStats.AFFIX_STATS.keys().all(func(id: String) -> bool: return table.has(id))
	var flats: Array = table.keys().filter(func(id: String) -> bool: return bool(table[id].get("flat", false)))
	flats.sort()
	check(mapped and flats == ["armor_pen", "defense", "max_stamina"], "Every affix maps to a stat, and only defense, armor_pen and max_stamina are flat")
	var mixed: Dictionary = PlayerStats.compute({"base": "sword_old", "rarity": "r", "affixes": [["defense", 15], ["attack_speed", 8], ["max_stamina", 20], ["lifesteal", 4]]})
	check(is_equal_approx(float(mixed["defense"]), 15.0) and is_equal_approx(float(mixed["max_stamina"]), 20.0) and is_equal_approx(float(mixed["attack_speed"]), 0.08)
		and is_equal_approx(float(mixed["lifesteal"]), 0.04), "Flat affixes add points and percent affixes add fractions")
	check(PlayerStats.affix_text(["defense", 15]) == "Phòng ngự +15" and PlayerStats.affix_text(["attack_speed", 8]) == "Tốc độ ra đòn +8%", "Affix text shows points for flat affixes and percentages for the rest")
	check(is_equal_approx(Combat.defense_mult(0.0), 1.0) and is_equal_approx(Combat.defense_mult(100.0), 0.5) and is_equal_approx(Combat.defense_mult(300.0), 0.25)
		and is_equal_approx(Combat.defense_mult(-40.0), 1.0), "Defense keeps 100 / (100 + defense) of a blow; none or less is neutral")
	state.stats = {"max_stamina": 30.0}
	check(is_equal_approx(state.max_stamina(), 130.0) and is_equal_approx(GameState.new().max_stamina(), GameState.BASE_STAMINA), "Max stamina is the base 100 plus flat max_stamina")
	_sheet()

func _sheet() -> void:
	## The Nhân vật tab: every stat gear, blessings or statuses can grant has a labelled row.
	var granted: Dictionary = {}
	for stat: String in PlayerStats.AFFIX_STATS.values():
		granted[stat] = 0.1
	for entry: Dictionary in ContentDB.get_data("trial")["buffs"]["pool"]:
		for stat: String in entry.get("stats", {entry.get("stat", ""): 0.0}):
			if stat != "":
				granted[stat] = 0.1
	for id: String in (ContentDB.get_data("elements") as Dictionary)["statuses"]:
		for stat: String in ContentDB.status(id).get("stats", {}):
			granted[stat] = 0.1
	var state: GameState = GameState.new()
	state.stats = granted
	var rows: Dictionary = {}
	var headers: Array = []
	for row: Dictionary in PlayerStats.sheet(state):
		if row.has("header"):
			headers.append(row["header"])
		else:
			rows[String(row["stat"])] = row
	var labelled: bool = granted.keys().all(func(stat: String) -> bool: return rows.has(stat) and String(rows[stat]["label"]) != stat)
	check(labelled and not headers.has("Khác") and rows.has("res_frost"), "The character sheet labels every stat that gear, blessings and statuses grant (%d rows)" % rows.size())
	state.stats = {"defense": 50.0, "attack_speed": 0.1, "damage_taken": -0.25, "skill_cd": -0.3}
	state.status_stats = {"attack_bonus": 0.2}
	rows.clear()
	for row: Dictionary in PlayerStats.sheet(state):
		if not row.has("header"):
			rows[String(row["stat"])] = row
	check(rows["defense"]["value"] == "50" and String(rows["defense"]["detail"]).contains("giảm 33% sát thương") and rows["attack_speed"]["value"] == "+10%" and int(rows["attack_speed"]["tone"]) == 1,
		"The sheet shows flat defense with its damage cut, and percentages signed")
	check(int(rows["damage_taken"]["tone"]) == 1 and int(rows["skill_cd"]["tone"]) == -1 and rows["attack_bonus"]["value"] == "%d" % roundi(state.attack_power())
		and String(rows["attack_bonus"]["detail"]).contains("trạng thái +20%") and int(rows["move_speed"]["tone"]) == 0,
		"The sheet totals attack power with live buffs, and marks less damage taken as a bonus")

func _talismans() -> void:
	## Ngọc bội: data, rolls, the three slots, set bonuses, the profile migration and the full pouch.
	var data: Dictionary = Talismans.data()
	var pieces: Dictionary = data["pieces"]
	var data_ok: bool = (data["sets"] as Dictionary).size() >= 4 and Talismans.slots().size() == 3
	var coverage: Dictionary = {}
	for id: String in pieces:
		var main: String = String(pieces[id]["main"][0])
		data_ok = data_ok and not Talismans.set_info(String(pieces[id]["set"])).is_empty() and Talismans.slot_index(id) >= 0
		data_ok = data_ok and PlayerStats.AFFIX_STATS.has(main) and PlayerStats.affix_allowed(main, "talisman")
		coverage["%s:%s" % [pieces[id]["set"], pieces[id]["slot"]]] = true
	for set_id: String in data["sets"]:
		data_ok = data_ok and Talismans.set_info(set_id).has("2") and Talismans.set_info(set_id).has("3")
		for slot: Dictionary in Talismans.slots():
			data_ok = data_ok and coverage.has("%s:%s" % [set_id, slot["id"]])
	check(data_ok and pieces.size() >= 12, "%d talisman pieces across four sets, each set with a piece per slot and 2- and 3-piece bonuses" % pieces.size())
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2843
	var table: Dictionary = ContentDB.get_data("affixes")
	var rolls_ok: bool = true
	for rarity: String in ["r", "sr", "ssr"]:
		for id: String in pieces:
			for attempt: int in range(25):
				var item: Dictionary = Talismans.make(id, rarity, rng)
				var span: Vector2i = Talismans.main_span(id, rarity)
				var subs: Array = item["subs"]
				rolls_ok = rolls_ok and item["main"][0] == pieces[id]["main"][0] and int(item["main"][1]) >= span.x and int(item["main"][1]) <= span.y
				rolls_ok = rolls_ok and subs.size() == int(Talismans.rarity_info(rarity)["substats"])
				var seen: Dictionary = {String(item["main"][0]): true}
				for affix: Array in subs:
					var bounds: Array = table[affix[0]]["range"]
					rolls_ok = rolls_ok and not seen.has(affix[0]) and int(affix[1]) >= int(bounds[0]) and int(affix[1]) <= int(bounds[1])
					seen[affix[0]] = true
	check(rolls_ok, "Rolled talismans keep the main stat in its rarity range and 1/2/3 distinct in-range substats by rarity")
	var swords_ok: bool = not PlayerStats.affix_allowed("reaction_dmg", "sword") and PlayerStats.affix_allowed("reaction_dmg", "talisman")
	for attempt: int in range(300):
		for affix: Array in Gacha.make_weapon("sword_flame", "ssr", rng):
			swords_ok = swords_ok and PlayerStats.affix_allowed(String(affix[0]), "sword")
	check(swords_ok, "Talisman-only affixes (reaction damage) never roll on swords")
	var tally: Dictionary = {"r": 0, "sr": 0, "ssr": 0}
	for attempt: int in range(5000):
		tally[Talismans.roll_rarity(Talismans.source_weights("enemy"), rng)] += 1
	check(absf(tally["r"] / 5000.0 - 0.76) < 0.03 and absf(tally["ssr"] / 5000.0 - 0.04) < 0.015, "Enemy talisman rarities follow the data weights (%d/%d/%d)" % [tally["r"], tally["sr"], tally["ssr"]])
	# Three slots, one per piece type; a piece replaces whatever sits in its own slot.
	var profile: PlayerProfile = PlayerProfile.new()
	var bell: Dictionary = profile.add_talisman({"piece": "phong_linh_thien", "rarity": "sr", "main": ["skill_cd", 6], "subs": [["crit_rate", 4], ["defense", 10]]})
	var chime: Dictionary = profile.add_talisman({"piece": "phong_linh_dia", "rarity": "r", "main": ["meter_gain", 10], "subs": [["atk_pct", 5]]})
	var tassel: Dictionary = profile.add_talisman({"piece": "phong_linh_nhan", "rarity": "r", "main": ["stamina_regen", 12], "subs": [["move_speed", 4]]})
	var hoop: Dictionary = profile.add_talisman({"piece": "kim_cuong_thien", "rarity": "ssr", "main": ["defense", 24], "subs": [["lifesteal", 3], ["crit_dmg", 15], ["poise_dmg", 12]]})
	var filled: bool = profile.equip_talisman(int(bell["uid"])) and profile.equip_talisman(int(chime["uid"])) and profile.equip_talisman(int(tassel["uid"]))
	check(filled and profile.equipped_talismans().size() == 3 and profile.talisman_equipped == [bell["uid"], chime["uid"], tassel["uid"]],
		"Three talismans fill the Thiên, Địa and Nhân slots")
	var three: Dictionary = PlayerStats.compute({}, {}, profile.equipped_talismans())
	check(is_equal_approx(float(three["skill_cd"]), 0.06 + 0.10 + 0.05) and is_equal_approx(float(three["meter_gain"]), 0.10 + 0.25) and is_equal_approx(float(three["defense"]), 10.0)
		and is_equal_approx(float(three["crit_rate"]), 0.04) and is_equal_approx(float(three["stamina_regen"]), 0.12) and is_equal_approx(float(three["attack_bonus"]), 0.05),
		"Three Phong Linh pieces add main stats, substats and both the 2- and 3-piece bonuses")
	check(profile.equip_talisman(int(hoop["uid"])) and int(profile.talisman_equipped[0]) == int(hoop["uid"]) and not profile.is_worn(int(bell["uid"])) and not profile.equip_talisman(9999),
		"A piece replaces the one in its own slot; an unknown talisman is refused")
	var two: Dictionary = PlayerStats.compute({}, {}, profile.equipped_talismans())
	var summary: Array[Dictionary] = Talismans.set_summary(profile.equipped_talismans())
	check(is_equal_approx(float(two["skill_cd"]), 0.10) and is_equal_approx(float(two["meter_gain"]), 0.10) and is_equal_approx(float(two["defense"]), 24.0)
		and is_equal_approx(float(two["lifesteal"]), 0.03) and is_equal_approx(float(two["poise_dmg"]), 0.12) and summary.size() == 2,
		"Two Phong Linh pieces keep only the 2-piece bonus; a lone Kim Cương piece adds no set bonus")
	check(is_equal_approx(float(PlayerStats.compute({"base": "sword_flame", "rarity": "sr", "affixes": [["skill_cd", 5]]}, {"skill_cd": 0.12}, profile.equipped_talismans())["skill_cd"]), 0.27),
		"Talismans stack with the armory sword and Trial blessings")
	profile.unequip_talisman(0)
	check(profile.equipped_talismans().size() == 2 and int(profile.talisman_equipped[0]) == -1 and not profile.unequip_talisman(0), "A slot can be emptied")
	# Profile v1 -> v2: the old file keeps everything and gains an empty pouch.
	_remove(PROFILE)
	var v1: Dictionary = {"version": 1, "currency": {"ngoc_gio": 320, "manh_ky_ngo": 12}, "pity": {"ngu_hanh": {"since_ssr": 41, "since_sr": 3, "guaranteed": true, "total": 77}},
		"history": [{"banner": "ngu_hanh", "rarity": "sr", "label": "Lôi Minh Kiếm · Hiếm", "time": "2026-10-01T10:00:00"}],
		"armory": [{"uid": 4, "base": "sword_thunder", "rarity": "sr", "affixes": [["crit_rate", 5], ["atk_pct", 8]], "skin": ""}], "next_uid": 5,
		"skins": ["lam_an_mac_truc"], "equipped_skins": {"player": "lam_an_mac_truc", "weapon": ""}, "trial": {"best_wave": 7, "runs": 3, "milestones": [5]},
		"daily": {"date": "", "missions": [], "bonus_claimed": false}, "login": {"last": "2026-10-16", "streak": 2, "claimed": "2026-10-16"},
		"rng": {"seed": "2844", "state": "123456789"}, "welcomed": true}
	var file: FileAccess = FileAccess.open(PROFILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(v1, "\t"))
	file.close()
	var migrated: PlayerProfile = PlayerProfile.load_file(PROFILE)
	check(migrated.balance("ngoc_gio") == 320 and migrated.balance("manh_ky_ngo") == 12 and int(migrated.pity["ngu_hanh"]["since_ssr"]) == 41 and migrated.pity["ngu_hanh"]["guaranteed"]
		and migrated.weapon(4).get("rarity") == "sr" and migrated.history.size() == 1 and migrated.skins == ["lam_an_mac_truc"] and int(migrated.trial["best_wave"]) == 7
		and migrated.welcomed and migrated.rng_seed == 2844 and migrated.rng_state == 123456789 and migrated.next_uid == 5,
		"A version 1 profile migrates, keeping currency, pity, history, armory, outfits, records and the RNG")
	check(migrated.talismans.is_empty() and migrated.talisman_equipped == [-1, -1, -1], "The migrated profile gains an empty Ngọc bội pouch and three empty slots")
	var kept: Dictionary = migrated.add_talisman(Talismans.make("huyet_ngoc_thien", "ssr", rng))
	migrated.equip_talisman(int(kept["uid"]))
	check(int(kept["uid"]) == 5 and migrated.save_file(PROFILE) == OK and int(SaveStore.read_json(PROFILE, func(raw: Variant) -> Dictionary: return raw)["version"]) == 2
		and int(SaveStore.read_json(PROFILE + ".bak", func(raw: Variant) -> Dictionary: return raw)["version"]) == 1,
		"The migrated profile saves as version 2 and keeps the version 1 file as its backup")
	var reloaded: PlayerProfile = PlayerProfile.load_file(PROFILE)
	check(reloaded.talisman(int(kept["uid"])) == kept and reloaded.talisman_equipped == migrated.talisman_equipped and reloaded.next_uid == 6 and reloaded.balance("ngoc_gio") == 320,
		"Talismans, their rolls and the worn slots survive a reload")
	var future: Dictionary = migrated.to_dict()
	future["version"] = 3
	check(PlayerProfile.validate(future).is_empty() and not PlayerProfile.validate(migrated.to_dict()).is_empty(), "A profile from a newer version is refused")
	_remove(PROFILE)
	# A full pouch salvages the lowest-rarity candidate, never a worn talisman.
	var full: PlayerProfile = PlayerProfile.new()
	for index: int in range(Talismans.capacity()):
		full.add_talisman({"piece": "kim_cuong_dia", "rarity": "r" if index < 2 else "sr", "main": ["poise_dmg", 12], "subs": []})
	var worn_uid: int = int(full.talismans[0]["uid"])
	var spare_uid: int = int(full.talismans[1]["uid"])
	full.equip_talisman(worn_uid)
	var plain: Dictionary = Talismans.grant(full, Talismans.make("loi_van_dia", "r", rng))
	check(not plain["kept"] and int(plain["coins"]) == Talismans.salvage_value("r") and full.talismans.size() == Talismans.capacity(),
		"A full pouch turns a new Thường talisman straight into %d Đồng" % Talismans.salvage_value("r"))
	var better: Dictionary = Talismans.grant(full, Talismans.make("loi_van_dia", "ssr", rng))
	check(better["kept"] and int(better["salvaged"]["uid"]) == spare_uid and full.talisman(spare_uid).is_empty() and not full.talisman(worn_uid).is_empty()
		and full.talismans.size() == Talismans.capacity() and int(better["coins"]) == Talismans.salvage_value("r"),
		"A better drop into a full pouch salvages the oldest unworn lowest-rarity talisman; worn ones are kept")
	var even: Dictionary = Talismans.grant(full, Talismans.make("loi_van_dia", "sr", rng))
	check(not even["kept"] and int(even["coins"]) == Talismans.salvage_value("sr"), "When nothing unworn ranks lower, the new drop itself is salvaged")
	var sr_uid: int = int(full.talismans[2]["uid"])
	check(Talismans.salvage(full, worn_uid) == 0 and Talismans.salvage(full, sr_uid) == Talismans.salvage_value("sr") and full.talismans.size() == Talismans.capacity() - 1,
		"Salvaging refuses a worn talisman and pays an unworn one's value")
	# Drops use the profile RNG: the same saved state always gives the same talisman.
	var seeded: RandomNumberGenerator = RandomNumberGenerator.new()
	seeded.seed = 2845
	var lucky: PlayerProfile = PlayerProfile.new()
	lucky.rng_seed = 2845
	lucky.rng_state = seeded.state
	var before: int = lucky.rng_state
	var boss_drop: Dictionary = Talismans.drop(lucky, "boss", 1.0)
	var replay: PlayerProfile = PlayerProfile.new()
	replay.rng_seed = 2845
	replay.rng_state = before
	check(not boss_drop.is_empty() and Talismans.drop(replay, "boss", 1.0) == boss_drop and lucky.rng_state != before and Talismans.drop(lucky, "enemy", 0.0).is_empty(),
		"A boss always drops a talisman, the same saved RNG state rolls the same one, and a zero chance never drops")
	var chest: Dictionary = Talismans.from_chest(lucky, "boss_tier", "sr")
	check(chest.get("rarity", "") == "sr" and Talismans.from_chest(lucky, "missing", "r").is_empty(), "A Cảnh Giới chest always holds a talisman at the chest's rarity")

func _missions() -> void:
	var profile: PlayerProfile = PlayerProfile.new()
	check(Missions.refresh(profile, "2026-10-17") and profile.daily["missions"].size() == 4 and not Missions.refresh(profile, "2026-10-17"), "A new day rolls four daily missions once")
	var mission: Dictionary = profile.daily["missions"][0]
	check(Missions.claim(profile, 0) == 0, "An unfinished mission cannot be claimed")
	Missions.notify(profile, String(mission["event"]), int(mission["goal"]) + 5)
	check(int(mission["progress"]) == int(mission["goal"]) and Missions.claim(profile, 0) == int(mission["reward"]) and Missions.claim(profile, 0) == 0,
		"A finished mission pays once")
	check(Missions.refresh(profile, "2026-10-18") and int(profile.daily["missions"][0]["progress"]) == 0, "Missions reset on the next day")
	var rewards: Array = ContentDB.get_data("daily")["login"]
	check(Missions.claim_login(profile, "2026-10-17") == int(rewards[0]) and Missions.claim_login(profile, "2026-10-17") == 0, "Login reward pays once a day")
	check(Missions.claim_login(profile, "2026-10-18") == int(rewards[1]), "Consecutive days continue the login streak")
	check(Missions.claim_login(profile, "2026-10-20") == int(rewards[0]), "A missed day restarts the login streak")

func _consumables() -> void:
	var items: Dictionary = ContentDB.get_data("items")
	var data_ok: bool = true
	for id: String in items:
		var effect: Dictionary = Consumables.effect(id)
		if effect.has("buff") and StatusEffects.kind_of(String(effect["buff"])) != "buff":
			data_ok = false
		for cured: Variant in effect.get("cleanse", []):
			data_ok = data_ok and not ContentDB.status(String(cured)).is_empty()
	for enemy: String in ContentDB.get_data("enemies"):
		for drop: Array in ContentDB.enemy(enemy).get("drops", []):
			data_ok = data_ok and (drop[0] == "coins" or drop[0] == Talismans.DROP or items.has(drop[0]))
	for table: Dictionary in (Gacha.data()["chests"] as Dictionary).values():
		for supply: Array in table.get("supplies", []):
			data_ok = data_ok and Consumables.usable(String(supply[0]))
	var offers: Array[Dictionary] = Consumables.offers("quay_thuoc")
	check(data_ok and offers.size() == (Consumables.shop("quay_thuoc")["items"] as Array).size()
		and offers.all(func(offer: Dictionary) -> bool: return Consumables.usable(String(offer["item"])) and int(offer["price"]) > 0),
		"Consumable buffs and cures name real statuses, drops and chest supplies real items, and the counter prices every shelf item")
	check(Consumables.shop_price("quay_thuoc", "banh_ngai") == 12 and Consumables.shop_price("quay_thuoc", "tra_sen") == int(items["tra_sen"]["price"])
		and Consumables.shop_price("quay_thuoc", "da_gio") == -1, "A shelf price overrides the item's own, null falls back to it, unsold items have none")
	var heals: Array[String] = Consumables.heal_items()
	var state: GameState = GameState.new()
	var none: String = Consumables.best_heal(state)
	state.add_item("banh_ngai", 2)
	var weak_only: String = Consumables.best_heal(state)
	state.add_item("tra_sen", 1)
	check(heals.size() == 2 and heals[0] == "tra_sen" and heals[1] == "banh_ngai" and none == "" and weak_only == "banh_ngai" and Consumables.best_heal(state) == "tra_sen",
		"Healing items rank strongest first: R takes Trà sen before Bánh ngải, and Bánh ngải when it is all that is left")
	state.coins = 50
	var price: int = Consumables.shop_price("quay_thuoc", "kim_cang_dan")
	check(Consumables.buy(state, "kim_cang_dan", price) and state.coins == 50 - price and state.count("kim_cang_dan") == 1, "Buying deducts the price in Đồng and adds the item")
	var coins: int = state.coins
	check(not Consumables.buy(state, "bao_huyet_dan", Consumables.shop_price("quay_thuoc", "bao_huyet_dan")) and state.coins == coins and state.count("bao_huyet_dan") == 0,
		"A purchase the coins cannot cover is refused and changes nothing")
	state.quick_item = "kim_cang_dan"
	var save: Dictionary = {"version": SaveStore.SCHEMA_VERSION, "seed": 284, "position": [1.0, 2.0, 3.0], "checkpoint": [1.0, 2.0, 3.0], "state": state.to_dict()}
	save.merge(WeatherDirector.initial_save(284))
	var loaded: GameState = GameState.new()
	loaded.from_dict(save["state"])
	check(SaveStore.validate(save) and loaded.quick_item == "kim_cang_dan", "The quick slot is saved with the game state")
	var older: Dictionary = save.duplicate(true)
	(older["state"] as Dictionary).erase("quick_item")
	loaded.from_dict(older["state"])
	check(SaveStore.validate(older) and loaded.quick_item == "", "A save from before the quick slot still loads, with the slot empty")
	save["state"]["quick_item"] = "da_gio"
	loaded.from_dict(save["state"])
	check(loaded.quick_item == "", "A material on the quick slot is dropped on load")
	save["state"]["quick_item"] = 7
	check(not SaveStore.validate(save), "A non-text quick slot is rejected")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2842
	var supplies: Array = Gacha.chest_supplies("boss_tier", rng)
	check(supplies.any(func(entry: Array) -> bool: return entry[0] == "tra_sen" and int(entry[1]) >= 1) and Gacha.chest_supplies("missing", rng).is_empty(),
		"A Cảnh Giới chest always carries Trà sen; an unknown table carries nothing")

func _settle(game: Node) -> void:
	for index: int in range(3000):
		var world: WorldManager = game.world
		if world.active.size() == game.settings.chunk_capacity() and world.building.is_empty() and world.pending.is_empty():
			break
		await frames(1)
	await frames(10)

func _kill(game: Node, enemy: Enemy) -> void:
	enemy.take_damage(Combat.make_damage(game.player, {"poise": 0}, 999999.0, enemy.global_position))

func _wait_action(player: PlayerController) -> void:
	for attempt: int in range(120):
		if player.state != "action":
			break
		await frames(1)

func _items_scene(game: Node) -> void:
	## Consumables through the real player, inventory actions, save and the village counter.
	var player: PlayerController = game.player
	var state: GameState = game.state
	var effect: Dictionary = Consumables.effect("kim_cang_dan")
	state.add_item("kim_cang_dan", 1)
	check(player.consume_item("kim_cang_dan") and state.count("kim_cang_dan") == 0 and player.statuses.has("buff_def")
		and is_equal_approx(float(player.statuses.active["buff_def"]["duration"]), float(effect["duration"])) and is_equal_approx(state.stat("damage_taken"), -0.25),
		"Kim Cang Đan spends the pill and puts Kim cang on Lâm An for its %d s" % int(effect["duration"]))
	player._tick_statuses(float(effect["duration"]) - 1.0)
	var lasting: bool = player.statuses.has("buff_def")
	player._tick_statuses(1.5)
	check(lasting and not player.statuses.has("buff_def") and is_equal_approx(state.stat("damage_taken"), 0.0), "The buff ends when the item's time runs out")
	state.add_item("giai_doc_thao", 1)
	var idle_refusal: String = player.item_refusal("giai_doc_thao")
	player.apply_status("poison", 2)
	player.apply_status("bleed", 3)
	check(idle_refusal != "" and player.item_refusal("giai_doc_thao") == "" and player.consume_item("giai_doc_thao") and not player.statuses.has("poison") and not player.statuses.has("bleed"),
		"Giải Độc Thảo is kept while there is nothing to cure, then removes poison and bleeding")
	state.add_item("hoa_on_dan", 1)
	player.apply_status("chill", 1)
	player.consume_item("hoa_on_dan")
	check(not player.statuses.has("chill") and player.statuses.has("buff_warm") and is_equal_approx(player.status_resistance("frost"), 0.5),
		"Hỏa Ôn Đan thaws chill and leaves frost resistance behind")
	player.cleanse(player.statuses.active.keys())
	# R takes the strongest heal with the old interact timing.
	for heal: String in ["banh_ngai", "tra_sen"]:
		state.inventory.erase(heal)
		state.add_item(heal, 1)
	player.health = player.max_health() * 0.2
	player._try_heal()
	var picked: String = String(player.action.get("item", ""))
	await _wait_action(player)
	check(picked == "tra_sen" and state.count("tra_sen") == 0 and state.count("banh_ngai") == 1 and is_equal_approx(player.health, player.max_health() * 0.85),
		"R uses the strongest healing item first (Trà sen, +65%)")
	game._refresh_hud()
	check(game.hud.heal_label.text == "%s  •  Bánh ngải ×1  •  Trà sen ×0" % UserSettings.event_label("heal"), "The heal counter lists the healing items from data")
	# The quick slot (C) uses the chosen consumable and keeps the choice when the stack runs out.
	game.set_quick_item("tinh_tam_tra")
	state.add_item("tinh_tam_tra", 1)
	player.queue_input("item")
	await frames(2)
	await _wait_action(player)
	check(state.count("tinh_tam_tra") == 0 and player.statuses.has("buff_resist") and is_equal_approx(state.stat("status_resist"), 0.5) and state.quick_item == "tinh_tam_tra",
		"The quick-use key drinks Tịnh Tâm Trà and the slot stays set")
	player._try_quick_item()
	game._refresh_hud()
	check(player.state == "move" and game.hud.quick_label.text.ends_with("Tịnh Tâm Trà ×0"), "An empty quick slot refuses and the HUD shows the stack at zero")
	check(game.save_game(true), "Saving with a quick slot set")
	state.quick_item = ""
	check(game.load_game() and game.state.quick_item == "tinh_tam_tra", "The quick slot survives a save and reload")
	await frames(2)
	state.add_item("khinh_than_tan", 1)
	check(game.use_item("khinh_than_tan") == "" and player.statuses.has("buff_speed") and state.count("khinh_than_tan") == 0 and game.use_item("khinh_than_tan") != "",
		"Inventory 'Dùng' applies a tonic at once; an empty stack is refused")
	var chest: Interactable = game.spawn_reward_chest("boss_tier", player.global_position + Vector3(3, 0, 0))
	var sen: int = state.count("tra_sen")
	var opened: Dictionary = game.open_reward_chest(chest, true)
	check(state.count("tra_sen") > sen and not (opened.get("supplies", []) as Array).is_empty(), "A reward chest adds its consumable supplies to the bag")
	var found: Dictionary = opened.get("talisman", {})
	check(found.get("kept", false) and found["item"]["rarity"] == chest.entity["rarity"] and not game.profile.talisman(int(found["item"]["uid"])).is_empty(),
		"A Cảnh Giới chest also holds a Ngọc bội of its own rarity, kept in the profile")
	chest.queue_free()
	# Ông Lang Vân's counter: dialogue choice -> shop panel -> purchases with Đồng.
	var merchant: Npc = null
	for attempt: int in range(120):
		game.spawner.update_now()
		merchant = game.spawner.node_for("npc_lang_van") as Npc
		if merchant:
			break
		await frames(1)
	if merchant == null:
		check(false, "Ông Lang Vân keeps a medicine counter on the village plaza")
		return
	# Standing at the front of his stall is close enough to talk across the counter.
	var gate: Vector3 = player.global_position
	player.teleport(Vector3(-11.7, game.world.height_at(-11.7, 29.0) + 0.3, 29.0))
	player.face_direction(Vector3(-1, 0, 0), true)
	await frames(8)
	game._update_focus()
	check(merchant.display_name == "Ông Lang Vân" and game.focus == merchant and player.global_position.x > -12.0,
		"Ông Lang Vân keeps a counter on the village plaza, reachable from the front of his stall")
	game.spawner.update_now()
	check(merchant.bark_label.visible and (merchant.entity["barks"] as Array).has(merchant.bark_label.text), "He calls out his wares when Lâm An comes near")
	game.start_dialogue(merchant)
	for step: int in range(10):
		if game.dialogue.is_empty() or game.dialogue.has("choices"):
			break
		game._advance_dialogue()
	if game.dialogue.has("choices"):
		game._choose_dialogue(0)
	check(game.menus.current_panel == "shop" and game.get_tree().paused and game.dialogue.is_empty(), "Choosing 'Xem quầy thuốc' opens the counter")
	var price: int = Consumables.shop_price("quay_thuoc", "bao_huyet_dan")
	state.coins = price - 5
	var refusal: String = game.buy_item("quay_thuoc", "bao_huyet_dan")
	check(refusal != "" and state.coins == price - 5 and state.count("bao_huyet_dan") == 0 and (game.hud.toast.text == refusal or game.hud.toast_queue.has(refusal)),
		"Short of Đồng, the counter refuses with a notice and nothing changes")
	state.coins = price + 30
	check(game.buy_item("quay_thuoc", "bao_huyet_dan") == "" and state.coins == 30 and state.count("bao_huyet_dan") == 1, "Buying at the counter deducts the price and adds the item")
	game.menus.refresh_panel()
	game.menus.close_panel()
	check(game.menus.current_panel == "" and not game.get_tree().paused and not game.menus.pause_panel.visible, "Closing the counter returns straight to play")
	player.revive(gate)
	await frames(2)

func _talisman_scene(game: Node) -> void:
	## Worn Ngọc bội reach GameState.stats, the Nhân vật sheet and the armory tab; salvage pays Đồng.
	var profile: PlayerProfile = game.profile
	var state: GameState = game.state
	for attempt: int in range(300):
		if game.player.state == "move":
			break
		await frames(1)
	var uids: Array[int] = []
	for entry: Array in [["kim_cuong_thien", ["defense", 12]], ["kim_cuong_dia", ["poise_dmg", 15]], ["kim_cuong_nhan", ["max_stamina", 14]]]:
		uids.append(int(profile.add_talisman({"piece": entry[0], "rarity": "r", "main": entry[1], "subs": []})["uid"]))
	var worn: bool = true
	for uid: int in uids:
		worn = game.equip_talisman(uid) and worn
	check(worn and is_equal_approx(state.stat("defense"), 12.0 + 25.0) and is_equal_approx(state.stat("poise_dmg"), 0.15 + 0.30) and is_equal_approx(state.stat("status_resist"), 0.15)
		and is_equal_approx(state.max_stamina(), GameState.BASE_STAMINA + 14.0), "Three Kim Cương talismans fold their main stats and both set bonuses into the game's stats")
	var rows: Dictionary = {}
	for row: Dictionary in PlayerStats.sheet(state):
		if not row.has("header"):
			rows[String(row["stat"])] = row
	check(rows["defense"]["value"] == "37" and int(rows["poise_dmg"]["tone"]) == 1 and rows.has("reaction_dmg"), "The Nhân vật tab shows the talisman totals")
	game.menus.armory_tab = 1
	game.open_panel("armory")
	await frames(2)
	var tabs: TabContainer = game.menus.panel_body.find_child("ArmoryTabs", true, false)
	check(tabs != null and tabs.current_tab == 1 and tabs.get_current_tab_control().name == "Ngọc bội" and game.get_tree().paused, "The armory opens on its Ngọc bội tab")
	var coins: int = state.coins
	check(game.salvage_talisman(uids[0]) != "" and not profile.talisman(uids[0]).is_empty(), "A worn talisman cannot be salvaged")
	check(game.unequip_talisman(0) and is_equal_approx(state.stat("defense"), 25.0) and is_equal_approx(state.stat("status_resist"), 0.0),
		"Taking one piece off keeps the 2-piece bonus and drops the 3-piece one")
	check(game.salvage_talisman(uids[0]) == "" and profile.talisman(uids[0]).is_empty() and state.coins == coins + Talismans.salvage_value("r"),
		"Salvaging an unworn talisman pays its Đồng into the save")
	game.menus.refresh_panel()
	game.menus.close_panel()
	game.menus.armory_tab = 0
	game.set_paused(false)
	# The full Huyết Ngọc set heals on a world kill (heal_on_kill used to be Trial-only).
	var blood: Array[int] = []
	for entry: Array in [["huyet_ngoc_thien", ["lifesteal", 2]], ["huyet_ngoc_dia", ["heal_bonus", 10]], ["huyet_ngoc_nhan", ["atk_pct", 4]]]:
		blood.append(int(profile.add_talisman({"piece": entry[0], "rarity": "r", "main": entry[1], "subs": []})["uid"]))
		game.equip_talisman(blood[-1])
	var foe: Enemy = EnemyFactory.create(ContentDB.enemy("tan_binh"))
	game.add_child(foe)
	foe.setup({"id": "test_talisman_foe", "enemy": "tan_binh", "camp": "", "yaw": 0.0}, game.assets, game.world)
	foe.global_position = game.player.global_position + Vector3(2, 0, 0)
	game.player.health = game.player.max_health() * 0.5
	# No level-up from this kill: its full heal would hide the set's heal.
	state.xp = 0
	game.on_enemy_defeated(foe, {"id": "test_talisman_foe", "enemy": "tan_binh"})
	check(is_equal_approx(state.stat("heal_on_kill"), 0.05) and is_equal_approx(game.player.health, game.player.max_health() * 0.55),
		"Three Huyết Ngọc pieces heal 5% of max health on a world kill")
	foe.queue_free()
	for slot: int in range(3):
		game.unequip_talisman(slot)
	check(profile.equipped_talismans().is_empty() and state.stats.is_empty(), "With every slot empty the stats are neutral again")
	await frames(2)

func _scene() -> void:
	var save: String = "user://progression_test_save.json"
	_remove(save)
	_remove(PROFILE)
	var game: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	game.skip_title = true
	game.save_path = save
	game.profile_path = PROFILE
	root.add_child(game)
	for attempt: int in range(900):
		if game.initialized:
			break
		await frames(1)
	if not game.initialized:
		check(false, "Game initializes for the progression scene checks")
		return
	await _settle(game)
	var player: PlayerController = game.player
	var trial: TrialDirector = game.trial
	check(game.profile.balance(Gacha.currency()) == int(Gacha.data()["welcome"]), "A first run grants the welcome Ngọc Gió once")
	await _items_scene(game)
	var flags_before: int = game.state.flags.size()
	var kills_before: int = game.state.camp_kills.size()
	var gate: Vector3 = player.global_position
	trial.start(gate)
	await frames(2)
	check(game.world.layout.in_pocket(player.global_position.x, player.global_position.z), "The Trial gate takes the player into the arena pocket")
	for attempt: int in range(1500):
		if trial.phase == "fighting" and trial.alive.size() > 0:
			break
		await frames(1)
	await frames(2)
	check(trial.wave == 1 and trial.alive.size() == 3, "Wave 1 brings three foes (%d)" % trial.alive.size())
	check(not game.save_game(true), "Saving is refused during a Trial run")
	for enemy: Enemy in trial.alive.duplicate():
		_kill(game, enemy)
	for attempt: int in range(120):
		if trial.phase == "picking":
			break
		await frames(1)
	check(trial.phase == "picking" and game.menus.current_panel == "trial_pick" and game.get_tree().paused, "Clearing a wave pauses on the blessing picker")
	game.menus.close_panel()
	check(game.menus.current_panel == "trial_pick", "Esc cannot dismiss the blessing picker")
	var blessing: Dictionary = {}
	for entry: Dictionary in ContentDB.get_data("trial")["buffs"]["pool"]:
		if entry["id"] == "kiem_phong":
			blessing = entry
	game.choose_trial_buff(blessing)
	check(not game.get_tree().paused and is_equal_approx(game.state.stat("melee_mult"), 0.15), "Choosing Kiếm Phong resumes with +15% basic-hit damage")
	for attempt: int in range(1500):
		if trial.wave == 2 and trial.alive.size() > 0:
			break
		await frames(1)
	if not trial.alive.is_empty():
		var target: Enemy = trial.alive[0]
		var result: Dictionary = player.strike(target, {"mult": 1.0}, 1.0)
		check(is_equal_approx(float(result.get("amount", 0.0)), game.state.attack_power() * 1.15), "Kiếm Phong raises the next basic hit by 15%")
	# The gear-stat blessings stack per pick up to their limit, like the old ones.
	var pool: Dictionary = {}
	for entry: Dictionary in ContentDB.get_data("trial")["buffs"]["pool"]:
		pool[entry["id"]] = entry
	for id: String in ["thiet_bi", "huyet_kiem", "tat_kiem", "pha_the"]:
		trial.choose(pool[id])
		trial.choose(pool[id])
	var doubled: bool = ["thiet_bi", "huyet_kiem", "tat_kiem", "pha_the"].all(func(id: String) -> bool:
		return is_equal_approx(game.state.stat(String(pool[id]["stat"])), float(pool[id]["value"]) * 2.0))
	check(doubled and is_equal_approx(game.state.stat("melee_mult"), 0.15) and is_equal_approx(player.attack_rate(), 1.0 + float(pool["tat_kiem"]["value"]) * 2.0),
		"Thiết Bì, Huyết Kiếm, Tật Kiếm and Phá Thế stack twice into the run's stats")
	trial.choose(pool["thiet_bi"])
	var offered: bool = false
	for attempt: int in range(40):
		offered = offered or trial.pick_choices().any(func(entry: Dictionary) -> bool: return entry["id"] == "thiet_bi")
	check(is_equal_approx(game.state.stat("defense"), float(pool["thiet_bi"]["value"]) * 3.0) and not offered, "A blessing at its limit is no longer offered")
	trial.wave = 5
	var boss: Enemy = trial._spawn("truc_tuong")
	check(boss.boss and is_equal_approx(boss.max_health, 950.0 * trial.wave_scale(5).x), "The fifth-wave guardian's health follows the wave scaling")
	player.health = 0.0
	player._die()
	for attempt: int in range(600):
		if not trial.active:
			break
		await frames(1)
	check(not trial.active and not game.world.layout.in_pocket(player.global_position.x, player.global_position.z) and not player.is_dead(),
		"Falling ends the run and returns Lâm An to the gate")
	check(game.state.camp_kills.size() == kills_before and not game.state.flags.keys().any(func(key: String) -> bool: return key.begins_with("dead:")) and game.state.flags.size() == flags_before,
		"A Trial run writes no story flags or camp kills")
	check(int(game.profile.trial["best_wave"]) >= 1 and game.profile.balance(Gacha.currency()) > int(Gacha.data()["welcome"]) and game.state.stats.is_empty(),
		"The run pays its banked Ngọc Gió, records the best wave and drops its blessings")
	await _talisman_scene(game)
	# World Tier 1 after the story slice: the guardian returns stronger and is remembered per tier.
	game.state.set_flag("slice_complete")
	game.state.set_flag("chimes_solved")
	check(game.set_world_tier(1) and game.state.world_tier == 1, "World Tier 1 opens after the story slice")
	player.teleport(Vector3(0, game.world.height_at(0, -312) + 0.5, -312))
	await _settle(game)
	var guardian: Enemy = null
	for attempt: int in range(600):
		guardian = game.spawner.node_for("boss_truc_tuong") as Enemy
		if guardian:
			break
		await frames(1)
	check(guardian != null and is_equal_approx(guardian.max_health, 950.0 * 1.7), "At tier 1 Trúc Tướng returns with 1.7× health")
	if guardian:
		var ngoc: int = game.profile.balance(Gacha.currency())
		var pouch: int = game.profile.talismans.size()
		_kill(game, guardian)
		await frames(2)
		check(game.state.has_flag("tier_dead:1:boss_truc_tuong") and game.state.max_tier == 2 and game.profile.balance(Gacha.currency()) == ngoc + 80,
			"Beating the tier-1 guardian pays Ngọc Gió and opens tier 2")
		var announced: bool = game.hud.toast.text.begins_with("Nhận Ngọc bội") or game.hud.toast_queue.any(func(text: String) -> bool: return text.begins_with("Nhận Ngọc bội"))
		check(game.profile.talismans.size() == pouch + 1 and announced, "Trúc Tướng always drops a Ngọc bội, announced on screen")
	var elite: Enemy = Enemy.new()
	game.add_child(elite)
	elite.setup({"id": "test_elite", "enemy": "tan_binh", "camp": "test", "yaw": 0.0}, game.assets, game.world)
	EnemyScaler.make_elite(elite, ["thiet_giap"])
	check(is_equal_approx(elite.max_health, 70.0 * 1.5 * 1.6) and elite.has_node("EliteTag") and ContentDB.enemy("tan_binh")["hp"] == 70, "Elites gain affix health and a tag without touching shared data")
	elite.queue_free()
	game.queue_free()
	await frames(2)
	_remove(save)
	_remove(PROFILE)

