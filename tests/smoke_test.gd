extends SceneTree

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

func _run() -> void:
	var game: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	for attempt: int in range(600):
		if game.initialized:
			break
		await frames(1)
	check(game.initialized, "Blender GLB assets load and game initializes")
	if not game.initialized:
		quit(1)
		return
	await frames(80)
	var world: WorldManager = game.world
	var player: PlayerController = game.player
	check(world.active.size() == game.settings.chunk_capacity(), "All nearby chunks load within bounded capacity")
	check(player.is_on_floor(), "Player stands on generated terrain collision")
	check(game.hud.status.get_global_rect().position.x > 0, "Status HUD is inside viewport")
	check(world.coord_at(Vector3(-0.1, 0, -32.1)) == Vector2i(-1, -2), "Negative world coordinates map to correct chunks")
	var initial_height: float = world.height_at(18, -73)
	var second_noise: FastNoiseLite = FastNoiseLite.new()
	second_noise.seed = world.noise.seed
	second_noise.noise_type = world.noise.noise_type
	second_noise.frequency = world.noise.frequency
	second_noise.fractal_octaves = world.noise.fractal_octaves
	second_noise.fractal_type = world.noise.fractal_type
	check(is_equal_approx(initial_height, second_noise.get_noise_2d(18, -73) * game.settings.terrain_amplitude), "Seed reproduces terrain")
	var a: WorldChunk = world.active[Vector2i(0, 0)]
	var b: WorldChunk = world.active[Vector2i(1, 0)]
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
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(6)
	check(player.position.y > ground_y + 0.2, "Jump lifts player above terrain")
	await frames(65)
	check(player.is_on_floor(), "Player lands after jump")
	game.set_paused(true)
	check(game.hud.pause_panel.get_global_rect().position.x > 0, "Pause menu is inside viewport")
	var paused_position: Vector3 = player.position
	Input.action_press("move_forward")
	await frames(5)
	check(player.position.is_equal_approx(paused_position), "Pause freezes gameplay")
	Input.action_release("move_forward")
	game.set_paused(false)
	var previous_chunk_ids: Array[int] = []
	for chunk: WorldChunk in world.active.values():
		previous_chunk_ids.append(chunk.get_instance_id())
	player.teleport(Vector3(400, world.height_at(400, -400) + 1, -400))
	await frames(80)
	check(world.active.size() == game.settings.chunk_capacity() and world.pool.is_empty(), "Teleport replaces distant chunks without growing pool")
	var reused: bool = true
	for chunk: WorldChunk in world.active.values():
		reused = reused and previous_chunk_ids.has(chunk.get_instance_id())
	check(reused, "Chunk nodes are reused across world streaming")
	check(player.is_on_floor(), "Collision remains valid after distant teleport")
	player.teleport(game.beacon.position + Vector3(0, 0.6, 2))
	await frames(80)
	check(game.activate_beacon(), "Nearby beacon activates checkpoint")
	check(not game.activate_beacon(), "Checkpoint activation is idempotent")
	game.save_path = TEST_SAVE
	var saved_position: Vector3 = player.position
	game.save_game()
	world.reset_seed(999)
	player.teleport(Vector3(600, 10, 600))
	game.load_game()
	check(game.settings.world_seed == 284 and game.beacon_active, "Game load restores world seed and checkpoint state")
	check(player.position.distance_to(saved_position) < 0.3, "Game load restores the saved player location")
	await frames(80)
	check(player.is_on_floor(), "Loaded game rebuilds playable terrain")
	var data: Dictionary = {"version": 1, "seed": 284, "position": [1.0, 2.0, 3.0], "checkpoint": [4.0, 5.0, 6.0], "beacon_active": true}
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
	print("SMOKE RESULT: ", failures, " failure(s). Last chunk build: ", world.last_build_ms, " ms")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
