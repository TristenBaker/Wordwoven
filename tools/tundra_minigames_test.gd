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
	_check_chest_pool()
	_check_non_spoiler_text()
	await _check_stories()
	await _check_chest_ui()
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
		check(RunState.gold == opened * 10, "Chest payout for %d locks" % opened)
		check(EVENTS.complete("treasure_chest").is_empty(), "Chest payout cannot repeat")
	setup("treasure_chest")
	EVENTS.submit_word("treasure_chest", EVENTS.progress("treasure_chest").locks[0].anchors[0])
	var skipped: Dictionary = EVENTS.complete("treasure_chest", true)
	check(skipped.skipped and RunState.gold == 0, "Skipping unfinished chest forfeits reward")
	check(not RunState.begin_optional_encounter("treasure_chest"), "Skipped encounter cannot replay")
	setup("treasure_chest")
	RunState.pending_optional_encounter = "frozen_traveler"
	check(not EVENTS.submit_word("treasure_chest", "wooden").valid, "Mismatched pending ID cannot play")
	setup("treasure_chest")
	EventBus.gold_changed.connect(_try_duplicate_reward, CONNECT_ONE_SHOT)
	var locks: Array = EVENTS.progress("treasure_chest").locks
	play("treasure_chest", [locks[0].anchors[0], locks[1].anchors[0], locks[2].anchors[0]])
	check(RunState.gold == 30, "Gold signal cannot re-enter reward settlement")
	var music: AudioStreamPlayer = get_tree().root.get_node_or_null("TundraSideQuestMusic")
	if music != null:
		music.stop()
		music.queue_free()
	await get_tree().process_frame
	print("Tundra mini-game rules: %d failures" % failures)
	get_tree().quit(1 if failures else 0)

func _try_duplicate_reward(_amount: int) -> void:
	check(EVENTS.complete(RunState.pending_optional_encounter).is_empty(), "Claim recorded before emitting gold signal")

## Check every authored answer against the actual text returned to the UI.
func _assert_no_answers(text: String, answers: Array, context: String) -> void:
	var tokens := RegEx.new()
	tokens.compile("[a-z]+")
	for token: RegExMatch in tokens.search_all(text.to_lower()):
		check(not answers.has(token.get_string()), "No answer examples in " + context + ": " + token.get_string())

func _check_chest_pool() -> void:
	var chest: GDScript = EVENTS.rules("treasure_chest")
	var validator := WordValidator.new()
	var names := {}
	var intentions := {}
	var messages := {}
	check(chest.LOCKS.size() >= 30, "At least 30 chest challenges")
	for lock: Dictionary in chest.LOCKS:
		var intended: String = lock.anchors[0]
		check(not names.has(lock.name) and not intentions.has(intended), "Unique lock and intended answer: " + lock.name)
		check(lock.clue != lock.hint and not lock.success.is_empty() and not messages.has(lock.success), "Distinct clue, retry hint, and success message: " + lock.name)
		names[lock.name] = true
		intentions[intended] = true
		messages[lock.success] = true
		for answer: String in lock.accepted + lock.anchors:
			check(validator.validate(answer, "a").valid and chest.accepts(answer, lock), "Adjective works for %s: %s" % [lock.name, answer])
	validator.free()
	var previous_order: Array[String] = []
	for cycle in 2:
		var order: Array[String] = []
		while order.size() < chest.LOCKS.size():
			setup("treasure_chest")
			var locks: Array = EVENTS.progress("treasure_chest").locks
			check(locks.size() == 3, "Each encounter draws three locks")
			check(EVENTS.progress("treasure_chest").locks == locks, "Reopening keeps the existing draw")
			for lock: Dictionary in locks:
				check(not order.has(lock.name), "No repeats before pool exhaustion: " + lock.name)
				order.append(lock.name)
		if cycle > 0:
			check(order != previous_order, "Pool reshuffles after exhaustion")
		previous_order = order


func _check_non_spoiler_text() -> void:
	var chest: GDScript = EVENTS.rules("treasure_chest")
	var adjectives: Array = []
	for lock: Dictionary in chest.LOCKS:
		adjectives.append_array(lock.accepted)
	_assert_no_answers(EVENTS.definition("treasure_chest").description, adjectives, "chest description")
	for lock: Dictionary in chest.LOCKS:
		_assert_no_answers(lock.clue + " " + lock.hint, lock.accepted, "chest clue and hint: " + lock.name)
		check(not String(lock.clue).contains("opposite of"), "Clues avoid direct antonyms")
		var puzzle: Dictionary = chest.initial_state()
		puzzle.locks = [lock, lock, lock]
		for guesses: int in 2:
			puzzle.guesses = guesses
			var baseline: Dictionary = chest.presentation(puzzle)
			_assert_no_answers(baseline.instruction + " " + baseline.preview, lock.accepted, "chest gameplay hints")
			check(baseline.preview.contains("ADJECTIVE") and baseline.preview.contains("10 gold"), "Chest POS and reward remain visible")
		chest.play(puzzle, "wooden", -1)
		_assert_no_answers(puzzle.feedback, lock.accepted, "incorrect answer feedback")

