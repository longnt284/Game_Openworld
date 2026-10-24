class_name StormDirector
extends Node3D
## Lightning while the sky shown is a storm (data/weather.json "lightning"). Bolts come every
## WeatherDirector.lightning_interval() seconds times a random factor ("spread"), drawn from this
## node's own RNG so the saved weather RNG never moves. Most are distant: a wide bolt somewhere in
## view (Vfx.bolt, past the fog), the sky and ambient flash (Atmosphere.flash), a full-screen
## flash on the HUD's own layer (GameHUD.flash, not the fade) and thunder after the time sound
## takes to cover the distance (audio "thunder", silent while the clip is missing). Rarely, while
## Lâm An is near foes, a bolt strikes instead: a ring (Vfx.telegraph) warns for "telegraph"
## seconds around one of them, then thunder damage and Tê liệt hit everything inside it, foes and
## Lâm An alike. The safe rule: no strike in a "safe" region (the village, layout.json), in an
## "indoor" one, in the Trial, during a dialogue, vision or prompt, or for a dead or idle
## journey; a warned strike that stops being allowed fizzles. Indoors no bolt shows at all.
## Ticks in _physics_process and parents its effects (PAUSABLE), so a pause holds the next bolt,
## a warning ring with its strike, and the thunder on its way.

signal bolt_fell(point: Vector3, distance: float)
signal strike_warned(point: Vector3)
signal strike_landed(point: Vector3, hits: Array)

var game: Node
var weather: WeatherDirector
var rule: Dictionary = {}
var strike_rule: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Seconds before the next bolt; negative while no storm is shown.
var until_next: float = -1.0
var since_strike: float = 999.0
## Warned strikes: {"point", "left", "ring"}.
var pending: Array[Dictionary] = []
## Thunder on its way: {"left", "volume", "position" (null when distant)}.
var rumbles: Array[Dictionary] = []

func setup(owner_main: Node) -> void:
	game = owner_main
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Copies: tests and tuning may change them without touching the cached data/weather.json.
	rule = (WeatherDirector.data().get("lightning", {}) as Dictionary).duplicate(true)
	strike_rule = rule.get("strike", {})
	rng.randomize()

func follow(director: WeatherDirector) -> void:
	## main: the clock's director while playing, null on the title screen (no lightning).
	weather = director
	until_next = -1.0
	cancel()

func cancel() -> void:
	## Drops warned strikes and thunder still on its way (a new game, a load, the title screen).
	for strike: Dictionary in pending:
		if is_instance_valid(strike["ring"]):
			(strike["ring"] as Node).queue_free()
	pending.clear()
	rumbles.clear()

func _physics_process(delta: float) -> void:
	step(delta)

func step(seconds: float) -> void:
	## One tick: lands due strikes, sounds due thunder and counts down to the next bolt.
	since_strike += seconds
	for index: int in range(pending.size() - 1, -1, -1):
		var strike: Dictionary = pending[index]
		strike["left"] = float(strike["left"]) - seconds
		if float(strike["left"]) <= 0.0:
			pending.remove_at(index)
			_land(strike)
	for index: int in range(rumbles.size() - 1, -1, -1):
		var rumble: Dictionary = rumbles[index]
		rumble["left"] = float(rumble["left"]) - seconds
		if float(rumble["left"]) <= 0.0:
			rumbles.remove_at(index)
			game.audio.play("thunder", rumble["position"], float(rumble["volume"]), 0.06)
	var interval: float = weather.lightning_interval() if weather and not _sheltered() else 0.0
	if interval <= 0.0:
		until_next = -1.0
		return
	if until_next < 0.0:
		until_next = roll(interval)
	until_next -= seconds
	if until_next > 0.0:
		return
	until_next = roll(interval)
	var target: Variant = _strike_target() if since_strike >= float(strike_rule.get("cooldown", 30.0)) and rng.randf() < float(strike_rule.get("chance", 0.0)) else null
	if target != null:
		warn(target)
	else:
		distant_bolt()

func roll(interval: float) -> float:
	## Seconds to the next bolt: the weather's interval times a random factor in "spread".
	var spread: Array = rule.get("spread", [0.5, 1.5])
	return interval * rng.randf_range(float(spread[0]), float(spread[-1]))

func _sheltered() -> bool:
	return game == null or bool(game.world.layout.region_at(game.player.global_position.z).get("indoor", false))

# ------------------------------------------------------------------ distant bolts

func distant_bolt() -> void:
	## A bolt far off in front of the camera, its flash, and thunder once the sound arrives.
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var reach: Array = rule.get("distance", [75, 170])
	var distance: float = rng.randf_range(float(reach[0]), float(reach[-1]))
	var view: float = float(rule.get("view", 0.42))
	var origin: Vector3 = camera.global_position
	var ground: Vector3 = origin + forward.rotated(Vector3.UP, rng.randf_range(-view, view)) * distance
	var layout: WorldLayout = game.world.layout
	ground.y = layout.height_at(ground.x, ground.z) if layout.inside_bounds(ground.x, ground.z) else game.player.global_position.y
	var heights: Array = rule.get("height", [55, 85])
	var top: Vector3 = ground + Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(float(heights[0]), float(heights[-1])), rng.randf_range(-12.0, 12.0))
	var color: Color = Color(String(rule.get("color", "e6eeff")))
	Vfx.bolt(self, top, ground, color, 0.34, 9.0, 9.0, true)
	# A fork from part way down, thinner.
	var fork: Vector3 = top.lerp(ground, rng.randf_range(0.3, 0.55))
	Vfx.bolt(self, fork, fork + Vector3(rng.randf_range(-18.0, 18.0), -rng.randf_range(14.0, 24.0), rng.randf_range(-18.0, 18.0)), color, 0.26, 4.0, 4.0, true)
	var near: float = inverse_lerp(float(reach[-1]), float(reach[0]), distance)
	var flash: Dictionary = rule.get("flash", {})
	var sky: Array = flash.get("sky", [0.9, 0.45])
	var screen: Array = flash.get("screen", [0.32, 0.12])
	game.atmosphere.flash(lerpf(float(sky[-1]), float(sky[0]), near))
	game.hud.flash(lerpf(float(screen[-1]), float(screen[0]), near))
	var loudness: Array = rule.get("thunder_db", [-2, -10])
	rumbles.append({"left": distance / float(rule.get("speed_of_sound", 343.0)), "volume": lerpf(float(loudness[-1]), float(loudness[0]), near), "position": null})
	bolt_fell.emit(ground, distance)

