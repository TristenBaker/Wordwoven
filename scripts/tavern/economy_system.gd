class_name EconomySystem
extends Node
## Tavern transactions for recruiting letters, paid dismissals, and meals.
## Offers belong to the run so revisiting the tavern cannot reroll stock.

const RECRUIT_COUNT: int = 6
const LETTER_DEALER_OFFER_COUNT: int = 6
const RECRUIT_PRICE: int = 10
const RARE_RECRUIT_PRICE: int = 20
const DROP_PRICE: int = 10
const MIN_DECK_SIZE: int = 10
const MEAL_PRICE: int = 15
const MEAL_HEAL: int = 10


func _ready() -> void:
	ensure_recruitment_offers()


## A completed encounter brings six distinct recruits, including a rogue.
func ensure_recruitment_offers() -> void:
	var latest: int = 0
	for encounter: int in RunState.completed_encounters:
		latest = maxi(latest, encounter)
	if RunState.recruitment_encounter == latest:
		return
	var candidates: Array[String] = []
	var rares: Array[String] = []
	for letter: String in LetterStats.BASE_POWER:
		candidates.append(letter)
	for letter: String in LetterStats.UNCOMMON_CONSONANTS:
		rares.append(letter)
	var rare: String = rares.pick_random()
	candidates.erase(rare)
	candidates.shuffle()
	var offered: Array[String] = [rare]
	for index: int in range(RECRUIT_COUNT - 1):
		offered.append(candidates[index])
	offered.sort()
	RunState.recruitment_stock = []
	for letter: String in offered:
		RunState.recruitment_stock.append({
			"letter": letter,
			"purchased": false,
		})
	RunState.recruitment_encounter = latest


## Runs already in progress may still hold the older { letter = "a" }
## recruitment stock. Treat it as stale rather than trying to display it as
## an itemized tile.
func _has_valid_letter_dealer_stock() -> bool:
	if RunState.recruitment_stock.size() != LETTER_DEALER_OFFER_COUNT:
		return false
	for offer: Dictionary in RunState.recruitment_stock:
		if not (offer.get("item", null) is LetterStats):
			return false
	return true


func recruitment_offers() -> Array[Dictionary]:
	ensure_recruitment_offers()
	return RunState.recruitment_stock.duplicate(true)


## The itemized-letter dealer receives fresh stock when a new encounter has
## been completed. Stock is kept on the run state, so leaving the room never
## rerolls unpurchased letters.
func ensure_letter_dealer_offers() -> void:
	var latest: int = 0
	for encounter: int in RunState.completed_encounters:
		latest = maxi(latest, encounter)
	if RunState.recruitment_encounter == latest and _has_valid_letter_dealer_stock():
		return
	var highest_level: int = _highest_owned_item_level()
	RunState.recruitment_stock = []
	for _index: int in range(LETTER_DEALER_OFFER_COUNT):
		RunState.recruitment_stock.append({
			"item": _rolled_dealer_item(highest_level),
			"purchased": false,
		})
	RunState.recruitment_encounter = latest


func letter_dealer_offers() -> Array[Dictionary]:
	ensure_letter_dealer_offers()
	return RunState.recruitment_stock.duplicate(true)


func letter_dealer_price(item: LetterStats) -> int:
	if item == null:
		return -1
	return item.level * 5


func buy_letter_dealer_item(offer_index: int) -> bool:
	ensure_letter_dealer_offers()
	if offer_index < 0 or offer_index >= RunState.recruitment_stock.size():
		return false
	var offer: Dictionary = RunState.recruitment_stock[offer_index]
	var item: LetterStats = offer.get("item", null)
	if offer.get("purchased", false) or item == null:
		return false
	var price: int = letter_dealer_price(item)
	if price < 0 or not RunState.spend_gold(price):
		return false
	offer["purchased"] = true
	RunState.add_letter_item(item)
	return true


func _highest_owned_item_level() -> int:
	var highest: int = 1
	for item: LetterStats in RunState.letter_inventory:
		if item != null:
			highest = maxi(highest, item.level)
	for item: LetterStats in RunState.equipped_letters.values():
		if item != null:
			highest = maxi(highest, item.level)
	return highest


func _rolled_dealer_item(highest_level: int) -> LetterStats:
	var letters: Array[String] = []
	for letter: String in LetterStats.BASE_POWER:
		letters.append(letter)
	var elements: Array[int] = [
		LetterStats.Element.FIRE,
		LetterStats.Element.LIGHTNING,
		LetterStats.Element.WATER,
		LetterStats.Element.ICE,
		LetterStats.Element.NATURE,
		LetterStats.Element.EARTH,
	]
	return LetterStats.create_item(
		letters.pick_random(), elements.pick_random(), randi_range(1, maxi(1, highest_level))
	)


func recruit_price(letter: String) -> int:
	var normalized: String = letter.to_lower()
	if not LetterStats.BASE_POWER.has(normalized):
		return -1
	if LetterStats.UNCOMMON_CONSONANTS.contains(normalized):
		return RARE_RECRUIT_PRICE
	return RECRUIT_PRICE


## Each offer can be bought once; owned copies remain separate characters.
func buy_recruit(offer_index: int) -> bool:
	if RunState.use_itemized_letters:
		return false
	ensure_recruitment_offers()
	if offer_index < 0 or offer_index >= RunState.recruitment_stock.size():
		return false
	var offer: Dictionary = RunState.recruitment_stock[offer_index]
	if offer["purchased"]:
		return false
	var letter: String = offer["letter"]
	var price: int = recruit_price(letter)
	if price < 0 or not RunState.spend_gold(price):
		return false
	offer["purchased"] = true
	RunState.deck.append(LetterStats.create(letter))
	EventBus.emit_deck_changed()
	return true


## Dismissals cost gold and preserve a minimum party of ten letters.
func drop_letter(stats: LetterStats) -> bool:
	if RunState.deck.size() <= MIN_DECK_SIZE:
		return false
	if not RunState.deck.has(stats):
		return false
	if not RunState.spend_gold(DROP_PRICE):
		return false
	RunState.deck.erase(stats)
	EventBus.emit_deck_changed()
	return true


func buy_meal() -> bool:
	if RunState.player_health >= RunState.player_max_health:
		return false
	if not RunState.spend_gold(MEAL_PRICE):
		return false
	RunState.heal_player(MEAL_HEAL)
	return true
