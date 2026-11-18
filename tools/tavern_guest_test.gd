extends Node
const GUEST := preload("res://scripts/tavern/tavern_letter_guest.gd")
var checks := 0
var failures := 0


func _ready() -> void:
	PlayerStats._persistence_enabled = false
	OS.set_environment("WORDWOVEN_RUN_ARCHIVE_DIR", "res://.tmp/tavern/guest_test_" + Crypto.new().generate_random_bytes(8).hex_encode())
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var original_cosmetics := PlayerProfile.letter_cosmetics.duplicate()
	var owned := LetterStats.create_item("a", LetterStats.Element.FIRE, 3)
	RunState.use_itemized_letters = true
	RunState.equipped_letters = {"a": owned}
	RunState.letter_inventory = []
	RunState.completed_encounters = []
	RunState.tavern_guest_letter = null
	var first := RunState.tavern_guest_for_shop()
	check(first != owned and first.letter == "a" and first.level == 3, "Guest is a snapshot of an owned letter")
	owned.level = 9
	check(RunState.tavern_guest_for_shop() == first and first.level == 3, "Same guest survives reopening this shop phase")
	RunState.completed_encounters = [1]
	var next := RunState.tavern_guest_for_shop()
	check(next != first and next.level == 9, "Next shop phase refreshes guest")
	check(RunState.equipped_letters.a == owned and RunState.letter_inventory.is_empty(), "Guest selection does not move owned tiles")
	RunState.use_itemized_letters = false
	RunState.deck = [owned]
	RunState.letter_inventory = [LetterStats.create_item("b", LetterStats.Element.WATER)]
	RunState.completed_encounters = [2]
	RunState.tavern_guest_for_shop()
	check(RunState.deck.size() == 1, "Legacy deck is not changed when building the candidate pool")
	RunState.start_new_run()
	check(RunState.tavern_guest_letter == null and RunState.tavern_guest_phase == -1, "New runs clear guest cache")
	var hub: Control = load(ScenePaths.TAVERN).instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	var guest: Node2D = hub.letter_guest
	guest.set_process(false)
	check(guest.get_parent() == hub.panorama.world, "Guest belongs to panorama world")
	var local := guest.position
	var global_before := guest.global_position
	hub.panorama.camera += Vector2(50, 0)
	hub.panorama._apply_camera()
	check(guest.position == local and guest.global_position == global_before - Vector2(50, 0), "Camera panning preserves world position")
	var room: TavernPanorama = hub.panorama
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = guest.info_button.get_global_rect().get_center()
	press.pressed = true
	room._input(press)
	check(room._held_button == guest.info_button, "Visitor is a panorama click target")
	var before_click: Vector2 = guest.position
	guest._rest = 0
	guest._destination = guest.position + Vector2(100, 0)
	guest._process(0.5)
	check(guest.position == before_click, "Visitor holds still during a click")
	press.pressed = false
	room._input(press)
	var inspector := get_tree().get_first_node_in_group("letter_inspector") as LetterInspector
	check(inspector != null, "Click opens letter inspector")
	if inspector != null:
		check(inspector._letter_label.text == guest.stats.letter.to_upper(), "Panel identifies clicked letter")
		check(inspector._element_label.text == guest.stats.element_name_text().to_upper(), "Panel identifies clicked element")
		check(inspector._level_label.text == "Level %d" % guest.stats.level, "Panel shows visitor snapshot level")
		var before_menu := room.camera
		guest._process(1.0)
		room._process(1.0)
		check(guest.position == before_click and room.camera == before_menu and not guest.sprite.is_playing(), "Inspector freezes walking and navigation")
		inspector.queue_free()
		await get_tree().process_frame
	check(not hub._room_menu_open(), "Closing inspector unlocks tavern")
	press.position = guest.info_button.get_global_rect().get_center()
	press.pressed = true
	room._input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = press.position + Vector2(35, 0)
	motion.relative = Vector2(35, 0)
	var before_drag := room.camera
	room._input(motion)
	press.position = motion.position
	press.pressed = false
	room._input(press)
	check(room.camera == room._clamp_camera(before_drag - Vector2(35, 0)), "Dragging over visitor pans the room")
	check(get_tree().get_first_node_in_group("letter_inspector") == null, "Dragging over visitor does not inspect")
	var area := Rect2(640, 740, 1200, 125)
	for id: String in ["warrior", "healer", "rogue", "mage"]:
		PlayerProfile.letter_cosmetics["a"] = id
		var actor := GUEST.new()
		hub.panorama.world.add_child(actor)
		actor.position = Vector2(1280, 805)
		actor.setup(owned, area)
		actor.set_process(false)
		check(actor.cosmetic == PlayerProfile.cosmetic_resource(id), "Assigned cosmetic used: " + id)
		actor._rest = 0
		actor._destination = actor.position + Vector2(-100, 0)
		actor._play(&"walk")
		actor._process(0.25)
		check(actor.position.x < 1280 and actor.sprite.flip_h, "Walks and faces left: " + id)
		check(actor.sprite.animation == actor.cosmetic.animation_for(&"walk"), "Uses cosmetic walk mapping: " + id)
		actor.blocked = func(): return true
		var stopped: Vector2 = actor.position
		actor._process(1.0)
		check(actor.position == stopped and not actor.sprite.is_playing(), "Menus freeze movement and animation: " + id)
		actor.blocked = Callable()
		for frame: int in 300:
			actor._process(0.1)
		check(area.has_point(actor.position), "Wandering stays on the floor: " + id)
		actor.queue_free()
	PlayerProfile.letter_cosmetics = original_cosmetics
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-guest="):
			guest.info_button.tooltip_text = ""
			guest.info_button.pressed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			inspector = get_tree().get_first_node_in_group("letter_inspector") as LetterInspector
			var powers_scroll: Control = inspector._powers_list.get_parent()
			check(powers_scroll.get_global_rect().end.y <= get_viewport().get_visible_rect().end.y, "Inspector content fits the screen")
			var pointer := InputEventMouseMotion.new()
			pointer.position = Vector2(12, 700)
			pointer.global_position = pointer.position
			Input.parse_input_event(pointer)
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png(argument.get_slice("=", 1)) == OK, "Visitor panel preview saved")
	print("TAVERN GUEST TEST: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
