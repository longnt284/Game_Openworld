class_name WeatherDirector
extends Node
## The valley's clock and sky over data/weather.json: the time of day (one in-game day lasts
## "day_length" real seconds, about two thirds light and one third night), the day count, and
## the weather. A weather lasts a rolled number of seconds; the next one is drawn from the
## current region's weights with an RNG whose seed and state ride in the save (schema v4), so
## reloading cannot reroll it. A region may fix its weather ("ao_canh", the Trial pocket): the
## valley's weather then waits untouched until Lâm An comes back. With the "Thời tiết động"
## setting off the sky stays clear and the valley's weather waits too; the clock still turns.
## Renderer and audio read smoothed levels that ease over "transition" seconds; gameplay reads
## element_mult, detect_mult, soak_interval and reward_mult. Created in main._start_world and
## PAUSABLE, so the pause menu stops the clock.

## kind: "weather" (what is shown changed), "phase" (dawn/day/dusk/night) or "time" (the clock
## was set or skipped, as by a shrine rest or a load).
signal changed(kind: String)

## Render knobs every weather defines (0..1, except lightning which is seconds between strikes).
const LEVELS: PackedStringArray = ["rain", "fog", "wind", "storm", "darken", "desaturate", "clouds"]
## Day phases in clock order; before dawn it is still night.
const PHASES: PackedStringArray = ["dawn", "day", "dusk", "night"]
const FALLBACK: String = "clear"
## Read-only default for lookups, so hot paths never build an empty Dictionary.
const NONE: Dictionary = {}

var rules: Dictionary = {}
var day_length: float = 1440.0
var transition: float = 30.0
var default_id: String = FALLBACK
var night_detect: float = 1.0
var night_reward: float = 1.0
## Start fraction of each phase, in PHASES order.
var phase_starts: PackedFloat32Array = PackedFloat32Array([0.17, 0.25, 0.75, 0.83])
## Fraction of the in-game day (0 = midnight, 0.5 = noon) and the day of the journey (from 1).
var clock: float = 0.29
var day: int = 1
var phase: String = "day"
## The valley's weather and the seconds left before the next draw (both saved, with the RNG).
var world: String = FALLBACK
var remaining: float = 600.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## What is shown and played now: the valley's weather, the region's fixed weather, or clear with
## dynamic weather off. Levels ease from from_levels toward it while blend runs 0 -> 1.
var shown: String = FALLBACK
var previous: String = FALLBACK
var blend: float = 1.0
var blend_time: float = 0.0
var from_levels: Dictionary = {}
## Each weather's share of the sky when the current blend began (see weight()).
var from_weights: Dictionary = {}
var region: String = ""
var fixed: String = ""
var dynamic: bool = true

static func data() -> Dictionary:
	return ContentDB.get_data("weather")

static func initial_save(rng_seed: int) -> Dictionary:
	## Clock and weather of a fresh journey ("start" in data/weather.json): a new game, or a save
	## written before the clock existed. Same shape as to_save().
	var start: Dictionary = data().get("start", {})
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = rng_seed
	return {"time_of_day": fposmod(float(start.get("time", 0.29)), 1.0), "day": 1, "weather": {
		"id": String(start.get("weather", data().get("default", FALLBACK))), "remaining": maxf(1.0, float(start.get("remaining", 600.0))),
		"seed": str(generator.seed), "state": str(generator.state)}}

func _init() -> void:
	var config: Dictionary = data()
	rules = config.get("weathers", {})
	day_length = maxf(1.0, float(config.get("day_length", 1440.0)))
	transition = maxf(0.0, float(config.get("transition", 30.0)))
	default_id = String(config.get("default", FALLBACK))
	night_detect = float(config.get("night", {}).get("detect_mult", 1.0))
	night_reward = float(config.get("night", {}).get("reward_mult", 1.0))
	var phases: Dictionary = config.get("phases", {})
	for index: int in range(PHASES.size()):
		phase_starts[index] = float(phases.get(PHASES[index], {}).get("start", phase_starts[index]))
	world = default_id
	shown = default_id
	previous = default_id
	from_save(initial_save(1))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	advance(delta)

