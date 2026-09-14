class_name ScenePaths
extends RefCounted
## The single place scene file locations are written down, so flow
## changes never require hunting through scripts for path strings.

const MAIN_MENU: String = "res://scenes/main_menu.tscn"
const COMBAT: String = "res://scenes/combat/combat.tscn"
const TAVERN: String = "res://scenes/tavern/tavern_hub.tscn"
const TAVERN_LEFT: String = "res://scenes/tavern/tavern_left.tscn"
const TAVERN_RIGHT: String = "res://scenes/tavern/tavern_right.tscn"
const ENCOUNTER_SELECT: String = \
		"res://scenes/encounter_select.tscn"
const RUN_WON: String = "res://scenes/run_won.tscn"
const RUN_LOST: String = "res://scenes/run_lost.tscn"
