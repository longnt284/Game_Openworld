extends Node3D
## Game root: wires world streaming, player, entities, quests, dialogue, UI, audio
## and saving together. Gameplay rules live in their own classes.

const ECHO_COUNT: int = 3

@export var save_path: String = SaveStore.SAVE_PATH
@export var profile_path: String = PlayerProfile.PATH
@export var skip_title: bool = false
var settings: GameSettings = preload("res://config/default_settings.tres").duplicate() as GameSettings
var user_settings: UserSettings = UserSettings.new()
var assets: AssetLibrary = AssetLibrary.new()
var state: GameState = GameState.new()
var profile: PlayerProfile
var quests: QuestManager
var audio: AudioDirector
var atmosphere: Atmosphere
var ambient: AmbientFx
var weather: WeatherDirector
var rain: RainFx
var storm: StormDirector
var night_lights: NightLights
## Weather bed shares handed to the AudioDirector every frame (reused, no allocation).
var weather_beds: Dictionary = {"rain_light": 0.0, "rain_heavy": 0.0, "storm_wind": 0.0, "night_insects": 0.0}
var player: PlayerController
var world: WorldManager
var spawner: EntitySpawner
var props: PropPlacer
var trial: TrialDirector
var hud: GameHUD
var menus: Menus
var title_camera: Camera3D
var initialized: bool = false
var playing: bool = false
var in_title: bool = false
var mode: String = "boot"
var hud_elapsed: float = 0.0
var autosave_timer: float = 300.0
var current_region: String = ""
var focus: Node3D
var dialogue: Dictionary = {}
var vision_callback: Callable
var chime_sequence: Array[int] = []
var title_angle: float = 0.0
var hinted: Dictionary = {}
var engaged: int = 0
var death_serial: int = 0
## Browser build: no quit, fullscreen only from a click, Esc releases the pointer first.
var web: bool = OS.has_feature("web")
var had_pointer: bool = false
var announced_ready: bool = false
## World Tier elites and reward-chest drops (not the gacha: that RNG lives in the profile).
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	user_settings.load_file()
	user_settings.apply_input()
	profile = PlayerProfile.load_file(profile_path)
	audio = AudioDirector.new()
	audio.name = "Audio"
	add_child(audio)
	audio.apply_volumes(user_settings)
	atmosphere = Atmosphere.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	quests = QuestManager.new()
	quests.name = "Quests"
	add_child(quests)
	quests.setup(state, give_rewards)
	quests.quest_started.connect(_on_quest_started)
	quests.quest_completed.connect(_on_quest_completed)
	hud = GameHUD.new()
	add_child(hud)
	hud.dialogue_advanced.connect(_advance_dialogue)
	hud.choice_selected.connect(_choose_dialogue)
	hud.vision_closed.connect(_on_vision_closed)
	menus = Menus.new()
	add_child(menus)
	menus.setup(self)
	menus.new_game_requested.connect(start_new_game)
	menus.continue_requested.connect(continue_game)
	menus.resume_requested.connect(func() -> void: set_paused(false))
	menus.save_requested.connect(save_game)
	menus.load_requested.connect(load_game)
	menus.checkpoint_requested.connect(func() -> void:
		if trial and trial.active:
			hud.show_message("Hãy rời Ải Vô Tận trước")
		elif engaged > 0 or spawner.arena.fighting:
			hud.show_message("Không thể về Miếu Gió khi đang giao chiến")
		else:
			respawn())
	menus.title_requested.connect(return_to_title)
	menus.settings_changed.connect(apply_settings)
	menus.quit_requested.connect(quit_game)
	state.changed.connect(_on_state_changed)
	rng.randomize()
	if not profile.welcomed:
		# First run: enough Ngọc Gió for one ten-pull, so the Kỳ Ngộ banner can be tried at once.
		profile.welcomed = true
		profile.add_currency(Gacha.currency(), int(Gacha.data().get("welcome", 0)))
	Missions.refresh(profile, Missions.today())
	save_profile()
	hud.set_tracker("Vân Khê", "", "Đang tải thung lũng…")
	assets.request_all()

func _exit_tree() -> void:
	MapView.shutdown()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and web and initialized and playing and engaged == 0:
		# A closed tab gives no warning, so the browser build saves whenever it loses focus.
		save_game(true)

func quit_game() -> void:
	## Lets the audio server release its streams before the tree is torn down.
	if web:
		# Quitting would leave a frozen canvas in the page; go back to the title instead.
		if playing:
			return_to_title()
		return
	audio.stop_all()
	await get_tree().create_timer(0.2, true, false, true).timeout
	get_tree().quit()

func _start_world() -> void:
	player = PlayerController.new()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.initialize(settings, assets, state)
	settings.view_radius = int(user_settings.preset()["view_radius"])
	world = WorldManager.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.add_to_group(EntitySpawner.NAV_SOURCE)
	add_child(world)
	world.initialize(settings, assets, player)
	player.world = world
	var water: WaterBodies = WaterBodies.new()
	water.name = "Water"
	add_child(water)
	water.build(world.layout)
	var backdrop: Backdrop = Backdrop.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	backdrop.build(Vector2(0, -180), settings.world_seed, assets)
	atmosphere.haze_changed.connect(backdrop.set_haze)
	atmosphere.light_changed.connect(backdrop.set_light)
	backdrop.set_haze(atmosphere.haze())
	backdrop.set_light(atmosphere.light_tint())
	props = PropPlacer.new()
	props.name = "Props"
	props.add_to_group(EntitySpawner.NAV_SOURCE)
	add_child(props)
	props.build(assets, world.layout)
	spawner = EntitySpawner.new()
	spawner.name = "Entities"
	spawner.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(spawner)
	spawner.setup(self, assets, world, player)
	spawner.arena.fight_started.connect(_on_fight_started)
	trial = TrialDirector.new()
	trial.name = "Trial"
	add_child(trial)
	trial.setup(self)
	trial.run_finished.connect(_on_trial_finished)
	MapView.prepare(world.layout)
	ambient = AmbientFx.new()
	ambient.name = "AmbientFx"
	add_child(ambient)
	ambient.target = player
	atmosphere.light_changed.connect(ambient.set_light)
	ambient.set_light(atmosphere.light_tint())
	weather = WeatherDirector.new()
	weather.name = "Weather"
	add_child(weather)
	quests.weather = weather
	rain = RainFx.new()
	rain.name = "Rain"
	add_child(rain)
	rain.target = player
	atmosphere.light_changed.connect(rain.set_light)
	rain.set_light(atmosphere.light_tint())
	storm = StormDirector.new()
	storm.name = "Storm"
	add_child(storm)
	storm.setup(self)
	night_lights = NightLights.new()
	night_lights.name = "NightLights"
	add_child(night_lights)
	night_lights.setup(props.lights, atmosphere, player)
	player.health_changed.connect(func(_c: float, _m: float) -> void: _refresh_vitals())
	player.stamina_changed.connect(func(_c: float, _m: float) -> void: _refresh_vitals())
	player.died.connect(_on_player_died)
	player.hazard.connect(_on_hazard)
	player.footstep.connect(_on_footstep)
	player.attack_landed.connect(_on_attack_landed)
	player.parried.connect(func(_enemy: Node) -> void:
		audio.play("parry", player.global_position + Vector3.UP, 2.0)
		_mission("parry"))
	player.notice.connect(func(text: String) -> void: hud.show_message(text, 2.0))
	player.skill_used.connect(_on_skill_used)
	player.status_applied.connect(func(_status: String) -> void: _mission("status"))
	player.finisher_landed.connect(_on_finisher_landed)
	player.focus_started.connect(_on_focus_started)
	player.focus_ended.connect(func() -> void: hud.set_focus(false))
	player.statuses_changed.connect(_on_player_statuses)
	_equip_visuals()
	title_camera = Camera3D.new()
	title_camera.far = 1500
	title_camera.fov = 55
	add_child(title_camera)
	player.teleport(_start_position())
	player.face_direction(Vector3(0, 0, -1), true)
	initialized = true
	apply_settings()
	if skip_title or DisplayServer.get_name() == "headless":
		start_new_game()
	else:
		show_title()

func _start_position() -> Vector3:
	var start: Array = ContentDB.get_data("entities").get("start", {}).get("pos", [-20, 71])
	return Vector3(float(start[0]), world.height_at(float(start[0]), float(start[1])) + 0.3, float(start[1]))

# ------------------------------------------------------------------ flow

func show_title() -> void:
	in_title = true
	playing = false
	mode = "title"
	get_tree().paused = false
	player.input_enabled = false
	player.state = "disabled"
	hud.set_gameplay_visible(false)
	hud.close_dialogue()
	# The title always shows the valley's fair reference afternoon, whatever the clock says.
	_follow_weather(null)
	title_camera.current = true
	menus.show_title(SaveStore.has_save(save_path))
	audio.set_music("title", 1.5)
	audio.set_ambience("wind")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not announced_ready:
		announced_ready = true
		print("VK_READY")

