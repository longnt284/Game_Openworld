class_name Atmosphere
extends Node3D
## Sky, sun, fog, colour grading and ambient light. Blends a mood per region so each
## area of the valley reads differently while paths and attacks stay legible. Depth fog
## ends at the edge of the streamed terrain and matches the horizon, so the world fades
## into the sky while the distant karst backdrop (fog-free) stays crisp.

signal haze_changed(color: Color)

const SKY_SHADER: Shader = preload("res://shaders/sky.gdshader")
const MOODS: Dictionary = {
	"ben_van_khe": {"top": Color("2b78cc"), "horizon": Color("c4e2f0"), "fog": Color("cfe5ee"), "sun": Color("fff0cc"), "sun_energy": 1.12,
		"ambient": Color("b9d2e2"), "ambient_energy": 0.55, "pitch": -50.0, "clouds": 0.5, "saturation": 1.04},
	"doi_gio": {"top": Color("2a74c6"), "horizon": Color("c8e4ee"), "fog": Color("d2e6ea"), "sun": Color("fff2d2"), "sun_energy": 1.12,
		"ambient": Color("b8d0dc"), "ambient_energy": 0.55, "pitch": -46.0, "clouds": 0.47, "saturation": 1.04},
	"truc_hai": {"top": Color("3282c4"), "horizon": Color("cfe9e2"), "fog": Color("c4e0d4"), "sun": Color("f7f6d6"), "sun_energy": 1.08,
		"ambient": Color("a8d0c4"), "ambient_energy": 0.6, "pitch": -56.0, "clouds": 0.52, "saturation": 1.03},
	"den_tich_phong": {"top": Color("3e70b8"), "horizon": Color("e6dcd0"), "fog": Color("dcd8d6"), "sun": Color("ffdcae"), "sun_energy": 1.1,
		"ambient": Color("bcc0d2"), "ambient_energy": 0.5, "pitch": -34.0, "clouds": 0.55, "saturation": 1.0},
	"ao_canh": {"top": Color("3b4f9a"), "horizon": Color("d9c9e8"), "fog": Color("cfc4e2"), "sun": Color("ffe2c8"), "sun_energy": 1.05,
		"ambient": Color("c4bcdc"), "ambient_energy": 0.6, "pitch": -40.0, "clouds": 0.56, "saturation": 1.02},
}

var environment: Environment
var sun: DirectionalLight3D
var sky_material: ShaderMaterial
var current: Dictionary = {}
var target_id: String = "ben_van_khe"
var shadow_distance: float = 60.0
## Streamed terrain radius in metres; depth fog finishes just inside it.
var view_distance: float = 64.0
var settled: bool = false

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
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 1.4
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_density = 0.82
	environment.fog_sky_affect = 0.0
	environment.fog_depth_curve = 1.6
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 0.88
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.06
	world_environment.environment = environment
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = shadow_distance
	sun.shadow_blur = 1.0
	add_child(sun)
	current = MOODS[target_id].duplicate()
	set_view_distance(view_distance)
	_apply(current)

func set_region(region_id: String) -> void:
	if MOODS.has(region_id) and region_id != target_id:
		target_id = region_id
		settled = false

func set_shadow_distance(distance: float) -> void:
	shadow_distance = distance
	if sun:
		sun.shadow_enabled = distance > 0.0
		sun.directional_shadow_max_distance = maxf(distance, 10.0)
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if distance > 100.0 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS

func set_view_distance(distance: float) -> void:
	view_distance = distance
	if environment:
		environment.fog_depth_begin = distance * 0.6
		environment.fog_depth_end = distance * 1.6

func haze() -> Color:
	return current.get("fog", Color.WHITE)

func _process(delta: float) -> void:
	if settled:
		return
	var goal: Dictionary = MOODS[target_id]
	var t: float = clampf(delta * 0.6, 0.0, 1.0)
	var done: bool = true
	for key: String in goal:
		if goal[key] is Color:
			current[key] = (current[key] as Color).lerp(goal[key], t)
			done = done and (current[key] as Color).is_equal_approx(goal[key])
		else:
			current[key] = lerpf(float(current[key]), float(goal[key]), t)
			done = done and absf(float(current[key]) - float(goal[key])) < 0.002
	_apply(current)
	# Stop rewriting sky uniforms once the mood has arrived (each write re-renders the radiance).
	settled = done

func _apply(mood: Dictionary) -> void:
	sky_material.set_shader_parameter("top_color", mood["top"])
	sky_material.set_shader_parameter("horizon_color", mood["horizon"])
	sky_material.set_shader_parameter("ground_color", (mood["fog"] as Color).darkened(0.2))
	sky_material.set_shader_parameter("sun_color", mood["sun"])
	sky_material.set_shader_parameter("cloud_coverage", mood["clouds"])
	environment.fog_light_color = mood["fog"]
	environment.ambient_light_color = mood["ambient"]
	environment.ambient_light_energy = float(mood["ambient_energy"])
	environment.adjustment_saturation = float(mood["saturation"])
	sun.light_color = mood["sun"]
	sun.light_energy = float(mood["sun_energy"])
	sun.rotation_degrees = Vector3(float(mood["pitch"]), -35.0, 0.0)
	haze_changed.emit(mood["fog"])
