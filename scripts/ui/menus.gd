class_name Menus
extends CanvasLayer
## Title screen, pause menu and the full-screen panels (map, journal, inventory,
## settings, shop). Panels read live game state from `main` and never own game logic.

signal new_game_requested
signal continue_requested
signal resume_requested
signal save_requested
signal load_requested
signal checkpoint_requested
signal title_requested
signal settings_changed
signal quit_requested

var main: Node
var root: Control
var title_screen: Control
var continue_button: Button
var new_game_button: Button
var pause_panel: PanelContainer
var panel_host: PanelContainer
var panel_title: Label
var panel_body: Control
var current_panel: String = ""
var rebinding: String = ""
var rebind_buttons: Dictionary = {}
var close_button: Button
var resume_button: Button
var leave_trial_button: Button
## Retention panel state: Trial blessing offer, last Kỳ Ngộ results and an inline notice.
var trial_choices: Array = []
var last_pull: Array = []
var reveal: bool = false
var panel_note: String = ""
## The inline notice reports a success (jade) rather than a refusal (vermilion).
var panel_note_ok: bool = false
## Inventory row kept selected across refreshes; the shop the counter panel shows.
var selected_item: String = ""
## Inventory right-hand tab (0 Võ học, 1 Nhân vật), kept across refreshes.
var inventory_tab: int = 0
## Armory tab (0 Kiếm & trang phục, 1 Ngọc bội), kept across refreshes.
var armory_tab: int = 0
var shop_id: String = ""
## Panels opened from the world (a shop counter) close straight back into play, not to the pause menu.
var resume_on_close: bool = false

func setup(owner_main: Node) -> void:
	main = owner_main
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = UiTheme.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_title()
	_build_pause()
	_build_panel_host()

# ------------------------------------------------------------------ title

func _build_title() -> void:
	title_screen = Control.new()
	title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(title_screen)
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.07, 0.08, 0.25)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_screen.add_child(shade)
	# Darker band behind the title column so text stays readable over the bright valley.
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.03, 0.07, 0.08, 0.82))
	gradient.set_color(1, Color(0.03, 0.07, 0.08, 0.0))
	gradient.add_point(0.55, Color(0.03, 0.07, 0.08, 0.6))
	var band_texture: GradientTexture2D = GradientTexture2D.new()
	band_texture.gradient = gradient
	band_texture.width = 256
	band_texture.height = 4
	var band: TextureRect = TextureRect.new()
	band.texture = band_texture
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	band.offset_right = 860
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_screen.add_child(band)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	box.offset_left = 90
	box.offset_right = 620
	box.offset_top = -330
	box.offset_bottom = 360
	title_screen.add_child(box)
	box.add_child(UiTheme.title("Vân Khê", 74, UiTheme.CREAM))
	box.add_child(UiTheme.title("Dư Âm Gió", 34, UiTheme.JADE_LIGHT))
	var tagline: Label = UiTheme.label("Một lữ khách, một thanh kiếm cũ và những ký ức còn vương trong gió.", 17, UiTheme.MUTED)
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.custom_minimum_size.x = 480
	box.add_child(tagline)
	if OS.has_feature("web") and not OS.is_userfs_persistent():
		var storage: Label = UiTheme.label("Trình duyệt đang chặn lưu trữ (chế độ ẩn danh?): hành trình sẽ mất khi đóng thẻ.", 15, UiTheme.VERMILION)
		storage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		storage.custom_minimum_size.x = 480
		box.add_child(storage)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 26
	box.add_child(spacer)
	continue_button = UiTheme.button("Tiếp tục hành trình", func() -> void: emit_signal("continue_requested"), 300)
	box.add_child(continue_button)
	new_game_button = UiTheme.button("Hành trình mới", func() -> void: emit_signal("new_game_requested"), 300)
	box.add_child(new_game_button)
	box.add_child(UiTheme.button("Kỳ Ngộ", func() -> void: open_panel("gacha"), 300))
	box.add_child(UiTheme.button("Nhiệm vụ ngày", func() -> void: open_panel("daily"), 300))
	box.add_child(UiTheme.button("Kiếm, Ngọc bội & trang phục", func() -> void: open_panel("armory"), 300))
	box.add_child(UiTheme.button("Thiết lập", func() -> void: open_panel("settings"), 300))
	box.add_child(UiTheme.button("Ghi công", func() -> void: open_panel("credits"), 300))
	if not OS.has_feature("web"):
		box.add_child(UiTheme.button("Thoát game", func() -> void: emit_signal("quit_requested"), 300))
	var credit: Label = UiTheme.label("Chương I — đoạn chơi mẫu  •  Game của Nguyễn Thành Long", 13, UiTheme.MUTED)
	credit.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	credit.offset_left = 90
	credit.offset_top = -44
	credit.offset_right = 700
	credit.offset_bottom = -20
	title_screen.add_child(credit)
	title_screen.visible = false

