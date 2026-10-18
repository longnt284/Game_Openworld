class_name AmbientFx
extends Node3D
## Drifting particles around the camera that give each region its air: blossom petals by
## the village, leaves and seed fluff on the hills, bamboo leaves in Trúc Hải, spirit
## motes near the temple. The quality preset scales the particle budget (0 turns it off).

const MOODS: Dictionary = {
	"ben_van_khe": {"colors": ["ffd3e0", "fff6f8", "f2a9bd"], "amount": 70, "size": 0.09, "fall": 0.5, "spin": true},
	"doi_gio": {"colors": ["b4d36e", "fffaf0", "e9c46a"], "amount": 60, "size": 0.08, "fall": 0.35, "spin": true},
	"truc_hai": {"colors": ["9ccf63", "6fae4f", "c9e27a"], "amount": 80, "size": 0.09, "fall": 0.7, "spin": true},
	"den_tich_phong": {"colors": ["8fe3d6", "dff8ff"], "amount": 50, "size": 0.05, "fall": -0.15, "spin": false},
	"ao_canh": {"colors": ["d9c9ff", "8fe3d6"], "amount": 60, "size": 0.05, "fall": -0.2, "spin": false},
}

var particles: CPUParticles3D
var material: StandardMaterial3D
var budget: float = 0.5
var region: String = ""
var target: Node3D

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
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.0, 0.5)
	particles.mesh = quad
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

func set_region(id: String) -> void:
	if id != region:
		region = id
		_configure()

func _configure() -> void:
	var mood: Dictionary = MOODS.get(region, {})
	if particles == null or mood.is_empty() or budget <= 0.0:
		if particles:
			particles.emitting = false
		return
	particles.amount = maxi(4, roundi(float(mood["amount"]) * budget))
	particles.scale_amount_min = float(mood["size"]) * 0.7
	particles.scale_amount_max = float(mood["size"]) * 1.3
	particles.gravity = Vector3(0.25, -float(mood["fall"]), 0.0)
	var ramp: Gradient = Gradient.new()
	var colors: Array = mood["colors"]
	ramp.set_color(0, Color(String(colors[0]), 0.0))
	ramp.set_color(1, Color(String(colors[-1]), 0.0))
	ramp.add_point(0.15, Color(String(colors[0])))
	ramp.add_point(0.85, Color(String(colors[mini(1, colors.size() - 1)])))
	particles.color_ramp = ramp
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if mood["spin"] else BaseMaterial3D.BLEND_MODE_ADD
	particles.angular_velocity_max = 140.0 if mood["spin"] else 0.0
	particles.angular_velocity_min = -140.0 if mood["spin"] else 0.0
	particles.emitting = true

func _process(_delta: float) -> void:
	if target and is_instance_valid(target):
		particles.global_position = target.global_position + Vector3(0, 3.0, 0)