# ------------------------------------------------------------------ strikes

func may_strike(point: Vector3) -> bool:
	## The safe rule (see the class notes) for a strike at point now.
	if game == null or not game.playing or game.player.is_dead() or game.trial.active:
		return false
	if not game.dialogue.is_empty() or game.hud.dialogue_open() or game.hud.vision_open():
		return false
	var layout: WorldLayout = game.world.layout
	for z: float in [point.z, game.player.global_position.z]:
		var region: Dictionary = layout.region_at(z)
		if region.get("safe", false) or region.get("indoor", false):
			return false
	return true

func _strike_target() -> Variant:
	## A point beside one of the live foes near Lâm An, or null when none may be struck.
	var player: PlayerController = game.player
	var reach: float = float(strike_rule.get("range", 14.0))
	var foes: Array[Enemy] = []
	for node: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: Enemy = node as Enemy
		if enemy and not enemy.is_dead() and not enemy.boss and enemy.global_position.distance_to(player.global_position) <= reach and may_strike(enemy.global_position):
			foes.append(enemy)
	if foes.is_empty():
		return null
	var foe: Enemy = foes[rng.randi() % foes.size()]
	var point: Vector3 = foe.global_position + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
	point.y = game.world.height_at(point.x, point.z)
	return point

func warn(point: Vector3) -> void:
	## Starts a strike at point: the ring fills for "telegraph" seconds before the bolt falls.
	since_strike = 0.0
	var seconds: float = float(strike_rule.get("telegraph", 1.2))
	var ring: Node3D = Vfx.telegraph(self, point, float(strike_rule.get("radius", 2.8)), seconds, Color(String(strike_rule.get("color", "ffe066"))))
	pending.append({"point": point, "left": seconds, "ring": ring})
	game.audio.play("danger", point, -4.0)
	strike_warned.emit(point)

func _land(strike: Dictionary) -> void:
	var point: Vector3 = strike["point"]
	if is_instance_valid(strike["ring"]):
		(strike["ring"] as Node).queue_free()
	if not may_strike(point):
		# Fizzles: a conversation started, Lâm An fell or left, the journey ended.
		return
	var color: Color = Color(String(rule.get("color", "e6eeff")))
	Vfx.lightning(self, point, color)
	Vfx.bolt(self, point + Vector3(rng.randf_range(-6.0, 6.0), 60.0, rng.randf_range(-6.0, 6.0)), point + Vector3.UP * 14.0, color, 0.3, 3.0, 3.0, true)
	game.atmosphere.flash(1.0)
	game.hud.flash(float(rule.get("flash", {}).get("strike_screen", 0.55)))
	game.audio.play("thunder", point, 4.0, 0.04)
	var player: PlayerController = game.player
	var closeness: float = 1.0 - clampf(player.global_position.distance_to(point) / 16.0, 0.0, 1.0)
	if closeness > 0.0:
		player.camera_rig.add_trauma(float(strike_rule.get("shake", 0.6)) * closeness)
	strike_landed.emit(point, hit(point))

func hit(point: Vector3) -> Array:
	## Thunder damage and Tê liệt to every foe and to Lâm An standing in the ring (a flat circle,
	## up to 3 m above or below its centre). Returns who was struck.
	var radius: float = float(strike_rule.get("radius", 2.8))
	var struck: Array = []
	var targets: Array[Node] = get_tree().get_nodes_in_group("enemy")
	targets.append(game.player)
	for node: Node in targets:
		var body: Node3D = node as Node3D
		if body == null or (body is Enemy and (body as Enemy).is_dead()) or (body is PlayerController and (body as PlayerController).is_dead()):
			continue
		var offset: Vector3 = body.global_position - point
		if absf(offset.y) > 3.0 or Vector2(offset.x, offset.z).length() > radius:
			continue
		var share: float = float(strike_rule.get("player_damage", 0.14))
		var health: float = 0.0
		if body is Enemy:
			share = float(strike_rule.get("boss_damage" if (body as Enemy).boss else "enemy_damage", 0.2))
			health = (body as Enemy).max_health
		else:
			health = (body as PlayerController).max_health()
		var damage: Combat.Damage = Combat.make_damage(self, {"poise": strike_rule.get("poise", 40), "knockback": strike_rule.get("knockback", 3.0),
			"hitstop": strike_rule.get("hitstop", 0.08), "shake": strike_rule.get("shake", 0.6), "element": "thunder", "status": strike_rule.get("status", {}),
			"unblockable": true, "ranged": true}, health * share, body.global_position)
		offset.y = 0.0
		damage.direction = offset.normalized() if offset.length() > 0.05 else Vector3.FORWARD
		var result: Dictionary = body.call("take_damage", damage)
		if result.get("hit", false):
			struck.append(body)
	return struck
