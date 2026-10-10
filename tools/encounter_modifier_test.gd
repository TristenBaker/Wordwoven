extends Node
const MODIFIERS = preload("res://scripts/modifiers/encounter_modifier.gd")
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
	var validator := WordValidator.new()
	add_child(validator)
	check(validator.validate("merciless", "a").valid, "adjective accepted")
	for word: String in ["", "a", "merciless!", "asdfghjk", "quickly"]:
		check(not validator.validate(word, "a").valid, "invalid adjective rejected: " + word)
	var factory := EnemyFactory.new()
	add_child(factory)
	for stage: int in [1, 3, 6]:
		RunState.start_new_run()
		RunState.selected_biome = "tundra"
		RunState.encounter_index = stage
		var id: String = factory.ids_for_stage(stage)[0]
		for entry: Dictionary in MODIFIERS.ENTRIES:
			RunState.start_new_run()
			RunState.selected_biome = "tundra"
			RunState.encounter_index = stage
			var base: Dictionary = factory.build_spawn_data(id)
			var adjusted: Dictionary = MODIFIERS.apply_spawn(base, entry)
			for stat: String in ["health", "attack"]:
				var expected: int = maxi(1, int(round(base[stat] * entry.factor))) if entry.stat == stat else int(base[stat])
				check(adjusted[stat] == expected, entry.id + " " + stat)
			check(MODIFIERS.player_factor(entry) == (entry.factor if entry.stat == "player_damage" else 1.0), entry.id + " player factor")
			var before: int = base.health
			adjusted.health = 1
			check(base.health == before, "spawn not mutated")
			RunState.cache_encounter_modifier(id, "merciless", entry.id)
			var cached: Dictionary = RunState.cache_encounter_modifier(id, "gentle", "doommarked")
			check(cached.modifier_id == entry.id and cached.word == "merciless", "no reroll")
			var combat = load(ScenePaths.COMBAT).instantiate()
			RunState.next_enemy_id = id
			add_child(combat)
			check(combat._encounter_modifier.id == entry.id, "combat consumes fate")
			check(combat.enemy._max_health == (int(round(base.health * entry.factor)) if entry.stat == "health" else base.health), "combat HP")
			check(combat.enemy.attack == (int(round(base.attack * entry.factor)) if entry.stat == "attack" else base.attack), "combat attack")
			check(combat.get_node("Layout/ActiveModifierPanel/Content/ModifierName").text == "Modifier: " + entry.name, "indicator")
			var panel = combat.get_node("Layout/ActiveModifierPanel")
			check(panel.effect_label.text == entry.effect, "panel displays catalogue effect only")
			await get_tree().process_frame
			check(is_equal_approx(panel.get_global_rect().position.y, combat.timer_label.get_global_rect().end.y + 10.0), "panel directly below quick-cast timer")
			check(is_equal_approx(panel.get_global_rect().end.y + 8.0, combat.dev_kill_button.get_global_rect().position.y), "Dev Auto Kill directly below banner")
			check(panel.get_global_rect().position.x == combat.dev_kill_button.get_global_rect().position.x and panel.get_global_rect().end.x == combat.dev_kill_button.get_global_rect().end.x, "Banner and button edges match")
			check(combat.dev_kill_button.size == Vector2(264, 40), "Dev Auto Kill dimensions preserved")
			check(not panel.get_global_rect().intersects(combat.get_node("Layout/StatusArea").get_global_rect()), "panel clears status UI")
			check(RunState.pending_encounter_modifier.is_empty(), "consumed once")
			check(RunState.word_history.is_empty() and combat.cold.heat == 0 and combat.cold.turns == 0 and combat.cold.frozen.is_empty(), "preparation no combat effects")
			if stage == 1 and entry.stat == "player_damage":
				# No relic procs: compare deterministic base damage with the encounter factor.
				RunState.relics.clear()
				var split: Dictionary = combat.deck_manager.split_word("ox")
				var expected: Dictionary = combat.calculator.calculate("ox", split.drawn, split.undrawn, combat.enemy.tags, combat.required_pos, combat.enemy.affinities, false, combat._turn_elapsed_seconds)
				combat._refresh_word_composer("ox")
				check(combat.damage_output.text == str(int(round(float(expected.damage) * entry.factor))), "preview includes player factor")
				var hp_before: int = combat.enemy._health
				combat.word_input.text = "ox"
				combat._on_submit()
				check(not RunState.word_history.is_empty(), "real accepted cast recorded")
				check(is_equal_approx(RunState.word_history.back().damage, float(expected.damage) * entry.factor), "real cast player multiplier")
				var deadline: int = Time.get_ticks_msec() + 6000
				while combat._state != combat.State.PLAYER_INPUT and Time.get_ticks_msec() < deadline:
					await get_tree().process_frame
				check(combat.enemy._health == hp_before - int(round(float(expected.damage) * entry.factor)), "actual enemy HP reduction")
				check(combat._state == combat.State.PLAYER_INPUT, "modified cast returns to input")
				check(combat._encounter_modifier.id == entry.id and panel.name_label.text == "Modifier: " + entry.name, "modifier persists across turns")
			await get_tree().process_frame
			for audio: AudioStreamPlayer in combat.find_children("*", "AudioStreamPlayer", true, false):
				audio.stop()
				audio.stream = null
			remove_child(combat)
			combat.queue_free()
			await get_tree().process_frame
			check(RunState.take_encounter_modifier(id).is_empty(), "cannot consume twice")
	RunState.cache_encounter_modifier("frost_wyrm", "merciless", "titanbound")
	RunState.advance_encounter()
	check(RunState.take_encounter_modifier("frost_wyrm").is_empty(), "stale stage rejected")
	RunState.cache_encounter_modifier("wolf", "merciless", "titanbound")
	check(RunState.take_encounter_modifier("bear").is_empty(), "wrong enemy rejected")
	RunState.cache_encounter_modifier("wolf", "merciless", "titanbound")
	RunState.start_new_run()
	check(RunState.pending_encounter_modifier.is_empty(), "new run clean")
	# No preparation, wrong enemy, and stale stage must all produce an unmodified fight.
	for scenario: String in ["none", "wrong_enemy", "stale_stage"]:
		RunState.start_new_run()
		RunState.selected_biome = "tundra"
		RunState.next_enemy_id = "frostfang_wolf"
		if scenario != "none":
			RunState.cache_encounter_modifier("glacier_bear" if scenario == "wrong_enemy" else "frostfang_wolf", "strong", "titanbound")
			if scenario == "stale_stage":
				RunState.pending_encounter_modifier.encounter = 0
		var base: Dictionary = factory.build_spawn_data("frostfang_wolf")
		var combat = load(ScenePaths.COMBAT).instantiate()
		add_child(combat)
		check(combat._encounter_modifier.is_empty(), "no active fate: " + scenario)
		check(combat.enemy._max_health == base.health and combat.enemy.attack == base.attack, "unmodified stats: " + scenario)
		check(combat.get_node("Layout/ActiveModifierPanel/Content/ModifierName").text == "No Active Modifier", "empty panel: " + scenario)
		check(RunState.pending_encounter_modifier.is_empty(), "invalid preparation discarded: " + scenario)
		combat.queue_free()
		await get_tree().process_frame
	print("Encounter modifiers: ", failures, " failures; all six effects at first/normal/boss stages")
	get_tree().quit(1 if failures else 0)
