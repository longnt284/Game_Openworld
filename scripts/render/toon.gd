class_name Toon
extends RefCounted
## Converts imported glTF materials into the shared toon look and builds the
## stylised materials used by code-generated geometry.

const TOON_SHADER: Shader = preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER: Shader = preload("res://shaders/outline.gdshader")
const WATER_SHADER: Shader = preload("res://shaders/water.gdshader")
const FOLIAGE: PackedStringArray = ["tree", "pine", "maple", "bamboo", "grass", "foliage"]

static var _noise: NoiseTexture2D
static var _cache: Dictionary = {}
static var _outline: ShaderMaterial

static func noise_texture() -> NoiseTexture2D:
	if _noise == null:
		_noise = NoiseTexture2D.new()
		_noise.width = 256
		_noise.height = 256
		_noise.seamless = true
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.frequency = 0.02
		noise.fractal_octaves = 3
		_noise.noise = noise
	return _noise

static func make(color: Color, options: Dictionary = {}) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = TOON_SHADER
	material.set_shader_parameter("albedo", color)
	material.set_shader_parameter("paint_noise", noise_texture())
	for key: String in options:
		material.set_shader_parameter(key, options[key])
	return material

static func flat_material(color: Color) -> ShaderMaterial:
	return make(color, {"rim_strength": 0.0})

static func terrain_material() -> ShaderMaterial:
	return make(Color.WHITE, {"use_vertex_color": true, "rim_strength": 0.0, "paint_strength": 0.09, "paint_scale": 0.05,
		"shade_tint": Color(0.66, 0.72, 0.86), "shade_softness": 0.12})

static func outline_material() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE_SHADER
	return _outline

static func water_material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("flow_noise", noise_texture())
	return material

static func convert_material(material: Material, outline: bool, foliage: bool) -> Material:
	if material == null or material is ShaderMaterial:
		return material
	var key: String = "%d:%s:%s" % [material.get_instance_id(), outline, foliage]
	if _cache.has(key):
		return _cache[key]
	var color: Color = Color.WHITE
	var options: Dictionary = {}
	if material is BaseMaterial3D:
		var base: BaseMaterial3D = material as BaseMaterial3D
		color = base.albedo_color
		if base.emission_enabled:
			options["emission_color"] = base.emission
			options["emission_energy"] = base.emission_energy_multiplier * 1.2
		if base.metallic > 0.3:
			options["rim_strength"] = 0.35
	if foliage:
		options["sway"] = 1.0
		options["rim_strength"] = 0.05
		options["double_sided_light"] = true
		options["shade_tint"] = Color(0.62, 0.74, 0.8)
	var converted: ShaderMaterial = make(color, options)
	converted.resource_name = material.resource_name
	if outline:
		converted.next_pass = outline_material()
	_cache[key] = converted
	return converted

static func apply_to_scene(root: Node, outline: bool = false, foliage: bool = false) -> void:
	## Rewrites surface materials on the shared mesh resources (once per mesh).
	for node: Node in _walk(root):
		if node is MeshInstance3D:
			var instance: MeshInstance3D = node as MeshInstance3D
			var mesh: Mesh = instance.mesh
			if mesh == null:
				continue
			var tag: String = "toon_%s_%s" % [outline, foliage]
			if mesh.has_meta(tag):
				continue
			for surface: int in range(mesh.get_surface_count()):
				mesh.surface_set_material(surface, convert_material(mesh.surface_get_material(surface), outline, foliage))
			mesh.set_meta(tag, true)

static func is_foliage(key: String) -> bool:
	for word: String in FOLIAGE:
		if key.contains(word):
			return true
	return false

static func _walk(root: Node) -> Array[Node]:
	var nodes: Array[Node] = [root]
	var index: int = 0
	while index < nodes.size():
		nodes.append_array(nodes[index].get_children())
		index += 1
	return nodes
