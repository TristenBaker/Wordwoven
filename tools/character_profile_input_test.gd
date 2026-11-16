extends Node
var failures := 0
func _ready() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func mouse(at: Vector2, down: bool, button: int) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = button
	event.pressed = down
	get_viewport().push_input(event, true)
func close_profile() -> void:
	var panel := get_tree().get_first_node_in_group("letter_inspector")
	if panel != null:
		panel.queue_free()
	await get_tree().process_frame
func _run() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	RunState.start_new_run()
	var combat = load(ScenePaths.COMBAT).instantiate()
	add_child(combat)
	await get_tree().process_frame
	await get_tree().process_frame
	var tile = combat.hand_box.get_child(0)
	var at: Vector2 = tile.get_global_rect().get_center()
	mouse(at, true, MOUSE_BUTTON_RIGHT)
	mouse(at, false, MOUSE_BUTTON_RIGHT)
	await get_tree().process_frame
	check(get_tree().get_first_node_in_group("letter_inspector") != null, "Combat right click opens profile")
	await close_profile()
	mouse(at, true, MOUSE_BUTTON_LEFT)
	await get_tree().create_timer(0.6).timeout
	mouse(at, false, MOUSE_BUTTON_LEFT)
	await get_tree().process_frame
	check(get_tree().get_first_node_in_group("letter_inspector") != null, "Combat hold opens profile")
	await close_profile()
	var info: Button = tile.find_child("InspectProfile", true, false)
	check(info != null, "Combat has a visible profile button")
	if info != null:
		at = info.get_global_rect().get_center()
		mouse(at, true, MOUSE_BUTTON_LEFT)
		mouse(at, false, MOUSE_BUTTON_LEFT)
		await get_tree().process_frame
		check(get_tree().get_first_node_in_group("letter_inspector") != null, "Combat info click opens profile")
		await close_profile()
	var equipment = combat.get_node("EquipmentOverlay")
	equipment.panel.show()
	await get_tree().process_frame
	await get_tree().process_frame
	var slot: Button
	for candidate: Button in equipment.slots_grid.get_children():
		if candidate.letter_stats != null:
			slot = candidate
			break
	check(slot != null, "Test has an equipped letter")
	if slot == null:
		get_tree().quit(1)
		return
	var original: LetterStats = slot.letter_stats
	at = slot.get_global_rect().get_center()
	mouse(at, true, MOUSE_BUTTON_RIGHT)
	mouse(at, false, MOUSE_BUTTON_RIGHT)
	await get_tree().process_frame
	check(get_tree().get_first_node_in_group("letter_inspector") != null, "Equipment right click opens profile")
	check(RunState.equipped_letters.get(original.letter) == original, "Inspection does not unequip")
	await close_profile()
	info = slot.find_child("InspectProfile", true, false)
	at = info.get_global_rect().get_center()
	mouse(at, true, MOUSE_BUTTON_LEFT)
	mouse(at, false, MOUSE_BUTTON_LEFT)
	await get_tree().process_frame
	check(get_tree().get_first_node_in_group("letter_inspector") != null, "Equipment info click opens profile")
	check(RunState.equipped_letters.get(original.letter) == original, "Info click does not unequip")
	await close_profile()
	combat.queue_free()
	await get_tree().process_frame
	var portrait = load("res://scenes/tavern/character_portrait.tscn").instantiate()
	add_child(portrait)
	portrait.size = Vector2(300, 300)
	portrait.show_member(original)
	await get_tree().process_frame
	await get_tree().process_frame
	info = portrait.find_child("InspectProfile", true, false)
	at = info.get_global_rect().get_center()
	mouse(at, true, MOUSE_BUTTON_LEFT)
	mouse(at, false, MOUSE_BUTTON_LEFT)
	await get_tree().process_frame
	check(get_tree().get_first_node_in_group("letter_inspector") != null, "Tavern portrait info opens profile")
	await close_profile()
	portrait.queue_free()
	print("Profile input tests: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
