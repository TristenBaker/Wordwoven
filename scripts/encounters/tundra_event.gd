extends Control

const TundraEventScript = preload("res://scripts/encounters/tundra_events.gd")
const SideQuestMusic = preload("res://scripts/encounters/tundra_side_quest_music.gd")
## One reusable presentation for all optional Tundra encounters.
var encounter_id: String
var data: Dictionary
var _frames: Array[AtlasTexture] = []
var _elapsed: float = 0.0
var _finished: bool = false
var _choice: int = -1
var _meter_tween: Tween
@onready var game_panel: PanelContainer = $Margin/Content/Game
@onready var heading: Label = $Margin/Content/Game/Lines/Heading
@onready var meter_label: Label = $Margin/Content/Game/Lines/MeterLabel
@onready var meter: ProgressBar = $Margin/Content/Game/Lines/Meter
@onready var instruction: Label = $Margin/Content/Game/Lines/Instruction
@onready var preview: Label = $Margin/Content/Game/Lines/Preview
@onready var choice_row: HBoxContainer = $Margin/Content/Game/Lines/Choices
@onready var locks_row: HBoxContainer = $Margin/Content/Game/Lines/Locks
@onready var next_button: Button = $Margin/Content/NextRound
@onready var sprite: TextureRect = $Margin/Content/Sprite
@onready var input: LineEdit = $Margin/Content/InputRow/WordInput
@onready var submit: Button = $Margin/Content/InputRow/Submit
@onready var skip: Button = $Margin/Content/InputRow/Skip
@onready var result_panel: PanelContainer = $Margin/Content/Result
@onready var dialogue: Label = $Margin/Content/Result/Lines/Dialogue
@onready var reward: Label = $Margin/Content/Result/Lines/Reward
@onready var continue_button: Button = $Margin/Content/Continue
@onready var feedback_banner: PanelContainer = $Margin/Content/FeedbackBanner
@onready var feedback: Label = $Margin/Content/FeedbackBanner/Feedback

func _ready() -> void:
	encounter_id = RunState.pending_optional_encounter
	data = TundraEventScript.definition(encounter_id)
	if data.is_empty() or (not RunState.optional_encounter_available(encounter_id) and not RunState.optional_encounters.has(encounter_id)):
		_return_to_map.call_deferred()
		return
	SideQuestMusic.ensure_playing(get_tree())
	$Margin/Content/Title.text = data.name
	$Margin/Content/Description/Text.text = data.description
	skip.tooltip_text = "Leave without a reward. This encounter cannot be replayed this run."
	_style_meter()
	feedback.item_rect_changed.connect(_sync_feedback_banner)
	next_button.pressed.connect(_next_round)
	input.text_changed.connect(func(_text: String): _refresh_preview())
	input.placeholder_text = "Enter a %s..." % WordNet.pos_name(data.pos)
	var frame_count: int = int(data.frames) if data.get("animate", true) else 1
	for frame: int in frame_count:
		_frames.append(TundraEventScript.frame_texture(data, frame))
	sprite.texture = _frames[0]
	set_process(_frames.size() > 1)
	submit.pressed.connect(_submit)
	input.text_submitted.connect(func(_text: String): _submit())
	skip.pressed.connect(_skip)
	continue_button.pressed.connect(_return_to_map)
	if RunState.optional_encounters.has(encounter_id):
		_show_result(RunState.optional_encounters[encounter_id])
	else:
		_refresh_game()
		input.grab_focus()

func _process(delta: float) -> void:
	if _frames.size() <= 1:
		return
	_elapsed = fmod(_elapsed + delta, float(_frames.size()) / float(data.fps))
	sprite.texture = _frames[int(_elapsed * float(data.fps)) % _frames.size()]

func _submit() -> void:
	if _finished:
		return
	var verdict: Dictionary = TundraEventScript.submit_word(encounter_id, input.text, _choice)
	if not verdict.valid:
		feedback.text = "%s. Enter a valid %s." % [verdict.reason, WordNet.pos_name(String(data.pos))]
		feedback.modulate = Color.WHITE
		_sync_feedback_banner()
		input.grab_focus()
		return
	input.clear()
	if not verdict.result.is_empty():
		_show_result(verdict.result)
	else:
		_refresh_game()
		next_button.grab_focus()

