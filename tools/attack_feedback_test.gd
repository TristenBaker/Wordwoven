extends Node
## Run: Godot --headless --path . tools/attack_feedback_test.tscn.

var failures: int = 0

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func _run() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for id: String in definitions:
		RunState.start_new_run()
		RunState.selected_biome = definitions[id].get("biome", "")
		RunState.encounter_index = 6 if id == "frost_wyrm" else (2 if id in EnemyFactory.TUNDRA_REGULARS else 1)
		RunState.next_enemy_id = id
		var combat = load(ScenePaths.COMBAT).instantiate()
		add_child(combat)
		await get_tree().process_frame
		var enemy: Enemy = combat.enemy
		var rest: Vector2 = enemy.sprite.position
		var bar_rest: Vector2 = combat.player_health_bar.position
		var scale_before: Vector2 = enemy.sprite.scale
		var rotation_before: float = enemy.sprite.rotation
		var texture_before: Texture2D = enemy.sprite.texture
		var hp_before: int = RunState.player_health
		var saw_lunge: bool = false
		var saw_shake: bool = false
		var saw_idle_advance: bool = false
		var idle_before: float = enemy._idle_elapsed
		combat._enemy_turn()
		var deadline: int = Time.get_ticks_msec() + 6000
		while combat._state != combat.State.PLAYER_INPUT and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
			saw_lunge = saw_lunge or enemy.sprite.position.distance_to(rest) > 1.0
			if combat.player_health_bar.position != bar_rest:
				saw_shake = true
				check(RunState.player_health < hp_before, id + ": shake starts after damage")
				check(is_equal_approx(combat.player_health_bar.position.y, bar_rest.y), id + ": shake remains horizontal")
			saw_idle_advance = saw_idle_advance or enemy._idle_elapsed != idle_before
		check(enemy.enemy_id == id, id + ": correct monster tested")
		check(saw_lunge, id + ": lunge visible")
		check(saw_shake, id + ": health bar shake visible")
		check(RunState.player_health == hp_before - enemy.attack, id + ": damage unchanged")
		check(enemy.sprite.position == rest, id + ": sprite returns exactly")
		check(combat.player_health_bar.position == bar_rest, id + ": health bar returns exactly")
		check(enemy.sprite.scale == scale_before and enemy.sprite.rotation == rotation_before and enemy.sprite.texture == texture_before, id + ": sprite presentation preserved")
		check(enemy._anim == "idle", id + ": attack returns to idle")
		if enemy._idle_frames > 1:
			check(saw_idle_advance, id + ": idle keeps advancing")
		# Rapidly restart both visual tweens to detect accumulated position offsets.
		for repeat: int in 3:
			enemy.begin_retaliation_lunge(Vector2.ZERO)
			enemy.finish_retaliation_lunge()
			combat._health_bar_shake.play(combat.player_health_bar)
			await get_tree().create_timer(0.045).timeout
		enemy.begin_retaliation_lunge(Vector2.ZERO)
		enemy.finish_retaliation_lunge()
		combat._health_bar_shake.play(combat.player_health_bar)
		await get_tree().create_timer(0.35).timeout
		check(enemy.sprite.position == rest and combat.player_health_bar.position == bar_rest, id + ": overlapping attacks do not drift")
		# Burn/poison can trigger the existing hit flash just before retaliation.
		enemy.take_damage(1.0)
		enemy.begin_retaliation_lunge(Vector2.ZERO)
		enemy.finish_retaliation_lunge()
		check(enemy._hit_tween.is_running() and enemy.sprite.modulate != Color.WHITE, id + ": lunge preserves hit feedback")
		await get_tree().create_timer(0.35).timeout
		check(enemy.sprite.position == rest and enemy.sprite.modulate == Color.WHITE, id + ": combined hit and lunge return exactly")
		# A fully blocked attack still lunges, but must not shake the health bar.
		if id == "frost_wyrm":
			hp_before = RunState.player_health
			combat._guard = enemy.attack
			combat._enemy_turn()
			deadline = Time.get_ticks_msec() + 6000
			while combat._state != combat.State.PLAYER_INPUT and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
				check(combat.player_health_bar.position == bar_rest, "Blocked blow does not shake health bar")
			check(RunState.player_health == hp_before, "Blocked damage unchanged")
		combat.queue_free()
		await get_tree().process_frame
	print("Attack feedback: %d monsters, %d failures" % [definitions.size(), failures])
	get_tree().quit(1 if failures else 0)
