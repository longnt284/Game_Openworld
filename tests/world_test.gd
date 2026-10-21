extends SceneTree
## World systems of Phase 2: the day–night clock and its phases, weather draws by region
## weights from a saved RNG, the Trial pocket's fixed weather, the "Thời tiết động" setting,
## smoothed levels and gameplay multipliers, the time:/weather: conditions, save schema v4 and
## its step-by-step migration; then in the running game: pausing, the HUD clock, the setting,
## shrine rest to dawn or dusk, the Trial pocket and saving and loading the clock.

var failures: int = 0
const SAVE: String = "user://world_test_save.json"
const PROFILE: String = "user://world_test_profile.json"
const SETTINGS: String = "user://world_test_settings.cfg"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int) -> void:
	for index: int in range(count):
		await physics_frame
		await process_frame

func _remove(path: String) -> void:
	for candidate: String in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)

func _run() -> void:
	_data()
	_clock()
	_weather()
	_levels()
	_conditions()
	_saves()
	await _scene()
	print("WORLD RESULT: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)

func _director(rng_seed: int, region: String = "") -> WeatherDirector:
	## A standalone director (not in the tree): tests drive it with advance().
	var director: WeatherDirector = WeatherDirector.new()
	director.reset(rng_seed)
	if region != "":
		director.set_region(region)
	return director

func _data() -> void:
	var data: Dictionary = WeatherDirector.data()
	var phases: Dictionary = data["phases"]
	var starts: Array[float] = []
	for id: String in WeatherDirector.PHASES:
		starts.append(float(phases[id]["start"]))
	var ordered: bool = starts[0] < starts[1] and starts[1] < starts[2] and starts[2] < starts[3] and starts[3] < 1.0
	var night: float = (1.0 - starts[3]) + starts[0]
	check(int(data["day_length"]) == 1440 and ordered and absf(night - 1.0 / 3.0) < 0.02,
		"One in-game day lasts 1440 s (24 min) with phases in order and night about a third of it (%.3f)" % night)
	var rules: Dictionary = data["weathers"]
	var rules_ok: bool = rules.size() == 6
	for id: String in ["clear", "cloudy", "rain", "storm", "fog", "wind"]:
		var rule: Dictionary = rules.get(id, {})
		rules_ok = rules_ok and String(rule.get("name", "")) != "" and rule.get("gameplay") is Dictionary and float(rule["duration"][0]) <= float(rule["duration"][1])
		for key: String in WeatherDirector.LEVELS:
			rules_ok = rules_ok and rule.has(key) and float(rule[key]) >= 0.0
		rules_ok = rules_ok and rule.has("lightning")
	check(rules_ok, "Six weathers, each with a name, a duration range, every render knob and gameplay rules")
	var regions_ok: bool = (data["regions"] as Dictionary).has("default")
	for region: String in data["regions"]:
		for key: String in data["regions"][region]:
			regions_ok = regions_ok and (rules.has(key) or (key == "fixed" and rules.has(String(data["regions"][region][key]))))
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/layout.json"))
	for region: Dictionary in layout["regions"]:
		regions_ok = regions_ok and (data["regions"] as Dictionary).has(String(region["id"]))
	check(regions_ok and data["regions"]["ao_canh"].get("fixed", "") == "clear", "Every region has weights naming real weathers, and the Trial pocket is fixed clear")
	var director: WeatherDirector = _director(1)
	check(director.day_phase() == "day" and director.hours() > 5.0 and director.hours() < 9.0 and director.weather_id() == "clear" and director.day == 1,
		"A new journey starts on a clear morning of day 1 (%s)" % director.clock_hhmm())
	director.free()

func _clock() -> void:
	var director: WeatherDirector = _director(2840)
	var start: float = director.time_of_day()
	var kinds: Array[String] = []
	director.changed.connect(func(kind: String) -> void: kinds.append(kind))
	director.advance(720.0)
	check(is_equal_approx(director.time_of_day(), start + 0.5) and director.day == 1, "Half a day of real time (12 min) moves the clock half a day")
	director.advance(720.0)
	check(absf(director.time_of_day() - start) < 0.0001 and director.day == 2, "The clock wraps past midnight and counts the next day")
	for step: int in range(3 * 48):
		director.advance(30.0)
	check(director.day == 5 and absf(director.time_of_day() - start) < 0.001, "Three more days of small steps land on day 5 at the same hour")
	check(kinds.has("phase"), "Crossing dusk, night and dawn signals the phase changes")
	var nights: int = 0
	var lights: int = 0
	for minute: int in range(1440):
		director.set_time(minute / 1440.0)
		if director.is_night():
			nights += 1
		if director.is_time("day"):
			lights += 1
	check(absf(nights / 1440.0 - 1.0 / 3.0) < 0.02 and nights + lights == 1440, "Night covers about a third of the day (%.1f of 24 min)" % (nights / 60.0))
	director.set_time(0.5)
	var noon: String = director.clock_text()
	var noon_hhmm: String = director.clock_hhmm()
	var noon_light: float = director.night_level()
	director.set_time(0.0)
	var midnight: String = director.clock_text()
	var midnight_light: float = director.night_level()
	director.set_time(20.0 / 24.0)
	var evening: String = director.clock_text()
	director.set_time(7.5 / 24.0)
	check(noon == "Giờ Ngọ" and midnight == "Giờ Tý" and evening == "Giờ Tuất" and noon_hhmm == "12:00" and director.clock_hhmm() == "07:30" and director.clock_text() == "Giờ Thìn",
		"The clock reads the traditional double hours (Ngọ at noon, Tý at midnight, Tuất at 20:00)")
	director.set_time(0.79)
	check(noon_light == 0.0 and midnight_light == 1.0 and director.night_level() > 0.0 and director.night_level() < 1.0 and director.day_phase() == "dusk",
		"Night light is 0 at noon, 1 at midnight and eases in across dusk")
	director.free()

func _sequence(director: WeatherDirector, steps: int) -> Array[String]:
	## Every draw (the RNG moved) as "weather@step", over steps of 30 s.
	var seen: Array[String] = []
	var drawn: int = director.rng.state
	for step: int in range(steps):
		director.advance(30.0)
		if director.rng.state != drawn:
			drawn = director.rng.state
			seen.append("%s@%d" % [director.world, step])
	return seen

func _weather() -> void:
	var first: WeatherDirector = _director(777, "truc_hai")
	var second: WeatherDirector = _director(777, "truc_hai")
	var a: Array[String] = _sequence(first, 600)
	var b: Array[String] = _sequence(second, 600)
	check(a.size() > 8 and a == b and first.to_save() == second.to_save(), "The same seed draws the same weather at the same moments (%d changes in 5 h)" % a.size())
	var other: WeatherDirector = _director(778, "truc_hai")
	check(_sequence(other, 600) != a, "A different seed draws a different sky")
	other.free()
	second.free()
	# Region weights: frequencies follow data/weather.json, zero weights never come up.
	var picker: WeatherDirector = _director(31)
	var regions: Dictionary = WeatherDirector.data()["regions"]
	var weights_ok: bool = true
	var village_storms: float = 0.0
	for region: String in ["ben_van_khe", "doi_gio", "truc_hai", "den_tich_phong", "vung_moi"]:
		picker.set_region(region)
		var weights: Dictionary = regions.get(region, regions["default"])
		var total: float = 0.0
		for id: String in weights:
			total += float(weights[id])
		var counts: Dictionary = {}
		for draw: int in range(6000):
			var id: String = picker.pick_next()
			counts[id] = int(counts.get(id, 0)) + 1
		for id: String in weights:
			var expected: float = float(weights[id]) / total
			weights_ok = weights_ok and absf(int(counts.get(id, 0)) / 6000.0 - expected) < 0.025
		weights_ok = weights_ok and counts.keys().all(func(id: String) -> bool: return weights.has(id))
		if region == "ben_van_khe":
			village_storms = int(counts.get("storm", 0)) / 6000.0
	check(weights_ok and village_storms < 0.04, "Draws follow each region's weights (unlisted regions use the default); the village rarely storms (%.1f%%)" % (village_storms * 100.0))
	picker.free()
	# The Trial pocket shows a fixed clear sky and leaves the valley's weather untouched.
	first.set_region("truc_hai")
	first.set_weather("rain", 0.0, 100.0)
	var before: Dictionary = first.to_save()["weather"]
	var hour: float = first.day + first.time_of_day()
	first.set_region("ao_canh")
	var shown: String = first.weather_id()
	var dry: float = first.rain()
	first.advance(600.0)
	check(shown == "clear" and dry == 0.0 and first.weather_id() == "clear" and first.to_save()["weather"] == before and first.day + first.time_of_day() > hour,
		"In the Trial pocket the sky is clear and the valley's rain waits untouched, RNG and all; the clock still turns")
	first.set_region("truc_hai")
	check(first.weather_id() == "rain" and is_equal_approx(first.rain(), float(WeatherDirector.data()["weathers"]["rain"]["rain"])), "Back in the valley the rain is there at once")
	# "Thời tiết động" off: clear sky, the valley's weather waits, the day still turns.
	first.set_weather("storm", 0.0, 50.0)
	first.set_dynamic(false)
	var cleared: String = first.weather_id()
	var clock: float = first.day + first.time_of_day()
	first.advance(3600.0)
	check(cleared == "clear" and first.weather_id() == "clear" and first.storm() == 0.0 and first.world == "storm" and is_equal_approx(first.remaining, 50.0) and first.day + first.time_of_day() > clock,
		"With dynamic weather off the sky stays clear for hours while the clock runs")
	first.set_dynamic(true)
	check(first.weather_id() == "storm", "Turning dynamic weather back on brings the waiting storm back")
	first.set_weather("fog", 0.0, 10.0)
	var state: int = first.rng.state
	first.advance(5.0)
	var halfway: float = first.remaining
	first.advance(6.0)
	check(is_equal_approx(halfway, 5.0) and first.rng.state != state and first.remaining > 0.0, "A weather counts down its seconds, then the next one is drawn")
	first.free()

func _levels() -> void:
	var director: WeatherDirector = _director(5)
	director.set_time(0.5)
	director.set_weather("clear")
	director.set_weather("storm", 20.0)
	var start: float = director.rain()
	director.advance(11.0)
	var middle: float = director.rain()
	var early: float = director.lightning_interval()
	director.advance(14.0)
	check(start == 0.0 and middle > 0.1 and middle < 0.9 and is_equal_approx(director.rain(), 1.0) and director.settled() and early == 12.0,
		"A storm rolls in over its transition (rain %.2f halfway), lightning once it is mostly in" % middle)
	check(is_equal_approx(director.element_mult("thunder"), 1.3) and is_equal_approx(director.element_mult("wind"), 1.15) and is_equal_approx(director.element_mult("flame"), 0.8)
		and is_equal_approx(director.element_mult("frost"), 1.0) and is_equal_approx(director.darkness(), 0.55) and director.soak_interval() > 0.0,
		"A storm: Lôi ×1.3, Phong ×1.15, Hỏa ×0.8, soaking, darker sky")
	director.set_weather("rain")
	check(is_equal_approx(director.element_mult("thunder"), 1.2) and is_equal_approx(director.element_mult("flame"), 0.8) and director.lightning_interval() == 0.0, "Rain: Lôi ×1.2, Hỏa ×0.8, no lightning")
	director.set_weather("fog")
	var fog_day: float = director.detect_mult()
	director.set_time(0.0)
	var fog_night: float = director.detect_mult()
	var night_reward: float = director.reward_mult()
	director.set_weather("clear")
	var clear_night: float = director.detect_mult()
	var dark: float = director.darkness()
	director.set_time(0.5)
	check(is_equal_approx(fog_day, 0.6) and is_equal_approx(clear_night, 0.8) and is_equal_approx(fog_night, 0.48) and is_equal_approx(director.detect_mult(), 1.0),
		"Enemy sight: fog ×0.6, night ×0.8, both ×0.48, a clear day ×1")
	check(is_equal_approx(night_reward, 1.25) and director.reward_mult() == 1.0 and dark == 1.0 and director.darkness() == 0.0 and director.soak_interval() == 0.0,
		"Night pays ×1.25; a clear noon is neither dark nor wet")
	director.free()

func _conditions() -> void:
	var quests: QuestManager = QuestManager.new()
	quests.setup(GameState.new(), Callable())
	check(quests.check(["time:day"]) and not quests.check(["time:night"]) and quests.check(["weather:clear"]), "Without a clock the conditions read a clear day")
	var director: WeatherDirector = _director(9)
	quests.weather = director
	director.set_time(0.9)
	var night: bool = quests.check(["time:night"]) and not quests.check(["time:day"]) and not quests.check(["!time:night"]) and quests.check(["!time:day"])
	director.set_time(0.2)
	var dawn: bool = quests.check(["time:dawn"]) and quests.check(["time:day"]) and not quests.check(["time:dusk"]) and not quests.check(["time:night"])
	director.set_weather("rain")
	var rain: bool = quests.check(["weather:rain"]) and not quests.check(["!weather:rain"]) and not quests.check(["weather:clear"]) and quests.check(["weather:rain", "time:dawn", "!flag:missing"])
	check(night and dawn and rain, "time:night, time:day, time:dawn, weather:<id> and their negations follow the clock and sky")
	check(not quests.check(["season:winter"]), "An unknown condition still fails (with a warning)")
	quests.free()
	director.free()

func _base_save(state: Dictionary = {}) -> Dictionary:
	## A save without the v4 clock: the shape of v3 (and of v2 once its state is trimmed).
	return {"version": SaveStore.SCHEMA_VERSION, "seed": 284, "position": [1.0, 2.0, 3.0], "checkpoint": [1.0, 2.0, 3.0], "yaw": 0.0,
		"state": state if not state.is_empty() else GameState.new().to_dict()}

func _saves() -> void:
	# The director round-trips through JSON and keeps drawing exactly as before.
	var director: WeatherDirector = _director(4242, "den_tich_phong")
	director.advance(5000.0)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(director.to_save()))
	var reloaded: WeatherDirector = WeatherDirector.new()
	reloaded.set_region("den_tich_phong")
	reloaded.from_save(saved)
	check(is_equal_approx(reloaded.time_of_day(), director.time_of_day()) and reloaded.day == director.day and reloaded.world == director.world
		and is_equal_approx(reloaded.remaining, director.remaining) and reloaded.rng.seed == director.rng.seed and reloaded.rng.state == director.rng.state,
		"Clock, day, weather, its seconds and the RNG survive a save (day %d, %s)" % [reloaded.day, reloaded.world])
	check(_sequence(reloaded, 400) == _sequence(director, 400), "A reloaded journey draws the same weather it would have: reloading cannot reroll the sky")
	reloaded.free()
	var full: Dictionary = _base_save()
	full.merge(director.to_save())
	check(SaveStore.SCHEMA_VERSION == 4 and SaveStore.validate(full) and SaveStore.validate(JSON.parse_string(JSON.stringify(full))), "A v4 save with its clock validates, also after JSON")
	director.free()
	var bad_ok: bool = not SaveStore.validate(_base_save())
	for broken: Array in [["time_of_day", 1.5], ["time_of_day", "noon"], ["day", 0], ["day", 2.5], ["weather", "rain"]]:
		var copy: Dictionary = full.duplicate(true)
		copy[broken[0]] = broken[1]
		bad_ok = bad_ok and not SaveStore.validate(copy)
	for broken: Array in [["id", 3], ["remaining", -1.0], ["seed", 12345], ["state", "abc"], ["seed", ""]]:
		var copy: Dictionary = full.duplicate(true)
		copy["weather"][broken[0]] = broken[1]
		bad_ok = bad_ok and not SaveStore.validate(copy)
	check(bad_ok, "A v4 save without its clock, or with a bad time, day, weather or RNG text, is rejected")
	# v3 -> v4: the journey keeps everything and wakes on a clear morning.
	var start: Dictionary = WeatherDirector.data()["start"]
	var v3_state: Dictionary = GameState.new().to_dict()
	v3_state["level"] = 6
	v3_state["flags"] = {"slice_complete": true}
	v3_state["quick_item"] = "tra_sen"
	var v3: Dictionary = _base_save(v3_state)
	v3["version"] = 3
	var migrated: Dictionary = SaveStore.migrate(JSON.parse_string(JSON.stringify(v3)))
	check(not migrated.is_empty() and int(migrated["version"]) == 4 and is_equal_approx(float(migrated["time_of_day"]), float(start["time"])) and int(migrated["day"]) == 1
		and migrated["weather"]["id"] == "clear" and int(migrated["state"]["level"]) == 6 and migrated["state"]["flags"].has("slice_complete") and migrated["state"]["quick_item"] == "tra_sen",
		"A v3 save migrates to v4 with its state intact, on a clear morning of day 1")
	var v2_state: Dictionary = GameState.new().to_dict()
	for key: String in ["swords", "equipped_uid", "world_tier", "max_tier", "quick_item"]:
		v2_state.erase(key)
	v2_state["sword"] = "sword_bamboo"
	var v2: Dictionary = _base_save(v2_state)
	v2["version"] = 2
	var from_v2: Dictionary = SaveStore.migrate(v2)
	check(not from_v2.is_empty() and int(from_v2["version"]) == 4 and from_v2["state"]["swords"] == ["sword_old", "sword_bamboo"] and int(from_v2["state"]["world_tier"]) == 0
		and from_v2.has("time_of_day") and from_v2["weather"]["id"] == "clear", "A v2 save steps through v3 (swords, tiers) to v4 (clock)")
	var from_v1: Dictionary = SaveStore.migrate({"version": 1, "seed": 284, "position": [3.0, 1.0, -5.0], "checkpoint": [3.0, 1.0, -5.0], "beacon_active": true})
	check(not from_v1.is_empty() and int(from_v1["version"]) == 4 and from_v1["state"]["checkpoint_id"] == "shrine_village" and from_v1["state"]["flags"].has("migrated_from_v1")
		and int(from_v1["day"]) == 1 and from_v1["label"] == "Bản nền cũ", "A v1 save steps through every version to v4")
	var future: Dictionary = full.duplicate(true)
	future["version"] = 5
	check(SaveStore.migrate(future).is_empty() and SaveStore.migrate({"version": 2}).is_empty(), "A save from a newer version, or a broken old one, is refused")
	# On disk: a v3 file reads as v4, and the first v4 write keeps the v3 file as the backup.
	_remove(SAVE)
	var file: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(v3, "\t"))
	file.close()
	var read: Dictionary = SaveStore.read_save(SAVE)
	check(not read.is_empty() and int(read["version"]) == 4 and SaveStore.write_save(read, SAVE) == OK
		and int(SaveStore.read_json(SAVE + ".bak", func(raw: Variant) -> Dictionary: return raw)["version"]) == 3 and not FileAccess.file_exists(SAVE + ".tmp"),
		"A v3 file loads as v4; saving writes through .tmp and keeps the v3 file as .bak")
	_remove(SAVE)

