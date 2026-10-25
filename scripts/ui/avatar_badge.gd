class_name AvatarBadge
extends Control
## Lâm An's round badge at the corner of the vitals: a medallion ringed in the colour of the
## Kiếm Quyết on E with its element glyph, the health share as a thin arc around it and the
## level in a gold coin at the bottom right.

var icon: String = "wind"
var tint: Color = UiTheme.JADE_LIGHT
var level: int = 1
var health_share: float = 1.0
var points: int = 0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(76, 76)

func show_state(style_icon: String, color: Color, current_level: int, share: float, spare_points: int) -> void:
	share = clampf(share, 0.0, 1.0)
	if style_icon == icon and color == tint and current_level == level and absf(share - health_share) < 0.005 and spare_points == points:
		return
	icon = style_icon
	tint = color
	level = current_level
	health_share = share
	points = spare_points
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = Vector2(36, 36)
	draw_circle(center + Vector2(0, 4), 34.0, UiTheme.LIP)
	draw_circle(center, 34.0, UiDraw.INK)
	draw_circle(center, 30.0, Color(0.08, 0.17, 0.18))
	draw_arc(center, 31.5, -PI * 0.5, -PI * 0.5 + TAU * health_share, 48, UiTheme.VERMILION.lightened(0.1), 4.0, true)
	draw_circle(center, 25.0, tint.darkened(0.55))
	draw_arc(center, 25.0, 0.0, TAU, 40, tint, 3.0, true)
	UiDraw.element_icon(self, center, 15.0, icon, tint)
	var coin: Vector2 = Vector2(62, 62)
	draw_circle(coin, 14.0, UiDraw.INK)
	draw_circle(coin, 12.0, UiTheme.GOLD)
	UiDraw.outlined_text(self, Vector2(coin.x - 14, coin.y + 5), str(level), 14 if level < 10 else 12, UiTheme.INK, 28.0, HORIZONTAL_ALIGNMENT_CENTER, 0)
	if points > 0:
		# Unspent cultivation points: a small jade plus at the top right.
		var badge: Vector2 = Vector2(64, 10)
		draw_circle(badge, 10.0, UiDraw.INK)
		draw_circle(badge, 8.0, UiTheme.JADE_LIGHT)
		draw_line(badge - Vector2(4, 0), badge + Vector2(4, 0), UiTheme.INK, 2.4)
		draw_line(badge - Vector2(0, 4), badge + Vector2(0, 4), UiTheme.INK, 2.4)
