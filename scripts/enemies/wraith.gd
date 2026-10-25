class_name Wraith
extends Enemy
## Hồn ảnh, a memory wraith: floats above the ground ("float_height", bobbing), drawn as a pale
## see-through shade. It rakes with its claws (Lãng quên) and, after a ring warning, wails
## (Suy nhược on everyone in reach); between blows it fades out and reappears beside or behind
## its target ("blink_every"), so standing still is never safe.

const BLINK_TIME: float = 0.6
const GHOST: Color = Color(0.78, 0.95, 1.0, 0.58)

var blink_timer: float = 4.0
var blink_target: Vector3
var blinked: bool = false
var bob: float = 0.0
var ghost: StandardMaterial3D

func setup(entity: Dictionary, library: AssetLibrary, world_manager: WorldManager) -> void:
	super.setup(entity, library, world_manager)
	bob = randf() * TAU
	ghost = StandardMaterial3D.new()
	ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.albedo_color = GHOST
	ghost.rim_enabled = false
	for mesh: MeshInstance3D in visual.meshes:
		mesh.material_override = ghost
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Vfx.wisps(visual, Color(0.75, 0.95, 1.0), 10, 0.5)

func _process(delta: float) -> void:
	super._process(delta)
	bob += delta * 2.2 * time_dilation
	visual.position.y = float(data.get("float_height", 0.35)) + sin(bob) * 0.08 if state != "dead" else move_toward(visual.position.y, 0.0, delta)

func _physics_chase(delta: float) -> void:
	blink_timer -= delta
	if target and not target.is_dead() and blink_timer <= 0.0 and _flat_distance(target.global_position) < float(data.get("lose", 24.0)):
		_begin_blink()
		return
	super._physics_chase(delta)

func _choose_attack(distance: float) -> String:
	return "scream" if randf() < float(data.get("scream_chance", 0.3)) or distance > 2.0 else "claw"

func _begin_attack(name: String) -> void:
	super._begin_attack(name)
	if name == "scream":
		var wail: AreaEffect = AreaEffect.spawn(self, attack_data, float(data.get("damage_scale", 1.0)), "nova", Color("cfe9f0"), Combat.LAYER_HURT_PLAYER)
		wail.add_strike(global_position, float(attack_data.get("hit_start", 1.0)) / maxf(speed_scale, 0.1), float(attack_data.get("nova_radius", 4.5)))

func _attack_window(t: float, hit_start: float, hit_end: float) -> void:
	if attack_name == "scream":
		return  # the wail's ring deals it (AreaEffect)
	super._attack_window(t, hit_start, hit_end)

func _begin_blink() -> void:
	blink_timer = randf_range(float(data.get("blink_every", 7.0)) * 0.8, float(data.get("blink_every", 7.0)) * 1.3)
	blinked = false
	_release_token()
	var side: Vector3 = target.global_position - global_position
	side.y = 0.0
	side = side.normalized().rotated(Vector3.UP, randf_range(-2.2, 2.2)) if side.length() > 0.1 else Vector3.FORWARD
	blink_target = global_position
	for attempt: int in range(6):
		var candidate: Vector3 = target.global_position + side.rotated(Vector3.UP, randf_range(-0.6, 0.6)) * randf_range(2.4, 3.4)
		if world.is_position_ready(candidate) and world.layout.water_at(candidate.x, candidate.z).is_empty() and not world.layout.in_chasm(candidate.x, candidate.z) \
				and world.layout.inside_bounds(candidate.x, candidate.z):
			candidate.y = world.height_at(candidate.x, candidate.z) + 0.1
			blink_target = candidate
			break
	state = "blink"
	state_time = 0.0
	invulnerable = true
	visual.play_action("blink")
	Vfx.burst(get_parent(), global_position + Vector3.UP * 1.2, Color(0.8, 0.95, 1.0), 16, 3.0, 0.12, 0.6)

func _think(delta: float) -> void:
	if state == "blink":
		_stop(delta)
		visual.scale = Vector3.ONE * (1.0 - 0.9 * sin(clampf(state_time / BLINK_TIME, 0.0, 1.0) * PI))
		if not blinked and state_time >= BLINK_TIME * 0.5:
			blinked = true
			global_position = blink_target
			_face_target(1.0, 30.0)
			Vfx.burst(get_parent(), global_position + Vector3.UP * 1.2, Color(0.8, 0.95, 1.0), 16, 3.0, 0.12, 0.6)
		if state_time >= BLINK_TIME:
			visual.scale = Vector3.ONE
			invulnerable = false
			cooldown = minf(cooldown, 0.2)
			_set_state("chase")
		return
	super._think(delta)

func _die(damage: Combat.Damage) -> void:
	invulnerable = false
	visual.scale = Vector3.ONE
	Vfx.burst(get_parent(), global_position + Vector3.UP * 1.2, Color(0.8, 0.95, 1.0), 30, 4.0, 0.14, 1.0)
	super._die(damage)
