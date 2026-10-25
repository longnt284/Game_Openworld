shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_mix;

// Overhead gauges for ordinary foes on one camera-facing quad: a red health bar on top (with a
// pale trail of the health just lost) and a thin poise bar under it. While the foe is broken and
// can be finished, the poise bar turns gold and its frame flashes (TIME drives the pulse, so the
// script only writes uniforms when they change).
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float health : hint_range(0.0, 1.0) = 1.0;
uniform float trail : hint_range(0.0, 1.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform float finishable : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fill_color : source_color = vec4(0.95, 0.88, 0.7, 1.0);
uniform vec4 health_color : source_color = vec4(0.9, 0.27, 0.2, 1.0);
uniform vec4 trail_color : source_color = vec4(1.0, 0.92, 0.75, 1.0);
uniform vec4 finish_color : source_color = vec4(1.0, 0.7, 0.24, 1.0);
uniform vec4 back_color : source_color = vec4(0.05, 0.07, 0.08, 0.72);
uniform vec4 frame_color : source_color = vec4(0.0, 0.0, 0.0, 0.85);

void vertex() {
	// Billboard that keeps the node's scale (as StandardMaterial3D's billboard mode does).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

// One framed gauge: returns the colour and alpha at uv (0..1 across this gauge).
vec4 gauge(vec2 uv, float value, vec3 color, float lag, float gold, float edge_y) {
	vec2 edge = min(uv, 1.0 - uv);
	float frame = 1.0 - step(0.018, edge.x) * step(edge_y, edge.y);
	float inner = clamp((uv.x - 0.018) / 0.964, 0.0, 1.0);
	float filled = step(inner, value) * step(0.001, value);
	float trailed = step(inner, lag) * (1.0 - filled);
	float wave = 0.5 + 0.5 * sin(TIME * 11.0);
	vec3 body = mix(back_color.rgb, color, filled);
	body = mix(body, trail_color.rgb, trailed);
	// A glossy band along the top of the fill.
	body += filled * step(0.62, uv.y) * 0.12;
	body = mix(body, finish_color.rgb * (0.85 + 0.25 * wave), gold);
	float body_alpha = max(max(mix(back_color.a, 1.0, filled), trailed), gold);
	vec3 rim = mix(frame_color.rgb, vec3(1.0, 0.93, 0.72), gold * wave);
	return vec4(mix(body, rim, frame), mix(body_alpha, max(frame_color.a, gold), frame));
}

void fragment() {
	// UV.y runs top to bottom: health in the upper 58%, a gap, then the poise bar.
	vec4 result = vec4(0.0);
	if (UV.y < 0.58) {
		result = gauge(vec2(UV.x, 1.0 - UV.y / 0.58), health, health_color.rgb, trail, 0.0, 0.16);
	} else if (UV.y > 0.7) {
		result = gauge(vec2(UV.x, 1.0 - (UV.y - 0.7) / 0.3), fill, fill_color.rgb, 0.0, finishable, 0.24);
	}
	ALBEDO = result.rgb;
	ALPHA = result.a * alpha;
}
