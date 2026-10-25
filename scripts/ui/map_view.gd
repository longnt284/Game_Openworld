class_name MapView
extends Control
## Painted overview of the valley generated from WorldLayout (cached once, built
## off-thread, or a few rows per frame on single-threaded web builds), with discovered
## places, shrines, the tracked objective and the player.

const RESOLUTION: float = 2.0

static var texture: ImageTexture
static var image: Image
static var task: int = -1
static var bounds: Rect2
static var next_row: int = -1
static var source: WorldLayout

var main: Node

static func prepare(layout: WorldLayout) -> void:
	if task != -1 or texture != null or next_row != -1:
		return
	bounds = layout.bounds
	if OS.has_feature("nothreads"):
		# A task would run inline here and stall the first frame for seconds.
		source = layout
		image = _blank(layout)
		next_row = 0
		return
	task = WorkerThreadPool.add_task(func() -> void: image = _paint(layout))

static func step(rows: int) -> void:
	## Paints the next rows of the incremental (no-threads) map.
	if next_row < 0 or texture != null:
		return
	for index: int in range(rows):
		if next_row >= image.get_height():
			texture = ImageTexture.create_from_image(image)
			source = null
			next_row = -1
			return
		_paint_row(source, image, next_row)
		next_row += 1

static func poll() -> void:
	## Turns a finished background painting into the texture (the minimap asks every refresh,
	## so the corner map appears without the full map ever being opened).
	if texture == null and task != -1 and WorkerThreadPool.is_task_completed(task):
		WorkerThreadPool.wait_for_task_completion(task)
		texture = ImageTexture.create_from_image(image)

static func shutdown() -> void:
	## Worker tasks must finish before the engine tears down.
	if task != -1 and texture == null:
		WorkerThreadPool.wait_for_task_completion(task)
		texture = ImageTexture.create_from_image(image)

static func _blank(layout: WorldLayout) -> Image:
	return Image.create(int(layout.bounds.size.x / RESOLUTION), int(layout.bounds.size.y / RESOLUTION), false, Image.FORMAT_RGB8)

static func _paint(layout: WorldLayout) -> Image:
	var result: Image = _blank(layout)
	for py: int in range(result.get_height()):
		_paint_row(layout, result, py)
	return result

static func _paint_row(layout: WorldLayout, result: Image, py: int) -> void:
	var light: Vector3 = Vector3(-0.5, 0.75, -0.4).normalized()
	for px: int in range(result.get_width()):
		var x: float = layout.bounds.position.x + px * RESOLUTION
		var z: float = layout.bounds.position.y + py * RESOLUTION
		var h: float = layout.height_at(x, z)
		var dx: float = layout.height_at(x + RESOLUTION, z) - h
		var dz: float = layout.height_at(x, z + RESOLUTION) - h
		var normal: Vector3 = Vector3(-dx, RESOLUTION, -dz).normalized()
		var color: Color = layout.ground_color(x, z, h, 1.0 - normal.y * normal.y)
		var water: Dictionary = layout.water_at(x, z)
		if not water.is_empty():
			color = Color("4f9fb0")
		elif layout.in_chasm(x, z):
			color = Color("2a3436")
		var shade: float = clampf(normal.dot(light) * 1.1, 0.55, 1.15)
		color = Color(color.r * shade, color.g * shade, color.b * shade).lerp(Color("efe3c2"), 0.18)
		result.set_pixel(px, py, color)

func _process(_delta: float) -> void:
	MapView.poll()
	queue_redraw()

func _map_rect() -> Rect2:
	if texture == null:
		return Rect2(Vector2.ZERO, size)
	var aspect: float = bounds.size.x / bounds.size.y
	var height: float = size.y
	var width: float = height * aspect
	if width > size.x:
		width = size.x
		height = width / aspect
	return Rect2(Vector2((size.x - width) * 0.5, (size.y - height) * 0.5), Vector2(width, height))

func to_map(world_x: float, world_z: float) -> Vector2:
	var rect: Rect2 = _map_rect()
	return rect.position + Vector2((world_x - bounds.position.x) / bounds.size.x, (world_z - bounds.position.y) / bounds.size.y) * rect.size

func _draw() -> void:
	var font: Font = UiTheme.BOLD_FONT
	if texture == null:
		draw_string(font, size * 0.5 - Vector2(120, 0), "Đang vẽ bản đồ…", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiTheme.CREAM)
		return
	var rect: Rect2 = _map_rect()
	draw_rect(rect.grow(6), Color(0.08, 0.12, 0.12))
	draw_texture_rect(texture, rect, false)
	draw_rect(rect, UiTheme.JADE.darkened(0.2), false, 2.0)
	var state: GameState = main.state
	for entity: Dictionary in ContentDB.get_data("entities").get("entities", []):
		var point: Vector2 = to_map(float(entity["pos"][0]), float(entity["pos"][1])) if entity.has("pos") else Vector2.ZERO
		match String(entity["type"]):
			"poi":
				if state.discovered.has(entity["id"]):
					draw_circle(point, 4.0, UiTheme.CREAM)
					draw_string(font, point + Vector2(8, 5), String(entity["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.INK)
			"shrine":
				var lit: bool = state.has_flag("lit:" + String(entity["id"]))
				draw_colored_polygon(PackedVector2Array([point + Vector2(0, -8), point + Vector2(7, 4), point + Vector2(-7, 4)]), UiTheme.JADE_LIGHT if lit else Color(0.4, 0.45, 0.45))
	var tracked: String = state.tracked_quest
	if tracked != "":
		var marker: Variant = main.quests.marker(tracked)
		if marker != null:
			var point: Vector2 = to_map((marker as Vector2).x, (marker as Vector2).y)
			draw_colored_polygon(PackedVector2Array([point + Vector2(0, -9), point + Vector2(7, 0), point + Vector2(0, 9), point + Vector2(-7, 0)]), UiTheme.GOLD)
	if main.player:
		var player_point: Vector2 = to_map(main.player.global_position.x, main.player.global_position.z)
		var forward: Vector2 = Vector2(main.player.facing.x, main.player.facing.z).normalized() * 11.0
		var side: Vector2 = Vector2(-forward.y, forward.x) * 0.55
		draw_colored_polygon(PackedVector2Array([player_point + forward, player_point - forward * 0.6 + side, player_point - forward * 0.6 - side]), UiTheme.VERMILION)
	draw_string(font, rect.position + Vector2(rect.size.x + 18, 24), "Bắc ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiTheme.CREAM)
	var legend: Array = [["▲", "Miếu Gió (sáng: đã thắp)", UiTheme.JADE_LIGHT], ["◆", "Mục tiêu đang theo dõi", UiTheme.GOLD], ["➤", "Lâm An", UiTheme.VERMILION]]
	for index: int in range(legend.size()):
		draw_string(font, rect.position + Vector2(rect.size.x + 18, 64 + index * 26), "%s  %s" % [legend[index][0], legend[index][1]], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, legend[index][2])