func _check_stories() -> void:
	var traveler: GDScript = EVENTS.rules("frozen_traveler")
	var tales: Array = traveler.stories()
	check(tales.size() == 15, "Fifteen authored stories load")
	var ids: Array[String] = []
	var titles: Array[String] = []
	var previous: String = ""
	for _index: int in 100:
		var selected: Dictionary = traveler.initial_state()
		check(selected.story.id != previous, "No immediate story repeat across encounters")
		previous = selected.story.id
	for tale: Dictionary in tales:
		check(not ids.has(tale.id) and not titles.has(tale.title), "Unique story ID and title")
		ids.append(tale.id)
		titles.append(tale.title)
		check(tale.blanks.size() >= 3 and tale.blanks.size() <= 5, "Short story blank count")
		for pos: String in ["n", "v", "a", "r"]:
			check(tale.blanks.has(pos), "Each story mixes all four word types")
		setup("frozen_traveler")
		var state: Dictionary = EVENTS.progress("frozen_traveler")
		state.story = tale.duplicate(true)
		await _check_entry_ui()
		check(EVENTS.complete("frozen_traveler").is_empty(), "Unfinished story cannot pay")
		var result: Dictionary = {}
		for index: int in tale.blanks.size():
			var pos: String = tale.blanks[index]
			check(EVENTS.requested_pos("frozen_traveler") == pos, "Correct blank part of speech")
			check(String(tale.text).contains("{%d}" % index), "Every blank has a placeholder")
			var saved: Dictionary = state.duplicate(true)
			for invalid: String in ["", "   ", "zzzzzzz", "ice cream", "123", "quickly" if pos != "r" else "telescope"]:
				check(not EVENTS.submit_word("frozen_traveler", invalid).valid, "Invalid input rejected for " + pos)
				check(state == saved, "Invalid input never advances story")
			var word: String = {"n": "telescope", "v": "dance", "a": "purple", "r": "quickly"}[pos]
			var verdict: Dictionary = EVENTS.submit_word("frozen_traveler", "  " + word.to_upper() + "  ")
			check(verdict.valid and state.words[index] == word, "Creative input accepted and normalized")
			result = verdict.get("result", {})
			if index < tale.blanks.size() - 1:
				check(not EVENTS.submit_word("frozen_traveler", word).valid, "Feedback waits for Next Blank")
				check(RunState.gold == 0 and RunState.player_health == 23, "No early payout")
				EVENTS.next_round("frozen_traveler")
		check(not result.is_empty(), "Last blank completes story")
		check(not result.story.contains("{") and not result.story.contains("["), "No unfilled placeholders")
		for word: String in state.words:
			check(result.story.contains("‹%s›" % word.to_upper()), "Every inserted word is distinguished")
		check(result.dialogue.contains(tale.title), "Result includes story title")
		check(RunState.player_health == 33 and RunState.gold == 20, "Guaranteed 20 percent healing and 20 gold")
		check(EVENTS.complete("frozen_traveler").is_empty(), "Traveler reward cannot repeat")
		check(not EVENTS.submit_word("frozen_traveler", "telescope").valid, "Completed story rejects new input")
		await _check_story_ui(result)
	setup("frozen_traveler")
	RunState.player_max_health = 53
	RunState.player_health = 52
	var state: Dictionary = EVENTS.progress("frozen_traveler")
	state.turn = state.story.blanks.size()
	state.value = state.turn
	EVENTS.complete("frozen_traveler")
	check(RunState.player_health == 53, "Healing is capped at maximum")
	setup("frozen_traveler")
	RunState.player_max_health = 53
	RunState.player_health = 0
	state = EVENTS.progress("frozen_traveler")
	state.turn = state.story.blanks.size()
	state.value = state.turn
	EventBus.gold_changed.connect(_try_duplicate_reward, CONNECT_ONE_SHOT)
	EVENTS.complete("frozen_traveler")
	check(RunState.player_health == 11 and RunState.gold == 20, "Healing rounds up and reward is reentrant-safe")
	setup("frozen_traveler")
	var skipped: Dictionary = EVENTS.complete("frozen_traveler", true)
	check(skipped.skipped and RunState.gold == 0 and RunState.player_health == 23, "Skipping traveler grants nothing")
	_check_bonus_rewards()

