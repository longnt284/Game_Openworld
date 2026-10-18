class_name RetentionPanels
extends RefCounted
## Full-screen panels for the long-term systems: Kỳ Ngộ banner, armory and outfits, daily
## missions with the login calendar, World Tier and the Endless Trial blessing picker.
## Built by Menus.open_panel; they read `menus.main` and call its retention methods.

const BANNER: String = "ngu_hanh"

static func _percent(value: float) -> String:
	return ("%.1f%%" % (value * 100.0)).replace(".", ",")

static func _card(color: Color, min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.11, 0.13, 0.95)
	box.border_color = color
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", box)
	card.custom_minimum_size = min_size
	return card

static func _wrap(label: Label, width: float) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = width
	return label

static func _scroll(content: Control) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return scroll

static func _reward_label(entry: Dictionary) -> String:
	match String(entry.get("type", "")):
		"weapon":
			return String(ContentDB.weapon(String(entry["base"])).get("name", entry["base"]))
		"skin":
			return "Trang phục " + String(ContentDB.skin(String(entry["id"])).get("name", entry["id"]))
		"shards":
			return "%s ×%d" % [Gacha.data()["shards"]["name"], int(entry.get("amount", 1))]
	return "?"

# ------------------------------------------------------------------ Kỳ Ngộ

static func gacha(menus: Menus) -> Control:
	var main: Node = menus.main
	var profile: PlayerProfile = main.profile
	var info: Dictionary = Gacha.banner(BANNER)
	var pity: Dictionary = Gacha.new_pity()
	pity.merge(profile.pity.get(BANNER, {}), true)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	var head: HBoxContainer = HBoxContainer.new()
	root.add_child(head)
	var name: Label = UiTheme.title(String(info.get("name", "Kỳ Ngộ")), 26, UiTheme.GOLD)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(UiTheme.label("%s: %d   •   %s: %d" % [Gacha.data()["currency"]["name"], profile.balance(Gacha.currency()),
		Gacha.data()["shards"]["name"], profile.balance(Gacha.shards())], 18, UiTheme.JADE_LIGHT, true))
	root.add_child(_wrap(UiTheme.label(String(info.get("description", "")), 15, UiTheme.MUTED), 860))
	var hard: int = int(info["pity"]["hard"])
	root.add_child(UiTheme.label("Bảo hiểm: %d/%d lượt kể từ lần Cực phẩm trước  •  %s  •  Tổng: %d lượt" % [int(pity["since_ssr"]), hard,
		"lần Cực phẩm kế tiếp chắc chắn ra kiếm nổi bật" if pity["guaranteed"] else "Cực phẩm kế tiếp: 50% ra kiếm nổi bật", int(pity["total"])], 15, UiTheme.CREAM))
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	root.add_child(buttons)
	for count: int in [1, 10]:
		var price: int = Gacha.cost(BANNER, count)
		var pull: Button = UiTheme.button("Quay ×%d  (%d Ngọc)" % [count, price], func() -> void:
			var results: Array = main.gacha_pull(count)
			if results.is_empty():
				menus.panel_note = "Không đủ Ngọc Gió. Nhận thêm từ Ải Vô Tận, boss Cảnh giới, nhiệm vụ ngày và điểm danh."
				main.audio.ui("ui_error")
			else:
				menus.last_pull = results
				menus.reveal = true
				menus.panel_note = ""
				var best: String = "r"
				for result: Dictionary in results:
					if result["rarity"] == "ssr" or (result["rarity"] == "sr" and best == "r"):
						best = result["rarity"]
				main.audio.ui("ui_confirm")
				main.audio.play("level_up" if best == "ssr" else ("glint" if best == "sr" else "pickup"))
			menus.refresh_panel(), 260)
		pull.disabled = profile.balance(Gacha.currency()) < price
		buttons.add_child(pull)
	if menus.panel_note != "":
		root.add_child(UiTheme.label(menus.panel_note, 15, UiTheme.VERMILION))
	var tabs: TabContainer = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	tabs.add_child(_pull_results(menus))
	tabs.add_child(_rates(info))
	tabs.add_child(_history(profile))
	tabs.add_child(_exchange(menus))
	return root

