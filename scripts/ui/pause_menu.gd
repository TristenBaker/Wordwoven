class_name PauseMenu
extends CanvasLayer
## A reusable in-game pause overlay. It owns pause state so gameplay scenes
## only need to instance it, while the settings view can grow independently.

signal resumed

@onready var menu_panel: PanelContainer = $Center/MenuPanel
@onready var settings_screen: SettingsScreen = $SettingsScreen
@onready var resume_button: Button = $Center/MenuPanel/Menu/ResumeButton
@onready var settings_button: Button = $Center/MenuPanel/Menu/SettingsButton
@onready var main_menu_button: Button = $Center/MenuPanel/Menu/MainMenuButton
@onready var quit_button: Button = $Center/MenuPanel/Menu/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(_resume)
	settings_button.pressed.connect(_show_settings)
	main_menu_button.pressed.connect(_return_to_main_menu)
	quit_button.pressed.connect(_quit_to_desktop)
	settings_screen.closed.connect(_show_main_menu)
	hide()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		if visible and settings_screen.visible:
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
	resume_button.call_deferred("grab_focus")


func _resume() -> void:
	get_tree().paused = false
	hide()
	resumed.emit()


func _show_settings() -> void:
	menu_panel.hide()
	settings_screen.open()


func _show_main_menu() -> void:
	settings_screen.hide()
	menu_panel.show()


func _return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)


func _quit_to_desktop() -> void:
	get_tree().quit()


func _exit_tree() -> void:
	# Scene changes must never leave the next scene paused.
	get_tree().paused = false
