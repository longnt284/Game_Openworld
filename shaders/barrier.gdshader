shader_type spatial;
// Wind barrier around the boss arena: nearly clear face-on, brighter at grazing
// angles and near the ground, with slow rising bands so it reads as moving air.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.55, 0.95, 0.85, 1.0);
uniform float strength = 0.35;
uniform float wall_height = 9.0;

varying float height01;

void vertex() {
	height01 = clamp(VERTEX.y / wall_height + 0.5, 0.0, 1.0);
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, 3.0);
	float ground = 1.0 - smoothstep(0.0, 0.45, height01);
	float top_fade = 1.0 - smoothstep(0.6, 1.0, height01);
	float bands = 0.5 + 0.5 * sin(height01 * 26.0 - TIME * 1.6 + sin(UV.x * 40.0) * 1.2);
	ALBEDO = tint.rgb;
	ALPHA = clamp((rim * 0.9 + ground * 0.35 + bands * 0.06) * top_fade * strength, 0.0, 1.0);
}
