class_name TavernPanorama
extends Control
## Room coordinates are independent of the HUD and ready for replacement art.
const ROOM_SIZE := Vector2(2560, 1440)
const DRAG_THRESHOLD := 8.0
const BUTTON_THEME := preload("res://assets/Themes/WordWoven_Button_Theme.tres")
static var saved_center := Vector2(1280, 540)

var world: Control
var camera := Vector2.ZERO
var _target := Vector2.ZERO
var _turning := false
var _points: Dictionary = {}
var _indicators: Dictionary = {}
var blocked: Callable
var _pointer_down := false
var _dragged := false
var _press_position := Vector2.ZERO
var _held_button: Button
var _mouse_button := MOUSE_BUTTON_NONE


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	clip_contents = true
	mouse_default_cursor_shape = CURSOR_ARROW
	world = Control.new()
	world.mouse_filter = MOUSE_FILTER_IGNORE
	world.size = ROOM_SIZE
	add_child(world)
	resized.connect(_resize_view)
	_resize_view.call_deferred()


func _resize_view() -> void:
	camera = _clamp_camera(saved_center - size * 0.5)
	_apply_camera()


func add_background(texture: Texture2D) -> void:
	var backdrop := TextureRect.new()
	backdrop.texture = texture
	backdrop.size = ROOM_SIZE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	world.add_child(backdrop)


func portrait(path: String, rect: Rect2, crop_height: float) -> void:
	var texture: Texture2D = load(path)
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2.ZERO, texture.get_size() * Vector2(1, crop_height))
	var actor := TextureRect.new()
	actor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	actor.texture = atlas
	actor.position = rect.position * ROOM_SIZE
	actor.size = rect.size * ROOM_SIZE
	actor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	actor.mouse_filter = MOUSE_FILTER_IGNORE
	world.add_child(actor)


func foreground(texture: Texture2D, region: Rect2) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(region.position * texture.get_size(), region.size * texture.get_size())
	var piece := TextureRect.new()
	piece.texture = atlas
	piece.position = region.position * ROOM_SIZE
	piece.size = region.size * ROOM_SIZE
	piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	piece.mouse_filter = MOUSE_FILTER_IGNORE
	world.add_child(piece)


func prop(title: String, rect: Rect2, color: Color, text_size: int = 24) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position * ROOM_SIZE
	panel.size = rect.size * ROOM_SIZE
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("9c7042")
	style.set_border_width_all(6)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", text_size)
	label.add_theme_color_override("font_color", Color("382016") if color.get_luminance() > 0.4 else Color("f6da9f"))
	label.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(label)
	world.add_child(panel)
	return panel


func add_poi(id: String, title: String, rect: Rect2, button: Button) -> void:
	button.reparent(world, false)
	button.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
	button.text = ""
	button.custom_minimum_size = Vector2.ZERO
	button.position = rect.position * ROOM_SIZE
	button.size = rect.size * ROOM_SIZE
	button.tooltip_text = title
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 0.7, 0.3, 0.05 if state != "normal" else 0.0)
		style.border_color = Color(1, 0.8, 0.4, 0.8 if state != "normal" else 0.0)
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		button.add_theme_stylebox_override(state, style)
	var badge := Label.new()
	badge.text = "◆ " + title
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.position = Vector2(0, button.size.y - 30)
	badge.size = Vector2(button.size.x, 30)
	badge.add_theme_font_size_override("font_size", 20)
	badge.add_theme_color_override("font_color", Color("ffe0a2"))
	badge.add_theme_color_override("font_outline_color", Color("100b08"))
	badge.add_theme_constant_override("outline_size", 7)
	badge.mouse_filter = MOUSE_FILTER_IGNORE
	button.add_child(badge)
	_points[id] = {"center": button.position + button.size * 0.5, "title": title, "badge": badge, "button": button}
	var indicator := Button.new()
	indicator.theme = BUTTON_THEME
	indicator.theme_type_variation = &"WordWovenActionButton"
	indicator.size = Vector2(175, 42)
	indicator.tooltip_text = "Look toward " + title
	indicator.pressed.connect(focus_poi.bind(id))
	add_child(indicator)
	_indicators[id] = indicator


