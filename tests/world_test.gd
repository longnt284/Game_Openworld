extends SceneTree
## World systems of Phase 2: the day–night clock and its phases, weather draws by region
## weights from a saved RNG, the Trial pocket's fixed weather, the "Thời tiết động" setting,
## smoothed levels and gameplay multipliers, the time:/weather: conditions, save schema v4 and
## its step-by-step migration; the layered atmosphere (data/world/moods.json, the sun and moon
## arc, deterministic blending, settling, global shader uniforms); then in the running game:
## pausing, the HUD clock, the setting, shrine rest to dawn or dusk, the Trial pocket, saving and
## loading the clock, and the sky following the clock in play but not on the title screen; then
## the effects: the rain curtain and its presets, shelter and the Trial, the gale, the lantern
## light pool, lightning intervals and flashes, and strikes with their safe rule; the weather
## sound beds and thunder.

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
	_moods()
	_atmosphere()
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
	# A shrine rest runs the valley's weather through the skipped hours and shows the result at once.
	first.set_time(0.5)
	first.set_weather("fog", 0.0, 10.0)
	state = first.rng.state
	var skipped: float = first.rest_until("dusk")
	check(is_equal_approx(skipped, (float(WeatherDirector.data()["rest"]["dusk"]) - 0.5) * first.day_length) and first.rng.state != state and first.settled() and first.weather_id() == first.world and first.day_phase() == "dusk"
		and is_zero_approx(first.rest_until("dusk")), "Resting skips the hours (%.0f s), draws the weather they would have brought and shows it settled; no rest into the phase already here" % skipped)
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

func _moods() -> void:
	var data: Dictionary = ContentDB.get_data("moods")
	var keys: Array = data["keys"]
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/layout.json"))
	var complete: bool = keys.size() >= 10
	var missing: Array[String] = []
	for region: Dictionary in layout["regions"]:
		var mood: Dictionary = data["regions"].get(String(region["id"]), {})
		for key: String in keys:
			if not mood.has(key):
				missing.append("%s.%s" % [region["id"], key])
	for group: String in ["regions", "times"]:
		for id: String in data[group]:
			complete = complete and (data[group][id] as Dictionary).size() == keys.size()
	check(complete and missing.is_empty() and (data["times"] as Dictionary).has_all(["dawn", "dusk", "night"]),
		"moods.json: every region and the dawn, dusk and night palettes have every key %s" % str(missing))
	var overlays_ok: bool = true
	for id: String in data["weathers"]:
		overlays_ok = overlays_ok and WeatherDirector.data()["weathers"].has(id)
		for key: String in data["weathers"][id]:
			overlays_ok = overlays_ok and keys.has(key) and data["weathers"][id][key] is String
	check(overlays_ok and (data["weathers"] as Dictionary).has_all(["rain", "storm", "fog"]) and not (data["weathers"] as Dictionary).has("clear"),
		"Weather overlays name real weathers and only recolour mood keys; clear has none (a fair day is the region's own mood)")
	var palettes: Dictionary = Atmosphere.moods()
	var old_village: Dictionary = {"top": Color("2b78cc"), "horizon": Color("c4e2f0"), "fog": Color("cfe5ee"), "sun": Color("fff0cc"), "sun_energy": 1.12,
		"ambient": Color("b9d2e2"), "ambient_energy": 0.55, "pitch": -50.0, "clouds": 0.5, "saturation": 1.04}
	var same: bool = true
	for key: String in old_village:
		same = same and palettes["regions"]["ben_van_khe"][key] == old_village[key]
	check(same and palettes["regions"]["ben_van_khe"]["top"] is Color, "The village's fair-day mood is the old one, colours parsed once")

