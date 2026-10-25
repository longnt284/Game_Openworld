extends SceneTree
## Prebakes every encounter navmesh of the default valley into assets/nav/ (see NavBake), so the
## single-threaded web build never stalls on a Recast bake. Run after editing the terrain, props,
## flora or navzones:  tools/run.sh navbake   (add "-- --check" to only compare with the shipped files)
## Each zone is baked with the whole view radius streamed in around its centre.

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var check_only: bool = OS.get_cmdline_user_args().has("--check")
	var game: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	game.skip_title = true
	game.save_path = "user://navbake_save.json"
	game.profile_path = "user://navbake_profile.json"
	root.add_child(game)
	for attempt: int in range(900):
		if game.initialized:
			break
		await process_frame
	if not game.initialized:
		push_error("Game did not initialize")
		quit(1)
		return
	# Nothing but the ground matters here: no foes, NPCs or live bakes of the zones.
	game.spawner.set_process(false)
	game.player.invulnerable = 1.0e9
	var world: WorldManager = game.world
	var ids: Array[String] = []
	for zone: Dictionary in NavBake.zones():
		var id: String = String(zone["id"])
		var center: Vector2 = Vector2(float(zone["pos"][0]), float(zone["pos"][1]))
		game.player.teleport(Vector3(center.x, world.height_at(center.x, center.y) + 1.0, center.y))
		await _settle(game)
		var half: float = float(zone.get("size", 40.0)) * 0.5
		for corner: Vector2 in [Vector2(-half, -half), Vector2(half, -half), Vector2(-half, half), Vector2(half, half)]:
			if not world.is_position_ready(Vector3(center.x + corner.x, 0, center.y + corner.y)):
				push_error("%s: ground around the zone did not stream in" % id)
				failures += 1
		var mesh: NavigationMesh = NavBake.make_mesh(zone, world.height_at(center.x, center.y))
		var source: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(mesh, source, game)
		NavigationServer3D.bake_from_source_geometry_data(mesh, source)
		if mesh.get_polygon_count() == 0:
			push_error("%s: baked no polygons" % id)
			failures += 1
		if check_only:
			var shipped: NavigationMesh = load(NavBake.path(id)) as NavigationMesh if ResourceLoader.exists(NavBake.path(id)) else null
			var same: bool = shipped != null and shipped.get_vertices() == mesh.get_vertices() and shipped.get_polygon_count() == mesh.get_polygon_count()
			print("%s %s: %d polygons" % ["OK  " if same else "STALE", id, mesh.get_polygon_count()])
			if not same:
				failures += 1
		else:
			var error: Error = ResourceSaver.save(mesh, NavBake.path(id), ResourceSaver.FLAG_COMPRESS)
			print("%s: %d polygons, %d vertices%s" % [id, mesh.get_polygon_count(), mesh.get_vertices().size(), "" if error == OK else " (SAVE FAILED)"])
			if error != OK:
				failures += 1
		ids.append(id)
	if check_only:
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(NavBake.MANIFEST)) if FileAccess.file_exists(NavBake.MANIFEST) else null
		if not (manifest is Dictionary and String(manifest.get("fingerprint", "")) == NavBake.fingerprint()):
			print("STALE manifest: the world data changed since the bake")
			failures += 1
	elif failures == 0:
		var file: FileAccess = FileAccess.open(NavBake.MANIFEST, FileAccess.WRITE)
		file.store_string(JSON.stringify({"format": NavBake.FORMAT, "seed": game.settings.world_seed, "fingerprint": NavBake.fingerprint(), "zones": ids}, "\t") + "\n")
		file.close()
	print("NAVBAKE RESULT: %d failure(s)" % failures)
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _settle(game: Node) -> void:
	var world: WorldManager = game.world
	for index: int in range(3000):
		await physics_frame
		await process_frame
		if world.active.size() == game.settings.chunk_capacity() and world.building.is_empty() and world.pending.is_empty() and world.is_position_ready(game.player.global_position):
			break
	for index: int in range(4):
		await physics_frame
