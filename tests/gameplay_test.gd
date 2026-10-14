extends SceneTree
## Plays the vertical slice from New Game to the epilogue through the real systems
## (triggers, dialogue, combat damage, chests, shrines, echoes, chimes, boss) and
## checks combat rules, one-time rewards, entity persistence and save migration.

var failures: int = 0
var game: Node3D
const TEST_SAVE: String = "user://gameplay_test_save.json"

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
	game.spawner.update_now()
	await frames(4)

func go(x: float, z: float) -> void:
	game.player.teleport(Vector3(x, game.world.height_at(x, z) + 0.4, z))
	await frames(2)
	await settle()

func talk(id: String) -> void:
	var npc: Npc = game.spawner.node_for(id) as Npc
	if npc == null:
		check(false, "NPC %s is spawned" % id)
		return
	game.start_dialogue(npc)
	for step: int in range(40):
		if game.dialogue.is_empty():
			break
		if game.dialogue.has("choices"):
			game._choose_dialogue(game.dialogue["choices"].size() - 1)
		else:
			game._advance_dialogue()
	await frames(2)

func kill(id: String) -> void:
	var enemy: Enemy = game.spawner.node_for(id) as Enemy
	if enemy == null:
		check(false, "Enemy %s is spawned" % id)
		return
	var damage: Combat.Damage = Combat.make_damage(game.player, {"poise": 999, "knockback": 0.0}, 99999.0, enemy.global_position)
	enemy.take_damage(damage)
	await frames(3)

func use(id: String) -> void:
	var item: Interactable = game.spawner.node_for(id) as Interactable
	if item == null:
		check(false, "Interactable %s is spawned" % id)
		return
	game.on_interact(item)
	await frames(2)

func stage(quest: String) -> int:
	return game.quests.stage(quest)

