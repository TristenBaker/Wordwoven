extends Control
## End-of-run screen for both victory and defeat. Shows a short
## tally of the run and returns to the main menu.

const BODY := preload("res://assets/Fonts/Junicode.ttf")
const BUTTON_THEME := preload("res://assets/Themes/WordWoven_Button_Theme.tres")

@export var victory: bool = false

@onready var title_label: Label = $CenterBox/Menu/TitleLabel
@onready var tally_label: Label = $CenterBox/Menu/TallyLabel
@onready var menu_button: Button = $CenterBox/Menu/MenuButton

var _run: Dictionary = {}
var _leaderboard_entries: Array[Dictionary] = []
var _score_popup: PanelContainer


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
	_record_run_once()
	tally_label.text = _build_tally()
	_add_score_button()


func _record_run_once() -> void:
	_run = RunScoring.snapshot(victory)
	var leaderboard := RunLeaderboard.new()
	if not RunState.run_score_recorded:
		_leaderboard_entries = leaderboard.record(_run)
		RunState.run_score_recorded = true
	else:
		_leaderboard_entries = leaderboard.entries()


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
	tally += "\nGold earned: %d" % RunState.gold_earned_this_run
	if RunState.has_key_item("ember_word"):
		tally += "\nKey item recovered: THE EMBER WORD"
	return tally


func _add_score_button() -> void:
	var button := Button.new()
	button.theme = BUTTON_THEME
	button.theme_type_variation = &"WordWovenActionButton"
	button.text = "View Score & Leaderboard"
	button.custom_minimum_size = Vector2(300, 46)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_toggle_score_popup)
	var menu := menu_button.get_parent()
	menu.add_child(button)
	menu.move_child(button, menu_button.get_index())


func _toggle_score_popup() -> void:
	if _score_popup == null:
		_build_score_popup()
	else:
		_score_popup.visible = not _score_popup.visible


func _build_score_popup() -> void:
	_score_popup = PanelContainer.new()
	_score_popup.name = "ScoreLeaderboardPopup"
	_score_popup.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_score_popup.position = Vector2(-510, 96)
	_score_popup.size = Vector2(480, 480)
	_score_popup.add_theme_stylebox_override("panel", _popup_style())
	add_child(_score_popup)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	_score_popup.add_child(content)
	content.add_child(_label("SCORE & LEADERBOARD", 25, Color("ffe08a")))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(430, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var details := _label(_score_details(), 18, Color("f6ead4"))
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(details)
	var close := Button.new()
	close.theme = BUTTON_THEME
	close.theme_type_variation = &"WordWovenActionButton"
	close.text = "Close"
	close.custom_minimum_size = Vector2(140, 38)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): _score_popup.hide())
	content.add_child(close)


func _score_details() -> String:
	var text := RunScoring.breakdown_text(_run)
	text += "\n\nLOCAL %s LEADERBOARD" % String(_run.get("mode", "Story")).to_upper()
	for index: int in mini(5, _leaderboard_entries.size()):
		var entry: Dictionary = _leaderboard_entries[index]
		text += "\n#%d  %d  · %s · %s" % [
			index + 1, int(entry.get("score", 0)),
			"Victory" if bool(entry.get("victory", false)) else "Defeat",
			entry.get("biome", "Unknown"),
		]
	return text


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", BODY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _popup_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171226")
	style.border_color = Color("c79b50")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 12
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 16.0
	return style


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)
