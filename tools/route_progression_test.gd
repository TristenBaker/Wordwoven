extends Node

var failures: int = 0


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _ready() -> void:
	RunState.start_new_run()
	RunState.selected_biome = "tundra"
	RunState.ensure_tundra_route_plan()
	check(RunState.route_graph_columns.size() == 8, "Route has seven rooms and a boss")
	check(RunState.route_graph_columns[1].size() == 2, "Opening fight immediately splits")

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
