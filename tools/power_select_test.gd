extends Node
## Checks layout/selection without submitting words or writing player progression.
const CARD := preload("res://scripts/post_fight/power_choice_card.gd")
var checks := 0
var failures := 0


func _ready() -> void:
	PlayerStats._persistence_enabled = false
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	RunState.pending_victory_enemy = "Goblin"
	RunState.encounter_index = 1
	RunState.completed_encounters = [1]
	RunState.relic_rewards = {}
	RunState.relics = []
	RunState.pending_relic_choices = ["ember_pact", "tidal_mend", "storm_chorus"]
	var page: Control = load("res://scenes/post_fight/power_select.tscn").instantiate()
	add_child(page)
	await get_tree().process_frame
	await get_tree().process_frame
	var ids: Array[String] = page.relic_system.relic_ids()
	for start: int in range(0, ids.size(), 3):
		RunState.pending_relic_choices.assign(ids.slice(start, start + 3))
		page._refresh()
		await get_tree().process_frame
		await get_tree().process_frame
		check(get_viewport().get_visible_rect().encloses(page.get_node("CenterBox/PowerPanel").get_global_rect()), "Full page fits viewport")
		for index: int in RunState.pending_relic_choices.size():
			var button: Button = page.choice_buttons[index]
			var info: Dictionary = page.relic_system.relic_info(RunState.pending_relic_choices[index])
			var element := String(info.effect).get_slice("_", 0)
			var color: Color = CARD.COLORS.get(element, CARD.UNIVERSAL_COLOR)
			var description: RichTextLabel = button.description_label
			check(description.text.contains("[color=#%s]" % color.to_html(false)), "Correct numeric color for " + String(info.name))
			check(description.get_parsed_text() == info.description, "Formatting preserves effect text")
			check(description.get_content_height() <= description.size.y + 1, "Description does not clip: " + String(info.name))
			for child: Control in button.find_children("*", "Control", true, false):
				if child.is_visible_in_tree() and child.get_window() == button.get_window():
					check(child.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Visible card content passes clicks to button: " + child.name)
	var sample := CARD.colored_description("+12.5% damage, 3 Guard, -2 retaliation", Color("ef735d"))
	check(sample.count("[color=#ef735d]") == 3, "Signed values, decimals, percentages, and flat numbers are colored")
	# Hover information describes the owned build, not the offered effect.
	RunState.relics = ["coal_script", "coal_script", "tidal_mend", "prismatic_refrain", "red_thread"]
	RunState.pending_relic_choices = ["ember_pact", "tidal_mend", "prismatic_refrain"]
	page._refresh()
	var fire: Button = page.choice_buttons[0]
	check(fire._owned_power_ids() == ["coal_script", "prismatic_refrain", "red_thread"], "Fire tooltip includes only owned Fire and universal powers, deduplicated")
	var tooltip: Control = fire._make_custom_tooltip("")
	page.add_child(tooltip)
	await get_tree().process_frame
	var tooltip_text := ""
	for label: RichTextLabel in tooltip.find_children("*", "RichTextLabel", true, false):
		tooltip_text += label.get_parsed_text() + "\n"
	check(tooltip_text.contains("Coal Script ×2") and tooltip_text.contains("+24% damage total"), "Tooltip shows owned stack counts and their calculated total")
	check(not tooltip_text.contains("Tidal Mend") and not tooltip_text.contains("Ember Pact"), "Tooltip excludes unrelated and unowned powers")
	var style: StyleBoxFlat = tooltip.get_theme_stylebox("panel")
	check(style.bg_color == LetterTooltip.BACKGROUND and style.border_color == LetterTooltip.BORDER, "Power tooltip shares opaque letter-tooltip styling")
	check(fire.theme.get_stylebox("panel", "TooltipPanel") is StyleBoxEmpty, "Default transparent-black tooltip wrapper is removed")
	tooltip.queue_free()
	RunState.relics.assign(ids)
	var universal: Button = page.choice_buttons[2]
	check(universal._owned_power_ids().size() == ids.size(), "Universal offer shows powers across all elements")
	tooltip = universal._make_custom_tooltip("")
	page.add_child(tooltip)
	await get_tree().process_frame
	await get_tree().process_frame
	check(tooltip.size.x <= get_viewport().get_visible_rect().size.x and tooltip.size.y <= get_viewport().get_visible_rect().size.y, "Full-catalog tooltip fits the viewport")
	tooltip.queue_free()
	RunState.relics = []
	tooltip = fire._make_custom_tooltip("")
	page.add_child(tooltip)
	await get_tree().process_frame
	tooltip_text = ""
	for label: RichTextLabel in tooltip.find_children("*", "RichTextLabel", true, false):
		tooltip_text += label.get_parsed_text()
	check(tooltip_text.contains("No related powers owned yet."), "Empty build has a clear tooltip message")
	tooltip.queue_free()
	RunState.pending_relic_choices = ["ember_pact", "tidal_mend", "storm_chorus"]
	page._refresh()
	await get_tree().process_frame
	page.choice_buttons[0].pressed.emit()
	check(RunState.relics == ["ember_pact"], "Whole-card selection grants correct power")
	check(not page.continue_button.disabled, "Selection enables View Loot")
	for button: Button in page.choice_buttons:
		check(button.disabled, "Selection locks all cards")
	page._select_choice(1)
	check(RunState.relics == ["ember_pact"], "Double selection cannot grant another reward")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture=") or argument.begins_with("--capture-tooltip="):
			RunState.relic_rewards = {}
			RunState.relics = []
			if argument.begins_with("--capture-tooltip="):
				RunState.relics = ["coal_script", "coal_script", "ember_pact", "prismatic_refrain", "red_thread"]
			page._refresh()
			# Preview the returned tooltip directly; suppress native hover popups
			# caused by the desktop pointer happening to rest over the test window.
			for button: Button in page.choice_buttons:
				button.tooltip_text = ""
			var motion := InputEventMouseMotion.new()
			motion.position = Vector2(12, 700)
			motion.global_position = motion.position
			Input.parse_input_event(motion)
			await get_tree().process_frame
			if argument.begins_with("--capture-tooltip="):
				tooltip = page.choice_buttons[0]._make_custom_tooltip("")
				page.add_child(tooltip)
				tooltip.position = Vector2(456, 245)
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png(argument.get_slice("=", 1)) == OK, "Preview saved")
	print("POWER SELECT TEST: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
