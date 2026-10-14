extends Node

const TundraEventScript = preload("res://scripts/encounters/tundra_events.gd")
## End-to-end scene transitions, detours, rewards, animation, and six-fight progression.
var failures: int = 0

func _valid_word(id: String) -> String:
	if id == "treasure_chest":
		var state: Dictionary = TundraEventScript.progress(id)
		return state.locks[int(state.lock_index)].anchors[0]
	return "torch" if id == "frozen_traveler" else "carefully"

func _finish_event(event: Control) -> void:
	for turn: int in 6:
		if event._finished:
			break
		if event.next_button.visible:
			event._next_round()
		if event.encounter_id == "icy_portal":
			event._choose(0)
		event.input.text = "  " + _valid_word(event.encounter_id).to_upper() + "  "
		event.input.text_submitted.emit(event.input.text)
	check(event._finished, "Mini-game completes: " + event.encounter_id)

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _go(path: String) -> Node:
	get_tree().change_scene_to_file(path)
	await _frames()
	return get_tree().current_scene

func _wait(path: String) -> Node:
	var deadline: int = Time.get_ticks_msec() + 10000
	while get_tree().current_scene == null or get_tree().current_scene.scene_file_path != path:
		if Time.get_ticks_msec() > deadline:
			check(false, "Timed out reaching " + path)
			get_tree().quit(1)
			return null
		await get_tree().process_frame
	await _frames()
	return get_tree().current_scene

func _setup_between_fights() -> void:
	RunState.start_new_run()
	RunState.selected_biome = "tundra"
	RunState.encounter_index = 2
	RunState.completed_encounters.append(1)
	RunState.defeated_enemy_ids.append("frostfang_wolf")

func _run() -> void:
	get_tree().current_scene = null
	if not WordNet.is_ready:
		await WordNet.loading_finished
	for id: String in TundraEventScript.IDS:
		RunState.start_new_run()
		RunState.selected_biome = "tundra"
		RunState.ensure_tundra_route_plan()
		var depth: int = int(RunState.route_activity_stages[id])
		RunState.route_depth = depth
		var route_key: String = "activity_" + id
		check(RunState.begin_optional_encounter(id, route_key), "Side quest opens: " + id)
		var event: Control = await _go(ScenePaths.TUNDRA_EVENT)
		check(event != null and event.encounter_id == id, "Correct side quest scene: " + id)
		_finish_event(event)
		check(RunState.optional_encounters.has(id), "Side quest records its result: " + id)
		event.continue_button.pressed.emit()
		await _wait(ScenePaths.ENCOUNTER_SELECT)
		check(RunState.route_depth == depth + 1, "Side quest advances one map room: " + id)
		check(RunState.encounter_index == 1, "Side quest does not consume a fight: " + id)
	var music: AudioStreamPlayer = get_tree().root.get_node_or_null("TundraSideQuestMusic")
	if music != null:
		music.stop()
		music.queue_free()
	print("Tundra optional encounters: %d failures" % failures)
	get_tree().quit(1 if failures else 0)


