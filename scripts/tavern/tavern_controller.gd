extends Control
## The tavern offers haggled recruits, paid dismissals, a meal, and
## the bard's story. Letters grow in combat and relics are chosen
## after victories. Every gold purchase is confirmed first.

var _selected: LetterStats = null
var _letter_group: ButtonGroup = ButtonGroup.new()
var _haggle_offer: int = -1

@onready var economy: EconomySystem = $Systems/EconomySystem
@onready var gold_label: Label = $TopBar/GoldLabel
@onready var health_label: Label = $TopBar/HealthLabel
@onready var story_label: RichTextLabel = \
		$Layout/StoryPanel/StoryMargin/StoryLabel
@onready var vowel_grid: GridContainer = %VowelGrid
@onready var common_grid: GridContainer = %CommonGrid
@onready var uncommon_grid: GridContainer = %UncommonGrid
@onready var selected_label: Label = %SelectedLabel
@onready var drop_button: Button = %DropButton
@onready var recruit_grid: GridContainer = %RecruitGrid
@onready var meal_button: Button = %MealButton
@onready var feedback_label: Label = %FeedbackLabel
@onready var continue_button: Button = $ContinueButton
@onready var close_button: Button = $CloseButton
@onready var confirmer: ActionConfirmer = $ActionConfirmer
@onready var haggle_challenge: TypingChallenge = $HaggleChallenge


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	close_button.pressed.connect(_on_close_pressed)
	drop_button.pressed.connect(_on_drop_pressed)
	meal_button.pressed.connect(_on_meal_pressed)
	haggle_challenge.finished.connect(_on_haggle_finished)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.deck_changed.connect(_on_deck_changed)
	economy.ensure_recruitment_offers()
	_rebuild_deck_grids()
	_rebuild_recruit_buttons()
	_refresh_top_bar()
	_refresh_actions()
	var bard: Storyteller = Storyteller.new()
	story_label.text = bard.generate()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_B:
		get_viewport().set_input_as_handled()
		_on_close_pressed()


# Purchases and dismissals delegate all state changes to the economy.
# Purchases ask first, then delegate every state change to the economy,
# which revalidates availability and gold when the player confirms.
# Buying a recruit always starts with its one haggle. Once the haggle
# is settled, the purchase is confirmed at the resulting price; the
# economy revalidates availability and gold when the player confirms.
func _on_recruit_pressed(offer_index: int) -> void:
	if confirmer.is_pending() or haggle_challenge.is_active():
		return
	var prompt: Dictionary = economy.begin_haggle(offer_index)
	if prompt.is_empty():
		_request_purchase(offer_index)
		return
	_haggle_offer = offer_index
	_rebuild_recruit_buttons()
	haggle_challenge.open(
		"%s to talk the price down from %dg to %dg." % [
			HaggleChallenge.prompt_text(prompt),
			economy.offer_price(offer_index),
			HaggleChallenge.discounted_price(
				economy.offer_price(offer_index)
			),
		],
		economy.check_haggle_answer.bind(offer_index),
		HaggleChallenge.DURATION_MSEC
	)


func _on_haggle_finished(success: bool) -> void:
	var offer_index: int = _haggle_offer
	_haggle_offer = -1
	var discounted: bool = economy.finish_haggle(offer_index, success)
	_rebuild_recruit_buttons()
	if haggle_challenge.walked_away:
		_note("You walk away. The price stays at %dg." % \
				economy.offer_price(offer_index))
		return
	if discounted:
		_note("Deal! This recruit now costs %dg." % \
				economy.offer_price(offer_index))
	else:
		_note("No deal. The price stands.")
	_request_purchase(offer_index)


func _request_purchase(offer_index: int) -> void:
	var offers: Array[Dictionary] = economy.recruitment_offers()
	if offer_index < 0 or offer_index >= offers.size():
		return
	var stats: LetterStats = LetterStats.create(
		offers[offer_index]["letter"]
	)
	confirmer.request(
		"Recruit a letter",
		"Recruit %s (%s) for %dg?" % [
			stats.letter.to_upper(), stats.class_name_text(),
			economy.offer_price(offer_index),
		],
		_confirm_recruit.bind(offer_index)
	)


func _confirm_recruit(offer_index: int) -> void:
	if economy.buy_recruit(offer_index):
		_note("A new letter joins your party!")
	else:
		_note("Recruit unavailable, or not enough gold.")


func _on_drop_pressed() -> void:
	if _selected == null:
		return
	if RunState.deck.size() <= EconomySystem.MIN_DECK_SIZE:
		_note("The party must keep at least ten letters.")
		return
	confirmer.request(
		"Dismiss a letter",
		"Dismiss %s for %dg? It leaves your party for good." % [
			_selected.describe(), EconomySystem.DROP_PRICE,
		],
		_confirm_drop.bind(_selected)
	)


func _confirm_drop(stats: LetterStats) -> void:
	if economy.drop_letter(stats):
		_note("The letter departs. -%dg." % EconomySystem.DROP_PRICE)
	else:
		_note("That letter can no longer be dismissed for gold.")


