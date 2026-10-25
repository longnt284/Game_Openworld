extends SceneTree
## Chapter-one monsters through the real AI: data and clips for every new kind; the archer's
## leading arrows and backward hop; the shield guard's frontal guard (reduced, no status but
## Thổ's cracks; full from behind; broken by a heavy blow); the storm mage's blink and its
## warned lightning; the wolf leader's howl rallying its pack; the wraith's float, blink and
## wail; the stone golem asleep until disturbed, its unblockable slam, phase two and the HUD
## boss bar for minibosses.

var failures: int = 0
var game: Node3D
var player: PlayerController
var serial: int = 0
const NEW_KINDS: PackedStringArray = ["cung_thu", "ho_ve", "phap_su", "soi_suong", "soi_chua", "hon_anh", "khoi_loi"]
const CLASSES: Dictionary = {"cung_thu": "Archer", "ho_ve": "ShieldGuard", "phap_su": "Mage", "soi_suong": "Wolf", "soi_chua": "Wolf", "hon_anh": "Wraith", "khoi_loi": "Golem"}

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

func settle() -> void:
	for index: int in range(4000):
		var world: WorldManager = game.world
		if world.active.size() == game.settings.chunk_capacity() and world.building.is_empty() and world.pending.is_empty():
			break
		await frames(1)
	await frames(4)

func spawn(kind: String, offset: Vector3, live: bool = true, camp: String = "monster_test") -> Enemy:
	## A real enemy beside Lâm An, facing her; live ones run their AI.
	serial += 1
	var enemy: Enemy = EnemyFactory.create(ContentDB.enemy(kind))
	game.add_child(enemy)
	enemy.setup({"id": "monster_%d" % serial, "enemy": kind, "camp": camp, "yaw": 0.0}, game.assets, game.world)
	var point: Vector3 = player.global_position + offset
	point.y = game.world.height_at(point.x, point.z) + 0.1
	enemy.activate(point, player)
	game.on_enemy_spawned(enemy, {"id": enemy.entity_id})
	face(enemy, player.global_position)
	enemy.set_physics_process(live)
	return enemy

func face(enemy: Enemy, point: Vector3) -> void:
	var direction: Vector3 = point - enemy.global_position
	direction.y = 0.0
	if direction.length() > 0.01:
		enemy.facing = direction.normalized()
		enemy._apply_facing(true)

func clear() -> void:
	for node: Node in get_nodes_in_group("enemy"):
		node.queue_free()
	for node: Node in game.get_children():
		if node is WindProjectile or node is AreaEffect:
			node.queue_free()
	await frames(2)

func reset_player() -> void:
	player.revive(player.global_position)
	player.invulnerable = 0.0
	player.statuses.clear()
	player._sync_statuses()
	player.face_direction(Vector3(0, 0, -1), true)
	await frames(2)

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _run() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	game.skip_title = true
	game.save_path = "user://monster_test_save.json"
	game.profile_path = "user://monster_test_profile.json"
	root.add_child(game)
	for attempt: int in range(900):
		if game.initialized:
			break
		await frames(1)
	if not game.initialized:
		check(false, "Game initialises")
		_finish()
		return
	player = game.player
	game.spawner.clear_all()
	game.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	# Open, flat ground by the dock, clear weather so no lightning or rain gets involved.
	game.weather.set_weather("clear")
	player.teleport(Vector3(-20, game.world.height_at(-20, 64) + 0.3, 64))
	await settle()
	await _data()
	await _archer()
	await _shield()
	await _mage()
	await _wolves()
	await _wraith()
	await _golem()
	_finish()

func _finish() -> void:
	print("MONSTER RESULT: ", failures, " failure(s)")
	if game:
		game.audio.stop_all()
	await create_timer(0.2, true, false, true).timeout
	if game:
		game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _data() -> void:
	var data_ok: bool = true
	var clips_ok: bool = true
	var class_ok: bool = true
	for kind: String in NEW_KINDS:
		var data: Dictionary = ContentDB.enemy(kind)
		if EnemyFactory.script_for(data).get_global_name() != CLASSES[kind]:
			class_ok = false
			push_error("%s builds %s" % [kind, EnemyFactory.script_for(data).get_global_name()])
		var enemy: Enemy = spawn(kind, Vector3(0, 0, -6), false)
		for clip: String in ["idle", "walk", "run", "hit", "stagger", "death"]:
			if not enemy.visual.has_animation(clip):
				clips_ok = false
				push_error("%s lacks clip %s" % [kind, clip])
		for attack: Variant in data.get("attacks", []):
			var info: Dictionary = Combat.attack(String(data["owner"]), String(attack))
			if not info.has("hit_start") or not info.has("recover") or not info.has("damage"):
				data_ok = false
				push_error("%s attack %s lacks data or timing" % [kind, attack])
			if not enemy.visual.has_animation(String(attack)):
				clips_ok = false
				push_error("%s lacks attack clip %s" % [kind, attack])
		for drop: Variant in data.get("drops", []):
			if String(drop[0]) not in ["coins", Talismans.DROP] and not (ContentDB.get_data("items") as Dictionary).has(String(drop[0])):
				data_ok = false
				push_error("%s drops unknown item %s" % [kind, drop[0]])
		if not data.has("hint"):
			data_ok = false
		await clear()
	check(class_ok, "Every new monster builds through its own AI class")
	check(clips_ok, "Every new monster model has its locomotion, reaction and attack clips")
	check(data_ok, "Every new monster attack has data and timings, drops real items and carries a first-encounter hint")

