extends Control
## Preview is editable. Only explicit confirmation caches the encounter fate.
const FATE_CLASSIFIER: Script = preload("uid://ms42avqgikf")
const VOCABULARY: Script = preload("uid://dlxn4nft028ba")
const MODIFIERS: Script = preload("uid://dubtvvoj1ve87")
const Balance: Script = preload("uid://3njd88j876qj")
const BODY: Font = preload("res://assets/Fonts/Junicode.ttf")
const BUTTON_THEME: Theme = preload(
	"res://assets/Themes/WordWoven_Button_Theme.tres"
)
const GOLD: Color = Color("d6bb7a")
const HARMFUL: Color = Color("dda59a")
var _validator: WordValidator
var _adjective_input: LineEdit
var _message: Label
var _title: Label
var _flavor: Label
var _effect: Label
var _confirm: Button
var _continue: Button
var _examples: Array[Button] = []
var _preview: Dictionary = {}
var _base_spawn: Dictionary = {}
var _committed: bool = false
var _leaving: bool = false


func _ready() -> void:
	if not RunState.is_run_active:
		get_tree().change_scene_to_file(ScenePaths.BIOME_SELECT)
		return
	var factory: EnemyFactory = EnemyFactory.new()
	add_child(factory)
	var pending: Dictionary = RunState.pending_encounter_modifier
	if not pending.is_empty() \
			and int(pending.get("encounter", -1)) != RunState.encounter_index:
		RunState.pending_encounter_modifier.clear()
		pending = {}
	# Reopening retains the original enemy as well as its committed fate.
	if not pending.is_empty():
		RunState.next_enemy_id = pending.enemy_id
	else:
		var allowed: Array[String] = factory.ids_for_stage(
			RunState.encounter_index
		)
		var debug_choice: bool = (
			DebugTools.free_map_select and RunState.selected_biome == "tundra"
			and (RunState.next_enemy_id == factory.boss_id()
				or RunState.next_enemy_id == Balance.TUNDRA_STARTER_ENEMY
				or EnemyFactory.TUNDRA_REGULARS.has(RunState.next_enemy_id))
		)
		if not allowed.has(RunState.next_enemy_id) and not debug_choice:
			RunState.next_enemy_id = allowed.pick_random()
	_base_spawn = factory.build_spawn_data(RunState.next_enemy_id)
	factory.queue_free()
	_validator = WordValidator.new()
	add_child(_validator)
	_build_screen()
	if not pending.is_empty():
		_reveal(pending)
	else:
		_on_word_changed(_adjective_input.text)
		_adjective_input.grab_focus()
	WordNet.loading_finished.connect(_on_lexicon_loaded)


