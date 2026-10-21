extends Control
const Balance = preload("res://data/balance/tuning.gd")
## Three one-use fishing holes. A chosen hole reveals a fish, then asks the
## player to copy a WordNet-derived sequence of warm-related words within one
## continuous eight-second countdown.

enum FishingState {
	WAITING_FOR_WORDNET,
	CHOOSING_HOLE,
	FISHING,
	RESOLVED,
}

const HOLE_COUNT: int = preload("res://data/balance/tuning.gd").ICE_FISHING_CONTROLLER_HOLE_COUNT
const WORD_SECONDS: float = preload("res://data/balance/tuning.gd").ICE_FISHING_CONTROLLER_WORD_SECONDS
const WARM_SEEDS: Array[String] = preload("res://data/balance/tuning.gd").ICE_FISHING_CONTROLLER_WARM_SEEDS
const FISH_TABLE: Array[Dictionary] = preload("res://data/balance/tuning.gd").ICE_FISHING_CONTROLLER_FISH_TABLE

var _state: FishingState = FishingState.WAITING_FOR_WORDNET
var _fish: Dictionary = {}
var _warm_word_pool: Array[String] = []
var _challenge_words: Array[String] = []
var _current_word_index: int = 0
var _selected_hole: int = -1

@onready var hole_selection_panel: PanelContainer = %HoleSelectionPanel
@onready var hole_status_label: Label = %HoleStatusLabel
@onready var tutorial_panel: PanelContainer = %TutorialPanel
@onready var start_fishing_button: Button = %StartFishingButton
@onready var subtitle_label: Label = $MainPanel/Margin/Content/Subtitle
@onready var hole_one_button: Button = %HoleOneButton
@onready var hole_two_button: Button = %HoleTwoButton
@onready var hole_three_button: Button = %HoleThreeButton
@onready var fish_panel: PanelContainer = %FishPanel
@onready var fish_name_label: Label = %FishNameLabel
@onready var rarity_label: Label = %RarityLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var progress_label: Label = %ProgressLabel
@onready var target_panel: PanelContainer = %TargetPanel
@onready var target_word_label: Label = %TargetWordLabel
@onready var timer_label: Label = %TimerLabel
@onready var timer_bar: ProgressBar = %TimerBar
@onready var input_row: HBoxContainer = %InputRow
@onready var word_input: LineEdit = %WordInput
@onready var submit_button: Button = %SubmitButton
@onready var feedback_label: Label = %FeedbackLabel
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel
@onready var loot_label: Label = %LootLabel
@onready var retry_button: Button = %RetryButton
@onready var return_button: Button = %ReturnButton
@onready var word_timer: Timer = %WordTimer


func _ready() -> void:
	if RunState.pending_route_activity == "ice_fishing":
		return_button.text = "Return to Route"
	var hole_buttons: Array[Button] = [
		hole_one_button, hole_two_button, hole_three_button,
	]
	for hole_index: int in range(hole_buttons.size()):
		hole_buttons[hole_index].pressed.connect(
			_select_hole.bind(hole_index)
		)
	submit_button.pressed.connect(_submit_word)
	# Match combat typing: Enter submits without releasing the keyboard field.
	word_input.keep_editing_on_text_submit = true
	word_input.text_submitted.connect(_on_text_submitted)
	start_fishing_button.pressed.connect(_dismiss_tutorial)
	retry_button.pressed.connect(_show_hole_selection)
	return_button.pressed.connect(_return_from_fishing)
	word_timer.timeout.connect(_on_word_timer_timeout)
	result_panel.hide()
	tutorial_panel.hide()
	_set_fishing_visible(false)

	if WordNet.is_ready:
		_prepare_word_pool()
		_show_entry_screen()
	else:
		hole_selection_panel.hide()
		feedback_label.show()
		feedback_label.text = "Finding warm words in WordNet..."
		WordNet.loading_finished.connect(_on_wordnet_loaded, CONNECT_ONE_SHOT)


func _process(_delta: float) -> void:
	if _state != FishingState.FISHING:
		return
	timer_bar.value = word_timer.time_left
	timer_label.text = "TIME LEFT  %.1fs" % word_timer.time_left
	if not word_input.has_focus():
		call_deferred("_focus_word_input")


