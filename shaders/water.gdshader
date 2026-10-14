shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;

// Stylised river: banded colour, drifting brush noise and foam along the banks (UV.y = 0..1 across).
uniform vec4 deep_color : source_color = vec4(0.18, 0.5, 0.55, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.42, 0.74, 0.7, 1.0);
uniform vec4 foam_color : source_color = vec4(0.93, 0.97, 0.92, 1.0);
uniform float flow_speed = 0.35;
uniform float alpha = 0.86;
uniform sampler2D flow_noise : repeat_enable, filter_linear_mipmap;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 1.3 + world_pos.x * 0.35 + world_pos.z * 0.2) * 0.04;
}

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;
	vec2 drift = vec2(UV.x * 0.08 - TIME * flow_speed * 0.05, UV.y * 0.6);
	float n = texture(flow_noise, drift).r;
	float n2 = texture(flow_noise, drift * 2.7 + vec2(TIME * 0.02, 0.3)).r;
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, smoothstep(0.35, 1.0, across) + (n - 0.5) * 0.3);
	float streak = smoothstep(0.62, 0.7, n2) * 0.35;
	float foam = smoothstep(0.78, 0.96, across + (n - 0.5) * 0.25);
	col = mix(col, foam_color.rgb, clamp(foam + streak, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = mix(alpha, 1.0, foam);
	ROUGHNESS = 0.2;
	SPECULAR = 0.3;
	EMISSION = col * 0.12;
}
