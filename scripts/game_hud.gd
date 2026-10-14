class_name GameHUD
extends CanvasLayer
## In-game HUD: vitals, skills, quest tracker with world marker, interaction prompt,
## toasts/banners, boss bar, dialogue box, memory visions, fade/death screen and
## the optional technical overlay (F3).

signal dialogue_advanced
signal choice_selected(index: int)
signal vision_closed

var root: Control
var status: Label
var region_label: Label
var quest_title: Label
var objective: Label
var prompt: Label
var toast: Label
var banner: Label
var banner_sub: Label
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var level_label: Label
var heal_label: Label
var skill_boxes: Dictionary = {}
var boss_box: VBoxContainer
var boss_name: Label
var boss_bar: ProgressBar
var marker: Label
var reticle: Label
var dialogue_panel: PanelContainer
var dialogue_name: Label
var dialogue_text: RichTextLabel
var dialogue_hint: Label
var choice_box: VBoxContainer
var vision: Control
var vision_title: Label
var vision_text: Label
var fade: ColorRect
var fade_text: Label
var fade_sub: Label
var hint_panel: PanelContainer
var hint_label: Label
var toast_queue: Array[String] = []
var toast_remaining: float = 0.0
var banner_remaining: float = 0.0
var typing: float = 0.0
var hint_remaining: float = 0.0
var debug_enabled: bool = false

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = UiTheme.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_tracker()
	_build_vitals()
	_build_skills()
	_build_center()
	_build_boss()
	_build_dialogue()
	_build_vision()
	_build_fade()
	status = _anchored(UiTheme.label("", 14, UiTheme.CREAM), Control.PRESET_TOP_RIGHT, Vector2(-380, 16), Vector2(-16, 140))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.visible = false

func _anchored(control: Control, preset: int, top_left: Vector2, bottom_right: Vector2) -> Control:
	root.add_child(control)
	control.set_anchors_preset(preset)
	control.offset_left = top_left.x
	control.offset_top = top_left.y
	control.offset_right = bottom_right.x
	control.offset_bottom = bottom_right.y
	return control

func _build_tracker() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_anchored(box, Control.PRESET_TOP_LEFT, Vector2(28, 20), Vector2(560, 160))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	region_label = UiTheme.title("", 22, UiTheme.CREAM)
	box.add_child(region_label)
	quest_title = UiTheme.label("", 15, UiTheme.GOLD, true)
	box.add_child(quest_title)
	objective = UiTheme.label("", 16, UiTheme.CREAM)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.custom_minimum_size.x = 470
	box.add_child(objective)
	marker = UiTheme.label("◆", 18, UiTheme.GOLD, true)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.size = Vector2(120, 44)
	root.add_child(marker)
	marker.visible = false
	reticle = UiTheme.label("◇", 30, Color(1.0, 0.85, 0.6), true)
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.size = Vector2(40, 40)
	root.add_child(reticle)
	reticle.visible = false

func _build_vitals() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_anchored(box, Control.PRESET_BOTTOM_LEFT, Vector2(28, -104), Vector2(400, -20))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label = UiTheme.label("Lâm An  •  Cấp 1", 15, UiTheme.CREAM, true)
	box.add_child(level_label)
	health_bar = UiTheme.bar(UiTheme.VERMILION, Vector2(320, 14))
	health_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(health_bar)
	stamina_bar = UiTheme.bar(Color("4fbfa8"), Vector2(250, 8))
	stamina_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(stamina_bar)
	heal_label = UiTheme.label("", 14, UiTheme.MUTED)
	box.add_child(heal_label)

