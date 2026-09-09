extends Control
## Lets the player choose the next encounter. Offers two enemies
## suited to the current stage, or only the boss when the run has
## reached its final encounter.

const CHOICE_COUNT: int = 2

@onready var factory: EnemyFactory = $EnemyFactory
@onready var title_label: Label = $CenterBox/Menu/TitleLabel
@onready var choices_box: HBoxContainer = \
		$CenterBox/Menu/ChoicesBox


func _ready() -> void:
	title_label.text = "Choose your next foe"
	if RunState.is_boss_next():
		title_label.text = "The end of the road"
		_add_choice(factory.boss_id())
		return
	var ids: Array[String] = factory.ids_for_stage(
		RunState.encounter_index
	)
	ids.shuffle()
	for i: int in mini(CHOICE_COUNT, ids.size()):
		_add_choice(ids[i])


func _add_choice(enemy_id: String) -> void:
	var data: Dictionary = factory.build_spawn_data(enemy_id)
	if data.is_empty():
		return
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(260, 120)
	var pool: Array = data["tags"]
	button.text = "%s\n(%s)" % [
		data["name"], " / ".join(pool)
	]
	button.pressed.connect(
		_on_choice_pressed.bind(enemy_id)
	)
	choices_box.add_child(button)


func _on_choice_pressed(enemy_id: String) -> void:
	RunState.next_enemy_id = enemy_id
	get_tree().change_scene_to_file(ScenePaths.COMBAT)
