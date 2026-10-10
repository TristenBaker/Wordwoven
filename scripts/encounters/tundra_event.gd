extends Control

const TundraEventScript = preload("res://scripts/encounters/tundra_events.gd")
const SideQuestMusic = preload("res://scripts/encounters/tundra_side_quest_music.gd")
## One reusable presentation for all optional Tundra encounters.
var encounter_id: String
var data: Dictionary
var _frames: Array[AtlasTexture] = []
var _elapsed: float = 0.0
var _finished: bool = false
@onready var sprite: TextureRect = $Margin/Content/Sprite
@onready var input: LineEdit = $Margin/Content/InputRow/WordInput
@onready var submit: Button = $Margin/Content/InputRow/Submit
@onready var skip: Button = $Margin/Content/InputRow/Skip
@onready var result_panel: PanelContainer = $Margin/Content/Result
@onready var dialogue: Label = $Margin/Content/Result/Lines/Dialogue
@onready var reward: Label = $Margin/Content/Result/Lines/Reward
@onready var continue_button: Button = $Margin/Content/Continue
@onready var feedback: Label = $Margin/Content/Feedback
@onready var validator: WordValidator = $WordValidator

func _ready() -> void:
	encounter_id = RunState.pending_optional_encounter
	data = TundraEventScript.definition(encounter_id)
	if data.is_empty() or (not RunState.optional_encounter_available(encounter_id) and not RunState.optional_encounters.has(encounter_id)):
		_return_to_map.call_deferred()
		return
	SideQuestMusic.ensure_playing(get_tree())
	$Margin/Content/Title.text = data.name
	$Margin/Content/Description/Text.text = data.description
	input.placeholder_text = "Enter a %s..." % WordNet.pos_name(data.pos)
	var frame_count: int = int(data.frames) if data.get("animate", true) else 1
	for frame: int in frame_count:
		_frames.append(TundraEventScript.frame_texture(data, frame))
	sprite.texture = _frames[0]
	set_process(_frames.size() > 1)
	submit.pressed.connect(_submit)
	input.text_submitted.connect(func(_text: String): _submit())
	skip.pressed.connect(_skip)
	continue_button.pressed.connect(_return_to_map)
	if RunState.optional_encounters.has(encounter_id):
		_show_result(RunState.optional_encounters[encounter_id])
	else:
		input.grab_focus()

func _process(delta: float) -> void:
	if _frames.size() <= 1:
		return
	_elapsed = fmod(_elapsed + delta, float(_frames.size()) / float(data.fps))
	sprite.texture = _frames[int(_elapsed * float(data.fps)) % _frames.size()]

func _submit() -> void:
	if _finished:
		return
	if not WordNet.is_ready:
		feedback.text = "The lexicon is warming up. Try again in a moment."
		return
	var word: String = input.text.strip_edges().to_lower()
	var verdict: Dictionary = validator.validate(word, String(data.pos))
	if not verdict.valid:
		var expected: String = WordNet.pos_name(String(data.pos))
		var article: String = "an" if expected.begins_with("a") else "a"
		var request: String = "Enter %s %s." % [article, expected]
		feedback.text = request if verdict.reason == "Use a " + expected else "%s. %s" % [verdict.reason, request]
		input.grab_focus()
		return
	var result: Dictionary = TundraEventScript.complete(encounter_id, word)
	if not result.is_empty():
		_show_result(result)

func _skip() -> void:
	if _finished:
		return
	var result: Dictionary = TundraEventScript.complete(encounter_id, "", true)
	if not result.is_empty():
		_show_result(result)

func _show_result(result: Dictionary) -> void:
	_finished = true
	input.editable = false
	submit.disabled = true
	skip.disabled = true
	feedback.hide()
	$Margin/Content/Description.hide()
	$Margin/Content/InputRow.hide()
	dialogue.text = result.dialogue
	reward.text = result.reward
	result_panel.show()
	continue_button.show()
	continue_button.grab_focus()

func _return_to_map() -> void:
	RunState.pending_optional_encounter = ""
	get_tree().change_scene_to_file(ScenePaths.ENCOUNTER_SELECT)
