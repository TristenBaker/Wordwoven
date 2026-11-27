extends Control
## Title navigation and presentation. Starting a tale requires the lexicon.

@onready var center_box: CenterContainer = $CenterBox
@onready var primary: VBoxContainer = $CenterBox/Menu/Pages/Primary
@onready var extras: VBoxContainer = $CenterBox/Menu/Pages/Extras
@onready var start_button: Button = primary.get_node("StartButton")
@onready var extras_button: Button = primary.get_node("ExtrasButton")
@onready var settings_button: Button = primary.get_node("SettingsButton")
@onready var status_label: Label = $CenterBox/Menu/StatusLabel
@onready var settings_screen: SettingsScreen = $SettingsScreen
@onready var achievements_menu: Control = $AchievementsMenu

var _return_button: Button
var _controller_bindings: Dictionary[StringName, InputEventJoypadButton] = {}


func _enter_tree() -> void:
	# Godot's directional actions include gamepads, but this project's accept and
	# cancel actions ship with keyboard bindings. Extend them for the title UI.
	for action: StringName in [&"ui_accept", &"ui_cancel"]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A if action == &"ui_accept" else JOY_BUTTON_B
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
			_controller_bindings[action] = event


func _exit_tree() -> void:
	for action: StringName in _controller_bindings:
		InputMap.action_erase_event(action, _controller_bindings[action])
	_controller_bindings.clear()


func _ready() -> void:
	Telemetry.end_run("abandoned")
	PlayerStats.finalize_run()
	start_button.disabled = not WordNet.is_ready
	for page: VBoxContainer in [primary, extras]:
		for button: Button in page.get_children():
			_setup_button_feedback(button)
		_link_focus(page)
	start_button.pressed.connect(_on_start_pressed)
	extras_button.pressed.connect(_show_extras)
	settings_button.pressed.connect(_on_settings_pressed)
	primary.get_node("QuitButton").pressed.connect(_on_quit_pressed)
	extras.get_node("AchievementsButton").pressed.connect(_show_achievements)
	_connect_overlay("LeaderboardButton", "LeaderboardOverlay", LeaderboardOverlay.open_in)
	_connect_overlay("PermanentUpgradesButton", "PermanentUpgradesOverlay", PermanentUpgradesOverlay.open_in)
	_connect_overlay("CosmeticsButton", "CosmeticsOverlay", CosmeticsOverlay.open_in)
	extras.get_node("BackButton").pressed.connect(_show_primary)
	achievements_menu.closed.connect(_restore_menu)
	settings_screen.closed.connect(_restore_menu)
	if start_button.disabled:
		status_label.text = "Consulting the lexicon..."
		WordNet.loading_finished.connect(_on_loading_finished)
		extras_button.grab_focus()
	else:
		start_button.grab_focus()


func _link_focus(page: VBoxContainer) -> void:
	var buttons: Array[Button] = []
	for button: Button in page.get_children():
		if not button.disabled:
			buttons.append(button)
	for index in buttons.size():
		var button := buttons[index]
		button.focus_neighbor_top = button.get_path_to(buttons[posmod(index - 1, buttons.size())])
		button.focus_neighbor_bottom = button.get_path_to(buttons[(index + 1) % buttons.size()])
		button.focus_neighbor_left = NodePath(".")
		button.focus_neighbor_right = NodePath(".")
		button.focus_previous = button.focus_neighbor_top
		button.focus_next = button.focus_neighbor_bottom


func _setup_button_feedback(button: Button) -> void:
	var update := _update_button_feedback.bind(button)
	button.focus_entered.connect(update)
	button.focus_exited.connect(update)
	button.mouse_entered.connect(update)
	button.mouse_exited.connect(update)
	button.draw.connect(_draw_focus_ornament.bind(button))


func _update_button_feedback(button: Button) -> void:
	if button.has_meta(&"highlight_tween"):
		var previous: Tween = button.get_meta(&"highlight_tween")
		previous.kill()
	var highlight := not button.disabled and (button.has_focus() or button.is_hovered())
	var target := Color(1.10, 1.08, 1.04) if highlight else Color.WHITE
	var tween := button.create_tween()
	button.set_meta(&"highlight_tween", tween)
	tween.tween_property(button, "self_modulate", target, 0.14)
	button.queue_redraw()


func _draw_focus_ornament(button: Button) -> void:
	if not button.has_focus() or button.disabled:
		return
	var center := Vector2(-16.0, button.size.y * 0.5)
	var points := PackedVector2Array([
		center + Vector2(-7, 0), center + Vector2(0, -5),
		center + Vector2(7, 0), center + Vector2(0, 5),
	])
	button.draw_colored_polygon(points, Color("f6d791"))
	points.append(points[0])
	button.draw_polyline(points, Color("694520"), 1.25, true)


func _on_loading_finished(success: bool) -> void:
	if success:
		start_button.disabled = false
		status_label.text = ""
		_link_focus(primary)
		if center_box.visible and primary.visible and extras_button.has_focus():
			start_button.grab_focus()
	else:
		status_label.text = "Lexicon failed to load. See logs."


func _show_extras() -> void:
	primary.hide()
	extras.show()
	extras.get_node("AchievementsButton").grab_focus()


func _show_primary() -> void:
	extras.hide()
	primary.show()
	extras_button.grab_focus()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(ScenePaths.MODE_SELECT)


func _on_settings_pressed() -> void:
	_cover_menu(settings_button)
	settings_screen.open()


func _show_achievements() -> void:
	_cover_menu(extras.get_node("AchievementsButton") if extras.visible else extras_button)
	achievements_menu.open()


func _connect_overlay(button_name: String, overlay_name: String, open: Callable) -> void:
	var button: Button = extras.get_node(button_name)
	button.pressed.connect(_open_overlay.bind(button, overlay_name, open))


func _open_overlay(button: Button, overlay_name: String, open: Callable) -> void:
	_cover_menu(button)
	open.call(self)
	var overlay := get_node(overlay_name)
	overlay.tree_exited.connect(_restore_menu.call_deferred, CONNECT_ONE_SHOT)
	for control in overlay.find_children("*", "Button", true, false):
		var candidate := control as Button
		if candidate.is_visible_in_tree() and not candidate.disabled and candidate.focus_mode != FOCUS_NONE:
			candidate.grab_focus()
			break


func _cover_menu(button: Button) -> void:
	_return_button = button
	center_box.hide()


func _restore_menu() -> void:
	if not is_inside_tree():
		return
	center_box.show()
	if is_instance_valid(_return_button):
		_return_button.grab_focus()
	_return_button = null


func _on_quit_pressed() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if achievements_menu.visible:
		achievements_menu.close()
	elif settings_screen.visible:
		settings_screen.close()
	elif center_box.visible and extras.visible:
		_show_primary()
	else:
		return
	get_viewport().set_input_as_handled()