func _check_story_ui(result: Dictionary) -> void:
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var viewport := SubViewport.new()
		viewport.size = resolution
		add_child(viewport)
		var event: Control = load(ScenePaths.TUNDRA_EVENT).instantiate()
		viewport.add_child(event)
		await get_tree().process_frame
		await get_tree().process_frame
		check(event._finished and event.result_panel.visible and event.continue_button.visible, "Result awaits explicit Continue")
		check(event.dialogue.text == result.dialogue, "Completed story displayed unchanged")
		check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(event.result_panel.get_global_rect()), "Story fits preserved UI")
		check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(event.continue_button.get_global_rect()), "Continue fits preserved UI")
		await get_tree().process_frame
		check(event.dialogue.text == result.dialogue and event.result_panel.visible, "Story persists across frames")
		viewport.queue_free()
		await get_tree().process_frame

func _check_bonus_rewards() -> void:
	# Seed only the settlement roll, after all randomized story/lock selection.
	for itemized: bool in [true, false]:
		for id: String in EVENTS.IDS:
			for win_bonus: bool in [true, false]:
				setup(id)
				RunState.use_itemized_letters = itemized
				var state: Dictionary = EVENTS.progress(id)
				if id == "frozen_traveler":
					state.turn = state.story.blanks.size()
				else:
					state.lock_index = 3
					state.value = 3
				var chance: float = EVENTS.rules(id).outcome(state).bonus_chance
				check(is_equal_approx(chance, 0.10 if id == "frozen_traveler" else 0.20), "Configured bonus probability")
				var chosen_seed: int = 0
				for candidate: int in 1000:
					seed(candidate)
					if (randf() < chance) == win_bonus:
						chosen_seed = candidate
						break
				var before: int = RunState.letter_inventory.size() if itemized else RunState.deck.size()
				seed(chosen_seed)
				EVENTS.complete(id)
				var after: int = RunState.letter_inventory.size() if itemized else RunState.deck.size()
				check(after == before + (1 if win_bonus else 0), "Bonus roll uses existing inventory mode")
				check(EVENTS.complete(id).is_empty(), "Bonus reward also cannot repeat")
				if win_bonus:
					var item: LetterStats = RunState.letter_inventory[-1] if itemized else RunState.deck[-1]
					check(item.level == 1, "Bonus letter is level one")
	setup("treasure_chest")
	var failed: Dictionary = EVENTS.progress("treasure_chest")
	failed.lock_index = 3
	check(EVENTS.rules("treasure_chest").outcome(failed).bonus_chance == 0.0, "Failed chest cannot award bonus")

func _check_entry_ui() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child(viewport)
	var event: Control = load(ScenePaths.TUNDRA_EVENT).instantiate()
	viewport.add_child(event)
	await get_tree().process_frame
	await get_tree().process_frame
	var pos: String = WordNet.pos_name(EVENTS.requested_pos("frozen_traveler"))
	check(event.input.placeholder_text.contains(pos) and event.preview.text.contains(pos), "Entry UI names requested POS")
	event.input.text = "123"
	event._submit()
	check(event.feedback.text.contains(pos) and event.feedback_banner.visible, "Invalid feedback names requested POS")
	check(Rect2(0, 0, 1280, 720).encloses(event.game_panel.get_global_rect()), "Story prompt fits existing panel")
	check(Rect2(0, 0, 1280, 720).encloses(event.input.get_global_rect()), "Story input fits existing layout")
	viewport.queue_free()
	await get_tree().process_frame


