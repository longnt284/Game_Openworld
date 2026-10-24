extends Node3D
## Deterministic in-engine art review. No game state or player saves are loaded.
var camera: Camera3D
var sun: DirectionalLight3D
var environment: Environment
var hero: Node3D
var village: Node3D
var animation: AnimationPlayer
var output: String = "res://docs/visual-upgrade/prototype"

func asset(path: String, position_at: Vector3, parent: Node3D) -> Node3D:
	var model: Node3D = (load("res://assets/models/" + path + ".glb") as PackedScene).instantiate()
	parent.add_child(model)
	model.position = position_at
	Toon.apply_to_scene(model, path.begins_with("characters"), Toon.is_foliage(path))
	return model

func box(size: Vector3, at: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = Toon.flat_material(color)
	village.add_child(node)
	node.position = at

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	village = Node3D.new()
	add_child(village)
	box(Vector3(24,0.15,28),Vector3(0,-0.15,-3),Color("72a550"))
	box(Vector3(6,0.04,26),Vector3(0,-0.045,-3),Color("d8b477"))
	asset("env/house_small",Vector3(-6,0,-5),village)
	asset("env/well",Vector3(4,0,-3),village)
	asset("env/market_stall",Vector3(-4,0,2),village)
	asset("env/lantern_post",Vector3(3.5,0,3),village)
	asset("env/bamboo_cluster",Vector3(-9,0,-8),village)
	asset("env/tree_maple",Vector3(7,0,-8),village)
	hero = asset("characters/lam_an",Vector3.ZERO,self)
	for node: Node in Toon._walk(hero):
		if node is AnimationPlayer:
			animation = node
		if node.name == "SheathSocket":
			asset("weapons/sword_old",Vector3.ZERO,node as Node3D)
	var world := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("a3cce3")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c2d7e2")
	environment.ambient_light_energy = 0.3
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-32,0)
	sun.light_color = Color("fff0d6")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 55
	add_child(camera)
	camera.current = true
	get_viewport().msaa_3d = Viewport.MSAA_4X
	await frames(20)
	if not OS.get_cmdline_user_args().has("--capture"):
		camera.position = Vector3(0,3.1,7)
		camera.look_at(Vector3(0,1.3,-3))
		return
	print("ART_REVIEW_GPU ", RenderingServer.get_video_adapter_name())
	village.visible = false
	for view: Array in [["front",Vector3(0,1.1,3.3)],["back",Vector3(0,1.1,-3.3)],["side",Vector3(3.3,1.1,0)],["three_quarter",Vector3(2,1.4,3)]]:
		camera.position = view[1]
		camera.look_at(Vector3(0,0.95,0))
		await capture("lam_an_"+str(view[0]))
	for clip: String in ["run","dodge","block","attack_2","skill_cyclone","air_leap","glide"]:
		if not animation.has_animation(clip):
			push_error("Missing animation: "+clip)
			get_tree().quit(1)
			return
		animation.play(clip)
		animation.seek(animation.get_animation(clip).length*0.45,true)
		animation.pause()
		await capture("pose_"+clip)
	animation.play("idle")
	animation.seek(0,true)
	animation.pause()
	village.visible = true
	hero.rotation.y = PI
	camera.position = Vector3(0,3.1,7)
	camera.look_at(Vector3(0,1.3,-3))
	await capture("village_day")
	sun.light_color = Color("ffd2a0")
	sun.light_energy = 0.75
	sun.rotation_degrees.x = -20
	environment.background_color = Color("d1b8ad")
	await capture("village_dusk")
	get_tree().quit()

func frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame

func capture(label: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+label+".png")
	print("ART_SHOT ",label," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
