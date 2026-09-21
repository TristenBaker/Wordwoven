extends Control
## Second step after a fight: choose one stacking roguelite power.

var relic_system := RelicSystem.new()
var choice_buttons: Array[Button] = []

@onready var status_label: Label = $CenterBox/PowerPanel/Content/Status
@onready var continue_button: Button = $CenterBox/PowerPanel/Content/ContinueButton


func _ready() -> void:
	if RunState.pending_victory_enemy.is_empty():
		get_tree().change_scene_to_file(ScenePaths.TAVERN)
		return
	choice_buttons = [
		$CenterBox/PowerPanel/Content/Choices/ChoiceOne,
		$CenterBox/PowerPanel/Content/Choices/ChoiceTwo,
		$CenterBox/PowerPanel/Content/Choices/ChoiceThree,
	]
	for index: int in choice_buttons.size():
		choice_buttons[index].pressed.connect(_select_choice.bind(index))
	continue_button.pressed.connect(_open_loot)
	_ensure_choices()
	_refresh()


func _ensure_choices() -> void:
	if not RunState.pending_relic_choices.is_empty():
		return
	var ids: Array[String] = relic_system.relic_ids()
	ids.shuffle()
	for relic_id: String in ids:
		if RunState.pending_relic_choices.size() >= choice_buttons.size():
			break
		RunState.pending_relic_choices.append(relic_id)


func _select_choice(index: int) -> void:
	if index >= RunState.pending_relic_choices.size():
		return
	relic_system.grant_reward(
		RunState.pending_relic_choices[index], RunState.encounter_index
	)
	_refresh()


func _refresh() -> void:
	var claimed: String = RunState.relic_rewards.get(RunState.encounter_index, "")
	for index: int in choice_buttons.size():
		var button := choice_buttons[index]
		if index >= RunState.pending_relic_choices.size():
			button.hide()
			continue
		var relic_id := RunState.pending_relic_choices[index]
		var info := relic_system.relic_info(relic_id)
		button.text = "%s\n%s\nOwned: %d" % [
			info.get("name", relic_id), info.get("description", ""),
			RunState.relics.count(relic_id),
		]
		button.disabled = not claimed.is_empty()
	if claimed.is_empty():
		status_label.text = "Choose one power. Copies stack."
		continue_button.disabled = true
	else:
		status_label.text = "Power gained: %s" % relic_system.relic_info(claimed).get("name", claimed)
		continue_button.disabled = false
func _open_loot() -> void:
	get_tree().change_scene_to_file(ScenePaths.LOOT_DROP)
