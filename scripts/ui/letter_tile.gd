class_name LetterTile
extends PanelContainer
## One letter tile in the combat hand. Its fill signals class and its
## border signals rank; detailed mechanics remain available by tooltip.

# Used letters fade from the hand while their visual copy travels to the board.
const COLOR_IDLE: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_USED: Color = Color(0.45, 0.45, 0.45, 0.35)

var stats: LetterStats = null

@export var tile_theme: LetterTileTheme = preload(
		"res://assets/Themes/letter_tiles/default_letter_tile_theme.tres"
)

@onready var letter_label: Label = $Layout/LetterLabel


func setup(new_stats: LetterStats) -> void:
	stats = new_stats
	letter_label.text = stats.letter.to_upper()
	letter_label.add_theme_color_override("font_color", tile_theme.letter_color)
	add_theme_stylebox_override("panel", _tile_style())
	tooltip_text = "%s\n%s" % [stats.describe(), stats.effect_text()]


## Brightens or dims the tile while a word is being typed.
func set_used(used: bool, typing: bool) -> void:
	if not typing:
		modulate = COLOR_IDLE
	elif used:
		modulate = COLOR_USED
	else:
		modulate = COLOR_IDLE


func _tile_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tile_theme.fill_for(stats.letter_class)
	style.border_color = tile_theme.border_for(stats.level)
	style.set_border_width_all(6)
	style.set_corner_radius_all(10)
	style.shadow_color = tile_theme.shadow_color
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 3)
	return style
