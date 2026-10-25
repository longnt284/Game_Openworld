class_name StatusEffects
extends RefCounted
## Statuses on one fighter (an enemy or Lâm An): stacks, timers, damage and healing over
## time, slows, stuns, stat bonuses and the extra damage some statuses let other elements
## deal. Rules live in data/elements.json "statuses"; optional rule fields:
##   kind          "element" (default), "buff" or "debuff": HUD border and resist handling
##   stats         {stat: value per stack} added to the holder's stats while active
##   shed_on_dodge stacks removed by each dodge          blocks_regen  stops "regen_max_hp"
##   dot_max_hp    damage per tick × the holder's max health (passed to tick; enemies pass 0)
##   regen_max_hp  healing per tick × the holder's max health

## Shown on the model in this order when several statuses are active.
const PRIORITY: PackedStringArray = ["freeze", "stun", "mire", "burn", "poison", "bleed", "shock", "chill", "soak", "sunder", "gale", "weaken", "forget", "enemy_rage"]

## id -> {"stacks", "time", "duration", "tick", "interval", "power"}
var active: Dictionary = {}
## id -> seconds before the status can be applied again
var immune: Dictionary = {}
## 0..1: lowers the chance to apply and shortens harmful durations (bosses, player resistance).
var resist: float = 0.0
## Bosses never freeze; a full chill stack only slows them.
var no_freeze: bool = false
## Bumped whenever a status starts, ends or changes stacks, so holders know when to refresh.
var revision: int = 0

static func kind_of(id: String) -> String:
	return String(ContentDB.status(id).get("kind", "element"))

func apply(id: String, stacks: int, power: float, duration: float = 0.0) -> String:
	## Adds stacks of a status. Returns the status that is now active from this call
	## ("freeze" when chill reaches its cap), or "" when nothing was applied. A positive
	## duration replaces the rule's own (a potion's buff lasts as long as the item says).
	var rule: Dictionary = ContentDB.status(id)
	if rule.is_empty() or immune.has(id) or (id == "freeze" and no_freeze):
		return ""
	for removed: String in rule.get("removes", []):
		active.erase(removed)
	var entry: Dictionary = active.get(id, {"stacks": 0, "time": 0.0, "tick": float(rule.get("tick", 0.5)), "interval": 0.0, "power": 0.0})
	var cap: int = int(rule.get("max_stacks", 1))
	entry["stacks"] = mini(cap, int(entry["stacks"]) + maxi(1, stacks))
	# Resistance shortens what hurts; a buff always runs its full course.
	entry["time"] = (duration if duration > 0.0 else float(rule.get("duration", 2.0))) * (1.0 - resist * 0.5 if String(rule.get("kind", "element")) != "buff" else 1.0)
	entry["duration"] = entry["time"]
	entry["power"] = maxf(float(entry["power"]), power)
	active[id] = entry
	revision += 1
	if rule.has("at_max") and int(entry["stacks"]) >= cap and not no_freeze:
		active.erase(id)
		return apply(String(rule["at_max"]), 1, power)
	return id

func tick(delta: float, max_hp: float = 0.0) -> Dictionary:
	## Advances timers. Returns {"dot": damage to deal now, "dot_id": the status dealing most
	## of it, "heal": health to restore now, "stun": seconds of stun to start}.
	var result: Dictionary = {"dot": 0.0, "dot_id": "", "heal": 0.0, "stun": 0.0}
	var strongest: float = 0.0
	var regen: bool = not regen_blocked()
	for id: String in immune.keys():
		immune[id] = float(immune[id]) - delta
		if float(immune[id]) <= 0.0:
			immune.erase(id)
	for id: String in active.keys():
		var entry: Dictionary = active[id]
		var rule: Dictionary = ContentDB.status(id)
		entry["time"] = float(entry["time"]) - delta
		if rule.has("dot") or rule.has("dot_max_hp") or rule.has("regen_max_hp"):
			entry["tick"] = float(entry["tick"]) - delta
			if float(entry["tick"]) <= 0.0:
				entry["tick"] = float(entry["tick"]) + float(rule.get("tick", 0.5))
				var dealt: float = (float(rule.get("dot", 0.0)) * float(entry["power"]) + float(rule.get("dot_max_hp", 0.0)) * max_hp) * int(entry["stacks"])
				result["dot"] = float(result["dot"]) + dealt
				if dealt > strongest:
					strongest = dealt
					result["dot_id"] = id
				if regen:
					result["heal"] = float(result["heal"]) + float(rule.get("regen_max_hp", 0.0)) * max_hp * int(entry["stacks"])
		if rule.has("micro_stun"):
			entry["interval"] = float(entry["interval"]) - delta
			if float(entry["interval"]) <= 0.0:
				entry["interval"] = float(rule.get("interval", 1.0))
				result["stun"] = maxf(float(result["stun"]), float(rule["micro_stun"]) * (1.0 - resist))
		if float(entry["time"]) <= 0.0:
			active.erase(id)
			revision += 1
			if rule.has("immune_after"):
				immune[id] = float(rule["immune_after"])
	return result

