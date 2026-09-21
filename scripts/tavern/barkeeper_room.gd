extends Control
## Left tavern room: the barkeeper sells the existing restorative meal.

@onready var economy: EconomySystem = $Systems/EconomySystem
@onready var barkeeper_button: Button = $BarkeeperButton
@onready var menu_panel: PanelContainer = $FoodMenu
@onready var meal_button: Button = $FoodMenu/Menu/MealButton
@onready var close_button: Button = $FoodMenu/Menu/CloseButton
@onready var back_button: Button = $BackButton
@onready var health_label: Label = $StatusPanel/HealthLabel
@onready var gold_label: Label = $StatusPanel/GoldLabel
@onready var feedback_label: Label = $FoodMenu/Menu/FeedbackLabel


func _ready() -> void:
	barkeeper_button.pressed.connect(_open_menu)
	meal_button.pressed.connect(_buy_meal)
	close_button.pressed.connect(menu_panel.hide)
	back_button.pressed.connect(_return_to_hub)
	EventBus.gold_changed.connect(_on_gold_changed)
	_refresh()
	menu_panel.hide()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_B:
		get_viewport().set_input_as_handled()
		_return_to_hub()


func _open_menu() -> void:
	feedback_label.text = ""
	menu_panel.show()
	_refresh()


func _buy_meal() -> void:
	if economy.buy_meal():
		feedback_label.text = "Warm stew restores %d health." % EconomySystem.MEAL_HEAL
	else:
		feedback_label.text = "You need %dg and room to recover." % EconomySystem.MEAL_PRICE
	_refresh()


func _on_gold_changed(_amount: int) -> void:
	_refresh()


func _refresh() -> void:
	health_label.text = "Health  %d / %d" % [
		RunState.player_health, RunState.player_max_health
	]
	gold_label.text = "Gold  %d" % RunState.gold
	meal_button.text = "Hot Meal  —  %dg  (+%d health)" % [
		EconomySystem.MEAL_PRICE, EconomySystem.MEAL_HEAL
	]
	meal_button.disabled = RunState.player_health >= RunState.player_max_health \
		or RunState.gold < EconomySystem.MEAL_PRICE


func _return_to_hub() -> void:
	get_tree().change_scene_to_file(ScenePaths.TAVERN)
