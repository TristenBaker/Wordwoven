extends Control
## Preview is editable. Only explicit confirmation caches the encounter fate.
const FATE_CLASSIFIER: Script = preload("uid://ms42avqgikf")
const MODIFIERS: Script = preload("uid://dubtvvoj1ve87")
const Balance: Script = preload("uid://3njd88j876qj")
const BODY: Font = preload("res://assets/Fonts/Junicode.ttf")
const BUTTON_THEME: Theme = preload(
	"res://assets/Themes/WordWoven_Button_Theme.tres"
)
const BOLD: Font = preload("res://assets/Fonts/Junicode-Bold.ttf")
const FRAME: StyleBoxTexture = preload("res://assets/Themes/encounters/information_panel.tres")
const ModifierRuntime = preload("res://data/balance/encounter_modifier_runtime.gd")
const HELPFUL := Color("add8b3")
const GOLD: Color = Color("d6bb7a")
const HARMFUL: Color = Color("dda59a")
var _validator: WordValidator
var _adjective_input: LineEdit
var _message: Label
var _title: Label
var _tradeoff: Label
var _reward_detail: Label
var _enemy_name: Label
var _enemy_stats: Dictionary[String, RichTextLabel] = {}
var _enemy_affinities: Label
var _portrait: TextureRect
var _browse: Button
var _browser: VBoxContainer
var _browse_words: GridContainer
var _category_tabs: Array[Button] = []
var _category_choices: Array[Array] = []
var _category_index := 0
var _effect: Label
var _confirm: Button
var _continue: Button
var _examples: Array[Button] = []
var _adjective_buttons: Dictionary[String, Button] = {}
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


func _selection_button(text_value: String) -> Button:
	var button := _button(text_value)
	button.toggle_mode = true
	var highlight := BUTTON_THEME.get_stylebox("hover", &"WordWovenActionButton")
	button.add_theme_stylebox_override("pressed", highlight)
	button.add_theme_stylebox_override("hover_pressed", highlight)
	return button


func _framed_panel(padding: float, vertical_padding: float) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := FRAME.duplicate() as StyleBoxTexture
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = vertical_padding
	style.content_margin_bottom = vertical_padding
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _build_screen() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("080e20", 0.54)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := _framed_panel(20, 14)
	panel.name = "PreparationPanel"
	panel.custom_minimum_size.x = 920
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)
	content.add_child(_label("Describe the Coming Foe", 32))
	content.add_child(_label("Choose an adjective to change this fight and its victory gold.", 18))
	content.add_child(_build_encounter_summary())

	_adjective_input = LineEdit.new()
	_adjective_input.placeholder_text = "Enter an adjective…"
	_adjective_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_adjective_input.caret_blink = true
	_adjective_input.keep_editing_on_text_submit = true
	_adjective_input.add_theme_font_override("font", BODY)
	_adjective_input.add_theme_font_size_override("font_size", 26)
	_adjective_input.custom_minimum_size.y = 44
	_adjective_input.text_changed.connect(_on_word_changed)
	_adjective_input.text_submitted.connect(_on_text_submitted)
	content.add_child(_adjective_input)
	_message = _label("", 17)
	_message.custom_minimum_size.y = 24
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(_message)
	_build_adjective_choices(content)

	var preview_panel := _framed_panel(16, 10)
	preview_panel.custom_minimum_size.y = 126
	content.add_child(preview_panel)
	var preview_content := VBoxContainer.new()
	preview_content.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_content.add_theme_constant_override("separation", 4)
	preview_panel.add_child(preview_content)
	_title = _label("No modifier selected", 24)
	preview_content.add_child(_title)
	_effect = _label("", 18)
	_tradeoff = _label("", 18)
	_reward_detail = _label("", 16)
	for line: Label in [_effect, _tradeoff, _reward_detail]:
		preview_content.add_child(line)
	_confirm = _button("CONFIRM MODIFIER")
	_confirm.disabled = true
	_confirm.pressed.connect(_on_confirm)
	content.add_child(_confirm)
	_continue = _button("ENTER COMBAT")
	_continue.hide()
	_continue.pressed.connect(_on_continue)
	content.add_child(_continue)


