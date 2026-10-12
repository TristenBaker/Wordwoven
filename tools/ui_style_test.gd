extends Node
## Run with Godot --headless --path . tools/ui_style_test.tscn.
## Checks explicit action styles, gameplay card isolation, and interaction wiring.

const BUTTON_THEME = preload("res://assets/Themes/WordWoven_Button_Theme.tres")
const STATES = ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]
var failures: int = 0
var buttons_checked: int = 0
var cards_checked: int = 0
var selected_enemy: String = ""

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _scene_paths(path: String) -> Array[String]:
	var paths: Array[String] = []
	var directory := DirAccess.open(path)
	for file: String in directory.get_files():
		if file.ends_with(".tscn"):
			paths.append(path.path_join(file))
	for folder: String in directory.get_directories():
		paths.append_array(_scene_paths(path.path_join(folder)))
	return paths

func _run() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	var paths := _scene_paths("res://scenes")
	for path: String in paths:
		RunState.start_new_run()
		RunState.selected_biome = "forest"
		RunState.next_enemy_id = "goblin"
		RunState.pending_victory_enemy = "Goblin"
		RunState.pending_relic_choices.assign(["ember_ring"])
		if path == ScenePaths.TUNDRA_EVENT:
			RunState.selected_biome = "tundra"
			RunState.encounter_index = 2
			RunState.completed_encounters.append(1)
			RunState.begin_optional_encounter("frozen_traveler")
		var packed: PackedScene = load(path)
		_check(packed != null, "Scene loads: " + path)
		if packed == null:
			continue
		var scene := packed.instantiate()
		add_child(scene)
		await get_tree().process_frame
		await get_tree().process_frame
		for button: Button in scene.find_children("*", "Button", true, false):
			buttons_checked += 1
			var type: String = String(button.theme_type_variation)
			if type not in ["WordWovenActionButton", "WordWovenOptionButton"]:
				cards_checked += 1
				for state: String in STATES:
					_check(button.get_theme_stylebox(state) != BUTTON_THEME.get_stylebox(state, "WordWovenActionButton"), "Gameplay card excludes action frame: %s/%s/%s" % [path, button.name, state])
				continue
			for state: String in STATES:
				_check(button.get_theme_stylebox(state) == BUTTON_THEME.get_stylebox(state, type),
					"Button state %s: %s/%s" % [state, path, button.name])
			_check(button.get_theme_font("font") == BUTTON_THEME.get_font("font", type),
				"Button font: %s/%s" % [path, button.name])
			if button.is_visible_in_tree():
				var minimum := button.get_combined_minimum_size()
				_check(button.size.x + 0.1 >= minimum.x and button.size.y + 0.1 >= minimum.y,
					"Button content fits: %s/%s" % [path, button.name])
			_check(not button.flat, "Button frame visible: %s/%s" % [path, button.name])
		for tile: LetterTile in scene.find_children("*", "PanelContainer", true, false).filter(func(node): return node is LetterTile):
			if tile.stats == null:
				continue
			var tile_style: StyleBoxFlat = tile.get_theme_stylebox("panel")
			_check(tile_style.bg_color == tile.tile_theme.fill_for(tile.stats.element) and tile_style.border_color == tile.tile_theme.border_for(tile.stats.level), "Letter retains element fill and rank border: " + path)
		if path == "res://scenes/combat/combat.tscn":
			await _check_log(scene)
			_check(scene.feedback_banner.get_theme_stylebox("panel") is StyleBoxFlat, "Feedback remains plain dark panel")
		if path == "res://scenes/tavern/tavern_right.tscn":
			scene.dealer_button.pressed.emit()
			_check(scene.menu_panel.visible, "Browse Letter Stock opens shop")
			RunState.gold = 999
			scene._rebuild_offers()
			var offer: Button = scene.offers_grid.get_child(0)
			_check(offer.flat and offer.get_theme_stylebox("normal") is not StyleBoxTexture, "Shop letter wrapper retains original flat styling")
			var owned_before: int = RunState.letter_inventory.size()
			offer.pressed.emit()
			_check(RunState.letter_inventory.size() == owned_before + 1 and RunState.gold < 999, "Letter purchase through original pressed signal")
			scene.close_button.pressed.emit()
			_check(not scene.menu_panel.visible, "Shop Close hides shop")
		for audio: AudioStreamPlayer in scene.find_children("*", "AudioStreamPlayer", true, false):
			audio.stop()
			audio.stream = null
		scene.queue_free()
		await get_tree().process_frame
	await _check_card_isolation()
	print("UI style check: %d scenes, %d buttons (%d gameplay cards), %d failures" % [paths.size(), buttons_checked, cards_checked, failures])
	get_tree().quit(1 if failures else 0)

