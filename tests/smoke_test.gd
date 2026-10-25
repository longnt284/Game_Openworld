extends SceneTree
## Core integration checks kept from the base (world, movement, pause, streaming,
## checkpoint, saving) updated for the chapter systems.

var failures: int = 0
const TEST_SAVE: String = "user://smoke_test_save.json"

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

func settle(game: Node, max_frames: int = 3000) -> void:
	## Chunks build on worker threads, so wait for the streaming queue instead of a fixed frame count.
	for index: int in range(max_frames):
		var world: WorldManager = game.world
		if world.active.size() == game.settings.chunk_capacity() and world.building.is_empty() and world.pending.is_empty():
			break
		await frames(1)
	await frames(20)

func _run() -> void:
	var game: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	game.skip_title = true
	game.save_path = TEST_SAVE
	game.profile_path = "user://smoke_test_profile.json"
	root.add_child(game)
	for attempt: int in range(900):
		if game.initialized:
			break
		await frames(1)
	check(game.initialized, "Blender GLB assets load and game initializes")
	if not game.initialized:
		quit(1)
		return
	await settle(game)
	var world: WorldManager = game.world
	var player: PlayerController = game.player
	check(world.active.size() == game.settings.chunk_capacity(), "All nearby chunks load within bounded capacity")
	check(player.is_on_floor(), "Player stands on generated terrain collision")
	check(game.hud.region_label.get_global_rect().position.x > 0, "Tracker HUD is inside viewport")
	await _check_hud_layout(game)
	check(world.coord_at(Vector3(-0.1, 0, -32.1)) == Vector2i(-1, -2), "Negative world coordinates map to correct chunks")
	var second: WorldLayout = WorldLayout.load_default(game.settings.world_seed)
	check(is_equal_approx(world.height_at(18, -73), second.height_at(18, -73)) and is_equal_approx(world.height_at(-61, -150), second.height_at(-61, -150)), "Seed reproduces terrain")
	_check_flora(game, second)
	var center: Vector2i = world.coord_at(player.global_position)
	if not world.active.has(center) or not world.active.has(center + Vector2i(1, 0)):
		check(false, "Chunks around the player are active")
		quit(1)
		return
	var a: WorldChunk = world.active[center]
	var b: WorldChunk = world.active[center + Vector2i(1, 0)]
	var av: PackedVector3Array = a.ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var bv: PackedVector3Array = b.ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var edge_matches: bool = true
	var width: int = game.settings.subdivisions + 1
	for z: int in range(width):
		edge_matches = edge_matches and is_equal_approx(av[z * width + width - 1].y, bv[z * width].y)
	check(edge_matches, "Adjacent terrain meshes share identical boundary heights")
	var start: Vector3 = player.position
	Input.action_press("move_forward")
	await frames(30)
	var lag: float = player.visual.global_position.distance_to(player.global_position)
	var step: float = player.velocity.length() / Engine.physics_ticks_per_second
	Input.action_release("move_forward")
	await frames(12)
	check(player.position.distance_to(start) > 1.0, "WASD movement changes player position")
	check(step > 0.0 and lag <= step + 0.001,
		"The model is drawn between the last two physics steps (%.3f m behind, one step %.3f m)" % [lag, step])
	var ground_y: float = player.position.y
	player.queue_input("jump")
	await frames(8)
	check(player.position.y > ground_y + 0.2, "Jump lifts player above terrain")
	await frames(65)
	check(player.is_on_floor(), "Player lands after jump")
	game.set_paused(true)
	check(game.menus.pause_panel.visible and game.menus.pause_panel.get_global_rect().position.x > 0, "Pause menu is inside viewport")
	var paused_position: Vector3 = player.position
	Input.action_press("move_forward")
	await frames(5)
	check(player.position.is_equal_approx(paused_position), "Pause freezes gameplay")
	Input.action_release("move_forward")
	game.set_paused(false)
	var previous_chunk_ids: Array[int] = []
	for chunk: WorldChunk in world.active.values():
		previous_chunk_ids.append(chunk.get_instance_id())
	player.teleport(Vector3(60, world.height_at(60, -300) + 1, -300))
	await frames(2)
	await settle(game)
	check(world.active.size() == game.settings.chunk_capacity() and world.pool.is_empty(), "Teleport replaces distant chunks without growing pool")
	var reused: bool = true
	for chunk: WorldChunk in world.active.values():
		reused = reused and previous_chunk_ids.has(chunk.get_instance_id())
	check(reused, "Chunk nodes are reused across world streaming")
	check(player.is_on_floor(), "Collision remains valid after distant teleport")
	await _check_sliced(game)
	_check_resolution()
	var warmup: ShaderWarmup = ShaderWarmup.run(game, game.player.camera_rig.camera, game.assets)
	var drawn: int = warmup.drawn
	await frames(ShaderWarmup.FRAMES + 2)
	check(drawn > game.assets.scenes.size() and not is_instance_valid(warmup),
		"Shader warm-up draws every model and effect once (%d nodes), then frees itself" % drawn)
	player.teleport(Vector3(6, world.height_at(6, 27) + 0.6, 27))
	await frames(2)
	await settle(game)
	game.spawner.update_now()
	await frames(2)
	var shrine: Interactable = game.spawner.node_for("shrine_village") as Interactable
	check(shrine != null, "Village shrine streams in near the player")
	if shrine:
		game.on_interact(shrine)
		game.on_interact(shrine)
	check(game.state.checkpoint_id == "shrine_village" and game.state.checkpoints.size() == 1, "Nearby shrine activates checkpoint once")
	var saved_position: Vector3 = player.global_position
	check(game.save_game(), "Game saves through the main flow")
	world.reset_seed(999)
	game.state.checkpoint_id = ""
	player.teleport(Vector3(60, 10, 0))
	check(game.load_game(), "Game load succeeds")
	check(game.settings.world_seed == 284 and game.state.checkpoint_id == "shrine_village", "Game load restores world seed and checkpoint state")
	check(player.global_position.distance_to(saved_position) < 0.5, "Game load restores the saved player location")
	await frames(2)
	await settle(game)
	check(player.is_on_floor(), "Loaded game rebuilds playable terrain")
	var data: Dictionary = {"version": SaveStore.SCHEMA_VERSION, "seed": 284, "position": [1.0, 2.0, 3.0], "checkpoint": [4.0, 5.0, 6.0], "yaw": 0.0, "state": GameState.new().to_dict()}
	data.merge(WeatherDirector.initial_save(284))
	check(SaveStore.write_save(data, TEST_SAVE) == OK, "Save writes successfully")
	var restored: Dictionary = SaveStore.read_save(TEST_SAVE)
	check(not restored.is_empty() and SaveStore.to_vector(restored["position"]) == Vector3(1, 2, 3), "Save restores position and schema")
	data["position"] = [8.0, 9.0, 10.0]
	check(SaveStore.write_save(data, TEST_SAVE) == OK, "Second save preserves previous backup")
	var broken: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	broken.store_string("{broken json")
	broken.close()
	check(SaveStore.to_vector(SaveStore.read_save(TEST_SAVE)["position"]) == Vector3(1, 2, 3), "Corrupt save recovers previous valid backup")
	check(not SaveStore.validate({"version": 99}), "Unsupported save schema rejected")
	data["position"] = [NAN, 0, 0]
	check(not SaveStore.validate(data), "Nonfinite coordinates rejected")
	data["position"] = ["bad", 0, 0]
	check(not SaveStore.validate(data), "Non-numeric coordinates rejected")
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(TEST_SAVE + suffix):
			DirAccess.remove_absolute(TEST_SAVE + suffix)
	print("SMOKE RESULT: ", failures, " failure(s). Last chunk apply: ", world.last_build_ms, " ms")
	game.audio.stop_all()
	await create_timer(0.2, true, false, true).timeout
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _check_hud_layout(game: Node) -> void:
	## The boss bar, prompt and fixed HUD blocks never cover one another, even with long pill text.
	var hud: GameHUD = game.hud
	hud.quick_label.text = "C  •  Đan Hồi Nguyên ×12"
	hud.heal_label.text = "R  •  Bánh ngải ×12  •  Trà sen ×10"
	hud.show_boss("Khôi lỗi giữ đền", "Tượng đá thức giấc", 0.6, 840.0, 1400.0)
	await frames(3)
	hud.show_prompt("F  •  Kết liễu", UiTheme.GOLD)
	var blocks: Dictionary = {"tracker": hud.tracker_panel, "minimap": hud.minimap, "vitals": hud.vitals_frame, "pills": hud.quick_label, "heal": hud.heal_label,
		"skill e": hud.skill_boxes["e"]["panel"], "skill q": hud.skill_boxes["q"]["panel"], "skill x": hud.skill_boxes["x"]["panel"], "prompt": hud.prompt_panel}
	var clashes: Array[String] = []
	var boss: Rect2 = hud.boss_box.get_global_rect()
	var view: Rect2 = hud.get_viewport().get_visible_rect()
	for name: String in blocks:
		if (blocks[name] as Control).get_global_rect().intersects(boss):
			clashes.append(name)
	check(clashes.is_empty() and view.encloses(boss), "The boss bar sits clear of the other HUD blocks (clashes: %s)" % (", ".join(clashes) if not clashes.is_empty() else "none"))
	hud.hide_boss()
	hud.show_prompt("")
	game._refresh_hud()

