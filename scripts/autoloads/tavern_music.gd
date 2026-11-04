extends Node
## One player survives scene changes throughout the tavern and its activities.
const TRACK := preload("res://assets/Audio/Tavern.mp3")
var player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.name = "TavernTrack"
	player.bus = &"Music"
	var looped: AudioStreamMP3 = TRACK.duplicate()
	looped.loop = true
	player.stream = looped
	add_child(player)

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	# Scene changes briefly have no current scene; keep the playback intact.
	if scene != null:
		sync_scene(scene.scene_file_path)

func sync_scene(path: String) -> void:
	if path.begins_with("res://scenes/tavern/"):
		if not player.playing:
			player.play()
	elif player.playing:
		player.stop()
