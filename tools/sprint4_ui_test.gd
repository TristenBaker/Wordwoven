extends Node
## Real combat integration and input ownership, exercised without rendering.
var failures: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func escape(menu: PauseMenu) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	menu._input(event)


func click_at(point: Vector2, button: Button) -> void:
	var movement := InputEventMouseMotion.new()
	movement.position = point
	get_viewport().push_input(movement, true)
	await get_tree().process_frame
	check(get_viewport().gui_get_hovered_control() == button, button.name + " receives hover")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = point
	click.pressed = true
	get_viewport().push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	get_viewport().push_input(click, true)


func dispose(scene: Node) -> void:
	for audio: AudioStreamPlayer in scene.find_children(
		"*", "AudioStreamPlayer", true, false
	):
		audio.stop()
		audio.stream = null
	scene.queue_free()
	await get_tree().process_frame


func _run() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	PlayerStats._persistence_enabled = false
	RunState.start_new_run()
	RunState.selected_biome = "tundra"
	var combat: Control = load(ScenePaths.COMBAT).instantiate()
	combat.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(combat)
	await get_tree().process_frame
	await get_tree().process_frame
	combat.enemy._health = 100000
	combat.required_pos = "n"
	combat._refresh_prompt()
	var history: ProgressMenu = combat.get_node("PauseMenu/WordHistory")
	var button: Button = combat.get_node("Layout/WordHistoryButton")
	var history_rect := button.get_global_rect()
	var toggle_rect: Rect2 = combat.log_toggle_button.get_global_rect()
	check(is_equal_approx(history_rect.position.x, toggle_rect.position.x) and
		toggle_rect.end.y < history_rect.position.y, "log toggle stacks above history")
	var log_rect: Rect2 = combat.side_panel.get_global_rect()
	check(log_rect.size.y >= 375.0, "Expanded log restores the original reading height")
	check(log_rect.end.y < toggle_rect.position.y and
		log_rect.end.y <= combat.hand_box.get_global_rect().position.y,
		"open log clears history and hand")
	await click_at(toggle_rect.position + Vector2(5, toggle_rect.size.y * 0.5), combat.log_toggle_button)
	check(combat.side_panel.visible and combat.log_toggle_button.text == "Hide Log",
		"log toggle opens the bottom-left combat log")
	for index in 30:
		combat._log("Combat log test entry %d" % index)
	await get_tree().process_frame
	await get_tree().process_frame
	check(combat.log_label.scroll_following and combat.log_label.get_v_scroll_bar().value > 0,
		"Expanded log still follows appended combat history")
	await click_at(Vector2(toggle_rect.end.x - 5, toggle_rect.get_center().y), combat.log_toggle_button)
	check(not combat.side_panel.visible and combat.log_toggle_button.text == "Show Log",
		"log toggle closes the combat log")
	combat.word_input.text = "flame"
	var damage: float = float(PlayerStats.run_snapshot().damage)
	await click_at(Vector2(history_rect.end.x - 5, history_rect.get_center().y), button)
	check(get_tree().paused and history.visible, "history pauses combat")
	var elapsed: float = combat._turn_elapsed_seconds
	check(history.entries.text.contains("No words"), "empty history message")
	await get_tree().create_timer(0.2).timeout
	check(is_equal_approx(combat._turn_elapsed_seconds, elapsed),
		"quick-cast timer freezes")
	combat._on_submit()
	check(RunState.word_history.is_empty(), "submission blocked while paused")
	check(combat.word_input.text == "flame", "typed draft preserved")
	escape(combat.pause_menu)
	await get_tree().process_frame
	check(not get_tree().paused and not history.visible, "Escape closes")
	check(not combat.pause_menu.visible, "Escape does not open pause menu")
	check(combat.word_input.has_focus(), "composer focus restored")
	await click_at(history_rect.position + Vector2(5, history_rect.size.y * 0.5), button)
	check(get_tree().paused and history.visible, "history also opens at its left edge")
	escape(combat.pause_menu)
	await get_tree().process_frame
	combat.word_input.text = "zzzzzz"
	combat._on_submit()
	check(PlayerStats.run_snapshot().words == 0, "invalid cast excluded")
	combat.required_pos = "n"
	combat.word_input.text = "flame"
	combat._on_submit()
	check(PlayerStats.run_snapshot().words == 1, "real cast tracked once")
	check(PlayerStats.run_snapshot().damage > damage, "resolved damage tracked")
	check(RunState.word_history.size() == 1, "one authoritative record")
	var entry: Dictionary = RunState.word_history.back()
	check(entry.pos == "n", "prompted POS recorded")
	check(entry.has("effectiveness_label"), "classification captured")
	var feedback: String = combat.effectiveness_indicator.label.text
	check(entry.effectiveness_label == feedback,
		"history matches combat classification")
	combat._open_word_history()
	check(not history.visible and not get_tree().paused,
		"history blocked during resolution")
	var deadline: int = Time.get_ticks_msec() + 10000
	while combat._state != combat.State.PLAYER_INPUT \
			and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(combat._state == combat.State.PLAYER_INPUT, "normal turn completes")
	combat.required_pos = "n"
	combat.word_input.text = "flame"
	combat._on_submit()
	check(PlayerStats.run_snapshot().words == 1, "repeat cast excluded")
	combat.required_pos = "v"
	combat.word_input.text = "run"
	combat._on_submit()
	deadline = Time.get_ticks_msec() + 10000
	while combat._state != combat.State.PLAYER_INPUT \
			and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(PlayerStats.run_snapshot().words == 2, "second real cast tracked")
	combat._open_word_history()
	check(history.entries.text.find("FLAME") < history.entries.text.find("RUN"),
		"history chronological")
	check(history.entries.text.contains("FLAME"), "accepted history displayed")
	check(history.entries.text.contains(entry.effectiveness_label),
		"history effectiveness displayed")
	history.close_button.pressed.emit()
	await get_tree().process_frame
	check(not get_tree().paused and combat.word_input.has_focus(),
		"visible close resumes and focuses composer")
	escape(combat.pause_menu)
	combat.pause_menu._show_achievements()
	check(get_tree().paused and
		combat.pause_menu.get_node("AchievementsMenu").visible,
		"pause achievements available")
	escape(combat.pause_menu)
	check(get_tree().paused and combat.pause_menu.menu_panel.visible,
		"Escape returns from achievements to pause")
	combat.pause_menu._show_settings()
	escape(combat.pause_menu)
	check(get_tree().paused and combat.pause_menu.menu_panel.visible,
		"settings Escape preserved")
	escape(combat.pause_menu)
	check(not get_tree().paused, "next Escape resumes combat")
	var word_damage: float = PlayerStats.run_snapshot().damage
	combat._on_dev_kill_pressed()
	check(PlayerStats.run_snapshot().damage == word_damage,
		"developer kill excluded from word damage")
	check(PlayerStats._lifetime.words == 0,
		"developer kill rolls back the entire run's achievement progress")
	await dispose(combat)
	var notifications: CanvasLayer = PlayerStats.get_child(0)
	notifications._clear()
	notifications._enqueue("one", "One")
	notifications._enqueue("two", "Two")
	notifications._enqueue("two", "Two")
	check(notifications._queue.size() == 1, "toast queue deduplicates")
	var won: Control = load(ScenePaths.RUN_WON).instantiate()
	add_child(won)
	await get_tree().process_frame
	check(notifications.panel.visible and notifications._queue.size() >= 1,
		"notifications survive scene changes")
	check(won.tally_label.text.contains("Gold amassed"), "gold retained")
	var view: RichTextLabel = won.get_node(
		"CenterBox/Menu/PlayerStatistics/Scroll/Statistics"
	)
	check(view.text.contains("Word Damage Dealt"), "summary statistics shown")
	check(view.text.contains("Mightiest Word:"), "best word retained")
	check(won.get_node("CenterBox/Menu/MenuButton").visible,
		"summary navigation retained")
	await dispose(won)
	var lost: Control = load(ScenePaths.RUN_LOST).instantiate()
	add_child(lost)
	await get_tree().process_frame
	check(lost.title_label.text == "Your Tale Ends Here", "defeat title")
	check(PlayerStats.run_snapshot().words == 2, "summary retains stats")
	await dispose(lost)
	var main: Control = load(ScenePaths.MAIN_MENU).instantiate()
	add_child(main)
	await get_tree().process_frame
	main._show_achievements()
	check(main.get_node("AchievementsMenu").visible, "main menu achievements")
	check(main.get_node("AchievementsMenu/Panel/Content/Scroll/Entries")
		.text.contains("Alphabet Explorer"), "achievement list populated")
	var original_size: Vector2i = get_tree().root.size
	for resolution: Vector2i in AppSettings.RESOLUTIONS:
		get_tree().root.size = resolution
		await get_tree().process_frame
		await get_tree().process_frame
		var overlay: Control = main.get_node("AchievementsMenu/Panel")
		var area: Rect2 = main.get_viewport_rect()
		check(area.encloses(overlay.get_global_rect()),
			"achievement panel fits " + str(resolution))
		var close_button: Button = main.get_node(
			"AchievementsMenu/Panel/Content/CloseButton"
		)
		var close_rect: Rect2 = close_button.get_global_rect()
		check(overlay.get_global_rect().encloses(close_rect),
			"close button fits " + str(resolution))
	get_tree().root.size = original_size
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	main._unhandled_input(event)
	check(main.get_node("CenterBox").visible, "main menu restored")
	await dispose(main)
	print("Sprint 4 UI integration: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