func _focus_word_input() -> void:
	if _state != FishingState.FISHING or not word_input.editable:
		return
	word_input.grab_focus()
	word_input.caret_column = word_input.text.length()


func _on_wordnet_loaded(success: bool) -> void:
	if success:
		_prepare_word_pool()
		_show_entry_screen()
		return
	feedback_label.show()
	feedback_label.text = "WordNet could not be loaded."
	timer_label.text = "Fishing is unavailable."


func _prepare_word_pool() -> void:
	_warm_word_pool.clear()
	_add_wordnet_word("warm")
	for synonym: String in WordNet.synonyms_of("warm", 32):
		_add_wordnet_word(synonym)

	for seed: String in WARM_SEEDS:
		var relation: Dictionary = WordNet.similarity_detailed(seed, "warm")
		if seed != "warm" and float(relation.get("score", 0.0)) < Balance.FISHING_SEMANTIC_THRESHOLD:
			continue
		_add_wordnet_word(seed)
		for synonym: String in WordNet.synonyms_of(seed, 12):
			_add_wordnet_word(synonym)


func _show_entry_screen() -> void:
	if RunState.fishing_tutorial_seen or RunState.fishing_hole_chosen >= 0:
		_show_hole_selection()
	else:
		_show_tutorial()


func _show_tutorial() -> void:
	_state = FishingState.CHOOSING_HOLE
	word_timer.stop()
	_set_fishing_visible(false)
	hole_selection_panel.hide()
	result_panel.hide()
	tutorial_panel.show()
	subtitle_label.show()
	start_fishing_button.grab_focus()


func _dismiss_tutorial() -> void:
	RunState.fishing_tutorial_seen = true
	_show_hole_selection()


func _add_wordnet_word(candidate: String) -> void:
	var word: String = candidate.strip_edges().to_lower()
	if word.length() < Balance.FISHING_MIN_LENGTH or word.length() > Balance.FISHING_MAX_LENGTH:
		return
	if not word.is_valid_identifier() or "_" in word:
		return
	if not WordNet.word_exists(word) or _warm_word_pool.has(word):
		return
	_warm_word_pool.append(word)


func _show_hole_selection() -> void:
	_state = FishingState.CHOOSING_HOLE
	word_timer.stop()
	_set_fishing_visible(false)
	tutorial_panel.hide()
	hole_selection_panel.show()
	result_panel.hide()
	retry_button.hide()
	return_button.show()
	subtitle_label.show()

	var hole_buttons: Array[Button] = [
		hole_one_button, hole_two_button, hole_three_button,
	]
	var choice_made: bool = RunState.fishing_hole_chosen >= 0
	for hole_index: int in range(hole_buttons.size()):
		var button: Button = hole_buttons[hole_index]
		button.disabled = choice_made
		button.text = ""
		button.accessibility_name = "Fishing hole %d" % (hole_index + 1)
		button.tooltip_text = "Cast into fishing hole %d" % (hole_index + 1)
		button.queue_redraw()

	if choice_made:
		hole_status_label.text = "You already chose a fishing hole this run."
		result_label.text = "The fishing trip is complete."
		loot_label.text = "Only one of the three holes may be chosen."
		result_panel.show()
	else:
		hole_status_label.text = (
			"Choose a glowing ice hole to cast your line."
		)


func _select_hole(hole_index: int) -> void:
	if not RunState.choose_fishing_hole(hole_index):
		return
	_selected_hole = hole_index
	_fish = _roll_fish()
	_build_challenge_words(int(_fish["words"]))
	_current_word_index = 0
	_state = FishingState.FISHING
	hole_selection_panel.hide()
	tutorial_panel.hide()
	result_panel.hide()
	_set_fishing_visible(true)
	subtitle_label.hide()
	# The tutorial already explained the rules. Keep the live challenge focused
	# on only the counter, target word, countdown, and typing controls.
	fish_panel.hide()
	instruction_label.hide()
	timer_label.hide()
	feedback_label.hide()

	fish_name_label.text = "Hole %d  •  %s" % [
		_selected_hole + 1, str(_fish["name"])
	]
	rarity_label.text = "%s catch  •  Reward: Level %d letter item" % [
		str(_fish["rarity"]), int(_fish["item_level"])
	]
	rarity_label.add_theme_color_override("font_color", _fish["color"])
	instruction_label.text = "Complete %d warm-word prompt%s to land this fish." % [
		_challenge_words.size(), "" if _challenge_words.size() == 1 else "s",
	]
	feedback_label.text = "The fish is biting—type the word shown above."
	timer_bar.max_value = WORD_SECONDS
	word_input.editable = true
	word_input.clear()
	submit_button.disabled = false
	_update_challenge_display()
	word_timer.start(WORD_SECONDS)
	call_deferred("_focus_word_input")