func _run_legacy() -> void:
	# Keep this runner alive when exercising actual scene navigation.
	get_tree().current_scene = null
	if not WordNet.is_ready:
		await WordNet.loading_finished
	_setup_between_fights()
	RunState.player_health = 23
	RunState.gold = 7
	RunState.begin_optional_encounter("treasure_chest")
	var skipped = await _go(ScenePaths.TUNDRA_EVENT)
	skipped.skip.pressed.emit()
	check(RunState.player_health == 23 and RunState.gold == 7 and RunState.optional_encounters.treasure_chest.skipped, "Skip awards nothing and consumes visit")
	skipped.continue_button.pressed.emit()
	var map = await _wait(ScenePaths.ENCOUNTER_SELECT)
	check(RunState.encounter_index == 2 and not RunState.optional_encounter_available("treasure_chest"), "Skip returns to same slot without farming")
	RunState.start_new_run()
	check(RunState.optional_encounters.is_empty() and RunState.optional_encounter_progress.is_empty() and RunState.pending_optional_encounter.is_empty(), "New run clears visits and pending event")
	RunState.selected_biome = "tundra"
	RunState.ensure_tundra_route_plan()
	if RunState.route_required_activity == "ice_fishing":
		RunState.fishing_hole_chosen = 0
	else:
		RunState.optional_encounters[RunState.route_required_activity] = {"skipped": true}
	check(not RunState.begin_optional_encounter("frozen_traveler"), "No detours before first fight")
	var fought: Array[String] = []
	for stage: int in range(1, 7):
		map = await _go(ScenePaths.ENCOUNTER_SELECT)
		check(RunState.encounter_index == stage, "Monster slot preserved: %d" % stage)
		var route_activity: String = RunState.route_activity_for_stage(stage)
		if not route_activity.is_empty() \
				and not RunState.route_activity_resolved(route_activity):
			RunState.route_bypassed_activities[route_activity] = true
			map = await _go(ScenePaths.ENCOUNTER_SELECT)
		if false and stage == 2:
			check(not get_tree().root.has_node("TundraSideQuestMusic"), "Entering map is silent")
			check(map.route_map.has_node("Activity_ice_fishing"), "Fishing is a route branch")
			check(map.route_map.has_node("Activity_frozen_traveler"), "Side quest is a route branch")
			var stage_before_fishing: int = RunState.encounter_index
			map.route_map.get_node("Activity_ice_fishing").pressed.emit()
			var fishing = await _wait(ScenePaths.ICE_FISHING)
			check(RunState.pending_route_activity == "ice_fishing", "Fishing remembers route origin")
			fishing.return_button.pressed.emit()
			map = await _wait(ScenePaths.ENCOUNTER_SELECT)
			check(RunState.encounter_index == stage_before_fishing, "Fishing cannot replace a combat")
			for id: String in ["frozen_traveler"]:
				var next_enemy: String = RunState.next_enemy_id
				var pending_fate: Dictionary = RunState.pending_encounter_modifier.duplicate(true)
				var activity_path: String = "Activity_" + id
				check(map.route_map.has_node(activity_path), "Rotating route reveals " + id)
				var card: Button = map.route_map.get_node(activity_path)
				check(card.has_node("PreviewRow/EnemyText/ActivitySubtitle"), "Side quest explains its route")
				card.pressed.emit()
				var event = await _wait(ScenePaths.TUNDRA_EVENT)
				var music: AudioStreamPlayer = get_tree().root.get_node("TundraSideQuestMusic")
				check(music.playing and music.bus == &"Music" and music.stream.resource_path.ends_with("2 - Crystal Veil (Loop).mp3"), "Each side quest starts Crystal Veil on Music bus")
				load("res://scripts/encounters/tundra_side_quest_music.gd").ensure_playing(get_tree())
				check(get_tree().root.get_node("TundraSideQuestMusic") == music, "Repeated music request preserves the single player")
				var frame_count: int = 4 if id == "frozen_traveler" else 1
				check(event.encounter_id == id and event._frames.size() == frame_count, "Correct animation frames: " + id)
				check(event.is_processing() == (frame_count > 1), "Only traveler animation plays: " + id)
				event.set_process(false)
				event._elapsed = 0.0
				var frame_size: Vector2 = event._frames[0].get_size()
				var sprite_rect: Rect2 = event.sprite.get_global_rect()
				for frame: int in 5:
					event._process(0.0 if frame == 0 else 0.401)
					check(event.sprite.texture == event._frames[frame % frame_count] and event.sprite.texture.get_size() == frame_size and event.sprite.get_global_rect() == sprite_rect, "Stable sprite playback: " + id)
					event._elapsed = float(frame % frame_count) * 0.4
				var initial_hp: int = RunState.player_health
				var initial_gold: int = RunState.gold
				var input_rect: Rect2 = event.input.get_global_rect()
				for invalid: String in ["", "zzzzzzz", "beautiful" if id != "treasure_chest" else "quickly"]:
					event.input.text = invalid
					event.submit.pressed.emit()
					await _frames()
					check(not event._finished and not RunState.optional_encounters.has(id), "Invalid word does not consume encounter")
					check(RunState.player_health == initial_hp and RunState.gold == initial_gold, "Invalid word awards nothing")
					check(event.feedback.text.contains(WordNet.pos_name(String(event.data.pos))), "Error explains expected word type")
					check(event.input.get_global_rect() == input_rect, "Validation does not shift input")
				if id == "icy_portal":
					event._choose(0)
				event.input.text = _valid_word(id)
				event._submit()
				check(not event._finished and event.next_button.visible, "First word shows feedback without ending game")
				check(RunState.player_health == initial_hp and RunState.gold == initial_gold, "Rewards wait for final round")
				var saved: Dictionary = TundraEventScript.progress(id).duplicate(true)
				event = await _go(ScenePaths.TUNDRA_EVENT)
				check(TundraEventScript.progress(id) == saved and event.next_button.visible, "Reopening resumes progress and feedback")
				_finish_event(event)
				check(event.dialogue.text.contains(RunState.optional_encounters[id].word) and event.continue_button.visible, "Last word appears in result: " + id)
				var hp: int = RunState.player_health
				var gold: int = RunState.gold
				event._submit()
				event._skip()
				check(RunState.player_health == hp and RunState.gold == gold, "Repeated input cannot repeat reward")
				await _frames()
				check(event.continue_button.get_global_rect().end.y <= event.get_viewport_rect().end.y, "Result UI fits viewport")
				event.continue_button.pressed.emit()
				map = await _wait(ScenePaths.ENCOUNTER_SELECT)
				check(not get_tree().root.has_node("TundraSideQuestMusic"), "Returning to map stops and removes side quest music")
				check(RunState.encounter_index == stage and RunState.next_enemy_id == next_enemy and RunState.pending_encounter_modifier == pending_fate, "Detour preserves monster and adjective state")
			check(map.route_map.get_node("Activity_frozen_traveler").disabled, "Completed side quests remain visible but cannot repeat")
		var combat_button: Button = _available_combat_button(map)
		check(combat_button != null, "Current combat branch is selectable")
		combat_button.pressed.emit()
		var preparation = await _wait(ScenePaths.ENCOUNTER_MODIFIER)
		preparation._input.text = "strong"
		preparation._submit.pressed.emit()
		await _frames()
		preparation._continue.pressed.emit()
		var combat = await _wait(ScenePaths.COMBAT)
		check(not get_tree().root.has_node("TundraSideQuestMusic") and combat.get_node("BattleMusic").playing, "Combat owns music without side quest overlap")
		var id: String = combat.enemy.enemy_id
		fought.append(id)
		check(combat._encounter_modifier.size() > 0 and combat.timer_label.text.contains("Quick-cast"), "Modifier and quick-cast preserved")
		check(combat.cold.enabled and combat.cold.frozen.is_empty(), "Existing cold reset preserved")
		check(id == "frostfang_wolf" if stage == 1 else (id == "frost_wyrm" if stage == 6 else id in EnemyFactory.TUNDRA_REGULARS), "Required Tundra monster: %d" % stage)
		combat.dev_kill_button.pressed.emit()
		var completion = await _wait(ScenePaths.FIGHT_COMPLETION)
		completion.continue_button.pressed.emit()
		var powers = await _wait(ScenePaths.POWER_SELECT)
		powers.choice_buttons[0].pressed.emit()
		powers.continue_button.pressed.emit()
		var loot = await _wait(ScenePaths.LOOT_DROP)
		loot.continue_button.pressed.emit()
		await _wait(ScenePaths.RUN_WON if stage == 6 else ScenePaths.TAVERN)
	check(fought.size() == 6 and RunState.defeated_enemy_ids.size() == 6 and RunState.completed_encounters.size() == 6, "All six distinct fights and boss completed")
	check(not RunState.optional_encounter_available("icy_portal"), "No optional encounters after boss")
	_setup_between_fights()
	RunState.selected_biome = "forest"
	check(not RunState.optional_encounter_available("treasure_chest"), "Other biomes unchanged")
	get_tree().current_scene.queue_free()
	get_tree().current_scene = null
	await _frames()
	await _check_layouts()
	var music: AudioStreamPlayer = get_tree().root.get_node_or_null("TundraSideQuestMusic")
	if music != null:
		music.stop()
		music.queue_free()
		await _frames()
	print("Tundra optional encounters: %d failures; full six-monster run completed" % failures)
	get_tree().quit(1 if failures else 0)