func _on_meal_pressed() -> void:
	confirmer.request(
		"Hot meal",
		"Buy a hot meal for %dg? It heals up to %d health." % [
			EconomySystem.MEAL_PRICE, EconomySystem.MEAL_HEAL,
		],
		_confirm_meal
	)


func _confirm_meal() -> void:
	if economy.buy_meal():
		_note("Warm stew. +%d health." % EconomySystem.MEAL_HEAL)
		_refresh_top_bar()
		_refresh_actions()
	else:
		_note("Already at full health, or not enough gold.")


func _on_continue_pressed() -> void:
	if haggle_challenge.is_active():
		return
	get_tree().change_scene_to_file(RunFlow.after_tavern())


func _on_close_pressed() -> void:
	get_tree().change_scene_to_file(ScenePaths.TAVERN)


# Refresh the existing layout after transactions without rerolling stock.
func _on_gold_changed(_new_total: int) -> void:
	_refresh_top_bar()
	_refresh_actions()
	_rebuild_recruit_buttons()


func _on_deck_changed() -> void:
	if _selected != null and not RunState.deck.has(_selected):
		_selected = null
	_rebuild_deck_grids()
	_rebuild_recruit_buttons()
	_refresh_actions()


func _rebuild_recruit_buttons() -> void:
	_clear_grid(recruit_grid)
	var offers: Array[Dictionary] = economy.recruitment_offers()
	for index: int in range(offers.size()):
		var offer: Dictionary = offers[index]
		var stats: LetterStats = LetterStats.create(offer["letter"])
		var price: int = economy.offer_price(index)
		recruit_grid.add_child(_recruit_button(index, offer, stats, price))


func _recruit_button(
	index: int, offer: Dictionary, stats: LetterStats, price: int
) -> Button:
	var button: Button = Button.new()
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 52)
	var can_haggle: bool = economy.can_haggle(index)
	# An unhaggled recruit is affordable if a won haggle would cover it.
	var lowest_price: int = HaggleChallenge.discounted_price(price) \
			if can_haggle else price
	var price_text: String = "%dg" % price
	if offer.get("discounted", false):
		price_text = "%dg (haggled)" % price
	button.text = "%s — %s\n%s" % [
		stats.letter.to_upper(),
		stats.class_name_text(),
		"Recruited" if offer["purchased"] else price_text,
	]
	button.disabled = offer["purchased"] or economy.is_haggling() \
			or RunState.gold < lowest_price
	var lines: Array[String] = [stats.effect_text()]
	if can_haggle:
		lines.append(
			"Buying starts a 15-second haggle: win it to pay %dg." \
					% lowest_price
		)
	elif not offer["purchased"]:
		lines.append("Already haggled; the price is final.")
	button.tooltip_text = "\n".join(lines)
	button.pressed.connect(_on_recruit_pressed.bind(index))
	return button


func _rebuild_deck_grids() -> void:
	_clear_grid(vowel_grid)
	_clear_grid(common_grid)
	_clear_grid(uncommon_grid)
	for stats: LetterStats in RunState.deck:
		var button: Button = Button.new()
		button.toggle_mode = true
		button.button_group = _letter_group
		button.button_pressed = stats == _selected
		button.custom_minimum_size = Vector2(52, 44)
		button.text = "%s\nLv%d" % [stats.letter.to_upper(), stats.level]
		button.tooltip_text = "%s\n%s\n+1 level on every drawn use." % [
			stats.describe(), stats.effect_text()
		]
		button.pressed.connect(_on_letter_selected.bind(stats))
		_grid_for(stats).add_child(button)


func _clear_grid(grid: GridContainer) -> void:
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()


func _grid_for(stats: LetterStats) -> GridContainer:
	match stats.letter_class:
		LetterStats.LetterClass.HEALER:
			return vowel_grid
		LetterStats.LetterClass.WARRIOR:
			return common_grid
	return uncommon_grid


func _on_letter_selected(stats: LetterStats) -> void:
	_selected = stats
	_refresh_actions()


func _refresh_top_bar() -> void:
	gold_label.text = "Gold: %d" % RunState.gold
	health_label.text = "Health: %d / %d" % [
		RunState.player_health, RunState.player_max_health
	]


func _refresh_actions() -> void:
	drop_button.text = "Dismiss (%dg)" % EconomySystem.DROP_PRICE
	drop_button.disabled = (
		_selected == null
		or RunState.deck.size() <= EconomySystem.MIN_DECK_SIZE
		or RunState.gold < EconomySystem.DROP_PRICE
	)
	meal_button.disabled = (
		RunState.player_health >= RunState.player_max_health
		or RunState.gold < EconomySystem.MEAL_PRICE
	)
	if _selected == null:
		selected_label.text = "Select a letter to view its role or dismiss it."
		return
	selected_label.text = "%s · %s" % [
		_selected.describe(), _selected.effect_text()
	]


func _note(message: String) -> void:
	feedback_label.text = message
