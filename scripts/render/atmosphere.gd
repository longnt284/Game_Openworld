class_name Atmosphere
extends Node3D
## Sky, sun and moon, fog, colour grading and ambient light over data/world/moods.json. The mood
## shown is layered: the region's fair-day mood, shifted by each weather's colour overlay as the
## WeatherDirector eases between skies, then by the hour (dawn, dusk and night palettes), then
## scaled by the weather's levels (darken dims the sun and its shadows, desaturate greys the
## grade, clouds and storm thicken the sky, fog pulls the depth fog in). One DirectionalLight3D
## is the sun by day and a cool, dim moon by night: it crosses the sky from east to west, and
## light and shadows fade out near the horizon so the swap never pops. Depth fog ends at the edge
## of the streamed terrain and matches the horizon, so the world fades into the sky while the
## distant karst backdrop (fog-free) stays crisp. (GL Compatibility also renders Environment height
## fog, max-combined with depth fog, but it ignores distance and greys the ground at the player's
## feet; weather fog stays depth fog.) Values are recomposed at most UPDATE_HZ times a second and
## written only when they moved meaningfully; once the mood has arrived nothing is written
## ("settled"), since each sky uniform write re-renders the radiance. Global shader
## uniforms (project.godot [shader_globals]) carry the sky to every material: vk_wind (foliage
## sway, gusts), vk_wet (rain-soaked ground), vk_night (a moonlit grade; lanterns glow brighter),
## vk_gloom (grey weather and dark regions) and vk_sky (what the water reflects); light_changed
## tints what is unlit. Without a WeatherDirector (the title screen), and in regions outside the
## valley's hours (the Trial pocket), it shows the fair reference hour: the valley's old fixed
## afternoon sun.

signal haze_changed(color: Color)
## How the light on the world compares with the region's fair day, per channel and linear: white
## at a fair noon, dim blue at night, grey in a storm, warm at dusk. Unlit things (the distant
## backdrop, drifting petals) multiply by it.
signal light_changed(tint: Color)

const SKY_SHADER: Shader = preload("res://shaders/sky.gdshader")
const FALLBACK: String = "ben_van_khe"
## Recompose and write at most this often (the preset's "sky_hz" may lower it).
const UPDATE_HZ: float = 10.0
## Region and weather changes ease toward the composed mood at this rate per second.
const EASE: float = 0.6
## Smallest change worth a write, per colour channel and for plain numbers.
const COLOR_STEP: float = 0.002
const VALUE_STEP: float = 0.001
## The sun or moon turns only once it has moved this far (degrees).
const ANGLE_STEP: float = 0.1
## Depth fog over the streamed radius in fair weather.
const FOG_BEGIN: float = 0.6
const FOG_END: float = 1.6
const FOG_DENSITY: float = 0.82
const FOG_CURVE: float = 1.6
## A lightning flash fades out over 1 / FLASH_FADE seconds and lifts the ambient by this much.
const FLASH_FADE: float = 3.5
const FLASH_AMBIENT: float = 1.6
## Share of grey in the light tint.
const TINT_GREY: float = 0.35
## Weather levels the mood follows besides the colour overlays (data/weather.json), and the keys
## they are eased under in goal/current.
const LEVELS: PackedStringArray = ["darken", "desaturate", "clouds", "fog", "storm", "rain", "wind"]
const LEVEL_KEYS: PackedStringArray = ["level_darken", "level_desaturate", "level_clouds", "level_fog", "level_storm", "level_rain", "level_wind"]

static var _moods: Dictionary = {}
static var _starts: PackedFloat32Array = PackedFloat32Array()

