extends Button
## Historical inventory tile: only saved facts, never live combat tooltips.
const TILE_THEME := preload("res://assets/Themes/letter_tiles/default_letter_tile_theme.tres")
const FONT := preload("res://assets/Fonts/Junicode-Bold.ttf")
var slot_letter := ""
var archived_tile: Dictionary = {}


func setup(letter: String, saved: Dictionary, selected: bool = false) -> void:
	slot_letter = letter
	archived_tile = saved
	theme = LetterTooltip.transparent_shell_theme()
	custom_minimum_size = Vector2(78, 92)
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if not saved.is_empty() else CURSOR_ARROW
	disabled = saved.is_empty()
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.set_border_width_all(2 if saved.is_empty() else 4)
	style.bg_color = Color("181b24")
	style.border_color = Color("494234")
	var stats: LetterStats
	if not saved.is_empty():
		stats = RunArchive.letter_from_record(saved)
		style.bg_color = TILE_THEME.fill_for(stats.element)
		style.border_color = Color("ffe0a2") if selected else TILE_THEME.border_for(stats.level)
	for state: String in ["normal", "disabled", "pressed"]:
		add_theme_stylebox_override(state, style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.border_color = Color("ffe0a2")
	hover.bg_color = style.bg_color.lightened(0.12)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("focus", hover)
	var layout := VBoxContainer.new()
	layout.mouse_filter = MOUSE_FILTER_IGNORE
	layout.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	layout.offset_top = 6
	layout.offset_bottom = -6
	layout.add_theme_constant_override("separation", 0)
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(layout)
	var character := _label(letter.to_upper(), 35 if stats != null else 29)
	character.add_theme_color_override("font_color", Color("fff7df") if stats != null else Color("716a5d"))
	layout.add_child(character)
	if stats != null:
		layout.add_child(_label("Lv %d" % stats.level, 15))
		layout.add_child(_label(stats.element_name_text(), 12))
		tooltip_text = "%s · %s\nFinal level %d\nClick to view this saved letter." % [letter.to_upper(), stats.element_name_text(), stats.level]
	else:
		layout.add_child(_label("Empty", 12))
		tooltip_text = "Empty %s slot at the end of this run." % letter.to_upper()


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("e8dfce") if not archived_tile.is_empty() else Color("716a5d"))
	return label


func _make_custom_tooltip(_for_text: String) -> Object:
	var tooltip := LetterTooltip.new()
	tooltip.add_theme_stylebox_override("panel", tooltip._panel_style())
	var label := _label(tooltip_text, 17)
	tooltip.add_child(label)
	return tooltip
