class_name UiTheme
extends RefCounted
## Shared look for every menu and HUD widget, in the chunky block style of the art kit: deep
## ink-teal panels with thick rounded rims, pressable buttons with a darker lip under them,
## cream text, jade borders and vermilion/gold accents. HUD text carries an ink outline so it
## reads over a bright sky. Fonts cover Vietnamese diacritics.

const BODY_FONT: FontFile = preload("res://assets/fonts/BeVietnamPro-Medium.ttf")
const BOLD_FONT: FontFile = preload("res://assets/fonts/BeVietnamPro-SemiBold.ttf")
const TITLE_FONT: FontFile = preload("res://assets/fonts/Lora-Variable.ttf")
const INK: Color = Color("13242a")
const PANEL: Color = Color(0.07, 0.13, 0.15, 0.94)
const PANEL_LIGHT: Color = Color(0.11, 0.2, 0.22, 0.96)
const JADE: Color = Color("2f9e94")
const JADE_LIGHT: Color = Color("86d4c6")
const CREAM: Color = Color("f3e6c8")
const MUTED: Color = Color("b8b09a")
const VERMILION: Color = Color("d2523f")
const GOLD: Color = Color("e9b24a")
const LIP: Color = Color(0.02, 0.05, 0.06, 0.9)
## Radii: panels are rounder than the buttons inside them, as in the block kit.
const PANEL_RADIUS: int = 16
const BUTTON_RADIUS: int = 10

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
	_button_styles("Button", Color(0.13, 0.29, 0.3), JADE.darkened(0.25), CREAM)
	# Primary actions: a gold block with ink text (AccentButton theme variation).
	_theme.set_type_variation("AccentButton", "Button")
	_button_styles("AccentButton", Color("d99a32"), Color("f6d27a"), INK)
	_theme.set_font("font", "Button", BOLD_FONT)
	_theme.set_font_size("font_size", "Button", 17)
	var slider_track: StyleBoxFlat = _box(Color(0.08, 0.15, 0.16), JADE.darkened(0.4), 2, 8)
	slider_track.content_margin_top = 5
	slider_track.content_margin_bottom = 5
	_theme.set_stylebox("slider", "HSlider", slider_track)
	var fill: StyleBoxFlat = _box(JADE, JADE_LIGHT, 0, 8)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	_theme.set_stylebox("grabber_area", "HSlider", fill)
	_theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	_theme.set_stylebox("panel", "TabContainer", _box(Color(0.06, 0.11, 0.12, 0.9), JADE.darkened(0.45), 2, 12))
	_theme.set_color("font_selected_color", "TabBar", INK)
	_theme.set_color("font_unselected_color", "TabBar", MUTED)
	_theme.set_color("font_hovered_color", "TabBar", CREAM)
	var tab_on: StyleBoxFlat = _box(GOLD, GOLD.lightened(0.3), 0, 10)
	tab_on.corner_radius_bottom_left = 0
	tab_on.corner_radius_bottom_right = 0
	var tab_off: StyleBoxFlat = _box(Color(0.08, 0.15, 0.16), Color(0.2, 0.3, 0.3), 2, 10)
	tab_off.corner_radius_bottom_left = 0
	tab_off.corner_radius_bottom_right = 0
	var tab_hover: StyleBoxFlat = tab_off.duplicate() as StyleBoxFlat
	tab_hover.bg_color = Color(0.13, 0.25, 0.26)
	tab_hover.border_color = JADE
	_theme.set_stylebox("tab_selected", "TabBar", tab_on)
	_theme.set_stylebox("tab_unselected", "TabBar", tab_off)
	_theme.set_stylebox("tab_hovered", "TabBar", tab_hover)
	_theme.set_font("font", "TabBar", BOLD_FONT)
	_theme.set_stylebox("normal", "LineEdit", _box(INK, JADE.darkened(0.4), 2))
	_theme.set_stylebox("panel", "ItemList", _box(Color(0.05, 0.1, 0.11, 0.92), JADE.darkened(0.5), 2, 12))
	_theme.set_color("font_color", "ItemList", CREAM)
	_theme.set_color("font_selected_color", "ItemList", INK)
	_theme.set_color("font_hovered_color", "ItemList", Color.WHITE)
	_theme.set_stylebox("selected", "ItemList", _box(JADE_LIGHT, JADE_LIGHT, 0, 8))
	_theme.set_stylebox("selected_focus", "ItemList", _box(JADE_LIGHT, Color.WHITE, 2, 8))
	_theme.set_stylebox("hovered", "ItemList", _box(Color(0.14, 0.28, 0.28), JADE, 0, 8))
	_theme.set_constant("v_separation", "ItemList", 6)
	_theme.set_color("default_color", "RichTextLabel", CREAM)
	_theme.set_font("normal_font", "RichTextLabel", BODY_FONT)
	_theme.set_font("bold_font", "RichTextLabel", BOLD_FONT)
	_theme.set_font_size("normal_font_size", "RichTextLabel", 17)
	_theme.set_font_size("bold_font_size", "RichTextLabel", 17)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		_theme.set_stylebox(state, "OptionButton", _theme.get_stylebox(state, "Button"))
	_theme.set_stylebox("panel", "PopupMenu", panel_style())
	_theme.set_color("font_color", "PopupMenu", CREAM)
	_theme.set_color("font_color", "CheckBox", CREAM)
	_theme.set_color("font_hover_color", "CheckBox", Color.WHITE)
	_theme.set_stylebox("background", "ProgressBar", _box(Color(0.05, 0.08, 0.09, 0.85), Color(0, 0, 0, 0.6), 1))
	var grabber: StyleBoxFlat = _box(Color(JADE, 0.7), JADE, 0, 6)
	_theme.set_stylebox("grabber", "VScrollBar", grabber)
	_theme.set_stylebox("grabber_highlight", "VScrollBar", _box(JADE_LIGHT, JADE_LIGHT, 0, 6))
	_theme.set_stylebox("scroll", "VScrollBar", _box(Color(0.03, 0.06, 0.07, 0.6), Color(0, 0, 0, 0), 0, 6))
	return _theme

