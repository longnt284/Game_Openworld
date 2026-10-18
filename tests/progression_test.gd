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
	_gacha()
	_stats()
	_missions()
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
	check(Gacha.pull(profile, banner, 1).is_empty() and profile.pity.is_empty(), "A pull without enough Ngọc Gió is refused and changes nothing")
	profile.add_currency(Gacha.currency(), Gacha.cost(banner, 10))
	var results: Array = Gacha.pull(profile, banner, 10)
	check(results.size() == 10 and profile.balance(Gacha.currency()) == 0 and int(profile.pity[banner]["total"]) == 10 and profile.history.size() == 10,
		"A ten-pull spends 1600 Ngọc Gió, records pity and history")
	check(results.any(func(result: Dictionary) -> bool: return result["rarity"] != "r"), "A ten-pull holds at least one rare result")
	profile.save_file(PROFILE)
	var loaded: PlayerProfile = PlayerProfile.load_file(PROFILE)
	check(loaded.pity[banner] == profile.pity[banner] and loaded.armory.size() == profile.armory.size(), "Pity and rolled weapons survive a profile reload")
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

func _settle(game: Node) -> void:
	for index: int in range(3000):
		var world: WorldManager = game.world
		if world.active.size() == game.settings.chunk_capacity() and world.building.is_empty() and world.pending.is_empty():
			break
		await frames(1)
	await frames(10)

func _kill(game: Node, enemy: Enemy) -> void:
	enemy.take_damage(Combat.make_damage(game.player, {"poise": 0}, 999999.0, enemy.global_position))

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
		_kill(game, guardian)
		await frames(2)
		check(game.state.has_flag("tier_dead:1:boss_truc_tuong") and game.state.max_tier == 2 and game.profile.balance(Gacha.currency()) == ngoc + 80,
			"Beating the tier-1 guardian pays Ngọc Gió and opens tier 2")
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