func _check_sliced(game: Node) -> void:
	## Single-threaded web builds step each chunk a few ms per frame: same chunk, nothing stalls.
	var world: WorldManager = game.world
	var coord: Vector2i = Vector2i(-1, -5)
	var whole: Dictionary = WorldChunk.compute(coord, world.layout, game.settings.chunk_size, game.settings.subdivisions, game.settings.world_seed, 1.0, world.part_transforms)
	var job: ChunkJob = ChunkJob.new(coord, world.layout, game.settings.chunk_size, game.settings.subdivisions, game.settings.world_seed, 1.0, world.part_transforms)
	while not job.step(0):
		pass
	check(job.steps > 20 and str(job.result) == str(whole) and job.result == whole, "A chunk built in %d slices is identical to one built at once" % job.steps)
	world.sliced = true
	# Driven by hand here so each frame's streaming work (slices and uploads) can be timed.
	world.set_process(false)
	var player: PlayerController = game.player
	player.teleport(Vector3(-40, world.height_at(-40, -180) + 1, -180))
	var worst: float = 0.0
	var frames_taken: int = 0
	for index: int in range(3000):
		var started: int = Time.get_ticks_usec()
		world._process(0.0)
		var spent: float = (Time.get_ticks_usec() - started) / 1000.0
		if world.active.has(world.center):
			worst = maxf(worst, spent)
		frames_taken += 1
		await frames(1)
		if world.active.size() == game.settings.chunk_capacity() and world.building.is_empty() and world.pending.is_empty():
			break
	await frames(4)
	var here: Vector2i = world.coord_at(player.global_position)
	var expected: Dictionary = WorldChunk.compute(here, world.layout, game.settings.chunk_size, game.settings.subdivisions, game.settings.world_seed,
		world.density_scale, world.part_transforms)
	var built: WorldChunk = world.active.get(here)
	var same: bool = built != null and built.ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == expected["vertices"]
	check(world.active.size() == game.settings.chunk_capacity() and same and player.is_on_floor() and worst < WorldManager.NEAR_BUDGET_MS * 3.0,
		"Sliced streaming fills the view radius with the same terrain in %d frames (longest frame of work %.1f ms)" % [frames_taken, worst])
	world.sliced = false
	world.set_process(true)

