extends Node
const CLASSIFIER = preload("res://scripts/modifiers/fate_classifier.gd")
const MODIFIERS = preload("res://scripts/modifiers/encounter_modifier.gd")
var failures: int = 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	var cases: Dictionary = {
		"weak": "doommarked", "frail": "doommarked", "strong": "titanbound", "tough": "titanbound",
		"angry": "war_blessed", "ferocious": "war_blessed", "timid": "spirit_broken", "cowardly": "spirit_broken",
		"vulnerable": "fate_exposed", "defenseless": "fate_exposed", "protected": "spellwarden", "guarded": "spellwarden",
		# Not concept anchors: these must generalize using WordNet synonyms.
		"irate": "war_blessed", "robust": "titanbound", "delicate": "doommarked", "afraid": "spirit_broken",
		"vicious": "war_blessed", "armoured": "spellwarden",
	}
	for word: String in cases:
		var result: Dictionary = CLASSIFIER.classify(word)
		print(word, " -> ", result)
		check(result.modifier_id == cases[word], "logical fate: " + word)
		for attempt: int in range(3):
			check(CLASSIFIER.select_modifier(word).id == cases[word], "reliable selection: " + word)
	for word: String in ["purple", "beautiful", "ancient", "strange", "wooden", "triangular"]:
		var result: Dictionary = CLASSIFIER.classify(word)
		print(word, " fallback -> ", result)
		check(result.modifier_id == "", "unrelated falls back: " + word)
		var rng := RandomNumberGenerator.new()
		rng.seed = 12345
		var outcomes: Dictionary = {}
		for attempt: int in range(30):
			var selected: Dictionary = CLASSIFIER.select_modifier(word, rng)
			check(not MODIFIERS.definition(selected.id).is_empty(), "fallback is an existing fate")
			outcomes[selected.id] = true
		check(outcomes.size() > 1, "fallback actually random: " + word)
	check(CLASSIFIER.classify("  WEAK  ").modifier_id == "doommarked", "case and whitespace")
	RunState.start_new_run()
	RunState.selected_biome = "tundra"
	var screen = load(ScenePaths.ENCOUNTER_MODIFIER).instantiate()
	add_child(screen)
	var before_health: int = RunState.player_health
	var before_gold: int = RunState.gold
	var before_levels: Array = RunState.deck.map(func(tile: LetterStats): return tile.level)
	screen._input.text = "quickly"
	screen._on_submit()
	check(RunState.pending_encounter_modifier.is_empty(), "non-adjective rejected before classification")
	screen._input.text = "weak"
	screen._on_submit()
	check(RunState.pending_encounter_modifier.modifier_id == "doommarked", "screen uses semantics")
	var original: Dictionary = RunState.pending_encounter_modifier.duplicate(true)
	screen._input.text = "strong"
	screen._on_submit()
	check(RunState.pending_encounter_modifier == original, "double submit cannot reclassify")
	check(RunState.word_history.is_empty(), "no combat history")
	check(RunState.player_health == before_health and RunState.gold == before_gold and RunState.encounter_index == 1, "preparation leaves run stats/progression unchanged")
	check(RunState.deck.map(func(tile: LetterStats): return tile.level) == before_levels, "preparation leaves letters unchanged")
	await get_tree().process_frame
	screen.queue_free()
	await get_tree().process_frame
	var reopened = load(ScenePaths.ENCOUNTER_MODIFIER).instantiate()
	add_child(reopened)
	check(reopened._input.text == "WEAK" and RunState.pending_encounter_modifier == original, "reopen preserves fate")
	reopened.queue_free()
	await get_tree().process_frame
	print("Fate classifier tests: ", failures, " failures")
	get_tree().quit(1 if failures else 0)