func _begin_play() -> void:
	in_title = false
	playing = true
	mode = "play"
	menus.hide_title()
	hud.set_gameplay_visible(true)
	player.input_enabled = true
	if player.state == "disabled":
		player.state = "move"
	player.camera_rig.camera.current = true
	_follow_weather(weather)
	current_region = ""
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _follow_weather(director: WeatherDirector) -> void:
	## The sky, the rain, the lightning and the gale follow the clock only in play; null (the
	## title screen) shows the fair reference afternoon, dry and calm. Warned strikes are dropped.
	atmosphere.follow(director)
	rain.follow(director)
	storm.follow(director)
	ambient.follow(director)

func start_new_game() -> void:
	death_serial += 1
	_close_dialogue()
	_abort_trial()
	_clear_reward_chests()
	if spawner.arena.fighting:
		spawner.arena.end_fight(false)
	hud.hide_boss()
	hud.fade_to(0.0, 0.3)
	state.from_dict(GameState.new().to_dict())
	state.health = state.max_health()
	weather.reset()
	chime_sequence.clear()
	spawner.clear_all()
	_equip_visuals()
	player.revive(_start_position())
	player.face_direction(Vector3(0, 0, -1), true)
	player.camera_rig.yaw = 0.0
	quests.start("mq01_ben_song")
	state.add_item("banh_ngai", 2)
	spawner.arena.set_closed(true)
	_begin_play()
	if DisplayServer.get_name() != "headless":
		show_vision("Vân Khê — Mùa sương", ["Lâm An cập bến khi sương còn đọng trên mặt sông. Trên lưng là thanh kiếm cũ, trong tai là tiếng gió.",
			"Từ ngọn núi phía bắc, một hồi chuông vọng xuống. Rồi có tiếng ai kêu cứu trên con đường lên làng."], func() -> void:
			hud.show_hint("WASD: di chuyển  •  Chuột: nhìn quanh\nShift: né (giữ để chạy nhanh)  •  Space: nhảy\nF: tương tác  •  M: bản đồ  •  J: nhật ký  •  Esc / P: tạm dừng", 12.0))

func continue_game() -> void:
	if load_game():
		_begin_play()

func return_to_title() -> void:
	death_serial += 1
	player.end_focus()
	_abort_trial()
	set_paused(false)
	show_title()

func set_paused(value: bool) -> void:
	if not playing:
		get_tree().paused = false
		return
	get_tree().paused = value
	had_pointer = false
	menus.set_paused(value)
	audio.ui("ui_open" if value else "ui_close")
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value or _ui_blocking() else Input.MOUSE_MODE_CAPTURED

func open_panel(name: String) -> void:
	if not playing:
		return
	if not get_tree().paused:
		set_paused(true)
	menus.open_panel(name)
	audio.ui("book" if name == "journal" else "ui_open")

func _ui_blocking() -> bool:
	return hud.dialogue_open() or hud.vision_open()

# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	if not initialized:
		if assets.poll():
			_start_world()
		elif not assets.failure.is_empty():
			hud.set_tracker("Lỗi tải tài nguyên", "", assets.failure)
		else:
			hud.set_tracker("Vân Khê", "", "Đang tải thung lũng… %d%%" % roundi(assets.progress() * 100.0))
		return
	MapView.step(6)
	if in_title:
		title_angle += delta * 0.05
		var center: Vector3 = Vector3(-6, world.height_at(-6, 40) + 6.0, 40)
		title_camera.global_position = center + Vector3(sin(title_angle) * 34.0, 7.0, cos(title_angle) * 34.0)
		title_camera.look_at(Vector3(-4, world.height_at(-4, 20) + 3.0, 20))
		return
	if get_tree().paused:
		return
	if web:
		_watch_pointer()
	_update_region()
	_update_focus()
	_update_combat_state()
	autosave_timer -= delta
	if autosave_timer <= 0.0 and player.state == "move" and engaged == 0 and not trial.active:
		autosave_timer = 60.0 if web else 300.0
		save_game(true)
	hud_elapsed += delta
	if hud_elapsed >= 0.1:
		hud_elapsed = 0.0
		_refresh_hud()
	hud.update_marker(player.camera_rig.camera, _marker_world(), player.global_position)
	hud.update_reticle(player.camera_rig.camera, player.lock_target)

func _watch_pointer() -> void:
	## Esc in a browser releases pointer lock before the game sees the key; treat losing it as a pause.
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		had_pointer = true
	elif had_pointer and not _ui_blocking() and not player.is_dead():
		had_pointer = false
		set_paused(true)

func _update_region() -> void:
	var region: Dictionary = world.layout.region_at(player.global_position.z)
	var id: String = String(region.get("id", ""))
	if id != current_region:
		# The Trial pocket is not part of the journey: no discovery banner or visit flag.
		var first: bool = current_region != "" and not state.has_flag("visited:" + id) and not trial.active
		current_region = id
		atmosphere.set_region(id)
		ambient.set_region(id)
		weather.set_region(id)
		rain.set_region(region)
		audio.set_area(String(region.get("music", "explore")), String(region.get("ambience", "wind")))
		if first:
			state.set_flag("visited:" + id)
			hud.show_banner(String(region.get("name", "")), "Vùng đất mới")
			save_game(true)
		elif current_region != "" and not trial.active and not state.has_flag("visited:" + id):
			state.set_flag("visited:" + id)
	var river_distance: float = 999.0
	for water: Dictionary in world.layout.waters:
		river_distance = minf(river_distance, world.layout._line_query(water, player.global_position.x, player.global_position.z).x - float(water["width"]) * 0.5)
	audio.set_river_distance(river_distance)
	_update_weather_audio(region)

func _update_weather_audio(region: Dictionary) -> void:
	## Rain on the leaves (light, then a heavy roar), storm wind, and crickets after dark; nothing
	## under a roof or in the Trial's fixed afternoon (its sky is always clear and day).
	var outside: bool = playing and not trial.active and not bool(region.get("indoor", false))
	var wet: float = weather.rain() if outside else 0.0
	weather_beds["rain_light"] = clampf(wet * 1.8, 0.0, 1.0) * (1.0 - 0.6 * smoothstep(0.55, 1.0, wet))
	weather_beds["rain_heavy"] = smoothstep(0.45, 1.0, wet)
	weather_beds["storm_wind"] = weather.wind() if outside else 0.0
	weather_beds["night_insects"] = weather.night_level() * (1.0 - wet) if outside else 0.0
	audio.set_weather(weather_beds)

