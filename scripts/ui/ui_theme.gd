class_name UiTheme
extends RefCounted
## Shared look for every menu and HUD widget: ink-teal panels, cream text,
## jade borders and vermilion/gold accents. Fonts cover Vietnamese diacritics.

const BODY_FONT: FontFile = preload("res://assets/fonts/BeVietnamPro-Medium.ttf")
const BOLD_FONT: FontFile = preload("res://assets/fonts/BeVietnamPro-SemiBold.ttf")
const TITLE_FONT: FontFile = preload("res://assets/fonts/Lora-Variable.ttf")
const INK: Color = Color("13242a")
const PANEL: Color = Color(0.075, 0.14, 0.16, 0.93)
const JADE: Color = Color("2f9e94")
const JADE_LIGHT: Color = Color("86d4c6")
const CREAM: Color = Color("f3e6c8")
const MUTED: Color = Color("b8b09a")
const VERMILION: Color = Color("d2523f")
const GOLD: Color = Color("e9b24a")

static var _theme: Theme
static var _title: FontVariation

static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font = BODY_FONT
	_theme.default_font_size = 17
	_theme.set_color("font_color", "Label", CREAM)
	_theme.set_color("font_shadow_color", "Label", Color(0.03, 0.06, 0.06, 0.8))
	_theme.set_constant("shadow_offset_x", "Label", 1)
	_theme.set_constant("shadow_offset_y", "Label", 1)
	_theme.set_stylebox("panel", "PanelContainer", panel_style())
	_theme.set_stylebox("panel", "Panel", panel_style())
	var normal: StyleBoxFlat = _box(Color(0.12, 0.22, 0.23, 0.95), JADE.darkened(0.35), 1)
	var hover: StyleBoxFlat = _box(Color(0.16, 0.32, 0.31, 0.98), JADE, 2)
	var pressed: StyleBoxFlat = _box(Color(0.2, 0.38, 0.35, 1.0), JADE_LIGHT, 2)
	var disabled: StyleBoxFlat = _box(Color(0.1, 0.14, 0.15, 0.8), Color(0.25, 0.3, 0.3), 1)
	for state: Array in [["normal", normal], ["hover", hover], ["pressed", pressed], ["focus", hover], ["disabled", disabled]]:
		_theme.set_stylebox(state[0], "Button", state[1])
	_theme.set_color("font_color", "Button", CREAM)
	_theme.set_color("font_hover_color", "Button", Color.WHITE)
	_theme.set_color("font_focus_color", "Button", Color.WHITE)
	_theme.set_color("font_disabled_color", "Button", Color(0.55, 0.55, 0.5))
	_theme.set_font("font", "Button", BOLD_FONT)
	_theme.set_font_size("font_size", "Button", 17)
	var slider_track: StyleBoxFlat = _box(Color(0.1, 0.18, 0.18), JADE.darkened(0.4), 1)
	slider_track.content_margin_top = 4
	slider_track.content_margin_bottom = 4
	_theme.set_stylebox("slider", "HSlider", slider_track)
	var fill: StyleBoxFlat = _box(JADE, JADE, 0)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	_theme.set_stylebox("grabber_area", "HSlider", fill)
	_theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	_theme.set_stylebox("panel", "TabContainer", panel_style())
	_theme.set_color("font_selected_color", "TabBar", GOLD)
	_theme.set_color("font_unselected_color", "TabBar", MUTED)
	_theme.set_color("font_hovered_color", "TabBar", CREAM)
	_theme.set_stylebox("tab_selected", "TabBar", _box(Color(0.14, 0.27, 0.27), JADE, 2))
	_theme.set_stylebox("tab_unselected", "TabBar", _box(Color(0.08, 0.14, 0.15), Color(0.2, 0.3, 0.3), 1))
	_theme.set_stylebox("tab_hovered", "TabBar", _box(Color(0.12, 0.22, 0.23), JADE, 1))
	_theme.set_font("font", "TabBar", BOLD_FONT)
	_theme.set_stylebox("normal", "LineEdit", _box(INK, JADE.darkened(0.4), 1))
	_theme.set_stylebox("panel", "ItemList", _box(Color(0.06, 0.11, 0.12, 0.9), JADE.darkened(0.5), 1))
	_theme.set_color("font_color", "ItemList", CREAM)
	_theme.set_color("font_selected_color", "ItemList", GOLD)
	_theme.set_stylebox("selected", "ItemList", _box(Color(0.16, 0.3, 0.29), JADE, 1))
	_theme.set_stylebox("selected_focus", "ItemList", _box(Color(0.16, 0.3, 0.29), JADE, 1))
	_theme.set_color("default_color", "RichTextLabel", CREAM)
	_theme.set_font("normal_font", "RichTextLabel", BODY_FONT)
	_theme.set_font("bold_font", "RichTextLabel", BOLD_FONT)
	_theme.set_font_size("normal_font_size", "RichTextLabel", 17)
	_theme.set_font_size("bold_font_size", "RichTextLabel", 17)
	_theme.set_stylebox("normal", "OptionButton", normal)
	_theme.set_stylebox("hover", "OptionButton", hover)
	_theme.set_stylebox("pressed", "OptionButton", pressed)
	_theme.set_stylebox("focus", "OptionButton", hover)
	_theme.set_stylebox("panel", "PopupMenu", panel_style())
	_theme.set_color("font_color", "PopupMenu", CREAM)
	_theme.set_color("font_color", "CheckBox", CREAM)
	_theme.set_stylebox("background", "ProgressBar", _box(Color(0.05, 0.08, 0.09, 0.85), Color(0, 0, 0, 0.6), 1))
	return _theme

static func title_font(weight: int = 600) -> FontVariation:
	if _title == null:
		_title = FontVariation.new()
		_title.base_font = TITLE_FONT
		_title.variation_opentype = {"wght": weight}
	return _title

static func _box(color: Color, border: Color, width: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(6)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

static func panel_style() -> StyleBoxFlat:
	var box: StyleBoxFlat = _box(PANEL, JADE.darkened(0.25), 2)
	box.set_corner_radius_all(10)
	box.content_margin_left = 26
	box.content_margin_right = 26
	box.content_margin_top = 20
	box.content_margin_bottom = 20
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 12
	return box

static func label(text: String, size: int = 17, color: Color = CREAM, bold: bool = false) -> Label:
	var node: Label = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	if bold:
		node.add_theme_font_override("font", BOLD_FONT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func title(text: String, size: int = 34, color: Color = CREAM) -> Label:
	var node: Label = label(text, size, color)
	node.add_theme_font_override("font", title_font())
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	node.add_theme_constant_override("shadow_offset_y", 2)
	return node

static func button(text: String, callback: Callable, min_width: float = 260.0) -> Button:
	var node: Button = Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(min_width, 40)
	node.pressed.connect(callback)
	return node

static func bar(fill: Color, size: Vector2) -> ProgressBar:
	var node: ProgressBar = ProgressBar.new()
	node.custom_minimum_size = size
	node.show_percentage = false
	var style: StyleBoxFlat = _box(fill, fill.lightened(0.3), 0)
	style.set_corner_radius_all(4)
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	node.add_theme_stylebox_override("fill", style)
	var back: StyleBoxFlat = _box(Color(0.04, 0.07, 0.08, 0.8), Color(0.0, 0.0, 0.0, 0.7), 1)
	back.set_corner_radius_all(4)
	node.add_theme_stylebox_override("background", back)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