func _archer() -> void:
	await reset_player()
	var archer: Archer = spawn("cung_thu", Vector3(0, 0, -11)) as Archer
	archer.cooldown = 0.0
	archer._set_state("chase")
	var health_before: float = player.health
	var shot: bool = false
	for step: int in range(320):
		await frames(1)
		if player.health < health_before:
			shot = true
			break
	check(shot and archer.global_position.distance_to(player.global_position) > 5.0, "The archer looses an arrow from range that hits Lâm An (%.0f → %.0f)" % [health_before, player.health])
	# Lâm An steps right up: the archer hops back out of reach.
	archer._set_state("chase")
	archer.hop_cooldown = 0.0
	archer.cooldown = 99.0
	var close: Vector3 = player.global_position + (archer.global_position - player.global_position).normalized() * 2.9
	archer.global_position = Vector3(close.x, game.world.height_at(close.x, close.z) + 0.1, close.z)
	var before: float = flat(archer.global_position, player.global_position)
	var hopped: bool = false
	for step: int in range(50):
		await frames(1)
		if archer.state == "hop":
			hopped = true
	check(hopped and flat(archer.global_position, player.global_position) > before + 1.0, "A foe at arm's length makes the archer hop back (%.1f → %.1f m)" % [before, flat(archer.global_position, player.global_position)])
	await clear()

func _shield() -> void:
	await reset_player()
	var guard: ShieldGuard = spawn("ho_ve", Vector3(0, 0, -2.4), false) as ShieldGuard
	var swing: Dictionary = Combat.attack("player", "attack_1").duplicate()
	swing["status"] = {"id": "burn", "chance": 1.0}
	swing["element"] = "flame"
	var before: float = guard.health
	player.strike(guard, swing, 1.0, (guard.global_position - player.global_position).normalized())
	var front: float = before - guard.health
	var front_status: bool = guard.statuses.has("burn")
	face(guard, guard.global_position * 2.0 - player.global_position)
	before = guard.health
	player.strike(guard, swing, 1.0, (guard.global_position - player.global_position).normalized())
	var back: float = before - guard.health
	check(front > 0.0 and front < back * 0.3 and not front_status and guard.statuses.has("burn"),
		"The tower shield turns a frontal blow (%.1f vs %.1f from behind) and its status; a blow from behind lands in full" % [front, back])
	guard.statuses.clear()
	face(guard, player.global_position)
	var earth: Dictionary = {"mult": 1.0, "poise": 0, "knockback": 0.0, "hitstop": 0.0, "element": "earth", "status": {"id": "sunder", "chance": 1.0}}
	player.strike(guard, earth, 1.0, (guard.global_position - player.global_position).normalized())
	check(guard.statuses.has("sunder") and guard.defense() < float(guard.data["defense"]), "Thổ's cracks pass the shield and strip the guard's armour")
	await frames(30)
	guard._set_state("idle")
	var heavy: Dictionary = Combat.attack("player", "heavy")
	player.strike(guard, heavy, 1.0, (guard.global_position - player.global_position).normalized())
	check(guard.is_broken(), "A heavy blow bats the shield aside and leaves the guard reeling")
	await clear()

func _mage() -> void:
	await reset_player()
	var mage: Mage = spawn("phap_su", Vector3(0, 0, -2.2)) as Mage
	mage.blink_cooldown = 0.0
	mage.cooldown = 99.0
	mage._set_state("chase")
	var blinked: bool = false
	for step: int in range(90):
		await frames(1)
		if mage.state == "blink":
			blinked = true
	check(blinked and flat(mage.global_position, player.global_position) > 5.0 and not mage.invulnerable,
		"Pressed close, the storm mage blinks away (%.1f m)" % flat(mage.global_position, player.global_position))
	await reset_player()
	player.block_held = true
	var health_before: float = player.health
	face(mage, player.global_position)
	mage._begin_attack("storm")
	var warned: bool = false
	for step: int in range(150):
		await frames(1)
		for node: Node in game.get_children():
			if node is AreaEffect and (node as AreaEffect).caster == mage:
				warned = true
		if player.health < health_before:
			break
	player.block_held = false
	check(warned and player.health < health_before and player.statuses.has("shock"), "The storm mage's lightning lands on the warned spot through a guard and leaves Tê liệt")
	await clear()