func _update_focus() -> void:
	focus = null
	if _ui_blocking():
		hud.show_prompt("")
		return
	# A broken foe within reach outranks every other use of F: the finisher.
	var broken: Enemy = player.finisher_target() if player.can_finish() else null
	if broken:
		focus = broken
		hud.show_prompt("%s  •  Kết liễu" % UserSettings.event_label("interact"), UiTheme.GOLD)
		return
	if player.state != "move" or not player.is_on_floor():
		hud.show_prompt("")
		return
	var best_score: float = INF
	for group: String in ["interactable", "npc"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var target: Node3D = node as Node3D
			if target == null or not target.visible:
				continue
			if target is Interactable and not (target as Interactable).can_interact():
				continue
			if target is Npc and (target as Npc).entity.get("talk", []).is_empty():
				continue
			var reach: float = (target as Interactable).radius if target is Interactable else 2.6
			var offset: Vector3 = target.global_position - player.global_position
			offset.y = 0.0
			var distance: float = offset.length()
			if distance > reach:
				continue
			var score: float = distance - offset.normalized().dot(player.facing) * 0.8
			if score < best_score:
				best_score = score
				focus = target
	if focus:
		var text: String = (focus as Interactable).prompt() if focus is Interactable else (focus as Npc).prompt()
		hud.show_prompt("%s  •  %s" % [UserSettings.event_label("interact"), text])
	else:
		hud.show_prompt("")

func _update_combat_state() -> void:
	engaged = 0
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: Enemy = node as Enemy
		if enemy and enemy.state in ["alert", "chase", "attack", "recover", "hit", "stagger"] and enemy.global_position.distance_to(player.global_position) < 32.0:
			engaged += 1
	var boss_fight: bool = spawner.arena.fighting or (trial.active and trial.boss != null)
	audio.set_combat(2 if boss_fight else (1 if engaged > 0 else 0))
	if engaged > 0 and not hinted.has("combat"):
		hinted["combat"] = true
		hud.show_hint("Chuột trái: đánh (3 đòn liên hoàn)  •  Giữ chuột trái: trọng kích\nShift: né  •  Chuột phải: đỡ — bấm đúng lúc đòn tới để phản đòn\n%s: khóa mục tiêu  •  %s: dùng thuốc  •  %s: vật phẩm nhanh" % [UserSettings.event_label("lock_on"), UserSettings.event_label("heal"), UserSettings.event_label("use_item")], 12.0)
	if not spawner.arena.fighting and state.has_flag("chimes_solved") and boss_alive() and spawner.arena.contains(player.global_position):
		spawner.arena.start_fight()

func _fighting_boss() -> Enemy:
	## The boss whose bar is on screen: the arena guardian or the Trial's wave leader.
	if trial.active and is_instance_valid(trial.boss):
		return trial.boss
	if spawner.arena.fighting:
		return spawner.node_for("boss_truc_tuong") as Enemy
	return null

func boss_alive() -> bool:
	## The arena guardian, once per World Tier after the story fight.
	if state.world_tier > 0:
		return not state.has_flag("tier_dead:%d:boss_truc_tuong" % state.world_tier)
	return not state.has_flag("dead:boss_truc_tuong")

func _marker_world() -> Variant:
	var tracked: String = state.tracked_quest
	if tracked == "" or not quests.is_active(tracked):
		return null
	var point: Variant = quests.marker(tracked)
	if point == null:
		return null
	var flat: Vector2 = point
	return Vector3(flat.x, world.height_at(flat.x, flat.y) + 2.2, flat.y)

func _refresh_vitals() -> void:
	if player:
		hud.set_vitals(player.health, player.max_health(), player.stamina, player.max_stamina())

func _refresh_hud() -> void:
	_refresh_vitals()
	hud.set_level(state.level, state.xp, state.xp_for_next(), state.skill_points)
	var heals: PackedStringArray = [UserSettings.event_label("heal")]
	for item: String in Consumables.heal_items(false):
		heals.append("%s ×%d" % [ContentDB.item(item).get("name", item), state.count(item)])
	hud.set_heal_count("  •  ".join(heals))
	var quick: String = state.quick_item
	var stock: String = "%s ×%d" % [ContentDB.item(quick).get("name", quick), state.count(quick)] if quick != "" else "Ô nhanh trống"
	hud.set_quick_item("%s  •  %s" % [UserSettings.event_label("use_item"), stock], quick != "" and state.count(quick) > 0)
	hud.set_statuses(player.statuses.list_for_hud())
	# The icon shows the moon once the sun is down (halfway through dusk), as the sky does.
	hud.set_clock(weather.clock_text(), weather.weather_name(), weather.icon(), weather.night_level() >= 0.5)
	var boss: Enemy = _fighting_boss()
	if boss:
		hud.set_boss_poise(boss.poise_ratio(), boss.is_broken(), boss.is_finishable())
	var style: String = player.style_id()
	for slot: String in StyleBook.SLOTS:
		var form: Dictionary = StyleBook.form(style, slot)
		var skill: String = String(form.get("skill", ""))
		var level: int = state.skill_level(skill)
		var fill: float = player.meter / PlayerController.METER_MAX if slot == "x" else 1.0 - player.cooldown_ratio(skill)
		hud.set_skill(slot, String(form.get("name", "")), level > 0, fill, level, StyleBook.color(style))
	var region_name: String = String(world.layout.region_at(player.global_position.z).get("name", ""))
	var tracked: String = state.tracked_quest
	if trial.active:
		hud.set_tracker(region_name, "Ải Vô Tận — Đợt %d" % maxi(trial.wave, 1), "Đã vượt %d đợt  •  Ngọc Gió tích lũy: %d  •  Kỷ lục: %d đợt" % [
			trial.cleared, int(trial.earned.get("ngoc", 0)), int(profile.trial.get("best_wave", 0))])
	elif tracked != "" and quests.is_active(tracked):
		hud.set_tracker(region_name, String(quests.definition(tracked).get("title", "")), quests.objective_text(tracked))
	elif state.has_flag("slice_complete"):
		hud.set_tracker(region_name, "Hồi 3 — Đền Tịch Phong", "Đoạn chơi mẫu đã hoàn thành. Tự do khám phá thung lũng.")
	else:
		hud.set_tracker(region_name, "", "")
	if hud.debug_enabled:
		var memory_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
		hud.status.text = "%d FPS  •  %.1f ms  •  %d draw calls\n%d/%d vùng  •  %.1f ms dựng vùng\nX %.0f  Y %.0f  Z %.0f  •  %s\nBộ nhớ %.0f MB  •  Quái %d  •  Seed %d\nNgày %d  •  %s  •  %s %.0f s  •  ghi trời %d\nMưa %.2f  •  đèn %d/%d" % [
			Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), world.active.size(), settings.chunk_capacity(), world.last_build_ms,
			player.global_position.x, player.global_position.y, player.global_position.z, current_region, memory_mb,
			get_tree().get_nodes_in_group("enemy").size(), settings.world_seed, weather.day, weather.clock_hhmm(), weather.world, weather.remaining, atmosphere.sky_writes,
			rain.intensity, night_lights.lit_count(), night_lights.lights.size()]

# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if not initialized or in_title:
		return
	if event.is_action_pressed("pause_game"):
		get_viewport().set_input_as_handled()
		if _ui_blocking():
			return
		if menus.panel_open():
			menus.close_panel()
			if not playing:
				return
			return
		set_paused(not get_tree().paused)
		return
	if event.is_action_pressed("toggle_debug"):
		user_settings.debug_hud = not user_settings.debug_hud
		hud.set_debug(user_settings.debug_hud)
		return
	if get_tree().paused:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _ui_blocking() and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if _ui_blocking():
		return
	if event.is_action_pressed("interact") and is_instance_valid(focus) and focus is Enemy:
		get_viewport().set_input_as_handled()
		player.start_finisher(focus as Enemy)
	elif event.is_action_pressed("interact") and focus and player.state == "move":
		get_viewport().set_input_as_handled()
		# Conversations, visions and shrines lock the controls, so they wait until the fight is over.
		if engaged > 0 and (focus is Npc or (focus as Interactable).kind in ["shrine", "echo", "diary", "memory_core", "seal_gate", "trial_gate"]):
			hud.show_message("Không thể làm việc này khi đang giao chiến")
			return
		if focus is Npc:
			start_dialogue(focus as Npc)
		else:
			(focus as Interactable).interact()
	elif event.is_action_pressed("open_map"):
		open_panel("map")
	elif event.is_action_pressed("open_journal"):
		open_panel("journal")
	elif event.is_action_pressed("open_inventory"):
		open_panel("inventory")
	elif event.is_action_pressed("save_game"):
		save_game()
	elif event.is_action_pressed("load_game"):
		load_game()

# ------------------------------------------------------------------ dialogue & visions

func start_dialogue(npc: Npc) -> void:
	var dialogue_id: String = ""
	for rule: Dictionary in npc.entity.get("talk", []):
		if quests.check(rule.get("if", [])):
			dialogue_id = String(rule["d"])
			break
	if dialogue_id == "":
		return
	npc.set_talking(true, player)
	player.face_direction(npc.global_position - player.global_position, true)
	player.input_enabled = false
	audio.ui("ui_select")
	_run_dialogue(dialogue_id, npc)

func _run_dialogue(dialogue_id: String, npc: Npc, choices_first: bool = false) -> void:
	## choices_first opens straight on the last line with its choices (a prompt, not a talk).
	var node: Dictionary = ContentDB.dialogue_node(dialogue_id)
	if node.is_empty():
		_end_dialogue()
		return
	dialogue = {"id": dialogue_id, "node": node, "index": (node.get("lines", []) as Array).size() if choices_first else 0, "npc": npc}
	_show_line()

func _show_line() -> void:
	var lines: Array = dialogue["node"].get("lines", [])
	var index: int = dialogue["index"]
	if index < lines.size():
		var line: Array = lines[index]
		hud.open_dialogue(String(line[0]), String(line[1]))
		return
	for action: String in dialogue["node"].get("do", []):
		run_action(action)
	var choices: Array = []
	for choice: Array in dialogue["node"].get("choices", []):
		if choice.size() < 3 or quests.check(choice[2]):
			choices.append(choice)
	if choices.size() > 1 or (choices.size() == 1 and String(choices[0][1]) != ""):
		dialogue["choices"] = choices
		var last: Array = lines[-1] if not lines.is_empty() else ["", ""]
		hud.open_dialogue(String(last[0]), String(last[1]), choices.map(func(choice: Array) -> String: return String(choice[0])))
		return
	_end_dialogue()

func _advance_dialogue() -> void:
	if dialogue.is_empty():
		return
	audio.ui("ui_click")
	dialogue["index"] = int(dialogue["index"]) + 1
	_show_line()

func _choose_dialogue(index: int) -> void:
	if dialogue.is_empty() or not dialogue.has("choices"):
		return
	var next: String = String(dialogue["choices"][index][1])
	audio.ui("ui_select")
	if next == "":
		_end_dialogue()
	else:
		_run_dialogue(next, dialogue["npc"])

func _end_dialogue() -> void:
	hud.close_dialogue()
	if not dialogue.is_empty() and is_instance_valid(dialogue["npc"]):
		(dialogue["npc"] as Npc).set_talking(false)
	dialogue = {}
	player.input_enabled = true

func _close_dialogue() -> void:
	## A new game or a load drops any conversation or prompt still on screen.
	if not dialogue.is_empty():
		_end_dialogue()

func show_vision(title: String, lines: Array, callback: Callable = Callable()) -> void:
	vision_callback = callback
	player.input_enabled = false
	hud.open_vision(title, "\n\n".join(PackedStringArray(lines)))
	if DisplayServer.get_name() == "headless":
		hud.close_vision()
		_on_vision_closed()

func _on_vision_closed() -> void:
	player.input_enabled = true
	var callback: Callable = vision_callback
	vision_callback = Callable()
	if callback.is_valid():
		callback.call()

# ------------------------------------------------------------------ actions & rewards