func _build_skills() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	_anchored(row, Control.PRESET_BOTTOM_RIGHT, Vector2(-330, -112), Vector2(-28, -24))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for skill: Array in [["gust", "Phong Trảm", "skill_1"], ["cyclone", "Toàn Phong", "skill_2"]]:
		var panel: PanelContainer = PanelContainer.new()
		panel.custom_minimum_size = Vector2(132, 80)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var inner: VBoxContainer = VBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(inner)
		var key: Label = UiTheme.label(skill[2], 22, UiTheme.GOLD, true)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(key)
		var name_label: Label = UiTheme.label(skill[1], 13, UiTheme.CREAM)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(name_label)
		var cooldown: ProgressBar = UiTheme.bar(UiTheme.JADE_LIGHT, Vector2(100, 5))
		cooldown.max_value = 1.0
		inner.add_child(cooldown)
		row.add_child(panel)
		skill_boxes[skill[0]] = {"panel": panel, "key": key, "name": name_label, "bar": cooldown, "action": skill[2]}

func _build_center() -> void:
	prompt = _anchored(UiTheme.label("", 20, UiTheme.CREAM, true), Control.PRESET_CENTER_BOTTOM, Vector2(-320, -170), Vector2(320, -136))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast = _anchored(UiTheme.label("", 17, UiTheme.CREAM), Control.PRESET_CENTER_BOTTOM, Vector2(-360, -214), Vector2(360, -178))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner = _anchored(UiTheme.title("", 40, UiTheme.CREAM), Control.PRESET_CENTER_TOP, Vector2(-420, 112), Vector2(420, 168))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub = _anchored(UiTheme.label("", 17, UiTheme.GOLD, true), Control.PRESET_CENTER_TOP, Vector2(-420, 168), Vector2(420, 196))
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_panel = PanelContainer.new()
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchored(hint_panel, Control.PRESET_CENTER_LEFT, Vector2(28, -70), Vector2(360, 70))
	hint_label = UiTheme.label("", 15, UiTheme.CREAM)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_panel.add_child(hint_label)
	hint_panel.visible = false

func _build_boss() -> void:
	boss_box = VBoxContainer.new()
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchored(boss_box, Control.PRESET_CENTER_TOP, Vector2(-300, 24), Vector2(300, 80))
	boss_name = UiTheme.title("", 22, UiTheme.CREAM)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)
	boss_bar = UiTheme.bar(Color("c8402e"), Vector2(600, 12))
	boss_box.add_child(boss_bar)
	boss_box.visible = false

func _build_dialogue() -> void:
	dialogue_panel = PanelContainer.new()
	_anchored(dialogue_panel, Control.PRESET_CENTER_BOTTOM, Vector2(-470, -230), Vector2(470, -32))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	dialogue_panel.add_child(box)
	dialogue_name = UiTheme.title("", 22, UiTheme.GOLD)
	box.add_child(dialogue_name)
	dialogue_text = RichTextLabel.new()
	dialogue_text.fit_content = true
	dialogue_text.scroll_active = false
	dialogue_text.custom_minimum_size = Vector2(880, 60)
	dialogue_text.add_theme_font_size_override("normal_font_size", 19)
	dialogue_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(dialogue_text)
	choice_box = VBoxContainer.new()
	box.add_child(choice_box)
	dialogue_hint = UiTheme.label("F / Space / Chuột trái — tiếp tục", 13, UiTheme.MUTED)
	dialogue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(dialogue_hint)
	dialogue_panel.visible = false

