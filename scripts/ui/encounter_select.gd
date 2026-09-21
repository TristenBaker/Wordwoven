extends Control
## Encounter setup. Offers stage-appropriate foes, each with a
## previewed environment, asks for one supported adjective as the
## foe's sole counterable tag, and confirms the complete setup before
## combat. The boss stage offers only the boss.

var planner: EncounterPlanner = EncounterPlanner.new()

var _options: Array[Dictionary] = []
var _selected_index: int = -1
var _option_group: ButtonGroup = ButtonGroup.new()
var _entering: bool = false

@onready var factory: EnemyFactory = $EnemyFactory
@onready var title_label: Label = $CenterBox/Menu/TitleLabel
@onready var choices_box: HBoxContainer = \
		$CenterBox/Menu/ChoicesBox
@onready var selection_label: Label = $CenterBox/Menu/SelectionLabel
@onready var tag_input: LineEdit = $CenterBox/Menu/TagRow/TagInput
@onready var enter_button: Button = $CenterBox/Menu/TagRow/EnterButton
@onready var feedback_label: Label = $CenterBox/Menu/FeedbackLabel
@onready var confirmer: ActionConfirmer = $ActionConfirmer


func _ready() -> void:
	if not RunState.is_run_active:
		RunState.start_new_run()
	# Both of the stage's noncombat events come before combat setup.
	if EventProgress.has_pending():
		get_tree().change_scene_to_file.call_deferred(ScenePaths.EVENT)
		return
	title_label.text = "Choose your next foe"
	if RunState.is_boss_next():
		title_label.text = "The end of the road"
	enter_button.pressed.connect(_on_enter_pressed)
	tag_input.text_submitted.connect(_on_tag_submitted)
	_options = planner.options_for_current(factory)
	for index: int in _options.size():
		_add_choice(index)
	if _options.size() == 1:
		select_option(0)


## Highlights one option and shows its enemy and environment preview.
func select_option(index: int) -> void:
	if index < 0 or index >= _options.size():
		return
	_selected_index = index
	var button: Button = choices_box.get_child(index)
	button.button_pressed = true
	var option: Dictionary = _options[index]
	selection_label.text = "%s\n%s" % [
		factory.describe(option["enemy_id"]),
		EnvironmentCatalog.describe(option["environment"]),
	]
	enter_button.disabled = false
	tag_input.grab_focus()


func _add_choice(index: int) -> void:
	var option: Dictionary = _options[index]
	var info: Dictionary = factory.enemy_info(option["enemy_id"])
	if info.is_empty():
		return
	var button: Button = Button.new()
	button.toggle_mode = true
	button.button_group = _option_group
	button.custom_minimum_size = Vector2(300, 96)
	button.text = "%s\n%s" % [
		info.get("name", option["enemy_id"]),
		EnvironmentCatalog.display_name(option["environment"]),
	]
	button.tooltip_text = "%s\n%s" % [
		factory.describe(option["enemy_id"]),
		EnvironmentCatalog.describe(option["environment"]),
	]
	button.pressed.connect(select_option.bind(index))
	choices_box.add_child(button)


# Names the tag's direct opposites so the player knows what counters it.
func _counter_hint(tag: String) -> String:
	var opposites: Array[String] = WordNet.counter_targets(tag, "a")
	if opposites.is_empty():
		return "No direct opposite of '%s' is known; counters will be rare." \
				% tag
	return "Opposites of '%s' deal extra damage, such as %s." % [
		tag, ", ".join(opposites.slice(0, 3)),
	]


func _on_tag_submitted(_text: String) -> void:
	_on_enter_pressed()


func _on_enter_pressed() -> void:
	if _entering or _selected_index < 0:
		feedback_label.text = "Choose a foe first."
		return
	var verdict: Dictionary = EncounterPlanner.normalize_tag(
		tag_input.text
	)
	if not verdict["valid"]:
		feedback_label.text = verdict["reason"]
		return
	feedback_label.text = ""
	var option: Dictionary = _options[_selected_index]
	var info: Dictionary = factory.enemy_info(option["enemy_id"])
	confirmer.request(
		"Enter encounter",
		"Face the %s %s on %s?\n\n%s\n%s\n%s" % [
			verdict["tag"],
			info.get("name", option["enemy_id"]),
			EnvironmentCatalog.display_name(option["environment"]),
			factory.describe(option["enemy_id"]),
			EnvironmentCatalog.describe(option["environment"]),
			_counter_hint(verdict["tag"]),
		],
		_confirm_entry.bind(_selected_index, verdict["tag"])
	)


func _confirm_entry(index: int, tag: String) -> void:
	if _entering or index < 0 or index >= _options.size():
		return
	var setup: Dictionary = EncounterPlanner.configure(
		_options[index], tag
	)
	if setup.is_empty() or not factory.has_enemy(setup["enemy_id"]):
		feedback_label.text = "That encounter is no longer available."
		return
	_entering = true
	enter_button.disabled = true
	RunState.pending_encounter = setup
	get_tree().change_scene_to_file(ScenePaths.COMBAT)