func _build_encounter_summary() -> PanelContainer:
	var foe := _framed_panel(16, 12)
	var foe_row := HBoxContainer.new()
	foe_row.add_theme_constant_override("separation", 18)
	foe.add_child(foe_row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(122, 86)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.texture = EncounterRouteMap.enemy_preview_texture(_base_spawn)
	if _portrait.texture != null and _base_spawn.get("black_matte", false):
		_portrait.material = Enemy.make_matte_material(load(_base_spawn.texture))
	foe_row.add_child(_portrait)
	var foe_info := VBoxContainer.new()
	foe_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foe_info.alignment = BoxContainer.ALIGNMENT_CENTER
	foe_info.add_theme_constant_override("separation", 4)
	foe_row.add_child(foe_info)
	_enemy_name = _label(String(_base_spawn.get("name", "Upcoming foe")), 26)
	_enemy_name.add_theme_font_override("font", BOLD)
	foe_info.add_child(_enemy_name)
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 8)
	foe_info.add_child(stats_row)
	for stat: String in ["health", "attack", "gold"]:
		var value := RichTextLabel.new()
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.custom_minimum_size.y = 62
		value.fit_content = false
		value.scroll_active = false
		value.bbcode_enabled = true
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value.add_theme_font_override("normal_font", BODY)
		value.add_theme_font_size_override("normal_font_size", 24)
		value.add_theme_color_override("default_color", Color("eadfc3"))
		stats_row.add_child(value)
		_enemy_stats[stat] = value
	_enemy_affinities = _label(_affinity_summary(_base_spawn.get("affinities", {})), 16)
	foe_info.add_child(_enemy_affinities)
	_enemy_affinities.visible = not _enemy_affinities.text.is_empty()
	_refresh_enemy_stats({})
	return foe


func _refresh_enemy_stats(modifier: Dictionary) -> void:
	var adjusted: Dictionary = MODIFIERS.apply_spawn(_base_spawn, modifier)
	var gold: int = _base_spawn.gold
	if not modifier.is_empty():
		gold = MODIFIERS.victory_gold(gold, modifier)
	var values := {"health": adjusted.health, "attack": adjusted.attack, "gold": gold}
	var names := {"health": "HP", "attack": "Attack", "gold": "Victory Gold"}
	if modifier.get("id") == "drowsy":
		var runtime := ModifierRuntime.new()
		runtime.id = modifier.id
		runtime.retaliations = 1
		values.attack = runtime.retaliation_plan(_base_spawn.attack).attack
		names.attack = "Awake attack"
	for stat: String in values:
		var original: int = _base_spawn[stat]
		var proposed: int = values[stat]
		var label: String = names[stat]
		var text := "[center][font_size=24]%s[/font_size]\n[font_size=26][b]%d[/b][/font_size]" % [label, original]
		if proposed != original:
			var helps := proposed > original if stat == "gold" else proposed < original
			var accent := HELPFUL if helps else HARMFUL
			text += " [font_size=26]→[/font_size] [font_size=26][color=#%s][b]%d[/b][/color][/font_size]" % [accent.to_html(false), proposed]
		_enemy_stats[stat].text = text + "[/center]"


func _affinity_summary(affinities: Dictionary) -> String:
	var weaknesses: PackedStringArray = []
	var resistances: PackedStringArray = []
	for element: String in affinities:
		var factor := float(affinities[element])
		if factor > 1.0:
			weaknesses.append("%s ×%.2f" % [element.capitalize(), factor])
		elif factor < 1.0:
			resistances.append("%s ×%.2f" % [element.capitalize(), factor])
	var parts: PackedStringArray = []
	if not weaknesses.is_empty():
		parts.append("Weak to " + ", ".join(weaknesses))
	if not resistances.is_empty():
		parts.append("Resists " + ", ".join(resistances))
	return "  •  ".join(parts)