static func _pull_results(menus: Menus) -> Control:
	var grid: GridContainer = GridContainer.new()
	grid.name = "Kết quả"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	if menus.last_pull.is_empty():
		grid.add_child(_wrap(UiTheme.label("Chưa quay lần nào trong phiên này. Kết quả sẽ hiện ở đây.", 15, UiTheme.MUTED), 600))
		return grid
	for index: int in range(menus.last_pull.size()):
		var result: Dictionary = menus.last_pull[index]
		var color: Color = PlayerStats.rarity_color(String(result["rarity"]))
		var card: PanelContainer = _card(color, Vector2(196, 112))
		var box: VBoxContainer = VBoxContainer.new()
		card.add_child(box)
		box.add_child(UiTheme.label(String(PlayerStats.rarity_data(String(result["rarity"])).get("name", "")) + ("  ★ Nổi bật" if result.get("featured", false) else ""), 14, color, true))
		box.add_child(_wrap(UiTheme.label(String(result.get("label", "")), 15, UiTheme.CREAM, true), 166))
		for affix: Array in result.get("affixes", []):
			box.add_child(UiTheme.label(PlayerStats.affix_text(affix), 13, UiTheme.MUTED))
		grid.add_child(card)
		if menus.reveal:
			# Cards flip in one after another.
			card.pivot_offset = Vector2(98, 56)
			card.scale = Vector2(0.0, 1.0)
			card.modulate.a = 0.0
			var tween: Tween = card.create_tween().set_parallel(true)
			tween.tween_property(card, "scale", Vector2.ONE, 0.22).set_delay(index * 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "modulate:a", 1.0, 0.18).set_delay(index * 0.07)
	menus.reveal = false
	return _scroll_named(grid, "Kết quả")

static func _scroll_named(content: Control, title: String) -> ScrollContainer:
	content.name = "Content"
	var scroll: ScrollContainer = _scroll(content)
	scroll.name = title
	return scroll

static func _rates(info: Dictionary) -> Control:
	var text: RichTextLabel = RichTextLabel.new()
	text.name = "Tỷ lệ & bảo hiểm"
	text.bbcode_enabled = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_color_override("default_color", UiTheme.CREAM)
	var rates: Dictionary = info["rates"]
	var pity: Dictionary = info["pity"]
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[b]Tỷ lệ công khai[/b]")
	lines.append("• Cực phẩm (SSR): %s mỗi lượt  —  tổng hợp tính cả bảo hiểm ≈ %s" % [_percent(float(rates["ssr"])), _percent(Gacha.consolidated_ssr(BANNER))])
	lines.append("• Hiếm (SR): %s mỗi lượt" % _percent(float(rates["sr"])))
	lines.append("• Thường (R): %s mỗi lượt" % _percent(float(rates["r"])))
	lines.append("\n[b]Bảo hiểm[/b]")
	lines.append("• Từ lượt thứ %d không ra Cực phẩm, tỉ lệ Cực phẩm tăng thêm %s mỗi lượt." % [int(pity["soft_from"]), _percent(float(pity["soft_step"]))])
	lines.append("• Lượt thứ %d chắc chắn ra Cực phẩm." % int(pity["hard"]))
	lines.append("• Cứ %d lượt chắc chắn có ít nhất một vật phẩm Hiếm trở lên." % int(pity["sr_every"]))
	lines.append("• Khi ra Cực phẩm: %s là kiếm nổi bật; trượt thì lần Cực phẩm sau chắc chắn là kiếm nổi bật." % _percent(float(info["featured"].get("rate_up", 0.5))))
	lines.append("• Bảo hiểm được lưu lại giữa các lần chơi và dùng chung cho mọi bản lưu.")
	lines.append("\n[b]Vật phẩm có thể nhận[/b] (chia đều trong mỗi bậc)")
	for rarity: String in Gacha.RARITIES:
		var names: PackedStringArray = PackedStringArray()
		for entry: Dictionary in info["pool"][rarity]:
			var label: String = _reward_label(entry)
			if not names.has(label):
				names.append(label)
		lines.append("• %s: %s" % [PlayerStats.rarity_data(rarity).get("name", rarity), ", ".join(names)])
	lines.append("\nKiếm nhận được có %s; bậc càng cao càng nhiều dòng chỉ số và công lực gốc cao hơn." % ", ".join(PackedStringArray([
		"Thường 1 dòng", "Hiếm 2 dòng (+10% công lực)", "Cực phẩm 3 dòng (+20% công lực)"])))
	lines.append("Trang phục trùng đổi thành %d %s." % [int(Gacha.data()["duplicates"]["skin"]), Gacha.data()["shards"]["name"]])
	lines.append("\n[color=#b8b09a]Ngọc Gió chỉ kiếm được trong game: Ải Vô Tận, boss Cảnh giới thế giới, nhiệm vụ ngày và điểm danh. Không có giao dịch bằng tiền thật.[/color]")
	text.text = "\n".join(lines)
	return text