func _check_chest_ui() -> void:
	setup("treasure_chest")
	var state: Dictionary = EVENTS.progress("treasure_chest")
	state.locks = EVENTS.rules("treasure_chest").LOCKS.slice(0, 3).duplicate(true)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child(viewport)
	var event: Control = load(ScenePaths.TUNDRA_EVENT).instantiate()
	viewport.add_child(event)
	await get_tree().process_frame
	await get_tree().process_frame
	var original_input: Rect2 = event.input.get_global_rect()
	check(event.heading.text == "Write an adjective" and event.input.has_focus() and event.input.caret_blink, "Chest starts with adjective heading and a focused blinking caret")
	check(event.heading.get_global_rect().end.y < event.instruction.get_global_rect().position.y and event.instruction.get_global_rect().end.y < original_input.position.y, "Heading, hint, and input appear in order")
	check(event.instruction.text == "Hint: " + state.locks[0].clue, "First lock shows the labeled authored clue")
	var frame_texture := preload("res://assets/Themes/encounters/fantasy_panel.svg")
	for panel: PanelContainer in [event.game_panel, event.feedback_banner, event.result_panel]:
		var style := panel.get_theme_stylebox("panel") as StyleBoxTexture
		check(style != null and style.texture == frame_texture, "Chest panel uses the original ornamental texture")
	check(not event.input.has_theme_stylebox_override("normal") and not event.input.has_theme_stylebox_override("focus") and not event.skip.flat, "Original field and decorative Skip styles are restored")
	check(event.locks_row.get_child(0).get_child(0).text.contains("Current") and event.locks_row.get_child(1).get_child(0).text.contains("Sealed"), "Initial lock states differ")
	event.input.text = "quickly"
	event.submit.pressed.emit()
	await get_tree().process_frame
	check(state.guesses == 0 and event.input.has_focus() and event.feedback.text.contains("adjective"), "Invalid input gets feedback and returns focus without spending a guess")
	event.input.text = "warm"
	event.input.caret_column = event.input.text.length()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	viewport.push_input(enter, true)
	check(state.lock_index == 1 and event.input.text.is_empty() and event.input.has_focus(), "Keyboard success advances and restores input immediately")
	check(event.instruction.text == "Hint: " + state.locks[1].clue, "Unlock shows the next lock's initial hint")
	check(event.locks_row.get_child(0).get_child(0).text.contains("Opened") and event.locks_row.get_child(1).get_child(0).text.contains("Current"), "Success updates opened and current indicators")
	check(event.feedback.text.contains("+10 gold") and event.feedback.get_theme_color("font_color") == event.SUCCESS and not event.next_button.visible and RunState.gold == 0, "Green success shows earned gold before payout and requires no next button")
	event.submit.pressed.emit()
	event.skip.pressed.emit()
	check(state.turn == 1 and not event._finished, "Same-transition submission and skip are ignored")
	await get_tree().process_frame
	event.submit.pressed.emit()
	check(state.turn == 1 and event.feedback.text.contains("+10 gold"), "Extra Unlock click leaves success feedback intact")
	event.input.text = "wooden"
	event.submit.pressed.emit()
	await get_tree().process_frame
	check(state.guesses == 1 and event.preview.text == "1 guess remaining" and event.instruction.text == "New Hint: " + state.locks[1].hint, "Wrong answer spends one guess and reveals the retry hint")
	check(state.locks[1].hint != state.locks[1].clue and event.feedback.text == "That adjective doesn't fit. Try again.", "Retry shows distinct authored information and concise feedback")
	event.input.text = "wooden"
	event.submit.pressed.emit()
	await get_tree().process_frame
	check(state.lock_index == 2 and event.locks_row.get_child(1).get_child(0).text.contains("Failed") and event.feedback.text.contains("No guesses left"), "Exhaustion marks failed and advances")
	check(event.instruction.text == "Hint: " + state.locks[2].clue, "Exhaustion resets the hint label and content")
	check(event.input.has_focus() and event.input.get_global_rect() == original_input, "Feedback and lock changes keep the focused input in place")
	event._set_chest_feedback("The locksmith examines the answer, consults a very large book, and places a small brass plaque beneath the keyhole explaining why this particular lock still needs a different adjective.", event.ERROR)
	await get_tree().process_frame
	await get_tree().process_frame
	check(event.feedback.get_line_count() > 1 and event.feedback_banner.get_global_rect().encloses(event.feedback.get_global_rect()), "Long feedback wraps inside the ornamental frame")
	event.skip.pressed.emit()
	check(event._finished and event.locks_row.get_child(2).get_child(0).text.contains("Skipped"), "Skip marks the remaining lock")
	check(RunState.gold == 0 and event.continue_button.visible, "Skip forfeits gold and offers return to map")
	event.reward.text = "Found 30 gold. Bonus: level 1 letter W! The letter has been added to your inventory and is ready to equip for the next encounter."
	await get_tree().process_frame
	await get_tree().process_frame
	check(event.reward.get_line_count() > 1 and event.result_panel.get_global_rect().encloses(event.reward.get_global_rect()), "Long bonus reward wraps inside the results frame")
	check(event.sprite.get_global_rect().end.y < event.game_panel.get_global_rect().position.y and event.continue_button.get_global_rect().end.y <= viewport.size.y, "Results remain clear of the chest and fit the viewport")
	viewport.queue_free()
	await get_tree().process_frame
