extends Control
## Choose a world before creating a run. Biomes are menu-only for now.

const PLAYABLE_BIOME: String = "tundra"

var _selected_biome: String = ""
var _starting: bool = false
var _biome_group: ButtonGroup = ButtonGroup.new()

@onready var choices: HBoxContainer = %Choices
@onready var selection_label: Label = %SelectionLabel
@onready var preview: TextureRect = %Preview
@onready var description: Label = %Description
@onready var mechanics: VBoxContainer = %Mechanics
@onready var begin_button: Button = %BeginButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	begin_button.pressed.connect(_on_begin_pressed)
	back_button.pressed.connect(_on_back_pressed)
	var default_button: Button = null
	for button: Button in choices.get_children():
		button.disabled = String(button.get_meta("biome_id")) != PLAYABLE_BIOME
		if not button.disabled:
			default_button = button
		button.button_group = _biome_group
		button.pressed.connect(_on_biome_selected.bind(button))
	begin_button.disabled = default_button == null
	if default_button != null:
		default_button.button_pressed = true
		_on_biome_selected(default_button)
		default_button.grab_focus()


func _on_biome_selected(button: Button) -> void:
	var biome_id := String(button.get_meta("biome_id"))
	if button.disabled or biome_id != PLAYABLE_BIOME:
		return
	_selected_biome = biome_id
	selection_label.text = button.get_node("Content/Name").text
	preview.texture = button.get_meta(
		"preview_texture", button.get_node("Content/Thumbnail").texture
	)
	description.text = String(button.get_meta("description"))
	mechanics.visible = biome_id == "tundra"


func _on_begin_pressed() -> void:
	if _starting or _selected_biome != PLAYABLE_BIOME or not WordNet.is_ready:
		return
	_starting = true
	begin_button.disabled = true
	RunState.start_new_run()
	RunState.selected_biome = _selected_biome
	get_tree().change_scene_to_file(ScenePaths.COMBAT)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)
