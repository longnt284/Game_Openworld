extends SceneTree
## Elemental sword styles: every form of every style casts, deals damage and applies its
## status; statuses tick (burn), stack into freeze (chill) and respect boss resistance;
## the ultimate needs a full meter; cooldown ratios follow the reduced cooldown. Enemy
## infrastructure: class factory, enemy-cast areas, camp attack slots, tint, wind-up cues
## and damage-over-time numbers. Statuses on Lâm An: poison, bleed, stun, slows, buffs and
## debuffs in GameState.stat, cleanse, revive, enemy blows that land or miss, HUD icons.
## Gear stats: defense, elemental resistance, enemy defense and armor_pen, poise damage,
## lifesteal, attack speed (clip and hit window together), stamina, move speed, item healing.
## Elemental reactions: each of the six fires on its combination only, consumes and applies its
## statuses, splashes other enemies once each without chaining into more reactions, grows with
## reaction_dmg and grants no lifesteal or meter for its splash.
## Poise and finishers: a break opens a broken, finishable window (shorter on bosses); F finishes
## only a broken foe within reach and ahead of any other interaction; the finisher kills an
## ordinary foe, is capped on bosses and leaves Lâm An untouchable; poise bar visibility.
## Tâm Nhãn: a perfect dodge or parry (only in its first instant, not while cooling down) slows
## enemies' clocks, animation, missiles and areas, never Lâm An's; it ends on her time, holds
## while paused and resets on revive and death.

var failures: int = 0
var game: Node3D
var player: PlayerController
var serial: int = 0
const TEST_SAVE: String = "user://combat_test_save.json"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int) -> void:
	for index: int in range(count):
		await physics_frame
		await process_frame

func settle() -> void:
	for index: int in range(4000):
		var world: WorldManager = game.world
		if world.active.size() == game.settings.chunk_capacity() and world.building.is_empty() and world.pending.is_empty():
			break
		await frames(1)
	await frames(4)

func spawn(kind: String, offset: Vector3, hp: float = 5000.0) -> Enemy:
	## A frozen-AI target dummy with the real hurtbox, damage and status rules.
	serial += 1
	var enemy: Enemy = EnemyFactory.create(ContentDB.enemy(kind))
	enemy.setup({"id": "test_dummy_%d" % serial, "enemy": kind, "yaw": 180.0}, game.assets, game.world)
	game.add_child(enemy)
	var point: Vector3 = player.global_position + offset
	point.y = game.world.height_at(point.x, point.z) + 0.05
	enemy.activate(point, player)
	enemy.set_physics_process(false)
	enemy.max_health = hp
	enemy.health = hp
	return enemy

func blow(target: Enemy, element: String, amount: float = 100.0, extra: Dictionary = {}) -> Combat.Damage:
	## A still, unstaggering test blow of one element (or plain steel for "").
	var data: Dictionary = {"poise": 0, "knockback": 0.0, "hitstop": 0.0, "element": element}
	data.merge(extra, true)
	return Combat.make_damage(player, data, amount, target.global_position)

func watch(enemies: Array) -> Dictionary:
	## Counts reaction_hit signals per enemy id, splash hits included.
	var counts: Dictionary = {}
	for enemy: Enemy in enemies:
		enemy.reaction_hit.connect(func(target: Enemy, _reaction: String, _amount: float, _splash: bool) -> void:
			counts[target.entity_id] = int(counts.get(target.entity_id, 0)) + 1)
	return counts

func clear_dummies() -> void:
	for node: Node in get_nodes_in_group("enemy"):
		node.queue_free()
	await frames(2)

func reset_player() -> void:
	player.revive(player.global_position)
	player.invulnerable = 0.0
	player.cooldowns.clear()
	player.cooldown_max.clear()
	player.face_direction(Vector3(0, 0, -1), true)
	await frames(2)

func cast(slot: String) -> void:
	player._try_skill(slot)
	for index: int in range(240):
		if player.state != "action":
			break
		await frames(1)