func _check_resolution() -> void:
	## Web: a slow median lowers the 3D resolution a step; fast play or one long stall does not.
	var adaptive: AdaptiveResolution = AdaptiveResolution.new()
	root.add_child(adaptive)
	adaptive.set_process(false)
	var viewport: Viewport = adaptive.get_viewport()
	var before: float = viewport.scaling_3d_scale
	adaptive.reset(1.0)
	adaptive.active = true
	for index: int in range(200):
		adaptive.sample(1000.0 / 60.0)
	adaptive.sample(2000.0)
	var steady: bool = is_equal_approx(adaptive.scale, 1.0)
	for index: int in range(80):
		adaptive.sample(40.0)
	var lowered: bool = is_equal_approx(adaptive.scale, 0.9) and is_equal_approx(viewport.scaling_3d_scale, 0.9)
	for index: int in range(1000):
		adaptive.sample(40.0)
	var floored: bool = is_equal_approx(adaptive.scale, AdaptiveResolution.MIN_SCALE)
	adaptive.reset(0.85)
	check(steady and lowered and floored and is_equal_approx(adaptive.scale, 0.85),
		"Adaptive resolution steps down only while play runs slow, never below %.1f, and a preset restarts it" % AdaptiveResolution.MIN_SCALE)
	viewport.scaling_3d_scale = before
	adaptive.free()