func run_action(action: String) -> void:
	var parts: PackedStringArray = action.split(":")
	match parts[0]:
		"give":
			give_items([[parts[1], int(parts[2]) if parts.size() > 2 else 1]])
		"take":
			state.remove_item(parts[1], int(parts[2]) if parts.size() > 2 else 1)
			quests.refresh()
		"event":
			quests.notify(action.substr(6))
		"quest":
			quests.start(parts[1])
		"flag":
			state.set_flag(action.substr(5))
			if parts[1] == "map_unlocked":
				hud.show_message("Đã có bản đồ thung lũng  •  %s" % UserSettings.event_label("open_map"))
		"unlock":
			unlock_skill(parts[1])
		"sword":
			state.grant_sword(parts[1])
			state.equip_sword(parts[1])
			_equip_visuals()
			audio.play("sword_draw")
			hud.show_banner("Nhận " + String(ContentDB.weapon(state.sword).get("name", state.sword)), "Công lực tăng lên %d" % roundi(state.attack_power()))
		"xp":
			_add_xp(int(parts[1]))
		"shop":
			open_shop(parts[1])
		"rest":
			# After the prompt has closed, so the fade keeps the controls locked.
			_rest.call_deferred(parts[1])

func unlock_skill(skill: String) -> void:
	state.unlock_skill(skill)
	audio.play("level_up")
	hud.show_banner("Lĩnh hội: " + StyleBook.skill_name(skill), "Võ học mới")
	if skill == "khinh_cong":
		var jump: String = UserSettings.event_label("jump")
		hud.show_hint("%s trên không: khinh công bật nhảy  •  giữ %s khi rơi: lướt gió" % [jump, jump], 10.0)
		return
	var found: Dictionary = StyleBook.find(skill)
	if not found.is_empty():
		var key: String = UserSettings.event_label(StyleBook.SLOT_ACTIONS[found["slot"]])
		hud.show_hint("%s: %s — %s" % [key, StyleBook.skill_name(skill), String(found["form"].get("description", ""))], 10.0)

func _on_skill_used(skill: String, _cooldown: float) -> void:
	var found: Dictionary = StyleBook.find(skill)
	if found.is_empty():
		return
	var data: Dictionary = Combat.attack("player", String(found["form"]["attack"]))
	audio.play(String(data.get("sfx", "wind_slash")), player.global_position, 0.0)
	_mission("skill")
	if found["slot"] == "x":
		_mission("ult")
		hud.show_banner(StyleBook.skill_name(skill), String(ContentDB.style(found["style"]).get("name", "")))

func _check_echo_skill(announce: bool) -> void:
	## Hearing all three memory echoes in Trúc Hải teaches Toàn Phong (also repairs older saves).
	if state.skill_level("cyclone") > 0:
		return
	for index: int in range(1, ECHO_COUNT + 1):
		if not state.has_flag("echo_seen:echo_%d" % index):
			return
	if announce:
		hud.show_message("Ba tiếng vọng quyện lại, xoáy quanh lưỡi kiếm thành một luồng gió.")
		unlock_skill("cyclone")
	else:
		state.unlock_skill("cyclone")

func give_items(items: Array) -> void:
	var parts: Array[String] = []
	for entry: Array in items:
		var item: String = String(entry[0])
		var amount: int = int(entry[1])
		state.add_item(item, amount)
		parts.append("%s ×%d" % ["Đồng" if item == "coins" else String(ContentDB.item(item).get("name", item)), amount])
	if not parts.is_empty():
		hud.show_message("Nhận: " + ", ".join(parts))
		audio.play("coins" if items.size() == 1 and items[0][0] == "coins" else "pickup")
	quests.refresh()

func give_rewards(rewards: Dictionary, title: String) -> void:
	hud.show_banner("Hoàn thành", title)
	audio.play("quest_complete")
	_add_xp(int(rewards.get("xp", 0)))
	give_items(rewards.get("items", []))
	save_game(true)

func _add_xp(amount: int) -> void:
	if amount <= 0:
		return
	var levels: int = state.add_xp(amount)
	if levels > 0:
		player.heal(player.max_health())
		audio.play("level_up")
		hud.show_banner("Cấp %d" % state.level, "Khí huyết và công lực tăng  •  +%d điểm tu luyện (%s)" % [levels, UserSettings.event_label("open_inventory")])

func on_skill_upgraded(skill: String) -> void:
	audio.ui("ui_confirm")
	hud.show_message("Đã nâng bậc " + StyleBook.skill_name(skill))

func _on_quest_started(id: String) -> void:
	var data: Dictionary = quests.definition(id)
	if data.get("kind", "") != "main" or id != "mq01_ben_song":
		hud.show_message(("Sự kiện: " if data.get("kind", "") == "event" else "Nhiệm vụ mới: ") + String(data.get("title", id)))
	audio.ui("ui_confirm")

func _on_quest_completed(id: String) -> void:
	if id == "mq04_vuot_khe":
		state.set_flag("slice_complete")
		state.max_tier = maxi(state.max_tier, 1)
		hud.show_message("Đã mở Cảnh giới thế giới và Ải Vô Tận đầy đủ (menu tạm dừng)", 5.0)

func _on_state_changed(kind: String, key: String) -> void:
	if kind in ["item", "coins"]:
		quests.refresh()
	# The first tonic picked up in play explains the quick slot (heals already have R).
	if (kind == "item" and playing and not get_tree().paused and state.quick_item == "" and not hinted.has("quick_item")
			and state.count(key) > 0 and Consumables.usable(key) and String(ContentDB.item(key).get("kind", "")) != "heal"):
		hinted["quick_item"] = true
		hud.show_hint("Nhận %s. Mở Túi đồ (%s) để đặt vào ô nhanh, rồi bấm %s để dùng ngay cả giữa trận." % [
			ContentDB.item(key).get("name", key), UserSettings.event_label("open_inventory"), UserSettings.event_label("use_item")], 9.0)

# ------------------------------------------------------------------ consumables & shops

func use_item(id: String) -> String:
	## Inventory "Dùng": applies a consumable at once behind the paused panel. Returns why it
	## was refused ("" when used). In a fight only R and the quick slot work, so a heal still
	## costs its moment in the open.
	if not playing or player.state in ["dead", "disabled", "loading"]:
		return "Không thể dùng lúc này"
	if engaged > 0 or spawner.arena.fighting:
		return "Đang giao chiến: dùng thuốc bằng %s hoặc ô nhanh %s" % [UserSettings.event_label("heal"), UserSettings.event_label("use_item")]
	var refusal: String = player.item_refusal(id)
	if refusal == "" and not player.consume_item(id):
		refusal = "Không dùng được " + String(ContentDB.item(id).get("name", id))
	return refusal

func set_quick_item(id: String) -> void:
	## Puts a consumable on the quick slot (C); "" empties it.
	if id != "" and not Consumables.usable(id):
		return
	state.quick_item = id
	audio.ui("ui_confirm")

func open_shop(id: String) -> void:
	## Opened by a dialogue "shop:<id>" action; closing the counter drops straight back into play.
	if Consumables.shop(id).is_empty():
		return
	menus.shop_id = id
	open_panel("shop")
	menus.resume_on_close = true

func buy_item(shop_id: String, item: String) -> String:
	## One purchase with Đồng. Returns why it was refused ("" when bought); a refusal changes nothing.
	var price: int = Consumables.shop_price(shop_id, item)
	var title: String = String(ContentDB.item(item).get("name", item))
	if price < 0:
		return "Quầy không bán " + title
	if not Consumables.buy(state, item, price):
		var reason: String = "Không đủ Đồng: %s giá %d, trong túi còn %d" % [title, price, state.coins]
		hud.show_message(reason)
		audio.ui("ui_error")
		return reason
	audio.play("coins")
	return ""

# ------------------------------------------------------------------ world events

func discover(poi: Dictionary) -> void:
	if in_title:
		return
	if state.discover(String(poi["id"])):
		hud.show_banner(String(poi["name"]), "Địa điểm mới")
		audio.play("discovery", null, -2.0)
		_add_xp(10)

