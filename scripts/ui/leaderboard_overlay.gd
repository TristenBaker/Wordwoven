class_name LeaderboardOverlay
extends Control
## Reusable local run history shown from the title screen and tavern.

const BUTTON_THEME := preload("res://assets/Themes/WordWoven_Button_Theme.tres")


static func open_in(parent: Node) -> void:
	if parent.get_node_or_null("LeaderboardOverlay") != null:
		return
	var overlay := LeaderboardOverlay.new()
	overlay.name = "LeaderboardOverlay"
	parent.add_child(overlay)


func _ready() -> void:
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

	var leaderboard := RunLeaderboard.new()
	var entries: Array[Dictionary] = leaderboard.entries()
	var list := RichTextLabel.new()
	list.bbcode_enabled = true
	list.fit_content = false
	list.scroll_active = true
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(560, 340)
	list.add_theme_font_size_override("normal_font_size", 19)
	list.add_theme_color_override("default_color", Color("f4e9d0"))
	list.text = _entry_text(entries)
	content.add_child(list)


func _entry_text(entries: Array[Dictionary]) -> String:
	if entries.is_empty():
		return "[center]No completed runs yet.\n\nFinish a tale to add its score here.[/center]"
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
