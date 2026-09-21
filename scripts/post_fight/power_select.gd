extends Control
## Second step after a fight: choose one of three mixed rewards drawn
## from modifier stickers, punctuation, letter upgrades, and relics.
## Stickers and upgrades ask for the receiving letter and preview
## exactly what it becomes. Choices are rolled once per victory and
## only one can be claimed.

var rewards: RewardSystem = RewardSystem.new()
var choice_buttons: Array[Button] = []
# Receives the next scene path; tests capture it instead of leaving.
var navigate: Callable = Callable()

# The choice waiting for its target letter, or -1.
var _targeting: int = -1

@onready var subtitle_label: Label = \
		$CenterBox/PowerPanel/Content/Subtitle
@onready var status_label: Label = $CenterBox/PowerPanel/Content/Status
@onready var target_panel: VBoxContainer = \
		$CenterBox/PowerPanel/Content/TargetPanel
@onready var target_label: Label = \
		$CenterBox/PowerPanel/Content/TargetPanel/TargetLabel
@onready var target_grid: GridContainer = \
		$CenterBox/PowerPanel/Content/TargetPanel/TargetGrid
@onready var cancel_target_button: Button = \
		$CenterBox/PowerPanel/Content/TargetPanel/CancelTargetButton
@onready var continue_button: Button = \
		$CenterBox/PowerPanel/Content/ContinueButton
@onready var confirmer: ActionConfirmer = $ActionConfirmer


func _ready() -> void:
	if RunState.pending_victory_enemy.is_empty():
		_go(ScenePaths.TAVERN)
		return
	choice_buttons = [
		$CenterBox/PowerPanel/Content/Choices/ChoiceOne,
		$CenterBox/PowerPanel/Content/Choices/ChoiceTwo,
		$CenterBox/PowerPanel/Content/Choices/ChoiceThree,
	]
	for index: int in choice_buttons.size():
		choice_buttons[index].pressed.connect(select_choice.bind(index))
	cancel_target_button.pressed.connect(_cancel_target)
	continue_button.pressed.connect(_open_loot)
	subtitle_label.text = "Claim one. Stickers and training go on a"
	subtitle_label.text += " letter you choose."
	rewards.victory_choices()
	_refresh()


## Picks a choice: targeted rewards open the letter picker, others
## ask to confirm straight away.
func select_choice(index: int) -> void:
	var choices: Array[Dictionary] = rewards.victory_choices()
	if index < 0 or index >= choices.size() or _is_claimed() \
			or confirmer.is_pending():
		return
	var reward: Dictionary = choices[index]
	if rewards.needs_target(reward):
		_targeting = index
		_show_targets(reward)
		return
	confirmer.request(
		"Claim reward",
		"Claim %s?\n%s\nThis is your only reward from this victory." % [
			rewards.title(reward), rewards.describe(reward),
		],
		_confirm_claim.bind(index, null)
	)


## Asks to confirm the targeted reward on one letter instance.
func select_target(stats: LetterStats) -> void:
	var choices: Array[Dictionary] = rewards.victory_choices()
	if _targeting < 0 or _targeting >= choices.size() \
			or confirmer.is_pending():
		return
	var reward: Dictionary = choices[_targeting]
	var message: String = "Give %s to %s (%s)?\nIt becomes %s." % [
		rewards.title(reward), stats.describe(), stats.tag_text(),
		rewards.preview(reward, stats),
	]
	message += "\nThis is your only reward from this victory."
	confirmer.request(
		"Claim reward", message, _confirm_claim.bind(_targeting, stats)
	)


func targeting_index() -> int:
	return _targeting


func _confirm_claim(index: int, stats: LetterStats) -> void:
	if rewards.claim_victory(index, stats):
		_targeting = -1
	_refresh()


func _cancel_target() -> void:
	_targeting = -1
	_refresh()


func _show_targets(reward: Dictionary) -> void:
	for child: Node in target_grid.get_children():
		target_grid.remove_child(child)
		child.queue_free()
	target_label.text = "Choose the letter to receive %s:" % \
			rewards.title(reward)
	for stats: LetterStats in rewards.target_candidates(reward):
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(62, 48)
		button.text = "%s\nLv%d" % [stats.letter.to_upper(), stats.level]
		button.tooltip_text = "%s (%s)\n%s\nBecomes: %s" % [
			stats.describe(), stats.tag_text(), stats.full_effect_text(),
			rewards.preview(reward, stats),
		]
		button.pressed.connect(select_target.bind(stats))
		target_grid.add_child(button)
	target_panel.show()


func _is_claimed() -> bool:
	return not rewards.claimed_for_current().is_empty()


func _refresh() -> void:
	var choices: Array[Dictionary] = rewards.victory_choices()
	var claimed: Dictionary = rewards.claimed_for_current()
	for index: int in choice_buttons.size():
		var button: Button = choice_buttons[index]
		if index >= choices.size():
			button.hide()
			continue
		var reward: Dictionary = choices[index]
		button.text = "%s\n%s" % [
			rewards.title(reward), rewards.describe(reward),
		]
		if String(reward["kind"]) == "relic":
			button.text += "\nOwned: %d" % RunState.relics.count(
				String(reward["id"])
			)
		button.disabled = not claimed.is_empty()
	if not claimed.is_empty():
		target_panel.hide()
		status_label.text = "Claimed: %s" % rewards.title(claimed)
		continue_button.disabled = false
		return
	target_panel.visible = _targeting >= 0
	status_label.text = "Choose one reward."
	continue_button.disabled = true


func _open_loot() -> void:
	if not _is_claimed():
		return
	_go(ScenePaths.LOOT_DROP)


func _go(scene_path: String) -> void:
	if navigate.is_valid():
		navigate.call(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)