static func _history(profile: PlayerProfile) -> Control:
	var list: ItemList = ItemList.new()
	list.name = "Lịch sử"
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if profile.history.is_empty():
		list.add_item("Chưa có lượt quay nào.")
	for entry: Dictionary in profile.history:
		list.add_item("%s   %s   %s" % [String(entry.get("time", "")).replace("T", " "), PlayerStats.rarity_data(String(entry["rarity"])).get("name", ""), entry.get("label", "")])
		list.set_item_custom_fg_color(list.item_count - 1, PlayerStats.rarity_color(String(entry["rarity"])))
	return list

static func _exchange(menus: Menus) -> Control:
	var main: Node = menus.main
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Đổi Mảnh"
	box.add_theme_constant_override("separation", 8)
	box.add_child(UiTheme.label("Đổi %s lấy phần thưởng cố định:" % Gacha.data()["shards"]["name"], 16, UiTheme.GOLD, true))
	for offer: Dictionary in Gacha.data().get("exchange", []):
		var row: HBoxContainer = HBoxContainer.new()
		var label: Label = UiTheme.label(String(offer["label"]), 16)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var id: String = String(offer["id"])
		var trade: Button = UiTheme.button("Đổi (%d Mảnh)" % int(offer["cost"]), func() -> void:
			var result: Dictionary = Gacha.exchange(main.profile, id)
			if result.is_empty():
				menus.panel_note = "Không đủ Mảnh, hoặc đã sở hữu trang phục này."
				main.audio.ui("ui_error")
			else:
				menus.last_pull = [result]
				menus.reveal = true
				menus.panel_note = ""
				main.save_profile()
				main.audio.ui("ui_confirm")
			menus.refresh_panel(), 200)
		var reward: Dictionary = offer["reward"]
		trade.disabled = main.profile.balance(Gacha.shards()) < int(offer["cost"]) or (reward.get("type", "") == "skin" and main.profile.skins.has(String(reward["id"])))
		row.add_child(trade)
		box.add_child(row)
	return box

# ------------------------------------------------------------------ armory & outfits

