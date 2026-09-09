extends Node
## Headless simulation of a combat encounter: spawns the combat
## scene, plays an invalid word, plays a real word, waits out the
## enemy retaliation, then finishes the fight. Exits non-zero on
## any failed expectation.
##
## Run from the project root:
##   godot --headless --path . res://tools/combat_sim_test.tscn

var _failures: int = 0


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	var scene: PackedScene = load(ScenePaths.COMBAT)
	var combat: Control = scene.instantiate()
	get_tree().root.add_child(combat)
	await get_tree().process_frame
	await get_tree().process_frame
	var enemy: Enemy = combat.enemy
	_expect(
		not enemy.enemy_name.is_empty(), "enemy spawned"
	)
	_expect(not enemy.tags.is_empty(), "enemy has tags")
	print("  enemy: %s %s" % [enemy.enemy_name, enemy.tags])
	_expect(
		combat.hand_box.get_child_count() == 8,
		"hand deals 8 tiles"
	)
	# An invalid word is rejected with a reason.
	combat.word_input.text = "zzxqjy"
	combat._on_submit()
	_expect(
		not combat.feedback_label.text.is_empty(),
		"nonsense word rejected"
	)
	# A real word deals damage and the enemy hits back.
	var health_before: int = enemy._health
	var player_before: int = RunState.player_health
	combat.word_input.text = "flame"
	combat._on_submit()
	await get_tree().process_frame
	_expect(
		enemy._health < health_before,
		"flame dealt damage (%d -> %d)" % [
			health_before, enemy._health
		]
	)
	_expect(
		RunState.word_history.size() == 1, "word recorded"
	)
	await get_tree().create_timer(2.0).timeout
	_expect(
		RunState.player_health < player_before,
		"enemy retaliated (%d -> %d)" % [
			player_before, RunState.player_health
		]
	)
	_expect(
		combat.word_input.editable, "input returned to player"
	)
	# Repeating a word is rejected.
	combat.word_input.text = "flame"
	combat._on_submit()
	_expect(
		combat.feedback_label.text == "Already played this fight",
		"repeat word rejected"
	)
	# Finishing the enemy shows the victory panel and pays gold.
	var gold_before: int = RunState.gold
	enemy.take_damage(999.0)
	await get_tree().process_frame
	_expect(
		combat.victory_panel.visible, "victory panel shown"
	)
	_expect(
		RunState.gold > gold_before,
		"gold paid (%d -> %d)" % [gold_before, RunState.gold]
	)
	print("=== %d failure(s) ===" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  " + label)
	else:
		print("  FAIL  " + label)
		_failures += 1
