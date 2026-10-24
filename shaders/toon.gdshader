shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, ambient_light_disabled;

// Three-band cel shading with a cool shadow tint and restrained rim light.
// Works on the GL Compatibility renderer.
// Terrain adds painted ground strokes and, under tree canopies (vertex alpha),
// sun flecks that drift like light through moving leaves. The sky reaches every
// material through global uniforms (project.godot [shader_globals], set by Atmosphere):
// vk_wind (x: sway amplitude, 1 when calm; y: gusts, a quick flutter and a lean
// downwind), vk_wet (rain-soaked ground and roofs: darker, with a sheen of the sky),
// vk_night (a moonlit grade; emissive lanterns glow brighter), vk_gloom (grey weather,
// dark regions). The sun or moon gets the two-tone cel shade; lantern lights at night
// (omni lights) get a soft pool instead.
global uniform vec2 vk_wind;
global uniform float vk_wet;
global uniform float vk_night;
global uniform float vk_gloom;
global uniform vec4 vk_sky : source_color;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 shade_tint : source_color = vec4(0.6, 0.66, 0.84, 1.0);
uniform float shade_threshold = 0.04;
uniform float shade_softness = 0.07;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float rim_strength = 0.045;
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.86, 1.0);
uniform float paint_strength = 0.0;
uniform float paint_scale = 0.08;
uniform sampler2D paint_noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform float sway = 0.0;
// Thin ground cover (grass, flowers, ferns) lit like the ground it stands on.
uniform float normal_up = 0.0;
uniform bool use_vertex_color = false;
// Imported (glTF) vertex colours reach the shader already linear; code-built meshes
// (terrain, MultiMesh instance tints) carry sRGB and are converted here.
uniform bool vertex_color_linear = false;
uniform bool double_sided_light = false;
// Hard-edged highlight band (hair sheen, polished metal).
uniform float spec_strength = 0.0;
uniform float spec_size = 0.2;
// Terrain only: painted ground strokes and dappled canopy light.
uniform float ground_detail = 0.0;
uniform float dapple = 0.0;
// Emission gain at full night (lanterns, glowing charms).
uniform float night_glow = 1.5;

varying vec3 world_pos;
varying float canopy;
varying float soaked;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	canopy = COLOR.a;
	if (normal_up > 0.0) {
		NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), normal_up));
	}
	if (sway > 0.0) {
		float h = max(VERTEX.y, 0.0);
		float phase = TIME * 1.4 + world_pos.x * 0.21 + world_pos.z * 0.17;
		float bend = sway * h * h * 0.01;
		VERTEX.x += sin(phase) * bend * vk_wind.x;
		VERTEX.z += cos(phase * 0.8) * bend * 0.8 * vk_wind.x;
		if (vk_wind.y > 0.0) {
			// Gusts: a fast flutter on top of the sway and a lean downwind (+x, the way the
			// ambient leaves drift), turned into this instance's own space.
			vec3 downwind = normalize((vec4(1.0, 0.0, 0.3, 0.0) * MODEL_MATRIX).xyz);
			float flutter = sin(TIME * 5.3 + world_pos.x * 0.7 + world_pos.z * 0.5 + h * 1.3);
			VERTEX += downwind * bend * vk_wind.y * (0.55 + flutter * 0.3);
		}
	}
}

