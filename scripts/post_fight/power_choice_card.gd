extends Button
## The whole card remains one keyboard/mouse target; content never intercepts input.

const BODY_FONT := preload("res://assets/Fonts/Junicode.ttf")
const BOLD_FONT := preload("res://assets/Fonts/Junicode-Bold.ttf")
const FRAME := preload("res://assets/Themes/encounters/information_panel.tres")
const COLORS := {
	"fire": Color("ef735d"), "lightning": Color("e4c34a"),
	"water": Color("63b4ef"), "ice": Color("a3e9f7"),
	"nature": Color("79d37a"), "earth": Color("ca9264"),
}
const UNIVERSAL_COLOR := Color("ecd394")

var description_label: RichTextLabel
var _quality: Label
var _title: Label
var _owned: Label
var _art: Control
var _quality_color := Color.WHITE


func _ready() -> void:
	text = ""
	custom_minimum_size = Vector2(0, 428)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style: StyleBoxTexture = FRAME.duplicate()
		style.modulate_color = Color("fff0d0") if state in ["hover", "hover_pressed"] else Color.WHITE
		add_theme_stylebox_override(state, style)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = UNIVERSAL_COLOR
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(5)
	focus.set_expand_margin_all(3)
	add_theme_stylebox_override("focus", focus)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var content := VBoxContainer.new()
	content.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	_quality = _label(16, UNIVERSAL_COLOR)
	content.add_child(_quality)
	_art = Control.new()
	_art.mouse_filter = MOUSE_FILTER_IGNORE
	_art.custom_minimum_size.y = 100
	content.add_child(_art)
	_title = _label(27, Color("fff2d3"))
	_title.add_theme_font_override("font", BOLD_FONT)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size.y = 62
	content.add_child(_title)
	description_label = RichTextLabel.new()
	description_label.name = "EffectDescription"
	description_label.bbcode_enabled = true
	description_label.scroll_active = false
	description_label.mouse_filter = MOUSE_FILTER_IGNORE
	description_label.size_flags_vertical = SIZE_EXPAND_FILL
	description_label.custom_minimum_size.y = 114
	description_label.add_theme_font_override("normal_font", BODY_FONT)
	description_label.add_theme_font_override("bold_font", BOLD_FONT)
	description_label.add_theme_font_size_override("normal_font_size", 21)
	description_label.add_theme_font_size_override("bold_font_size", 21)
	description_label.add_theme_color_override("default_color", Color("e8dfce"))
	content.add_child(description_label)
	_owned = _label(18, Color("b8ad98"))
	content.add_child(_owned)
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	focus_entered.connect(_hover.bind(true))
	focus_exited.connect(_hover.bind(false))


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func present(info: Dictionary, quality: String, quality_color: Color, owned: int, claimed: bool, selected: bool) -> void:
	_quality_color = quality_color
	_quality.text = "◆  %s  ◆" % quality.to_upper()
	_quality.add_theme_color_override("font_color", quality_color)
	_title.text = String(info.get("name", "Unknown power"))
	var element := String(info.get("effect", "")).get_slice("_", 0)
	var color: Color = COLORS.get(element, UNIVERSAL_COLOR)
	description_label.text = "[center]%s[/center]" % colored_description(String(info.get("description", "")), color)
	_owned.text = "✓  POWER CHOSEN  •  %d owned" % owned if selected else "Copies owned: %d" % owned
	_owned.add_theme_color_override("font_color", quality_color if selected else Color("b8ad98"))
	tooltip_text = "%s\n%s\nCopies owned: %d" % [_title.text, info.get("description", ""), owned]
	disabled = claimed
	modulate = Color.WHITE if not claimed or selected else Color(0.7, 0.7, 0.7)
	_build_art(element)
	_hover(false)


static func colored_description(description: String, color: Color) -> String:
	var regex := RegEx.new()
	regex.compile("[+-]?\\d+(?:\\.\\d+)?%?")
	var result := ""
	var cursor := 0
	for number: RegExMatch in regex.search_all(description):
		result += description.substr(cursor, number.get_start() - cursor)
		result += "[color=#%s][b]%s[/b][/color]" % [color.to_html(false), number.get_string()]
		cursor = number.get_end()
	return result + description.substr(cursor)


func _build_art(element: String) -> void:
	for child: Node in _art.get_children():
		_art.remove_child(child)
		child.queue_free()
	if element in ElementArt.ELEMENTS:
		var flourish := ElementArt.image(element, "flourish")
		_art.add_child(flourish)
		flourish.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		flourish.offset_top = 60
		flourish.offset_left = 24
		flourish.offset_right = -24
		flourish.modulate.a = 0.5
		var emblem := ElementArt.image(element)
		_art.add_child(emblem)
		emblem.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
		emblem.offset_left = -39
		emblem.offset_right = 39
		emblem.offset_top = 0
		emblem.offset_bottom = 82
	else:
		# Universal powers represent all elements, with warm gold numeric accents.
		var row := HBoxContainer.new()
		row.mouse_filter = MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		_art.add_child(row)
		row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		for name: String in ElementArt.ELEMENTS:
			var emblem := ElementArt.image(name)
			emblem.custom_minimum_size = Vector2(34, 60)
			row.add_child(emblem)


func _hover(active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = Color(_quality_color, 0.85 if active else 0.25)
	style.set_border_width_all(2 if active else 1)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(_quality_color, 0.25 if active else 0.0)
	style.shadow_size = 12 if active else 0
	# A separate overlay preserves the ornate frame under the rarity glow.
	var outline := get_node_or_null("RarityOutline") as Panel
	if outline == null:
		outline = Panel.new()
		outline.name = "RarityOutline"
		outline.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(outline)
		outline.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	outline.add_theme_stylebox_override("panel", style)
