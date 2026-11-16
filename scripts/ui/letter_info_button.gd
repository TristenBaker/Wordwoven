class_name LetterInfoButton
extends Button
## A normal button with the rich, element-aware tooltip used by letter tiles.

var letter_stats: LetterStats = null
var _inspect_button: Button


func _ready() -> void:
	theme = LetterTooltip.transparent_shell_theme()


func set_letter_stats(stats: LetterStats) -> void:
	letter_stats = stats
	tooltip_text = stats.information_tooltip()
	if _inspect_button == null:
		_inspect_button = LetterInspector.add_inspect_button(self)
		_inspect_button.pressed.connect(func() -> void: LetterInspector.open_for(letter_stats))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		LetterInspector.open_for(letter_stats)
		accept_event()


func _make_custom_tooltip(_for_text: String) -> Object:
	if letter_stats == null:
		return null
	return LetterTooltip.create_for(letter_stats)
