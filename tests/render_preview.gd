extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	for frame: int in range(180):
		await process_frame
	if not game.initialized:
		quit(1)
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.cache")
	var error: Error = root.get_texture().get_image().save_png("res://.cache/preview.png")
	print("PREVIEW: ", error_string(error), " | FPS: ", Engine.get_frames_per_second(), " | draw calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("PLAYER: ", game.player.position, " floor=", game.player.is_on_floor())
	print("HUD: ", game.hud.status.get_global_rect(), " parent=", game.hud.status.get_parent().get_global_rect())
	var samples: Array[float] = []
	var max_chunk_ms: float = 0.0
	var started: Vector3 = game.player.position
	var previous: int = Time.get_ticks_usec()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for frame: int in range(600):
		await process_frame
		var now: int = Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
		max_chunk_ms = maxf(max_chunk_ms, game.world.last_build_ms)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	samples.sort()
	print("PROFILE: 600 rendered frames | p95 wall frame ms=", samples[569], " | max chunk build ms=", max_chunk_ms, " | distance m=", started.distance_to(game.player.position), " | active chunks=", game.world.active.size())
	game.queue_free()
	await process_frame
	quit(error)
