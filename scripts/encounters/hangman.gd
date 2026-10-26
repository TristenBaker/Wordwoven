extends Control

const Rules = preload("res://scripts/encounters/hangman_rules.gd")
const FONT = preload("res://assets/Fonts/Junicode.ttf")
const TITLE_FONT = preload("res://assets/Fonts/BLKCHCRY.TTF")

var puzzle: Dictionary = {}
var placed: Array[int] = []
var finished := false
var deadline_ms: int = 0
var cells: Array[PanelContainer] = []
var cell_labels: Array[Label] = []
var hand_tiles: Array[PanelContainer] = []
var game_ui: Control
var pending_rewards: Array[LetterStats] = []
var result_committed: bool = false
var timer_label: Label
var timer_bar: ProgressBar
var feedback: Label
var submit_button: Button
var clear_button: Button
var hand_row: GridContainer
var result_label: Label
var continue_button: Button


func _ready() -> void:
	if RunState.pending_optional_encounter != "hangman" or not RunState.optional_encounter_available("hangman"):
		get_tree().change_scene_to_file.call_deferred(ScenePaths.ENCOUNTER_SELECT)
		return
	if not WordNet.is_ready:
		var waiting := _label("Preparing the combat word bank...", 24, Color("f0d6a0"))
		waiting.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		add_child(waiting)
		var loaded: bool = await WordNet.loading_finished
		if not is_inside_tree():
			return
		waiting.queue_free()
		if not loaded:
			_return_unavailable()
			return
	DebugTools.hangman_reset_requested.connect(_on_debug_reset_requested)
	if not _start_puzzle():
		_return_unavailable()


func _start_puzzle(tier_override: int = -1) -> bool:
	var next_puzzle: Dictionary = Rules.new_puzzle(RunState.route_depth, tier_override)
	if next_puzzle.is_empty():
		return false
	if game_ui != null:
		remove_child(game_ui)
		game_ui.queue_free()
	game_ui = null
	cells.clear()
	cell_labels.clear()
	hand_tiles.clear()
	placed.clear()
	pending_rewards.clear()
	result_committed = false
	finished = false
	puzzle = next_puzzle
	_build_ui()
	deadline_ms = Time.get_ticks_msec() + int(float(puzzle.seconds) * 1000.0)
	set_process(true)
	_process(0.0)
	return true


func _on_debug_reset_requested(tier_override: int) -> void:
	if not _start_puzzle(tier_override):
		feedback.text = "Unable to draw a word for that tier."


func _return_unavailable() -> void:
	RunState.pending_optional_encounter = ""
	RunState.pending_route_activity = ""
	RunState.pending_route_key = ""
	get_tree().change_scene_to_file.call_deferred(ScenePaths.ENCOUNTER_SELECT)


func _process(_delta: float) -> void:
	if finished:
		return
	var remaining: float = maxf(0.0, float(deadline_ms - Time.get_ticks_msec()) / 1000.0)
	timer_label.text = "TIME  %.1f s" % remaining
	timer_bar.value = remaining
	if remaining <= 0.0:
		_finish(false)


func _unhandled_key_input(event: InputEvent) -> void:
	if finished or DebugTools.panel.visible or not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ENTER:
		_submit()
	elif key_event.keycode == KEY_BACKSPACE:
		_erase_last()
	else:
		var typed: String = char(key_event.unicode).to_lower()
		if typed.length() == 1 and typed >= "a" and typed <= "z":
			for index: int in puzzle.hand.size():
				if puzzle.hand[index] == typed and not placed.has(index):
					_place(index)
					break
				else:
					feedback.text = "That letter is not available in your hand."
		else:
			return
	get_viewport().set_input_as_handled()


func _build_ui() -> void:
	game_ui = Control.new()
	game_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(game_ui)
	var background := TextureRect.new()
	background.texture = load("res://art/backgrounds/tundra.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.045, 0.09, 0.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_ui.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(850, 580)
	panel.add_theme_stylebox_override("panel", _style(Color("122333"), Color("a58c62"), 2))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)
	var title := _label("THE MISSING WORD", 36, Color("f0d6a0"))
	title.add_theme_font_override("font", TITLE_FONT)
	box.add_child(title)
	box.add_child(_label("Type the missing letters in order. Press Enter to guess; Backspace erases.", 19, Color("dfebed")))
	box.add_child(_label("Wrong guesses clear your placed letters. The timer keeps running.", 17, Color("b7c9cf")))
	timer_label = _label("", 23, Color("f5d08b"))
	box.add_child(timer_label)
	timer_bar = ProgressBar.new()
	timer_bar.custom_minimum_size = Vector2(0, 16)
	timer_bar.max_value = float(puzzle.seconds)
	timer_bar.value = float(puzzle.seconds)
	timer_bar.show_percentage = false
	box.add_child(timer_bar)
	var word_row := GridContainer.new()
	word_row.columns = mini(14, String(puzzle.word).length())
	word_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	word_row.add_theme_constant_override("h_separation", 4)
	word_row.add_theme_constant_override("v_separation", 4)
	box.add_child(word_row)
	for index: int in String(puzzle.word).length():
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(48, 50) if String(puzzle.word).length() > 12 else Vector2(59, 64)
		word_row.add_child(cell)
		var label := _label("", 24 if String(puzzle.word).length() > 12 else 30, Color("f3efe2"))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(label)
		cells.append(cell)
		cell_labels.append(label)
	box.add_child(_label("YOUR LETTERS · A–Z", 18, Color("f0d6a0")))
	hand_row = GridContainer.new()
	hand_row.columns = mini(14, puzzle.hand.size())
	hand_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hand_row.add_theme_constant_override("h_separation", 5)
	hand_row.add_theme_constant_override("v_separation", 5)
	box.add_child(hand_row)
	for index: int in puzzle.hand.size():
		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(48, 50)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_theme_stylebox_override("panel", _style(Color("273b4a"), Color("98b5bd"), 1))
		var tile_label := _label(String(puzzle.hand[index]).to_upper(), 26, Color("eef2e9"))
		tile_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tile_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(tile_label)
		hand_row.add_child(tile)
		hand_tiles.append(tile)
	feedback = _label("Type the missing letters from left to right.", 18, Color("b7d7dc"))
	box.add_child(feedback)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	box.add_child(actions)
	submit_button = _action("Guess", _submit)
	actions.add_child(submit_button)
	clear_button = _action("Clear", _clear)
	actions.add_child(clear_button)
	var leave_button := _action("Leave", func(): _finish(false))
	actions.add_child(leave_button)
	result_label = _label("", 20, Color("f0d6a0"))
	result_label.visible = false
	box.add_child(result_label)
	continue_button = _action("Return to Map", _return_to_map)
	continue_button.focus_mode = Control.FOCUS_ALL
	continue_button.visible = false
	box.add_child(continue_button)
	_refresh()