func on_interact(item: Interactable) -> void:
	if not item.can_interact():
		return
	var data: Dictionary = item.entity
	match item.kind:
		"shrine":
			_use_shrine(item)
		"chest":
			state.set_flag(item.flag_key())
			item.open_lid()
			audio.play("chest_open", item.global_position)
			give_items(data.get("loot", []))
			quests.notify("interact:" + item.entity_id)
		"echo":
			audio.play("echo_whisper" if not data.has("event_quest") else "flute_call")
			show_vision(String(data.get("title", "")), data.get("lines", []), func() -> void:
				state.set_flag(item.flag_key())
				if data.has("flag"):
					state.set_flag(String(data["flag"]))
				if data.has("event_quest"):
					quests.start(String(data["event_quest"]))
				if not data.get("silent_count", false):
					quests.notify("echo")
					_check_echo_skill(true)
				quests.notify("interact:" + item.entity_id)
				if is_instance_valid(item):
					item.refresh())
		"diary":
			audio.play("book")
			show_vision(String(data.get("title", "")), data.get("lines", []), func() -> void:
				state.set_flag(item.flag_key())
				give_items([["nhat_ky", 1], ["long_vu_gio", 1]])
				unlock_skill("khinh_cong")
				quests.notify("interact:" + item.entity_id)
				if is_instance_valid(item):
					item.refresh())
		"chime":
			_ring_chime(item)
		"memory_core":
			audio.play("temple_bell")
			show_vision(String(data.get("title", "")), data.get("lines", []), func() -> void:
				state.set_flag(item.flag_key())
				state.set_flag("memory_core_seen")
				quests.notify("interact:memory_core")
				if is_instance_valid(item):
					item.refresh()
				_epilogue())
		"trial_gate":
			if not trial.unlocked():
				hud.show_message("Bia đá im lặng. Có lẽ nó chờ một lữ khách đã quen thung lũng hơn.")
				return
			audio.play("seal_hum", item.global_position)
			hud.fade_to(0.7, 0.2)
			trial.start(player.global_position)
			hud.fade_to(0.0, 0.8)
			hud.show_hint("Ải Vô Tận: đánh bại từng đợt, chọn phúc lành sau mỗi đợt.\nGục ngã hay rời Ải (menu tạm dừng) đều nhận đủ phần thưởng đã tích lũy.", 8.0)
		"reward_chest":
			open_reward_chest(item)
		"seal_gate":
			audio.play("seal_hum", item.global_position)
			show_vision("Cổng phong ấn", ["Bùa phong ấn đỏ rực chắn lối lên Đền Tịch Phong. Gió va vào đó rồi dội ngược lại.",
				"Muốn qua, cần hóa giải phong ấn. Những sợi Tơ ký ức kết từ người làng có thể là chìa khóa. (Hồi 3)"])

func _use_shrine(item: Interactable) -> void:
	var first: bool = not item.is_used()
	state.set_flag(item.flag_key())
	state.unlock_checkpoint(item.entity_id)
	item.refresh()
	audio.play("shrine_bell", item.global_position)
	Vfx.ring(self, item.global_position + Vector3.UP * 0.5, 4.0, Vfx.WIND, 0.8)
	player.heal(player.max_health())
	player.set_stamina(player.max_stamina())
	state.reset_camps()
	_reset_enemies(false)
	quests.notify("interact:" + item.entity_id)
	var name: String = String(ContentDB.get_data("entities").get("checkpoints", {}).get(item.entity_id, {}).get("name", "Miếu Gió"))
	if first:
		hud.show_banner(name, "Miếu Gió đã thắp sáng")
	hud.show_message("Nghỉ chân: hồi đầy khí huyết • Đã lưu hành trình • Quái trong trại xuất hiện lại")
	save_game(true)
	if not first and can_rest():
		# A shrine already lit also lets Lâm An wait for the next dawn or dusk.
		player.input_enabled = false
		audio.ui("ui_open")
		_run_dialogue("shrine_rest", null, true)

func can_rest() -> bool:
	## Waiting at a shrine for dawn or dusk: never in a fight or inside the Trial.
	return playing and not player.is_dead() and not trial.active and engaged == 0 and not spawner.arena.fighting

func _rest(target: String) -> void:
	## "Nghỉ đến sáng / tối": the screen fades out, the clock skips to the next dawn or dusk
	## (WeatherDirector.rest_until), the journey is saved and the screen fades back in.
	if not can_rest() or not weather.can_rest_until(target):
		return
	var serial: int = death_serial
	player.input_enabled = false
	var wake: Callable = func() -> void:
		# A death, load, new game or the title screen in between cancels the rest (and only the
		# title leaves the screen to lift here: the others run their own fades).
		if serial != death_serial or not playing:
			if not playing:
				hud.fade_to(0.0, 0.4)
			return
		player.input_enabled = true
		hud.fade_to(0.0, 1.0)
		if not can_rest():
			hud.show_message("Không thể nghỉ khi đang giao chiến")
			return
		weather.rest_until(target)
		hud.show_banner(weather.phase_name(), "Ngày %d  •  %s  •  %s" % [weather.day, weather.clock_text(), weather.weather_name()])
		save_game(true)
	if DisplayServer.get_name() == "headless":
		wake.call()
		return
	hud.fade_to(1.0, 0.6, "", "Ngồi nghỉ bên ngọn đèn miếu…")
	get_tree().create_timer(0.9).timeout.connect(wake)

func _ring_chime(item: Interactable) -> void:
	var note: int = int(item.entity.get("note", 1))
	audio.play("chime_%d" % note, item.global_position)
	Vfx.ring(self, item.global_position + Vector3.UP * 2.0, 1.4, Vfx.WIND, 0.6)
	if state.has_flag("chimes_solved"):
		return
	chime_sequence.append(note)
	var expected: Array[int] = [1, 2, 3]
	for index: int in range(chime_sequence.size()):
		if chime_sequence[index] != expected[index]:
			chime_sequence.clear()
			if note == expected[0]:
				chime_sequence.append(note)
			Vfx.burst(self, item.global_position + Vector3.UP * 1.5, Vfx.WIND, 30, 6.0)
			audio.play("dodge", item.global_position)
			hud.show_message("Chuông lạc nhịp, gió cuốn đi âm thanh… Hãy nhớ lời ru: trúc xanh, đá cũ, nước trong.")
			return
	if chime_sequence.size() == expected.size():
		state.set_flag("chimes_solved")
		audio.play("chime_solved")
		spawner.arena.set_closed(false)
		hud.show_banner("Bức tường gió tan đi", "Lối vào đấu trường trúc đã mở")
		quests.refresh()
		save_game(true)

func _on_fight_started() -> void:
	var boss: Enemy = spawner.node_for("boss_truc_tuong") as Enemy
	audio.play("roar", boss.global_position if boss else null)
	hud.show_banner("Trúc Tướng", "Kẻ gác rừng trúc")
	if boss:
		hud.show_boss(boss.display_name(), String(boss.data.get("title", "")), boss.health / boss.max_health)

func on_enemy_spawned(enemy: Enemy, data: Dictionary) -> void:
	if state.world_tier > 0 and data.has("enemy"):
		# World Tier: valley foes come back stronger; some are elites with affixes.
		var tier: Dictionary = ContentDB.tier(state.world_tier)
		EnemyScaler.apply(enemy, float(tier.get("hp", 1.0)), float(tier.get("damage", 1.0)), float(tier.get("xp", 1.0)), float(tier.get("coins", 1.0)))
		if not enemy.boss and rng.randf() < float(tier.get("elite", 0.0)):
			EnemyScaler.make_elite(enemy, EnemyScaler.roll_affixes(int(tier.get("elite_affixes", 1)), rng))
	if data.get("boss", false):
		enemy.health_changed.connect(func(target: Enemy, current: float, maximum: float) -> void:
			if spawner.arena.fighting:
				hud.show_boss(target.display_name(), String(target.data.get("title", "")), current / maximum))
		if enemy is Guardian:
			(enemy as Guardian).phase_changed.connect(func(_phase: int) -> void:
				audio.play("roar", enemy.global_position, 3.0)
				hud.show_banner("Trúc Tướng nổi giận!", "Gió quanh đấu trường cuộn lên"))
	enemy.attack_started.connect(func(attacker: Enemy, attack: String) -> void:
		# Wind-up cue from the attack's data (data/attacks.json "start_sfx").
		var sound: String = String(Combat.attack(attacker.owner_key, attack).get("start_sfx", "sabre_swing"))
		audio.play(sound, attacker.global_position, 0.0))
	enemy.status_damage.connect(_on_status_damage)
	enemy.reaction_hit.connect(_on_reaction_hit)
	enemy.poise_broken.connect(_on_poise_broken)

func on_enemy_defeated(enemy: Enemy, data: Dictionary) -> void:
	var id: String = String(data["id"])
	var tiered: bool = state.world_tier > 0 and data.get("persistent", false)
	if tiered:
		state.set_flag("tier_dead:%d:%s" % [state.world_tier, id])
	elif data.get("persistent", false):
		state.set_flag("dead:" + id)
	else:
		state.record_camp_kill(id)
	_mission("kill")
	if enemy.data.has("elite") and rng.randf() < float(ContentDB.get_data("elites").get("base", {}).get("chest_chance", 0.2)):
		spawn_reward_chest("elite", enemy.global_position)
	audio.play("enemy_down", enemy.global_position)
	_add_xp(int(enemy.data.get("xp", 10)))
	# heal_on_kill (the Huyết Ngọc set) works on world kills too; Trial kills heal in TrialDirector.
	var heal: float = state.stat("heal_on_kill")
	if heal > 0.0 and not player.is_dead():
		player.heal(player.max_health() * heal)
	var drops: Array = []
	var talisman_chance: float = 0.0
	for drop: Array in enemy.data.get("drops", []):
		if drop[0] == Talismans.DROP:
			talisman_chance = float(drop[3])
		elif randf() <= float(drop[3]):
			drops.append([drop[0], randi_range(int(drop[1]), int(drop[2]))])
	if not drops.is_empty():
		give_items(drops)
	if talisman_chance > 0.0:
		_drop_talisman(enemy, talisman_chance)
	quests.notify("kill:" + enemy.kind)
	quests.notify("kill:" + id)
	var camp: String = String(data.get("camp", ""))
	if camp != "" and not state.has_flag("camp_clear:" + camp):
		var cleared: bool = true
		for entry: Dictionary in spawner.entries:
			if entry["type"] == "enemy" and entry.get("camp", "") == camp:
				if not (state.has_flag("dead:" + String(entry["id"])) or state.camp_kills.has(entry["id"])):
					cleared = false
		if cleared:
			if data.get("persistent", false):
				state.set_flag("camp_clear:" + camp)
			quests.notify("camp_clear:" + camp)
	if data.get("boss", false):
		spawner.arena.end_fight(true)
		hud.hide_boss()
		audio.play("victory")
		if tiered:
			var tier: Dictionary = ContentDB.tier(state.world_tier)
			var ngoc: int = int(tier.get("ngoc_boss", 0))
			profile.add_currency(Gacha.currency(), ngoc)
			var tiers: int = (ContentDB.get_data("world_tiers").get("tiers", []) as Array).size()
			state.max_tier = maxi(state.max_tier, mini(state.world_tier + 1, tiers - 1))
			spawn_reward_chest("boss_tier", enemy.global_position + Vector3(0, 0, 2.0))
			hud.show_banner("Trúc Tướng gục ngã — %s" % tier.get("name", ""), "+%d Ngọc Gió  •  Rương Cảnh Giới xuất hiện" % ngoc)
			save_profile()
		else:
			hud.show_banner("Đã đánh bại Trúc Tướng", "Lõi phong ấn lộ ra giữa đấu trường")
		save_game(true)

