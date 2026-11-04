extends Control
## Free drawing sandbox sharing the forge's exact board and offline model.

const BUTTON_THEME := preload("res://assets/Themes/WordWoven_Button_Theme.tres")
var board: ForgeDrawingBoard
var result: Label
var status: Label
var recognize_button: Button
var model_preview: TextureRect
var history: Label
var _recent: PackedStringArray = []
var _reveal: Tween


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("160c13")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(760, 0)
	content.add_theme_constant_override("separation", 16)
	center.add_child(content)
	content.add_child(_label("HANDWRITING LAB", 34))
	content.add_child(_label("Draw a letter and see what the forge recognizes. No tiles needed.", 19))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	content.add_child(row)
	board = ForgeDrawingBoard.new()
	board.custom_minimum_size = Vector2(460, 300)
	row.add_child(board)
	var results := VBoxContainer.new()
	results.custom_minimum_size = Vector2(260, 300)
	results.add_theme_constant_override("separation", 6)
	row.add_child(results)
	results.add_child(_label("THE FORGE SEES", 18))
	result = _label("?", 100)
	result.custom_minimum_size = Vector2(260, 125)
	results.add_child(result)
	results.add_child(_label("Model input · 28 × 28", 15))
	model_preview = TextureRect.new()
	model_preview.custom_minimum_size = Vector2(84, 84)
	model_preview.size_flags_horizontal = SIZE_SHRINK_CENTER
	model_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	model_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	model_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	results.add_child(model_preview)
	status = _label("Draw one A–Z letter, then click Recognize.", 18)
	content.add_child(status)
	history = _label("", 18)
	content.add_child(history)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	_button(actions, "Clear", _clear)
	recognize_button = _button(actions, "Recognize", _recognize)
	recognize_button.disabled = true
	_button(actions, "Return to Tavern", func(): get_tree().change_scene_to_file(ScenePaths.TAVERN))
	board.changed.connect(func(): recognize_button.disabled = not board.has_ink() or not ForgeLetterRecognizer.available())
	if not ForgeLetterRecognizer.available():
		status.text = "Recognition model unavailable."


func _recognize() -> void:
	if not board.has_ink():
		return
	var pixels := board.pixels()
	var started := Time.get_ticks_usec()
	var letter := ForgeLetterRecognizer.recognize(pixels)
	var milliseconds := (Time.get_ticks_usec() - started) / 1000.0
	if letter.is_empty():
		status.text = "Recognition model unavailable."
		return
	var image := Image.create(28, 28, false, Image.FORMAT_RGB8)
	for y: int in 28:
		for x: int in 28:
			var value := pixels[y * 28 + x]
			image.set_pixel(x, y, Color(value, value, value))
	model_preview.texture = ImageTexture.create_from_image(image)
	result.text = letter.to_upper()
	status.text = "Recognized %s · %.1f ms · Offline" % [letter.to_upper(), milliseconds]
	_recent.append(letter.to_upper())
	if _recent.size() > 10:
		_recent.remove_at(0)
	history.text = "Recent: " + "   ".join(_recent)
	if _reveal != null and _reveal.is_valid():
		_reveal.kill()
	result.pivot_offset = result.size * 0.5
	result.scale = Vector2(0.6, 0.6)
	result.modulate.a = 0.0
	_reveal = create_tween().set_parallel(true)
	_reveal.tween_property(result, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reveal.tween_property(result, "modulate:a", 1.0, 0.3)


func _clear() -> void:
	board.clear_drawing()
	if _reveal != null and _reveal.is_valid():
		_reveal.kill()
	result.scale = Vector2.ONE
	result.modulate.a = 1.0
	result.text = "?"
	model_preview.texture = null
	status.text = "Draw one A–Z letter, then click Recognize."


func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("ffe0aa"))
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(180, 44)
	button.theme = BUTTON_THEME
	button.theme_type_variation = &"WordWovenActionButton"
	button.pressed.connect(action)
	parent.add_child(button)
	return button
