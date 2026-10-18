class_name StatusEffects
extends RefCounted
## Elemental statuses on one enemy: stacks, timers, damage over time, slows, stuns and
## the extra damage some statuses let other elements deal. Rules live in data/elements.json.

## Shown on the model in this order when several statuses are active.
const PRIORITY: PackedStringArray = ["freeze", "burn", "shock", "chill", "soak", "gale"]

## id -> {"stacks", "time", "tick", "interval", "power"}
var active: Dictionary = {}
## id -> seconds before the status can be applied again
var immune: Dictionary = {}
## 0..1: lowers the chance to apply and shortens durations (bosses).
var resist: float = 0.0
## Bosses never freeze; a full chill stack only slows them.
var no_freeze: bool = false

func apply(id: String, stacks: int, power: float) -> String:
	## Adds stacks of a status. Returns the status that is now active from this call
	## ("freeze" when chill reaches its cap), or "" when nothing was applied.
	var rule: Dictionary = ContentDB.status(id)
	if rule.is_empty() or immune.has(id) or (id == "freeze" and no_freeze):
		return ""
	for removed: String in rule.get("removes", []):
		active.erase(removed)
	var entry: Dictionary = active.get(id, {"stacks": 0, "time": 0.0, "tick": float(rule.get("tick", 0.5)), "interval": 0.0, "power": 0.0})
	var cap: int = int(rule.get("max_stacks", 1))
	entry["stacks"] = mini(cap, int(entry["stacks"]) + maxi(1, stacks))
	entry["time"] = float(rule.get("duration", 2.0)) * (1.0 - resist * 0.5)
	entry["power"] = maxf(float(entry["power"]), power)
	active[id] = entry
	if rule.has("at_max") and int(entry["stacks"]) >= cap and not no_freeze:
		active.erase(id)
		return apply(String(rule["at_max"]), 1, power)
	return id

func tick(delta: float) -> Dictionary:
	## Advances timers. Returns {"dot": damage to deal now, "stun": seconds of stun to start}.
	var result: Dictionary = {"dot": 0.0, "stun": 0.0}
	for id: String in immune.keys():
		immune[id] = float(immune[id]) - delta
		if float(immune[id]) <= 0.0:
			immune.erase(id)
	for id: String in active.keys():
		var entry: Dictionary = active[id]
		var rule: Dictionary = ContentDB.status(id)
		entry["time"] = float(entry["time"]) - delta
		if rule.has("dot"):
			entry["tick"] = float(entry["tick"]) - delta
			if float(entry["tick"]) <= 0.0:
				entry["tick"] = float(entry["tick"]) + float(rule.get("tick", 0.5))
				result["dot"] = float(result["dot"]) + float(rule["dot"]) * float(entry["power"]) * int(entry["stacks"])
		if rule.has("micro_stun"):
			entry["interval"] = float(entry["interval"]) - delta
			if float(entry["interval"]) <= 0.0:
				entry["interval"] = float(rule.get("interval", 1.0))
				result["stun"] = maxf(float(result["stun"]), float(rule["micro_stun"]) * (1.0 - resist))
		if float(entry["time"]) <= 0.0:
			active.erase(id)
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

func dominant() -> String:
	for id: String in PRIORITY:
		if active.has(id):
			return id
	return ""

func clear() -> void:
	active.clear()
	immune.clear()
