class_name StylesPanel
extends RefCounted
## Kiếm Quyết panel (K): the three skill keys with the forms bound to them, the six elemental
## sword arts as medallions (locked ones say which quest teaches them), and the chosen style's
## forms with "bind to this key", cultivation (+25% damage, -15% cooldown a level) and the
## ultimate bought with points. Its element's status and the reactions it takes part in are
## listed so the player can plan combinations. Built by Menus.open_panel; every change goes
## through GameState (main.equip_style for the binding) and redraws the panel.

static func build(menus: Menus) -> Control:
	var main: Node = menus.main
	var state: GameState = main.state
	if menus.selected_style == "" or ContentDB.style(menus.selected_style).is_empty():
		menus.selected_style = state.slot_style("e")
	var root: HBoxContainer = HBoxContainer.new()
	root.add_theme_constant_override("separation", 22)
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size.x = 420
	left.add_theme_constant_override("separation", 12)
	root.add_child(left)
	left.add_child(UiTheme.label("Chiêu đang gắn", 18, UiTheme.GOLD, true))
	var keys: HBoxContainer = HBoxContainer.new()
	keys.add_theme_constant_override("separation", 10)
	left.add_child(keys)
	for slot: String in StyleBook.SLOTS:
		keys.add_child(_bound_card(state, slot))
	left.add_child(UiTheme.label("Ngũ hành kiếm quyết", 18, UiTheme.GOLD, true))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	left.add_child(grid)
	for style: String in StyleBook.styles():
		var bound: PackedStringArray = []
		for slot: String in StyleBook.SLOTS:
			if state.slot_style(slot) == style:
				bound.append(slot)
		var medallion: StyleMedallion = StyleMedallion.new().setup(style, state.style_learned(style), style == menus.selected_style, bound)
		medallion.pressed.connect(func() -> void:
			menus.selected_style = style
			menus.refresh_panel())
		grid.add_child(medallion)
		if style == menus.selected_style:
			medallion.call_deferred("grab_focus")
	var learned: int = state.learned_styles().size()
	left.add_child(UiTheme.label("Đã lĩnh hội %d/%d  •  Điểm tu luyện: %d" % [learned, StyleBook.styles().size(), state.skill_points], 15, UiTheme.CREAM, true))
	var sword: Dictionary = ContentDB.weapon(state.sword)
	var sword_element: String = String(sword.get("element", ""))
	var attune: Label = UiTheme.label("Kiếm đang cầm: %s%s" % [String(sword.get("name", state.sword)),
		("  •  hệ %s: chiêu cùng hệ +%d%% sát thương" % [String(ContentDB.element(sword_element).get("name", "")), roundi(StyleBook.ATTUNE_BONUS * 100.0)]) if sword_element != "" else "  •  kiếm thường, không cộng hệ"], 14, UiTheme.MUTED)
	attune.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attune.custom_minimum_size.x = 410
	left.add_child(attune)
	var tip: Label = UiTheme.label("Giữ %s giữa trận để mở vòng Kiếm Quyết và đổi cả bộ trong tích tắc." % UserSettings.event_label("style_wheel"), 14, UiTheme.MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size.x = 410
	left.add_child(tip)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	scroll.add_child(_details(menus, menus.selected_style))
	return root

static func _bound_card(state: GameState, slot: String) -> PanelContainer:
	var style: String = state.slot_style(slot)
	var form: Dictionary = StyleBook.form(style, slot)
	var known: bool = state.skill_level(String(form.get("skill", ""))) > 0
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.card_style(StyleBook.color(style), known))
	card.custom_minimum_size = Vector2(132, 0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	box.add_child(UiTheme.chip(UserSettings.event_label(StyleBook.SLOT_ACTIONS[slot]), UiTheme.GOLD if slot == "x" else UiTheme.CREAM, UiTheme.INK, 14))
	var name: Label = UiTheme.label(String(form.get("name", "")), 15, StyleBook.color(style).lightened(0.3) if known else UiTheme.MUTED, true)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name)
	box.add_child(UiTheme.label(String(ContentDB.style(style).get("name", "")).trim_suffix(" Quyết"), 12, UiTheme.MUTED))
	if not known:
		box.add_child(UiTheme.label("chưa lĩnh hội", 12, UiTheme.VERMILION))
	return card

