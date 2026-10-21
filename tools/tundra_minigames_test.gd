extends Node
const EVENTS = preload("res://scripts/encounters/tundra_events.gd")
var failures: int = 0

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func setup(id: String) -> void:
	RunState.start_new_run()
	RunState.selected_biome = "tundra"
	RunState.encounter_index = 2
	RunState.route_depth = 2
	RunState.completed_encounters.append(1)
	RunState.player_health = 23
	check(RunState.begin_optional_encounter(id), "Encounter available: " + id)

func play(id: String, words: Array, choice: int = -1) -> Dictionary:
	var verdict: Dictionary = {}
	for word: String in words:
		verdict = EVENTS.submit_word(id, word, choice)
		check(verdict.valid, "Accepted: " + word)
		EVENTS.next_round(id)
	return verdict.get("result", {})

func _run() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	_check_non_spoiler_text()
	setup("frozen_traveler")
	check(EVENTS.complete("frozen_traveler").is_empty(), "Cannot settle before three turns")
	for word: String in ["", "zzzzzzz", "quickly", "ice cream"]:
		check(not EVENTS.submit_word("frozen_traveler", word).valid, "Invalid noun rejected")
	check(EVENTS.progress("frozen_traveler").turn == 0, "Invalid words do not spend turns")
	var accepted: Dictionary = EVENTS.submit_word("frozen_traveler", " TORCH ")
	check(accepted.valid and EVENTS.progress("frozen_traveler").value == 3, "Fuel and normalization")
	check(not EVENTS.submit_word("frozen_traveler", "soup").valid, "Cannot submit during round feedback")
	EVENTS.next_round("frozen_traveler")
	var result: Dictionary = play("frozen_traveler", ["blanket", "soup"])
	check(RunState.player_health == 29 and result.score == 7, "Full rescue heals six")
	check(EVENTS.complete("frozen_traveler").is_empty(), "Cannot claim twice")
	check(not EVENTS.submit_word("frozen_traveler", "torch").valid, "Completed game rejects input")
	setup("frozen_traveler")
	result = play("frozen_traveler", ["telescope", "spoon", "map"])
	check(RunState.player_health == 26 and result.score == 3, "Fair fallback earns partial rescue")
	setup("frozen_traveler")
	RunState.player_health = 49
	play("frozen_traveler", ["torch", "torch", "torch"])
	check(RunState.player_health == 50, "Healing capped and repeated supplies legal")
	setup("icy_portal")
	check(not EVENTS.submit_word("icy_portal", "carefully").valid, "Portal requires a choice")
	check(not EVENTS.submit_word("icy_portal", "carefully", 2).valid, "Portal rejects out of range choice")
	check(not EVENTS.submit_word("icy_portal", "blanket", 0).valid, "Portal rejects noun")
	check(EVENTS.progress("icy_portal").turn == 0, "Invalid portal input spends nothing")
	result = play("icy_portal", ["carefully", "gently", "slowly"], 0)
	check(RunState.player_health == 28 and RunState.gold == 0, "Calm steady portal heals five")
	setup("icy_portal")
	result = play("icy_portal", ["quickly", "boldly", "swiftly"], 1)
	check(RunState.gold == 8 and RunState.player_health == 23, "Energetic charge portal awards gold")
	check(EVENTS.complete("icy_portal").is_empty(), "Portal cannot award twice")
	setup("icy_portal")
	play("icy_portal", ["quickly", "quickly", "quickly"], 0)
	check(RunState.gold == 0 and RunState.player_health == 23, "Poor portal choices award nothing without damage")
	setup("icy_portal")
	play("icy_portal", ["oddly", "oddly", "oddly"], 0)
	check(RunState.player_health == 28, "Unrecognized adverbs can stabilize via steady actions")
	var chest: GDScript = EVENTS.rules("treasure_chest")
	check(chest.accepts("valiant", chest.LOCKS[1]), "WordNet accepts valiant as brave synonym")
	check(not chest.accepts("wooden", chest.LOCKS[1]), "Unrelated adjective does not fit")
	for opened: int in range(4):
		setup("treasure_chest")
		var state: Dictionary = EVENTS.progress("treasure_chest")
		state.locks = chest.LOCKS.slice(0, 3).duplicate(true)
		check(not EVENTS.submit_word("treasure_chest", "quickly").valid, "Wrong POS does not use a guess")
		check(state.turn == 0 and state.guesses == 0, "Invalid chest input spends nothing")
		for index: int in 3:
			if index < opened:
				play("treasure_chest", [state.locks[index].anchors[0]])
			else:
				play("treasure_chest", ["wooden"])
				check(state.guesses == 1 and state.feedback.contains(state.locks[index].hint), "Incorrect answer gives a clear hint")
				play("treasure_chest", ["wooden"])
		check(RunState.gold == opened * 4, "Chest payout for %d locks" % opened)
		check(EVENTS.complete("treasure_chest").is_empty(), "Chest payout cannot repeat")
	setup("treasure_chest")
	EVENTS.submit_word("treasure_chest", EVENTS.progress("treasure_chest").locks[0].anchors[0])
	var skipped: Dictionary = EVENTS.complete("treasure_chest", true)
	check(skipped.skipped and RunState.gold == 0, "Skipping unfinished chest forfeits reward")
	check(not RunState.begin_optional_encounter("treasure_chest"), "Skipped encounter cannot replay")
	setup("icy_portal")
	RunState.pending_optional_encounter = "frozen_traveler"
	check(not EVENTS.submit_word("icy_portal", "carefully", 0).valid, "Mismatched pending ID cannot play")
	setup("icy_portal")
	EventBus.gold_changed.connect(_try_duplicate_reward, CONNECT_ONE_SHOT)
	play("icy_portal", ["quickly", "boldly", "swiftly"], 1)
	check(RunState.gold == 8, "Gold signal cannot re-enter reward settlement")
	print("Tundra mini-game rules: %d failures" % failures)
	get_tree().quit(1 if failures else 0)

