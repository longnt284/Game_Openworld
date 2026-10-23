class_name GameHUD
extends CanvasLayer
## In-game HUD: vitals with buff/debuff icons, skills, quest tracker with world marker and the
## clock and weather beside the region name, interaction prompt, toasts/banners, boss bar with
## its poise gauge, the Tâm Nhãn veil, the lightning flash, dialogue box, memory visions, fade/death screen and the
## optional technical overlay (F3).

signal dialogue_advanced
signal choice_selected(index: int)
signal vision_closed

const FOCUS_SHADER: Shader = preload("res://shaders/focus_veil.gdshader")
## Seconds the Tâm Nhãn name stays up (it fades over the last 0.4 s).
const FOCUS_TITLE_TIME: float = 1.3
## A lightning flash on the screen fades out at this rate (alpha per second).
const FLASH_FADE: float = 3.0
const FLASH_COLOR: Color = Color(0.9, 0.94, 1.0, 0.0)

var root: Control
var status: Label
var region_label: Label
## Double hour and weather name beside the region, with a drawn icon (sun, moon, cloud, rain,
## storm, fog, wind) so no glyph depends on the font.
var clock_label: Label
var clock_icon: Control
var clock_kind: String = ""
var clock_night: bool = false
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
var quick_label: Label
var status_row: HBoxContainer
## Reused status icons, one per active status: {"root", "style", "glyph", "stacks", "time"}
var status_icons: Array[Dictionary] = []
## slot (e, q, x) -> {"panel", "key", "name", "bar", "action"}
var skill_boxes: Dictionary = {}
var boss_box: VBoxContainer
var boss_name: Label
var boss_bar: ProgressBar
## Thin poise gauge under the boss bar; pulses gold while the boss can be finished.
var boss_poise: ProgressBar
var boss_poise_fill: StyleBoxFlat
var boss_poise_back: StyleBoxFlat
var boss_finishable: bool = false
var pulse_time: float = 0.0
var prompt_tint: Color = UiTheme.CREAM
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
## Tâm Nhãn: a full-screen cool veil (its own ColorRect under every other HUD element, apart
## from `fade`) easing toward focus_active, with the name and how it was earned above the centre.
var focus_veil: ColorRect
var focus_material: ShaderMaterial
var focus_title: Label
var focus_sub: Label
var focus_active: bool = false
var focus_level: float = 0.0
var focus_title_left: float = 0.0
## Lightning: a full-screen pale flash on its own ColorRect (not `fade`), just above the Tâm
## Nhãn veil and under every other HUD element, fading out over 1 / FLASH_FADE seconds.
var flash_rect: ColorRect
var flash_level: float = 0.0
var toast_queue: Array[String] = []
## Colour of a queued toast by its text (a talisman drop shows in its rarity colour); cream otherwise.
var toast_tints: Dictionary = {}
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
	_build_focus()
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

func _build_focus() -> void:
	focus_veil = ColorRect.new()
	focus_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_material = ShaderMaterial.new()
	focus_material.shader = FOCUS_SHADER
	focus_veil.material = focus_material
	focus_veil.visible = false
	root.add_child(focus_veil)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = FLASH_COLOR
	flash_rect.visible = false
	root.add_child(flash_rect)
	focus_title = _anchored(UiTheme.title("", 34, UiTheme.CREAM), Control.PRESET_CENTER, Vector2(-300, -240), Vector2(300, -192))
	focus_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_sub = _anchored(UiTheme.label("", 16, UiTheme.CREAM, true), Control.PRESET_CENTER, Vector2(-300, -192), Vector2(300, -166))
	focus_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for label: Label in [focus_title, focus_sub]:
		# An ink outline keeps the pale name readable against the sky behind it.
		label.add_theme_color_override("font_outline_color", Color(UiTheme.INK, 0.8))
		label.add_theme_constant_override("outline_size", 6 if label == focus_title else 4)
		label.visible = false