func _label(text_value: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", BODY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("eadfc3"))
	label.add_theme_color_override("font_outline_color", Color("080e20"))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _button(text_value: String) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.theme = BUTTON_THEME
	button.theme_type_variation = &"WordWovenActionButton"
	button.custom_minimum_size.y = 38
	return button


func _build_screen() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color("080e20")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	move_child(backdrop, 0)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 16.0
	center.offset_bottom = -16.0
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "PreparationPanel"
	panel.custom_minimum_size.x = 820
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("111c32", 0.94)
	style.border_color = Color("927443")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	content.add_child(_label("Describe the Coming Foe", 32))
	content.add_child(_label(
		"Choose an adjective, preview its effect, then confirm.", 22
	))
	_adjective_input = LineEdit.new()
	_adjective_input.placeholder_text = "Enter an adjective…"
	_adjective_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_adjective_input.add_theme_font_override("font", BODY)
	_adjective_input.add_theme_font_size_override("font_size", 26)
	_adjective_input.custom_minimum_size.y = 44
	_adjective_input.text_changed.connect(_on_word_changed)
	# Enter refreshes the preview; it never confirms a selection.
	_adjective_input.text_submitted.connect(_on_text_submitted)
	content.add_child(_adjective_input)
	_message = _label("", 20)
	_message.custom_minimum_size.y = 48
	content.add_child(_message)
	content.add_child(_label("Try an adjective (hover for its effect):", 20))
	var examples: GridContainer = GridContainer.new()
	examples.columns = 5
	examples.add_theme_constant_override("h_separation", 6)
	examples.add_theme_constant_override("v_separation", 4)
	content.add_child(examples)
	for modifier: Dictionary in MODIFIERS.eligible_entries(
		RunState.selected_biome
	):
		var word: String = VOCABULARY.WORDS[modifier.id][0]
		var example: Button = _button(word.capitalize())
		example.custom_minimum_size.y = 30
		example.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		example.add_theme_font_size_override("font_size", 18)
		example.tooltip_text = "%s: %s" % [modifier.name, modifier.effect]
		example.pressed.connect(_choose_example.bind(word))
		examples.add_child(example)
		_examples.append(example)
	_title = _label("No modifier selected", 28)
	_title.add_theme_color_override("font_color", GOLD)
	content.add_child(_title)
	_flavor = _label("", 20)
	_flavor.custom_minimum_size.y = 48
	content.add_child(_flavor)
	_effect = _label("", 22)
	_effect.custom_minimum_size.y = 84
	content.add_child(_effect)
	_confirm = _button("CONFIRM MODIFIER")
	_confirm.disabled = true
	_confirm.pressed.connect(_on_confirm)
	content.add_child(_confirm)
	_continue = _button("ENTER COMBAT")
	_continue.visible = false
	_continue.pressed.connect(_on_continue)
	content.add_child(_continue)


func _choose_example(word: String) -> void:
	if _committed or _leaving:
		return
	_adjective_input.text = word
	_on_word_changed(word)
	_adjective_input.grab_focus()
	_adjective_input.caret_column = word.length()


func _on_text_submitted(_text: String) -> void:
	_on_submit()


func _on_lexicon_loaded(success: bool) -> void:
	if not _committed:
		_on_word_changed(_adjective_input.text)
		if not success:
			_message.text = "The lexicon could not load. Please restart."


func _on_word_changed(_text: String) -> void:
	if _committed or _leaving:
		return
	_preview.clear()
	_confirm.disabled = true
	_title.text = "No modifier selected"
	_title.add_theme_color_override("font_color", GOLD)
	_flavor.text = ""
	_effect.text = ""
	_message.add_theme_color_override("font_color", HARMFUL)
	if not WordNet.is_ready:
		_message.text = "The lexicon is opening. Please wait…"
		return
	var word: String = _adjective_input.text.strip_edges().to_lower()
	if word.is_empty():
		_message.text = "Type an adjective or choose an example below."
		return
	var verdict: Dictionary = _validator.validate(word, "a")
	if not verdict.valid:
		_message.text = verdict.reason
		if verdict.reason == "Use a adjective":
			_message.text = "Use an adjective"
		return
	var result: Dictionary = FATE_CLASSIFIER.classify(word)
	if result.status == "restricted":
		_message.text = "%s activates %s only in %s. Try another adjective." % [
			word.capitalize(), result.name, String(result.biome).capitalize(),
		]
		return
	if result.status != "supported":
		_message.text = (
			"Valid adjective, but no assigned combat modifier. "
			+ "Try another word or choose an example."
		)
		return
	_preview = MODIFIERS.definition(result.modifier_id)
	_message.text = "Preview only — you can change your adjective."
	_message.add_theme_color_override("font_color", GOLD)
	_show_effect(_preview)
	_confirm.disabled = false


func _on_submit() -> void:
	_on_word_changed(_adjective_input.text)


func _show_effect(modifier: Dictionary) -> void:
	_title.text = modifier.name
	var accent: Color = GOLD if modifier.beneficial else HARMFUL
	_title.add_theme_color_override("font_color", accent)
	_flavor.text = modifier.flavor
	_effect.text = _effect_description(modifier) + "\nThis encounter only."
	_effect.add_theme_color_override("font_color", accent)


func _effect_description(modifier: Dictionary) -> String:
	var applied: Dictionary = MODIFIERS.apply_spawn(_base_spawn, modifier)
	if modifier.stat in ["health", "attack"]:
		var stat: String = modifier.stat
		return "%s\n%s: %d → %d" % [
			modifier.effect, "Enemy HP" if stat == "health" else "Enemy attack",
			_base_spawn[stat], applied[stat],
		]
	if modifier.stat == "player_damage":
		return modifier.effect + "\nApplies to direct hit damage."
	match modifier.id:
		"drowsy":
			return "Sleeps first; alternates sleep and attacks at +25% damage."
		"clumsy":
			return "Every 3rd retaliation hits itself for half its base attack."
		"long_winded":
			return "7+ letters: +20% direct damage. Shorter words: +2 Guard."
		"echo_bound":
			return (
				"Start with the last word's final letter: +25% direct damage."
			)
		"chameleon":
			return "Enemy counter tags change every 2 retaliations."
		"greedy":
			return (
				"Casts: +1g (max 5). Win: +8g.\n"
				+ "Theft: 2g every 2 retaliations (max 4)."
			)
		"frostbite_tax":
			return "Freeze every 2 casts; gain 2 Heat per cast (normally 1)."
	return modifier.effect


func _on_confirm() -> void:
	if _committed or _leaving:
		return
	# Revalidate current text; never commit a stale preview.
	_on_word_changed(_adjective_input.text)
	if _preview.is_empty():
		return
	var word: String = _adjective_input.text.strip_edges().to_lower()
	var pending: Dictionary = RunState.cache_encounter_modifier(
		RunState.next_enemy_id, word, _preview.id
	)
	_reveal(pending)


func _reveal(pending: Dictionary) -> void:
	_committed = true
	_preview = MODIFIERS.definition(pending.modifier_id)
	_adjective_input.text = String(pending.word).to_upper()
	_adjective_input.editable = false
	_confirm.hide()
	for example: Button in _examples:
		example.disabled = true
	_message.text = "Modifier confirmed for this encounter."
	_message.add_theme_color_override("font_color", GOLD)
	_show_effect(_preview)
	_continue.show()
	_continue.call_deferred("grab_focus")


func _on_continue() -> void:
	if _leaving or RunState.pending_encounter_modifier.is_empty():
		return
	_leaving = true
	_continue.disabled = true
	get_tree().change_scene_to_file(ScenePaths.COMBAT)