static func _details(menus: Menus, style: String) -> VBoxContainer:
	var main: Node = menus.main
	var state: GameState = main.state
	var data: Dictionary = ContentDB.style(style)
	var color: Color = StyleBook.color(style)
	var known: bool = state.style_learned(style)
	var element: String = String(data.get("element", ""))
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	var title: Label = UiTheme.title(String(data.get("name", style)), 30, color.lightened(0.2))
	head.add_child(title)
	head.add_child(UiTheme.chip("Hệ " + String(ContentDB.element(element).get("name", "")), color, UiTheme.INK, 14))
	if not known:
		head.add_child(UiTheme.chip("Chưa lĩnh hội", Color(0.4, 0.42, 0.42), UiTheme.CREAM, 13))
	box.add_child(UiTheme.label(String(data.get("role", "")), 16, UiTheme.CREAM))
	if menus.panel_note != "":
		box.add_child(UiTheme.label(menus.panel_note, 15, UiTheme.JADE_LIGHT if menus.panel_note_ok else UiTheme.VERMILION))
	if not known:
		var lock: Label = UiTheme.label("Cách lĩnh hội: " + StyleBook.unlock_hint(style), 16, UiTheme.GOLD)
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(lock)
		var quest: String = StyleBook.unlock_quest(style)
		if quest != "" and main.quests.is_active(quest):
			box.add_child(UiTheme.label("Đang làm: " + String(main.quests.definition(quest).get("title", quest)), 15, UiTheme.JADE_LIGHT))
	for slot: String in StyleBook.SLOTS:
		box.add_child(_form_card(menus, style, slot))
	var equip_all: Button = UiTheme.button("Trang bị cả bộ lên %s / %s / %s" % [UserSettings.event_label("skill_1"), UserSettings.event_label("skill_2"), UserSettings.event_label("skill_ult")], func() -> void:
		var ok: bool = main.equip_style(style)
		menus.panel_note = ("Đã gắn %s lên cả ba phím" % String(data.get("name", style))) if ok else "Chưa lĩnh hội Kiếm Quyết này"
		menus.panel_note_ok = ok
		menus.refresh_panel(), 420, true)
	equip_all.disabled = not known or Array(StyleBook.SLOTS).all(func(slot: String) -> bool: return state.slot_style(slot) == style)
	box.add_child(equip_all)
	box.add_child(UiTheme.label("Ngũ hành tương tác", 17, UiTheme.GOLD, true))
	var status_id: String = String(ContentDB.element(element).get("status", ""))
	var status: Dictionary = ContentDB.status(status_id)
	var lines: PackedStringArray = []
	lines.append("Trạng thái gây ra: %s%s" % [String(status.get("name", status_id)), (" — " + String(status.get("hint", "")).get_slice(":", 1).strip_edges()) if status.has("hint") else ""])
	for reaction: Dictionary in Reactions.list():
		var needs: Array = reaction.get("needs", [])
		if String(reaction.get("element", "")) == element or needs.has(status_id):
			lines.append("• " + String(reaction.get("hint", reaction.get("name", ""))))
	var info: Label = UiTheme.label("\n".join(lines), 14, UiTheme.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info)
	return box

static func _form_card(menus: Menus, style: String, slot: String) -> PanelContainer:
	var main: Node = menus.main
	var state: GameState = main.state
	var form: Dictionary = StyleBook.form(style, slot)
	var skill: String = String(form.get("skill", ""))
	var level: int = state.skill_level(skill)
	var color: Color = StyleBook.color(style)
	var bound_here: bool = state.slot_style(slot) == style
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.card_style(color, bound_here and level > 0))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	row.add_child(UiTheme.chip(UserSettings.event_label(StyleBook.SLOT_ACTIONS[slot]), UiTheme.GOLD if slot == "x" else UiTheme.CREAM, UiTheme.INK, 16))
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var level_text: String = ("bậc %d/3" % level) if level > 0 and slot != "x" else ("đã lĩnh hội" if level > 0 else "chưa lĩnh hội")
	text.add_child(UiTheme.label("%s  —  %s" % [String(form.get("name", "")), level_text], 17, color.lightened(0.3) if level > 0 else UiTheme.MUTED, true))
	var cooldown: String = "Tốn đầy nộ khí." if slot == "x" else "Hồi %ds. Mỗi bậc: +25%% sát thương, -15%% hồi chiêu." % roundi(float(form.get("cooldown", 0.0)))
	var description: Label = UiTheme.label("%s  %s" % [String(form.get("description", "")), cooldown], 14, UiTheme.CREAM)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(description)
	var actions: VBoxContainer = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	row.add_child(actions)
	var bind: Button = UiTheme.button("Đang gắn" if bound_here else "Gắn vào %s" % UserSettings.event_label(StyleBook.SLOT_ACTIONS[slot]), func() -> void:
		var ok: bool = main.equip_style(style, slot)
		menus.panel_note = ("Đã gắn %s vào %s" % [String(form.get("name", "")), UserSettings.event_label(StyleBook.SLOT_ACTIONS[slot])]) if ok else "Chưa lĩnh hội Kiếm Quyết này"
		menus.panel_note_ok = ok
		menus.refresh_panel(), 170, not bound_here)
	bind.disabled = bound_here or not state.style_learned(style)
	actions.add_child(bind)
	if slot == "x" and level == 0:
		var needs: String = String(StyleBook.form(style, "q").get("skill", ""))
		var learn: Button = UiTheme.button("Lĩnh hội (%d điểm)" % StyleBook.ULT_COST, func() -> void:
			if state.learn_ultimate(skill, needs):
				main.unlock_skill(skill)
			menus.refresh_panel(), 170)
		learn.disabled = state.skill_level(needs) <= 0 or state.skill_points < StyleBook.ULT_COST
		actions.add_child(learn)
	elif slot != "x":
		var upgrade: Button = UiTheme.button("Nâng bậc", func() -> void:
			if state.upgrade_skill(skill):
				main.on_skill_upgraded(skill)
			menus.refresh_panel(), 170)
		upgrade.disabled = level == 0 or level >= 3 or state.skill_points <= 0
		actions.add_child(upgrade)
	return card