static func armory(menus: Menus) -> Control:
	var main: Node = menus.main
	var profile: PlayerProfile = main.profile
	var state: GameState = main.state
	var can_equip: bool = main.playing and main.player.state == "move"
	var split: HBoxContainer = HBoxContainer.new()
	split.add_theme_constant_override("separation", 24)
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	split.add_child(_scroll(left))
	left.add_child(UiTheme.label("Kiếm", 20, UiTheme.GOLD, true))
	if not main.playing:
		left.add_child(_wrap(UiTheme.label("Vào hành trình để trang bị kiếm. Kho kiếm dùng chung cho mọi bản lưu.", 14, UiTheme.MUTED), 520))
	elif not can_equip:
		left.add_child(UiTheme.label("Chỉ đổi kiếm khi đứng yên, không giao chiến.", 14, UiTheme.MUTED))
	if main.playing:
		for id: String in state.swords:
			var data: Dictionary = ContentDB.weapon(id)
			var equipped: bool = state.sword == id and state.equipped_uid < 0
			left.add_child(_weapon_row(String(data.get("name", id)), "Kiếm cốt truyện  •  Công lực %d  •  %s" % [int(data.get("attack", 10)), ContentDB.style(StyleBook.style_of(id)).get("name", "")],
				[], UiTheme.CREAM, equipped, can_equip, func() -> void:
					main.equip_story_sword(id)
					menus.refresh_panel()))
	var items: Array = profile.armory.duplicate()
	var order: Dictionary = {"ssr": 0, "sr": 1, "r": 2}
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(order.get(a["rarity"], 3)) < int(order.get(b["rarity"], 3)) or (a["rarity"] == b["rarity"] and int(a["uid"]) > int(b["uid"])))
	if items.is_empty():
		left.add_child(_wrap(UiTheme.label("Kho chưa có kiếm nào. Kiếm có chỉ số đến từ Kỳ Ngộ và rương thưởng.", 14, UiTheme.MUTED), 520))
	for item: Dictionary in items:
		var base: String = String(item["base"])
		var uid: int = int(item["uid"])
		var rarity: String = String(item["rarity"])
		var subtitle: String = "%s  •  Công lực %d (+%d%%)  •  %s" % [PlayerStats.rarity_data(rarity).get("name", ""), int(ContentDB.weapon(base).get("attack", 10)),
			roundi(float(PlayerStats.rarity_data(rarity).get("attack", 0.0)) * 100.0), ContentDB.style(StyleBook.style_of(base)).get("name", "")]
		left.add_child(_weapon_row(String(ContentDB.weapon(base).get("name", base)), subtitle, item.get("affixes", []), PlayerStats.rarity_color(rarity),
			main.playing and state.equipped_uid == uid, can_equip, func() -> void:
				main.equip_armory(uid)
				menus.refresh_panel()))
	var right: VBoxContainer = VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	split.add_child(_scroll(right))
	for target: String in ["player", "weapon"]:
		right.add_child(UiTheme.label("Trang phục Lâm An" if target == "player" else "Ánh kiếm", 20, UiTheme.GOLD, true))
		var current: String = String(profile.equipped_skins.get(target, ""))
		right.add_child(_skin_row("Mặc định", "", current == "", true, UiTheme.CREAM, func() -> void:
			main.equip_skin(target, "")
			menus.refresh_panel()))
		var skins: Dictionary = ContentDB.get_data("skins")
		for id: String in skins:
			if String(skins[id].get("target", "")) != target:
				continue
			var owned: bool = profile.skins.has(id)
			right.add_child(_skin_row(String(skins[id]["name"]), String(skins[id].get("description", "")) + ("" if owned else "  (chưa có — Kỳ Ngộ)"),
				current == id, owned, PlayerStats.rarity_color(String(skins[id].get("rarity", "sr"))), func() -> void:
					main.equip_skin(target, id)
					menus.refresh_panel()))
	return split

static func _weapon_row(title: String, subtitle: String, affixes: Array, color: Color, equipped: bool, can_equip: bool, on_equip: Callable) -> Control:
	var card: PanelContainer = _card(color if equipped else color.darkened(0.45))
	var row: HBoxContainer = HBoxContainer.new()
	card.add_child(row)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UiTheme.label(title, 17, color, true))
	text.add_child(UiTheme.label(subtitle, 14, UiTheme.MUTED))
	for affix: Array in affixes:
		text.add_child(UiTheme.label("◆ " + PlayerStats.affix_text(affix), 14, UiTheme.JADE_LIGHT))
	if equipped:
		row.add_child(UiTheme.label("Đang dùng", 15, UiTheme.GOLD, true))
	else:
		var button: Button = UiTheme.button("Trang bị", on_equip, 120)
		button.disabled = not can_equip
		row.add_child(button)
	return card

static func _skin_row(title: String, description: String, worn: bool, owned: bool, color: Color, on_wear: Callable) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	var text: Label = _wrap(UiTheme.label("%s\n%s" % [title, description] if description != "" else title, 15, color if owned else UiTheme.MUTED), 380)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	if worn:
		row.add_child(UiTheme.label("Đang mặc", 15, UiTheme.GOLD, true))
	else:
		var button: Button = UiTheme.button("Mặc", on_wear, 100)
		button.disabled = not owned
		row.add_child(button)
	return row

# ------------------------------------------------------------------ daily missions & login

