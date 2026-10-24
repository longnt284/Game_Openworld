shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Rain curtain: two open cylinders around the camera (RainFx) whose inside walls carry thin
// falling streaks. Each wall is cut into columns (UV.x around, UV2.x columns, UV2.y 0 for the
// near wall, 1 for the far one); a column rains when its hash falls under "intensity", so
// light rain is sparse and a storm fills every column. Streaks scroll down in world height,
// so the camera rising or falling never drags them, and lean downwind (+x, the way the
// foliage and leaves go) by "lean" metres per metre of fall. No scene depth is read (a depth
// copy every frame is too dear for the Web build): streaks fade toward the cylinder ends, and
// solid things in front hide the rain behind them by the depth test.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float lean = 0.0;
uniform vec4 tint : source_color = vec4(0.84, 0.89, 0.95, 1.0);
// Metres a second the streaks fall; the far wall falls a little slower (parallax).
uniform float speed = 15.0;
uniform float opacity = 0.42;

varying float columns;
varying float layer;
varying float height;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	columns = UV2.x;
	layer = UV2.y;
	// The wall's top sits upwind of its foot: drops blown along +x as they fall.
	VERTEX.x -= VERTEX.y * lean;
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float x = UV.x * columns;
	float column = floor(x);
	float seed = column + layer * 977.0;
	float pick = hash(seed + 0.37);
	if (pick > intensity) {
		discard;
	}
	float jitter = hash(seed + 5.1);
	// A thin line per column, anti-aliased by its on-screen width.
	float across = abs(fract(x) - 0.5 - (jitter - 0.5) * 0.5);
	float width = mix(0.045, 0.06, layer);
	float line = 1.0 - smoothstep(width, width + fwidth(x) * 1.2, across);
	// Streaks along the column: a bright head below a fading tail, spaced a few metres apart.
	float spacing = mix(3.2, 4.6, layer);
	float fall = TIME * speed * mix(1.0, 0.82, layer) * (0.85 + jitter * 0.3);
	float v = fract((height + fall) / spacing + hash(seed + 9.3) * 7.0);
	float tail = mix(0.34, 0.24, layer);
	float streak = smoothstep(0.0, 0.03, v) * (1.0 - smoothstep(0.03, tail, v));
	float ends = smoothstep(0.0, 0.2, UV.y) * (1.0 - smoothstep(0.75, 1.0, UV.y));
	ALBEDO = tint.rgb;
	ALPHA = line * streak * ends * opacity * mix(0.75, 1.0, layer);
}