func _build_adjective_choices(content: VBoxContainer) -> void:
	var suggestions := HBoxContainer.new()
	suggestions.add_theme_constant_override("separation", 8)
	content.add_child(suggestions)
	for suggestion: Array in [
		["weak", "Lower enemy health"],
		["vulnerable", "Increase your damage"],
		["strong", "Earn more gold"],
	]:
		var button := _selection_button("%s — %s" % [String(suggestion[0]).capitalize(), suggestion[1]])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 18)
		button.set_meta("adjective", suggestion[0])
		button.pressed.connect(_choose_example.bind(suggestion[0]))
		suggestions.add_child(button)
		_examples.append(button)

	_browse = _button("Browse more adjectives")
	_browse.toggle_mode = true
	_browse.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_browse.add_theme_font_size_override("font_size", 18)
	content.add_child(_browse)
	_browser = VBoxContainer.new()
	_browser.hide()
	content.add_child(_browser)
	_browse.toggled.connect(func(open: bool) -> void:
		_browser.visible = open
		_browse.text = "Hide adjective browser" if open else "Browse more adjectives"
	)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	_browser.add_child(tabs)
	var group := ButtonGroup.new()
	var categories := [
		["Reduce Risk", Color(1.48, 1.13, 0.72), [
			["doommarked", "weak", "Lower enemy health"],
			["spirit_broken", "timid", "Lower enemy attack"],
			["drowsy", "sleepy", "Alternating sleep and stronger hits"],
			["clumsy", "clumsy", "Enemy sometimes hits itself"],
		]],
		["Boost Your Casts", Color(1.48, 1.13, 0.72), [
			["fate_exposed", "vulnerable", "Increase your damage"],
			["long_winded", "wordy", "Word length bonuses"],
			["echo_bound", "echoing", "Link words for bonus damage"],
		]],
		["Earn More Gold", Color(1.48, 1.13, 0.72), [
			["titanbound", "strong", "Tougher enemy, more gold"],
			["war_blessed", "angry", "Stronger enemy hits, more gold"],
			["spellwarden", "protected", "Lower player damage, more gold"],
			["greedy", "greedy", "Cast gold, theft, and victory bonus"],
		]],
		["Special Effects", Color(1.48, 1.13, 0.72), [
			["chameleon", "changeable", "Enemy traits shift"],
			["frostbite_tax", "icy", "Faster frost, more Heat"],
		]],
	]
	for category: Array in categories:
		var choices: Array[Array] = []
		for choice: Array in category[2]:
			if MODIFIERS.eligible(MODIFIERS.definition(choice[0]), RunState.selected_biome):
				choices.append(choice)
		if choices.is_empty():
			continue
		var index := _category_choices.size()
		_category_choices.append(choices)
		var tab := _selection_button(category[0])
		var tint: Color = category[1]
		for state: String in ["normal", "hover", "pressed"]:
			var source := "hover" if state == "pressed" else state
			var style := BUTTON_THEME.get_stylebox(source, &"WordWovenActionButton").duplicate() as StyleBoxTexture
			style.modulate_color = tint
			if state == "pressed":
				style.modulate_color = Color(tint.r * 1.16, tint.g * 1.16, tint.b * 1.16)
				tab.add_theme_stylebox_override("hover_pressed", style)
			tab.add_theme_stylebox_override(state, style)
		tab.button_group = group
		tab.set_pressed_no_signal(index == 0)
		tab.custom_minimum_size.y = 38
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 18)
		tab.pressed.connect(_select_category.bind(index))
		tabs.add_child(tab)
		_category_tabs.append(tab)

	_browse_words = GridContainer.new()
	_browse_words.columns = 2
	_browse_words.custom_minimum_size.y = 72
	_browse_words.add_theme_constant_override("h_separation", 8)
	_browse_words.add_theme_constant_override("v_separation", 4)
	_browser.add_child(_browse_words)
	_show_category_choices()


func _select_category(index: int) -> void:
	if _category_index != index:
		_category_index = index
		_show_category_choices()


func _show_category_choices() -> void:
	_adjective_buttons.clear()
	for child: Node in _browse_words.get_children():
		_browse_words.remove_child(child)
		child.queue_free()
	for choice: Array in _category_choices[_category_index]:
		var word: String = choice[1]
		var button := _selection_button("%s — %s" % [word.capitalize(), choice[2]])
		button.custom_minimum_size = Vector2(0, 34)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_choose_example.bind(word))
		_browse_words.add_child(button)
		_adjective_buttons[word] = button
	# Keep both columns the same width, even for one eligible effect.
	if _adjective_buttons.size() == 1:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_browse_words.add_child(spacer)
	_update_adjective_highlight()


