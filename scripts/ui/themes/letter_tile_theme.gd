class_name LetterTileTheme
extends Resource
## Presentation-only rules for combat letter tiles. New tile looks can
## provide another resource without changing the deck or combat systems.

@export_group("Class fills")
@export var healer_fill := Color("397a55")
@export var warrior_fill := Color("9c3c38")
@export var rogue_fill := Color("b58a29")

@export_group("Rank borders")
@export var bronze_border := Color("a9673f")
@export var silver_border := Color("b9c2c9")
@export var gold_border := Color("e5bf4d")
@export var platinum_border := Color("71c8cd")
@export var diamond_border := Color("aa7eea")

@export_group("Shared")
@export var letter_color := Color("fff7df")
@export var shadow_color := Color("160f0a")


func fill_for(letter_class: int) -> Color:
	match letter_class:
		LetterStats.LetterClass.WARRIOR:
			return warrior_fill
		LetterStats.LetterClass.ROGUE:
			return rogue_fill
		_:
			return healer_fill


func border_for(level: int) -> Color:
	if level <= 1:
		return bronze_border
	if level == 2:
		return silver_border
	if level == 3:
		return gold_border
	if level == 4:
		return platinum_border
	return diamond_border
