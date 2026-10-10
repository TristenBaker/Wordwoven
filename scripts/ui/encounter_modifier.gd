extends Control
## Preparation is separate from combat: validation only, one cached fate, one exit.
const FATE_CLASSIFIER = preload("res://scripts/modifiers/fate_classifier.gd")
const MODIFIERS = preload("res://scripts/modifiers/encounter_modifier.gd")
const BODY = preload("res://assets/Fonts/Junicode.ttf")
const BUTTON_THEME = preload("res://assets/Themes/WordWoven_Button_Theme.tres")
var _validator: WordValidator
var _input: LineEdit
var _message: Label
var _title: Label
var _flavor: Label
var _effect: Label
var _submit: Button
var _continue: Button
var _leaving: bool = false

func _ready() -> void:
	if not RunState.is_run_active:
		get_tree().change_scene_to_file(ScenePaths.BIOME_SELECT)
		return
	var factory := EnemyFactory.new()
	add_child(factory)
	var pending: Dictionary = RunState.pending_encounter_modifier
	if not pending.is_empty() and int(pending.get("encounter", -1)) != RunState.encounter_index:
		RunState.pending_encounter_modifier.clear()
		pending = {}
	# Reopening retains the original enemy as well as its fate.
	if not pending.is_empty():
		RunState.next_enemy_id = pending.enemy_id
	else:
		var allowed: Array[String] = factory.ids_for_stage(RunState.encounter_index)
		if not allowed.has(RunState.next_enemy_id):
			RunState.next_enemy_id = allowed.pick_random()
	factory.queue_free()
	_validator = WordValidator.new()
	add_child(_validator)
	_build_screen()
	if not pending.is_empty():
		_reveal(pending)
	else:
		_input.grab_focus()

func _label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", BODY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("eadfc3"))
	label.add_theme_color_override("font_outline_color", Color("080e20"))
	label.add_theme_constant_override("outline_size", 3)
	return label

func _build_screen() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("080e20")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	# Keep the navy fallback behind the scene's background artwork.
	move_child(backdrop, 0)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Float below the portal's crown while staying horizontally centered.
	center.offset_top = 80.0
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 350)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111c32")
	style.bg_color.a = 0.85
	style.border_color = Color("927443")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	_title = _label("The Coming Foe", 38)
	_title.add_theme_color_override("font_color", Color("d6bb7a"))
	content.add_child(_title)
	content.add_child(_label("Describe your coming foe with an adjective.", 25))
	_input = LineEdit.new()
	_input.placeholder_text = "Enter an adjective…"
	_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input.add_theme_font_override("font", BODY)
	_input.add_theme_font_size_override("font_size", 26)
	_input.add_theme_color_override("font_uneditable_color", Color("eadfc3"))
	_input.custom_minimum_size.y = 48
	_input.text_submitted.connect(func(_text: String): _on_submit())
	content.add_child(_input)
	_message = _label("", 20)
	_message.add_theme_color_override("font_color", Color("dda59a"))
	content.add_child(_message)
	_submit = Button.new()
	_submit.text = "REVEAL YOUR FATE"
	_submit.custom_minimum_size.y = 44
	_submit.theme = BUTTON_THEME
	_submit.theme_type_variation = &"WordWovenActionButton"
	_submit.pressed.connect(_on_submit)
	content.add_child(_submit)
	_flavor = _label("", 24)
	_flavor.visible = false
	content.add_child(_flavor)
	_effect = _label("", 26)
	_effect.visible = false
	content.add_child(_effect)
	_continue = Button.new()
	_continue.text = "FACE YOUR FATE"
	_continue.custom_minimum_size.y = 44
	_continue.theme = BUTTON_THEME
	_continue.theme_type_variation = &"WordWovenActionButton"
	_continue.visible = false
	_continue.pressed.connect(_on_continue)
	content.add_child(_continue)

func _on_submit() -> void:
	if _leaving or not RunState.pending_encounter_modifier.is_empty():
		return
	if not WordNet.is_ready:
		_message.text = "The lexicon is still opening. Try again shortly."
		return
	var word: String = _input.text.strip_edges().to_lower()
	var verdict: Dictionary = _validator.validate(word, "a")
	if not verdict.valid:
		_message.text = verdict.reason
		_input.grab_focus()
		return
	var chosen: Dictionary = FATE_CLASSIFIER.select_modifier(word)
	var pending: Dictionary = RunState.cache_encounter_modifier(RunState.next_enemy_id, word, chosen.id)
	_reveal(pending)

func _reveal(pending: Dictionary) -> void:
	var modifier: Dictionary = MODIFIERS.definition(pending.modifier_id)
	_input.text = String(pending.word).to_upper()
	_input.editable = false
	_submit.visible = false
	_message.text = "Your adjective has sealed this encounter's fate."
	_title.text = modifier.name
	var accent := Color("d6bb7a") if modifier.beneficial else Color("dda59a")
	_title.add_theme_color_override("font_color", accent)
	_flavor.text = modifier.flavor
	_flavor.visible = true
	_effect.text = "%s\nThis encounter only." % modifier.effect
	_effect.visible = true
	_effect.add_theme_color_override("font_color", accent)
	_continue.visible = true
	# Do not let the same Enter press reveal and immediately leave.
	_continue.call_deferred("grab_focus")

func _on_continue() -> void:
	if _leaving or RunState.pending_encounter_modifier.is_empty():
		return
	_leaving = true
	_continue.disabled = true
	get_tree().change_scene_to_file(ScenePaths.COMBAT)
