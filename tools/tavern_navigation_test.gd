extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var hub: Control = load(ScenePaths.TAVERN).instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	var room: TavernPanorama = hub.panorama
	assert(room._points.size() == 6)
	assert(room._clamp_camera(Vector2(-100, -100)) == Vector2.ZERO)
	assert(room._clamp_camera(Vector2(99999, 99999)) == (room.ROOM_SIZE - room.size).max(Vector2.ZERO))
	var initial := room.camera
	var offscreen := 0
	for indicator: Button in room._indicators.values():
		if indicator.visible:
			offscreen += 1
	assert(offscreen > 0)
	# Hovering no longer pans; dragging follows the pointer instead.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(650, 600)
	motion.relative = Vector2(40, 0)
	room._input(motion)
	assert(room.camera == initial)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = Vector2(610, 600)
	press.pressed = true
	room._input(press)
	room._input(motion)
	assert(room.camera == room._clamp_camera(initial - Vector2(40, 0)))
	press.position = motion.position
	press.pressed = false
	room._input(press)
	assert(not room._pointer_down)
	for id: String in room._points:
		room.focus_poi(id)
		room.camera = room._target
		room._apply_camera()
		var center: Vector2 = room._points[id].center - room.camera
		assert(Rect2(Vector2.ZERO, room.size).has_point(center))
		assert(not room._indicators[id].visible)
	# A drag that begins over an interactive table must not open its menu.
	room.focus_poi("minigames")
	room.camera = room._target
	room._turning = false
	room._apply_camera()
	var before_drag := room.camera
	press.position = hub.minigames_button.get_global_rect().get_center()
	press.pressed = true
	room._input(press)
	motion.position = press.position + Vector2(40, 0)
	motion.relative = Vector2(40, 0)
	room._input(motion)
	press.position = motion.position
	press.pressed = false
	room._input(press)
	assert(not hub.minigames_popup.visible)
	assert(room.camera == room._clamp_camera(before_drag - Vector2(40, 0)))
	# A stationary click still opens the table's menu.
	press.position = hub.minigames_button.get_global_rect().get_center()
	press.pressed = true
	room._input(press)
	press.pressed = false
	room._input(press)
	assert(hub.minigames_popup.visible)
	hub.minigames_popup.hide()
	room.camera = initial
	room._turning = false
	room._apply_camera()
	hub.minigames_button.pressed.emit()
	assert(hub.minigames_popup.visible and hub._room_menu_open())
	room._process(1.0)
	assert(room.camera == initial)
	hub.minigames_popup.hide()
	hub.leaderboard_button.pressed.emit()
	assert(hub.get_node_or_null("LeaderboardOverlay") != null and hub._room_menu_open())
	hub.get_node("LeaderboardOverlay").queue_free()
	await get_tree().process_frame
	# Both NPCs now open the existing shop UI over this same tavern instance.
	RunState.gold = 100
	RunState.player_health = 20
	RunState.player_max_health = 50
	hub.left_arrow.pressed.emit()
	var shop: Control = hub.get_node("TavernShopOverlay")
	var barkeeper: Control = shop.get_child(1)
	assert(barkeeper.embedded and barkeeper.menu_panel.visible)
	assert(hub._room_menu_open())
	barkeeper.meal_button.pressed.emit()
	await get_tree().process_frame
	assert(RunState.player_health == 20 + EconomySystem.MEAL_HEAL)
	assert(RunState.gold == 100 - EconomySystem.MEAL_PRICE)
	assert(hub.health_label.text.contains(str(RunState.player_health)))
	barkeeper.close_button.pressed.emit()
	await get_tree().process_frame
	assert(not is_instance_valid(shop))
	hub.right_arrow.pressed.emit()
	shop = hub.get_node("TavernShopOverlay")
	var dealer: Control = shop.get_child(1)
	assert(dealer.embedded and dealer.menu_panel.visible)
	assert(dealer.offers_grid.get_child_count() == 6)
	var before_shop := room.camera
	room._process(1.0)
	assert(room.camera == before_shop)
	if "--capture-tavern" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://.tmp/tavern")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.tmp/tavern/shop.png")
	dealer.close_button.pressed.emit()
	await get_tree().process_frame
	assert(not hub._room_menu_open())
	assert(room.mouse_default_cursor_shape == Control.CURSOR_ARROW)
	# A single stream/player continues at its current position across activities.
	TavernMusic.sync_scene(ScenePaths.TAVERN)
	TavernMusic.player.seek(5.0)
	for path: String in [ScenePaths.TAVERN_LEFT, ScenePaths.TAVERN_RIGHT, ScenePaths.FORGE, ScenePaths.WORD_GAME, ScenePaths.HANDWRITING_GAME, ScenePaths.HANDWRITING_LAB]:
		TavernMusic.sync_scene(path)
		assert(TavernMusic.player.playing)
		assert(TavernMusic.player.get_playback_position() >= 4.9)
	TavernMusic.sync_scene(ScenePaths.COMBAT)
	assert(not TavernMusic.player.playing)
	# Optional render artifact for reviewing composition in a real renderer.
	if "--capture-tavern" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://.tmp/tavern")
		get_viewport().get_texture().get_image().save_png("res://.tmp/tavern/overview.png")
		for id: String in ["dealer", "minigames"]:
			room.focus_poi(id)
			room.camera = room._target
			room._turning = false
			room._apply_camera()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://.tmp/tavern/" + id + ".png")
	print("TAVERN NAVIGATION PASSED: dragging, six POIs, embedded shops, purchases, menu camera lock, and continuous music")
	get_tree().quit.call_deferred()