func _wolves() -> void:
	await reset_player()
	var leader: Wolf = spawn("soi_chua", Vector3(0, 0, -7), true, "test_pack") as Wolf
	var pup: Wolf = spawn("soi_suong", Vector3(3, 0, -7), false, "test_pack") as Wolf
	var stranger: Wolf = spawn("soi_suong", Vector3(-3, 0, -7), false, "other_pack") as Wolf
	check(leader.boss and leader.poise_bar_wanted() == false, "The pack leader fights as a miniboss (HUD bar, no overhead gauge)")
	leader._begin_attack("howl")
	for step: int in range(120):
		await frames(1)
		if pup.statuses.has("enemy_rage"):
			break
	check(pup.statuses.has("enemy_rage") and leader.statuses.has("enemy_rage") and not stranger.statuses.has("enemy_rage"), "The leader's howl maddens its own pack, not other wolves")
	game._refresh_hud()
	await frames(1)
	check(game.hud.boss_box.visible and game.hud.boss_name.text.begins_with(leader.display_name()), "An engaged miniboss shows the HUD boss bar")
	leader.take_damage(Combat.make_damage(player, {"poise": 999, "knockback": 0.0}, 99999.0, leader.global_position))
	await frames(2)
	game._refresh_hud()
	check(not game.hud.boss_box.visible, "The boss bar leaves with the fallen miniboss")
	await clear()

func _wraith() -> void:
	await reset_player()
	var wraith: Wraith = spawn("hon_anh", Vector3(0, 0, -6)) as Wraith
	wraith.cooldown = 99.0
	await frames(20)
	check(wraith.visual.position.y > 0.2 and wraith.visual.meshes[0].material_override == wraith.ghost, "The wraith floats above the ground as a pale shade")
	wraith._set_state("chase")
	wraith.blink_timer = 0.0
	var vanished: bool = false
	for step: int in range(80):
		await frames(1)
		if wraith.state == "blink":
			vanished = true
	check(vanished and flat(wraith.global_position, player.global_position) < 4.0, "The wraith fades out and reappears beside Lâm An (%.1f m)" % flat(wraith.global_position, player.global_position))
	await reset_player()
	face(wraith, player.global_position)
	wraith.cooldown = 99.0
	wraith.blink_timer = 99.0
	wraith._begin_attack("scream")
	for step: int in range(150):
		await frames(1)
		if player.statuses.has("weaken"):
			break
	check(player.statuses.has("weaken"), "The wraith's wail leaves Suy nhược on Lâm An in its ring")
	await clear()

func _golem() -> void:
	await reset_player()
	var golem: Golem = spawn("khoi_loi", Vector3(0, 0, -12)) as Golem
	await frames(5)
	check(golem.is_dormant(), "The golem sleeps until disturbed")
	var result: Dictionary = golem.take_damage(Combat.make_damage(player, {"poise": 0, "knockback": 0.0}, 50.0, golem.global_position))
	check(not result.get("hit", false) and golem.state == "waking" and golem.invulnerable and is_equal_approx(golem.health, golem.max_health), "A blow on the sleeping golem only wakes it")
	await frames(int(Golem.WAKE_TIME * 60.0) + 10)
	check(golem.state in ["chase", "attack", "recover"] and not golem.invulnerable, "The golem rises and fights (%s)" % golem.state)
	await reset_player()
	golem.global_position = player.global_position + Vector3(0, 0.1, -3.0)
	face(golem, player.global_position)
	player.block_held = true
	player._start_action("parry")
	var health_before: float = player.health
	golem._begin_attack("slam")
	for step: int in range(200):
		await frames(1)
		if player.health < health_before:
			break
	player.block_held = false
	check(player.health < health_before, "The golem's slam cannot be blocked")
	await reset_player()
	var plated: float = golem.health
	golem.take_damage(Combat.make_damage(player, {"poise": 0, "knockback": 0.0, "hitstop": 0.0}, 100.0, golem.global_position))
	check(plated - golem.health < 70.0 and plated - golem.health > 0.0, "Golem armour turns part of every blow (%.1f of 100)" % (plated - golem.health))
	golem.take_damage(Combat.make_damage(player, {"poise": 0, "knockback": 0.0, "hitstop": 0.0}, golem.health * 1.0, golem.global_position))
	check(golem.phase == 2 and golem.state == "roar" and golem.invulnerable and is_equal_approx(golem.base_speed_scale, 1.2), "Below half health the golem roars into phase two")
	await clear()
