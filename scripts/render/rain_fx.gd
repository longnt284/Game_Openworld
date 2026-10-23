class_name RainFx
extends Node3D
## The rain the WeatherDirector calls for, cheap enough for the Web build: two open cylinders
## around the camera whose shader (shaders/rain.gdshader) scrolls thin streaks down and leans
## them downwind with the gusts, plus small splashes around Lâm An on the High preset only.
## How much falls is WeatherDirector.rain() times the quality preset's "rain" (0 turns it off);
## nothing falls in sheltered regions (layout.json "indoor") or under a clear sky, which is what
## the Trial pocket always shows. The wet ground is the Atmosphere's (vk_wet). Recomputed at most
## UPDATE_HZ times a second; uniforms are written only when they move a step. Follows a director
## only while playing (main._follow_weather), so the title screen stays dry.

const SHADER: Shader = preload("res://shaders/rain.gdshader")
const UPDATE_HZ: float = 10.0
## Smallest change worth a uniform write.
const STEP: float = 0.01
## The two walls: radius and height (metres) and streak columns around.
const WALLS: Array[Vector3] = [Vector3(4.5, 16.0, 170.0), Vector3(11.0, 22.0, 340.0)]
## Share of each wall below the camera.
const BELOW: float = 0.42
const SEGMENTS: int = 28
## Streak lean in metres per metre of fall at full wind.
const LEAN: float = 0.45
## Streak opacity in a fair light at full rain.
const OPACITY: float = 0.5
## Splashes at full rain on High; their count changes in quarters so the emitter rarely restarts.
const SPLASHES: int = 48

var weather: WeatherDirector
## Lâm An, around whom the splashes land.
var target: Node3D
## Quality preset "rain": 0 none, 0.5 half the streaks (Medium), 1 every streak and splashes (High).
var density: float = 1.0
var sheltered: bool = false
## What is drawn now: 0 dry, 1 a full storm.
var intensity: float = 0.0
var light: Color = Color.WHITE
var curtain: MeshInstance3D
var material: ShaderMaterial
var splash: CPUParticles3D
var since: float = 0.0
## Last value written to each uniform.
var written: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	curtain = MeshInstance3D.new()
	curtain.name = "Curtain"
	curtain.mesh = _walls()
	material = ShaderMaterial.new()
	material.shader = SHADER
	curtain.material_override = material
	curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The cylinders travel with the camera; never cull them by a stale bounding box.
	curtain.extra_cull_margin = 16.0
	curtain.visible = false
	add_child(curtain)
	splash = CPUParticles3D.new()
	splash.name = "Splash"
	splash.emitting = false
	splash.local_coords = false
	splash.amount = SPLASHES
	splash.lifetime = 0.35
	splash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	splash.emission_box_extents = Vector3(5.0, 0.05, 5.0)
	splash.direction = Vector3.UP
	splash.spread = 35.0
	splash.initial_velocity_min = 0.8
	splash.initial_velocity_max = 1.6
	splash.gravity = Vector3(0, -9.0, 0)
	splash.scale_amount_min = 0.6
	splash.scale_amount_max = 1.2
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.6))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	splash.color_ramp = fade
	# A small soft dot (the quad sets its size: CPUParticles3D scale only varies it).
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.09, 0.06)
	splash.mesh = quad
	var dot: GradientTexture2D = GradientTexture2D.new()
	dot.width = 16
	dot.height = 16
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	var falloff: Gradient = Gradient.new()
	falloff.set_color(0, Color(1, 1, 1, 1))
	falloff.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = falloff
	var drops: StandardMaterial3D = StandardMaterial3D.new()
	drops.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drops.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	drops.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drops.vertex_color_use_as_albedo = true
	drops.albedo_color = Color(0.86, 0.9, 0.96)
	drops.albedo_texture = dot
	splash.material_override = drops
	splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(splash)

static func _walls() -> ArrayMesh:
	## Both open cylinders in one surface: UV.x runs around, UV.y up, UV2 = (columns, wall).
	var vertices: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var walls: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for wall: int in range(WALLS.size()):
		var shape: Vector3 = WALLS[wall]
		var first: int = vertices.size()
		for step: int in range(SEGMENTS + 1):
			var u: float = float(step) / SEGMENTS
			var around: Vector3 = Vector3(cos(u * TAU), 0.0, sin(u * TAU)) * shape.x
			for row: int in range(2):
				vertices.append(around + Vector3.UP * shape.y * (float(row) - BELOW))
				uvs.append(Vector2(u, float(row)))
				walls.append(Vector2(shape.z, float(wall)))
			if step > 0:
				var a: int = first + (step - 1) * 2
				indices.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = walls
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func follow(director: WeatherDirector) -> void:
	## main: the clock's director while playing, null on the title screen (dry). A sky shown or
	## set at once (a teleport into the Trial, a load) stops or starts the rain the same frame.
	if weather and weather.changed.is_connected(_on_weather_changed):
		weather.changed.disconnect(_on_weather_changed)
	weather = director
	if weather:
		weather.changed.connect(_on_weather_changed)
	update()

func _on_weather_changed(_kind: String) -> void:
	update()

func set_density(value: float) -> void:
	density = clampf(value, 0.0, 1.0)
	update()

func set_region(region: Dictionary) -> void:
	## layout.json region: "indoor" keeps the rain off (caves, halls).
	sheltered = bool(region.get("indoor", false))
	update()

func set_light(tint: Color) -> void:
	## Atmosphere.light_changed: unlit streaks dim with the light, like the drifting leaves.
	light = tint
	update()

func level() -> float:
	## The rain that should be falling now (0..1).
	if weather == null or sheltered or density <= 0.0:
		return 0.0
	return clampf(weather.rain() * density, 0.0, 1.0)

func splashing() -> bool:
	return density >= 1.0 and intensity > 0.05

func _process(delta: float) -> void:
	since += delta
	if since >= 1.0 / UPDATE_HZ:
		since = 0.0
		update()
	if not curtain.visible:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera:
		curtain.global_position = camera.global_position
	if splash.emitting and target and is_instance_valid(target):
		splash.global_position = target.global_position + Vector3.UP * 0.05

func update() -> void:
	## Recomputes what falls and writes what moved.
	if curtain == null:
		return
	intensity = level()
	var raining: bool = intensity > 0.001
	if curtain.visible != raining:
		curtain.visible = raining
	_write(&"intensity", intensity)
	var gust: float = weather.wind() if weather else 0.0
	_write(&"lean", gust * gust * LEAN)
	# Pale streaks against a fair sky, dimmer at night (the tint's brightness, partly).
	var bright: float = clampf(0.35 + 0.65 * light.get_luminance(), 0.0, 1.0)
	_write(&"opacity", OPACITY * clampf(0.55 + intensity * 0.6, 0.0, 1.0) * bright)
	var wanted: bool = splashing()
	if wanted:
		var count: int = maxi(8, roundi(SPLASHES * ceilf(intensity * 4.0) / 4.0))
		if splash.amount != count:
			splash.amount = count
	if splash.emitting != wanted:
		splash.emitting = wanted

func _write(key: StringName, value: float) -> void:
	var last: Variant = written.get(key)
	if last != null and absf(float(last) - value) < STEP and not (value == 0.0 and float(last) != 0.0):
		return
	written[key] = value
	material.set_shader_parameter(key, value)