func _build_vision() -> void:
	vision = Control.new()
	vision.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(vision)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.03, 0.08, 0.09, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vision.add_child(dim)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -420
	box.offset_right = 420
	box.offset_top = -170
	box.offset_bottom = 170
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	vision.add_child(box)
	vision_title = UiTheme.title("", 30, UiTheme.JADE_LIGHT)
	vision_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(vision_title)
	vision_text = UiTheme.label("", 21, UiTheme.CREAM)
	vision_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vision_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vision_text.custom_minimum_size.x = 820
	box.add_child(vision_text)
	var hint: Label = UiTheme.label("F / Space / Chuột trái — tiếp tục", 13, UiTheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	vision.visible = false

func _build_fade() -> void:
	fade = ColorRect.new()
	fade.color = Color(0.02, 0.03, 0.04, 0.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	fade_text = _anchored(UiTheme.title("", 46, UiTheme.CREAM), Control.PRESET_CENTER, Vector2(-400, -60), Vector2(400, 0))
	fade_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade_sub = _anchored(UiTheme.label("", 18, UiTheme.MUTED), Control.PRESET_CENTER, Vector2(-420, 6), Vector2(420, 70))
	fade_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# ------------------------------------------------------------------ updates

func set_vitals(health: float, max_health: float, stamina: float, max_stamina: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = health
	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina
	stamina_bar.modulate = Color(1, 1, 1, 1.0 if stamina < max_stamina - 0.5 else 0.55)

func set_level(level: int, xp: int, next_xp: int, skill_points: int) -> void:
	level_label.text = "Lâm An  •  Cấp %d  •  %d/%d KN%s" % [level, xp, next_xp, ("  •  +%d điểm tu luyện" % skill_points) if skill_points > 0 else ""]

func set_heal_count(text: String) -> void:
	heal_label.text = text

func set_skill(skill: String, unlocked: bool, ratio: float, level: int) -> void:
	var box: Dictionary = skill_boxes[skill]
	(box["panel"] as Control).modulate = Color(1, 1, 1, 1.0 if unlocked else 0.35)
	(box["bar"] as ProgressBar).value = 1.0 - ratio
	(box["key"] as Label).text = UserSettings.event_label(box["action"]) if unlocked else "—"
	(box["name"] as Label).text = String({"gust": "Phong Trảm", "cyclone": "Toàn Phong"}[skill]) + ((" %s" % ["I", "II", "III"][clampi(level - 1, 0, 2)]) if unlocked else "")

func set_tracker(region: String, title: String, text: String) -> void:
	region_label.text = region
	quest_title.text = title
	objective.text = text

func update_marker(camera: Camera3D, point: Variant, origin: Vector3) -> void:
	if point == null or camera == null:
		marker.visible = false
		return
	var world_point: Vector3 = point
	var view: Vector2 = root.size
	var distance: float = Vector2(origin.x, origin.z).distance_to(Vector2(world_point.x, world_point.z))
	if distance < 4.0:
		marker.visible = false
		return
	var screen: Vector2 = camera.unproject_position(world_point)
	var inside: Rect2 = Rect2(Vector2(70, 60), view - Vector2(140, 250))
	if camera.is_position_behind(world_point) or not inside.has_point(screen):
		## Off-screen: pin the marker to an ellipse around the screen centre in the target's direction.
		var local: Vector3 = camera.global_transform.affine_inverse() * world_point
		var direction: Vector2 = Vector2(local.x, -local.y)
		if local.z > 0.0:
			direction.y = absf(direction.y) * 0.3 + 1.0
		direction = direction.normalized()
		var center: Vector2 = inside.get_center()
		screen = center + Vector2(direction.x * inside.size.x * 0.5, direction.y * inside.size.y * 0.5)
	marker.position = screen - marker.size * 0.5
	marker.text = "◆\n%d m" % roundi(distance)
	marker.visible = true

func update_reticle(camera: Camera3D, target: Node3D) -> void:
	if target == null or camera == null or camera.is_position_behind(target.global_position):
		reticle.visible = false
		return
	var height: float = 1.2
	if target is Enemy:
		height = float((target as Enemy).data.get("height", 1.8)) * 0.65
	var screen: Vector2 = camera.unproject_position(target.global_position + Vector3.UP * height)
	reticle.position = screen - reticle.size * 0.5
	reticle.visible = true

func show_prompt(text: String) -> void:
	prompt.text = text

func show_message(message: String, duration: float = 3.5) -> void:
	if toast_remaining > 0.0 and toast.text != message:
		if not toast_queue.has(message):
			toast_queue.append(message)
		return
	toast.text = message
	toast_remaining = duration

func show_banner(title: String, subtitle: String = "", duration: float = 3.5) -> void:
	banner.text = title
	banner_sub.text = subtitle
	banner_remaining = duration

func show_hint(text: String, duration: float = 9.0) -> void:
	hint_label.text = text
	hint_panel.visible = true
	hint_remaining = duration

func show_boss(name: String, title: String, ratio: float) -> void:
	boss_box.visible = true
	boss_name.text = "%s — %s" % [name, title] if title != "" else name
	boss_bar.max_value = 1.0
	boss_bar.value = ratio

func hide_boss() -> void:
	boss_box.visible = false

func open_dialogue(speaker: String, text: String, choices: Array = []) -> void:
	dialogue_panel.visible = true
	dialogue_name.text = speaker
	dialogue_text.text = text
	dialogue_text.visible_ratio = 0.0
	typing = 0.0
	for child: Node in choice_box.get_children():
		child.queue_free()
	for index: int in range(choices.size()):
		var button: Button = UiTheme.button("%d. %s" % [index + 1, choices[index]], func() -> void: emit_signal("choice_selected", index), 600)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choice_box.add_child(button)
	dialogue_hint.visible = choices.is_empty()
	if not choices.is_empty():
		dialogue_text.visible_ratio = 1.0
		(choice_box.get_child(0) as Button).call_deferred("grab_focus")

func close_dialogue() -> void:
	dialogue_panel.visible = false

func dialogue_open() -> bool:
	return dialogue_panel.visible

func open_vision(title: String, text: String) -> void:
	vision_title.text = title
	vision_text.text = text
	vision.visible = true
	vision.modulate.a = 0.0
	create_tween().tween_property(vision, "modulate:a", 1.0, 0.35)

func close_vision() -> void:
	vision.visible = false

func vision_open() -> bool:
	return vision.visible

func fade_to(alpha: float, duration: float, title: String = "", subtitle: String = "") -> Tween:
	fade_text.text = title
	fade_sub.text = subtitle
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(fade, "color:a", alpha, duration)
	tween.tween_property(fade_text, "modulate:a", 1.0 if alpha > 0.5 else 0.0, duration)
	tween.tween_property(fade_sub, "modulate:a", 1.0 if alpha > 0.5 else 0.0, duration)
	return tween

func set_debug(enabled: bool) -> void:
	debug_enabled = enabled
	status.visible = enabled

func set_gameplay_visible(value: bool) -> void:
	for node: Control in [region_label, quest_title, objective, health_bar, stamina_bar, level_label, heal_label, prompt]:
		node.visible = value
	for skill: String in skill_boxes:
		(skill_boxes[skill]["panel"] as Control).visible = value
	if not value:
		marker.visible = false
		reticle.visible = false

func _unhandled_input(event: InputEvent) -> void:
	var advance: bool = event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("attack") or (event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ENTER)
	if vision.visible and advance:
		get_viewport().set_input_as_handled()
		close_vision()
		emit_signal("vision_closed")
	elif dialogue_panel.visible and choice_box.get_child_count() == 0 and advance:
		get_viewport().set_input_as_handled()
		if dialogue_text.visible_ratio < 1.0:
			dialogue_text.visible_ratio = 1.0
		else:
			emit_signal("dialogue_advanced")

func _process(delta: float) -> void:
	if dialogue_panel.visible and dialogue_text.visible_ratio < 1.0:
		typing += delta
		dialogue_text.visible_ratio = clampf(typing * 55.0 / maxf(1.0, float(dialogue_text.get_total_character_count())), 0.0, 1.0)
	toast_remaining = maxf(0.0, toast_remaining - delta)
	if toast_remaining <= 0.0 and not toast_queue.is_empty():
		toast.text = toast_queue.pop_front()
		toast_remaining = 3.0
	toast.visible = toast_remaining > 0.0
	toast.modulate.a = clampf(toast_remaining * 3.0, 0.0, 1.0)
	banner_remaining = maxf(0.0, banner_remaining - delta)
	var banner_alpha: float = clampf(banner_remaining * 1.5, 0.0, 1.0)
	banner.modulate.a = banner_alpha
	banner_sub.modulate.a = banner_alpha
	if hint_remaining > 0.0:
		hint_remaining -= delta
		hint_panel.modulate.a = clampf(hint_remaining, 0.0, 1.0)
		if hint_remaining <= 0.0:
			hint_panel.visible = false
