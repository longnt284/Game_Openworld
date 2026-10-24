extends SceneTree
## Dev tool: renders key viewpoints of the valley. Run with a rendering display (not --headless).

const VIEWS: Array = [
	["dock", Vector3(-20, 0, 66), Vector3(0, 0, 20), 9.0],
	["plaza", Vector3(10, 0, 40), Vector3(0, 0, 10), 10.0],
	["hill", Vector3(10, 0, -60), Vector3(4, 0, -115), 8.0],
	["bamboo", Vector3(6, 0, -135), Vector3(5, 0, -165), 6.0],
	["gorge", Vector3(4, 0, -236), Vector3(0, 0, -275), 7.0],
	["arena", Vector3(0, 0, -305), Vector3(0, 0, -334), 9.0],
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var settings: GameSettings = (load("res://config/default_settings.tres") as GameSettings).duplicate()
	var assets: AssetLibrary = AssetLibrary.new()
	assets.request_all()
	while not assets.poll():
		if not assets.failure.is_empty():
			push_error(assets.failure)
			quit(1)
			return
		await process_frame
	var root3d: Node3D = Node3D.new()
	root.add_child(root3d)
	var atmosphere: Atmosphere = Atmosphere.new()
	root3d.add_child(atmosphere)
	var anchor: Node3D = Node3D.new()
	root3d.add_child(anchor)
	var world: WorldManager = WorldManager.new()
	root3d.add_child(world)
	world.initialize(settings, assets, anchor)
	if OS.get_environment("NO_WATER").is_empty():
		var water: WaterBodies = WaterBodies.new()
		root3d.add_child(water)
		water.build(world.layout)
	if OS.get_environment("NO_BACKDROP").is_empty():
		var backdrop: Backdrop = Backdrop.new()
		root3d.add_child(backdrop)
		backdrop.build(Vector2(0, -180), settings.world_seed)
	var camera: Camera3D = Camera3D.new()
	camera.far = 1400
	camera.fov = 62
	root3d.add_child(camera)
	camera.current = true
	DirAccess.make_dir_recursive_absolute("res://.cache/world_preview")
	var only: String = OS.get_environment("VIEW")
	for view: Array in VIEWS:
		if not only.is_empty() and view[0] != only:
			continue
		var eye: Vector3 = view[1]
		var look: Vector3 = view[2]
		anchor.global_position = eye
		atmosphere.set_region(world.layout.region_at(eye.z).get("id", "ben_van_khe"))
		atmosphere.snap()
		for frame: int in range(90):
			await process_frame
		eye.y = world.height_at(eye.x, eye.z) + view[3]
		look.y = world.height_at(look.x, look.z) + 1.5
		camera.global_position = eye
		camera.look_at(look)
		for frame: int in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.cache/world_preview/%s.png" % view[0])
		print("VIEW ", view[0], " chunks=", world.active.size(), " build_ms=", world.last_build_ms)
	quit(0)
