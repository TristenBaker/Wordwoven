class_name TypingChallenge
extends Control
## A timed typing prompt. The caller supplies the prompt text and a
## validator; invalid answers may be corrected until the countdown
## ends. Success, timeout, and leaving each report one result.

signal finished(success: bool)

const DEFAULT_DURATION_MSEC: int = 15000

var clock: GameClock = GameClock.new()

var _validator: Callable = Callable()
var _started_msec: int = -1
var _duration_msec: int = DEFAULT_DURATION_MSEC

@onready var prompt_label: Label = $Panel/Margin/Box/PromptLabel
@onready var countdown_bar: ProgressBar = $Panel/Margin/Box/CountdownBar
@onready var answer_input: LineEdit = \
		$Panel/Margin/Box/AnswerRow/AnswerInput
@onready var submit_button: Button = \
		$Panel/Margin/Box/AnswerRow/SubmitButton
@onready var feedback_label: Label = $Panel/Margin/Box/FeedbackLabel
@onready var leave_button: Button = $Panel/Margin/Box/LeaveButton


func _ready() -> void:
	hide()
	set_process(false)
	submit_button.pressed.connect(_on_submit_pressed)
	answer_input.text_submitted.connect(_on_text_submitted)
	leave_button.pressed.connect(cancel)


func _process(_delta: float) -> void:
	tick()


func is_active() -> bool:
	return _started_msec >= 0


## Starts the countdown. validator takes the typed word and returns
## {"valid": bool, "reason": String}.
func open(
	prompt_text: String,
	validator: Callable,
	duration_msec: int = DEFAULT_DURATION_MSEC
) -> void:
	_validator = validator
	_duration_msec = duration_msec
	_started_msec = clock.now_msec()
	prompt_label.text = prompt_text
	feedback_label.text = ""
	answer_input.clear()
	countdown_bar.max_value = float(duration_msec)
	countdown_bar.value = float(duration_msec)
	show()
	set_process(true)
	answer_input.grab_focus()


func remaining_msec() -> int:
	if not is_active():
		return 0
	var elapsed: int = clock.now_msec() - _started_msec
	return maxi(_duration_msec - elapsed, 0)


## Ends the challenge as a failure once the countdown has run out.
func tick() -> void:
	if not is_active():
		return
	var elapsed: int = clock.now_msec() - _started_msec
	countdown_bar.value = float(remaining_msec())
	if elapsed > _duration_msec:
		_finish(false)


## Checks an answer; returns true when it wins the challenge.
func submit(text: String) -> bool:
	tick()
	if not is_active():
		return false
	var verdict: Dictionary = _validator.call(text)
	if verdict.get("valid", false):
		_finish(true)
		return true
	feedback_label.text = String(verdict.get("reason", "Try again."))
	answer_input.clear()
	answer_input.grab_focus()
	return false


## Leaves the challenge; this counts as a failed attempt.
func cancel() -> void:
	if is_active():
		_finish(false)


func _on_submit_pressed() -> void:
	submit(answer_input.text)


func _on_text_submitted(text: String) -> void:
	submit(text)


func _finish(success: bool) -> void:
	_started_msec = -1
	_validator = Callable()
	set_process(false)
	hide()
	finished.emit(success)
