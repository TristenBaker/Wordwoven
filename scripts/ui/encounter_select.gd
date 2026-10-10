extends Control

const TundraEventScript = preload("res://scripts/encounters/tundra_events.gd")
## Presents the run as a left-to-right expedition map. Completed
## encounters remain visible, the current stage branches into enemy
## choices, and every route converges on the final boss. Tundra runs
## expose every undefeated regular foe; other biomes offer two choices.

const CHOICE_COUNT: int = 2

@onready var factory: EnemyFactory = $EnemyFactory
@onready var title_label: Label = $Header/TitleLabel
@onready var subtitle_label: Label = $Header/SubtitleLabel
@onready var progress_label: Label = $ProgressBadge/ProgressLabel
@onready var route_map: Control = \
		$MapPanel/Margin/Content/RouteMap


func _ready() -> void:
	var stage: int = RunState.encounter_index
	progress_label.text = "ENCOUNTER %d / %d" % [
		mini(stage, RunState.ENCOUNTERS_PER_RUN),
		RunState.ENCOUNTERS_PER_RUN,
	]
	route_map.enemy_selected.connect(_on_choice_pressed)
	route_map.optional_selected.connect(_on_optional_pressed)
	var optional_ids: Array[String] = []
	for id: String in TundraEventScript.IDS:
		if RunState.optional_encounter_available(id):
			optional_ids.append(id)
	var detours: VBoxContainer = $MapPanel/Margin/Content/OptionalChoices
	detours.visible = not optional_ids.is_empty()
	route_map.setup_optional(detours.get_node("Cards"), optional_ids)
	if RunState.is_boss_next():
		title_label.text = "The End of the Road"
		subtitle_label.text = \
				"One final gate remains. Defeat its guardian to finish the run."
		var boss_data: Dictionary = factory.build_spawn_data(
			factory.boss_id()
		)
		var no_choices: Array[Dictionary] = []
		route_map.setup(stage, no_choices, boss_data)
		return
	var ids: Array[String] = factory.ids_for_stage(stage)
	ids.shuffle()
	var count: int = ids.size() if RunState.selected_biome == "tundra" \
			else mini(CHOICE_COUNT, ids.size())
	var choices: Array[Dictionary] = []
	for i: int in count:
		choices.append(factory.build_spawn_data(ids[i]))
	route_map.setup(stage, choices, {})


func _on_choice_pressed(enemy_id: String) -> void:
	RunState.next_enemy_id = enemy_id
	get_tree().change_scene_to_file(ScenePaths.ENCOUNTER_MODIFIER)


func _on_optional_pressed(id: String) -> void:
	if RunState.begin_optional_encounter(id):
		get_tree().change_scene_to_file(ScenePaths.TUNDRA_EVENT)
