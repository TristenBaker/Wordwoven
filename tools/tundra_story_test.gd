extends Node

const EMBER_WORD: Resource = preload("res://data/items/ember_word.tres")

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

	check(
		RunState.route_graph_columns[3].size() == 3
		and String(RunState.route_nodes[RunState.route_graph_columns[3][0]].content_id) == "lore_room"
		and String(RunState.route_nodes[RunState.route_graph_columns[3][1]].content_id) == "lore_room",
		"The lore room appears early on two established branches"
	)

	var intro: Control = load(ScenePaths.TUNDRA_INTRO).instantiate()
	add_child(intro)
	await get_tree().process_frame
	check(RunState.tundra_intro_seen, "The tundra intro marks itself seen")
	check(
		str(intro.LINES).contains("□") or str(intro.LINES).contains("_"),
		"The tundra intro visually freezes or removes letters"
	)
	check(intro.continue_button.text == "Skip Cutscene", "The intro is skippable")
	intro.queue_free()

	RunState.pending_route_activity = "lore_room"
	RunState.pending_route_key = String(RunState.route_graph_columns[3][0])
	var lore: Control = load(ScenePaths.LORE_ROOM).instantiate()
	add_child(lore)
	await get_tree().process_frame
	check(lore.story_text.text.contains("glacier"), "The lore room reveals a frozen memory")
	check(
		lore.get_node("BlackBackground").color == Color.BLACK,
		"The lore cutscene uses a completely black background"
	)
	check(
		lore.get_node_or_null("Center/LorePanel") == null
		and lore.get_node_or_null("Center/StoryText") != null,
		"The lore cutscene displays only its white poem text"
	)
	lore.queue_free()

	RunState.pending_route_activity = ""
	RunState.pending_route_key = ""
	RunState.debug_jump_to_route_node(RunState.route_boss_key, 0)
	RunState.begin_victory("Frost Wyrm", 100)
	var boss_loot: Control = load(ScenePaths.LOOT_DROP).instantiate()
	add_child(boss_loot)
	await get_tree().process_frame
	check(RunState.has_key_item(EMBER_WORD.id), "The boss reward grants the Ember Word")
	check(
		boss_loot.key_item_label != null
		and boss_loot.key_item_label.text.contains(EMBER_WORD.display_name),
		"The boss reward names the item"
	)
	var repeated_loot: Control = load(ScenePaths.LOOT_DROP).instantiate()
	add_child(repeated_loot)
	await get_tree().process_frame
	check(RunState.key_items.size() == 1, "Re-entering the reward cannot grant it twice")
	boss_loot.queue_free()
	repeated_loot.queue_free()

	var tavern: PackedScene = load(ScenePaths.TAVERN)
	var tavern_instance: Node = tavern.instantiate()
	check(
		tavern_instance.get_node_or_null("Margin/VBox/DebugIceFishingButton") == null,
		"The developer ice-fishing menu button is removed"
	)
	tavern_instance.free()

	print("Tundra story flow: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
