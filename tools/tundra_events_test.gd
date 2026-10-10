extends Node

const TundraEventScript = preload("res://scripts/encounters/tundra_events.gd")
## End-to-end scene transitions, detours, rewards, animation, and six-fight progression.
var failures: int = 0

func _valid_word(id: String) -> String:
	return {"frozen_traveler": "sock", "treasure_chest": "shiny", "icy_portal": "quickly"}[id]

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
	# Keep this runner alive when exercising actual scene navigation.
	get_tree().current_scene = null
	if not WordNet.is_ready:
		await WordNet.loading_finished
	_setup_between_fights()
	RunState.player_health = RunState.player_max_health
	check(RunState.begin_optional_encounter("frozen_traveler"), "Traveler available between fights")
	var result: Dictionary = TundraEventScript.complete("frozen_traveler", "sock")
	check(RunState.player_health == RunState.player_max_health and result.reward.contains("full health"), "Full HP safely capped")
	check(TundraEventScript.complete("frozen_traveler", "sock").is_empty(), "Cannot collect twice")
	_setup_between_fights()
	RunState.player_health = 23
	RunState.begin_optional_encounter("frozen_traveler")
	TundraEventScript.complete("frozen_traveler", "sock")
	check(RunState.player_health == 29, "Traveler restores configured six HP")
	RunState.begin_optional_encounter("treasure_chest")
	TundraEventScript.complete("treasure_chest", "shiny")
	check(RunState.gold == 12, "Chest awards configured twelve gold")
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
	var observed: Dictionary = {}
	for trial: int in 24:
		_setup_between_fights()
		RunState.player_health = 2 if trial < 12 else 49
		RunState.begin_optional_encounter("icy_portal")
		seed(trial)
		var before: int = RunState.player_health
		result = TundraEventScript.complete("icy_portal", "quickly")
		check(RunState.player_health >= 1 and RunState.player_health <= 50 and RunState.is_run_active, "Portal cannot kill or overheal")
		if RunState.gold > 0:
			observed.gold = true
		elif RunState.player_health > before:
			observed.heal = true
		elif RunState.player_health < before:
			observed.damage = true
	check(observed.size() == 3, "All three modest portal outcomes verified")
	RunState.start_new_run()
	check(RunState.optional_encounters.is_empty() and RunState.pending_optional_encounter.is_empty(), "New run clears visits and pending event")
	RunState.selected_biome = "tundra"
	check(not RunState.begin_optional_encounter("frozen_traveler"), "No detours before first fight")
	var fought: Array[String] = []
	for stage: int in range(1, 7):
		map = await _go(ScenePaths.ENCOUNTER_SELECT)
		check(RunState.encounter_index == stage, "Monster slot preserved: %d" % stage)
		var cards: VBoxContainer = map.get_node("MapPanel/Margin/Content/OptionalChoices/Cards")
		check(cards.get_child_count() == (3 if stage == 2 else 0), "Optional availability: %d" % stage)
		if stage == 2:
			check(not get_tree().root.has_node("TundraSideQuestMusic"), "Entering map is silent")
			check(map.get_node("MapPanel/Margin/Content/OptionalChoices/Title").text == "Side Quests", "Side Quests heading")
			check(not map.has_node("MapPanel/Margin/Content/OptionalChoices/Hint"), "Removed hint")
			for id: String in TundraEventScript.IDS:
				var next_enemy: String = RunState.next_enemy_id
				var pending_fate: Dictionary = RunState.pending_encounter_modifier.duplicate(true)
				for card: Button in cards.get_children():
					check(not card.has_node("PreviewRow/EnemyText/EnemyTags"), "Side quest has no subtitle")
					for monster: Button in map.route_map._buttons:
						check(not card.get_global_rect().intersects(monster.get_global_rect()), "Optional cards clear monsters")
				cards.get_node("Event_" + id).pressed.emit()
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
				event.input.text = "  " + _valid_word(id).to_upper() + "  "
				event.input.text_submitted.emit(event.input.text)
				check(event._finished and event.dialogue.text.contains(_valid_word(id)) and event.continue_button.visible, "Normalized word inserted into humorous result: " + id)
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
				cards = map.get_node("MapPanel/Margin/Content/OptionalChoices/Cards")
			check(cards.get_child_count() == 0, "Completed detours disappear")
		map.route_map._buttons[0].pressed.emit()
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
		for card: Button in map.get_node("MapPanel/Margin/Content/OptionalChoices/Cards").get_children():
			check(bounds.encloses(card.get_global_rect()), "Map card fits " + str(dimensions))
			for monster: Button in map.route_map._buttons:
				check(not card.get_global_rect().intersects(monster.get_global_rect()), "Map cards do not overlap " + str(dimensions))
		map.queue_free()
		await _frames()
		RunState.encounter_index = 6
		RunState.completed_encounters.assign([1, 2, 3, 4, 5])
		map = load(ScenePaths.ENCOUNTER_SELECT).instantiate()
		viewport.add_child(map)
		await _frames()
		check(map.route_map._buttons.size() == 1 and RunState.optional_encounter_available("icy_portal"), "Unvisited detours coexist with boss")
		check(bounds.encloses(map.route_map._buttons[0].get_global_rect()), "Boss fits alongside detours " + str(dimensions))
		map.queue_free()
		await _frames()
		RunState.encounter_index = 2
		for id: String in TundraEventScript.IDS:
			RunState.begin_optional_encounter(id)
			var event: Control = load(ScenePaths.TUNDRA_EVENT).instantiate()
			viewport.add_child(event)
			await _frames()
			check(bounds.encloses(event.get_node("Margin/Content/InputRow").get_global_rect()), "Input fits " + id + str(dimensions))
			event.input.text = _valid_word(id)
			event._submit()
			await _frames()
			check(bounds.encloses(event.continue_button.get_global_rect()), "Result fits " + id + str(dimensions))
			event.queue_free()
			await _frames()
		viewport.queue_free()
		await _frames()