var environment: Environment
var sun: DirectionalLight3D
var sky_material: ShaderMaterial
var weather: WeatherDirector
## Values shown now and the composed values they ease toward: every mood key, the weather levels
## (LEVEL_KEYS), "night" (the night palette's share) and the region's own fair-day light
## ("base_*": the water's reflection and the light tint are measured against it).
var current: Dictionary = {}
var goal: Dictionary = {}
## Last value written to each sky uniform, environment property and global uniform.
var written: Dictionary = {}
## Levels of the default weather (data/weather.json "clear"): neutral, the look before weather.
var calm: Dictionary = {}
var target_id: String = FALLBACK
## True in a region outside the valley's hours ("still" in moods.json "light": the Trial's illusion
## keeps its fair afternoon at any hour, as its weather stays clear).
var still: bool = false
var shadow_distance: float = 60.0
## Streamed terrain radius in metres; depth fog finishes just inside it.
var view_distance: float = 64.0
var settled: bool = false
var update_interval: float = 1.0 / UPDATE_HZ
var since: float = 0.0
## Ground wetness behind vk_wet: soaks in over "wet_in" seconds of rain, dries over "wet_out".
var wet: float = 0.0
var flash_level: float = 0.0
## Energies last composed for the ambient light and the sun or moon.
var ambient_energy: float = 0.55
var sun_energy: float = 1.12
## The light as last composed: x pitch, y yaw (degrees), z fade near the horizon, w 1 for the moon.
var arc: Vector4 = Vector4(-50.0, -35.0, 1.0, 0.0)
## Sky uniform writes so far: each one re-renders the radiance (tests and the F3 overlay).
var sky_writes: int = 0
## Recompositions so far (tests: at most UPDATE_HZ a second).
var updates: int = 0

static func moods() -> Dictionary:
	## data/world/moods.json with its colours parsed once.
	if _moods.is_empty():
		var raw: Dictionary = (ContentDB.get_data("moods") as Dictionary).duplicate(true)
		for group: String in ["regions", "times", "weathers"]:
			var parsed: Dictionary = {}
			for id: String in raw.get(group, {}):
				parsed[id] = parse(raw[group][id])
			raw[group] = parsed
		raw["shading"] = parse(raw.get("shading", {}))
		_moods = raw
	return _moods

static func parse(mood: Dictionary) -> Dictionary:
	## Hex strings become Colors, everything else a float.
	var parsed: Dictionary = {}
	for key: String in mood:
		parsed[key] = Color(String(mood[key])) if mood[key] is String else float(mood[key])
	return parsed

static func phase_starts() -> PackedFloat32Array:
	## The WeatherDirector's phase starts (data/weather.json), so the sky and gameplay agree on night.
	if _starts.is_empty():
		var phases: Dictionary = WeatherDirector.data().get("phases", {})
		var fallback: Array[float] = [0.17, 0.25, 0.75, 0.83]
		for index: int in range(WeatherDirector.PHASES.size()):
			_starts.append(float(phases.get(WeatherDirector.PHASES[index], {}).get("start", fallback[index])))
	return _starts

static func _bump(fraction: float, window: Dictionary) -> float:
	## 0 outside [from, to], rising to 1 at "peak" and falling back.
	var from: float = float(window.get("from", 0.0))
	var peak: float = float(window.get("peak", 0.0))
	var to: float = float(window.get("to", 0.0))
	if fraction <= from or fraction >= to:
		return 0.0
	return smoothstep(from, peak, fraction) if fraction < peak else 1.0 - smoothstep(peak, to, fraction)

static func time_weights(fraction: float) -> Vector3:
	## Shares of the dawn (x), dusk (y) and night (z) palettes at a fraction of the day, before each
	## palette's strength. Dawn and dusk swell around sunrise and sunset; night is the director's
	## night_curve: 1 from nightfall to dawn, 0 through the day.
	var light: Dictionary = moods()["light"]
	return Vector3(_bump(fraction, light["dawn"]), _bump(fraction, light["dusk"]), WeatherDirector.night_curve(fraction, phase_starts()))

static func reference_clock() -> float:
	## The hour at which the sun stands where the valley's old fixed sun stood (yaw "reference_yaw",
	## pitch the region's): a fair day then looks exactly as it did before the clock existed.
	var light: Dictionary = moods()["light"]
	var east: float = float(light["east_yaw"])
	var share: float = (east - float(light["reference_yaw"])) / (east - float(light["west_yaw"]))
	return float(light["rise"]) + share * (float(light["set"]) - float(light["rise"]))

