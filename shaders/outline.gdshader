shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

// Inverted-hull outline drawn as next_pass of character materials.
uniform vec4 outline_color : source_color = vec4(0.16, 0.13, 0.15, 1.0);
uniform float width = 0.0016;

void vertex() {
	vec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float distance_factor = clamp(-view_pos.z, 1.5, 40.0);
	view_pos += view_normal * width * distance_factor;
	POSITION = PROJECTION_MATRIX * vec4(view_pos, 1.0);
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