func _check_flora(game: Node, layout: WorldLayout) -> void:
	var size: int = game.settings.chunk_size
	var subdiv: int = game.settings.subdivisions
	var seed: int = game.settings.world_seed
	var coord: Vector2i = Vector2i(0, -3)
	var full: Dictionary = WorldChunk.compute(coord, layout, size, subdiv, seed, 1.0)
	var again: Dictionary = WorldChunk.compute(coord, layout, size, subdiv, seed, 1.0)
	var half: Dictionary = WorldChunk.compute(coord, layout, size, subdiv, seed, 0.5)
	var total: int = 0
	var stable: bool = true
	var colliders_kept: bool = true
	for kind: String in full["flora"]:
		total += (full["flora"][kind] as Array).size()
		stable = stable and str(full["flora"][kind]) == str(again["flora"][kind])
		var rule: Dictionary = layout.flora[kind]
		if not rule.get("dense", false):
			colliders_kept = colliders_kept and str(full["flora"][kind]) == str(half["flora"][kind])
	check(total > 40, "Flora scatters densely in a forest chunk (%d instances)" % total)
	check(stable, "Flora placement is deterministic per chunk")
	check(colliders_kept, "Lower quality thins only ground cover; trees and rocks stay put")
	var keepout_clear: bool = not layout.keepouts.is_empty()
	for cell: Vector2i in layout.keepouts:
		for keepout: Array in layout.keepouts[cell]:
			if keepout[2]:
				continue
			var center: Vector2 = keepout[0]
			var chunk: Vector2i = Vector2i(floori(center.x / size), floori(center.y / size))
			var data: Dictionary = WorldChunk.compute(chunk, layout, size, subdiv, seed, 1.0)
			for kind: String in data["flora"]:
				for entry: Array in data["flora"][kind]:
					var origin: Vector3 = (entry[0] as Transform3D).origin + Vector3(chunk.x * size, 0, chunk.y * size)
					if Vector2(origin.x, origin.z).distance_to(center) < float(keepout[1]) * 0.5:
						keepout_clear = false
			break
		break
	check(keepout_clear, "Keep-outs around NPCs, chests and shrines stay free of flora")
	var presets: Dictionary = UserSettings.QUALITY
	check(presets.has("low") and presets.has("medium") and presets.has("high"), "Low, Medium and High quality presets exist")
	var scaled: bool = true
	for key: String in ["rain", "lights"]:
		scaled = scaled and float(presets["low"][key]) < float(presets["medium"][key]) and float(presets["medium"][key]) < float(presets["high"][key])
	# Low keeps a sparse rain curtain (the Web build shows rain) but no lantern lights.
	scaled = scaled and float(presets["low"]["rain"]) > 0.0 and int(presets["low"]["lights"]) == 0
	check(float(presets["low"]["density"]) < float(presets["medium"]["density"]) and float(presets["medium"]["density"]) < float(presets["high"]["density"])
		and int(presets["high"]["view_radius"]) >= int(presets["medium"]["view_radius"]) and scaled,
		"Quality presets scale density, view distance, rain (sparse on Low) and lantern lights (none on Low)")