func focus_poi(id: String) -> void:
	_target = _clamp_camera(Vector2(_points[id].center) - size * 0.5)
	_turning = true


func _process(delta: float) -> void:
	var paused: bool = get_tree().paused or (blocked.is_valid() and bool(blocked.call()))
	for indicator: Button in _indicators.values():
		indicator.disabled = paused
	if paused or not get_window().has_focus():
		_cancel_drag()
		return
	if _turning:
		camera = camera.lerp(_target, 1.0 - exp(-7.0 * delta))
		if camera.distance_to(_target) < 1.0:
			camera = _target
			_turning = false
	_apply_camera()


func _input(event: InputEvent) -> void:
	if get_tree().paused or (blocked.is_valid() and bool(blocked.call())):
		_cancel_drag()
		return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if event.pressed:
			if _pointer_down or not get_global_rect().has_point(event.position):
				return
			# Fixed HUD controls and off-screen markers keep normal GUI clicks.
			var hovered := get_viewport().gui_get_hovered_control()
			if hovered != null and hovered != self and not world.is_ancestor_of(hovered):
				return
			for indicator: Button in _indicators.values():
				if indicator.visible and indicator.get_global_rect().has_point(event.position):
					return
			_pointer_down = true
			_dragged = false
			_turning = false
			_press_position = event.position
			_mouse_button = event.button_index
			_held_button = _hotspot_at(event.position) if event.button_index == MOUSE_BUTTON_LEFT else null
			if is_instance_valid(_held_button):
				_held_button.set_pressed_no_signal(true)
			get_viewport().set_input_as_handled()
		elif _pointer_down and event.button_index == _mouse_button:
			var clicked: Button = _held_button if not _dragged and _hotspot_at(event.position) == _held_button else null
			_cancel_drag()
			get_viewport().set_input_as_handled()
			if is_instance_valid(clicked):
				clicked.pressed.emit()
	elif event is InputEventMouseMotion and _pointer_down:
		if not _dragged and event.position.distance_to(_press_position) > DRAG_THRESHOLD:
			_dragged = true
			mouse_default_cursor_shape = CURSOR_DRAG
			camera = _clamp_camera(camera - (event.position - _press_position))
			if is_instance_valid(_held_button):
				_held_button.set_pressed_no_signal(false)
		elif _dragged:
			camera = _clamp_camera(camera - event.relative)
		_apply_camera()
		get_viewport().set_input_as_handled()


func _hotspot_at(point: Vector2) -> Button:
	for poi: Dictionary in _points.values():
		var button: Button = poi.button
		if button.get_global_rect().has_point(point):
			return button
	return null


func _cancel_drag() -> void:
	mouse_default_cursor_shape = CURSOR_ARROW
	if is_instance_valid(_held_button):
		_held_button.set_pressed_no_signal(false)
	_pointer_down = false
	_held_button = null
	_mouse_button = MOUSE_BUTTON_NONE


func _clamp_camera(value: Vector2) -> Vector2:
	return value.clamp(Vector2.ZERO, (ROOM_SIZE - size).max(Vector2.ZERO))


func _apply_camera() -> void:
	world.position = -camera
	saved_center = camera + size * 0.5
	var slots := {"left": 0, "right": 0, "top": 0, "bottom": 0}
	for id: String in _points:
		var point: Vector2 = Vector2(_points[id].center) - camera
		var indicator: Button = _indicators[id]
		var side := ""
		if point.x < 90:
			side = "left"
		elif point.x > size.x - 90:
			side = "right"
		elif point.y < 130:
			side = "top"
		elif point.y > size.y - 125:
			side = "bottom"
		indicator.visible = not side.is_empty()
		_points[id].badge.visible = side.is_empty()
		if side.is_empty():
			continue
		var slot: int = slots[side]
		slots[side] += 1
		match side:
			"left": indicator.position = Vector2(14, 170 + slot * 50)
			"right": indicator.position = Vector2(size.x - 189, 170 + slot * 50)
			"top": indicator.position = Vector2(230 + slot * 185, 110)
			"bottom": indicator.position = Vector2(230 + slot * 185, size.y - 100)
		var arrow: String = {"left": "←", "right": "→", "top": "↑", "bottom": "↓"}[side]
		indicator.text = "%s %s" % [arrow, _points[id].title]
