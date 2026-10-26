class_name IceHoleButton
extends Button

@export_range(1, 3) var hole_number: int = 1
@export var use_background_art: bool = false

var _hovered: bool = false


func _ready() -> void:
	flat = true
	text = ""
	mouse_entered.connect(func() -> void: _hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hovered = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.43)
	var outer := Vector2(size.x * 0.39, size.y * 0.29)
	if use_background_art:
		_draw_art_hotspot(center, outer)
		return
	var glow: Color = Color("6fe4c0") if (_hovered or has_focus()) \
			and not disabled else Color("7596a0")
	var rim: Color = Color("b9e6e7") if not disabled else Color("65777a")
	var water: Color = Color("09202b") if not disabled else Color("172326")
	draw_set_transform(Vector2(0, 5))
	draw_colored_polygon(_ellipse(center, outer + Vector2(8, 7)), Color(0, 0, 0, 0.38))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(_ellipse(center, outer + Vector2(5, 5)), glow)
	draw_colored_polygon(_ellipse(center, outer), rim)
	draw_colored_polygon(_ellipse(center, outer * Vector2(0.78, 0.64)), water)
	draw_arc(center, outer.x * 0.72, PI * 0.16, PI * 0.82, 20, Color(0.55, 0.86, 0.93, 0.7), 2.0, true)
	_draw_crack(center + Vector2(-outer.x * 0.69, -2), Vector2(-18, -13))
	_draw_crack(center + Vector2(outer.x * 0.67, 2), Vector2(19, -11))
	_draw_crack(center + Vector2(outer.x * 0.2, -outer.y * 0.78), Vector2(6, -15))
	var label := "SPENT" if disabled else "HOLE %s" % _roman(hole_number)
	var font: Font = get_theme_default_font()
	var font_size: int = 17
	var label_width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - label_width) * 0.5, size.y - 8), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			Color("ead9ad") if not disabled else Color("778385"))


func _draw_art_hotspot(center: Vector2, radius: Vector2) -> void:
	var outline: Color = Color("efd18a") if (_hovered or has_focus()) \
			and not disabled else Color(0.7, 0.9, 0.92, 0.22)
	var points: PackedVector2Array = _ellipse(center, radius)
	if _hovered or has_focus():
		draw_colored_polygon(points, Color(0.25, 0.88, 0.72, 0.11))
	elif disabled:
		draw_colored_polygon(points, Color(0.02, 0.04, 0.05, 0.48))
	points.append(points[0])
	draw_polyline(points, outline, 4.0 if (_hovered or has_focus()) else 2.0, true)
	var label := "SPENT" if disabled else "HOLE %s" % _roman(hole_number)
	var font: Font = get_theme_default_font()
	var font_size: int = 18
	var label_width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var label_position := Vector2((size.x - label_width) * 0.5, size.y - 5)
	draw_string(font, label_position + Vector2(2, 2), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.9))
	draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			Color("efd18a") if not disabled else Color("8b999a"))


func _ellipse(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in 40:
		var angle: float = TAU * float(index) / 40.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points


func _draw_crack(origin: Vector2, direction: Vector2) -> void:
	var end := origin + direction
	draw_line(origin, end, Color("d9f4f2"), 2.0, true)
	draw_line(origin + direction * 0.52, origin + direction * 0.52 + Vector2(-direction.y, direction.x).normalized() * 8.0,
			Color("b4dddf"), 1.5, true)


func _roman(value: int) -> String:
	return ["I", "II", "III"][clampi(value - 1, 0, 2)]


func set_spent(value: bool) -> void:
	disabled = value
	queue_redraw()
