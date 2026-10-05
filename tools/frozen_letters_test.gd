extends Node
## Full combat integration plus deterministic edge cases. Run with --headless.
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	RunState.start_new_run()
	RunState.selected_biome = "tundra"
	var combat = load(ScenePaths.COMBAT).instantiate()
	add_child(combat)
	await get_tree().process_frame
	combat.enemy._health = 10000
	combat.enemy.attack = 0
	check(combat.heat_meter.visible and combat.cold.heat == 0, "Tundra starts cold")
	combat.word_input.text = "zzxqjy"
	combat._on_submit()
	check(combat.cold.turns == 0 and combat.cold.heat == 0, "invalid word gives no heat or turn")
	for word: String in ["cat", "run", "big"]:
		combat.word_input.text = word
		combat._on_text_changed(word)
		combat._on_submit()
		for frame in range(900):
			await get_tree().process_frame
			if combat._state == combat.State.PLAYER_INPUT:
				break
		check(combat._state == combat.State.PLAYER_INPUT, "combat returns to input: " + word)
		if word != "big":
			check(combat.cold.frozen.is_empty(), "no early freeze")
	check(combat.cold.heat == 3 and combat.cold.turns == 3, "three words grant three Heat")
	check(combat.cold.frozen.size() == 1, "third turn freezes exactly one tile")
	if combat.cold.frozen.is_empty():
		get_tree().quit(1)
		return
	var frozen: LetterStats = combat.cold.frozen[0]
	var tile: LetterTile = combat._hand_tile_for(frozen)
	check(tile.frozen and tile._badge.text.begins_with("THAW"), "frost has affordable cue")
	var blocked_word: String = frozen.letter.repeat(12)
	combat.word_input.text = blocked_word
	combat._on_text_changed(blocked_word)
	check(combat.word_input.text.is_empty(), "keyboard/paste cannot draft frozen letters")
	combat.word_input.text = blocked_word
	combat._on_submit()
	check(combat.cold.heat == 3 and combat.cold.turns == 3, "submission guard prevents bypass")
	check(not combat.deck_manager.split_word(blocked_word).drawn.has(frozen), "frozen tile excluded from damage/party selections")
	combat.cold.heat = 1
	combat._refresh_cold()
	combat._on_hand_tile_activated(tile)
	check(combat.cold.heat == 1 and tile.frozen, "insufficient heat cannot thaw or spend")
	combat.cold.heat = 2
	combat._state = combat.State.ENEMY_TURN
	combat._on_hand_tile_activated(tile)
	check(combat.cold.heat == 2 and tile.frozen, "thaw blocked outside player turn")
	combat._state = combat.State.PLAYER_INPUT
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	tile._gui_input(click)
	click.pressed = false
	tile._gui_input(click)
	check(combat.cold.heat == 0 and not tile.frozen, "click spends exactly two and thaws immediately")
	check(combat.deck_manager.split_word(frozen.letter).drawn.has(frozen), "thawed letter usable immediately")
	var rules := TundraCold.new()
	rules.reset(true)
	var hand: Array[LetterStats] = []
	for character: String in "abcdefgh":
		hand.append(LetterStats.create(character))
	for turn in range(30):
		rules.accept_word()
		rules.freeze_after_turn(hand)
	check(rules.heat == 5, "Heat capped at five")
	check(rules.frozen.size() == 3, "never freezes duplicates and always leaves five usable")
	var duplicate: LetterStats = LetterStats.create(rules.frozen[0].letter)
	hand.append(duplicate)
	check(rules.blocked_letter(duplicate.letter, hand).is_empty(), "unfrozen duplicate remains usable")
	check(not rules.blocked_letter(duplicate.letter.repeat(2), hand).is_empty(), "duplicate cannot substitute for frozen occurrence")
	rules.reset(false)
	rules.accept_word()
	check(rules.heat == 0 and rules.frozen.is_empty() and rules.freeze_after_turn(hand) == null, "reset and non-Tundra isolation")
	var gold_before: int = RunState.gold
	combat.enemy.take_damage(999999)
	check(combat._state == combat.State.WON and RunState.gold > gold_before, "Tundra victory and rewards intact")
	combat.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("Frozen Letters integration: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