func _build_tracker() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_anchored(box, Control.PRESET_TOP_LEFT, Vector2(28, 20), Vector2(560, 160))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heading: HBoxContainer = HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(heading)
	region_label = UiTheme.title("", 22, UiTheme.CREAM)
	heading.add_child(region_label)
	clock_icon = Control.new()
	clock_icon.custom_minimum_size = Vector2(24, 24)
	clock_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock_icon.draw.connect(_draw_clock_icon)
	heading.add_child(clock_icon)
	clock_label = UiTheme.label("", 15, UiTheme.CREAM, true)
	clock_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(clock_label)
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
	# Healing counter (R) with the quick-use slot (C) beside it.
	var items: HBoxContainer = HBoxContainer.new()
	items.add_theme_constant_override("separation", 18)
	items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(items)
	heal_label = UiTheme.label("", 14, UiTheme.MUTED)
	items.add_child(heal_label)
	quick_label = UiTheme.label("", 14, UiTheme.JADE_LIGHT)
	items.add_child(quick_label)
	# Buff and debuff icons sit on their own row above the vitals, so the bars never shift.
	status_row = HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 6)
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchored(status_row, Control.PRESET_BOTTOM_LEFT, Vector2(28, -158), Vector2(420, -110))

func _status_icon() -> Dictionary:
	## Rounded square tinted by the status, glyph in the middle, stacks as a corner badge and
	## the seconds left underneath. Buffs get a jade border, debuffs a vermilion one.
	var icon: Control = Control.new()
	icon.custom_minimum_size = Vector2(36, 48)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel: Panel = Panel.new()
	panel.position = Vector2.ZERO
	panel.size = Vector2(36, 36)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	icon.add_child(panel)
	var glyph: Label = UiTheme.label("", 15, UiTheme.CREAM, true)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.position = Vector2.ZERO
	glyph.size = Vector2(36, 36)
	icon.add_child(glyph)
	var stacks: Label = UiTheme.label("", 11, UiTheme.CREAM, true)
	stacks.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stacks.position = Vector2(14, -6)
	stacks.size = Vector2(26, 14)
	icon.add_child(stacks)
	var time: Label = UiTheme.label("", 11, UiTheme.MUTED)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time.position = Vector2(-4, 35)
	time.size = Vector2(44, 14)
	icon.add_child(time)
	status_row.add_child(icon)
	return {"root": icon, "style": style, "glyph": glyph, "stacks": stacks, "time": time}

func _build_skills() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	_anchored(row, Control.PRESET_BOTTOM_RIGHT, Vector2(-330, -112), Vector2(-28, -24))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.offset_left = -560
	for slot: String in StyleBook.SLOTS:
		var panel: PanelContainer = PanelContainer.new()
		panel.custom_minimum_size = Vector2(140, 80)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var inner: VBoxContainer = VBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(inner)
		var key: Label = UiTheme.label("", 22, UiTheme.GOLD, true)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(key)
		var name_label: Label = UiTheme.label("", 13, UiTheme.CREAM)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(name_label)
		var cooldown: ProgressBar = UiTheme.bar(UiTheme.GOLD if slot == "x" else UiTheme.JADE_LIGHT, Vector2(108, 5))
		cooldown.max_value = 1.0
		inner.add_child(cooldown)
		row.add_child(panel)
		skill_boxes[slot] = {"panel": panel, "key": key, "name": name_label, "bar": cooldown, "action": StyleBook.SLOT_ACTIONS[slot]}

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
	boss_poise = UiTheme.bar(UiTheme.CREAM, Vector2(600, 5))
	boss_poise.max_value = 1.0
	boss_poise.step = 0.0
	boss_poise.value = 1.0
	boss_poise_fill = boss_poise.get_theme_stylebox("fill") as StyleBoxFlat
	boss_poise_back = boss_poise.get_theme_stylebox("background") as StyleBoxFlat
	# Thin: the shared bar background pads to label height, which the gauge does not need.
	boss_poise_back.content_margin_top = 0
	boss_poise_back.content_margin_bottom = 0
	boss_box.add_child(boss_poise)
	boss_box.visible = false

func _build_dialogue() -> void:
	dialogue_panel = PanelContainer.new()
	_anchored(dialogue_panel, Control.PRESET_CENTER_BOTTOM, Vector2(-470, -230), Vector2(470, -32))
	# Extra choices push the box up from its bottom edge instead of off the screen.
	dialogue_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
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

