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
			check(combat.get_node("Layout/FateIndicator").text.contains(entry.name), "indicator")
			check(RunState.pending_encounter_modifier.is_empty(), "consumed once")
			check(RunState.word_history.is_empty() and combat.cold.heat == 0 and combat.cold.turns == 0 and combat.cold.frozen.is_empty(), "preparation no combat effects")
			if stage == 1 and entry.stat == "player_damage":
				var split: Dictionary = combat.deck_manager.split_word("ox")
				var expected: Dictionary = combat.calculator.calculate("ox", split.drawn, split.undrawn, combat.enemy.tags, combat.required_pos, combat._turn_elapsed_seconds)
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
	print("Encounter modifiers: ", failures, " failures; all six effects at first/normal/boss stages")
	get_tree().quit(1 if failures else 0)
