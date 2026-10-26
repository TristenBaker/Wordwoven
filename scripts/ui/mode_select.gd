extends Control
## Separates the authored expedition from the quick, repeatable Endless loop.

@onready var story_button: Button = %StoryButton
@onready var endless_button: Button = %EndlessButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	story_button.pressed.connect(_start_story)
	endless_button.pressed.connect(_start_endless)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file(ScenePaths.MAIN_MENU))


func _start_story() -> void:
	get_tree().change_scene_to_file(ScenePaths.BIOME_SELECT)


func _start_endless() -> void:
	RunState.start_new_run(RunState.RunMode.ENDLESS)
	# Endless treats locations as visual variety rather than a rule set.
	RunState.selected_biome = ""
	get_tree().change_scene_to_file(ScenePaths.COMBAT)