func show_title(has_save: bool) -> void:
	title_screen.visible = true
	continue_button.disabled = not has_save
	(continue_button if has_save else new_game_button).call_deferred("grab_focus")

func hide_title() -> void:
	title_screen.visible = false

# ------------------------------------------------------------------ pause

func _build_pause() -> void:
	pause_panel = PanelContainer.new()
	root.add_child(pause_panel)
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -350
	pause_panel.offset_right = 350
	pause_panel.offset_top = -270
	pause_panel.offset_bottom = 270
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	pause_panel.add_child(box)
	var heading: Label = UiTheme.title("Tạm dừng", 30)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for entry: Array in [["Tiếp tục", func() -> void: emit_signal("resume_requested")], ["Bản đồ  (M)", func() -> void: open_panel("map")],
			["Nhật ký  (J)", func() -> void: open_panel("journal")], ["Túi đồ & tu luyện  (I)", func() -> void: open_panel("inventory")],
			["Kiếm, Ngọc bội & trang phục", func() -> void: open_panel("armory")], ["Kỳ Ngộ", func() -> void: open_panel("gacha")],
			["Nhiệm vụ ngày", func() -> void: open_panel("daily")], ["Cảnh giới thế giới", func() -> void: open_panel("tier")],
			["Thiết lập", func() -> void: open_panel("settings")], ["Về Miếu Gió gần nhất", func() -> void: emit_signal("checkpoint_requested")],
			["Lưu hành trình  (F5)", func() -> void: emit_signal("save_requested")], ["Tải lần lưu gần nhất  (F9)", func() -> void: emit_signal("load_requested")],
			["Về màn hình chính", func() -> void: emit_signal("title_requested")], ["Thoát game", func() -> void: emit_signal("quit_requested")]]:
		if entry[0] == "Thoát game" and OS.has_feature("web"):
			continue
		var button: Button = UiTheme.button(entry[0], entry[1], 320)
		if resume_button == null:
			resume_button = button
		grid.add_child(button)
	leave_trial_button = UiTheme.button("Rời Ải Vô Tận (nhận thưởng)", func() -> void: main.leave_trial(), 660)
	box.add_child(leave_trial_button)
	pause_panel.visible = false

func set_paused(value: bool) -> void:
	pause_panel.visible = value and current_panel == ""
	leave_trial_button.visible = main.trial != null and main.trial.active
	if value and pause_panel.visible:
		resume_button.grab_focus()
	if not value:
		close_panel(true)

# ------------------------------------------------------------------ panels

func _build_panel_host() -> void:
	panel_host = PanelContainer.new()
	root.add_child(panel_host)
	panel_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_host.offset_left = 70
	panel_host.offset_right = -70
	panel_host.offset_top = 46
	panel_host.offset_bottom = -46
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel_host.add_child(box)
	var header: HBoxContainer = HBoxContainer.new()
	box.add_child(header)
	panel_title = UiTheme.title("", 30)
	panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(panel_title)
	close_button = UiTheme.button("Đóng  (Esc)", close_panel, 150)
	header.add_child(close_button)
	panel_body = MarginContainer.new()
	panel_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(panel_body)
	panel_host.visible = false

func panel_open() -> bool:
	return panel_host.visible

