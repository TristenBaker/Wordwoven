extends Control
## Right tavern room: the dealer exposes the existing persistent recruit stock.

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


func _on_offer_pressed(index: int) -> void:
	if economy.buy_recruit(index):
		feedback_label.text = "A letter joins your party."
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
	var offers: Array[Dictionary] = economy.recruitment_offers()
	for index: int in range(offers.size()):
		var offer: Dictionary = offers[index]
		var stats := LetterStats.create(offer["letter"])
		var price := economy.recruit_price(stats.letter)
		var button := Button.new()
		button.custom_minimum_size = Vector2(142, 70)
		button.text = "%s\n%s · %dg" % [
			stats.letter.to_upper(), stats.class_name_text(), price
		]
		button.disabled = offer["purchased"] or RunState.gold < price
		if offer["purchased"]:
			button.text = "%s\nRecruited" % stats.letter.to_upper()
		button.tooltip_text = stats.effect_text()
		button.pressed.connect(_on_offer_pressed.bind(index))
		offers_grid.add_child(button)


func _refresh_status() -> void:
	gold_label.text = "Gold  %d" % RunState.gold


func _return_to_hub() -> void:
	get_tree().change_scene_to_file(ScenePaths.TAVERN)
