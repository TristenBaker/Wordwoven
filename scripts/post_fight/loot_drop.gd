extends Control
## Final step after a fight: a deliberately small loot summary, ready for
## dropped letters and other items to be added later.

@onready var enemy_label: Label = $CenterBox/LootPanel/Content/Enemy
@onready var gold_label: Label = $CenterBox/LootPanel/Content/GoldCard/Gold
@onready var continue_button: Button = $CenterBox/LootPanel/Content/ContinueButton


func _ready() -> void:
	if RunState.pending_victory_enemy.is_empty():
		get_tree().change_scene_to_file(ScenePaths.TAVERN)
		return
	enemy_label.text = "%s left behind:" % RunState.pending_victory_enemy
	gold_label.text = "%d gold" % RunState.pending_victory_gold
	continue_button.text = "Complete the Tale" if RunState.is_boss_next() else "Return to Tavern"
	continue_button.pressed.connect(_finish_rewards)
	continue_button.grab_focus()


func _finish_rewards() -> void:
	var defeated_boss := RunState.is_boss_next()
	RunState.advance_encounter()
	RunState.clear_pending_victory()
	get_tree().change_scene_to_file(RunFlow.after_rewards(defeated_boss))
