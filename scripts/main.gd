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
var player: PlayerController
var world: WorldManager
var spawner: EntitySpawner
var props: PropPlacer
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
		if engaged > 0 or spawner.arena.fighting:
			hud.show_message("Không thể về Miếu Gió khi đang giao chiến")
		else:
			respawn())
	menus.title_requested.connect(return_to_title)
	menus.settings_changed.connect(apply_settings)
	menus.quit_requested.connect(quit_game)
	state.changed.connect(_on_state_changed)
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
	backdrop.set_haze(atmosphere.haze())
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
	MapView.prepare(world.layout)
	ambient = AmbientFx.new()
	ambient.name = "AmbientFx"
	add_child(ambient)
	ambient.target = player
	player.health_changed.connect(func(_c: float, _m: float) -> void: _refresh_vitals())
	player.stamina_changed.connect(func(_c: float, _m: float) -> void: _refresh_vitals())
	player.died.connect(_on_player_died)
	player.hazard.connect(_on_hazard)
	player.footstep.connect(_on_footstep)
	player.attack_landed.connect(_on_attack_landed)
	player.parried.connect(func(_enemy: Node) -> void: audio.play("parry", player.global_position + Vector3.UP, 2.0))
	player.notice.connect(func(text: String) -> void: hud.show_message(text, 2.0))
	player.skill_used.connect(_on_skill_used)
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
	current_region = ""
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func start_new_game() -> void:
	death_serial += 1
	if spawner.arena.fighting:
		spawner.arena.end_fight(false)
	hud.hide_boss()
	hud.fade_to(0.0, 0.3)
	state.from_dict(GameState.new().to_dict())
	state.health = state.max_health()
	chime_sequence.clear()
	spawner.clear_all()
	player.visual.attach_weapon(assets, state.sword)
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
	if autosave_timer <= 0.0 and player.state == "move" and engaged == 0:
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
		var first: bool = current_region != "" and not state.has_flag("visited:" + id)
		current_region = id
		atmosphere.set_region(id)
		ambient.set_region(id)
		audio.set_area(String(region.get("music", "explore")), String(region.get("ambience", "wind")))
		if first:
			state.set_flag("visited:" + id)
			hud.show_banner(String(region.get("name", "")), "Vùng đất mới")
			save_game(true)
		elif current_region != "" and not state.has_flag("visited:" + id):
			state.set_flag("visited:" + id)
	var river_distance: float = 999.0
	for water: Dictionary in world.layout.waters:
		river_distance = minf(river_distance, world.layout._line_query(water, player.global_position.x, player.global_position.z).x - float(water["width"]) * 0.5)
	audio.set_river_distance(river_distance)

func _update_focus() -> void:
	focus = null
	if player.state != "move" or not player.is_on_floor() or _ui_blocking():
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
	var boss_fight: bool = spawner.arena.fighting
	audio.set_combat(2 if boss_fight else (1 if engaged > 0 else 0))
	if engaged > 0 and not hinted.has("combat"):
		hinted["combat"] = true
		hud.show_hint("Chuột trái: đánh (3 đòn liên hoàn)  •  Giữ chuột trái: trọng kích\nShift: né  •  Chuột phải: đỡ — bấm đúng lúc đòn tới để phản đòn\n%s: khóa mục tiêu  •  %s: dùng thuốc" % [UserSettings.event_label("lock_on"), UserSettings.event_label("heal")], 12.0)
	if not boss_fight and spawner.arena and state.has_flag("chimes_solved") and not state.has_flag("dead:boss_truc_tuong") and spawner.arena.contains(player.global_position):
		spawner.arena.start_fight()

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
		hud.set_vitals(player.health, player.max_health(), player.stamina, player.max_stamina)

func _refresh_hud() -> void:
	_refresh_vitals()
	hud.set_level(state.level, state.xp, state.xp_for_next(), state.skill_points)
	hud.set_heal_count("%s  •  Bánh ngải ×%d  •  Trà sen ×%d" % [UserSettings.event_label("heal"), state.count("banh_ngai"), state.count("tra_sen")])
	var style: String = player.style_id()
	for slot: String in StyleBook.SLOTS:
		var form: Dictionary = StyleBook.form(style, slot)
		var skill: String = String(form.get("skill", ""))
		var level: int = state.skill_level(skill)
		var fill: float = player.meter / PlayerController.METER_MAX if slot == "x" else 1.0 - player.cooldown_ratio(skill)
		hud.set_skill(slot, String(form.get("name", "")), level > 0, fill, level, StyleBook.color(style))
	var region_name: String = String(world.layout.region_at(player.global_position.z).get("name", ""))
	var tracked: String = state.tracked_quest
	if tracked != "" and quests.is_active(tracked):
		hud.set_tracker(region_name, String(quests.definition(tracked).get("title", "")), quests.objective_text(tracked))
	elif state.has_flag("slice_complete"):
		hud.set_tracker(region_name, "Hồi 3 — Đền Tịch Phong", "Đoạn chơi mẫu đã hoàn thành. Tự do khám phá thung lũng.")
	else:
		hud.set_tracker(region_name, "", "")
	if hud.debug_enabled:
		var memory_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
		hud.status.text = "%d FPS  •  %.1f ms  •  %d draw calls\n%d/%d vùng  •  %.1f ms dựng vùng\nX %.0f  Y %.0f  Z %.0f  •  %s\nBộ nhớ %.0f MB  •  Quái %d  •  Seed %d" % [
			Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), world.active.size(), settings.chunk_capacity(), world.last_build_ms,
			player.global_position.x, player.global_position.y, player.global_position.z, current_region, memory_mb,
			get_tree().get_nodes_in_group("enemy").size(), settings.world_seed]

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
	if event.is_action_pressed("interact") and focus and player.state == "move":
		get_viewport().set_input_as_handled()
		# Conversations, visions and shrines lock the controls, so they wait until the fight is over.
		if engaged > 0 and (focus is Npc or (focus as Interactable).kind in ["shrine", "echo", "diary", "memory_core", "seal_gate"]):
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

