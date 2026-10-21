extends Node
const RUNTIME = preload("res://data/balance/encounter_modifier_runtime.gd")
const MODIFIERS = preload("res://data/balance/encounter_modifier.gd")
var failures: int = 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	var enemies: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/enemies.json"))
	var tag_catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/chameleon_tags.json"))
	for enemy_id: String in enemies:
		check(tag_catalogue.has(enemy_id), "authored Chameleon pairs cover " + enemy_id)
		for pair: Array in tag_catalogue[enemy_id]:
			check(pair.size() == 2 and pair[0] != pair[1], "two distinct semantic tags")
			for tag: String in pair:
				check(enemies[enemy_id].tag_pool.has(tag), "Chameleon tags belong to monster identity")
	# Deterministic counter and arithmetic tests, including read-only previews.
	for id: String in ["drowsy", "clumsy", "long_winded", "echo_bound", "chameleon", "greedy", "frostbite_tax"]:
		var runtime = RUNTIME.new()
		runtime.configure(MODIFIERS.definition(id), 10, "frostfang_wolf")
		for turn in range(6):
			var result: Dictionary = {"damage": 20.0, "gold": 0}
			runtime.modify_result(result, "elephant" if turn % 2 == 0 else "tree")
			check(runtime.casts == turn and runtime.retaliations == turn, id + " preview does not advance state")
			if id == "long_winded":
				check(result.damage == (24.0 if turn % 2 == 0 else 20.0), "long-word direct damage")
				check(int(result.get("modifier_guard", 0)) == (0 if turn % 2 == 0 else 2), "short-word guard")
			if id == "echo_bound":
				check(result.damage == (25.0 if turn > 0 else 20.0), "echo chain damage")
			var bonus: int = runtime.accept_cast("elephant" if turn % 2 == 0 else "tree")
			check(bonus == (1 if id == "greedy" and turn < 5 else 0), "cast gold cap")
			var plan: Dictionary = runtime.retaliation_plan(10)
			if id == "drowsy":
				check(plan.kind == ("sleep" if turn % 2 == 0 else "attack") and plan.attack == 13, "sleep first; awake attack rounded +25%")
			if id == "clumsy":
				check(plan.kind == ("self_hit" if turn % 3 == 2 else "attack"), "third retaliation self-hit")
				if turn % 3 == 2: check(plan.self_damage == 5.0, "self-hit base attack half")
			var stolen: int = runtime.complete_retaliation(100)
			check(stolen == (2 if id == "greedy" and turn in [1, 3] else 0), "theft timing and cap")
		check(runtime.victory_bonus() == (8 if id == "greedy" else 0), "victory bonus")
	var echo = RUNTIME.new()
	echo.configure(MODIFIERS.definition("echo_bound"), 10, "rat")
	echo.accept_cast("cat")
	var unlinked: Dictionary = {"damage": 20.0, "gold": 0}
	echo.modify_result(unlinked, "dog")
	check(unlinked.damage == 20.0, "unlinked valid words remain usable at normal damage")
	var poor = RUNTIME.new()
	poor.configure(MODIFIERS.definition("greedy"), 10, "rat")
	poor.complete_retaliation(0)
	check(poor.complete_retaliation(1) == 1 and poor.gold_stolen == 1, "theft limited by available gold")
	var cold := TundraCold.new()
	cold.reset(true)
	cold.freeze_every = 2
	cold.heat_per_word = 2
	var hand: Array[LetterStats] = []
	for letter: String in "abcdefgh": hand.append(LetterStats.create(letter))
	for turn in range(12):
		cold.accept_word()
		cold.freeze_after_turn(hand)
		if turn == 0: check(cold.frozen.is_empty() and cold.heat == 2, "tax first turn heat; no freeze")
		if turn == 1: check(cold.frozen.size() == 1 and cold.heat == 4, "tax second turn freeze")
	check(cold.heat == 5 and cold.frozen.size() == 3, "tax retains heat cap and five usable letters")
	var frozen_tile: LetterStats = cold.frozen[0]
	check(cold.thaw(frozen_tile) and cold.heat == 3 and not cold.frozen.has(frozen_tile), "tax thaw still costs two heat")
	cold.reset(true)
	check(cold.freeze_every == 3 and cold.heat_per_word == 1, "next encounter restores cold defaults")
	# Actual combat scenes: invalid words, preview/cast equality, all turn effects,
	# tag identity/stat preservation and duplicate victory prevention.
	for id: String in ["drowsy", "clumsy", "long_winded", "echo_bound", "chameleon", "greedy", "frostbite_tax"]:
		RunState.start_new_run()
		RunState.selected_biome = "tundra"
		RunState.relics.clear()
		RunState.next_enemy_id = "frostfang_wolf"
		RunState.cache_encounter_modifier("frostfang_wolf", "strong", id)
		var combat = load(ScenePaths.COMBAT).instantiate()
		add_child(combat)
		await get_tree().process_frame
		var original_size: Vector2i = get_tree().root.size
		var panel = combat.get_node("Layout/ActiveModifierPanel")
		for resolution: Vector2i in AppSettings.RESOLUTIONS:
			get_tree().root.size = resolution
			await get_tree().process_frame
			await get_tree().process_frame
			check(panel.size.x == 264 and panel.size.y >= panel.get_combined_minimum_size().y, id + " status fits at " + str(resolution))
			check(not combat.has_node("Layout/DevKillButton"), id + " debug kill control moved to F12")
			check(not panel.get_global_rect().intersects(combat.get_node("Layout/StatusArea").get_global_rect()), id + " status does not overlap existing UI")
		get_tree().root.size = original_size
		combat.set_process(false) # Freeze quick-cast time while asserting exact preview equality.
		combat.enemy._health = 10000
		combat.enemy.attack = 4
		var original_tags: Array[String] = combat.enemy.tags.duplicate()
		var enemy_name: String = combat.enemy.enemy_name
		var max_hp: int = combat.enemy._max_health
		combat.word_input.text = "zzxqjy"
		combat._on_submit()
		check(combat._modifier_runtime.casts == 0 and combat.cold.turns == 0, id + " invalid does not advance")
		for turn in range(3):
			# Force a valid noun each turn to isolate modifier tests from POS rotation.
			combat.required_pos = "n"
			combat.cold.frozen.clear()
			combat._refresh_cold()
			var word: String = ["elephant", "tree", "egg"][turn]
			combat._refresh_word_composer(word)
			var preview: int = int(combat.damage_output.text)
			var hp_before: int = combat.enemy._health
			var player_before: int = RunState.player_health
			combat.word_input.text = word
			combat._on_submit()
			combat._on_submit()
			check(combat._modifier_runtime.casts == turn + 1, id + " accepted once despite repeated submit")
			check(int(round(float(RunState.word_history.back().damage))) == preview, id + " preview matches cast")
			var deadline: int = Time.get_ticks_msec() + 10000
			while combat._state != combat.State.PLAYER_INPUT and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
			check(combat._state == combat.State.PLAYER_INPUT, id + " turn completes")
			check(combat._modifier_runtime.retaliations == turn + 1, id + " retaliation commits once")
			var self_hit: int = int(round(combat._modifier_runtime.base_attack * 0.5)) if id == "clumsy" and turn == 2 else 0
			check(combat.enemy._health == hp_before - preview - self_hit, id + " actual HP matches direct preview plus self-hit")
			if id == "drowsy": check(RunState.player_health == player_before - (5 if turn == 1 else 0), "actual sleep/awake damage")
			if id == "clumsy" and turn == 2: check(RunState.player_health == player_before, "self-hit spares player")
			if id == "long_winded" and turn > 0: check(RunState.player_health == player_before - 2, "short word guard actually reduces retaliation")
			if id == "frostbite_tax":
				check(combat.cold.heat == mini(5, (turn + 1) * 2), "actual tax heat")
				check(combat.cold.frozen.size() == (1 if turn == 1 else 0), "actual tax second accepted turn freezes")
			if id == "chameleon" and turn == 1:
				check(combat.enemy.tags != original_tags and combat.enemy.tags.size() == 2, "authored tag shift")
				check(combat.enemy.enemy_name == enemy_name and combat.enemy._max_health == max_hp and combat.enemy.attack == 4, "tag shift preserves identity/stats")
				check(combat.enemy.tags_label.text.contains(combat.enemy.tags[0]), "new weakness displayed")
		if id == "greedy": check(combat._modifier_runtime.gold_gained == 3 and combat._modifier_runtime.gold_stolen == 2, "actual greedy counters")
		if id == "clumsy":
			# A self-hit may finish the encounter; no player hit or next turn follows.
			combat._modifier_runtime.retaliations = 2
			combat.enemy._health = 1
			combat._state = combat.State.RESOLVING
			var before_self_gold: int = RunState.gold
			var before_self_hp: int = RunState.player_health
			combat._enemy_turn()
			var self_deadline: int = Time.get_ticks_msec() + 6000
			while combat._state != combat.State.WON and Time.get_ticks_msec() < self_deadline:
				await get_tree().process_frame
			check(combat._state == combat.State.WON and RunState.gold == before_self_gold + combat.enemy.gold_reward and RunState.player_health == before_self_hp, "self-hit victory rewards once and spares player")
			combat._on_enemy_died()
			check(RunState.gold == before_self_gold + combat.enemy.gold_reward, "self-hit duplicate reward prevented")
			combat.queue_free()
			await get_tree().process_frame
			continue
		var before_gold: int = RunState.gold
		var reward: int = combat.enemy.gold_reward + (8 if id == "greedy" else 0)
		combat.enemy.take_damage(999999)
		check(RunState.gold == before_gold + reward and combat._state == combat.State.WON, id + " victory reward")
		combat._on_enemy_died()
		check(RunState.gold == before_gold + reward, id + " no duplicate victory reward")
		combat.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	print("Expanded modifiers: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