func set_quick_item(text: String, stocked: bool) -> void:
	## The quick slot dims while it is empty or its stack has run out.
	quick_label.text = text
	quick_label.modulate.a = 1.0 if stocked else 0.5

func set_statuses(list: Array) -> void:
	## list: StatusEffects.list_for_hud() of the player. Icons are pooled and only re-tinted.
	while status_icons.size() < list.size():
		status_icons.append(_status_icon())
	for index: int in range(status_icons.size()):
		var icon: Dictionary = status_icons[index]
		var root_control: Control = icon["root"]
		root_control.visible = index < list.size()
		if not root_control.visible:
			continue
		var entry: Dictionary = list[index]
		var color: Color = entry["color"]
		var style: StyleBoxFlat = icon["style"]
		style.bg_color = Color(color.darkened(0.6), 0.92)
		style.border_color = UiTheme.JADE_LIGHT if String(entry["kind"]) == "buff" else UiTheme.VERMILION
		var glyph: Label = icon["glyph"]
		glyph.text = String(entry["glyph"])
		glyph.add_theme_color_override("font_color", color.lightened(0.35))
		(icon["stacks"] as Label).text = "×%d" % int(entry["stacks"]) if int(entry["stacks"]) > 1 else ""
		(icon["time"] as Label).text = "%ds" % ceili(float(entry["time"]))
		# The last seconds fade the icon, so an expiring buff is noticed before it is gone.
		root_control.modulate.a = 0.55 if float(entry["time"]) < 3.0 else 1.0

func status_icon_count() -> int:
	var count: int = 0
	for icon: Dictionary in status_icons:
		if (icon["root"] as Control).visible:
			count += 1
	return count

func set_skill(slot: String, title: String, unlocked: bool, fill: float, level: int, tint: Color) -> void:
	## fill: 1 when ready (cooldown done, or a full charge meter on the ultimate slot).
	var box: Dictionary = skill_boxes[slot]
	var ready: bool = unlocked and fill >= 0.999
	(box["panel"] as Control).modulate = Color(1, 1, 1, 1.0 if unlocked else 0.35)
	(box["bar"] as ProgressBar).value = fill
	(box["key"] as Label).text = UserSettings.event_label(box["action"]) if unlocked else "—"
	(box["key"] as Label).modulate = tint.lightened(0.25) if ready else Color(1, 1, 1)
	(box["name"] as Label).text = title + ((" %s" % ["I", "II", "III"][clampi(level - 1, 0, 2)]) if unlocked and slot != "x" else "")

func set_tracker(region: String, title: String, text: String) -> void:
	region_label.text = region
	quest_title.text = title
	objective.text = text

func set_clock(hour: String, weather: String, icon: String, night: bool) -> void:
	## From main's 10 Hz refresh: "Giờ Thìn  •  Mưa" and its icon, redrawn only when they change.
	var text: String = "%s  •  %s" % [hour, weather]
	if clock_label.text != text:
		clock_label.text = text
	if icon != clock_kind or night != clock_night:
		clock_kind = icon
		clock_night = night
		clock_icon.queue_redraw()

