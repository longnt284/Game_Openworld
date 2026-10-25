class_name SkillSlot
extends Control
## One HUD skill button: a block tile (E, Q) or a round seal (X) showing the bound Kiếm Quyết
## form's element glyph, a dark wipe draining as the cooldown runs with the seconds left on it,
## the key in a badge, cultivation pips, and for the ultimate a ring that fills with the charge
## meter and glows when it is full. Redraws only when what it shows changes.

var key_text: String = ""
var icon: String = "wind"
var tint: Color = UiTheme.JADE_LIGHT
var unlocked: bool = false
## 1 when ready (cooldown done, or a full charge meter on the ultimate).
var fill: float = 1.0
var seconds: float = 0.0
var level: int = 0
var ultimate: bool = false
## Flash on becoming ready, and the ultimate's pulse while full (seconds of animation).
var flash: float = 0.0
var pulse: float = 0.0
var _tile: StyleBoxFlat
var _badge: StyleBoxFlat

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tile = UiTheme.box(Color(0.05, 0.1, 0.11, 0.86), UiTheme.JADE, 3, 16)
	_tile.shadow_color = UiTheme.LIP
	_tile.shadow_offset = Vector2(0, 4)
	_badge = UiTheme.box(UiTheme.CREAM, UiTheme.INK, 2, 7)

func show_form(key: String, form_icon: String, color: Color, is_unlocked: bool, ready_fill: float, left: float, form_level: int) -> void:
	var was_ready: bool = unlocked and fill >= 0.999
	var rounded_left: float = ceilf(left * 10.0) / 10.0
	if key == key_text and form_icon == icon and color == tint and is_unlocked == unlocked and absf(ready_fill - fill) < 0.004 and rounded_left == seconds and form_level == level:
		return
	key_text = key
	icon = form_icon
	tint = color
	unlocked = is_unlocked
	fill = clampf(ready_fill, 0.0, 1.0)
	seconds = rounded_left
	level = form_level
	if unlocked and fill >= 0.999 and not was_ready:
		flash = 0.35
	queue_redraw()

func _process(delta: float) -> void:
	var animating: bool = flash > 0.0 or (ultimate and unlocked and fill >= 0.999)
	if not animating:
		return
	flash = maxf(0.0, flash - delta)
	pulse += delta
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - 4.0
	var ready: bool = unlocked and fill >= 0.999
	var color: Color = tint if unlocked else UiDraw.LOCKED
	if ultimate:
		draw_circle(center + Vector2(0, 4), radius + 1.0, UiTheme.LIP)
		draw_circle(center, radius + 1.0, Color(0.05, 0.1, 0.11, 0.88))
		draw_arc(center, radius - 3.0, 0.0, TAU, 48, Color(0.0, 0.0, 0.0, 0.55), 7.0, true)
		if unlocked and fill > 0.0:
			draw_arc(center, radius - 3.0, -PI * 0.5, -PI * 0.5 + TAU * fill, 48, color if ready else color.darkened(0.25), 7.0, true)
		if ready:
			var glow: float = 0.5 + 0.5 * sin(pulse * 5.0)
			draw_arc(center, radius + 3.0, 0.0, TAU, 48, Color(color.lightened(0.4), 0.35 + 0.45 * glow), 4.0, true)
	else:
		_tile.border_color = color if ready else color.darkened(0.5)
		_tile.bg_color = Color(0.05, 0.1, 0.11, 0.86) if unlocked else Color(0.08, 0.1, 0.1, 0.7)
		draw_style_box(_tile, Rect2(Vector2(2, 2), size - Vector2(4, 8)))
	var icon_center: Vector2 = center + (Vector2(0, -2) if not ultimate else Vector2.ZERO)
	UiDraw.element_icon(self, icon_center, radius * (0.42 if ultimate else 0.46), icon, color if ready or ultimate else color.darkened(0.25))
	if not unlocked:
		UiDraw.padlock(self, center + Vector2(radius * 0.45, radius * 0.35), radius * 0.36)
	elif not ultimate and fill < 0.999:
		# Cooldown: a dark curtain that lifts as the form recharges, with the seconds left on it.
		var inner: Rect2 = Rect2(Vector2(5, 5), size - Vector2(10, 14))
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * (1.0 - fill))), Color(0.0, 0.02, 0.03, 0.62))
		if seconds > 0.0:
			var text: String = ("%.1f" % seconds) if seconds < 3.0 else str(ceili(seconds))
			UiDraw.outlined_text(self, Vector2(0, center.y + 9), text, int(radius * 0.62), Color.WHITE, size.x)
	if flash > 0.0:
		var alpha: float = flash / 0.35
		if ultimate:
			draw_arc(center, radius + 1.0, 0.0, TAU, 48, Color(1, 1, 1, alpha), 5.0, true)
		else:
			var glow: StyleBoxFlat = UiTheme.box(Color(1, 1, 1, 0.18 * alpha), Color(1, 1, 1, alpha), 3, 16)
			draw_style_box(glow, Rect2(Vector2(2, 2), size - Vector2(4, 8)))
	# Cultivation pips along the top (I to III); the ultimate has none.
	if unlocked and not ultimate:
		for pip: int in range(3):
			var at: Vector2 = Vector2(center.x + (pip - 1) * 11.0, 11.0)
			draw_circle(at, 4.0, UiDraw.INK)
			draw_circle(at, 2.8, UiTheme.GOLD if pip < level else Color(0.3, 0.33, 0.33))
	# Key badge straddling the bottom edge.
	var font: Font = UiTheme.BOLD_FONT
	var label_width: float = maxf(26.0, font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 14.0)
	var badge: Rect2 = Rect2(Vector2(center.x - label_width * 0.5, size.y - 24.0), Vector2(label_width, 22.0))
	_badge.bg_color = UiTheme.GOLD if ready and ultimate else UiTheme.CREAM
	draw_style_box(_badge, badge)
	draw_string(font, Vector2(badge.position.x, badge.position.y + 16.5), key_text, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 15, UiTheme.INK)