func has(id: String) -> bool:
	return active.has(id)

func stacks(id: String) -> int:
	return int(active.get(id, {}).get("stacks", 0))

func speed_mult() -> float:
	var mult: float = 1.0
	for id: String in active:
		mult -= float(ContentDB.status(id).get("slow_per_stack", 0.0)) * int(active[id]["stacks"])
	return clampf(mult, 0.4, 1.0)

func taken_mult(element: String) -> float:
	## Extra damage an element deals to a target carrying these statuses (water conducts thunder).
	var mult: float = 1.0
	if element == "":
		return mult
	for id: String in active:
		mult *= float((ContentDB.status(id).get("taken", {}) as Dictionary).get(element, 1.0))
	return mult

func poise_mult() -> float:
	var mult: float = 1.0
	for id: String in active:
		mult *= float(ContentDB.status(id).get("poise_taken", 1.0))
	return mult

func stun_time(id: String) -> float:
	var rule: Dictionary = ContentDB.status(id)
	return float(rule.get("duration", 1.5)) * (1.0 - resist * 0.5) if rule.get("stun", false) else 0.0

func stat_bonus(key: String) -> float:
	## Sum of one stat over every active status ("stats" value × stacks); 0 when none grants it.
	var total: float = 0.0
	for id: String in active:
		total += float((ContentDB.status(id).get("stats", {}) as Dictionary).get(key, 0.0)) * int(active[id]["stacks"])
	return total

func stat_table() -> Dictionary:
	## Every stat the active statuses change, in the GameState.stats shape.
	var table: Dictionary = {}
	for id: String in active:
		var bonuses: Dictionary = ContentDB.status(id).get("stats", {})
		for key: String in bonuses:
			table[key] = float(table.get(key, 0.0)) + float(bonuses[key]) * int(active[id]["stacks"])
	return table

func regen_blocked() -> bool:
	for id: String in active:
		if ContentDB.status(id).get("blocks_regen", false):
			return true
	return false

func shed(count: int = 1) -> PackedStringArray:
	## A dodge rolls off "shed_on_dodge" stacks of each status that allows it (bleeding).
	## Returns the statuses that lost stacks.
	var shaken: PackedStringArray = []
	for id: String in active.keys():
		var per: int = int(ContentDB.status(id).get("shed_on_dodge", 0)) * count
		if per <= 0:
			continue
		var left: int = stacks(id) - per
		if left <= 0:
			active.erase(id)
		else:
			active[id]["stacks"] = left
		shaken.append(id)
	if not shaken.is_empty():
		revision += 1
	return shaken

func cleanse(ids: Array) -> int:
	## Removes the listed statuses (antidotes, cleansing tea); returns how many were active.
	var removed: int = 0
	for id: Variant in ids:
		if active.erase(String(id)):
			removed += 1
	if removed > 0:
		revision += 1
	return removed

func list_for_hud() -> Array[Dictionary]:
	## Buffs first, then debuffs and elemental statuses, each in the order they started:
	## {"id", "name", "glyph", "color", "time", "duration", "stacks", "kind"}.
	var buffs: Array[Dictionary] = []
	var harmful: Array[Dictionary] = []
	for id: String in active:
		var rule: Dictionary = ContentDB.status(id)
		var entry: Dictionary = active[id]
		var name: String = String(rule.get("name", id))
		var kind: String = String(rule.get("kind", "element"))
		var item: Dictionary = {"id": id, "name": name, "glyph": String(rule.get("glyph", name.left(1))), "color": Color(String(rule.get("color", "ffffff"))),
			"time": maxf(0.0, float(entry["time"])), "duration": float(entry.get("duration", entry["time"])), "stacks": int(entry["stacks"]), "kind": kind}
		if kind == "buff":
			buffs.append(item)
		else:
			harmful.append(item)
	buffs.append_array(harmful)
	return buffs

func dominant() -> String:
	for id: String in PRIORITY:
		if active.has(id):
			return id
	return ""

func clear() -> void:
	if not active.is_empty():
		revision += 1
	active.clear()
	immune.clear()