func _reset_enemies(include_engaged: bool) -> void:
	for id: String in spawner.nodes.keys():
		var node: Node = spawner.node_for(id)
		if node is Enemy and (include_engaged or (node as Enemy).state in ["idle", "return"]) and (node as Enemy).state != "dead":
			node.queue_free()
			spawner.nodes.erase(id)

# ------------------------------------------------------------------ death & hazards

func _on_player_died() -> void:
	audio.play("death")
	audio.set_combat(0)
	if trial.active:
		# Falling in the Trial ends the run; the banked rewards are paid at the gate.
		hud.fade_to(1.0, 1.0, "Kết thúc Ải Vô Tận", "Vượt %d đợt. Phần thưởng đã tích lũy được giữ nguyên." % trial.cleared)
		death_serial += 1
		var run_serial: int = death_serial
		get_tree().create_timer(2.6).timeout.connect(func() -> void:
			if run_serial == death_serial and playing and trial.active:
				trial.end_run("death"))
		return
	hud.fade_to(1.0, 1.2, "Gục ngã", "Lâm An sẽ tỉnh lại ở Miếu Gió gần nhất. Hành trang, nhiệm vụ và kinh nghiệm được giữ nguyên;\nquái trong trại và kẻ gác đấu trường sẽ hồi phục.")
	death_serial += 1
	var serial: int = death_serial
	get_tree().create_timer(3.2).timeout.connect(func() -> void:
		# A load, new game or return to title during the death screen cancels this respawn.
		if serial == death_serial and playing and player.is_dead():
			respawn())

func respawn() -> void:
	set_paused(false)
	var point: Vector3 = _checkpoint_position()
	if spawner.arena.fighting:
		spawner.arena.end_fight(false)
		hud.hide_boss()
	_reset_enemies(true)
	state.reset_camps()
	player.revive(point)
	hud.fade_to(0.0, 0.8)
	hud.show_message("Đã trở về " + String(ContentDB.get_data("entities").get("checkpoints", {}).get(state.checkpoint_id, {}).get("name", "bến sông")))

func _checkpoint_position() -> Vector3:
	var checkpoint: Dictionary = ContentDB.get_data("entities").get("checkpoints", {}).get(state.checkpoint_id, {})
	if checkpoint.is_empty():
		return _start_position()
	var point: Array = checkpoint["respawn"]
	return Vector3(float(point[0]), world.height_at(float(point[0]), float(point[1])) + 0.3, float(point[1]))

func _on_hazard(kind: String) -> void:
	var damage: float = player.max_health() * 0.15
	audio.play("splash" if kind == "water" else "land", player.global_position)
	if player.health - damage <= 0.0:
		player.health = 0.0
		player._die()
		return
	player._apply_damage(damage)
	hud.fade_to(0.6, 0.15)
	player.teleport(player.last_safe + Vector3.UP * 0.3)
	hud.fade_to(0.0, 0.5)
	hud.show_message("Bị nước cuốn trôi" if kind == "water" else "Trượt chân rơi xuống vực", 2.5)

func _on_footstep(surface: String) -> void:
	var position: Vector3 = player.global_position
	match surface:
		"swing":
			audio.play("swing_heavy" if player.current_action() in ["heavy", "attack_3", "finisher"] else "swing", position, -2.0)
		"dodge":
			audio.play("dodge", position, -2.0)
		"jump":
			audio.play("jump", position, -6.0)
		"leap":
			audio.play("leap", position, -2.0)
		"land":
			audio.play("land", position, -6.0)
		"block":
			audio.play("block", position)
		"heal":
			audio.play("heal", position)
		"wind":
			pass
		_:
			audio.play("step_" + surface if surface in ["grass", "wood", "stone", "dirt", "leaves"] else "step_grass", position, -10.0, 0.12)

func _on_attack_landed(target: Node, amount: float) -> void:
	var position: Vector3 = (target as Node3D).global_position + Vector3.UP
	audio.play("boar_hit" if target is Boar else ("hit_heavy" if amount > 30.0 else "hit_flesh"), position)
	if user_settings.damage_numbers:
		Vfx.number(self, position, amount, Color(1.0, 0.95, 0.75) if amount < 30.0 else Color(1.0, 0.75, 0.4))

func _on_player_statuses() -> void:
	## The first time each debuff lands, explain what it does and how to shake it off
	## (one at a time: the rest wait for the next change).
	for id: String in player.statuses.active:
		var hint: String = String(ContentDB.status(id).get("hint", ""))
		if hint != "" and not hinted.has("status:" + id):
			hinted["status:" + id] = true
			hud.show_hint(hint.format({"dodge": UserSettings.event_label("sprint")}), 8.0)
			return

func _on_poise_broken(enemy: Enemy) -> void:
	## A clang as the guard gives way; the first break explains the finisher.
	audio.play("parry_metal", enemy.global_position + Vector3.UP, -3.0)
	if not hinted.has("finisher"):
		hinted["finisher"] = true
		hud.show_hint("Phá thế! Kẻ địch loạng choạng một lúc và chịu thêm sát thương.\nĐứng gần rồi bấm %s để kết liễu — khi ra đòn, Lâm An không thể bị đánh trúng." % UserSettings.event_label("interact"), 9.0)

func _on_finisher_landed(target: Node, _amount: float, _killed: bool) -> void:
	audio.play(String(Combat.attack("player", "finisher").get("impact_sfx", "ground_slam")), (target as Node3D).global_position, 0.0)
	_mission("finisher")

func _on_focus_started(kind: String) -> void:
	## Tâm Nhãn: a cool veil and its name on the HUD, a clear bell note; the first one explains itself.
	var rule: Dictionary = Combat.attack("player", "focus")
	hud.set_focus(true, String(rule.get("name", "Tâm Nhãn")) + "!", "Né hoàn hảo" if kind == "dodge" else "Phản đòn hoàn hảo", Color(String(rule.get("color", "8fd0f5"))))
	audio.play(String(rule.get("sfx", "chime_3")), null, -2.0, 0.02)
	if not hinted.has("focus"):
		hinted["focus"] = true
		hud.show_hint("Tâm Nhãn! Né hay đỡ đúng khoảnh khắc đòn địch vừa chạm tới, mọi kẻ địch sẽ chậm hẳn lại trong chốc lát.\nĐòn kế tiếp của Lâm An thành đòn phản (×1,5); né hoàn hảo còn hoàn lại thể lực. Mỗi lần mở xong cần nghỉ vài giây.", 9.0)

func _on_status_damage(enemy: Enemy, amount: float, status: String) -> void:
	## Damage over time floats up quietly in the colour of the status that dealt it.
	if user_settings.damage_numbers and amount >= 0.5:
		Vfx.number(self, enemy.global_position + Vector3.UP, amount, Color(String(ContentDB.status(status).get("color", "ffd0a0"))))

func _on_reaction_hit(enemy: Enemy, reaction: String, amount: float, splash: bool) -> void:
	## The blow that sets a reaction off sounds it (the hit number comes from attack_landed) and
	## explains it the first time; its splash floats numbers in the reaction colour.
	var rule: Dictionary = Reactions.find(reaction)
	if splash:
		if user_settings.damage_numbers and amount >= 0.5:
			Vfx.number(self, enemy.global_position + Vector3.UP, amount, Color(String(rule.get("color", "ffd0a0"))))
		return
	audio.play(String(rule.get("sfx", "hit_heavy")), enemy.global_position)
	var hint: String = String(rule.get("hint", ""))
	if hint != "" and not hinted.has("reaction:" + reaction):
		hinted["reaction:" + reaction] = true
		hud.show_hint(hint, 8.0)

