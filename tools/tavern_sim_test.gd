extends Node
## Headless simulation of the tavern: exercises the economy
## (recruits, dismissals, meals), haggling challenges and their
## persistence, purchase confirmations, and the storyteller.
##
## Run from the project root:
##   godot --headless --path . res://tools/tavern_sim_test.tscn

var _failures: int = 0
var _challenge_results: Array[bool] = []


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	await _test_economy_and_story()
	await _test_typing_challenge()
	await _test_haggling()
	await _test_confirmations()
	print("=== %d failure(s) ===" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _test_economy_and_story() -> void:
	print("-- economy and story --")
	RunState.start_new_run()
	RunState.record_word(
		"torrent", "Red Dragon", ["fiery"], 31.0
	)
	RunState.record_word(
		"pebble", "Red Dragon", ["fiery"], 4.0
	)
	RunState.damage_player(20)
	var tavern: Control = await _open_tavern()
	var economy: EconomySystem = tavern.economy
	var first: LetterStats = RunState.deck[0]
	_expect(RunState.deck.size() == 18, "starter party has 18 letters")
	_expect(first.letter_class == LetterStats.LetterClass.HEALER,
			"starter vowel is a healer")
	RunState.add_gold(500)
	var offers: Array[Dictionary] = economy.recruitment_offers()
	_expect(offers.size() == 6, "six recruit offers")
	var recruit_index: int = 0
	_expect(economy.buy_recruit(recruit_index), "recruit bought")
	_expect(RunState.deck.size() == 19, "recruit joined party")
	var deck_size: int = RunState.deck.size()
	_expect(
		economy.drop_letter(RunState.deck[1]),
		"letter dismissed for gold"
	)
	_expect(
		RunState.deck.size() == deck_size - 1,
		"deck shrank by one"
	)
	_expect(economy.recruit_price("z") == 20, "rare recruit costs 20g")
	var health_before: int = RunState.player_health
	_expect(economy.buy_meal(), "meal bought")
	_expect(
		RunState.player_health > health_before, "meal healed"
	)
	var bard: Storyteller = Storyteller.new()
	var tale: String = bard.generate()
	print("--- tale ---")
	print(tale)
	print("------------")
	_expect(tale.contains("TORRENT"), "tale features played word")
	var visible_letters: int = tavern.vowel_grid.get_child_count()
	visible_letters += tavern.common_grid.get_child_count()
	visible_letters += tavern.uncommon_grid.get_child_count()
	_expect(visible_letters == RunState.deck.size(),
			"deck grids match deck")
	await _close(tavern)


func _test_typing_challenge() -> void:
	print("-- typing challenge --")
	var tavern: Control = await _open_tavern()
	var challenge: TypingChallenge = tavern.haggle_challenge
	var clock: ManualClock = ManualClock.new()
	challenge.clock = clock
	challenge.finished.connect(_on_challenge_finished)
	var prompt: Dictionary = {"pos": "n", "letter": "q"}
	var validator: Callable = HaggleChallenge.validate.bind(prompt)

	_challenge_results = []
	challenge.open("Type a noun containing Q", validator, 15000)
	clock.advance(5000)
	_expect(not challenge.submit("zzzq"), "invalid answer is rejected")
	_expect(challenge.is_active()
			and not challenge.feedback_label.text.is_empty(),
			"invalid answer can be corrected in the same countdown")
	clock.advance(10000)
	_expect(challenge.submit("queen"),
			"valid answer at the deadline succeeds")
	_expect(_challenge_results == [true], "success reported once")

	_challenge_results = []
	challenge.open("Type a noun containing Q", validator, 15000)
	clock.advance(15001)
	challenge.tick()
	_expect(not challenge.is_active() and _challenge_results == [false],
			"timeout ends the challenge as a failure")
	_expect(not challenge.submit("queen"),
			"answers after timeout are ignored")

	_challenge_results = []
	challenge.open("Type a noun containing Q", validator, 15000)
	challenge.cancel()
	_expect(_challenge_results == [false], "leaving counts as a failure")

	_expect(not HaggleChallenge.validate("queen", {
		"pos": "n", "letter": "z",
	})["valid"], "answer must contain the offered letter")
	_expect(not HaggleChallenge.validate("quickly", {
		"pos": "n", "letter": "q",
	})["valid"], "answer must match the part of speech")
	_expect(not HaggleChallenge.validate("quits", {
		"pos": "v", "letter": "q",
	})["valid"], "verb prompts require base forms")
	_expect(HaggleChallenge.validate("quit", {
		"pos": "v", "letter": "q",
	})["valid"], "base-form verb accepted")
	_expect(WordNet.words_containing("q", "r", 5).size() > 0,
			"lexicon supplies adverbs containing Q")
	challenge.finished.disconnect(_on_challenge_finished)
	await _close(tavern)


func _test_haggling() -> void:
	print("-- haggling --")
	RunState.start_new_run()
	RunState.add_gold(100)
	var tavern: Control = await _open_tavern()
	var economy: EconomySystem = tavern.economy
	var offers: Array[Dictionary] = economy.recruitment_offers()
	var solvable: bool = true
	for offer: Dictionary in offers:
		var prompt: Dictionary = offer.get("haggle_prompt", {})
		solvable = solvable and not prompt.is_empty() \
				and HaggleChallenge.validate(
					prompt["solution"], prompt
				)["valid"] \
				and prompt["letter"] == offer["letter"]
	_expect(solvable, "every offer has a verified, solvable prompt")
	_expect(HaggleChallenge.discounted_price(10) == 8
			and HaggleChallenge.discounted_price(20) == 16,
			"haggling takes 20% off (10g -> 8g, 20g -> 16g)")

	var rare_index: int = -1
	for index: int in offers.size():
		if economy.recruit_price(offers[index]["letter"]) == 20:
			rare_index = index
	var common_index: int = 0
	while economy.recruit_price(offers[common_index]["letter"]) != 10:
		common_index += 1
	var rare_prompt: Dictionary = offers[rare_index]["haggle_prompt"]

	# Win the rare offer's haggle through the tavern screen.
	tavern._on_haggle_pressed(rare_index)
	_expect(tavern.haggle_challenge.is_active(), "haggle opens a challenge")
	_expect(not economy.can_haggle(rare_index),
			"starting a haggle consumes the attempt")
	tavern._on_haggle_pressed(common_index)
	_expect(economy.can_haggle(common_index),
			"a second haggle cannot start while one is open")
	tavern.haggle_challenge.submit("zzzz")
	_expect(tavern.haggle_challenge.is_active(),
			"invalid haggle answer keeps the countdown")
	tavern.haggle_challenge.submit(rare_prompt["solution"])
	_expect(economy.offer_price(rare_index) == 16,
			"winning the haggle discounts 20g to 16g")
	_expect(not RunState.recruitment_stock[rare_index]["purchased"]
			and RunState.gold == 100,
			"winning the haggle does not buy the recruit")

	# Lose the common offer's haggle by leaving.
	tavern._on_haggle_pressed(common_index)
	tavern.haggle_challenge.cancel()
	_expect(economy.offer_price(common_index) == 10,
			"leaving the haggle keeps the original price")
	_expect(economy.begin_haggle(common_index).is_empty(),
			"only one attempt per offer")

	# An interrupted haggle cannot be won after reopening the tavern.
	var third_index: int = 0
	while third_index == rare_index or third_index == common_index:
		third_index += 1
	var third_prompt: Dictionary = economy.begin_haggle(third_index)
	await _close(tavern)
	tavern = await _open_tavern()
	economy = tavern.economy
	var third_base: int = economy.recruit_price(
		RunState.recruitment_stock[third_index]["letter"]
	)
	_expect(not economy.finish_haggle(third_index, true)
			and economy.offer_price(third_index) == third_base,
			"reopened tavern cannot win an interrupted haggle")
	_expect(economy.begin_haggle(third_index).is_empty(),
			"reopening the tavern does not reset attempts")
	_expect(economy.offer_price(rare_index) == 16,
			"discount persists after reopening")
	_expect(economy.recruitment_offers()[third_index]["haggle_prompt"]
			== third_prompt,
			"prompt persists after reopening")
	_expect(economy.buy_recruit(rare_index) and RunState.gold == 84,
			"discounted recruit charges 16g")
	await _close(tavern)


func _test_confirmations() -> void:
	print("-- confirmations --")
	RunState.start_new_run()
	RunState.add_gold(100)
	RunState.damage_player(20)
	var tavern: Control = await _open_tavern()
	var economy: EconomySystem = tavern.economy
	var confirmer: ActionConfirmer = tavern.confirmer
	var price: int = economy.offer_price(0)

	tavern._on_recruit_pressed(0)
	_expect(confirmer.is_pending(), "recruiting asks for confirmation")
	_expect(confirmer.dialog_text.contains("%dg" % price),
			"confirmation shows the exact cost")
	tavern._on_recruit_pressed(1)
	_expect(confirmer.dialog_text.contains("%dg" % price),
			"a second request cannot replace an open confirmation")
	confirmer.decline()
	_expect(RunState.gold == 100 and RunState.deck.size() == 18,
			"cancelled recruitment changes nothing")
	tavern._on_recruit_pressed(0)
	confirmer.approve()
	confirmer.approve()
	_expect(RunState.gold == 100 - price and RunState.deck.size() == 19,
			"approved recruitment charges once")

	tavern._on_recruit_pressed(1)
	var stale_price: int = economy.offer_price(1)
	_expect(economy.buy_recruit(1), "offer bought elsewhere meanwhile")
	var gold_before: int = RunState.gold
	confirmer.approve()
	_expect(RunState.gold == gold_before and RunState.deck.size() == 20,
			"stale confirmation is revalidated and charges nothing")
	_expect(gold_before == 100 - price - stale_price, "only real buys paid")

	tavern._on_meal_pressed()
	_expect(confirmer.dialog_text.contains("15g"), "meal shows its cost")
	confirmer.decline()
	var health: int = RunState.player_health
	_expect(RunState.gold == gold_before, "cancelled meal is free")
	tavern._on_meal_pressed()
	confirmer.approve()
	_expect(RunState.player_health == health + 10, "confirmed meal heals")

	var dismissed: LetterStats = RunState.deck[2]
	tavern._on_letter_selected(dismissed)
	tavern._on_drop_pressed()
	_expect(confirmer.dialog_text.contains("10g"),
			"dismissal shows its cost")
	confirmer.decline()
	_expect(RunState.deck.has(dismissed), "cancelled dismissal keeps letter")
	tavern._on_drop_pressed()
	confirmer.approve()
	_expect(not RunState.deck.has(dismissed), "confirmed dismissal")
	await _close(tavern)


func _open_tavern() -> Control:
	var tavern: Control = load(ScenePaths.TAVERN).instantiate()
	add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame
	return tavern


func _close(tavern: Control) -> void:
	tavern.queue_free()
	await get_tree().process_frame


func _on_challenge_finished(success: bool) -> void:
	_challenge_results.append(success)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  " + label)
	else:
		print("  FAIL  " + label)
		_failures += 1