static func daily(menus: Menus) -> Control:
	var main: Node = menus.main
	var profile: PlayerProfile = main.profile
	var today: String = Missions.today()
	Missions.refresh(profile, today)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.add_child(UiTheme.label("Điểm danh 7 ngày", 20, UiTheme.GOLD, true))
	var calendar: HBoxContainer = HBoxContainer.new()
	calendar.add_theme_constant_override("separation", 8)
	root.add_child(calendar)
	var rewards: Array = ContentDB.get_data("daily").get("login", [])
	var claimable: bool = Missions.can_claim_login(profile, today)
	var next_day: int = Missions.login_day(profile, today) if claimable else int(profile.login.get("streak", 1))
	for day: int in range(1, rewards.size() + 1):
		var reached: bool = day < next_day or (day == next_day and not claimable)
		var card: PanelContainer = _card(UiTheme.GOLD if day == next_day else (UiTheme.JADE if reached else UiTheme.MUTED.darkened(0.4)), Vector2(118, 74))
		var box: VBoxContainer = VBoxContainer.new()
		card.add_child(box)
		box.add_child(UiTheme.label("Ngày %d" % day, 15, UiTheme.GOLD if day == next_day else UiTheme.CREAM, true))
		box.add_child(UiTheme.label("%d Ngọc" % int(rewards[day - 1]), 15, UiTheme.JADE_LIGHT))
		box.add_child(UiTheme.label("✓" if reached else "", 15, UiTheme.JADE_LIGHT))
		calendar.add_child(card)
	var login: Button = UiTheme.button("Điểm danh hôm nay (+%d Ngọc)" % int(rewards[mini(Missions.login_day(profile, today), rewards.size()) - 1]) if claimable else "Đã điểm danh hôm nay", func() -> void:
		if Missions.claim_login(profile, today) > 0:
			main.audio.play("coins")
			main.save_profile()
		menus.refresh_panel(), 340)
	login.disabled = not claimable
	root.add_child(login)
	root.add_child(UiTheme.label("Bỏ lỡ một ngày, chuỗi điểm danh bắt đầu lại từ ngày 1.", 14, UiTheme.MUTED))
	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 8
	root.add_child(spacer)
	root.add_child(UiTheme.label("Nhiệm vụ ngày", 20, UiTheme.GOLD, true))
	root.add_child(UiTheme.label("Nhiệm vụ ngày %s  •  làm mới lúc 0 giờ theo đồng hồ máy" % today, 16, UiTheme.MUTED))
	var missions: Array = profile.daily.get("missions", [])
	for index: int in range(missions.size()):
		var mission: Dictionary = missions[index]
		var done: bool = int(mission["progress"]) >= int(mission["goal"])
		var card: PanelContainer = _card(UiTheme.JADE if done else UiTheme.JADE.darkened(0.5))
		var row: HBoxContainer = HBoxContainer.new()
		card.add_child(row)
		var label: Label = UiTheme.label("%s   (%d/%d)" % [mission["name"], int(mission["progress"]), int(mission["goal"])], 17, UiTheme.CREAM if not mission["claimed"] else UiTheme.MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var claim: Button = UiTheme.button("Đã nhận" if mission["claimed"] else "Nhận +%d Ngọc" % int(mission["reward"]), func() -> void:
			if Missions.claim(profile, index) > 0:
				main.audio.ui("ui_confirm")
				main.save_profile()
			menus.refresh_panel(), 190)
		claim.disabled = mission["claimed"] or not done
		row.add_child(claim)
		root.add_child(card)
	var bonus: Button = UiTheme.button("Hoàn thành tất cả: +%d Ngọc Gió" % int(ContentDB.get_data("daily").get("all_done", 80)), func() -> void:
		if Missions.claim_bonus(profile) > 0:
			main.audio.play("level_up")
			main.save_profile()
		menus.refresh_panel(), 340)
	bonus.disabled = profile.daily.get("bonus_claimed", false) or not Missions.all_claimed(profile)
	root.add_child(bonus)
	return _scroll(root)

# ------------------------------------------------------------------ World Tier

static func tier(menus: Menus) -> Control:
	var main: Node = menus.main
	var state: GameState = main.state
	var cap: int = main.tier_cap()
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	if cap == 0:
		root.add_child(_wrap(UiTheme.label("Cảnh giới thế giới mở sau khi hoàn thành đoạn chơi mẫu: hạ Trúc Tướng và vượt Khe Gió. Cốt truyện không thay đổi.", 16, UiTheme.MUTED), 900))
	else:
		root.add_child(_wrap(UiTheme.label("Ở cảnh giới cao, kẻ địch và Trúc Tướng xuất hiện lại, mạnh hơn và rơi nhiều hơn. Hạ Trúc Tướng ở cảnh giới cao nhất để mở cảnh giới kế tiếp.", 15, UiTheme.MUTED), 900))
	var tiers: Array = ContentDB.get_data("world_tiers").get("tiers", [])
	for data: Dictionary in tiers:
		var index: int = int(data["id"])
		var current: bool = index == state.world_tier
		var locked: bool = index > cap
		var card: PanelContainer = _card(UiTheme.GOLD if current else (UiTheme.MUTED.darkened(0.4) if locked else UiTheme.JADE.darkened(0.3)))
		var row: HBoxContainer = HBoxContainer.new()
		card.add_child(row)
		var text: VBoxContainer = VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		text.add_child(UiTheme.label("%d — %s" % [index, data["name"]], 18, UiTheme.MUTED if locked else UiTheme.CREAM, true))
		var numbers: String = "Khí huyết ×%s  •  Sát thương ×%s  •  Kinh nghiệm, Đồng ×%s  •  Tinh anh %s" % [
			str(data["hp"]).replace(".", ","), str(data["damage"]).replace(".", ","), str(data["xp"]).replace(".", ","), _percent(float(data["elite"]))]
		if int(data.get("ngoc_boss", 0)) > 0:
			numbers += "  •  Trúc Tướng: +%d Ngọc" % int(data["ngoc_boss"])
		text.add_child(UiTheme.label(numbers, 14, UiTheme.JADE_LIGHT))
		text.add_child(_wrap(UiTheme.label(String(data.get("description", "")), 14, UiTheme.MUTED), 700))
		if current:
			row.add_child(UiTheme.label("Đang ở", 15, UiTheme.GOLD, true))
		else:
			var choose: Button = UiTheme.button("Khóa" if locked else "Chọn", func() -> void:
				if main.set_world_tier(index):
					menus.close_panel()
				else:
					menus.refresh_panel(), 120)
			choose.disabled = locked or not main.playing
			row.add_child(choose)
		root.add_child(card)
	return _scroll(root)

# ------------------------------------------------------------------ Endless Trial blessings

static func trial_pick(menus: Menus) -> Control:
	var main: Node = menus.main
	var director: TrialDirector = main.trial
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	root.add_child(UiTheme.title("Đợt %d hoàn thành — chọn một phúc lành" % director.cleared, 28, UiTheme.GOLD))
	root.add_child(UiTheme.label("Tích lũy: %d Ngọc Gió  •  %d Đồng  •  %d kinh nghiệm. Phúc lành mất đi khi rời Ải." % [
		int(director.earned.get("ngoc", 0)), int(director.earned.get("coins", 0)), int(director.earned.get("xp", 0))], 16, UiTheme.MUTED))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(row)
	for buff: Dictionary in menus.trial_choices:
		var card: PanelContainer = _card(UiTheme.JADE_LIGHT, Vector2(320, 220))
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		card.add_child(box)
		box.add_child(UiTheme.title(String(buff["name"]), 26, UiTheme.CREAM))
		box.add_child(_wrap(UiTheme.label(String(buff["desc"]), 16, UiTheme.JADE_LIGHT), 280))
		if buff.has("max"):
			box.add_child(UiTheme.label("Đã có %d/%d" % [int(director.buffs.get(buff["id"], 0)), int(buff["max"])], 14, UiTheme.MUTED))
		var spacer: Control = Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(spacer)
		var chosen: Dictionary = buff
		box.add_child(UiTheme.button("Chọn", func() -> void: main.choose_trial_buff(chosen), 260))
		row.add_child(card)
	return root
