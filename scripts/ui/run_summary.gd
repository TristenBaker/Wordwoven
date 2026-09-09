extends Control
## End-of-run screen for both victory and defeat. Shows a short
## tally of the run and returns to the main menu.

@export var victory: bool = false

@onready var title_label: Label = $CenterBox/Menu/TitleLabel
@onready var tally_label: Label = $CenterBox/Menu/TallyLabel
@onready var menu_button: Button = $CenterBox/Menu/MenuButton


func _ready() -> void:
	RunState.is_run_active = false
	menu_button.pressed.connect(_on_menu_pressed)
	if victory:
		title_label.text = "The Tale Is Told"
	else:
		title_label.text = "Your Tale Ends Here"
	tally_label.text = _build_tally()


func _build_tally() -> String:
	var words_played: int = RunState.word_history.size()
	var best_word: String = ""
	var best_damage: float = 0.0
	for entry: Dictionary in RunState.word_history:
		if entry["damage"] > best_damage:
			best_damage = entry["damage"]
			best_word = entry["word"]
	var tally: String = "Words spoken: %d" % words_played
	if not best_word.is_empty():
		tally += "\nMightiest word: %s (%.0f damage)" % [
			best_word.to_upper(), best_damage
		]
	tally += "\nGold amassed: %d" % RunState.gold
	return tally


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)
