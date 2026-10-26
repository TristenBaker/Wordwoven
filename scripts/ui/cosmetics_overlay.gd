class_name CosmeticsOverlay
extends Control
## A two-step persistent cosmetic picker: alphabet first, then a focused
## letter view with scrollable visual avatar choices.

const BODY := preload("res://assets/Fonts/Junicode.ttf")
const BUTTON_THEME := preload("res://assets/Themes/WordWoven_Button_Theme.tres")

var _selected_letter := ""
var _chooser: VBoxContainer
var _detail: VBoxContainer
var _letter_grid: GridContainer
var _current_preview: TextureRect
var _current_label: Label
var _options: VBoxContainer


static func open_in(parent: Node) -> void:
	var existing := parent.get_node_or_null("CosmeticsOverlay")
	if existing != null:
		existing.queue_free()
	var overlay := CosmeticsOverlay.new()
	overlay.name = "CosmeticsOverlay"
	parent.add_child(overlay)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_show_letter_chooser()


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.012, 0.03, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 610)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	content.add_child(_label("LETTER COSMETICS", 38, Color("ffe08a")))
	_chooser = VBoxContainer.new()
	_chooser.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chooser.add_theme_constant_override("separation", 14)
	content.add_child(_chooser)
	_detail = VBoxContainer.new()
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 10)
	content.add_child(_detail)
	var close := Button.new()
	close.theme = BUTTON_THEME
	close.theme_type_variation = &"WordWovenActionButton"
	close.text = "Back"
	close.custom_minimum_size = Vector2(180, 42)
	close.pressed.connect(queue_free)
	content.add_child(close)
	_build_chooser()
	_build_detail()


func _build_chooser() -> void:
	_chooser.add_child(_label("Choose a letter to customize", 21, Color("d8cbb5")))
	_letter_grid = GridContainer.new()
	_letter_grid.columns = 7
	_letter_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_letter_grid.add_theme_constant_override("h_separation", 12)
	_letter_grid.add_theme_constant_override("v_separation", 12)
	_chooser.add_child(_letter_grid)
	for letter: String in "abcdefghijklmnopqrstuvwxyz":
		var button := Button.new()
		button.custom_minimum_size = Vector2(82, 86)
		button.theme = BUTTON_THEME
		button.theme_type_variation = &"WordWovenActionButton"
		button.tooltip_text = "%s — current: %s" % [
			letter.to_upper(), _cosmetic_name(letter),
		]
		var preview := TextureRect.new()
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.position = Vector2(8, 19)
		preview.size = Vector2(66, 62)
		preview.texture = _texture_for(letter)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(preview)
		var letter_label := Label.new()
		letter_label.text = letter.to_upper()
		letter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		letter_label.position = Vector2(0, 1)
		letter_label.size = Vector2(82, 25)
		letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter_label.add_theme_font_override("font", BODY)
		letter_label.add_theme_font_size_override("font_size", 22)
		letter_label.add_theme_color_override("font_color", Color("fff3d0"))
		button.add_child(letter_label)
		button.pressed.connect(_select_letter.bind(letter))
		_letter_grid.add_child(button)


func _build_detail() -> void:
	var header := HBoxContainer.new()
	_detail.add_child(header)
	var back_to_letters := Button.new()
	back_to_letters.theme = BUTTON_THEME
	back_to_letters.theme_type_variation = &"WordWovenActionButton"
	back_to_letters.text = "← Letters"
	back_to_letters.custom_minimum_size = Vector2(150, 40)
	back_to_letters.pressed.connect(_show_letter_chooser)
	header.add_child(back_to_letters)
	_current_label = _label("", 24, Color("f6d797"))
	_current_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_current_label)
	var hero := HBoxContainer.new()
	hero.custom_minimum_size = Vector2(0, 180)
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_theme_constant_override("separation", 18)
	_detail.add_child(hero)
	_current_preview = TextureRect.new()
	_current_preview.custom_minimum_size = Vector2(160, 160)
	_current_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_current_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.add_child(_current_preview)
	var current_text := VBoxContainer.new()
	current_text.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(current_text)
	current_text.add_child(_label("CURRENT COSTUME", 18, Color("d8cbb5")))
	var detail_note := _label("Select any available avatar below. This changes the portrait display for this letter.", 18, Color("d8cbb5"))
	detail_note.custom_minimum_size = Vector2(380, 0)
	current_text.add_child(detail_note)
	_detail.add_child(_label("AVAILABLE COSTUMES", 19, Color("f6d797")))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 270)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail.add_child(scroll)
	_options = VBoxContainer.new()
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options.add_theme_constant_override("separation", 8)
	scroll.add_child(_options)


