class_name EnemyScaler
extends RefCounted
## Strengthens a freshly set-up enemy for a World Tier or an Endless Trial wave, and turns
## it into an elite with affixes from data/elites.json. Works on a private copy of the
## enemy's data: the ContentDB cache is shared by every enemy of the kind.

static func apply(enemy: Enemy, hp: float, damage: float, xp: float = 1.0, coins: float = 1.0) -> void:
	if is_equal_approx(hp, 1.0) and is_equal_approx(damage, 1.0) and is_equal_approx(xp, 1.0) and is_equal_approx(coins, 1.0):
		return
	_own(enemy)
	enemy.max_health *= hp
	enemy.health = enemy.max_health
	enemy.data["damage_scale"] = float(enemy.data.get("damage_scale", 1.0)) * damage
	enemy.data["xp"] = roundi(float(enemy.data.get("xp", 10)) * xp)
	for drop: Array in enemy.data.get("drops", []):
		if drop[0] == "coins":
			drop[1] = roundi(float(drop[1]) * coins)
			drop[2] = roundi(float(drop[2]) * coins)

static func roll_affixes(count: int, rng: RandomNumberGenerator) -> Array:
	var ids: Array = (ContentDB.get_data("elites") as Dictionary).get("affixes", {}).keys()
	var chosen: Array = []
	for index: int in range(mini(count, ids.size())):
		chosen.append(ids.pop_at(rng.randi_range(0, ids.size() - 1)))
	return chosen

static func make_elite(enemy: Enemy, affixes: Array) -> void:
	_own(enemy)
	var table: Dictionary = ContentDB.get_data("elites")
	var base: Dictionary = table.get("base", {})
	var hp: float = float(base.get("hp", 1.5))
	var damage: float = float(base.get("damage", 1.15))
	var speed: float = 1.0
	var names: Array[String] = []
	for id: String in affixes:
		var affix: Dictionary = table["affixes"].get(id, {})
		names.append(String(affix.get("name", id)))
		hp *= float(affix.get("hp", 1.0))
		damage *= float(affix.get("damage", 1.0))
		speed *= float(affix.get("speed", 1.0))
		enemy.max_poise *= float(affix.get("poise", 1.0))
		if affix.has("cooldown"):
			var span: Array = enemy.data.get("cooldown", [1.2, 2.2])
			enemy.data["cooldown"] = [float(span[0]) * float(affix["cooldown"]), float(span[1]) * float(affix["cooldown"])]
		if affix.has("lifesteal"):
			enemy.data["lifesteal"] = float(affix["lifesteal"])
		if affix.has("resist"):
			var resist: Dictionary = {}
			for element: String in (ContentDB.get_data("elements") as Dictionary).get("elements", {}):
				resist[element] = float(affix["resist"])
			enemy.data["resist"] = resist
	enemy.max_health *= hp
	enemy.health = enemy.max_health
	enemy.poise = enemy.max_poise
	enemy.base_speed_scale *= speed
	enemy.data["damage_scale"] = float(enemy.data.get("damage_scale", 1.0)) * damage
	enemy.data["xp"] = roundi(float(enemy.data.get("xp", 10)) * float(base.get("xp", 2.5)))
	for drop: Array in enemy.data.get("drops", []):
		if drop[0] == "coins":
			drop[1] = roundi(float(drop[1]) * float(base.get("coins", 2.0)))
			drop[2] = roundi(float(drop[2]) * float(base.get("coins", 2.0)))
	enemy.data["elite"] = affixes
	enemy.visual.scale *= float(base.get("size", 1.12))
	var color: Color = Color(String(table["affixes"].get(affixes[0], {}).get("color", "ffd36a"))) if not affixes.is_empty() else Color("ffd36a")
	var tag: Label3D = Label3D.new()
	tag.name = "EliteTag"
	tag.text = "Tinh Anh • " + " • ".join(names)
	tag.modulate = color
	tag.outline_modulate = Color(0.05, 0.05, 0.08, 0.9)
	tag.outline_size = 10
	tag.font_size = 44
	tag.pixel_size = 0.006
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.position.y = float(enemy.data.get("height", 1.8)) * float(base.get("size", 1.12)) + 0.45
	enemy.add_child(tag)
	var aura: CPUParticles3D = Vfx.wisps(enemy, color, 14, float(enemy.data.get("radius", 0.5)) + 0.3)
	aura.position.y = 0.6

static func _own(enemy: Enemy) -> void:
	if not enemy.has_meta("own_data"):
		enemy.data = enemy.data.duplicate(true)
		enemy.set_meta("own_data", true)
