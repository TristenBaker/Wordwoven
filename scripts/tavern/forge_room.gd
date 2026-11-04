extends Control
const Balance = preload("res://data/balance/tuning.gd")
## Sacrifice a matched trio and draw the letter the offline model will forge.

const TILE_THEME: LetterTileTheme = preload(
	"res://assets/Themes/letter_tiles/default_letter_tile_theme.tres"
)

var forge_system := ForgeSystem.new()
var selected_items: Array[LetterStats] = []
var board: GridContainer
var rules_box: VBoxContainer
var inventory_grid: ForgeInventoryGrid
var equipped_grid: GridContainer
var rule_result: Label
var feedback_label: Label
var drawing_overlay: Control
var drawing_board: ForgeDrawingBoard
var forge_button: Button
var effects_layer: Control
var is_forging: bool = false


func _ready() -> void:
	_build_layout()
	EventBus.deck_changed.connect(_refresh)
	_refresh()


func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = Color("160c13")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	effects_layer = Control.new()
	effects_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effects_layer.z_index = 20
	add_child(effects_layer)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)

	var header := HBoxContainer.new()
	page.add_child(header)
	var title := Label.new()
	title.text = "The Letter Forge"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("ffd07a"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.theme = preload("res://assets/Themes/WordWoven_Button_Theme.tres")
	close.theme_type_variation = &"WordWovenActionButton"
	close.text = "Return to Route" if RunState.pending_route_activity == "forge" else "Return to Tavern"
	close.pressed.connect(_return_to_tavern)
	header.add_child(close)

	var main_row := HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 16)
	page.add_child(main_row)

	var rules_panel := _panel()
	rules_panel.custom_minimum_size = Vector2(250, 0)
	main_row.add_child(rules_panel)
	var rules_layout := VBoxContainer.new()
	rules_panel.add_child(rules_layout)
	var rules_title := Label.new()
	rules_title.text = "Recipes"
	rules_title.add_theme_font_size_override("font_size", 21)
	rules_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules_layout.add_child(rules_title)
	var rules_scroll := ScrollContainer.new()
	rules_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rules_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules_layout.add_child(rules_scroll)
	rules_box = VBoxContainer.new()
	rules_box.add_theme_constant_override("separation", 8)
	rules_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules_scroll.add_child(rules_box)

	var forge_panel := _panel()
	forge_panel.custom_minimum_size = Vector2(390, 0)
	main_row.add_child(forge_panel)
	var forge_scroll := ScrollContainer.new()
	forge_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	forge_panel.add_child(forge_scroll)
	var forge_box := VBoxContainer.new()
	forge_box.add_theme_constant_override("separation", 8)
	forge_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forge_scroll.add_child(forge_box)
	var board_title := Label.new()
	board_title.text = "Combine %d Tiles" % Balance.FORGE_INGREDIENT_COUNT
	board_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board_title.add_theme_font_size_override("font_size", 21)
	forge_box.add_child(board_title)
	board = GridContainer.new()
	board.columns = Balance.FORGE_INGREDIENT_COUNT
	board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board.add_theme_constant_override("h_separation", 7)
	board.add_theme_constant_override("v_separation", 7)
	forge_box.add_child(board)
	rule_result = Label.new()
	rule_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule_result.add_theme_color_override("font_color", Color("ffe59b"))
	forge_box.add_child(rule_result)
	forge_button = Button.new()
	forge_button.theme = preload("res://assets/Themes/WordWoven_Button_Theme.tres")
	forge_button.theme_type_variation = &"WordWovenActionButton"
	forge_button.text = "Draw & Forge"
	forge_button.custom_minimum_size = Vector2(0, 42)
	forge_button.pressed.connect(_forge)
	forge_box.add_child(forge_button)
	feedback_label = Label.new()
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_color_override("font_color", Color("ffbf89"))
	forge_box.add_child(feedback_label)

	var equipped_panel := _panel()
	equipped_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.add_child(equipped_panel)
	var equipped_box := VBoxContainer.new()
	equipped_panel.add_child(equipped_box)
	var equipped_title := Label.new()
	equipped_title.text = "Equipped"
	equipped_title.tooltip_text = "Click a tile to unequip it. Hold for details."
	equipped_title.add_theme_font_size_override("font_size", 21)
	equipped_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipped_box.add_child(equipped_title)
	var equipped_scroll := ScrollContainer.new()
	equipped_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipped_box.add_child(equipped_scroll)
	equipped_grid = GridContainer.new()
	equipped_grid.columns = 6
	equipped_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipped_scroll.add_child(equipped_grid)

	var inventory_panel := _panel()
	inventory_panel.custom_minimum_size = Vector2(0, 170)
	page.add_child(inventory_panel)
	var inventory_box := VBoxContainer.new()
	inventory_panel.add_child(inventory_box)
	var inventory_title := Label.new()
	inventory_title.text = "Inventory"
	inventory_title.tooltip_text = "Drag or click tiles to add them. Green borders highlight compatible tiles. Hold for details."
	inventory_title.add_theme_font_size_override("font_size", 21)
	inventory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_box.add_child(inventory_title)
	var inventory_scroll := ScrollContainer.new()
	inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_box.add_child(inventory_scroll)
	inventory_grid = ForgeInventoryGrid.new()
	inventory_grid.forge_owner = self
	inventory_grid.columns = 10
	inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_scroll.add_child(inventory_grid)


