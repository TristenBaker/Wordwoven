class_name EncounterAbility
extends RefCounted
## Base behavior for an enemy or environment ability. A handler
## overrides only the hooks it uses; each hook receives the entry's
## data parameters and returns log lines describing what happened.


## Runs after an enemy attack that the player survived.
func after_enemy_attack(
	_context: AbilityContext, _params: Dictionary
) -> Array[String]:
	return []


## Runs as each player turn opens, before input becomes available.
func on_player_turn_start(
	_context: AbilityContext, _params: Dictionary
) -> Array[String]:
	return []


## Player-facing summary used in encounter previews and tooltips.
func describe(_params: Dictionary) -> String:
	return ""


## Reads the entry's "count" parameter, defaulting to one.
func count_param(params: Dictionary) -> int:
	return maxi(int(params.get("count", 1)), 0)
