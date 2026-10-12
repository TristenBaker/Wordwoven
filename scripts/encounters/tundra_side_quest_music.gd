extends AudioStreamPlayer
## One voice while a Tundra side quest is active; other scenes own their audio.
const TRACK = preload("res://assets/Art/Music/2 - Crystal Veil (Loop).mp3")
const EVENT: String = "res://scenes/encounters/tundra_event.tscn"

static func ensure_playing(tree: SceneTree) -> void:
	if RunState.selected_biome != "tundra":
		return
	if tree.root.has_node("TundraSideQuestMusic"):
		return
	var player := AudioStreamPlayer.new()
	player.set_script(load("res://scripts/encounters/tundra_side_quest_music.gd"))
	player.name = "TundraSideQuestMusic"
	player.stream = TRACK
	player.bus = &"Music"
	tree.root.add_child(player)
	player.set("parameters/looping", true)
	player.play()

func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)

func _on_scene_changed() -> void:
	var scene: Node = get_tree().current_scene
	if scene != null and (RunState.selected_biome != "tundra" or scene.scene_file_path != EVENT):
		stop()
		queue_free()
