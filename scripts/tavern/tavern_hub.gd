extends Control
## The atmospheric tavern hub. The existing management screen remains the
## Tavern Page, opened from here by the room interaction or the B shortcut.

const TAVERN_PAGE: String = "res://scenes/tavern/tavern.tscn"

@onready var tavern_page_button: Button = $TavernPageButton
@onready var leave_button: Button = $LeaveButton
@onready var left_arrow: Button = $GoLeftButton
@onready var right_arrow: Button = $RightArrow
@onready var forge_button: Button = $ForgeButton
@onready var leaderboard_button: Button = $LeaderboardButton
@onready var minigames_button: Button = $MinigamesButton
@onready var minigames_popup: Control = $MinigamesPopup
@onready var word_game_button: Button = $MinigamesPopup/Center/Panel/Menu/WordGameButton
@onready var handwriting_button: Button = $MinigamesPopup/Center/Panel/Menu/HandwritingButton
@onready var minigames_close_button: Button = $MinigamesPopup/Center/Panel/Menu/CloseButton
@onready var ice_fishing_button := get_node_or_null("DebugIceFishingButton") as Button
@onready var health_label: Label = $StatusPanel/HealthLabel
@onready var gold_label: Label = $StatusPanel/GoldLabel


func _ready() -> void:
	tavern_page_button.pressed.connect(_open_tavern_page)
	leave_button.pressed.connect(_leave_tavern)
	left_arrow.pressed.connect(_open_left_room)
	right_arrow.pressed.connect(_open_right_room)
	forge_button.pressed.connect(_open_forge)
	leaderboard_button.pressed.connect(_open_leaderboard)
	minigames_button.pressed.connect(_open_minigames)
	word_game_button.pressed.connect(_open_word_game)
	handwriting_button.pressed.connect(_open_handwriting_game)
	minigames_close_button.pressed.connect(minigames_popup.hide)
	minigames_popup.hide()
	if ice_fishing_button != null:
		ice_fishing_button.visible = OS.is_debug_build()
		ice_fishing_button.pressed.connect(_open_ice_fishing)
	EventBus.gold_changed.connect(_on_gold_changed)
	_refresh_status()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_B:
		get_viewport().set_input_as_handled()
		_open_tavern_page()


func _open_tavern_page() -> void:
	get_tree().change_scene_to_file(TAVERN_PAGE)


func _leave_tavern() -> void:
	get_tree().change_scene_to_file(
		ScenePaths.COMBAT if RunState.is_endless() else ScenePaths.ENCOUNTER_SELECT
	)


func _open_left_room() -> void:
	get_tree().change_scene_to_file(ScenePaths.TAVERN_LEFT)


func _open_right_room() -> void:
	get_tree().change_scene_to_file(ScenePaths.TAVERN_RIGHT)


func _open_forge() -> void:
	get_tree().change_scene_to_file(ScenePaths.FORGE)


func _open_leaderboard() -> void:
	LeaderboardOverlay.open_in(self)


func _open_word_game() -> void:
	get_tree().change_scene_to_file(ScenePaths.WORD_GAME)


func _open_minigames() -> void:
	minigames_popup.show()


func _open_handwriting_game() -> void:
	get_tree().change_scene_to_file(ScenePaths.HANDWRITING_GAME)


func _open_ice_fishing() -> void:
	get_tree().change_scene_to_file(ScenePaths.ICE_FISHING)
func _on_gold_changed(_new_total: int) -> void:
	_refresh_status()


func _refresh_status() -> void:
	health_label.text = "Health  %d / %d" % [
		RunState.player_health, RunState.player_max_health
	]
	gold_label.text = "Gold  %d" % RunState.gold
