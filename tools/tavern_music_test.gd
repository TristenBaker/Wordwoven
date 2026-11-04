extends Node
## Real scene transitions verify one uninterrupted, correctly routed voice.
const TAVERN_PAGE: String = "res://scenes/tavern/tavern.tscn"
const EQUIPMENT: PackedScene = preload(
	"res://scenes/ui/equipment_overlay.tscn"
)
var failures: int = 0
var checks: int = 0
var _player: AudioStreamPlayer
var _playback_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _go(path: String) -> void:
	_check(get_tree().change_scene_to_file(path) == OK, "Load " + path)
	await _settle_scene()


func _follow(action: Callable) -> void:
	action.call()
	await _settle_scene()


func _settle_scene() -> void:
	await get_tree().scene_changed
	await get_tree().process_frame
	await get_tree().process_frame


func _music_count() -> int:
	var count: int = 0
	for audio: AudioStreamPlayer in get_tree().root.find_children(
		"*", "AudioStreamPlayer", true, false
	):
		if audio.playing and audio.bus == &"Music":
			count += 1
	return count


func _continuous(context: String, before: float) -> void:
	_check(AppSettings._tavern_music == _player, context + ": same player")
	_check(_player.playing, context + ": still playing")
	_check(_player.get_stream_playback().get_instance_id() == _playback_id,
		context + ": same playback, no restart")
	_check(_player.get_playback_position() + 0.1 >= before,
		context + ": position continues")
	_check(_music_count() == 1, context + ": no overlapping music")


func _watch_incoming_music(node: Node) -> void:
	if node is AudioStreamPlayer and node.name in ["TitleMusic", "BattleMusic"]:
		if is_instance_valid(_player):
			_check(not _player.playing,
				"Tavern stops before incoming " + String(node.name))