func _refresh() -> void:
	if is_forging:
		return
	var still_owned: Array[LetterStats] = []
	for item: LetterStats in selected_items:
		if RunState.letter_inventory.has(item):
			still_owned.append(item)
	selected_items = still_owned
	_rebuild_rules()
	_rebuild_board()
	_rebuild_inventory()
	_rebuild_equipped()
	_refresh_forge_state()


func _rebuild_rules() -> void:
	_clear(rules_box)
	var active: Dictionary = forge_system.matching_rule(selected_items)
	for rule: Dictionary in forge_system.rules():
		var card_panel := PanelContainer.new()
		card_panel.add_theme_stylebox_override(
			"panel", _rule_style(rule["id"] == active.get("id", ""))
		)
		var card := Label.new()
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.text = "%s\n%s\n→ %s" % [
			rule["name"], rule["description"], rule["result"],
		]
		card.add_theme_font_size_override("font_size", 15)
		card_panel.add_child(card)
		rules_box.add_child(card_panel)


func _rebuild_board() -> void:
	_clear(board)
	for index: int in range(Balance.FORGE_INGREDIENT_COUNT):
		if index < selected_items.size():
			var item: LetterStats = selected_items[index]
			var button := _tile_button(item, true, true)
			button.pressed.connect(_remove_from_board.bind(item, button))
			board.add_child(button)
		else:
			var empty := ForgeTileButton.new()
			empty.forge_owner = self
			empty.accepts_forge_drop = true
			empty.text = "+"
			empty.custom_minimum_size = Vector2(66, 52)
			empty.add_theme_font_size_override("font_size", 26)
			empty.add_theme_stylebox_override("normal", _empty_style())
			board.add_child(empty)


func _rebuild_inventory() -> void:
	_clear(inventory_grid)
	if RunState.letter_inventory.is_empty():
		var empty := Label.new()
		empty.text = "No loose tiles. Buy or find letters to use the forge."
		inventory_grid.add_child(empty)
		return
	for item: LetterStats in RunState.letter_inventory:
		if selected_items.has(item):
			continue
		var eligible: bool = forge_system.can_extend_rule(selected_items, item)
		var button := _tile_button(item, false, false, eligible)
		if not selected_items.is_empty():
			button.tooltip_text = "Eligible for the current recipe" if eligible \
				else "Does not complete the current recipe"
		button.pressed.connect(_toggle_item.bind(item, button))
		inventory_grid.add_child(button)