func _refresh_game() -> void:
	var state: Dictionary = TundraEventScript.progress(encounter_id)
	var view: Dictionary = TundraEventScript.rules(encounter_id).presentation(state, input.text.strip_edges().to_lower())
	heading.text = view.heading
	meter_label.text = view.meter
	meter.max_value = view.maximum
	if _meter_tween != null and _meter_tween.is_valid():
		_meter_tween.kill()
	_meter_tween = create_tween()
	_meter_tween.tween_property(meter, "value", float(state.value), 0.3)
	instruction.text = view.instruction
	preview.text = view.preview
	feedback.text = state.feedback
	feedback.modulate = Color("f3dfb4")
	_sync_feedback_banner()
	submit.text = view.submit
	input.editable = not state.awaiting_next
	submit.disabled = state.awaiting_next
	next_button.visible = state.awaiting_next
	next_button.text = "Next Turn" if encounter_id == "frozen_traveler" else ("Try Again" if encounter_id == "treasure_chest" and int(state.guesses) > 0 else ("Next Lock" if encounter_id == "treasure_chest" else "Next Round"))
	_refresh_locks(state)
	choice_row.visible = not view.choices.is_empty()
	for child: Node in choice_row.get_children():
		choice_row.remove_child(child)
		child.queue_free()
	for index: int in view.choices.size():
		var button := Button.new()
		button.text = view.choices[index]
		button.theme = submit.theme
		button.theme_type_variation = submit.theme_type_variation
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 48
		button.toggle_mode = true
		button.button_pressed = _choice == index
		button.disabled = state.awaiting_next
		button.pressed.connect(_choose.bind(index))
		choice_row.add_child(button)

func _style_meter() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color("142431")
	background.border_color = Color("9c8353")
	background.set_border_width_all(1)
	background.set_corner_radius_all(3)
	meter.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("e8ae61") if encounter_id == "frozen_traveler" else (Color("78c9ec") if encounter_id == "icy_portal" else Color("d9bc73"))
	fill.set_corner_radius_all(3)
	meter.add_theme_stylebox_override("fill", fill)

func _refresh_locks(state: Dictionary) -> void:
	locks_row.visible = encounter_id == "treasure_chest"
	if not locks_row.visible:
		return
	for child: Node in locks_row.get_children():
		locks_row.remove_child(child)
		child.queue_free()
	for index: int in 3:
		var label := Label.new()
		label.text = "%s • %s" % [state.locks[index].name, String(state.statuses[index]).to_upper()]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_override("font", heading.get_theme_font("font"))
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color("9be2b0") if state.statuses[index] == "open" else (Color("aaa8b1") if state.statuses[index] == "stuck" else Color("c0dce5")))
		locks_row.add_child(label)

func _refresh_preview() -> void:
	if _finished:
		return
	var view: Dictionary = TundraEventScript.rules(encounter_id).presentation(TundraEventScript.progress(encounter_id), input.text.strip_edges().to_lower())
	preview.text = view.preview

func _choose(index: int) -> void:
	_choice = index
	for i: int in choice_row.get_child_count():
		choice_row.get_child(i).set_pressed_no_signal(i == index)
	input.grab_focus()

func _next_round() -> void:
	TundraEventScript.next_round(encounter_id)
	_choice = -1
	_refresh_game()
	input.grab_focus()

func _skip() -> void:
	if _finished:
		return
	var result: Dictionary = TundraEventScript.complete(encounter_id, true)
	if not result.is_empty():
		_show_result(result)

func _show_result(result: Dictionary) -> void:
	_finished = true
	input.editable = false
	submit.disabled = true
	skip.disabled = true
	feedback_banner.hide()
	game_panel.hide()
	next_button.hide()
	$Margin/Content/Description.hide()
	$Margin/Content/InputRow.hide()
	dialogue.text = result.dialogue
	reward.text = result.reward
	result_panel.show()
	continue_button.show()
	continue_button.grab_focus()

## Collapse the whole frame, including padding, when its label has no message.
func _sync_feedback_banner() -> void:
	feedback_banner.visible = not _finished and not feedback.text.strip_edges().is_empty()

func _return_to_map() -> void:
	RunState.pending_optional_encounter = ""
	get_tree().change_scene_to_file(ScenePaths.ENCOUNTER_SELECT)