func _check_layouts() -> void:
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		var viewport := SubViewport.new()
		viewport.size = dimensions
		add_child(viewport)
		_setup_between_fights()
		var map: Control = load(ScenePaths.ENCOUNTER_SELECT).instantiate()
		viewport.add_child(map)
		await _frames()
		var bounds := Rect2(Vector2.ZERO, Vector2(dimensions))
		var second_column_nodes: int = 0
		for route_node: Dictionary in map.route_map._nodes:
			if int(route_node.column) == 2:
				second_column_nodes += 1
		check(second_column_nodes >= 2, "The opening combat immediately splits into room choices")
		for activity_id: String in ["ice_fishing", "frozen_traveler", "icy_portal", "treasure_chest"]:
			var activity_button: Button = map.route_map.get_node("Activity_" + activity_id)
			var activity_detail: Label = activity_button.get_node("PreviewRow/EnemyText/ActivitySubtitle")
			check(activity_detail.text.is_empty(), "Activity cards omit detour/required labels")
			var activity_node: Dictionary = map.route_map._button_nodes[activity_button]
			var same_column: int = 0
			for route_node: Dictionary in map.route_map._nodes:
				if int(route_node.column) == int(activity_node.column):
					same_column += 1
			if activity_id == RunState.route_required_activity:
				check(same_column == 1, "Required activity is the only node in its column")
			else:
				check(same_column in [2, 3] and not map.route_map.has_node("Pass_" + activity_id), "Optional minigame is a real room on the combat fork")
		for source_key: String in RunState.route_edges:
			check(RunState.route_edges[source_key].size() <= 3, "A room exposes at most three exits")
		for column_index: int in range(1, RunState.route_graph_columns.size() - 1):
			var sources: Array = RunState.route_graph_columns[column_index]
			var destinations: Array = RunState.route_graph_columns[column_index + 1]
			if sources.size() <= 1 or destinations.size() <= 1:
				continue
			var fully_connected: bool = true
			for source: String in sources:
				if RunState.route_edges[source].size() < destinations.size():
					fully_connected = false
			check(not fully_connected, "Split rooms have distinct outgoing paths")
		for index: int in map.route_map._buttons.size():
			var card: Button = map.route_map._buttons[index]
			check(bounds.encloses(card.get_global_rect()), "Map card fits " + str(dimensions))
			for other_index: int in range(index + 1, map.route_map._buttons.size()):
				var other: Button = map.route_map._buttons[other_index]
				check(not card.get_global_rect().intersects(other.get_global_rect()), "Route branches do not overlap " + str(dimensions))
		map.queue_free()
		await _frames()
		RunState.encounter_index = 6
		RunState.completed_encounters.assign([1, 2, 3, 4, 5])
		map = load(ScenePaths.ENCOUNTER_SELECT).instantiate()
		viewport.add_child(map)
		await _frames()
		check(map.route_map._buttons.size() == 11, "The entire route remains visible at the boss")
		for card: Button in map.route_map._buttons:
			check(bounds.encloses(card.get_global_rect()), "Boss map fits " + str(dimensions))
		map.queue_free()
		await _frames()
		RunState.encounter_index = 2
		for id: String in TundraEventScript.IDS:
			RunState.begin_optional_encounter(id)
			var event: Control = load(ScenePaths.TUNDRA_EVENT).instantiate()
			viewport.add_child(event)
			await _frames()
			check(bounds.encloses(event.get_node("Margin/Content/InputRow").get_global_rect()), "Input fits " + id + str(dimensions))
			for round_index: int in 3:
				if event.next_button.visible:
					event._next_round()
				var hint_before_typing: String = event.preview.text
				event.input.text = _valid_word(id)
				await _frames()
				check(event.preview.text == hint_before_typing, "Typing does not disclose word effects: " + id)
				for control: Control in [event.game_panel, event.input, event.feedback_banner, event.feedback, event.choice_row]:
					if control.is_visible_in_tree():
						check(bounds.encloses(control.get_global_rect()), "Gameplay fits " + id + str(dimensions))
				if id == "icy_portal": event._choose(0)
				event._submit()
				await _frames()
				if event.next_button.visible:
					check(bounds.encloses(event.next_button.get_global_rect()), "Round feedback fits " + id + str(dimensions))
					_check_banner(event, bounds, id + str(dimensions))
					var original: String = event.feedback.text
					event.feedback.text = "The wizard has reviewed your unusually elaborate application. Please keep your limbs inside reality while he locates his misplaced sandwich. Your chosen word still counts, and the next round begins when you are ready. A tiny clerk stamps the receipt and asks whether the sandwich was declared at the border."
					await _frames()
					_check_banner(event, bounds, "Long message " + id + str(dimensions))
					event.feedback.text = ""
					event._sync_feedback_banner()
					await _frames()
					check(not event.feedback_banner.visible, "Empty banner collapses")
					event.feedback.text = original
					event._sync_feedback_banner()
					await _frames()
			check(event._finished and bounds.encloses(event.continue_button.get_global_rect()), "Result fits " + id + str(dimensions))
			event.queue_free()
			await _frames()
		viewport.queue_free()
		await _frames()


