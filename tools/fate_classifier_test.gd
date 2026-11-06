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
	check(screen._examples.size() == 13, "Eligible clickable examples")
	for id: String in VOCABULARY.WORDS:
		_type(screen, VOCABULARY.WORDS[id][0])
		check(screen._preview.get("id", "") == id, "Live preview: " + id)
		check(screen._title.text == MODIFIERS.definition(id).name,
			"Preview modifier name: " + id)
		var entry: Dictionary = MODIFIERS.definition(id)
		check(screen._effect_description(entry) == entry.selection_effect, "Effect description: " + id)
		check(screen._effect.text.contains("Reward: " + MODIFIERS.reward_description(entry)), "Live reward preview: " + id)
		var numbers := RegEx.new()
		numbers.compile("[0-9%+−→]")
		check(numbers.search(screen._effect_description(entry)) == null, "Selection effect has no statistics: " + id)
		check(not screen._effect.text.contains(entry.effect), "Numerical combat text is not exposed in preparation: " + id)
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
	check(screen._effect_description(screen._preview) == "Frail Enemy", "Preview uses descriptive enemy weakness")
	check(screen._effect.text.contains("Decreased Gold"), "Easier preview shows reduced reward")
	_type(screen, "strong")
	check(screen._preview.id == "titanbound", "Edit replaces previous preview")
	for word: String in ["purple", "quickly", "weak!", ""]:
		_type(screen, word)
		screen._on_confirm()
		check(screen._preview.is_empty() and screen._confirm.disabled,
			"Edit clears stale preview: " + word)
		check(screen._effect.text.is_empty(), "Clears stale effect and reward: " + word)
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
	screen._examples[0].pressed.emit()
	check(screen._adjective_input.text == "strong"
		and screen._preview.id == "titanbound",
		"Example click updates input and preview")
	_type(screen, "weak")
	screen._adjective_input.text_submitted.emit("weak")
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
	check(forest._examples.size() == 12, "Forest hides Tundra example")
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
