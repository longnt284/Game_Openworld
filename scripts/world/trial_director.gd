class_name TrialDirector
extends Node3D
## Ải Vô Tận: an endless wave arena on a mountain pocket beyond the valley walls
## (data/trial.json). Waves grow in size and strength, elites appear from wave 3 and a
## Trúc Tướng guards every fifth wave. Each cleared wave offers a choice of blessings;
## rewards bank per wave and are paid when the run ends (death or leaving). Runs never
## write story flags or camp kills, and the game refuses to save during one.

signal run_finished(summary: Dictionary)

var main: Node
var config: Dictionary = {}
var arena: Arena
var center: Vector3
var active: bool = false
var phase: String = "idle"
var wave: int = 0
var cleared: int = 0
var alive: Array[Enemy] = []
var queue: Array[String] = []
var boss: Enemy
## Blessing id -> stacks taken this run.
var buffs: Dictionary = {}
var earned: Dictionary = {}
var chests: Array[Interactable] = []
var return_point: Vector3
var rest_left: float = 0.0
var serial: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func setup(owner_main: Node) -> void:
	main = owner_main
	process_mode = Node.PROCESS_MODE_PAUSABLE
	config = ContentDB.get_data("trial")
	var spot: Array = config.get("arena", {}).get("pos", [0, 230])
	arena = Arena.new()
	arena.name = "TrialArena"
	add_child(arena)
	arena.setup({"pos": spot, "radius": float(config.get("arena", {}).get("radius", 22))}, main.world.layout)
	arena.set_closed(false)
	center = arena.global_position
	rng.randomize()

func unlocked() -> bool:
	return main.quests.check(config.get("unlock", []))

func start(from: Vector3) -> void:
	if active:
		return
	active = true
	return_point = from
	wave = 0
	cleared = 0
	buffs.clear()
	earned = {"ngoc": 0, "coins": 0, "xp": 0, "kills": 0}
	main.refresh_stats()
	main.player.teleport(center + Vector3(0, 0.6, 9.0))
	main.player.face_direction(Vector3(0, 0, -1), true)
	main.player.heal(main.player.max_health())
	arena.set_closed(true)
	phase = "arming"

func _process(delta: float) -> void:
	if not active:
		return
	match phase:
		"arming":
			if main.world.is_position_ready(center) and main.world.is_position_ready(center + Vector3(16, 0, 16)) and main.world.is_position_ready(center - Vector3(16, 0, 16)):
				_begin_wave(1)
		"fighting":
			alive = alive.filter(func(enemy: Variant) -> bool: return is_instance_valid(enemy) and not (enemy as Enemy).is_dead())
			var cap: int = int(config["waves"].get("max_alive", 5))
			while not queue.is_empty() and alive.size() < cap:
				_spawn(queue.pop_front())
			if queue.is_empty() and alive.is_empty():
				_clear_wave()
		"resting":
			rest_left -= delta
			if rest_left <= 0.0:
				_begin_wave(wave + 1)

func _begin_wave(number: int) -> void:
	wave = number
	var waves: Dictionary = config["waves"]
	var count: int = mini(int(waves.get("max_count", 10)), int(waves.get("base", 3)) + floori(float(waves.get("per_wave", 0.5)) * (number - 1)))
	var boss_wave: bool = number % int(waves.get("boss_every", 5)) == 0
	queue.clear()
	if boss_wave:
		queue.append(String(waves.get("boss", "truc_tuong")))
		count = maxi(1, count / 2)
	for index: int in range(count):
		queue.append(_pick_enemy(number))
	phase = "fighting"
	main.hud.show_banner("Đợt %d" % number, "Thủ lĩnh xuất hiện!" if boss_wave else "Ải Vô Tận")
	main.audio.play("roar" if boss_wave else "danger", null, -4.0)

func _pick_enemy(number: int) -> String:
	var options: Array = (config["waves"].get("pool", []) as Array).filter(func(entry: Dictionary) -> bool: return int(entry.get("from", 1)) <= number)
	var total: float = 0.0
	for entry: Dictionary in options:
		total += float(entry.get("weight", 1))
	var pick: float = rng.randf() * total
	for entry: Dictionary in options:
		pick -= float(entry.get("weight", 1))
		if pick < 0.0:
			return String(entry["enemy"])
	return String(options[0]["enemy"]) if not options.is_empty() else "tan_binh"

func wave_scale(number: int) -> Vector2:
	## (health, damage) multipliers for a wave.
	var scaling: Dictionary = config["waves"].get("scaling", {})
	return Vector2(1.0 + float(scaling.get("hp", 0.12)) * (number - 1), 1.0 + float(scaling.get("damage", 0.06)) * (number - 1))