func _run() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	game.skip_title = true
	game.save_path = TEST_SAVE
	game.profile_path = "user://combat_test_profile.json"
	root.add_child(game)
	for attempt: int in range(900):
		if game.initialized:
			break
		await frames(1)
	if not game.initialized:
		check(false, "Game initializes")
		quit(1)
		return
	player = game.player
	# Quiet arena: no streamed NPCs, camps or quest triggers around the dummies.
	game.spawner.clear_all()
	game.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	player.teleport(Vector3(-20, game.world.height_at(-20, 64) + 0.3, 64))
	await settle()
	var state: GameState = game.state

	# ---- data integrity
	var styles: Array = StyleBook.styles()
	check(styles.size() == 5, "Five sword styles are defined")
	var forms_ok: bool = true
	for style: String in styles:
		for slot: String in StyleBook.SLOTS:
			var form: Dictionary = StyleBook.form(style, slot)
			var data: Dictionary = Combat.attack("player", String(form.get("attack", "")))
			var clip: String = String(data.get("clip", form.get("attack", "")))
			if not data.has("mult") or not (player.visual.has_animation(clip) or player.visual.has_animation(String(data.get("fallback_clip", "")))):
				forms_ok = false
				push_error("Form %s/%s has no attack data or playable clip" % [style, slot])
	check(forms_ok, "Every form has attack data and a playable clip")
	var weapons_ok: bool = true
	for sword: String in ContentDB.get_data("weapons"):
		if StyleBook.style_of(sword) != String(ContentDB.weapon(sword).get("style", "")):
			weapons_ok = false
	check(weapons_ok, "Every sword names an existing style")

	# ---- enemy infrastructure: one factory, wind-up cues from data
	var factory_ok: bool = true
	for kind: String in ContentDB.get_data("enemies"):
		var enemy_data: Dictionary = ContentDB.enemy(kind)
		var made: Enemy = EnemyFactory.create(enemy_data)
		if made == null or (enemy_data.has("class") and not EnemyFactory.CLASSES.has(String(enemy_data["class"]))):
			factory_ok = false
			push_error("Enemy %s has no registered class" % kind)
		if made:
			made.free()
	var made_boar: Enemy = EnemyFactory.create(ContentDB.enemy("heo_gio"))
	var made_guardian: Enemy = EnemyFactory.create(ContentDB.enemy("truc_tuong"))
	var made_plain: Enemy = EnemyFactory.create(ContentDB.enemy("tan_binh"))
	check(factory_ok and made_boar is Boar and made_guardian is Guardian and made_plain.get_script() == Enemy, "The enemy factory builds every enemies.json entry as its class")
	for made: Enemy in [made_boar, made_guardian, made_plain]:
		made.free()
	var cues_ok: bool = true
	var attacks: Dictionary = ContentDB.get_data("attacks")
	for owner: String in attacks:
		if owner == "player":
			continue
		for attack: String in attacks[owner]:
			var cue: String = String(Combat.attack(owner, attack).get("start_sfx", ""))
			if cue == "" or game.audio._pick(cue) == null:
				cues_ok = false
				push_error("Enemy attack %s/%s has no playable start_sfx" % [owner, attack])
	check(cues_ok and Combat.attack("guardian", "slam")["start_sfx"] == "danger" and Combat.attack("boar", "charge")["start_sfx"] == "boar_grunt", "Every enemy attack names a playable wind-up sound")

	# ---- enemy-cast areas hit the player hurtbox only, and end with their caster
	await reset_player()
	var caster: Enemy = spawn("tan_binh", Vector3(0, 0, -8))
	var bystander: Enemy = spawn("tan_binh", Vector3(1.0, 0, 0.5))
	await frames(2)
	var health_before: float = player.health
	var blast: AreaEffect = AreaEffect.spawn(caster, {"damage": 12, "poise": 0, "knockback": 0.0, "hitstop": 0.0}, 1.5, "nova", Vfx.DANGER, Combat.LAYER_HURT_PLAYER)
	blast.events.append({"time": 0.0, "position": player.global_position, "radius": 3.0})
	await frames(3)
	var expected_hurt: float = 12.0 * 1.5 * maxf(0.2, 1.0 + state.stat("damage_taken"))
	check(is_equal_approx(health_before - player.health, expected_hurt) and is_equal_approx(bystander.health, bystander.max_health) and is_equal_approx(caster.health, caster.max_health),
		"An enemy-cast nova hurts the player (%.1f) but not enemies beside them" % (health_before - player.health))
	check(not is_instance_valid(blast), "A spent nova frees itself")
	var lingering: AreaEffect = AreaEffect.spawn(caster, {"damage": 5, "tick": 0.2, "flinch": false}, 1.0, "field", Vfx.DANGER, Combat.LAYER_HURT_PLAYER)
	lingering.start_field(player.global_position, 3.0, 5.0)
	caster.state = "dead"
	await frames(2)
	check(not is_instance_valid(lingering), "A slain enemy's field stops hurting the winner")
	caster.state = "idle"

	# ---- camp attack slots follow max_attackers; bosses ignore them
	var first: Enemy = spawn("tan_binh", Vector3(3, 0, -6))
	var second: Enemy = spawn("tan_binh", Vector3(-3, 0, -6))
	var slot_boss: Enemy = spawn("truc_tuong", Vector3(0, 0, -12))
	await frames(1)
	check(first.max_attackers() == 2 and int(ContentDB.enemy("tan_binh").get("max_attackers", Enemy.MAX_ATTACKERS)) == 2, "Common enemies keep two attack slots per camp")
	for enemy: Enemy in [first, second, slot_boss]:
		enemy.data = enemy.data.duplicate(true)
		enemy.data["max_attackers"] = 1
		enemy.camp = "test_slots"
	var first_slot: bool = first._take_token()
	first.state = "attack"
	var second_slot: bool = second._take_token()
	var boss_slot: bool = slot_boss._take_token()
	second.data["max_attackers"] = 2
	var wider_slot: bool = second._take_token()
	check(first_slot and not second_slot and boss_slot and wider_slot, "A camp with max_attackers 1 grants one attack slot; a boss swings regardless")
	check(int(ContentDB.enemy("tan_binh").get("max_attackers", 0)) == 2, "Slot overrides stay off the shared enemy data")
	first.state = "idle"
	second.state = "idle"
	Enemy.tokens.erase("test_slots")

	# ---- data "tint" recolours the model's palette
	var palette: String = ""
	for mesh: MeshInstance3D in first.visual.meshes:
		for surface: int in range(mesh.mesh.get_surface_count() if mesh.mesh else 0):
			var material: Material = mesh.mesh.surface_get_material(surface)
			if palette == "" and material is ShaderMaterial and material.resource_name != "":
				palette = material.resource_name
	var enemy_table: Dictionary = ContentDB.get_data("enemies")
	var tinted_data: Dictionary = (enemy_table["tan_binh"] as Dictionary).duplicate(true)
	tinted_data["tint"] = {palette: "ff2020"}
	enemy_table["test_tinted"] = tinted_data
	var tinted: Enemy = spawn("test_tinted", Vector3(0, 0, -10))
	enemy_table.erase("test_tinted")
	var recoloured: bool = false
	for mesh: MeshInstance3D in tinted.visual.meshes:
		for surface: int in range(mesh.mesh.get_surface_count() if mesh.mesh else 0):
			var override: ShaderMaterial = mesh.get_surface_override_material(surface) as ShaderMaterial
			if override == null:
				continue
			var albedo: Color = override.get_shader_parameter("albedo")
			if albedo.is_equal_approx(Color("ff2020")):
				recoloured = true
	check(palette != "" and recoloured, "Enemy data 'tint' recolours its palette material (%s)" % palette)

	# ---- damage over time floats a number like other hits, unless numbers are off
	var burning: Enemy = spawn("tan_binh", Vector3(2, 0, -6))
	game.on_enemy_spawned(burning, {"id": burning.entity_id})
	var count_labels: Callable = func() -> int: return game.get_children().filter(func(node: Node) -> bool: return node is Label3D).size()
	burning.statuses.apply("burn", 1, 20.0)
	var labels_before: int = count_labels.call()
	burning._tick_statuses(0.6)
	var labels_shown: int = count_labels.call()
	game.user_settings.damage_numbers = false
	burning._tick_statuses(0.6)
	var labels_hidden: int = count_labels.call()
	game.user_settings.damage_numbers = true
	check(labels_shown == labels_before + 1 and labels_hidden == labels_shown and burning.health < burning.max_health, "Burn ticks show a damage number and respect the damage-numbers setting")
	await clear_dummies()

	# ---- statuses on a plain target
	await reset_player()
	var dummy: Enemy = spawn("tan_binh", Vector3(0, 0, -6))
	await frames(2)
	dummy.statuses.apply("burn", 1, 20.0)
	var before: float = dummy.health
	dummy._tick_statuses(0.6)
	check(is_equal_approx(before - dummy.health, 0.12 * 20.0) and dummy.state == "idle", "Burn deals quiet damage over time without a flinch")
	var chill: Combat.Damage = Combat.make_damage(player, {"poise": 0, "knockback": 0.0, "element": "frost", "status": {"id": "chill", "stacks": 3, "chance": 1.0}}, 1.0, dummy.global_position)
	dummy.take_damage(chill)
	check(dummy.statuses.has("freeze") and dummy.state == "stagger", "Three chill stacks freeze a common enemy")
	dummy.statuses.clear()
	dummy.statuses.apply("soak", 1, 10.0)
	check(dummy.statuses.taken_mult("thunder") > 1.2 and is_equal_approx(dummy.statuses.taken_mult(""), 1.0), "Soaked targets take extra thunder damage only")
	dummy.statuses.clear()
	dummy.statuses.apply("chill", 2, 10.0)
	dummy._tick_statuses(0.01)
	check(dummy.speed_scale < 0.8, "Chill slows the enemy")
	var boss: Enemy = spawn("truc_tuong", Vector3(5, 0, -6))
	await frames(2)
	boss.take_damage(Combat.make_damage(player, {"poise": 0, "knockback": 0.0, "element": "frost", "status": {"id": "chill", "stacks": 3, "chance": 1.0}}, 1.0, boss.global_position))
	check(not boss.statuses.has("freeze") and boss.statuses.has("chill"), "The miniboss cannot be frozen")
	await clear_dummies()

	# ---- the ultimate needs a full meter; cooldown ratios follow the reduced cooldown
	await reset_player()
	state.sword = "sword_wind"
	for skill: String in ["gust", "cyclone", "phong_x"]:
		state.skills[skill] = 1
	player.set_meter(50.0)
	player._try_skill("x")
	check(player.state != "action" and is_equal_approx(player.meter, 50.0), "Ultimate is refused below a full meter")
	await reset_player()
	player.set_meter(PlayerController.METER_MAX)
	player._try_skill("x")
	check(player.current_action() == "ult_phong" and is_zero_approx(player.meter), "Ultimate spends the full meter")
	await cast("")
	await frames(60)
	await reset_player()
	state.skills["gust"] = 2
	player._try_skill("e")
	check(is_equal_approx(player.cooldown_ratio("gust"), 1.0) and player.cooldown_max["gust"] < 6.0, "Cooldown ratio uses the level-reduced cooldown")
	await cast("")
	state.skills["gust"] = 1
	await frames(30)

	# ---- missile forms keep their clip at normal playback; missile_speed only moves the missile
	for form: Array in [["ult_thuy", "ultimate"], ["bang_e", "skill_gust"]]:
		var timed: Dictionary = Combat.attack("player", String(form[0]))
		check(is_equal_approx(float(timed["recover"]), float(ContentDB.timing("player", String(form[1]))["recover"])) and float(timed.get("missile_speed", 0.0)) > 1.0,
			"%s plays its %s clip at normal speed (recover %.2f s)" % [form[0], form[1], float(timed["recover"])])

	# ---- Phong Trảm keeps its numbers with a plain story sword
	await reset_player()
	state.sword = "sword_bamboo"
	var target: Enemy = spawn("tan_binh", Vector3(0, 0, -5))
	await frames(3)
	before = target.health
	player._try_skill("e")
	await cast("")
	await frames(30)
	check(is_equal_approx(before - target.health, state.attack_power() * 1.6), "Phong Trảm with a story sword deals attack × 1.6 (%.1f)" % (before - target.health))
	await clear_dummies()

	# ---- every form of every style lands and applies its status
	for style: String in styles:
		var sword: String = ""
		for candidate: String in ContentDB.get_data("weapons"):
			if String(ContentDB.weapon(candidate).get("style", "")) == style and String(ContentDB.weapon(candidate).get("element", "")) != "":
				sword = candidate
				break
		state.sword = sword
		for slot: String in StyleBook.SLOTS:
			state.skills[String(StyleBook.form(style, slot)["skill"])] = 1
		for slot: String in StyleBook.SLOTS:
			await reset_player()
			var targets: Array[Enemy] = [spawn("tan_binh", Vector3(0, 0, -3.5)), spawn("tan_binh", Vector3(1.6, 0, -5)), spawn("tan_binh", Vector3(-1.6, 0, -5))]
			await frames(3)
			player.set_meter(PlayerController.METER_MAX)
			var form: Dictionary = StyleBook.form(style, slot)
			var data: Dictionary = Combat.attack("player", String(form["attack"]))
			player._try_skill(slot)
			check(player.current_action() == String(form["attack"]), "%s %s starts" % [style, form["name"]])
			await cast("")
			await frames(250 if String(data.get("kind", "")) == "field" else 60)
			var dealt: float = 0.0
			var with_status: int = 0
			var status: String = String((data.get("status", {}) as Dictionary).get("id", ""))
			for enemy: Enemy in targets:
				dealt += enemy.max_health - enemy.health
				if enemy.statuses.has(status) or (status == "chill" and enemy.statuses.has("freeze")):
					with_status += 1
			check(dealt > 0.0, "%s %s damages enemies (%.0f)" % [style, form["name"], dealt])
			if float((data.get("status", {}) as Dictionary).get("chance", 0.0)) >= 1.0:
				check(with_status > 0, "%s %s applies %s" % [style, form["name"], status])
			await clear_dummies()

	# ---- statuses on Lâm An: data, damage and healing over time, dodge shedding, stun
	var hud_ok: bool = true
	for id: String in (ContentDB.get_data("elements") as Dictionary)["statuses"]:
		var rule: Dictionary = ContentDB.status(id)
		var glyph: String = String(rule.get("glyph", ""))
		if String(rule.get("name", "")) == "" or glyph.length() < 1 or glyph.length() > 2 or not rule.has("color") or not (String(rule.get("kind", "element")) in ["element", "buff", "debuff"]):
			hud_ok = false
			push_error("Status %s lacks a name, a 1-2 letter glyph, a colour or a known kind" % id)
	check(hud_ok, "Every status has a Vietnamese name, a short glyph, a colour and a kind")
	await reset_player()
	var max_hp: float = player.max_health()
	player.health = max_hp * 0.5
	player.apply_status("buff_regen")
	player.apply_status("poison")
	var hp_before: float = player.health
	player._tick_statuses(0.6)
	check(is_equal_approx(hp_before - player.health, max_hp * float(ContentDB.status("poison")["dot_max_hp"])) and player.state == "move",
		"Poison drains %.1f a tick without a flinch, and Hồi xuân cannot heal through it" % (hp_before - player.health))
	player.cleanse(["poison"])
	hp_before = player.health
	player._tick_statuses(0.5)
	check(not player.statuses.has("poison") and is_equal_approx(player.health - hp_before, max_hp * float(ContentDB.status("buff_regen")["regen_max_hp"])), "Once the poison is gone, Hồi xuân heals over time")
	await reset_player()
	player.apply_status("poison")
	player.input_enabled = false
	hp_before = player.health
	var poison_left: float = float(player.statuses.active["poison"]["time"])
	await frames(40)
	check(is_equal_approx(player.health, hp_before) and is_equal_approx(float(player.statuses.active["poison"]["time"]), poison_left), "Poison holds still while a conversation locks input")
	player.input_enabled = true
	await reset_player()
	player.apply_status("bleed", 3)
	hp_before = player.health
	player._tick_statuses(0.6)
	check(is_equal_approx(hp_before - player.health, max_hp * float(ContentDB.status("bleed")["dot_max_hp"]) * 3.0), "Bleeding drains by stack")
	player._start_dodge()
	check(player.state == "dodge" and player.statuses.stacks("bleed") == 2, "A dodge sheds one bleed stack")
	await frames(40)
	await reset_player()
	var stun_time: float = float(ContentDB.status("stun")["duration"])
	player.apply_status("stun")
	check(player.state == "hit" and is_equal_approx(player.hit_time, stun_time), "Choáng holds Lâm An in the hit state for %.1f s" % stun_time)
	await frames(roundi(stun_time * 60.0) + 20)
	check(player.state == "move" and not player.statuses.has("stun"), "Lâm An acts again once the stun wears off")
	player.apply_status("chill", 2)
	var slowed: float = player.move_speed_scale()
	player.cleanse(["chill"])
	player.apply_status("buff_speed")
	check(slowed < 1.0 and player.move_speed_scale() > 1.0, "Chill slows Lâm An and Khinh thân quickens her")

	# ---- buffs and debuffs reach GameState.stat: attack power, cooldowns; cleanse and revive
	await reset_player()
	state.sword = "sword_wind"
	state.skills["gust"] = 1
	var gear_attack: float = float(state.stats.get("attack_bonus", 0.0))
	var base_attack: float = state.attack_power()
	var atk_bonus: float = float(ContentDB.status("buff_atk")["stats"]["attack_bonus"])
	player.apply_status("buff_atk")
	check(is_equal_approx(state.attack_power(), base_attack / (1.0 + gear_attack) * (1.0 + gear_attack + atk_bonus)) and is_equal_approx(state.stat("attack_bonus"), gear_attack + atk_bonus),
		"Cường lực raises attack power (%.1f → %.1f)" % [base_attack, state.attack_power()])
	player._tick_statuses(float(ContentDB.status("buff_atk")["duration"]) + 0.1)
	check(not player.statuses.has("buff_atk") and is_equal_approx(state.attack_power(), base_attack) and state.status_stats.is_empty(), "Cường lực expires and attack power returns to %.1f" % base_attack)
	player.apply_status("weaken", 2)
	check(state.attack_power() < base_attack, "Suy nhược lowers attack power")
	player.cleanse(["weaken"])
	player.apply_status("forget")
	player._try_skill("e")
	var gust_form: Dictionary = StyleBook.form(player.style_id(), "e")
	var forgotten: float = float(gust_form["cooldown"]) * maxf(0.4, 1.0 - float(state.stats.get("skill_cd", 0.0)) - float(ContentDB.status("forget")["stats"]["skill_cd"]))
	check(player.current_action() == String(gust_form["attack"]) and is_equal_approx(float(player.cooldown_max.get("gust", 0.0)), forgotten), "Lãng quên lengthens the cooldown to %.1f s" % forgotten)
	await cast("")
	await frames(30)
	await reset_player()
	player.apply_status("poison")
	player.apply_status("bleed", 2)
	player.apply_status("buff_def")
	var removed: int = player.cleanse(["poison", "bleed", "stun"])
	check(removed == 2 and player.statuses.active.keys() == ["buff_def"] and state.stat("damage_taken") < 0.0, "Cleansing removes only the listed statuses")
	player.apply_status("weaken")
	player.revive(player.global_position)
	check(player.statuses.active.is_empty() and state.status_stats.is_empty() and is_equal_approx(state.attack_power(), base_attack), "Waking at a shrine clears every buff and debuff")

	# ---- enemy blows carry their status onto Lâm An only when they land
	await reset_player()
	var striker: Enemy = spawn("tan_binh", Vector3(0, 0, -2))
	await frames(2)
	var bleed_hit: Dictionary = {"poise": 0, "knockback": 0.0, "hitstop": 0.0, "status": {"id": "bleed", "chance": 1.0}}
	var clean: Dictionary = player.take_damage(Combat.make_damage(striker, bleed_hit, 4.0, player.global_position))
	check(clean.get("hit", false) and String(clean.get("status", "")) == "bleed" and player.statuses.has("bleed"), "An enemy blow carrying bleed makes Lâm An bleed on a clean hit")
	await reset_player()
	player._start_dodge()
	var dodged: Dictionary = player.take_damage(Combat.make_damage(striker, bleed_hit, 4.0, player.global_position))
	check(not dodged.get("hit", true) and not player.statuses.has("bleed"), "A dodged blow carries no status")
	await frames(40)
	await reset_player()
	player.face_direction(striker.global_position - player.global_position, true)
	player._start_action("parry")
	var parried: Dictionary = player.take_damage(Combat.make_damage(striker, bleed_hit, 4.0, player.global_position))
	check(parried.get("parried", false) and not player.statuses.has("bleed"), "A parried blow carries no status")
	await frames(40)
	await reset_player()
	seed(1337)
	var guarded_hits: int = 0
	for index: int in range(400):
		if player._roll_status(Combat.make_damage(striker, bleed_hit, 0.0, player.global_position), 0.5) != "":
			guarded_hits += 1
		player.statuses.clear()
	check(guarded_hits > 160 and guarded_hits < 240, "Guarded blows make their status stick at half the chance (%d/400)" % guarded_hits)
	var sure_bleed: Dictionary = bleed_hit.duplicate(true)
	sure_bleed["status"]["chance"] = 2.0
	player.block_held = true
	var blocked: Dictionary = player.take_damage(Combat.make_damage(striker, sure_bleed, 4.0, player.global_position))
	player.block_held = false
	check(blocked.get("blocked", false) and String(blocked.get("status", "")) == "bleed", "A blocked blow still rolls its status")
	await reset_player()
	var stun_hit: Dictionary = {"poise": 0, "knockback": 0.0, "hitstop": 0.0, "status": {"id": "stun", "chance": 1.0}}
	var stunned: Dictionary = player.take_damage(Combat.make_damage(striker, stun_hit, 2.0, player.global_position))
	check(String(stunned.get("status", "")) == "stun" and player.state == "hit" and is_equal_approx(player.hit_time, stun_time), "An enemy blow carrying Choáng stuns Lâm An for its full duration")
	striker.statuses.apply("enemy_rage", 1, 0.0)
	striker._tick_statuses(0.01)
	check(striker.speed_scale > 1.0 and striker.shown_status == "enemy_rage", "Cuồng nộ quickens an enemy and tints it")
	await clear_dummies()

	# ---- HUD: one icon per status, buffs first and bordered apart from debuffs
	await reset_player()
	player.apply_status("buff_atk")
	player.apply_status("poison", 2)
	player.apply_status("bleed")
	game._refresh_hud()
	var icons: Array[Dictionary] = game.hud.status_icons
	check(game.hud.status_icon_count() == player.statuses.active.size() and game.hud.status_icon_count() == 3 and (icons[0]["glyph"] as Label).text == String(ContentDB.status("buff_atk")["glyph"])
		and (icons[0]["style"] as StyleBoxFlat).border_color != (icons[1]["style"] as StyleBoxFlat).border_color and (icons[1]["stacks"] as Label).text == "×2",
		"The HUD shows one icon per status, buffs first and bordered apart (%d icons)" % game.hud.status_icon_count())
	player.cleanse(["poison", "bleed", "buff_atk"])
	game._refresh_hud()
	check(game.hud.status_icon_count() == 0, "Cleansed statuses leave the HUD")

	# ---- gear stats: defense and elemental resistance on Lâm An, enemy defense and armor_pen,
	# poise damage, lifesteal, attack speed, stamina, move speed and item healing
	var kept_stats: Dictionary = state.stats
	var kept_sword: String = state.sword
	state.sword = "sword_old"
	await reset_player()
	var brute: Enemy = spawn("tan_binh", Vector3(0, 0, -2))
	await frames(2)
	var steel_blow: Dictionary = {"poise": 0, "knockback": 0.0, "hitstop": 0.0}
	var frost_blow: Dictionary = {"poise": 0, "knockback": 0.0, "hitstop": 0.0, "element": "frost"}
	var losses: Array[float] = []
	for trial_case: Array in [[{}, steel_blow], [{"defense": 100.0}, steel_blow], [{"res_frost": 0.5}, frost_blow], [{"res_frost": 0.5}, steel_blow]]:
		await reset_player()
		state.stats = trial_case[0]
		var hp_start: float = player.health
		player.take_damage(Combat.make_damage(brute, trial_case[1], 20.0, player.global_position))
		losses.append(hp_start - player.health)
	check(is_equal_approx(losses[0], 20.0) and is_equal_approx(losses[1], 10.0), "100 defense halves a blow (%.1f → %.1f)" % [losses[0], losses[1]])
	check(is_equal_approx(losses[2], 10.0) and is_equal_approx(losses[3], 20.0), "Frost resistance halves frost blows only (frost %.1f, steel %.1f)" % [losses[2], losses[3]])
	await reset_player()
	state.stats = {}
	brute.data = brute.data.duplicate(true)
	brute.data["defense"] = 100.0
	var pierced: Array[float] = []
	for pen: float in [0.0, 60.0, 150.0]:
		var probe: Combat.Damage = Combat.make_damage(player, {"poise": 0, "knockback": 0.0, "hitstop": 0.0, "flinch": false}, 50.0, brute.global_position)
		probe.armor_pen = pen
		var brute_start: float = brute.health
		brute.take_damage(probe)
		pierced.append(brute_start - brute.health)
	check(is_equal_approx(pierced[0], 25.0) and is_equal_approx(pierced[1], 50.0 * 100.0 / 140.0) and is_equal_approx(pierced[2], 50.0),
		"Enemy defense 100 halves a blow; armor_pen 60 leaves 40 of it, 150 ignores it all (%.1f, %.1f, %.1f)" % [pierced[0], pierced[1], pierced[2]])
	state.stats = {"armor_pen": 40.0}
	player.counter_bonus = 0.0
	var through: Dictionary = player.strike(brute, {"mult": 1.0, "poise": 0, "knockback": 0.0, "hitstop": 0.0}, 1.0)
	check(is_equal_approx(float(through.get("amount", 0.0)), state.attack_power() * 100.0 / 160.0), "Lâm An's armor_pen rides on her strikes (%.1f)" % float(through.get("amount", 0.0)))
	state.stats = {"poise_dmg": 0.5}
	brute.poise = brute.max_poise
	player.strike(brute, {"mult": 0.1, "poise": 10, "knockback": 0.0, "hitstop": 0.0}, 1.0)
	check(is_equal_approx(brute.max_poise - brute.poise, 15.0), "poise_dmg +50%% makes a 10-poise blow break 15 (%.1f)" % (brute.max_poise - brute.poise))
	state.stats = {"lifesteal": 0.5}
	player.health = player.max_health() * 0.5
	var hp_mark: float = player.health
	var drink: Dictionary = player.strike(brute, {"mult": 1.0, "poise": 0, "knockback": 0.0, "hitstop": 0.0}, 1.0)
	var drank: float = player.health - hp_mark
	brute.statuses.apply("burn", 2, 30.0)
	hp_mark = player.health
	var brute_burning: float = brute.health
	brute._tick_statuses(0.6)
	check(drank > 0.0 and is_equal_approx(drank, float(drink.get("amount", 0.0)) * 0.5) and brute.health < brute_burning and is_equal_approx(player.health, hp_mark),
		"Lifesteal heals half of what a blow dealt (%.1f) and nothing from the burn it left" % drank)
	await clear_dummies()
	# Attack speed: the clip and its hit window run faster together, and the blow still lands.
	state.stats = {"attack_speed": 0.25}
	await reset_player()
	player._start_action("attack_3")
	var quick_data: Dictionary = player.action["data"]
	var base_data: Dictionary = Combat.attack("player", "attack_3")
	check(is_equal_approx(float(quick_data["hit_start"]), float(base_data["hit_start"]) / 1.25) and is_equal_approx(float(quick_data["length"]), float(base_data["length"]) / 1.25)
		and is_equal_approx(player.visual.base_speed, 1.25) and is_equal_approx(player.visual.action_length, player.visual.animation_length("attack_3") / 1.25),
		"Attack speed +25% plays attack_3 1.25× faster with its hit window scaled alike")
	await frames(70)
	var swing_frames: Array[int] = []
	var hit_frames: Array[int] = []
	for quick: float in [0.0, 0.25]:
		state.stats = {"attack_speed": quick} if quick > 0.0 else {}
		await reset_player()
		var swing_target: Enemy = spawn("tan_binh", Vector3(0, 0, -1.8))
		await frames(2)
		player._start_action("attack_3")
		var landed: int = -1
		var count: int = 0
		while player.state == "action" and count < 240:
			await frames(1)
			count += 1
			if landed < 0 and swing_target.health < swing_target.max_health:
				landed = count
		swing_frames.append(count)
		hit_frames.append(landed)
		await clear_dummies()
	check(hit_frames[0] > 0 and hit_frames[1] > 0 and hit_frames[1] < hit_frames[0] and swing_frames[1] < swing_frames[0] and absf(swing_frames[1] - swing_frames[0] / 1.25) <= 4.0,
		"A quicker attack_3 still lands, sooner (frame %d vs %d) and ends sooner (%d vs %d frames)" % [hit_frames[1], hit_frames[0], swing_frames[1], swing_frames[0]])
	# Stamina: a flat bonus over the base 100 that shrinks back, and quicker recovery.
	await reset_player()
	state.stats = {"max_stamina": 50.0}
	player.set_stamina(999.0)
	var topped: float = player.stamina
	game._refresh_vitals()
	var bar_max: float = game.hud.stamina_bar.max_value
	state.stats = {}
	player._tick_timers(0.01)
	check(is_equal_approx(topped, 150.0) and is_equal_approx(bar_max, 150.0) and is_equal_approx(player.stamina, 100.0),
		"max_stamina +50 lifts the bar to 150 and it shrinks back to 100 when the bonus ends")
	player.set_stamina(10.0)
	player.stamina_delay = 0.0
	player._tick_timers(0.5)
	var base_regen: float = player.stamina - 10.0
	state.stats = {"stamina_regen": 0.5}
	player.set_stamina(10.0)
	player.stamina_delay = 0.0
	player._tick_timers(0.5)
	check(is_equal_approx(base_regen, 16.0) and is_equal_approx(player.stamina - 10.0, 24.0), "stamina_regen +50% recovers 24 instead of 16 in half a second")
	# Move speed: the run itself is faster, not just the factor.
	var runs: Array[float] = []
	for bonus: float in [0.0, 0.2]:
		await reset_player()
		state.stats = {"move_speed": bonus} if bonus > 0.0 else {}
		Input.action_press("move_forward")
		await frames(20)
		runs.append(Vector2(player.velocity.x, player.velocity.z).length())
		Input.action_release("move_forward")
		await frames(10)
	check(is_equal_approx(player.move_speed_scale(), 1.2) and absf(runs[0] - game.settings.walk_speed) < 0.2 and absf(runs[1] - game.settings.walk_speed * 1.2) < 0.2,
		"move_speed +20%% runs at %.2f m/s instead of %.2f" % [runs[1], runs[0]])
	state.stats = {"heal_bonus": 0.5}
	state.add_item("banh_ngai", 1)
	player.health = player.max_health() * 0.1
	player.consume_item("banh_ngai")
	check(is_equal_approx(player.health, player.max_health() * (0.1 + float(Consumables.effect("banh_ngai")["heal"]) * 1.5)), "heal_bonus +50% makes Bánh ngải restore half again as much")
	state.stats = kept_stats
	state.sword = kept_sword
	await reset_player()

	# ---- elemental reactions: data, then each reaction on its combination, its splash and
	# what it consumes; wrong combinations stay quiet; splash never sets off another reaction
	await clear_dummies()
	var reaction_stats: Dictionary = state.stats
	state.stats = {}
	await reset_player()
	var reactions_ok: bool = true
	for reaction: Dictionary in Reactions.list():
		var named: Array = (reaction.get("needs", []) as Array) + (reaction.get("consume", []) as Array)
		var trigger_ok: bool = String(reaction.get("trigger", "")) == "heavy" or not ContentDB.element(String(reaction.get("element", ""))).is_empty()
		for id: Variant in named:
			if ContentDB.status(String(id)).is_empty():
				trigger_ok = false
		if String(reaction.get("name", "")) == "" or not reaction.has("color") or (reaction.get("needs", []) as Array).is_empty() or not trigger_ok:
			reactions_ok = false
			push_error("Reaction %s lacks a name, a colour, known statuses or a trigger" % reaction.get("id", "?"))
	check(reactions_ok and Reactions.list().size() == 6 and bool(Combat.attack("player", "heavy").get("heavy", false)) and Combat.make_damage(player, Combat.attack("player", "heavy"), 1.0, player.global_position).heavy,
		"Six reactions name known statuses and a trigger; the heavy attack carries the heavy tag")
	var soak_thunder: float = float(ContentDB.status("soak")["taken"]["thunder"])

	# Điện Giật: +40% on the soaked target, shock and a jolt for soaked foes within 5 m only.
	var wet: Enemy = spawn("tan_binh", Vector3(0, 0, -6))
	var wet_near: Enemy = spawn("tan_binh", Vector3(2, 0, -6))
	var dry_near: Enemy = spawn("tan_binh", Vector3(-2, 0, -6))
	var wet_far: Enemy = spawn("tan_binh", Vector3(0, 0, -14))
	await frames(2)
	for enemy: Enemy in [wet, wet_near]:
		game.on_enemy_spawned(enemy, {"id": enemy.entity_id})
	var reacted: Dictionary = watch([wet, wet_near, dry_near, wet_far])
	for enemy: Enemy in [wet, wet_near, wet_far]:
		enemy.statuses.apply("soak", 1, 10.0)
	var floating: Callable = func() -> Array: return game.get_children().filter(func(node: Node) -> bool: return node is Label3D).map(func(node: Node) -> String: return (node as Label3D).text)
	var floats_before: int = floating.call().size()
	var rule: Dictionary = Reactions.find("electrocharge")
	var charged: Dictionary = wet.take_damage(blow(wet, "thunder"))
	check(String(charged.get("reaction", "")) == "electrocharge" and is_equal_approx(float(charged["amount"]), 100.0 * soak_thunder * float(rule["mult"])) and wet.statuses.has("soak"),
		"Điện Giật: thunder on a soaked foe deals %.0f of 100 and leaves it wet" % float(charged.get("amount", 0.0)))
	check(wet_near.statuses.has("shock") and is_equal_approx(wet_near.max_health - wet_near.health, 100.0 * float(rule["splash"]) * soak_thunder)
		and not dry_near.statuses.has("shock") and is_equal_approx(dry_near.health, dry_near.max_health) and not wet_far.statuses.has("shock") and is_equal_approx(wet_far.health, wet_far.max_health),
		"Điện Giật spreads shock to soaked foes within 5 m, not to dry or distant ones")
	check(int(reacted.get(wet.entity_id, 0)) == 1 and int(reacted.get(wet_near.entity_id, 0)) == 1 and not reacted.has(dry_near.entity_id) and not reacted.has(wet_far.entity_id)
		and is_equal_approx(wet.max_health - wet.health, float(charged["amount"])) and wet_near.statuses.has("soak"),
		"A reaction's splash hits each foe once and never sets off a reaction of its own")
	var floats: Array = floating.call()
	check(floats.size() == floats_before + 2 and floats.has("Điện Giật!") and game.hinted.has("reaction:electrocharge"),
		"A reaction floats its name, its splash floats a number, and the first one explains itself")
	await clear_dummies()

	# Hỏa Lốc: gale + flame bursts 4 m, two burn stacks on everyone it reaches, gale used up.
	var whirled: Enemy = spawn("tan_binh", Vector3(0, 0, -6))
	var beside: Enemy = spawn("tan_binh", Vector3(2.5, 0, -6))
	var aside: Enemy = spawn("tan_binh", Vector3(-7, 0, -6))
	await frames(2)
	whirled.statuses.apply("gale", 1, 10.0)
	rule = Reactions.find("firestorm")
	var firestorm: Dictionary = whirled.take_damage(blow(whirled, "flame"))
	check(String(firestorm.get("reaction", "")) == "firestorm" and is_equal_approx(float(firestorm["amount"]), 100.0 * float(rule["mult"])) and not whirled.statuses.has("gale") and whirled.statuses.stacks("burn") == 2,
		"Hỏa Lốc: flame on a gale-struck foe deals %.0f, uses up the gale and burns it twice" % float(firestorm.get("amount", 0.0)))
	check(beside.statuses.stacks("burn") == 2 and is_equal_approx(beside.max_health - beside.health, 100.0 * float(rule["splash"])) and is_equal_approx(aside.health, aside.max_health) and not aside.statuses.has("burn"),
		"Hỏa Lốc's 4 m burst burns a foe beside it, not one 7 m away")
	await clear_dummies()

	# Bốc Hơi: chill or freeze + flame, ×1.8, melts both.
	var chilled: Enemy = spawn("tan_binh", Vector3(0, 0, -6))
	var iced: Enemy = spawn("tan_binh", Vector3(4, 0, -6))
	await frames(2)
	chilled.statuses.apply("chill", 1, 10.0)
	var steam: Dictionary = chilled.take_damage(blow(chilled, "flame"))
	iced.apply_status("freeze", 1, 10.0)
	var melted: Dictionary = iced.take_damage(blow(iced, "flame"))
	check(String(steam.get("reaction", "")) == "vaporize" and is_equal_approx(float(steam["amount"]), 100.0 * float(Reactions.find("vaporize")["mult"])) and not chilled.statuses.has("chill")
		and String(melted.get("reaction", "")) == "vaporize" and not iced.statuses.has("freeze"),
		"Bốc Hơi: flame on a chilled foe deals %.0f and melts chill and freeze alike" % float(steam.get("amount", 0.0)))
	await clear_dummies()

	# Đông Kết: soak + frost freezes at once (in place of the frost's own chill); a boss chills twice.
	var drenched: Enemy = spawn("tan_binh", Vector3(0, 0, -6))
	var drenched_boss: Enemy = spawn("truc_tuong", Vector3(5, 0, -8))
	await frames(2)
	var frost_hit: Dictionary = {"status": {"id": "chill", "chance": 1.0}}
	drenched.statuses.apply("soak", 1, 10.0)
	var frozen: Dictionary = drenched.take_damage(blow(drenched, "frost", 10.0, frost_hit))
	check(String(frozen.get("reaction", "")) == "deep_freeze" and String(frozen.get("status", "")) == "freeze" and drenched.statuses.has("freeze") and drenched.state == "stagger"
		and not drenched.statuses.has("soak") and not drenched.statuses.has("chill"),
		"Đông Kết: frost on a soaked foe freezes it at once and dries it")
	drenched_boss.statuses.apply("soak", 1, 10.0)
	var boss_frozen: Dictionary = drenched_boss.take_damage(blow(drenched_boss, "frost", 10.0, frost_hit))
	check(String(boss_frozen.get("reaction", "")) == "deep_freeze" and not drenched_boss.statuses.has("freeze") and drenched_boss.statuses.stacks("chill") == 2 and not drenched_boss.statuses.has("soak"),
		"Đông Kết on the miniboss adds two chill stacks instead of a freeze")
	await clear_dummies()

	# Lôi Phong: gale + thunder chains to the two nearest foes in turn, not a third.
	var storm_eye: Enemy = spawn("tan_binh", Vector3(0, 0, -6))
	var link_one: Enemy = spawn("tan_binh", Vector3(3, 0, -6))
	var link_two: Enemy = spawn("tan_binh", Vector3(6, 0, -6))
	var link_three: Enemy = spawn("tan_binh", Vector3(9, 0, -6))
	await frames(2)
	reacted = watch([storm_eye, link_one, link_two, link_three])
	storm_eye.statuses.apply("gale", 1, 10.0)
	rule = Reactions.find("storm_chain")
	var chained: Dictionary = storm_eye.take_damage(blow(storm_eye, "thunder"))
	check(String(chained.get("reaction", "")) == "storm_chain" and is_equal_approx(float(chained["amount"]), 100.0 * float(rule["mult"])) and not storm_eye.statuses.has("gale"),
		"Lôi Phong: thunder on a gale-struck foe deals %.0f and uses up the gale" % float(chained.get("amount", 0.0)))
	check(is_equal_approx(link_one.max_health - link_one.health, 100.0 * float(rule["splash"])) and is_equal_approx(link_two.max_health - link_two.health, 100.0 * float(rule["splash"]))
		and link_one.statuses.has("shock") and link_two.statuses.has("shock") and is_equal_approx(link_three.health, link_three.max_health)
		and int(reacted.get(link_one.entity_id, 0)) == 1 and int(reacted.get(link_two.entity_id, 0)) == 1 and not reacted.has(link_three.entity_id),
		"Lôi Phong's lightning hops to two more foes, once each, and stops")
	await clear_dummies()

	# Vỡ Băng: a heavy blow on a frozen foe shatters the ice and knocks it down afresh.
	var statue: Enemy = spawn("tan_binh", Vector3(0, 0, -6))
	await frames(2)
	statue.apply_status("freeze", 1, 10.0)
	statue.state_time = 0.5
	rule = Reactions.find("shatter")
	var shattered: Dictionary = statue.take_damage(Combat.make_damage(player, Combat.attack("player", "heavy"), 100.0, statue.global_position))
	check(String(shattered.get("reaction", "")) == "shatter" and is_equal_approx(float(shattered["amount"]), 100.0 * 1.35 * float(rule["mult"])) and not statue.statuses.has("freeze")
		and statue.state == "stagger" and is_zero_approx(statue.state_time) and is_equal_approx(statue.stagger_time, float(statue.data.get("break_stagger", 1.4))) and is_equal_approx(statue.poise, statue.max_poise),
		"Vỡ Băng: a heavy blow on a frozen foe deals %.0f, breaks the ice and its poise" % float(shattered.get("amount", 0.0)))
	await clear_dummies()

	# Wrong combinations: nothing reacts and nothing is consumed.
	var bystander_dummy: Enemy = spawn("tan_binh", Vector3(0, 0, -6))
	await frames(2)
	var quiet: bool = true
	for case: Array in [["gale", "frost", false], ["chill", "thunder", false], ["soak", "flame", false], ["soak", "", false], ["chill", "", true], ["freeze", "", false], ["burn", "water", false]]:
		bystander_dummy.statuses.clear()
		bystander_dummy.state = "idle"
		bystander_dummy.apply_status(String(case[0]), 1, 10.0)
		var outcome: Dictionary = bystander_dummy.take_damage(blow(bystander_dummy, String(case[1]), 10.0, {"heavy": bool(case[2])}))
		if outcome.has("reaction") or not bystander_dummy.statuses.has(String(case[0])):
			quiet = false
			push_error("%s + %s%s reacted (%s)" % [case[0], case[1], " heavy" if case[2] else "", outcome.get("reaction", "")])
	check(quiet, "Wrong combinations set off no reaction and keep their status")
	await clear_dummies()

	# reaction_dmg grows the bonus and the splash; splash grants no lifesteal or meter.
	await reset_player()
	var conductor: Enemy = spawn("tan_binh", Vector3(0, 0, -2))
	var neighbour: Enemy = spawn("tan_binh", Vector3(2, 0, -2.5))
	await frames(2)
	var zap: Dictionary = {"mult": 1.0, "poise": 0, "knockback": 0.0, "hitstop": 0.0, "element": "thunder"}
	var direct: Array[float] = []
	var jolts: Array[float] = []
	for bonus: float in [0.0, 0.5]:
		state.stats = {"reaction_dmg": bonus} if bonus > 0.0 else {}
		for enemy: Enemy in [conductor, neighbour]:
			enemy.health = enemy.max_health
			enemy.statuses.clear()
			enemy.statuses.apply("soak", 1, 10.0)
		player.counter_bonus = 0.0
		direct.append(float(player.strike(conductor, zap, 1.0).get("amount", 0.0)))
		jolts.append(neighbour.max_health - neighbour.health)
	rule = Reactions.find("electrocharge")
	var grown: float = (1.0 + (float(rule["mult"]) - 1.0) * 1.5) / float(rule["mult"])
	check(direct[0] > 0.0 and is_equal_approx(direct[1] / direct[0], grown) and jolts[0] > 0.0 and is_equal_approx(jolts[1] / jolts[0], 1.5),
		"reaction_dmg +50%% grows Điện Giật's bonus (×%.3f) and its splash (×%.2f)" % [direct[1] / direct[0], jolts[1] / jolts[0]])
	state.stats = {"lifesteal": 0.5}
	for enemy: Enemy in [conductor, neighbour]:
		enemy.health = enemy.max_health
		enemy.statuses.apply("soak", 1, 10.0)
	player.health = player.max_health() * 0.5
	player.set_meter(0.0)
	var drink_mark: float = player.health
	player.counter_bonus = 0.0
	var conducted: Dictionary = player.strike(conductor, zap, 1.0)
	check(String(conducted.get("reaction", "")) == "electrocharge" and neighbour.health < neighbour.max_health and is_equal_approx(player.health - drink_mark, float(conducted["amount"]) * 0.5) and is_equal_approx(player.meter, 5.0),
		"Lifesteal and meter come from the reacting blow only, never its splash")
	state.stats = reaction_stats
	await clear_dummies()
	await reset_player()

	# ---- poise break: a broken, finishable stagger; the finisher; interact priority; poise bars
	await clear_dummies()
	var finish_stats: Dictionary = state.stats
	state.stats = {}
	await reset_player()
	var finisher: Dictionary = Combat.attack("player", "finisher")
	check(String(finisher.get("kind", "")) == "finisher" and Combat.make_damage(player, finisher, 1.0, player.global_position).heavy and player.visual.has_animation(String(finisher.get("clip", "")))
		and float(finisher.get("hp_floor", 0.0)) > 0.0 and float(finisher.get("boss_cap", 0.0)) > 0.0,
		"The finisher has attack data, a playable clip, the heavy tag (Vỡ Băng), a health floor and a boss cap")
	var reeling: Enemy = spawn("tan_binh", Vector3(0, 0, -2.2))
	await frames(2)
	var breaks: Array[int] = [0]
	reeling.poise_broken.connect(func(_enemy: Enemy) -> void: breaks[0] += 1)
	check(not reeling.is_broken() and is_equal_approx(reeling.poise_ratio(), 1.0) and player.finisher_target() == null and not player.start_finisher(reeling),
		"A foe with poise left cannot be finished")
	reeling.take_damage(blow(reeling, "", 1.0, {"poise": reeling.max_poise * 0.5}))
	check(is_equal_approx(reeling.poise_ratio(), 0.5) and not reeling.is_broken(), "Poise drains with each blow (bar at %.2f)" % reeling.poise_ratio())
	reeling.take_damage(blow(reeling, "", 1.0, {"poise": reeling.max_poise}))
	check(breaks[0] == 1 and reeling.state == "stagger" and reeling.is_broken() and reeling.is_finishable() and reeling.stagger_time >= Enemy.BROKEN_MIN
		and is_equal_approx(reeling.finish_time, reeling.stagger_time) and is_zero_approx(reeling.poise_ratio()),
		"Breaking poise leaves an ordinary foe broken and finishable for %.1f s" % reeling.stagger_time)
	var punished: Dictionary = reeling.take_damage(blow(reeling, "", 100.0))
	check(is_equal_approx(float(punished.get("amount", 0.0)), 135.0) and reeling.is_broken(), "A broken foe takes ×1.35 and stays broken")
	reeling.state_time = reeling.stagger_time
	reeling._think(0.016)
	check(reeling.state == "chase" and not reeling.is_broken() and not reeling.is_finishable() and is_equal_approx(reeling.poise_ratio(), 1.0),
		"The window closes when the foe recovers, poise full again")
	await clear_dummies()

	# The boss: a shorter finishing window inside its usual break stagger.
	var warden: Enemy = spawn("truc_tuong", Vector3(0, 0, -2.4), float(ContentDB.enemy("truc_tuong")["hp"]))
	await frames(2)
	warden.take_damage(blow(warden, "", 1.0, {"poise": warden.max_poise + 1.0}))
	var boss_window: float = warden.finish_time
	check(warden.is_finishable() and is_equal_approx(warden.stagger_time, float(warden.data["break_stagger"])) and boss_window < warden.stagger_time and boss_window < Enemy.BROKEN_MIN,
		"A broken boss is finishable for %.1f s of its %.1f s stagger" % [boss_window, warden.stagger_time])
	warden.state_time = boss_window + 0.1
	warden._think(boss_window + 0.1)
	check(warden.is_broken() and not warden.is_finishable() and player.finisher_target() == null, "After its window the staggered boss can no longer be finished")
	# Bosses take a capped share of their health, never the kill.
	warden.state_time = warden.stagger_time
	warden._think(0.016)
	warden.take_damage(blow(warden, "", 1.0, {"poise": warden.max_poise + 1.0}))
	var boss_hits: Array = []
	player.finisher_landed.connect(func(target: Node, amount: float, killed: bool) -> void: boss_hits.append([target, amount, killed]), CONNECT_ONE_SHOT)
	var warden_before: float = warden.health
	check(player.start_finisher(warden) and player.current_action() == "finisher" and player.invulnerable > 0.0, "F starts the finisher on a broken boss within reach")
	for step: int in range(150):
		if player.state != "action":
			break
		await frames(1)
	check(boss_hits.size() == 1 and boss_hits[0][0] == warden and not boss_hits[0][2] and is_equal_approx(warden_before - warden.health, warden.max_health * float(finisher["boss_cap"])),
		"A finisher takes %.0f of the boss's %.0f health (capped at %d%%)" % [warden_before - warden.health, warden.max_health, roundi(float(finisher["boss_cap"]) * 100.0)])
	await clear_dummies()

	# Ordinary foes: in range only, then one blow ends a full-health bandit; untouchable meanwhile.
	await reset_player()
	var far_foe: Enemy = spawn("tan_binh", Vector3(0, 0, -4.5))
	var victim: Enemy = spawn("tan_binh", Vector3(0.6, 0, -2.0), float(ContentDB.enemy("tan_binh")["hp"]))
	await frames(2)
	for enemy: Enemy in [far_foe, victim]:
		enemy.take_damage(blow(enemy, "", 0.0, {"poise": enemy.max_poise + 1.0}))
	check(far_foe.is_finishable() and not player.start_finisher(far_foe) and player.finisher_target() == victim and player.current_action() == "",
		"Only a broken foe within %.0f m can be finished" % player.finisher_reach())
	var kills: Array = []
	player.finisher_landed.connect(func(target: Node, amount: float, killed: bool) -> void: kills.append([target, amount, killed]), CONNECT_ONE_SHOT)
	player.set_meter(0.0)
	check(player.start_finisher(victim), "F starts the finisher on the broken bandit")
	var spared: Dictionary = player.take_damage(Combat.make_damage(far_foe, {"damage": 30, "poise": 20, "knockback": 2.0}, 30.0, player.global_position))
	check(not spared.get("hit", true) and is_equal_approx(player.health, player.max_health()), "Lâm An cannot be hit while she finishes")
	for step: int in range(150):
		if player.state != "action":
			break
		await frames(1)
	check(victim.is_dead() and kills.size() == 1 and kills[0][2] and player.meter >= float(finisher.get("meter_gain", 0.0)) - 0.01,
		"The finisher kills a full-health bandit (%.0f of %.0f) and fills the meter" % [float(kills[0][1]) if kills.size() > 0 else 0.0, victim.max_health])
	await clear_dummies()

	# F prefers the finisher over a reward chest beside Lâm An, and only shows it while one is due.
	await reset_player()
	var chest: Interactable = game.spawn_reward_chest("trial", player.global_position + Vector3(1.6, 0, 0.6))
	var duelist: Enemy = spawn("tan_binh", Vector3(0, 0, -2.0))
	await frames(2)
	game._update_focus()
	check(game.focus == chest and not game.hud.prompt.text.contains("Kết liễu"), "Without a broken foe, F still opens the chest")
	duelist.take_damage(blow(duelist, "", 0.0, {"poise": duelist.max_poise + 1.0}))
	game._update_focus()
	check(game.focus == duelist and game.hud.prompt.text.contains("Kết liễu"), "A broken foe in reach takes F over the chest: \"%s\"" % game.hud.prompt.text)
	var press: InputEventAction = InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	game._unhandled_input(press)
	check(player.current_action() == "finisher" and not chest.opened, "Pressing F finishes the foe and leaves the chest shut")
	for step: int in range(150):
		if player.state != "action":
			break
		await frames(1)
	game._clear_reward_chests()
	await clear_dummies()

	# Poise bars: ordinary foes only, while locked on, after a hit for a few seconds, and while broken.
	await reset_player()
	player.set_lock(null)
	var marked: Enemy = spawn("tan_binh", Vector3(0, 0, -3.0))
	var big: Enemy = spawn("truc_tuong", Vector3(5, 0, -6))
	await frames(2)
	marked.since_hit = 99.0
	marked.update_poise_bar(1.0)
	var bar_hidden: bool = marked.poise_bar == null or not marked.poise_bar.visible
	marked.take_damage(blow(marked, "", 1.0, {"poise": marked.max_poise * 0.25}))
	marked.update_poise_bar(1.0)
	var bar_hit: bool = marked.poise_bar != null and marked.poise_bar.visible and is_equal_approx(float(marked.poise_bar.material.get_shader_parameter("fill")), 0.75)
	marked.since_hit = Enemy.POISE_BAR_LINGER + 0.1
	marked.update_poise_bar(1.0)
	var bar_faded: bool = not marked.poise_bar.visible
	player.set_lock(marked)
	marked.update_poise_bar(1.0)
	var bar_locked: bool = marked.poise_bar.visible
	player.set_lock(null)
	marked.update_poise_bar(1.0)
	var bar_unlocked: bool = not marked.poise_bar.visible
	check(bar_hidden and bar_hit and bar_faded and bar_locked and bar_unlocked,
		"The poise bar shows after a hit (%s) and while locked on (%s), hidden otherwise (%s, %s, %s)" % [bar_hit, bar_locked, bar_hidden, bar_faded, bar_unlocked])
	marked.take_damage(blow(marked, "", 1.0, {"poise": marked.max_poise}))
	marked.since_hit = Enemy.POISE_BAR_LINGER + 0.1
	marked.update_poise_bar(1.0)
	check(marked.is_finishable() and marked.poise_bar.visible and is_equal_approx(float(marked.poise_bar.material.get_shader_parameter("finishable")), 1.0),
		"A broken foe keeps its bar up, flashing for the finisher")
	big.take_damage(blow(big, "", 1.0, {"poise": 10.0}))
	player.set_lock(big)
	big.update_poise_bar(1.0)
	game.hud.set_boss_poise(big.poise_ratio(), big.is_broken(), big.is_finishable())
	var boss_gauge: float = game.hud.boss_poise.value
	player.set_lock(null)
	marked.take_damage(blow(marked, "", 99999.0))
	marked.update_poise_bar(1.0)
	check(big.poise_bar == null and not big.poise_bar_wanted() and is_equal_approx(boss_gauge, big.poise_ratio()) and not marked.poise_bar.visible,
		"Bosses show poise on the HUD gauge (%.2f), not overhead; a dead foe's bar goes" % boss_gauge)
	state.stats = finish_stats
	await clear_dummies()
	await reset_player()

	# ---- Tâm Nhãn: a perfect dodge or parry slows every enemy, never Lâm An, for a while
	var focus: Dictionary = player.focus_rule()
	var focus_time: float = float(focus.get("duration", 0.0))
	check(float(focus.get("enemy_time", 1.0)) < 1.0 and focus_time > 0.0 and float(focus.get("cooldown", 0.0)) > focus_time
		and float(focus.get("perfect_dodge", 0.0)) < float(ContentDB.timing("player", "dodge")["hit_end"]) and float(focus.get("perfect_parry", 0.0)) < float(ContentDB.timing("player", "parry")["hit_end"]),
		"Tâm Nhãn has data: perfect windows inside the dodge and parry windows, a slower enemy clock, a duration and a longer cooldown")
	var lunger: Enemy = spawn("tan_binh", Vector3(0, 0, -2.0))
	await frames(2)
	var lunge: Dictionary = {"poise": 10, "knockback": 0.0, "hitstop": 0.0}
	var opened: Array[String] = []
	var closed: Array[int] = [0]
	player.focus_started.connect(func(kind: String) -> void: opened.append(kind))
	player.focus_ended.connect(func() -> void: closed[0] += 1)
	var rested: float = player.stamina
	player.counter_bonus = 0.0
	player._start_dodge()
	var dodged_clean: Dictionary = player.take_damage(Combat.make_damage(lunger, lunge, 10.0, player.global_position))
	check(not dodged_clean.get("hit", true) and dodged_clean.get("perfect", false) and Enemy.time_dilation < 1.0 and player.is_focused() and opened.size() == 1 and opened[0] == "dodge"
		and is_equal_approx(player.stamina, rested) and player.counter_bonus > 0.0 and game.hud.focus_active,
		"A blow caught in the first instant of a dodge opens Tâm Nhãn: enemies at ×%.2f, the dodge's stamina back, a counter primed, the HUD veiled" % Enemy.time_dilation)
	player._tick_timers(focus_time * 0.5)
	var paused_at: float = player.focus_time
	game.set_paused(true)
	await frames(20)
	var held: bool = is_equal_approx(player.focus_time, paused_at)
	game.set_paused(false)
	check(held and is_equal_approx(paused_at, focus_time * 0.5) and Enemy.time_dilation < 1.0, "Tâm Nhãn counts down on Lâm An's own clock, and a pause holds it (%.2f s left)" % paused_at)
	player._tick_timers(player.focus_time + 0.01)
	game.hud._fade_focus(1.0)
	check(is_equal_approx(Enemy.time_dilation, 1.0) and not player.is_focused() and closed[0] == 1 and player.focus_cooldown > 0.0 and not game.hud.focus_active and not game.hud.focus_veil.visible,
		"After %.1f s of her time enemies are back at ×1 and the veil lifts" % focus_time)
	for step: int in range(60):
		if player.state == "move":
			break
		await frames(1)
	player._start_dodge()
	var cooling: Dictionary = player.take_damage(Combat.make_damage(lunger, lunge, 10.0, player.global_position))
	check(not cooling.get("hit", true) and not cooling.get("perfect", true) and is_equal_approx(Enemy.time_dilation, 1.0) and opened.size() == 1 and player.stamina < rested - 1.0,
		"While Tâm Nhãn cools down a perfect dodge only dodges (no slow-down, no stamina back)")
	player._tick_timers(player.focus_cooldown + 0.01)
	player._start_dodge()
	var again: Dictionary = player.take_damage(Combat.make_damage(lunger, lunge, 10.0, player.global_position))
	check(again.get("perfect", false) and Enemy.time_dilation < 1.0 and opened.size() == 2, "Once cooled down, the next perfect dodge opens it again")
	player.revive(player.global_position)
	check(is_equal_approx(Enemy.time_dilation, 1.0) and not player.is_focused() and is_zero_approx(player.focus_cooldown) and closed[0] == 2, "Waking at a shrine restores one clock for everyone")
	await reset_player()
	player._start_dodge()
	player.dodge_time = float(focus["perfect_dodge"]) + 0.05
	var late_dodge: Dictionary = player.take_damage(Combat.make_damage(lunger, lunge, 10.0, player.global_position))
	check(not late_dodge.get("hit", true) and late_dodge.get("dodged", false) and not late_dodge.get("perfect", true) and is_equal_approx(Enemy.time_dilation, 1.0) and is_equal_approx(player.health, player.max_health()),
		"A blow met later in the dodge's invulnerable frames is dodged, without Tâm Nhãn")
	await frames(30)
	await reset_player()
	player.face_direction(lunger.global_position - player.global_position, true)
	player._start_action("parry")
	player.action["t"] = float(focus["perfect_parry"]) + 0.05
	var late_parry: Dictionary = player.take_damage(Combat.make_damage(lunger, lunge, 10.0, player.global_position))
	check(late_parry.get("parried", false) and not late_parry.get("perfect", true) and lunger.state == "stagger" and is_equal_approx(Enemy.time_dilation, 1.0),
		"A parry late in its window still staggers the attacker, without Tâm Nhãn")
	await frames(30)
	await reset_player()
	lunger._set_state("chase")
	player.face_direction(lunger.global_position - player.global_position, true)
	player._start_action("parry")
	var perfect_parry: Dictionary = player.take_damage(Combat.make_damage(lunger, lunge, 10.0, player.global_position))
	check(perfect_parry.get("parried", false) and perfect_parry.get("perfect", false) and lunger.state == "stagger" and Enemy.time_dilation < 1.0 and opened.back() == "parry",
		"A parry in its first instant is perfect: the attacker staggers and Tâm Nhãn opens")
	await frames(30)
	await reset_player()
	await clear_dummies()

	# Only enemies slow down: their attack clock, animation, missiles, the boar's wind-up and the guardian's ring.
	var swinger: Enemy = spawn("tan_binh", Vector3(0, 0, -2.5))
	var charger: Boar = spawn("heo_gio", Vector3(4, 0, -4)) as Boar
	var ringer: Guardian = spawn("truc_tuong", Vector3(-5, 0, -7)) as Guardian
	await frames(2)
	swinger._begin_attack("attack")
	swinger._physics_process(0.1)
	var real_clock: float = swinger.attack_clock
	swinger._begin_attack("attack")
	player.start_focus("parry")
	var rate: float = Enemy.time_dilation
	swinger._physics_process(0.1)
	var slowed_clock: float = swinger.attack_clock
	var slowed_anim: float = swinger.visual.player.speed_scale
	check(is_equal_approx(real_clock, 0.1 * swinger.speed_scale) and is_equal_approx(slowed_clock, real_clock * rate) and is_equal_approx(slowed_anim, rate),
		"Under Tâm Nhãn an enemy's attack clock (%.3f vs %.3f) and animation run at ×%.2f" % [slowed_clock, real_clock, rate])
	var thrown: WindProjectile = WindProjectile.new()
	game.add_child(thrown)
	thrown.launch(swinger.global_position + Vector3(0, 1.3, 0), Vector3.RIGHT, 10.0, 5.0, {}, Combat.LAYER_HURT_PLAYER, swinger)
	thrown.set_physics_process(false)
	thrown._physics_process(0.1)
	var cast: WindProjectile = WindProjectile.new()
	game.add_child(cast)
	cast.launch(player.global_position + Vector3(0, 1.3, 0), Vector3.RIGHT, 10.0, 5.0, {}, Combat.LAYER_HURT_ENEMY, player)
	cast.set_physics_process(false)
	cast._physics_process(0.1)
	check(is_equal_approx(thrown.travelled, 1.0 * rate) and is_equal_approx(cast.travelled, 1.0), "An enemy's missile flies at ×%.2f (%.2f m), Lâm An's at full speed (%.2f m)" % [rate, thrown.travelled, cast.travelled])
	for missile: WindProjectile in [thrown, cast]:
		if is_instance_valid(missile):
			missile.queue_free()
	charger._begin_windup()
	charger._physics_process(0.1)
	ringer.shockwave_radius = 0.5
	ringer.shockwave_center = ringer.global_position
	ringer._process(0.1)
	check(is_equal_approx(charger.state_time, 0.1 * rate) and is_equal_approx(ringer.shockwave_radius, 0.5 + 0.9 * rate), "The boar's wind-up and the guardian's shockwave slow with them")
	ringer.shockwave_radius = -1.0
	player._tick_timers(player.focus_time + 0.01)
	swinger._physics_process(0.1)
	check(is_equal_approx(Enemy.time_dilation, 1.0) and is_equal_approx(swinger.visual.player.speed_scale, 1.0) and is_equal_approx(swinger.attack_clock, slowed_clock + 0.1 * swinger.speed_scale),
		"When it ends enemies run at exactly ×1 again, animation included")
	await clear_dummies()
	await reset_player()

	# ---- kiếm phụ: the swap key trades swords; the first blow after a swap is empowered
	await reset_player()
	var sword_before: String = state.sword
	var uid_before: int = state.equipped_uid
	state.set_alt("")
	var refused: bool = not player.try_swap()
	state.grant_sword("sword_water")
	state.grant_sword("sword_thunder")
	state.equip_sword("sword_water")
	game._equip_visuals()
	var set_ok: bool = game.set_alt_sword("sword_thunder") and not state.set_alt("sword_water")
	var water_style: String = player.style_id()
	var swapped: bool = player.try_swap()
	await frames(1)
	check(refused and set_ok and swapped and state.sword == "sword_thunder" and state.sword_alt == "sword_water" and water_style == "thuy" and player.style_id() == "loi",
		"The swap key trades the Thủy sword for the Lôi one at the hip (style %s → %s); no secondary sword, no swap" % [water_style, player.style_id()])
	var swap_blocked: bool = not player.try_swap()
	var swap_data: Dictionary = player.swap_rule()
	var soaked: Enemy = spawn("tan_binh", Vector3(0, 0, -2.2))
	soaked.statuses.apply("soak", 1, 10.0)
	var plain: Enemy = spawn("tan_binh", Vector3(2.5, 0, -2.2))
	var hit_data: Dictionary = Combat.attack("player", "attack_1")
	var before_swap_hit: float = soaked.health
	var swap_hit: Dictionary = player.strike(soaked, hit_data, 1.0)
	var empowered: float = before_swap_hit - soaked.health
	var spent: bool = player.swap_window == 0.0
	var before_plain: float = plain.health
	player.strike(plain, hit_data, 1.0)
	var normal: float = before_plain - plain.health
	check(swap_blocked and swap_hit.get("reaction", "") == "electrocharge" and spent and empowered > normal * 1.3,
		"Right after a swap: no second swap for %.1f s; the first Lôi blow lands +30%% with its Tê liệt for certain, sets off Điện Giật on the soaked foe (%.0f vs %.0f), and spends the bonus" % [float(swap_data["cooldown"]), empowered, normal])
	player._tick_timers(float(swap_data["cooldown"]) + 0.01)
	player._start_dodge()
	var mid_dodge: bool = not player.try_swap()
	await reset_player()
	player.input_enabled = false
	var in_talk: bool = not player.try_swap()
	player.input_enabled = true
	var saved: Dictionary = state.to_dict()
	var reloaded: GameState = GameState.new()
	reloaded.from_dict(saved)
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("sword_alt")
	legacy.erase("alt_uid")
	var old: GameState = GameState.new()
	old.from_dict(legacy)
	check(mid_dodge and in_talk and reloaded.sword_alt == state.sword_alt and reloaded.sword == state.sword and not old.has_alt(),
		"No swap mid-dodge or in a conversation; both swords survive a save, and an older save has no secondary sword")
	state.set_alt("")
	state.equip_sword(sword_before, uid_before)
	game._equip_visuals()
	await clear_dummies()

	# ---- last, because it runs the death screen: poison can kill, and death clears statuses
	await reset_player()
	player.apply_status("poison", 3)
	player.start_focus("dodge")
	player.health = 0.5
	player._tick_statuses(0.6)
	check(player.is_dead() and player.statuses.active.is_empty() and is_equal_approx(Enemy.time_dilation, 1.0) and not player.is_focused(),
		"Poison can finish Lâm An off, and death clears her statuses and Tâm Nhãn")
	player.revive(player.global_position)

	print("COMBAT RESULT: %d failure(s)" % failures)
	game.audio.stop_all()
	await create_timer(0.2, true, false, true).timeout
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