static func light_arc(fraction: float, pitch: float) -> Vector4:
	## The light at a fraction of the day: x pitch and y yaw in degrees (DirectionalLight3D rotation),
	## z its fade (0 on the horizon, 1 once clear of it; light and shadows scale by it), w 1 when it
	## is the moon. The sun rises in the east at "rise" and sets in the west at "set"; pitch is its
	## height at reference_clock(), a little higher at noon. The moon takes the same path through
	## the night and reaches pitch (the night palette's) at its highest.
	var light: Dictionary = moods()["light"]
	var sunrise: float = float(light["rise"])
	var sunset: float = float(light["set"])
	var power: float = float(light["arc_power"])
	var east: float = float(light["east_yaw"])
	var west: float = float(light["west_yaw"])
	var moon: bool = fraction < sunrise or fraction >= sunset
	var along: float = fposmod(fraction - sunset, 1.0) / (1.0 - (sunset - sunrise)) if moon else (fraction - sunrise) / (sunset - sunrise)
	along = clampf(along, 0.0, 1.0)
	var height: float = pow(sin(PI * along), power)
	if not moon:
		var reference: float = (east - float(light["reference_yaw"])) / (east - west)
		height /= pow(sin(PI * reference), power)
	var edge: float = float(light["fade"])
	var fade: float = smoothstep(0.0, edge, along) * smoothstep(0.0, edge, 1.0 - along)
	return Vector4(clampf(pitch * height, -85.0, 0.0), lerpf(east, west, along), fade, 1.0 if moon else 0.0)

func _init() -> void:
	var rules: Dictionary = WeatherDirector.data().get("weathers", {})
	var neutral: Dictionary = rules.get(String(WeatherDirector.data().get("default", WeatherDirector.FALLBACK)), {})
	for key: String in LEVELS:
		calm[key] = float(neutral.get(key, 0.0))

func _ready() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	environment = Environment.new()
	var sky: Sky = Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	var clouds: NoiseTexture2D = NoiseTexture2D.new()
	clouds.seamless = true
	clouds.width = 512
	clouds.height = 512
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.frequency = 0.008
	noise.fractal_octaves = 4
	clouds.noise = noise
	sky_material.set_shader_parameter("cloud_noise", clouds)
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 1.4
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_density = FOG_DENSITY
	environment.fog_sky_affect = 0.0
	environment.fog_depth_curve = FOG_CURVE
	environment.glow_enabled = false
	environment.glow_intensity = 0.55
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.4
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.0
	world_environment.environment = environment
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = shadow_distance
	sun.shadow_blur = 1.0
	add_child(sun)
	snap()

func follow(director: WeatherDirector) -> void:
	## Follows a WeatherDirector's clock and sky (main: while playing); null shows the fair reference
	## hour, as on the title screen. Either way the new sky shows at once.
	if weather and weather.changed.is_connected(_on_weather_changed):
		weather.changed.disconnect(_on_weather_changed)
	weather = director
	if weather:
		weather.changed.connect(_on_weather_changed)
	snap()

func _on_weather_changed(kind: String) -> void:
	# A set or skipped clock (shrine rest, load, new game) or a sky shown at once (a teleport into
	# a fixed region): no easing, the world is already behind a fade or a menu.
	if kind == "time" or (kind == "weather" and weather.settled()):
		snap()

func set_region(region_id: String) -> void:
	if (moods()["regions"] as Dictionary).has(region_id) and region_id != target_id:
		target_id = region_id
		settled = false
		var outside: bool = (moods()["light"].get("still", []) as Array).has(region_id)
		if outside != still:
			# Into or out of a pocket outside the valley's hours: a teleport, behind a fade.
			still = outside
			snap()

func set_update_rate(hz: float) -> void:
	update_interval = 1.0 / clampf(hz, 1.0, UPDATE_HZ)

func set_shadow_distance(distance: float) -> void:
	shadow_distance = distance
	if sun:
		sun.shadow_enabled = distance > 0.0
		sun.directional_shadow_max_distance = maxf(distance, 10.0)
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if distance > 100.0 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS

func set_view_distance(distance: float) -> void:
	view_distance = distance
	if environment and not current.is_empty():
		_apply_fog(true)

func haze() -> Color:
	return current.get("fog", Color.WHITE)

func time_of_day() -> float:
	## The hour shown: the director's clock, or the reference hour without one or where time stands
	## still.
	return weather.time_of_day() if weather and not still else reference_clock()

func flash(strength: float = 1.0) -> void:
	## A lightning stroke: lights the cloud deck and lifts the ambient for a moment, from this
	## frame on. Written every frame while it fades (a fraction of a second), outside the UPDATE_HZ
	## budget.
	flash_level = maxf(flash_level, clampf(strength, 0.0, 1.0))
	if environment:
		_write_flash()

