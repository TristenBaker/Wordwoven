extends Node
var checks := 0
var failures := 0
var directory: String


func _ready() -> void:
	PlayerStats._persistence_enabled = false
	directory = "res://.tmp/tavern/archive_test_" + Crypto.new().generate_random_bytes(8).hex_encode()
	OS.set_environment("WORDWOVEN_RUN_ARCHIVE_DIR", directory)
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var menu: SceneState = load("res://scenes/main_menu.tscn").get_state()
	var has_talent_button := false
	for index: int in menu.get_node_count():
		if menu.get_node_name(index) == &"PermanentUpgradesButton":
			has_talent_button = true
	check(not has_talent_button, "Start screen has no elemental talents button")
	var archive := RunArchive.new()
	check(archive.entries().is_empty(), "No archives is a valid state")
	RunState.start_new_run()
	RunState.use_itemized_letters = true
	RunState.selected_biome = "forest"
	var tile := LetterStats.create_item("a", LetterStats.Element.FIRE, 7)
	tile.modifier = LetterStats.Modifier.KEEN
	RunState.equipped_letters = {"a": tile}
	RunState.letter_inventory = [LetterStats.create_item("z", LetterStats.Element.ICE, 99)]
	RunState.relics = ["coal_script", "coal_script", "ember_pact", "prismatic_refrain"]
	PlayerProfile.letter_cosmetics["a"] = "mage"
	var first := archive.record_current(RunScoring.snapshot(true))
	check(not first.is_empty(), "Final loadout saved")
	check(first.equipped_letters.size() == 1 and first.equipped_letters[0].letter == "a", "Only equipped tiles saved, not loose inventory")
	check(first.equipped_letters[0].cosmetic == "mage" and first.equipped_letters[0].modifier == "keen", "Cosmetic and modifier saved")
	check(first.powers.size() == 3 and first.powers[0].count == 2, "Final power stacks saved once per ID")
	check(first.powers[0].combined_effect == "+24% damage total", "Historical power totals captured")
	check(first.started_at > 0 and first.finished_at >= first.started_at, "Run dates saved")
	var id: String = first.id
	check(FileAccess.file_exists(directory.path_join(id + ".json.bak")), "Backup created")
	tile.level = 100
	PlayerProfile.letter_cosmetics["a"] = "rogue"
	RunState.relics = []
	var loaded := RunArchive.new().load_run(id)
	check(loaded.equipped_letters[0].level == 7 and loaded.equipped_letters[0].cosmetic == "mage", "Archive is independent of live letter/cosmetic changes")
	check(archive.record_current(RunScoring.snapshot(false)).summary.victory, "Reopening cannot overwrite the archived outcome")
	check(archive.entries().size() == 1, "Repeated archive calls do not duplicate runs")
	var corrupt := FileAccess.open(directory.path_join(id + ".json"), FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	check(archive.load_run(id).equipped_letters[0].level == 7, "Backup recovers corrupt primary")
	check(archive.load_run("../player_profile").is_empty(), "Run IDs cannot escape the archive directory")
	check(RunArchive.letter_from_record(loaded.equipped_letters[0]).modifier == LetterStats.Modifier.KEEN, "Saved tile round-trips")
	var malformed_id := Crypto.new().generate_random_bytes(16).hex_encode()
	var malformed := FileAccess.open(directory.path_join(malformed_id + ".json"), FileAccess.WRITE)
	malformed.store_string('{"schema_version":1,"id":"invalid","equipped_letters":null}')
	malformed.close()
	check(archive.entries().size() == 1, "Malformed records skipped without touching good files")
	var bad_enum := loaded.duplicate(true)
	bad_enum.equipped_letters[0].element = {"unexpected": "object"}
	check(not archive._valid_record(bad_enum), "Invalid tile field types are rejected safely")
	var future := loaded.duplicate(true)
	future.schema_version = 999
	check(not archive._valid_record(future), "Unsupported archive versions are not interpreted")
	RunState.start_new_run(RunState.RunMode.ENDLESS)
	RunState.equipped_letters = {}
	RunState.relics = []
	var empty := archive.record_current(RunScoring.snapshot(false))
	check(empty.summary.mode == "Endless" and empty.equipped_letters.is_empty() and empty.powers.is_empty(), "Empty Endless loadout valid")
	RunState.start_new_run()
	RunState.equipped_letters = {}
	for index: int in 26:
		var letter := String.chr(97 + index)
		RunState.equipped_letters[letter] = LetterStats.create_item(letter, index % 6, index + 1)
	RunState.relics = RelicSystem.new().relic_ids()
	RunState.run_score_recorded = true # End-screen hook reads but never rewrites real leaderboard.
	var summary: Control = load("res://scripts/ui/run_summary.gd").new()
	summary._record_run_once()
	summary.free()
	check(archive.entries().size() == 3, "End-screen hook archives even if leaderboard was already recorded")
	var rich := archive.load_run(RunState.archive_run_id)
	check(rich.equipped_letters.size() == 26 and rich.powers.size() == 20, "Full final build saved")
	RunState.start_new_run()
	RunState.relics = []
	for index: int in 26:
		PlayerProfile.letter_cosmetics[String.chr(97 + index)] = "rogue"
	var guest_stats := RunState.tavern_guest_for_shop()
	check(not RunState.tavern_guest_archive.is_empty(), "Tavern selects from past runs")
	check(RunState.tavern_guest_for_shop() == guest_stats, "Archived guest stable for shop phase")
	var hub: Control = load(ScenePaths.TAVERN).instantiate()
	add_child(hub)
	await get_tree().process_frame
	var guest: Node2D = hub.letter_guest
	check(guest.stats.level == int(guest.archived_guest.tile.level), "Guest uses saved final level")
	check(guest.cosmetic == PlayerProfile.cosmetic_resource(String(guest.archived_guest.tile.cosmetic)), "Guest uses saved cosmetic, not current selection")
	guest.info_button.pressed.emit()
	await get_tree().process_frame
	var overlay := get_tree().get_first_node_in_group("run_archive_overlay") as RunArchiveOverlay
	check(overlay != null and overlay._record.id == guest.archived_guest.run.id, "Visitor click opens original run")
	check(hub._room_menu_open(), "Archived visitor info locks tavern navigation")
	var before_guest: Vector2 = guest.position
	guest._process(1.0)
	check(guest.position == before_guest, "Guest stops during archive view")
	overlay.queue_free()
	await get_tree().process_frame
	check(not hub._room_menu_open(), "Closing archive restores tavern")
	LeaderboardOverlay.open_in(hub)
	var board: Control = hub.get_node("LeaderboardOverlay")
	board._leaderboard._boards = {"story": [rich.summary, loaded.summary], "endless": [empty.summary]}
	board._select_mode("story")
	await get_tree().process_frame
	await get_tree().process_frame
	check(board._list.get_child_count() == 2, "Leaderboard renders ranked run rows")
	var archived_entries: Array[Dictionary] = [loaded]
	check(board._archive_for_entry(loaded.summary, archived_entries).id == loaded.id, "Leaderboard links an unchanged score entry to its archive")
	var old_score: Dictionary = loaded.summary.duplicate()
	old_score.recorded_at = float(old_score.recorded_at) - 600
	check(board._archive_for_entry(old_score, archived_entries).is_empty(), "Older unarchived scores do not open a different loadout")
	var ambiguous: Array[Dictionary] = [loaded, loaded.duplicate(true)]
	check(board._archive_for_entry(loaded.summary, ambiguous).is_empty(), "Ambiguous score records never open the wrong archive")
	var row_view: Button
	for button: Button in board._list.find_children("*", "Button", true, false):
		if button.text == "View Loadout" and not button.disabled:
			row_view = button
			break
	check(row_view != null, "Ranked rows offer saved loadouts")
	if row_view != null:
		row_view.pressed.emit()
		check(board.get_node_or_null("RunArchiveOverlay") != null, "Ranked row opens its loadout")
		board.get_node("RunArchiveOverlay").queue_free()
		await get_tree().process_frame
	board._select_mode("endless")
	check(board._list.get_child_count() == 1, "Story and Endless rankings remain separate")
	board._select_mode("story")
	await get_tree().process_frame
	await get_tree().process_frame
	check(get_viewport().get_visible_rect().encloses(board._list.get_parent().get_global_rect()), "Restyled leaderboard fits screen")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-board="):
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png(argument.get_slice("=", 1)) == OK, "Leaderboard preview saved")
	var opened_from_board := false
	for button: Button in board.find_children("*", "Button", true, false):
		if button.text == "Past Loadouts":
			button.pressed.emit()
			opened_from_board = board.get_node_or_null("RunArchiveOverlay") != null
			break
	check(opened_from_board, "Existing leaderboard opens separate archive browser")
	board.queue_free()
	await get_tree().process_frame
	RunArchiveOverlay.open_in(hub, rich, rich.equipped_letters[0])
	await get_tree().process_frame
	await get_tree().process_frame
	overlay = hub.get_node("RunArchiveOverlay")
	var screen := get_viewport().get_visible_rect()
	check(screen.encloses(overlay._details.get_parent().get_global_rect()), "Full build stays in scrollable viewport")
	check(overlay._details.find_children("*", "Button", true, false).size() == 26, "All final equipped letters can be inspected")
	check(overlay._details.find_children("*", "RichTextLabel", true, false).size() == 20, "All final powers displayed")
	var identity: Label = overlay._details.find_child("ArchivedLetterIdentity", true, false)
	check(identity.size.x >= 200 and identity.size.y <= 180, "Selected letter identity has readable width")
	overlay._show_run(loaded, loaded.equipped_letters[0])
	await get_tree().process_frame
	await get_tree().process_frame
	var slots: GridContainer = overlay._details.find_child("AlphabetSlots", true, false)
	check(slots.get_child_count() == 26, "Sparse loadout retains all alphabet slots")
	var empty_slots := 0
	for index: int in slots.get_child_count():
		var slot: Button = slots.get_child(index)
		check(slot.slot_letter == String.chr(97 + index), "Alphabet slots stay in A-Z order")
		if slot.disabled:
			empty_slots += 1
	check(empty_slots == 25, "Unequipped letters display as empty holes")
	check(slots.get_child(0).archived_tile.level == 7, "Occupied card shows archived level")
	check(slots.get_global_rect().end.x <= overlay._details.get_parent().get_global_rect().end.x, "Alphabet grid fits without horizontal clipping")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-archive="):
			overlay._show_run(loaded, loaded.equipped_letters[0])
			var pointer := InputEventMouseMotion.new()
			pointer.position = Vector2(12, 700)
			pointer.global_position = pointer.position
			Input.parse_input_event(pointer)
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png(argument.get_slice("=", 1)) == OK, "Archive preview saved")
	print("RUN ARCHIVE TEST: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
