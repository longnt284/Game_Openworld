shader_type sky;

// Painted anime sky: deep blue zenith fading to a pale horizon, a soft sun and
// two-tone cumulus clouds (bright sunlit crowns, cool blue undersides, crisp edges).
uniform vec4 top_color : source_color = vec4(0.2, 0.5, 0.82, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.78, 0.88, 0.93, 1.0);
uniform vec4 ground_color : source_color = vec4(0.55, 0.62, 0.55, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.94, 0.78, 1.0);
uniform vec4 cloud_light : source_color = vec4(1.0, 0.99, 0.96, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.66, 0.76, 0.9, 1.0);
uniform float cloud_coverage = 0.52;
uniform sampler2D cloud_noise : repeat_enable, filter_linear;

float density(vec2 uv) {
	return textureLod(cloud_noise, uv, 0.0).r * 0.62 + textureLod(cloud_noise, uv * 2.3 + 0.37, 0.0).r * 0.38;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 col = mix(horizon_color.rgb, top_color.rgb, pow(smoothstep(-0.02, 0.6, h), 0.65));
	col = mix(col, ground_color.rgb, 1.0 - smoothstep(-0.12, 0.0, h));
	float sun = dot(dir, LIGHT0_DIRECTION);
	col += sun_color.rgb * (smoothstep(0.9988, 0.9993, sun) * 1.4 + pow(max(sun, 0.0), 64.0) * 0.32 + pow(max(sun, 0.0), 5.0) * 0.06);
	if (h > -0.02) {
		vec2 uv = dir.xz / (max(h, 0.0) + 0.12) * 0.16 + vec2(TIME * 0.0024, TIME * 0.0011);
		float n = density(uv);
		// Clouds bank up toward the horizon like summer cumulus.
		float cover = cloud_coverage - (1.0 - smoothstep(0.0, 0.35, h)) * 0.07;
		float body = smoothstep(cover, cover + 0.03, n);
		vec2 toward_sun = normalize(LIGHT0_DIRECTION.xz + vec2(0.0001)) * 0.025;
		float lit = step(density(uv + toward_sun), n - 0.012);
		float core = smoothstep(cover + 0.05, cover + 0.2, n);
		vec3 cloud = mix(cloud_light.rgb, cloud_shadow.rgb, clamp(core * 0.85 - lit * 0.6, 0.0, 1.0));
		cloud = mix(cloud, horizon_color.rgb, (1.0 - smoothstep(0.0, 0.22, h)) * 0.4);
		col = mix(col, cloud, body * smoothstep(-0.02, 0.06, h));
	}
	COLOR = col;
}
