class_name NightLights
extends Node3D
## Lantern light after dark: a small pool of shadowless OmniLight3D (the quality preset's
## "lights": none on Low, 4 on Medium, 6 on High) handed to the flames nearest the view, just in
## front of Lâm An, among the props' lights (PropPlacer.lights, from props.json "lights"). They
## follow the night the sky shows (Atmosphere current "night"): they fade in through dusk, stay
## on until dawn, and stay dark in the Trial's fixed afternoon and on the title screen. A light
## leaving for a nearer flame fades out first, then fades in at its new place, so nothing pops.
## Off by day: hidden, no work but one comparison a frame. The toon shader gives these lights a
## soft wrapped pool and lets them shine through the paper of the lantern they sit in.

## The nearest flames are chosen this often (seconds), within REACH metres of a point LOOK_AHEAD
## metres in front of Lâm An along the camera's view, so the pool lights what is on screen.
const UPDATE_INTERVAL: float = 0.3
const REACH: float = 34.0
const LOOK_AHEAD: float = 9.0
## A light's own fade when it moves, per second.
const FADE: float = 2.5
## Falloff exponent: a bright pool under the flame that fades within a few metres.
const ATTENUATION: float = 1.2
## Night share (0..1) over which the lanterns come on.
const DUSK: Vector2 = Vector2(0.2, 0.7)

var atmosphere: Atmosphere
var target: Node3D
## Flames: {"position", "color", "energy", "range"}.
var flames: Array[Dictionary] = []
var lights: Array[OmniLight3D] = []
## Per light: the flame it serves (-1 none), the flame it should serve, and its fade 0..1.
var serving: PackedInt32Array = PackedInt32Array()
var wanted: PackedInt32Array = PackedInt32Array()
var fades: PackedFloat32Array = PackedFloat32Array()
var glow: float = 0.0
## True while any light may be on (it is night); the first day frame turns them all off.
var active: bool = false
var since: float = 0.0
## Scratch for the nearest-flame search (no allocation per update).
var nearest: PackedInt32Array = PackedInt32Array()
var nearest_distance: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func setup(props_lights: Array[Dictionary], sky: Atmosphere, follow_target: Node3D) -> void:
	flames = props_lights
	atmosphere = sky
	target = follow_target

func set_budget(count: int) -> void:
	## Grows or shrinks the pool (quality preset "lights").
	count = maxi(0, count)
	while lights.size() > count:
		lights.pop_back().queue_free()
	while lights.size() < count:
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Lantern%d" % lights.size()
		light.shadow_enabled = false
		light.light_specular = 0.0
		light.omni_attenuation = ATTENUATION
		light.light_energy = 0.0
		light.visible = false
		add_child(light)
		lights.append(light)
	serving.resize(count)
	wanted.resize(count)
	fades.resize(count)
	serving.fill(-1)
	wanted.fill(-1)
	fades.fill(0.0)
	for light: OmniLight3D in lights:
		light.visible = false
	since = UPDATE_INTERVAL

func night_glow() -> float:
	## How lit the lanterns are: 0 by day, 1 once night has fallen.
	var night: float = float(atmosphere.current.get("night", 0.0)) if atmosphere else 0.0
	return smoothstep(DUSK.x, DUSK.y, night)

func lit_count() -> int:
	var count: int = 0
	for light: OmniLight3D in lights:
		if light.visible and light.light_energy > 0.0:
			count += 1
	return count

func _process(delta: float) -> void:
	glow = night_glow()
	if lights.is_empty():
		return
	if glow <= 0.0:
		if active:
			active = false
			_darken()
		return
	active = true
	since += delta
	if since >= UPDATE_INTERVAL:
		since = 0.0
		_choose()
	_fade(delta)

func _darken() -> void:
	## Day: every light off and free, so dusk starts from the nearest flames again.
	for index: int in range(lights.size()):
		lights[index].visible = false
		lights[index].light_energy = 0.0
		serving[index] = -1
		wanted[index] = -1
		fades[index] = 0.0
	since = UPDATE_INTERVAL

func _choose() -> void:
	## The pool's flames: the nearest ones within REACH. A light keeps its flame if that flame is
	## still wanted; the others are handed the wanted flames nobody serves.
	if target == null or not is_instance_valid(target):
		return
	var origin: Vector3 = target.global_position
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera:
		var ahead: Vector3 = -camera.global_basis.z
		ahead.y = 0.0
		if ahead.length() > 0.01:
			origin += ahead.normalized() * LOOK_AHEAD
	var count: int = lights.size()
	nearest.resize(count)
	nearest_distance.resize(count)
	nearest.fill(-1)
	nearest_distance.fill(REACH * REACH)
	for index: int in range(flames.size()):
		var distance: float = origin.distance_squared_to(flames[index]["position"])
		if distance >= nearest_distance[count - 1]:
			continue
		# Insertion into the sorted short list.
		var slot: int = count - 1
		while slot > 0 and nearest_distance[slot - 1] > distance:
			nearest_distance[slot] = nearest_distance[slot - 1]
			nearest[slot] = nearest[slot - 1]
			slot -= 1
		nearest_distance[slot] = distance
		nearest[slot] = index
	for index: int in range(count):
		wanted[index] = serving[index] if serving[index] >= 0 and nearest.has(serving[index]) else -1
	for flame: int in nearest:
		if flame < 0 or wanted.has(flame):
			continue
		var free: int = wanted.find(-1)
		if free < 0:
			break
		wanted[free] = flame

func _fade(delta: float) -> void:
	for index: int in range(lights.size()):
		var light: OmniLight3D = lights[index]
		if serving[index] != wanted[index]:
			# Fade out where it stands, then move to the new flame.
			fades[index] = maxf(0.0, fades[index] - delta * FADE)
			if fades[index] <= 0.0:
				serving[index] = wanted[index]
				if serving[index] >= 0:
					var flame: Dictionary = flames[serving[index]]
					light.global_position = flame["position"]
					light.light_color = flame["color"]
					light.omni_range = float(flame["range"])
		elif serving[index] >= 0:
			fades[index] = minf(1.0, fades[index] + delta * FADE)
		var energy: float = float(flames[serving[index]]["energy"]) * fades[index] * glow if serving[index] >= 0 else 0.0
		var shown: bool = energy > 0.001
		if light.visible != shown:
			light.visible = shown
		if shown and absf(light.light_energy - energy) > 0.002:
			light.light_energy = energy
