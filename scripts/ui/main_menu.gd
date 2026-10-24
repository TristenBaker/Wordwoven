extends Control
## Title screen. Waits for the WordNet database to finish loading,
## then lets the player start a run or quit.

@onready var start_button: Button = $CenterBox/Menu/StartButton
@onready var settings_button: Button = $CenterBox/Menu/SettingsButton
@onready var quit_button: Button = $CenterBox/Menu/QuitButton
@onready var status_label: Label = $CenterBox/Menu/StatusLabel
@onready var settings_screen: SettingsScreen = $SettingsScreen


func _ready() -> void:
	Telemetry.end_run("abandoned")
	PlayerStats.finalize_run()
	$CenterBox/Menu/AchievementsButton.pressed.connect(_show_achievements)
	$AchievementsMenu.closed.connect(_on_settings_closed)
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_screen.closed.connect(_on_settings_closed)
	if WordNet.is_ready:
		_on_loading_finished(true)
	else:
		status_label.text = "Consulting the lexicon..."
		WordNet.loading_finished.connect(_on_loading_finished)


func _on_loading_finished(success: bool) -> void:
	if success:
		start_button.disabled = false
		status_label.text = ""
	else:
		status_label.text = "Lexicon failed to load. See logs."


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(ScenePaths.BIOME_SELECT)


func _on_settings_pressed() -> void:
	$CenterBox.hide()
	settings_screen.open()


func _on_settings_closed() -> void:
	$CenterBox.show()
	start_button.call_deferred("grab_focus")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _show_achievements() -> void:
	$CenterBox.hide()
	$AchievementsMenu.open()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE and $AchievementsMenu.visible:
		$AchievementsMenu.close()
		get_viewport().set_input_as_handled()
