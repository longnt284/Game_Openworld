class_name Consumables
extends RefCounted
## Usable items and the village shops over data/items.json and data/shops.json. Data rules
## only: PlayerController applies an effect to Lâm An, main and the menus buy and list offers.
## Item fields: "price" (Đồng, base shop price) and "effect":
##   heal      fraction of max health restored        buff      status id put on Lâm An
##   duration  seconds the buff lasts (the status rule's own when absent)
##   cleanse   [status ids] removed on use
## A shop is {"name", "keeper", "description", "items": [[item id, price or null]]}; null uses
## the item's own price.

static func effect(id: String) -> Dictionary:
	return ContentDB.item(id).get("effect", {})

static func usable(id: String) -> bool:
	return not effect(id).is_empty()

static func heal_items(strongest_first: bool = true) -> Array[String]:
	## Healing items (kind "heal" with an effect "heal"), strongest first (what R reaches for),
	## or in data order for the HUD counter.
	var result: Array[String] = []
	var items: Dictionary = ContentDB.get_data("items")
	for id: String in items:
		if String(items[id].get("kind", "")) != "heal" or float(effect(id).get("heal", 0.0)) <= 0.0:
			continue
		var at: int = result.size()
		if strongest_first:
			# Insertion keeps data order between equal heals, so the pick never flickers.
			while at > 0 and float(effect(result[at - 1]).get("heal", 0.0)) < float(effect(id).get("heal", 0.0)):
				at -= 1
		result.insert(at, id)
	return result

static func best_heal(state: GameState) -> String:
	## The strongest healing item in the bag, or "" when none is left.
	for id: String in heal_items():
		if state.count(id) > 0:
			return id
	return ""

static func shop(id: String) -> Dictionary:
	return (ContentDB.get_data("shops") as Dictionary).get(id, {})

static func offers(shop_id: String) -> Array[Dictionary]:
	## [{"item", "price"}] in shelf order; an unknown item or one without any price is left out.
	var result: Array[Dictionary] = []
	for entry: Array in shop(shop_id).get("items", []):
		var id: String = String(entry[0])
		var price: int = int(entry[1]) if entry.size() > 1 and entry[1] != null else int(ContentDB.item(id).get("price", -1))
		if (ContentDB.get_data("items") as Dictionary).has(id) and price >= 0:
			result.append({"item": id, "price": price})
	return result

static func shop_price(shop_id: String, item: String) -> int:
	## What this shop asks for the item, or -1 when it does not sell it.
	for offer: Dictionary in offers(shop_id):
		if offer["item"] == item:
			return int(offer["price"])
	return -1

static func buy(state: GameState, item: String, price: int) -> bool:
	## Spends Đồng for one item. Refuses, changing nothing, when the coins fall short.
	if price < 0 or state.coins < price:
		return false
	state.remove_item("coins", price)
	state.add_item(item, 1)
	return true
