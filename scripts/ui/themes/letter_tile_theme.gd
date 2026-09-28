class_name LetterTileTheme
extends Resource
## Presentation-only rules for combat letter tiles. New tile looks can
## provide another resource without changing the deck or combat systems.

@export_group("Element fills")
@export var fire_fill := Color("9c3c38")
@export var lightning_fill := Color("d0a72e")
@export var water_fill := Color("2f75a8")
@export var ice_fill := Color("73bdd4")
@export var nature_fill := Color("397a55")
@export var earth_fill := Color("7b5438")

@export_group("Rank borders")
@export var bronze_border := Color("a9673f")
@export var silver_border := Color("b9c2c9")
@export var gold_border := Color("e5bf4d")
@export var platinum_border := Color("71c8cd")
@export var diamond_border := Color("aa7eea")

@export_group("Shared")
@export var letter_color := Color("fff7df")
@export var shadow_color := Color("160f0a")


func fill_for(element: int) -> Color:
	match element:
		LetterStats.Element.LIGHTNING:
			return lightning_fill
		LetterStats.Element.WATER:
			return water_fill
		LetterStats.Element.ICE:
			return ice_fill
		LetterStats.Element.NATURE:
			return nature_fill
		LetterStats.Element.EARTH:
			return earth_fill
		_:
			return fire_fill


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
