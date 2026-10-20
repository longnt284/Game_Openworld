extends SceneTree
## Rendered capture of real gameplay scenes (not headless). Writes PNGs to
## res://.cache/shots/ and prints frame-time statistics for each scene.
##   godot --path . --script res://tests/render_preview.gd [-- scene_name ...]

var game: Node3D
var shots: String = "res://.cache/shots"

func _initialize() -> void:
	call_deferred("_run")

func frames(count: int) -> void:
	for index: int in range(count):
		await physics_frame
		await process_frame

func settle() -> void:
	for index: int in range(4000):
		if game.world.active.size() == game.settings.chunk_capacity() and game.world.building.is_empty() and game.world.pending.is_empty():
			break
		await frames(1)
	game.spawner.update_now()
	await frames(30)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [shots, name])
	print("SHOT ", name, " fps=", Engine.get_frames_per_second(), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

func place(x: float, z: float, yaw_deg: float, camera_pitch: float = -0.28) -> void:
	var player: PlayerController = game.player
	player.teleport(Vector3(x, game.world.height_at(x, z) + 0.3, z))
	var yaw: float = deg_to_rad(yaw_deg)
	player.face_direction(Vector3(-sin(yaw), 0, -cos(yaw)), true)
	player.camera_rig.yaw = yaw
	player.camera_rig.pitch = camera_pitch
	await frames(2)
	await settle()

func measure(label: String, frame_count: int) -> void:
	## Frame-to-frame wall time while the scene keeps running; prints p50/p95/FPS and memory.
	var samples: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	var draw_calls: float = 0.0
	for frame: int in range(frame_count):
		await process_frame
		var now: int = Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
		draw_calls = maxf(draw_calls, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var total: float = 0.0
	for sample: float in samples:
		total += sample
	samples.sort()
	print("PROFILE %s: frames=%d | avg FPS=%.1f | p50 ms=%.2f | p95 ms=%.2f | max draw calls=%d | static MB=%.1f | video MB=%.1f" % [
		label, frame_count, 1000.0 * frame_count / total, samples[frame_count / 2], samples[int(frame_count * 0.95)], draw_calls,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])

func profile() -> void:
	print("PROFILE setup: ", DisplayServer.window_get_size(), " | ", RenderingServer.get_video_adapter_name(), " | ",
		RenderingServer.get_video_adapter_vendor(), " | quality=", game.user_settings.quality)
	# Busy village plaza: NPCs, props, market, shadows.
	await place(0, 20, 0, -0.22)
	Input.action_press("move_forward")
	await measure("village", 300)
	Input.action_release("move_forward")
	# Region change: sprint north from the hill into Trúc Hải while chunks stream in.
	await place(4, -92, 0, -0.22)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await measure("region_transition", 420)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	# Boss fight: guardian active and attacking, wall up, VFX and music on.
	game.state.set_flag("chimes_solved")
	game.spawner.arena.set_closed(false)
	await place(0, -322, 0, -0.2)
	game.player.invulnerable = 999.0
	var guardian: Enemy = game.spawner.node_for("boss_truc_tuong") as Enemy
	if guardian:
		guardian.global_position = game.player.global_position + Vector3(0, 0.2, -4.0)
		guardian._set_state("chase")
	await measure("boss_fight", 420)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(shots)
	var only: PackedStringArray = OS.get_cmdline_user_args()
	if only.has("title"):
		game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
		root.add_child(game)
		while not game.initialized:
			await frames(1)
		await settle()
		await frames(60)
		await shot("title")
		game.audio.stop_all()
		await create_timer(0.2, true, false, true).timeout
		quit(0)
		return
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	game.skip_title = true
	game.save_path = "user://render_preview_save.json"
	game.profile_path = "user://render_preview_profile.json"
	root.add_child(game)
	while not game.initialized:
		await frames(1)
	game.hud.close_vision()
	game._on_vision_closed()
	await settle()
	var scenes: Array[String] = ["dock", "village", "dialogue", "combat", "statuses", "reactions", "finisher", "focus", "moves", "bamboo", "gorge", "arena", "boss", "map", "journal", "inventory", "character", "shop", "settings", "credits", "gacha", "armory", "talismans", "daily", "tier", "trial"]
	for scene: String in scenes:
		if not only.is_empty() and not only.has(scene):
			continue
		match scene:
			"dock":
				await place(-20, 70.5, 0)
				await frames(30)
				await shot("dock")
			"village":
				await place(2, 26, 15, -0.22)
				await frames(40)
				await shot("village")
			"dialogue":
				await place(-16.3, 6.2, 0, -0.2)
				var npc: Npc = game.spawner.node_for("npc_ba_luc") as Npc
				if npc:
					game.start_dialogue(npc)
				await frames(40)
				game.hud.dialogue_text.visible_ratio = 1.0
				await frames(2)
				await shot("dialogue")
				game._end_dialogue()
			"combat":
				await place(-5, 56, 0, -0.32)
				await frames(20)
				var enemy: Enemy = game.spawner.node_for("en_rescue_1") as Enemy
				if enemy:
					enemy.global_position = game.player.global_position + Vector3(0, 0, -2.2)
					enemy._set_state("chase")
					game.player.face_direction(Vector3(0, 0, -1), true)
					game.player._start_action("attack_1")
					await frames(9)
					await shot("combat_swing")
					await frames(30)
					game.player._start_action("skill_gust")
					game.state.unlock_skill("gust")
					await frames(12)
					await shot("combat_skill")
			"statuses":
				# Buff and debuff icons above the vitals: two buffs, then stacked debuffs.
				await place(-20, 70.5, 0)
				var lam_an: PlayerController = game.player
				for entry: Array in [["buff_atk", 1], ["buff_regen", 1], ["poison", 2], ["bleed", 3], ["weaken", 1]]:
					lam_an.apply_status(entry[0], entry[1])
				await frames(20)
				game._refresh_hud()
				await frames(2)
				await shot("statuses")
				lam_an.cleanse(lam_an.statuses.active.keys())
				lam_an.heal(lam_an.max_health())
			"reactions":
				# Điện Giật arcing between soaked bandits, then Hỏa Lốc's fire whirl. Slow time keeps
				# the short bolts and the floating name on screen for a slow renderer.
				await place(-20, 66, 0, -0.25)
				var foes: Array[Enemy] = []
				for offset: Vector3 in [Vector3(0, 0, -4.5), Vector3(2.4, 0, -6.2), Vector3(-2.4, 0, -6.2)]:
					var foe: Enemy = EnemyFactory.create(ContentDB.enemy("tan_binh"))
					foe.setup({"id": "preview_reaction_%d" % foes.size(), "enemy": "tan_binh", "yaw": 180.0}, game.assets, game.world)
					game.add_child(foe)
					var point: Vector3 = game.player.global_position + offset
					point.y = game.world.height_at(point.x, point.z) + 0.05
					foe.activate(point, game.player)
					foe.set_physics_process(false)
					foe.max_health = 5000.0
					foe.health = 5000.0
					game.on_enemy_spawned(foe, {"id": foe.entity_id})
					foe.statuses.apply("soak", 1, 10.0)
					foe._tick_statuses(0.0)
					foes.append(foe)
				game.player.face_direction(Vector3(0, 0, -1), true)
				await frames(4)
				Engine.time_scale = 0.1
				game.player.strike(foes[0], {"mult": 1.0, "poise": 0, "knockback": 0.0, "hitstop": 0.0, "element": "thunder"}, 1.0)
				await frames(3)
				await shot("reaction_electrocharge")
				Engine.time_scale = 1.0
				await frames(90)
				foes[0].statuses.apply("gale", 1, 10.0)
				Engine.time_scale = 0.25
				game.player.strike(foes[0], {"mult": 1.0, "poise": 0, "knockback": 0.0, "hitstop": 0.0, "element": "flame"}, 1.0)
				await frames(12)
				await shot("reaction_firestorm")
				Engine.time_scale = 1.0
				for foe: Enemy in foes:
					foe.queue_free()
				await frames(30)
			"finisher":
				# Poise bars over a bandit just hit and a broken one (gold), the F prompt, the boss
				# bar's poise gauge; then the finisher's blow, slowed so it is caught mid-swing.
				await place(-20, 66, 0, -0.25)
				var guards: Array[Enemy] = []
				for offset: Vector3 in [Vector3(-1.6, 0, -4.2), Vector3(0.9, 0, -2.4)]:
					var guard: Enemy = EnemyFactory.create(ContentDB.enemy("tan_binh"))
					guard.setup({"id": "preview_poise_%d" % guards.size(), "enemy": "tan_binh", "yaw": 180.0}, game.assets, game.world)
					game.add_child(guard)
					var spot: Vector3 = game.player.global_position + offset
					spot.y = game.world.height_at(spot.x, spot.z) + 0.05
					guard.activate(spot, game.player)
					guard.set_physics_process(false)
					game.on_enemy_spawned(guard, {"id": guard.entity_id})
					guards.append(guard)
				var tap: Combat.Damage = Combat.make_damage(game.player, {"poise": guards[0].max_poise * 0.6, "knockback": 0.0, "hitstop": 0.0}, 4.0, guards[0].global_position)
				guards[0].take_damage(tap)
				guards[1].take_damage(Combat.make_damage(game.player, {"poise": 999, "knockback": 0.0, "hitstop": 0.0}, 4.0, guards[1].global_position))
				game.hud.show_boss("Trúc Tướng", "Kẻ gác rừng trúc", 0.72)
				game.hud.set_boss_poise(0.45, false, false)
				game.player.face_direction(Vector3(0.3, 0, -1), true)
				game.player.set_lock(guards[0])
				await frames(20)
				game._refresh_hud()
				await frames(2)
				await shot("poise_bars")
				game.hud.set_boss_poise(0.0, true, true)
				game.player.set_lock(null)
				game.player.start_finisher(guards[1])
				Engine.time_scale = 0.2
				for step: int in range(80):
					await frames(1)
					if game.player.action.get("fired", false):
						break
				await frames(2)
				await shot("finisher")
				Engine.time_scale = 1.0
				await frames(60)
				game.hud.hide_boss()
				for guard: Enemy in guards:
					if is_instance_valid(guard):
						guard.queue_free()
				await frames(30)
			"focus":
				# Tâm Nhãn: Lâm An rolls clear of a bandit's swing at the last instant; the cool veil
				# and its name come up while the bandit finishes the swing on its slowed clock.
				await place(-20, 66, 0, -0.25)
				var swordsman: Enemy = EnemyFactory.create(ContentDB.enemy("tan_binh"))
				swordsman.setup({"id": "preview_focus", "enemy": "tan_binh", "yaw": 180.0}, game.assets, game.world)
				game.add_child(swordsman)
				var stand: Vector3 = game.player.global_position + Vector3(0.3, 0, -2.0)
				stand.y = game.world.height_at(stand.x, stand.z) + 0.05
				swordsman.activate(stand, game.player)
				game.on_enemy_spawned(swordsman, {"id": swordsman.entity_id})
				await frames(4)
				swordsman._begin_attack("attack")
				for step: int in range(90):
					await frames(1)
					if swordsman.attack_clock >= float(swordsman.attack_data.get("hit_start", 0.7)) - 0.12:
						break
				game.hinted["focus"] = true  # the first-time hint would cover the bandit
				game.player.face_direction(Vector3(1, 0, 0.4), true)
				game.player._start_dodge()
				game.player.take_damage(Combat.make_damage(swordsman, swordsman.attack_data, 10.0, game.player.global_position))
				# Early: a slow renderer catches physics up several steps a frame, and the focus is short.
				await frames(2)
				await shot("focus")
				game.player.end_focus()
				swordsman.queue_free()
				await frames(40)
			"moves":
				await place(0, 14, 0)
				var side: Camera3D = Camera3D.new()
				side.fov = 40
				game.add_child(side)
				var p: PlayerController = game.player
				side.global_position = p.global_position + Vector3(4.2, 1.4, 0.0)
				side.look_at(p.global_position + Vector3(0, 1.0, 0))
				side.current = true
				game.state.unlock_skill("gust")
				game.state.unlock_skill("cyclone")
				# Pose each move at the middle of its damage window by seeking the clip directly,
				# so the frame matches data/anim_timings.json regardless of the render frame rate.
				var timings: Dictionary = ContentDB.get_data("timings").get("player", {})
				# The sword trail needs real playback: slow time so a slow renderer still samples the swing.
				Engine.time_scale = 0.05
				p._start_action("attack_2")
				for step: int in range(60):
					await frames(1)
					if p.visual.action_time >= float(timings.get("attack_2", {}).get("hit_end", 0.3)):
						break
				await shot("move_trail")
				Engine.time_scale = 1.0
				# Posed shots below freeze the player, so drop the ribbon left from the live swing.
				p.visual.stop_action()
				p.visual.trail.samples.clear()
				p.visual.trail.strip.clear_surfaces()
				p.process_mode = Node.PROCESS_MODE_DISABLED
				p.visual.set_sheathed(false)
				p.visual.tree.active = false
				for move: String in ["attack_1", "attack_2", "attack_3", "heavy", "skill_gust", "skill_cyclone", "parry", "dodge", "dash_slash", "ultimate"]:
					var timing: Dictionary = timings.get(move, {})
					var at: float = 0.1
					if timing.has("hit_start"):
						at = (float(timing["hit_start"]) + float(timing["hit_end"])) * 0.5
					p.visual.player.play(move)
					p.visual.player.seek(at, true)
					p.visual.player.pause()
					await frames(3)
					await shot("move_" + move)
				p.visual.player.stop()
				p.visual.tree.active = true
				p.process_mode = Node.PROCESS_MODE_PAUSABLE
				side.queue_free()
				game.player.camera_rig.camera.current = true
			"boss":
				game.state.set_flag("chimes_solved")
				game.spawner.arena.set_closed(false)
				await place(0, -324, 0, -0.18)
				game.player.invulnerable = 999.0
				await frames(30)
				var guardian: Enemy = game.spawner.node_for("boss_truc_tuong") as Enemy
				if guardian:
					guardian.global_position = game.player.global_position + Vector3(0, 0.2, -5.0)
					guardian._begin_attack("slam")
					await frames(40)
					await shot("boss_slam")
			"bamboo":
				await place(4, -128, 0, -0.18)
				await frames(30)
				await shot("bamboo")
			"gorge":
				await place(1, -243, 0, -0.3)
				await frames(30)
				await shot("gorge")
			"arena":
				await place(3, -300, 0, -0.2)
				await frames(30)
				await shot("arena")
			"map":
				game.open_panel("map")
				await frames(120)
				await shot("map")
				game.menus.close_panel()
				game.set_paused(false)
			"gacha":
				# A seeded ten-pull so the result cards show.
				game.profile.add_currency(Gacha.currency(), 1600)
				game.open_panel("gacha")
				game.menus.last_pull = game.gacha_pull(10)
				game.menus.refresh_panel()
				await frames(40)
				await shot("gacha")
				game.menus.close_panel()
				game.set_paused(false)
			"trial":
				game.trial.start(game.player.global_position)
				while game.trial.phase != "fighting" or game.trial.alive.size() < 3:
					await frames(1)
				var center: Vector3 = game.trial.center
				game.player.teleport(center + Vector3(0, 0.5, 12))
				game.player.face_direction(Vector3(0, 0, -1), true)
				game.player.camera_rig.yaw = 0.0
				game.player.camera_rig.pitch = -0.2
				game.player.invulnerable = 999.0
				await frames(60)
				await shot("trial_wave")
				for enemy: Enemy in game.trial.alive.duplicate():
					enemy.take_damage(Combat.make_damage(game.player, {"poise": 0}, 99999.0, enemy.global_position))
				while game.trial.phase != "picking":
					await frames(1)
				await frames(10)
				await shot("trial_pick")
				game.choose_trial_buff(game.menus.trial_choices[0])
				game.trial.end_run("leave")
				await frames(30)
			"shop":
				# Ông Lang Vân behind his stall, the HUD's heal counter and quick slot, then his counter
				# and a bag of consumables in the Inventory.
				await place(-10.2, 29.6, 75, -0.2)
				for entry: Array in [["kim_cang_dan", 2], ["giai_doc_thao", 3], ["tra_sen", 1], ["hoa_on_dan", 1]]:
					game.state.add_item(entry[0], entry[1])
				game.set_quick_item("kim_cang_dan")
				game.state.coins = 120
				await frames(30)
				game._refresh_hud()
				await shot("merchant")
				game.open_shop("quay_thuoc")
				game.buy_item("quay_thuoc", "tinh_tam_tra")
				game.menus.panel_note = "Đã mua Tịnh Tâm Trà  •  còn %d Đồng" % game.state.coins
				game.menus.panel_note_ok = true
				game.menus.refresh_panel()
				await frames(10)
				await shot("shop")
				game.menus.close_panel()
				game.menus.selected_item = "kim_cang_dan"
				game.open_panel("inventory")
				await frames(10)
				await shot("inventory_items")
				game.menus.close_panel()
				game.set_paused(false)
			"character":
				# The Nhân vật tab: a rolled sword, two Trial blessings and live buffs all in the totals.
				game.state.stats = PlayerStats.compute({"base": "sword_flame", "rarity": "sr", "affixes": [["attack_speed", 8], ["defense", 15]]}, {"lifesteal": 0.05, "poise_dmg": 0.3})
				game.player.apply_status("buff_atk")
				game.player.apply_status("weaken")
				game.menus.inventory_tab = 1
				game.open_panel("inventory")
				await frames(10)
				await shot("character")
				var sheet_tabs: TabContainer = game.menus.panel_body.find_child("InventoryTabs", true, false)
				(sheet_tabs.get_current_tab_control() as ScrollContainer).scroll_vertical = 10000
				await frames(5)
				await shot("character_more")
				game.menus.close_panel()
				game.menus.inventory_tab = 0
				game.player.cleanse(["buff_atk", "weaken"])
				game.refresh_stats()
				game.set_paused(false)
			"talismans":
				# The Ngọc bội tab: a worn Huyết Ngọc pair with one Lôi Văn piece, and a pouch of rolls.
				game.profile.talismans.clear()
				game.profile.talisman_equipped = Talismans.empty_slots()
				var rolls: RandomNumberGenerator = RandomNumberGenerator.new()
				rolls.seed = 2846
				for entry: Array in [["huyet_ngoc_thien", "ssr"], ["huyet_ngoc_dia", "sr"], ["loi_van_nhan", "sr"], ["kim_cuong_thien", "r"],
						["phong_linh_dia", "r"], ["loi_van_dia", "ssr"], ["phong_linh_nhan", "sr"], ["kim_cuong_nhan", "r"]]:
					var item: Dictionary = game.profile.add_talisman(Talismans.make(entry[0], entry[1], rolls))
					if game.profile.equipped_talismans().size() < 3:
						game.equip_talisman(int(item["uid"]))
				game.menus.armory_tab = 1
				game.open_panel("armory")
				await frames(10)
				await shot("talismans")
				game.menus.armory_tab = 0
				game.menus.inventory_tab = 1
				game.menus.close_panel()
				game.open_panel("inventory")
				await frames(10)
				await shot("talismans_character")
				game.menus.close_panel()
				game.menus.inventory_tab = 0
				game.set_paused(false)
			"journal", "inventory", "settings", "credits", "armory", "daily", "tier":
				game.open_panel(scene)
				await frames(10)
				await shot(scene)
				game.menus.close_panel()
				game.set_paused(false)
	if only.is_empty() or only.has("profile"):
		await profile()
	game.audio.stop_all()
	await create_timer(0.2, true, false, true).timeout
	game.queue_free()
	await process_frame
	quit(0)
