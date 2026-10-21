extends Node

const HANGMAN_RULES = preload("res://scripts/encounters/hangman_rules.gd")

var failures: int = 0


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _ready() -> void:
	check(DebugTools.has_node("Panel/Box/EncounterRow/AutoKillButton"), "F12 owns Dev Auto Kill")
	check(DebugTools.has_node("Panel/Box/EncounterRow/FreeMapButton"), "F12 exposes free map selection")
	check(DebugTools.has_node("Panel/Box/HangmanRow/TierSelect"), "F12 exposes Hangman tier selection")
	check(DebugTools.has_node("Panel/Box/HangmanRow/ResetButton"), "F12 exposes Hangman reset")
	RunState.start_new_run()
	RunState.selected_biome = "tundra"
	RunState.ensure_tundra_route_plan()
	check(RunState.route_graph_columns.size() == 8, "Route has seven rooms and a boss")
	check(RunState.route_graph_columns[1].size() >= 2, "Opening fight immediately splits")
	var hangman_depth: int = -1
	for column_index: int in RunState.route_graph_columns.size():
		if RunState.route_graph_columns[column_index].has("activity_hangman"):
			hangman_depth = column_index + 1
	check(hangman_depth in [2, 4, 6], "The word puzzle can appear at different run depths")
	if not WordNet.is_ready:
		var lexicon_loaded: bool = await WordNet.loading_finished
		check(lexicon_loaded, "Combat word bank loads")
	for depth: int in [2, 4, 6]:
		var puzzle: Dictionary = HANGMAN_RULES.new_puzzle(depth)
		check(not puzzle.is_empty(), "Word puzzle draws from combat lexicon")
		if puzzle.is_empty():
			continue
		var sorted_hand: Array = puzzle.hand.duplicate()
		sorted_hand.sort()
		check(puzzle.hand == sorted_hand, "Word puzzle letters are alphabetical")
		var answer: String = HANGMAN_RULES.expected_letters(puzzle)
		var validator := WordValidator.new()
		add_child(validator)
		var playable: bool = false
		for pos: String in WordNet.parts_of_speech(String(puzzle.word)):
			if validator.validate(String(puzzle.word), pos).valid:
				playable = true
				break
		check(playable, "Spelling target is playable in combat")
		validator.queue_free()
		for letter: String in answer:
			check(puzzle.hand.count(letter) >= answer.count(letter), "Word puzzle hand contains every required letter")

	var forced_combat_depths: Array[int] = []
	for column_index: int in RunState.route_graph_columns.size() - 1:
		var column: Array = RunState.route_graph_columns[column_index]
		var combat_only: bool = not column.is_empty()
		for key: String in column:
			combat_only = combat_only and key.begins_with("combat_")
		if combat_only:
			forced_combat_depths.append(column_index + 1)
	check(forced_combat_depths.size() >= 4, "Every path contains at least four fights")

	# Resolve the opener, then take the first side quest. It must advance route
	# depth without also incrementing the combat counter.
	RunState.record_route_choice(1, "combat_1_0")
	RunState.advance_encounter()
	var first_activity_key: String = String(RunState.route_graph_columns[1][0])
	_resolve_activity(first_activity_key)
	check(RunState.route_depth == 3, "A side quest advances to the next map layer")
	check(RunState.encounter_index == 2, "A side quest does not count as a fight")

	# Continue by preferring activities whenever a branch allows one. Forced
	# combat layers must still produce four victories before the boss.
	while RunState.route_depth < RunState.route_graph_columns.size():
		var predecessor: String = RunState.route_predecessor_for_stage(RunState.route_depth)
		var choices: Array = RunState.route_edges.get(predecessor, [])
		check(not choices.is_empty(), "Current room has a forward path")
		if choices.is_empty():
			break
		var selected: String = String(choices[0])
		for choice: String in choices:
			if choice.begins_with("activity_"):
				selected = choice
				break
		if selected.begins_with("activity_"):
			_resolve_activity(selected)
		else:
			RunState.record_route_choice(RunState.route_depth, selected)
			RunState.advance_encounter()

	check(RunState.is_boss_next(), "Route reaches the boss node")
	check(RunState.encounter_index - 1 >= 4, "At least four combats precede the boss")
	DebugTools.free_map_select = true
	var map: Control = load(ScenePaths.ENCOUNTER_SELECT).instantiate()
	add_child(map)
	await get_tree().process_frame
	for button: Button in map.route_map._buttons:
		check(not button.disabled, "Free map selection exposes every route node")
	map.queue_free()
	var puzzle_depth: int = int(RunState.route_activity_stages.hangman)
	check(RunState.debug_jump_to_route_node("activity_hangman", puzzle_depth), "Debug jump accepts the word puzzle")
	check(RunState.route_depth == puzzle_depth and RunState.optional_encounter_available("hangman"), "Debug jump makes the selected room playable")
	check(RunState.begin_optional_encounter("hangman", "activity_hangman"), "Debug puzzle can start")
	var hangman: Variant = load(ScenePaths.HANGMAN).instantiate()
	add_child(hangman)
	var deck_before_reset: int = RunState.deck.size()
	hangman._finish(true)
	check(not RunState.optional_encounters.has("hangman") and RunState.deck.size() == deck_before_reset, "Previewed win has no committed rewards")
	DebugTools.hangman_reset_requested.emit(2)
	check(not hangman.finished and int(hangman.puzzle.tier) == 2, "F12 reset starts selected Hangman tier")
	check(hangman.pending_rewards.is_empty() and RunState.deck.size() == deck_before_reset, "Reset discards unclaimed rewards")
	check(hangman.deadline_ms > Time.get_ticks_msec(), "Hangman reset restarts the timer")
	DebugTools.hangman_reset_requested.emit(-1)
	check(int(hangman.puzzle.tier) == HANGMAN_RULES.tier_for_depth(puzzle_depth), "Route tier option restores automatic difficulty")
	hangman.queue_free()
	check(RunState.debug_jump_to_route_node("boss", RunState.route_graph_columns.size()), "Debug jump accepts the boss")
	check(RunState.is_boss_next() and RunState.encounter_index == RunState.ENCOUNTERS_PER_RUN, "Boss jump sets combat stage")
	DebugTools.free_map_select = false

	var fishing: Control = load(ScenePaths.ICE_FISHING).instantiate()
	add_child(fishing)
	await get_tree().process_frame
	var holes: int = 0
	for button: Button in [fishing.hole_one_button, fishing.hole_two_button, fishing.hole_three_button]:
		if button is IceHoleButton and button.text.is_empty():
			holes += 1
	check(holes == 3, "Fishing presents three illustrated ice holes")
	fishing.queue_free()

	print("Route progression and fishing UI: %d failures" % failures)
	get_tree().quit(1 if failures else 0)


func _resolve_activity(route_key: String) -> void:
	var activity_id: String = route_key.trim_prefix("activity_")
	RunState.pending_route_activity = activity_id
	RunState.pending_route_key = route_key
	if activity_id == "ice_fishing":
		RunState.fishing_hole_chosen = 0
	else:
		RunState.optional_encounters[activity_id] = {"skipped": true}
	RunState.finish_route_activity()
