class_name AmbientFx
extends Node3D
## Drifting particles around the camera that give each region its air: blossom petals by
## the village, leaves and seed fluff on the hills, bamboo leaves in Trúc Hải, spirit
## motes near the temple. The quality preset scales the particle budget (0 turns it off).
## Petals and leaves take the Atmosphere's light tint (they are unlit), so they dim at night;
## glowing motes do not. In a gale (WeatherDirector.wind() at STORM_WIND or more: the "wind"
## and "storm" weathers) every region's air turns to torn leaves streaming sideways downwind
## (+x, the way the foliage leans), fast and short-lived, emitted upwind of Lâm An so they
## cross the view; the budget scales them too.

const MOODS: Dictionary = {
	"ben_van_khe": {"colors": ["ffd3e0", "fff6f8", "f2a9bd"], "amount": 70, "size": 0.09, "fall": 0.5, "spin": true},
	"doi_gio": {"colors": ["b4d36e", "fffaf0", "e9c46a"], "amount": 60, "size": 0.08, "fall": 0.35, "spin": true},
	"truc_hai": {"colors": ["9ccf63", "6fae4f", "c9e27a"], "amount": 80, "size": 0.09, "fall": 0.7, "spin": true},
	"den_tich_phong": {"colors": ["8fe3d6", "dff8ff"], "amount": 50, "size": 0.05, "fall": -0.15, "spin": false},
	"ao_canh": {"colors": ["d9c9ff", "8fe3d6"], "amount": 60, "size": 0.05, "fall": -0.2, "spin": false},
}
## The gale's torn leaves, whatever the region.
const GALE: Dictionary = {"colors": ["8fb35a", "c9b46a", "6f8f4a"], "amount": 160, "size": 1.0, "fall": 1.2, "spin": true}
## Wind level (0..1) from which the drift becomes a gale, and the gale's speeds (m/s).
const STORM_WIND: float = 0.6
const GALE_SPEED: Vector2 = Vector2(7.0, 12.0)
## The gale leaf's size in metres, set on the mesh: with BILLBOARD_PARTICLES the GL Compatibility
## renderer (4.7) ignores CPUParticles3D scale_amount, so the drift's sprites show at the full
## quad size (1 × 0.5 m, softened by the sprite and the distance fade).
const GALE_LEAF: Vector2 = Vector2(0.24, 0.12)
## The wind is read this often (seconds).
const WIND_INTERVAL: float = 0.25

var particles: CPUParticles3D
var material: StandardMaterial3D
## The region drift's sprite and the gale's leaf (see GALE_LEAF).
var drift_quad: QuadMesh
var gale_quad: QuadMesh
var budget: float = 0.5
var region: String = ""
var light: Color = Color.WHITE
var target: Node3D
var weather: WeatherDirector
var gale: bool = false
var since: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	particles = CPUParticles3D.new()
	particles.local_coords = false
	particles.lifetime = 9.0
	particles.preprocess = 6.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(18.0, 7.0, 18.0)
	particles.direction = Vector3(1.0, 0.0, 0.3)
	particles.spread = 40.0
	particles.initial_velocity_min = 0.3
	particles.initial_velocity_max = 1.1
	particles.angular_velocity_min = -90.0
	particles.angular_velocity_max = 90.0
	drift_quad = QuadMesh.new()
	drift_quad.size = Vector2(1.0, 0.5)
	gale_quad = QuadMesh.new()
	gale_quad.size = GALE_LEAF
	particles.mesh = drift_quad
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Soft oval sprite so petals and leaves read as shapes, not flat cards.
	var sprite: GradientTexture2D = GradientTexture2D.new()
	sprite.width = 32
	sprite.height = 32
	sprite.fill = GradientTexture2D.FILL_RADIAL
	sprite.fill_from = Vector2(0.5, 0.5)
	sprite.fill_to = Vector2(0.5, 0.0)
	var falloff: Gradient = Gradient.new()
	falloff.set_color(0, Color(1, 1, 1, 1))
	falloff.set_color(1, Color(1, 1, 1, 0))
	falloff.add_point(0.6, Color(1, 1, 1, 0.9))
	sprite.gradient = falloff
	material.albedo_texture = sprite
	# Anything drifting right past the lens fades out instead of filling the screen.
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	material.distance_fade_min_distance = 1.0
	material.distance_fade_max_distance = 4.0
	particles.material_override = material
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	particles.emitting = false

