extends Control
## Title screen. Waits for the WordNet database to finish loading,
## then lets the player start a run or quit.

@onready var start_button: Button = $CenterBox/Menu/StartButton
@onready var settings_button: Button = $CenterBox/Menu/SettingsButton
@onready var leaderboard_button: Button = $CenterBox/Menu/LeaderboardButton
@onready var permanent_upgrades_button: Button = $CenterBox/Menu/PermanentUpgradesButton
@onready var cosmetics_button: Button = $CenterBox/Menu/CosmeticsButton
@onready var quit_button: Button = $CenterBox/Menu/QuitButton
@onready var status_label: Label = $CenterBox/Menu/StatusLabel
@onready var settings_screen: SettingsScreen = $SettingsScreen


func _ready() -> void:
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	permanent_upgrades_button.pressed.connect(_on_permanent_upgrades_pressed)
	cosmetics_button.pressed.connect(_on_cosmetics_pressed)
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
	get_tree().change_scene_to_file(ScenePaths.MODE_SELECT)


func _on_settings_pressed() -> void:
	$CenterBox.hide()
	settings_screen.open()


func _on_settings_closed() -> void:
	$CenterBox.show()


func _on_leaderboard_pressed() -> void:
	LeaderboardOverlay.open_in(self)


func _on_permanent_upgrades_pressed() -> void:
	PermanentUpgradesOverlay.open_in(self)


func _on_cosmetics_pressed() -> void:
	CosmeticsOverlay.open_in(self)


func _on_quit_pressed() -> void:
	get_tree().quit()
