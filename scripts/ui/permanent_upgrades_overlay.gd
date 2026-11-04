class_name PermanentUpgradesOverlay
extends Control
## Six elemental paths, each with two specializations and a shared capstone.

const CATALOG := preload("res://data/balance/talents.gd")
const THEME := preload("res://assets/Themes/WordWoven_Button_Theme.tres")
const TALENT_NODE := preload("res://scripts/ui/talent_node.gd")
const STAR_COIN := preload("res://assets/Art/Items/starcoin.png")
const COLORS := [Color("ef735d"), Color("e4c34a"), Color("63b4ef"), Color("a3e9f7"), Color("79d37a"), Color("ca9264")]

var _balance: Label
var _tree: Control
var _viewport: Control
var _panning := false
var _press_position := Vector2.ZERO
var _pressed_node := ""
var _dragged := false
var _held := false
var _gesture := 0
var _inspector: PanelContainer
var pause_game := false
var _resume_on_close := false


static func open_in(parent: Node, pause_gameplay: bool = false) -> void:
	if parent.get_node_or_null("PermanentUpgradesOverlay") != null:
		return
	var overlay := PermanentUpgradesOverlay.new()
	overlay.name = "PermanentUpgradesOverlay"
	overlay.pause_game = pause_gameplay
	parent.add_child(overlay)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("talent_overlay")
	z_index = 300
	if pause_game and not get_tree().paused:
		_resume_on_close = true
		get_tree().paused = true
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color("100d1e")
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var heading := Label.new()
	heading.text = "ELEMENTAL TALENTS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	layout.add_child(heading)
	_balance = Label.new()
	_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(_balance)
	var hint := Label.new()
	hint.text = "Click: learn • Hold: inspect • Drag either button: pan • Wheel: zoom • Ctrl + click: refund"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	layout.add_child(hint)
	_viewport = Control.new()
	_viewport.size_flags_vertical = SIZE_EXPAND_FILL
	_viewport.size_flags_horizontal = SIZE_EXPAND_FILL
	_viewport.clip_contents = true
	layout.add_child(_viewport)
	_tree = Control.new()
	_tree.mouse_filter = MOUSE_FILTER_IGNORE
	_viewport.add_child(_tree)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(actions)
	_action(actions, "Fit Tree", _fit_tree)
	_action(actions, "Refund All", func(): PlayerProfile.reset_talents(); _refresh())
	_action(actions, "DEV +1 ★", func(): PlayerProfile.add_dev_star_coin(); _refresh())
	_action(actions, "Back", queue_free)
	_refresh()
	_fit_tree.call_deferred()


