class_name PoisonTileAbility
extends EncounterAbility
## After each surviving attack, poisons random unpoisoned hand tiles.
## Poison follows the instance through drawing and discarding.


func after_enemy_attack(
	context: AbilityContext, params: Dictionary
) -> Array[String]:
	var lines: Array[String] = []
	for index: int in count_param(params):
		var candidates: Array[LetterStats] = []
		for stats: LetterStats in context.deck.hand():
			if not context.conditions.is_poisoned(stats):
				candidates.append(stats)
		var target: LetterStats = context.conditions.pick_random(
			candidates
		)
		if target == null:
			break
		context.conditions.poison(target)
		lines.append("The %s poisons your %s tile!" % [
			context.source_name, target.letter.to_upper(),
		])
	return lines


func describe(params: Dictionary) -> String:
	return (
		"Poisons %d hand tile(s) after each attack, halving their"
		+ " damage, healing, and gold."
	) % count_param(params)
