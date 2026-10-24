extends Control
## End-of-run screen for both victory and defeat. Shows a short
## tally of the run and returns to the main menu.

@export var victory: bool = false

@onready var title_label: Label = $CenterBox/Menu/TitleLabel
@onready var tally_label: Label = $CenterBox/Menu/TallyLabel
@onready var menu_button: Button = $CenterBox/Menu/MenuButton


func _ready() -> void:
	PlayerStats.finalize_run(victory)
	$CenterBox/Menu/PlayerStatistics/Scroll/Statistics.refresh()
	Telemetry.end_run("won" if victory else "lost")
	RunState.is_run_active = false
	menu_button.pressed.connect(_on_menu_pressed)
	if victory:
		title_label.text = "The Tale Is Told"
	else:
		title_label.text = "Your Tale Ends Here"
	tally_label.text = _build_tally()


func _build_tally() -> String:
	var tally: String = "Gold amassed: %d" % RunState.gold
	if RunState.has_key_item("ember_word"):
		tally += "\nKey item recovered: THE EMBER WORD"
	return tally


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)
