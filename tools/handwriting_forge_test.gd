extends Node
## Offline inference plus a complete forge transaction, without profile writes.

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(ForgeLetterRecognizer.available())
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/models/forge_fixtures.json"))
	for fixture: Dictionary in fixtures:
		assert(ForgeLetterRecognizer.recognize(PackedFloat32Array(fixture.pixels)) == fixture.letter)
	var system := ForgeSystem.new()
	var items: Array[LetterStats] = []
	for i: int in 3:
		items.append(LetterStats.create_item("b", LetterStats.Element.FIRE, 2))
	var result := system.forge(items, "Z")
	assert(result.letter == "z" and result.level == 3 and result.element == LetterStats.Element.FIRE)
	assert(system.forge(items, "") == null)
	assert(system.forge(items, "zz") == null)
	items[2].level = 3
	assert(system.forge(items, "a") == null)
	items[2].level = 2
	var room: Control = load("res://scripts/tavern/forge_room.gd").new()
	RunState.letter_inventory = items.duplicate()
	RunState.equipped_letters.clear()
	add_child(room)
	for item: LetterStats in items:
		room.add_item_to_board(item)
	room._forge()
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not room.drawing_board.has_ink())
	room.drawing_board.strokes.append(PackedVector2Array([Vector2(0.36, 0.85), Vector2(0.5, 0.15), Vector2(0.64, 0.85)]))
	room.drawing_board.strokes.append(PackedVector2Array([Vector2(0.42, 0.55), Vector2(0.58, 0.55)]))
	assert(room.drawing_board.has_ink())
	var pixels: PackedFloat32Array = room.drawing_board.pixels()
	var letter := ForgeLetterRecognizer.recognize(pixels)
	print("Mouse-stroke A recognized as: ", letter)
	assert(letter == "a")
	var panel: PanelContainer = room.drawing_overlay.get_child(1).get_child(0)
	var content: VBoxContainer = panel.get_child(0)
	var actions: HBoxContainer = content.get_child(content.get_child_count() - 1)
	room.drawing_board.changed.emit()
	var commit: Button = actions.get_child(2)
	assert(not commit.disabled)
	commit.pressed.emit()
	assert(RunState.letter_inventory.size() == 1)
	assert(RunState.letter_inventory[0].letter == "a")
	assert(RunState.letter_inventory[0].level == 3)
	for item: LetterStats in items:
		assert(not RunState.letter_inventory.has(item))
	await get_tree().create_timer(3.5).timeout
	assert(not room.is_forging)
	assert(room.selected_items.is_empty())
	assert(not is_instance_valid(room.drawing_overlay))
	print("HANDWRITING FORGE PASSED: A–Z inference parity, stroke recognition, recipe validation, atomic rewards, and animation")
	get_tree().quit()