func _check_log(scene: Node) -> void:
	var panel: PanelContainer = scene.get_node("Layout/SidePanel")
	var label: RichTextLabel = panel.get_node("LogLabel")
	var toggle: Button = scene.get_node("Layout/LogToggleButton")
	toggle.button_pressed = true
	await get_tree().process_frame
	_check(panel.visible and toggle.text == "Hide Log", "Log opens with its toggle")
	var before := label.get_parsed_text()
	for index: int in 40:
		scene.call("_log", "UI test message %d" % index)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(label.get_parsed_text().begins_with(before) and label.get_parsed_text().contains("UI test message 39"), "Log appends messages")
	_check(label.scroll_following and label.get_v_scroll_bar().value > 0, "Log follows scrolling")
	_check(panel.get_global_rect().encloses(label.get_global_rect()), "Log text stays inside frame")
	_check(not panel.get_global_rect().intersects(scene.get_node("Layout/InputArea").get_global_rect()), "Log clears input area")
	_check(not panel.get_global_rect().intersects(scene.get_node("Layout/EnemyArea").get_global_rect()), "Log clears enemy area")
	toggle.button_pressed = false
	_check(not panel.visible and toggle.text == "Show Log", "Log closes with its toggle")

func _check_card_isolation() -> void:
	# An action-themed ancestor must not turn an unmarked child into an action button.
	var parent := Control.new()
	parent.theme = BUTTON_THEME
	add_child(parent)
	var plain := Button.new()
	parent.add_child(plain)
	_check(plain.get_theme_stylebox("normal") is not StyleBoxTexture, "Unmarked Button remains plain under shared theme")
	var action := Button.new()
	action.theme_type_variation = &"WordWovenActionButton"
	parent.add_child(action)
	_check(action.get_theme_stylebox("normal") == BUTTON_THEME.get_stylebox("normal", "WordWovenActionButton"), "Explicit action inherits exact reference frame")
	var map := EncounterRouteMap.new()
	map.size = Vector2(1100, 350)
	parent.add_child(map)
	var choices: Array[Dictionary] = [{"id": "goblin", "name": "Goblin", "texture": "res://art/red_dragon.png"}]
	map.setup(1, choices, {"id": "dragon", "name": "Dragon", "texture": "res://art/red_dragon.png"})
	map.enemy_selected.connect(_on_test_enemy_selected)
	var card: Button = map._buttons[0]
	_check(card.get_theme_stylebox("normal") is StyleBoxFlat and card.get_theme_stylebox("normal").bg_color == Color(0.075, 0.18, 0.15, 0.98), "Monster card retains original green style")
	card.pressed.emit()
	_check(selected_enemy == "goblin", "Monster selection signal still carries enemy ID")
	map.setup(6, choices, {"id": "dragon", "name": "Dragon", "texture": "res://art/red_dragon.png"})
	card = map._buttons[0]
	_check(card.get_theme_stylebox("normal").bg_color == Color(0.22, 0.055, 0.045, 0.98), "Boss card retains original red style")
	card.pressed.emit()
	_check(selected_enemy == "dragon", "Boss selection remains interactive")
	parent.queue_free()
	await get_tree().process_frame

func _on_test_enemy_selected(enemy_id: String) -> void:
	selected_enemy = enemy_id
