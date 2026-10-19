extends SceneTree
## Elemental sword styles: every form of every style casts, deals damage and applies its
## status; statuses tick (burn), stack into freeze (chill) and respect boss resistance;
## the ultimate needs a full meter; cooldown ratios follow the reduced cooldown. Enemy
## infrastructure: class factory, enemy-cast areas, camp attack slots, tint, wind-up cues
## and damage-over-time numbers. Statuses on Lâm An: poison, bleed, stun, slows, buffs and
## debuffs in GameState.stat, cleanse, revive, enemy blows that land or miss, HUD icons.

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

	# ---- last, because it runs the death screen: poison can kill, and death clears statuses
	await reset_player()
	player.apply_status("poison", 3)
	player.health = 0.5
	player._tick_statuses(0.6)
	check(player.is_dead() and player.statuses.active.is_empty(), "Poison can finish Lâm An off, and death clears her statuses")
	player.revive(player.global_position)

	print("COMBAT RESULT: %d failure(s)" % failures)
	game.audio.stop_all()
	await create_timer(0.2, true, false, true).timeout
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