func _draw_clock_icon() -> void:
	## 24 × 24 px: a sun or moon for a clear sky, a cloud (with the sun or moon behind it), rain
	## streaks, a storm bolt, fog bands or wind gusts. An ink rim keeps it readable on a bright sky.
	var ink: Color = Color(UiTheme.INK, 0.55)
	var orb: Color = Color("f7e3a1") if clock_night else UiTheme.GOLD
	var cloud: Color = Color("c9d3d8") if clock_kind != "storm" else Color("8a96a3")
	match clock_kind:
		"sun", "cloud":
			var center: Vector2 = Vector2(12, 12) if clock_kind == "sun" else Vector2(16, 8)
			var radius: float = 5.5 if clock_kind == "sun" else 4.5
			if clock_night:
				_draw_moon(center, radius + 1.0, orb, ink)
			else:
				for ray: int in range(8):
					var direction: Vector2 = Vector2.RIGHT.rotated(TAU * ray / 8.0)
					clock_icon.draw_line(center + direction * (radius + 2.0), center + direction * (radius + 4.5), orb, 2.0, true)
				clock_icon.draw_circle(center, radius + 1.2, ink)
				clock_icon.draw_circle(center, radius, orb)
			if clock_kind == "cloud":
				_draw_cloud(Vector2(11, 15), cloud, ink)
		"rain":
			_draw_cloud(Vector2(12, 10), cloud, ink)
			for x: float in [7.0, 12.0, 17.0]:
				clock_icon.draw_line(Vector2(x, 17), Vector2(x - 2.0, 22), Color("7ec8f2"), 2.0, true)
		"storm":
			_draw_cloud(Vector2(12, 9), cloud, ink)
			var bolt: PackedVector2Array = PackedVector2Array([Vector2(13, 13), Vector2(9, 18.5), Vector2(12.5, 18.5), Vector2(10, 23.5)])
			clock_icon.draw_polyline(bolt, ink, 4.0, true)
			clock_icon.draw_polyline(bolt, UiTheme.GOLD, 2.0, true)
		"fog":
			for row: int in range(4):
				var y: float = 6.0 + row * 4.5
				var inset: float = 3.0 if row % 2 == 0 else 6.0
				clock_icon.draw_line(Vector2(inset, y), Vector2(24.0 - inset * 0.6, y), ink, 4.0, true)
				clock_icon.draw_line(Vector2(inset, y), Vector2(24.0 - inset * 0.6, y), cloud, 2.2, true)
		"wind":
			for row: int in range(3):
				var y: float = 6.0 + row * 6.0
				var length: float = [16.0, 20.0, 12.0][row]
				clock_icon.draw_line(Vector2(2, y), Vector2(2.0 + length, y), ink, 3.6, true)
				clock_icon.draw_line(Vector2(2, y), Vector2(2.0 + length, y), UiTheme.JADE_LIGHT, 2.0, true)
				clock_icon.draw_arc(Vector2(2.0 + length, y - 2.0), 2.0, -PI * 0.5, PI * 0.5, 6, UiTheme.JADE_LIGHT, 2.0, true)

func _draw_moon(center: Vector2, radius: float, color: Color, ink: Color) -> void:
	## A crescent: the disc minus a smaller disc offset toward the upper right.
	var points: PackedVector2Array = PackedVector2Array()
	for step: int in range(13):
		points.append(center + Vector2.from_angle(PI * 0.35 + PI * 1.3 * step / 12.0) * radius)
	var cut: Vector2 = center + Vector2(radius * 0.55, -radius * 0.35)
	for step: int in range(13):
		var point: Vector2 = center + Vector2.from_angle(PI * 1.65 - PI * 1.3 * step / 12.0) * radius
		points.append(cut + (point - cut) * 0.62)
	clock_icon.draw_polyline(points + PackedVector2Array([points[0]]), ink, 2.4, true)
	clock_icon.draw_colored_polygon(points, color)

func _draw_cloud(center: Vector2, color: Color, ink: Color) -> void:
	for part: Array in [[Vector2(-5, 2), 4.0], [Vector2(0, -1.5), 5.5], [Vector2(5, 2), 4.0]]:
		clock_icon.draw_circle(center + part[0], part[1] + 1.2, ink)
	clock_icon.draw_rect(Rect2(center + Vector2(-9.5, 1.5), Vector2(19, 5.2)), ink)
	for part: Array in [[Vector2(-5, 2), 4.0], [Vector2(0, -1.5), 5.5], [Vector2(5, 2), 4.0]]:
		clock_icon.draw_circle(center + part[0], part[1], color)
	clock_icon.draw_rect(Rect2(center + Vector2(-8.5, 2.0), Vector2(17, 4.0)), color)

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

func show_prompt(text: String, tint: Color = UiTheme.CREAM) -> void:
	## Called every frame by main._update_focus; gold marks a finisher.
	prompt.text = text
	if tint != prompt_tint:
		prompt_tint = tint
		prompt.add_theme_color_override("font_color", tint)

