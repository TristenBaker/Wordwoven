extends Node
## Headless simulation of the tavern: exercises the economy
## (upgrades, classes, modifiers, dropping letters, relics, meals)
## and checks the storyteller produces a tale from history.
##
## Run from the project root:
##   godot --headless --path . res://tools/tavern_sim_test.tscn

var _failures: int = 0


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	RunState.start_new_run()
	RunState.record_word(
		"torrent", "Red Dragon", ["fiery"], 31.0
	)
	RunState.record_word(
		"pebble", "Red Dragon", ["fiery"], 4.0
	)
	RunState.damage_player(20)
	var scene: PackedScene = load(ScenePaths.TAVERN)
	var tavern: Control = scene.instantiate()
	get_tree().root.add_child(tavern)
	await get_tree().process_frame
	await get_tree().process_frame
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
	print("=== %d failure(s) ===" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  " + label)
	else:
		print("  FAIL  " + label)
		_failures += 1
