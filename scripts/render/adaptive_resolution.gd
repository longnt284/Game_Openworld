class_name AdaptiveResolution
extends Node
## Browser builds: when the median frame over a few seconds of play is slower than ~38 fps, the 3D
## view renders at a lower internal resolution (the HUD stays sharp), one step at a time down to
## MIN_SCALE. The median ignores one-off stalls (a tab switch, a chunk upload). It never raises the
## scale by itself, so the picture never pumps; picking a quality preset starts again from its scale.

signal lowered(scale: float)

const WINDOW: float = 3.0
const SLOW_MS: float = 26.0
const STEP: float = 0.1
const MIN_SCALE: float = 0.6

## Only counts frames while true (main sets it during play, not in menus, dialogue or loading).
var active: bool = false
var scale: float = 1.0
var samples: PackedFloat32Array = PackedFloat32Array()
var elapsed: float = 0.0
var last_usec: int = 0

func reset(preset_scale: float) -> void:
	scale = preset_scale
	samples.clear()
	elapsed = 0.0

func _process(_delta: float) -> void:
	# Wall-clock time: the delta handed out shrinks with Engine.time_scale (hit-stop, Tâm Nhãn).
	var now: int = Time.get_ticks_usec()
	if last_usec > 0:
		sample((now - last_usec) / 1000.0)
	last_usec = now

func sample(frame_ms: float) -> void:
	## One frame's real duration; every WINDOW seconds of play the median decides.
	if not active:
		samples.clear()
		elapsed = 0.0
		return
	samples.append(frame_ms)
	elapsed += frame_ms / 1000.0
	if elapsed < WINDOW:
		return
	samples.sort()
	var median: float = samples[samples.size() / 2]
	samples.clear()
	elapsed = 0.0
	if median > SLOW_MS and scale > MIN_SCALE + 0.001:
		scale = maxf(MIN_SCALE, scale - STEP)
		get_viewport().scaling_3d_scale = scale
		lowered.emit(scale)