func open_panel(name: String) -> void:
	if current_panel != name:
		panel_note = ""
		panel_note_ok = false
		resume_on_close = false
	current_panel = name
	pause_panel.visible = false
	panel_host.visible = true
	close_button.visible = name != "trial_pick"
	for child: Node in panel_body.get_children():
		child.queue_free()
	match name:
		"map":
			panel_title.text = "Bản đồ thung lũng Vân Khê"
			panel_body.add_child(_map_view())
		"journal":
			panel_title.text = "Nhật ký hành trình"
			panel_body.add_child(_journal_view())
		"inventory":
			panel_title.text = "Túi đồ & tu luyện"
			panel_body.add_child(_inventory_view())
		"settings":
			panel_title.text = "Thiết lập"
			panel_body.add_child(_settings_view())
		"credits":
			panel_title.text = "Ghi công & giấy phép"
			panel_body.add_child(_credits_view())
		"gacha":
			panel_title.text = "Kỳ Ngộ"
			panel_body.add_child(RetentionPanels.gacha(self))
		"armory":
			panel_title.text = "Kho kiếm, Ngọc bội & trang phục"
			panel_body.add_child(RetentionPanels.armory(self))
		"daily":
			panel_title.text = "Nhiệm vụ ngày & điểm danh"
			panel_body.add_child(RetentionPanels.daily(self))
		"tier":
			panel_title.text = "Cảnh giới thế giới"
			panel_body.add_child(RetentionPanels.tier(self))
		"trial_pick":
			panel_title.text = "Ải Vô Tận"
			panel_body.add_child(RetentionPanels.trial_pick(self))
		"shop":
			panel_title.text = String(Consumables.shop(shop_id).get("name", "Quầy hàng"))
			panel_body.add_child(ShopPanel.build(self))

func close_panel(force: bool = false) -> void:
	## The Trial blessing picker cannot be dismissed: a blessing must be chosen.
	if current_panel == "trial_pick" and not force:
		return
	rebinding = ""
	if not panel_host.visible:
		return
	panel_host.visible = false
	current_panel = ""
	if resume_on_close:
		resume_on_close = false
		if get_tree().paused and not title_screen.visible:
			emit_signal("resume_requested")
		return
	if get_tree().paused and not title_screen.visible:
		pause_panel.visible = true
		resume_button.grab_focus()

func refresh_panel() -> void:
	if panel_host.visible:
		open_panel(current_panel)

# ------------------------------------------------------------------ credits

const CREDITS: Array[String] = [
	"[b]Vân Khê — Dư Âm Gió[/b] (Chương I, đoạn chơi mẫu)",
	"Thiết kế: Nguyễn Thành Long. Model, animation, nhạc và hiệu ứng âm thanh tạo riêng cho dự án.",
	"",
	"[b]Thành phần bên thứ ba[/b]",
	"• Godot Engine — giấy phép MIT (toàn văn bên dưới).",
	"• Phông Be Vietnam Pro và Lora — SIL Open Font License 1.1 (toàn văn bên dưới).",
	"• Hiệu ứng âm thanh Kenney (kenney.nl): Impact Sounds, RPG Audio, Interface Sounds — CC0 1.0.",
	"• Nhạc được render bằng soundfont FluidR3_GM (Frank Wen) — giấy phép MIT.",
]
const FONT_LICENCES: Array[String] = ["res://assets/fonts/OFL-BeVietnamPro.txt", "res://assets/fonts/OFL-Lora.txt"]

func _credits_view() -> Control:
	var text: RichTextLabel = RichTextLabel.new()
	text.bbcode_enabled = true
	text.selection_enabled = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_color_override("default_color", UiTheme.CREAM)
	text.add_theme_font_size_override("normal_font_size", 15)
	text.add_theme_font_size_override("bold_font_size", 17)
	var parts: PackedStringArray = PackedStringArray(CREDITS)
	parts.append("\n[b]Godot Engine[/b]")
	parts.append(_escape(Engine.get_license_text()))
	for path: String in FONT_LICENCES:
		if FileAccess.file_exists(path):
			parts.append("\n[b]%s[/b]" % path.get_file().get_basename())
			parts.append(_escape(FileAccess.get_file_as_string(path)))
	parts.append("\n[b]Thư viện tích hợp trong Godot[/b]")
	for component: Dictionary in Engine.get_copyright_info():
		var licences: PackedStringArray = PackedStringArray()
		for part: Dictionary in component.get("parts", []):
			licences.append(String(part.get("license", "")))
		parts.append("• %s — %s" % [_escape(String(component.get("name", ""))), ", ".join(licences)])
	var licence_info: Dictionary = Engine.get_license_info()
	for licence: String in licence_info:
		parts.append("\n[b]%s[/b]" % _escape(licence))
		parts.append(_escape(String(licence_info[licence])))
	text.text = "\n".join(parts)
	return text

