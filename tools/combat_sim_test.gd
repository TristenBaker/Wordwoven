extends Node
## Headless combat checks. Rule units use fixed letters, seeded
## generators, and a manual clock; scene runs use fixed enemies,
## environments, and decks. Exits non-zero on any failed expectation.
##
## Run from the project root:
##   godot --headless --path . res://tools/combat_sim_test.tscn

const SEED: int = 20260916
const RETALIATION_WAIT: float = 2.0

var _failures: int = 0
var _last_result: Dictionary = {}
var _navigated: Array[String] = []


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	EventBus.word_resolved.connect(_on_word_resolved)
	_test_conditions_and_damage()
	_test_speed_timer()
	_test_deck_redraw_and_theft()
	_test_abilities()
	_test_relic_catalog()
	_test_spelling_suggestions()
	await _test_encounter_setup()
	await _test_goblin_combat()
	await _test_icy_rat_combat()
	print("=== %d failure(s) ===" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# --- Rule units ----------------------------------------------------

func _test_conditions_and_damage() -> void:
	print("-- conditions and damage --")
	RunState.start_new_run()
	var calculator: DamageCalculator = DamageCalculator.new()
	var conditions: EncounterConditions = EncounterConditions.new(_rng())
	var b_one: LetterStats = LetterStats.create("b")
	var b_two: LetterStats = LetterStats.create("b")
	var a_one: LetterStats = LetterStats.create("a")
	var e_one: LetterStats = LetterStats.create("e")
	var k_one: LetterStats = LetterStats.create("k")
	var no_tags: Array[String] = []
	var no_undrawn: Array[String] = []

	conditions.poison(b_one)
	_expect(conditions.is_poisoned(b_one), "poison marks one instance")
	_expect(not conditions.is_poisoned(b_two), "duplicate copy unaffected")
	_expect(not conditions.poison(b_one), "poison does not stack")
	var result: Dictionary = calculator.calculate(
		"bab", [b_one, a_one, b_two], no_undrawn, no_tags, "n",
		{"conditions": conditions}
	)
	_expect_near(result["base_power"], 2.5 + 1.0 + 5.0,
			"poison halves only that copy's power")
	_expect(result["poisoned_count"] == 1, "poisoned count reported")
	_expect(result["level_eligible"].has(b_one),
			"poisoned tile still levels")

	var vowels: EncounterConditions = EncounterConditions.new(_rng())
	vowels.poison(a_one)
	vowels.poison(e_one)
	result = calculator.calculate(
		"ae", [a_one, e_one], no_undrawn, no_tags, "n",
		{"conditions": vowels}
	)
	_expect(result["heal_amount"] == 1,
			"halved healing sums before rounding down (0.5 + 0.5)")
	result = calculator.calculate(
		"a", [a_one], no_undrawn, no_tags, "n", {"conditions": vowels}
	)
	_expect(result["heal_amount"] == 0, "lone halved heal rounds down")
	var rogue: EncounterConditions = EncounterConditions.new(_rng())
	rogue.poison(k_one)
	result = calculator.calculate(
		"k", [k_one], no_undrawn, no_tags, "n", {"conditions": rogue}
	)
	_expect(result["gold_bonus"] == 1, "poisoned rogue gold halved")

	var icy: EncounterConditions = EncounterConditions.new(_rng())
	icy.freeze(b_two)
	icy.freeze(a_one)
	result = calculator.calculate(
		"ba", [b_two, a_one], no_undrawn, no_tags, "n",
		{"conditions": icy}
	)
	_expect_near(result["base_power"], 0.6 + 0.2,
			"frozen tiles give 20% base letter power")
	_expect(result["heal_amount"] == 0, "frozen healer does not heal")
	_expect(result["level_eligible"].is_empty(), "frozen tiles never level")
	_expect(result["frozen_count"] == 2, "frozen count reported")

	var both: EncounterConditions = EncounterConditions.new(_rng())
	both.freeze(b_one)
	both.poison(b_one)
	result = calculator.calculate(
		"b", [b_one], no_undrawn, no_tags, "n", {"conditions": both}
	)
	_expect_near(result["base_power"], 0.3,
			"frozen and poisoned tile gives half of 20%")

	var plain: Dictionary = calculator.calculate(
		"ka", [k_one, a_one], no_undrawn, no_tags, "n"
	)
	var swift: Dictionary = calculator.calculate(
		"ka", [k_one, a_one], no_undrawn, no_tags, "n",
		{"speed_bonus": true}
	)
	_expect_near(swift["damage"], plain["damage"] * 1.5,
			"speed bonus multiplies final damage by 1.5")
	_expect(swift["heal_amount"] == plain["heal_amount"]
			and swift["gold_bonus"] == plain["gold_bonus"],
			"speed bonus leaves healing and gold unchanged")
	_expect(not plain["speed_bonus"] and plain["speed_multiplier"] == 1.0,
			"calls without context keep old results")
	calculator.free()


func _test_speed_timer() -> void:
	print("-- speed timer --")
	var clock: ManualClock = ManualClock.new()
	clock.current_msec = 1000
	var timer: SpeedTimer = SpeedTimer.new(clock)
	_expect(not timer.qualifies(1000), "stopped timer grants nothing")
	timer.start()
	_expect(timer.qualifies(13000), "exactly 12 seconds still qualifies")
	_expect(not timer.qualifies(13001), "past 12 seconds does not")
	clock.advance(5000)
	_expect(timer.remaining_msec() == 7000, "remaining time counts down")
	timer.start()
	_expect(timer.remaining_msec() == 12000, "new turn resets the timer")
	timer.stop()
	_expect(not timer.qualifies(clock.now_msec()), "stop removes timing")


func _test_deck_redraw_and_theft() -> void:
	print("-- deck redraw and theft --")
	RunState.start_new_run()
	var deck: DeckManager = DeckManager.new()
	deck.rng = _rng()
	var a: LetterStats = LetterStats.create("a")
	var b: LetterStats = LetterStats.create("b")
	var c: LetterStats = LetterStats.create("c")
	var d: LetterStats = LetterStats.create("d")
	var e: LetterStats = LetterStats.create("e")
	deck.set_piles([a, b, c], [d], [e])
	_expect(deck.redraw([a, b]), "redraw with draw and discard supply")
	_expect(not deck.hand().has(a) and not deck.hand().has(b),
			"redrawn tiles cannot return immediately")
	_expect(deck.hand().has(d) and deck.hand().has(e),
			"replacements come from draw then reshuffled discard")
	_expect(deck.discard_pile().size() == 2, "selections go to discard")

	deck.set_piles([a, b], [], [c])
	_expect(not deck.can_redraw(2), "insufficient replacements detected")
	_expect(not deck.redraw([a, b]), "insufficient redraw is rejected")
	_expect(deck.hand().size() == 2 and deck.discard_pile() == [c],
			"rejected redraw changes nothing")
	deck.set_piles([a, b], [c, d], [])
	_expect(not deck.redraw([a, a]), "duplicate selection rejected")
	_expect(not deck.redraw([e]), "tile outside hand rejected")

	var conditions: EncounterConditions = EncounterConditions.new(_rng())
	var e_copy: LetterStats = LetterStats.create("e")
	deck.set_piles([e, e_copy], [], [])
	conditions.freeze(e)
	var split: Dictionary = deck.split_word("e", conditions)
	_expect(split["drawn"] == [e_copy],
			"spelling prefers an unaffected duplicate")

	deck.set_piles([a, b, c], [d], [])
	_expect(deck.remove_from_hand(b), "theft removes a hand tile")
	_expect(deck.hand().size() == 2, "stolen tile is not replaced")
	deck.return_to_discard([b])
	_expect(deck.discard_pile().has(b), "stolen tile returns to discard")
	deck.free()


func _test_abilities() -> void:
	print("-- abilities --")
	RunState.start_new_run()
	var deck: DeckManager = DeckManager.new()
	var conditions: EncounterConditions = EncounterConditions.new(_rng())
	var context: AbilityContext = AbilityContext.new(
		conditions, deck, "Tester"
	)
	var letters: Array[LetterStats] = _letters("abcde")
	deck.set_piles(letters, [], [])
	var thieves: EncounterAbilities = EncounterAbilities.new()
	thieves.add_entries([{"id": "steal_tile", "count": 1}])
	var lines: Array[String] = thieves.after_enemy_attack(context)
	_expect(lines.size() == 1 and deck.hand().size() == 4,
			"goblin steals exactly one tile")
	_expect(conditions.stolen_letters().size() == 1
			and not deck.hand().has(conditions.stolen_letters()[0]),
			"stolen instance leaves the hand")
	_expect(thieves.on_player_turn_start(context).is_empty(),
			"theft has no turn-start effect")

	var rats: EncounterAbilities = EncounterAbilities.new()
	rats.add_entries([{"id": "poison_tile", "count": 1}])
	deck.set_piles(_letters("xy"), [], [])
	rats.after_enemy_attack(context)
	rats.after_enemy_attack(context)
	_expect(conditions.poisoned_letters().size() == 2,
			"each rat attack poisons a different tile")
	_expect(rats.after_enemy_attack(context).is_empty(),
			"poison skips when every tile is poisoned")

	var ice: EncounterAbilities = EncounterAbilities.new()
	ice.add_entries([{"id": "freeze_tiles", "count": 2}])
	var hand: Array[LetterStats] = _letters("fghij")
	deck.set_piles(hand, [], [])
	ice.on_player_turn_start(context)
	var first_ice: Array[LetterStats] = conditions.frozen_letters()
	_expect(first_ice.size() == 2, "ice freezes two tiles")
	deck.set_piles(_letters("k"), [], [])
	ice.on_player_turn_start(context)
	_expect(conditions.frozen_letters().size() == 1
			and not conditions.is_frozen(first_ice[0]),
			"ice clears last turn and freezes all when fewer remain")

	var unknown: EncounterAbilities = EncounterAbilities.new()
	unknown.add_entries([{"id": "no_such_ability"}])
	_expect(unknown.ability_ids().is_empty(), "unknown abilities skipped")
	deck.free()


func _test_relic_catalog() -> void:
	print("-- relic catalog --")
	RunState.start_new_run()
	RelicCatalog.reload()
	_expect(RelicCatalog.relics().size() == 6, "all six relics valid")
	var legacy: Dictionary = {
		"name": "Old", "description": "Legacy entry.",
		"effect": "victory_gold", "amount": 5,
	}
	_expect(RelicCatalog.validate_entry(legacy).is_empty(),
			"legacy single-effect entry accepted")
	_expect(RelicCatalog.effects_of(legacy)[0]["type"] == "victory_gold",
			"legacy entry normalizes to an effect list")
	_expect(not RelicCatalog.validate_entry({
		"name": "Bad", "description": "Unknown.",
		"effects": [{"type": "teleport", "amount": 1}],
	}).is_empty(), "unknown effect type rejected")
	_expect(not RelicCatalog.validate_entry({
		"name": "Bad", "description": "No amount.",
		"effects": [{"type": "hand_size"}],
	}).is_empty(), "missing effect amount rejected")
	var relics: RelicSystem = RelicSystem.new()
	RunState.relics = ["tome_of_echoes", "tome_of_echoes"]
	_expect_near(relics.total_effect("damage_multiplier"), 0.24,
			"Tome copies stack")
	RunState.relics = ["quill_of_fortune", "traveler_satchel"]
	_expect_near(relics.total_effect("victory_gold"), 8.0,
			"victory gold relics stack")
	RunState.relics = []
	RunState.complete_encounter()
	_expect(relics.grant_reward("iron_bookmark", 1),
			"relic granted once")
	_expect(RunState.player_max_health == 60, "Iron Bookmark raises max HP")
	_expect(not relics.grant_reward("iron_bookmark", 1),
			"second relic for one encounter refused")


func _test_spelling_suggestions() -> void:
	print("-- spelling suggestions --")
	var verbs: Array[String] = WordNet.spelling_suggestions("jumpp", "v")
	_expect(verbs.has("jump"), "deletion finds jump")
	_expect(not verbs.has("jumps"), "verb prompts skip inflected forms")
	var nouns: Array[String] = WordNet.spelling_suggestions("jumpp", "n")
	_expect(nouns.has("jumps") or nouns.has("jump"),
			"noun prompts accept noun candidates")
	var played: Array[String] = ["jump"]
	_expect(not WordNet.spelling_suggestions("jumpp", "v", played).has(
		"jump"
	), "already played words are skipped")
	var many: Array[String] = WordNet.spelling_suggestions("cat", "n")
	var sorted: Array[String] = many.duplicate()
	sorted.sort()
	_expect(many.size() == 5 and many == sorted,
			"at most five suggestions, alphabetical")
	_expect(WordNet.spelling_suggestions("fomr", "n").has("form"),
			"adjacent transposition is one edit")


func _test_encounter_setup() -> void:
	print("-- encounter setup --")
	RunState.start_new_run()
	_expect(EncounterPlanner.normalize_tag("  FIERY ")["tag"] == "fiery",
			"tag input normalizes case and whitespace")
	_expect(not EncounterPlanner.normalize_tag("very fiery")["valid"],
			"multiword tag rejected")
	_expect(EncounterPlanner.normalize_tag("Purple")["tag"] == "purple",
			"any dictionary adjective is accepted")
	_expect(not EncounterPlanner.normalize_tag("quickly")["valid"],
			"non-adjective tag rejected")
	_expect(not EncounterPlanner.normalize_tag("zzqxv")["valid"],
			"non-word tag rejected")
	_expect(not EncounterPlanner.normalize_tag("")["valid"],
			"empty tag rejected")
	_expect(WordNet.counter_detailed("cold", "hot", "a")["score"] == 1.0,
			"uncurated adjective is countered by its antonym")
	_expect(WordNet.counter_targets("wet", "a").has("dry"),
			"antonyms become counter targets for new tags")
	_expect(WordNet.counter_targets("scorching", "a").has("cold"),
			"satellite adjectives borrow their head's antonyms")
	_expect(WordNet.counter_detailed("cold", "wet", "a")["score"] == 0.0,
			"unrelated words do not counter a new tag")
	_expect(WordNet.counter_targets("fiery", "n").has("water"),
			"curated tags keep their thematic counters")

	var factory: EnemyFactory = EnemyFactory.new()
	add_child(factory)
	var planner: EncounterPlanner = EncounterPlanner.new(_rng())
	var first: Array[Dictionary] = planner.options_for_current(factory)
	_expect(first.size() == 2, "first encounter offers two foes")
	var tier_one: bool = true
	for option: Dictionary in first:
		tier_one = tier_one and factory.enemy_info(
			option["enemy_id"]
		)["tier"] == 1
	_expect(tier_one, "first encounter offers stage-one foes")
	var other: EncounterPlanner = EncounterPlanner.new(
		RandomNumberGenerator.new()
	)
	_expect(other.options_for_current(factory) == first,
			"previews stay stable within an encounter")
	planner.icy_chance = 1.0
	var icy: Array[Dictionary] = planner.build_options(factory, 2)
	planner.icy_chance = 0.0
	var clear: Array[Dictionary] = planner.build_options(factory, 2)
	_expect(icy[0]["environment"] == "icy"
			and clear[0]["environment"] == "normal",
			"environment roll follows the icy chance")
	var setup: Dictionary = EncounterPlanner.configure(first[0], " Angry")
	_expect(setup["tag"] == "angry" and setup["encounter"] == 1
			and setup["environment"] == first[0]["environment"],
			"confirmed setup stores enemy, tag, and environment")
	_expect(EncounterPlanner.configure(first[0], "red hot").is_empty(),
			"invalid tag produces no setup")
	var spawn: Dictionary = factory.build_configured_spawn_data(
		setup["enemy_id"], setup["tag"]
	)
	_expect(spawn["tags"] == ["angry"], "configured foe has one tag")
	RunState.pending_encounter = setup
	RunState.encounter_index = 2
	_expect(RunState.take_pending_encounter().is_empty(),
			"stale setup is not consumed by another encounter")

	RunState.encounter_index = RunState.ENCOUNTERS_PER_RUN
	var boss: Array[Dictionary] = planner.options_for_current(factory)
	_expect(boss.size() == 1 and boss[0]["enemy_id"] == factory.boss_id(),
			"boss encounter uses setup with only the boss")
	factory.queue_free()

	RunState.start_new_run()
	# Setup opens only after the stage's two events are finished.
	RunState.event_stages[RunState.encounter_index] = {
		"types": [], "events": [], "slot": 0,
	}
	var screen: Control = load(ScenePaths.ENCOUNTER_SELECT).instantiate()
	add_child(screen)
	await get_tree().process_frame
	var options: Array[Dictionary] = RunState.encounter_options.duplicate()
	_expect(screen.choices_box.get_child_count() == 2,
			"setup screen shows first-encounter choices")
	screen.select_option(0)
	screen.tag_input.text = "quickly"
	screen._on_enter_pressed()
	_expect(not screen.confirmer.is_pending(),
			"a non-adjective cannot be confirmed")
	screen.tag_input.text = "Hot"
	screen._on_enter_pressed()
	_expect(screen.confirmer.is_pending(), "entry asks for confirmation")
	_expect(screen.confirmer.dialog_text.contains("cold"),
			"confirmation names the tag's opposites")
	screen.confirmer.decline()
	_expect(RunState.pending_encounter.is_empty(),
			"cancelled entry stores nothing")
	screen.queue_free()
	await get_tree().process_frame
	var reopened: Control = load(ScenePaths.ENCOUNTER_SELECT).instantiate()
	add_child(reopened)
	await get_tree().process_frame
	_expect(RunState.encounter_options == options,
			"reopening setup keeps the same previews")
	reopened.queue_free()
	await get_tree().process_frame


# --- Scene runs ----------------------------------------------------

func _test_goblin_combat() -> void:
	print("-- goblin combat --")
	var clock: ManualClock = ManualClock.new()
	clock.current_msec = 1000
	var combat: Control = _spawn_combat("goblin", "angry", "normal", clock)
	await get_tree().process_frame
	await get_tree().process_frame
	var enemy: Enemy = combat.enemy
	_expect(enemy.enemy_name == "Goblin", "fixed enemy spawned")
	_expect(enemy.tags == ["angry"], "chosen adjective is the only tag")
	_expect(combat.abilities.ability_ids() == ["steal_tile"],
			"goblin brings its theft ability")
	_expect(combat.hand_box.get_child_count() == 8, "hand deals 8 tiles")
	_expect(combat.conditions.stolen_letters().is_empty(),
			"no theft before the first attack")
	_make_sturdy(enemy)

	clock.advance(3000)
	combat.word_input.text = "zzxqjy"
	combat._on_submit()
	_expect(not combat.feedback_label.text.is_empty(),
			"nonsense word rejected")
	_expect(combat.speed_timer.remaining_msec() == 9000,
			"rejected word does not reset the timer")
	_expect(combat.word_input.editable, "rejected word keeps the turn")

	var health_before: int = enemy._health
	var player_before: int = RunState.player_health
	combat.word_input.text = "lemon"
	combat._on_submit()
	await get_tree().process_frame
	_expect(enemy._health < health_before, "lemon dealt damage")
	_expect(_last_result.get("speed_bonus", false),
			"word within 12 seconds earns the swift bonus")
	_expect(RunState.word_history.size() == 1, "word recorded")
	_expect(not combat.speed_timer.is_running(),
			"timer stops during enemy resolution")
	_expect(combat.thread_candidates().size()
			== int(_last_result["drawn_count"]),
			"every drawn lemon tile can be threaded")
	await get_tree().create_timer(RETALIATION_WAIT).timeout
	_expect(RunState.player_health == player_before,
			"the enemy waits while a thread is chosen")
	combat.skip_thread()
	await get_tree().create_timer(RETALIATION_WAIT).timeout
	_expect(RunState.player_health < player_before, "enemy retaliated")
	_expect(combat.conditions.stolen_letters().size() == 1,
			"goblin stole one tile after attacking")
	_expect(combat.deck_manager.hand().size() == 7,
			"stolen tile is not replaced immediately")
	_expect(RunState.deck.size() == 12, "theft never removes owned letters")
	_expect(combat.word_input.editable, "input returned to player")
	_expect(combat.speed_timer.remaining_msec() == 12000,
			"timer restarts on the new turn")

	combat.word_input.text = "lemon"
	combat._on_submit()
	_expect(combat.feedback_label.text == "Already played this fight",
			"repeat word rejected")

	# Redraw costs and limits.
	var hand: Array[LetterStats] = combat.deck_manager.hand().duplicate()
	combat.toggle_tile_selection(hand[0])
	combat.request_redraw()
	_expect(not combat.confirmer.is_pending(),
			"redraw without gold is refused before confirming")
	RunState.add_gold(20)
	combat.toggle_tile_selection(hand[1])
	combat.request_redraw()
	_expect(combat.confirmer.is_pending(), "redraw asks for confirmation")
	combat.confirmer.decline()
	_expect(RunState.gold == 20
			and combat.deck_manager.hand() == hand,
			"cancelled redraw changes nothing")
	var stale_selection: Array[LetterStats] = [hand[0], hand[1]]
	combat._confirm_redraw(combat._turn_number - 1, stale_selection)
	_expect(RunState.gold == 20, "stale redraw from another turn refused")
	combat.request_redraw()
	combat.confirmer.approve()
	combat.confirmer.approve()
	_expect(RunState.gold == 16, "two tiles cost 4g, charged once")
	_expect(not combat.deck_manager.hand().has(hand[0])
			and not combat.deck_manager.hand().has(hand[1]),
			"redrawn tiles left the hand")
	_expect(combat.deck_manager.hand().size() == 7,
			"redraw keeps the hand size")
	_expect(combat.word_input.editable
			and combat.redraw_button.text == "Redrawn",
			"redraw keeps the turn without an enemy attack")
	combat.toggle_tile_selection(combat.deck_manager.hand()[0])
	_expect(combat.selected_tiles().is_empty(),
			"no second redraw selection this turn")

	# Paid autocorrect for the current verb prompt.
	var remaining_before: int = combat.speed_timer.remaining_msec()
	combat.word_input.text = "zzzzqx"
	combat.request_autocorrect()
	_expect(combat.current_suggestions().is_empty()
			and not combat.confirmer.is_pending() and RunState.gold == 16,
			"no suggestions costs nothing")
	combat.word_input.text = "listn"
	combat.request_autocorrect()
	var listen_index: int = combat.current_suggestions().find("listen")
	_expect(listen_index >= 0, "autocorrect suggests listen for listn")
	combat.choose_suggestion(listen_index)
	_expect(combat.confirmer.is_pending(), "correction asks to confirm")
	combat.confirmer.decline()
	_expect(RunState.gold == 16 and combat.word_input.text == "listn",
			"cancelled correction is free and keeps the input")
	combat.choose_suggestion(listen_index)
	combat.word_input.text = "listnn"
	combat.confirmer.approve()
	_expect(RunState.gold == 16 and combat.word_input.text == "listnn",
			"stale correction after editing charges nothing")
	combat.word_input.text = "listn"
	combat.request_autocorrect()
	combat.choose_suggestion(combat.current_suggestions().find("listen"))
	combat.confirmer.approve()
	combat.confirmer.approve()
	_expect(RunState.gold == 11 and combat.word_input.text == "listen",
			"accepted correction charges 5g once and replaces input")
	_expect(RunState.word_history.size() == 1
			and combat.word_input.editable,
			"correction does not submit the word")
	_expect(combat.speed_timer.remaining_msec() == remaining_before,
			"autocorrect leaves the swift timer running")
	combat.word_input.clear()

	# Victory returns stolen tiles and hands off to the reward screens.
	var stolen: LetterStats = combat.conditions.stolen_letters()[0]
	var gold_before_win: int = RunState.gold
	enemy.take_damage(99999.0)
	await get_tree().process_frame
	_expect(combat.conditions.stolen_letters().is_empty()
			and combat.deck_manager.discard_pile().has(stolen),
			"stolen tile returns when the goblin dies")
	_expect(_navigated == [ScenePaths.FIGHT_COMPLETION],
			"victory opens the fight completion screen once")
	_expect(RunState.gold == gold_before_win + 32
			and RunState.pending_victory_gold == 32,
			"victory pays the goblin's gold once")
	enemy.take_damage(99999.0)
	await get_tree().process_frame
	_expect(_navigated.size() == 1 and RunState.gold == gold_before_win + 32,
			"a second death signal pays nothing")

	var log_text: String = combat.log_label.get_parsed_text()
	combat.set_log_expanded(false)
	_expect(not combat.log_label.visible
			and combat.log_label.get_parsed_text() == log_text,
			"collapsed log keeps its contents")
	combat.set_log_expanded(true)
	_expect(combat.log_label.visible, "log expands again")
	combat.queue_free()
	await get_tree().process_frame


func _test_icy_rat_combat() -> void:
	print("-- icy rat combat --")
	var clock: ManualClock = ManualClock.new()
	var combat: Control = _spawn_combat("rat", "filthy", "icy", clock)
	await get_tree().process_frame
	await get_tree().process_frame
	_make_sturdy(combat.enemy)
	var frozen: Array[LetterStats] = combat.conditions.frozen_letters()
	_expect(frozen.size() == 2, "icy ground freezes two tiles at turn start")
	_expect(combat.conditions.poisoned_letters().is_empty(),
			"no poison before the first attack")
	var frozen_tiles: int = 0
	for tile: LetterTile in combat.hand_box.get_children():
		if tile.frozen_badge.visible:
			frozen_tiles += 1
	_expect(frozen_tiles == 2, "frozen tiles show their indicator")

	RunState.add_gold(10)
	var old_hand: Array[LetterStats] = combat.deck_manager.hand().duplicate()
	combat.toggle_tile_selection(old_hand[0])
	combat.request_redraw()
	combat.confirmer.approve()
	var fresh_frozen: bool = false
	for stats: LetterStats in combat.deck_manager.hand():
		if not old_hand.has(stats) and combat.conditions.is_frozen(stats):
			fresh_frozen = true
	_expect(not fresh_frozen, "newly drawn tiles are not frozen this turn")

	clock.advance(12001)
	combat.word_input.text = "sermon"
	combat._on_submit()
	await get_tree().process_frame
	_expect(RunState.word_history.size() == 1
			and not _last_result.get("speed_bonus", true),
			"late word still resolves without the swift bonus")
	combat.skip_thread()
	await get_tree().create_timer(RETALIATION_WAIT).timeout
	var poisoned: Array[LetterStats] = combat.conditions.poisoned_letters()
	_expect(poisoned.size() == 1, "rat poisons one tile after attacking")
	var next_frozen: Array[LetterStats] = combat.conditions.frozen_letters()
	var all_in_hand: bool = next_frozen.size() == 2
	for stats: LetterStats in next_frozen:
		all_in_hand = all_in_hand and combat.deck_manager.hand().has(stats)
	_expect(all_in_hand, "next turn refreezes two current hand tiles")
	combat.queue_free()
	await get_tree().process_frame


# --- Helpers -------------------------------------------------------

func _spawn_combat(
	enemy_id: String, tag: String, environment: String, clock: GameClock
) -> Control:
	RunState.start_new_run()
	RunState.deck = _letters("aceilmnoprst")
	RunState.pending_encounter = {
		"encounter": RunState.encounter_index,
		"enemy_id": enemy_id,
		"tag": tag,
		"environment": environment,
	}
	var combat: Control = load(ScenePaths.COMBAT).instantiate()
	combat.clock = clock
	combat.rng = _rng()
	_navigated = []
	combat.navigate = _on_navigate
	add_child(combat)
	# These fights check other mechanics; word rules have their own suite.
	combat.rule_tracker.clear()
	return combat


# Keeps fixed test fights alive long enough to observe several turns.
func _make_sturdy(enemy: Enemy) -> void:
	enemy._max_health = 5000
	enemy._health = 5000


func _letters(characters: String) -> Array[LetterStats]:
	var letters: Array[LetterStats] = []
	for character: String in characters:
		letters.append(LetterStats.create(character))
	return letters


func _rng() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	return rng


func _on_navigate(scene_path: String) -> void:
	_navigated.append(scene_path)


func _on_word_resolved(result: Dictionary) -> void:
	_last_result = result


func _expect_near(actual: float, expected: float, label: String) -> void:
	_expect(absf(actual - expected) < 0.001,
			"%s (%.3f vs %.3f)" % [label, actual, expected])


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  " + label)
	else:
		print("  FAIL  " + label)
		_failures += 1