func _settle(game: Node) -> void:
	for index: int in range(3000):
		var world: WorldManager = game.world
		if world.active.size() == game.settings.chunk_capacity() and world.building.is_empty() and world.pending.is_empty():
			break
		await frames(1)
	game.spawner.update_now()
	await frames(10)

func _choices(game: Node) -> Array:
	return (game.dialogue.get("choices", []) as Array).map(func(choice: Array) -> String: return String(choice[0]))

func _scene() -> void:
	_remove(SAVE)
	_remove(PROFILE)
	var game: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	game.skip_title = true
	game.save_path = SAVE
	game.profile_path = PROFILE
	root.add_child(game)
	for attempt: int in range(900):
		if game.initialized:
			break
		await frames(1)
	if not game.initialized:
		check(false, "Game initializes for the world scene checks")
		return
	await _settle(game)
	var weather: WeatherDirector = game.weather
	var player: PlayerController = game.player
	var start: Dictionary = WeatherDirector.data()["start"]
	var since: float = weather.time_of_day() - float(start["time"])
	check(weather != null and weather.process_mode == Node.PROCESS_MODE_PAUSABLE and game.quests.weather == weather and weather.day == 1
		and since >= 0.0 and since < 0.05 and weather.weather_id() == "clear" and weather.region == "ben_van_khe",
		"A new game runs the clock from a clear morning, wired to the quests and fed the region")
	# Pausing stops the clock; play moves it.
	var before: float = weather.time_of_day()
	await frames(30)
	var running: float = weather.time_of_day()
	game.set_paused(true)
	await frames(30)
	var paused: float = weather.time_of_day()
	game.set_paused(false)
	await frames(30)
	check(running > before and paused == running and weather.time_of_day() > paused, "The clock runs in play and stops while the game is paused")
	# HUD clock and weather beside the region name.
	weather.set_time(0.5)
	weather.set_weather("rain")
	game._refresh_hud()
	var day_text: String = game.hud.clock_label.text
	var day_icon: String = game.hud.clock_kind
	weather.set_time(0.9)
	weather.set_weather("clear")
	game._refresh_hud()
	check(day_text == "Giờ Ngọ  •  Mưa" and day_icon == "rain" and game.hud.clock_label.text == "Giờ Hợi  •  Trời quang" and game.hud.clock_kind == "sun" and game.hud.clock_night
		and game.hud.clock_label.visible and game.hud.clock_label.get_global_rect().position.x > game.hud.region_label.get_global_rect().end.x,
		"The HUD shows the double hour and the weather, with its icon, beside the region name")
	check(game.quests.check(["time:night"]) and game.quests.check(["weather:clear"]), "The game's conditions read its own clock and sky")
	# The "Thời tiết động" setting: saved in settings.cfg, applied by main.
	weather.set_weather("rain", 0.0, 300.0)
	game.user_settings.dynamic_weather = false
	game.apply_settings()
	var off: String = weather.weather_id()
	var stored: UserSettings = UserSettings.new()
	game.user_settings.save_file(SETTINGS)
	stored.load_file(SETTINGS)
	game.user_settings.dynamic_weather = true
	game.apply_settings()
	check(off == "clear" and not stored.dynamic_weather and weather.weather_id() == "rain" and weather.world == "rain",
		"Turning off 'Thời tiết động' clears the sky (kept in settings.cfg); turning it on brings the rain back")
	_remove(SETTINGS)
	# Shrine rest: a lit shrine offers to wait for dawn or dusk.
	player.teleport(Vector3(6, game.world.height_at(6, 27) + 0.6, 27))
	await frames(2)
	await _settle(game)
	var shrine: Interactable = game.spawner.node_for("shrine_village") as Interactable
	check(shrine != null, "The village shrine streams in")
	if shrine:
		weather.set_time(0.5)
		var day: int = weather.day
		game.on_interact(shrine)
		var lit_prompt: bool = not game.dialogue.is_empty()
		game.on_interact(shrine)
		var offered: Array = _choices(game)
		check(not lit_prompt and offered == ["Nghỉ đến sáng", "Nghỉ đến tối", "Thôi"] and game.hud.dialogue_open() and not player.input_enabled,
			"Lighting a shrine only lights it; using it again offers Nghỉ đến sáng / Nghỉ đến tối / Thôi")
		game._choose_dialogue(0)
		await frames(2)
		var rest: Dictionary = WeatherDirector.data()["rest"]
		var on_disk: Dictionary = SaveStore.read_save(SAVE)
		check(absf(weather.time_of_day() - float(rest["dawn"])) < 0.001 and weather.day == day + 1 and weather.day_phase() == "dawn" and game.dialogue.is_empty() and player.input_enabled
			and not on_disk.is_empty() and is_equal_approx(float(on_disk["time_of_day"]), float(rest["dawn"])) and int(on_disk["day"]) == day + 1,
			"Resting to dawn from noon wakes at dawn the next day and saves the journey (%s)" % weather.clock_hhmm())
		game.on_interact(shrine)
		var at_dawn: Array = _choices(game)
		game._choose_dialogue(0)
		await frames(2)
		check(at_dawn == ["Nghỉ đến tối", "Thôi"] and absf(weather.time_of_day() - float(rest["dusk"])) < 0.001 and weather.day == day + 1 and weather.day_phase() == "dusk",
			"At dawn only the rest to dusk is offered, and it keeps the same day")
		game.on_interact(shrine)
		var at_dusk: Array = _choices(game)
		var hour: float = weather.time_of_day()
		game._choose_dialogue(at_dusk.size() - 1)
		await frames(2)
		check(at_dusk == ["Nghỉ đến sáng", "Thôi"] and absf(weather.time_of_day() - hour) < 0.001 and game.dialogue.is_empty() and player.input_enabled,
			"'Thôi' closes the prompt and leaves the clock alone")
		game.engaged = 1
		game.on_interact(shrine)
		var fighting_prompt: bool = not game.dialogue.is_empty()
		game._rest("dawn")
		check(not fighting_prompt and absf(weather.time_of_day() - hour) < 0.001 and not game.can_rest(), "No rest is offered or taken during a fight")
		game.engaged = 0
	# The Trial pocket: fixed clear sky, the valley's weather waits; no rest inside.
	weather.set_weather("rain", 0.0, 500.0)
	game.trial.start(player.global_position)
	await frames(4)
	var inside: String = weather.weather_id()
	var region: String = weather.region
	var waiting: Dictionary = weather.to_save()["weather"]
	await frames(30)
	check(region == "ao_canh" and inside == "clear" and weather.weather_id() == "clear" and weather.to_save()["weather"] == waiting and weather.world == "rain" and not game.can_rest(),
		"In the Trial the sky is clear and the valley's rain waits, unchanged; there is no shrine rest")
	game.trial.end_run("leave")
	await frames(4)
	check(weather.region != "ao_canh" and weather.weather_id() == "rain", "Leaving the Trial brings back the valley's rain")
	# Save and load through the game: clock, day, weather and RNG.
	weather.set_time(0.9)
	weather.set_weather("storm", 0.0, 77.0)
	weather.day = 5
	check(game.save_game(), "Saving the journey at night in a storm")
	var kept: Dictionary = SaveStore.read_save(SAVE)
	weather.set_time(0.4)
	weather.set_weather("clear")
	weather.day = 9
	weather.rng.randi()
	check(game.load_game() and absf(weather.time_of_day() - float(kept["time_of_day"])) < 0.0001 and weather.day == 5 and weather.world == "storm" and weather.weather_id() == "storm"
		and is_equal_approx(weather.remaining, float(kept["weather"]["remaining"])) and str(weather.rng.state) == String(kept["weather"]["state"]) and int(kept["version"]) == 4,
		"Loading restores the night, day 5, the storm with its seconds left and the RNG")
	await frames(2)
	game.start_new_game()
	await frames(2)
	check(weather.day == 1 and absf(weather.time_of_day() - float(start["time"])) < 0.01 and weather.weather_id() == "clear", "A new game starts the clock over on a clear morning")
	game.audio.stop_all()
	await create_timer(0.2, true, false, true).timeout
	game.queue_free()
	await frames(2)
	_remove(SAVE)
	_remove(PROFILE)