func _run() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(TEST_SAVE + suffix):
			DirAccess.remove_absolute(TEST_SAVE + suffix)
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	game.skip_title = true
	game.save_path = TEST_SAVE
	root.add_child(game)
	while not game.initialized:
		await frames(1)
	await settle()
	var state: GameState = game.state
	var player: PlayerController = game.player
	check(game.quests.is_active("mq01_ben_song") and stage("mq01_ben_song") == 0, "New game starts the first main quest")

	# --- Act 1: rescue
	await go(-5, 56)
	check(stage("mq01_ben_song") == 1, "Reaching the road triggers the rescue objective")
	await kill("en_rescue_1")
	await kill("en_rescue_2")
	check(stage("mq01_ben_song") == 2 and state.has_flag("dead:en_rescue_1"), "Clearing the bandits advances the quest and persists their death")
	await talk("npc_tieu_mac")
	check(game.quests.is_done("mq01_ben_song") and state.count("thu_tieu_mac") == 1, "Talking to Tiểu Mạc completes the rescue and gives the letter")
	var xp_after_first: int = state.xp + (state.level - 1) * 1000
	game.quests.notify("talk:tieu_mac")
	game.quests._complete("mq01_ben_song")
	check(state.xp + (state.level - 1) * 1000 == xp_after_first, "Quest rewards are granted only once")
	check(game.quests.is_active("mq02_lang_quen"), "Next main quest starts automatically")

	# --- Village
	await go(-16, 7)
	await talk("npc_ba_luc")
	check(stage("mq02_lang_quen") == 1 and state.count("thu_tieu_mac") == 0, "Delivering the letter advances 'Làng quên tên'")
	await go(7, 26)
	await use("shrine_village")
	check(stage("mq02_lang_quen") == 2 and state.checkpoint_id == "shrine_village", "Lighting the village shrine sets the checkpoint")
	await go(18.5, 14.5)
	await talk("npc_chu_bay")
	await go(-19.5, 24)
	await talk("npc_ba_hanh")
	check(stage("mq02_lang_quen") == 3 and game.quests.is_active("sq01_chuong_gio") and game.quests.is_active("sq02_lo_ren"), "Asking villagers starts both side quests")
	await go(-16, 7)
	await talk("npc_ba_luc")
	check(game.quests.is_done("mq02_lang_quen") and state.skill_level("gust") == 1 and state.has_flag("map_unlocked"), "Reporting back unlocks Phong Trảm and the map")
	var npc_count: int = 0
	for node: Node in get_nodes_in_group("npc"):
		if (node as Npc).entity_id == "npc_ba_luc" and not node.is_queued_for_deletion():
			npc_count += 1
	check(npc_count == 1, "Repeated streaming keeps a single instance of each NPC")

	# --- Side quest: wind chime
	await go(72, 8)
	await use("chest_meadow")
	check(state.count("chuong_gio") == 1 and stage("sq01_chuong_gio") == 1, "Meadow chest yields the wind chime")
	var coins_before: int = state.coins
	await use("chest_meadow")
	check(state.coins == coins_before, "Chest loot cannot be taken twice")
	await go(-19.5, 24)
	await talk("npc_ba_hanh")
	check(game.quests.is_done("sq01_chuong_gio") and state.count("to_ky_uc") == 1, "Returning the chime completes the side quest with a memory thread")

	# --- Act 2: Trúc Hải
	await go(4, -113)
	check(stage("mq03_dau_ky_uc") == 1, "Reaching the bamboo gate advances the trail")
	await go(9, -80)
	check(game.quests.is_active("ev01_chan_duong"), "Hill ambush event starts on the road")
	for id: String in ["en_hill_1", "en_hill_2", "en_hill_3"]:
		await kill(id)
	check(game.quests.is_done("ev01_chan_duong"), "Clearing the ambush completes the local event")
	for echo: Array in [["echo_1", 6, -171], ["echo_2", -23, -189], ["echo_3", 40, -209]]:
		await go(echo[1], echo[2])
		await use(echo[0])
	check(stage("mq03_dau_ky_uc") == 2, "Three memory echoes lead to the watchtower")
	check(state.skill_level("cyclone") == 1, "All three echoes teach the Toàn Phong skill")
	await go(42, -211)
	await use("diary_tower")
	check(game.quests.is_done("mq03_dau_ky_uc") and state.skill_level("khinh_cong") == 1, "The diary unlocks khinh công and completes the trail")
	await use("chest_tower")
	await go(-46, -205)
	await use("chest_camp")
	check(state.count("da_gio") >= 3 and stage("sq02_lo_ren") == 1, "Wind stones from camp and tower satisfy the smith")
	await go(-22, -149)
	await use("flute_echo")
	await go(-60, -147)
	await use("chest_stream")
	check(game.quests.is_done("ev02_tieng_sao"), "Flute echo reveals the hidden stream chest")
	await go(18.5, 14.5)
	await talk("npc_chu_bay")
	check(game.quests.is_done("sq02_lo_ren") and state.sword == "sword_bamboo" and player.visual.weapon_key == "sword_bamboo", "Smith forges Thanh Trúc Kiếm")

	# --- Khinh công physics
	await go(0, -240)
	player.velocity = Vector3.ZERO
	player.global_position += Vector3.UP * 3.0
	await frames(2)
	player.queue_input("jump")
	await frames(2)
	check(player.velocity.y > 6.0 and player.used_leap, "Khinh công performs an air leap")
	await frames(60)

	# --- Gorge, chimes, boss
	await go(0, -273)
	check(stage("mq04_vuot_khe") == 1, "Crossing the gorge advances the final quest")
	check(game.spawner.arena.closed, "Arena wind barrier is closed before the puzzle")
	await go(-5, -288)
	await use("chime_stone")
	await use("chime_bamboo")
	check(not state.has_flag("chimes_solved"), "Wrong chime order resets the puzzle")
	await use("chime_bamboo")
	await use("chime_stone")
	await use("chime_water")
	check(state.has_flag("chimes_solved") and stage("mq04_vuot_khe") == 2 and not game.spawner.arena.closed, "Correct chime order opens the arena")
	await go(0, -330)
	await frames(10)
	var boss: Guardian = game.spawner.node_for("boss_truc_tuong") as Guardian
	check(boss != null and game.spawner.arena.fighting, "Entering the arena starts the guardian fight")
	if boss:
		var hit: Combat.Damage = Combat.make_damage(player, {"poise": 0, "knockback": 0.0}, boss.max_health * 0.55, boss.global_position)
		boss.take_damage(hit)
		check(boss.phase == 2 and boss.invulnerable, "Guardian enters phase two below half health")
		await frames(140)
	await kill("boss_truc_tuong")
	check(state.has_flag("dead:boss_truc_tuong") and not game.spawner.arena.fighting and stage("mq04_vuot_khe") == 3, "Defeating the guardian ends the fight")
	await frames(5)
	game.spawner.update_now()
	await use("memory_core")
	check(game.quests.is_done("mq04_vuot_khe") and state.has_flag("slice_complete"), "Memory core completes the slice")

	# --- Persistence across streaming and save/load
	check(game.save_game(), "Save after the slice")
	await go(-20, 66)
	await go(0, -330)
	await frames(5)
	var revisited: Enemy = game.spawner.node_for("boss_truc_tuong") as Enemy
	check(revisited == null or revisited.is_dead(), "Defeated boss never respawns after streaming")
	var opened: Interactable = null
	await go(72, 8)
	opened = game.spawner.node_for("chest_meadow") as Interactable
	check(opened != null and not opened.can_interact(), "Opened chests stay opened after streaming")
	var level: int = state.level
	check(game.load_game(), "Reload saved slice")
	check(state.level == level and state.has_flag("slice_complete") and state.sword == "sword_bamboo", "Reload restores progression")

	# --- Combat rules
	await go(-46, -200)
	state.reset_camps()
	game.spawner.clear_all()
	await frames(2)
	game.spawner.update_now()
	await frames(4)
	var bandit: Enemy = game.spawner.node_for("en_camp_1") as Enemy
	if bandit:
		player.teleport(bandit.global_position + Vector3(0, 0.3, 1.6))
		await frames(3)
		bandit.set_physics_process(false)
		player.face_direction(bandit.global_position - player.global_position, true)
		var before: float = bandit.health
		player._start_action("attack_1")
		await frames(40)
		var expected: float = state.attack_power() * 1.0
		check(is_equal_approx(before - bandit.health, expected), "One sword swing damages a target exactly once (%.1f)" % (before - bandit.health))
		bandit.set_physics_process(true)
		player._start_action("parry")
		await frames(2)
		var swing: Dictionary = Combat.attack("bandit", "attack")
		var result: Dictionary = player.take_damage(Combat.make_damage(bandit, swing, 14.0, player.global_position))
		check(result.get("parried", false) and bandit.state == "stagger", "Timed parry staggers the attacker")
		await frames(40)
		player._start_dodge()
		await frames(2)
		var health_before: float = player.health
		player.take_damage(Combat.make_damage(bandit, swing, 14.0, player.global_position))
		check(player.health == health_before, "Dodge grants invulnerability frames")
	else:
		check(false, "Camp bandit available for combat checks")

	# --- Enemies never step into the gorge
	await go(0, -246)
	var boar: Boar = Boar.new()
	game.spawner.add_child(boar)
	boar.setup({"id": "test_boar", "enemy": "heo_gio", "yaw": 180}, game.assets, game.world)
	boar.activate(Vector3(0, game.world.height_at(0, -249.5) + 0.3, -249.5), player)
	player.teleport(Vector3(0, game.world.height_at(0, -266) + 0.5, -266))
	boar.target = player
	boar._set_state("chase")
	var entered: bool = false
	for step: int in range(240):
		await frames(1)
		if game.world.layout.in_chasm(boar.global_position.x, boar.global_position.z):
			entered = true
	check(not entered, "Edge guard keeps enemies out of the gorge")
	boar.queue_free()

	# --- Navigation and migration
	var baked: bool = false
	for region: NavigationRegion3D in game.spawner.navzones.values():
		if region.navigation_mesh and region.navigation_mesh.get_polygon_count() > 0:
			baked = true
	check(baked, "Encounter navmesh bakes from streamed colliders")
	var legacy: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version": 1, "seed": 284, "position": [3.0, 1.0, -5.0], "checkpoint": [3.0, 1.0, -5.0], "beacon_active": true}))
	legacy.close()
	var migrated: Dictionary = SaveStore.read_save(TEST_SAVE)
	check(not migrated.is_empty() and int(migrated["version"]) == 2 and migrated["state"]["checkpoint_id"] == "shrine_village", "Version 1 saves migrate to schema 2")
	check(game.load_game() and state.has_flag("migrated_from_v1"), "Migrated save loads into the game")

	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(TEST_SAVE + suffix):
			DirAccess.remove_absolute(TEST_SAVE + suffix)
	print("GAMEPLAY RESULT: ", failures, " failure(s)")
	game.audio.stop_all()
	await create_timer(0.2, true, false, true).timeout
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