func _process(delta: float) -> void:
	if flash_level > 0.0:
		flash_level = maxf(0.0, flash_level - delta * FLASH_FADE)
		_write_flash()
	since += delta
	if since < update_interval:
		return
	step(since)
	since = 0.0

func snap() -> void:
	## Shows the composed mood now, without easing.
	_compose()
	for key: String in goal:
		current[key] = goal[key]
	wet = float(goal["level_rain"])
	settled = true
	since = 0.0
	_apply(true)

func step(seconds: float) -> void:
	## One update: recompose, ease toward it and write what moved. Once the mood has arrived and the
	## composition stops changing, only the travelling sun or moon is turned.
	updates += 1
	_compose()
	var rain: float = float(goal["level_rain"])
	if settled and wet == rain and _matches():
		_apply_light(false)
		return
	var t: float = clampf(seconds * EASE, 0.0, 1.0)
	var arrived: bool = true
	for key: String in goal:
		var aim: Variant = goal[key]
		if aim is Color:
			var color: Color = (current[key] as Color).lerp(aim, t)
			if _color_delta(color, aim) < COLOR_STEP * 0.5:
				color = aim
			else:
				arrived = false
			current[key] = color
		else:
			var value: float = lerpf(float(current[key]), float(aim), t)
			if absf(value - float(aim)) < VALUE_STEP * 0.5:
				value = float(aim)
			else:
				arrived = false
			current[key] = value
	var shading: Dictionary = moods()["shading"]
	wet = move_toward(wet, rain, seconds / maxf(float(shading["wet_in"] if rain > wet else shading["wet_out"]), 0.1))
	settled = arrived and wet == rain
	# The last write before settling lands exactly on the goal, not just within a step of it.
	_apply(settled)

func _matches() -> bool:
	for key: String in goal:
		if goal[key] != current[key]:
			return false
	return true

# ------------------------------------------------------------------ composition

func _compose() -> void:
	## goal = region mood, + weather colour overlays (by share), -> dawn/dusk/night palettes (by
	## hour), plus the weather levels. Writes into the same Dictionary every time.
	var data: Dictionary = moods()
	var regions: Dictionary = data["regions"]
	var region: Dictionary = regions.get(target_id, regions[FALLBACK])
	for key: String in region:
		goal[key] = region[key]
	goal["base_horizon"] = region["horizon"]
	goal["base_sun"] = region["sun"]
	goal["base_sun_energy"] = region["sun_energy"]
	goal["base_ambient"] = region["ambient"]
	goal["base_ambient_energy"] = region["ambient_energy"]
	if weather:
		var overlays: Dictionary = data["weathers"]
		for id: String in overlays:
			var share: float = weather.weight(id)
			if share <= 0.0:
				continue
			var overlay: Dictionary = overlays[id]
			for key: String in overlay:
				# Weighted mean of region and overlays: each adds its difference by its share.
				if region[key] is Color:
					goal[key] = (goal[key] as Color) + ((overlay[key] as Color) - (region[key] as Color)) * share
				else:
					goal[key] = float(goal[key]) + (float(overlay[key]) - float(region[key])) * share
		for index: int in range(LEVELS.size()):
			goal[LEVEL_KEYS[index]] = weather.level(LEVELS[index])
	else:
		for index: int in range(LEVELS.size()):
			goal[LEVEL_KEYS[index]] = calm[LEVELS[index]]
	var shares: Vector3 = time_weights(time_of_day())
	var times: Dictionary = data["times"]
	var light: Dictionary = data["light"]
	_toward(times["dawn"], shares.x * float(light["dawn"]["strength"]))
	_toward(times["dusk"], shares.y * float(light["dusk"]["strength"]))
	_toward(times["night"], shares.z * float(light["night"]["strength"]))
	goal["night"] = shares.z

func _toward(palette: Dictionary, amount: float) -> void:
	if amount <= 0.0:
		return
	for key: String in palette:
		if palette[key] is Color:
			goal[key] = (goal[key] as Color).lerp(palette[key], amount)
		else:
			goal[key] = lerpf(float(goal[key]), float(palette[key]), amount)