# ------------------------------------------------------------------ clock

func advance(seconds: float) -> void:
	## Moves the clock and the valley's weather on by real seconds (every frame, from _process).
	if seconds <= 0.0:
		return
	_move_clock(seconds / day_length)
	_run_weather(seconds)
	if blend < 1.0:
		blend = minf(1.0, blend + seconds / maxf(blend_time, 0.001))

func _move_clock(span: float) -> void:
	clock += span
	if clock >= 1.0:
		var days: int = floori(clock)
		day += days
		clock -= days
	_update_phase()

func _update_phase() -> void:
	var now: String = phase_at(clock)
	if now != phase:
		phase = now
		changed.emit("phase")

func phase_at(fraction: float) -> String:
	var current: String = PHASES[PHASES.size() - 1]
	for index: int in range(PHASES.size()):
		if fraction >= phase_starts[index]:
			current = PHASES[index]
	return current

func time_of_day() -> float:
	return clock

func hours() -> float:
	return clock * 24.0

func day_phase() -> String:
	return phase

func is_night() -> bool:
	return phase == "night"

func is_time(id: String) -> bool:
	## Quest condition "time:<id>": "night", "day" (any light hour: dawn, day or dusk), "dawn", "dusk".
	match id:
		"night":
			return is_night()
		"day":
			return not is_night()
		"dawn", "dusk":
			return phase == id
	push_warning("Unknown time condition " + id)
	return false

func night_level() -> float:
	## 0 in full daylight, 1 in full night, easing across dusk and dawn.
	return night_curve(clock, phase_starts)

static func night_curve(fraction: float, starts: PackedFloat32Array) -> float:
	## night_level() at any fraction of the day for phase starts in PHASES order.
	var dawn: float = starts[0]
	var morning: float = starts[1]
	var dusk: float = starts[2]
	var night: float = starts[3]
	if fraction >= night or fraction < dawn:
		return 1.0
	if fraction < morning:
		return 1.0 - smoothstep(dawn, morning, fraction)
	if fraction >= dusk:
		return smoothstep(dusk, night, fraction)
	return 0.0

func phase_name(id: String = "") -> String:
	return String(data().get("phases", {}).get(phase if id == "" else id, {}).get("name", ""))

func clock_text() -> String:
	## The traditional double hour shown on the HUD: Giờ Tý is 23:00–01:00, Giờ Ngọ 11:00–13:00.
	var names: Array = data().get("hours", [])
	if names.size() != 12:
		return clock_hhmm()
	return "Giờ " + String(names[int(fposmod(hours() + 1.0, 24.0) / 2.0) % 12])

func clock_hhmm() -> String:
	var minutes: int = int(clock * 1440.0) % 1440
	return "%02d:%02d" % [minutes / 60, minutes % 60]

func set_time(fraction: float) -> void:
	## Debug and test hook: puts the clock at a fraction of the day, keeping the day count.
	clock = fposmod(fraction, 1.0)
	_update_phase()
	changed.emit("time")

func can_rest_until(target: String) -> bool:
	## A shrine rest waits for the next dawn or dusk; not while that phase is already here.
	return (data().get("rest", {}) as Dictionary).has(target) and phase != target

func rest_until(target: String) -> float:
	## Shrine rest: skips to the next "rest" time (data/weather.json) for dawn or dusk, counting a
	## new day past midnight. The valley's weather runs through the skipped time and shows at
	## once, without easing. Returns the real seconds skipped (0 when the rest is not allowed).
	if not can_rest_until(target):
		return 0.0
	var goal: float = fposmod(float(data()["rest"][target]), 1.0)
	var span: float = goal - clock
	if span <= 0.0:
		span += 1.0
		day += 1
	clock = goal
	_update_phase()
	var seconds: float = span * day_length
	_run_weather(seconds)
	_refresh_shown(0.0)
	changed.emit("time")
	return seconds

