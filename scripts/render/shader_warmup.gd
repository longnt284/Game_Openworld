class_name ShaderWarmup
extends Node3D
## The Compatibility renderer compiles each shader variant the first time something draws with it,
## and in a browser (WebGL) that compile stalls the frame: the first wraith, fire burst or lantern
## night would hitch. Behind the title, this draws one of everything for a few frames, shrunk to a
## speck just in front of the camera (skinned characters, weapons, props, flora MultiMeshes, every
## effect material, a lantern light), then frees itself.

const FRAMES: int = 4
const SCALE: float = 0.005

var frames_left: int = FRAMES
## How many nodes were drawn (the smoke test reads it).
var drawn: int = 0

static func run(parent: Node, camera: Camera3D, assets: AssetLibrary) -> ShaderWarmup:
	var warmup: ShaderWarmup = ShaderWarmup.new()
	warmup.name = "ShaderWarmup"
	parent.add_child(warmup)
	warmup.global_transform = camera.global_transform.translated_local(Vector3(0, 0, -1.5)).scaled_local(Vector3.ONE * SCALE)
	warmup._populate(assets)
	return warmup

func _populate(assets: AssetLibrary) -> void:
	var slot: int = 0
	for key: String in assets.scenes:
		_place(assets.instantiate(key), slot)
		slot += 1
	for kind: String in assets.mesh_parts:
		for part: Dictionary in assets.mesh_parts[kind]:
			_place(_batch(part["mesh"]), slot)
			slot += 1
	for group: String in assets.far_meshes:
		_place(_batch(assets.far_meshes[group]), slot)
		slot += 1
	# Effects: unshaded additive and mixed materials, particles, ribbons, text, toon rock.
	Vfx.slash(self, global_position, -global_basis.z, {"arc": [-60, 60], "radius": 1.0})
	Vfx.burst(self, global_position, Vfx.SPARK, 4)
	Vfx.ring(self, global_position, 1.0)
	Vfx.telegraph(self, global_position, 1.0, 0.5)
	Vfx.glint(self, global_position)
	Vfx.label(self, global_position, "Vân Khê")
	Vfx.wisps(self, Vfx.WIND, 4)
	Vfx.streak(self, global_position, global_position + Vector3.UP * 0.05, Vfx.WIND)
	Vfx.bolt(self, global_position, global_position + Vector3.UP * 0.05)
	Vfx.pillar(self, global_position, Vfx.DANGER, 0.05, 0.01)
	Vfx.shards(self, global_position, Color("bfefff"), 2, 0.02, 0.02)
	Vfx.rock_spikes(self, global_position, 0.02, 2, 0.02)
	Vfx.flames(self, global_position, 0.02, 0.6, 4)
	Vfx.tornado(self, global_position, 0.02)
	Vfx.crack(self, global_position, 0.02)
	Vfx.field(self, global_position, 0.02, Vfx.WIND, 0.5)
	var ghost: StandardMaterial3D = StandardMaterial3D.new()
	ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var shade: MeshInstance3D = MeshInstance3D.new()
	shade.mesh = BoxMesh.new()
	shade.material_override = ghost
	_place(shade, slot)
	var bar: PoiseBar = PoiseBar.new()
	add_child(bar)
	bar.setup(1.0)
	bar.show_poise(true, 1.0, false, 1.0)
	# The lantern pass: toon lit by an omni light, as every night. Unscaled and reaching only
	# the specks, so the title scene never flashes.
	var lantern: OmniLight3D = OmniLight3D.new()
	lantern.top_level = true
	lantern.shadow_enabled = false
	lantern.omni_range = 0.4
	add_child(lantern)
	lantern.global_position = global_position
	drawn = get_child_count()

func _place(node: Node3D, slot: int) -> void:
	add_child(node)
	node.position = Vector3((slot % 12) * 3.0 - 16.5, floorf(slot / 12.0) * 3.0 - 6.0, 0.0)

func _batch(mesh: Mesh) -> MultiMeshInstance3D:
	var batch: MultiMeshInstance3D = MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.use_colors = true
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = 1
	batch.multimesh.set_instance_color(0, Color.WHITE)
	return batch

func _process(_delta: float) -> void:
	frames_left -= 1
	if frames_left <= 0:
		queue_free()