static func _button_styles(type: String, fill: Color, rim: Color, font: Color) -> void:
	## A block button: fill, rim and a darker lip under it; pressing sinks it onto the lip.
	var normal: StyleBoxFlat = _box(fill, rim, 2, BUTTON_RADIUS)
	_lip(normal, 4)
	var hover: StyleBoxFlat = _box(fill.lightened(0.16), rim.lightened(0.3), 2, BUTTON_RADIUS)
	_lip(hover, 4)
	var pressed: StyleBoxFlat = _box(fill.darkened(0.1), rim.lightened(0.4), 2, BUTTON_RADIUS)
	_lip(pressed, 1)
	pressed.content_margin_top += 3
	pressed.content_margin_bottom -= 3
	var disabled: StyleBoxFlat = _box(Color(0.1, 0.14, 0.15, 0.8), Color(0.25, 0.3, 0.3), 2, BUTTON_RADIUS)
	_lip(disabled, 2)
	var focus: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
	focus.border_color = GOLD if type == "Button" else Color.WHITE
	for entry: Array in [["normal", normal], ["hover", hover], ["pressed", pressed], ["focus", focus], ["disabled", disabled]]:
		_theme.set_stylebox(entry[0], type, entry[1])
	_theme.set_color("font_color", type, font)
	_theme.set_color("font_hover_color", type, Color.WHITE if type == "Button" else INK)
	_theme.set_color("font_pressed_color", type, Color.WHITE if type == "Button" else INK)
	_theme.set_color("font_focus_color", type, Color.WHITE if type == "Button" else INK)
	_theme.set_color("font_disabled_color", type, Color(0.55, 0.55, 0.5))

static func _lip(box: StyleBoxFlat, depth: int) -> void:
	box.shadow_color = LIP
	box.shadow_size = 0
	box.shadow_offset = Vector2(0, depth)

static func title_font(weight: int = 600) -> FontVariation:
	if _title == null:
		_title = FontVariation.new()
		_title.base_font = TITLE_FONT
		_title.variation_opentype = {"wght": weight}
	return _title