void fragment() {
	vec3 base = albedo.rgb;
	if (use_vertex_color) {
		// Imported GLB palettes are linear; generated terrain/instance colours are sRGB.
		vec3 c = COLOR.rgb;
		if (vertex_color_linear && OUTPUT_IS_SRGB) {
			c = mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
		} else if (!vertex_color_linear && !OUTPUT_IS_SRGB) {
			c = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
		}
		base *= c;
	}
	float n = texture(paint_noise, world_pos.xz * paint_scale + vec2(world_pos.y * 0.05)).r;
	base *= 1.0 + (n - 0.5) * 2.0 * paint_strength;
	if (ground_detail > 0.0) {
		// Short directional strokes and speckle so open ground reads as painted grass and soil.
		float strokes = texture(paint_noise, world_pos.xz * vec2(2.4, 0.65)).r;
		float speckle = texture(paint_noise, world_pos.xz * 3.7 + vec2(0.31, 0.17)).r;
		base *= 1.0 + ((strokes - 0.5) * 0.22 + (speckle - 0.5) * 0.16) * ground_detail;
	}
	if (vk_gloom > 0.0) {
		float luma = dot(base, vec3(0.299, 0.587, 0.114));
		base = mix(base, vec3(luma), vk_gloom * 0.45) * (1.0 - vk_gloom * 0.2);
	}
	if (vk_night > 0.0) {
		// Moonlight greys colours and pulls them toward blue.
		float luma = dot(base, vec3(0.299, 0.587, 0.114));
		base = mix(base, luma * vec3(0.78, 0.9, 1.25), vk_night * 0.42);
	}
	soaked = 0.0;
	vec3 sheen = vec3(0.0);
	if (vk_wet > 0.0) {
		// Rain darkens what faces the sky and gives it a thin sheen at grazing angles.
		float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
		soaked = vk_wet * smoothstep(0.35, 0.85, up);
		base *= 1.0 - soaked * 0.22;
		sheen = vk_sky.rgb * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * soaked * 0.22;
	}
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	// A bounded cel fill avoids adding the sky ambient a second time on top of
	// the shadow band. It follows the existing night/weather globals.
	vec3 fill = base * mix(0.24, 0.06, vk_night) * (1.0 - vk_gloom * 0.3);
	EMISSION = fill + emission_color.rgb * emission_energy * (1.0 + vk_night * night_glow) + rim_color.rgb * rim * rim_strength * base + sheen;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (!LIGHT_IS_DIRECTIONAL) {
		// Lantern light (NightLights: shadowless omni lights): a soft pool wrapped a little past the
		// terminator, all of it fading with distance (ATTENUATION, which grows past 1 right by the
		// flame). The paper or stone right around the flame (within about half a metre) glows
		// whichever way it faces. Normalize the light energy as in the directional pass.
		float wrap = smoothstep(-0.35, 0.55, double_sided_light ? abs(ndl) : ndl);
		float through = 0.45 * smoothstep(2.0, 4.0, ATTENUATION);
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * max(wrap, through) / PI;
	} else {
		if (double_sided_light) {
			ndl = abs(ndl) * 0.8;
		}
		float lit = smoothstep(shade_threshold - shade_softness, shade_threshold + shade_softness, ndl) * ATTENUATION;
		if (dapple > 0.0 && canopy > 0.01) {
			vec2 drift = world_pos.xz * 0.42 + vec2(TIME * 0.045, TIME * 0.03);
			float leaves = texture(paint_noise, drift).r * 0.6 + texture(paint_noise, drift * 2.3 + 0.5).r * 0.4;
			float flecks = smoothstep(0.5, 0.56, leaves);
			lit *= mix(1.0, flecks, clamp(canopy * 1.7, 0.0, 1.0) * dapple);
		}
		float band = mix(0.58, 0.82, smoothstep(0.28, 0.34, ndl));
		band = mix(band, 1.0, smoothstep(0.72, 0.78, ndl));
		vec3 shade = mix(shade_tint.rgb * 0.65, vec3(band), lit);
		// Godot multiplies diffuse lighting by ALBEDO after light(). Applying it
		// here too crushes dark colours and exaggerates saturation.
		DIFFUSE_LIGHT += shade * LIGHT_COLOR * 0.62 / PI;
		if (spec_strength > 0.0) {
			float highlight = dot(reflect(-LIGHT, NORMAL), VIEW);
			SPECULAR_LIGHT += LIGHT_COLOR * spec_strength * smoothstep(1.0 - spec_size, 1.0 - spec_size + 0.03, highlight) * lit;
		}
		if (soaked > 0.0) {
			// Wet glint: a small, faint highlight of the sun or moon on soaked ground, only as strong
			// as the light breaking through the clouds (vk_sky.a). Broad terrain facets catch a wide
			// window, so it stays tight and dim or whole slopes would flash white.
			float glint = dot(reflect(-LIGHT, NORMAL), VIEW);
			SPECULAR_LIGHT += LIGHT_COLOR * soaked * 0.08 * vk_sky.a * smoothstep(0.985, 0.995, glint) * lit;
		}
	}
}
