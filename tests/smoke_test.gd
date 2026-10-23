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
	Input.action_release("move_forward")
	await frames(12)
	check(player.position.distance_to(start) > 1.0, "WASD movement changes player position")
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
		scaled = scaled and float(presets["low"][key]) == 0.0 and float(presets["low"][key]) < float(presets["medium"][key]) and float(presets["medium"][key]) < float(presets["high"][key])
	check(float(presets["low"]["density"]) < float(presets["medium"]["density"]) and float(presets["medium"]["density"]) < float(presets["high"]["density"])
		and int(presets["high"]["view_radius"]) >= int(presets["medium"]["view_radius"]) and scaled,
		"Quality presets scale density, view distance, rain and lantern lights (none on Low)")