static func _box(color: Color, border: Color, width: int, radius: int = 8) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.corner_detail = 6
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

static func box(color: Color, border: Color = Color(0, 0, 0, 0), width: int = 0, radius: int = 12) -> StyleBoxFlat:
	## A plain rounded box for custom widgets (chips, cards, badges).
	return _box(color, border, width, radius)

static func panel_style() -> StyleBoxFlat:
	var panel: StyleBoxFlat = _box(PANEL, JADE.darkened(0.2), 3, PANEL_RADIUS)
	panel.content_margin_left = 26
	panel.content_margin_right = 26
	panel.content_margin_top = 20
	panel.content_margin_bottom = 20
	panel.shadow_color = Color(0, 0, 0, 0.4)
	panel.shadow_size = 14
	panel.shadow_offset = Vector2(0, 5)
	return panel

static func card_style(accent: Color = JADE, selected: bool = false) -> StyleBoxFlat:
	## A raised card inside a panel; the selected one glows in its accent colour.
	var card: StyleBoxFlat = _box(PANEL_LIGHT if not selected else Color(accent.darkened(0.65), 0.97), accent if selected else accent.darkened(0.45), 3 if selected else 2, 12)
	_lip(card, 3)
	card.content_margin_left = 16
	card.content_margin_right = 16
	card.content_margin_top = 12
	card.content_margin_bottom = 12
	return card

static func hud_panel(alpha: float = 0.72) -> StyleBoxFlat:
	## The translucent rounded backing of HUD blocks (tracker, prompt, toast).
	var panel: StyleBoxFlat = _box(Color(0.04, 0.09, 0.1, alpha), Color(JADE_LIGHT, 0.35), 2, 14)
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	return panel

static func label(text: String, size: int = 17, color: Color = CREAM, bold: bool = false) -> Label:
	var node: Label = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	if bold:
		node.add_theme_font_override("font", BOLD_FONT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func outlined(node: Label, width: int = 5) -> Label:
	## Ink outline for text drawn straight over the 3D view.
	node.add_theme_color_override("font_outline_color", Color(INK, 0.92))
	node.add_theme_constant_override("outline_size", width)
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	node.add_theme_constant_override("shadow_offset_y", 2)
	return node

static func hud_label(text: String, size: int = 17, color: Color = CREAM, bold: bool = true) -> Label:
	return outlined(label(text, size, color, bold), maxi(4, int(size / 4.0)))

static func title(text: String, size: int = 34, color: Color = CREAM) -> Label:
	var node: Label = label(text, size, color)
	node.add_theme_font_override("font", title_font())
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	node.add_theme_constant_override("shadow_offset_y", 2)
	return node

static func button(text: String, callback: Callable, min_width: float = 260.0, accent: bool = false) -> Button:
	var node: Button = Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(min_width, 44)
	if accent:
		node.theme_type_variation = "AccentButton"
	node.pressed.connect(callback)
	return node

static func chip(text: String, fill: Color, font_color: Color = INK, size: int = 14) -> PanelContainer:
	## A small rounded pill ("E", "Cấp 3", "Đã khóa").
	var holder: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = _box(fill, fill.lightened(0.35), 2, 8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	_lip(style, 2)
	holder.add_theme_stylebox_override("panel", style)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_label: Label = label(text, size, font_color, true)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(text_label)
	return holder

static func bar(fill: Color, size: Vector2) -> ProgressBar:
	var node: ProgressBar = ProgressBar.new()
	node.custom_minimum_size = size
	node.show_percentage = false
	var radius: int = maxi(2, int(size.y * 0.5))
	var style: StyleBoxFlat = _box(fill, fill.lightened(0.3), 0, radius)
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	node.add_theme_stylebox_override("fill", style)
	var back: StyleBoxFlat = _box(Color(0.03, 0.06, 0.07, 0.82), Color(0.0, 0.0, 0.0, 0.75), 1, radius)
	node.add_theme_stylebox_override("background", back)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