func _available_combat_button(map: Control) -> Button:
	for button: Button in map.route_map._buttons:
		var node: Dictionary = map.route_map._button_nodes[button]
		if (
			String(node.get("type", "enemy")) in ["enemy", "boss"]
			and int(node.get("stage", 0)) == RunState.encounter_index
			and not button.disabled
		):
			return button
	return null


func _check_banner(event: Control, bounds: Rect2, context: String) -> void:
	var banner: Rect2 = event.feedback_banner.get_global_rect()
	var controls: Rect2 = event.get_node("Margin/Content/InputRow").get_global_rect()
	check(bounds.encloses(banner), "Banner fits: " + context)
	check(banner.encloses(event.feedback.get_global_rect()), "Banner encloses text: " + context)
	check(event.feedback.size.y >= event.feedback.get_combined_minimum_size().y, "Wrapped text is not clipped: " + context)
	check(banner.position.y >= controls.end.y + 9, "Banner remains below interaction controls: " + context)
	check(not banner.intersects(event.game_panel.get_global_rect()), "Banner clears information panel: " + context)
	check(not banner.intersects(event.next_button.get_global_rect()), "Banner clears next button: " + context)
	check(bounds.encloses(event.next_button.get_global_rect()), "Next button fits after wrapping: " + context)
	check(event.sprite.get_global_rect().end.y <= event.game_panel.get_global_rect().position.y, "Sprite remains above information: " + context)