func _rebuild_equipped() -> void:
	_clear(equipped_grid)
	for letter: String in "abcdefghijklmnopqrstuvwxyz":
		var item: LetterStats = RunState.equipped_letters.get(letter, null)
		if item == null:
			var empty := Button.new()
			empty.text = "%s\n—" % letter.to_upper()
			empty.disabled = true
			empty.custom_minimum_size = Vector2(66, 52)
			empty.add_theme_stylebox_override("disabled", _empty_style())
			equipped_grid.add_child(empty)
			continue
		var button := _tile_button(item, true)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_unequip_from_forge.bind(letter, button))
		equipped_grid.add_child(button)


func _tile_button(
	item: LetterStats, compact: bool = false, accepts_drop: bool = false,
	eligible: bool = false
) -> ForgeTileButton:
	var button := ForgeTileButton.new()
	button.forge_owner = self
	button.item = item
	button.accepts_forge_drop = accepts_drop
	button.set_letter_stats(item)
	button.custom_minimum_size = Vector2(66, 52) if compact else Vector2(105, 64)
	button.text = "%s  Lv%d\n%s" % [
		item.letter.to_upper(), item.level, item.element_name_text(),
	]
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", TILE_THEME.letter_color)
	button.add_theme_stylebox_override("normal", _tile_style(item, eligible))
	button.add_theme_stylebox_override("hover", _tile_style(item, eligible))
	button.add_theme_stylebox_override("pressed", _tile_style(item, eligible))
	button.gui_input.connect(_on_item_gui_input.bind(button, item))
	return button


func _toggle_item(item: LetterStats, button: Button) -> void:
	if _consume_inspector_press(button):
		button.button_pressed = selected_items.has(item)
		return
	if selected_items.has(item):
		remove_item_from_board(item)
	else:
		add_item_to_board(item)


func _remove_from_board(item: LetterStats, button: Button) -> void:
	if _consume_inspector_press(button):
		return
	remove_item_from_board(item)


func add_item_to_board(item: LetterStats) -> void:
	if is_forging or item == null or selected_items.has(item) \
		or not RunState.letter_inventory.has(item):
		return
	if selected_items.size() >= Balance.FORGE_INGREDIENT_COUNT:
		feedback_label.text = "A first-version recipe uses exactly three tiles."
		return
	selected_items.append(item)
	_refresh()


func remove_item_from_board(item: LetterStats) -> void:
	if is_forging or not selected_items.has(item):
		return
	selected_items.erase(item)
	_refresh()


func _unequip_from_forge(letter: String, button: Button) -> void:
	if is_forging:
		return
	if _consume_inspector_press(button):
		return
	if RunState.unequip_letter(letter):
		feedback_label.text = "%s returned to loose inventory." % letter.to_upper()


func _refresh_forge_state() -> void:
	var rule: Dictionary = forge_system.matching_rule(selected_items)
	if rule.is_empty():
		rule_result.text = forge_system.next_step_text(selected_items)
	else:
		rule_result.text = "%s\n%s" % [rule["name"], rule["result"]]
	forge_button.disabled = rule.is_empty()


func _forge() -> void:
	if is_forging or is_instance_valid(drawing_overlay):
		return
	if forge_system.matching_rule(selected_items).is_empty():
		_refresh_forge_state()
		return
	if not ForgeLetterRecognizer.available():
		feedback_label.text = "The forge's recognition model could not be loaded. No tiles consumed."
		return
	_open_drawing()


