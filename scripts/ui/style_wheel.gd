class_name StyleWheel
extends Control
## Vòng Kiếm Quyết: held on the style-wheel key in a fight, six slices around the screen centre,
## one per Kiếm Quyết (locked ones greyed with their unlock hint). Mouse movement or the number
## keys 1–6 pick a slice; releasing the key equips the whole style on E, Q and X (main does it
## through the chosen signal). The world slows while it is open (main), never pauses.

signal chosen(style: String)

const RADIUS: float = 200.0
const INNER: float = 84.0
## Mouse travel (px) before a direction counts as a pick.
const DEADZONE: float = 26.0

var styles: Array = []
var learned: Dictionary = {}
var current: String = ""
var selected: int = -1
var aim: Vector2 = Vector2.ZERO
var opened: float = 0.0

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func open(learned_styles: Array[String], equipped: String) -> void:
	styles = StyleBook.styles()
	learned.clear()
	for style: String in learned_styles:
		learned[style] = true
	current = equipped
	selected = styles.find(equipped)
	aim = Vector2.ZERO
	opened = 0.0
	visible = true
	queue_redraw()

func close(apply: bool) -> void:
	if not visible:
		return
	visible = false
	if apply and selected >= 0 and learned.has(styles[selected]) and String(styles[selected]) != current:
		chosen.emit(String(styles[selected]))

func is_open() -> bool:
	return visible

func pick(index: int) -> void:
	if index >= 0 and index < styles.size():
		selected = index
		queue_redraw()

func steer(motion: Vector2) -> void:
	## Relative mouse motion while the wheel is up: the direction from the centre picks a slice.
	aim = (aim + motion).limit_length(140.0)
	if aim.length() < DEADZONE or styles.is_empty():
		return
	var angle: float = fposmod(aim.angle() + PI * 0.5 + PI / styles.size(), TAU)
	pick(int(angle / (TAU / styles.size())) % styles.size())

func _process(delta: float) -> void:
	if visible and opened < 1.0:
		opened = minf(1.0, opened + delta * 9.0)
		queue_redraw()

func _draw() -> void:
	if styles.is_empty():
		return
	var center: Vector2 = size * 0.5
	var grow: float = 0.85 + 0.15 * opened
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.06, 0.38 * opened))
	var span: float = TAU / styles.size()
	for index: int in range(styles.size()):
		var style: String = styles[index]
		var data: Dictionary = ContentDB.style(style)
		var color: Color = StyleBook.color(style)
		var known: bool = learned.has(style)
		var from: float = -PI * 0.5 - span * 0.5 + index * span + 0.03
		var to: float = from + span - 0.06
		var outer: float = RADIUS * grow * (1.06 if index == selected else 1.0)
		var slice: PackedVector2Array = UiDraw.sector(center, INNER * grow, outer, from, to)
		var fill: Color = Color(color.darkened(0.55), 0.92) if known else Color(0.12, 0.14, 0.15, 0.85)
		if index == selected:
			fill = Color(color.darkened(0.15), 0.96) if known else Color(0.22, 0.24, 0.25, 0.92)
		draw_colored_polygon(slice, fill)
		var rim: PackedVector2Array = slice.duplicate()
		rim.append(slice[0])
		draw_polyline(rim, color.lightened(0.3) if index == selected and known else UiDraw.INK, 3.0 if index == selected else 2.0, true)
		var middle: Vector2 = center + Vector2.from_angle((from + to) * 0.5) * (INNER + outer) * 0.5
		UiDraw.element_icon(self, middle + Vector2(0, -12), 22.0, String(data.get("icon", "")), color if known else UiDraw.LOCKED)
		if not known:
			UiDraw.padlock(self, middle + Vector2(18, -2), 14.0)
		var name: String = String(data.get("name", style)).trim_suffix(" Quyết")
		UiDraw.outlined_text(self, middle + Vector2(-70, 30), name, 15, Color.WHITE if known else Color(0.7, 0.72, 0.7), 140.0)
		UiDraw.outlined_text(self, middle + Vector2(-70, -40), str(index + 1), 13, UiTheme.GOLD, 140.0, HORIZONTAL_ALIGNMENT_CENTER, 4)
		if style == current:
			draw_arc(middle + Vector2(0, -12), 32.0, 0.0, TAU, 32, Color(UiTheme.GOLD, 0.9), 3.0, true)
	draw_circle(center, INNER * grow - 6.0, Color(0.04, 0.09, 0.1, 0.94))
	draw_arc(center, INNER * grow - 6.0, 0.0, TAU, 48, UiTheme.JADE, 3.0, true)
	if selected < 0:
		return
	var chosen_style: String = styles[selected]
	var info: Dictionary = ContentDB.style(chosen_style)
	var known_style: bool = learned.has(chosen_style)
	UiDraw.outlined_text(self, center + Vector2(-INNER, -14), String(info.get("name", "")), 16, StyleBook.color(chosen_style) if known_style else Color(0.75, 0.76, 0.74), INNER * 2.0)
	if known_style:
		var forms: PackedStringArray = []
		for slot: String in StyleBook.SLOTS:
			forms.append(String(StyleBook.form(chosen_style, slot).get("name", "")))
		UiDraw.outlined_text(self, center + Vector2(-INNER, 8), forms[0], 12, UiTheme.CREAM, INNER * 2.0, HORIZONTAL_ALIGNMENT_CENTER, 4)
		UiDraw.outlined_text(self, center + Vector2(-INNER, 24), forms[1], 12, UiTheme.CREAM, INNER * 2.0, HORIZONTAL_ALIGNMENT_CENTER, 4)
		UiDraw.outlined_text(self, center + Vector2(-INNER, 40), forms[2], 12, UiTheme.GOLD, INNER * 2.0, HORIZONTAL_ALIGNMENT_CENTER, 4)
	else:
		UiDraw.outlined_text(self, center + Vector2(-INNER, 12), "Chưa lĩnh hội", 13, UiTheme.MUTED, INNER * 2.0, HORIZONTAL_ALIGNMENT_CENTER, 4)
	var hint: String = StyleBook.unlock_hint(chosen_style) if not known_style else String(info.get("role", ""))
	UiDraw.outlined_text(self, Vector2(center.x - 360, center.y + RADIUS * grow + 40), hint, 16, UiTheme.CREAM, 720.0)
	UiDraw.outlined_text(self, Vector2(center.x - 360, center.y - RADIUS * grow - 22), "Rê chuột hoặc bấm 1–6 • thả phím để trang bị cả bộ E / Q / X", 15, UiTheme.JADE_LIGHT, 720.0)
