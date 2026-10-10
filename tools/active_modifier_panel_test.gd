extends Node
## Presentation regression checks; never changes modifier definitions or selection.

const MODIFIERS = preload("res://scripts/modifiers/encounter_modifier.gd")
const PANEL = preload("res://scenes/ui/active_modifier_panel.tscn")
var failures: int = 0

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func _run() -> void:
	var panel = PANEL.instantiate()
	add_child(panel)
	var style = panel.get_theme_stylebox("panel")
	_check(style.bg_color == load("res://assets/Themes/Feedback_Banner_Panel.tres").bg_color and style is StyleBoxFlat and style.bg_color.a < 1.0, "Modifier shares plain translucent feedback style")
	var base: Dictionary = {"health": 41, "attack": 7}
	for modifier: Dictionary in MODIFIERS.ENTRIES:
		var applied: Dictionary = MODIFIERS.apply_spawn(base, modifier)
		var factor: float = MODIFIERS.player_factor(modifier)
		panel.show_modifier("merciless", modifier, base, applied, factor)
		await get_tree().process_frame
		_check(panel.name_label.text == "Modifier: " + modifier.name, "Modifier name: " + modifier.id)
		_check(panel.effect_label.text == modifier.effect and panel.effect_label.get_line_count() == 1, "Single-line catalogue effect: " + modifier.id)
		_check(panel.name_label.get_theme_color("font_color") == (panel.HELPFUL if modifier.beneficial else panel.HARMFUL), "Original disposition color")
		_check(panel.get_node("Content").get_child_count() == 2, "Exactly two labels")
		_check(panel.size.y < 136, "Modifier panel is compact")
		_check(panel.size.x >= panel.get_combined_minimum_size().x and panel.size.y >= panel.get_combined_minimum_size().y, "Compact text fits: " + modifier.id)
	panel.show_modifier("", {}, {}, {}, 1.0)
	await get_tree().process_frame
	_check(panel.size == panel.get_combined_minimum_size(), "Panel automatically shrinks to content")
	_check(panel.name_label.text == "No Active Modifier" and not panel.effect_label.visible, "Empty encounter clears stale modifier")
	panel.queue_free()
	print("Active modifier panel: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
