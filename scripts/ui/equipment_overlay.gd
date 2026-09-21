class_name EquipmentOverlay
extends Control
## Reusable ARPG letter inventory. The overlay stays mounted in major gameplay
## scenes and only its panel is toggled, so opening it never changes scenes.

const ALPHABET := "abcdefghijklmnopqrstuvwxyz"
const TILE_THEME: LetterTileTheme = preload(
	"res://assets/Themes/letter_tiles/default_letter_tile_theme.tres"
)

@onready var toggle_button: Button = $EquipButton
@onready var panel: PanelContainer = $EquipmentPanel
@onready var mode_label: Label = $EquipmentPanel/Content/ModeLabel
@onready var slots_grid: GridContainer = $EquipmentPanel/Content/SlotsScroll/SlotsGrid
@onready var inventory_grid: GridContainer = $EquipmentPanel/Content/InventoryScroll/InventoryGrid
@onready var close_button: Button = $EquipmentPanel/Content/TitleRow/CloseButton


func _ready() -> void:
	toggle_button.pressed.connect(_toggle_panel)
	close_button.pressed.connect(panel.hide)
	EventBus.deck_changed.connect(_refresh)
	panel.hide()
	_refresh()


func _toggle_panel() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		_refresh()


func _refresh() -> void:
	mode_label.text = "Itemized letters mode" if RunState.use_itemized_letters \
		else "Legacy deck mode — item equipment is inactive"
	_rebuild_slots()
	_rebuild_inventory()


func _rebuild_slots() -> void:
	_clear(slots_grid)
	for character: String in ALPHABET:
		var item: LetterStats = RunState.equipped_letters.get(character, null)
		var button := _item_button(item, character, true)
		button.disabled = item == null or not RunState.use_itemized_letters
		if item != null:
			button.pressed.connect(_unequip.bind(character))
		slots_grid.add_child(button)


func _rebuild_inventory() -> void:
	_clear(inventory_grid)
	if not RunState.use_itemized_letters:
		_add_empty_message("Switch on itemized letters mode to manage equipped letter items.")
		return
	if RunState.letter_inventory.is_empty():
		_add_empty_message("No loose letter items yet. Defeat monsters to find them.")
		return
	for item: LetterStats in RunState.letter_inventory:
		var button := _item_button(item, item.letter, false)
		button.pressed.connect(_equip.bind(item))
		inventory_grid.add_child(button)


func _item_button(item: LetterStats, slot_letter: String, is_slot: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(72, 70) if is_slot else Vector2(150, 88)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 15 if is_slot else 16)
	if item == null:
		button.text = "%s\nEmpty" % slot_letter.to_upper()
		button.tooltip_text = "Empty %s equipment slot" % slot_letter.to_upper()
		button.add_theme_stylebox_override("normal", _empty_style())
		return button
	button.text = "%s\nLv%d %s" % [
		item.letter.to_upper(), item.level, item.class_name_text()
	]
	button.tooltip_text = "%s\n%s" % [item.describe(), item.effect_text()]
	button.add_theme_color_override("font_color", TILE_THEME.letter_color)
	button.add_theme_stylebox_override("normal", _item_style(item))
	return button


func _item_style(item: LetterStats) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = TILE_THEME.fill_for(item.letter_class)
	style.border_color = TILE_THEME.border_for(item.level)
	style.set_border_width_all(5)
	style.set_corner_radius_all(8)
	return style


func _empty_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.075, 0.045, 0.95)
	style.border_color = Color(0.45, 0.32, 0.2, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style


func _equip(item: LetterStats) -> void:
	RunState.equip_letter_item(item)


func _unequip(letter: String) -> void:
	RunState.unequip_letter(letter)


func _add_empty_message(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0, 58)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_grid.add_child(label)


func _clear(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