func _atmosphere() -> void:
	# Pure functions of the hour: deterministic, night 1 at midnight and 0 at noon.
	var midnight: Vector3 = Atmosphere.time_weights(0.0)
	var noon: Vector3 = Atmosphere.time_weights(0.5)
	var sunset: Vector3 = Atmosphere.time_weights(0.785)
	var sunrise: Vector3 = Atmosphere.time_weights(0.215)
	check(is_equal_approx(midnight.z, 1.0) and is_zero_approx(noon.z) and noon == Atmosphere.time_weights(0.5) and is_zero_approx(noon.x + noon.y + midnight.x + midnight.y)
		and sunset.y > 0.95 and sunrise.x > 0.95 and sunset.z > 0.2 and sunset.z < 0.8,
		"Hour weights: night %.2f at midnight and %.2f at noon; dusk peaks at sunset, dawn at sunrise; same hour, same weights" % [midnight.z, noon.z])
	var reference: float = Atmosphere.reference_clock()
	var old_sun: Vector4 = Atmosphere.light_arc(reference, -50.0)
	var high: Vector4 = Atmosphere.light_arc(0.5, -50.0)
	var morning: Vector4 = Atmosphere.light_arc(0.29, -50.0)
	var moon: Vector4 = Atmosphere.light_arc(0.0, -48.0)
	var rise: Vector4 = Atmosphere.light_arc(float(Atmosphere.moods()["light"]["rise"]), -50.0)
	check(reference > 0.5 and reference < 0.75 and is_equal_approx(old_sun.x, -50.0) and is_equal_approx(old_sun.y, -35.0) and old_sun.z == 1.0 and old_sun.w == 0.0,
		"At the reference hour (%s) the sun stands where the old fixed sun stood (pitch -50, yaw -35)" % _hhmm(reference))
	check(high.x < -50.0 and is_zero_approx(high.y) and morning.y > 0.0 and morning.x > -50.0 and moon.w == 1.0 and is_equal_approx(moon.x, -48.0) and is_zero_approx(moon.y)
		and rise.z == 0.0 and morning.z == 1.0,
		"The sun climbs from the east to its noon height in the south; at midnight the moon is high in the south; light fades out on the horizon")
	# A standalone atmosphere and director: fair noon is the region's mood, night is moonlit blue.
	var atmosphere: Atmosphere = Atmosphere.new()
	root.add_child(atmosphere)
	var region: Dictionary = Atmosphere.moods()["regions"]["ben_van_khe"]
	var fair: bool = (atmosphere.time_of_day() == reference and is_equal_approx(atmosphere.sun.light_energy, float(region["sun_energy"])) and atmosphere.environment.fog_light_color == region["fog"]
		and is_equal_approx(atmosphere.environment.ambient_light_energy, float(region["ambient_energy"])) and atmosphere.sky_material.get_shader_parameter("top_color") == region["top"]
		and atmosphere.sun.rotation_degrees.is_equal_approx(Vector3(-50.0, -35.0, 0.0)) and atmosphere.written[&"vk_wind"] == Vector2(1.0, 0.0)
		and atmosphere.written[&"vk_wet"] == 0.0 and atmosphere.written[&"vk_night"] == 0.0 and atmosphere.written[&"vk_gloom"] == 0.0
		and atmosphere.light_tint().is_equal_approx(Color.WHITE) and (atmosphere.written[&"vk_sky"] as Color).is_equal_approx(Atmosphere.moods()["shading"]["water_sky"]))
	check(fair, "Without a clock (the title) the village shows exactly its old fair afternoon, and every global uniform is neutral")
	var director: WeatherDirector = _director(77, "ben_van_khe")
	director.set_time(0.5)
	director.set_weather("clear")
	atmosphere.follow(director)
	var noon_ambient: float = atmosphere.ambient_energy
	var noon_tint: float = atmosphere.light_tint().get_luminance()
	var noon_goal: Dictionary = atmosphere.goal.duplicate()
	atmosphere._compose()
	check(atmosphere.goal == noon_goal and atmosphere.current["top"] == region["top"] and atmosphere.current["fog"] == region["fog"] and is_zero_approx(atmosphere.current["night"]),
		"A clear noon composes to the region's own mood, the same every time")
	director.set_time(0.0)
	var night_tint: float = atmosphere.light_tint().get_luminance()
	check(is_equal_approx(atmosphere.current["night"], 1.0) and atmosphere.arc.w == 1.0 and atmosphere.written[&"moon"] == 1.0 and is_equal_approx(atmosphere.written[&"vk_night"], 1.0)
		and atmosphere.ambient_energy > noon_ambient and night_tint > 0.15 and night_tint < 0.6 * noon_tint and (atmosphere.current["ambient"] as Color).b > (atmosphere.current["ambient"] as Color).r,
		"Midnight: the night factor is 1, the moon lights the valley, the light is moonlit blue and dim (%.2f of noon) but never black" % (night_tint / noon_tint))
	director.set_time(0.5)
	director.set_weather("storm")
	var storm_sun: float = atmosphere.sun.light_energy
	var storm_wind: Vector2 = atmosphere.written[&"vk_wind"]
	check(storm_sun < 0.6 * float(region["sun_energy"]) and atmosphere.written[&"storm"] == 1.0 and float(atmosphere.written[&"cloud_coverage"]) < 0.2 and storm_wind.x > 1.5 and storm_wind.y > 0.5
		and float(atmosphere.written[&"vk_gloom"]) > 0.0 and is_equal_approx(atmosphere.wet, 1.0) and atmosphere.sun.shadow_opacity < 0.6,
		"A storm at noon: a dim sun with faint shadows, a full dark deck, gusting foliage, soaked ground, gloom")
	director.set_weather("fog")
	var fog_end: float = atmosphere.environment.fog_depth_end
	director.set_weather("clear")
	check(fog_end < 0.5 * atmosphere.environment.fog_depth_end and atmosphere.written[&"vk_wind"] == Vector2(1.0, 0.0) and atmosphere.written[&"storm"] == 0.0,
		"Fog pulls the depth fog in (ends at %.0f m instead of %.0f m); a clear sky puts everything back" % [fog_end, atmosphere.environment.fog_depth_end])
	# Settling: nothing is written once the mood has arrived; a change writes at most UPDATE_HZ a second.
	atmosphere.snap()
	var writes: int = atmosphere.sky_writes
	for tick: int in range(30):
		atmosphere.step(0.1)
	var still: bool = atmosphere.settled and atmosphere.sky_writes == writes
	atmosphere.set_region("truc_hai")
	var updates: int = atmosphere.updates
	for frame: int in range(60):
		atmosphere._process(1.0 / 60.0)
	var per_second: int = atmosphere.updates - updates
	var moving: int = atmosphere.sky_writes - writes
	var ticks: int = 0
	while not atmosphere.settled and ticks < 1000:
		atmosphere.step(0.1)
		ticks += 1
	var arrived: int = atmosphere.sky_writes
	for tick: int in range(30):
		atmosphere.step(0.1)
	var target: Dictionary = Atmosphere.moods()["regions"]["truc_hai"]
	check(still and per_second <= 10 and per_second >= 5 and moving > 0 and atmosphere.settled and atmosphere.sky_writes == arrived and ticks < 1000
		and atmosphere.current["top"] == target["top"] and atmosphere.sky_material.get_shader_parameter("horizon_color") == target["horizon"],
		"The atmosphere settles and stops writing; walking into Trúc Hải eases over %.1f s at %d updates a second, lands exactly on its mood and stops again" % [ticks * 0.1, per_second])
	# Rain soaks the ground over seconds and it dries slowly after.
	director.set_weather("rain", 0.0)
	atmosphere.wet = 0.0
	atmosphere.settled = false
	for tick: int in range(50):
		atmosphere.step(0.1)
	var soaking: float = atmosphere.wet
	director.set_weather("clear", 0.0)
	atmosphere.wet = 0.65
	atmosphere.settled = false
	for tick: int in range(50):
		atmosphere.step(0.1)
	check(soaking > 0.1 and soaking < 0.65 and atmosphere.wet > 0.5 and atmosphere.wet < 0.65 and absf(float(atmosphere.written[&"vk_wet"]) - atmosphere.wet) <= Atmosphere.VALUE_STEP,
		"Rain soaks the ground over seconds (%.2f after 5 s) and it dries more slowly (%.2f)" % [soaking, atmosphere.wet])
	# A lightning flash lights the sky and lifts the ambient, then fades back exactly.
	var calm_ambient: float = atmosphere.environment.ambient_light_energy
	atmosphere.flash(1.0)
	atmosphere._process(0.016)
	var lit: float = atmosphere.environment.ambient_light_energy
	for frame: int in range(40):
		atmosphere._process(0.016)
	check(lit > calm_ambient + 1.0 and atmosphere.flash_level == 0.0 and is_equal_approx(atmosphere.environment.ambient_light_energy, calm_ambient)
		and atmosphere.sky_material.get_shader_parameter("flash") == 0.0, "A lightning flash lifts the ambient and fades back")
	atmosphere.follow(null)
	check(atmosphere.weather == null and atmosphere.time_of_day() == reference and not director.changed.is_connected(atmosphere._on_weather_changed),
		"Letting go of the clock returns to the reference hour")
	# Unlit petals follow the light: untouched on a fair day, darker than the tint itself at night.
	var petals: AmbientFx = AmbientFx.new()
	root.add_child(petals)
	petals.set_budget(0.5)
	petals.set_region("ben_van_khe")
	petals.set_light(Color.WHITE)
	var fair_petals: Color = petals.material.albedo_color
	var moonlit: Color = Color(0.3, 0.36, 0.55)
	petals.set_light(moonlit)
	var night_petals: Color = petals.material.albedo_color
	check(fair_petals.is_equal_approx(Color.WHITE) and night_petals.get_luminance() < 0.8 * moonlit.linear_to_srgb().get_luminance() and night_petals.b > night_petals.r
		and is_equal_approx(night_petals.a, 1.0), "Drifting petals keep their colours on a fair day and dim below the light's tint at night, still opaque")
	petals.free()
	atmosphere.free()
	director.free()

