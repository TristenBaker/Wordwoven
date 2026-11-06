extends Node
var failures: int = 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var original: Dictionary = AppSettings.preferences.duplicate(true)
	if DisplayServer.get_name() != "headless":
		await _test_windows(original)
	var path: String = "/tmp/wordwoven-settings-test-%d.cfg" % OS.get_process_id()
	var desired: Dictionary = {"display_mode": 1, "resolution": Vector2i(1920, 1080), "master_volume": 80.0, "music_volume": 70.0, "sfx_volume": 0.0}
	desired = AppSettings.DEFAULTS.merged(desired, true)
	check(AppSettings.save_and_apply(desired, path) == OK, "save settings")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))), 0.8), "master gain")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))), 0.7), "music gain")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "zero mutes SFX")
	AppSettings.preferences = AppSettings.DEFAULTS.duplicate(true)
	AppSettings.load_preferences(path)
	check(AppSettings.preferences == desired, "all settings persisted")
	var clean: Dictionary = AppSettings._sanitize({"display_mode": 99, "resolution": Vector2i(-1, 0), "master_volume": -1.0, "music_volume": 110.0})
	check(clean.display_mode == 2 and clean.resolution == Vector2i(1280, 720) and clean.master_volume == 0 and clean.music_volume == 100, "invalid values bounded")
	for pair: Array in [["res://assets/Art/Music/1 - Whispers of the Eldertree (Loop).mp3", "Music"], ["res://assets/Audio/Death.mp3", "Music"], ["res://assets/Audio/party/enemy_death.wav", "SFX"]]:
		var player := AudioStreamPlayer.new()
		player.stream = load(pair[0])
		add_child(player)
		await get_tree().process_frame
		check(player.bus == StringName(pair[1]), "route " + pair[0])
		check(AudioServer.get_bus_send(AudioServer.get_bus_index(player.bus)) == &"Master", "child bus sends to Master")
		player.queue_free()
	var pooled := AudioStreamPlayer.new()
	add_child(pooled)
	await get_tree().process_frame
	check(pooled.bus == &"SFX", "streamless pooled effects routed")
	pooled.queue_free()
	var screen = load("res://scenes/settings_screen.tscn").instantiate()
	add_child(screen)
	screen.open()
	check(screen.mode_option.selected == 1 and screen.resolution_option.disabled, "borderless controls populated")
	check(screen.music.value == 70 and screen.get_node("%MusicPercent").text == "70%", "saved slider percent")
	screen.music.value = 42
	check(screen.get_node("%MusicPercent").text == "42%", "percent updates")
	screen.close()
	screen.open()
	check(screen.music.value == 70, "Back preserves applied settings")
	screen.mode_option.select(2)
	screen._refresh_display_hint()
	check(not screen.resolution_option.disabled, "windowed resolution enabled")
	await _test_scaling()
	screen.queue_free()
	DirAccess.remove_absolute(path)
	AppSettings.apply_preferences(original)
	await get_tree().process_frame
	print("Settings tests: ", failures, " failures")
	get_tree().quit(1 if failures else 0)


func _test_windows(original: Dictionary) -> void:
	var screen = load("res://scenes/settings_screen.tscn").instantiate()
	add_child(screen)
	screen.open()
	for mode: int in [2, 0, 1, 2]:
		var values: Dictionary = original.duplicate(true)
		values.display_mode = mode
		AppSettings.apply_preferences(values)
		await get_tree().create_timer(2.0).timeout
		var expected: int = DisplayServer.WINDOW_MODE_FULLSCREEN if mode == 0 else DisplayServer.WINDOW_MODE_WINDOWED
		check(DisplayServer.window_get_mode() == expected, "native window mode " + str(mode))
		if mode != 0:
			check(DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS) == (mode == 1), "borderless flag " + str(mode))
		print("Display mode ", mode, " actual ", DisplayServer.window_get_mode(), " size ", DisplayServer.window_get_size())
		var panel: Control = screen.get_node("Center/Panel")
		check(Rect2(Vector2.ZERO, screen.size).encloses(panel.get_global_rect()), "settings fits mode " + str(mode))
	for resolution: Vector2i in AppSettings.supported_resolutions():
		var values: Dictionary = original.duplicate(true)
		values.display_mode = 2
		values.resolution = resolution
		AppSettings.apply_preferences(values)
		await get_tree().create_timer(0.4).timeout
		var usable: Vector2i = DisplayServer.screen_get_usable_rect().size
		check(DisplayServer.window_get_size() == Vector2i(mini(resolution.x, usable.x), mini(resolution.y, usable.y)), "window resolution " + str(resolution))
		check(get_tree().root.content_scale_size == Vector2i(1280, 720), "canvas unchanged")
		print("Resolution ", resolution, " actual ", DisplayServer.window_get_size())
	# Native window changes must survive saving unchanged display preferences.
	var values: Dictionary = original.duplicate(true)
	values.display_mode = 2
	values.resolution = Vector2i(1280, 720)
	AppSettings.apply_preferences(values)
	var window: Window = get_window()
	for mode: Window.Mode in [Window.MODE_WINDOWED, Window.MODE_MAXIMIZED, Window.MODE_FULLSCREEN]:
		window.mode = mode
		if mode == Window.MODE_WINDOWED:
			window.size = Vector2i(1440, 810)
		await get_tree().create_timer(0.5).timeout
		var actual_mode: Window.Mode = window.mode
		var actual_size: Vector2i = window.size
		check(actual_mode == mode, "native mode entered " + str(mode))
		values.master_volume = 31.0
		values.auto_equip_enabled = not values.auto_equip_enabled
		var path: String = "/tmp/wordwoven-window-test-%d.cfg" % OS.get_process_id()
		check(AppSettings.save_and_apply(values, path) == OK, "save unrelated preferences")
		await get_tree().create_timer(0.5).timeout
		check(window.mode == actual_mode and window.size == actual_size, "native window preserved " + str(mode))
		DirAccess.remove_absolute(path)
	# A changed display preference must still deliberately exit native fullscreen.
	values.resolution = Vector2i(1600, 900)
	AppSettings.apply_preferences(values)
	await get_tree().create_timer(0.5).timeout
	check(window.mode == Window.MODE_WINDOWED, "changed display preference applied")
	AppSettings.apply_preferences(original)
	screen.queue_free()


func _test_scaling() -> void:
	var window: Window = get_window()
	var original_size: Vector2i = window.size
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1600, 1000), Vector2i(2560, 1080)]:
		window.size = resolution
		await get_tree().process_frame
		check(window.content_scale_size == Vector2i(1280, 720), "design canvas preserved")
		check(window.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "canvas item scaling")
		check(window.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "aspect ratio preserved")
		var scale: Vector2 = window.get_final_transform().get_scale()
		var expected: float = minf(float(window.size.x) / 1280.0, float(window.size.y) / 720.0)
		check(is_equal_approx(scale.x, expected) and is_equal_approx(scale.y, expected), "uniform scaling " + str(resolution))
	window.size = original_size