func _show_letter_chooser() -> void:
	_chooser.show()
	_detail.hide()


func _select_letter(letter: String) -> void:
	_selected_letter = letter
	_chooser.hide()
	_detail.show()
	_refresh_detail()


func _refresh_detail() -> void:
	_current_label.text = "%s  •  %s" % [
		_selected_letter.to_upper(), _cosmetic_name(_selected_letter),
	]
	_current_preview.texture = _texture_for(_selected_letter)
	for child: Node in _options.get_children():
		child.queue_free()
	_add_costume_option("", "Default", _default_texture_for(_selected_letter))
	for cosmetic: String in PlayerProfile.COSMETICS:
		_add_costume_option(cosmetic, String(PlayerProfile.COSMETICS[cosmetic]), _texture_for_cosmetic(cosmetic))


func _add_costume_option(cosmetic: String, name: String, texture: Texture2D) -> void:
	var selected := PlayerProfile.cosmetic_for_letter(_selected_letter) == cosmetic
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 100)
	button.theme = BUTTON_THEME
	button.theme_type_variation = &"WordWovenActionButton"
	button.add_theme_stylebox_override("normal", _costume_style(selected, false))
	button.add_theme_stylebox_override("hover", _costume_style(selected, true))
	button.pressed.connect(_apply_costume.bind(cosmetic))
	_options.add_child(button)
	var preview := TextureRect.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.position = Vector2(14, 8)
	preview.size = Vector2(84, 84)
	preview.texture = texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	button.add_child(preview)
	var name_label := Label.new()
	name_label.text = "%s%s" % [name, "  ✓ EQUIPPED" if selected else ""]
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.position = Vector2(120, 18)
	name_label.size = Vector2(500, 32)
	name_label.add_theme_font_override("font", BODY)
	name_label.add_theme_font_size_override("font_size", 23)
	name_label.add_theme_color_override("font_color", Color("ffe08a") if selected else Color("f6ead4"))
	button.add_child(name_label)
	var description := Label.new()
	description.text = "Battle-ready: uses this cosmetic's full animation and action style."
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.position = Vector2(120, 53)
	description.size = Vector2(520, 28)
	description.add_theme_font_override("font", BODY)
	description.add_theme_font_size_override("font_size", 16)
	description.add_theme_color_override("font_color", Color("c8bda9"))
	button.add_child(description)


func _apply_costume(cosmetic: String) -> void:
	if cosmetic.is_empty():
		PlayerProfile.clear_letter_cosmetic(_selected_letter)
	else:
		PlayerProfile.set_letter_cosmetic(_selected_letter, cosmetic)
	_refresh_detail()


func _cosmetic_name(letter: String) -> String:
	var selected := PlayerProfile.cosmetic_for_letter(letter)
	if not selected.is_empty():
		return String(PlayerProfile.COSMETICS[selected])
	return "Default"


func _texture_for(letter: String) -> Texture2D:
	return PlayerProfile.cosmetic_texture(letter, _default_texture_for(letter))


func _default_texture_for(letter: String) -> Texture2D:
	var stats := LetterStats.create(letter)
	if stats.element in [LetterStats.Element.FIRE, LetterStats.Element.EARTH]:
		return PlayerProfile.WARRIOR
	if stats.element in [LetterStats.Element.LIGHTNING, LetterStats.Element.ICE]:
		return PlayerProfile.ROGUE
	return PlayerProfile.HEALER


func _texture_for_cosmetic(cosmetic: String) -> Texture2D:
	var resource := PlayerProfile.cosmetic_resource(cosmetic)
	return resource.portrait if resource != null else PlayerProfile.HEALER


func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", BODY)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _costume_style(selected: bool, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("3b2a22") if hovered else Color("251b27")
	style.border_color = Color("ffe08a") if selected else Color("8c6a54")
	style.set_border_width_all(3 if selected else 2)
	style.set_corner_radius_all(8)
	return style


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171226")
	style.border_color = Color("c79b50")
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.content_margin_left = 30.0
	style.content_margin_right = 30.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 22.0
	return style