func _hhmm(fraction: float) -> String:
	var minutes: int = int(fraction * 1440.0)
	return "%02d:%02d" % [minutes / 60, minutes % 60]

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
	var sky: Atmosphere = game.atmosphere
	check(sky.weather == weather and sky.target_id == "ben_van_khe" and absf(sky.time_of_day() - weather.time_of_day()) < 0.0001 and sky.arc.w == 0.0 and sky.arc.y > 0.0,
		"In play the atmosphere follows the clock: a morning sun in the east")
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
	weather.set_time(0.77)
	game._refresh_hud()
	var before_sunset: bool = game.hud.clock_night
	weather.set_time(0.8)
	game._refresh_hud()
	check(not before_sunset and game.hud.clock_night and weather.day_phase() == "dusk" and game.atmosphere.arc.w == 1.0,
		"The HUD icon turns to the moon when the sun sets, halfway through dusk, as the sky does")
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
		var weights: Vector3 = Atmosphere.time_weights(weather.time_of_day())
		check(absf(float(game.atmosphere.current["night"]) - weights.z) < 0.02 and weights.x > 0.5 and weights.z > 0.1 and game.atmosphere.settled and game.atmosphere.arc.w == 0.0,
			"The sky jumps with the rest: at once into sunrise, no slow fade from noon")
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
	# The Trial pocket: fixed clear sky, the valley's weather waits; no rest inside. Its illusion
	# keeps a fair afternoon even when the valley is deep in the night.
	weather.set_weather("rain", 0.0, 500.0)
	weather.set_time(0.95)
	game.trial.start(player.global_position)
	await frames(4)
	var inside: String = weather.weather_id()
	var region: String = weather.region
	var waiting: Dictionary = weather.to_save()["weather"]
	var trial_sky: bool = (sky.still and sky.time_of_day() == Atmosphere.reference_clock() and is_zero_approx(float(sky.current["night"])) and sky.arc.w == 0.0
		and sky.settled and is_zero_approx(sky.wet))
	await frames(30)
	check(region == "ao_canh" and inside == "clear" and weather.weather_id() == "clear" and weather.to_save()["weather"] == waiting and weather.world == "rain" and not game.can_rest(),
		"In the Trial the sky is clear and the valley's rain waits, unchanged; there is no shrine rest")
	check(trial_sky and weather.is_night(), "The Trial shows its fair afternoon at once, dry, while the valley's clock says night")
	game.trial.end_run("leave")
	await frames(4)
	check(weather.region != "ao_canh" and weather.weather_id() == "rain" and not sky.still and is_equal_approx(float(sky.current["night"]), 1.0) and sky.arc.w == 1.0,
		"Leaving the Trial brings back the valley's rain and its night at once")
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
	weather.set_time(0.0)
	game.return_to_title()
	await frames(2)
	var title_sky: bool = (game.atmosphere.weather == null and game.atmosphere.time_of_day() == Atmosphere.reference_clock() and game.atmosphere.arc.w == 0.0
		and game.rain.weather == null and game.storm.weather == null and game.ambient.weather == null)
	game.start_new_game()
	await frames(2)
	check(title_sky and game.atmosphere.weather == weather and game.rain.weather == weather and game.storm.weather == weather and game.ambient.weather == weather,
		"The title shows the fair reference afternoon whatever the hour, dry and calm; play follows the clock again")
	check(weather.day == 1 and absf(weather.time_of_day() - float(start["time"])) < 0.01 and weather.weather_id() == "clear", "A new game starts the clock over on a clear morning")
	await _effects(game)
	_audio(game)
	game.audio.stop_all()
	await create_timer(0.2, true, false, true).timeout
	game.queue_free()
	await frames(2)
	_remove(SAVE)
	_remove(PROFILE)

