class_name SwordTrail
extends MeshInstance3D
## Fading ribbon swept by the blade between its guard and its tip during attacks.
## Samples live in world space, so the ribbon stays where the blade passed.

const LIFETIME: float = 0.16
const MAX_SAMPLES: int = 24

var emitting: bool = false
var color: Color = Color(0.85, 1.0, 0.95)
var blade: Node3D
var tip_node: Node3D
var tip_local: Vector3 = Vector3(0, 0.9, 0)
var samples: Array = []
var strip: ImmediateMesh

func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	strip = ImmediateMesh.new()
	mesh = strip
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	material_override = material

func bind(weapon: Node3D, tint: Color) -> void:
	## Follows `weapon`: its "Tip" marker when the model has one, else the top of its mesh bounds.
	blade = weapon
	color = tint
	samples.clear()
	tip_node = weapon.find_child("Tip", true, false) as Node3D
	var top: float = 0.0
	for node: Node in weapon.find_children("*", "MeshInstance3D", true, false):
		top = maxf(top, (node as MeshInstance3D).get_aabb().end.y)
	tip_local = Vector3(0, top if top > 0.2 else 0.9, 0)

func _process(delta: float) -> void:
	for sample: Array in samples:
		sample[2] += delta
	while not samples.is_empty() and float(samples[0][2]) > LIFETIME:
		samples.pop_front()
	if emitting and is_instance_valid(blade) and blade.is_inside_tree():
		var frame: Transform3D = blade.global_transform
		var tip: Vector3 = tip_node.global_position if is_instance_valid(tip_node) else frame * tip_local
		samples.append([frame.origin.lerp(tip, 0.28), tip, 0.0])
		if samples.size() > MAX_SAMPLES:
			samples.pop_front()
	strip.clear_surfaces()
	if samples.size() < 2:
		return
	strip.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for sample: Array in samples:
		var fade: float = 1.0 - float(sample[2]) / LIFETIME
		# Bright core near the blade edge, tinted and thinner toward the guard.
		var edge: Color = color.lerp(Color(1, 1, 1), 0.35 * fade)
		edge.a = fade * 0.9
		strip.surface_set_color(Color(color.r, color.g, color.b, edge.a * 0.3))
		strip.surface_add_vertex(sample[0])
		strip.surface_set_color(edge)
		strip.surface_add_vertex(sample[1])
	strip.surface_end()