static func _color_delta(a: Color, b: Color) -> float:
	## Largest channel difference, alpha included (vk_sky carries the glint strength there).
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), maxf(absf(a.b - b.b), absf(a.a - b.a)))

# ------------------------------------------------------------------ writes

func _changed(key: StringName, value: Variant, exact: bool) -> bool:
	## True (and remembered) when value moved a write step since it was last written; exact also
	## catches the last small difference once the mood has arrived.
	var last: Variant = written.get(key)
	if last != null and typeof(last) == typeof(value):
		if exact:
			if last == value:
				return false
		elif value is Color:
			if _color_delta(last, value) < COLOR_STEP:
				return false
		elif value is Vector2:
			var moved: Vector2 = ((last as Vector2) - (value as Vector2)).abs()
			if maxf(moved.x, moved.y) < VALUE_STEP:
				return false
		elif absf(float(last) - float(value)) < VALUE_STEP:
			return false
	written[key] = value
	return true

func _sky(key: StringName, value: Variant, exact: bool) -> void:
	if _changed(key, value, exact):
		sky_material.set_shader_parameter(key, value)
		sky_writes += 1

func _global(key: StringName, value: Variant, exact: bool) -> void:
	if _changed(key, value, exact):
		RenderingServer.global_shader_parameter_set(key, value)

func _apply(exact: bool) -> void:
	if environment == null:
		return
	var levels: Dictionary = moods()["levels"]
	var darken: float = float(current["level_darken"])
	var desaturate: float = float(current["level_desaturate"])
	var night: float = float(current["night"])
	var fog: Color = current["fog"]
	var coverage: float = float(current["clouds"]) - (float(current["level_clouds"]) - float(calm["clouds"])) * float(levels["cloud_gain"])
	_apply_light(exact)
	_sky(&"top_color", current["top"], exact)
	_sky(&"horizon_color", current["horizon"], exact)
	_sky(&"ground_color", fog.darkened(0.2), exact)
	_sky(&"sun_color", current["sun"], exact)
	_sky(&"cloud_coverage", clampf(coverage, 0.0, 1.0), exact)
	_sky(&"cloud_light", current["cloud"], exact)
	_sky(&"cloud_shadow", current["cloud_shade"], exact)
	_sky(&"night", night, exact)
	_sky(&"storm", float(current["level_storm"]), exact)
	if _changed(&"fog", fog, exact):
		environment.fog_light_color = fog
		haze_changed.emit(fog)
	if _changed(&"ambient", current["ambient"], exact):
		environment.ambient_light_color = current["ambient"]
	ambient_energy = float(current["ambient_energy"]) * (1.0 - darken * float(levels["ambient_dim"]))
	if flash_level <= 0.0 and _changed(&"ambient_energy", ambient_energy, exact):
		environment.ambient_light_energy = ambient_energy
	var saturation: float = float(current["saturation"]) * (1.0 - desaturate * float(levels["desaturate"]))
	if _changed(&"saturation", saturation, exact):
		environment.adjustment_saturation = saturation
	_apply_fog(exact)
	_apply_globals(exact)
	var tint: Color = light_tint()
	if _changed(&"tint", tint, exact):
		light_changed.emit(tint)

func light_tint() -> Color:
	## The light_changed tint for the values shown now: ambient plus most of the sun or moon, over
	## the same sum for the region's fair day.
	var lit: Color = (current["ambient"] as Color).srgb_to_linear() * ambient_energy + (current["sun"] as Color).srgb_to_linear() * (sun_energy * 0.7)
	var fair: Color = (current["base_ambient"] as Color).srgb_to_linear() * float(current["base_ambient_energy"]) + (current["base_sun"] as Color).srgb_to_linear() * (float(current["base_sun_energy"]) * 0.7)
	var tint: Color = Color(clampf(lit.r / maxf(fair.r, 0.001), 0.0, 1.5), clampf(lit.g / maxf(fair.g, 0.001), 0.0, 1.5), clampf(lit.b / maxf(fair.b, 0.001), 0.0, 1.5))
	# Half way to grey: moonlight would otherwise paint the distant clouds a saturated blue.
	var luma: float = tint.get_luminance()
	return tint.lerp(Color(luma, luma, luma), TINT_GREY)

