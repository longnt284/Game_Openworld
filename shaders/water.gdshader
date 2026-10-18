shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;

// Stylised river: turquoise bands, drifting brush noise, foam along the banks
// (UV.y = 0..1 across), a fresnel lift toward the sky colour and sun glints.
uniform vec4 deep_color : source_color = vec4(0.07, 0.46, 0.55, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.36, 0.8, 0.76, 1.0);
uniform vec4 sky_color : source_color = vec4(0.72, 0.88, 0.95, 1.0);
uniform vec4 foam_color : source_color = vec4(0.95, 0.99, 0.95, 1.0);
uniform float flow_speed = 0.35;
uniform float alpha = 0.88;
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
	float n3 = texture(flow_noise, world_pos.xz * 0.35 + vec2(TIME * 0.06, -TIME * 0.04)).r;
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, smoothstep(0.3, 1.0, across) + (n - 0.5) * 0.3);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col = mix(col, sky_color.rgb, fresnel * 0.55);
	float streak = smoothstep(0.62, 0.7, n2) * 0.35;
	float foam = smoothstep(0.78, 0.96, across + (n - 0.5) * 0.25);
	col = mix(col, foam_color.rgb, clamp(foam + streak, 0.0, 1.0));
	// Glints: hard sparkles where the ripple noise peaks.
	float glint = step(0.74, n3) * step(0.6, n2) * (1.0 - foam);
	ALBEDO = col;
	ALPHA = mix(alpha, 1.0, foam);
	ROUGHNESS = 0.2;
	SPECULAR = 0.3;
	EMISSION = col * 0.14 + vec3(1.0, 0.98, 0.9) * glint * 0.9;
}
