extends Control
## Title screen. Waits for the WordNet database to finish loading,
## then lets the player start a run or quit.

const FIRST_SCENE_PATH: String = "res://scenes/combat/combat.tscn"

@onready var start_button: Button = $CenterBox/Menu/StartButton
@onready var quit_button: Button = $CenterBox/Menu/QuitButton
@onready var status_label: Label = $CenterBox/Menu/StatusLabel


func _ready() -> void:
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
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
	RunState.start_new_run()
	get_tree().change_scene_to_file(FIRST_SCENE_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()
