class_name StealTileAbility
extends EncounterAbility
## After each surviving attack, takes random hand tiles out of
## circulation until the thief is defeated. Owned letters are
## untouched; only this encounter's hand loses the instance.


func after_enemy_attack(
	context: AbilityContext, params: Dictionary
) -> Array[String]:
	var lines: Array[String] = []
	for index: int in count_param(params):
		var stolen: LetterStats = context.conditions.pick_random(
			context.deck.hand()
		)
		if stolen == null:
			break
		context.deck.remove_from_hand(stolen)
		context.conditions.steal(stolen)
		lines.append("The %s steals your %s tile!" % [
			context.source_name, stolen.letter.to_upper(),
		])
	return lines


func describe(params: Dictionary) -> String:
	return (
		"Steals %d hand tile(s) after each attack; they return when"
		+ " it is defeated."
	) % count_param(params)