func _foe(game: Node, id: String, point: Vector3) -> Enemy:
	## A bandit standing still at point (its AI off) for the lightning checks.
	var foe: Enemy = EnemyFactory.create(ContentDB.enemy("tan_binh"))
	foe.setup({"id": id, "enemy": "tan_binh", "yaw": 0.0}, game.assets, game.world)
	game.add_child(foe)
	point.y = game.world.height_at(point.x, point.z)
	foe.activate(point, game.player)
	foe.set_physics_process(false)
	return foe

func _ground(game: Node, x: float, z: float) -> Vector3:
	return Vector3(x, game.world.height_at(x, z), z)

func _run_storm(storm: StormDirector, seconds: float, times: Array[float], warned: Array[Vector3], until_warned: bool = false) -> void:
	## Drives the lightning scheduler by hand in 0.1 s steps, noting when each bolt fell (distant or
	## warned strike) and where each strike was warned; until_warned stops at the first warning.
	var clock: Array[float] = [0.0]
	var before: int = warned.size()
	var on_bolt: Callable = func(_point: Vector3, _distance: float) -> void: times.append(clock[0])
	var on_warn: Callable = func(point: Vector3) -> void:
		times.append(clock[0])
		warned.append(point)
	storm.bolt_fell.connect(on_bolt)
	storm.strike_warned.connect(on_warn)
	for tick: int in range(roundi(seconds * 10.0)):
		clock[0] += 0.1
		storm.step(0.1)
		if until_warned and warned.size() > before:
			break
	storm.bolt_fell.disconnect(on_bolt)
	storm.strike_warned.disconnect(on_warn)

