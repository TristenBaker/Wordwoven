extends Control
## The atmospheric tavern hub. The existing management screen remains the
## Tavern Page, opened from here by the room interaction or the B shortcut.

const TAVERN_PAGE: String = "res://scenes/tavern/tavern.tscn"

@onready var tavern_page_button: Button = $TavernPageButton
@onready var leave_button: Button = $LeaveButton
@onready var left_arrow: Button = $GoLeftButton
@onready var right_arrow: Button = $RightArrow
@onready var health_label: Label = $StatusPanel/HealthLabel
@onready var gold_label: Label = $StatusPanel/GoldLabel


func _ready() -> void:
	tavern_page_button.pressed.connect(_open_tavern_page)
	leave_button.pressed.connect(_leave_tavern)
	left_arrow.pressed.connect(_open_left_room)
	right_arrow.pressed.connect(_open_right_room)
	EventBus.gold_changed.connect(_on_gold_changed)
	_refresh_status()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_B:
		get_viewport().set_input_as_handled()
		_open_tavern_page()


func _open_tavern_page() -> void:
	get_tree().change_scene_to_file(TAVERN_PAGE)


func _leave_tavern() -> void:
	get_tree().change_scene_to_file(ScenePaths.ENCOUNTER_SELECT)


func _open_left_room() -> void:
	get_tree().change_scene_to_file(ScenePaths.TAVERN_LEFT)


func _open_right_room() -> void:
	get_tree().change_scene_to_file(ScenePaths.TAVERN_RIGHT)


func _on_gold_changed(_new_total: int) -> void:
	_refresh_status()


func _refresh_status() -> void:
	health_label.text = "Health  %d / %d" % [
		RunState.player_health, RunState.player_max_health
	]
	gold_label.text = "Gold  %d" % RunState.gold
