shader_type sky;

// Painterly gradient sky with a soft sun and drifting cloud bands.
uniform vec4 top_color : source_color = vec4(0.36, 0.62, 0.78, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.86, 0.89, 0.8, 1.0);
uniform vec4 ground_color : source_color = vec4(0.55, 0.62, 0.55, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.92, 0.72, 1.0);
uniform float cloud_coverage = 0.5;
uniform sampler2D cloud_noise : repeat_enable, filter_linear;

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 col = mix(horizon_color.rgb, top_color.rgb, smoothstep(0.0, 0.6, h));
	col = mix(col, ground_color.rgb, 1.0 - smoothstep(-0.2, 0.0, h));
	float sun = dot(dir, LIGHT0_DIRECTION);
	col += sun_color.rgb * (smoothstep(0.9990, 0.9995, sun) * 1.2 + pow(max(sun, 0.0), 48.0) * 0.3);
	if (h > 0.0) {
		vec2 uv = dir.xz / (h + 0.18) * 0.22 + vec2(TIME * 0.003, 0.0);
		float n = textureLod(cloud_noise, uv, 0.0).r * 0.65 + textureLod(cloud_noise, uv * 2.4 + 0.37, 0.0).r * 0.35;
		float c = smoothstep(cloud_coverage, cloud_coverage + 0.1, n) * smoothstep(0.0, 0.2, h);
		vec3 cloud = mix(vec3(1.0, 0.985, 0.95), horizon_color.rgb * 0.92, clamp(0.55 - n * 0.6, 0.0, 1.0));
		col = mix(col, cloud, c * 0.88);
	}
	COLOR = col;
}
