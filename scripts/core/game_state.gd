class_name GameState
extends RefCounted
## Everything that must survive chunk streaming, death and save/load:
## world flags, quests, inventory, progression and the active checkpoint.

signal changed(kind: String, key: String)

const XP_CURVE: Array[int] = [0, 100, 260, 480, 760, 1100, 1500, 1960, 2480, 3060]
## Stamina before gear, blessings and buffs ("max_stamina" adds flat points).
const BASE_STAMINA: float = 100.0

var flags: Dictionary = {}
var camp_kills: Dictionary = {}
var inventory: Dictionary = {}
var quests: Dictionary = {}
var level: int = 1
var xp: int = 0
var skill_points: int = 0
var skills: Dictionary = GameState.default_skills()
## Equipped sword (base id from data/weapons.json) and every base sword owned in this save.
var sword: String = "sword_old"
var swords: Array = ["sword_old"]
## Armory weapon (PlayerProfile.armory uid) equipped over the base sword, or -1.
var equipped_uid: int = -1
## Secondary sword on the swap key ("" none): a base sword id, with its armory uid or -1.
var sword_alt: String = ""
var alt_uid: int = -1
## Post-story difficulty loop: 0 is the story; higher tiers respawn stronger camps and bosses.
var world_tier: int = 0
var max_tier: int = 0
var coins: int = 0
var health: float = -1.0
var checkpoint_id: String = ""
var checkpoints: Array = []
var discovered: Array = []
var play_time: float = 0.0
## Runtime bonuses from the equipped armory weapon and Endless Trial blessings (PlayerStats);
## never saved, recomputed by main. Empty means neutral: story numbers stay exact.
var stats: Dictionary = {}
## Live bonuses from Lâm An's buffs and debuffs (StatusEffects "stats"), pushed by
## PlayerController whenever they change; never saved. stat() adds them to the table above.
var status_stats: Dictionary = {}
var tracked_quest: String = ""
## Consumable on the quick-use key (C), chosen in the Inventory; kept when the stack runs out.
var quick_item: String = ""

func has_flag(key: String) -> bool:
	return bool(flags.get(key, false))

func set_flag(key: String, value: Variant = true) -> void:
	if flags.get(key) == value:
		return
	flags[key] = value
	changed.emit("flag", key)

func count(item: String) -> int:
	return int(inventory.get(item, 0))

func add_item(item: String, amount: int = 1) -> void:
	if item == "coins":
		coins += amount
		changed.emit("coins", item)
		return
	inventory[item] = count(item) + amount
	if inventory[item] <= 0:
		inventory.erase(item)
	changed.emit("item", item)

func remove_item(item: String, amount: int = 1) -> bool:
	if item == "coins":
		if coins < amount:
			return false
		coins -= amount
		changed.emit("coins", item)
		return true
	if count(item) < amount:
		return false
	add_item(item, -amount)
	return true

func max_health() -> float:
	return 120.0 + (level - 1) * 14.0

func max_stamina() -> float:
	## Never below a quarter of the base, whatever drains it.
	return maxf(BASE_STAMINA * 0.25, BASE_STAMINA + stat("max_stamina"))

static func default_skills() -> Dictionary:
	## Every sword form (data/styles.json) plus khinh công, all unlearned.
	var result: Dictionary = {"khinh_cong": 0}
	for skill: String in StyleBook.all_skill_ids():
		result[skill] = 0
	return result

func attack_power() -> float:
	# Stacked Suy nhược can push the bonus negative; a floor keeps every blow worth something.
	return (float(ContentDB.weapon(sword).get("attack", 10)) + (level - 1) * 1.5) * maxf(0.2, 1.0 + stat("attack_bonus"))

func stat(id: String) -> float:
	return float(stats.get(id, 0.0)) + float(status_stats.get(id, 0.0))

func xp_for_next() -> int:
	return XP_CURVE[mini(level, XP_CURVE.size() - 1)] if level < XP_CURVE.size() else XP_CURVE[-1] + 600 * (level - XP_CURVE.size() + 1)

func add_xp(amount: int) -> int:
	## Returns the number of levels gained.
	xp += amount
	var gained: int = 0
	while xp >= xp_for_next():
		level += 1
		skill_points += 1
		gained += 1
	changed.emit("xp", str(amount))
	return gained

func skill_level(skill: String) -> int:
	return int(skills.get(skill, 0))

func unlock_skill(skill: String) -> void:
	if skill_level(skill) == 0:
		skills[skill] = 1
		changed.emit("skill", skill)

func upgrade_skill(skill: String) -> bool:
	if skill_points <= 0 or skill_level(skill) == 0 or skill_level(skill) >= 3:
		return false
	skill_points -= 1
	skills[skill] = skill_level(skill) + 1
	changed.emit("skill", skill)
	return true

func learn_ultimate(skill: String, requires: String) -> bool:
	## Ultimates are learned with cultivation points once the style's Q form is known.
	if skill_level(skill) > 0 or skill_level(requires) <= 0 or skill_points < StyleBook.ULT_COST:
		return false
	skill_points -= StyleBook.ULT_COST
	skills[skill] = 1
	changed.emit("skill", skill)
	return true