func _action(parent: Node, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.theme = THEME
	button.theme_type_variation = &"WordWovenActionButton"
	button.custom_minimum_size = Vector2(150, 42)
	button.pressed.connect(callback)
	parent.add_child(button)


func _refresh() -> void:
	_balance.text = "Talent points: %d available / %d total   •   %d allocated" % [
		PlayerProfile.star_coins, PlayerProfile.total_star_coins, PlayerProfile.allocated_talent_points()]
	for child: Node in _tree.get_children():
		_tree.remove_child(child)
		child.queue_free()
	_overview()


func _overview() -> void:
	var coin := TextureRect.new()
	coin.texture = STAR_COIN
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.position = Vector2(-65, -65)
	coin.size = Vector2(130, 130)
	coin.mouse_filter = MOUSE_FILTER_IGNORE
	_tree.add_child(coin)
	for index: int in PlayerProfile.ELEMENTS.size():
		var element: String = PlayerProfile.ELEMENTS[index]
		var angle := -PI / 2.0 + index * TAU / 6.0
		var point := Vector2(cos(angle), sin(angle)) * 685.0
		_text("%s • %d/8" % [element.capitalize(), _learned(element)], point - Vector2(95, 18), Vector2(190, 36))
		_line(Vector2.ZERO, _position_for(CATALOG.NODES[element + "_0"]), COLORS[index])
	_branch()


func _learned(element: String) -> int:
	var count := 0
	for id: String in PlayerProfile.talent_allocations:
		if CATALOG.NODES[id].element == element and not CATALOG.NODES[id].get("repeatable", false):
			count += 1
	return count


func _position_for(node: Dictionary) -> Vector2:
	var index: int = PlayerProfile.ELEMENTS.find(String(node.element))
	var angle := -PI / 2.0 + index * TAU / 6.0
	var outward := Vector2(cos(angle), sin(angle))
	var sideways := Vector2(-outward.y, outward.x)
	return outward * (140.0 + int(node.tier) * 95.0) + sideways * int(node.lane) * 65.0


func _branch() -> void:
	for id: String in CATALOG.NODES:
		var node: Dictionary = CATALOG.NODES[id]
		var color: Color = COLORS[PlayerProfile.ELEMENTS.find(String(node.element))]
		for parent: String in node.requires:
			_line(_position_for(CATALOG.NODES[parent]), _position_for(node), color)
	for id: String in CATALOG.NODES:
		var node: Dictionary = CATALOG.NODES[id]
		var color: Color = COLORS[PlayerProfile.ELEMENTS.find(String(node.element))]
		var owned := PlayerProfile.talent_allocations.has(id)
		var available := PlayerProfile.can_allocate_talent(id)
		var button := TALENT_NODE.new()
		button.position = _position_for(node) - Vector2(25, 25)
		button.size = Vector2(50, 50)
		button.text = "∞\n%d" % PlayerProfile.talent_rank(id) if node.get("repeatable", false) else ("✓" if owned else "")
		button.tooltip_text = "%s — %s\n%s\nCost: 1 talent point\n%s" % [String(node.element).capitalize(), node.name, node.description, "Learned. Ctrl + click refunds this and dependent talents." if owned else "Requires: " + _requirements(node)]
		button.detail_text = _detail_text(id)
		button.theme = LetterTooltip.transparent_shell_theme()
		button.set_meta("talent_id", id)
		button.add_theme_stylebox_override("normal", _style(color, owned or available))
		button.add_theme_stylebox_override("hover", _style(color.lightened(0.3), true))
		button.add_theme_stylebox_override("pressed", _style(color, true))
		button.add_theme_stylebox_override("focus", _style(color.lightened(0.3), true))
		button.modulate.a = 1.0 if owned or available else 0.55
		_tree.add_child(button)


func _requirements(node: Dictionary) -> String:
	var names: PackedStringArray = []
	for id: String in node.requires:
		names.append(CATALOG.NODES[id].name)
	return ", ".join(names) if not names.is_empty() else "No prerequisite"


func _line(start: Vector2, end: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.add_point(start)
	line.add_point(end)
	line.width = 3
	line.default_color = Color(color, 0.45)
	_tree.add_child(line)


func _text(value: String, point: Vector2, dimensions: Vector2) -> void:
	var label := Label.new()
	label.text = value
	label.position = point
	label.size = dimensions
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tree.add_child(label)


func _style(color: Color, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("251c32")
	style.border_color = color
	style.set_border_width_all(3 if active else 1)
	style.set_corner_radius_all(25)
	if active:
		style.shadow_color = Color(color, 0.35)
		style.shadow_size = 6
	return style


func _fit_tree() -> void:
	var factor := clampf(minf(_viewport.size.x / 1610.0, _viewport.size.y / 1460.0), 0.2, 1.5)
	_tree.scale = Vector2.ONE * factor
	_tree.position = _viewport.size * 0.5


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		queue_free()
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				if not _viewport.get_global_rect().has_point(event.position) or (is_instance_valid(_inspector) and _inspector.get_global_rect().has_point(event.position)):
					return
				_panning = true
				_press_position = event.position
				_dragged = false
				_held = false
				_pressed_node = _node_at(event.position) if event.button_index == MOUSE_BUTTON_LEFT else ""
				_gesture += 1
				if not _pressed_node.is_empty():
					_hold_node(_gesture)
			elif _panning:
				_panning = false
				_gesture += 1
				if not _dragged and not _held and not _pressed_node.is_empty() and _node_at(event.position) == _pressed_node:
					if event.ctrl_pressed:
						PlayerProfile.refund_talent(_pressed_node)
					else:
						PlayerProfile.allocate_talent(_pressed_node)
					_refresh()
				_pressed_node = ""
				get_viewport().set_input_as_handled()
				return
			if _panning:
				get_viewport().set_input_as_handled()
		elif event.pressed and _viewport.get_global_rect().has_point(event.position) and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var local_mouse := _viewport.get_local_mouse_position()
			var before := (local_mouse - _tree.position) / _tree.scale.x
			var factor := clampf(_tree.scale.x * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 0.2, 2.0)
			_tree.scale = Vector2.ONE * factor
			_tree.position = local_mouse - before * factor
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _panning:
		if not _dragged and event.position.distance_to(_press_position) > 8.0:
			_dragged = true
			_gesture += 1
			_tree.position += event.position - _press_position
		elif _dragged:
			_tree.position += event.relative
		get_viewport().set_input_as_handled()


func _node_at(point: Vector2) -> String:
	for child: Node in _tree.get_children():
		if child is Button and child.has_meta("talent_id"):
			var rect: Rect2 = child.get_global_rect()
			if point.distance_to(rect.get_center()) <= rect.size.x * 0.5:
				return String(child.get_meta("talent_id"))
	return ""


func _hold_node(token: int) -> void:
	await get_tree().create_timer(0.5).timeout
	if token != _gesture or not _panning or _dragged or _pressed_node.is_empty():
		return
	_held = true
	_open_inspector(_pressed_node)


func _detail_text(id: String) -> String:
	var node: Dictionary = CATALOG.NODES[id]
	var color: Color = COLORS[PlayerProfile.ELEMENTS.find(String(node.element))]
	if node.get("repeatable", false):
		var rank := PlayerProfile.talent_rank(id)
		return "[center][font_size=24][b]%s[/b][/font_size]\n[color=#%s]%s • MASTERY[/color]\nRANK %d / ∞[/center]\n\n%s\n\n[b]Current mastery bonus:[/b] +%d%% damage\n[b]Next rank:[/b] +%d%% damage\n[b]Cost:[/b] 1 talent point per rank\n[b]Requires:[/b] %s\n\nClick to invest • Hold to inspect\nCtrl + click refunds one rank." % [node.name, color.to_html(false), String(node.element).to_upper(), rank, node.description, rank * 3, (rank + 1) * 3, _requirements(node)]
	return "[center][font_size=24][b]%s[/b][/font_size]\n[color=#%s]%s • TALENT[/color]\n%s[/center]\n\n%s\n\n[b]Cost:[/b] 1 talent point\n[b]Requires:[/b] %s\n\nClick to learn • Hold to inspect" % [node.name, color.to_html(false), String(node.element).to_upper(), "LEARNED" if PlayerProfile.talent_allocations.has(id) else "NOT LEARNED", node.description, _requirements(node)]


func _open_inspector(id: String) -> void:
	if is_instance_valid(_inspector):
		remove_child(_inspector)
		_inspector.queue_free()
	_inspector = PanelContainer.new()
	_inspector.set_anchors_preset(PRESET_RIGHT_WIDE)
	_inspector.offset_left = -420
	_inspector.offset_right = -20
	_inspector.offset_top = 110
	_inspector.offset_bottom = -85
	var card := LetterTooltip.new()
	_inspector.add_theme_stylebox_override("panel", card._panel_style())
	card.free()
	add_child(_inspector)
	var content := VBoxContainer.new()
	_inspector.add_child(content)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.size_flags_vertical = SIZE_EXPAND_FILL
	text.custom_minimum_size.x = 350
	text.text = _detail_text(id) + "\n\n[b]Refund:[/b] Ctrl + click on the tree refunds this talent and its dependents."
	content.add_child(text)
	_action(content, "Close", func(): _inspector.queue_free())


func _exit_tree() -> void:
	if _resume_on_close:
		get_tree().paused = false