func _open_drawing() -> void:
	drawing_overlay = Control.new()
	drawing_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drawing_overlay.z_index = 30
	add_child(drawing_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.015, 0.04, 0.95)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drawing_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drawing_overlay.add_child(center)
	var panel := _panel()
	panel.custom_minimum_size = Vector2(520, 520)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	var title := Label.new()
	title.text = "DRAW A LETTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	content.add_child(title)
	var note := Label.new()
	note.text = "A–Z · The recognized letter is final.\nForging consumes your %d tiles." % Balance.FORGE_INGREDIENT_COUNT
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 16)
	content.add_child(note)
	var drawing_area := Control.new()
	drawing_area.custom_minimum_size = Vector2(440, 300)
	drawing_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(drawing_area)
	drawing_board = ForgeDrawingBoard.new()
	drawing_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drawing_area.add_child(drawing_board)
	var reveal := Label.new()
	reveal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reveal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reveal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reveal.add_theme_font_size_override("font_size", 160)
	reveal.add_theme_color_override("font_color", Color("ffe0aa"))
	reveal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawing_area.add_child(reveal)
	drawing_area.resized.connect(func(): reveal.pivot_offset = drawing_area.size * 0.5)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(actions)
	var clear := _drawing_action(actions, "Clear")
	var cancel := _drawing_action(actions, "Cancel")
	var commit := _drawing_action(actions, "Forge Letter")
	commit.disabled = true
	clear.pressed.connect(drawing_board.clear_drawing)
	cancel.pressed.connect(func():
		if not is_forging:
			drawing_overlay.queue_free()
	)
	drawing_board.changed.connect(func(): commit.disabled = not drawing_board.has_ink())
	commit.pressed.connect(_commit_drawing.bind(reveal, commit, cancel, clear))


