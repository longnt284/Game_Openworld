class_name Minimap
extends Control
## Corner minimap, north up: the painted valley (MapView's texture) around Lâm An, lit shrines,
## the tracked objective (pinned to the rim when it is out of range), nearby foes as red dots
## (bosses larger), villagers as cream dots and Lâm An's arrow turned with the camera. Redrawn
## at most REDRAW_HZ times a second from main's HUD refresh.

const SPAN: float = 110.0
const REDRAW_HZ: float = 10.0

var main: Node
var center_world: Vector2 = Vector2.ZERO
var heading: float = 0.0
var since_draw: float = 1.0
var _frame: StyleBoxFlat

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = UiTheme.box(Color(0.04, 0.08, 0.09, 0.9), UiTheme.JADE.darkened(0.15), 3, 18)
	_frame.shadow_color = UiTheme.LIP
	_frame.shadow_offset = Vector2(0, 4)

func refresh(delta: float) -> void:
	since_draw += delta
	if since_draw < 1.0 / REDRAW_HZ or main == null or main.player == null:
		return
	since_draw = 0.0
	MapView.poll()
	center_world = Vector2(main.player.global_position.x, main.player.global_position.z)
	var camera: Camera3D = main.player.camera_rig.camera if main.player.camera_rig else null
	if camera:
		var forward: Vector3 = -camera.global_transform.basis.z
		heading = atan2(forward.x, -forward.z)
	queue_redraw()

func _to_map(world_x: float, world_z: float, area: Rect2) -> Vector2:
	return area.get_center() + Vector2(world_x - center_world.x, world_z - center_world.y) / SPAN * area.size

func _draw() -> void:
	draw_style_box(_frame, Rect2(Vector2.ZERO, size))
	var area: Rect2 = Rect2(Vector2(7, 7), size - Vector2(14, 14))
	if MapView.texture != null:
		var texel: float = MapView.RESOLUTION
		var origin: Vector2 = (center_world - MapView.bounds.position) / texel - Vector2(SPAN, SPAN) / texel * 0.5
		var region: Rect2 = Rect2(origin, Vector2(SPAN, SPAN) / texel)
		var tex_size: Vector2 = MapView.texture.get_size()
		# Clip the region to the painted map; outside the valley stays the frame colour.
		var clipped: Rect2 = region.intersection(Rect2(Vector2.ZERO, tex_size))
		if clipped.has_area():
			var target: Rect2 = Rect2(area.position + (clipped.position - region.position) / region.size * area.size, clipped.size / region.size * area.size)
			draw_texture_rect_region(MapView.texture, target, clipped, Color(1, 1, 1, 0.95))
	else:
		UiDraw.outlined_text(self, Vector2(0, size.y * 0.5), "Đang vẽ…", 13, UiTheme.MUTED, size.x)
	if main == null:
		return
	for entity: Dictionary in ContentDB.get_data("entities").get("entities", []):
		if String(entity.get("type", "")) != "shrine" or not entity.has("pos"):
			continue
		var point: Vector2 = _to_map(float(entity["pos"][0]), float(entity["pos"][1]), area)
		if area.has_point(point):
			var lit: bool = main.state.has_flag("lit:" + String(entity["id"]))
			draw_colored_polygon(PackedVector2Array([point + Vector2(0, -7), point + Vector2(6, 4), point + Vector2(-6, 4)]), UiTheme.JADE_LIGHT if lit else Color(0.5, 0.55, 0.55))
	for node: Node in main.get_tree().get_nodes_in_group("npc"):
		var npc: Node3D = node as Node3D
		if npc and npc.visible:
			var point: Vector2 = _to_map(npc.global_position.x, npc.global_position.z, area)
			if area.has_point(point):
				draw_circle(point, 3.6, UiDraw.INK)
				draw_circle(point, 2.6, UiTheme.CREAM)
	for node: Node in main.get_tree().get_nodes_in_group("enemy"):
		var enemy: Enemy = node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var point: Vector2 = _to_map(enemy.global_position.x, enemy.global_position.z, area)
		if area.has_point(point):
			var big: float = 5.5 if enemy.boss else 3.6
			draw_circle(point, big + 1.2, UiDraw.INK)
			draw_circle(point, big, Color("ff5a44"))
	var marker: Variant = main._marker_world()
	if marker != null:
		var target_point: Vector2 = _to_map((marker as Vector3).x, (marker as Vector3).z, area)
		var inside: Rect2 = area.grow(-8)
		if not inside.has_point(target_point):
			var offset: Vector2 = target_point - inside.get_center()
			var scale: float = minf(inside.size.x * 0.5 / maxf(absf(offset.x), 0.001), inside.size.y * 0.5 / maxf(absf(offset.y), 0.001))
			target_point = inside.get_center() + offset * minf(scale, 1.0)
		var diamond: PackedVector2Array = PackedVector2Array([target_point + Vector2(0, -8), target_point + Vector2(7, 0), target_point + Vector2(0, 8), target_point + Vector2(-7, 0)])
		draw_colored_polygon(diamond, UiDraw.INK)
		draw_colored_polygon(PackedVector2Array([target_point + Vector2(0, -6), target_point + Vector2(5, 0), target_point + Vector2(0, 6), target_point + Vector2(-5, 0)]), UiTheme.GOLD)
	var me: Vector2 = area.get_center()
	var forward: Vector2 = Vector2.from_angle(heading - PI * 0.5)
	var side: Vector2 = Vector2(-forward.y, forward.x)
	var arrow: PackedVector2Array = PackedVector2Array([me + forward * 10.0, me - forward * 6.0 + side * 6.5, me - forward * 3.0, me - forward * 6.0 - side * 6.5])
	var rim: PackedVector2Array = arrow.duplicate()
	rim.append(arrow[0])
	draw_colored_polygon(arrow, UiTheme.VERMILION.lightened(0.15))
	draw_polyline(rim, UiDraw.INK, 2.0, true)
	UiDraw.outlined_text(self, Vector2(size.x - 24, 22), "B", 14, UiTheme.CREAM, -1.0, HORIZONTAL_ALIGNMENT_LEFT, 4)