func _settle_audio(game: Node, region: Dictionary) -> void:
	## The beds fade a little each frame; run enough updates for them to arrive.
	for index: int in range(240):
		game._update_weather_audio(region)

func _audio(game: Node) -> void:
	## Phase 2.4: the weather beds follow the sky, crickets come out at night, thunder has variants.
	var weather: WeatherDirector = game.weather
	var audio: AudioDirector = game.audio
	var region: Dictionary = game.world.layout.region_at(game.player.global_position.z)
	weather.set_time(0.5)
	weather.set_weather("clear")
	_settle_audio(game, region)
	var dry: bool = audio.weather_volume("rain_light") < -50.0 and audio.weather_volume("rain_heavy") < -50.0 and audio.weather_volume("night_insects") < -50.0
	weather.set_weather("rain")
	_settle_audio(game, region)
	var drizzle: float = audio.weather_volume("rain_light")
	var drizzle_heavy: float = audio.weather_volume("rain_heavy")
	weather.set_weather("storm")
	_settle_audio(game, region)
	var downpour: float = audio.weather_volume("rain_heavy")
	var gale: float = audio.weather_volume("storm_wind")
	check(dry and drizzle > -20.0 and drizzle_heavy < drizzle and downpour > drizzle_heavy and gale > -20.0,
		"Rain beds follow the sky: silent when clear, a light patter in rain (%.0f dB), the heavy roar and gale in a storm (%.0f / %.0f dB)" % [drizzle, downpour, gale])
	_settle_audio(game, {"indoor": true})
	var sheltered: float = audio.weather_volume("rain_heavy")
	weather.set_weather("clear")
	weather.set_time(0.95)
	_settle_audio(game, region)
	var crickets: float = audio.weather_volume("night_insects")
	weather.set_time(0.5)
	_settle_audio(game, region)
	check(sheltered < -45.0 and crickets > -25.0 and audio.weather_volume("night_insects") < -50.0,
		"No rain is heard under a roof; crickets sing at night (%.0f dB) and fall silent by day" % crickets)
	var thunder: int = 0
	audio._pick("thunder")
	thunder = (audio.variants.get("thunder", []) as Array).size()
	check(thunder >= 4, "Thunder has %d variants for the storm to pick from" % thunder)