func _epilogue() -> void:
	audio.set_music("title", 3.0)
	hud.fade_to(0.85, 1.5)
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		show_vision("Hết đoạn chơi mẫu", ["Chiều hôm ấy, chuông Đền Tịch Phong không vang. Dưới làng, bà Lục nhớ ra tên người chồng đã khuất; bà Hạnh treo lại chiếc chuông gió của bé Tý.",
			"Phong ấn vẫn còn đó, và cơn bão dưới núi vẫn chờ. Những sợi Tơ ký ức kết từ người làng sẽ là chìa khóa cho cách thứ ba.",
			"Hồi 3 — Đền Tịch Phong (đang phát triển). Bạn có thể tiếp tục khám phá thung lũng, hoàn thành nhiệm vụ phụ và rèn Phong Ngân Kiếm."], func() -> void:
			hud.fade_to(0.0, 1.2)
			save_game(true)))

# ------------------------------------------------------------------ settings

func apply_settings() -> void:
	user_settings.save_file()
	audio.apply_volumes(user_settings)
	hud.set_debug(user_settings.debug_hud)
	if player:
		player.camera_rig.sensitivity = user_settings.mouse_sensitivity
		player.camera_rig.invert_y = user_settings.invert_y
		player.camera_rig.shake_scale = user_settings.camera_shake
		settings.mouse_sensitivity = user_settings.mouse_sensitivity
	var preset: Dictionary = user_settings.preset()
	atmosphere.set_shadow_distance(float(preset["shadow"]))
	atmosphere.set_update_rate(float(preset["sky_hz"]))
	atmosphere.environment.glow_enabled = bool(preset["glow"])
	RenderingServer.directional_shadow_atlas_set_size(int(preset["shadow_atlas"]), true)
	var viewport: Viewport = get_viewport()
	viewport.msaa_3d = preset["msaa"]
	viewport.scaling_3d_scale = float(preset["scale"])
	if weather:
		weather.set_dynamic(user_settings.dynamic_weather)
	if world:
		world.configure(int(preset["view_radius"]), float(preset["density"]))
		ambient.set_budget(float(preset["ambient"]))
		rain.set_density(float(preset["rain"]))
		night_lights.set_budget(int(preset["lights"]))
		atmosphere.set_view_distance(world.settings.view_radius * world.settings.chunk_size)
		for chunk: WorldChunk in world.pool + world.active.values():
			_apply_chunk_quality(chunk, preset)
		for job: Dictionary in world.building.values():
			_apply_chunk_quality(job["chunk"], preset)
	if DisplayServer.get_name() != "headless" and not web:
		var window_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if user_settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != window_mode:
			DisplayServer.window_set_mode(window_mode)

func _apply_chunk_quality(chunk: WorldChunk, preset: Dictionary) -> void:
	var ranges: Dictionary = {"tree": "tree_distance", "bamboo": "bamboo", "grass": "grass", "clutter": "clutter", "rock": "rock"}
	for kind: String in chunk.batches:
		for batch: MultiMeshInstance3D in chunk.batches[kind]:
			batch.visibility_range_end = float(preset[ranges.get(String(batch.get_meta("range", "clutter")), "clutter")])
	for group: String in chunk.far_batches:
		(chunk.far_batches[group] as MultiMeshInstance3D).visibility_range_begin = float(preset["bamboo" if group == "bamboo" else "tree_distance"])

# ------------------------------------------------------------------ save / load

func save_game(silent: bool = false) -> bool:
	if not initialized or not playing or player.is_dead():
		return false
	if trial.active:
		if not silent:
			hud.show_message("Không thể lưu khi đang ở Ải Vô Tận")
		return false
	state.health = player.health
	var data: Dictionary = {
		"version": SaveStore.SCHEMA_VERSION, "seed": settings.world_seed, "position": SaveStore.to_array(player.global_position),
		"yaw": player.model_yaw, "checkpoint": SaveStore.to_array(_checkpoint_position()), "state": state.to_dict(),
		"label": String(world.layout.region_at(player.global_position.z).get("name", "")), "saved_at": int(Time.get_unix_time_from_system()),
	}
	data.merge(weather.to_save())
	var error: Error = SaveStore.write_save(data, save_path)
	if error == OK:
		save_profile()
		if not silent:
			hud.show_message("Đã lưu hành trình")
		else:
			hud.show_message("Tự động lưu", 1.5)
		return true
	hud.show_message("Không thể lưu: " + error_string(error))
	return false

func save_profile() -> void:
	var error: Error = profile.save_file(profile_path)
	if error != OK:
		hud.show_message("Không thể lưu hồ sơ: " + error_string(error))

func load_game() -> bool:
	if not initialized:
		return false
	var data: Dictionary = SaveStore.read_save(save_path)
	if data.is_empty():
		hud.show_message("Chưa có bản lưu hợp lệ")
		return false
	death_serial += 1
	_close_dialogue()
	_abort_trial()
	_clear_reward_chests()
	hud.fade_to(0.0, 0.4)
	if int(data["seed"]) != settings.world_seed:
		# The valley is authored for the default seed; props, water and the map are not rebuilt.
		world.reset_seed(int(data["seed"]))
		spawner.reset_navzones()
	state.from_dict(data["state"])
	weather.from_save(data)
	storm.cancel()
	_check_echo_skill(false)
	spawner.clear_all()
	chime_sequence.clear()
	if spawner.arena.fighting:
		spawner.arena.end_fight(false)
	spawner.arena.set_closed(not state.has_flag("chimes_solved"))
	hud.hide_boss()
	_equip_visuals()
	var location: Vector3 = SaveStore.to_vector(data["position"])
	if not world.layout.inside_bounds(location.x, location.z) or world.layout.in_pocket(location.x, location.z) or not world.layout.water_at(location.x, location.z).is_empty() or world.layout.in_chasm(location.x, location.z):
		location = _checkpoint_position()
	location.y = maxf(location.y, world.height_at(location.x, location.z) + 0.2)
	var saved_health: float = state.health
	player.revive(location)
	if saved_health > 0.0:
		player.health = minf(saved_health, player.max_health())
		state.health = player.health
	player.face_direction(Vector3(sin(float(data.get("yaw", 0.0))), 0, cos(float(data.get("yaw", 0.0)))), true)
	quests.refresh()
	if playing:
		set_paused(false)
	hud.show_message("Đã tải hành trình")
	return true

# ------------------------------------------------------------------ retention: trial, tiers, gacha, armory, missions

func refresh_stats() -> void:
	## Bonuses from the equipped armory weapon, the worn talismans and this run's Trial
	## blessings (neutral otherwise).
	var item: Dictionary = profile.weapon(state.equipped_uid) if state.equipped_uid >= 0 else {}
	state.stats = PlayerStats.compute(item, trial.buff_stats() if trial and trial.active else {}, profile.equipped_talismans())

func _equip_visuals() -> void:
	## Re-attaches the equipped sword with its skins and stats. An armory weapon from another
	## profile falls back to the best story sword of this save.
	if state.equipped_uid >= 0 and profile.weapon(state.equipped_uid).is_empty():
		state.equip_sword(String(state.swords[-1]))
	player.visual.attach_weapon(assets, state.sword)
	_apply_skins()
	refresh_stats()

func _apply_skins() -> void:
	var outfit: Dictionary = ContentDB.skin(String(profile.equipped_skins.get("player", "")))
	player.visual.apply_tint(outfit.get("tint", {}))
	var blade: Dictionary = ContentDB.skin(String(profile.equipped_skins.get("weapon", "")))
	player.visual.apply_weapon_glow(Color(String(blade["glow"])) if blade.has("glow") else null)

func equip_story_sword(id: String) -> void:
	if not playing or player.state != "move":
		return
	state.equip_sword(id)
	_equip_visuals()
	audio.play("sword_draw")

func equip_armory(uid: int) -> void:
	var item: Dictionary = profile.weapon(uid)
	if item.is_empty() or not playing or player.state != "move":
		return
	var base: String = String(item["base"])
	state.learn_style(base)
	state.equip_sword(base, uid)
	_equip_visuals()
	audio.play("sword_draw")

func equip_skin(target: String, id: String) -> void:
	if id != "" and not profile.skins.has(id):
		return
	profile.equipped_skins[target] = id
	if player:
		_apply_skins()
	save_profile()

# ------------------------------------------------------------------ talismans (Ngọc bội)

func can_change_talismans() -> bool:
	## Like swords: only while standing free in play. The title screen may change them freely.
	return not playing or (player != null and player.state == "move")

func equip_talisman(uid: int) -> bool:
	if not can_change_talismans() or not profile.equip_talisman(uid):
		return false
	_talismans_changed()
	audio.ui("ui_confirm")
	return true

func unequip_talisman(slot: int) -> bool:
	if not can_change_talismans() or not profile.unequip_talisman(slot):
		return false
	_talismans_changed()
	audio.ui("ui_close")
	return true

func salvage_talisman(uid: int) -> String:
	## Turns an unworn talisman into Đồng for this save. Returns why it was refused ("" when done).
	if not playing:
		return "Vào hành trình để phân giải Ngọc bội lấy Đồng"
	if profile.is_worn(uid):
		return "Tháo Ngọc bội ra trước khi phân giải"
	var coins: int = Talismans.salvage(profile, uid)
	if coins <= 0:
		return "Không phân giải được Ngọc bội này"
	state.add_item("coins", coins)
	save_profile()
	audio.play("coins")
	return ""

