class_name EntitySpawner
extends Node3D
## Spawns NPCs, enemies and interactables near the player from data/world/entities.json.
## Each entity has a stable id; at most one node exists per id, and persistent
## state (dead bosses, opened chests, quest NPC positions) comes from GameState,
## so chunk streaming or reloads never duplicate NPCs or re-grant rewards.

const SPAWN_RADIUS: float = 85.0
const DESPAWN_RADIUS: float = 115.0

var main: Node
var assets: AssetLibrary
var world: WorldManager
var player: PlayerController
var entries: Array = []
var nodes: Dictionary = {}
var tick: float = 0.0
var navzones: Dictionary = {}
var arena: Arena
var inside_triggers: Dictionary = {}

func setup(owner_main: Node, library: AssetLibrary, world_manager: WorldManager, hero: PlayerController) -> void:
	main = owner_main
	assets = library
	world = world_manager
	player = hero
	entries = ContentDB.get_data("entities").get("entities", [])
	for entry: Dictionary in entries:
		if entry["type"] == "arena":
			arena = Arena.new()
			arena.name = "Arena"
			add_child(arena)
			arena.setup(entry, world.layout)

func entry(id: String) -> Dictionary:
	for candidate: Dictionary in entries:
		if candidate["id"] == id:
			return candidate
	return {}

func node_for(id: String) -> Node:
	var node: Variant = nodes.get(id)
	return node if node != null and is_instance_valid(node) else null

func clear_all() -> void:
	for id: String in nodes.keys():
		var node: Node = node_for(id)
		if node:
			node.queue_free()
	nodes.clear()
	inside_triggers.clear()

func _process(delta: float) -> void:
	if player == null or main == null or not main.initialized:
		return
	tick -= delta
	if tick > 0.0:
		return
	tick = 0.25
	update_now()

func update_now() -> void:
	var origin: Vector3 = player.global_position
	for data: Dictionary in entries:
		var type: String = data["type"]
		if type in ["arena"]:
			continue
		var position_rule: Dictionary = _position_rule(data)
		if position_rule.is_empty():
			continue
		var flat: Vector2 = Vector2(float(position_rule["pos"][0]), float(position_rule["pos"][1]))
		var distance: float = Vector2(origin.x, origin.z).distance_to(flat)
		match type:
			"trigger":
				_update_trigger(data, distance)
			"poi":
				if distance < float(data.get("radius", 12.0)):
					main.discover(data)
			"navzone":
				if distance < 80.0 and not navzones.has(data["id"]):
					_bake_navzone(data)
			_:
				_update_spawn(data, position_rule, distance)

func _position_rule(data: Dictionary) -> Dictionary:
	if data.has("positions"):
		for rule: Dictionary in data["positions"]:
			if main.quests.check(rule.get("if", [])):
				return rule
		return {}
	return {"pos": data["pos"], "yaw": data.get("yaw", 0.0)}

func should_exist(data: Dictionary) -> bool:
	if not main.quests.check(data.get("if", [])):
		return false
	if data["type"] == "enemy":
		if main.state.has_flag("dead:" + String(data["id"])):
			return false
		if main.state.camp_kills.has(data["id"]):
			return false
	return true

func _update_spawn(data: Dictionary, rule: Dictionary, distance: float) -> void:
	var id: String = data["id"]
	var node: Node3D = node_for(id) as Node3D
	var wanted: bool = should_exist(data)
	if node:
		var moved: bool = data.has("positions") and node.has_meta("rule_pos") and node.get_meta("rule_pos") != rule["pos"]
		var busy: bool = node is Enemy and (node as Enemy).state in ["chase", "attack", "stagger", "hit", "alert", "dead"]
		if node is Enemy and (node as Enemy).state == "dead":
			return
		if (not wanted and not busy) or (distance > DESPAWN_RADIUS and not busy) or (moved and distance > 25.0):
			node.queue_free()
			nodes.erase(id)
		return
	if not wanted or distance > SPAWN_RADIUS:
		return
	var x: float = float(rule["pos"][0])
	var z: float = float(rule["pos"][1])
	if data["type"] == "enemy" and not world.is_position_ready(Vector3(x, 0, z)):
		return
	var spawned: Node3D = _create(data)
	if spawned == null:
		return
	nodes[id] = spawned
	spawned.set_meta("rule_pos", rule["pos"])
	var y: float = world.height_at(x, z)
	if spawned is Enemy:
		(spawned as Enemy).activate(Vector3(x, y + 0.2, z), player)
	elif spawned is Npc:
		(spawned as Npc).place(Vector3(x, y, z), float(rule.get("yaw", 0.0)))
	else:
		spawned.global_position = Vector3(x, y, z)
		spawned.rotation.y = deg_to_rad(float(rule.get("yaw", 0.0)))

func _create(data: Dictionary) -> Node3D:
	match String(data["type"]):
		"npc":
			var npc: Npc = Npc.new()
			npc.name = String(data["id"])
			add_child(npc)
			npc.setup(data, assets, world.layout)
			return npc
		"enemy":
			var enemy_data: Dictionary = ContentDB.enemy(String(data["enemy"]))
			var enemy: Enemy
			match String(enemy_data.get("class", "")):
				"boar":
					enemy = Boar.new()
				"guardian":
					enemy = Guardian.new()
				_:
					enemy = Enemy.new()
			enemy.name = String(data["id"])
			add_child(enemy)
			enemy.setup(data, assets, world)
			enemy.defeated.connect(main.on_enemy_defeated.bind(data))
			main.on_enemy_spawned(enemy, data)
			return enemy
		"shrine", "chest", "echo", "diary", "chime", "memory_core", "seal_gate":
			var item: Interactable = Interactable.new()
			item.name = String(data["id"])
			add_child(item)
			item.setup(data, assets, main)
			return item
	return null

func _update_trigger(data: Dictionary, distance: float) -> void:
	var id: String = data["id"]
	var inside: bool = distance < float(data.get("radius", 8.0)) and main.quests.check(data.get("if", []))
	if inside and not inside_triggers.get(id, false):
		if data.has("start_quest"):
			main.quests.start(String(data["start_quest"]))
		main.quests.notify(String(data["event"]))
	inside_triggers[id] = inside

func _bake_navzone(data: Dictionary) -> void:
	## Parses the colliders already streamed in around the encounter and bakes off-thread.
	var size: float = float(data.get("size", 40.0))
	var center: Vector2 = Vector2(float(data["pos"][0]), float(data["pos"][1]))
	for offset: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
		var corner: Vector2 = center + offset * size * 0.8
		if not world.is_position_ready(Vector3(corner.x, 0, corner.y)):
			return
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.agent_radius = 0.5
	mesh.agent_height = 2.0
	mesh.agent_max_climb = 0.5
	mesh.agent_max_slope = 42.0
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = Combat.LAYER_WORLD
	var low: float = world.height_at(center.x, center.y) - 20.0
	mesh.filter_baking_aabb = AABB(Vector3(center.x - size * 0.5, low, center.y - size * 0.5), Vector3(size, 60.0, size))
	var source: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, main)
	var region: NavigationRegion3D = NavigationRegion3D.new()
	region.name = "Nav_" + String(data["id"])
	add_child(region)
	navzones[data["id"]] = region
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, source, func() -> void:
		if is_instance_valid(region):
			region.navigation_mesh = mesh)