func grant_sword(id: String) -> bool:
	## Adds a base sword; the first sword of an elemental style also teaches its E and Q forms.
	if ContentDB.weapon(id).is_empty():
		return false
	var fresh: bool = not swords.has(id)
	if fresh:
		swords.append(id)
		learn_style(id)
		changed.emit("sword", id)
	return fresh

func learn_style(id: String) -> void:
	## Holding a sword of an elemental style (story or armory) teaches that style's E and Q forms.
	var style: String = StyleBook.style_of(id)
	if style != StyleBook.DEFAULT_STYLE:
		for slot: String in ["e", "q"]:
			unlock_skill(String(StyleBook.form(style, slot).get("skill", "")))

func equip_sword(id: String, uid: int = -1) -> void:
	if not swords.has(id) and uid < 0:
		return
	if sword_alt == id and alt_uid == uid:
		# Drawing the secondary sword as the main one swaps the two.
		sword_alt = sword
		alt_uid = equipped_uid
	sword = id
	equipped_uid = uid
	changed.emit("equip", id)

func has_alt() -> bool:
	return sword_alt != ""

func set_alt(id: String, uid: int = -1) -> bool:
	## Hangs a sword at the hip for the swap key; "" clears it. Never the sword in hand.
	if id == "":
		sword_alt = ""
		alt_uid = -1
		changed.emit("equip", "")
		return true
	if (not swords.has(id) and uid < 0) or (id == sword and uid == equipped_uid):
		return false
	sword_alt = id
	alt_uid = uid
	changed.emit("equip", id)
	return true

func swap_swords() -> bool:
	## The secondary sword to hand and the main one to the hip.
	if not has_alt():
		return false
	var held: String = sword
	var held_uid: int = equipped_uid
	sword = sword_alt
	equipped_uid = alt_uid
	sword_alt = held
	alt_uid = held_uid
	changed.emit("equip", sword)
	return true

func record_camp_kill(entity_id: String) -> void:
	camp_kills[entity_id] = true

func reset_camps() -> void:
	camp_kills.clear()
	changed.emit("camps", "")

func unlock_checkpoint(id: String) -> void:
	if not checkpoints.has(id):
		checkpoints.append(id)
	checkpoint_id = id
	changed.emit("checkpoint", id)

func discover(id: String) -> bool:
	if discovered.has(id):
		return false
	discovered.append(id)
	changed.emit("discover", id)
	return true

func to_dict() -> Dictionary:
	return {
		"flags": flags.duplicate(true), "camp_kills": camp_kills.duplicate(), "inventory": inventory.duplicate(), "quests": quests.duplicate(true),
		"level": level, "xp": xp, "skill_points": skill_points, "skills": skills.duplicate(), "sword": sword, "coins": coins,
		"swords": swords.duplicate(), "equipped_uid": equipped_uid, "sword_alt": sword_alt, "alt_uid": alt_uid, "world_tier": world_tier, "max_tier": max_tier,
		"health": health, "checkpoint_id": checkpoint_id, "checkpoints": checkpoints.duplicate(), "discovered": discovered.duplicate(),
		"play_time": play_time, "tracked_quest": tracked_quest, "quick_item": quick_item,
	}

func from_dict(data: Dictionary) -> void:
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	camp_kills = (data.get("camp_kills", {}) as Dictionary).duplicate()
	inventory = {}
	for item: String in (data.get("inventory", {}) as Dictionary):
		inventory[item] = int(data["inventory"][item])
	quests = (data.get("quests", {}) as Dictionary).duplicate(true)
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	skill_points = int(data.get("skill_points", 0))
	skills = GameState.default_skills()
	for skill: String in (data.get("skills", {}) as Dictionary):
		skills[skill] = int(data["skills"][skill])
	sword = String(data.get("sword", "sword_old"))
	if ContentDB.weapon(sword).is_empty():
		sword = "sword_old"
	swords = []
	for owned: Variant in data.get("swords", ["sword_old"]):
		if owned is String and not ContentDB.weapon(owned).is_empty() and not swords.has(owned):
			swords.append(owned)
	if not swords.has("sword_old"):
		swords.insert(0, "sword_old")
	equipped_uid = int(data.get("equipped_uid", -1))
	if equipped_uid < 0 and not swords.has(sword):
		swords.append(sword)
	# Older saves have no secondary sword; one that is no longer owned is dropped.
	sword_alt = String(data.get("sword_alt", ""))
	alt_uid = int(data.get("alt_uid", -1))
	if ContentDB.weapon(sword_alt).is_empty() or (alt_uid < 0 and not swords.has(sword_alt)) or (sword_alt == sword and alt_uid == equipped_uid):
		sword_alt = ""
		alt_uid = -1
	world_tier = maxi(0, int(data.get("world_tier", 0)))
	max_tier = maxi(world_tier, int(data.get("max_tier", 0)))
	coins = int(data.get("coins", 0))
	health = float(data.get("health", -1.0))
	checkpoint_id = String(data.get("checkpoint_id", ""))
	checkpoints = (data.get("checkpoints", []) as Array).duplicate()
	discovered = (data.get("discovered", []) as Array).duplicate()
	play_time = float(data.get("play_time", 0.0))
	tracked_quest = String(data.get("tracked_quest", ""))
	# Older saves have no quick slot; an item that is no longer usable empties it.
	quick_item = String(data.get("quick_item", ""))
	if not Consumables.usable(quick_item):
		quick_item = ""
	changed.emit("load", "")
