extends Control
## A short, text-first prologue shown when a tundra run begins.

const LINES: Array[String] = [
	"The Frost Wyrm stole the EMBER WORD. \nThe word that gives speech warmth and meaning.",
	"Without it, words freeze before they can be spoken. \nNames fade. Voices fail. Only the cold endure.",
	"Your letters are still alive.",
	"Take them to restore the silence...",
]

const FADE_SECONDS: float = 0.65
const HOLD_SECONDS: float = 2.35

@onready var story_text: RichTextLabel = $Center/StoryText

var line_index: int = 0
var _ending: bool = false
var _active_tween: Tween


func _ready() -> void:
	if not RunState.is_run_active or RunState.selected_biome != "tundra":
		get_tree().change_scene_to_file.call_deferred(ScenePaths.BIOME_SELECT)
		return
	RunState.tundra_intro_seen = true
	story_text.modulate.a = 0.0
	_play_sequence()


func _unhandled_input(event: InputEvent) -> void:
	var mouse_skip: bool = event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if event.is_action_pressed("ui_accept") \
			or event.is_action_pressed("ui_cancel") or mouse_skip:
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
	# The prologue hands straight into the opening bag draw. That screen then
	# introduces the equipped letters before beginning the first encounter.
	get_tree().change_scene_to_file(ScenePaths.STARTER_DRAW)