func _build_challenge_words(word_count: int) -> void:
	var choices: Array[String] = _warm_word_pool.duplicate()
	choices.shuffle()
	_challenge_words.clear()
	for word: String in choices:
		_challenge_words.append(word)
		if _challenge_words.size() >= word_count:
			break

	if _challenge_words.size() < word_count:
		push_error("Ice fishing needs more WordNet warm words.")
		while _challenge_words.size() < word_count:
			_challenge_words.append("warm")


func _roll_fish() -> Dictionary:
	var total_weight: int = 0
	for fish: Dictionary in FISH_TABLE:
		total_weight += int(fish["weight"])

	var roll: int = randi_range(1, total_weight)
	for fish: Dictionary in FISH_TABLE:
		roll -= int(fish["weight"])
		if roll <= 0:
			return fish
	return FISH_TABLE[0]


func _submit_word() -> void:
	if _state != FishingState.FISHING:
		return

	var typed_word: String = word_input.text.strip_edges().to_lower()
	var target_word: String = _challenge_words[_current_word_index]
	word_input.clear()
	call_deferred("_focus_word_input")

	if typed_word != target_word:
		feedback_label.show()
		feedback_label.text = (
			"Not quite. Enter %s exactly—the timer is still running." %
			target_word.to_upper()
		)
		return

	_current_word_index += 1
	if _current_word_index >= _challenge_words.size():
		_resolve_catch(true)
		return

	feedback_label.hide()
	_update_challenge_display()


func _update_challenge_display() -> void:
	progress_label.text = "WORD %d / %d" % [
		_current_word_index + 1, _challenge_words.size()
	]
	var current_word: String = _challenge_words[_current_word_index]
	target_word_label.text = current_word.to_upper()


func _on_text_submitted(_text: String) -> void:
	_submit_word()


func _on_word_timer_timeout() -> void:
	_resolve_catch(false)


func _resolve_catch(caught: bool) -> void:
	if _state != FishingState.FISHING:
		return
	_state = FishingState.RESOLVED
	subtitle_label.show()
	word_timer.stop()
	timer_bar.value = 0.0
	word_input.editable = false
	submit_button.disabled = true
	_set_fishing_visible(false)
	result_panel.show()

	if caught:
		var reward: LetterStats = RunState.rolled_letter_drop_at_level(
			int(_fish["item_level"])
		)
		RunState.add_letter_item(reward)
		result_label.text = "Caught: %s!" % str(_fish["name"])
		loot_label.text = "%s reward: %s" % [
			str(_fish["rarity"]), reward.describe()
		]
		feedback_label.text = (
			"The letter item was added to your forge inventory."
		)
	else:
		result_label.text = "%s escaped!" % str(_fish["name"])
		loot_label.text = "Hole %d is spent. No item reward." % (
			_selected_hole + 1
		)
		feedback_label.text = "The line froze before the sequence was complete."

	retry_button.hide()


func _set_fishing_visible(visible_state: bool) -> void:
	var fishing_controls: Array[Control] = [
		fish_panel,
		instruction_label,
		progress_label,
		target_panel,
		timer_label,
		timer_bar,
		input_row,
		feedback_label,
	]
	for control: Control in fishing_controls:
		control.visible = visible_state


func _return_from_fishing() -> void:
	if RunState.pending_route_activity == "ice_fishing":
		if RunState.fishing_hole_chosen >= 0:
			RunState.finish_route_activity()
		else:
			RunState.pending_route_activity = ""
			RunState.pending_route_key = ""
		get_tree().change_scene_to_file(ScenePaths.ENCOUNTER_SELECT)
		return
	get_tree().change_scene_to_file(ScenePaths.TAVERN)