func show_message(message: String, duration: float = 3.5, tint: Color = UiTheme.CREAM) -> void:
	toast_tints[message] = tint
	if toast_remaining > 0.0 and toast.text != message:
		if not toast_queue.has(message):
			toast_queue.append(message)
		return
	_show_toast(message, duration)

func _show_toast(message: String, duration: float) -> void:
	toast.text = message
	toast.add_theme_color_override("font_color", toast_tints.get(message, UiTheme.CREAM))
	toast_tints.erase(message)
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

func set_boss_poise(ratio: float, broken: bool, finishable: bool) -> void:
	## ratio: Enemy.poise_ratio() (empty while broken). While a finisher can still land the
	## gauge fills gold and pulses; for the rest of the break it stays empty with a gold rim.
	boss_poise.value = 1.0 if finishable else ratio
	boss_poise_fill.bg_color = UiTheme.GOLD if broken else UiTheme.CREAM
	boss_poise_back.border_color = UiTheme.GOLD if broken else Color(0.0, 0.0, 0.0, 0.7)
	boss_finishable = finishable
	if not finishable:
		boss_poise.modulate.a = 1.0

func set_focus(active: bool, title: String = "", subtitle: String = "", tint: Color = UiTheme.JADE_LIGHT) -> void:
	## Tâm Nhãn on, with its name and how it was earned in its colour, or off. The veil eases in
	## quickly and lifts slowly (_process), so a pause holds it where it is.
	focus_active = active
	if not active:
		return
	focus_material.set_shader_parameter("tint", tint)
	focus_title.text = title
	focus_title.add_theme_color_override("font_color", tint)
	focus_sub.text = subtitle
	focus_title_left = FOCUS_TITLE_TIME

func flash(strength: float) -> void:
	## A lightning flash over the whole screen (StormDirector), from this frame on.
	flash_level = maxf(flash_level, clampf(strength, 0.0, 1.0))
	flash_rect.color.a = flash_level
	flash_rect.visible = flash_level > 0.0

func hide_boss() -> void:
	boss_box.visible = false
	boss_finishable = false

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
	for node: Control in [region_label, clock_icon, clock_label, quest_title, objective, health_bar, stamina_bar, level_label, heal_label, quick_label, prompt, status_row]:
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

func _fade_focus(delta: float) -> void:
	## Writes the veil's strength only while it changes; the name fades on its own timer.
	var goal: float = 1.0 if focus_active else 0.0
	if focus_level != goal:
		focus_level = move_toward(focus_level, goal, delta * (8.0 if focus_active else 2.5))
		focus_material.set_shader_parameter("strength", focus_level)
		focus_veil.visible = focus_level > 0.0
	if focus_title_left > 0.0 or focus_title.visible:
		focus_title_left = maxf(0.0, focus_title_left - delta)
		var alpha: float = clampf(focus_title_left * 2.5, 0.0, 1.0)
		focus_title.modulate.a = alpha
		focus_sub.modulate.a = alpha
		focus_title.visible = alpha > 0.0
		focus_sub.visible = alpha > 0.0

func _process(delta: float) -> void:
	if dialogue_panel.visible and dialogue_text.visible_ratio < 1.0:
		typing += delta
		dialogue_text.visible_ratio = clampf(typing * 55.0 / maxf(1.0, float(dialogue_text.get_total_character_count())), 0.0, 1.0)
	if boss_finishable and boss_box.visible:
		pulse_time += delta
		boss_poise.modulate.a = 0.55 + 0.45 * sin(pulse_time * 11.0)
	_fade_focus(delta)
	if flash_level > 0.0:
		flash_level = maxf(0.0, flash_level - delta * FLASH_FADE)
		flash_rect.color.a = flash_level
		flash_rect.visible = flash_level > 0.0
	# A message raised behind the dialogue box (a shrine's prompt) waits until it closes.
	if not dialogue_panel.visible:
		toast_remaining = maxf(0.0, toast_remaining - delta)
		if toast_remaining <= 0.0 and not toast_queue.is_empty():
			_show_toast(toast_queue.pop_front(), 3.0)
	toast.visible = toast_remaining > 0.0 and not dialogue_panel.visible
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
