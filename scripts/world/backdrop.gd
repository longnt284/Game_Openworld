class_name Backdrop
extends Node3D
## Distant scenery outside the playable area: three rings of limestone karst towers with
## forested crowns, low cloud banks at their feet and a pagoda on the northern peak. Each
## ring fades further into the horizon colour; none of it takes scene fog. Atmosphere feeds
## the haze colour and the light tint of the hour and weather.

const SHADER: Shader = preload("res://shaders/backdrop.gdshader")
const CLOUD_SHADER: Shader = preload("res://shaders/backdrop_cloud.gdshader")
## radius, count, height range, width range, haze
const RINGS: Array = [[430.0, 30, [70.0, 150.0], [34.0, 62.0], 0.16], [620.0, 34, [130.0, 230.0], [55.0, 90.0], 0.4], [880.0, 30, [200.0, 330.0], [80.0, 130.0], 0.62]]

var materials: Array[ShaderMaterial] = []

func build(center: Vector2, seed_value: int, assets: AssetLibrary = null) -> void:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed_value + 91
	var peak: Mesh = _mesh(assets, "env/karst_peak")
	for ring: Array in RINGS:
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("haze", ring[4])
		materials.append(material)
		var transforms: Array[Transform3D] = []
		for index: int in range(int(ring[1])):
			var angle: float = TAU * (index + random.randf_range(-0.3, 0.3)) / int(ring[1])
			var radius: float = float(ring[0]) * random.randf_range(0.9, 1.1)
			var height: float = random.randf_range(ring[2][0], ring[2][1])
			var width: float = random.randf_range(ring[3][0], ring[3][1])
			var basis: Basis = Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3(width, height, width * random.randf_range(0.8, 1.2)))
			transforms.append(Transform3D(basis, Vector3(center.x + cos(angle) * radius, -30.0, center.y + sin(angle) * radius)))
		if peak:
			add_child(_batch(peak, transforms, material))
		_clouds(center, float(ring[0]) * 0.92, int(ring[1]) / 2, random, material)
	if assets and assets.scenes.has("env/pagoda_bell_tower"):
		# A temple pagoda on a tall tower behind Đền Tịch Phong, as in the concept art.
		var pagoda: Node3D = assets.instantiate("env/pagoda_bell_tower")
		add_child(pagoda)
		pagoda.position = Vector3(center.x + 40.0, 132.0, center.y - 430.0)
		pagoda.scale = Vector3.ONE * 3.2
		var tower: Array[Transform3D] = [Transform3D(Basis.IDENTITY.scaled(Vector3(46.0, 170.0, 46.0)), Vector3(center.x + 40.0, -36.0, center.y - 430.0))]
		add_child(_batch(peak, tower, materials[0]))

func set_haze(color: Color) -> void:
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("haze_color", color)

func set_light(tint: Color) -> void:
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("light_tint", tint)

func _mesh(assets: AssetLibrary, key: String) -> Mesh:
	if assets == null or not assets.scenes.has(key):
		return null
	var root: Node = assets.instantiate(key)
	var found: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
	root.free()
	return mesh

func _batch(mesh: Mesh, transforms: Array[Transform3D], material: Material) -> MultiMeshInstance3D:
	var batch: MultiMeshInstance3D = MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		batch.multimesh.set_instance_transform(index, transforms[index])
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return batch

func _clouds(center: Vector2, radius: float, count: int, random: RandomNumberGenerator, material: ShaderMaterial) -> void:
	## Flat white banks of overlapping ellipsoids drifting at the feet of the towers.
	var puff: SphereMesh = SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 10
	puff.rings = 5
	var cloud_material: ShaderMaterial = ShaderMaterial.new()
	cloud_material.shader = CLOUD_SHADER
	cloud_material.set_shader_parameter("haze", float(material.get_shader_parameter("haze")) * 0.6)
	materials.append(cloud_material)
	var white: Array[Transform3D] = []
	for bank: int in range(count):
		var angle: float = random.randf() * TAU
		var base: Vector3 = Vector3(center.x + cos(angle) * radius, random.randf_range(25.0, 60.0), center.y + sin(angle) * radius)
		for lobe: int in range(5):
			var offset: Vector3 = Vector3(random.randf_range(-40.0, 40.0), random.randf_range(-4.0, 8.0), random.randf_range(-12.0, 12.0)).rotated(Vector3.UP, angle)
			var size: Vector3 = Vector3(random.randf_range(22.0, 40.0), random.randf_range(6.0, 11.0), random.randf_range(14.0, 24.0))
			white.append(Transform3D(Basis(Vector3.UP, angle).scaled(size), base + offset))
	var batch: MultiMeshInstance3D = MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = puff
	batch.multimesh.instance_count = white.size()
	for index: int in range(white.size()):
		batch.multimesh.set_instance_transform(index, white[index])
	batch.material_override = cloud_material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)