func _run_dialogue(dialogue_id: String, npc: Npc) -> void:
	var node: Dictionary = ContentDB.dialogue_node(dialogue_id)
	if node.is_empty():
		_end_dialogue()
		return
	dialogue = {"id": dialogue_id, "node": node, "index": 0, "npc": npc}
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
			player.visual.attach_weapon(assets, state.sword)
			audio.play("sword_draw")
			hud.show_banner("Nhận " + String(ContentDB.weapon(state.sword).get("name", state.sword)), "Công lực tăng lên %d" % roundi(state.attack_power()))
		"xp":
			_add_xp(int(parts[1]))

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
	if found["slot"] == "x":
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

func _on_state_changed(kind: String, _key: String) -> void:
	if kind in ["item", "coins"]:
		quests.refresh()

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
	player.set_stamina(player.max_stamina)
	state.reset_camps()
	_reset_enemies(false)
	quests.notify("interact:" + item.entity_id)
	var name: String = String(ContentDB.get_data("entities").get("checkpoints", {}).get(item.entity_id, {}).get("name", "Miếu Gió"))
	if first:
		hud.show_banner(name, "Miếu Gió đã thắp sáng")
	hud.show_message("Nghỉ chân: hồi đầy khí huyết • Đã lưu hành trình • Quái trong trại xuất hiện lại")
	save_game(true)

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
	if data.get("boss", false):
		enemy.health_changed.connect(func(target: Enemy, current: float, maximum: float) -> void:
			if spawner.arena.fighting:
				hud.show_boss(target.display_name(), String(target.data.get("title", "")), current / maximum))
		if enemy is Guardian:
			(enemy as Guardian).phase_changed.connect(func(_phase: int) -> void:
				audio.play("roar", enemy.global_position, 3.0)
				hud.show_banner("Trúc Tướng nổi giận!", "Gió quanh đấu trường cuộn lên"))
	enemy.attack_started.connect(func(attacker: Enemy, attack: String) -> void:
		var sound: String = {"attack": "sabre_swing" if attacker.kind == "tan_binh" else "glaive_slam", "sweep": "glaive_sweep", "slam": "danger", "charge": "boar_grunt"}.get(attack, "sabre_swing")
		audio.play(sound, attacker.global_position, 0.0))

func on_enemy_defeated(enemy: Enemy, data: Dictionary) -> void:
	var id: String = String(data["id"])
	if data.get("persistent", false):
		state.set_flag("dead:" + id)
	else:
		state.record_camp_kill(id)
	audio.play("enemy_down", enemy.global_position)
	_add_xp(int(enemy.data.get("xp", 10)))
	var drops: Array = []
	for drop: Array in enemy.data.get("drops", []):
		if randf() <= float(drop[3]):
			drops.append([drop[0], randi_range(int(drop[1]), int(drop[2]))])
	if not drops.is_empty():
		give_items(drops)
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
			audio.play("swing_heavy" if player.current_action() in ["heavy", "attack_3"] else "swing", position, -2.0)
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
	atmosphere.environment.glow_enabled = bool(preset["glow"])
	RenderingServer.directional_shadow_atlas_set_size(int(preset["shadow_atlas"]), true)
	var viewport: Viewport = get_viewport()
	viewport.msaa_3d = preset["msaa"]
	viewport.scaling_3d_scale = float(preset["scale"])
	if world:
		world.configure(int(preset["view_radius"]), float(preset["density"]))
		ambient.set_budget(float(preset["ambient"]))
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
	state.health = player.health
	var data: Dictionary = {
		"version": SaveStore.SCHEMA_VERSION, "seed": settings.world_seed, "position": SaveStore.to_array(player.global_position),
		"yaw": player.model_yaw, "checkpoint": SaveStore.to_array(_checkpoint_position()), "state": state.to_dict(),
		"label": String(world.layout.region_at(player.global_position.z).get("name", "")), "saved_at": int(Time.get_unix_time_from_system()),
	}
	var error: Error = SaveStore.write_save(data, save_path)
	if error == OK:
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
	hud.fade_to(0.0, 0.4)
	if int(data["seed"]) != settings.world_seed:
		# The valley is authored for the default seed; props, water and the map are not rebuilt.
		world.reset_seed(int(data["seed"]))
		spawner.reset_navzones()
	state.from_dict(data["state"])
	_check_echo_skill(false)
	spawner.clear_all()
	chime_sequence.clear()
	if spawner.arena.fighting:
		spawner.arena.end_fight(false)
	spawner.arena.set_closed(not state.has_flag("chimes_solved"))
	hud.hide_boss()
	player.visual.attach_weapon(assets, state.sword)
	var location: Vector3 = SaveStore.to_vector(data["position"])
	if not world.layout.inside_bounds(location.x, location.z) or not world.layout.water_at(location.x, location.z).is_empty() or world.layout.in_chasm(location.x, location.z):
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
