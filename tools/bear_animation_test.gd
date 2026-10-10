extends Node
## Run: Godot --headless --path . res://tools/bear_animation_test.tscn
## Checks the correct four-frame idle art and preserved attack/hurt timing.
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
	RunState.start_new_run()
	RunState.selected_biome = "tundra"
	RunState.encounter_index = 2
	RunState.next_enemy_id = "glacier_bear"
	var combat = load(ScenePaths.COMBAT).instantiate()
	add_child(combat)
	await get_tree().process_frame
	var enemy: Enemy = combat.enemy
	check(enemy.enemy_id == "glacier_bear", "bear spawned")
	check(enemy._idle_atlas.atlas.resource_path.ends_with("Glacier Bear Idle.png"), "correct blue-and-white source")
	check(enemy._idle_atlas.atlas.get_size() == Vector2(2172, 724), "actual source dimensions")
	check(enemy._idle_atlas.filter_clip and enemy.sprite.size.x == 320.0, "framing and display size preserved")
	var region: Rect2 = enemy._idle_atlas.region
	check(region.size == Vector2(543, 410) and region.position.y == 240.0, "idle row cropped to the cell")
	check(is_equal_approx(enemy.sprite.size.x / enemy.sprite.size.y, 543.0 / 410.0), "cropped aspect kept")
	check(is_equal_approx(enemy.sprite.position.y + enemy.sprite.size.y, 470.0), "feet on the ground line")
	check(is_equal_approx(enemy._idle_fps, 2.5), "idle matches Tundra standard at 400ms per frame")
	enemy.set_process(false)
	var order: Array[int] = []
	enemy._idle_elapsed = 0.0
	for i in 7:
		enemy._process(0.0 if i == 0 else 0.401)
		check(enemy._idle_atlas.region.end.x <= 2172 and enemy._idle_atlas.region.end.y <= 724, "frame stays in source bounds")
		order.append(int(enemy._idle_atlas.region.position.x / 543.0))
	check(order == [0, 1, 2, 3, 2, 1, 0], "idle ping-pongs")
	enemy.set_process(true)

	enemy.take_damage(1)
	check(enemy._anim == "hurt" and enemy._idle_atlas.region.position.y == 240.0, "hurt row on hit")
	await get_tree().create_timer(0.45).timeout
	check(enemy._anim == "idle" and enemy._idle_atlas.region.position.y == 240.0, "hurt returns to idle")

	var hp_before: int = RunState.player_health
	combat._enemy_turn()
	await get_tree().create_timer(0.75).timeout
	check(enemy._anim == "attack" and enemy._idle_atlas.region.position.y == 240.0, "attack row plays")
	check(RunState.player_health == hp_before, "no damage before contact frame")
	await get_tree().create_timer(0.6).timeout
	check(RunState.player_health == hp_before - enemy.attack, "damage on contact frame")
	check(combat.strike_fx.is_processing() and combat.strike_fx._number.visible, "strike effect plays")
	await get_tree().create_timer(0.5).timeout
	check(enemy._anim == "idle", "attack returns to idle")
	check(combat.get_node("Layout").position == Vector2.ZERO, "screen shake settles")

	# A hit during the wind-up must not strand the awaiting enemy turn.
	enemy._attack_pending = false
	var landed: Array[bool] = [false]
	enemy.attack_landed.connect(func() -> void: landed[0] = true, CONNECT_ONE_SHOT)
	enemy.play_attack()
	enemy.take_damage(1)
	check(landed[0] and enemy._anim == "hurt", "interrupted attack still lands")

	var map := EncounterRouteMap.new()
	var icon: AtlasTexture = map._enemy_icon(combat.factory.build_spawn_data("glacier_bear"))
	check(icon.region == Rect2(0, 240, 543, 410), "route map icon uses one cell")
	map.free()

	enemy.take_damage(9999)
	check(enemy._anim == "hurt" and enemy._idle_atlas.region.position.y == 240.0, "hurt plays on death")
	await get_tree().create_timer(0.4).timeout
	check(enemy._idle_atlas.region.position == Vector2(0, 240) and not enemy.is_processing(), "last hurt pose held")
	for audio: AudioStreamPlayer in combat.find_children("*", "AudioStreamPlayer", true, false):
		audio.stop()
		audio.stream = null
	combat.queue_free()
	await get_tree().process_frame
	print("Bear animation: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
