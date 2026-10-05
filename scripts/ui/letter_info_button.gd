class_name LetterInfoButton
extends Button
## A normal button with the rich, element-aware tooltip used by letter tiles.

var letter_stats: LetterStats = null


func _ready() -> void:
	theme = LetterTooltip.transparent_shell_theme()


func set_letter_stats(stats: LetterStats) -> void:
	letter_stats = stats
	tooltip_text = stats.information_tooltip()


func _make_custom_tooltip(_for_text: String) -> Object:
	if letter_stats == null:
		return null
	return LetterTooltip.create_for(letter_stats)
