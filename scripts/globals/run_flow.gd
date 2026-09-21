class_name RunFlow
extends RefCounted
## The order of screens in a run. Each of the six combat stages
## follows: noncombat event -> noncombat event -> combat setup ->
## combat -> rewards -> tavern. The first pair follows run setup and
## the dragon has its own pair; its victory ends the run.


## Where to go once a new run is set up.
static func after_run_start() -> String:
	return before_combat()


## The next event of the current stage, or combat setup when both of
## its events are finished.
static func before_combat() -> String:
	if EventProgress.has_pending(RunState.encounter_index):
		return ScenePaths.EVENT
	return ScenePaths.ENCOUNTER_SELECT


static func after_tavern() -> String:
	return before_combat()


static func after_event() -> String:
	return before_combat()


## After the loot screen: the ending for the dragon, else the tavern.
static func after_rewards(defeated_boss: bool) -> String:
	if defeated_boss:
		return ScenePaths.RUN_WON
	return ScenePaths.TAVERN
