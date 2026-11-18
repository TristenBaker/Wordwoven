extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var stats := LetterStats.create("a")
	var other := LetterStats.create("a")
	check(stats.best_word.is_empty() and stats.scar_count() == 0, "New letters start without history")
	stats.record_word_use("ash", 30.0)
	stats.record_word_use("apple", 20.0)
	stats.record_word_use("axe", 30.0)
	check(stats.best_word == "ASH" and stats.accepted_uses == 3, "Best damage wins; ties retain first word")
	check(other.accepted_uses == 0, "Duplicate glyphs have independent history")
	stats.record_word_use("arc", 45.0)
	stats.record_word_use("ant", 12.0)
	check(stats.best_word == "ARC" and stats.scar_count() == 1, "Fifth use earns first scar")
	check(stats.level == 1, "History does not alter itemized level balance")
	for level in [1, 5, 10, 20]:
		stats.level = level
		check(stats.gear_tier() == [1, 5, 10, 20].find(level), "Gear threshold")
	var path := "res://.godot/character_profile_test.tres"
	check(ResourceSaver.save(stats, path) == OK, "Profile saves as resource")
	var restored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as LetterStats
	check(restored.best_word == "ARC" and restored.accepted_uses == 5 and restored.appearance_seed == stats.appearance_seed, "History and appearance survive serialization")
	DirAccess.remove_absolute(path)
	LetterInspector.open_for(stats)
	await get_tree().process_frame
	var inspector := get_tree().get_first_node_in_group("letter_inspector")
	check(inspector != null and inspector._history_label.text.contains("ARC"), "Inspector displays history")
	LetterInspector.open_for(other)
	check(get_tree().get_nodes_in_group("letter_inspector").size() == 1, "Inspector reuses one popup")
	check(inspector._history_label.text.contains("No words"), "Switching letters refreshes history")
	var tile = load("res://scenes/combat/letter_tile.tscn").instantiate()
	add_child(tile)
	tile.setup(stats)
	await get_tree().process_frame
	check(tile.get_node_or_null("Appearance") != null, "Tiles show personal appearance")
	RunState.use_itemized_letters = false
	RunState.deck.assign([stats, other])
	RunState.letter_inventory.clear()
	DebugTools._refresh_profile_letters()
	DebugTools.profile_select.select(1)
	DebugTools._simulate_profile_uses(5)
	check(other.accepted_uses == 5 and other.scar_count() == 1, "Debug simulation advances selected duplicate only")
	check(stats.accepted_uses == 5, "Debug simulation leaves other letters unchanged")
	DebugTools.profile_select.select(0)
	DebugTools._simulate_profile_uses(5)
	check(stats.accepted_uses == 10 and stats.scar_count() == 2, "Debug simulation reaches second scar tier")
	DebugTools._simulate_profile_uses(5)
	DebugTools._simulate_profile_uses(1)
	check(stats.accepted_uses == 16 and stats.scar_count() == 3, "Debug simulation caps scars at three")
	check(stats.best_word == "ARC" and stats.best_word_damage == 45.0 and stats.level == 20, "Debug simulation preserves best word and level")
	check(inspector._history_label.text.contains("16 uses"), "Debug simulation refreshes open profile")
	RunState.deck.clear()
	DebugTools._simulate_profile_uses(5)
	check(DebugTools.profile_five_button.disabled, "Debug simulation handles empty roster")
	if "--preview" in OS.get_cmdline_user_args():
		LetterInspector.open_for(stats)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/profile_preview.png")
	inspector.queue_free()
	tile.queue_free()
	print("Character profile tests: %d failures" % failures)
	get_tree().quit(1 if failures else 0)


