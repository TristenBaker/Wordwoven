class_name ForgeDrawingBoard
extends Control
signal changed

var strokes: Array[PackedVector2Array] = []
var drawing := false
var locked := false

func _ready() -> void:
	custom_minimum_size = Vector2(300, 260)
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	gui_input.connect(_input_stroke)

func clear_drawing() -> void:
	strokes.clear()
	drawing = false
	queue_redraw()
	changed.emit()

func has_ink() -> bool:
	var distance := 0.0
	for stroke: PackedVector2Array in strokes:
		for i: int in range(1, stroke.size()):
			distance += stroke[i].distance_to(stroke[i - 1])
	return distance > 0.08

func _input_stroke(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		drawing = event.pressed
		if drawing:
			strokes.append(PackedVector2Array())
			_add(event.position)
		accept_event()
	elif event is InputEventMouseMotion and drawing:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			drawing = false
			return
		_add(event.position)
		accept_event()

func _add(point: Vector2) -> void:
	var normalized := (point / size).clamp(Vector2.ZERO, Vector2.ONE)
	if strokes[-1].is_empty() or strokes[-1][-1].distance_to(normalized) > 0.003:
		strokes[-1].append(normalized)
		queue_redraw()
		changed.emit()

func _draw() -> void:
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	for stroke: PackedVector2Array in strokes:
		for i: int in stroke.size():
			var point := stroke[i] * size
			draw_circle(point, 5, Color("ffe0aa"))
			if i > 0:
				draw_line(stroke[i - 1] * size, point, Color("ffe0aa"), 10, true)

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("151321")
	style.border_color = Color("ac7847")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	return style

func pixels() -> PackedFloat32Array:
	# Match training: tight bounds, longest axis 20px, centered on a 28px image.
	var bounds := Rect2()
	var first := true
	for stroke: PackedVector2Array in strokes:
		for point: Vector2 in stroke:
			if first:
				bounds = Rect2(point * size, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(point * size)
	bounds = bounds.grow(5.0)
	var factor := 20.0 / maxf(bounds.size.x, bounds.size.y)
	var offset := (Vector2(28, 28) - bounds.size * factor) * 0.5
	var radius := 5.0 * factor
	var result := PackedFloat32Array()
	result.resize(784)
	for stroke: PackedVector2Array in strokes:
		for i: int in stroke.size():
			var end := (stroke[i] * size - bounds.position) * factor + offset
			var start := (stroke[maxi(0, i - 1)] * size - bounds.position) * factor + offset
			for y: int in range(maxi(0, floori(minf(start.y, end.y) - radius - 1)), mini(28, ceili(maxf(start.y, end.y) + radius + 1))):
				for x: int in range(maxi(0, floori(minf(start.x, end.x) - radius - 1)), mini(28, ceili(maxf(start.x, end.x) + radius + 1))):
					var point := Vector2(x + 0.5, y + 0.5)
					var nearest := Geometry2D.get_closest_point_to_segment(point, start, end)
					var ink := clampf(radius + 0.5 - point.distance_to(nearest), 0.0, 1.0)
					result[y * 28 + x] = maxf(result[y * 28 + x], ink)
	return result
