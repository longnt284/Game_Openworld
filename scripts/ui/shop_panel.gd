class_name ShopPanel
extends RefCounted
## Village shop counter over data/shops.json: each offer with what it does, its price and how
## many Lâm An already carries, bought one at a time with Đồng. Built by Menus.open_panel for
## `menus.shop_id`; purchases go through main.buy_item, which refuses and changes nothing
## when the coins fall short.

static func build(menus: Menus) -> Control:
	var main: Node = menus.main
	var state: GameState = main.state
	var shop: Dictionary = Consumables.shop(menus.shop_id)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	var head: HBoxContainer = HBoxContainer.new()
	root.add_child(head)
	var blurb: Label = UiTheme.label(String(shop.get("description", "")), 15, UiTheme.MUTED)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(blurb)
	head.add_child(UiTheme.label("Đồng: %d" % state.coins, 20, UiTheme.GOLD, true))
	if menus.panel_note != "":
		root.add_child(UiTheme.label(menus.panel_note, 15, UiTheme.JADE_LIGHT if menus.panel_note_ok else UiTheme.VERMILION))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for offer: Dictionary in Consumables.offers(menus.shop_id):
		grid.add_child(_offer_card(menus, String(offer["item"]), int(offer["price"])))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(grid)
	root.add_child(scroll)
	root.add_child(UiTheme.label("Đặt thuốc vào ô nhanh (%s) trong Túi đồ để dùng giữa trận." % UserSettings.event_label("use_item"), 14, UiTheme.MUTED))
	return root

static func _offer_card(menus: Menus, item: String, price: int) -> PanelContainer:
	var main: Node = menus.main
	var state: GameState = main.state
	var data: Dictionary = ContentDB.item(item)
	var affordable: bool = state.coins >= price
	var card: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.11, 0.13, 0.95)
	style.border_color = UiTheme.JADE if affordable else UiTheme.JADE.darkened(0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(530, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UiTheme.label("%s   (đang có ×%d)" % [data.get("name", item), state.count(item)], 17, UiTheme.CREAM, true))
	var description: Label = UiTheme.label(String(data.get("description", "")), 14, UiTheme.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = 330
	text.add_child(description)
	var buy: VBoxContainer = VBoxContainer.new()
	buy.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(buy)
	var cost: Label = UiTheme.label("%d Đồng" % price, 16, UiTheme.GOLD if affordable else UiTheme.VERMILION, true)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy.add_child(cost)
	# Kept clickable when short of coins, so the counter says why instead of greying out.
	buy.add_child(UiTheme.button("Mua", func() -> void:
		var refusal: String = main.buy_item(menus.shop_id, item)
		menus.panel_note = refusal if refusal != "" else "Đã mua %s  •  còn %d Đồng" % [data.get("name", item), state.coins]
		menus.panel_note_ok = refusal == ""
		menus.refresh_panel(), 120))
	return card
