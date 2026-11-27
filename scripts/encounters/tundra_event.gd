extends Control

const TundraEventScript = preload("res://scripts/encounters/tundra_events.gd")
const SideQuestMusic = preload("res://scripts/encounters/tundra_side_quest_music.gd")
const TutorialFlow = preload("res://scripts/ui/tutorial_presenter.gd")
const Balance = preload("res://data/balance/tuning.gd")
const HUD_FRAME = preload("res://assets/Themes/Combat_HUD_Panel.tres")
const CHEST_ID := "treasure_chest"
const SUCCESS := Color("b1dcb5")
const ERROR := Color("efb1a9")
const MUTED := Color("b8c5d6")
const GOLD := Color("f5d58d")
## One reusable presentation for all optional Tundra encounters.
var encounter_id: String
var data: Dictionary
var _frames: Array[AtlasTexture] = []
var _elapsed: float = 0.0
var _finished: bool = false
var _choice: int = -1
var _meter_tween: Tween
var _chest_busy := false
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
	if encounter_id == CHEST_ID:
		_setup_chest_layout()
	else:
		_style_meter()
		feedback.item_rect_changed.connect(_sync_feedback_banner)
		next_button.pressed.connect(_next_round)
		input.text_changed.connect(func(_text: String): _refresh_preview())
	input.placeholder_text = "Enter a %s..." % WordNet.pos_name(TundraEventScript.requested_pos(encounter_id))
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
		if encounter_id == CHEST_ID:
			TundraEventScript.next_round(encounter_id)
			var state := TundraEventScript.progress(encounter_id)
			_refresh_chest(state)
			if int(state.turn) > 0:
				var previous := int(state.lock_index) - (1 if int(state.guesses) == 0 else 0)
				_show_chest_turn_feedback(state, previous)
		else:
			_refresh_game()
		input.grab_focus()
		call_deferred("_show_minigame_tutorial")


func _show_minigame_tutorial() -> void:
	var steps: Array[Dictionary] = []
	match encounter_id:
		"frozen_traveler":
			steps = [
				{
					"target": meter,
					"title": "Finish a frozen tale",
					"body": "Fill every blank to earn healing and gold. Every valid idea counts.",
				},
				{
					"target": input,
					"title": "Invent the missing words",
					"body": "Follow the requested word type. Verbs use their base form. Silly answers are welcome!",
				},
			]
		"treasure_chest":
			steps = [
				{
					"target": locks_row,
					"title": "Open three locks",
					"body": "Each lock gives a clue and allows two guesses.",
				},
				{
					"target": input,
					"title": "Answer with an adjective",
					"body": "Use a describing word that fits the active clue. Synonyms can work.",
				},
			]
	if not steps.is_empty():
		var on_finished := input.grab_focus if encounter_id == CHEST_ID else Callable()
		TutorialFlow.show(self, encounter_id, steps, on_finished)

func _process(delta: float) -> void:
	if _frames.size() <= 1:
		return
	_elapsed = fmod(_elapsed + delta, float(_frames.size()) / float(data.fps))
	sprite.texture = _frames[int(_elapsed * float(data.fps)) % _frames.size()]

func _submit() -> void:
	if _finished or _chest_busy:
		return
	if encounter_id == CHEST_ID:
		_submit_chest()
		return
	var verdict: Dictionary = TundraEventScript.submit_word(encounter_id, input.text, _choice)
	if not verdict.valid:
		feedback.text = "%s. Enter a valid %s." % [verdict.reason, WordNet.pos_name(TundraEventScript.requested_pos(encounter_id))]
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
	input.placeholder_text = "Enter a %s..." % WordNet.pos_name(TundraEventScript.requested_pos(encounter_id))
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
	next_button.text = "Next Blank" if encounter_id == "frozen_traveler" else "Next Round"
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
	fill.bg_color = Color("e8ae61") if encounter_id == "frozen_traveler" else Color("d9bc73")
	fill.set_corner_radius_all(3)
	meter.add_theme_stylebox_override("fill", fill)

