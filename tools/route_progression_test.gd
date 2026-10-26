extends Node

const HANGMAN_RULES = preload("res://scripts/encounters/hangman_rules.gd")

var failures: int = 0


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _ready() -> void:
	check(DebugTools.has_node("Panel/Box/EncounterRow/FreeMapButton"), "F12 exposes free map selection")
	check(DebugTools.has_node("Panel/Box/HangmanRow/TierSelect"), "F12 exposes Hangman tier selection")
	RunState.start_new_run()
	RunState.selected_biome = "tundra"
	RunState.initialize_tundra_route(7319)
	check(RunState.route_graph_columns.size() == 9, "Route has a start, seven intermediate columns, and a boss")
	check(RunState.route_graph_columns[1].size() >= 2, "Opening combat immediately leads to a split")
	check(RunState.route_graph_columns[3].size() == 3, "Early route keeps three distinct branches")
	var early_lore_count: int = 0
	for key: String in RunState.route_graph_columns[3]:
		if String(RunState.route_nodes[key].content_id) == "lore_room":
			early_lore_count += 1
	check(early_lore_count == 2, "Lore appears early on two different branches")

	if not WordNet.is_ready:
		var loaded: bool = await WordNet.loading_finished
		check(loaded, "Combat word bank loads")
	for depth: int in [2, 6]:
		var puzzle: Dictionary = HANGMAN_RULES.new_puzzle(depth)
		check(not puzzle.is_empty(), "Word puzzle draws from combat lexicon")
		if puzzle.is_empty():
			continue
		var sorted_hand: Array = puzzle.hand.duplicate()
		sorted_hand.sort()
		check(puzzle.hand == sorted_hand, "Word puzzle letters are alphabetical")

	var map: Control = load(ScenePaths.ENCOUNTER_SELECT).instantiate()
	add_child(map)
	await get_tree().process_frame
	var opening: Dictionary = {}
	for node: Dictionary in map._build_tundra_route():
		if node.route_key == RunState.route_start_key:
			opening = node
	check(String(opening.get("state", "")) == "available", "Generated start appears and is selectable")
	check(String(opening.get("reveal_state", "")) == "revealed", "Current successors are fully revealed")
	map.queue_free()

	# Walk a complete route using graph neighbors. Four forced combat columns
	# must be crossed before the boss regardless of activity choices.
	var combats: int = 0
	while true:
		var available: Array[String] = []
		for key: String in RunState.route_nodes:
			if RunState.route_key_available(key):
				available.append(key)
		check(not available.is_empty(), "Route never dead-ends")
		if available.is_empty():
			break
		available.sort()
		var chosen: String = available[0]
		check(RunState.select_route_node(chosen), "Available route node can be selected")
		check(RunState.activate_pending_route_node(), "Selected destination becomes current")
		var type: String = String(RunState.current_route_node().node_type)
		if type in ["normal_combat", "elite_combat"]:
			combats += 1
		RunState.complete_current_route_node()
		if type == "boss":
			break
	check(combats >= 4, "Every complete route has at least four combats")
	check(RunState.is_boss_next(), "Complete route reaches the boss")

	DebugTools.free_map_select = true
	map = load(ScenePaths.ENCOUNTER_SELECT).instantiate()
	add_child(map)
	await get_tree().process_frame
	for button: Button in map.route_map._buttons:
		check(not button.disabled, "Free map selection exposes every generated node")
	map.queue_free()
	var hangman_key: String = _key_for_content("hangman")
	check(not hangman_key.is_empty(), "Generated route includes a relic word trial")
	check(RunState.debug_jump_to_route_node(hangman_key, 0), "Debug jump accepts generated node keys")
	check(RunState.begin_optional_encounter("hangman", hangman_key), "Debug word trial can start")
	var hangman: Variant = load(ScenePaths.HANGMAN).instantiate()
	add_child(hangman)
	var inventory_before: int = RunState.letter_inventory.size()
	hangman._finish(true)
	check(not RunState.optional_encounters.has("hangman") and RunState.letter_inventory.size() == inventory_before, "Previewed win has no committed rewards")
	DebugTools.hangman_reset_requested.emit(2)
	check(not hangman.finished and int(hangman.puzzle.tier) == 2, "F12 reset starts selected Hangman tier")
	hangman.queue_free()
	DebugTools.free_map_select = false

	# Exercise the fishing presentation using its generated route node.
	RunState.start_new_run()
	RunState.selected_biome = "tundra"
	RunState.initialize_tundra_route(7319)
	var fishing_key: String = _key_for_content("ice_fishing")
	check(RunState.debug_jump_to_route_node(fishing_key, 0), "Fishing node exists in generated build column")
	RunState.pending_route_activity = "ice_fishing"
	RunState.pending_route_key = fishing_key
	var fishing: Control = load(ScenePaths.ICE_FISHING).instantiate()
	add_child(fishing)
	await get_tree().process_frame
	var holes: int = 0
	for button: Button in [fishing.hole_one_button, fishing.hole_two_button, fishing.hole_three_button]:
		if button is IceHoleButton and button.text.is_empty():
			holes += 1
	check(holes == 3, "Fishing presents three illustrated ice holes")
	check(fishing.tutorial_panel.visible, "Fishing opens with its first-time tutorial")
	fishing._dismiss_tutorial()
	fishing._warm_word_pool.clear()
	for warm_word: String in ["warm", "hot", "heated", "sunny", "summer"]:
		fishing._warm_word_pool.append(warm_word)
	fishing._select_hole(0)
	await get_tree().process_frame
	check(fishing.word_input.has_focus(), "Fishing captures typing immediately")
	if fishing._challenge_words.size() == 1:
		fishing._challenge_words.append("hot")
	var time_before: float = fishing.word_timer.time_left
	fishing.word_input.text = fishing._challenge_words[0]
	fishing._submit_word()
	check(fishing.word_timer.time_left <= time_before, "Fishing keeps one eight-second total timer")
	fishing.queue_free()

	print("Route progression and fishing UI: %d failures" % failures)
	get_tree().quit(1 if failures else 0)


func _key_for_content(content_id: String) -> String:
	for key: String in RunState.route_nodes:
		if String(RunState.route_nodes[key].content_id) == content_id:
			return key
	return ""
