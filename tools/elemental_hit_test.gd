extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	RunState.start_new_run()
	RunState.next_enemy_id = "goblin"
	var combat: Control = load(ScenePaths.COMBAT).instantiate()
	add_child(combat)
	await get_tree().process_frame
	combat._state = combat.State.RESOLVING
	combat.enemy._health = 1000
	combat.enemy._max_health = 1000
	var kinds: Array[String] = []
	var hits: Array[int] = []
	combat.enemy.damage_received.connect(func(amount: int, kind: String): hits.append(amount); kinds.append(kind))
	await combat._apply_cast_hits({"damage": 101.4, "lightning_procs": 3}, 0.5)
	assert(combat.enemy._health == 899)
	assert(kinds == ["hit", "lightning", "lightning", "lightning"])
	assert(hits.reduce(func(total: int, value: int): return total + value, 0) == 101)
	assert(combat._secondary_damage_active > 0)
	await get_tree().create_timer(0.8).timeout
	assert(combat._secondary_damage_active == 0)
	combat.enemy.add_burn(12.6)
	combat.enemy.consume_burn()
	assert(kinds.back() == "burn" and hits.back() == 13)
	combat.enemy.add_poison(6.4)
	combat.enemy.consume_poison()
	assert(kinds.back() == "poison" and hits.back() == 6)
	assert(combat.enemy._health == 880)
	await get_tree().create_timer(0.8).timeout
	combat.enemy._health = 5
	combat.enemy.add_burn(10)
	combat.enemy.consume_burn()
	assert(combat._state == combat.State.WON)
	assert(combat._secondary_damage_active == 1)
	await get_tree().create_timer(0.25).timeout
	assert(combat.enemy.sprite.modulate.a > 0.9)
	assert(combat.transition_fade.color.a == 0.0)
	print("ELEMENTAL HIT TEST PASSED: distinct echoes, exact total damage, burn/poison feedback, and lethal-hit presentation")
	get_tree().quit.call_deferred()