# ------------------------------------------------------------------ weather

func set_region(id: String) -> void:
	## Fed by main._update_region. Walking into a new region only changes the weights of the next
	## draw; entering or leaving a region with a fixed weather (a teleport) shows it at once.
	if id == region:
		return
	region = id
	var was: String = fixed
	fixed = String((data().get("regions", {}) as Dictionary).get(id, NONE).get("fixed", ""))
	if fixed != was:
		_refresh_shown(0.0)

func set_dynamic(value: bool) -> void:
	## The "Thời tiết động" setting: off eases the sky to clear and holds the valley's weather.
	if value == dynamic:
		return
	dynamic = value
	_refresh_shown(transition)

func set_weather(id: String, seconds: float = 0.0, duration: float = -1.0) -> bool:
	## Debug and test hook: starts the valley's weather now (eased over seconds; 0 shows it at
	## once) for duration seconds, or a rolled duration when negative.
	if not rules.has(id):
		return false
	world = id
	remaining = duration if duration > 0.0 else _roll_duration(id)
	_refresh_shown(seconds)
	return true

func pick_next() -> String:
	## Draws the next weather from this region's weights (data/weather.json "regions", "default"
	## for regions it does not list) with the saved RNG. A fixed region draws nothing.
	var regions: Dictionary = data().get("regions", {})
	var weights: Dictionary = regions.get(region, regions.get("default", NONE))
	if weights.has("fixed"):
		return String(weights["fixed"])
	var total: float = 0.0
	for id: String in weights:
		if rules.has(id):
			total += maxf(0.0, float(weights[id]))
	if total <= 0.0:
		return default_id
	var roll: float = rng.randf() * total
	var last: String = default_id
	for id: String in weights:
		var weight: float = maxf(0.0, float(weights[id])) if rules.has(id) else 0.0
		if weight <= 0.0:
			continue
		last = id
		roll -= weight
		if roll < 0.0:
			return id
	return last

func _roll_duration(id: String) -> float:
	var span: Array = (rules.get(id, NONE) as Dictionary).get("duration", [300, 600])
	return maxf(1.0, rng.randf_range(float(span[0]), float(span[-1])))

func _run_weather(seconds: float) -> void:
	## The valley's weather moves on only while it is the one shown.
	if fixed != "" or not dynamic:
		return
	remaining -= seconds
	var guard: int = 0
	while remaining <= 0.0 and guard < 1000:
		guard += 1
		var overshoot: float = remaining
		world = pick_next()
		remaining = _roll_duration(world) + overshoot
		_refresh_shown(transition)

func _refresh_shown(seconds: float) -> void:
	var target: String = fixed if fixed != "" else (world if dynamic else default_id)
	if target == shown:
		if seconds <= 0.0:
			blend = 1.0
		return
	from_levels = {}
	for key: String in LEVELS:
		from_levels[key] = level(key)
	var shares: Dictionary = {}
	for id: String in rules:
		var share: float = weight(id)
		if share > 0.0:
			shares[id] = share
	from_weights = shares
	previous = shown
	shown = target
	blend_time = seconds
	blend = 0.0 if seconds > 0.0 else 1.0
	changed.emit("weather")

func weather_id() -> String:
	return shown

func weather_rule() -> Dictionary:
	return rules.get(shown, NONE)

func weather_name() -> String:
	return String(weather_rule().get("name", shown))

func icon() -> String:
	return String(weather_rule().get("icon", "sun"))

func settled() -> bool:
	return blend >= 1.0

func level(key: String) -> float:
	## One of LEVELS, eased from where the sky stood toward the shown weather.
	var goal: float = float(weather_rule().get(key, 0.0))
	if blend >= 1.0:
		return goal
	return lerpf(float(from_levels.get(key, goal)), goal, smoothstep(0.0, 1.0, blend))

