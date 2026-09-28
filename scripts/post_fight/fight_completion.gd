extends Control
## First step after a fight: the bard retells the encounter before rewards.

@onready var title_label: Label = $CenterBox/TalePanel/Content/Title
@onready var story_label: RichTextLabel = \
		$CenterBox/TalePanel/Content/Story
@onready var reward_label: Label = $CenterBox/TalePanel/Content/Reward
@onready var continue_button: Button = \
		$CenterBox/TalePanel/Content/ContinueButton


func _ready() -> void:
	if RunState.pending_victory_enemy.is_empty():
		get_tree().change_scene_to_file(ScenePaths.TAVERN)
		return
	# Fade in from the black the combat scene faded out to.
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)
	title_label.text = "%s Defeated" % RunState.pending_victory_enemy
	var bard: Storyteller = Storyteller.new()
	story_label.text = bard.generate_for_encounter(
		RunState.encounter_index
	)
	reward_label.text = "The tale earns you %d gold." % \
			RunState.pending_victory_gold
	continue_button.pressed.connect(_open_power_select)
	continue_button.grab_focus()


func _open_power_select() -> void:
	get_tree().change_scene_to_file(ScenePaths.POWER_SELECT)
