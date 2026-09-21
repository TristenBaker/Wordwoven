class_name EncounterRouteMap
extends Control
## Draws a horizontal expedition route and places interactive enemy
## cards at the current fork. The visual language is intentionally
## map-like: dotted trails, cleared waypoints, fogged future nodes,
## and a dominant boss destination.

signal enemy_selected(enemy_id: String)

const STAGE_COUNT: int = 6
const MAP_PADDING_X: float = 72.0
const CHOICE_OFFSET_Y: float = 92.0

const COLOR_TRAIL: Color = Color(0.25, 0.31, 0.29, 0.72)
const COLOR_CLEARED: Color = Color(0.76, 0.62, 0.32, 1.0)
const COLOR_CURRENT: Color = Color(0.34, 0.9, 0.61, 1.0)
const COLOR_LOCKED: Color = Color(0.22, 0.28, 0.28, 1.0)
const COLOR_BOSS: Color = Color(0.88, 0.22, 0.18, 1.0)
const COLOR_INK: Color = Color(0.84, 0.84, 0.72, 0.9)

var _stage: int = 1
var _choices: Array[Dictionary] = []
var _boss: Dictionary = {}
var _buttons: Array[Button] = []


func setup(
	stage: int, choices: Array[Dictionary], boss: Dictionary
) -> void:
	_stage = clampi(stage, 1, STAGE_COUNT)
	_choices = choices
	_boss = boss
	_rebuild_buttons()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_buttons()
		queue_redraw()


func _draw() -> void:
	if size.x <= MAP_PADDING_X * 2.0:
		return
	_draw_trail()
	_draw_waypoints()


func _draw_trail() -> void:
	# A faint complete route keeps the boss visually connected even while
	# future encounters remain unknown.
	for stage: int in STAGE_COUNT:
		_draw_dotted_line(
			_stage_point(stage), _stage_point(stage + 1), COLOR_TRAIL, 3.0
		)
	# The current fork fans out and then reconverges on the next encounter.
	if _stage < STAGE_COUNT and not _choices.is_empty():
		var previous: Vector2 = _stage_point(_stage - 1)
		var next: Vector2 = _stage_point(_stage + 1)
		for index: int in _choices.size():
			var choice_point: Vector2 = _choice_point(index)
			_draw_dotted_line(previous, choice_point, COLOR_CURRENT, 4.0)
			_draw_dotted_line(choice_point, next, COLOR_CURRENT.darkened(0.2), 3.0)


func _draw_waypoints() -> void:
	# Expedition origin.
	var origin: Vector2 = _stage_point(0)
	draw_circle(origin, 17.0, COLOR_CLEARED.darkened(0.25))
	draw_arc(origin, 17.0, 0.0, TAU, 32, COLOR_CLEARED, 3.0, true)
	_draw_centered_text(origin + Vector2(0, 38), "CAMP", COLOR_INK, 14)

	for stage: int in range(1, STAGE_COUNT + 1):
		if stage == _stage:
			continue
		var point: Vector2 = _stage_point(stage)
		if stage < _stage:
			draw_circle(point, 16.0, COLOR_CLEARED.darkened(0.35))
			draw_arc(point, 16.0, 0.0, TAU, 32, COLOR_CLEARED, 3.0, true)
			_draw_centered_text(point, "✓", COLOR_CLEARED, 18)
		elif stage == STAGE_COUNT:
			_draw_boss_destination(point)
		else:
			draw_circle(point, 13.0, COLOR_LOCKED)
			draw_arc(point, 13.0, 0.0, TAU, 24, COLOR_TRAIL, 2.0, true)
			_draw_centered_text(point + Vector2(0, 34), "?", COLOR_TRAIL, 16)


func _draw_boss_destination(point: Vector2) -> void:
	# Layered rings make the boss read as the final destination at a glance.
	draw_circle(point, 32.0, Color(COLOR_BOSS, 0.08))
	draw_arc(point, 32.0, 0.0, TAU, 40, Color(COLOR_BOSS, 0.35), 2.0, true)
	draw_circle(point, 21.0, COLOR_BOSS.darkened(0.48))
	draw_arc(point, 21.0, 0.0, TAU, 32, COLOR_BOSS, 4.0, true)
	_draw_centered_text(point, "B", Color(1.0, 0.72, 0.55, 1.0), 19)
	_draw_centered_text(point + Vector2(0, 48), "FINAL BOSS", COLOR_BOSS, 14)