func _try_duplicate_reward(_amount: int) -> void:
	check(EVENTS.complete("icy_portal").is_empty(), "Claim recorded before emitting gold signal")

## Check every authored answer against the actual text returned to the UI.
func _assert_no_answers(text: String, answers: Array, context: String) -> void:
	var tokens := RegEx.new()
	tokens.compile("[a-z]+")
	for token: RegExMatch in tokens.search_all(text.to_lower()):
		check(not answers.has(token.get_string()), "No answer examples in " + context + ": " + token.get_string())

func _check_non_spoiler_text() -> void:
	var traveler: GDScript = EVENTS.rules("frozen_traveler")
	var supplies: Array = []
	for category: Dictionary in traveler.CATEGORIES:
		supplies.append_array(category.words)
	var rescue: Dictionary = traveler.initial_state()
	var baseline: Dictionary = traveler.presentation(rescue)
	_assert_no_answers(JSON.stringify(baseline), supplies, "traveler instructions")
	_assert_no_answers(rescue.feedback, supplies, "traveler initial feedback")
	_assert_no_answers(EVENTS.definition("frozen_traveler").description, supplies, "traveler description")
	for word: String in supplies + ["telescope"]:
		check(traveler.presentation(rescue, word) == baseline, "Typing does not reveal supply classification")
	var portal: GDScript = EVENTS.rules("icy_portal")
	var adverbs: Array = portal.CALM + portal.ENERGETIC
	var gate: Dictionary = portal.initial_state()
	_assert_no_answers(gate.feedback, adverbs, "portal initial feedback")
	_assert_no_answers(EVENTS.definition("icy_portal").description, adverbs, "portal description")
	for round_index: int in 3:
		gate.turn = round_index
		baseline = portal.presentation(gate)
		_assert_no_answers(JSON.stringify(baseline), adverbs, "portal round %d" % round_index)
		check(baseline.choices.size() == 2 and baseline.choices[0].contains("+2 stability") and baseline.choices[1].contains("+1 treasure charge"), "Portal base action effects remain visible")
		for word: String in adverbs + ["oddly"]:
			check(portal.presentation(gate, word) == baseline, "Typing does not reveal adverb effects")
	var chest: GDScript = EVENTS.rules("treasure_chest")
	var adjectives: Array = []
	for lock: Dictionary in chest.LOCKS:
		adjectives.append_array(lock.accepted)
	_assert_no_answers(EVENTS.definition("treasure_chest").description, adjectives, "chest description")
	for lock: Dictionary in chest.LOCKS:
		_assert_no_answers(lock.clue + " " + lock.hint, adjectives, "chest clue and hint: " + lock.name)
		check(not String(lock.clue).contains("opposite of"), "Clues avoid direct antonyms")
		var puzzle: Dictionary = chest.initial_state()
		puzzle.locks = [lock, lock, lock]
		for guesses: int in 2:
			puzzle.guesses = guesses
			baseline = chest.presentation(puzzle)
			_assert_no_answers(JSON.stringify(baseline), adjectives, "chest gameplay hints")
			check(baseline.preview.contains("ADJECTIVE") and baseline.preview.contains("4 gold"), "Chest POS and reward remain visible")
		chest.play(puzzle, "wooden", -1)
		_assert_no_answers(puzzle.feedback, adjectives, "incorrect answer feedback")
