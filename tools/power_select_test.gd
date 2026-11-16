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
				if child.is_visible_in_tree():
					check(child.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Visible card content passes clicks to button: " + child.name)
	var sample := CARD.colored_description("+12.5% damage, 3 Guard, -2 retaliation", Color("ef735d"))
	check(sample.count("[color=#ef735d]") == 3, "Signed values, decimals, percentages, and flat numbers are colored")
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
		if argument.begins_with("--capture="):
			RunState.relic_rewards = {}
			RunState.relics = []
			page._refresh()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--capture=")) == OK, "Preview saved")
	print("POWER SELECT TEST: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