func _rebuild_buttons() -> void:
	for button: Button in _buttons:
		button.queue_free()
	_buttons.clear()
	if _stage >= STAGE_COUNT and not _boss.is_empty():
		_add_enemy_button(_boss, true)
	else:
		for data: Dictionary in _choices:
			_add_enemy_button(data, false)
	_layout_buttons.call_deferred()


func _add_enemy_button(data: Dictionary, is_boss: bool) -> void:
	var button: Button = Button.new()
	var compact: bool = _choices.size() > 2 and not is_boss
	button.custom_minimum_size = Vector2(190, 72) if compact \
			else (Vector2(205, 96) if not is_boss else Vector2(224, 116))
	button.text = "%s\n%s" % [
		data.get("name", "Unknown"),
		" • ".join(data.get("tags", [])),
	]
	button.tooltip_text = "Health %d  •  Attack %d  •  Reward %dg" % [
		data.get("health", 0), data.get("attack", 0), data.get("gold", 0),
	]
	button.icon = _enemy_icon(data)
	button.expand_icon = true
	button.add_theme_constant_override(
		"icon_max_width", 48 if compact else (62 if not is_boss else 78)
	)
	button.add_theme_font_size_override(
		"font_size", 16 if compact else (18 if not is_boss else 20)
	)
	button.add_theme_color_override("font_color", Color(0.94, 0.9, 0.76, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _card_style(is_boss, false))
	button.add_theme_stylebox_override("hover", _card_style(is_boss, true))
	button.add_theme_stylebox_override("focus", _card_style(is_boss, true))
	button.add_theme_stylebox_override("pressed", _card_style(is_boss, true))
	button.pressed.connect(
		enemy_selected.emit.bind(String(data.get("id", "")))
	)
	add_child(button)
	_buttons.append(button)


func _layout_buttons() -> void:
	if _buttons.is_empty() or size.x <= 0.0:
		return
	for index: int in _buttons.size():
		var button: Button = _buttons[index]
		var point: Vector2 = _stage_point(_stage) \
				if _stage >= STAGE_COUNT else _choice_point(index)
		button.position = point - button.custom_minimum_size * 0.5
		button.size = button.custom_minimum_size


func _stage_point(stage: int) -> Vector2:
	var usable_width: float = size.x - MAP_PADDING_X * 2.0
	var x: float = MAP_PADDING_X + usable_width \
			* (float(stage) / float(STAGE_COUNT))
	var wave: float = sin(float(stage) * 1.35) * 26.0
	return Vector2(x, size.y * 0.52 + wave)


func _choice_point(index: int) -> Vector2:
	var base: Vector2 = _stage_point(_stage)
	if _choices.size() > 2:
		var spacing: float = minf(84.0, (size.y - 72.0) \
				/ float(maxi(_choices.size() - 1, 1)))
		var total_height: float = spacing * float(_choices.size() - 1)
		return Vector2(
			base.x, size.y * 0.5 - total_height * 0.5 + spacing * index
		)
	var direction: float = -1.0 if index % 2 == 0 else 1.0
	return Vector2(base.x, size.y * 0.5 + direction * CHOICE_OFFSET_Y)


func _draw_dotted_line(
	from: Vector2, to: Vector2, color: Color, width: float
) -> void:
	var distance: float = from.distance_to(to)
	if distance <= 0.0:
		return
	var direction: Vector2 = (to - from) / distance
	var cursor: float = 0.0
	while cursor < distance:
		var dash_end: float = minf(cursor + 9.0, distance)
		draw_line(
			from + direction * cursor,
			from + direction * dash_end,
			color, width, true
		)
		cursor += 16.0


func _draw_centered_text(
	position: Vector2, text: String, color: Color, font_size: int
) -> void:
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	)
	draw_string(
		font, position - Vector2(text_size.x * 0.5, -text_size.y * 0.32),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color
	)


func _card_style(is_boss: bool, highlighted: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.055, 0.045, 0.98) if is_boss \
			else Color(0.075, 0.18, 0.15, 0.98)
	style.border_color = COLOR_BOSS if is_boss else COLOR_CURRENT
	if highlighted:
		style.bg_color = style.bg_color.lightened(0.12)
		style.border_color = style.border_color.lightened(0.18)
	style.set_border_width_all(3 if highlighted else 2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.48)
	style.shadow_size = 9 if highlighted else 5
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


func _enemy_icon(data: Dictionary) -> Texture2D:
	var texture: Texture2D = load(String(data.get("texture", "")))
	if texture == null:
		return null
	var frame_width: int = int(data.get("frame_width", 0))
	if frame_width <= 0:
		return texture
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, frame_width, texture.get_height())
	return atlas
