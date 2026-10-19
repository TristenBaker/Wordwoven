class_name LeaderboardOverlay
extends Control
## Reusable local run history shown from the title screen and tavern.

const BUTTON_THEME := preload("res://assets/Themes/WordWoven_Button_Theme.tres")

var _leaderboard: RunLeaderboard
var _mode_key: String = "story"
var _list: RichTextLabel
var _story_button: Button
var _endless_button: Button


static func open_in(parent: Node) -> void:
	if parent.get_node_or_null("LeaderboardOverlay") != null:
		return
	var overlay := LeaderboardOverlay.new()
	overlay.name = "LeaderboardOverlay"
	parent.add_child(overlay)


func _ready() -> void:
	_leaderboard = RunLeaderboard.new()
	if RunState.is_run_active and RunState.is_endless():
		_mode_key = "endless"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.012, 0.025, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 520)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	var title := Label.new()
	title.text = "LEADERBOARD"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("ffd487"))
	title.add_theme_font_size_override("font_size", 30)
	title_row.add_child(title)
	var close := Button.new()
	close.theme = BUTTON_THEME
	close.theme_type_variation = &"WordWovenActionButton"
	close.text = "Close"
	close.custom_minimum_size = Vector2(100, 38)
	close.pressed.connect(queue_free)
	title_row.add_child(close)

	var subtitle := Label.new()
	subtitle.text = "Your top 20 local runs, ranked by the score shown at each tale's end."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", Color("ead8b3"))
	subtitle.add_theme_font_size_override("font_size", 17)
	content.add_child(subtitle)

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 12)
	content.add_child(tabs)
	var tab_group := ButtonGroup.new()
	_story_button = _mode_button("Story", "story", tab_group)
	_endless_button = _mode_button("Endless", "endless", tab_group)
	tabs.add_child(_story_button)
	tabs.add_child(_endless_button)
	_story_button.button_pressed = _mode_key == "story"
	_endless_button.button_pressed = _mode_key == "endless"
	_story_button.pressed.connect(_select_mode.bind("story"))
	_endless_button.pressed.connect(_select_mode.bind("endless"))

	_list = RichTextLabel.new()
	_list.bbcode_enabled = true
	_list.fit_content = false
	_list.scroll_active = true
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(560, 290)
	_list.add_theme_font_size_override("normal_font_size", 19)
	_list.add_theme_color_override("default_color", Color("f4e9d0"))
	content.add_child(_list)
	_refresh_list()


func _mode_button(label: String, key: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.theme = BUTTON_THEME
	button.theme_type_variation = &"WordWovenActionButton"
	button.text = label
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(145, 40)
	button.set_meta("mode_key", key)
	return button


func _select_mode(key: String) -> void:
	_mode_key = key
	_refresh_list()


func _refresh_list() -> void:
	_list.text = _entry_text(_leaderboard.entries(_mode_key), _mode_key)


func _entry_text(entries: Array[Dictionary], mode_key: String) -> String:
	if entries.is_empty():
		return "[center]No completed %s runs yet.\n\nFinish a run to add its score here.[/center]" % mode_key.capitalize()
	var lines: Array[String] = []
	for index: int in entries.size():
		var entry: Dictionary = entries[index]
		var result := "Victory" if bool(entry.get("victory", false)) else "Defeat"
		var color := "9ff59b" if result == "Victory" else "e7a6a6"
		lines.append("[color=#ffd487]#%d[/color]  [b]%d[/b]  [color=#%s]%s[/color]  ·  %s  ·  %d foes  ·  %d gold" % [
			index + 1,
			int(entry.get("score", 0)),
			color,
			result,
			String(entry.get("biome", "Unknown")),
			int(entry.get("enemies", 0)),
			int(entry.get("gold_earned", 0)),
		])
	return "\n\n".join(lines)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("21150f")
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color("d89b46")
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 24
	style.content_margin_top = 22
	style.content_margin_right = 24
	style.content_margin_bottom = 22
	return style
