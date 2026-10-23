shader_type sky;

// Painted anime sky: deep blue zenith fading to a pale horizon, a soft sun and
// two-tone cumulus clouds (bright sunlit crowns, cool blue undersides, crisp edges).
// Atmosphere drives the hour and the weather: at night stars fade in and LIGHT0 (the
// moon then) is drawn as a pale disc with a halo; storm softens the clouds into a deck
// with fast scud beneath; flash lights the clouds for a lightning stroke.
uniform vec4 top_color : source_color = vec4(0.2, 0.5, 0.82, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.78, 0.88, 0.93, 1.0);
uniform vec4 ground_color : source_color = vec4(0.55, 0.62, 0.55, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.94, 0.78, 1.0);
uniform vec4 cloud_light : source_color = vec4(1.0, 0.99, 0.96, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.66, 0.76, 0.9, 1.0);
uniform float cloud_coverage = 0.52;
uniform sampler2D cloud_noise : repeat_enable, filter_linear;
// 0 by day, 1 at night: stars.
uniform float night = 0.0;
// 1 while LIGHT0 is the moon, 0 for the sun; disc fades it near the horizon.
uniform float moon = 0.0;
uniform float disc = 1.0;
uniform float storm = 0.0;
uniform float flash = 0.0;

float density(vec2 uv) {
	return textureLod(cloud_noise, uv, 0.0).r * 0.62 + textureLod(cloud_noise, uv * 2.3 + 0.37, 0.0).r * 0.38;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float stars(vec3 dir) {
	// One star in a few percent of the cells of a grid around the eye, jittered, a pixel or two wide.
	vec3 p = dir * 160.0;
	vec3 cell = floor(p);
	float h = hash(cell);
	if (h < 0.968) {
		return 0.0;
	}
	float rank = (h - 0.968) / 0.032;
	vec3 jitter = vec3(hash(cell + 7.1), hash(cell + 3.7), hash(cell + 11.3)) - 0.5;
	float d = length(fract(p) - 0.5 - jitter * 0.5);
	float twinkle = 0.75 + 0.25 * sin(TIME * (1.3 + rank * 2.0) + h * 91.0);
	return smoothstep(0.17 + rank * 0.11, 0.02, d) * (0.6 + rank * 0.9) * twinkle;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 col = mix(horizon_color.rgb, top_color.rgb, pow(smoothstep(-0.02, 0.6, h), 0.65));
	col = mix(col, ground_color.rgb, 1.0 - smoothstep(-0.12, 0.0, h));
	if (night > 0.001 && h > 0.0) {
		col += vec3(0.86, 0.9, 1.0) * stars(dir) * night * smoothstep(0.0, 0.3, h);
	}
	float sun = dot(dir, LIGHT0_DIRECTION);
	if (moon > 0.5) {
		// A pale moon with soft grey seas and a cool halo.
		float body = smoothstep(0.99962, 0.99968, sun);
		vec3 side = normalize(cross(LIGHT0_DIRECTION, vec3(0.0, 1.0, 0.001)));
		vec3 up = cross(side, LIGHT0_DIRECTION);
		vec2 face = vec2(dot(dir, side), dot(dir, up)) * 14.0;
		float seas = smoothstep(0.45, 0.62, textureLod(cloud_noise, face + vec2(0.3, 0.7), 0.0).r);
		vec3 lunar = mix(vec3(0.97, 0.97, 1.0), vec3(0.74, 0.77, 0.86), seas * 0.7);
		col = mix(col, lunar, body * disc);
		col += mix(sun_color.rgb, vec3(0.8, 0.86, 1.0), 0.5) * (pow(max(sun, 0.0), 900.0) * 0.3 + pow(max(sun, 0.0), 40.0) * 0.07) * disc;
	} else {
		col += sun_color.rgb * (smoothstep(0.9988, 0.9993, sun) * 1.4 + pow(max(sun, 0.0), 64.0) * 0.32 + pow(max(sun, 0.0), 5.0) * 0.06) * disc;
	}
	if (h > -0.02) {
		vec2 uv = dir.xz / (max(h, 0.0) + 0.12) * 0.16 + vec2(TIME * 0.0024, TIME * 0.0011);
		float n = density(uv);
		// Clouds bank up toward the horizon like summer cumulus.
		float cover = cloud_coverage - (1.0 - smoothstep(0.0, 0.35, h)) * 0.07;
		// A storm softens the crisp edges into one heavy deck: few sunlit crowns, and cores that
		// darken gradually instead of in cel bands.
		float body = smoothstep(cover, cover + 0.03 + storm * 0.22, n);
		vec2 toward_sun = normalize(LIGHT0_DIRECTION.xz + vec2(0.0001)) * 0.025;
		float lit = step(density(uv + toward_sun), n - 0.012) * (1.0 - storm * 0.8);
		float core = smoothstep(cover + 0.05, cover + 0.2 + storm * 0.35, n);
		vec3 cloud = mix(cloud_light.rgb, cloud_shadow.rgb, clamp(core * 0.85 - lit * 0.6, 0.0, 1.0));
		if (storm > 0.0) {
			// Low scud racing under the deck.
			vec2 low = dir.xz / (max(h, 0.0) + 0.08) * 0.3 + vec2(TIME * 0.018, TIME * 0.006);
			float scud = smoothstep(0.42, 0.66, density(low)) * storm;
			cloud = mix(cloud, cloud_shadow.rgb * 0.82, scud * 0.65);
			body = max(body, scud);
		}
		cloud = mix(cloud, horizon_color.rgb, (1.0 - smoothstep(0.0, 0.22, h)) * 0.4);
		if (flash > 0.0) {
			// Lightning lights the deck from inside, brightest in the thick cores.
			cloud += vec3(0.78, 0.84, 1.0) * flash * (0.5 + core * 0.9);
			col += vec3(0.5, 0.55, 0.7) * flash * 0.35;
		}
		col = mix(col, cloud, body * smoothstep(-0.02, 0.06, h));
	}
	COLOR = col;
}
