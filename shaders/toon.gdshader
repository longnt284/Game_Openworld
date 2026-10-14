shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Soft two-tone cel shading with a cool shadow tint, rim light and a faint
// world-space "brush" variation. Works on the GL Compatibility renderer.
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 shade_tint : source_color = vec4(0.6, 0.66, 0.84, 1.0);
uniform float shade_threshold = 0.04;
uniform float shade_softness = 0.07;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float rim_strength = 0.16;
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.86, 1.0);
uniform float paint_strength = 0.05;
uniform float paint_scale = 0.08;
uniform sampler2D paint_noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform float sway = 0.0;
uniform bool use_vertex_color = false;
uniform bool double_sided_light = false;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (sway > 0.0) {
		float h = max(VERTEX.y, 0.0);
		float phase = TIME * 1.4 + world_pos.x * 0.21 + world_pos.z * 0.17;
		VERTEX.x += sin(phase) * sway * h * h * 0.01;
		VERTEX.z += cos(phase * 0.8) * sway * h * h * 0.008;
	}
}

void fragment() {
	vec3 base = albedo.rgb;
	if (use_vertex_color) {
		// Vertex colours are authored in sRGB; convert before lighting.
		vec3 c = COLOR.rgb;
		base *= mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
	}
	float n = texture(paint_noise, world_pos.xz * paint_scale + vec2(world_pos.y * 0.05)).r;
	base *= 1.0 + (n - 0.5) * 2.0 * paint_strength;
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = emission_color.rgb * emission_energy + rim_color.rgb * rim * rim_strength * base;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (double_sided_light) {
		ndl = abs(ndl) * 0.8;
	}
	float lit = smoothstep(shade_threshold - shade_softness, shade_threshold + shade_softness, ndl) * ATTENUATION;
	vec3 shade = mix(shade_tint.rgb, vec3(1.0), lit);
	DIFFUSE_LIGHT += ALBEDO * shade * LIGHT_COLOR / PI;
}
