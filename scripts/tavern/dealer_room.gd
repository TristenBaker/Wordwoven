extends Control
## Right tavern room: the dealer offers six itemized letters each shop phase.

const LETTER_TILE_SCENE: PackedScene = preload("res://scenes/combat/letter_tile.tscn")

@onready var economy: EconomySystem = $Systems/EconomySystem
@onready var dealer_button: Button = $DealerButton
@onready var menu_panel: PanelContainer = $LetterShop
@onready var offers_grid: GridContainer = $LetterShop/Menu/OffersGrid
@onready var close_button: Button = $LetterShop/Menu/CloseButton
@onready var back_button: Button = $GoLeftButton
@onready var gold_label: Label = $StatusPanel/GoldLabel
@onready var feedback_label: Label = $LetterShop/Menu/FeedbackLabel


func _ready() -> void:
	dealer_button.pressed.connect(_open_menu)
	close_button.pressed.connect(menu_panel.hide)
	back_button.pressed.connect(_return_to_hub)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.deck_changed.connect(_rebuild_offers)
	if RunState.use_itemized_letters:
		economy.ensure_letter_dealer_offers()
	else:
		economy.ensure_recruitment_offers()
	_rebuild_offers()
	_refresh_status()
	menu_panel.hide()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_B:
		get_viewport().set_input_as_handled()
		_return_to_hub()


func _open_menu() -> void:
	feedback_label.text = ""
	menu_panel.show()
	_rebuild_offers()


func _on_offer_pressed(index: int, button: Button) -> void:
	if _consume_inspector_press(button):
		return
	var purchased: bool = economy.buy_letter_dealer_item(index) \
		if RunState.use_itemized_letters else economy.buy_recruit(index)
	if purchased:
		feedback_label.text = "A letter was added to your inventory."
	else:
		feedback_label.text = "That letter is unavailable, or you need more gold."
	_rebuild_offers()
	_refresh_status()


func _on_gold_changed(_amount: int) -> void:
	_refresh_status()
	_rebuild_offers()


func _rebuild_offers() -> void:
	for child: Node in offers_grid.get_children():
		offers_grid.remove_child(child)
		child.queue_free()
	var offers: Array[Dictionary] = economy.letter_dealer_offers() \
		if RunState.use_itemized_letters else economy.recruitment_offers()
	for index: int in range(offers.size()):
		var offer: Dictionary = offers[index]
		if RunState.use_itemized_letters:
			_add_item_offer(index, offer)
			continue
		var stats: LetterStats = LetterStats.create(offer["letter"])
		var price: int = economy.recruit_price(stats.letter)
		var button := Button.new()
		button.custom_minimum_size = Vector2(142, 70)
		button.add_theme_color_override("font_color", Color(0.2, 0.09, 0.03, 1))
		button.add_theme_color_override("font_hover_color", Color(0.2, 0.09, 0.03, 1))
		button.add_theme_stylebox_override("normal", _offer_style(
			Color(0.76, 0.61, 0.38, 1), Color(0.27, 0.11, 0.06, 1)
		))
		button.add_theme_stylebox_override("hover", _offer_style(
			Color(0.96, 0.79, 0.48, 1), Color(0.63, 0.32, 0.09, 1)
		))
		button.add_theme_stylebox_override("disabled", _offer_style(
			Color(0.34, 0.25, 0.16, 0.9), Color(0.2, 0.12, 0.07, 1)
		))
		button.text = "%s · Lv%d\n%s · %dg" % [
			stats.letter.to_upper(), stats.level, stats.element_name_text(), price
		]
		button.disabled = offer["purchased"] or RunState.gold < price
		if offer["purchased"]:
			button.text = "%s\nSold" % stats.letter.to_upper()
		button.tooltip_text = stats.information_tooltip()
		button.gui_input.connect(_on_offer_gui_input.bind(button, stats))
		button.pressed.connect(_on_offer_pressed.bind(index, button))
		offers_grid.add_child(button)


func _add_item_offer(index: int, offer: Dictionary) -> void:
	var stats: LetterStats = offer.get("item", null)
	if stats == null:
		return
	var price: int = economy.letter_dealer_price(stats)
	var sold: bool = offer.get("purchased", false)
	var affordable: bool = RunState.gold >= price
	var buy_button := LetterInfoButton.new()
	buy_button.custom_minimum_size = Vector2(142, 138)
	buy_button.flat = true
	buy_button.set_letter_stats(stats)
	offers_grid.add_child(buy_button)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 3)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buy_button.add_child(column)

	var tile: LetterTile = LETTER_TILE_SCENE.instantiate()
	tile.custom_minimum_size = Vector2(92, 100)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(tile)
	tile.setup(stats)
	tile.tooltip_text = stats.information_tooltip()
	if sold:
		tile.modulate = Color(0.35, 0.35, 0.35, 0.55)
	elif not affordable:
		tile.modulate = Color(0.7, 0.7, 0.7, 0.72)
	var price_label := Label.new()
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 18)
	price_label.text = "SOLD" if sold else "%d gold" % price
	price_label.add_theme_color_override("font_color", (
		Color("a28a72") if sold else Color("ffd36e") if affordable else Color("d39a86")
	))
	column.add_child(price_label)
	buy_button.gui_input.connect(_on_offer_gui_input.bind(buy_button, stats))
	buy_button.pressed.connect(_on_item_offer_pressed.bind(index, buy_button))


func _on_item_offer_pressed(index: int, button: Button) -> void:
	if _consume_inspector_press(button):
		return
	if economy.buy_letter_dealer_item(index):
		feedback_label.text = "A letter was added to your inventory."
	else:
		feedback_label.text = "That letter is unavailable, or you need more gold."
	_rebuild_offers()
	_refresh_status()


func _on_offer_gui_input(
	event: InputEvent, button: Button, stats: LetterStats
) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		var token: int = Time.get_ticks_msec()
		button.set_meta("letter_press_token", token)
		get_tree().create_timer(0.45).timeout.connect(
			_open_offer_inspector_if_still_held.bind(button, stats, token)
		)
		return
	button.remove_meta("letter_press_token")


func _open_offer_inspector_if_still_held(
	button: Button, stats: LetterStats, token: int
) -> void:
	if int(button.get_meta("letter_press_token", -1)) != token:
		return
	button.set_meta("suppress_letter_action", true)
	LetterInspector.open_for(stats)


func _consume_inspector_press(button: Button) -> bool:
	if not button.get_meta("suppress_letter_action", false):
		return false
	button.remove_meta("suppress_letter_action")
	return true


func _offer_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style


func _refresh_status() -> void:
	gold_label.text = "Gold  %d" % RunState.gold


func _return_to_hub() -> void:
	get_tree().change_scene_to_file(ScenePaths.TAVERN)
