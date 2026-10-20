shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_mix;

// Overhead poise gauge for ordinary foes: one camera-facing quad with a dark frame and a pale
// fill for the poise left. While the foe is broken and can be finished, the body turns gold and
// the frame flashes (TIME drives the pulse, so the script only writes uniforms when they change).
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform float finishable : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fill_color : source_color = vec4(0.95, 0.88, 0.7, 1.0);
uniform vec4 finish_color : source_color = vec4(1.0, 0.7, 0.24, 1.0);
uniform vec4 back_color : source_color = vec4(0.05, 0.07, 0.08, 0.72);
uniform vec4 frame_color : source_color = vec4(0.0, 0.0, 0.0, 0.85);

void vertex() {
	// Billboard that keeps the node's scale (as StandardMaterial3D's billboard mode does).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 edge = min(UV, 1.0 - UV);
	float frame = 1.0 - step(0.022, edge.x) * step(0.2, edge.y);
	// Inner 0..1 across the frame, so an empty bar stays empty and a full one reaches the frame.
	float inner = clamp((UV.x - 0.022) / 0.956, 0.0, 1.0);
	float filled = step(inner, fill) * step(0.001, fill);
	float wave = 0.5 + 0.5 * sin(TIME * 11.0);
	// Broken: a solid gold body that breathes, inside a rim flashing toward pale gold.
	vec3 body = mix(back_color.rgb, fill_color.rgb, filled);
	body = mix(body, finish_color.rgb * (0.85 + 0.25 * wave), finishable);
	float body_alpha = max(mix(back_color.a, 1.0, filled), finishable);
	vec3 rim = mix(frame_color.rgb, vec3(1.0, 0.93, 0.72), finishable * wave);
	ALBEDO = mix(body, rim, frame);
	ALPHA = mix(body_alpha, max(frame_color.a, finishable), frame) * alpha;
}
