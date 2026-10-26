extends Control
## A route room that reveals why the Frost Wyrm imposed the White Silence.

const LINES: Array[String] = [
	"A voice is trapped inside the glacier.",
	"It is old, immense—and afraid.",
	"[i]I watched promises become threats, and names become weapons.[/i]",
	"[i]A frozen word cannot lie.[/i]",
	"[i]When every voice is still, meaning will remain pure.[/i]",
	"The memory belongs to the Frost Wyrm.",
	"It means to preserve language by silencing everyone who could change it.",
]

const FADE_SECONDS: float = 0.65
const HOLD_SECONDS: float = 2.35

@onready var story_text: RichTextLabel = $Center/LorePanel/Content/StoryText
@onready var continue_button: Button = $Center/LorePanel/Content/ContinueButton

var line_index: int = 0
var _ending: bool = false
var _active_tween: Tween


func _ready() -> void:
	if RunState.pending_route_activity != "lore_room":
		get_tree().change_scene_to_file.call_deferred(ScenePaths.ENCOUNTER_SELECT)
		return
	continue_button.pressed.connect(_finish_cutscene)
	continue_button.text = "Skip Cutscene"
	continue_button.grab_focus()
	story_text.modulate.a = 0.0
	_play_sequence()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish_cutscene()


func _show_line() -> void:
	story_text.text = "[center]%s[/center]" % LINES[line_index]


func _play_sequence() -> void:
	while line_index < LINES.size() and not _ending:
		_show_line()
		_active_tween = create_tween()
		_active_tween.tween_property(
			story_text, "modulate:a", 1.0, FADE_SECONDS
		)
		await _active_tween.finished
		if _ending:
			return
		await get_tree().create_timer(HOLD_SECONDS).timeout
		if _ending:
			return
		_active_tween = create_tween()
		_active_tween.tween_property(
			story_text, "modulate:a", 0.0, FADE_SECONDS
		)
		await _active_tween.finished
		line_index += 1
	_finish_cutscene()


func _finish_cutscene() -> void:
	if _ending:
		return
	_ending = true
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	RunState.finish_lore_room()
	get_tree().change_scene_to_file(ScenePaths.ENCOUNTER_SELECT)