func _escape(value: String) -> String:
	return value.replace("[", "[lb]")

# ------------------------------------------------------------------ map

func _map_view() -> Control:
	var view: MapView = MapView.new()
	view.main = main
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(900, 520)
	return view

# ------------------------------------------------------------------ journal

func _journal_view() -> Control:
	var split: HBoxContainer = HBoxContainer.new()
	split.add_theme_constant_override("separation", 18)
	var list: ItemList = ItemList.new()
	list.custom_minimum_size = Vector2(380, 0)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(list)
	var detail: RichTextLabel = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(detail)
	var ids: Array = main.state.quests.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var done_a: bool = main.quests.is_done(a)
		var done_b: bool = main.quests.is_done(b)
		if done_a != done_b:
			return not done_a
		return int(main.quests.definition(a).get("order", 50)) < int(main.quests.definition(b).get("order", 50)))
	var kinds: Dictionary = {"main": "Chính", "side": "Phụ", "event": "Sự kiện"}
	for id: String in ids:
		var data: Dictionary = main.quests.definition(id)
		var label: String = "%s  [%s]%s" % [data.get("title", id), kinds.get(data.get("kind", ""), ""), "  ✓" if main.quests.is_done(id) else ""]
		list.add_item(label)
		list.set_item_metadata(list.item_count - 1, id)
		if main.quests.is_done(id):
			list.set_item_custom_fg_color(list.item_count - 1, UiTheme.MUTED)
	var show: Callable = func(index: int) -> void:
		var id: String = list.get_item_metadata(index)
		var data: Dictionary = main.quests.definition(id)
		var text: String = "[font_size=26][color=#e9b24a]%s[/color][/font_size]\n\n" % data.get("title", id)
		text += "[color=#b8b09a]Nguyên do:[/color] %s\n\n" % data.get("cause", "")
		var objectives: Array = data.get("objectives", [])
		for index_objective: int in range(objectives.size()):
			var done: bool = main.quests.is_done(id) or index_objective < main.quests.stage(id)
			var current: bool = not done and index_objective == main.quests.stage(id)
			var line: String = objectives[index_objective].get("text", "")
			if current:
				line = main.quests.objective_text(id)
			if done or current:
				text += ("[color=#86d4c6]✓ %s[/color]\n" if done else "[color=#f3e6c8]➤ %s[/color]\n") % line
		if main.quests.is_done(id):
			text += "\n[color=#b8b09a]Kết quả:[/color] %s\n" % data.get("result", "")
		var rewards: Dictionary = data.get("rewards", {})
		var reward_parts: Array[String] = ["%d kinh nghiệm" % int(rewards.get("xp", 0))]
		for item: Array in rewards.get("items", []):
			reward_parts.append("%s ×%d" % [("Đồng" if item[0] == "coins" else ContentDB.item(item[0]).get("name", item[0])), int(item[1])])
		text += "\n[color=#b8b09a]Phần thưởng:[/color] %s" % ", ".join(reward_parts)
		if main.quests.is_active(id):
			main.state.tracked_quest = id
			text += "\n\n[color=#86d4c6](Đang theo dõi nhiệm vụ này)[/color]"
		detail.text = text
	list.item_selected.connect(show)
	if list.item_count > 0:
		var tracked: int = 0
		for index: int in range(list.item_count):
			if list.get_item_metadata(index) == main.state.tracked_quest:
				tracked = index
		list.select(tracked)
		show.call(tracked)
	else:
		detail.text = "Chưa có nhiệm vụ nào."
	return split

# ------------------------------------------------------------------ inventory

