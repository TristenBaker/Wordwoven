class_name EncounterRouteMap
extends Control
const Balance = preload("res://data/balance/tuning.gd")

## Persistent expedition map. Every node and connection is visible before it
## is reached; node state controls only its color and whether it is selectable.

signal enemy_selected(enemy_id: String)
signal activity_selected(activity_id: String)
signal activity_bypassed(activity_id: String)
signal route_node_selected(route_key: String)

const STAGE_COUNT: int = Balance.RUN_STATE_ENCOUNTERS_PER_RUN
const MAP_PADDING_X: float = 66.0
const COLOR_TRAIL: Color = Color(0.27, 0.34, 0.32, 0.78)
const COLOR_CLEARED: Color = Color(0.76, 0.62, 0.32, 1.0)
const COLOR_CURRENT: Color = Color(0.34, 0.9, 0.61, 1.0)
const COLOR_LOCKED: Color = Color(0.22, 0.28, 0.28, 1.0)
const COLOR_BOSS: Color = Color(0.88, 0.22, 0.18, 1.0)
const COLOR_ACTIVITY: Color = Color(0.66, 0.55, 0.88, 1.0)
const COLOR_COMBAT: Color = Color(0.48, 0.52, 0.51, 1.0)
const COLOR_INK: Color = Color(0.9, 0.88, 0.76, 0.92)

var _stage: int = 1
var _column_count: int = STAGE_COUNT
var _current_column: int = 1
var _nodes: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _button_nodes: Dictionary = {}


func setup_full(stage: int, nodes: Array[Dictionary]) -> void:
	_stage = clampi(stage, 1, STAGE_COUNT)
	_nodes = nodes
	_column_count = STAGE_COUNT
	_current_column = 1
	for node: Dictionary in _nodes:
		_column_count = maxi(_column_count, int(node.get("column_count", 0)))
		if String(node.get("state", "locked")) == "available":
			var column: int = int(node.get("column", node.get("stage", 1)))
			if _current_column == 1 or column < _current_column:
				_current_column = column
	_rebuild_buttons()
	queue_redraw()


## Compatibility path for non-Tundra biomes that still provide one fork.
func setup(stage: int, choices: Array[Dictionary], boss: Dictionary) -> void:
	var nodes: Array[Dictionary] = []
	var source: Array[Dictionary] = choices
	if stage >= STAGE_COUNT and not boss.is_empty():
		source = [boss]
	for index: int in source.size():
		var node: Dictionary = source[index].duplicate(true)
		node["stage"] = clampi(stage, 1, STAGE_COUNT)
		node["column"] = clampi(stage, 1, STAGE_COUNT)
		node["column_count"] = STAGE_COUNT
		node["column_label"] = str(stage)
		node["lane"] = index
		node["lane_count"] = source.size()
		node["state"] = "available"
		if stage >= STAGE_COUNT:
			node["type"] = "boss"
		nodes.append(node)
	setup_full(stage, nodes)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_buttons()
		queue_redraw()


func _draw() -> void:
	if size.x <= MAP_PADDING_X * 2.0:
		return
	_draw_connections()
	_draw_origin()


func _draw_connections() -> void:
	var origin := Vector2(MAP_PADDING_X * 0.42, size.y * 0.5)
	for node: Dictionary in _nodes_at_column(1):
		_draw_dotted_line(origin, _node_point(node), _edge_color(1), 3.0)
	for column: int in range(1, _column_count):
		for from_node: Dictionary in _nodes_at_column(column):
			for to_node: Dictionary in _nodes_at_column(column + 1):
				var next_keys: Array = from_node.get("next_keys", [])
				if not next_keys.is_empty() and not next_keys.has(
						String(to_node.get("route_key", ""))
				):
					continue
				var destination_state: String = String(
						to_node.get("state", "locked")
				)
				var color: Color = COLOR_TRAIL
				if destination_state == "available":
					color = COLOR_CURRENT
				elif destination_state == "completed":
					color = Color(COLOR_CLEARED, 0.78)
				_draw_dotted_line(
						_node_point(from_node), _node_point(to_node),
						color, 3.0
				)