func set_budget(value: float) -> void:
	budget = value
	_configure()

func set_light(tint: Color) -> void:
	## Atmosphere.light_changed: a linear tint, white on a fair day.
	light = tint
	if material and particles.emitting:
		_tint()

func follow(director: WeatherDirector) -> void:
	## main: the clock's director while playing (its wind drives the gale), null on the title screen.
	weather = director
	set_wind(weather.wind() if weather else 0.0)

func set_wind(level: float) -> void:
	## Switches between the region's drift and the gale; the switch restarts the emitter, so it
	## only happens when the wind crosses STORM_WIND.
	var gusting: bool = level >= STORM_WIND
	if gusting != gale:
		gale = gusting
		_configure()

func mood() -> Dictionary:
	## What drifts now: the gale's leaves, or the region's own air.
	return GALE if gale and MOODS.has(region) else MOODS.get(region, {})

func _tint() -> void:
	# Unlit sprites have no shaded side and miss the moonlit grade the world gets, so they dim by
	# the light's brightness once more; otherwise leaves glow against a dark storm or night.
	var dim: float = minf(light.get_luminance(), 1.0)
	var dimmed: Color = Color(light.r * dim, light.g * dim, light.b * dim)
	material.albedo_color = dimmed.linear_to_srgb() if mood().get("spin", false) else Color.WHITE

func set_region(id: String) -> void:
	if id != region:
		region = id
		_configure()

func _configure() -> void:
	var drift: Dictionary = mood()
	if particles == null or drift.is_empty() or budget <= 0.0:
		if particles:
			particles.emitting = false
		return
	particles.amount = maxi(4, roundi(float(drift["amount"]) * budget))
	particles.scale_amount_min = float(drift["size"]) * 0.7
	particles.scale_amount_max = float(drift["size"]) * 1.3
	particles.mesh = gale_quad if gale else drift_quad
	if gale:
		# Short lives at speed from a box upwind of Lâm An (see _process), so they cross the view.
		particles.lifetime = 3.0
		particles.preprocess = 3.0
		particles.emission_box_extents = Vector3(10.0, 5.0, 18.0)
		particles.direction = Vector3(1.0, -0.05, 0.3)
		particles.spread = 12.0
		particles.initial_velocity_min = GALE_SPEED.x
		particles.initial_velocity_max = GALE_SPEED.y
		particles.gravity = Vector3(2.0, -float(drift["fall"]), 0.6)
		material.distance_fade_min_distance = 0.6
		material.distance_fade_max_distance = 2.5
	else:
		particles.lifetime = 9.0
		particles.preprocess = 6.0
		particles.emission_box_extents = Vector3(18.0, 7.0, 18.0)
		particles.direction = Vector3(1.0, 0.0, 0.3)
		particles.spread = 40.0
		particles.initial_velocity_min = 0.3
		particles.initial_velocity_max = 1.1
		particles.gravity = Vector3(0.25, -float(drift["fall"]), 0.0)
		material.distance_fade_min_distance = 1.0
		material.distance_fade_max_distance = 4.0
	var ramp: Gradient = Gradient.new()
	var colors: Array = drift["colors"]
	ramp.set_color(0, Color(String(colors[0]), 0.0))
	ramp.set_color(1, Color(String(colors[-1]), 0.0))
	ramp.add_point(0.15, Color(String(colors[0])))
	ramp.add_point(0.85, Color(String(colors[mini(1, colors.size() - 1)])))
	particles.color_ramp = ramp
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if drift["spin"] else BaseMaterial3D.BLEND_MODE_ADD
	_tint()
	var spin: float = (420.0 if gale else 140.0) if drift["spin"] else 0.0
	particles.angular_velocity_max = spin
	particles.angular_velocity_min = -spin
	particles.emitting = true
	particles.restart()

func _process(delta: float) -> void:
	if weather:
		since += delta
		if since >= WIND_INTERVAL:
			since = 0.0
			set_wind(weather.wind())
	if target and is_instance_valid(target):
		particles.global_position = target.global_position + (Vector3(-11.0, 3.0, -3.0) if gale else Vector3(0, 3.0, 0))
