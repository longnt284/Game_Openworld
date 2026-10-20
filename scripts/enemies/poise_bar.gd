class_name PoiseBar
extends MeshInstance3D
## Small poise gauge over an ordinary foe's head (Enemy.update_poise_bar decides when it is
## wanted): fades in and out, empties as poise drains and pulses gold while the foe can be
## finished. One unshaded billboard quad (shaders/poise_bar.gdshader), cheap on the Web build.

const SHADER: Shader = preload("res://shaders/poise_bar.gdshader")
const SIZE: Vector2 = Vector2(0.86, 0.09)

var material: ShaderMaterial
var alpha: float = 0.0
## Last values written to the shader, so unchanged frames write nothing.
var shown: Vector3 = Vector3(-1.0, -1.0, -1.0)

func setup(height: float) -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = SIZE
	mesh = quad
	material = ShaderMaterial.new()
	material.shader = SHADER
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position.y = height + 0.4
	visible = false

func show_poise(wanted: bool, ratio: float, finishable: bool, delta: float) -> void:
	## ratio: Enemy.poise_ratio(); finishable: the gold pulse.
	alpha = move_toward(alpha, 1.0 if wanted else 0.0, delta * 5.0)
	visible = alpha > 0.0
	if not visible:
		return
	var values: Vector3 = Vector3(ratio, alpha, 1.0 if finishable else 0.0)
	if values.is_equal_approx(shown):
		return
	shown = values
	material.set_shader_parameter("fill", ratio)
	material.set_shader_parameter("alpha", alpha)
	material.set_shader_parameter("finishable", values.z)
