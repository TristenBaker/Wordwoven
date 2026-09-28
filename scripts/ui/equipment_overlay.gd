class_name EquipmentOverlay
extends Control
## Reusable ARPG letter inventory. The overlay stays mounted in major gameplay
## scenes and only its panel is toggled, so opening it never changes scenes.

const ALPHABET := "abcdefghijklmnopqrstuvwxyz"
const TILE_THEME: LetterTileTheme = preload(
	"res://assets/Themes/letter_tiles/default_letter_tile_theme.tres"
)

@onready var toggle_button: Button = $EquipButton
@onready var powers_button: Button = $PowersButton
@onready var panel: PanelContainer = $EquipmentPanel
@onready var title_label: Label = $EquipmentPanel/Content/TitleRow/Title
@onready var letters_tab: Button = $EquipmentPanel/Content/TitleRow/LettersTab
@onready var powers_tab: Button = $EquipmentPanel/Content/TitleRow/PowersTab
@onready var mode_label: Label = $EquipmentPanel/Content/ModeLabel
@onready var equipped_label: Label = $EquipmentPanel/Content/EquippedLabel
@onready var slots_grid: GridContainer = $EquipmentPanel/Content/SlotsScroll/SlotsGrid
@onready var slots_scroll: ScrollContainer = $EquipmentPanel/Content/SlotsScroll
@onready var inventory_label: Label = $EquipmentPanel/Content/InventoryLabel
@onready var inventory_scroll: ScrollContainer = \
		$EquipmentPanel/Content/InventoryScroll
@onready var inventory_grid: GridContainer = $EquipmentPanel/Content/InventoryScroll/InventoryGrid
@onready var inventory_empty_label: Label = \
		$EquipmentPanel/Content/InventoryEmptyLabel
@onready var powers_scroll: ScrollContainer = \
		$EquipmentPanel/Content/PowersScroll
@onready var powers_grid: GridContainer = \
		$EquipmentPanel/Content/PowersScroll/PowersGrid
@onready var close_button: Button = $EquipmentPanel/Content/TitleRow/CloseButton

var _showing_powers: bool = false


func _ready() -> void:
	toggle_button.pressed.connect(_toggle_panel)
	powers_button.pressed.connect(_open_powers)
	close_button.pressed.connect(panel.hide)
	letters_tab.pressed.connect(_show_letters)
	powers_tab.pressed.connect(_show_powers)
	EventBus.deck_changed.connect(_refresh)
	$EquipmentPanel/Content/TitleRow.move_child(letters_tab, 1)
	$EquipmentPanel/Content/TitleRow.move_child(powers_tab, 2)
	$EquipmentPanel/Content/TitleRow.move_child(close_button, 3)
	panel.hide()
	_refresh()


func _toggle_panel() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		_show_letters()
		_refresh()


func _open_powers() -> void:
	panel.show()
	_show_powers()
	_refresh()


func _refresh() -> void:
	powers_button.text = "Powers (%d)" % RunState.relics.size()
	mode_label.text = "Itemized letters mode" if RunState.use_itemized_letters \
		else "Legacy deck mode — item equipment is inactive"
	_rebuild_slots()
	_rebuild_inventory()
	_rebuild_powers()
	_refresh_tab()


func _show_letters() -> void:
	_showing_powers = false
	_refresh_tab()


func _show_powers() -> void:
	_showing_powers = true
	_refresh_tab()


func _refresh_tab() -> void:
	title_label.text = "Powers" if _showing_powers else "Equipment"
	letters_tab.button_pressed = not _showing_powers
	powers_tab.button_pressed = _showing_powers
	mode_label.visible = not _showing_powers
	equipped_label.visible = not _showing_powers
	slots_scroll.visible = not _showing_powers
	inventory_label.visible = not _showing_powers
	inventory_scroll.visible = not _showing_powers \
		and inventory_empty_label.text.is_empty()
	inventory_empty_label.visible = not _showing_powers \
		and not inventory_empty_label.text.is_empty()
	powers_scroll.visible = _showing_powers


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
	inventory_empty_label.text = ""
	inventory_scroll.show()
	if not RunState.use_itemized_letters:
		_show_inventory_empty(
			"Switch on itemized letters mode to manage equipped letter items."
		)
		return
	if RunState.letter_inventory.is_empty():
		_show_inventory_empty(
			"No loose letter items yet. Defeat monsters to find them."
		)
		return
	inventory_grid.columns = 6
	for item: LetterStats in RunState.letter_inventory:
		var button := _item_button(item, item.letter, false)
		button.pressed.connect(_equip.bind(item))
		inventory_grid.add_child(button)


func _show_inventory_empty(message: String) -> void:
	inventory_scroll.hide()
	inventory_empty_label.text = message


func _rebuild_powers() -> void:
	_clear(powers_grid)
	if RunState.relics.is_empty():
		_add_power_message("No powers yet. Defeat an enemy to choose one.")
		return
	var power_system: RelicSystem = RelicSystem.new()
	var counts: Dictionary[String, int] = {}
	for power_id: String in RunState.relics:
		counts[power_id] = counts.get(power_id, 0) + 1
	for power_id: String in counts:
		var info: Dictionary = power_system.relic_info(power_id)
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 54)
		button.add_theme_font_size_override("font_size", 20)
		button.text = "%s  ×%d" % [
			info.get("name", power_id), counts[power_id]
		]
		button.tooltip_text = "%s\n%s\nStacks: %d" % [
			power_system.quality_name(power_id),
			info.get("description", ""), counts[power_id]
		]
		var color: Color = power_system.quality_color(power_id)
		button.add_theme_color_override("font_color", color)
		button.add_theme_stylebox_override("normal", _power_style(color))
		button.focus_mode = Control.FOCUS_NONE
		powers_grid.add_child(button)


func _add_power_message(message: String) -> void:
	var label: Label = Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0, 58)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	powers_grid.add_child(label)


func _power_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.075, 0.045, 0.98)
	style.border_color = color
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	return style


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
		item.letter.to_upper(), item.level, item.element_name_text()
	]
	button.tooltip_text = "%s\n%s" % [item.describe(), item.effect_text()]
	button.add_theme_color_override("font_color", TILE_THEME.letter_color)
	button.add_theme_stylebox_override("normal", _item_style(item))
	return button


func _item_style(item: LetterStats) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = TILE_THEME.fill_for(item.element)
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


func _clear(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