func _inventory_view() -> Control:
	var split: HBoxContainer = HBoxContainer.new()
	split.add_theme_constant_override("separation", 24)
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(470, 0)
	left.add_theme_constant_override("separation", 6)
	split.add_child(left)
	var state: GameState = main.state
	left.add_child(UiTheme.label("Hành trang", 20, UiTheme.GOLD, true))
	left.add_child(UiTheme.label("Đồng: %d" % state.coins, 17))
	var items: ItemList = ItemList.new()
	items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(items)
	var description: Label = UiTheme.label("", 15, UiTheme.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(460, 70)
	left.add_child(description)
	# Consumables can be used here (outside a fight) or put on the quick slot.
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	left.add_child(actions)
	var use_button: Button = UiTheme.button("Dùng", func() -> void:
		var refusal: String = main.use_item(selected_item)
		panel_note = refusal if refusal != "" else "Đã dùng " + String(ContentDB.item(selected_item).get("name", selected_item))
		panel_note_ok = refusal == ""
		refresh_panel(), 150)
	actions.add_child(use_button)
	var quick_button: Button = UiTheme.button("Đặt vào ô nhanh", func() -> void:
		var clearing: bool = state.quick_item == selected_item
		var title: String = String(ContentDB.item(selected_item).get("name", selected_item))
		main.set_quick_item("" if clearing else selected_item)
		panel_note = ("Đã bỏ %s khỏi ô nhanh" % title) if clearing else ("Đã đặt %s vào ô nhanh (%s)" % [title, UserSettings.event_label("use_item")])
		panel_note_ok = true
		refresh_panel(), 260)
	actions.add_child(quick_button)
	if panel_note != "":
		var note: Label = UiTheme.label(panel_note, 15, UiTheme.JADE_LIGHT if panel_note_ok else UiTheme.VERMILION)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size.x = 460
		left.add_child(note)
	var keys: Array = state.inventory.keys()
	keys.sort()
	for item_id: String in keys:
		var item: Dictionary = ContentDB.item(item_id)
		items.add_item("%s  ×%d%s" % [item.get("name", item_id), state.count(item_id), "   ◆ ô nhanh" if item_id == state.quick_item else ""])
		items.set_item_metadata(items.item_count - 1, item_id)
	var select: Callable = func(index: int) -> void:
		selected_item = items.get_item_metadata(index)
		description.text = ContentDB.item(selected_item).get("description", "")
		use_button.disabled = not Consumables.usable(selected_item)
		quick_button.disabled = use_button.disabled
		quick_button.text = "Bỏ khỏi ô nhanh" if state.quick_item == selected_item else "Đặt vào ô nhanh"
	items.item_selected.connect(select)
	use_button.disabled = true
	quick_button.disabled = true
	var kept: int = keys.find(selected_item)
	if kept >= 0:
		items.select(kept)
		select.call(kept)
	var right: VBoxContainer = VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	right.add_child(UiTheme.label("Lâm An — Cấp %d" % state.level, 20, UiTheme.GOLD, true))
	right.add_child(UiTheme.label("Kinh nghiệm: %d / %d   •   Điểm tu luyện: %d" % [state.xp, state.xp_for_next(), state.skill_points], 16))
	right.add_child(UiTheme.label("Khí huyết tối đa: %d   •   Công lực: %d" % [roundi(state.max_health()), roundi(state.attack_power())], 16))
	var style: String = StyleBook.style_of(state.sword)
	right.add_child(UiTheme.label("Kiếm: %s  •  %s" % [ContentDB.weapon(state.sword).get("name", state.sword), ContentDB.style(style).get("name", "")], 16, UiTheme.JADE_LIGHT, true))
	right.add_child(UiTheme.label("Tơ ký ức đã kết: %d" % state.count("to_ky_uc"), 16, UiTheme.CREAM))
	# Cultivation and the character sheet share the rest of the column as two tabs.
	var tabs: TabContainer = TabContainer.new()
	tabs.name = "InventoryTabs"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(tabs)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Võ học"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	# The equipped sword's style first, then any other style with a learned form.
	var shown: Array = [style]
	for other: String in StyleBook.styles():
		if other != style and ["e", "q"].any(func(slot: String) -> bool: return state.skill_level(String(StyleBook.form(other, slot).get("skill", ""))) > 0):
			shown.append(other)
	for shown_style: String in shown:
		list.add_child(UiTheme.label(String(ContentDB.style(shown_style).get("name", "")), 16, StyleBook.color(shown_style), true))
		for slot: String in StyleBook.SLOTS:
			var form: Dictionary = StyleBook.form(shown_style, slot)
			_skill_row(list, String(form["skill"]), "%s [%s]" % [form.get("name", ""), UserSettings.event_label(StyleBook.SLOT_ACTIONS[slot])],
				String(form.get("description", "")) + ("  Tốn đầy nộ khí." if slot == "x" else "  Mỗi bậc: +25% sát thương, -15% hồi chiêu."),
				String(StyleBook.form(shown_style, "q").get("skill", "")) if slot == "x" else "")
	_skill_row(list, "khinh_cong", "Khinh công", "Nhảy trên không (Space) và lướt gió (giữ Space). Mỗi bậc giảm thể lực tiêu hao.", "")
	tabs.add_child(_character_view())
	tabs.current_tab = clampi(inventory_tab, 0, tabs.get_tab_count() - 1)
	tabs.tab_changed.connect(func(tab: int) -> void: inventory_tab = tab)
	return split

func _character_view() -> Control:
	## Nhân vật: every stat as one total (PlayerStats.sheet reads GameState.stat, so the sword,
	## talismans, Trial blessings and live buffs all count), bonuses in jade, penalties in vermilion.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Nhân vật"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	for row: Dictionary in PlayerStats.sheet(main.state):
		if row.has("header"):
			list.add_child(UiTheme.label(String(row["header"]), 17, UiTheme.GOLD, true))
			continue
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var name_label: Label = UiTheme.label(String(row["label"]), 15)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		if String(row["detail"]) != "":
			line.add_child(UiTheme.label(String(row["detail"]), 13, UiTheme.MUTED))
		var tone: int = int(row["tone"])
		var idle: bool = tone == 0 and String(row["value"]) in ["0", "0%"]
		var value: Label = UiTheme.label(String(row["value"]), 15, UiTheme.JADE_LIGHT if tone > 0 else (UiTheme.VERMILION if tone < 0 else (UiTheme.MUTED if idle else UiTheme.CREAM)), true)
		value.custom_minimum_size.x = 80
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(value)
		list.add_child(line)
	var note: Label = UiTheme.label("Chỉ số tổng của cấp, kiếm, Ngọc bội (cả hiệu ứng bộ), phúc lành Ải và các trạng thái đang có.", 13, UiTheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(note)
	return scroll

func _skill_row(list: VBoxContainer, skill: String, title: String, description: String, ultimate_needs: String) -> void:
	## One cultivation line. Ultimates (ultimate_needs = the style's Q skill) are learned with points.
	var state: GameState = main.state
	var row: HBoxContainer = HBoxContainer.new()
	var level: int = state.skill_level(skill)
	var text: Label = UiTheme.label("%s — %s\n%s" % [title, ("bậc %d/3" % level) if level > 0 else "chưa lĩnh hội", description], 15)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	if ultimate_needs != "" and level == 0:
		var learn: Button = UiTheme.button("Lĩnh hội (%d điểm)" % StyleBook.ULT_COST, func() -> void:
			if state.learn_ultimate(skill, ultimate_needs):
				main.unlock_skill(skill)
			refresh_panel(), 170)
		learn.disabled = state.skill_level(ultimate_needs) <= 0 or state.skill_points < StyleBook.ULT_COST
		row.add_child(learn)
	else:
		var upgrade: Button = UiTheme.button("Nâng bậc", func() -> void:
			if state.upgrade_skill(skill):
				main.on_skill_upgraded(skill)
			refresh_panel(), 130)
		upgrade.disabled = level == 0 or level >= 3 or state.skill_points <= 0
		row.add_child(upgrade)
	list.add_child(row)

# ------------------------------------------------------------------ settings

func _settings_view() -> Control:
	var settings: UserSettings = main.user_settings
	var tabs: TabContainer = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var controls: VBoxContainer = VBoxContainer.new()
	controls.name = "Điều khiển"
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Điều khiển"
	scroll.add_child(controls)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(scroll)
	controls.add_child(_slider_row("Độ nhạy chuột", 0.0006, 0.008, settings.mouse_sensitivity, func(value: float) -> void:
		settings.mouse_sensitivity = value
		_changed()))
	controls.add_child(_check_row("Đảo trục dọc chuột", settings.invert_y, func(value: bool) -> void:
		settings.invert_y = value
		_changed()))
	rebind_buttons.clear()
	for action: String in UserSettings.REBINDABLE:
		var row: HBoxContainer = HBoxContainer.new()
		var name_label: Label = UiTheme.label(UserSettings.ACTION_NAMES.get(action, action), 16)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var button: Button = UiTheme.button(UserSettings.event_label(action), func() -> void: _begin_rebind(action), 220)
		rebind_buttons[action] = button
		row.add_child(button)
		controls.add_child(row)
	controls.add_child(UiTheme.button("Khôi phục phím mặc định", func() -> void:
		settings.reset_bindings()
		_changed()
		refresh_panel(), 300))
	var audio: VBoxContainer = VBoxContainer.new()
	audio.name = "Âm thanh"
	tabs.add_child(audio)
	for entry: Array in [["Nhạc nền", "music_volume"], ["Hiệu ứng", "sfx_volume"], ["Âm thanh môi trường", "ambience_volume"]]:
		var key: String = entry[1]
		audio.add_child(_slider_row(entry[0], 0.0, 1.0, float(settings.get(key)), func(value: float) -> void:
			settings.set(key, value)
			_changed()))
	var video: VBoxContainer = VBoxContainer.new()
	video.name = "Hình ảnh"
	tabs.add_child(video)
	var quality_row: HBoxContainer = HBoxContainer.new()
	var quality_label: Label = UiTheme.label("Chất lượng đồ họa", 16)
	quality_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quality_row.add_child(quality_label)
	var quality: OptionButton = OptionButton.new()
	var keys: Array = UserSettings.QUALITY.keys()
	for index: int in range(keys.size()):
		quality.add_item(UserSettings.QUALITY[keys[index]]["label"])
		if keys[index] == settings.quality:
			quality.select(index)
	quality.item_selected.connect(func(index: int) -> void:
		settings.quality = keys[index]
		_changed())
	quality_row.add_child(quality)
	video.add_child(quality_row)
	video.add_child(_check_row("Toàn màn hình", settings.fullscreen, func(value: bool) -> void:
		settings.fullscreen = value
		if OS.has_feature("web"):
			# Browsers only allow fullscreen inside the click that asks for it.
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
		_changed()))
	video.add_child(_check_row("Hiện số sát thương", settings.damage_numbers, func(value: bool) -> void:
		settings.damage_numbers = value
		_changed()))
	video.add_child(_check_row("Thời tiết động", settings.dynamic_weather, func(value: bool) -> void:
		settings.dynamic_weather = value
		_changed()))
	video.add_child(_check_row("Bảng thông số kỹ thuật (F3)", settings.debug_hud, func(value: bool) -> void:
		settings.debug_hud = value
		_changed()))
	video.add_child(_slider_row("Độ rung camera", 0.0, 1.0, settings.camera_shake, func(value: float) -> void:
		settings.camera_shake = value
		_changed()))
	var note: Label = UiTheme.label("Thấp: tắt bóng đổ, giảm cỏ cây và độ phân giải dựng hình. Cao: bóng đổ xa hơn, khử răng cưa 4x.\nTắt Thời tiết động: trời luôn quang, ngày đêm vẫn luân chuyển.", 14, UiTheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	video.add_child(note)
	return tabs

func _slider_row(text: String, low: float, high: float, value: float, callback: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = UiTheme.label(text, 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = (high - low) / 100.0
	slider.value = value
	slider.custom_minimum_size = Vector2(320, 24)
	slider.value_changed.connect(callback)
	row.add_child(slider)
	return row

func _check_row(text: String, value: bool, callback: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var check: CheckBox = CheckBox.new()
	check.text = text
	check.button_pressed = value
	check.toggled.connect(callback)
	row.add_child(check)
	return row

func _begin_rebind(action: String) -> void:
	rebinding = action
	(rebind_buttons[action] as Button).text = "Bấm phím mới…"

func _input(event: InputEvent) -> void:
	if rebinding == "" or not panel_host.visible:
		return
	if (event is InputEventKey and (event as InputEventKey).pressed) or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		get_viewport().set_input_as_handled()
		if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
			rebinding = ""
			refresh_panel()
			return
		main.user_settings.rebind(rebinding, event)
		rebinding = ""
		_changed()
		refresh_panel()

func _changed() -> void:
	emit_signal("settings_changed")
