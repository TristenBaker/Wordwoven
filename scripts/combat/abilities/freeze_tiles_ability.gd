class_name FreezeTilesAbility
extends EncounterAbility
## At the start of each player turn, thaws last turn's ice and then
## freezes random hand tiles, or every tile when fewer remain.


func on_player_turn_start(
	context: AbilityContext, params: Dictionary
) -> Array[String]:
	context.conditions.clear_frozen()
	var frozen: Array[LetterStats] = context.conditions.pick_several(
		context.deck.hand(), count_param(params)
	)
	var letters: Array[String] = []
	for stats: LetterStats in frozen:
		context.conditions.freeze(stats)
		letters.append(stats.letter.to_upper())
	if letters.is_empty():
		return []
	return ["Ice grips your %s tile(s)." % ", ".join(letters)]


func describe(params: Dictionary) -> String:
	return (
		"Each turn, %d random hand tiles freeze and give only 20%%"
		+ " base power."
	) % count_param(params)
