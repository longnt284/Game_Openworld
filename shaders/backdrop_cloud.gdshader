shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled, depth_draw_never;

// Low cloud banks among the distant karst towers: bright tops, cool undersides, and
// edges that fade out so the banks read as mist rather than solid shapes. They take
// the towers' light_tint.
uniform vec4 haze_color : source_color = vec4(0.78, 0.88, 0.93, 1.0);
uniform vec4 light_tint = vec4(1.0);
uniform float haze = 0.2;
uniform vec4 top_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 under_color : source_color = vec4(0.8, 0.87, 0.95, 1.0);

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = mix(under_color.rgb, top_color.rgb, smoothstep(-0.2, 0.5, world_normal.y));
	c *= light_tint.rgb;
	ALBEDO = mix(c, haze_color.rgb, haze);
	ALPHA = smoothstep(0.05, 0.8, dot(NORMAL, VIEW)) * 0.8;
}
