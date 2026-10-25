class_name HudBar
extends Control
## Chunky rounded gauge for the HUD: a pale "trail" that lags behind a drop (so a big hit
## reads as a chunk lost), a glossy band along the top of the fill, optional segment ticks and
## optional "current / max" text in the middle. max_value and value mirror ProgressBar.

var max_value: float = 100.0
var value: float = 100.0
var fill_color: Color = UiTheme.VERMILION
var trail_color: Color = Color(1.0, 0.92, 0.75)
var show_text: bool = false
## Divides the bar into this many cells with thin ticks (0 = none); the boss bar uses it.
var segments: int = 0
var trail: float = 100.0
var trail_hold: float = 0.0
var _back: StyleBoxFlat
var _fill: StyleBoxFlat

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back = UiTheme.box(Color(0.03, 0.06, 0.07, 0.85), UiDraw.INK, 2, 8)
	_fill = UiTheme.box(fill_color, Color(0, 0, 0, 0), 0, 6)

func setup(color: Color, minimum: Vector2, text: bool = false) -> HudBar:
	fill_color = color
	custom_minimum_size = minimum
	show_text = text
	return self

func set_values(current: float, maximum: float) -> void:
	maximum = maxf(maximum, 0.001)
	current = clampf(current, 0.0, maximum)
	if is_equal_approx(current, value) and is_equal_approx(maximum, max_value):
		return
	if not is_equal_approx(maximum, max_value):
		# A new scale (another boss, a level up) starts clean: no trail from the old one.
		trail = current
		trail_hold = 0.0
	elif current < value:
		trail_hold = 0.45
		trail = maxf(trail, value)
	else:
		trail = current
	value = current
	max_value = maximum
	queue_redraw()

func _process(delta: float) -> void:
	if trail <= value:
		return
	if trail_hold > 0.0:
		trail_hold -= delta
		return
	trail = maxf(value, trail - max_value * delta * 0.9)
	queue_redraw()

func _draw() -> void:
	var radius: int = maxi(2, int(size.y * 0.5))
	_back.set_corner_radius_all(radius)
	draw_style_box(_back, Rect2(Vector2.ZERO, size))
	var inner: Rect2 = Rect2(Vector2(2, 2), size - Vector2(4, 4))
	_fill.set_corner_radius_all(maxi(1, radius - 2))
	var trail_width: float = inner.size.x * clampf(trail / max_value, 0.0, 1.0)
	if trail_width > value / max_value * inner.size.x + 0.5:
		_fill.bg_color = trail_color
		draw_style_box(_fill, Rect2(inner.position, Vector2(trail_width, inner.size.y)))
	var width: float = inner.size.x * clampf(value / max_value, 0.0, 1.0)
	if width >= 1.0:
		_fill.bg_color = fill_color
		draw_style_box(_fill, Rect2(inner.position, Vector2(maxf(width, minf(inner.size.y, inner.size.x)), inner.size.y)))
		if inner.size.y >= 6.0:
			_fill.bg_color = Color(1, 1, 1, 0.22)
			draw_style_box(_fill, Rect2(inner.position + Vector2(2, 1), Vector2(maxf(0.0, width - 4.0), inner.size.y * 0.38)))
	if segments > 1:
		for cut: int in range(1, segments):
			var x: float = inner.position.x + inner.size.x * cut / segments
			draw_line(Vector2(x, inner.position.y + 1), Vector2(x, inner.end.y - 1), Color(0, 0, 0, 0.45), 2.0)
	if show_text and size.y >= 14.0:
		var text: String = "%d / %d" % [roundi(value), roundi(max_value)]
		UiDraw.outlined_text(self, Vector2(0, size.y * 0.5 + size.y * 0.27), text, int(clampf(size.y * 0.66, 11.0, 16.0)), Color.WHITE, size.x, HORIZONTAL_ALIGNMENT_CENTER, 4)
