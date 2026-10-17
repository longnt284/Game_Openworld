extends SceneTree
## Elemental sword styles: every form of every style casts, deals damage and applies its
## status; statuses tick (burn), stack into freeze (chill) and respect boss resistance;
## the ultimate needs a full meter; cooldown ratios follow the reduced cooldown.

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
	var enemy: Enemy = Guardian.new() if kind == "truc_tuong" else Enemy.new()
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

	print("COMBAT RESULT: %d failure(s)" % failures)
	game.audio.stop_all()
	await create_timer(0.2, true, false, true).timeout
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
