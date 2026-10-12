extends Node
## Application preferences, independent of runs and gameplay.
const CONFIG_PATH: String = "user://settings.cfg"
const DEFAULTS: Dictionary = {
	"display_mode": 2, "resolution": Vector2i(1280, 720),
	"master_volume": 50.0, "music_volume": 50.0, "sfx_volume": 50.0,
}
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
var preferences: Dictionary = DEFAULTS.duplicate(true)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	get_tree().node_added.connect(_on_node_added)
	load_preferences()
	apply_preferences(preferences)
	_route_existing_audio.call_deferred()

func _route_existing_audio() -> void:
	for type_name: String in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		for player: Node in get_tree().root.find_children("*", type_name, true, false):
			_route_audio(player)

func _ensure_audio_buses() -> void:
	for bus: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")

func _on_node_added(node: Node) -> void:
	if not (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
		return
	# Route after the player has finished initializing its bus/playback state.
	_route_audio.call_deferred(node)

func _route_audio(node: Node) -> void:
	if not is_instance_valid(node):
		return
	# Respect explicitly routed players. Current music uses these existing assets;
	# stream-less pooled party voices are effects and receive SFX before playback.
	if node.bus != &"Master":
		return
	var path: String = node.stream.resource_path if node.stream != null else ""
	var music: bool = path.begins_with("res://assets/Art/Music/") or path == "res://assets/Audio/Death.mp3"
	node.bus = &"Music" if music else &"SFX"

func supported_resolutions() -> Array[Vector2i]:
	var options: Array[Vector2i] = []
	var available: Vector2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	for resolution: Vector2i in RESOLUTIONS:
		if resolution == DEFAULTS.resolution or (resolution.x <= available.x and resolution.y <= available.y):
			options.append(resolution)
	return options

func _sanitize(values: Dictionary) -> Dictionary:
	var clean: Dictionary = DEFAULTS.duplicate(true)
	var mode = values.get("display_mode", DEFAULTS.display_mode)
	if mode is int:
		clean.display_mode = clampi(mode, 0, 2)
	var resolution = values.get("resolution", DEFAULTS.resolution)
	if resolution is Vector2i and resolution in RESOLUTIONS:
		clean.resolution = resolution
	for key: String in ["master_volume", "music_volume", "sfx_volume"]:
		var volume = values.get(key, DEFAULTS[key])
		if (volume is float or volume is int) and is_finite(float(volume)):
			clean[key] = clampf(float(volume), 0.0, 100.0)
	return clean

func load_preferences(path: String = CONFIG_PATH) -> void:
	var config := ConfigFile.new()
	var values: Dictionary = DEFAULTS.duplicate(true)
	if config.load(path) == OK:
		for key: String in DEFAULTS:
			values[key] = config.get_value("settings", key, DEFAULTS[key])
	preferences = _sanitize(values)

func save_and_apply(values: Dictionary, path: String = CONFIG_PATH) -> Error:
	var clean: Dictionary = _sanitize(values)
	var config := ConfigFile.new()
	for key: String in clean:
		config.set_value("settings", key, clean[key])
	var error: Error = config.save(path)
	if error == OK:
		apply_preferences(clean)
	return error

func apply_preferences(values: Dictionary) -> void:
	preferences = _sanitize(values)
	_apply_display()
	for entry: Array in [["Master", "master_volume"], ["Music", "music_volume"], ["SFX", "sfx_volume"]]:
		var index: int = AudioServer.get_bus_index(entry[0])
		var linear: float = float(preferences[entry[1]]) / 100.0
		AudioServer.set_bus_mute(index, linear <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))

func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Keep the project's 1280x720 canvas and aspect ratio; only resize the window.
	var window: Window = get_window()
	if preferences.display_mode == 0:
		window.borderless = false
		window.mode = Window.MODE_FULLSCREEN
		return
	window.mode = Window.MODE_WINDOWED
	var screen: int = DisplayServer.window_get_current_screen()
	if preferences.display_mode == 1:
		window.borderless = true
		window.size = DisplayServer.screen_get_size(screen)
		window.position = DisplayServer.screen_get_position(screen)
	else:
		window.borderless = false
		var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
		var requested: Vector2i = preferences.resolution
		var fitted := Vector2i(mini(requested.x, usable.size.x), mini(requested.y, usable.size.y))
		# Move off the maximized frame first: macOS ignores resizing that frame.
		window.position = usable.position + Vector2i(Vector2(usable.size - fitted) / 2.0)
		window.size = fitted
