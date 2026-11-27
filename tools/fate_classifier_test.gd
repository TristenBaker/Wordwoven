extends Node
## Exhaustive vocabulary, preparation lifecycle, and combat handoff checks.
const CLASSIFIER: Script = preload("uid://ms42avqgikf")
const MODIFIERS: Script = preload("uid://dubtvvoj1ve87")
const VOCABULARY: Script = preload("uid://dlxn4nft028ba")
var failures: int = 0
var checks: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	if not WordNet.is_ready:
		check(false, "WordNet database loaded")
		get_tree().quit(1)
		return
	_test_vocabulary()
	await _test_preparation()
	await _test_combat_handoff()
	await _test_enemy_summaries()
	await _test_continue_transition()
	await get_tree().create_timer(0.2).timeout
	print("Fate classifier: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_vocabulary() -> void:
	var validator: WordValidator = WordValidator.new()
	add_child(validator)
	var seen: Dictionary[String, String] = {}
	check(VOCABULARY.WORDS.size() == 13, "All thirteen categories")
	for entry: Dictionary in MODIFIERS.ENTRIES:
		check(VOCABULARY.WORDS.has(entry.id), "Vocabulary: " + entry.id)
	for id: String in VOCABULARY.WORDS:
		check(not MODIFIERS.definition(id).is_empty(), "Known modifier: " + id)
		for word: String in VOCABULARY.WORDS[id]:
			check(not seen.has(word), "Unique assignment: " + word)
			seen[word] = id
			check(word == word.strip_edges().to_lower(), "Normalized: " + word)
			check(validator.validate(word, "a").valid,
				"Valid adjective: " + word)
			for biome: String in ["forest", "tundra"]:
				RunState.selected_biome = biome
				var eligible: bool = MODIFIERS.eligible(
					MODIFIERS.definition(id), biome
				)
				var result: Dictionary = CLASSIFIER.classify(word)
				var status: String = "supported" if eligible else "restricted"
				check(result.status == status,
					"Eligibility: %s in %s" % [word, biome])
				for attempt: int in range(3):
					var chosen: Dictionary = CLASSIFIER.select_modifier(word)
					check(chosen.get("id", "") == (id if eligible else ""),
						"Deterministic selection: " + word)
			RunState.selected_biome = "tundra"
			var padded: String = " \t" + word.to_upper() + "\n"
			check(CLASSIFIER.classify(padded).modifier_id == id,
				"Capitalization and whitespace: " + word)
	RunState.selected_biome = "tundra"
	for word: String in [
		"purple", "beautiful", "ancient", "triangular", "wooden",
	]:
		check(validator.validate(word, "a").valid, "Valid unsupported: " + word)
		check(CLASSIFIER.classify(word).status == "unsupported",
			"Explicit unsupported result: " + word)
		for attempt: int in range(30):
			check(CLASSIFIER.select_modifier(word).is_empty(),
				"No random fallback: " + word)
	for word: String in ["", "a", "weak!", "asdfghjk", "quickly", "ice cold"]:
		check(not validator.validate(word, "a").valid, "Invalid: " + word)
		check(CLASSIFIER.select_modifier(word).is_empty(),
			"Invalid never selects: " + word)
	print("Validated %d unique WordNet adjectives" % seen.size())
	validator.queue_free()


func _type(screen: Control, word: String) -> void:
	screen._adjective_input.text = word
	screen._adjective_input.text_changed.emit(word)


func _dispose(node: Node) -> void:
	# Release looping scene music before a headless test shuts down audio.
	for audio: AudioStreamPlayer in node.find_children(
		"*", "AudioStreamPlayer", true, false
	):
		audio.stop()
		audio.stream = null
	node.queue_free()


func _test_preparation() -> void:
	RunState.start_new_run()
	RunState.selected_biome = "tundra"
	var screen: Control = load(ScenePaths.ENCOUNTER_MODIFIER).instantiate()
	add_child(screen)
	var before_health: int = RunState.player_health
	var before_gold: int = RunState.gold
	var before_levels: Array = RunState.deck.map(
		func(tile: LetterStats) -> int: return tile.level
	)
	check(screen._examples.size() == 3 and not screen._browser.visible, "Three suggestions and a closed browser")
	check(screen._adjective_input.has_focus() and screen._adjective_input.caret_blink, "Adjective input starts focused with a blinking caret")
	check(screen.find_children("*", "ProgressBar", true, false).is_empty(), "Preparation shows no player health panel")
	screen._browse.button_pressed = true
	check(screen._browser.visible and screen._category_tabs.size() == 4, "Browser expands with four purpose tabs")
	var browsed := {}
	var category_colors := {}
	for category in screen._category_tabs.size():
		var tab: Button = screen._category_tabs[category]
		tab.button_pressed = true
		tab.pressed.emit()
		var normal := tab.get_theme_stylebox("normal") as StyleBoxTexture
		var hover := tab.get_theme_stylebox("hover") as StyleBoxTexture
		var selected := tab.get_theme_stylebox("pressed") as StyleBoxTexture
		check(screen._category_index == category and tab.button_pressed and selected.texture == hover.texture and selected.modulate_color != hover.modulate_color and normal.texture != hover.texture, "Tab retains ornamental art and distinguishes all states")
		category_colors[normal.modulate_color] = true
		await get_tree().process_frame
		await get_tree().process_frame
		var viewport: Rect2 = get_viewport().get_visible_rect()
		var panel: Control = screen.find_child("PreparationPanel", true, false)
		check(viewport.encloses(panel.get_global_rect()), "Expanded browser fits")
		check(screen._adjective_buttons.size() == screen._category_choices[category].size(), "One button per choice")
		for choice: Array in screen._category_choices[category]:
			var id: String = choice[0]
			var word: String = choice[1]
			var button: Button = screen._adjective_buttons[word]
			check(not browsed.has(id) and button.text.contains(choice[2]), "Each effect appears once with a gameplay label")
			browsed[id] = true
			check(screen._browse_words.get_global_rect().encloses(button.get_global_rect()), "Choice remains fully inside the grid")
			button.pressed.emit()
			check(screen._adjective_input.text == word and screen._preview.id == id and button.button_pressed, "Representative previews and highlights the expected effect")
	check(browsed.size() == 13 and category_colors.size() == 1, "All Tundra effects use one unified category tint")
	screen._browse.button_pressed = false
	for id: String in VOCABULARY.WORDS:
		for word: String in VOCABULARY.WORDS[id]:
			_type(screen, word)
			check(screen._preview.get("id", "") == id, "Free-form synonym remains available: " + word)
	for id: String in VOCABULARY.WORDS:
		_type(screen, VOCABULARY.WORDS[id][0])
		check(screen._preview.get("id", "") == id, "Live preview: " + id)
		check(screen._title.text == MODIFIERS.definition(id).name,
			"Preview modifier name: " + id)
		var plain_language := {
			"doommarked": "Enemy has less health.",
			"titanbound": "Enemy has more health.",
			"spirit_broken": "Enemy deals less damage.",
			"war_blessed": "Enemy deals more damage.",
			"fate_exposed": "Your words deal more damage.",
			"spellwarden": "Your words deal less damage.",
		}
		if plain_language.has(id):
			check(screen._effect.text == plain_language[id] or screen._tradeoff.text == plain_language[id], "Plain-language modifier description: " + id)
		check(not screen._effect.text.contains("before rounding") and not screen._tradeoff.text.contains("before rounding"), "No rounding jargon in selection description: " + id)
		var entry: Dictionary = MODIFIERS.definition(id)
		var base_gold: int = screen._base_spawn.gold
		var gold: int = MODIFIERS.victory_gold(base_gold, entry)
		var gold_text := "Victory Gold\n%d" % base_gold
		if gold != base_gold:
			gold_text += " → %d" % gold
		check(screen._enemy_stats.gold.get_parsed_text() == gold_text, "Live numerical reward preview: " + id)
		check(not screen._confirm.disabled, "Can confirm: " + id)
		check(RunState.pending_encounter_modifier.is_empty(),
			"Preview does not commit: " + id)
		await get_tree().process_frame
		var panel: Control = screen.find_child("PreparationPanel", true, false)
		var viewport: Rect2 = get_viewport().get_visible_rect()
		check(viewport.encloses(panel.get_global_rect()),
			"Preparation fits desktop viewport: " + id)
		check(screen._effect.get_line_count() <= 3,
			"Effect text fits reserved space: " + id)
	_type(screen, "weak")
	var original_health: int = screen._base_spawn.health
	var lower_health: int = MODIFIERS.apply_spawn(screen._base_spawn, screen._preview).health
	check(screen._enemy_stats.health.get_parsed_text() == "HP\n%d → %d" % [original_health, lower_health], "Weak previews actual enemy health")
	_type(screen, "strong")
	check(screen._preview.id == "titanbound", "Edit replaces previous preview")
	for word: String in ["purple", "quickly", "weak!", ""]:
		_type(screen, word)
		screen._on_confirm()
		check(screen._preview.is_empty() and screen._confirm.disabled,
			"Edit clears stale preview: " + word)
		check(screen._effect.text.is_empty() and screen._tradeoff.text.is_empty() and screen._enemy_stats.gold.get_parsed_text() == "Victory Gold\n%d" % screen._base_spawn.gold and not screen._enemy_stats.health.text.contains("→"), "Clears stale effects and restores neutral enemy stats: " + word)
		check(RunState.pending_encounter_modifier.is_empty(),
			"Invalid/unsupported cannot commit: " + word)
	_type(screen, "beautiful")
	check(screen._message.text.contains("no assigned combat modifier"),
		"Explains valid unsupported adjective")
	RunState.selected_biome = "forest"
	_type(screen, "frigid")
	check(screen._message.text.contains("only in Tundra"), "Biome guidance")
	check(screen._preview.is_empty(), "Restricted preview unavailable")
	screen._on_confirm()
	check(RunState.pending_encounter_modifier.is_empty(),
		"Restriction enforced")
	RunState.selected_biome = "tundra"
	screen._examples[2].pressed.emit()
	check(screen._adjective_input.text == "strong"
		and screen._preview.id == "titanbound",
		"Example click updates input and preview")
	_type(screen, "weak")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	get_viewport().push_input(enter, true)
	check(screen._adjective_input.has_focus(), "Enter refreshes the preview and keeps input focus")
	check(RunState.pending_encounter_modifier.is_empty(),
		"Enter does not accidentally confirm")
	# Programmatic text changes bypass signals; confirmation must revalidate.
	screen._adjective_input.text = "  STRONG  "
	screen._on_confirm()
	var original: Dictionary = (
		RunState.pending_encounter_modifier.duplicate(true)
	)
	check(original.get("modifier_id", "") == "titanbound"
		and original.get("word", "") == "strong",
		"Confirm current normalized text")
	check(not screen._adjective_input.editable and screen._continue.visible,
		"Confirmed selection locked and combat offered")
	screen._on_confirm()
	screen._examples[1].pressed.emit()
	check(RunState.pending_encounter_modifier == original,
		"Double confirmation and examples cannot overwrite commitment")
	check(RunState.word_history.is_empty(),
		"Preparation adds no combat history")
	check(RunState.player_health == before_health
		and RunState.gold == before_gold and RunState.encounter_index == 1,
		"Preparation does not change run stats")
	check(RunState.deck.map(func(tile: LetterStats) -> int: return tile.level)
		== before_levels, "Preparation does not change letters")
	_dispose(screen)
	await get_tree().process_frame
	var reopened: Control = load(ScenePaths.ENCOUNTER_MODIFIER).instantiate()
	add_child(reopened)
	check(reopened._adjective_input.text == "STRONG" and reopened._committed
		and RunState.pending_encounter_modifier == original,
		"Reopening preserves confirmed fate")
	_dispose(reopened)
	await get_tree().process_frame
	RunState.start_new_run()
	RunState.selected_biome = "forest"
	var forest: Control = load(ScenePaths.ENCOUNTER_MODIFIER).instantiate()
	add_child(forest)
	var shown: Array = []
	for category: Array in forest._category_choices:
		for choice: Array in category:
			shown.append(choice[0])
	check(shown.size() == 12 and not shown.has("frostbite_tax"), "Forest browser omits Frostbite Tax")
	_dispose(forest)
	await get_tree().process_frame


func _test_combat_handoff() -> void:
	for entry: Dictionary in MODIFIERS.ENTRIES:
		RunState.start_new_run()
		RunState.selected_biome = "tundra"
		RunState.next_enemy_id = "frostfang_wolf"
		var screen: Control = load(ScenePaths.ENCOUNTER_MODIFIER).instantiate()
		add_child(screen)
		_type(screen, VOCABULARY.WORDS[entry.id][0])
		screen._on_confirm()
		var combat: Control = load(ScenePaths.COMBAT).instantiate()
		add_child(combat)
		check(combat._encounter_modifier.get("id", "") == entry.id,
			"Confirmed adjective reaches combat: " + entry.id)
		check(RunState.pending_encounter_modifier.is_empty(),
			"Commitment consumed once: " + entry.id)
		var panel: Control = combat.get_node("Layout/ActiveModifierPanel")
		check(panel.name_label.text == "Modifier: " + entry.name,
			"Active display preserved: " + entry.id)
		_dispose(combat)
		_dispose(screen)
		await get_tree().process_frame


func _test_enemy_summaries() -> void:
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EnemyFactory.ENEMIES_DATA_PATH))
	for id: String in definitions:
		var data: Dictionary = definitions[id]
		var biome: String = data.get("biome", "forest")
		var stage: int = [0, 1, 3, 5, RunState.ENCOUNTERS_PER_RUN][data.tier]
		if biome == "tundra" and id not in ["frostfang_wolf", "frost_wyrm"]:
			stage = 3
		await _verify_summary(id, biome, stage)
	await _verify_summary("tundra_behemoth", "tundra", 4, true)
	await _verify_summary("goblin", "forest", 8, false, true)


