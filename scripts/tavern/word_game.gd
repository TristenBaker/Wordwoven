extends Control
## Direct typing, flip reveals, and a persistent color-aware keyboard.

const WORDS: Array[String] = ["ember", "frost", "quill", "rhyme", "stone", "thorn", "tidal", "gloom", "spark", "flame"]
const KEY_ROWS: Array[String] = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
const BODY := preload("res://assets/Fonts/Junicode.ttf")
const EMPTY := Color("1d2936")
const ABSENT := Color("3b4a55")
const PRESENT := Color("c49645")
const CORRECT := Color("4d9b78")

var target := ""
var row := 0
var guess := ""
var revealing := false
var cell_panels: Array[Array] = []
var cell_labels: Array[Array] = []
var key_buttons: Dictionary[String, Button] = {}
var key_ranks: Dictionary[String, int] = {}
var status: Label

func _ready() -> void:
	target = WORDS.pick_random()
	_build_ui()

func _unhandled_key_input(event: InputEvent) -> void:
	if revealing or row >= 6 or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ENTER:
		_submit()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_BACKSPACE:
		_backspace()
		get_viewport().set_input_as_handled()
		return
	var typed := char(event.unicode).to_lower()
	if typed.length() == 1 and typed >= "a" and typed <= "z":
		_add_letter(typed)
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("101823")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(690, 610)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	box.add_child(_label("THE INKWELL WORD", 36, Color("a9e7f5")))
	box.add_child(_label("Find the five-letter word in six guesses.", 18, Color("c0d1d4")))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	box.add_child(grid)
	for _row: int in range(6):
		var panel_row: Array = []
		var label_row: Array = []
		for _column: int in range(5):
			var cell := PanelContainer.new()
			cell.custom_minimum_size = Vector2(54, 54)
			cell.add_theme_stylebox_override("panel", _cell_style(EMPTY))
			cell.pivot_offset = Vector2(27, 27)
			grid.add_child(cell)
			var label := Label.new()
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 28)
			label.add_theme_color_override("font_color", Color("f2f5ea"))
			cell.add_child(label)
			panel_row.append(cell)
			label_row.append(label)
		cell_panels.append(panel_row)
		cell_labels.append(label_row)
	status = _label("", 17, Color("99b5bd"))
	box.add_child(status)
	var keyboard_zone := HBoxContainer.new()
	keyboard_zone.alignment = BoxContainer.ALIGNMENT_CENTER
	keyboard_zone.add_theme_constant_override("separation", 10)
	box.add_child(keyboard_zone)
	var keyboard := VBoxContainer.new()
	keyboard.alignment = BoxContainer.ALIGNMENT_CENTER
	keyboard.add_theme_constant_override("separation", 5)
	keyboard_zone.add_child(keyboard)
	for letters: String in KEY_ROWS:
		var key_row := HBoxContainer.new()
		key_row.alignment = BoxContainer.ALIGNMENT_CENTER
		key_row.add_theme_constant_override("separation", 4)
		keyboard.add_child(key_row)
		for letter: String in letters:
			var key := Button.new()
			key.text = letter.to_upper()
			key.custom_minimum_size = Vector2(39, 39)
			key.add_theme_font_size_override("font_size", 17)
			key.add_theme_stylebox_override("normal", _key_style(EMPTY))
			key.add_theme_stylebox_override("hover", _key_style(EMPTY.lightened(0.14)))
			key.pressed.connect(_add_letter.bind(letter))
			key_row.add_child(key)
			key_buttons[letter] = key
	var action_keys := VBoxContainer.new()
	action_keys.alignment = BoxContainer.ALIGNMENT_CENTER
	action_keys.add_theme_constant_override("separation", 6)
	keyboard_zone.add_child(action_keys)
	var erase := Button.new()
	erase.text = "⌫"
	erase.custom_minimum_size = Vector2(74, 35)
	erase.pressed.connect(_backspace)
	action_keys.add_child(erase)
	var enter := Button.new()
	enter.text = "ENTER"
	enter.custom_minimum_size = Vector2(74, 52)
	enter.pressed.connect(_submit)
	action_keys.add_child(enter)
	var back := Button.new()
	back.text = "Return to Tavern"
	back.pressed.connect(func(): get_tree().change_scene_to_file(ScenePaths.TAVERN))
	box.add_child(back)

func _add_letter(letter: String) -> void:
	if revealing or row >= 6 or guess.length() >= 5:
		return
	guess += letter
	_render_typing_row()

func _backspace() -> void:
	if revealing or row >= 6 or guess.is_empty():
		return
	guess = guess.left(guess.length() - 1)
	_render_typing_row()

func _render_typing_row() -> void:
	for index: int in range(5):
		var label: Label = cell_labels[row][index]
		label.text = guess[index].to_upper() if index < guess.length() else ""

func _submit() -> void:
	if revealing or row >= 6:
		return
	if guess.length() != 5:
		status.text = "Use exactly five letters."
		return
	if WordNet.is_ready and not WordNet.word_exists(guess):
		status.text = "That word is not in the lexicon."
		return
	revealing = true
	var result: Array[Color] = _score_guess(guess)
	await _reveal_guess(result)
	if guess == target:
		status.text = "Perfect. The tavern remembers \"%s\"." % guess.capitalize()
		row = 6
		return
	row += 1
	if row >= 6:
		status.text = "The word was %s. Another round is waiting." % target.to_upper()
		return
	guess = ""
	revealing = false
	status.text = "%d guesses remain." % (6 - row)

func _score_guess(value: String) -> Array[Color]:
	var remaining: Array[String] = []
	for character: String in target:
		remaining.append(character)
	var result: Array[Color] = []
	for index: int in range(5):
		var letter: String = value[index]
		if letter == target[index]:
			result.append(CORRECT)
			remaining.erase(letter)
		else:
			result.append(ABSENT)
	for index: int in range(5):
		var letter: String = value[index]
		if result[index] == ABSENT and remaining.has(letter):
			result[index] = PRESENT
			remaining.erase(letter)
	return result

func _reveal_guess(result: Array[Color]) -> void:
	for index: int in range(5):
		var cell: PanelContainer = cell_panels[row][index]
		var letter: String = guess[index]
		var flip := create_tween()
		flip.tween_property(cell, "scale:x", 0.05, 0.12)
		await flip.finished
		cell.add_theme_stylebox_override("panel", _cell_style(result[index]))
		_update_key(letter, result[index])
		var unfold := create_tween()
		unfold.tween_property(cell, "scale:x", 1.0, 0.12)
		await unfold.finished
		await get_tree().create_timer(0.06).timeout

func _update_key(letter: String, color: Color) -> void:
	var rank: int = 3 if color == CORRECT else (2 if color == PRESENT else 1)
	if rank <= int(key_ranks.get(letter, 0)):
		return
	key_ranks[letter] = rank
	var key: Button = key_buttons[letter]
	key.add_theme_stylebox_override("normal", _key_style(color))
	key.add_theme_stylebox_override("hover", _key_style(color.lightened(0.12)))

func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", BODY)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("192532")
	style.border_color = Color("5c9ead")
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.content_margin_left = 32.0
	style.content_margin_right = 32.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 22.0
	return style

func _cell_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("82b3bc") if color == EMPTY else color.lightened(0.24)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style

func _key_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	return style
