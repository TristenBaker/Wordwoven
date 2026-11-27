extends Node
const MODIFIERS = preload("res://data/balance/encounter_modifier.gd")
const VOCABULARY = preload("res://data/balance/adjective_vocabulary.gd")
var failures: int = 0
var reentrant_combat: Control
var expected: Dictionary = {
	"titanbound": ["Tougher Enemy", "harder", 1.25],
	"doommarked": ["Frail Enemy", "easier", 0.75],
	"war_blessed": ["Stronger Enemy Strikes", "harder", 1.25],
	"spirit_broken": ["Weaker Enemy Strikes", "easier", 0.75],
	"fate_exposed": ["Empowered Attacks", "easier", 0.75],
	"spellwarden": ["Weakened Attacks", "harder", 1.25],
	"drowsy": ["Naps, Fierce Awakenings", "easier", 0.75],
	"clumsy": ["Enemy Strikes Itself", "easier", 0.75],
	"long_winded": ["Word Length Bonuses", "easier", 0.75],
	"echo_bound": ["Linked Word Power", "easier", 0.75],
	"chameleon": ["Shifting Enemy Weaknesses", "mixed", 1.0],
	"greedy": ["Coins And Theft", "mixed", 1.0],
	"frostbite_tax": ["Faster Freezing, Extra Heat", "mixed", 1.0],
}

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	_run.call_deferred()

func _dispose(node: Node) -> void:
	for audio: AudioStreamPlayer in node.find_children("*", "AudioStreamPlayer", true, false):
		audio.stop()
		audio.stream = null
	node.queue_free()

func _run() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	check(MODIFIERS.ENTRIES.size() == 13, "All thirteen fates")
	for entry: Dictionary in MODIFIERS.ENTRIES:
		check(entry.selection_effect == expected[entry.id][0], "Descriptive effect: " + entry.id)
		check(entry.difficulty == expected[entry.id][1], "Difficulty: " + entry.id)
		check(MODIFIERS.reward_multiplier(entry) == expected[entry.id][2], "Multiplier: " + entry.id)
		var label: String = {"harder": "Increased Gold", "easier": "Decreased Gold", "mixed": "Standard Gold"}[entry.difficulty]
		check(MODIFIERS.reward_description(entry) == label, "Correct descriptive reward: " + entry.id)
		check(entry.selection_effect.split(" ").size() <= 4, "Concise description: " + entry.id)
	check(MODIFIERS.victory_gold(10, MODIFIERS.definition("titanbound")) == 13, "Hard gold rounds half up")
	check(MODIFIERS.victory_gold(10, MODIFIERS.definition("doommarked")) == 8, "Easy gold rounds half up")
	check(MODIFIERS.victory_gold(11, {}) == 11, "No modifier means standard rewards")
	check(MODIFIERS.victory_gold(0, MODIFIERS.definition("titanbound")) == 0, "Zero stays zero")
	await _test_previews()
	await _test_victories()
	await _test_route_receipt()
	await get_tree().create_timer(0.2).timeout
	print("Modifier risk rewards: %d failures" % failures)
	get_tree().quit(1 if failures else 0)

