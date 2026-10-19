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
	var run: Dictionary = RunScoring.snapshot(victory)
	var leaderboard := RunLeaderboard.new()
	var entries: Array[Dictionary]
	if not RunState.run_score_recorded:
		entries = leaderboard.record(run)
		RunState.run_score_recorded = true
	else:
		entries = leaderboard.entries()
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
	tally += "\nGold earned: %d" % RunState.gold_earned_this_run
	tally += "\n\n" + RunScoring.breakdown_text(run)
	tally += "\n\nLOCAL LEADERBOARD"
	for index: int in mini(5, entries.size()):
		var entry: Dictionary = entries[index]
		tally += "\n#%d  %d  · %s · %s" % [
			index + 1, int(entry.get("score", 0)),
			"Victory" if bool(entry.get("victory", false)) else "Defeat",
			entry.get("biome", "Unknown"),
		]
	return tally


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)