func weight(id: String) -> float:
	## Share of weather id in the sky now (0..1, all shares sum to 1), eased like level(): the
	## Atmosphere mixes each weather's colour overlay by it.
	var goal: float = 1.0 if id == shown else 0.0
	if blend >= 1.0:
		return goal
	return lerpf(float(from_weights.get(id, 0.0)), goal, smoothstep(0.0, 1.0, blend))

func rain() -> float:
	return level("rain")

func fog() -> float:
	return level("fog")

func wind() -> float:
	return level("wind")

func storm() -> float:
	return level("storm")

func darkness() -> float:
	## Night and heavy weather together: 0 in a fair noon, 1 at its darkest.
	return 1.0 - (1.0 - night_level()) * (1.0 - level("darken"))

func lightning_interval() -> float:
	## Seconds between strikes of the shown weather once it has mostly rolled in (0: none).
	return float(weather_rule().get("lightning", 0.0)) if blend >= 0.5 else 0.0

# ------------------------------------------------------------------ gameplay

func _gameplay(id: String) -> Dictionary:
	return (rules.get(id, NONE) as Dictionary).get("gameplay", NONE)

func _blended(key: String, neutral: float) -> float:
	var goal: float = float(_gameplay(shown).get(key, neutral))
	if blend >= 1.0:
		return goal
	return lerpf(float(_gameplay(previous).get(key, neutral)), goal, smoothstep(0.0, 1.0, blend))

func element_mult(element: String) -> float:
	## Damage multiplier of an element under this sky (rain: Lôi ×1.2, Hỏa ×0.8); 1 when neutral.
	var goal: float = float((_gameplay(shown).get("element_mult", NONE) as Dictionary).get(element, 1.0))
	if blend >= 1.0:
		return goal
	var start: float = float((_gameplay(previous).get("element_mult", NONE) as Dictionary).get(element, 1.0))
	return lerpf(start, goal, smoothstep(0.0, 1.0, blend))

func detect_mult() -> float:
	## Scale of enemy sight: the weather's (fog ×0.6) times the night's, which eases in over dusk.
	return _blended("detect_mult", 1.0) * lerpf(1.0, night_detect, night_level())

func soak_interval() -> float:
	## Seconds between Ướt applied to enemies out in the rain (0: the sky is dry).
	return float(_gameplay(shown).get("soak_interval", 0.0)) if blend >= 0.5 else 0.0

func reward_mult() -> float:
	## Experience and Đồng for foes beaten at night.
	return night_reward if is_night() else 1.0

# ------------------------------------------------------------------ save

func reset(rng_seed: int = 0) -> void:
	## A new journey: the "start" clock and weather with a fresh RNG (random unless seeded).
	if rng_seed == 0:
		var generator: RandomNumberGenerator = RandomNumberGenerator.new()
		generator.randomize()
		rng_seed = int(generator.seed)
	from_save(initial_save(rng_seed))

func to_save() -> Dictionary:
	## The save's v4 fields (SaveStore): the valley's weather, never a region's fixed one.
	return {"time_of_day": clock, "day": day, "weather": {"id": world, "remaining": remaining, "seed": str(rng.seed), "state": str(rng.state)}}

func from_save(saved: Dictionary) -> void:
	## Restores the clock, the valley's weather and the RNG exactly; the sky shows it at once.
	clock = fposmod(float(saved.get("time_of_day", 0.29)), 1.0)
	day = maxi(1, int(saved.get("day", 1)))
	var weather: Dictionary = saved.get("weather", NONE)
	world = String(weather.get("id", default_id))
	if not rules.has(world):
		world = default_id
	remaining = maxf(0.0, float(weather.get("remaining", 600.0)))
	rng.seed = str(weather.get("seed", "1")).to_int()
	if weather.has("state"):
		rng.state = str(weather["state"]).to_int()
	phase = phase_at(clock)
	_refresh_shown(0.0)
	changed.emit("time")
