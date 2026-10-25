class_name StyleMedallion
extends Button
## A round, pressable Kiếm Quyết medallion for the Kiếm Quyết panel: the element glyph in its
## colour on a dark coin, a padlock while the style is unlearned, a gold rim on the selected one
## and small E/Q/X dots for the keys it is bound to.

var style: String = ""
var learned: bool = false
var chosen: bool = false
## Keys (e, q, x) this style is bound to in the loadout.
var bound: PackedStringArray = []

func setup(style_id: String, is_learned: bool, is_chosen: bool, keys: PackedStringArray) -> StyleMedallion:
	style = style_id
	learned = is_learned
	chosen = is_chosen
	bound = keys
	custom_minimum_size = Vector2(112, 128)
	flat = true
	focus_mode = Control.FOCUS_ALL
	tooltip_text = String(ContentDB.style(style).get("name", style))
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	return self

func _draw() -> void:
	var color: Color = StyleBook.color(style) if learned else UiDraw.LOCKED
	var center: Vector2 = Vector2(size.x * 0.5, 48)
	var hovered: bool = is_hovered() or has_focus()
	var radius: float = 40.0 if hovered or chosen else 37.0
	draw_circle(center + Vector2(0, 5), radius + 2.0, UiTheme.LIP)
	draw_circle(center, radius + 2.0, UiDraw.INK)
	draw_circle(center, radius, Color(color.darkened(0.62), 0.97) if learned else Color(0.13, 0.15, 0.16))
	draw_arc(center, radius - 2.0, 0.0, TAU, 40, UiTheme.GOLD if chosen else (color if hovered else color.darkened(0.3)), 4.0 if chosen else 3.0, true)
	UiDraw.element_icon(self, center, radius * 0.5, String(ContentDB.style(style).get("icon", "")), color)
	if not learned:
		UiDraw.padlock(self, center + Vector2(radius * 0.55, radius * 0.5), 16.0)
	for index: int in range(bound.size()):
		var at: Vector2 = center + Vector2(-radius * 0.62 + index * 15.0, -radius * 0.72)
		draw_circle(at, 9.0, UiDraw.INK)
		draw_circle(at, 7.5, UiTheme.CREAM)
		draw_string(UiTheme.BOLD_FONT, at + Vector2(-8, 4.5), bound[index].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 16.0, 12, UiTheme.INK)
	var name: String = String(ContentDB.style(style).get("name", style)).trim_suffix(" Quyết")
	UiDraw.outlined_text(self, Vector2(0, size.y - 8), name, 14, Color.WHITE if learned else UiTheme.MUTED, size.x, HORIZONTAL_ALIGNMENT_CENTER, 4)
