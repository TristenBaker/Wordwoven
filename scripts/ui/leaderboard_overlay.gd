class_name LeaderboardOverlay
extends Control
## Reusable local run history shown from the title screen and tavern.

const BUTTON_THEME := preload("res://assets/Themes/WordWoven_Button_Theme.tres")
const FRAME := preload("res://assets/Themes/encounters/information_panel.tres")
const FONT := preload("res://assets/Fonts/Junicode.ttf")

var _leaderboard: RunLeaderboard
var _mode_key: String = "story"
var _list: VBoxContainer
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
	panel.custom_minimum_size = Vector2(1000, 610)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", FRAME)
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
	title.add_theme_font_override("font", preload("res://assets/Fonts/BLKCHCRY.TTF"))
	title_row.add_child(title)
	var loadouts := Button.new()
	loadouts.theme = BUTTON_THEME
	loadouts.theme_type_variation = &"WordWovenActionButton"
	loadouts.text = "Past Loadouts"
	loadouts.custom_minimum_size = Vector2(140, 38)
	loadouts.pressed.connect(func(): RunArchiveOverlay.open_in(self))
	title_row.add_child(loadouts)
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
	subtitle.add_theme_font_override("font", FONT)
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

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 360
	content.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
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
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	(_list.get_parent() as ScrollContainer).scroll_vertical = 0
	var entries := _leaderboard.entries(_mode_key)
	if entries.is_empty():
		_list.add_child(_label("No completed %s runs yet.\nFinish a run to add its score here." % _mode_key.capitalize(), 21))
		return
	var archives := RunArchive.new().entries()
	for index: int in entries.size():
		_add_entry(index, entries[index], archives)


func _add_entry(index: int, entry: Dictionary, archives: Array[Dictionary]) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101d2e")
	style.border_color = Color("6d5b3b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	_list.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var rank := _label("#%d" % (index + 1), 27, Color("e8c77e"))
	rank.custom_minimum_size.x = 50
	row.add_child(rank)
	var score := _label(str(int(entry.get("score", 0))), 29, Color("fff0cf"))
	score.custom_minimum_size.x = 110
	row.add_child(score)
	var details := RichTextLabel.new()
	details.bbcode_enabled = true
	details.fit_content = true
	details.scroll_active = false
	details.size_flags_horizontal = SIZE_EXPAND_FILL
	details.custom_minimum_size.x = 300
	details.add_theme_font_override("normal_font", FONT)
	details.add_theme_font_override("bold_font", preload("res://assets/Fonts/Junicode-Bold.ttf"))
	details.add_theme_font_size_override("normal_font_size", 19)
	details.add_theme_font_size_override("bold_font_size", 19)
	var victory: bool = bool(entry.get("victory", false))
	details.text = "[color=#%s][b]%s[/b][/color] · %s\n%d foes · %d gold earned" % [
		"9ff59b" if victory else "e7a6a6", "Victory" if victory else "Defeat", entry.get("biome", "Unknown"),
		int(entry.get("enemies", 0)), int(entry.get("gold_earned", 0))]
	if float(entry.get("recorded_at", 0)) > 0:
		details.text += "\n[font_size=16][color=#b8ad98]%s[/color][/font_size]" % RunArchiveOverlay._date(float(entry.recorded_at))
	row.add_child(details)
	var saved := _archive_for_entry(entry, archives)
	var view := Button.new()
	view.theme = BUTTON_THEME
	view.theme_type_variation = &"WordWovenActionButton"
	view.text = "View Loadout"
	view.custom_minimum_size.x = 145
	view.disabled = saved.is_empty()
	view.tooltip_text = "This run has no saved loadout." if saved.is_empty() else "View this run's final equipped letters and powers."
	if not saved.is_empty():
		view.pressed.connect(func(): RunArchiveOverlay.open_in(self, saved))
	row.add_child(view)


func _archive_for_entry(entry: Dictionary, archives: Array[Dictionary]) -> Dictionary:
	var matched: Dictionary = {}
	for archive: Dictionary in archives:
		var summary: Dictionary = archive.summary
		if absf(float(summary.get("recorded_at", 0)) - float(entry.get("recorded_at", -1))) < 0.001 \
				and summary.get("mode", "Story") == entry.get("mode", "Story") \
				and summary.get("score", -1) == entry.get("score", -2) \
				and summary.get("victory", false) == entry.get("victory", false):
			if not matched.is_empty():
				return {} # Leave ambiguous legacy matches in the archive browser.
			matched = archive
	return matched


func _label(text: String, size: int, color: Color = Color("e8dfce")) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
