extends Node
## Run: Godot --headless --path . res://tools/tundra_sim_test.tscn
var failures: int = 0

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	var factory := EnemyFactory.new()
	add_child(factory)
	# Every possible regular-monster ordering must obey the run contract.
	var regulars: Array[String] = EnemyFactory.TUNDRA_REGULARS
	for a in regulars:
		for b in regulars:
			for c in regulars:
				for d in regulars:
					if a == b or a == c or a == d or b == c or b == d or c == d:
						continue
					RunState.start_new_run()
					RunState.selected_biome = "tundra"
					var last_hp: int = 0
					var last_attack: int = 0
					for id in ["frostfang_wolf", a, b, c, d, "frost_wyrm"]:
						var choices := factory.ids_for_stage(RunState.encounter_index)
						check(choices.has(id), "available " + id)
						check(choices.size() == (1 if RunState.encounter_index in [1, 6] else 6 - RunState.encounter_index), "choice count")
						for defeated in RunState.defeated_enemy_ids:
							check(not choices.has(defeated), "no repeats")
						var data := factory.build_spawn_data(id)
						check(data.health > last_hp and data.attack >= last_attack, "difficulty grows")
						last_hp = data.health
						last_attack = data.attack
						RunState.complete_encounter(id)
						RunState.advance_encounter()
	print("Checked all 24 Tundra encounter orders")
	RunState.start_new_run()
	RunState.selected_biome = "tundra"
	check(RunState.defeated_enemy_ids.is_empty(), "new run clears roster")
	for stage in range(1, 7):
		RunState.encounter_index = stage
		# Invalid/stale selections must never override the opener/boss/remaining roster.
		RunState.next_enemy_id = "rat"
		var combat = load(ScenePaths.COMBAT).instantiate()
		add_child(combat)
		await get_tree().process_frame
		var enemy: Enemy = combat.enemy
		check(factory.ids_for_stage(stage).has(enemy.enemy_id), "valid spawn")
		check(enemy.enemy_id == "frostfang_wolf" if stage == 1 else enemy.enemy_id == "frost_wyrm" if stage == 6 else enemy.enemy_id in regulars, "fixed endpoints")
		var data := factory.build_spawn_data(enemy.enemy_id)
		check(enemy.name_label.text == data.name, "name UI")
		check(enemy.health_bar.value == data.health and enemy.attack == data.attack, "stats UI")
		check(enemy._idle_atlas.atlas.resource_path == data.texture, "correct sheet")
		var expected_frames: int = 8 if enemy.enemy_id == "frost_wyrm" else 4
		check(enemy._idle_frames == expected_frames, "idle frame count")
		check((enemy.sprite.material != null) == (enemy.enemy_id == "tundra_behemoth"), "Behemoth matte only")
		check(combat.background.texture == null and combat.layered_background != null \
				and combat.layered_background._layers.size() == combat.TUNDRA_LAYERS.size(), "layered background")
		enemy.set_process(false)
		# Legacy idles run at half speed; grid sheets keep their Aseprite timing.
		var speed: float = 1.0 if data.cell_width > 0 else 0.5
		check(is_equal_approx(enemy._idle_fps, data.idle_fps * speed), "idle FPS")
		var step: float = 1.0 / enemy._idle_fps
		var rest_position: Vector2 = enemy.sprite.position
		var rest_scale: Vector2 = enemy.sprite.scale
		var rest_size: Vector2 = enemy.sprite.size
		enemy._idle_elapsed = 0.0
		enemy._process(step * 0.5)
		check(is_zero_approx(enemy._idle_atlas.region.position.x), "frame held for its full duration")
		enemy._idle_elapsed = 0.0
		# Ping-pong idles turn around at the last frame instead of wrapping.
		var cycle: int = expected_frames * 2 - 2 if data.idle_ping_pong else expected_frames
		for frame in range(1, cycle * 2 + 1):
			enemy._process(step + 0.001)
			var index: int = frame % cycle
			if index >= expected_frames:
				index = cycle - index
			check(is_equal_approx(enemy._idle_atlas.region.position.x, index * enemy._idle_width), "two complete loops")
		check(enemy.sprite.position == rest_position and enemy.sprite.scale == rest_scale and enemy.sprite.size == rest_size, "idle preserves placement and size")
		enemy.set_process(true)
		var old_x: float = enemy._idle_atlas.region.position.x
		await get_tree().create_timer(step * 1.05).timeout
		check(enemy._idle_atlas.region.position.x != old_x, "idle advances during combat")
		check(combat.hand_box.get_child_count() == 8 and combat.word_input.editable, "word input and hand")
		enemy.set_projected_damage(3)
		check(enemy.health_preview.visible, "damage preview")
		enemy.take_damage(3)
		check(enemy.health_bar.value == data.health - 3, "damage and health bar")
		var hp_before: int = RunState.player_health
		combat._enemy_turn()
		await get_tree().create_timer(2.0).timeout
		check(RunState.player_health == hp_before - enemy.attack, "retaliation damage")
		RunState.heal_player(50)
		var gold_before: int = RunState.gold
		enemy.take_damage(9999)
		check(RunState.defeated_enemy_ids.has(enemy.enemy_id), "victory records defeated id")
		check(RunState.completed_encounters.has(stage) and RunState.gold > gold_before, "victory rewards")
		check(RunState.pending_victory_enemy == enemy.enemy_name, "victory presentation")
		combat.queue_free()
		await get_tree().process_frame
		if stage < 6:
			RunState.advance_encounter()
			var selection = load(ScenePaths.ENCOUNTER_SELECT).instantiate()
			add_child(selection)
			check(
				selection.route_map._buttons.size() \
						== (1 if stage == 5 else 5 - stage),
				"selection map nodes"
			)
			selection.queue_free()
			await get_tree().process_frame
	RunState.start_new_run()
	check(factory.ids_for_stage(1).has("rat") and factory.boss_id() == "dragon", "legacy encounters unchanged")
	print("Tundra simulation: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
