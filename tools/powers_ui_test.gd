extends Node
var failures: int = 0

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	RunState.start_new_run()
	var overlay = load("res://scenes/ui/equipment_overlay.tscn").instantiate()
	add_child(overlay)
	overlay.powers_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var empty: Label = overlay.powers_empty_label
	check(empty.visible and empty.text == "You have no powers yet." and not overlay.powers_scroll.visible, "Empty Powers message replaces grid")
	check(empty.size.x > 500 and empty.size.y > 400 and empty.get_line_count() == 1, "Empty message fills content and never becomes vertical text")
	check(empty.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and empty.vertical_alignment == VERTICAL_ALIGNMENT_CENTER and is_equal_approx(empty.get_global_rect().get_center().x, overlay.panel.get_global_rect().get_center().x), "Empty message centered")
	check(empty.get_theme_font("font") == load("res://assets/Fonts/Junicode.ttf"), "Fantasy font")
	overlay.letters_tab.pressed.emit()
	check(not empty.visible, "Powers message hidden on Letters tab")
	overlay.powers_tab.pressed.emit()
	RunState.pending_victory_enemy = "Goblin"
	RunState.completed_encounters.append(RunState.encounter_index)
	RunState.pending_relic_choices.assign(["coal_script", "storm_tome", "prismatic_refrain"])
	var selection = load("res://scenes/post_fight/power_select.tscn").instantiate()
	add_child(selection)
	await get_tree().process_frame
	for button: Button in selection.choice_buttons:
		var normal: StyleBoxFlat = button.get_theme_stylebox("normal")
		var hover: StyleBoxFlat = button.get_theme_stylebox("hover")
		check(normal.bg_color == Color(0.12, 0.07, 0.18, 0.98) and hover.bg_color.b > hover.bg_color.r and hover.bg_color.r > hover.bg_color.g and hover.bg_color.v > normal.bg_color.v, "Hover stays subtly purple")
		var normal_text: Color = button.get_theme_color("font_color")
		for state: String in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			check(button.get_theme_color(state) == normal_text, "Rarity text unchanged across states")
		check(button.get_theme_stylebox("pressed") == hover and button.get_theme_stylebox("focus") is StyleBoxFlat, "Pressed and keyboard focus use explicit card styles")
		button.grab_focus()
		check(button.has_focus(), "Keyboard card focus remains functional")
	selection.choice_buttons[0].pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(RunState.relics == ["coal_script"] and not selection.continue_button.disabled, "Original reward selection grants exactly one power")
	check(not empty.visible and overlay.powers_scroll.visible and overlay.powers_grid.get_child_count() == 1, "Open inventory automatically replaces empty message after reward")
	check(overlay.powers_grid.get_child(0).text == "Coal Script  ×1", "Owned power displayed normally")
	selection.choice_buttons[0].pressed.emit()
	check(RunState.relics.size() == 1, "Repeated selection does not duplicate reward")
	overlay.queue_free()
	selection.queue_free()
	await get_tree().process_frame
	print("Powers UI: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