func _setup_chest_layout() -> void:
	var margin: MarginContainer = $Margin
	margin.anchor_left = 0.5
	margin.anchor_right = 0.5
	margin.anchor_top = 0.06
	margin.anchor_bottom = 0.98
	margin.offset_left = -340
	margin.offset_right = 340
	$Margin/Content/Description.hide()
	# Preserve the original nine-slice artwork and give its contents a clear inset.
	for panel: PanelContainer in [game_panel, feedback_banner, result_panel]:
		var frame := panel.get_theme_stylebox("panel").duplicate() as StyleBoxTexture
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			frame.set_content_margin(side, 8.0 if panel == feedback_banner else 16.0)
		panel.add_theme_stylebox_override("panel", frame)
	var lines: VBoxContainer = $Margin/Content/Game/Lines
	var input_row := input.get_parent() as HBoxContainer
	input_row.reparent(lines, false)
	feedback_banner.reparent(lines, false)
	for child: Control in [heading, instruction, input_row, preview, feedback_banner, locks_row, meter_label]:
		lines.move_child(child, -1)
	lines.add_theme_constant_override("separation", 7)
	meter.hide()
	choice_row.hide()
	sprite.custom_minimum_size.y = 275
	sprite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sprite.resized.connect(_scale_chest_sprite)
	call_deferred("_scale_chest_sprite")
	heading.add_theme_font_size_override("font_size", 36)
	instruction.custom_minimum_size.y = 54
	instruction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview.custom_minimum_size.y = 22
	preview.add_theme_font_size_override("font_size", 16)
	meter_label.add_theme_font_size_override("font_size", 16)
	meter_label.add_theme_color_override("font_color", MUTED)
	feedback.custom_minimum_size.y = 30
	feedback.add_theme_font_size_override("font_size", 18)
	$Margin/Content/Result/Lines.add_theme_constant_override("separation", 14)
	dialogue.add_theme_constant_override("line_spacing", 4)
	reward.add_theme_constant_override("line_spacing", 4)
	feedback_banner.self_modulate.a = 0.0
	input.caret_blink = true
	input.keep_editing_on_text_submit = true
	submit.text = "Unlock"
	skip.custom_minimum_size.x = 70
	skip.tooltip_text = "Leave the chest. Skipping forfeits all gold and any bonus reward."
	preview.mouse_filter = Control.MOUSE_FILTER_PASS
	preview.tooltip_text = "Only valid words use a guess. Synonyms can work."
	meter_label.mouse_filter = Control.MOUSE_FILTER_PASS
	meter_label.tooltip_text = "Each opened lock earns %d gold, paid when you finish. Open all three for a chance at a bonus letter." % Balance.CHEST_GOLD_PER_LOCK


func _scale_chest_sprite() -> void:
	if encounter_id != CHEST_ID:
		return
	await get_tree().process_frame
	if is_instance_valid(sprite):
		sprite.pivot_offset = sprite.size * 0.5
		sprite.scale = Vector2(1.5, 1.5)


func _input(event: InputEvent) -> void:
	if encounter_id == CHEST_ID and is_instance_valid(input) and input.has_focus() \
			and event.is_echo() and event.is_action("ui_accept"):
		get_viewport().set_input_as_handled()


func _submit_chest() -> void:
	var state := TundraEventScript.progress(encounter_id)
	# The previous attempt cleared the field. An extra Unlock click must not
	# replace its feedback or submit another guess for the new lock.
	if input.text.strip_edges().is_empty() and int(state.turn) > 0:
		input.grab_focus()
		return
	_chest_busy = true
	var previous := int(state.lock_index)
	var verdict := TundraEventScript.submit_word(encounter_id, input.text)
	if not verdict.valid:
		var reason := String(verdict.reason)
		var pos := WordNet.pos_name(TundraEventScript.requested_pos(encounter_id))
		if reason.begins_with("Use a "):
			reason = "This lock needs an %s." % pos
		else:
			reason = "%s. Try an %s." % [reason.trim_suffix("."), pos]
		_set_chest_feedback(reason, ERROR)
		input.select_all()
	else:
		input.clear()
		if not verdict.result.is_empty():
			_show_result(verdict.result)
		else:
			TundraEventScript.next_round(encounter_id)
			_refresh_chest(state)
			_show_chest_turn_feedback(state, previous)
	if not _finished:
		input.grab_focus()
	_release_chest_submit.call_deferred()


func _release_chest_submit() -> void:
	_chest_busy = false


