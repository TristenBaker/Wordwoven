extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	var equipment: EquipmentOverlay = load("res://scenes/ui/equipment_overlay.tscn").instantiate()
	add_child(equipment)
	var pause: PauseMenu = load("res://scenes/pause_menu.tscn").instantiate()
	add_child(pause)
	await get_tree().process_frame
	var button: TalentAccessButton = equipment.get_node("TalentButton")
	assert(button.texture_normal != null)
	assert(equipment.toggle_button.get_node_or_null("StarCoinIcon") == null)
	assert(not equipment.toggle_button.tooltip_text.contains("StarCoin"))
	assert(button.get_node("StarCoinIcon").position.x < 0)
	PlayerProfile.star_coins_changed.emit(0)
	assert(not button.get_node("UnspentPointsDot").visible)
	assert(button.get_node("StarCoinCount").text == "0")
	PlayerProfile.star_coins_changed.emit(3)
	assert(button.get_node("UnspentPointsDot").visible)
	assert(button.get_node("StarCoinCount").text == "3")
	PlayerProfile.star_coins_changed.emit(PlayerProfile.star_coins)
	assert(button.get_global_rect().end.x < equipment.toggle_button.get_global_rect().position.x)
	button.pressed.emit()
	var overlay := get_node("PermanentUpgradesOverlay")
	assert(get_tree().paused and overlay.process_mode == Node.PROCESS_MODE_ALWAYS)
	assert(get_tree().get_nodes_in_group("talent_overlay").size() == 1)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	pause._input(escape)
	assert(not pause.visible)
	overlay._input(escape)
	await get_tree().process_frame
	assert(not get_tree().paused)
	assert(get_node_or_null("PermanentUpgradesOverlay") == null)
	# Reopening and Back use the same pause ownership and cleanup path.
	button.pressed.emit()
	overlay = get_node("PermanentUpgradesOverlay")
	assert(get_tree().paused)
	overlay.queue_free()
	await get_tree().process_frame
	assert(not get_tree().paused)
	print("TALENT ACCESS PASSED: HUD placement, opening, pause ownership, Escape, and reopening")
	get_tree().quit.call_deferred()
