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
	AppSettings.apply_preferences(original)
	screen.queue_free()