func _effects(game: Node) -> void:
	## Phase 2.3 in the running game: the rain curtain, the gale, lantern light, lightning and its
	## strikes with their safe rule.
	var weather: WeatherDirector = game.weather
	var player: PlayerController = game.player
	var rain: RainFx = game.rain
	var storm: StormDirector = game.storm
	var lights: NightLights = game.night_lights
	var rules: Dictionary = WeatherDirector.data()["weathers"]
	var presets: Dictionary = UserSettings.QUALITY
	check(float(presets["low"]["rain"]) == 0.3 and float(presets["medium"]["rain"]) == 0.5 and float(presets["high"]["rain"]) == 1.0
		and int(presets["low"]["lights"]) == 0 and int(presets["medium"]["lights"]) == 4 and int(presets["high"]["lights"]) == 6,
		"Quality presets carry the rain density (0.3 / 0.5 / 1) and the lantern light pool (0 / 4 / 6)")
	# Rain: as hard as the weather says times the preset; the shader is told the same.
	rain.set_density(1.0)
	weather.set_weather("rain")
	rain.update()
	var light_rain: float = rain.intensity
	var shown: bool = rain.curtain.visible
	weather.set_weather("storm")
	rain.update()
	var downpour: float = rain.intensity
	var lean: float = float(rain.material.get_shader_parameter("lean"))
	var splashing: bool = rain.splash.emitting
	rain.set_density(0.5)
	var medium: float = rain.intensity
	var medium_splash: bool = rain.splash.emitting
	weather.set_weather("clear")
	rain.update()
	check(is_equal_approx(light_rain, float(rules["rain"]["rain"])) and shown and is_equal_approx(downpour, 1.0) and lean > 0.0 and is_equal_approx(medium, 0.5)
		and splashing and not medium_splash and rain.intensity == 0.0 and not rain.curtain.visible and float(rain.material.get_shader_parameter("intensity")) == 0.0,
		"Rain falls as hard as the weather says times the preset (rain %.2f, storm %.2f, half on Medium, splashes on High only), leaning with the storm wind; a clear sky stops it" % [light_rain, downpour])
	weather.set_weather("rain")
	rain.set_region({"indoor": true})
	var indoors: float = rain.intensity
	rain.set_region(game.world.layout.region_at(player.global_position.z))
	check(indoors == 0.0 and rain.intensity > 0.0, "No rain falls in a sheltered ('indoor') region")
	# The gale: a storm's wind turns the drifting petals into torn leaves streaming downwind.
	var ambient: AmbientFx = game.ambient
	ambient.set_budget(0.5)
	weather.set_weather("storm")
	ambient.set_wind(weather.wind())
	var gale: bool = ambient.gale and ambient.mood() == AmbientFx.GALE and ambient.particles.direction.x > 0.0 and ambient.particles.initial_velocity_min >= AmbientFx.GALE_SPEED.x
	weather.set_weather("clear")
	ambient.set_wind(weather.wind())
	check(gale and not ambient.gale and ambient.mood() == AmbientFx.MOODS[ambient.region], "A storm's gale sends torn leaves streaming downwind; calm air brings the region's drift back")
	# Lantern light: the pool follows the preset and lights only at night, near the view.
	var sizes: Array[int] = []
	for quality: String in ["low", "medium", "high"]:
		lights.set_budget(int(presets[quality]["lights"]))
		sizes.append(lights.lights.size())
	player.teleport(Vector3(6, game.world.height_at(6, 27) + 0.6, 27))
	weather.set_time(0.5)
	await create_timer(0.5).timeout
	var day_lit: int = lights.lit_count()
	weather.set_time(0.0)
	await create_timer(0.6).timeout
	var night_lit: int = lights.lit_count()
	var near: bool = true
	for light: OmniLight3D in lights.lights:
		near = near and light.visible and light.global_position.distance_to(player.global_position) < NightLights.REACH + NightLights.LOOK_AHEAD and light.shadow_enabled == false
	weather.set_time(0.5)
	await create_timer(0.2).timeout
	check(sizes == [0, 4, 6] and day_lit == 0 and night_lit == 6 and near and lights.lit_count() == 0 and not lights.lights[0].visible,
		"The lantern light pool follows the preset (none, 4, 6), stays dark by day and lights the lanterns near Lâm An at night (%d lit)" % night_lit)
	# The Trial pocket: never rain, lightning or lantern light, whatever the valley's night storm.
	weather.set_weather("storm", 0.0, 900.0)
	weather.set_time(0.0)
	game.trial.start(player.global_position)
	await create_timer(0.3).timeout
	rain.update()
	var trial_rain: float = rain.intensity
	var trial_curtain: bool = rain.curtain.visible
	storm.set_physics_process(false)
	var trial_bolts: Array[float] = []
	var trial_warned: Array[Vector3] = []
	_run_storm(storm, 60.0, trial_bolts, trial_warned)
	check(trial_rain == 0.0 and not trial_curtain and trial_bolts.is_empty() and storm.until_next < 0.0 and lights.lit_count() == 0 and weather.world == "storm",
		"In the Trial no rain falls, no lightning comes and no lantern lights, while the valley's night storm waits")
	game.trial.end_run("leave")
	await frames(4)
	# Lightning in the village: bolts at the storm's intervals, but never a strike there, even with
	# a foe beside Lâm An and every bolt allowed to strike.
	weather.set_time(0.5)
	player.teleport(Vector3(6, game.world.height_at(6, 27) + 0.6, 27))
	await frames(2)
	var interval: float = float(rules["storm"]["lightning"])
	var spread: Array = storm.rule["spread"]
	storm.strike_rule["chance"] = 1.0
	storm.strike_rule["cooldown"] = 0.0
	var guard: Enemy = _foe(game, "world_test_storm_guard", player.global_position + Vector3(2.0, 0.0, -2.0))
	weather.set_weather("storm", 0.0, 9999.0)
	storm.until_next = -1.0
	var times: Array[float] = []
	var warned: Array[Vector3] = []
	_run_storm(storm, 600.0, times, warned)
	var gaps_ok: bool = times.size() >= floori(600.0 / (interval * float(spread[-1]))) and times[0] <= interval * float(spread[-1]) + 0.11
	for index: int in range(1, times.size()):
		var gap: float = times[index] - times[index - 1]
		gaps_ok = gaps_ok and gap >= interval * float(spread[0]) - 0.11 and gap <= interval * float(spread[-1]) + 0.11
	check(gaps_ok and warned.is_empty() and guard.health == guard.max_health and player.health == player.max_health(),
		"A storm's bolts fall every %.0f–%.0f s (%d in 10 min); in the village none ever strikes, even beside a foe" % [interval * float(spread[0]), interval * float(spread[-1]), times.size()])
	storm.rumbles.clear()
	storm.distant_bolt()
	var rumble: Dictionary = storm.rumbles[-1] if not storm.rumbles.is_empty() else {}
	check(game.hud.flash_level > 0.0 and game.hud.flash_rect.visible and game.hud.fade.color.a == 0.0 and game.atmosphere.flash_level > 0.0 and not rumble.is_empty()
		and float(rumble["left"]) >= float(storm.rule["distance"][0]) / float(storm.rule["speed_of_sound"]) - 0.01 and rumble["position"] == null,
		"A distant bolt flashes the sky and the screen (its own HUD layer), and its thunder waits %.2f s for the sound to arrive" % float(rumble.get("left", 0.0)))
	# Out on Đồi Gió (not a safe region): no strike during a dialogue; outside one, strikes come.
	var hill: Vector3 = _ground(game, 8.0, -60.0)
	player.teleport(hill + Vector3.UP * 0.6)
	guard.global_position = _ground(game, hill.x + 7.0, hill.z - 5.0)
	await frames(2)
	await _settle(game)
	game._run_dialogue("shrine_rest", null, true)
	var talking: bool = game.hud.dialogue_open()
	times.clear()
	warned.clear()
	_run_storm(storm, 300.0, times, warned)
	var during_talk: int = warned.size()
	game._end_dialogue()
	times.clear()
	_run_storm(storm, 3.0 * interval, times, warned, true)
	var struck_near_foe: bool = not warned.is_empty() and Vector2(warned[0].x - guard.global_position.x, warned[0].z - guard.global_position.z).length() <= 1.5
	check(talking and during_talk == 0 and struck_near_foe, "On Đồi Gió no strike comes while a dialogue is open; once it closes, a strike is warned beside the foe")
	storm.cancel()
	# A strike: the ring warns, then thunder and Tê liệt hit every foe and Lâm An inside it, only them.
	# (No scheduled bolt may fall meanwhile.)
	storm.until_next = 1000000.0
	await create_timer(0.6).timeout
	player.cleanse(player.statuses.active.keys())
	player.heal(player.max_health())
	var radius: float = float(storm.strike_rule["radius"])
	var spot: Vector3 = _ground(game, 8.0, -64.0)
	guard.health = guard.max_health
	guard.statuses.clear()
	guard.global_position = _ground(game, spot.x + 0.6, spot.z + 0.4)
	var outside: Enemy = _foe(game, "world_test_storm_far", spot + Vector3(radius + 1.5, 0.0, 0.0))
	player.teleport(spot + Vector3(-1.0, 0.6, 0.6))
	await frames(2)
	var hp: float = player.health
	storm.warn(spot)
	var ring: bool = storm.pending.size() == 1 and is_instance_valid(storm.pending[0]["ring"])
	storm.step(float(storm.strike_rule["telegraph"]) * 0.5)
	var early: bool = guard.health == guard.max_health and player.health == hp
	storm.step(float(storm.strike_rule["telegraph"]))
	check(ring and early and guard.health < guard.max_health and guard.statuses.has("shock") and outside.health == outside.max_health and not outside.statuses.has("shock")
		and player.health < hp and player.statuses.has("shock") and storm.pending.is_empty(),
		"A strike warns with a ring, then thunder and Tê liệt hit the foe and Lâm An inside it (-%.0f), not the foe %.1f m outside" % [hp - player.health, radius + 1.5])
	# Out of the ring nothing reaches her; a strike whose moment comes in a dialogue fizzles.
	await create_timer(0.6).timeout
	player.cleanse(player.statuses.active.keys())
	player.heal(player.max_health())
	player.teleport(spot + Vector3(-radius - 3.0, 0.6, 0.0))
	await frames(2)
	var guard_hp: float = guard.health
	storm.warn(spot)
	storm.step(float(storm.strike_rule["telegraph"]) + 0.1)
	var spared: bool = player.health == player.max_health() and guard.health < guard_hp
	guard_hp = guard.health
	storm.warn(spot)
	game._run_dialogue("shrine_rest", null, true)
	storm.step(float(storm.strike_rule["telegraph"]) + 0.1)
	var fizzled: bool = guard.health == guard_hp and storm.pending.is_empty()
	game._end_dialogue()
	check(spared and fizzled, "Lâm An outside the ring is spared while the foe in it is struck; a strike due during a dialogue fizzles")
	storm.strike_rule["chance"] = float(WeatherDirector.data()["lightning"]["strike"]["chance"])
	storm.strike_rule["cooldown"] = float(WeatherDirector.data()["lightning"]["strike"]["cooldown"])
	storm.set_physics_process(true)
	weather.set_weather("clear")
	for foe: Enemy in [guard, outside]:
		foe.queue_free()
	lights.set_budget(int(game.user_settings.preset()["lights"]))
	rain.set_density(float(game.user_settings.preset()["rain"]))
	ambient.set_budget(float(game.user_settings.preset()["ambient"]))
	await frames(2)
