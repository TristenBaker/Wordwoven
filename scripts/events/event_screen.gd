extends Control
## Shows the current stage's pending noncombat event. Everything on
## screen is rebuilt from the event's retained state, so leaving and
## returning cannot reroll the event or repeat its rewards. Continue
## unlocks once the event is resolved or declined, then advances the
## slot and moves to the next event or to combat setup.

# Receives the next scene path; tests capture it instead of leaving.
var navigate: Callable = Callable()

var _state: Dictionary = {}
var _event: NoncombatEvent = null
var _leaving: bool = false

@onready var eyebrow_label: Label = $CenterBox/EventPanel/Content/Eyebrow
@onready var title_label: Label = $CenterBox/EventPanel/Content/Title
@onready var body_label: RichTextLabel = \
		$CenterBox/EventPanel/Content/Body
@onready var picker_grid: GridContainer = \
		$CenterBox/EventPanel/Content/PickerGrid
@onready var prompt_label: Label = \
		$CenterBox/EventPanel/Content/PromptLabel
@onready var answer_row: HBoxContainer = \
		$CenterBox/EventPanel/Content/AnswerRow
@onready var answer_input: LineEdit = \
		$CenterBox/EventPanel/Content/AnswerRow/AnswerInput
@onready var submit_button: Button = \
		$CenterBox/EventPanel/Content/AnswerRow/SubmitButton
@onready var feedback_label: Label = \
		$CenterBox/EventPanel/Content/FeedbackLabel
@onready var actions_row: HBoxContainer = \
		$CenterBox/EventPanel/Content/ActionsRow
@onready var continue_button: Button = \
		$CenterBox/EventPanel/Content/ContinueButton
@onready var confirmer: ActionConfirmer = $ActionConfirmer


func _ready() -> void:
	if not RunState.is_run_active:
		RunState.start_new_run()
	submit_button.pressed.connect(_on_submit_pressed)
	answer_input.text_submitted.connect(submit_answer)
	continue_button.pressed.connect(continue_on)
	_state = EventProgress.current_event()
	if _state.is_empty():
		_go(RunFlow.after_event())
		return
	_event = EventCatalog.handler(String(_state["type"]))
	title_label.text = _event.display_name()
	eyebrow_label.text = "STAGE %d · EVENT %d OF %d" % [
		RunState.encounter_index, EventProgress.current_slot_number(),
		EventProgress.EVENTS_PER_STAGE,
	]
	if RunState.is_boss_next():
		eyebrow_label.text += " · BEFORE THE DRAGON"
	refresh()


## The retained state of the event on screen.
func event_state() -> Dictionary:
	return _state


func event_view() -> Dictionary:
	return _event.view(_state)


## Rebuilds text, picker, prompt, and actions from the event state.
func refresh() -> void:
	var view: Dictionary = _event.view(_state)
	var resolved: bool = _event.is_resolved(_state)
	body_label.text = String(view.get("body", ""))
	var prompt: String = String(view.get("prompt", ""))
	prompt_label.text = prompt
	prompt_label.visible = not prompt.is_empty() and not resolved
	answer_row.visible = prompt_label.visible
	_rebuild_picker(view.get("picker", []), resolved)
	_rebuild_actions(view.get("actions", []), resolved)
	continue_button.disabled = not resolved
	continue_button.text = "Continue" if resolved \
			else "Resolve or decline to continue"
	if prompt_label.visible:
		answer_input.grab_focus()


## Submits a typed answer to the event's word challenge.
func submit_answer(text: String) -> Dictionary:
	if _event == null or _event.is_resolved(_state) or _leaving:
		return {"valid": false, "reason": ""}
	var verdict: Dictionary = _event.submit_word(_state, text)
	feedback_label.text = "Well written." if verdict["valid"] \
			else String(verdict["reason"])
	answer_input.clear()
	refresh()
	return verdict


## Runs an action by id, asking first when the action has a confirm.
func choose_action(action_id: String) -> void:
	if _event == null or _leaving or confirmer.is_pending():
		return
	for entry: Dictionary in _event.view(_state).get("actions", []):
		if String(entry["id"]) != action_id or not bool(entry["enabled"]):
			continue
		var confirm: String = String(entry.get("confirm", ""))
		if confirm.is_empty():
			_apply(action_id, "")
		else:
			confirmer.request(
				String(entry["label"]), confirm,
				_apply.bind(action_id, "")
			)
		return


## Chooses one picker option by id.
func choose_pick(option_id: String) -> void:
	if _event == null or _leaving or confirmer.is_pending():
		return
	_apply("pick", option_id)


## Advances past a resolved event exactly once.
func continue_on() -> void:
	if _leaving or _event == null or not _event.is_resolved(_state):
		return
	_leaving = true
	EventProgress.advance()
	_go(RunFlow.after_event())


func _on_submit_pressed() -> void:
	submit_answer(answer_input.text)


func _apply(action_id: String, value: String) -> void:
	if _event.is_resolved(_state) and action_id != "leave":
		return
	var message: String = _event.act(_state, action_id, value)
	if not message.is_empty():
		feedback_label.text = message
	refresh()


func _rebuild_picker(options: Array, resolved: bool) -> void:
	for child: Node in picker_grid.get_children():
		picker_grid.remove_child(child)
		child.queue_free()
	picker_grid.visible = not options.is_empty() and not resolved
	if resolved:
		return
	for option: Variant in options:
		var entry: Dictionary = option
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(120, 44)
		button.text = String(entry["label"])
		button.tooltip_text = String(entry.get("tooltip", ""))
		button.pressed.connect(choose_pick.bind(String(entry["id"])))
		picker_grid.add_child(button)


func _rebuild_actions(actions: Array, resolved: bool) -> void:
	for child: Node in actions_row.get_children():
		actions_row.remove_child(child)
		child.queue_free()
	if resolved:
		return
	for action: Variant in actions:
		var entry: Dictionary = action
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(170, 44)
		button.text = String(entry["label"])
		button.disabled = not bool(entry["enabled"])
		button.tooltip_text = String(entry.get("tooltip", ""))
		button.pressed.connect(choose_action.bind(String(entry["id"])))
		actions_row.add_child(button)


func _go(scene_path: String) -> void:
	if navigate.is_valid():
		navigate.call(scene_path)
	else:
		get_tree().change_scene_to_file.call_deferred(scene_path)
