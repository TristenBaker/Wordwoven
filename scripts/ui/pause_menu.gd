class_name PauseMenu
extends CanvasLayer
## A reusable in-game pause overlay. It owns pause state so gameplay scenes
## only need to instance it, while the settings view can grow independently.

signal resumed

var _history: ProgressMenu = null
var _history_open: bool = false

@onready var menu_panel: PanelContainer = $Center/MenuPanel
@onready var settings_screen: SettingsScreen = $SettingsScreen
@onready var resume_button: Button = $Center/MenuPanel/Menu/ResumeButton
@onready var settings_button: Button = $Center/MenuPanel/Menu/SettingsButton
@onready var main_menu_button: Button = $Center/MenuPanel/Menu/MainMenuButton
@onready var quit_button: Button = $Center/MenuPanel/Menu/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Center/MenuPanel/Menu/AchievementsButton.pressed.connect(
		_show_achievements
	)
	$AchievementsMenu.closed.connect(_show_main_menu)
	resume_button.pressed.connect(_resume)
	settings_button.pressed.connect(_show_settings)
	main_menu_button.pressed.connect(_return_to_main_menu)
	quit_button.pressed.connect(_quit_to_desktop)
	settings_screen.closed.connect(_show_main_menu)
	hide()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		if visible and _history_open:
			_history.close()
		elif visible and $AchievementsMenu.visible:
			$AchievementsMenu.close()
		elif visible and settings_screen.visible:
			settings_screen.close()
		elif visible:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()


func _pause() -> void:
	get_tree().paused = true
	show()
	_show_main_menu()


func _resume() -> void:
	get_tree().paused = false
	_history_open = false
	if _history != null:
		_history.hide()
	hide()
	resumed.emit()


func _show_settings() -> void:
	menu_panel.hide()
	settings_screen.open()


func _show_main_menu() -> void:
	$AchievementsMenu.hide()
	settings_screen.hide()
	menu_panel.show()
	resume_button.call_deferred("grab_focus")


func _return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)


func _quit_to_desktop() -> void:
	get_tree().quit()


func _exit_tree() -> void:
	# Scene changes must never leave the next scene paused.
	get_tree().paused = false


func _show_achievements() -> void:
	menu_panel.hide()
	$AchievementsMenu.open()


func open_history(history: ProgressMenu) -> void:
	if visible or get_tree().paused:
		return
	_history = history
	_history_open = true
	get_tree().paused = true
	show()
	menu_panel.hide()
	settings_screen.hide()
	$AchievementsMenu.hide()
	if not history.closed.is_connected(_resume):
		history.closed.connect(_resume)
	history.open()
