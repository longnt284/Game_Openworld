class_name PoiseBar
extends MeshInstance3D
## Small health and poise gauges over an ordinary foe's head (Enemy.update_poise_bar decides
## when they are wanted): fade in and out; health drops with a pale trail of what was just lost,
## poise empties as it drains and pulses gold while the foe can be finished. One unshaded
## billboard quad (shaders/poise_bar.gdshader), cheap on the Web build.

const SHADER: Shader = preload("res://shaders/poise_bar.gdshader")
const SIZE: Vector2 = Vector2(0.96, 0.19)
## Health per second the pale trail drains toward the current health (share of the bar).
const TRAIL_RATE: float = 0.9

var material: ShaderMaterial
var alpha: float = 0.0
## Last values written to the shader, so unchanged frames write nothing.
var shown: Vector3 = Vector3(-1.0, -1.0, -1.0)
var shown_health: Vector2 = Vector2(-1.0, -1.0)
var trail: float = 1.0
var trail_hold: float = 0.0

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

func show_poise(wanted: bool, ratio: float, finishable: bool, delta: float, health: float = 1.0) -> void:
	## ratio: Enemy.poise_ratio(); finishable: the gold pulse; health: share of health left.
	alpha = move_toward(alpha, 1.0 if wanted else 0.0, delta * 5.0)
	visible = alpha > 0.0
	if health < trail:
		if shown_health.x >= 0.0 and health < shown_health.x - 0.0001:
			trail_hold = 0.4
		if trail_hold > 0.0:
			trail_hold -= delta
		else:
			trail = maxf(health, trail - TRAIL_RATE * delta)
	else:
		trail = health
	if not visible:
		return
	var bars: Vector2 = Vector2(health, trail)
	if not bars.is_equal_approx(shown_health):
		shown_health = bars
		material.set_shader_parameter("health", health)
		material.set_shader_parameter("trail", trail)
	var values: Vector3 = Vector3(ratio, alpha, 1.0 if finishable else 0.0)
	if values.is_equal_approx(shown):
		return
	shown = values
	material.set_shader_parameter("fill", ratio)
	material.set_shader_parameter("alpha", alpha)
	material.set_shader_parameter("finishable", values.z)