func _refresh_chest(state: Dictionary) -> void:
	var pos := WordNet.pos_name(TundraEventScript.requested_pos(encounter_id))
	var article := "an" if pos.begins_with("a") else "a"
	heading.text = "Write %s %s" % [article, pos]
	input.placeholder_text = "Type your answer"
	var lock: Dictionary = state.locks[int(state.lock_index)]
	instruction.text = "Hint: %s" % lock.clue if int(state.guesses) == 0 else "New Hint: %s" % lock.hint
	var remaining := 2 - int(state.guesses)
	preview.text = "%d %s remaining" % [remaining, "guess" if remaining == 1 else "guesses"]
	_refresh_locks(state)


func _show_chest_turn_feedback(state: Dictionary, index: int) -> void:
	var lock_name: String = state.locks[index].name
	match String(state.statuses[index]):
		"open":
			var message: String = state.locks[index].get("success", "The %s lock clicks open." % lock_name)
			_set_chest_feedback("%s +%d gold." % [message, Balance.CHEST_GOLD_PER_LOCK], SUCCESS)
			var card := locks_row.get_child(index) as Control
			card.modulate = Color(1.12, 1.17, 1.06)
			create_tween().tween_property(card, "modulate", Color.WHITE, 0.35)
		"stuck":
			_set_chest_feedback("No guesses left. The %s lock stays shut." % lock_name, ERROR)
		_:
			_set_chest_feedback("That adjective doesn't fit. Try again.", ERROR)


func _set_chest_feedback(text: String, color: Color) -> void:
	feedback.text = text
	feedback.add_theme_color_override("font_color", color)
	feedback_banner.self_modulate.a = 1.0


func _refresh_locks(state: Dictionary, skipped: bool = false) -> void:
	locks_row.show()
	for child: Node in locks_row.get_children():
		locks_row.remove_child(child)
		child.queue_free()
	var total: int = state.locks.size()
	var opened: int = state.value
	var earned := 0 if skipped else opened * Balance.CHEST_GOLD_PER_LOCK
	meter_label.text = "%d / %d opened   •   %d gold earned" % [opened, total, earned]
	for index: int in total:
		var status: String = state.statuses[index]
		var name_text := "Sealed"
		var color := MUTED
		match status:
			"open":
				name_text = "Opened"
				color = SUCCESS
			"stuck":
				name_text = "Failed"
				color = ERROR
			_:
				if skipped:
					name_text = "Skipped"
				elif index == int(state.lock_index):
					name_text = "Current"
					color = GOLD
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style: StyleBoxFlat = HUD_FRAME.duplicate()
		style.bg_color = Color("101c2d") if name_text == "Current" else Color("101725")
		style.border_color = color.darkened(0.25 if name_text == "Current" else 0.55)
		card.add_theme_stylebox_override("panel", style)
		locks_row.add_child(card)
		var label := Label.new()
		label.text = "%d · %s" % [index + 1, name_text]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", heading.get_theme_font("font"))
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", color)
		card.add_child(label)


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
	if _finished or _chest_busy:
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
	next_button.hide()
	$Margin/Content/Description.hide()
	(input.get_parent() as Control).hide()
	dialogue.text = result.dialogue
	if encounter_id == CHEST_ID:
		heading.hide()
		instruction.hide()
		preview.hide()
		var state := TundraEventScript.progress(encounter_id)
		var skipped: bool = result.skipped
		_refresh_locks(state, skipped)
		meter_label.hide()
		if skipped:
			dialogue.text = "Chest skipped. The remaining locks stay sealed."
			dialogue.add_theme_color_override("font_color", ERROR)
	else:
		game_panel.hide()
	reward.text = result.reward
	result_panel.show()
	continue_button.show()
	continue_button.grab_focus()
	if encounter_id == CHEST_ID:
		call_deferred("_scale_chest_sprite")

## Collapse the whole frame, including padding, when its label has no message.
func _sync_feedback_banner() -> void:
	feedback_banner.visible = not _finished and not feedback.text.strip_edges().is_empty()

func _return_to_map() -> void:
	if RunState.optional_encounters.has(encounter_id) \
			and RunState.pending_route_activity == encounter_id:
		RunState.finish_route_activity()
	RunState.pending_optional_encounter = ""
	get_tree().change_scene_to_file(ScenePaths.ENCOUNTER_SELECT)