func _spawn(kind: String) -> Enemy:
	var enemy: Enemy = EnemyFactory.create(ContentDB.enemy(kind))
	serial += 1
	var entity: Dictionary = {"id": "trial_%d" % serial, "enemy": kind, "camp": "trial", "yaw": rng.randf() * 360.0}
	enemy.name = entity["id"]
	add_child(enemy)
	enemy.setup(entity, main.assets, main.world)
	var scale: Vector2 = wave_scale(wave)
	EnemyScaler.apply(enemy, scale.x, scale.y)
	var scaling: Dictionary = config["waves"].get("scaling", {})
	var elite_from: int = int(scaling.get("elite_from", 3))
	var elite_chance: float = minf(float(scaling.get("elite_cap", 0.5)), float(scaling.get("elite", 0.03)) * (wave - elite_from + 1))
	if not enemy.boss and wave >= elite_from and rng.randf() < elite_chance:
		EnemyScaler.make_elite(enemy, EnemyScaler.roll_affixes(mini(3, 1 + wave / int(scaling.get("elite_affixes_every", 7))), rng))
	var angle: float = rng.randf() * TAU
	var spot: Vector3 = center + Vector3(sin(angle), 0, cos(angle)) * (0.0 if enemy.boss else rng.randf_range(9.0, 15.0))
	if enemy.boss:
		spot = center + Vector3(0, 0, -8.0)
	spot.y = main.world.height_at(spot.x, spot.z) + 0.2
	enemy.activate(spot, main.player)
	enemy.home = center
	enemy._set_state("alert")
	enemy.defeated.connect(_on_defeated)
	main.on_enemy_spawned(enemy, {"id": entity["id"]})
	alive.append(enemy)
	if enemy.boss:
		boss = enemy
		main.hud.show_boss(enemy.display_name(), "Thủ lĩnh đợt %d" % wave, 1.0)
		enemy.health_changed.connect(func(target: Enemy, current: float, maximum: float) -> void:
			if active and target == boss:
				main.hud.show_boss(target.display_name(), "Thủ lĩnh đợt %d" % wave, current / maximum))
	return enemy

func _on_defeated(enemy: Enemy) -> void:
	alive.erase(enemy)
	earned["kills"] = int(earned["kills"]) + 1
	main.on_trial_kill(enemy)
	var heal: float = main.state.stat("heal_on_kill")
	if heal > 0.0:
		main.player.heal(main.player.max_health() * heal)
	if enemy == boss:
		boss = null
		main.hud.hide_boss()
	if enemy.data.has("elite") and rng.randf() < float(ContentDB.get_data("elites").get("base", {}).get("chest_chance", 0.2)):
		_drop_chest("elite", enemy.global_position)

func _clear_wave() -> void:
	cleared = wave
	var rewards: Dictionary = config.get("rewards", {})
	earned["ngoc"] = int(earned["ngoc"]) + int(rewards.get("ngoc_per_wave", 8))
	earned["coins"] = int(earned["coins"]) + int(rewards.get("coins_per_wave", 12)) * (1 + wave / 5)
	earned["xp"] = int(earned["xp"]) + int(rewards.get("xp_per_wave", 18)) * wave
	main.on_trial_wave(wave)
	var milestone: String = String(rewards.get("milestones", {}).get(str(wave), ""))
	if milestone != "" and not main.state.swords.has(milestone):
		main.grant_story_sword(milestone, "Phần thưởng vượt đợt %d" % wave)
	if wave % int(rewards.get("chest_every", 5)) == 0:
		_drop_chest("trial", center + Vector3(0, 0, -2.0))
	var choices: Array = pick_choices()
	if choices.is_empty():
		_rest()
		return
	phase = "picking"
	main.open_trial_pick(choices)

func pick_choices() -> Array:
	## Up to `choices` distinct blessings still below their stack limit, weighted.
	var pool: Array = (config["buffs"].get("pool", []) as Array).filter(func(entry: Dictionary) -> bool:
		return int(buffs.get(entry["id"], 0)) < int(entry.get("max", 99)))
	var picks: Array = []
	for index: int in range(mini(int(config["buffs"].get("choices", 3)), pool.size())):
		var total: float = 0.0
		for entry: Dictionary in pool:
			total += float(entry.get("weight", 1))
		var roll: float = rng.randf() * total
		var chosen: Dictionary = pool[-1]
		for entry: Dictionary in pool:
			roll -= float(entry.get("weight", 1))
			if roll < 0.0:
				chosen = entry
				break
		pool.erase(chosen)
		picks.append(chosen)
	return picks

func choose(buff: Dictionary) -> void:
	var id: String = String(buff["id"])
	buffs[id] = int(buffs.get(id, 0)) + 1
	if buff.get("instant", "") == "heal":
		main.player.heal(main.player.max_health())
	main.refresh_stats()
	if phase == "picking":
		_rest()

func _rest() -> void:
	phase = "resting"
	rest_left = float(config["waves"].get("rest", 2.5))

func buff_stats() -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in config.get("buffs", {}).get("pool", []):
		var stacks: int = int(buffs.get(entry["id"], 0))
		if stacks == 0:
			continue
		var values: Dictionary = entry.get("stats", {entry.get("stat", ""): entry.get("value", 0.0)})
		for stat: String in values:
			if stat != "":
				result[stat] = float(result.get(stat, 0.0)) + float(values[stat]) * stacks
	return result

func _drop_chest(table: String, at: Vector3) -> void:
	chests.append(main.spawn_reward_chest(table, at, self))

func end_run(reason: String) -> Dictionary:
	## Pays the banked rewards (and any unopened chest) and returns the player to the gate.
	if not active:
		return {}
	active = false
	phase = "idle"
	queue.clear()
	for enemy: Variant in alive:
		if is_instance_valid(enemy):
			(enemy as Enemy).queue_free()
	alive.clear()
	boss = null
	main.hud.hide_boss()
	var opened: Array = []
	for chest: Variant in chests:
		if is_instance_valid(chest):
			if not (chest as Interactable).opened:
				opened.append(main.open_reward_chest(chest, true))
			(chest as Interactable).queue_free()
	chests.clear()
	arena.set_closed(false)
	var summary: Dictionary = earned.duplicate()
	summary["wave"] = cleared
	summary["chests"] = opened
	summary["reason"] = reason
	buffs.clear()
	main.refresh_stats()
	run_finished.emit(summary)
	return summary