func _update_adjective_highlight() -> void:
	var selected := _adjective_input.text.strip_edges().to_lower()
	for word: String in _adjective_buttons:
		_adjective_buttons[word].set_pressed_no_signal(word == selected)
	for button: Button in _examples:
		button.set_pressed_no_signal(button.get_meta("adjective") == selected)


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
	_update_adjective_highlight()
	_preview.clear()
	_refresh_enemy_stats({})
	_confirm.disabled = true
	_title.text = "No modifier selected"
	_title.add_theme_color_override("font_color", GOLD)
	for line: Label in [_effect, _tradeoff, _reward_detail]:
		line.text = ""
		line.hide()
	_message.add_theme_color_override("font_color", HARMFUL)
	if not WordNet.is_ready:
		_message.add_theme_color_override("font_color", GOLD)
		_message.text = "The lexicon is opening. Please wait…"
		return
	var word: String = _adjective_input.text.strip_edges().to_lower()
	if word.is_empty():
		_message.add_theme_color_override("font_color", GOLD)
		_message.text = "Type an adjective or choose a suggestion below."
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
	_message.text = "Preview only. Arrows show base → proposed values. Confirm to apply."
	_message.add_theme_color_override("font_color", GOLD)
	_show_effect(_preview)
	_confirm.disabled = false


func _on_submit() -> void:
	_on_word_changed(_adjective_input.text)


func _show_effect(modifier: Dictionary) -> void:
	_title.text = modifier.name
	_title.add_theme_color_override("font_color", GOLD)
	_refresh_enemy_stats(modifier)
	var benefit := ""
	var drawback := ""
	match String(modifier.stat):
		"health":
			if float(modifier.factor) < 1.0:
				benefit = "Enemy has less health."
			else:
				drawback = "Enemy has more health."
		"attack":
			benefit = "Enemy deals less damage." if float(modifier.factor) < 1.0 else ""
			drawback = "Enemy deals more damage." if float(modifier.factor) > 1.0 else ""
		"player_damage":
			var factor: float = MODIFIERS.player_factor(modifier)
			if factor > 1.0:
				benefit = "Your words deal more damage."
			else:
				drawback = "Your words deal less damage."
		_:
			match String(modifier.id):
				"drowsy":
					benefit = "Enemy skips its first retaliation and every other retaliation after that."
					drawback = "Awake attacks deal 25% more damage."
				"clumsy":
					benefit = "Every third retaliation hits the enemy for half its base attack."
				"long_winded":
					benefit = "Words of 7+ letters deal 20% more damage. Shorter words grant 2 Guard."
				"echo_bound":
					benefit = "Deal 25% more damage when a word starts with the last letter of your previous cast."
				"chameleon":
					drawback = "Enemy traits change every 2 retaliations."
				"greedy":
					benefit = "+1 gold per valid cast, up to 5."
					drawback = "Enemy steals up to 2 gold every other retaliation, up to 4 total."
				"frostbite_tax":
					benefit = "Gain %d Heat per valid cast instead of %d." % [Balance.FROSTBITE_HEAT_PER_WORD, Balance.TUNDRA_COLD_HEAT_PER_WORD]
					drawback = "Frost checks every %d casts instead of %d." % [Balance.FROSTBITE_FREEZE_EVERY, Balance.TUNDRA_COLD_FREEZE_EVERY]
	_effect.text = benefit
	_effect.visible = not benefit.is_empty()
	_effect.add_theme_color_override("font_color", HELPFUL)
	_tradeoff.text = drawback
	_tradeoff.visible = not drawback.is_empty()
	_tradeoff.add_theme_color_override("font_color", HARMFUL)

	var extra: PackedStringArray = []
	if modifier.id == "greedy":
		var runtime := ModifierRuntime.new()
		runtime.id = modifier.id
		extra.append("Greedy adds +%d gold on victory" % runtime.victory_bonus())
	var relic_gold := int(RelicSystem.new().total_effect("victory_gold"))
	if relic_gold > 0:
		extra.append("Relics and talents add +%d gold on victory" % relic_gold)
	_reward_detail.text = "  •  ".join(extra)
	_reward_detail.visible = not extra.is_empty()


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
	_update_adjective_highlight()
	_adjective_input.editable = false
	_confirm.hide()
	for example: Button in _examples:
		example.disabled = true
	_browse.disabled = true
	_browse.set_pressed_no_signal(false)
	_browse.text = "Browse more adjectives"
	_browser.hide()
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
