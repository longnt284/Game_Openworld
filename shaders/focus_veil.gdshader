shader_type canvas_item;

// Tâm Nhãn (focus time): a cool veil over the whole screen that thickens toward the edges while
// every enemy is slowed. One full-screen ColorRect under the HUD; GameHUD writes "strength" only
// while the veil fades in or out, and the slow breathing comes from TIME.
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.56, 0.82, 0.96, 1.0);

void fragment() {
	// 0 in the middle, 1 at the middle of each side, about 1.4 in the corners (an elliptical vignette).
	float reach = length((UV - 0.5) * 2.0);
	float edge = smoothstep(0.5, 1.3, reach);
	float breath = 0.92 + 0.08 * sin(TIME * 5.0);
	COLOR = vec4(tint.rgb, strength * (0.08 + 0.62 * edge * breath));
}
