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
		quit(0)
		return
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	game.skip_title = true
	game.save_path = "user://render_preview_save.json"
	root.add_child(game)
	while not game.initialized:
		await frames(1)
	game.hud.close_vision()
	game._on_vision_closed()
	await settle()
	var scenes: Array[String] = ["dock", "village", "dialogue", "combat", "bamboo", "gorge", "arena", "map", "journal"]
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
			"bamboo":
				await place(4, -128, 180, -0.18)
				await frames(30)
				await shot("bamboo")
			"gorge":
				await place(1, -243, 180, -0.3)
				await frames(30)
				await shot("gorge")
			"arena":
				game.state.set_flag("chimes_solved")
				game.spawner.arena.set_closed(false)
				await place(0, -316, 180, -0.2)
				await frames(60)
				await place(0, -326, 180, -0.22)
				await frames(60)
				await shot("arena")
			"map":
				game.open_panel("map")
				await frames(120)
				await shot("map")
				game.menus.close_panel()
				game.set_paused(false)
			"journal":
				game.open_panel("journal")
				await frames(10)
				await shot("journal")
				game.menus.close_panel()
				game.set_paused(false)
	if only.is_empty() or only.has("profile"):
		await place(-20, 70.5, 0)
		var samples: Array[float] = []
		var previous: int = Time.get_ticks_usec()
		Input.action_press("move_forward")
		for frame: int in range(300):
			await process_frame
			var now: int = Time.get_ticks_usec()
			samples.append((now - previous) / 1000.0)
			previous = now
		Input.action_release("move_forward")
		samples.sort()
		print("PROFILE: 300 rendered frames | p50 ms=", samples[150], " | p95 ms=", samples[284], " | static MB=", Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	game.queue_free()
	await process_frame
	quit(0)