func _verify_summary(id: String, biome: String, stage: int, elite := false, endless := false) -> void:
	RunState.start_new_run(RunState.RunMode.ENDLESS if endless else RunState.RunMode.STORY)
	RunState.selected_biome = biome
	RunState.encounter_index = stage
	RunState.next_enemy_id = id
	if elite:
		RunState.route_current_key = "preview_elite"
		RunState.route_nodes[RunState.route_current_key] = {"node_type": "elite_combat", "content_id": id}
	var screen: Control = load(ScenePaths.ENCOUNTER_MODIFIER).instantiate()
	add_child(screen)
	var base: Dictionary = screen._base_spawn
	var context: String = id + (" elite" if elite else (" endless" if endless else ""))
	check(base.id == id and base.elite == elite, "Preparation resolves the requested enemy: " + context)
	check(screen._portrait.texture != null and screen._portrait.texture.get_size().x > 0.0 and screen._portrait.texture.get_size().y > 0.0, "Valid cropped portrait: " + context)
	check((screen._portrait.material != null) == bool(base.black_matte), "Portrait uses the matte only when required: " + context)
	check(screen._enemy_name.text == base.name and screen._enemy_stats.health.get_parsed_text() == "HP\n%d" % base.health and screen._enemy_stats.attack.get_parsed_text() == "Attack\n%d" % base.attack and screen._enemy_stats.gold.get_parsed_text() == "Victory Gold\n%d" % base.gold, "Summary uses encounter-scaled stats: " + context)
	check(screen._enemy_affinities.visible == not base.affinities.is_empty(), "Affinity row only appears when meaningful: " + context)
	var word := "weak"
	_type(screen, word)
	screen._on_confirm()
	var combat: Control = load(ScenePaths.COMBAT).instantiate()
	add_child(combat)
	var adjusted: Dictionary = MODIFIERS.apply_spawn(base, MODIFIERS.definition("doommarked"))
	check(combat.enemy.enemy_id == id and combat.enemy._max_health == adjusted.health and combat.enemy.attack == adjusted.attack and combat.enemy.gold_reward == base.gold and combat.enemy.affinities == base.affinities, "Summary matches the actual combat handoff: " + context)
	_dispose(combat)
	_dispose(screen)
	await get_tree().process_frame


func _test_continue_transition() -> void:
	# Keep the test runner alive while the button performs a real scene change.
	get_tree().current_scene = null
	RunState.start_new_run()
	RunState.selected_biome = "forest"
	RunState.next_enemy_id = "goblin"
	var screen: Control = load(ScenePaths.ENCOUNTER_MODIFIER).instantiate()
	add_child(screen)
	screen._examples[0].pressed.emit()
	screen._confirm.pressed.emit()
	check(screen._continue.visible and RunState.pending_encounter_modifier.modifier_id == "doommarked", "Explicit confirmation unlocks Enter Combat")
	screen._continue.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var combat := get_tree().current_scene
	check(is_instance_valid(combat) and combat.scene_file_path == ScenePaths.COMBAT and combat._encounter_modifier.id == "doommarked", "Enter Combat changes scene and carries the same modifier")
	if is_instance_valid(combat):
		_dispose(combat)
	_dispose(screen)
	await get_tree().process_frame
