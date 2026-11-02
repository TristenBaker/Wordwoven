extends Control

signal finished

const DIM_COLOR := Color(0.02, 0.025, 0.03, 0.38)
const HIGHLIGHT_COLOR := Color(0.38, 0.94, 0.72, 1.0)
const HIGHLIGHT_PADDING := 9.0
const PANEL_WIDTH := 390.0

@onready var panel: PanelContainer = $LessonPanel
@onready var step_label: Label = $LessonPanel/Margin/Content/StepLabel
@onready var title_label: Label = $LessonPanel/Margin/Content/Title
@onready var body_label: Label = $LessonPanel/Margin/Content/Body
@onready var next_button: Button = $LessonPanel/Margin/Content/Actions/NextButton
@onready var skip_button: Button = $LessonPanel/Margin/Content/Actions/SkipButton

var _steps: Array = []
var _step_index: int = 0
var _focus_rect := Rect2()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	next_button.pressed.connect(_advance)
	skip_button.pressed.connect(_finish)


func begin(steps: Array) -> void:
	_steps = steps
	_step_index = 0
	visible = true
	_show_step()


func _process(_delta: float) -> void:
	_update_focus_rect()
	_position_panel()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	var enter_pressed := event.is_action("ui_accept")
	if event is InputEventKey:
		enter_pressed = enter_pressed or event.keycode in [KEY_ENTER, KEY_KP_ENTER]
	if enter_pressed:
		_advance()
		get_viewport().set_input_as_handled()
	elif event.is_action("ui_cancel"):
		_finish()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		# Keep typing from leaking into the minigame underneath the spotlight.
		get_viewport().set_input_as_handled()


func _show_step() -> void:
	if _steps.is_empty() or _step_index >= _steps.size():
		_finish()
		return
	var step: Dictionary = _steps[_step_index]
	step_label.text = "%d / %d" % [_step_index + 1, _steps.size()]
	title_label.text = String(step.get("title", ""))
	body_label.text = String(step.get("body", ""))
	next_button.text = (
		"Begin (Enter)"
		if _step_index == _steps.size() - 1
		else "Next (Enter)"
	)
	_update_focus_rect()
	_position_panel()
	next_button.grab_focus()
	queue_redraw()


func _advance() -> void:
	_step_index += 1
	_show_step()


func _finish() -> void:
	if not visible:
		return
	visible = false
	finished.emit()
	queue_free()


func _update_focus_rect() -> void:
	if _steps.is_empty() or _step_index >= _steps.size():
		return
	var target: Control = _steps[_step_index].get("target") as Control
	if target == null or not is_instance_valid(target):
		_focus_rect = Rect2(size * 0.5 - Vector2(120, 60), Vector2(240, 120))
		return
	var global_rect := target.get_global_rect()
	_focus_rect = Rect2(
		global_rect.position - global_position,
		global_rect.size
	).grow(HIGHLIGHT_PADDING)
	_focus_rect = _focus_rect.intersection(Rect2(Vector2.ZERO, size))


func _position_panel() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var minimum := panel.get_combined_minimum_size()
	var panel_size := Vector2(
		minf(PANEL_WIDTH, size.x - 48.0),
		minimum.y
	)
	panel.size = panel_size
	var x := clampf(
		_focus_rect.get_center().x - panel_size.x * 0.5,
		24.0,
		maxf(24.0, size.x - panel_size.x - 24.0)
	)
	var below_y := _focus_rect.end.y + 22.0
	var above_y := _focus_rect.position.y - panel_size.y - 22.0
	var y := below_y if below_y + panel_size.y <= size.y - 24.0 else above_y
	panel.position = Vector2(x, clampf(y, 24.0, maxf(24.0, size.y - panel_size.y - 24.0)))


func _draw() -> void:
	if _focus_rect.size.x <= 0.0 or _focus_rect.size.y <= 0.0:
		# Never fall back to an unexplained full-screen curtain if a target is
		# temporarily unavailable during a layout change.
		return
	# Four rectangles leave the active control unobscured while dimming and
	# blocking attention from every unrelated part of the battlefield.
	draw_rect(Rect2(0, 0, size.x, _focus_rect.position.y), DIM_COLOR)
	draw_rect(Rect2(0, _focus_rect.end.y, size.x, size.y - _focus_rect.end.y), DIM_COLOR)
	draw_rect(Rect2(0, _focus_rect.position.y, _focus_rect.position.x, _focus_rect.size.y), DIM_COLOR)
	draw_rect(Rect2(_focus_rect.end.x, _focus_rect.position.y, size.x - _focus_rect.end.x, _focus_rect.size.y), DIM_COLOR)
	draw_rect(_focus_rect, HIGHLIGHT_COLOR, false, 4.0)
