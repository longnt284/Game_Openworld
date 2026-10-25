class_name UiDraw
extends RefCounted
## Vector glyphs drawn with the CanvasItem API, so no icon depends on a font or a texture:
## the six elements of the Kiếm Quyết, a padlock and a few shared shapes. Every glyph has an
## ink rim so it reads on bright skies and on dark panels alike.

const INK: Color = Color(0.05, 0.1, 0.11, 0.9)
const LOCKED: Color = Color(0.45, 0.5, 0.5)

static func element_icon(canvas: CanvasItem, center: Vector2, radius: float, icon: String, color: Color) -> void:
	## icon: "wind", "water", "thunder", "flame", "frost" or "earth" (data/styles.json "icon").
	var light: Color = color.lightened(0.45)
	var rim: float = maxf(2.0, radius * 0.16)
	match icon:
		"wind":
			for row: int in range(3):
				var y: float = center.y + (row - 1) * radius * 0.48
				var start: float = center.x - radius * (0.85 - row * 0.12)
				var length: float = radius * [1.35, 1.6, 1.05][row]
				var curl: Vector2 = Vector2(start + length, y - radius * 0.18)
				canvas.draw_line(Vector2(start, y), Vector2(start + length, y), INK, rim + radius * 0.2, true)
				canvas.draw_arc(curl, radius * 0.18, -PI * 0.5, PI * 0.6, 10, INK, rim + radius * 0.2, true)
				canvas.draw_line(Vector2(start, y), Vector2(start + length, y), color, radius * 0.2, true)
				canvas.draw_arc(curl, radius * 0.18, -PI * 0.5, PI * 0.6, 10, color, radius * 0.2, true)
		"water":
			var drop: PackedVector2Array = PackedVector2Array([center + Vector2(0, -radius * 0.95)])
			var body: Vector2 = center + Vector2(0, radius * 0.22)
			for step: int in range(15):
				var angle: float = deg_to_rad(-25.0 + 230.0 * step / 14.0)
				drop.append(body + Vector2(cos(angle), sin(angle)) * radius * 0.66)
			_shape(canvas, drop, color, rim)
			canvas.draw_arc(body + Vector2(-radius * 0.18, -radius * 0.05), radius * 0.34, PI * 0.55, PI * 1.05, 8, light, radius * 0.14, true)
		"thunder":
			var bolt: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in [Vector2(0.2, -0.95), Vector2(-0.5, 0.12), Vector2(-0.06, 0.12), Vector2(-0.24, 0.95), Vector2(0.52, -0.2), Vector2(0.08, -0.2)]:
				bolt.append(center + point * radius)
			_shape(canvas, bolt, color, rim)
		"flame":
			_shape(canvas, _flame(center, radius), color, rim)
			_shape(canvas, _flame(center + Vector2(0, radius * 0.28), radius * 0.52), light, 0.0)
		"frost":
			for spoke: int in range(3):
				var direction: Vector2 = Vector2.from_angle(PI * 0.5 + PI * spoke / 3.0)
				canvas.draw_line(center - direction * radius * 0.92, center + direction * radius * 0.92, INK, rim + radius * 0.18, true)
			for spoke: int in range(3):
				var direction: Vector2 = Vector2.from_angle(PI * 0.5 + PI * spoke / 3.0)
				canvas.draw_line(center - direction * radius * 0.92, center + direction * radius * 0.92, color, radius * 0.18, true)
				for side: float in [-1.0, 1.0]:
					var base: Vector2 = center + direction * side * radius * 0.55
					for turn: float in [-0.7, 0.7]:
						canvas.draw_line(base, base + direction.rotated(turn) * side * radius * 0.3, color, radius * 0.12, true)
			canvas.draw_circle(center, radius * 0.16, light)
		"earth":
			var ridge: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in [Vector2(-0.95, 0.62), Vector2(-0.32, -0.5), Vector2(-0.02, -0.08), Vector2(0.3, -0.82), Vector2(0.95, 0.62)]:
				ridge.append(center + point * radius)
			_shape(canvas, ridge, color, rim)
			var cap: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in [Vector2(0.3, -0.82), Vector2(0.5, -0.38), Vector2(0.36, -0.44), Vector2(0.24, -0.34), Vector2(0.12, -0.42)]:
				cap.append(center + point * radius)
			canvas.draw_colored_polygon(cap, light)
			canvas.draw_line(center + Vector2(-radius, radius * 0.66), center + Vector2(radius, radius * 0.66), INK, rim, true)
		_:
			canvas.draw_circle(center, radius * 0.6, INK)
			canvas.draw_circle(center, radius * 0.5, color)

static func _flame(center: Vector2, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var base: Vector2 = center + Vector2(0, radius * 0.3)
	for step: int in range(11):
		var angle: float = deg_to_rad(-15.0 + 210.0 * step / 10.0)
		points.append(base + Vector2(cos(angle), sin(angle)) * radius * 0.6)
	points.append(center + Vector2(-radius * 0.58, -radius * 0.2))
	points.append(center + Vector2(-radius * 0.3, -radius * 0.42))
	points.append(center + Vector2(-radius * 0.18, -radius * 0.12))
	points.append(center + Vector2(radius * 0.06, -radius * 0.95))
	points.append(center + Vector2(radius * 0.42, -radius * 0.42))
	points.append(center + Vector2(radius * 0.6, -radius * 0.05))
	return points

static func _shape(canvas: CanvasItem, points: PackedVector2Array, color: Color, rim: float) -> void:
	canvas.draw_colored_polygon(points, color)
	if rim > 0.0:
		var closed: PackedVector2Array = points.duplicate()
		closed.append(points[0])
		canvas.draw_polyline(closed, INK, rim, true)

static func padlock(canvas: CanvasItem, center: Vector2, size: float, color: Color = Color(0.85, 0.85, 0.8)) -> void:
	var body: Rect2 = Rect2(center + Vector2(-size * 0.5, -size * 0.1), Vector2(size, size * 0.75))
	canvas.draw_arc(center + Vector2(0, -size * 0.12), size * 0.3, PI, TAU, 10, INK, size * 0.24, true)
	canvas.draw_arc(center + Vector2(0, -size * 0.12), size * 0.3, PI, TAU, 10, color, size * 0.13, true)
	canvas.draw_rect(body.grow(size * 0.08), INK)
	canvas.draw_rect(body, color)
	canvas.draw_circle(center + Vector2(0, size * 0.22), size * 0.1, INK)

static func outlined_text(canvas: CanvasItem, position: Vector2, text: String, size: int, color: Color, width: float = -1.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, outline: int = 5) -> void:
	## Text with an ink outline; position is the left end of the baseline (or of the width box).
	var font: Font = UiTheme.BOLD_FONT
	canvas.draw_string_outline(font, position, text, align, width, size, outline, INK)
	canvas.draw_string(font, position, text, align, width, size, color)

static func sector(center: Vector2, inner: float, outer: float, from_angle: float, to_angle: float, steps: int = 16) -> PackedVector2Array:
	## A ring slice between two angles (radians, 0 = right, clockwise on screen).
	var points: PackedVector2Array = PackedVector2Array()
	for step: int in range(steps + 1):
		points.append(center + Vector2.from_angle(lerpf(from_angle, to_angle, float(step) / steps)) * outer)
	for step: int in range(steps, -1, -1):
		points.append(center + Vector2.from_angle(lerpf(from_angle, to_angle, float(step) / steps)) * inner)
	return points