func _apply_light(exact: bool) -> void:
	## Turns the sun or moon along its arc, with its colour, energy and shadow strength.
	arc = light_arc(time_of_day(), float(current["pitch"]))
	var levels: Dictionary = moods()["levels"]
	var darken: float = float(current["level_darken"])
	var turned: Vector3 = sun.rotation_degrees
	if exact or written.get(&"moon") != arc.w or absf(turned.x - arc.x) >= ANGLE_STEP or absf(turned.y - arc.y) >= ANGLE_STEP:
		sun.rotation_degrees = Vector3(arc.x, arc.y, 0.0)
		if written.get(&"moon") != arc.w:
			# The swap happens with the light faded out; the sky's disc changes with it.
			_sky(&"moon", arc.w, true)
			_sky(&"disc", arc.z, true)
	if _changed(&"sun", current["sun"], exact):
		sun.light_color = current["sun"]
	sun_energy = float(current["sun_energy"]) * maxf(0.0, 1.0 - darken * float(levels["sun_dim"])) * arc.z
	if _changed(&"sun_energy", sun_energy, exact):
		sun.light_energy = sun_energy
	var night_shadow: float = float(moods()["light"]["night"]["shadow"])
	var shadow: float = arc.z * lerpf(1.0, night_shadow, arc.w) * clampf(1.0 - darken * float(levels["shadow_dim"]), 0.0, 1.0)
	if _changed(&"shadow", shadow, exact):
		sun.shadow_opacity = shadow
	# The disc fades with the light; its ends are written exactly.
	_sky(&"disc", arc.z, exact or arc.z == 0.0 or arc.z == 1.0)

func _apply_fog(exact: bool) -> void:
	var levels: Dictionary = moods()["levels"]
	var thick: float = float(current["level_fog"])
	var begin: float = view_distance * FOG_BEGIN * lerpf(1.0, float(levels["fog_begin"]), thick)
	var end: float = view_distance * FOG_END * lerpf(1.0, float(levels["fog_end"]), thick)
	if _changed(&"fog_begin", begin, exact):
		environment.fog_depth_begin = begin
	if _changed(&"fog_end", end, exact):
		environment.fog_depth_end = end
	var density: float = lerpf(FOG_DENSITY, float(levels["fog_density"]), thick)
	if _changed(&"fog_density", density, exact):
		environment.fog_density = density
	# Thick fog thickens close by too, not only toward the edge.
	var curve: float = lerpf(FOG_CURVE, float(levels["fog_curve"]), thick)
	if _changed(&"fog_curve", curve, exact):
		environment.fog_depth_curve = curve

func _apply_globals(exact: bool) -> void:
	var levels: Dictionary = moods()["levels"]
	var shading: Dictionary = moods()["shading"]
	var gust: float = maxf(0.0, float(current["level_wind"]) - float(calm["wind"]))
	_global(&"vk_wind", Vector2(1.0 + gust * float(shading["sway_gain"]), gust / maxf(1.0 - float(calm["wind"]), 0.01) * float(shading["gust_gain"])), exact)
	_global(&"vk_wet", wet, exact)
	_global(&"vk_night", float(current["night"]), exact)
	_global(&"vk_gloom", clampf(float(current["gloom"]) + float(current["level_desaturate"]) * float(levels["gloom"]), 0.0, 1.0), exact)
	# The rivers reflect the sky: their fair-day colour, tinted as the horizon moves away from the
	# region's own, with sun glints as strong as the light that makes them.
	var base: Color = current["base_horizon"]
	var horizon: Color = current["horizon"]
	var water: Color = shading["water_sky"]
	var tint: Color = Color(water.r * horizon.r / maxf(base.r, 0.01), water.g * horizon.g / maxf(base.g, 0.01), water.b * horizon.b / maxf(base.b, 0.01))
	tint.a = clampf(sun_energy / maxf(float(current["base_sun_energy"]), 0.01), 0.0, 1.0)
	_global(&"vk_sky", tint, exact)

func _write_flash() -> void:
	sky_material.set_shader_parameter(&"flash", flash_level)
	sky_writes += 1
	environment.ambient_light_energy = ambient_energy + flash_level * FLASH_AMBIENT
	written[&"ambient_energy"] = environment.ambient_light_energy