func _drawing_action(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.theme = preload("res://assets/Themes/WordWoven_Button_Theme.tres")
	button.theme_type_variation = &"WordWovenActionButton"
	button.custom_minimum_size = Vector2(135, 44)
	parent.add_child(button)
	return button


func _commit_drawing(reveal: Label, commit: Button, cancel: Button, clear: Button) -> void:
	if is_forging or not drawing_board.has_ink():
		return
	for item: LetterStats in selected_items:
		if not RunState.letter_inventory.has(item):
			drawing_overlay.queue_free()
			_refresh()
			return
	var letter := ForgeLetterRecognizer.recognize(drawing_board.pixels())
	var result: LetterStats = forge_system.forge(selected_items, letter)
	if result == null:
		feedback_label.text = "The forge could not resolve that recipe. No tiles consumed."
		return
	is_forging = true
	drawing_board.locked = true
	commit.disabled = true
	cancel.disabled = true
	clear.disabled = true
	forge_button.disabled = true
	# Commit before any awaits: closing during the reveal cannot reroll the letter.
	for item: LetterStats in selected_items:
		RunState.letter_inventory.erase(item)
	RunState.add_letter_item(result)
	reveal.text = letter.to_upper()
	reveal.modulate.a = 0.0
	reveal.scale = Vector2(0.4, 0.4)
	var morph := create_tween().set_parallel(true)
	morph.tween_property(drawing_board, "modulate:a", 0.0, 0.55)
	morph.tween_property(reveal, "modulate:a", 1.0, 0.65)
	morph.tween_property(reveal, "scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await morph.finished
	await get_tree().create_timer(0.55).timeout
	drawing_overlay.hide()
	drawing_overlay.queue_free()
	await _animate_forge(result)
	selected_items = []
	feedback_label.text = "The forge saw %s. Created %s." % [letter.to_upper(), result.describe()]
	is_forging = false
	EventBus.emit_deck_changed()
	_refresh()


func _animate_forge(result: LetterStats) -> void:
	var target: Vector2 = _effects_local(board.get_global_rect().get_center())
	var replicas: Array[Control] = []
	for index: int in range(mini(selected_items.size(), board.get_child_count())):
		var source := board.get_child(index) as Control
		if source == null:
			continue
		source.hide()
		var replica := _effect_tile(selected_items[index])
		replica.position = _effects_local(
			source.get_global_rect().get_center()
		) - replica.size * 0.5
		effects_layer.add_child(replica)
		replicas.append(replica)
	var combine := create_tween().set_parallel(true)
	for replica: Control in replicas:
		combine.tween_property(replica, "position", target - replica.size * 0.5, 0.42) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		combine.tween_property(replica, "scale", Vector2(0.45, 0.45), 0.42)
		combine.tween_property(replica, "modulate:a", 0.15, 0.42)
	await combine.finished
	for replica: Control in replicas:
		replica.queue_free()
	var flash := ColorRect.new()
	flash.color = Color("fff3a1")
	flash.size = Vector2(150, 120)
	flash.position = target - flash.size * 0.5
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.add_child(flash)
	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "color:a", 0.9, 0.10)
	flash_tween.tween_property(flash, "color:a", 0.0, 0.32)
	await flash_tween.finished
	flash.queue_free()
	var result_tile := _effect_tile(result)
	result_tile.position = target - result_tile.size * 0.5
	result_tile.pivot_offset = result_tile.size * 0.5
	result_tile.scale = Vector2(0.2, 0.2)
	result_tile.modulate.a = 0.0
	effects_layer.add_child(result_tile)
	var emerge := create_tween().set_parallel(true)
	emerge.tween_property(result_tile, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	emerge.tween_property(result_tile, "modulate:a", 1.0, 0.16)
	await emerge.finished
	var inventory_target: Vector2 = _effects_local(
		inventory_grid.get_global_rect().get_center()
	)
	var fly := create_tween().set_parallel(true)
	fly.tween_property(
		result_tile, "position", inventory_target - result_tile.size * 0.5, 0.48
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.tween_property(result_tile, "scale", Vector2(0.65, 0.65), 0.48)
	fly.tween_property(result_tile, "modulate:a", 0.25, 0.48)
	await fly.finished
	result_tile.queue_free()


func _effects_local(global_position: Vector2) -> Vector2:
	return global_position - effects_layer.get_global_rect().position


func _effect_tile(item: LetterStats) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.size = Vector2(66, 52)
	tile.add_theme_stylebox_override("panel", _tile_style(item))
	var label := Label.new()
	label.text = item.letter.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", TILE_THEME.letter_color)
	tile.add_child(label)
	return tile


func _on_item_gui_input(event: InputEvent, button: Button, item: LetterStats) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		var token: int = Time.get_ticks_msec()
		button.set_meta("forge_press_token", token)
		get_tree().create_timer(0.45).timeout.connect(
			_open_inspector_if_still_held.bind(button.get_instance_id(), item, token)
		)
	else:
		button.remove_meta("forge_press_token")


func _open_inspector_if_still_held(
	button_id: int, item: LetterStats, token: int
) -> void:
	var button := instance_from_id(button_id) as Button
	if button == null:
		return
	if int(button.get_meta("forge_press_token", -1)) != token:
		return
	button.set_meta("suppress_forge_action", true)
	LetterInspector.open_for(item)


func _consume_inspector_press(button: Button) -> bool:
	if not button.get_meta("suppress_forge_action", false):
		return false
	button.remove_meta("suppress_forge_action")
	return true


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	return panel


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("26172a")
	style.border_color = Color("70486b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	return style


func _tile_style(item: LetterStats, eligible: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = TILE_THEME.fill_for(item.element)
	style.border_color = Color("a6ff9a") if eligible else TILE_THEME.border_for(item.level)
	style.set_border_width_all(5 if eligible else 4)
	if eligible:
		style.shadow_color = Color("8dff83", 0.75)
		style.shadow_size = 8
	style.set_corner_radius_all(7)
	return style


func _empty_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17111a")
	style.border_color = Color("4d3d4f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	return style


func _rule_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("513f20") if active else Color("201720")
	style.border_color = Color("f3d65a") if active else Color("5f4c61")
	style.set_border_width_all(2 if active else 1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_top = 7.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 7.0
	return style


func _clear(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _return_to_tavern() -> void:
	if is_forging:
		return
	if RunState.pending_route_activity == "forge":
		RunState.finish_route_activity()
		get_tree().change_scene_to_file(ScenePaths.ENCOUNTER_SELECT)
		return
	get_tree().change_scene_to_file(ScenePaths.TAVERN)
