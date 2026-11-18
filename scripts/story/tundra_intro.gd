extends Control
## A text-first prologue advanced one passage at a time by the player.

const LINES: Array[String] = [
	"The Frost Wyrm stole the EMBER WORD. \nThe word that gives speech warmth and meaning.",
	"Without it, words freeze before they can be spoken. \nNames fade. Voices fail. Only the cold endure.",
	"Your letters are still alive.",
	"Take them to restore the silence...",
]

const FADE_SECONDS: float = 0.65

@onready var story_text: RichTextLabel = $Center/StoryText

var line_index: int = 0
var _ending: bool = false
var _active_tween: Tween


func _ready() -> void:
	if not RunState.is_run_active or RunState.selected_biome != "tundra":
		get_tree().change_scene_to_file.call_deferred(ScenePaths.BIOME_SELECT)
		return
	RunState.tundra_intro_seen = true
	_show_line()


func _unhandled_input(event: InputEvent) -> void:
	var mouse_advance: bool = event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if event.is_echo():
		return
	if event.is_action_pressed("ui_accept") \
			or event.is_action_pressed("ui_cancel") or mouse_advance:
		get_viewport().set_input_as_handled()
		_advance_line()


func _advance_line() -> void:
	if _ending:
		return
	line_index += 1
	if line_index >= LINES.size():
		_finish_cutscene()
	else:
		_show_line()


func _show_line() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	story_text.text = "[center]%s[/center]" % LINES[line_index]
	story_text.modulate.a = 0.0
	_active_tween = create_tween()
	_active_tween.tween_property(story_text, "modulate:a", 1.0, FADE_SECONDS)
	# Leave the passage visible indefinitely; input alone advances it.


func _finish_cutscene() -> void:
	if _ending:
		return
	_ending = true
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	# The prologue hands straight into the opening bag draw. That screen then
	# introduces the equipped letters before beginning the first encounter.
	get_tree().change_scene_to_file(ScenePaths.STARTER_DRAW)