func _run() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	# Keep this runner alive while real current scenes are replaced.
	get_tree().current_scene = null
	get_tree().node_added.connect(_watch_incoming_music)
	var original: Dictionary = AppSettings.preferences.duplicate(true)
	RunState.start_new_run()
	RunState.selected_biome = "forest"
	await _go(ScenePaths.TAVERN)
	_player = AppSettings._tavern_music
	_check(is_instance_valid(_player), "Entering hub creates tavern voice")
	if not is_instance_valid(_player):
		get_tree().quit(1)
		return
	_check(_player.playing, "Entering hub automatically plays music")
	_check(_player.bus == &"Music", "Explicit Music bus")
	_check(_player.stream is AudioStreamMP3, "Existing MP3 format")
	_check(_player.stream.data == AppSettings.TAVERN_TRACK.data,
		"Reuses exact Tavern.mp3 audio data")
	_check(_player.stream.loop, "Looping enabled on private stream")
	_check(not AppSettings.TAVERN_TRACK.loop, "Imported resource unchanged")
	_check(AudioServer.get_bus_send(AudioServer.get_bus_index("Music"))
		== &"Master", "Music respects Master bus")
	_player.seek(8.0)
	await get_tree().create_timer(0.1).timeout
	_playback_id = _player.get_stream_playback().get_instance_id()
	var before: float = _player.get_playback_position()
	_check(before >= 7.9, "Playback advanced away from start")

	var hub: Control = get_tree().current_scene
	hub._open_minigames()
	hub.minigames_popup.hide()
	var equipment: Control = hub.get_node("EquipmentOverlay")
	equipment._toggle_panel()
	equipment.close_button.pressed.emit()
	hub._open_leaderboard()
	hub.get_node("LeaderboardOverlay").queue_free()
	await get_tree().process_frame
	_continuous("Hub popup/equipment/leaderboard", before)
	# Inspectors and other root overlays must not look like scene changes.
	var overlay: Control = EQUIPMENT.instantiate()
	get_tree().root.add_child(overlay)
	_continuous("Root overlay", before)
	overlay.queue_free()

	await _follow(hub._open_right_room)
	_continuous("Dealer room", before)
	var dealer: Control = get_tree().current_scene
	dealer.dealer_button.pressed.emit()
	dealer.close_button.pressed.emit()
	_continuous("Dealer open/close", before)
	await _follow(dealer._return_to_hub)
	_continuous("Dealer return to hub", before)

	hub = get_tree().current_scene
	await _follow(hub._open_forge)
	_continuous("Forge", before)
	await _follow(get_tree().current_scene._return_to_tavern)
	_continuous("Forge return to hub", before)

	hub = get_tree().current_scene
	await _follow(hub._open_left_room)
	var barkeeper: Control = get_tree().current_scene
	barkeeper.barkeeper_button.pressed.emit()
	barkeeper.close_button.pressed.emit()
	_continuous("Barkeeper and meal menu", before)
	await _follow(barkeeper._return_to_hub)

	hub = get_tree().current_scene
	await _follow(hub._open_tavern_page)
	_check(not get_tree().current_scene.has_node("TavernMusic"),
		"Legacy page has no duplicate scene player")
	_continuous("Legacy management page", before)
	await _follow(get_tree().current_scene._on_close_pressed)

	for path: String in [
		ScenePaths.WORD_GAME, ScenePaths.HANDWRITING_GAME,
		ScenePaths.ICE_FISHING,
	]:
		await _go(path)
		_continuous("Tavern minigame: " + path, before)
		if path == ScenePaths.ICE_FISHING:
			await _follow(get_tree().current_scene._return_from_fishing)
		else:
			await _follow(get_tree().current_scene._leave_game)
		_continuous("Return from minigame", before)

	await _test_settings(original)
	await _test_loop()
	await _follow(get_tree().current_scene._leave_tavern)
	_check(not _player.playing, "Leave button stops tavern music")
	_check(_music_count() == 0, "No stray music on encounter route")

	for destination: String in [
		ScenePaths.MAIN_MENU, ScenePaths.BIOME_SELECT, ScenePaths.COMBAT,
	]:
		await _go(ScenePaths.TAVERN)
		_check(_player.playing and _player.get_playback_position() < 1.0,
			"Returning to tavern starts from beginning")
		await _go(destination)
		_check(not _player.playing, "Stops for " + destination)
		_check(_music_count() == 1, "Intended destination music only")

	# Shared route activities retain their previous non-tavern audio behavior.
	for path: String in AppSettings.TAVERN_ACTIVITIES:
		await _go(ScenePaths.TAVERN)
		RunState.pending_route_activity = AppSettings.TAVERN_ACTIVITIES[path]
		await _go(path)
		_check(not _player.playing,
			"No tavern track on route activity: " + path)
		RunState.pending_route_activity = ""
		await _go(ScenePaths.MAIN_MENU)

	# Opening any tavern screen directly also starts the track.
	for path: String in [
		ScenePaths.TAVERN_RIGHT, ScenePaths.TAVERN_LEFT, ScenePaths.FORGE,
		TAVERN_PAGE, ScenePaths.WORD_GAME, ScenePaths.HANDWRITING_GAME,
		ScenePaths.ICE_FISHING,
	]:
		await _go(path)
		_check(_player.playing and _music_count() == 1,
			"Direct tavern entry: " + path)
		await _go(ScenePaths.MAIN_MENU)

	AppSettings.apply_preferences(original)
	for audio: AudioStreamPlayer in get_tree().root.find_children(
		"*", "AudioStreamPlayer", true, false
	):
		audio.stop()
		audio.stream = null
	await get_tree().create_timer(0.2).timeout
	print("Tavern music: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_settings(original: Dictionary) -> void:
	var music_bus: int = AudioServer.get_bus_index("Music")
	var master_bus: int = AudioServer.get_bus_index("Master")
	var sfx_bus: int = AudioServer.get_bus_index("SFX")
	var values: Dictionary = original.duplicate(true)
	values.music_volume = 35.0
	values.sfx_volume = 0.0
	AppSettings.apply_preferences(values)
	_check(is_equal_approx(db_to_linear(
		AudioServer.get_bus_volume_db(music_bus)
	), 0.35), "Music volume slider controls tavern bus")
	_check(AudioServer.is_bus_mute(sfx_bus), "SFX muted independently")
	_check(not AudioServer.is_bus_mute(music_bus), "SFX mute leaves music on")
	values.music_volume = 0.0
	AppSettings.apply_preferences(values)
	_check(AudioServer.is_bus_mute(music_bus), "Music volume zero mutes track")
	_continuous("Muted music", 0.0)
	values.music_volume = 50.0
	values.master_volume = 0.0
	AppSettings.apply_preferences(values)
	_check(AudioServer.is_bus_mute(master_bus), "Master mute applies to music")
	values.master_volume = 50.0
	AppSettings.apply_preferences(values)
	_check(not AudioServer.is_bus_mute(music_bus), "Music unmute")
	get_tree().paused = true
	await get_tree().create_timer(0.05).timeout
	_continuous("Paused tavern menus", 0.0)
	get_tree().paused = false
	AppSettings.apply_preferences(original)


func _test_loop() -> void:
	var length: float = _player.stream.get_length()
	_check(length > 1.0, "Track has valid duration")
	_player.seek(length - 0.15)
	await get_tree().create_timer(0.05).timeout
	var loop_playback: int = _player.get_stream_playback().get_instance_id()
	_check(_player.get_playback_position() > length - 0.5,
		"Loop test reaches end of existing track")
	await get_tree().create_timer(0.35).timeout
	_check(_player.playing and _player.get_playback_position() < 1.0,
		"Track naturally wraps to beginning without stopping")
	_check(_player.get_stream_playback().get_instance_id() == loop_playback,
		"Loop keeps same playback instance")
