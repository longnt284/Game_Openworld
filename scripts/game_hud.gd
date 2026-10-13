class_name GameHUD
extends CanvasLayer

signal resume_requested
signal save_requested
signal load_requested
var status: Label
var objective: Label
var prompt: Label
var toast: Label
var pause_panel: PanelContainer
var toast_remaining: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var title: Label = _label("LONG / OPENWORLD", 26, Vector2(32, 24), root)
	title.add_theme_color_override("font_color", Color("f8ebca"))
	_label("BẢN NỀN KHÁM PHÁ  •  01", 13, Vector2(34, 60), root)
	objective = _label("Tìm trạm ánh sáng trong thung lũng", 17, Vector2(34, 99), root)
	status = _label("Đang tải thế giới…", 14, Vector2(-375, 30), root)
	status.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	status.offset_left = -375
	status.offset_top = 30
	status.offset_right = -32
	status.offset_bottom = 80
	prompt = _label("", 20, Vector2(-260, -120), root)
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -260
	prompt.offset_top = -120
	prompt.offset_right = 260
	prompt.offset_bottom = -90
	prompt.custom_minimum_size.x = 520
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast = _label("", 17, Vector2(-270, -160), root)
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.offset_left = -270
	toast.offset_top = -160
	toast.offset_right = 270
	toast.offset_bottom = -125
	toast.custom_minimum_size.x = 540
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var controls: Label = _label("WASD  Di chuyển     SHIFT  Chạy     SPACE  Nhảy     E  Tương tác\nCHUỘT  Nhìn     F5  Lưu     F9  Tải     R  Về trạm     ESC  Tạm dừng", 14, Vector2(34, -67), root)
	controls.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	controls.offset_left = 34
	controls.offset_top = -67
	controls.offset_bottom = -10
	controls.add_theme_constant_override("line_spacing", 7)
	pause_panel = PanelContainer.new()
	root.add_child(pause_panel)
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -180
	pause_panel.offset_top = -160
	pause_panel.offset_right = 180
	pause_panel.offset_bottom = 160
	pause_panel.custom_minimum_size = Vector2(360, 280)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.16, 0.14, 0.97)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	pause_panel.add_theme_stylebox_override("panel", style)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	pause_panel.add_child(box)
	var heading: Label = Label.new()
	heading.text = "TẠM DỪNG"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	box.add_child(heading)
	_button("Tiếp tục", box, func() -> void: resume_requested.emit())
	_button("Lưu hành trình", box, func() -> void: save_requested.emit())
	_button("Tải lần lưu gần nhất", box, func() -> void: load_requested.emit())
	_button("Thoát game", box, func() -> void: get_tree().quit())
	pause_panel.hide()

func _label(text_value: String, font_size: int, offset: Vector2, parent: Control) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.position = offset
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f0f0dd"))
	label.add_theme_color_override("font_shadow_color", Color(0.05, 0.1, 0.08, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label

func _button(text_value: String, parent: Control, callback: Callable) -> void:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 34
	parent.add_child(button)
	button.pressed.connect(callback)

func show_message(message: String) -> void:
	toast.text = message
	toast_remaining = 4.0

func set_paused(value: bool) -> void:
	pause_panel.visible = value
	if value:
		(pause_panel.get_child(0).get_child(1) as Button).grab_focus()

func _process(delta: float) -> void:
	toast_remaining = maxf(0, toast_remaining - delta)
	toast.visible = toast_remaining > 0
