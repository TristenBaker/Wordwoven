class_name LetterTile
extends PanelContainer
## One letter card in the combat hand. Shows the letter art, its
## power, and its level; brightens when the typed word would use it.

# Tint states for the tile while the player types.
const COLOR_IDLE: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_USED: Color = Color(1.0, 0.95, 0.5, 1.0)
const COLOR_DIMMED: Color = Color(0.55, 0.55, 0.55, 1.0)

# Letter art tiles are looked up by name; there is one per letter,
# so a UID table would just restate the alphabet.
const LETTER_ART_PATH: String = \
		"res://assets/Art/LetterArt/Letter_%s.png"

var stats: LetterStats = null

@onready var art: TextureRect = $Layout/Art
@onready var power_label: Label = $Layout/PowerLabel


func setup(new_stats: LetterStats) -> void:
	stats = new_stats
	var art_path: String = LETTER_ART_PATH % \
			stats.letter.to_upper()
	if ResourceLoader.exists(art_path):
		art.texture = load(art_path)
	power_label.text = "%s  Lv%d\n%s" % [
		str(int(stats.power())), stats.level, stats.class_name_text(),
	]
	tooltip_text = "%s\n%s" % [stats.describe(), stats.effect_text()]


## Brightens or dims the tile while a word is being typed.
func set_used(used: bool, typing: bool) -> void:
	if not typing:
		modulate = COLOR_IDLE
	elif used:
		modulate = COLOR_USED
	else:
		modulate = COLOR_DIMMED
