extends Node
## Historical timer rules plus current combat integration.
var failures: int = 0

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	RunState.start_new_run()
	RunState.next_enemy_id = "goblin"
	var combat = load(ScenePaths.COMBAT).instantiate()
	add_child(combat)
	combat.set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	check(combat._turn_elapsed_seconds == 0.0 and combat.timer_label.text == "Quick-cast: 20.0s  •  Damage ×1.50", "Encounter begins with original bonus and formatting")
	check(combat.timer_label.get_global_rect().position.y > combat.gold_label.get_global_rect().end.y and combat.timer_label.get_global_rect().end.y < combat.get_node("Layout/ActiveModifierPanel").get_global_rect().position.y, "Timer sits below Gold and clears modifier panel")
	check(combat.timer_label.get_theme_font("font") == load("res://assets/Fonts/Junicode.ttf"), "Timer uses fantasy font")
	var split: Dictionary = combat.deck_manager.split_word("ox")
	var base: Dictionary = combat.calculator.calculate("ox", split.drawn, split.undrawn, combat.enemy.tags, "n", combat.enemy.affinities)
	for elapsed: float in [0.0, 5.0, 10.0, 20.0, 30.0]:
		var result: Dictionary = combat.calculator.calculate("ox", split.drawn, split.undrawn, combat.enemy.tags, "n", combat.enemy.affinities, false, elapsed)
		var factor: float = 1.5 - minf(elapsed, 20.0) * 0.025
		check(is_equal_approx(result.speed_multiplier, factor) and is_equal_approx(result.damage, base.damage * factor), "Original linear damage factor at %.1fs" % elapsed)
		check(result.gold == base.gold and result.water_heal == base.water_heal and result.nature_poison == base.nature_poison and result.earth_guard == base.earth_guard and result.ice_slow == base.ice_slow and result.elemental_damage == base.elemental_damage, "Current elemental effects unchanged")
	combat._process(10.0)
	check(combat.timer_label.text == "Quick-cast: 10.0s  •  Damage ×1.25", "Countdown updates")
	combat.word_input.text = "ox"
	combat._on_text_changed("ox")
	check(combat.damage_output.text == str(int(round(base.damage * 1.25))), "Preview reflects remaining quick-cast bonus")
	combat._process(10.0)
	check(combat.timer_label.text == "Quick-cast: 0.0s  •  Damage ×1.00" and combat.damage_output.text == str(int(round(base.damage))), "Expired display resets to original zero and normal damage")
	combat.word_input.text = "zzzzzz"
	combat._on_submit()
	check(combat._turn_elapsed_seconds == 20.0, "Rejected word does not restart bonus")
	combat._enter_player_input()
	combat._process(10.0)
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	check(combat._turn_elapsed_seconds == 10.0, "Pause preserves timer")
	get_tree().paused = false
	# Compose the restored factor with the separate adjective modifier once.
	combat._encounter_modifier = {"stat": "player_damage", "factor": 1.1}
	combat.enemy._health = 10000
	combat.enemy._max_health = 10000
	combat.word_input.text = "ox"
	combat._on_submit()
	check(is_equal_approx(RunState.word_history.back().damage, base.damage * 1.25 * 1.1), "Cast applies speed and adjective exactly once")
	var elapsed_at_cast: float = combat._turn_elapsed_seconds
	combat._process(2.0)
	check(combat._turn_elapsed_seconds == elapsed_at_cast, "Attack animation does not consume timer")
	var deadline: int = Time.get_ticks_msec() + 6000
	while combat._state != combat.State.PLAYER_INPUT and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(combat._state == combat.State.PLAYER_INPUT and combat._turn_elapsed_seconds == 0.0, "Next player turn refreshes bonus without stacking")
	check(combat.enemy._health == 10000 - int(round(base.damage * 1.25 * 1.1)), "Actual HP loss matches timed cast")
	combat._state = combat.State.WON
	combat._process(5.0)
	check(combat._turn_elapsed_seconds == 0.0, "Encounter end stops countdown")
	for audio: AudioStreamPlayer in combat.find_children("*", "AudioStreamPlayer", true, false):
		audio.stop()
		audio.stream = null
	combat.queue_free()
	await get_tree().process_frame
	RunState.next_enemy_id = "goblin"
	var next_combat = load(ScenePaths.COMBAT).instantiate()
	add_child(next_combat)
	next_combat.set_process(false)
	check(next_combat._turn_elapsed_seconds == 0.0 and next_combat.timer_label.text == "Quick-cast: 20.0s  •  Damage ×1.50", "Fresh encounter receives fresh timer")
	for audio: AudioStreamPlayer in next_combat.find_children("*", "AudioStreamPlayer", true, false):
		audio.stop()
		audio.stream = null
	next_combat.queue_free()
	await get_tree().process_frame
	print("Quick-cast restoration: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
