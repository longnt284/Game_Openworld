class_name Atmosphere
extends Node3D
## Sky, sun, fog and ambient light. Blends a mood per region so each area of
## the valley reads differently while paths and attacks stay legible.

const SKY_SHADER: Shader = preload("res://shaders/sky.gdshader")
const MOODS: Dictionary = {
	"ben_van_khe": {"top": "5d9fc4", "horizon": "e6e2c8", "fog": "d7ddc6", "fog_density": 0.006, "sun": "ffe6b0", "sun_energy": 0.95, "ambient": "a9c4cc", "ambient_energy": 0.4, "pitch": -42.0},
	"doi_gio": {"top": "5c98bd", "horizon": "e0e3cf", "fog": "d2dccd", "fog_density": 0.007, "sun": "ffe9ba", "sun_energy": 0.92, "ambient": "a8c2cc", "ambient_energy": 0.4, "pitch": -40.0},
	"truc_hai": {"top": "5b95a6", "horizon": "cfe0cc", "fog": "bcd6c6", "fog_density": 0.013, "sun": "f4f1c8", "sun_energy": 0.92, "ambient": "98c4bc", "ambient_energy": 0.45, "pitch": -48.0},
	"den_tich_phong": {"top": "6b88b0", "horizon": "e8d8c8", "fog": "d6cfd0", "fog_density": 0.009, "sun": "ffd9a8", "sun_energy": 0.98, "ambient": "b0b6cc", "ambient_energy": 0.4, "pitch": -30.0},
}

var environment: Environment
var sun: DirectionalLight3D
var sky_material: ShaderMaterial
var current: Dictionary = {}
var target_id: String = "ben_van_khe"
var shadow_distance: float = 60.0

func _ready() -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	environment = Environment.new()
	var sky: Sky = Sky.new()
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
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = true
	environment.fog_sky_affect = 0.35
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_bloom = 0.05
	environment.glow_hdr_threshold = 1.1
	world_environment.environment = environment
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = shadow_distance
	sun.shadow_blur = 1.5
	add_child(sun)
	current = MOODS[target_id].duplicate()
	_apply(current)

func set_region(region_id: String) -> void:
	if MOODS.has(region_id):
		target_id = region_id

func set_shadow_distance(distance: float) -> void:
	shadow_distance = distance
	if sun:
		sun.shadow_enabled = distance > 0.0
		sun.directional_shadow_max_distance = maxf(distance, 10.0)

func _process(delta: float) -> void:
	var goal: Dictionary = MOODS[target_id]
	var t: float = clampf(delta * 0.6, 0.0, 1.0)
	for key: String in goal:
		if goal[key] is String:
			current[key] = Color(current[key]).lerp(Color(goal[key]), t).to_html(false)
		else:
			current[key] = lerpf(float(current[key]), float(goal[key]), t)
	_apply(current)

func _apply(mood: Dictionary) -> void:
	sky_material.set_shader_parameter("top_color", Color(mood["top"]))
	sky_material.set_shader_parameter("horizon_color", Color(mood["horizon"]))
	sky_material.set_shader_parameter("ground_color", Color(mood["fog"]).darkened(0.25))
	sky_material.set_shader_parameter("sun_color", Color(mood["sun"]))
	environment.fog_light_color = Color(mood["fog"])
	environment.fog_density = float(mood["fog_density"])
	environment.ambient_light_color = Color(mood["ambient"])
	environment.ambient_light_energy = float(mood["ambient_energy"])
	sun.light_color = Color(mood["sun"])
	sun.light_energy = float(mood["sun_energy"])
	sun.rotation_degrees = Vector3(float(mood["pitch"]), -35.0, 0.0)
