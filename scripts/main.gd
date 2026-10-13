extends Node3D

@export var save_path: String = SaveStore.SAVE_PATH
var settings: GameSettings = preload("res://config/default_settings.tres").duplicate() as GameSettings
var assets: AssetLibrary = AssetLibrary.new()
var player: PlayerController
var world: WorldManager
var hud: GameHUD
var sun: DirectionalLight3D
var beacon: Node3D
var checkpoint: Vector3
var beacon_active: bool = false
var initialized: bool = false
var day_phase: float = 0.18
var hud_elapsed: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud = GameHUD.new()
	add_child(hud)
	hud.resume_requested.connect(func() -> void: set_paused(false))
	hud.save_requested.connect(save_game)
	hud.load_requested.connect(load_game)
	_build_lighting()
	assets.request_all()

func _build_lighting() -> void:
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("6397ab")
	sky_material.sky_horizon_color = Color("d6d8b7")
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky_material.ground_bottom_color = Color("60755e")
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c3d5ce")
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color("bcc7ad")
	environment.fog_density = 0.014
	environment_node.environment = environment
	add_child(environment_node)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.light_color = Color("ffe0a6")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70
	add_child(sun)

func _start_world() -> void:
	player = PlayerController.new()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.initialize(settings)
	world = WorldManager.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.initialize(settings, assets, player)
	player.world = world
	checkpoint = Vector3(0, world.height_at(0, 5) + 0.6, 5)
	player.teleport(checkpoint)
	beacon = (assets.scenes["beacon"] as PackedScene).instantiate() as Node3D
	add_child(beacon)
	_place_beacon()
	initialized = true
	if DisplayServer.get_name() != "headless" and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _place_beacon() -> void:
	beacon.position = Vector3(3, world.height_at(3, -8), -8)

func _process(delta: float) -> void:
	if not initialized:
		if assets.poll():
			_start_world()
		elif not assets.failure.is_empty():
			hud.status.text = assets.failure
		return
	if not get_tree().paused:
		day_phase = fmod(day_phase + delta / settings.day_length_seconds, 1.0)
		sun.rotation.x = -PI * day_phase
		sun.light_energy = maxf(0.18, sin(day_phase * PI)) * 0.8
		if player.position.y < -30:
			respawn()
	hud_elapsed += delta
	if hud_elapsed >= 0.15:
		hud_elapsed = 0.0
		hud.status.text = "%d FPS  •  %d/%d vùng\nX %.0f   Z %.0f   •   Seed %d" % [Engine.get_frames_per_second(), world.active.size(), settings.chunk_capacity(), player.position.x, player.position.z, settings.world_seed]
		hud.prompt.text = "E  •  Kích hoạt trạm ánh sáng" if can_interact() else ""
		hud.objective.text = "Trạm đã mở • Tiếp tục khám phá thung lũng" if beacon_active else "Tìm trạm ánh sáng trong thung lũng"

func can_interact() -> bool:
	return initialized and not beacon_active and player.position.distance_to(beacon.position) < 4.0

func activate_beacon() -> bool:
	if not can_interact():
		return false
	beacon_active = true
	checkpoint = beacon.position + Vector3(0, 0.7, 3)
	hud.show_message("Đã mở trạm • Nhấn R để trở về")
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
		return
	if not initialized or get_tree().paused:
		return
	if event.is_action_pressed("interact"):
		activate_beacon()
	elif event.is_action_pressed("save_game"):
		save_game()
	elif event.is_action_pressed("load_game"):
		load_game()
	elif event.is_action_pressed("respawn"):
		respawn()

func set_paused(value: bool) -> void:
	get_tree().paused = value
	hud.set_paused(value)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED

func respawn() -> void:
	player.teleport(checkpoint)
	hud.show_message("Đã trở về điểm xuất phát" if not beacon_active else "Đã trở về trạm ánh sáng")

func save_game() -> void:
	if not initialized:
		return
	var data: Dictionary = {"version": SaveStore.SCHEMA_VERSION, "seed": settings.world_seed, "position": SaveStore.to_array(player.position), "checkpoint": SaveStore.to_array(checkpoint), "beacon_active": beacon_active}
	var error: Error = SaveStore.write_save(data, save_path)
	hud.show_message("Đã lưu hành trình" if error == OK else "Không thể lưu: " + error_string(error))

func load_game() -> void:
	if not initialized:
		return
	var data: Dictionary = SaveStore.read_save(save_path)
	if data.is_empty():
		hud.show_message("Chưa có bản lưu hợp lệ")
		return
	world.reset_seed(int(data["seed"]))
	checkpoint = SaveStore.to_vector(data["checkpoint"])
	beacon_active = bool(data["beacon_active"])
	var location: Vector3 = SaveStore.to_vector(data["position"])
	location.y = maxf(location.y, world.height_at(location.x, location.z) + 0.2)
	player.teleport(location)
	_place_beacon()
	set_paused(false)
	hud.show_message("Đã tải hành trình")