func _test_previews() -> void:
	RunState.start_new_run()
	RunState.selected_biome = "tundra"
	var viewport := SubViewport.new()
	add_child(viewport)
	var screen: Control = load(ScenePaths.ENCOUNTER_MODIFIER).instantiate()
	viewport.add_child(screen)
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		viewport.size = resolution
		screen._browse.button_pressed = true
		var original_confirm: Rect2
		for entry: Dictionary in MODIFIERS.ENTRIES:
			screen._choose_example(VOCABULARY.WORDS[entry.id][0])
			var base: Dictionary = screen._base_spawn
			var gold: int = MODIFIERS.victory_gold(base.gold, entry)
			var gold_text := "Victory Gold\n%d" % base.gold
			if gold != base.gold:
				gold_text += " → %d" % gold
			check(screen._enemy_stats.gold.get_parsed_text() == gold_text, "Foe panel uses combat gold and rounding: " + entry.id)
			for stat: String in ["health", "attack", "gold"]:
				check(screen._enemy_stats[stat].get_line_count() == 2, "Enemy stat stays in two aligned lines: " + stat + " / " + entry.id)
			var effect: String = screen._effect.text + " " + screen._tradeoff.text
			if entry.stat in ["health", "attack"]:
				var adjusted: Dictionary = MODIFIERS.apply_spawn(base, entry)
				var stat_text: String = screen._enemy_stats[entry.stat].get_parsed_text()
				if base[entry.stat] != adjusted[entry.stat]:
					check(stat_text.contains("%d → %d" % [base[entry.stat], adjusted[entry.stat]]), "Foe panel uses combat stat values: " + entry.id)
					var accent: Color = screen.HELPFUL if adjusted[entry.stat] < base[entry.stat] else screen.HARMFUL
					check(screen._enemy_stats[entry.stat].text.contains(accent.to_html(false)), "Changed enemy stat is colored from the player's perspective")
				else:
					check(not stat_text.contains("→"), "Rounded unchanged stat remains neutral")
			elif entry.stat == "player_damage":
				var expected_effect := "Your words deal more damage." if MODIFIERS.player_factor(entry) > 1.0 else "Your words deal less damage."
				check(effect.contains(expected_effect), "Preview explains the player damage change: " + entry.id)
			if entry.id == "greedy":
				check(effect.contains("up to 5") and effect.contains("up to 4 total") and screen._reward_detail.text.contains("+8 gold on victory"), "Greedy separates earnings, theft and victory bonus")
			if entry.id == "frostbite_tax":
				check(effect.contains("2 Heat") and effect.contains("2 casts"), "Frostbite Tax describes both changes")
			if entry.id == "drowsy":
				var awake: int = roundi(base.attack * 1.25)
				check(screen._enemy_stats.attack.get_parsed_text().contains("%d → %d" % [base.attack, awake]) and effect.contains("skips its first retaliation"), "Drowsy shows its incoming attack and sleep cadence")
			if entry.id == "long_winded":
				check(effect.contains("7+ letters") and effect.count("20% more damage") == 1 and effect.count("2 Guard") == 1, "Long-Winded lists both branches once")
			await get_tree().process_frame
			await get_tree().process_frame
			var panel: Control = screen.find_child("PreparationPanel", true, false)
			check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(panel.get_global_rect()), "Expanded selection fits " + str(resolution))
			if original_confirm.has_area():
				check(screen._confirm.get_global_rect() == original_confirm, "Preview keeps its confirmation position: " + entry.id)
			original_confirm = screen._confirm.get_global_rect()
	viewport.queue_free()
	await get_tree().process_frame

func _test_victories() -> void:
	var factory := EnemyFactory.new()
	add_child(factory)
	for stage: int in [1, 3, 6]:
		for entry: Dictionary in MODIFIERS.ENTRIES:
			RunState.start_new_run()
			RunState.selected_biome = "tundra"
			RunState.encounter_index = stage
			RunState.relics.clear()
			var id: String = factory.ids_for_stage(stage)[0]
			RunState.next_enemy_id = id
			RunState.cache_encounter_modifier(id, VOCABULARY.WORDS[entry.id][0], entry.id)
			var combat: Control = load(ScenePaths.COMBAT).instantiate()
			add_child(combat)
			var base_gold: int = combat.enemy.gold_reward
			var earned: int = roundi(base_gold * float(expected[entry.id][2])) + (8 if entry.id == "greedy" else 0)
			reentrant_combat = combat
			EventBus.gold_changed.connect(_try_reentrant_victory, CONNECT_ONE_SHOT)
			combat.enemy.take_damage(999999)
			check(RunState.gold == earned and RunState.pending_victory_gold == earned, "Victory pays and reports adjusted gold: " + entry.id)
			check(combat.enemy.gold_reward == base_gold, "Base reward remains unchanged")
			var inventory_count: int = RunState.letter_inventory.size()
			combat._on_enemy_died()
			check(RunState.gold == earned and RunState.letter_inventory.size() == inventory_count, "Repeated callback grants nothing")
			_dispose(combat)
			await get_tree().process_frame
			# A second scene for this same stage must not award gold or drops.
			RunState.next_enemy_id = id
			var reopened: Control = load(ScenePaths.COMBAT).instantiate()
			add_child(reopened)
			reopened.enemy.take_damage(999999)
			check(RunState.gold == earned and RunState.letter_inventory.size() == inventory_count, "Scene reload cannot reclaim rewards")
			check(RunState.pending_victory_gold == earned, "Reload cannot rescale existing victory amount")
			_dispose(reopened)
			await get_tree().process_frame
	factory.queue_free()

func _try_reentrant_victory(_gold: int) -> void:
	reentrant_combat._on_enemy_died()

func _test_route_receipt() -> void:
	RunState.start_new_run()
	check(RunState.claimed_combat_rewards.is_empty(), "New run clears reward receipts")
	check(RunState.claim_combat_rewards("stage:1"), "Stage claims once")
	check(not RunState.claim_combat_rewards("stage:1"), "Stage cannot claim twice")
	check(RunState.claim_combat_rewards("stage:2"), "Next stage has its own claim")
	check(RunState.claim_combat_rewards("route:route_2_0"), "Route node has its own claim")
	RunState.clear_pending_victory()
	check(not RunState.claim_combat_rewards("route:route_2_0"), "Clearing victory display cannot reset receipts")
	RunState.start_new_run()
	check(RunState.claim_combat_rewards("stage:1"), "New run permits rewards again")
