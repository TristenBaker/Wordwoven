class_name AbilityContext
extends RefCounted
## What an encounter ability may act on: the combat's letter
## conditions, its hand and piles, and the name shown in log lines.

var conditions: EncounterConditions = null
var deck: DeckManager = null
var source_name: String = ""


func _init(
	new_conditions: EncounterConditions,
	new_deck: DeckManager,
	new_source_name: String = ""
) -> void:
	conditions = new_conditions
	deck = new_deck
	source_name = new_source_name
