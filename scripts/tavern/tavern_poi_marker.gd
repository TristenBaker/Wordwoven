extends Control
## A dark map-pin backing drawn at UI resolution, with the art above it.

var direction := Vector2.UP:
	set(value):
		direction = value.normalized()
		queue_redraw()
var highlighted := false:
	set(value):
		highlighted = value
		queue_redraw()


func setup(texture: Texture2D) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_meta("poi_icon", true)
	resized.connect(queue_redraw)
	var image := TextureRect.new()
	image.name = "Icon"
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(image)
	image.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	image.offset_left = 16
	image.offset_right = -16
	image.offset_top = 16
	image.offset_bottom = -16


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 10.0
	var outline := PackedVector2Array([center + direction * (radius + 9.0)])
	for index: int in 65:
		var angle := direction.angle() + 0.27 + (TAU - 0.54) * index / 64.0
		outline.append(center + Vector2.from_angle(angle) * radius)
	draw_circle(center + Vector2(0, 3), radius + 2, Color(0, 0, 0, 0.35))
	draw_colored_polygon(outline, Color("172333") if highlighted else Color("101722"))
	outline.append(outline[0])
	draw_polyline(outline, Color("ffe1a0") if highlighted else Color("bc965b"), 2.5, true)
	draw_arc(center, radius - 4, 0, TAU, 64, Color(0.78, 0.62, 0.35, 0.25), 1, true)
