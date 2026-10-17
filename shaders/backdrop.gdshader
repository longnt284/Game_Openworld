shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

// Distant karst towers and cloud banks: vertex colours lit by a fixed sun direction,
// then faded toward the horizon colour by layer (aerial perspective without scene fog).
uniform vec4 haze_color : source_color = vec4(0.78, 0.88, 0.93, 1.0);
uniform float haze = 0.4;
uniform vec3 sun_direction = vec3(-0.45, 0.75, -0.5);
uniform float shadow_floor = 0.62;

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Imported glTF vertex colours already arrive linear.
	vec3 c = COLOR.rgb;
	float light = smoothstep(-0.05, 0.35, dot(world_normal, normalize(sun_direction)));
	c *= mix(shadow_floor, 1.08, light);
	ALBEDO = mix(c, haze_color.rgb, haze);
}