func _draw_origin() -> void:
	var origin := Vector2(MAP_PADDING_X * 0.42, size.y * 0.5)
	draw_circle(origin, 15.0, COLOR_CLEARED.darkened(0.35))
	draw_arc(origin, 15.0, 0.0, TAU, 28, COLOR_CLEARED, 3.0, true)
	_draw_centered_text(origin + Vector2(0, 32), "CAMP", COLOR_INK, 11)


func _draw_stage_labels() -> void:
	for column: int in range(1, _column_count + 1):
		var column_nodes: Array[Dictionary] = _nodes_at_column(column)
		if column_nodes.is_empty():
			continue
		var label: String = String(column_nodes[0].get("column_label", ""))
		var color: Color = COLOR_BOSS if label == "BOSS" else COLOR_INK
		_draw_centered_text(Vector2(_column_x(column), 17.0), label, color, 11)


func _edge_color(destination_column: int) -> Color:
	if destination_column < _current_column:
		return Color(COLOR_CLEARED, 0.78)
	if destination_column == _current_column:
		return COLOR_CURRENT
	return COLOR_TRAIL


func _nodes_at_column(column: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node: Dictionary in _nodes:
		if int(node.get("column", node.get("stage", 0))) == column:
			result.append(node)
	return result


func _rebuild_buttons() -> void:
	for button: Button in _buttons:
		button.queue_free()
	_buttons.clear()
	_button_nodes.clear()
	for node: Dictionary in _nodes:
		_add_node_button(node)
	_layout_buttons.call_deferred()


func _add_node_button(data: Dictionary) -> void:
	var button := Button.new()
	var type: String = String(data.get("type", "enemy"))
	var state: String = String(data.get("state", "locked"))
	var id: String = String(data.get("activity_id", data.get("id", "unknown")))
	button.name = ("Activity_" if type == "activity" else \
			("Pass_" if type == "pass" else "Enemy_")) + id \
			+ "_" + str(data.get("stage", 0)) + "_" + str(data.get("slot", 0))
	if type == "activity":
		button.name = "Activity_" + id
	elif type == "pass":
		button.name = "Pass_" + id
	button.custom_minimum_size = Vector2(118, 58)
	button.disabled = state != "available"
	button.focus_mode = Control.FOCUS_ALL if not button.disabled else Control.FOCUS_NONE
	button.tooltip_text = _tooltip(data)
	button.add_theme_color_override("font_color", COLOR_INK)
	button.add_theme_color_override("font_disabled_color", Color(COLOR_INK, 0.58))
	var accent: Color = _node_accent(data)
	button.add_theme_stylebox_override("normal", _node_style(accent, false, state))
	button.add_theme_stylebox_override("hover", _node_style(accent, true, state))
	button.add_theme_stylebox_override("focus", _node_style(accent, true, state))
	button.add_theme_stylebox_override("pressed", _node_style(accent, true, state))
	button.add_theme_stylebox_override("disabled", _node_style(accent, false, state))
	if state == "available":
		if type == "activity":
			button.pressed.connect(activity_selected.emit.bind(id))
		elif type == "pass":
			button.pressed.connect(activity_bypassed.emit.bind(id))
		else:
			button.pressed.connect(
					_emit_enemy_selected.bind(
							id, String(data.get("route_key", ""))
					)
			)
	add_child(button)
	_add_node_content(button, data)
	_buttons.append(button)
	_button_nodes[button] = data


func _emit_enemy_selected(enemy_id: String, route_key: String) -> void:
	route_node_selected.emit(route_key)
	enemy_selected.emit(enemy_id)


func _tooltip(data: Dictionary) -> String:
	var tooltip: String = String(data.get("tooltip", ""))
	if tooltip.is_empty() and int(data.get("health", 0)) > 0:
		tooltip = "Health %d  •  Attack %d  •  Reward %dg" % [
			data.get("health", 0), data.get("attack", 0), data.get("gold", 0),
		]
	var state: String = String(data.get("state", "locked"))
	if state == "locked":
		return (tooltip + "\nLocked until this stage.").strip_edges()
	if state == "completed":
		return (tooltip + "\nCompleted.").strip_edges()
	if state == "bypassed":
		return "This route was not taken."
	return tooltip


func _add_node_content(button: Button, data: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.name = "PreviewRow"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 7.0
	row.offset_right = -7.0
	row.offset_top = 6.0
	row.offset_bottom = -6.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	button.add_child(row)

	var preview := TextureRect.new()
	preview.name = "MonsterPreview"
	preview.custom_minimum_size = Vector2(38, 38)
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = data.get("preview_texture") \
			if data.has("preview_texture") else _preview_texture(data)
	row.add_child(preview)

	var text_box := VBoxContainer.new()
	text_box.name = "EnemyText"
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	var name_label := Label.new()
	name_label.text = _short_name(String(data.get("name", "Unknown")))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", COLOR_INK)
	text_box.add_child(name_label)

	var detail := Label.new()
	if String(data.get("type", "enemy")) == "activity":
		detail.name = "ActivitySubtitle"
	var state: String = String(data.get("state", "locked"))
	if state == "completed":
		detail.text = "✓ Cleared"
	elif state == "bypassed":
		detail.text = "Not taken"
	elif String(data.get("type", "enemy")) == "activity":
		detail.text = ""
		detail.hide()
	elif String(data.get("type", "enemy")) == "pass":
		detail.text = "Skip detour"
	else:
		var tags: Array = data.get("tags", [])
		detail.text = String(tags[0]) if not tags.is_empty() else "Combat"
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_theme_font_size_override("font_size", 10)
	detail.add_theme_color_override("font_color", Color(COLOR_INK, 0.72))
	text_box.add_child(detail)


func _short_name(full_name: String) -> String:
	match full_name:
		"Frozen Revenant": return "Revenant"
		"Tundra Behemoth": return "Behemoth"
		"Frozen Traveler": return "Traveler"
		"Treasure Chest": return "Treasure"
		"Unknown Foe": return "Battle"
	return full_name


func _layout_buttons() -> void:
	if _buttons.is_empty() or size.x <= 0.0:
		return
	var width: float = clampf(_column_spacing() - 12.0, 82.0, 118.0)
	for button: Button in _buttons:
		var node: Dictionary = _button_nodes[button]
		button.custom_minimum_size.x = width
		button.size = button.custom_minimum_size
		button.position = _node_point(node) - button.size * 0.5


func _node_point(node: Dictionary) -> Vector2:
	var count: int = maxi(int(node.get("lane_count", 1)), 1)
	var lane: int = int(node.get("lane", 0))
	var spacing: float = 0.0
	if count > 1:
		spacing = minf(82.0, (size.y - 88.0) / float(count - 1))
	var total_height: float = spacing * float(count - 1)
	return Vector2(
			_column_x(int(node.get("column", node.get("stage", 1)))),
			size.y * 0.53 - total_height * 0.5 + spacing * lane
	)


func _column_x(column: int) -> float:
	var usable_width: float = size.x - MAP_PADDING_X * 2.0
	return MAP_PADDING_X + usable_width * (
			float(column - 1) / float(maxi(_column_count - 1, 1))
	)


func _column_spacing() -> float:
	return (size.x - MAP_PADDING_X * 2.0) / float(maxi(_column_count - 1, 1))


func _node_accent(data: Dictionary) -> Color:
	var state: String = String(data.get("state", "locked"))
	var type: String = String(data.get("type", "enemy"))
	if type == "boss":
		return COLOR_BOSS
	if type == "enemy":
		return COLOR_COMBAT if state in ["available", "completed"] else COLOR_LOCKED
	if state == "completed":
		return COLOR_CLEARED
	if type == "activity":
		return data.get("accent", COLOR_ACTIVITY)
	if type == "pass":
		return COLOR_CURRENT if state == "available" else COLOR_LOCKED
	return COLOR_COMBAT if state == "available" else COLOR_LOCKED


func _node_style(accent: Color, highlighted: bool, state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.13, 0.13, 0.97)
	if accent == COLOR_BOSS:
		style.bg_color = Color(0.22, 0.055, 0.045, 0.98)
	elif state == "available" and accent == COLOR_CURRENT:
		style.bg_color = Color(0.075, 0.18, 0.15, 0.98)
	elif state == "available" and accent == COLOR_COMBAT:
		style.bg_color = Color(0.105, 0.12, 0.12, 0.98)
	if state == "locked" or state == "bypassed":
		style.bg_color = Color(0.055, 0.08, 0.08, 0.9)
		accent = Color(accent, 0.52)
	elif state == "completed" and accent == COLOR_COMBAT:
		style.bg_color = Color(0.09, 0.105, 0.105, 0.96)
	elif state == "completed":
		style.bg_color = Color(0.14, 0.12, 0.07, 0.96)
	if highlighted:
		style.bg_color = style.bg_color.lightened(0.13)
		accent = accent.lightened(0.18)
	style.border_color = accent
	style.set_border_width_all(3 if highlighted else 2)
	style.set_corner_radius_all(15)
	style.shadow_color = Color(0, 0, 0, 0.46)
	style.shadow_size = 8 if highlighted else 4
	return style


func _draw_dotted_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var distance: float = from.distance_to(to)
	if distance <= 0.0:
		return
	var direction: Vector2 = (to - from) / distance
	var cursor: float = 0.0
	while cursor < distance:
		var dash_end: float = minf(cursor + 8.0, distance)
		draw_line(from + direction * cursor, from + direction * dash_end, color, width, true)
		cursor += 14.0


func _draw_centered_text(
	local_position: Vector2, text: String, color: Color, font_size: int
) -> void:
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	)
	draw_string(
			font, local_position - Vector2(text_size.x * 0.5, -text_size.y * 0.32),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color
	)


func _preview_texture(data: Dictionary) -> Texture2D:
	var frame: Texture2D = _enemy_icon(data)
	if frame == null:
		return null
	var image: Image = frame.get_image()
	if image == null:
		return frame
	if image.is_compressed():
		image.decompress()
	var used: Rect2i = image.get_used_rect()
	if not used.has_area():
		return frame
	var trimmed := AtlasTexture.new()
	trimmed.atlas = frame
	trimmed.region = Rect2(used)
	trimmed.filter_clip = true
	return trimmed


func _enemy_icon(data: Dictionary) -> Texture2D:
	var texture_path: String = String(data.get("texture", ""))
	if texture_path.is_empty():
		return null
	var texture: Texture2D = load(texture_path)
	if texture == null:
		return null
	var idle_frames: int = maxi(int(data.get("idle_frames", 1)), 1)
	var frame_width: float = float(texture.get_width()) / idle_frames \
			if idle_frames > 1 else float(data.get("frame_width", 0))
	if idle_frames > 1 and int(data.get("cell_width", 0)) > 0:
		frame_width = float(data["cell_width"])
	if frame_width <= 0.0:
		frame_width = texture.get_width()
	var top: float = float(data.get("idle_top", 0)) if idle_frames > 1 else 0.0
	var height: float = float(data.get("idle_height", 0)) if idle_frames > 1 else 0.0
	if height <= 0.0:
		height = texture.get_height() - top
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.filter_clip = true
	atlas.region = Rect2(0, top, frame_width, height)
	return atlas