func _talismans_changed() -> void:
	if initialized:
		refresh_stats()
	save_profile()

func _drop_talisman(enemy: Enemy, chance: float) -> void:
	## An enemy's "talisman" drop entry: bosses and elites roll better rarities (data/talismans.json).
	var source: String = "boss" if enemy.boss else ("elite" if enemy.data.has("elite") else "enemy")
	var rolled: Dictionary = Talismans.drop(profile, source, chance)
	if rolled.is_empty():
		return
	_receive_talisman(Talismans.grant(profile, rolled), enemy.global_position)
	save_profile()

func _receive_talisman(outcome: Dictionary, at: Vector3, quiet: bool = false) -> void:
	## Pays the Đồng of a talisman a full pouch salvaged and announces the drop in its rarity colour.
	var coins: int = int(outcome.get("coins", 0))
	if coins > 0:
		state.add_item("coins", coins)
	if quiet:
		return
	var item: Dictionary = outcome["item"]
	var color: Color = PlayerStats.rarity_color(String(item.get("rarity", "r")))
	if outcome.get("kept", false):
		hud.show_message("Nhận Ngọc bội: %s" % Talismans.label(item), 4.0, color)
		Vfx.pillar(self, at, color, 6.0, 0.6, 0.5)
		audio.play("glint", at)
	var salvaged: Dictionary = outcome.get("salvaged", {})
	if not salvaged.is_empty():
		hud.show_message("Túi Ngọc bội đã đầy (%d): phân giải %s → +%d Đồng" % [Talismans.capacity(), Talismans.label(salvaged), coins], 4.5,
			PlayerStats.rarity_color(String(salvaged.get("rarity", "r"))))
	if outcome.get("kept", false) and profile.talismans.size() == 1:
		hud.show_hint("Nhận Ngọc bội đầu tiên. Vào mục Kiếm, Ngọc bội & trang phục (menu tạm dừng), thẻ Ngọc bội, để đeo vào ô Thiên, Địa, Nhân. Đeo 2 hoặc 3 món cùng bộ sẽ mở hiệu ứng bộ.", 10.0)

func tier_cap() -> int:
	## Highest World Tier this save may choose; none before the story slice is complete.
	if not state.has_flag(String(ContentDB.get_data("world_tiers").get("unlock_flag", "slice_complete"))):
		return 0
	var tiers: int = (ContentDB.get_data("world_tiers").get("tiers", []) as Array).size()
	return clampi(maxi(state.max_tier, 1), 1, tiers - 1)

func set_world_tier(tier: int) -> bool:
	if tier < 0 or tier > tier_cap() or tier == state.world_tier:
		return false
	if trial.active or engaged > 0 or spawner.arena.fighting:
		hud.show_message("Không thể đổi cảnh giới khi đang giao chiến")
		return false
	state.world_tier = tier
	_reset_enemies(true)
	spawner.clear_all()
	state.reset_camps()
	spawner.arena.set_closed(not state.has_flag("chimes_solved"))
	var data: Dictionary = ContentDB.tier(tier)
	hud.show_banner("Cảnh giới: " + String(data.get("name", "")), String(data.get("description", "")))
	audio.play("temple_bell")
	save_game(true)
	return true

func _abort_trial() -> void:
	if trial and trial.active:
		trial.end_run("abort")

func leave_trial() -> void:
	if trial.active:
		set_paused(false)
		trial.end_run("leave")

func on_trial_kill(enemy: Enemy) -> void:
	audio.play("enemy_down", enemy.global_position)
	_add_xp(int(enemy.data.get("xp", 10)) / 2)
	_mission("kill")

func on_trial_wave(wave: int) -> void:
	audio.play("quest_complete", null, -4.0)
	hud.show_message("Vượt đợt %d" % wave)
	profile.trial["best_wave"] = maxi(int(profile.trial.get("best_wave", 0)), wave)
	_mission("trial_wave")

func grant_story_sword(id: String, reason: String) -> void:
	if state.grant_sword(id):
		audio.play("sword_draw")
		hud.show_banner("Nhận " + String(ContentDB.weapon(id).get("name", id)), reason + "  •  Trang bị trong Kho kiếm")

func open_trial_pick(choices: Array) -> void:
	menus.trial_choices = choices
	open_panel("trial_pick")

func choose_trial_buff(buff: Dictionary) -> void:
	menus.close_panel(true)
	set_paused(false)
	audio.ui("ui_confirm")
	hud.show_message("Phúc lành: %s — %s" % [buff.get("name", ""), buff.get("desc", "")])
	trial.choose(buff)

func _on_trial_finished(summary: Dictionary) -> void:
	player.end_focus()  # leaving the pocket arena: no foe should stay slowed behind her
	profile.add_currency(Gacha.currency(), int(summary.get("ngoc", 0)))
	state.add_item("coins", int(summary.get("coins", 0)))
	_add_xp(int(summary.get("xp", 0)))
	profile.trial["runs"] = int(profile.trial.get("runs", 0)) + 1
	profile.trial["best_wave"] = maxi(int(profile.trial.get("best_wave", 0)), int(summary.get("wave", 0)))
	save_profile()
	if summary.get("reason", "") == "abort":
		return
	var point: Vector3 = trial.return_point
	if player.is_dead():
		player.revive(point)
	else:
		player.teleport(point)
		player.heal(player.max_health())
	hud.fade_to(0.0, 0.8)
	var line: String = "Vượt %d đợt  •  +%d Ngọc Gió  •  +%d Đồng" % [int(summary["wave"]), int(summary.get("ngoc", 0)), int(summary.get("coins", 0))]
	# Unopened Trial chests were opened quietly; name any Ngọc bội they held.
	var found: int = (summary.get("chests", []) as Array).filter(func(opened: Dictionary) -> bool: return opened.get("talisman", {}).get("kept", false)).size()
	if found > 0:
		line += "  •  +%d Ngọc bội" % found
	hud.show_banner("Rời Ải Vô Tận", line, 5.0)
	save_game(true)

func spawn_reward_chest(table: String, at: Vector3, parent: Node = null) -> Interactable:
	## A gacha chest whose rarity is rolled now, so it glows in that colour until opened.
	var rarity: String = Gacha.chest_rarity(profile, table)
	var chest: Interactable = Interactable.new()
	chest.name = "reward_%d" % Time.get_ticks_usec()
	(parent if parent else self).add_child(chest)
	chest.setup({"id": chest.name, "type": "reward_chest", "table": table, "rarity": rarity,
		"title": String(Gacha.data().get("chests", {}).get(table, {}).get("name", "rương thưởng")).to_lower()}, assets, self)
	chest.add_to_group("reward_chest")
	chest.global_position = Vector3(at.x, world.height_at(at.x, at.z), at.z)
	Vfx.pillar(self, chest.global_position, PlayerStats.rarity_color(rarity), 8.0, 0.9, 0.6)
	audio.play("glint", chest.global_position)
	return chest

func open_reward_chest(chest: Interactable, silent: bool = false) -> Dictionary:
	if chest.opened:
		return {}
	chest.opened = true
	chest.open_lid()
	if chest.wisps:
		chest.wisps.emitting = false
	var rarity: String = String(chest.entity.get("rarity", "r"))
	var result: Dictionary = Gacha.open_chest(profile, String(chest.entity.get("table", "trial")), rarity)
	# Consumables ride along in the save's bag (the reward itself is account-wide).
	var supplies: Array = Gacha.chest_supplies(String(chest.entity.get("table", "trial")), rng)
	if silent:
		for entry: Array in supplies:
			state.add_item(String(entry[0]), int(entry[1]))
	elif not supplies.is_empty():
		give_items(supplies)
	if not result.is_empty():
		result["supplies"] = supplies
	var talisman: Dictionary = Talismans.from_chest(profile, String(chest.entity.get("table", "trial")), rarity)
	if not talisman.is_empty():
		var outcome: Dictionary = Talismans.grant(profile, talisman)
		_receive_talisman(outcome, chest.global_position, silent)
		result["talisman"] = outcome
	_mission("chest")
	save_profile()
	if not silent and not result.is_empty():
		audio.play("chest_open", chest.global_position)
		Vfx.pillar(self, chest.global_position, PlayerStats.rarity_color(rarity), 10.0, 1.1, 0.9)
		hud.show_banner(String(result.get("label", "")), "%s  •  %s" % [PlayerStats.rarity_data(rarity).get("name", ""), String(chest.entity.get("title", "")).capitalize()], 4.5)
	return result

func _clear_reward_chests() -> void:
	for node: Node in get_tree().get_nodes_in_group("reward_chest"):
		if node.get_parent() == self:
			node.queue_free()

func gacha_pull(count: int) -> Array:
	var results: Array = Gacha.pull(profile, "ngu_hanh", count)
	if not results.is_empty():
		save_profile()
	return results

func _mission(event: String, amount: int = 1) -> void:
	Missions.refresh(profile, Missions.today())
	for name: String in Missions.notify(profile, event, amount):
		hud.show_message("Hoàn thành nhiệm vụ ngày: %s (nhận thưởng ở Nhiệm vụ ngày)" % name, 4.0)
