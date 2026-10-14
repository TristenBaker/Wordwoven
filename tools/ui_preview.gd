extends Node
## Render representative UI screens to .godot/ui-preview for visual review.
## Run this scene with --rendering-method gl_compatibility (not --headless).

const SCENES: Array[String] = [
	"main_menu", "biome_select", "encounter_select", "combat/combat",
	"post_fight/loot_drop", "post_fight/power_select", "tavern/tavern_hub",
	"settings_screen",
]


func _ready() -> void:
	_capture.call_deferred()


func _capture() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	DirAccess.make_dir_recursive_absolute("res://.godot/ui-preview")
	AudioServer.set_bus_mute(0, true)
	for scene_name: String in SCENES:
		RunState.start_new_run()
		RunState.selected_biome = "forest"
		RunState.next_enemy_id = "goblin"
		RunState.pending_victory_enemy = "Goblin"
		RunState.pending_relic_choices.assign([
			"coal_script", "static_ink", "prismatic_refrain",
		])
		var packed: PackedScene = load(
			"res://scenes/%s.tscn" % scene_name
		)
		var screen: Node = packed.instantiate()
		add_child(screen)
		if screen is SettingsScreen:
			screen.open()
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		var shot: Image = get_viewport().get_texture().get_image()
		var filename: String = scene_name.replace("/", "_")
		shot.save_png("res://.godot/ui-preview/%s.png" % filename)
		screen.queue_free()
		await get_tree().process_frame
	print("UI previews saved to .godot/ui-preview")
	get_tree().quit()