func _place(index: int) -> void:
	if finished or placed.has(index) or placed.size() >= puzzle.missing.size():
		return
	placed.append(index)
	feedback.text = "Press Guess when every gap is filled."
	_refresh()


func _erase_last() -> void:
	if finished or placed.is_empty():
		return
	placed.pop_back()
	_refresh()


func _clear() -> void:
	if finished:
		return
	placed.clear()
	_refresh()


func _submit() -> void:
	if finished:
		return
	if Time.get_ticks_msec() >= deadline_ms:
		_finish(false)
		return
	if placed.size() < puzzle.missing.size():
		feedback.text = "Fill every gap before guessing."
		return
	var guess := ""
	for index: int in placed:
		guess += String(puzzle.hand[index])
	if guess == Rules.expected_letters(puzzle):
		_finish(true)
	else:
		placed.clear()
		feedback.text = "Incorrect. Try again; the timer keeps running."
		_refresh()


func _refresh() -> void:
	if puzzle.is_empty():
		return
	for index: int in String(puzzle.word).length():
		var gap: int = puzzle.missing.find(index)
		var revealed: bool = gap < 0 or finished
		var filled: bool = gap >= 0 and gap < placed.size() and not finished
		cell_labels[index].text = String(puzzle.word[index]).to_upper() if revealed else (String(puzzle.hand[placed[gap]]).to_upper() if filled else "")
		cells[index].add_theme_stylebox_override("panel", _style(
			Color("26433c") if revealed else Color("1b2b39"),
			Color("a4a6a9") if gap >= 0 and not finished else Color("9bc5a4"),
			2 if gap >= 0 else 1
		))
	for index: int in hand_tiles.size():
		hand_tiles[index].modulate = Color(0.45, 0.45, 0.45, 0.5) if placed.has(index) else Color.WHITE
	submit_button.disabled = finished or placed.size() != puzzle.missing.size()
	clear_button.disabled = finished or placed.is_empty()


func _finish(won: bool) -> void:
	if finished:
		return
	finished = true
	var rewards: Array[String] = []
	if won:
		for _index: int in int(puzzle.reward_count):
			var item: LetterStats = RunState.rolled_letter_drop_at_level(int(puzzle.reward_level))
			pending_rewards.append(item)
			rewards.append(item.letter.to_upper())
	_refresh()
	feedback.visible = false
	hand_row.visible = false
	submit_button.get_parent().visible = false
	result_label.text = ("Solved: %s. Won %d letter items: %s." % [
		String(puzzle.word).to_upper(), rewards.size(), ", ".join(rewards)
	]) if won else "The word was %s. No reward." % String(puzzle.word).to_upper()
	result_label.visible = true
	continue_button.visible = true
	continue_button.grab_focus()
	set_process(false)


func _return_to_map() -> void:
	if not finished or result_committed:
		return
	result_committed = true
	var rewards: Array[String] = []
	for item: LetterStats in pending_rewards:
		rewards.append(item.letter.to_upper())
		if RunState.use_itemized_letters:
			RunState.add_letter_item(item)
		else:
			RunState.deck.append(item)
	if not RunState.use_itemized_letters and not pending_rewards.is_empty():
		EventBus.emit_deck_changed()
	RunState.optional_encounters["hangman"] = {
		"won": not pending_rewards.is_empty(),
		"word": puzzle.word,
		"rewards": rewards,
	}
	RunState.finish_route_activity()
	RunState.pending_optional_encounter = ""
	get_tree().change_scene_to_file(ScenePaths.ENCOUNTER_SELECT)


func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _action(value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(135, 46)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button


func _style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(5)
	style.content_margin_left = 6
	style.content_margin_right = 6
	return style
